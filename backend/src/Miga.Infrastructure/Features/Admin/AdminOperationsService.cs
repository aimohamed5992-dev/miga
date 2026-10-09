using Microsoft.EntityFrameworkCore;
using Miga.Domain;
using Miga.Domain.Common;
using Miga.Domain.Entities;
using Miga.Infrastructure.Common;
using Miga.Infrastructure.Features.Orders;
using Miga.Infrastructure.Notifications;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Features.Admin;

public record AdminCampaignDto(
    Guid Id, string TitleAr, Guid StoreId, string StoreName, string MerchantName, string ProductName, string? ImageUrl,
    decimal OriginalPrice, decimal CampaignPrice, int TargetQuantity, int CurrentQuantity, int Participants, CampaignStatus Status,
    DateTime StartDate, DateTime EndDate, DateTime? CompletedAt);

public record AdminOrderDto(
    Guid Id, string Number, string CustomerName, string CustomerPhone, string CampaignTitle, string StoreName, int Quantity, decimal TotalAmount,
    CampaignOrderStatus Status, PaymentStatus? PaymentStatus, DeliveryStatus? DeliveryStatus, string? CancellationReason, DateTime CreatedAt);

public record AdminMerchantOrderDto(
    Guid Id, string Number, string StoreName, string CampaignTitle, int TotalQuantity, int CustomersCount, decimal TotalAmount, decimal PlatformFee,
    MerchantOrderStatus Status, int Deliveries, int Delivered, DateTime CreatedAt, DateTime? ReadyAt, DateTime? CompletedAt);

public record AdminDeliveryDto(
    Guid Id, string Number, DeliveryStatus Status, string? DriverName, string? DriverPhone, string CustomerName, string CustomerPhone,
    string StoreName, string District, string City, string ProductName, int Quantity, decimal Fee, decimal OrderAmount, string? FailureReason,
    string OrderNumber, DateTime CreatedAt, DateTime? AcceptedAt, DateTime? DeliveredAt);

public record AdminPayoutDto(
    Guid Id, Guid MerchantUserId, string MerchantName, string? BusinessName, string? BankName, string Iban, decimal Amount, PayoutStatus Status,
    DateTime CreatedAt, DateTime? PaidAt, string? TransferReference, string? RejectionReason);

/// <summary>
/// MIGA operations: watch campaigns, customer and aggregated orders and deliveries; resolve failed deliveries
/// (retry with the same driver, or refund the customer); process merchant withdrawals.
/// </summary>
public class AdminOperationsService(MigaDbContext db, CampaignLifecycleService lifecycle, Notifier notifier, TimeProvider clock)
{
    private DateTime Now => clock.GetUtcNow().UtcDateTime;

    private static readonly List<CampaignOrderStatus> InProgressOrders =
        [CampaignOrderStatus.Paid, CampaignOrderStatus.Confirmed, CampaignOrderStatus.Preparing, CampaignOrderStatus.ReadyForDelivery, CampaignOrderStatus.OutForDelivery];
    private static readonly List<CampaignOrderStatus> ClosedOrders = [CampaignOrderStatus.Cancelled, CampaignOrderStatus.Refunded];
    private static readonly List<DeliveryStatus> InProgressDeliveries = [DeliveryStatus.DriverAccepted, DeliveryStatus.PickedUp, DeliveryStatus.OutForDelivery];
    private static readonly List<CampaignOrderStatus> Sold =
        [CampaignOrderStatus.Paid, CampaignOrderStatus.Confirmed, CampaignOrderStatus.Preparing, CampaignOrderStatus.ReadyForDelivery,
         CampaignOrderStatus.OutForDelivery, CampaignOrderStatus.Delivered];

    // ---------------------------------------------------------------- campaigns

    /// <param name="status">active · completed · ended (failed/cancelled/closed) · draft · all</param>
    public Task<PagedResult<AdminCampaignDto>> CampaignsAsync(string status, string? q, int page, int pageSize, CancellationToken ct)
    {
        var campaigns = db.Campaigns.AsNoTracking();
        campaigns = status switch
        {
            "active" => campaigns.Where(c => c.Status == CampaignStatus.Active || c.Status == CampaignStatus.Processing),
            "completed" => campaigns.Where(c => c.Status == CampaignStatus.Completed),
            "ended" => campaigns.Where(c => c.Status == CampaignStatus.Failed || c.Status == CampaignStatus.Cancelled || c.Status == CampaignStatus.Closed),
            "draft" => campaigns.Where(c => c.Status == CampaignStatus.Draft),
            _ => campaigns,
        };
        if (!string.IsNullOrWhiteSpace(q))
        {
            var term = q.Trim();
            campaigns = campaigns.Where(c => c.TitleAr.Contains(term) || c.Store.NameAr.Contains(term) || c.Product.NameAr.Contains(term));
        }
        return campaigns.OrderByDescending(c => c.CreatedAt).Select(c => new AdminCampaignDto(
            c.Id, c.TitleAr, c.StoreId, c.Store.NameAr, c.MerchantUser.FullName, c.Product.NameAr,
            c.Product.Images.OrderBy(i => i.SortOrder).Select(i => i.ImageUrl).FirstOrDefault(),
            c.OriginalPrice, c.CampaignPrice, c.TargetQuantity, c.CurrentQuantity, c.Orders.Count(o => Sold.Contains(o.Status)), c.Status,
            c.StartDate, c.EndDate, c.CompletedAt)).ToPagedAsync(page, pageSize, ct);
    }

    public Task CancelCampaignAsync(Guid id, string reason, CancellationToken ct) => lifecycle.CancelByAdminAsync(id, reason, ct);

    // ---------------------------------------------------------------- orders

    /// <param name="status">active · delivered · closed (cancelled/refunded) · all</param>
    public Task<PagedResult<AdminOrderDto>> OrdersAsync(string status, string? q, int page, int pageSize, CancellationToken ct)
    {
        var orders = db.CampaignOrders.AsNoTracking().Where(o => o.Status != CampaignOrderStatus.Pending);
        orders = status switch
        {
            "active" => orders.Where(o => InProgressOrders.Contains(o.Status)),
            "delivered" => orders.Where(o => o.Status == CampaignOrderStatus.Delivered),
            "closed" => orders.Where(o => ClosedOrders.Contains(o.Status)),
            _ => orders,
        };
        if (!string.IsNullOrWhiteSpace(q))
        {
            var term = q.Trim();
            var phoneTerm = term.StartsWith("05") ? "+966" + term[1..] : term;
            orders = orders.Where(o => o.Number.Contains(term) || o.Customer.FullName.Contains(term) || o.Customer.PhoneNumber!.Contains(phoneTerm));
        }
        return orders.OrderByDescending(o => o.CreatedAt).Select(o => new AdminOrderDto(
            o.Id, o.Number, o.Customer.FullName, o.Customer.PhoneNumber ?? "", o.Campaign.TitleAr, o.Campaign.Store.NameAr, o.Quantity, o.TotalAmount,
            o.Status, o.Payment != null ? o.Payment.Status : null, o.Delivery != null ? o.Delivery.Status : null, o.CancellationReason, o.CreatedAt))
            .ToPagedAsync(page, pageSize, ct);
    }

    /// <param name="status">open · completed · all</param>
    public Task<PagedResult<AdminMerchantOrderDto>> MerchantOrdersAsync(string status, string? q, int page, int pageSize, CancellationToken ct)
    {
        var orders = db.MerchantOrders.AsNoTracking();
        orders = status switch
        {
            "open" => orders.Where(o => o.Status != MerchantOrderStatus.Completed && o.Status != MerchantOrderStatus.Cancelled),
            "completed" => orders.Where(o => o.Status == MerchantOrderStatus.Completed),
            _ => orders,
        };
        if (!string.IsNullOrWhiteSpace(q))
        {
            var term = q.Trim();
            orders = orders.Where(o => o.Number.Contains(term) || o.Store.NameAr.Contains(term) || o.Campaign.TitleAr.Contains(term));
        }
        return orders.OrderByDescending(o => o.CreatedAt).Select(o => new AdminMerchantOrderDto(
            o.Id, o.Number, o.Store.NameAr, o.Campaign.TitleAr, o.TotalQuantity, o.CustomersCount, o.TotalAmount, o.PlatformFee, o.Status,
            o.Deliveries.Count(), o.Deliveries.Count(d => d.Status == DeliveryStatus.Delivered), o.CreatedAt, o.ReadyAt, o.CompletedAt))
            .ToPagedAsync(page, pageSize, ct);
    }

    // ---------------------------------------------------------------- deliveries

    /// <param name="status">failed · in_progress · waiting (no driver yet) · delivered · all</param>
    public Task<PagedResult<AdminDeliveryDto>> DeliveriesAsync(string status, string? q, int page, int pageSize, CancellationToken ct)
    {
        var deliveries = db.Deliveries.AsNoTracking();
        deliveries = status switch
        {
            "failed" => deliveries.Where(d => d.Status == DeliveryStatus.Failed),
            "in_progress" => deliveries.Where(d => InProgressDeliveries.Contains(d.Status)),
            "waiting" => deliveries.Where(d => d.Status == DeliveryStatus.Pending || d.Status == DeliveryStatus.Assigned),
            "delivered" => deliveries.Where(d => d.Status == DeliveryStatus.Delivered),
            _ => deliveries,
        };
        if (!string.IsNullOrWhiteSpace(q))
        {
            var term = q.Trim();
            deliveries = deliveries.Where(d => d.Number.Contains(term) || d.CampaignOrder.Number.Contains(term)
                || d.CampaignOrder.Customer.FullName.Contains(term) || (d.DriverUser != null && d.DriverUser.FullName.Contains(term)));
        }
        return deliveries.OrderByDescending(d => d.CreatedAt).Select(d => new AdminDeliveryDto(
            d.Id, d.Number, d.Status, d.DriverUser != null ? d.DriverUser.FullName : null, d.DriverUser != null ? d.DriverUser.PhoneNumber : null,
            d.CampaignOrder.Customer.FullName, d.CampaignOrder.Customer.PhoneNumber ?? "", d.MerchantOrder.Store.NameAr,
            d.DeliveryAddress.District.NameAr, d.DeliveryAddress.City.NameAr, d.CampaignOrder.Campaign.Product.NameAr, d.CampaignOrder.Quantity, d.Fee,
            d.CampaignOrder.TotalAmount, d.FailureReason, d.CampaignOrder.Number, d.CreatedAt, d.AcceptedAt, d.DeliveredAt))
            .ToPagedAsync(page, pageSize, ct);
    }

    /// <summary>
    /// After support reaches the customer: the same driver (who still has the goods) gets the delivery back as picked up,
    /// and starts the trip again from the app.
    /// </summary>
    public async Task RetryDeliveryAsync(Guid id, string? note, CancellationToken ct)
    {
        var d = await db.Deliveries.Include(x => x.CampaignOrder).Include(x => x.DriverUser)
            .FirstOrDefaultAsync(x => x.Id == id, ct) ?? throw AppException.NotFound("delivery_not_found", "التوصيلة غير موجودة");
        if (d.Status != DeliveryStatus.Failed) throw AppException.Conflict("delivery_not_failed", "إعادة المحاولة متاحة للتوصيلات المتعثرة فقط");
        if (d.DriverUser is not { IsActive: true }) throw AppException.Conflict("driver_inactive", "حساب المندوب موقوف، استخدم الاسترداد بدلًا من ذلك");

        d.Status = DeliveryStatus.PickedUp;
        d.DeliveryNotes = string.IsNullOrWhiteSpace(note) ? d.DeliveryNotes : note.Trim();
        d.FailureReason = null;
        d.OutForDeliveryAt = null;
        d.CampaignOrder.Status = CampaignOrderStatus.ReadyForDelivery;
        var extra = string.IsNullOrWhiteSpace(note) ? "" : $" ملاحظة الدعم: {note.Trim()}";
        notifier.Notify(d.DriverUserId!.Value, NotificationType.DeliveryRequest, "إعادة محاولة توصيل",
            $"تواصل الدعم مع العميل، أعد محاولة توصيل {d.Number}.{extra}", d.Id);
        notifier.Notify(d.CampaignOrder.CustomerId, NotificationType.OrderStatus, "سنعيد محاولة توصيل طلبك",
            $"سيتواصل معك المندوب قريبًا لتسليم الطلب {d.CampaignOrder.Number}.", d.CampaignOrderId);
        await db.SaveChangesAsync(ct);
    }

    public Task RefundDeliveryAsync(Guid id, string reason, CancellationToken ct) => lifecycle.RefundFailedDeliveryAsync(id, reason, ct);

    // ---------------------------------------------------------------- payouts

    /// <param name="status">requested · paid · rejected · all</param>
    public Task<PagedResult<AdminPayoutDto>> PayoutsAsync(string status, int page, int pageSize, CancellationToken ct)
    {
        var payouts = db.MerchantPayouts.AsNoTracking();
        payouts = status switch
        {
            "requested" => payouts.Where(p => p.Status == PayoutStatus.Requested),
            "paid" => payouts.Where(p => p.Status == PayoutStatus.Paid),
            "rejected" => payouts.Where(p => p.Status == PayoutStatus.Rejected),
            _ => payouts,
        };
        // Requests are handled first-in, first-out; history shows the latest first.
        payouts = status == "requested" ? payouts.OrderBy(p => p.CreatedAt) : payouts.OrderByDescending(p => p.CreatedAt);
        return payouts.Select(p => new AdminPayoutDto(
            p.Id, p.Merchant.UserId, p.Merchant.User.FullName, p.Merchant.BusinessNameAr, p.Merchant.BankName, p.Iban, p.Amount, p.Status,
            p.CreatedAt, p.PaidAt, p.TransferReference, p.RejectionReason)).ToPagedAsync(page, pageSize, ct);
    }

    public async Task MarkPayoutPaidAsync(Guid id, string reference, CancellationToken ct)
    {
        var p = await RequestedPayoutAsync(id, ct);
        p.Status = PayoutStatus.Paid;
        p.PaidAt = Now;
        p.TransferReference = reference.Trim();
        notifier.Notify(p.Merchant.UserId, NotificationType.Payment, "تم تحويل أرباحك 💸",
            $"حوّلنا {p.Amount:0.##} ر.س إلى حسابك البنكي. مرجع التحويل: {p.TransferReference}.", p.Id);
        await db.SaveChangesAsync(ct);
    }

    public async Task RejectPayoutAsync(Guid id, string reason, CancellationToken ct)
    {
        var p = await RequestedPayoutAsync(id, ct);
        p.Status = PayoutStatus.Rejected;
        p.RejectionReason = reason.Trim();
        notifier.Notify(p.Merchant.UserId, NotificationType.Payment, "تعذّر تحويل طلب السحب",
            $"لم نتمكن من تحويل {p.Amount:0.##} ر.س: {p.RejectionReason}. أُعيد المبلغ إلى رصيدك المتاح.", p.Id);
        await db.SaveChangesAsync(ct);
    }

    private async Task<MerchantPayout> RequestedPayoutAsync(Guid id, CancellationToken ct)
    {
        var p = await db.MerchantPayouts.Include(x => x.Merchant).FirstOrDefaultAsync(x => x.Id == id, ct)
            ?? throw AppException.NotFound("payout_not_found", "طلب السحب غير موجود");
        if (p.Status != PayoutStatus.Requested) throw AppException.Conflict("payout_already_processed", "تمت معالجة طلب السحب مسبقًا");
        return p;
    }
}
