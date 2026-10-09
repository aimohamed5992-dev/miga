using Microsoft.EntityFrameworkCore;
using Miga.Domain;
using Miga.Domain.Common;
using Miga.Domain.Entities;
using Miga.Infrastructure.Common;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Features.Catalog;

public record StoreCategoryDto(Guid Id, string NameAr, string NameEn, string? ImageUrl);

public record StoreSummaryDto(Guid Id, string NameAr, string? LogoUrl, string? CoverImageUrl, Guid CategoryId, string CategoryName, decimal Rating, bool IsVerified, int ActiveCampaigns);

public record StoreDetailDto(
    Guid Id, string NameAr, string NameEn, string? DescriptionAr, string? LogoUrl, string? CoverImageUrl,
    Guid CategoryId, string CategoryName, decimal Rating, bool IsVerified, int ActiveCampaigns, int ProductsCount, int Participants);

public record ProductCategoryDto(Guid Id, string NameAr, string NameEn, Guid? ParentId, int SortOrder, IReadOnlyList<ProductCategoryDto> Children);

public record ProductSummaryDto(Guid Id, Guid StoreId, Guid CategoryId, string NameAr, decimal Price, int StockQuantity, string? MainImageUrl, Guid? ActiveCampaignId);

public record ProductDetailDto(
    Guid Id, Guid StoreId, string StoreName, Guid CategoryId, string CategoryName, string NameAr, string NameEn,
    string? DescriptionAr, decimal Price, int StockQuantity, IReadOnlyList<string> Images, CampaignSummaryDto? ActiveCampaign);

public record CampaignSummaryDto(
    Guid Id, Guid StoreId, string StoreName, Guid ProductId, string ProductName, string? ImageUrl, string TitleAr,
    decimal OriginalPrice, decimal CampaignPrice, int DiscountPercent, int TargetQuantity, int CurrentQuantity,
    int ParticipantsCount, int? MaxQuantityPerCustomer, DateTime StartDate, DateTime EndDate, CampaignStatus Status);

public record CampaignDetailDto(CampaignSummaryDto Campaign, string? DescriptionAr, string? ProductDescriptionAr, IReadOnlyList<string> Images, StoreSummaryDto Store);

/// <summary>Home slide; <c>LinkType</c> is none · campaign · product · store · storeCategory.</summary>
public record BannerDto(Guid Id, string ImageUrl, string? TitleAr, string? SubtitleAr, string? ButtonLabelAr, string LinkType, Guid? LinkId);

public record HomeDto(
    IReadOnlyList<BannerDto> Banners,
    IReadOnlyList<StoreCategoryDto> Categories,
    IReadOnlyList<CampaignSummaryDto> EndingSoon,
    IReadOnlyList<CampaignSummaryDto> AlmostComplete,
    IReadOnlyList<StoreSummaryDto> FeaturedStores,
    IReadOnlyList<CampaignSummaryDto> Latest);

public record SearchDto(IReadOnlyList<CampaignSummaryDto> Campaigns, IReadOnlyList<ProductSummaryDto> Products, IReadOnlyList<StoreSummaryDto> Stores);

public enum CampaignSort
{
    Newest,
    EndingSoon,
    AlmostComplete,
    BiggestDiscount,
}

public record CampaignQuery(Guid? StoreId = null, Guid? StoreCategoryId = null, string? Q = null, CampaignSort Sort = CampaignSort.Newest, int Page = 1, int PageSize = 20);

/// <summary>
/// Read side of the customer app. Only verified, active stores are visible; campaigns must be Active and
/// inside their time window. Everything is projected in SQL (no entity loading).
/// </summary>
public class CatalogQueries(MigaDbContext db, TimeProvider clock)
{
    // Orders that count as real participation (paid and not cancelled/refunded).
    // A List, not an array: with C# 14, array.Contains binds to the span overload which EF Core 9 can't translate.
    private static readonly List<CampaignOrderStatus> Participating =
    [
        CampaignOrderStatus.Paid, CampaignOrderStatus.Confirmed, CampaignOrderStatus.Preparing,
        CampaignOrderStatus.ReadyForDelivery, CampaignOrderStatus.OutForDelivery, CampaignOrderStatus.Delivered,
    ];

    private DateTime Now => clock.GetUtcNow().UtcDateTime;

    private IQueryable<Store> VisibleStores => db.Stores.Where(s => s.Status == StoreStatus.Active && s.IsVerified);

    private IQueryable<Campaign> LiveCampaigns
    {
        get
        {
            var now = Now;
            return db.Campaigns.Where(c => c.Status == CampaignStatus.Active && c.IsActive && c.StartDate <= now && c.EndDate > now
                && c.Store.Status == StoreStatus.Active && c.Store.IsVerified);
        }
    }

    public Task<List<StoreCategoryDto>> StoreCategoriesAsync(CancellationToken ct) =>
        db.StoreCategories.AsNoTracking().Where(c => c.IsActive).OrderBy(c => c.SortOrder)
            .Select(c => new StoreCategoryDto(c.Id, c.NameAr, c.NameEn, c.ImageUrl)).ToListAsync(ct);

    public async Task<HomeDto> HomeAsync(CancellationToken ct)
    {
        var now = Now;
        return new HomeDto(
            await BannersAsync(ct),
            await StoreCategoriesAsync(ct),
            await ProjectCampaigns(LiveCampaigns.Where(c => c.EndDate <= now.AddHours(48)).OrderBy(c => c.EndDate)).Take(10).ToListAsync(ct),
            await ProjectCampaigns(LiveCampaigns.Where(c => c.CurrentQuantity * 4 >= c.TargetQuantity * 3)
                .OrderByDescending(c => (double)c.CurrentQuantity / c.TargetQuantity)).Take(10).ToListAsync(ct),
            await ProjectStores(VisibleStores.OrderByDescending(s => s.Rating)).Take(10).ToListAsync(ct),
            await ProjectCampaigns(LiveCampaigns.OrderByDescending(c => c.StartDate)).Take(20).ToListAsync(ct));
    }

    /// <summary>Active, in-schedule banners in admin order.</summary>
    public async Task<List<BannerDto>> BannersAsync(CancellationToken ct)
    {
        var now = Now;
        var rows = await db.Banners.AsNoTracking()
            .Where(b => b.IsActive && (b.StartsAt == null || b.StartsAt <= now) && (b.EndsAt == null || b.EndsAt > now))
            .OrderBy(b => b.SortOrder).ThenBy(b => b.CreatedAt).ToListAsync(ct);
        return rows.Select(b => new BannerDto(b.Id, b.ImageUrl, b.TitleAr, b.SubtitleAr, b.ButtonLabelAr, LinkName(b.LinkType), b.LinkId)).ToList();
    }

    public static string LinkName(BannerLinkType t) => t switch
    {
        BannerLinkType.Campaign => "campaign",
        BannerLinkType.Product => "product",
        BannerLinkType.Store => "store",
        BannerLinkType.StoreCategory => "storeCategory",
        _ => "none",
    };

    /// <summary>The customer's saved campaigns (any status, newest saved first) — ended ones stay visible so the list explains itself.</summary>
    public async Task<List<CampaignSummaryDto>> FavoritesAsync(Guid userId, CancellationToken ct)
    {
        var ids = await db.FavoriteCampaigns.AsNoTracking().Where(f => f.UserId == userId).OrderByDescending(f => f.CreatedAt)
            .Select(f => f.CampaignId).ToListAsync(ct);
        var rows = await ProjectCampaigns(db.Campaigns.Where(c => ids.Contains(c.Id))).ToListAsync(ct);
        return ids.Select(id => rows.FirstOrDefault(r => r.Id == id)).Where(r => r != null).Select(r => r!).ToList();
    }

    public Task<PagedResult<CampaignSummaryDto>> CampaignsAsync(CampaignQuery q, CancellationToken ct)
    {
        var query = LiveCampaigns;
        if (q.StoreId is { } storeId) query = query.Where(c => c.StoreId == storeId);
        if (q.StoreCategoryId is { } catId) query = query.Where(c => c.Store.StoreCategoryId == catId);
        if (!string.IsNullOrWhiteSpace(q.Q))
        {
            var term = q.Q.Trim();
            query = query.Where(c => c.TitleAr.Contains(term) || c.Product.NameAr.Contains(term) || c.Product.NameEn.Contains(term));
        }

        var now = Now;
        query = q.Sort switch
        {
            CampaignSort.EndingSoon => query.Where(c => c.EndDate <= now.AddDays(3)).OrderBy(c => c.EndDate),
            CampaignSort.AlmostComplete => query.Where(c => c.CurrentQuantity * 10 >= c.TargetQuantity * 6)
                .OrderByDescending(c => (double)c.CurrentQuantity / c.TargetQuantity),
            CampaignSort.BiggestDiscount => query.OrderByDescending(c => (c.OriginalPrice - c.CampaignPrice) / c.OriginalPrice),
            _ => query.OrderByDescending(c => c.StartDate),
        };
        return ProjectCampaigns(query).ToPagedAsync(q.Page, q.PageSize, ct);
    }

    /// <summary>Any non-draft status: customers open completed / failed campaigns from their order history.</summary>
    public async Task<CampaignDetailDto> CampaignAsync(Guid id, CancellationToken ct)
    {
        var campaign = await ProjectCampaigns(db.Campaigns.Where(c => c.Id == id && c.Status != CampaignStatus.Draft)).FirstOrDefaultAsync(ct)
            ?? throw AppException.NotFound("campaign_not_found", "الحملة غير موجودة");
        var extra = await db.Campaigns.Where(c => c.Id == id).Select(c => new
        {
            c.DescriptionAr,
            ProductDescription = c.Product.DescriptionAr,
            Images = c.Product.Images.OrderBy(i => i.SortOrder).Select(i => i.ImageUrl).ToList(),
        }).FirstAsync(ct);
        var store = await ProjectStores(db.Stores.Where(s => s.Id == campaign.StoreId)).FirstAsync(ct);
        return new CampaignDetailDto(campaign, extra.DescriptionAr, extra.ProductDescription, extra.Images, store);
    }

    public Task<PagedResult<StoreSummaryDto>> StoresAsync(Guid? categoryId, string? q, int page, int pageSize, CancellationToken ct)
    {
        var query = VisibleStores;
        if (categoryId is { } cat) query = query.Where(s => s.StoreCategoryId == cat);
        if (!string.IsNullOrWhiteSpace(q)) query = query.Where(s => s.NameAr.Contains(q.Trim()) || s.NameEn.Contains(q.Trim()));
        return ProjectStores(query.OrderByDescending(s => s.Rating).ThenBy(s => s.NameAr)).ToPagedAsync(page, pageSize, ct);
    }

    public async Task<StoreDetailDto> StoreAsync(Guid id, CancellationToken ct)
    {
        var now = Now;
        return await VisibleStores.Where(s => s.Id == id).Select(s => new StoreDetailDto(
                s.Id, s.NameAr, s.NameEn, s.DescriptionAr, s.LogoUrl, s.CoverImageUrl, s.StoreCategoryId, s.StoreCategory.NameAr, s.Rating, s.IsVerified,
                s.Campaigns.Count(c => c.Status == CampaignStatus.Active && c.EndDate > now),
                s.Products.Count(p => p.IsActive && !p.IsDeleted),
                s.Campaigns.SelectMany(c => c.Orders).Count(o => Participating.Contains(o.Status))))
            .FirstOrDefaultAsync(ct) ?? throw AppException.NotFound("store_not_found", "المتجر غير موجود");
    }

    public async Task<List<ProductCategoryDto>> StoreProductCategoriesAsync(Guid storeId, CancellationToken ct)
    {
        var all = await db.ProductCategories.AsNoTracking().Where(c => c.StoreId == storeId && c.IsActive)
            .OrderBy(c => c.SortOrder).ThenBy(c => c.NameAr).ToListAsync(ct);
        return BuildTree(all);
    }

    public Task<PagedResult<ProductSummaryDto>> StoreProductsAsync(Guid storeId, Guid? categoryId, string? q, int page, int pageSize, CancellationToken ct)
    {
        var query = db.Products.Where(p => p.StoreId == storeId && p.IsActive && !p.IsDeleted && p.Store.Status == StoreStatus.Active && p.Store.IsVerified);
        // A parent category includes its sub-categories.
        if (categoryId is { } cat) query = query.Where(p => p.ProductCategoryId == cat || p.ProductCategory.ParentCategoryId == cat);
        if (!string.IsNullOrWhiteSpace(q)) query = query.Where(p => p.NameAr.Contains(q.Trim()) || p.NameEn.Contains(q.Trim()));
        return ProjectProducts(query.OrderBy(p => p.NameAr)).ToPagedAsync(page, pageSize, ct);
    }

    public async Task<ProductDetailDto> ProductAsync(Guid id, CancellationToken ct)
    {
        var p = await db.Products.AsNoTracking()
            .Where(x => x.Id == id && x.IsActive && !x.IsDeleted && x.Store.Status == StoreStatus.Active && x.Store.IsVerified)
            .Select(x => new
            {
                x.Id, x.StoreId, StoreName = x.Store.NameAr, x.ProductCategoryId, CategoryName = x.ProductCategory.NameAr,
                x.NameAr, x.NameEn, x.DescriptionAr, x.Price, x.StockQuantity,
                Images = x.Images.OrderBy(i => i.SortOrder).Select(i => i.ImageUrl).ToList(),
            })
            .FirstOrDefaultAsync(ct) ?? throw AppException.NotFound("product_not_found", "المنتج غير موجود");

        var campaign = await ProjectCampaigns(LiveCampaigns.Where(c => c.ProductId == id).OrderBy(c => c.CampaignPrice)).FirstOrDefaultAsync(ct);
        return new ProductDetailDto(p.Id, p.StoreId, p.StoreName, p.ProductCategoryId, p.CategoryName, p.NameAr, p.NameEn, p.DescriptionAr,
            p.Price, p.StockQuantity, p.Images, campaign);
    }

    public async Task<SearchDto> SearchAsync(string q, CancellationToken ct)
    {
        var term = q.Trim();
        if (term.Length < 1) return new SearchDto([], [], []);
        return new SearchDto(
            (await CampaignsAsync(new CampaignQuery(Q: term, PageSize: 10), ct)).Items,
            await ProjectProducts(db.Products.Where(p => p.IsActive && !p.IsDeleted && p.Store.Status == StoreStatus.Active && p.Store.IsVerified
                && (p.NameAr.Contains(term) || p.NameEn.Contains(term))).OrderBy(p => p.NameAr)).Take(10).ToListAsync(ct),
            await ProjectStores(VisibleStores.Where(s => s.NameAr.Contains(term) || s.NameEn.Contains(term))).Take(10).ToListAsync(ct));
    }

    // ---------------- projections ----------------

    private IQueryable<CampaignSummaryDto> ProjectCampaigns(IQueryable<Campaign> q) => q.Select(c => new CampaignSummaryDto(
        c.Id, c.StoreId, c.Store.NameAr, c.ProductId, c.Product.NameAr,
        c.Product.Images.OrderBy(i => i.SortOrder).Select(i => i.ImageUrl).FirstOrDefault(),
        c.TitleAr, c.OriginalPrice, c.CampaignPrice,
        (int)Math.Round((c.OriginalPrice - c.CampaignPrice) / c.OriginalPrice * 100),
        c.TargetQuantity, c.CurrentQuantity,
        // One order per customer per campaign (enforced at checkout), so counting orders = counting participants.
        // Avoids COUNT(DISTINCT) in a correlated derived table, which MariaDB 10.4 can't resolve.
        c.Orders.Count(o => Participating.Contains(o.Status)),
        c.MaxQuantityPerCustomer, c.StartDate, c.EndDate, c.Status));

    private IQueryable<StoreSummaryDto> ProjectStores(IQueryable<Store> q)
    {
        var now = Now;
        return q.Select(s => new StoreSummaryDto(
            s.Id, s.NameAr, s.LogoUrl, s.CoverImageUrl, s.StoreCategoryId, s.StoreCategory.NameAr, s.Rating, s.IsVerified,
            s.Campaigns.Count(c => c.Status == CampaignStatus.Active && c.EndDate > now)));
    }

    private IQueryable<ProductSummaryDto> ProjectProducts(IQueryable<Product> q)
    {
        var now = Now;
        return q.Select(p => new ProductSummaryDto(
            p.Id, p.StoreId, p.ProductCategoryId, p.NameAr, p.Price, p.StockQuantity,
            p.Images.OrderBy(i => i.SortOrder).Select(i => i.ImageUrl).FirstOrDefault(),
            p.Campaigns.Where(c => c.Status == CampaignStatus.Active && c.StartDate <= now && c.EndDate > now).Select(c => (Guid?)c.Id).FirstOrDefault()));
    }

    internal static List<ProductCategoryDto> BuildTree(List<ProductCategory> all)
    {
        ProductCategoryDto Map(ProductCategory c) =>
            new(c.Id, c.NameAr, c.NameEn, c.ParentCategoryId, c.SortOrder, all.Where(x => x.ParentCategoryId == c.Id).Select(Map).ToList());
        return all.Where(c => c.ParentCategoryId == null).Select(Map).ToList();
    }
}
