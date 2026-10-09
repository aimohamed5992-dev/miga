using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Miga.Api.Infrastructure;
using Miga.Domain;
using Miga.Infrastructure.Common;
using Miga.Infrastructure.Features.Admin;
using Miga.Infrastructure.Features.Marketing;
using Miga.Infrastructure.Features.Settings;

namespace Miga.Api.Controllers;

public record RejectRequest([Required, StringLength(500, MinimumLength = 3)] string Reason);

public record SettingsRequest(
    decimal PlatformFeePercent, decimal DeliveryFee, [StringLength(20)] string? SupportPhone, [StringLength(20)] string? SupportWhatsApp,
    [StringLength(150)] string? SupportEmail);
public record SetActiveRequest(bool Active, [StringLength(500)] string? Reason);

public record RetryDeliveryRequest([StringLength(300)] string? Note);

public record BannerRequest(
    [Required, StringLength(500)] string ImageUrl, [StringLength(120)] string? TitleAr, [StringLength(200)] string? SubtitleAr,
    [StringLength(40)] string? ButtonLabelAr, [Required] string LinkType, Guid? LinkId, int SortOrder, bool IsActive, DateTime? StartsAt, DateTime? EndsAt)
{
    public BannerInput ToInput() => new(ImageUrl, TitleAr, SubtitleAr, ButtonLabelAr, LinkType, LinkId, SortOrder, IsActive, StartsAt, EndsAt);
}

public record PayoutPaidRequest([Required, StringLength(100, MinimumLength = 3)] string Reference);

/// <summary>MIGA admin dashboard: platform numbers, the merchant/driver review queue and user management.</summary>
[ApiController]
[Route("api/admin")]
[Authorize(Roles = "Admin")]
public class AdminController(AdminService admin, AdminOperationsService ops, AdminMapService map, MarketingService marketing, PlatformSettingsService settings) : ControllerBase
{
    [HttpGet("dashboard")]
    public Task<AdminDashboardDto> Dashboard(CancellationToken ct) => admin.DashboardAsync(ct);

    // ---- review queue ----

    /// <param name="type">merchant · driver · all</param>
    /// <param name="status">pending · rejected · verified</param>
    [HttpGet("verifications")]
    public Task<List<VerificationItemDto>> Verifications([FromQuery] string type = "all", [FromQuery] string status = "pending", CancellationToken ct = default) =>
        admin.VerificationsAsync(type, status, ct);

    /// <summary>Pending merchants and drivers (kept for older clients; the dashboard uses <c>verifications</c>).</summary>
    [HttpGet("pending")]
    public async Task<object> Pending(CancellationToken ct)
    {
        var items = await admin.VerificationsAsync("all", "pending", ct);
        return new { merchants = items.Where(i => i.Type == "merchant"), drivers = items.Where(i => i.Type == "driver") };
    }

    [HttpPost("merchants/{userId:guid}/verify")]
    public async Task<IActionResult> VerifyMerchant(Guid userId, CancellationToken ct)
    {
        await admin.VerifyMerchantAsync(userId, ct);
        return NoContent();
    }

    [HttpPost("merchants/{userId:guid}/reject")]
    public async Task<IActionResult> RejectMerchant(Guid userId, RejectRequest req, CancellationToken ct)
    {
        await admin.RejectMerchantAsync(userId, req.Reason, ct);
        return NoContent();
    }

    [HttpPost("drivers/{userId:guid}/verify")]
    public async Task<IActionResult> VerifyDriver(Guid userId, CancellationToken ct)
    {
        await admin.VerifyDriverAsync(userId, ct);
        return NoContent();
    }

    [HttpPost("drivers/{userId:guid}/reject")]
    public async Task<IActionResult> RejectDriver(Guid userId, RejectRequest req, CancellationToken ct)
    {
        await admin.RejectDriverAsync(userId, req.Reason, ct);
        return NoContent();
    }

    // ---- users ----

    /// <param name="type">customer · merchant · driver</param>
    /// <param name="status">all · active · suspended · pending · rejected · verified</param>
    [HttpGet("users")]
    public Task<PagedResult<AdminUserDto>> Users(
        [FromQuery] string type = "customer", [FromQuery] string? q = null, [FromQuery] string status = "all",
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        admin.UsersAsync(ParseType(type), q, status, page, pageSize, ct);

    [HttpGet("users/{id:guid}")]
    public Task<AdminUserDetailDto> GetUser(Guid id, CancellationToken ct) => admin.UserAsync(id, ct);

    [HttpPatch("users/{id:guid}/active")]
    public async Task<IActionResult> SetActive(Guid id, SetActiveRequest req, CancellationToken ct)
    {
        await admin.SetActiveAsync(User.UserId(), id, req.Active, req.Reason, ct);
        return NoContent();
    }

    // ---- campaigns & orders ----

    /// <param name="status">active · completed · ended · draft · all</param>
    [HttpGet("campaigns")]
    public Task<PagedResult<AdminCampaignDto>> Campaigns(
        [FromQuery] string status = "active", [FromQuery] string? q = null, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        ops.CampaignsAsync(status, q, page, pageSize, ct);

    /// <summary>Cancels a running campaign; every paid customer is refunded and the merchant is notified with the reason.</summary>
    [HttpPost("campaigns/{id:guid}/cancel")]
    public async Task<IActionResult> CancelCampaign(Guid id, RejectRequest req, CancellationToken ct)
    {
        await ops.CancelCampaignAsync(id, req.Reason, ct);
        return NoContent();
    }

    /// <param name="status">active · delivered · closed · all</param>
    [HttpGet("orders")]
    public Task<PagedResult<AdminOrderDto>> Orders(
        [FromQuery] string status = "active", [FromQuery] string? q = null, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        ops.OrdersAsync(status, q, page, pageSize, ct);

    /// <param name="status">open · completed · all</param>
    [HttpGet("merchant-orders")]
    public Task<PagedResult<AdminMerchantOrderDto>> MerchantOrders(
        [FromQuery] string status = "open", [FromQuery] string? q = null, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        ops.MerchantOrdersAsync(status, q, page, pageSize, ct);

    // ---- deliveries ----

    /// <summary>Live map: open deliveries, their stores and drivers on duty (optionally one city).</summary>
    [HttpGet("map")]
    public Task<AdminMapDto> Map([FromQuery] Guid? cityId, CancellationToken ct) => map.MapAsync(cityId, ct);

    /// <param name="status">failed · in_progress · waiting · delivered · all</param>
    [HttpGet("deliveries")]
    public Task<PagedResult<AdminDeliveryDto>> Deliveries(
        [FromQuery] string status = "failed", [FromQuery] string? q = null, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        ops.DeliveriesAsync(status, q, page, pageSize, ct);

    /// <summary>Failed delivery → back to the same driver as picked up, to try again.</summary>
    [HttpPost("deliveries/{id:guid}/retry")]
    public async Task<IActionResult> RetryDelivery(Guid id, RetryDeliveryRequest req, CancellationToken ct)
    {
        await ops.RetryDeliveryAsync(id, req.Note, ct);
        return NoContent();
    }

    /// <summary>Failed delivery → cancelled and the customer refunded (deducted from the merchant's settlement).</summary>
    [HttpPost("deliveries/{id:guid}/refund")]
    public async Task<IActionResult> RefundDelivery(Guid id, RejectRequest req, CancellationToken ct)
    {
        await ops.RefundDeliveryAsync(id, req.Reason, ct);
        return NoContent();
    }

    // ---- merchant withdrawals ----

    /// <param name="status">requested · paid · rejected · all</param>
    [HttpGet("payouts")]
    public Task<PagedResult<AdminPayoutDto>> Payouts(
        [FromQuery] string status = "requested", [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        ops.PayoutsAsync(status, page, pageSize, ct);

    [HttpPost("payouts/{id:guid}/paid")]
    public async Task<IActionResult> PayoutPaid(Guid id, PayoutPaidRequest req, CancellationToken ct)
    {
        await ops.MarkPayoutPaidAsync(id, req.Reference, ct);
        return NoContent();
    }

    [HttpPost("payouts/{id:guid}/reject")]
    public async Task<IActionResult> RejectPayout(Guid id, RejectRequest req, CancellationToken ct)
    {
        await ops.RejectPayoutAsync(id, req.Reason, ct);
        return NoContent();
    }

    // ---- home banners ----

    [HttpGet("banners")]
    public Task<List<AdminBannerDto>> Banners(CancellationToken ct) => marketing.BannersAsync(ct);

    [HttpPost("banners")]
    public Task<AdminBannerDto> CreateBanner(BannerRequest req, CancellationToken ct) => marketing.SaveBannerAsync(null, req.ToInput(), ct);

    [HttpPut("banners/{id:guid}")]
    public Task<AdminBannerDto> UpdateBanner(Guid id, BannerRequest req, CancellationToken ct) => marketing.SaveBannerAsync(id, req.ToInput(), ct);

    [HttpDelete("banners/{id:guid}")]
    public async Task<IActionResult> DeleteBanner(Guid id, CancellationToken ct)
    {
        await marketing.DeleteBannerAsync(id, ct);
        return NoContent();
    }

    // ---- platform settings ----

    [HttpGet("settings")]
    public Task<EffectiveSettings> Settings(CancellationToken ct) => settings.GetAsync(ct);

    /// <summary>Commission and delivery fee apply to campaigns completed after the change; existing orders keep their numbers.</summary>
    [HttpPut("settings")]
    public Task<EffectiveSettings> UpdateSettings(SettingsRequest req, CancellationToken ct) =>
        settings.UpdateAsync(User.UserId(), new SettingsInput(req.PlatformFeePercent, req.DeliveryFee, req.SupportPhone, req.SupportWhatsApp, req.SupportEmail), ct);

    private static UserType ParseType(string type) => type switch
    {
        "merchant" => UserType.Merchant,
        "driver" => UserType.Driver,
        _ => UserType.Customer,
    };
}
