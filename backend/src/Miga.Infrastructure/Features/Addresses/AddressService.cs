using Microsoft.EntityFrameworkCore;
using Miga.Domain.Common;
using Miga.Domain.Entities;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Features.Addresses;

public record AddressInput(
    string AddressName,
    Guid RegionId,
    Guid CityId,
    Guid DistrictId,
    string PhoneNumber,
    string? AddressDetails,
    string? BuildingNumber,
    string? StreetName,
    decimal? Latitude,
    decimal? Longitude,
    bool IsDefault);

public record AddressDto(
    Guid Id,
    string AddressName,
    Guid RegionId,
    string RegionName,
    Guid CityId,
    string CityName,
    Guid DistrictId,
    string DistrictName,
    string PhoneNumber,
    string? AddressDetails,
    string? BuildingNumber,
    string? StreetName,
    decimal? Latitude,
    decimal? Longitude,
    bool IsDefault)
{
    /// <summary>"النرجس، الرياض، منطقة الرياض" — same summary line the apps show.</summary>
    public string Summary => $"{DistrictName}، {CityName}، {RegionName}";
}

/// <summary>Customer addresses: Region → City → District + name + phone. Soft-deleted to keep old orders intact.</summary>
public class AddressService(MigaDbContext db)
{
    public const int MaxAddresses = 20;

    public Task<List<AddressDto>> ListAsync(Guid userId, CancellationToken ct) =>
        // Order on the entity before projecting: EF can't translate ordering on constructor-built DTOs.
        Project(db.Addresses.Where(a => a.UserId == userId && !a.IsDeleted).OrderByDescending(a => a.IsDefault).ThenBy(a => a.AddressName))
            .ToListAsync(ct);

    public async Task<AddressDto> GetAsync(Guid userId, Guid id, CancellationToken ct) =>
        await Project(db.Addresses.Where(a => a.Id == id && a.UserId == userId && !a.IsDeleted)).FirstOrDefaultAsync(ct)
        ?? throw AppException.NotFound("address_not_found", "العنوان غير موجود");

    public async Task<AddressDto> CreateAsync(Guid userId, AddressInput input, CancellationToken ct)
    {
        var count = await db.Addresses.CountAsync(a => a.UserId == userId && !a.IsDeleted, ct);
        if (count >= MaxAddresses) throw AppException.BadRequest("too_many_addresses", $"الحد الأقصى {MaxAddresses} عنوانًا");

        var address = new Address { UserId = userId };
        await ApplyAsync(address, input, ct);
        // The first address is always the default.
        address.IsDefault = input.IsDefault || count == 0;
        if (address.IsDefault) await ClearDefaultAsync(userId, ct);

        db.Addresses.Add(address);
        await db.SaveChangesAsync(ct);
        return await GetAsync(userId, address.Id, ct);
    }

    public async Task<AddressDto> UpdateAsync(Guid userId, Guid id, AddressInput input, CancellationToken ct)
    {
        var address = await FindAsync(userId, id, ct);
        await ApplyAsync(address, input, ct);
        if (input.IsDefault && !address.IsDefault)
        {
            await ClearDefaultAsync(userId, ct);
            address.IsDefault = true;
        }
        await db.SaveChangesAsync(ct);
        return await GetAsync(userId, id, ct);
    }

    public async Task SetDefaultAsync(Guid userId, Guid id, CancellationToken ct)
    {
        var address = await FindAsync(userId, id, ct);
        await ClearDefaultAsync(userId, ct);
        address.IsDefault = true;
        await db.SaveChangesAsync(ct);
    }

    public async Task DeleteAsync(Guid userId, Guid id, CancellationToken ct)
    {
        var address = await FindAsync(userId, id, ct);
        address.IsDeleted = true;
        if (address.IsDefault)
        {
            address.IsDefault = false;
            // Promote the next address so the customer always has a default.
            var next = await db.Addresses.Where(a => a.UserId == userId && !a.IsDeleted && a.Id != id).OrderBy(a => a.CreatedAt).FirstOrDefaultAsync(ct);
            if (next != null) next.IsDefault = true;
        }
        await db.SaveChangesAsync(ct);
    }

    private async Task<Address> FindAsync(Guid userId, Guid id, CancellationToken ct) =>
        await db.Addresses.FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId && !a.IsDeleted, ct)
        ?? throw AppException.NotFound("address_not_found", "العنوان غير موجود");

    private Task ClearDefaultAsync(Guid userId, CancellationToken ct) =>
        db.Addresses.Where(a => a.UserId == userId && a.IsDefault).ExecuteUpdateAsync(s => s.SetProperty(a => a.IsDefault, false), ct);

    private async Task ApplyAsync(Address a, AddressInput i, CancellationToken ct)
    {
        // District must belong to the city, and the city to the region.
        var valid = await db.Districts.AnyAsync(d => d.Id == i.DistrictId && d.IsActive && d.CityId == i.CityId && d.City.RegionId == i.RegionId, ct);
        if (!valid) throw AppException.BadRequest("invalid_location", "المنطقة أو المدينة أو الحي غير صحيح");

        a.AddressName = i.AddressName.Trim();
        a.RegionId = i.RegionId;
        a.CityId = i.CityId;
        a.DistrictId = i.DistrictId;
        a.PhoneNumber = PhoneNumber.Normalize(i.PhoneNumber);
        a.AddressDetails = i.AddressDetails?.Trim();
        a.BuildingNumber = i.BuildingNumber?.Trim();
        a.StreetName = i.StreetName?.Trim();
        a.Latitude = i.Latitude;
        a.Longitude = i.Longitude;
    }

    private static IQueryable<AddressDto> Project(IQueryable<Address> q) => q.Select(a => new AddressDto(
        a.Id, a.AddressName, a.RegionId, a.Region.NameAr, a.CityId, a.City.NameAr, a.DistrictId, a.District.NameAr,
        a.PhoneNumber, a.AddressDetails, a.BuildingNumber, a.StreetName, a.Latitude, a.Longitude, a.IsDefault));
}
