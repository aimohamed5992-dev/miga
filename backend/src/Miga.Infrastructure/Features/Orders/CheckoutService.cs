using Microsoft.EntityFrameworkCore;
using Miga.Domain;
using Miga.Domain.Common;
using Miga.Domain.Entities;
using Miga.Infrastructure.Common;
using Miga.Infrastructure.Features.Cart;
using Miga.Infrastructure.Notifications;
using Miga.Infrastructure.Payments;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Features.Orders;

public record CheckoutItemResult(Guid CartItemId, Guid? CampaignId, bool Success, Guid? OrderId, string? OrderNumber, decimal Amount, bool CampaignCompleted, string? Code, string? Message);

public record CheckoutResult(IReadOnlyList<CheckoutItemResult> Items, decimal TotalCharged, int SucceededCount, int FailedCount);

/// <summary>
/// Turns campaign lines of the cart into paid CampaignOrders. Each line is its own transaction:
/// lock campaign → validate (live, remaining, per-customer limit, not already joined) → charge → record →
/// increment quantity → complete the campaign if the target is reached. One failing line never blocks the others.
/// </summary>
public class CheckoutService(
    MigaDbContext db,
    CartService carts,
    CampaignLifecycleService lifecycle,
    IPaymentGateway payments,
    Notifier notifier,
    TimeProvider clock)
{
    private static readonly List<CampaignOrderStatus> Joined =
    [
        CampaignOrderStatus.Pending, CampaignOrderStatus.Paid, CampaignOrderStatus.Confirmed, CampaignOrderStatus.Preparing,
        CampaignOrderStatus.ReadyForDelivery, CampaignOrderStatus.OutForDelivery, CampaignOrderStatus.Delivered,
    ];

    public async Task<CheckoutResult> CheckoutAsync(Guid userId, Guid addressId, string paymentMethod, IReadOnlyCollection<Guid>? cartItemIds, CancellationToken ct)
    {
        if (!MockPaymentGateway.Methods.Contains(paymentMethod) && paymentMethod != MockPaymentGateway.FailingTestMethod)
            throw AppException.BadRequest("invalid_payment_method", "طريقة الدفع غير مدعومة");
        if (!await db.Addresses.AnyAsync(a => a.Id == addressId && a.UserId == userId && !a.IsDeleted, ct))
            throw AppException.BadRequest("invalid_address", "عنوان التوصيل غير صحيح");

        var cart = await carts.GetOrCreateAsync(userId, ct);
        var lines = await db.CartItems.AsNoTracking()
            .Where(i => i.CartId == cart.Id && (cartItemIds == null || cartItemIds.Count == 0 || cartItemIds.Contains(i.Id)))
            .Select(i => new { i.Id, i.CampaignId, i.Quantity })
            .ToListAsync(ct);
        if (lines.Count == 0) throw AppException.BadRequest("cart_empty", "السلة فارغة");

        var results = new List<CheckoutItemResult>();
        foreach (var line in lines)
        {
            if (line.CampaignId == null)
            {
                // Regular (non-campaign) product orders need the generic Order model — not part of this release.
                results.Add(new CheckoutItemResult(line.Id, null, false, null, null, 0, false, "product_orders_unsupported",
                    "شراء المنتجات خارج الحملات غير متاح حاليًا، انضم لحملة المنتج"));
                continue;
            }
            try
            {
                results.Add(await JoinCampaignAsync(userId, line.Id, line.CampaignId.Value, line.Quantity, addressId, paymentMethod, ct));
            }
            catch (AppException ex)
            {
                results.Add(new CheckoutItemResult(line.Id, line.CampaignId, false, null, null, 0, false, ex.Code, ex.Message));
            }
        }

        var ok = results.Where(r => r.Success).ToList();
        return new CheckoutResult(results, ok.Sum(r => r.Amount), ok.Count, results.Count - ok.Count);
    }

    private async Task<CheckoutItemResult> JoinCampaignAsync(Guid userId, Guid cartItemId, Guid campaignId, int quantity, Guid addressId, string method, CancellationToken ct)
    {
        db.ChangeTracker.Clear();
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var campaign = await lifecycle.LockAsync(campaignId, ct); // first statement in the transaction → serialized per campaign
        var now = clock.GetUtcNow().UtcDateTime;

        if (campaign.Status != CampaignStatus.Active || campaign.StartDate > now || campaign.EndDate <= now)
            throw AppException.Conflict("campaign_not_active", "انتهت الحملة أو لم تعد متاحة للانضمام");
        if (campaign.MaxQuantityPerCustomer is { } max && quantity > max)
            throw AppException.BadRequest("max_per_customer", $"الحد الأقصى لكل عميل في هذه الحملة {max} قطع");
        if (campaign.RemainingQuantity < quantity)
            throw AppException.Conflict("not_enough_quantity", campaign.RemainingQuantity == 0
                ? "اكتملت الكمية المطلوبة لهذه الحملة"
                : $"باقي {campaign.RemainingQuantity} قطعة فقط لاكتمال الحملة");
        // One order per customer per campaign (participant counts rely on it).
        if (await db.CampaignOrders.AnyAsync(o => o.CampaignId == campaignId && o.CustomerId == userId && Joined.Contains(o.Status), ct))
            throw AppException.Conflict("already_joined", "انضممت لهذه الحملة مسبقًا، تابع طلبك من صفحة طلباتي");

        var order = new CampaignOrder
        {
            Number = Codes.OrderNumber("MG"),
            CampaignId = campaignId,
            CustomerId = userId,
            DeliveryAddressId = addressId,
            Quantity = quantity,
            UnitPrice = campaign.CampaignPrice,
            TotalAmount = campaign.CampaignPrice * quantity,
            Status = CampaignOrderStatus.Pending,
        };
        order.Payment = new Payment { Amount = order.TotalAmount, PaymentMethod = method, Status = PaymentStatus.Pending };
        db.CampaignOrders.Add(order);

        var charge = await payments.ChargeAsync(order.TotalAmount, method, order.Number, ct);
        if (!charge.Success)
        {
            // Keep the failed attempt for support/audit; nothing is reserved and the cart line stays.
            order.Status = CampaignOrderStatus.Cancelled;
            order.CancelledAt = now;
            order.CancellationReason = "فشل الدفع";
            order.Payment.Status = PaymentStatus.Failed;
            order.Payment.FailureReason = charge.FailureReason;
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return new CheckoutItemResult(cartItemId, campaignId, false, order.Id, order.Number, 0, false, "payment_failed",
                $"تعذّر الدفع: {charge.FailureReason}. لم يتم خصم أي مبلغ.");
        }

        order.Status = CampaignOrderStatus.Paid;
        order.Payment.Status = PaymentStatus.Paid;
        order.Payment.PaidAt = now;
        order.Payment.TransactionId = charge.TransactionId;

        campaign.CurrentQuantity += quantity;
        campaign.ConcurrencyStamp = Guid.NewGuid();
        await db.CartItems.Where(i => i.Id == cartItemId).ExecuteDeleteAsync(ct);
        notifier.Notify(userId, NotificationType.Payment, "تم الانضمام للحملة",
            $"تم حجز {quantity} قطعة في حملة \"{campaign.TitleAr}\". باقي {campaign.RemainingQuantity} قطعة لاكتمالها.", order.Id);
        await db.SaveChangesAsync(ct);

        var completed = campaign.CurrentQuantity >= campaign.TargetQuantity;
        if (completed)
        {
            await lifecycle.CompleteAsync(campaign, ct);
            await db.SaveChangesAsync(ct);
        }
        await tx.CommitAsync(ct);
        return new CheckoutItemResult(cartItemId, campaignId, true, order.Id, order.Number, order.TotalAmount, completed, null, null);
    }
}
