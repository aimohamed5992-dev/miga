using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Miga.Api.Contracts;
using Miga.Api.Infrastructure;
using Miga.Domain.Common;
using Miga.Infrastructure.Auth;

namespace Miga.Api.Controllers;

[ApiController]
[Route("api/auth")]
[EnableRateLimiting("auth")]
public class AuthController(OtpService otp, AccountService accounts, TokenService tokens) : ControllerBase
{
    /// <summary>Sends a 4-digit SMS code. In Development the code is also returned as `devCode`.</summary>
    [HttpPost("send-otp")]
    public async Task<SendOtpResponse> SendOtp(SendOtpRequest req, CancellationToken ct)
    {
        var phone = PhoneNumber.Normalize(req.Phone);
        var r = await otp.SendAsync(phone, ct);
        return new SendOtpResponse(phone, r.ExpiresInSeconds, r.ResendAfterSeconds, r.DevCode);
    }

    /// <summary>Verifies the code, creates the account on first sign-in and returns tokens.</summary>
    [HttpPost("verify-otp")]
    public async Task<AuthResponse> VerifyOtp(VerifyOtpRequest req, CancellationToken ct)
    {
        var (account, pair) = await accounts.SignInWithOtpAsync(PhoneNumber.Normalize(req.Phone), req.Code, req.UserType, ct);
        return AuthResponse.From(pair, account);
    }

    [HttpPost("refresh")]
    public async Task<AuthResponse> Refresh(RefreshRequest req, CancellationToken ct)
    {
        var (user, pair) = await tokens.RefreshAsync(req.RefreshToken, ct);
        return AuthResponse.From(pair, await accounts.GetAsync(user.Id, ct));
    }

    [HttpPost("logout")]
    public async Task<IActionResult> Logout(RefreshRequest req, CancellationToken ct)
    {
        await tokens.RevokeAsync(req.RefreshToken, ct);
        return NoContent();
    }

    [Authorize]
    [HttpGet("me")]
    [DisableRateLimiting]
    public async Task<AccountResponse> Me(CancellationToken ct) => AccountResponse.From(await accounts.GetAsync(User.UserId(), ct));
}
