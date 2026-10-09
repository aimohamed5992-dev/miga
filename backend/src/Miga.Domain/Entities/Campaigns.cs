namespace Miga.Domain.Entities;

/// <summary>
/// Group-buying campaign. Example: 100 pieces at 20 SAR instead of 50.
/// Customers join through CampaignOrders; when CurrentQuantity reaches TargetQuantity
/// the campaign completes and one aggregated MerchantOrder is created.
/// </summary>
public class Campaign : Entity
{
    public Guid StoreId { get; set; }
    public Store Store { get; set; } = null!;

    public Guid ProductId { get; set; }
    public Product Product { get; set; } = null!;

    /// <summary>Merchant user who owns the campaign (fast ownership checks).</summary>
    public Guid MerchantUserId { get; set; }
    public ApplicationUser MerchantUser { get; set; } = null!;

    public string TitleAr { get; set; } = string.Empty;
    public string TitleEn { get; set; } = string.Empty;
    public string? DescriptionAr { get; set; }
    public string? DescriptionEn { get; set; }

    public decimal OriginalPrice { get; set; }
    public decimal CampaignPrice { get; set; }

    /// <summary>Quantity required to complete the campaign.</summary>
    public int TargetQuantity { get; set; }

    /// <summary>Paid quantity so far (updated in the same transaction as each paid order).</summary>
    public int CurrentQuantity { get; set; }

    public int? MaxQuantityPerCustomer { get; set; }

    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }

    public CampaignStatus Status { get; set; } = CampaignStatus.Draft;
    public DateTime? CompletedAt { get; set; }
    public bool IsActive { get; set; } = true;

    /// <summary>Optimistic-concurrency token: two customers taking the last pieces at once can't both win.</summary>
    public Guid ConcurrencyStamp { get; set; } = Guid.NewGuid();

    public ICollection<CampaignOrder> Orders { get; set; } = new List<CampaignOrder>();
    public MerchantOrder? MerchantOrder { get; set; }

    public int RemainingQuantity => Math.Max(TargetQuantity - CurrentQuantity, 0);
}
