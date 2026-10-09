using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Miga.Domain.Common;
using Miga.Domain.Entities;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Auth;

public record TokenPair(string AccessToken, DateTime AccessTokenExpiresAt, string RefreshToken);

public class TokenService(MigaDbContext db, IOptions<JwtOptions> options, TimeProvider clock)
{
    private readonly JwtOptions _o = options.Value;

    public async Task<TokenPair> IssueAsync(ApplicationUser user, CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var expires = now.AddMinutes(_o.AccessTokenMinutes);
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.MobilePhone, user.PhoneNumber ?? string.Empty),
            // One account type per phone number → one role.
            new(ClaimTypes.Role, user.UserType.ToString()),
        };

        var token = new JwtSecurityToken(
            _o.Issuer,
            _o.Audience,
            claims,
            notBefore: now,
            expires: expires,
            signingCredentials: new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_o.Key)), SecurityAlgorithms.HmacSha256));

        var refresh = Convert.ToBase64String(RandomNumberGenerator.GetBytes(48));
        db.RefreshTokens.Add(new RefreshToken { UserId = user.Id, TokenHash = Hash(refresh), CreatedAt = now, ExpiresAt = now.AddDays(_o.RefreshTokenDays) });
        await db.SaveChangesAsync(ct);

        return new TokenPair(new JwtSecurityTokenHandler().WriteToken(token), expires, refresh);
    }

    /// <summary>Rotation: the presented refresh token is revoked and a new pair is issued.</summary>
    public async Task<(ApplicationUser User, TokenPair Tokens)> RefreshAsync(string refreshToken, CancellationToken ct)
    {
        var hash = Hash(refreshToken);
        var stored = await db.RefreshTokens.Include(x => x.User).FirstOrDefaultAsync(x => x.TokenHash == hash, ct);
        var now = clock.GetUtcNow().UtcDateTime;

        if (stored == null || stored.RevokedAt != null || stored.ExpiresAt <= now || !stored.User.IsActive)
            throw AppException.Unauthorized("invalid_refresh_token", "انتهت الجلسة، سجّل الدخول مرة أخرى");

        stored.RevokedAt = now;
        return (stored.User, await IssueAsync(stored.User, ct));
    }

    public async Task RevokeAsync(string refreshToken, CancellationToken ct)
    {
        var hash = Hash(refreshToken);
        await db.RefreshTokens.Where(x => x.TokenHash == hash && x.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.RevokedAt, clock.GetUtcNow().UtcDateTime), ct);
    }

    private static string Hash(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
}
