namespace Miga.Infrastructure.Auth;

public class JwtOptions
{
    public const string Section = "Jwt";

    public string Issuer { get; set; } = "miga";
    public string Audience { get; set; } = "miga-apps";

    /// <summary>HMAC-SHA256 signing key, at least 32 characters. Never commit the production value.</summary>
    public string Key { get; set; } = string.Empty;

    public int AccessTokenMinutes { get; set; } = 60;
    public int RefreshTokenDays { get; set; } = 30;
}

public class OtpOptions
{
    public const string Section = "Otp";

    /// <summary>Secret mixed into the stored code hash.</summary>
    public string Secret { get; set; } = string.Empty;

    public int Length { get; set; } = 4;
    public int ExpiryMinutes { get; set; } = 5;
    public int MaxAttempts { get; set; } = 5;

    /// <summary>Matches the 60s resend timer in the apps.</summary>
    public int ResendCooldownSeconds { get; set; } = 60;
    public int MaxSendsPerWindow { get; set; } = 5;
    public int SendWindowMinutes { get; set; } = 30;

    /// <summary>Development/testing only: return the code in the API response instead of needing SMS.</summary>
    public bool ExposeCodeInResponse { get; set; }
}
