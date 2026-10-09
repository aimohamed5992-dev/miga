using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;
using Miga.Domain.Common;
using Miga.Domain.Entities;
using Miga.Infrastructure.Common;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Features.Settings;

public record SupportContacts(string? Phone, string? WhatsApp, string? Email);

/// <summary>The settings in force: saved values, or the server configuration where nothing was saved.</summary>
public record EffectiveSettings(decimal PlatformFeePercent, decimal DeliveryFee, SupportContacts Support, DateTime? UpdatedAt, string? UpdatedBy);

public record SettingsInput(decimal PlatformFeePercent, decimal DeliveryFee, string? SupportPhone, string? SupportWhatsApp, string? SupportEmail);

public partial class PlatformSettingsService(MigaDbContext db, IOptions<CommerceOptions> commerce, IConfiguration config, TimeProvider clock)
{
    public const decimal MaxFeePercent = 30;
    public const decimal MaxDeliveryFee = 200;

    public async Task<EffectiveSettings> GetAsync(CancellationToken ct)
    {
        var row = await db.PlatformSettings.AsNoTracking().OrderBy(s => s.CreatedAt).FirstOrDefaultAsync(ct);
        string? updatedBy = null;
        if (row?.UpdatedByUserId is { } uid) updatedBy = await db.Users.Where(u => u.Id == uid).Select(u => u.FullName).FirstOrDefaultAsync(ct);
        static string? Clean(string? v) => string.IsNullOrWhiteSpace(v) ? null : v.Trim();
        return new EffectiveSettings(
            row?.PlatformFeePercent ?? commerce.Value.PlatformFeePercent,
            row?.DeliveryFee ?? commerce.Value.DeliveryFee,
            new SupportContacts(
                Clean(row?.SupportPhone) ?? Clean(config["Support:Phone"]),
                Clean(row?.SupportWhatsApp) ?? Clean(config["Support:WhatsApp"]),
                Clean(row?.SupportEmail) ?? Clean(config["Support:Email"])),
            row?.UpdatedAt, updatedBy);
    }

    public async Task<EffectiveSettings> UpdateAsync(Guid adminId, SettingsInput i, CancellationToken ct)
    {
        if (i.PlatformFeePercent is < 0 or > MaxFeePercent)
            throw AppException.BadRequest("invalid_fee", $"عمولة المنصة بين 0 و{MaxFeePercent}٪");
        if (i.DeliveryFee is < 0 or > MaxDeliveryFee)
            throw AppException.BadRequest("invalid_delivery_fee", $"رسوم التوصيل بين 0 و{MaxDeliveryFee} ر.س");
        var phone = Clean(i.SupportPhone);
        var whatsapp = Clean(i.SupportWhatsApp)?.TrimStart('+');
        var email = Clean(i.SupportEmail);
        if (phone != null && !PhoneRx().IsMatch(phone)) throw AppException.BadRequest("invalid_phone", "رقم الدعم غير صحيح");
        if (whatsapp != null && !WhatsAppRx().IsMatch(whatsapp)) throw AppException.BadRequest("invalid_whatsapp", "رقم واتساب يُكتب دوليًا مثل 9665XXXXXXXX");
        if (email != null && !EmailRx().IsMatch(email)) throw AppException.BadRequest("invalid_email", "البريد الإلكتروني غير صحيح");

        var row = await db.PlatformSettings.OrderBy(s => s.CreatedAt).FirstOrDefaultAsync(ct);
        if (row == null) db.PlatformSettings.Add(row = new PlatformSettings());
        row.PlatformFeePercent = Math.Round(i.PlatformFeePercent, 2);
        row.DeliveryFee = Math.Round(i.DeliveryFee, 2);
        row.SupportPhone = phone;
        row.SupportWhatsApp = whatsapp;
        row.SupportEmail = email;
        row.UpdatedAt = clock.GetUtcNow().UtcDateTime;
        row.UpdatedByUserId = adminId;
        await db.SaveChangesAsync(ct);
        return await GetAsync(ct);
    }

    private static string? Clean(string? v) => string.IsNullOrWhiteSpace(v) ? null : v.Trim();

    [GeneratedRegex(@"^\+?\d{7,15}$")]
    private static partial Regex PhoneRx();

    [GeneratedRegex(@"^\d{9,15}$")]
    private static partial Regex WhatsAppRx();

    [GeneratedRegex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$")]
    private static partial Regex EmailRx();
}
