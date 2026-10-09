using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Miga.Domain.Common;
using Miga.Domain.Entities;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Auth;

/// <summary>Sends SMS. Swap <see cref="LogSmsSender"/> for a real provider (Unifonic, Taqnyat, Twilio…).</summary>
public interface ISmsSender
{
    Task SendAsync(string phone, string message, CancellationToken ct);
}

public class LogSmsSender(ILogger<LogSmsSender> log) : ISmsSender
{
    public Task SendAsync(string phone, string message, CancellationToken ct)
    {
        log.LogInformation("SMS to {Phone}: {Message}", phone, message);
        return Task.CompletedTask;
    }
}

public record OtpSendResult(int ExpiresInSeconds, int ResendAfterSeconds, string? DevCode);

public class OtpService(MigaDbContext db, ISmsSender sms, IOptions<OtpOptions> options, TimeProvider clock)
{
    private readonly OtpOptions _o = options.Value;

    public async Task<OtpSendResult> SendAsync(string phone, CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var recent = await db.OtpCodes
            .Where(x => x.PhoneNumber == phone && x.CreatedAt > now.AddMinutes(-_o.SendWindowMinutes))
            .OrderByDescending(x => x.CreatedAt)
            .Select(x => x.CreatedAt)
            .ToListAsync(ct);

        if (recent.Count > 0)
        {
            var wait = _o.ResendCooldownSeconds - (int)(now - recent[0]).TotalSeconds;
            if (wait > 0) throw AppException.TooManyRequests("otp_cooldown", $"يمكنك طلب رمز جديد بعد {wait} ثانية");
        }
        if (recent.Count >= _o.MaxSendsPerWindow)
            throw AppException.TooManyRequests("otp_limit", "تجاوزت عدد المحاولات المسموح، حاول لاحقًا");

        // A new code invalidates any previous unused one.
        await db.OtpCodes.Where(x => x.PhoneNumber == phone && !x.IsUsed).ExecuteUpdateAsync(s => s.SetProperty(x => x.IsUsed, true), ct);

        var code = RandomNumberGenerator.GetInt32(0, (int)Math.Pow(10, _o.Length)).ToString().PadLeft(_o.Length, '0');
        db.OtpCodes.Add(new OtpCode { PhoneNumber = phone, CodeHash = Hash(phone, code), CreatedAt = now, ExpiresAt = now.AddMinutes(_o.ExpiryMinutes) });
        await db.SaveChangesAsync(ct);

        await sms.SendAsync(phone, $"رمز التحقق في ميجا: {code}\nلا تشاركه مع أحد.", ct);
        return new OtpSendResult(_o.ExpiryMinutes * 60, _o.ResendCooldownSeconds, _o.ExposeCodeInResponse ? code : null);
    }

    /// <summary>Validates and consumes the latest code for the phone. Throws on failure.</summary>
    public async Task VerifyAsync(string phone, string code, CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var otp = await db.OtpCodes.Where(x => x.PhoneNumber == phone && !x.IsUsed).OrderByDescending(x => x.CreatedAt).FirstOrDefaultAsync(ct);

        if (otp == null || otp.ExpiresAt <= now) throw AppException.BadRequest("otp_expired", "انتهت صلاحية الرمز، اطلب رمزًا جديدًا");
        if (otp.Attempts >= _o.MaxAttempts) throw AppException.TooManyRequests("otp_attempts", "تجاوزت عدد المحاولات، اطلب رمزًا جديدًا");

        var ok = CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(otp.CodeHash), Encoding.UTF8.GetBytes(Hash(phone, code ?? string.Empty)));
        if (!ok)
        {
            otp.Attempts++;
            await db.SaveChangesAsync(ct);
            throw AppException.BadRequest("otp_invalid", "الرمز غير صحيح، حاول مرة أخرى");
        }

        otp.IsUsed = true;
        await db.SaveChangesAsync(ct);
    }

    private string Hash(string phone, string code)
    {
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(_o.Secret));
        return Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes($"{phone}:{code}")));
    }
}
