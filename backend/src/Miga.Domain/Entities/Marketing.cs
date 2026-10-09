namespace Miga.Domain.Entities;

public enum BannerLinkType
{
    None = 0,
    Campaign = 1,
    Product = 2,
    Store = 3,
    StoreCategory = 4
}

/// <summary>Home-screen slide managed from the admin dashboard. Tapping it opens <see cref="LinkType"/> / <see cref="LinkId"/>.</summary>
public class Banner : Entity
{
    public string ImageUrl { get; set; } = string.Empty;
    public string? TitleAr { get; set; }
    public string? SubtitleAr { get; set; }
    public string? ButtonLabelAr { get; set; }
    public BannerLinkType LinkType { get; set; }
    public Guid? LinkId { get; set; }
    public int SortOrder { get; set; }
    public bool IsActive { get; set; } = true;

    /// <summary>Optional schedule (UTC); outside it the banner is hidden from customers.</summary>
    public DateTime? StartsAt { get; set; }
    public DateTime? EndsAt { get; set; }
}

/// <summary>A campaign the customer saved to follow.</summary>
public class FavoriteCampaign : Entity
{
    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;
    public Guid CampaignId { get; set; }
    public Campaign Campaign { get; set; } = null!;
}
