using Microsoft.EntityFrameworkCore;
using Miga.Domain;
using Miga.Domain.Common;
using Miga.Domain.Entities;
using Miga.Infrastructure.Common;
using Miga.Infrastructure.Features.Catalog;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Features.MerchantCatalog;

public record StoreInput(string NameAr, string? NameEn, Guid StoreCategoryId, string? DescriptionAr, string? LogoUrl, string? CoverImageUrl, string? PickupAddress, Guid? CityId);

public record MerchantStoreDto(
    Guid Id, string NameAr, string NameEn, Guid StoreCategoryId, string CategoryName, string? DescriptionAr, string? LogoUrl, string? CoverImageUrl,
    string? PickupAddress, Guid? CityId, StoreStatus Status, bool IsVerified, decimal Rating, int ProductsCount, int CampaignsCount);

public record CategoryInput(string NameAr, string? NameEn, Guid? ParentCategoryId, int SortOrder);

public record ProductInput(
    Guid ProductCategoryId, string NameAr, string? NameEn, string? DescriptionAr, decimal Price, int StockQuantity, bool IsActive, IReadOnlyList<string> ImageUrls);

public record MerchantProductDto(
    Guid Id, Guid StoreId, Guid CategoryId, string CategoryName, string NameAr, string NameEn, string? DescriptionAr,
    decimal Price, int StockQuantity, bool IsActive, IReadOnlyList<string> Images, bool InActiveCampaign);

/// <summary>Merchant-side management. Every call checks the store belongs to the signed-in merchant.</summary>
public class MerchantCatalogService(MigaDbContext db)
{
    public const int MaxImages = 5;
    public const int MaxStores = 10;

    // ---------------- Stores ----------------

    public Task<List<MerchantStoreDto>> StoresAsync(Guid userId, CancellationToken ct) =>
        ProjectStores(db.Stores.Where(s => s.Merchant.UserId == userId).OrderBy(s => s.CreatedAt)).ToListAsync(ct);

    public async Task<MerchantStoreDto> StoreAsync(Guid userId, Guid storeId, CancellationToken ct) =>
        await ProjectStores(db.Stores.Where(s => s.Id == storeId && s.Merchant.UserId == userId)).FirstOrDefaultAsync(ct)
        ?? throw StoreNotFound();

    public async Task<MerchantStoreDto> CreateStoreAsync(Guid userId, StoreInput input, CancellationToken ct)
    {
        var merchant = await db.MerchantProfiles.Include(m => m.Stores).FirstOrDefaultAsync(m => m.UserId == userId, ct)
            ?? throw AppException.BadRequest("merchant_not_registered", "أكمل تسجيل بيانات النشاط التجاري أولًا");
        if (merchant.Stores.Count >= MaxStores) throw AppException.BadRequest("too_many_stores", $"الحد الأقصى {MaxStores} متاجر");

        var store = new Store { MerchantId = merchant.Id, IsVerified = merchant.IsVerified, Status = merchant.IsVerified ? StoreStatus.Active : StoreStatus.Inactive };
        await ApplyStoreAsync(store, input, ct);
        db.Stores.Add(store);
        await db.SaveChangesAsync(ct);
        return await StoreAsync(userId, store.Id, ct);
    }

    public async Task<MerchantStoreDto> UpdateStoreAsync(Guid userId, Guid storeId, StoreInput input, CancellationToken ct)
    {
        var store = await OwnedStoreAsync(userId, storeId, ct);
        await ApplyStoreAsync(store, input, ct);
        await db.SaveChangesAsync(ct);
        return await StoreAsync(userId, storeId, ct);
    }

    /// <summary>Merchant can pause / resume a verified store. Suspension is admin-only.</summary>
    public async Task<MerchantStoreDto> SetStoreActiveAsync(Guid userId, Guid storeId, bool active, CancellationToken ct)
    {
        var store = await OwnedStoreAsync(userId, storeId, ct);
        if (store.Status == StoreStatus.Suspended) throw AppException.Forbidden("store_suspended", "المتجر موقوف من الإدارة، تواصل مع الدعم");
        if (active && !store.IsVerified) throw AppException.BadRequest("store_not_verified", "لا يمكن تفعيل المتجر قبل التحقق منه");
        store.Status = active ? StoreStatus.Active : StoreStatus.Inactive;
        await db.SaveChangesAsync(ct);
        return await StoreAsync(userId, storeId, ct);
    }

    // ---------------- Product categories ----------------

    public async Task<List<ProductCategoryDto>> CategoriesAsync(Guid userId, Guid storeId, CancellationToken ct)
    {
        await OwnedStoreAsync(userId, storeId, ct);
        var all = await db.ProductCategories.AsNoTracking().Where(c => c.StoreId == storeId && c.IsActive).OrderBy(c => c.SortOrder).ThenBy(c => c.NameAr).ToListAsync(ct);
        return CatalogQueries.BuildTree(all);
    }

    public async Task<ProductCategoryDto> SaveCategoryAsync(Guid userId, Guid storeId, Guid? categoryId, CategoryInput input, CancellationToken ct)
    {
        await OwnedStoreAsync(userId, storeId, ct);
        var category = categoryId == null
            ? new ProductCategory { StoreId = storeId }
            : await db.ProductCategories.FirstOrDefaultAsync(c => c.Id == categoryId && c.StoreId == storeId && c.IsActive, ct) ?? throw CategoryNotFound();

        if (input.ParentCategoryId is { } parentId)
        {
            // Two levels only: a parent must itself be top-level, in the same store, and not the category itself.
            var parent = await db.ProductCategories.FirstOrDefaultAsync(c => c.Id == parentId && c.StoreId == storeId && c.IsActive, ct)
                ?? throw AppException.BadRequest("invalid_parent", "التصنيف الأب غير موجود");
            if (parent.Id == category.Id || parent.ParentCategoryId != null)
                throw AppException.BadRequest("invalid_parent", "يمكن إضافة تصنيفات فرعية تحت التصنيفات الرئيسية فقط");
            if (categoryId != null && await db.ProductCategories.AnyAsync(c => c.ParentCategoryId == categoryId, ct))
                throw AppException.BadRequest("invalid_parent", "هذا التصنيف لديه تصنيفات فرعية ولا يمكن جعله فرعيًا");
        }

        category.NameAr = input.NameAr.Trim();
        category.NameEn = input.NameEn?.Trim() ?? string.Empty;
        category.ParentCategoryId = input.ParentCategoryId;
        category.SortOrder = input.SortOrder;
        if (categoryId == null) db.ProductCategories.Add(category);
        await db.SaveChangesAsync(ct);
        return new ProductCategoryDto(category.Id, category.NameAr, category.NameEn, category.ParentCategoryId, category.SortOrder, []);
    }

    /// <summary>
    /// Removes a category and its sub-categories when they hold no live products. If deleted (archived) products
    /// still reference them, the categories are archived (IsActive = false) instead, keeping old orders consistent.
    /// </summary>
    public async Task DeleteCategoryAsync(Guid userId, Guid storeId, Guid categoryId, CancellationToken ct)
    {
        await OwnedStoreAsync(userId, storeId, ct);
        var ids = await db.ProductCategories.Where(c => c.StoreId == storeId && c.IsActive && (c.Id == categoryId || c.ParentCategoryId == categoryId))
            .Select(c => c.Id).ToListAsync(ct);
        if (!ids.Contains(categoryId)) throw CategoryNotFound();
        if (await db.Products.AnyAsync(p => ids.Contains(p.ProductCategoryId) && !p.IsDeleted, ct))
            throw AppException.Conflict("category_has_products", "انقل المنتجات إلى تصنيف آخر قبل حذف هذا التصنيف");

        if (await db.Products.AnyAsync(p => ids.Contains(p.ProductCategoryId), ct))
        {
            await db.ProductCategories.Where(c => ids.Contains(c.Id)).ExecuteUpdateAsync(s => s.SetProperty(c => c.IsActive, false), ct);
            return;
        }
        await db.ProductCategories.Where(c => c.ParentCategoryId == categoryId).ExecuteDeleteAsync(ct);
        await db.ProductCategories.Where(c => c.Id == categoryId).ExecuteDeleteAsync(ct);
    }

    // ---------------- Products ----------------

    public async Task<PagedResult<MerchantProductDto>> ProductsAsync(Guid userId, Guid storeId, Guid? categoryId, string? q, int page, int pageSize, CancellationToken ct)
    {
        await OwnedStoreAsync(userId, storeId, ct);
        var query = db.Products.Where(p => p.StoreId == storeId && !p.IsDeleted);
        if (categoryId is { } cat) query = query.Where(p => p.ProductCategoryId == cat || p.ProductCategory.ParentCategoryId == cat);
        if (!string.IsNullOrWhiteSpace(q)) query = query.Where(p => p.NameAr.Contains(q.Trim()) || p.NameEn.Contains(q.Trim()));
        return await ProjectProducts(query.OrderByDescending(p => p.CreatedAt)).ToPagedAsync(page, pageSize, ct);
    }

    public async Task<MerchantProductDto> ProductAsync(Guid userId, Guid storeId, Guid productId, CancellationToken ct)
    {
        await OwnedStoreAsync(userId, storeId, ct);
        return await ProjectProducts(db.Products.Where(p => p.Id == productId && p.StoreId == storeId && !p.IsDeleted)).FirstOrDefaultAsync(ct)
            ?? throw ProductNotFound();
    }

    public async Task<MerchantProductDto> SaveProductAsync(Guid userId, Guid storeId, Guid? productId, ProductInput input, CancellationToken ct)
    {
        await OwnedStoreAsync(userId, storeId, ct);
        if (!await db.ProductCategories.AnyAsync(c => c.Id == input.ProductCategoryId && c.StoreId == storeId && c.IsActive, ct))
            throw AppException.BadRequest("invalid_category", "التصنيف غير موجود في هذا المتجر");
        if (input.ImageUrls.Count > MaxImages) throw AppException.BadRequest("too_many_images", $"الحد الأقصى {MaxImages} صور");

        var product = productId == null
            ? new Product { StoreId = storeId }
            : await db.Products.Include(p => p.Images).FirstOrDefaultAsync(p => p.Id == productId && p.StoreId == storeId && !p.IsDeleted, ct) ?? throw ProductNotFound();

        product.ProductCategoryId = input.ProductCategoryId;
        product.NameAr = input.NameAr.Trim();
        product.NameEn = input.NameEn?.Trim() ?? string.Empty;
        product.DescriptionAr = input.DescriptionAr?.Trim();
        product.Price = input.Price;
        product.StockQuantity = input.StockQuantity;
        product.IsActive = input.IsActive;

        // Image order from the client is the display order; first = main.
        db.ProductImages.RemoveRange(product.Images);
        product.Images = input.ImageUrls.Select((url, i) => new ProductImage { ImageUrl = url, SortOrder = i, IsMain = i == 0 }).ToList();

        if (productId == null) db.Products.Add(product);
        await db.SaveChangesAsync(ct);
        return await ProductAsync(userId, storeId, product.Id, ct);
    }

    public async Task SetProductActiveAsync(Guid userId, Guid storeId, Guid productId, bool active, CancellationToken ct)
    {
        await OwnedStoreAsync(userId, storeId, ct);
        var product = await db.Products.FirstOrDefaultAsync(p => p.Id == productId && p.StoreId == storeId && !p.IsDeleted, ct) ?? throw ProductNotFound();
        if (!active && await HasLiveCampaignAsync(productId, ct))
            throw AppException.Conflict("product_in_campaign", "لا يمكن إخفاء منتج مرتبط بحملة نشطة");
        product.IsActive = active;
        await db.SaveChangesAsync(ct);
    }

    /// <summary>Soft delete (orders keep pointing to it). Blocked while a campaign is running.</summary>
    public async Task DeleteProductAsync(Guid userId, Guid storeId, Guid productId, CancellationToken ct)
    {
        await OwnedStoreAsync(userId, storeId, ct);
        var product = await db.Products.FirstOrDefaultAsync(p => p.Id == productId && p.StoreId == storeId && !p.IsDeleted, ct) ?? throw ProductNotFound();
        if (await HasLiveCampaignAsync(productId, ct)) throw AppException.Conflict("product_in_campaign", "لا يمكن حذف منتج مرتبط بحملة نشطة");
        product.IsDeleted = true;
        product.IsActive = false;
        await db.SaveChangesAsync(ct);
    }

    // ---------------- helpers ----------------

    private Task<bool> HasLiveCampaignAsync(Guid productId, CancellationToken ct) =>
        db.Campaigns.AnyAsync(c => c.ProductId == productId && (c.Status == CampaignStatus.Active || c.Status == CampaignStatus.Processing), ct);

    private async Task<Store> OwnedStoreAsync(Guid userId, Guid storeId, CancellationToken ct) =>
        await db.Stores.FirstOrDefaultAsync(s => s.Id == storeId && s.Merchant.UserId == userId, ct) ?? throw StoreNotFound();

    private async Task ApplyStoreAsync(Store store, StoreInput i, CancellationToken ct)
    {
        if (!await db.StoreCategories.AnyAsync(c => c.Id == i.StoreCategoryId && c.IsActive, ct))
            throw AppException.BadRequest("invalid_store_category", "قسم المتجر غير صحيح");
        if (i.CityId is { } cityId && !await db.Cities.AnyAsync(c => c.Id == cityId, ct))
            throw AppException.BadRequest("invalid_city", "المدينة غير صحيحة");

        store.NameAr = i.NameAr.Trim();
        store.NameEn = i.NameEn?.Trim() ?? string.Empty;
        store.StoreCategoryId = i.StoreCategoryId;
        store.DescriptionAr = i.DescriptionAr?.Trim();
        store.LogoUrl = i.LogoUrl;
        store.CoverImageUrl = i.CoverImageUrl;
        // Omitted city / pickup address keep the current value: an older app that doesn't send them must not
        // wipe them (a store without a city would be offered to drivers in every city).
        store.PickupAddress = i.PickupAddress?.Trim() ?? store.PickupAddress;
        store.CityId = i.CityId ?? store.CityId;
    }

    private static IQueryable<MerchantStoreDto> ProjectStores(IQueryable<Store> q) => q.Select(s => new MerchantStoreDto(
        s.Id, s.NameAr, s.NameEn, s.StoreCategoryId, s.StoreCategory.NameAr, s.DescriptionAr, s.LogoUrl, s.CoverImageUrl, s.PickupAddress, s.CityId,
        s.Status, s.IsVerified, s.Rating, s.Products.Count(p => !p.IsDeleted), s.Campaigns.Count()));

    private IQueryable<MerchantProductDto> ProjectProducts(IQueryable<Product> q) => q.Select(p => new MerchantProductDto(
        p.Id, p.StoreId, p.ProductCategoryId, p.ProductCategory.NameAr, p.NameAr, p.NameEn, p.DescriptionAr, p.Price, p.StockQuantity, p.IsActive,
        p.Images.OrderBy(i => i.SortOrder).Select(i => i.ImageUrl).ToList(),
        p.Campaigns.Any(c => c.Status == CampaignStatus.Active || c.Status == CampaignStatus.Processing)));

    private static AppException StoreNotFound() => AppException.NotFound("store_not_found", "المتجر غير موجود");
    private static AppException CategoryNotFound() => AppException.NotFound("category_not_found", "التصنيف غير موجود");
    private static AppException ProductNotFound() => AppException.NotFound("product_not_found", "المنتج غير موجود");
}
