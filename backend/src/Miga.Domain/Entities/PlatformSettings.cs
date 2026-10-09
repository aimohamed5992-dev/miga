namespace Miga.Domain.Entities;

/// <summary>
/// Platform settings edited from the admin dashboard (single row). Empty values fall back to the server
/// configuration (<c>Commerce</c> / <c>Support</c> sections), so a fresh install works before anyone saves.
/// </summary>
public class PlatformSettings : Entity
{
    /// <summary>MIGA commission on each completed campaign, percent of sales. Applies to campaigns completed after the change.</summary>
    public decimal? PlatformFeePercent { get; set; }

    /// <summary>Driver fee per customer delivery (SAR). Applies to deliveries created after the change.</summary>
    public decimal? DeliveryFee { get; set; }

    public string? SupportPhone { get; set; }
    public string? SupportWhatsApp { get; set; }
    public string? SupportEmail { get; set; }

    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedByUserId { get; set; }
}
