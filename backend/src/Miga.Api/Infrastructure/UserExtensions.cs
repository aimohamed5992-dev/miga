using System.Security.Claims;
using Miga.Domain.Common;

namespace Miga.Api.Infrastructure;

public static class UserExtensions
{
    /// <summary>Id of the signed-in user (from the JWT `sub` / NameIdentifier claim).</summary>
    public static Guid UserId(this ClaimsPrincipal user) =>
        Guid.TryParse(user.FindFirstValue(ClaimTypes.NameIdentifier), out var id)
            ? id
            : throw AppException.Unauthorized("unauthorized", "سجّل الدخول أولًا");
}
