using Microsoft.AspNetCore.Mvc;
using Miga.Infrastructure.Common;
using Miga.Infrastructure.Features.Catalog;

namespace Miga.Api.Controllers;

/// <summary>Public browsing for the customer app (no sign-in needed).</summary>
[ApiController]
[Route("api")]
public class CatalogController(CatalogQueries catalog) : ControllerBase
{
    /// <summary>Everything the home screen needs in one call.</summary>
    [HttpGet("home")]
    public Task<HomeDto> Home(CancellationToken ct) => catalog.HomeAsync(ct);

    /// <param name="sort">newest · endingSoon · almostComplete · biggestDiscount</param>
    [HttpGet("campaigns")]
    public Task<PagedResult<CampaignSummaryDto>> Campaigns(
        [FromQuery] Guid? storeId, [FromQuery] Guid? storeCategoryId, [FromQuery] string? q,
        [FromQuery] CampaignSort sort = CampaignSort.Newest, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        catalog.CampaignsAsync(new CampaignQuery(storeId, storeCategoryId, q, sort, page, pageSize), ct);

    [HttpGet("campaigns/{id:guid}")]
    public Task<CampaignDetailDto> Campaign(Guid id, CancellationToken ct) => catalog.CampaignAsync(id, ct);

    [HttpGet("stores")]
    public Task<PagedResult<StoreSummaryDto>> Stores([FromQuery] Guid? categoryId, [FromQuery] string? q, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        catalog.StoresAsync(categoryId, q, page, pageSize, ct);

    [HttpGet("stores/{id:guid}")]
    public Task<StoreDetailDto> Store(Guid id, CancellationToken ct) => catalog.StoreAsync(id, ct);

    [HttpGet("stores/{id:guid}/categories")]
    public Task<List<ProductCategoryDto>> StoreCategories(Guid id, CancellationToken ct) => catalog.StoreProductCategoriesAsync(id, ct);

    [HttpGet("stores/{id:guid}/products")]
    public Task<PagedResult<ProductSummaryDto>> StoreProducts(Guid id, [FromQuery] Guid? categoryId, [FromQuery] string? q, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        catalog.StoreProductsAsync(id, categoryId, q, page, pageSize, ct);

    [HttpGet("products/{id:guid}")]
    public Task<ProductDetailDto> Product(Guid id, CancellationToken ct) => catalog.ProductAsync(id, ct);

    [HttpGet("search")]
    public Task<SearchDto> Search([FromQuery] string q, CancellationToken ct) => catalog.SearchAsync(q ?? string.Empty, ct);
}
