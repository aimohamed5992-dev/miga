using Microsoft.EntityFrameworkCore;
using Miga.Domain;
using Miga.Domain.Common;
using Miga.Infrastructure.Common;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Features.Orders;

public record OrderSummaryDto(
    Guid Id, string Number, CampaignOrderStatus Status, DateTime CreatedAt, int Quantity, decimal TotalAmount,
    Guid CampaignId, string CampaignTitle, CampaignStatus CampaignStatus, int CampaignCurrentQuantity, int CampaignTargetQuantity, DateTime CampaignEndDate,
    string ProductName, string? ImageUrl, string StoreName);

public record OrderPaymentDto(string? Method, PaymentStatus Status, decimal Amount, DateTime? PaidAt, DateTime? RefundedAt);

public record OrderDeliveryDto(string Number, DeliveryStatus Status, string? DriverName, string? DriverPhone, string DeliveryCode, DateTime? OutForDeliveryAt, DateTime? DeliveredAt);

public record OrderDetailDto(
    OrderSummaryDto Order, decimal UnitPrice, decimal OriginalPrice, string AddressName, string AddressSummary, string AddressPhone,
    OrderPaymentDto? Payment, OrderDeliveryDto? Delivery, DateTime? ConfirmedAt, DateTime? DeliveredAt, DateTime? CancelledAt, string? CancellationReason,
    bool CanCancel);

public enum OrderScope
{
    Current,
    Past,
}

public class CustomerOrderQueries(MigaDbContext db)
{
    private static readonly List<CampaignOrderStatus> PastStatuses = [CampaignOrderStatus.Delivered, CampaignOrderStatus.Cancelled, CampaignOrderStatus.Refunded];

    public Task<PagedResult<OrderSummaryDto>> ListAsync(Guid userId, OrderScope scope, int page, int pageSize, CancellationToken ct)
    {
        // Failed payment attempts (no money taken) stay out of the customer's list.
        var q = db.CampaignOrders.Where(o => o.CustomerId == userId && !(o.Payment != null && o.Payment.Status == PaymentStatus.Failed));
        q = scope == OrderScope.Past ? q.Where(o => PastStatuses.Contains(o.Status)) : q.Where(o => !PastStatuses.Contains(o.Status));
        return q.OrderByDescending(o => o.CreatedAt).Select(o => new OrderSummaryDto(
                o.Id, o.Number, o.Status, o.CreatedAt, o.Quantity, o.TotalAmount,
                o.CampaignId, o.Campaign.TitleAr, o.Campaign.Status, o.Campaign.CurrentQuantity, o.Campaign.TargetQuantity, o.Campaign.EndDate,
                o.Campaign.Product.NameAr, o.Campaign.Product.Images.OrderBy(i => i.SortOrder).Select(i => i.ImageUrl).FirstOrDefault(), o.Campaign.Store.NameAr))
            .ToPagedAsync(page, pageSize, ct);
    }

    public async Task<OrderDetailDto> GetAsync(Guid userId, Guid orderId, CancellationToken ct)
    {
        var d = await db.CampaignOrders.AsNoTracking().Where(o => o.Id == orderId && o.CustomerId == userId).Select(o => new
        {
            Summary = new OrderSummaryDto(
                o.Id, o.Number, o.Status, o.CreatedAt, o.Quantity, o.TotalAmount,
                o.CampaignId, o.Campaign.TitleAr, o.Campaign.Status, o.Campaign.CurrentQuantity, o.Campaign.TargetQuantity, o.Campaign.EndDate,
                o.Campaign.Product.NameAr, o.Campaign.Product.Images.OrderBy(i => i.SortOrder).Select(i => i.ImageUrl).FirstOrDefault(), o.Campaign.Store.NameAr),
            o.UnitPrice, o.Campaign.OriginalPrice,
            o.DeliveryAddress.AddressName,
            District = o.DeliveryAddress.District.NameAr, City = o.DeliveryAddress.City.NameAr, Region = o.DeliveryAddress.Region.NameAr,
            AddressPhone = o.DeliveryAddress.PhoneNumber,
            Payment = o.Payment == null ? null : new OrderPaymentDto(o.Payment.PaymentMethod, o.Payment.Status, o.Payment.Amount, o.Payment.PaidAt, o.Payment.RefundedAt),
            Delivery = o.Delivery == null ? null : new OrderDeliveryDto(
                o.Delivery.Number, o.Delivery.Status,
                o.Delivery.DriverUser != null ? o.Delivery.DriverUser.FullName : null,
                o.Delivery.DriverUser != null ? o.Delivery.DriverUser.PhoneNumber : null,
                o.Delivery.DeliveryCode, o.Delivery.OutForDeliveryAt, o.Delivery.DeliveredAt),
            o.ConfirmedAt, o.DeliveredAt, o.CancelledAt, o.CancellationReason,
        }).FirstOrDefaultAsync(ct) ?? throw AppException.NotFound("order_not_found", "الطلب غير موجود");

        var canCancel = d.Summary.Status == CampaignOrderStatus.Paid && d.Summary.CampaignStatus == CampaignStatus.Active;
        return new OrderDetailDto(d.Summary, d.UnitPrice, d.OriginalPrice, d.AddressName, $"{d.District}، {d.City}، {d.Region}", d.AddressPhone,
            d.Payment, d.Delivery, d.ConfirmedAt, d.DeliveredAt, d.CancelledAt, d.CancellationReason, canCancel);
    }

    public Task<List<NotificationDto>> NotificationsAsync(Guid userId, CancellationToken ct) =>
        db.Notifications.AsNoTracking().Where(n => n.UserId == userId).OrderByDescending(n => n.CreatedAt).Take(100)
            .Select(n => new NotificationDto(n.Id, n.Type, n.Title, n.Body, n.ReferenceId, n.IsRead, n.CreatedAt)).ToListAsync(ct);

    public Task MarkAllReadAsync(Guid userId, CancellationToken ct) =>
        db.Notifications.Where(n => n.UserId == userId && !n.IsRead).ExecuteUpdateAsync(s => s.SetProperty(n => n.IsRead, true), ct);
}

public record NotificationDto(Guid Id, NotificationType Type, string Title, string Body, Guid? ReferenceId, bool IsRead, DateTime CreatedAt);
