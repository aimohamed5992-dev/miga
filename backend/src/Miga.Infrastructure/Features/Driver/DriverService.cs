using Microsoft.EntityFrameworkCore;
using Miga.Domain;
using Miga.Domain.Common;
using Miga.Domain.Entities;
using Miga.Infrastructure.Notifications;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Features.Driver;

public record DeliveryRequestDto(
    Guid Id, string Number, decimal Fee, decimal? DistanceKm, string StoreName, string? PickupAddress,
    string District, string City, string ProductName, string? ImageUrl, int Quantity, DateTime ReadySince);

public record DriverDeliveryDto(
    Guid Id, string Number, DeliveryStatus Status, decimal Fee, decimal? DistanceKm,
    string StoreName, string? PickupAddress, string? StorePhone,
    string CustomerName, string CustomerPhone, string AddressName, string District, string City, string Region, string? AddressDetails,
    decimal? Latitude, decimal? Longitude, string ProductName, string? ImageUrl, int Quantity,
    DateTime? AcceptedAt, DateTime? PickedUpAt, DateTime? OutForDeliveryAt, DateTime? DeliveredAt, string? FailureReason);

public record DriverVehicleDto(string? Type, string? Model, string? PlateNumber);

public record DriverHomeDto(
    bool IsVerified, bool IsAvailable, decimal TodayEarnings, int TodayDeliveries, decimal TodayDistanceKm, int RequestsCount, DriverDeliveryDto? ActiveDelivery,
    decimal Rating, string? CityName, DriverVehicleDto Vehicle);

public record EarningsBucketDto(string Label, decimal Amount);

public record DriverEarningsDto(decimal Total, int Deliveries, decimal DistanceKm, decimal Rating, decimal LifetimeEarnings, IReadOnlyList<EarningsBucketDto> Buckets, IReadOnlyList<DriverDeliveryDto> Recent);

public enum EarningsPeriod
{
    Week,
    Month,
}

/// <summary>
/// Driver flow per customer delivery: claim (Pending → DriverAccepted) → pickup with the merchant's code (PickedUp)
/// → start (OutForDelivery) → deliver with the customer's code (Delivered) or fail with a reason.
/// Requests are matched by city; claiming is atomic so two drivers can never take the same delivery.
/// </summary>
public class DriverService(MigaDbContext db, Notifier notifier, TimeProvider clock)
{
    public const int MaxActiveDeliveries = 10;

    private static readonly List<DeliveryStatus> InProgress = [DeliveryStatus.DriverAccepted, DeliveryStatus.PickedUp, DeliveryStatus.OutForDelivery];
    private static readonly List<DeliveryStatus> Finished = [DeliveryStatus.Delivered, DeliveryStatus.Failed];

    private DateTime Now => clock.GetUtcNow().UtcDateTime;

    public async Task<DriverHomeDto> HomeAsync(Guid userId, CancellationToken ct)
    {
        var profile = await ProfileAsync(userId, ct);
        var dayStart = Now.Date;
        var today = await db.Deliveries.AsNoTracking()
            .Where(d => d.DriverUserId == userId && d.Status == DeliveryStatus.Delivered && d.DeliveredAt >= dayStart)
            .Select(d => new { d.Fee, d.DistanceKm }).ToListAsync(ct);
        var active = await Project(Mine(userId).Where(d => InProgress.Contains(d.Status)).OrderBy(d => d.AcceptedAt)).FirstOrDefaultAsync(ct);
        var requests = profile.IsVerified ? await RequestsQuery(profile).CountAsync(ct) : 0;
        var city = profile.CityId == null ? null : await db.Cities.Where(c => c.Id == profile.CityId).Select(c => c.NameAr).FirstOrDefaultAsync(ct);
        return new DriverHomeDto(profile.IsVerified, profile.IsAvailable, today.Sum(d => d.Fee), today.Count, today.Sum(d => d.DistanceKm ?? 0), requests, active,
            profile.Rating, city, new DriverVehicleDto(profile.VehicleType, profile.VehicleModel, profile.VehiclePlateNumber));
    }

    /// <summary>
    /// Driver edits work city / vehicle. Moving city with deliveries in progress would strand them, so it's refused;
    /// requests are matched by city, so the new one applies to the very next refresh.
    /// </summary>
    public async Task<DriverHomeDto> UpdateProfileAsync(Guid userId, Guid? cityId, string? vehicleType, string? vehicleModel, string? plateNumber, CancellationToken ct)
    {
        var profile = await ProfileAsync(userId, ct);
        if (cityId is { } c && c != profile.CityId)
        {
            if (!await db.Cities.AnyAsync(x => x.Id == c && x.IsActive, ct)) throw AppException.BadRequest("invalid_city", "المدينة غير صحيحة");
            if (await db.Deliveries.AnyAsync(d => d.DriverUserId == userId && InProgress.Contains(d.Status), ct))
                throw AppException.Conflict("deliveries_in_progress", "أكمل توصيلاتك الجارية قبل تغيير مدينة العمل");
            profile.CityId = c;
        }
        if (!string.IsNullOrWhiteSpace(vehicleType)) profile.VehicleType = vehicleType.Trim();
        if (vehicleModel != null) profile.VehicleModel = string.IsNullOrWhiteSpace(vehicleModel) ? null : vehicleModel.Trim();
        if (!string.IsNullOrWhiteSpace(plateNumber)) profile.VehiclePlateNumber = plateNumber.Trim();
        await db.SaveChangesAsync(ct);
        return await HomeAsync(userId, ct);
    }

    public async Task SetAvailabilityAsync(Guid userId, bool available, CancellationToken ct)
    {
        var profile = await VerifiedAsync(userId, ct);
        profile.IsAvailable = available;
        await db.SaveChangesAsync(ct);
    }

    public async Task ReportLocationAsync(Guid userId, decimal latitude, decimal longitude, CancellationToken ct)
    {
        var profile = await VerifiedAsync(userId, ct);
        profile.LastLatitude = Math.Round(latitude, 7);
        profile.LastLongitude = Math.Round(longitude, 7);
        profile.LastLocationAt = Now;
        await db.SaveChangesAsync(ct);
    }

    /// <summary>Unclaimed deliveries of Ready aggregated orders in the driver's city. Customer identity stays hidden until accepted.</summary>
    public async Task<List<DeliveryRequestDto>> RequestsAsync(Guid userId, CancellationToken ct)
    {
        var profile = await VerifiedAsync(userId, ct);
        if (!profile.IsAvailable) return [];
        return await RequestsQuery(profile).OrderBy(d => d.MerchantOrder.ReadyAt).Select(d => new DeliveryRequestDto(
            d.Id, d.Number, d.Fee, d.DistanceKm, d.MerchantOrder.Store.NameAr, d.MerchantOrder.Store.PickupAddress,
            d.DeliveryAddress.District.NameAr, d.DeliveryAddress.City.NameAr,
            d.CampaignOrder.Campaign.Product.NameAr, d.CampaignOrder.Campaign.Product.Images.OrderBy(i => i.SortOrder).Select(i => i.ImageUrl).FirstOrDefault(),
            d.CampaignOrder.Quantity, d.MerchantOrder.ReadyAt ?? d.CreatedAt)).ToListAsync(ct);
    }

    public Task<List<DriverDeliveryDto>> DeliveriesAsync(Guid userId, bool history, CancellationToken ct) =>
        Project(Mine(userId).Where(d => history ? Finished.Contains(d.Status) : InProgress.Contains(d.Status))
            .OrderByDescending(d => d.AcceptedAt)).Take(100).ToListAsync(ct);

    public async Task<DriverDeliveryDto> GetAsync(Guid userId, Guid id, CancellationToken ct) =>
        await Project(Mine(userId).Where(d => d.Id == id)).FirstOrDefaultAsync(ct) ?? throw NotFound();

    /// <summary>Atomic claim: a single conditional UPDATE, so concurrent drivers can't both win.</summary>
    public async Task<DriverDeliveryDto> AcceptAsync(Guid userId, Guid id, CancellationToken ct)
    {
        var profile = await VerifiedAsync(userId, ct);
        if (!profile.IsAvailable) throw AppException.BadRequest("driver_unavailable", "فعّل حالتك (متصل) لقبول الطلبات");
        if (await db.Deliveries.CountAsync(d => d.DriverUserId == userId && InProgress.Contains(d.Status), ct) >= MaxActiveDeliveries)
            throw AppException.BadRequest("too_many_active", $"لديك {MaxActiveDeliveries} توصيلات جارية، أكملها أولًا");
        if (!await RequestsQuery(profile).AnyAsync(d => d.Id == id, ct))
            throw AppException.Conflict("delivery_unavailable", "الطلب لم يعد متاحًا");

        var now = Now;
        var claimed = await db.Deliveries
            .Where(d => d.Id == id && d.DriverUserId == null && d.Status == DeliveryStatus.Pending)
            .ExecuteUpdateAsync(s => s
                .SetProperty(d => d.DriverUserId, userId)
                .SetProperty(d => d.Status, DeliveryStatus.DriverAccepted)
                .SetProperty(d => d.AssignedAt, now)
                .SetProperty(d => d.AcceptedAt, now), ct);
        if (claimed == 0) throw AppException.Conflict("delivery_taken", "قبل مندوب آخر هذا الطلب");
        return await GetAsync(userId, id, ct);
    }

    /// <summary>Give an accepted delivery back before pickup (it returns to the request pool).</summary>
    public async Task ReleaseAsync(Guid userId, Guid id, CancellationToken ct)
    {
        var d = await MineTrackedAsync(userId, id, ct);
        if (d.Status != DeliveryStatus.DriverAccepted) throw AppException.Conflict("invalid_delivery_transition", "لا يمكن الاعتذار بعد استلام الطلب");
        d.DriverUserId = null;
        d.Status = DeliveryStatus.Pending;
        d.AssignedAt = d.AcceptedAt = null;
        await db.SaveChangesAsync(ct);
    }

    /// <summary>At the warehouse: the merchant shows the pickup code, the driver enters it.</summary>
    public async Task<DriverDeliveryDto> PickUpAsync(Guid userId, Guid id, string pickupCode, CancellationToken ct)
    {
        var d = await db.Deliveries.Include(x => x.MerchantOrder).ThenInclude(m => m.Store).ThenInclude(s => s.Merchant)
            .FirstOrDefaultAsync(x => x.Id == id && x.DriverUserId == userId, ct) ?? throw NotFound();
        Require(d, DeliveryStatus.DriverAccepted);
        if (d.MerchantOrder.Status != MerchantOrderStatus.Ready && d.MerchantOrder.Status != MerchantOrderStatus.Completed)
            throw AppException.Conflict("order_not_ready", "الطلب لم يجهز بعد لدى التاجر");
        if (!string.Equals(d.MerchantOrder.PickupCode, pickupCode?.Trim(), StringComparison.Ordinal))
            throw AppException.BadRequest("invalid_pickup_code", "رمز الاستلام غير صحيح");

        d.Status = DeliveryStatus.PickedUp;
        d.PickedUpAt = Now;
        await db.SaveChangesAsync(ct);

        // When every delivery has left the warehouse, the merchant's part is done.
        var waiting = await db.Deliveries.AnyAsync(x => x.MerchantOrderId == d.MerchantOrderId
            && (x.Status == DeliveryStatus.Pending || x.Status == DeliveryStatus.Assigned || x.Status == DeliveryStatus.DriverAccepted), ct);
        if (!waiting && d.MerchantOrder.Status != MerchantOrderStatus.Completed)
        {
            d.MerchantOrder.Status = MerchantOrderStatus.Completed;
            d.MerchantOrder.CompletedAt = Now;
            notifier.Notify(d.MerchantOrder.Store.Merchant.UserId, NotificationType.OrderStatus, "تم تسليم الطلب للمندوبين",
                $"استلم المندوبون كامل الطلب {d.MerchantOrder.Number}.", d.MerchantOrderId);
            await db.SaveChangesAsync(ct);
        }
        return await GetAsync(userId, id, ct);
    }

    public async Task<DriverDeliveryDto> StartAsync(Guid userId, Guid id, CancellationToken ct)
    {
        var d = await db.Deliveries.Include(x => x.CampaignOrder).Include(x => x.DriverUser).FirstOrDefaultAsync(x => x.Id == id && x.DriverUserId == userId, ct) ?? throw NotFound();
        Require(d, DeliveryStatus.PickedUp);
        d.Status = DeliveryStatus.OutForDelivery;
        d.OutForDeliveryAt = Now;
        d.CampaignOrder.Status = CampaignOrderStatus.OutForDelivery;
        notifier.Notify(d.CampaignOrder.CustomerId, NotificationType.OrderStatus, "طلبك في الطريق 🚚",
            $"المندوب {d.DriverUser!.FullName} في طريقه إليك بالطلب {d.CampaignOrder.Number}. رمز التسليم: {d.DeliveryCode}", d.CampaignOrderId);
        await db.SaveChangesAsync(ct);
        return await GetAsync(userId, id, ct);
    }

    /// <summary>Hand-over: the customer gives the 4-digit delivery code (shown in their order screen).</summary>
    public async Task<DriverDeliveryDto> DeliverAsync(Guid userId, Guid id, string deliveryCode, string? proofImageUrl, CancellationToken ct)
    {
        var d = await db.Deliveries.Include(x => x.CampaignOrder).FirstOrDefaultAsync(x => x.Id == id && x.DriverUserId == userId, ct) ?? throw NotFound();
        Require(d, DeliveryStatus.OutForDelivery);
        if (!string.Equals(d.DeliveryCode, deliveryCode?.Trim(), StringComparison.Ordinal))
            throw AppException.BadRequest("invalid_delivery_code", "رمز التسليم غير صحيح، اطلبه من العميل");

        var now = Now;
        d.Status = DeliveryStatus.Delivered;
        d.DeliveredAt = now;
        d.ProofImageUrl = proofImageUrl;
        d.CampaignOrder.Status = CampaignOrderStatus.Delivered;
        d.CampaignOrder.DeliveredAt = now;
        notifier.Notify(d.CampaignOrder.CustomerId, NotificationType.OrderStatus, "تم التسليم ✅", $"تم تسليم طلبك {d.CampaignOrder.Number}. شكرًا لاختيارك ميجا!", d.CampaignOrderId);
        await db.SaveChangesAsync(ct);
        return await GetAsync(userId, id, ct);
    }

    public async Task<DriverDeliveryDto> FailAsync(Guid userId, Guid id, string reason, CancellationToken ct)
    {
        var d = await db.Deliveries.Include(x => x.CampaignOrder).Include(x => x.MerchantOrder).ThenInclude(m => m.Store).ThenInclude(s => s.Merchant)
            .FirstOrDefaultAsync(x => x.Id == id && x.DriverUserId == userId, ct) ?? throw NotFound();
        if (d.Status is not (DeliveryStatus.PickedUp or DeliveryStatus.OutForDelivery))
            throw AppException.Conflict("invalid_delivery_transition", "لا يمكن تسجيل تعذّر التسليم في هذه الحالة");

        d.Status = DeliveryStatus.Failed;
        d.FailureReason = reason.Trim();
        // The customer's order waits for MIGA support to reschedule; money stays held, nothing is refunded automatically.
        d.CampaignOrder.Status = CampaignOrderStatus.ReadyForDelivery;
        notifier.Notify(d.CampaignOrder.CustomerId, NotificationType.OrderStatus, "تعذّر تسليم طلبك",
            $"لم يتمكن المندوب من تسليم الطلب {d.CampaignOrder.Number} ({d.FailureReason}). سيتواصل معك الدعم لإعادة الجدولة.", d.CampaignOrderId);
        notifier.Notify(d.MerchantOrder.Store.Merchant.UserId, NotificationType.OrderStatus, "تعذّر تسليم توصيلة",
            $"التوصيلة {d.Number} لم تُسلَّم: {d.FailureReason}.", d.MerchantOrderId);
        await db.SaveChangesAsync(ct);
        return await GetAsync(userId, id, ct);
    }

    public async Task<DriverEarningsDto> EarningsAsync(Guid userId, EarningsPeriod period, CancellationToken ct)
    {
        var profile = await ProfileAsync(userId, ct);
        var today = Now.Date;
        var from = period == EarningsPeriod.Week ? today.AddDays(-6) : today.AddDays(-27);

        var delivered = await db.Deliveries.AsNoTracking()
            .Where(d => d.DriverUserId == userId && d.Status == DeliveryStatus.Delivered)
            .Select(d => new { d.Fee, d.DistanceKm, d.DeliveredAt }).ToListAsync(ct);
        var inPeriod = delivered.Where(d => d.DeliveredAt >= from).ToList();

        string[] dayNames = ["أحد", "إثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة", "سبت"];
        var buckets = period == EarningsPeriod.Week
            ? Enumerable.Range(0, 7).Select(i => from.AddDays(i))
                .Select(day => new EarningsBucketDto(dayNames[(int)day.DayOfWeek], inPeriod.Where(d => d.DeliveredAt!.Value.Date == day).Sum(d => d.Fee))).ToList()
            : Enumerable.Range(0, 4).Select(i => (Start: from.AddDays(i * 7), Label: $"الأسبوع {i + 1}"))
                .Select(w => new EarningsBucketDto(w.Label, inPeriod.Where(d => d.DeliveredAt >= w.Start && d.DeliveredAt < w.Start.AddDays(7)).Sum(d => d.Fee))).ToList();

        var recent = await Project(Mine(userId).Where(d => d.Status == DeliveryStatus.Delivered).OrderByDescending(d => d.DeliveredAt)).Take(10).ToListAsync(ct);
        return new DriverEarningsDto(inPeriod.Sum(d => d.Fee), inPeriod.Count, inPeriod.Sum(d => d.DistanceKm ?? 0), profile.Rating, delivered.Sum(d => d.Fee), buckets, recent);
    }

    // ---------------- helpers ----------------

    private IQueryable<Delivery> RequestsQuery(DriverProfile p) => db.Deliveries.Where(d =>
        d.DriverUserId == null && d.Status == DeliveryStatus.Pending && d.MerchantOrder.Status == MerchantOrderStatus.Ready
        && (d.MerchantOrder.Store.CityId == null || d.MerchantOrder.Store.CityId == p.CityId));

    private IQueryable<Delivery> Mine(Guid userId) => db.Deliveries.Where(d => d.DriverUserId == userId);

    private async Task<Delivery> MineTrackedAsync(Guid userId, Guid id, CancellationToken ct) =>
        await db.Deliveries.FirstOrDefaultAsync(d => d.Id == id && d.DriverUserId == userId, ct) ?? throw NotFound();

    private async Task<DriverProfile> ProfileAsync(Guid userId, CancellationToken ct) =>
        await db.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == userId, ct)
        ?? throw AppException.BadRequest("driver_not_registered", "أكمل تسجيل بياناتك أولًا");

    private async Task<DriverProfile> VerifiedAsync(Guid userId, CancellationToken ct)
    {
        var p = await ProfileAsync(userId, ct);
        if (!p.IsVerified) throw AppException.Forbidden("driver_not_verified", "حسابك قيد المراجعة، سنبلغك فور التفعيل");
        return p;
    }

    private static void Require(Delivery d, DeliveryStatus expected)
    {
        if (d.Status != expected) throw AppException.Conflict("invalid_delivery_transition", "لا يمكن تنفيذ هذا الإجراء في حالة التوصيلة الحالية");
    }

    /// <summary>Full details — only ever used for the driver's own (claimed) deliveries.</summary>
    private static IQueryable<DriverDeliveryDto> Project(IQueryable<Delivery> q) => q.Select(d => new DriverDeliveryDto(
        d.Id, d.Number, d.Status, d.Fee, d.DistanceKm,
        d.MerchantOrder.Store.NameAr, d.MerchantOrder.Store.PickupAddress, d.MerchantOrder.Store.Merchant.User.PhoneNumber,
        d.CampaignOrder.Customer.FullName, d.DeliveryAddress.PhoneNumber, d.DeliveryAddress.AddressName,
        d.DeliveryAddress.District.NameAr, d.DeliveryAddress.City.NameAr, d.DeliveryAddress.Region.NameAr, d.DeliveryAddress.AddressDetails,
        d.DeliveryAddress.Latitude, d.DeliveryAddress.Longitude,
        d.CampaignOrder.Campaign.Product.NameAr, d.CampaignOrder.Campaign.Product.Images.OrderBy(i => i.SortOrder).Select(i => i.ImageUrl).FirstOrDefault(),
        d.CampaignOrder.Quantity, d.AcceptedAt, d.PickedUpAt, d.OutForDeliveryAt, d.DeliveredAt, d.FailureReason));

    private static AppException NotFound() => AppException.NotFound("delivery_not_found", "التوصيلة غير موجودة");
}
