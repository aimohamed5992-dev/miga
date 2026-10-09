using System.Security.Cryptography;

namespace Miga.Infrastructure.Common;

public class CommerceOptions
{
    public const string Section = "Commerce";

    /// <summary>MIGA commission taken from each completed campaign (percent of sales).</summary>
    public decimal PlatformFeePercent { get; set; } = 5;

    /// <summary>Driver fee per customer delivery (SAR).</summary>
    public decimal DeliveryFee { get; set; } = 15;
}

public static class Codes
{
    /// <summary>Human-readable order number, e.g. MG-4821937. Uniqueness is enforced by a DB index.</summary>
    public static string OrderNumber(string prefix) => $"{prefix}-{RandomNumberGenerator.GetInt32(1_000_000, 10_000_000)}";

    /// <summary>4-digit hand-over code (merchant → driver pickup, driver → customer delivery).</summary>
    public static string Pin() => RandomNumberGenerator.GetInt32(0, 10_000).ToString("D4");
}
