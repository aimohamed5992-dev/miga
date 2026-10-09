using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Miga.Api.Contracts;
using Miga.Api.Infrastructure;
using Miga.Infrastructure.Common;
using Miga.Infrastructure.Features.Catalog;
using Miga.Infrastructure.Features.MerchantCatalog;

namespace Miga.Api.Controllers;

/// <summary>Merchant: stores → product categories → products. Ownership is enforced in the service.</summary>
[ApiController]
[Route("api/merchant/stores")]
[Authorize(Roles = "Merchant")]
public class MerchantCatalogController(MerchantCatalogService service) : ControllerBase
{
    // ---- stores ----

    [HttpGet]
    public Task<List<MerchantStoreDto>> Stores(CancellationToken ct) => service.StoresAsync(User.UserId(), ct);

    [HttpGet("{storeId:guid}")]
    public Task<MerchantStoreDto> Store(Guid storeId, CancellationToken ct) => service.StoreAsync(User.UserId(), storeId, ct);

    [HttpPost]
    public async Task<ActionResult<MerchantStoreDto>> CreateStore(StoreRequest req, CancellationToken ct)
    {
        var store = await service.CreateStoreAsync(User.UserId(), req.ToInput(), ct);
        return CreatedAtAction(nameof(Store), new { storeId = store.Id }, store);
    }

    [HttpPut("{storeId:guid}")]
    public Task<MerchantStoreDto> UpdateStore(Guid storeId, StoreRequest req, CancellationToken ct) => service.UpdateStoreAsync(User.UserId(), storeId, req.ToInput(), ct);

    [HttpPatch("{storeId:guid}/active")]
    public Task<MerchantStoreDto> SetStoreActive(Guid storeId, ActiveRequest req, CancellationToken ct) => service.SetStoreActiveAsync(User.UserId(), storeId, req.Active, ct);

    // ---- product categories ----

    [HttpGet("{storeId:guid}/categories")]
    public Task<List<ProductCategoryDto>> Categories(Guid storeId, CancellationToken ct) => service.CategoriesAsync(User.UserId(), storeId, ct);

    [HttpPost("{storeId:guid}/categories")]
    public Task<ProductCategoryDto> CreateCategory(Guid storeId, CategoryRequest req, CancellationToken ct) =>
        service.SaveCategoryAsync(User.UserId(), storeId, null, req.ToInput(), ct);

    [HttpPut("{storeId:guid}/categories/{categoryId:guid}")]
    public Task<ProductCategoryDto> UpdateCategory(Guid storeId, Guid categoryId, CategoryRequest req, CancellationToken ct) =>
        service.SaveCategoryAsync(User.UserId(), storeId, categoryId, req.ToInput(), ct);

    [HttpDelete("{storeId:guid}/categories/{categoryId:guid}")]
    public async Task<IActionResult> DeleteCategory(Guid storeId, Guid categoryId, CancellationToken ct)
    {
        await service.DeleteCategoryAsync(User.UserId(), storeId, categoryId, ct);
        return NoContent();
    }

    // ---- products ----

    [HttpGet("{storeId:guid}/products")]
    public Task<PagedResult<MerchantProductDto>> Products(Guid storeId, [FromQuery] Guid? categoryId, [FromQuery] string? q, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        service.ProductsAsync(User.UserId(), storeId, categoryId, q, page, pageSize, ct);

    [HttpGet("{storeId:guid}/products/{productId:guid}")]
    public Task<MerchantProductDto> Product(Guid storeId, Guid productId, CancellationToken ct) => service.ProductAsync(User.UserId(), storeId, productId, ct);

    [HttpPost("{storeId:guid}/products")]
    public async Task<ActionResult<MerchantProductDto>> CreateProduct(Guid storeId, ProductRequest req, CancellationToken ct)
    {
        var product = await service.SaveProductAsync(User.UserId(), storeId, null, req.ToInput(), ct);
        return CreatedAtAction(nameof(Product), new { storeId, productId = product.Id }, product);
    }

    [HttpPut("{storeId:guid}/products/{productId:guid}")]
    public Task<MerchantProductDto> UpdateProduct(Guid storeId, Guid productId, ProductRequest req, CancellationToken ct) =>
        service.SaveProductAsync(User.UserId(), storeId, productId, req.ToInput(), ct);

    [HttpPatch("{storeId:guid}/products/{productId:guid}/active")]
    public async Task<IActionResult> SetProductActive(Guid storeId, Guid productId, ActiveRequest req, CancellationToken ct)
    {
        await service.SetProductActiveAsync(User.UserId(), storeId, productId, req.Active, ct);
        return NoContent();
    }

    [HttpDelete("{storeId:guid}/products/{productId:guid}")]
    public async Task<IActionResult> DeleteProduct(Guid storeId, Guid productId, CancellationToken ct)
    {
        await service.DeleteProductAsync(User.UserId(), storeId, productId, ct);
        return NoContent();
    }
}
