using Microsoft.EntityFrameworkCore;
using Miga.Domain;
using Miga.Domain.Common;
using Miga.Domain.Entities;
using Miga.Infrastructure.Features.Catalog;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Features.Marketing;

public record BannerInput(
    string ImageUrl, string? TitleAr, string? SubtitleAr, string? ButtonLabelAr, string LinkType, Guid? LinkId, int SortOrder, bool IsActive,
    DateTime? StartsAt, DateTime? EndsAt);

/// <summary>Admin view of a banner, with the linked item's name so the list reads without lookups.</summary>
public record AdminBannerDto(
    Guid Id, string ImageUrl, string? TitleAr, string? SubtitleAr, string? ButtonLabelAr, string LinkType, Guid? LinkId, string? LinkTitle,
    int SortOrder, bool IsActive, DateTime? StartsAt, DateTime? EndsAt, DateTime CreatedAt);

/// <summary>Home banners (admin-managed) and customers' favorite campaigns.</summary>
public class MarketingService(MigaDbContext db)
{
    // ---------------- banners (admin) ----------------

    public async Task<List<AdminBannerDto>> BannersAsync(CancellationToken ct)
    {
        var rows = await db.Banners.AsNoTracking().OrderBy(b => b.SortOrder).ThenBy(b => b.CreatedAt).ToListAsync(ct);
        var result = new List<AdminBannerDto>(rows.Count);
        foreach (var b in rows) result.Add(await ToDtoAsync(b, ct));
        return result;
    }

    public async Task<AdminBannerDto> SaveBannerAsync(Guid? id, BannerInput i, CancellationToken ct)
    {
        var type = ParseLink(i.LinkType);
        if (string.IsNullOrWhiteSpace(i.ImageUrl)) throw AppException.BadRequest("image_required", "أضف صورة البانر");
        if (type != BannerLinkType.None)
        {
            if (i.LinkId is not { } linkId) throw AppException.BadRequest("link_required", "اختر العنصر المرتبط بالبانر");
            var exists = type switch
            {
                BannerLinkType.Campaign => await db.Campaigns.AnyAsync(c => c.Id == linkId && c.Status != CampaignStatus.Draft, ct),
                BannerLinkType.Product => await db.Products.AnyAsync(p => p.Id == linkId && !p.IsDeleted, ct),
                BannerLinkType.Store => await db.Stores.AnyAsync(s => s.Id == linkId, ct),
                BannerLinkType.StoreCategory => await db.StoreCategories.AnyAsync(c => c.Id == linkId, ct),
                _ => true,
            };
            if (!exists) throw AppException.BadRequest("invalid_link", "العنصر المرتبط غير موجود");
        }
        if (i.StartsAt is { } s && i.EndsAt is { } e && e <= s) throw AppException.BadRequest("invalid_schedule", "تاريخ الانتهاء يجب أن يكون بعد البداية");

        var b = id == null ? new Banner() : await db.Banners.FirstOrDefaultAsync(x => x.Id == id, ct) ?? throw NotFound();
        b.ImageUrl = i.ImageUrl.Trim();
        b.TitleAr = Clean(i.TitleAr);
        b.SubtitleAr = Clean(i.SubtitleAr);
        b.ButtonLabelAr = Clean(i.ButtonLabelAr);
        b.LinkType = type;
        b.LinkId = type == BannerLinkType.None ? null : i.LinkId;
        b.SortOrder = i.SortOrder;
        b.IsActive = i.IsActive;
        b.StartsAt = i.StartsAt;
        b.EndsAt = i.EndsAt;
        if (id == null) db.Banners.Add(b);
        await db.SaveChangesAsync(ct);
        return await ToDtoAsync(b, ct);
    }

    public async Task DeleteBannerAsync(Guid id, CancellationToken ct)
    {
        var b = await db.Banners.FirstOrDefaultAsync(x => x.Id == id, ct) ?? throw NotFound();
        db.Banners.Remove(b);
        await db.SaveChangesAsync(ct);
    }

    private async Task<AdminBannerDto> ToDtoAsync(Banner b, CancellationToken ct)
    {
        var title = b.LinkId is not { } id ? null : b.LinkType switch
        {
            BannerLinkType.Campaign => await db.Campaigns.Where(c => c.Id == id).Select(c => c.TitleAr).FirstOrDefaultAsync(ct),
            BannerLinkType.Product => await db.Products.Where(p => p.Id == id).Select(p => p.NameAr).FirstOrDefaultAsync(ct),
            BannerLinkType.Store => await db.Stores.Where(s => s.Id == id).Select(s => s.NameAr).FirstOrDefaultAsync(ct),
            BannerLinkType.StoreCategory => await db.StoreCategories.Where(c => c.Id == id).Select(c => c.NameAr).FirstOrDefaultAsync(ct),
            _ => null,
        };
        return new AdminBannerDto(b.Id, b.ImageUrl, b.TitleAr, b.SubtitleAr, b.ButtonLabelAr, CatalogQueries.LinkName(b.LinkType), b.LinkId, title,
            b.SortOrder, b.IsActive, b.StartsAt, b.EndsAt, b.CreatedAt);
    }

    private static BannerLinkType ParseLink(string? s) => s switch
    {
        "campaign" => BannerLinkType.Campaign,
        "product" => BannerLinkType.Product,
        "store" => BannerLinkType.Store,
        "storeCategory" => BannerLinkType.StoreCategory,
        "none" or null or "" => BannerLinkType.None,
        _ => throw AppException.BadRequest("invalid_link_type", "نوع الرابط غير صحيح"),
    };

    private static string? Clean(string? v) => string.IsNullOrWhiteSpace(v) ? null : v.Trim();
    private static AppException NotFound() => AppException.NotFound("banner_not_found", "البانر غير موجود");

    // ---------------- favorites (customer) ----------------

    public async Task AddFavoriteAsync(Guid userId, Guid campaignId, CancellationToken ct)
    {
        if (!await db.Campaigns.AnyAsync(c => c.Id == campaignId && c.Status != CampaignStatus.Draft, ct))
            throw AppException.NotFound("campaign_not_found", "الحملة غير موجودة");
        if (await db.FavoriteCampaigns.AnyAsync(f => f.UserId == userId && f.CampaignId == campaignId, ct)) return;
        db.FavoriteCampaigns.Add(new FavoriteCampaign { UserId = userId, CampaignId = campaignId });
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            // Double tap: the unique index already holds it.
        }
    }

    public Task RemoveFavoriteAsync(Guid userId, Guid campaignId, CancellationToken ct) =>
        db.FavoriteCampaigns.Where(f => f.UserId == userId && f.CampaignId == campaignId).ExecuteDeleteAsync(ct);
}
