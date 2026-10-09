using Microsoft.EntityFrameworkCore;
using Miga.Domain;
using Miga.Domain.Common;
using Miga.Infrastructure.Common;
using Miga.Infrastructure.Notifications;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Features.MerchantSales;

public record MerchantOrderSummaryDto(
    Guid Id, string Number, MerchantOrderStatus Status, DateTime CreatedAt, Guid CampaignId, string CampaignTitle, string ProductName, string? ImageUrl,
    Guid StoreId, string StoreName, int TotalQuantity, int CustomersCount, decimal TotalAmount);

public record DistrictBatchDto(string District, int Quantity, int Customers);

public record MerchantDeliveryDto(Guid Id, string Number, DeliveryStatus Status, string District, int Quantity, string? DriverName);

public record MerchantOrderDetailDto(
    MerchantOrderSummaryDto Order, decimal PlatformFee, decimal NetAmount, string PickupCode,
    DateTime? ConfirmedAt, DateTime? ReadyAt, DateTime? CompletedAt,
    IReadOnlyList<DistrictBatchDto> Districts, IReadOnlyList<MerchantDeliveryDto> Deliveries);

public enum MerchantOrderTab
{
    New,
    Preparing,
    Ready,
    Done,
}

/// <summary>Aggregated orders: SentToMerchant → Confirmed → Preparing → Ready (drivers notified) → Completed (handed over, step 6).</summary>
public class MerchantOrderService(MigaDbContext db, Notifier notifier, TimeProvider clock)
{
    public Task<PagedResult<MerchantOrderSummaryDto>> ListAsync(Guid userId, MerchantOrderTab tab, int page, int pageSize, CancellationToken ct)
    {
        var q = Owned(userId);
        q = tab switch
        {
            MerchantOrderTab.New => q.Where(o => o.Status == MerchantOrderStatus.Pending || o.Status == MerchantOrderStatus.SentToMerchant || o.Status == MerchantOrderStatus.Confirmed),
            MerchantOrderTab.Preparing => q.Where(o => o.Status == MerchantOrderStatus.Preparing),
            MerchantOrderTab.Ready => q.Where(o => o.Status == MerchantOrderStatus.Ready),
            _ => q.Where(o => o.Status == MerchantOrderStatus.Completed || o.Status == MerchantOrderStatus.Cancelled),
        };
        return Project(q.OrderByDescending(o => o.CreatedAt)).ToPagedAsync(page, pageSize, ct);
    }

    public async Task<MerchantOrderDetailDto> GetAsync(Guid userId, Guid id, CancellationToken ct)
    {
        var summary = await Project(Owned(userId).Where(o => o.Id == id)).FirstOrDefaultAsync(ct) ?? throw NotFound();
        var extra = await db.MerchantOrders.AsNoTracking().Where(o => o.Id == id)
            .Select(o => new { o.PlatformFee, o.PickupCode, o.ConfirmedAt, o.ReadyAt, o.CompletedAt }).FirstAsync(ct);

        var deliveries = await db.Deliveries.AsNoTracking().Where(d => d.MerchantOrderId == id)
            .OrderBy(d => d.DeliveryAddress.District.NameAr)
            .Select(d => new MerchantDeliveryDto(d.Id, d.Number, d.Status, d.DeliveryAddress.District.NameAr, d.CampaignOrder.Quantity,
                d.DriverUser != null ? d.DriverUser.FullName : null))
            .ToListAsync(ct);

        // Preparation batches: quantities per district, largest first.
        var districts = deliveries.GroupBy(d => d.District)
            .Select(g => new DistrictBatchDto(g.Key, g.Sum(d => d.Quantity), g.Count()))
            .OrderByDescending(b => b.Quantity).ToList();

        return new MerchantOrderDetailDto(summary, extra.PlatformFee, summary.TotalAmount - extra.PlatformFee, extra.PickupCode,
            extra.ConfirmedAt, extra.ReadyAt, extra.CompletedAt, districts, deliveries);
    }

    public Task<MerchantOrderDetailDto> ConfirmAsync(Guid userId, Guid id, CancellationToken ct) =>
        AdvanceAsync(userId, id, [MerchantOrderStatus.Pending, MerchantOrderStatus.SentToMerchant], MerchantOrderStatus.Confirmed, ct);

    public Task<MerchantOrderDetailDto> StartPreparingAsync(Guid userId, Guid id, CancellationToken ct) =>
        AdvanceAsync(userId, id, [MerchantOrderStatus.Confirmed], MerchantOrderStatus.Preparing, ct);

    public Task<MerchantOrderDetailDto> MarkReadyAsync(Guid userId, Guid id, CancellationToken ct) =>
        AdvanceAsync(userId, id, [MerchantOrderStatus.Preparing], MerchantOrderStatus.Ready, ct);

    private async Task<MerchantOrderDetailDto> AdvanceAsync(Guid userId, Guid id, MerchantOrderStatus[] from, MerchantOrderStatus to, CancellationToken ct)
    {
        var order = await Owned(userId).Include(o => o.Campaign).Include(o => o.Store).FirstOrDefaultAsync(o => o.Id == id, ct) ?? throw NotFound();
        if (!from.Contains(order.Status)) throw AppException.Conflict("invalid_order_transition", "لا يمكن تنفيذ هذا الإجراء في حالة الطلب الحالية");

        var now = clock.GetUtcNow().UtcDateTime;
        order.Status = to;
        var customerStatus = to switch
        {
            MerchantOrderStatus.Preparing => CampaignOrderStatus.Preparing,
            MerchantOrderStatus.Ready => CampaignOrderStatus.ReadyForDelivery,
            _ => (CampaignOrderStatus?)null,
        };
        if (to == MerchantOrderStatus.Confirmed) order.ConfirmedAt = now;
        if (to == MerchantOrderStatus.Ready) order.ReadyAt = now;

        if (customerStatus is { } cs)
        {
            var customerOrders = await db.CampaignOrders.Where(o => o.Delivery!.MerchantOrderId == id).ToListAsync(ct);
            foreach (var co in customerOrders)
            {
                co.Status = cs;
                if (cs == CampaignOrderStatus.Preparing)
                    notifier.Notify(co.CustomerId, NotificationType.OrderStatus, "يجهّز التاجر طلبك", $"بدأ التاجر تجهيز طلبك {co.Number}.", co.Id);
            }
        }

        if (to == MerchantOrderStatus.Ready)
        {
            // Offer the deliveries to verified, available drivers in the store's city.
            var drivers = await db.DriverProfiles.Where(d => d.IsVerified && d.IsAvailable && (order.Store.CityId == null || d.CityId == order.Store.CityId))
                .Select(d => d.UserId).ToListAsync(ct);
            foreach (var driverId in drivers)
            {
                notifier.Notify(driverId, NotificationType.DeliveryRequest, "طلبات توصيل جديدة",
                    $"{order.CustomersCount} توصيلة جاهزة للاستلام من {order.Store.NameAr}.", order.Id);
            }
        }

        await db.SaveChangesAsync(ct);
        return await GetAsync(userId, id, ct);
    }

    private IQueryable<Domain.Entities.MerchantOrder> Owned(Guid userId) => db.MerchantOrders.Where(o => o.Store.Merchant.UserId == userId);

    private static IQueryable<MerchantOrderSummaryDto> Project(IQueryable<Domain.Entities.MerchantOrder> q) => q.Select(o => new MerchantOrderSummaryDto(
        o.Id, o.Number, o.Status, o.CreatedAt, o.CampaignId, o.Campaign.TitleAr, o.Campaign.Product.NameAr,
        o.Campaign.Product.Images.OrderBy(i => i.SortOrder).Select(i => i.ImageUrl).FirstOrDefault(),
        o.StoreId, o.Store.NameAr, o.TotalQuantity, o.CustomersCount, o.TotalAmount));

    private static AppException NotFound() => AppException.NotFound("merchant_order_not_found", "الطلب غير موجود");
}
