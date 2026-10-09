using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Miga.Domain;
using Miga.Domain.Common;
using Miga.Domain.Entities;
using Miga.Infrastructure.Common;
using Miga.Infrastructure.Features.Settings;
using Miga.Infrastructure.Notifications;
using Miga.Infrastructure.Payments;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Features.Orders;

/// <summary>
/// Campaign state machine: Active → Completed (target reached: MerchantOrder + Deliveries are created)
/// or Active → Failed (time ran out: every paid order is refunded). All quantity changes happen while
/// holding a row lock on the campaign (SELECT … FOR UPDATE), so concurrent buyers can never oversell.
/// </summary>
public class CampaignLifecycleService(
    MigaDbContext db,
    IPaymentGateway payments,
    Notifier notifier,
    PlatformSettingsService settings,
    TimeProvider clock,
    ILogger<CampaignLifecycleService> log)
{
    /// <summary>
    /// Loads the campaign with an exclusive row lock. Must run inside a transaction and before any other read of
    /// this campaign in the context (a tracked copy would otherwise mask the fresh row).
    /// </summary>
    public async Task<Campaign> LockAsync(Guid campaignId, CancellationToken ct)
    {
        var rows = await db.Campaigns.FromSqlInterpolated($"SELECT * FROM `Campaigns` WHERE `Id` = {campaignId} FOR UPDATE").ToListAsync(ct);
        return rows.FirstOrDefault() ?? throw AppException.NotFound("campaign_not_found", "الحملة غير موجودة");
    }

    /// <summary>
    /// Target reached: close the campaign, confirm all paid orders, create the aggregated MerchantOrder
    /// and one pending Delivery per customer order. Caller holds the lock and saves.
    /// </summary>
    public async Task CompleteAsync(Campaign campaign, CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        campaign.Status = CampaignStatus.Completed;
        campaign.CompletedAt = now;
        campaign.ConcurrencyStamp = Guid.NewGuid();

        var orders = await db.CampaignOrders.Where(o => o.CampaignId == campaign.Id && o.Status == CampaignOrderStatus.Paid).ToListAsync(ct);
        var total = orders.Sum(o => o.TotalAmount);
        var fees = await settings.GetAsync(ct); // rates in force when the campaign completes
        var merchantOrder = new MerchantOrder
        {
            Number = Codes.OrderNumber("MO"),
            CampaignId = campaign.Id,
            StoreId = campaign.StoreId,
            TotalQuantity = orders.Sum(o => o.Quantity),
            CustomersCount = orders.Count,
            TotalAmount = total,
            PlatformFee = Math.Round(total * fees.PlatformFeePercent / 100, 2),
            PickupCode = Codes.Pin(),
            Status = MerchantOrderStatus.SentToMerchant,
        };
        db.MerchantOrders.Add(merchantOrder);

        foreach (var order in orders)
        {
            order.Status = CampaignOrderStatus.Confirmed;
            order.ConfirmedAt = now;
            db.Deliveries.Add(new Delivery
            {
                Number = Codes.OrderNumber("DL"),
                CampaignOrderId = order.Id,
                MerchantOrderId = merchantOrder.Id,
                DeliveryAddressId = order.DeliveryAddressId,
                Fee = fees.DeliveryFee,
                DeliveryCode = Codes.Pin(),
                Status = DeliveryStatus.Pending,
            });
            notifier.Notify(order.CustomerId, NotificationType.CampaignCompleted, "اكتملت الحملة 🎉",
                $"حملة \"{campaign.TitleAr}\" اكتملت وجاري تجهيز طلبك {order.Number}.", order.Id);
        }

        // Stock leaves the warehouse with the aggregated order.
        await db.Products.Where(p => p.Id == campaign.ProductId)
            .ExecuteUpdateAsync(s => s.SetProperty(p => p.StockQuantity, p => p.StockQuantity >= merchantOrder.TotalQuantity ? p.StockQuantity - merchantOrder.TotalQuantity : 0), ct);

        notifier.Notify(campaign.MerchantUserId, NotificationType.OrderStatus, "طلب مجمّع جديد",
            $"اكتملت حملة \"{campaign.TitleAr}\": {merchantOrder.TotalQuantity} قطعة لـ {orders.Count} عميل. الطلب {merchantOrder.Number}.", merchantOrder.Id);
        log.LogInformation("Campaign {Campaign} completed → {MerchantOrder}", campaign.Id, merchantOrder.Number);
    }

    /// <summary>Background job: campaigns whose time is up become Failed and every paid order is refunded.</summary>
    public async Task<int> ExpireDueAsync(CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var due = await db.Campaigns.AsNoTracking().Where(c => c.Status == CampaignStatus.Active && c.EndDate <= now).Select(c => c.Id).ToListAsync(ct);

        foreach (var id in due)
        {
            db.ChangeTracker.Clear();
            await using var tx = await db.Database.BeginTransactionAsync(ct);
            var campaign = await LockAsync(id, ct);
            if (campaign.Status != CampaignStatus.Active || campaign.EndDate > now) continue; // changed meanwhile

            if (campaign.CurrentQuantity >= campaign.TargetQuantity)
            {
                await CompleteAsync(campaign, ct);
            }
            else
            {
                campaign.Status = CampaignStatus.Failed;
                campaign.ConcurrencyStamp = Guid.NewGuid();
                var orders = await db.CampaignOrders.Include(o => o.Payment)
                    .Where(o => o.CampaignId == id && o.Status == CampaignOrderStatus.Paid).ToListAsync(ct);
                foreach (var order in orders)
                {
                    await RefundAsync(order, CampaignOrderStatus.Refunded, ct);
                    notifier.Notify(order.CustomerId, NotificationType.CampaignFailed, "لم تكتمل الحملة",
                        $"انتهى وقت حملة \"{campaign.TitleAr}\" قبل اكتمالها، وتم استرداد {order.TotalAmount:0.##} ر.س إلى وسيلة الدفع.", order.Id);
                }
                notifier.Notify(campaign.MerchantUserId, NotificationType.CampaignFailed, "انتهت حملة دون اكتمال",
                    $"حملة \"{campaign.TitleAr}\" وصلت {campaign.CurrentQuantity} من {campaign.TargetQuantity}، وتم استرداد مبالغ العملاء.", campaign.Id);
            }
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
        }
        return due.Count;
    }

    /// <summary>Customer cancels before the campaign completes: full refund, quantity released.</summary>
    public async Task CancelByCustomerAsync(Guid customerId, Guid orderId, string reason, CancellationToken ct)
    {
        var campaignId = await db.CampaignOrders.AsNoTracking().Where(o => o.Id == orderId && o.CustomerId == customerId)
            .Select(o => (Guid?)o.CampaignId).FirstOrDefaultAsync(ct) ?? throw AppException.NotFound("order_not_found", "الطلب غير موجود");

        db.ChangeTracker.Clear();
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var campaign = await LockAsync(campaignId, ct);
        var order = await db.CampaignOrders.Include(o => o.Payment).FirstAsync(o => o.Id == orderId, ct);

        if (order.Status != CampaignOrderStatus.Paid || campaign.Status != CampaignStatus.Active)
            throw AppException.Conflict("order_not_cancellable", "لا يمكن إلغاء الطلب بعد اكتمال الحملة أو بدء التجهيز");

        await RefundAsync(order, CampaignOrderStatus.Cancelled, ct);
        order.CancellationReason = reason.Trim();
        campaign.CurrentQuantity -= order.Quantity;
        campaign.ConcurrencyStamp = Guid.NewGuid();
        notifier.Notify(customerId, NotificationType.Payment, "تم إلغاء الطلب", $"تم إلغاء الطلب {order.Number} واسترداد {order.TotalAmount:0.##} ر.س.", order.Id);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
    }

    /// <summary>Merchant cancels a running campaign: every paid order is refunded and participants are told why.</summary>
    public Task CancelByMerchantAsync(Guid merchantUserId, Guid campaignId, string reason, CancellationToken ct) =>
        CancelAsync(campaignId, reason, merchantUserId, ct);

    /// <summary>MIGA cancels a running campaign (e.g. policy violation): every paid customer is refunded and the merchant is told why.</summary>
    public Task CancelByAdminAsync(Guid campaignId, string reason, CancellationToken ct) => CancelAsync(campaignId, reason, null, ct);

    private async Task CancelAsync(Guid campaignId, string reason, Guid? merchantUserId, CancellationToken ct)
    {
        db.ChangeTracker.Clear();
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var campaign = await LockAsync(campaignId, ct);
        if (merchantUserId != null && campaign.MerchantUserId != merchantUserId) throw AppException.NotFound("campaign_not_found", "الحملة غير موجودة");
        if (campaign.Status is not (CampaignStatus.Active or CampaignStatus.Draft))
            throw AppException.Conflict("campaign_not_cancellable", "لا يمكن إلغاء حملة مكتملة أو منتهية");

        var byAdmin = merchantUserId == null;
        var orders = await db.CampaignOrders.Include(o => o.Payment).Where(o => o.CampaignId == campaignId && o.Status == CampaignOrderStatus.Paid).ToListAsync(ct);
        foreach (var order in orders)
        {
            await RefundAsync(order, CampaignOrderStatus.Refunded, ct);
            order.CancellationReason = reason.Trim();
            notifier.Notify(order.CustomerId, NotificationType.CampaignFailed, "أُلغيت الحملة",
                $"{(byAdmin ? "ألغت ميجا" : "ألغى التاجر")} حملة \"{campaign.TitleAr}\" وتم استرداد {order.TotalAmount:0.##} ر.س إلى وسيلة الدفع.", order.Id);
        }
        if (byAdmin)
            notifier.Notify(campaign.MerchantUserId, NotificationType.CampaignFailed, "ألغت ميجا إحدى حملاتك",
                $"تم إلغاء حملة \"{campaign.TitleAr}\": {reason.Trim()}. استُرد المبلغ لـ {orders.Count} عميل.", campaign.Id);
        campaign.Status = CampaignStatus.Cancelled;
        campaign.ConcurrencyStamp = Guid.NewGuid();
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
    }

    /// <summary>
    /// Support closes a failed delivery by refunding the customer: the delivery is cancelled and the amount leaves the
    /// merchant's settlement (see MerchantInsightsService.EarningsAsync).
    /// </summary>
    public async Task RefundFailedDeliveryAsync(Guid deliveryId, string reason, CancellationToken ct)
    {
        var d = await db.Deliveries.Include(x => x.CampaignOrder).ThenInclude(o => o.Payment)
            .Include(x => x.MerchantOrder).ThenInclude(m => m.Store).ThenInclude(s => s.Merchant)
            .FirstOrDefaultAsync(x => x.Id == deliveryId, ct) ?? throw AppException.NotFound("delivery_not_found", "التوصيلة غير موجودة");
        if (d.Status != DeliveryStatus.Failed) throw AppException.Conflict("delivery_not_failed", "الاسترداد متاح للتوصيلات المتعثرة فقط");

        var order = d.CampaignOrder;
        await RefundAsync(order, CampaignOrderStatus.Refunded, ct);
        order.CancellationReason = reason.Trim();
        d.Status = DeliveryStatus.Cancelled;
        notifier.Notify(order.CustomerId, NotificationType.Payment, "تم استرداد مبلغ طلبك",
            $"تعذّر تسليم الطلب {order.Number}، وتم استرداد {order.TotalAmount:0.##} ر.س إلى وسيلة الدفع.", order.Id);
        notifier.Notify(d.MerchantOrder.Store.Merchant.UserId, NotificationType.OrderStatus, "استرداد توصيلة متعثرة",
            $"أُلغيت التوصيلة {d.Number} واستُرد مبلغها للعميل ({reason.Trim()}). خُصم من مستحقات الطلب {d.MerchantOrder.Number}.", d.MerchantOrderId);
        await db.SaveChangesAsync(ct);
    }

    private async Task RefundAsync(CampaignOrder order, CampaignOrderStatus newStatus, CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        if (order.Payment is { Status: PaymentStatus.Paid, TransactionId: { } tx })
        {
            var refund = await payments.RefundAsync(tx, order.TotalAmount, ct);
            if (!refund.Success) throw AppException.Conflict("refund_failed", "تعذّر استرداد المبلغ، سيتواصل معك الدعم");
            order.Payment.Status = PaymentStatus.Refunded;
            order.Payment.RefundedAt = now;
        }
        order.Status = newStatus;
        order.CancelledAt = now;
    }
}
