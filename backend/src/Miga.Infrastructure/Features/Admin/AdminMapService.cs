using Microsoft.EntityFrameworkCore;
using Miga.Domain;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Features.Admin;

/// <summary>A map position. <c>Approximate</c> = placed at the district / city centre because no exact location is known.</summary>
public record MapPointDto(double Lat, double Lng, bool Approximate);

public record MapCityDto(Guid Id, string Name, double Lat, double Lng, int Deliveries, int DriversOnline);

public record MapDriverDto(
    Guid UserId, string Name, string Phone, string? City, string? VehicleType, bool IsAvailable, int ActiveDeliveries,
    MapPointDto Position, DateTime? LocationAt);

public record MapStoreDto(Guid Id, string Name, string? City, string? PickupAddress, int ActiveDeliveries, MapPointDto Position);

public record MapDeliveryDto(
    Guid Id, string Number, DeliveryStatus Status, string CustomerName, string CustomerPhone, string District, string City, string ProductName,
    int Quantity, Guid StoreId, string StoreName, Guid? DriverUserId, string? DriverName, string? FailureReason, DateTime CreatedAt,
    DateTime? AcceptedAt, MapPointDto Destination);

public record AdminMapDto(
    IReadOnlyList<MapCityDto> Cities, IReadOnlyList<MapDriverDto> Drivers, IReadOnlyList<MapStoreDto> Stores,
    IReadOnlyList<MapDeliveryDto> Deliveries, DateTime GeneratedAt);

/// <summary>
/// Live operations map: open deliveries (customer destination), the stores they come from and the drivers on duty.
/// Exact points come from the customer's saved GPS and the driver app's last reported location; everything else is
/// placed near its district or city centre and flagged as approximate.
/// </summary>
public class AdminMapService(MigaDbContext db, TimeProvider clock)
{
    /// <summary>Driver positions older than this are treated as unknown.</summary>
    public static readonly TimeSpan LocationFreshFor = TimeSpan.FromMinutes(30);

    private static readonly List<DeliveryStatus> Open =
        [DeliveryStatus.Pending, DeliveryStatus.Assigned, DeliveryStatus.DriverAccepted, DeliveryStatus.PickedUp, DeliveryStatus.OutForDelivery, DeliveryStatus.Failed];
    private static readonly List<DeliveryStatus> WithDriver = [DeliveryStatus.DriverAccepted, DeliveryStatus.PickedUp, DeliveryStatus.OutForDelivery];

    public async Task<AdminMapDto> MapAsync(Guid? cityId, CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;

        var cities = await db.Cities.AsNoTracking().Where(c => c.Latitude != null)
            .Select(c => new { c.Id, c.NameAr, Lat = (double)c.Latitude!.Value, Lng = (double)c.Longitude!.Value }).ToListAsync(ct);
        var cityById = cities.ToDictionary(c => c.Id);
        var districts = await db.Districts.AsNoTracking().Where(d => d.Latitude != null)
            .Select(d => new { d.Id, Lat = (double)d.Latitude!.Value, Lng = (double)d.Longitude!.Value }).ToDictionaryAsync(d => d.Id, ct);

        MapPointDto Near(Guid? city, Guid seed, double spread = 0.018)
        {
            if (city is { } id && cityById.TryGetValue(id, out var c))
            {
                var (dx, dy) = Jitter(seed);
                return new MapPointDto(c.Lat + dy * spread, c.Lng + dx * spread, true);
            }
            return new MapPointDto(24.7136, 46.6753, true); // no city: Riyadh centre
        }

        // ---- deliveries
        var deliveryRows = await db.Deliveries.AsNoTracking()
            .Where(d => Open.Contains(d.Status) && d.MerchantOrder.Status != MerchantOrderStatus.Cancelled)
            .Where(d => cityId == null || d.DeliveryAddress.CityId == cityId)
            .OrderBy(d => d.CreatedAt)
            .Select(d => new
            {
                d.Id, d.Number, d.Status, Customer = d.CampaignOrder.Customer.FullName, Phone = d.CampaignOrder.Customer.PhoneNumber ?? "",
                District = d.DeliveryAddress.District.NameAr, City = d.DeliveryAddress.City.NameAr, d.DeliveryAddress.CityId, d.DeliveryAddress.DistrictId,
                d.DeliveryAddress.Latitude, d.DeliveryAddress.Longitude, Product = d.CampaignOrder.Campaign.Product.NameAr, d.CampaignOrder.Quantity,
                StoreId = d.MerchantOrder.StoreId, Store = d.MerchantOrder.Store.NameAr, d.DriverUserId,
                Driver = d.DriverUser != null ? d.DriverUser.FullName : null, d.FailureReason, d.CreatedAt, d.AcceptedAt,
            })
            .ToListAsync(ct);

        var deliveries = deliveryRows.Select(d =>
        {
            var dest = d.Latitude is { } lat && d.Longitude is { } lng
                ? new MapPointDto((double)lat, (double)lng, false)
                : districts.TryGetValue(d.DistrictId, out var dc)
                    ? Offset(new MapPointDto(dc.Lat, dc.Lng, true), d.Id, 0.004)
                    : Near(d.CityId, d.Id);
            return new MapDeliveryDto(d.Id, d.Number, d.Status, d.Customer, d.Phone, d.District, d.City, d.Product, d.Quantity, d.StoreId, d.Store,
                d.DriverUserId, d.Driver, d.FailureReason, d.CreatedAt, d.AcceptedAt, dest);
        }).ToList();

        // ---- stores: active ones in scope, plus any that an open delivery comes from
        var storeIds = deliveries.Select(d => d.StoreId).Distinct().ToList();
        var storeRows = await db.Stores.AsNoTracking()
            .Where(s => (s.Status == StoreStatus.Active && s.IsVerified && (cityId == null || s.CityId == cityId)) || storeIds.Contains(s.Id))
            .Select(s => new { s.Id, s.NameAr, s.CityId, City = s.City != null ? s.City.NameAr : null, s.PickupAddress })
            .ToListAsync(ct);
        var stores = storeRows.Select(s => new MapStoreDto(
            s.Id, s.NameAr, s.City, s.PickupAddress, deliveries.Count(d => d.StoreId == s.Id), Near(s.CityId, s.Id, 0.03))).ToList();

        // ---- drivers on duty: online, or carrying an open delivery
        var busy = deliveries.Where(d => d.DriverUserId != null && WithDriver.Contains(d.Status)).GroupBy(d => d.DriverUserId!.Value)
            .ToDictionary(g => g.Key, g => g.Count());
        var busyIds = busy.Keys.ToList();
        var driverRows = await db.DriverProfiles.AsNoTracking()
            .Where(p => p.IsVerified && p.User.IsActive && (p.IsAvailable || busyIds.Contains(p.UserId)))
            .Where(p => cityId == null || p.CityId == cityId || busyIds.Contains(p.UserId))
            .Select(p => new
            {
                p.UserId, p.User.FullName, Phone = p.User.PhoneNumber ?? "", City = p.City != null ? p.City.NameAr : null, p.CityId, p.VehicleType,
                p.IsAvailable, p.LastLatitude, p.LastLongitude, p.LastLocationAt,
            })
            .ToListAsync(ct);
        var drivers = driverRows.Select(p =>
        {
            var fresh = p.LastLatitude != null && p.LastLocationAt >= now - LocationFreshFor;
            var pos = fresh ? new MapPointDto((double)p.LastLatitude!.Value, (double)p.LastLongitude!.Value, false) : Near(p.CityId, p.UserId, 0.025);
            return new MapDriverDto(p.UserId, p.FullName, p.Phone, p.City, p.VehicleType, p.IsAvailable, busy.GetValueOrDefault(p.UserId), pos,
                fresh ? p.LastLocationAt : null);
        }).ToList();

        // ---- cities with activity (for the city switcher)
        var cityStats = cities
            .Select(c => new MapCityDto(c.Id, c.NameAr, c.Lat, c.Lng,
                deliveryRows.Count(d => d.CityId == c.Id), driverRows.Count(p => p.CityId == c.Id && p.IsAvailable)))
            .Where(c => c.Deliveries > 0 || c.DriversOnline > 0 || c.Id == cityId)
            .OrderByDescending(c => c.Deliveries).ThenByDescending(c => c.DriversOnline)
            .ToList();

        return new AdminMapDto(cityStats, drivers, stores, deliveries, now);
    }

    private static MapPointDto Offset(MapPointDto p, Guid seed, double spread)
    {
        var (dx, dy) = Jitter(seed);
        return p with { Lat = p.Lat + dy * spread, Lng = p.Lng + dx * spread };
    }

    /// <summary>Stable pseudo-random offset in [-1, 1]² so approximate markers don't stack and don't move between refreshes.</summary>
    private static (double X, double Y) Jitter(Guid seed)
    {
        // Ids are sequential (time-based), so hash them first; MD5 is just a stable mixer here.
        var b = System.Security.Cryptography.MD5.HashData(seed.ToByteArray());
        return (BitConverter.ToUInt16(b, 0) / 32767.5 - 1, BitConverter.ToUInt16(b, 2) / 32767.5 - 1);
    }
}
