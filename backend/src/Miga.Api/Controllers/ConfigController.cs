using Microsoft.AspNetCore.Mvc;
using Miga.Infrastructure.Features.Settings;

namespace Miga.Api.Controllers;

public record SupportContactDto(string? Phone, string? WhatsApp, string? Email);

public record AppConfigDto(SupportContactDto Support, decimal PlatformFeePercent, decimal DeliveryFee);

/// <summary>Public app settings: support contacts and commerce numbers (edited by admins; server configuration as fallback).</summary>
[ApiController]
[Route("api/config")]
public class ConfigController(PlatformSettingsService settings) : ControllerBase
{
    [HttpGet]
    public async Task<AppConfigDto> Get(CancellationToken ct)
    {
        var s = await settings.GetAsync(ct);
        return new AppConfigDto(new SupportContactDto(s.Support.Phone, s.Support.WhatsApp, s.Support.Email), s.PlatformFeePercent, s.DeliveryFee);
    }
}
