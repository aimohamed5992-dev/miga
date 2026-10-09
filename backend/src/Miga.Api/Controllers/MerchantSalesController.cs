using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Miga.Api.Contracts;
using Miga.Api.Infrastructure;
using Miga.Infrastructure.Common;
using Miga.Infrastructure.Features.MerchantSales;

namespace Miga.Api.Controllers;

/// <summary>Merchant: campaigns, aggregated orders, dashboard and wallet.</summary>
[ApiController]
[Route("api/merchant")]
[Authorize(Roles = "Merchant")]
public class MerchantSalesController(MerchantCampaignService campaigns, MerchantOrderService orders, MerchantInsightsService insights) : ControllerBase
{
    [HttpGet("dashboard")]
    public Task<MerchantDashboardDto> Dashboard([FromQuery] Guid? storeId, CancellationToken ct) => insights.DashboardAsync(User.UserId(), storeId, ct);

    // ---- campaigns ----

    /// <param name="tab">active · done · ended · draft</param>
    [HttpGet("campaigns")]
    public Task<PagedResult<MerchantCampaignDto>> Campaigns([FromQuery] MerchantCampaignTab tab = MerchantCampaignTab.Active, [FromQuery] Guid? storeId = null,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        campaigns.ListAsync(User.UserId(), tab, storeId, page, pageSize, ct);

    [HttpGet("campaigns/{id:guid}")]
    public Task<MerchantCampaignDto> Campaign(Guid id, CancellationToken ct) => campaigns.GetAsync(User.UserId(), id, ct);

    [HttpGet("campaigns/{id:guid}/participants")]
    public Task<PagedResult<ParticipantDto>> Participants(Guid id, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        campaigns.ParticipantsAsync(User.UserId(), id, page, pageSize, ct);

    /// <summary>The 4-step wizard. `publish: false` saves a draft.</summary>
    [HttpPost("campaigns")]
    public async Task<ActionResult<MerchantCampaignDto>> Create(CampaignRequest req, CancellationToken ct)
    {
        var created = await campaigns.CreateAsync(User.UserId(), req.ToInput(), ct);
        return CreatedAtAction(nameof(Campaign), new { id = created.Id }, created);
    }

    [HttpPut("campaigns/{id:guid}")]
    public Task<MerchantCampaignDto> UpdateDraft(Guid id, CampaignRequest req, CancellationToken ct) => campaigns.UpdateDraftAsync(User.UserId(), id, req.ToInput(), ct);

    /// <summary>Edit a draft or running campaign (see MerchantCampaignService.EditAsync for what is locked once customers joined).</summary>
    [HttpPatch("campaigns/{id:guid}")]
    public Task<MerchantCampaignDto> Edit(Guid id, EditCampaignRequest r, CancellationToken ct) =>
        campaigns.EditAsync(User.UserId(), id,
            new CampaignEdit(r.TitleAr, r.DescriptionAr, r.OriginalPrice, r.CampaignPrice, r.TargetQuantity, r.MaxQuantityPerCustomer, r.EndsAt), ct);

    [HttpPost("campaigns/{id:guid}/publish")]
    public Task<MerchantCampaignDto> Publish(Guid id, CancellationToken ct) => campaigns.PublishAsync(User.UserId(), id, ct);

    [HttpPost("campaigns/{id:guid}/extend")]
    public Task<MerchantCampaignDto> Extend(Guid id, ExtendCampaignRequest req, CancellationToken ct) => campaigns.ExtendAsync(User.UserId(), id, req.Days, ct);

    [HttpPost("campaigns/{id:guid}/cancel")]
    public Task<MerchantCampaignDto> Cancel(Guid id, CancelCampaignRequest req, CancellationToken ct) => campaigns.CancelAsync(User.UserId(), id, req.Reason, ct);

    // ---- aggregated orders ----

    /// <param name="tab">new · preparing · ready · done</param>
    [HttpGet("orders")]
    public Task<PagedResult<MerchantOrderSummaryDto>> Orders([FromQuery] MerchantOrderTab tab = MerchantOrderTab.New, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        orders.ListAsync(User.UserId(), tab, page, pageSize, ct);

    [HttpGet("orders/{id:guid}")]
    public Task<MerchantOrderDetailDto> Order(Guid id, CancellationToken ct) => orders.GetAsync(User.UserId(), id, ct);

    [HttpPost("orders/{id:guid}/confirm")]
    public Task<MerchantOrderDetailDto> Confirm(Guid id, CancellationToken ct) => orders.ConfirmAsync(User.UserId(), id, ct);

    [HttpPost("orders/{id:guid}/start-preparing")]
    public Task<MerchantOrderDetailDto> StartPreparing(Guid id, CancellationToken ct) => orders.StartPreparingAsync(User.UserId(), id, ct);

    [HttpPost("orders/{id:guid}/ready")]
    public Task<MerchantOrderDetailDto> Ready(Guid id, CancellationToken ct) => orders.MarkReadyAsync(User.UserId(), id, ct);

    // ---- wallet ----

    [HttpGet("business")]
    public Task<MerchantBusinessDto> Business(CancellationToken ct) => insights.BusinessAsync(User.UserId(), ct);

    [HttpGet("earnings")]
    public Task<EarningsDto> Earnings(CancellationToken ct) => insights.EarningsAsync(User.UserId(), ct);

    [HttpPut("bank-account")]
    public async Task<IActionResult> BankAccount(BankAccountRequest req, CancellationToken ct)
    {
        await insights.SetBankAccountAsync(User.UserId(), req.BankName, req.Iban, ct);
        return NoContent();
    }

    [HttpPost("payouts")]
    public Task<EarningsDto> Payout(PayoutRequest req, CancellationToken ct) => insights.RequestPayoutAsync(User.UserId(), req.Amount, ct);
}
