using System.ComponentModel.DataAnnotations;
using Miga.Infrastructure.Features.MerchantSales;

namespace Miga.Api.Contracts;

public record CampaignRequest(
    [Required] Guid StoreId,
    [Required] Guid ProductId,
    [Required, StringLength(200, MinimumLength = 3)] string TitleAr,
    [StringLength(200)] string? TitleEn,
    [StringLength(2000)] string? DescriptionAr,
    [Range(0.01, 1_000_000)] decimal? OriginalPrice,
    [Range(0.01, 1_000_000)] decimal CampaignPrice,
    [Range(2, 1_000_000)] int TargetQuantity,
    [Range(1, 1_000_000)] int? MaxQuantityPerCustomer,
    DateTime? StartDate,
    [Range(1, MerchantCampaignService.MaxDurationDays)] int DurationDays = 7,
    bool Publish = true)
{
    public CampaignInput ToInput() => new(StoreId, ProductId, TitleAr, TitleEn, DescriptionAr, OriginalPrice, CampaignPrice, TargetQuantity,
        MaxQuantityPerCustomer, StartDate, DurationDays, Publish);
}

public record EditCampaignRequest(
    [StringLength(200)] string? TitleAr,
    [StringLength(2000)] string? DescriptionAr,
    [Range(0.01, 1_000_000)] decimal? OriginalPrice,
    [Range(0.01, 1_000_000)] decimal? CampaignPrice,
    [Range(2, 1_000_000)] int? TargetQuantity,
    [Range(0, 1_000_000)] int? MaxQuantityPerCustomer,
    DateTime? EndsAt);

public record ExtendCampaignRequest([Range(1, 14)] int Days);

public record CancelCampaignRequest([Required, StringLength(300, MinimumLength = 2)] string Reason);

public record BankAccountRequest([Required, StringLength(100, MinimumLength = 2)] string BankName, [Required, StringLength(40)] string Iban);

public record PayoutRequest([Range(1, 10_000_000)] decimal Amount);
