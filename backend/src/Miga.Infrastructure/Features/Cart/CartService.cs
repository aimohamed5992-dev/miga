using Microsoft.EntityFrameworkCore;
using Miga.Domain;
using Miga.Domain.Common;
using Miga.Domain.Entities;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Features.Cart;

public record CartItemDto(
    Guid Id,
    Guid ProductId,
    string ProductName,
    string? ImageUrl,
    Guid? CampaignId,
    string? CampaignTitle,
    int? CampaignCurrentQuantity,
    int? CampaignTargetQuantity,
    int? MaxQuantityPerCustomer,
    int Quantity,
    decimal UnitPrice,
    decimal? OriginalPrice,
    decimal LineTotal,
    /// <summary>null when OK; otherwise campaign_ended / unavailable / price_changed.</summary>
    string? Issue);

public record CartStoreGroupDto(Guid StoreId, string StoreName, string? StoreLogoUrl, IReadOnlyList<CartItemDto> Items, decimal Subtotal);

public record CartDto(IReadOnlyList<CartStoreGroupDto> Stores, int ItemsCount, decimal Total, decimal Savings);

/// <summary>One active cart per customer; items are regular products or campaign participations, grouped by store.</summary>
public class CartService(MigaDbContext db, TimeProvider clock)
{
    private static readonly List<CampaignOrderStatus> Joined =
    [
        CampaignOrderStatus.Pending, CampaignOrderStatus.Paid, CampaignOrderStatus.Confirmed, CampaignOrderStatus.Preparing,
        CampaignOrderStatus.ReadyForDelivery, CampaignOrderStatus.OutForDelivery, CampaignOrderStatus.Delivered,
    ];

    public async Task<CartDto> GetAsync(Guid userId, CancellationToken ct)
    {
        var cart = await GetOrCreateAsync(userId, ct);
        var now = clock.GetUtcNow().UtcDateTime;

        var rows = await db.CartItems.AsNoTracking().Where(i => i.CartId == cart.Id).OrderBy(i => i.CreatedAt).Select(i => new
        {
            i.Id, i.ProductId, ProductName = i.Product.NameAr,
            Image = i.Product.Images.OrderBy(x => x.SortOrder).Select(x => x.ImageUrl).FirstOrDefault(),
            i.Product.StoreId, StoreName = i.Product.Store.NameAr, StoreLogo = i.Product.Store.LogoUrl,
            ProductAvailable = i.Product.IsActive && !i.Product.IsDeleted && i.Product.Store.Status == StoreStatus.Active,
            ProductPrice = i.Product.Price,
            i.CampaignId,
            CampaignTitle = i.Campaign != null ? i.Campaign.TitleAr : null,
            CampaignCurrent = i.Campaign != null ? (int?)i.Campaign.CurrentQuantity : null,
            CampaignTarget = i.Campaign != null ? (int?)i.Campaign.TargetQuantity : null,
            MaxPer = i.Campaign != null ? i.Campaign.MaxQuantityPerCustomer : null,
            CampaignLive = i.Campaign != null && i.Campaign.Status == CampaignStatus.Active && i.Campaign.StartDate <= now && i.Campaign.EndDate > now,
            CampaignPrice = i.Campaign != null ? (decimal?)i.Campaign.CampaignPrice : null,
            OriginalPrice = i.Campaign != null ? (decimal?)i.Campaign.OriginalPrice : null,
            i.Quantity, i.UnitPrice,
        }).ToListAsync(ct);

        var items = rows.Select(r =>
        {
            var currentPrice = r.CampaignPrice ?? r.ProductPrice;
            var issue = !r.ProductAvailable ? "unavailable"
                : r.CampaignId != null && !r.CampaignLive ? "campaign_ended"
                : currentPrice != r.UnitPrice ? "price_changed"
                : null;
            return (r.StoreId, r.StoreName, r.StoreLogo, Item: new CartItemDto(
                r.Id, r.ProductId, r.ProductName, r.Image, r.CampaignId, r.CampaignTitle, r.CampaignCurrent, r.CampaignTarget, r.MaxPer,
                r.Quantity, currentPrice, r.OriginalPrice, currentPrice * r.Quantity, issue));
        }).ToList();

        var groups = items.GroupBy(x => (x.StoreId, x.StoreName, x.StoreLogo))
            .Select(g => new CartStoreGroupDto(g.Key.StoreId, g.Key.StoreName, g.Key.StoreLogo, g.Select(x => x.Item).ToList(), g.Sum(x => x.Item.LineTotal)))
            .ToList();
        return new CartDto(
            groups,
            items.Sum(x => x.Item.Quantity),
            items.Sum(x => x.Item.LineTotal),
            items.Where(x => x.Item.OriginalPrice != null).Sum(x => (x.Item.OriginalPrice!.Value - x.Item.UnitPrice) * x.Item.Quantity));
    }

    /// <summary>Adds (or merges into) a cart line. Campaign lines are validated against limits and prior participation.</summary>
    public async Task<CartDto> AddAsync(Guid userId, Guid productId, Guid? campaignId, int quantity, CancellationToken ct)
    {
        if (quantity < 1) throw AppException.BadRequest("invalid_quantity", "الكمية غير صحيحة");
        var cart = await GetOrCreateAsync(userId, ct);
        var existing = await db.CartItems.FirstOrDefaultAsync(i => i.CartId == cart.Id && i.ProductId == productId && i.CampaignId == campaignId, ct);
        var total = quantity + (existing?.Quantity ?? 0);
        var price = await ValidateAsync(userId, productId, campaignId, total, ct);

        if (existing == null)
        {
            db.CartItems.Add(new CartItem { CartId = cart.Id, ProductId = productId, CampaignId = campaignId, Quantity = total, UnitPrice = price });
        }
        else
        {
            existing.Quantity = total;
            existing.UnitPrice = price;
            existing.UpdatedAt = clock.GetUtcNow().UtcDateTime;
        }
        cart.UpdatedAt = clock.GetUtcNow().UtcDateTime;
        await db.SaveChangesAsync(ct);
        return await GetAsync(userId, ct);
    }

    public async Task<CartDto> SetQuantityAsync(Guid userId, Guid itemId, int quantity, CancellationToken ct)
    {
        var item = await OwnedItemAsync(userId, itemId, ct);
        if (quantity <= 0)
        {
            db.CartItems.Remove(item);
        }
        else
        {
            item.UnitPrice = await ValidateAsync(userId, item.ProductId, item.CampaignId, quantity, ct);
            item.Quantity = quantity;
            item.UpdatedAt = clock.GetUtcNow().UtcDateTime;
        }
        await db.SaveChangesAsync(ct);
        return await GetAsync(userId, ct);
    }

    public async Task<CartDto> RemoveAsync(Guid userId, Guid itemId, CancellationToken ct)
    {
        db.CartItems.Remove(await OwnedItemAsync(userId, itemId, ct));
        await db.SaveChangesAsync(ct);
        return await GetAsync(userId, ct);
    }

    public async Task ClearAsync(Guid userId, CancellationToken ct)
    {
        var cart = await GetOrCreateAsync(userId, ct);
        await db.CartItems.Where(i => i.CartId == cart.Id).ExecuteDeleteAsync(ct);
    }

    internal async Task<Domain.Entities.Cart> GetOrCreateAsync(Guid userId, CancellationToken ct)
    {
        var profile = await db.CustomerProfiles.FirstOrDefaultAsync(p => p.UserId == userId, ct);
        if (profile == null)
        {
            profile = new CustomerProfile { UserId = userId };
            db.CustomerProfiles.Add(profile);
        }
        var cart = await db.Carts.FirstOrDefaultAsync(c => c.CustomerId == profile.Id && c.IsActive, ct);
        if (cart == null)
        {
            cart = new Domain.Entities.Cart { CustomerId = profile.Id };
            db.Carts.Add(cart);
            await db.SaveChangesAsync(ct);
        }
        return cart;
    }

    /// <summary>Returns the unit price to use, or throws with an Arabic reason.</summary>
    private async Task<decimal> ValidateAsync(Guid userId, Guid productId, Guid? campaignId, int quantity, CancellationToken ct)
    {
        var product = await db.Products.AsNoTracking()
            .Where(p => p.Id == productId && p.IsActive && !p.IsDeleted && p.Store.Status == StoreStatus.Active && p.Store.IsVerified)
            .Select(p => new { p.Price, p.StockQuantity })
            .FirstOrDefaultAsync(ct) ?? throw AppException.BadRequest("product_unavailable", "المنتج غير متاح حاليًا");

        if (campaignId == null)
        {
            if (quantity > product.StockQuantity) throw AppException.BadRequest("out_of_stock", $"الكمية المتاحة {product.StockQuantity} فقط");
            return product.Price;
        }

        var now = clock.GetUtcNow().UtcDateTime;
        var campaign = await db.Campaigns.AsNoTracking().Where(c => c.Id == campaignId && c.ProductId == productId)
            .Select(c => new { c.Status, c.StartDate, c.EndDate, c.CampaignPrice, c.MaxQuantityPerCustomer, c.TargetQuantity, c.CurrentQuantity })
            .FirstOrDefaultAsync(ct) ?? throw AppException.BadRequest("campaign_not_found", "الحملة غير موجودة");

        if (campaign.Status != CampaignStatus.Active || campaign.StartDate > now || campaign.EndDate <= now)
            throw AppException.BadRequest("campaign_not_active", "الحملة غير متاحة للانضمام");
        if (campaign.MaxQuantityPerCustomer is { } max && quantity > max)
            throw AppException.BadRequest("max_per_customer", $"الحد الأقصى لكل عميل في هذه الحملة {max} قطع");
        var remaining = campaign.TargetQuantity - campaign.CurrentQuantity;
        if (quantity > remaining) throw AppException.BadRequest("not_enough_quantity", $"باقي {remaining} قطعة فقط لاكتمال الحملة");
        if (await db.CampaignOrders.AnyAsync(o => o.CampaignId == campaignId && o.CustomerId == userId && Joined.Contains(o.Status), ct))
            throw AppException.Conflict("already_joined", "انضممت لهذه الحملة مسبقًا، تابع طلبك من صفحة طلباتي");
        return campaign.CampaignPrice;
    }

    private async Task<CartItem> OwnedItemAsync(Guid userId, Guid itemId, CancellationToken ct) =>
        await db.CartItems.FirstOrDefaultAsync(i => i.Id == itemId && i.Cart.Customer.UserId == userId, ct)
        ?? throw AppException.NotFound("cart_item_not_found", "العنصر غير موجود في السلة");
}
