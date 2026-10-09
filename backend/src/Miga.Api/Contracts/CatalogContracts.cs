using System.ComponentModel.DataAnnotations;
using Miga.Infrastructure.Features.Addresses;
using Miga.Infrastructure.Features.MerchantCatalog;

namespace Miga.Api.Contracts;

public record AddressRequest(
    [Required, StringLength(100, MinimumLength = 2)] string AddressName,
    [Required] Guid RegionId,
    [Required] Guid CityId,
    [Required] Guid DistrictId,
    [Required] string PhoneNumber,
    [StringLength(500)] string? AddressDetails,
    [StringLength(20)] string? BuildingNumber,
    [StringLength(150)] string? StreetName,
    [Range(-90, 90)] decimal? Latitude,
    [Range(-180, 180)] decimal? Longitude,
    bool IsDefault = false)
{
    public AddressInput ToInput() => new(AddressName, RegionId, CityId, DistrictId, PhoneNumber, AddressDetails, BuildingNumber, StreetName, Latitude, Longitude, IsDefault);
}

public record StoreRequest(
    [Required, StringLength(200, MinimumLength = 2)] string NameAr,
    [StringLength(200)] string? NameEn,
    [Required] Guid StoreCategoryId,
    [StringLength(1000)] string? DescriptionAr,
    [StringLength(500)] string? LogoUrl,
    [StringLength(500)] string? CoverImageUrl,
    [StringLength(500)] string? PickupAddress,
    Guid? CityId)
{
    public StoreInput ToInput() => new(NameAr, NameEn, StoreCategoryId, DescriptionAr, LogoUrl, CoverImageUrl, PickupAddress, CityId);
}

public record ActiveRequest(bool Active);

public record CategoryRequest(
    [Required, StringLength(100, MinimumLength = 2)] string NameAr,
    [StringLength(100)] string? NameEn,
    Guid? ParentCategoryId,
    [Range(0, 1000)] int SortOrder = 0)
{
    public CategoryInput ToInput() => new(NameAr, NameEn, ParentCategoryId, SortOrder);
}

public record ProductRequest(
    [Required] Guid ProductCategoryId,
    [Required, StringLength(200, MinimumLength = 2)] string NameAr,
    [StringLength(200)] string? NameEn,
    [StringLength(2000)] string? DescriptionAr,
    [Range(0.01, 1_000_000)] decimal Price,
    [Range(0, 1_000_000)] int StockQuantity,
    bool IsActive,
    [MaxLength(MerchantCatalogService.MaxImages)] IReadOnlyList<string>? ImageUrls)
{
    public ProductInput ToInput() => new(ProductCategoryId, NameAr, NameEn, DescriptionAr, Price, StockQuantity, IsActive, ImageUrls ?? []);
}

public record UploadResponse(string Url);
