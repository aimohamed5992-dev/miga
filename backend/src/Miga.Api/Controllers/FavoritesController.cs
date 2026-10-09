using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Miga.Api.Infrastructure;
using Miga.Infrastructure.Features.Catalog;
using Miga.Infrastructure.Features.Marketing;

namespace Miga.Api.Controllers;

/// <summary>Campaigns the customer saved ("الحملات المفضلة").</summary>
[ApiController]
[Route("api/customer/favorites")]
[Authorize(Roles = "Customer")]
public class FavoritesController(CatalogQueries catalog, MarketingService marketing) : ControllerBase
{
    [HttpGet]
    public Task<List<CampaignSummaryDto>> List(CancellationToken ct) => catalog.FavoritesAsync(User.UserId(), ct);

    [HttpPut("{campaignId:guid}")]
    public async Task<IActionResult> Add(Guid campaignId, CancellationToken ct)
    {
        await marketing.AddFavoriteAsync(User.UserId(), campaignId, ct);
        return NoContent();
    }

    [HttpDelete("{campaignId:guid}")]
    public async Task<IActionResult> Remove(Guid campaignId, CancellationToken ct)
    {
        await marketing.RemoveFavoriteAsync(User.UserId(), campaignId, ct);
        return NoContent();
    }
}
