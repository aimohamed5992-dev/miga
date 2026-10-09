using Microsoft.EntityFrameworkCore;
using Miga.Domain;
using Miga.Domain.Common;
using Miga.Domain.Entities;
using Miga.Infrastructure.Common;
using Miga.Infrastructure.Features.Orders;
using Miga.Infrastructure.Notifications;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Features.MerchantSales;

public record CampaignInput(
    Guid StoreId,
    Guid ProductId,
    string TitleAr,
    string? TitleEn,
    string? DescriptionAr,
    decimal? OriginalPrice,
    decimal CampaignPrice,
    int TargetQuantity,
    int? MaxQuantityPerCustomer,
    DateTime? StartDate,
    int DurationDays,
    bool Publish);

public record MerchantCampaignDto(
    Guid Id, Guid StoreId, string StoreName, Guid ProductId, string ProductName, string? ImageUrl, string TitleAr, string? DescriptionAr,
    decimal OriginalPrice, decimal CampaignPrice, int DiscountPercent, int TargetQuantity, int CurrentQuantity, int? MaxQuantityPerCustomer,
    int ParticipantsCount, decimal CollectedAmount, DateTime StartDate, DateTime EndDate, CampaignStatus Status, Guid? MerchantOrderId);

public record ParticipantDto(Guid OrderId, string MaskedName, string District, int Quantity, decimal Amount, CampaignOrderStatus Status, DateTime CreatedAt);

public enum MerchantCampaignTab
{
    Active,
    Done,
    Ended,
    Draft,
}

/// <summary>Merchant side of campaigns: create (draft / publish), list by tab, participants, extend, cancel.</summary>
/// <summary>Partial campaign edit — null means unchanged; MaxQuantityPerCustomer = 0 removes the limit.</summary>
public record CampaignEdit(
    string? TitleAr, string? DescriptionAr, decimal? OriginalPrice, decimal? CampaignPrice, int? TargetQuantity, int? MaxQuantityPerCustomer, DateTime? EndsAt);

public class MerchantCampaignService(MigaDbContext db, CampaignLifecycleService lifecycle, Notifier notifier, TimeProvider clock)
{
    public const int MaxDurationDays = 30;
    public const int MaxTotalDays = 60;

    private static readonly List<CampaignOrderStatus> Participating =
    [
        CampaignOrderStatus.Paid, CampaignOrderStatus.Confirmed, CampaignOrderStatus.Preparing,
        CampaignOrderStatus.ReadyForDelivery, CampaignOrderStatus.OutForDelivery, CampaignOrderStatus.Delivered,
    ];

    public Task<PagedResult<MerchantCampaignDto>> ListAsync(Guid userId, MerchantCampaignTab tab, Guid? storeId, int page, int pageSize, CancellationToken ct)
    {
        var q = db.Campaigns.Where(c => c.MerchantUserId == userId);
        if (storeId is { } s) q = q.Where(c => c.StoreId == s);
        q = tab switch
        {
            MerchantCampaignTab.Active => q.Where(c => c.Status == CampaignStatus.Active),
            MerchantCampaignTab.Done => q.Where(c => c.Status == CampaignStatus.Completed || c.Status == CampaignStatus.Processing || c.Status == CampaignStatus.Closed),
            MerchantCampaignTab.Ended => q.Where(c => c.Status == CampaignStatus.Failed || c.Status == CampaignStatus.Cancelled),
            _ => q.Where(c => c.Status == CampaignStatus.Draft),
        };
        return Project(q.OrderByDescending(c => c.CreatedAt)).ToPagedAsync(page, pageSize, ct);
    }

    public async Task<MerchantCampaignDto> GetAsync(Guid userId, Guid id, CancellationToken ct) =>
        await Project(db.Campaigns.Where(c => c.Id == id && c.MerchantUserId == userId)).FirstOrDefaultAsync(ct) ?? throw NotFound();

    public async Task<PagedResult<ParticipantDto>> ParticipantsAsync(Guid userId, Guid id, int page, int pageSize, CancellationToken ct)
    {
        if (!await db.Campaigns.AnyAsync(c => c.Id == id && c.MerchantUserId == userId, ct)) throw NotFound();
        var rows = await db.CampaignOrders.AsNoTracking()
            .Where(o => o.CampaignId == id && Participating.Contains(o.Status))
            .OrderByDescending(o => o.CreatedAt)
            .Select(o => new { o.Id, o.Customer.FullName, District = o.DeliveryAddress.District.NameAr, o.Quantity, o.TotalAmount, o.Status, o.CreatedAt })
            .ToPagedAsync(page, pageSize, ct);
        // Privacy: merchants see "محمد ع." — full contact details only travel to the assigned driver.
        return new PagedResult<ParticipantDto>(
            rows.Items.Select(r => new ParticipantDto(r.Id, Mask(r.FullName), r.District, r.Quantity, r.TotalAmount, r.Status, r.CreatedAt)).ToList(),
            rows.Page, rows.PageSize, rows.TotalCount);
    }

    public async Task<MerchantCampaignDto> CreateAsync(Guid userId, CampaignInput i, CancellationToken ct)
    {
        var store = await db.Stores.FirstOrDefaultAsync(s => s.Id == i.StoreId && s.Merchant.UserId == userId, ct)
            ?? throw AppException.NotFound("store_not_found", "المتجر غير موجود");
        var product = await db.Products.FirstOrDefaultAsync(p => p.Id == i.ProductId && p.StoreId == store.Id && !p.IsDeleted && p.IsActive, ct)
            ?? throw AppException.BadRequest("invalid_product", "المنتج غير موجود في هذا المتجر أو غير مفعّل");

        var original = i.OriginalPrice ?? product.Price;
        Validate(original, i.CampaignPrice, i.TargetQuantity, i.MaxQuantityPerCustomer, i.DurationDays, product.StockQuantity);
        if (i.Publish) await EnsurePublishableAsync(store, product.Id, null, ct);

        var now = clock.GetUtcNow().UtcDateTime;
        var start = i.StartDate is { } sd && sd > now ? sd : now;
        var campaign = new Campaign
        {
            StoreId = store.Id,
            ProductId = product.Id,
            MerchantUserId = userId,
            TitleAr = i.TitleAr.Trim(),
            TitleEn = i.TitleEn?.Trim() ?? product.NameEn,
            DescriptionAr = i.DescriptionAr?.Trim(),
            OriginalPrice = original,
            CampaignPrice = i.CampaignPrice,
            TargetQuantity = i.TargetQuantity,
            MaxQuantityPerCustomer = i.MaxQuantityPerCustomer,
            StartDate = start,
            EndDate = start.AddDays(i.DurationDays),
            Status = i.Publish ? CampaignStatus.Active : CampaignStatus.Draft,
        };
        db.Campaigns.Add(campaign);
        await db.SaveChangesAsync(ct);
        return await GetAsync(userId, campaign.Id, ct);
    }

    /// <summary>Drafts are fully editable; once published only extension / cancellation are allowed.</summary>
    public async Task<MerchantCampaignDto> UpdateDraftAsync(Guid userId, Guid id, CampaignInput i, CancellationToken ct)
    {
        var campaign = await db.Campaigns.Include(c => c.Product).FirstOrDefaultAsync(c => c.Id == id && c.MerchantUserId == userId, ct) ?? throw NotFound();
        if (campaign.Status != CampaignStatus.Draft) throw AppException.Conflict("campaign_not_draft", "يمكن تعديل المسودات فقط");
        var product = await db.Products.FirstOrDefaultAsync(p => p.Id == i.ProductId && p.StoreId == campaign.StoreId && !p.IsDeleted, ct)
            ?? throw AppException.BadRequest("invalid_product", "المنتج غير موجود في هذا المتجر");

        var original = i.OriginalPrice ?? product.Price;
        Validate(original, i.CampaignPrice, i.TargetQuantity, i.MaxQuantityPerCustomer, i.DurationDays, product.StockQuantity);
        campaign.ProductId = product.Id;
        campaign.TitleAr = i.TitleAr.Trim();
        campaign.TitleEn = i.TitleEn?.Trim() ?? product.NameEn;
        campaign.DescriptionAr = i.DescriptionAr?.Trim();
        campaign.OriginalPrice = original;
        campaign.CampaignPrice = i.CampaignPrice;
        campaign.TargetQuantity = i.TargetQuantity;
        campaign.MaxQuantityPerCustomer = i.MaxQuantityPerCustomer;
        var now = clock.GetUtcNow().UtcDateTime;
        campaign.StartDate = i.StartDate is { } sd && sd > now ? sd : now;
        campaign.EndDate = campaign.StartDate.AddDays(i.DurationDays);
        await db.SaveChangesAsync(ct);
        return i.Publish ? await PublishAsync(userId, id, ct) : await GetAsync(userId, id, ct);
    }

    public async Task<MerchantCampaignDto> PublishAsync(Guid userId, Guid id, CancellationToken ct)
    {
        var campaign = await db.Campaigns.Include(c => c.Store).FirstOrDefaultAsync(c => c.Id == id && c.MerchantUserId == userId, ct) ?? throw NotFound();
        if (campaign.Status != CampaignStatus.Draft) throw AppException.Conflict("campaign_not_draft", "الحملة منشورة مسبقًا");
        await EnsurePublishableAsync(campaign.Store, campaign.ProductId, campaign.Id, ct);

        // The duration is kept; the clock starts at publication if the planned start has passed.
        var now = clock.GetUtcNow().UtcDateTime;
        if (campaign.StartDate < now)
        {
            var duration = campaign.EndDate - campaign.StartDate;
            campaign.StartDate = now;
            campaign.EndDate = now + duration;
        }
        campaign.Status = CampaignStatus.Active;
        await db.SaveChangesAsync(ct);
        return await GetAsync(userId, id, ct);
    }

    public async Task<MerchantCampaignDto> ExtendAsync(Guid userId, Guid id, int days, CancellationToken ct)
    {
        if (days is < 1 or > 14) throw AppException.BadRequest("invalid_extension", "يمكن التمديد من يوم إلى 14 يومًا");
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var campaign = await lifecycle.LockAsync(id, ct);
        if (campaign.MerchantUserId != userId) throw NotFound();
        if (campaign.Status != CampaignStatus.Active) throw AppException.Conflict("campaign_not_active", "يمكن تمديد الحملات النشطة فقط");
        if ((campaign.EndDate.AddDays(days) - campaign.StartDate).TotalDays > MaxTotalDays)
            throw AppException.BadRequest("invalid_extension", $"المدة الكلية للحملة لا تتجاوز {MaxTotalDays} يومًا");

        campaign.EndDate = campaign.EndDate.AddDays(days);
        campaign.ConcurrencyStamp = Guid.NewGuid();
        var customers = await db.CampaignOrders.Where(o => o.CampaignId == id && o.Status == CampaignOrderStatus.Paid).Select(o => new { o.CustomerId, o.Id }).ToListAsync(ct);
        foreach (var c in customers)
        {
            notifier.Notify(c.CustomerId, NotificationType.OrderStatus, "تم تمديد الحملة", $"مدّد التاجر حملة \"{campaign.TitleAr}\" {days} أيام إضافية.", c.Id);
        }
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return await GetAsync(userId, id, ct);
    }

    /// <summary>
    /// Edits a draft or a running campaign. Fields left null are unchanged; <c>MaxQuantityPerCustomer = 0</c> removes the limit.
    /// A running campaign protects people who already paid: the price is locked once anyone joined, the target can't go below
    /// what is sold (equal to it completes the campaign now), the per-customer limit can't go below an existing order,
    /// and the end stays at least an hour away and within the total duration limit. Participants hear about target/date changes.
    /// </summary>
    public async Task<MerchantCampaignDto> EditAsync(Guid userId, Guid id, CampaignEdit e, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        // Same lock as checkout, so a purchase can't slip in between the checks and the save.
        var campaign = await lifecycle.LockAsync(id, ct);
        if (campaign.MerchantUserId != userId) throw NotFound();
        if (campaign.Status is not (CampaignStatus.Draft or CampaignStatus.Active))
            throw AppException.Conflict("campaign_not_editable", "لا يمكن تعديل حملة مكتملة أو منتهية");
        var draft = campaign.Status == CampaignStatus.Draft;
        var now = clock.GetUtcNow().UtcDateTime;
        var stock = await db.Products.Where(p => p.Id == campaign.ProductId).Select(p => p.StockQuantity).FirstAsync(ct);

        if (e.TitleAr is { } title)
        {
            if (title.Trim().Length < 3) throw AppException.BadRequest("invalid_title", "عنوان الحملة قصير جدًا");
            campaign.TitleAr = title.Trim();
        }
        if (e.DescriptionAr != null) campaign.DescriptionAr = string.IsNullOrWhiteSpace(e.DescriptionAr) ? null : e.DescriptionAr.Trim();

        var priceChanged = (e.CampaignPrice is { } p1 && p1 != campaign.CampaignPrice) || (e.OriginalPrice is { } p2 && p2 != campaign.OriginalPrice);
        if (priceChanged)
        {
            if (!draft && campaign.CurrentQuantity > 0)
                throw AppException.Conflict("price_locked", "لا يمكن تغيير السعر بعد انضمام عملاء للحملة");
            var original = e.OriginalPrice ?? campaign.OriginalPrice;
            var price = e.CampaignPrice ?? campaign.CampaignPrice;
            if (price <= 0 || price >= original) throw AppException.BadRequest("invalid_campaign_price", "سعر الحملة يجب أن يكون أقل من السعر الأصلي");
            (campaign.OriginalPrice, campaign.CampaignPrice) = (original, price);
        }

        var oldTarget = campaign.TargetQuantity;
        if (e.TargetQuantity is { } target && target != campaign.TargetQuantity)
        {
            if (target < 2) throw AppException.BadRequest("invalid_target", "الكمية المطلوبة يجب أن تكون 2 على الأقل");
            if (target < campaign.CurrentQuantity)
                throw AppException.BadRequest("target_below_sold", $"بيع {campaign.CurrentQuantity} قطعة بالفعل، لا يمكن أن يقل الهدف عن ذلك");
            if (target > stock) throw AppException.BadRequest("target_exceeds_stock", $"الكمية المطلوبة أكبر من المخزون المتاح ({stock})");
            campaign.TargetQuantity = target;
        }

        if (e.MaxQuantityPerCustomer is { } maxPer)
        {
            if (maxPer == 0) campaign.MaxQuantityPerCustomer = null;
            else
            {
                if (maxPer < 1 || maxPer > campaign.TargetQuantity) throw AppException.BadRequest("invalid_max_per_customer", "الحد لكل عميل غير صحيح");
                var biggest = await db.CampaignOrders.Where(o => o.CampaignId == id && o.Status == CampaignOrderStatus.Paid)
                    .MaxAsync(o => (int?)o.Quantity, ct) ?? 0;
                if (maxPer < biggest) throw AppException.BadRequest("max_below_existing", $"أحد العملاء طلب {biggest} قطع، لا يمكن أن يقل الحد عن ذلك");
                campaign.MaxQuantityPerCustomer = maxPer;
            }
        }

        var oldEnd = campaign.EndDate;
        if (e.EndsAt is { } endsAt && endsAt != campaign.EndDate)
        {
            var end = endsAt.ToUniversalTime();
            var from = draft && campaign.StartDate < now ? now : campaign.StartDate;
            if (end < now.AddHours(1)) throw AppException.BadRequest("invalid_end", "يجب أن تنتهي الحملة بعد ساعة على الأقل من الآن");
            if ((end - from).TotalDays > (draft ? MaxDurationDays : MaxTotalDays))
                throw AppException.BadRequest("invalid_end", $"المدة الكلية للحملة لا تتجاوز {(draft ? MaxDurationDays : MaxTotalDays)} يومًا");
            campaign.EndDate = end;
        }

        campaign.ConcurrencyStamp = Guid.NewGuid();
        var completes = !draft && campaign.CurrentQuantity > 0 && campaign.CurrentQuantity >= campaign.TargetQuantity;
        if (completes)
        {
            await lifecycle.CompleteAsync(campaign, ct);
        }
        else if (!draft && (campaign.TargetQuantity != oldTarget || campaign.EndDate != oldEnd))
        {
            var changes = new List<string>();
            if (campaign.TargetQuantity != oldTarget) changes.Add($"الكمية المطلوبة أصبحت {campaign.TargetQuantity} قطعة");
            if (campaign.EndDate != oldEnd) changes.Add($"تنتهي الحملة في {campaign.EndDate.AddHours(3):yyyy/MM/dd HH:mm}");
            var customers = await db.CampaignOrders.Where(o => o.CampaignId == id && o.Status == CampaignOrderStatus.Paid)
                .Select(o => new { o.CustomerId, o.Id }).ToListAsync(ct);
            foreach (var c in customers)
                notifier.Notify(c.CustomerId, NotificationType.OrderStatus, "تحديث على حملتك", $"عدّل التاجر حملة \"{campaign.TitleAr}\": {string.Join("، ", changes)}.", c.Id);
        }
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return await GetAsync(userId, id, ct);
    }

    public async Task<MerchantCampaignDto> CancelAsync(Guid userId, Guid id, string reason, CancellationToken ct)
    {
        await lifecycle.CancelByMerchantAsync(userId, id, reason, ct);
        return await GetAsync(userId, id, ct);
    }

    // ---------------- rules ----------------

    private static void Validate(decimal original, decimal price, int target, int? maxPer, int days, int stock)
    {
        if (price <= 0 || price >= original) throw AppException.BadRequest("invalid_campaign_price", "سعر الحملة يجب أن يكون أقل من السعر الأصلي");
        if (target < 2) throw AppException.BadRequest("invalid_target", "الكمية المطلوبة يجب أن تكون 2 على الأقل");
        if (target > stock) throw AppException.BadRequest("target_exceeds_stock", $"الكمية المطلوبة أكبر من المخزون المتاح ({stock})");
        if (maxPer is { } m && (m < 1 || m > target)) throw AppException.BadRequest("invalid_max_per_customer", "الحد لكل عميل غير صحيح");
        if (days is < 1 or > MaxDurationDays) throw AppException.BadRequest("invalid_duration", $"مدة الحملة من يوم إلى {MaxDurationDays} يومًا");
    }

    private async Task EnsurePublishableAsync(Store store, Guid productId, Guid? exceptCampaignId, CancellationToken ct)
    {
        if (!store.IsVerified || store.Status != StoreStatus.Active)
            throw AppException.BadRequest("store_not_active", "لا يمكن نشر حملة قبل توثيق المتجر وتفعيله");
        // One running campaign per product keeps pricing and stock unambiguous for customers.
        if (await db.Campaigns.AnyAsync(c => c.ProductId == productId && c.Id != exceptCampaignId && c.Status == CampaignStatus.Active, ct))
            throw AppException.Conflict("product_has_active_campaign", "يوجد حملة نشطة لهذا المنتج بالفعل");
    }

    private IQueryable<MerchantCampaignDto> Project(IQueryable<Campaign> q) => q.Select(c => new MerchantCampaignDto(
        c.Id, c.StoreId, c.Store.NameAr, c.ProductId, c.Product.NameAr,
        c.Product.Images.OrderBy(i => i.SortOrder).Select(i => i.ImageUrl).FirstOrDefault(),
        c.TitleAr, c.DescriptionAr, c.OriginalPrice, c.CampaignPrice,
        (int)Math.Round((c.OriginalPrice - c.CampaignPrice) / c.OriginalPrice * 100),
        c.TargetQuantity, c.CurrentQuantity, c.MaxQuantityPerCustomer,
        c.Orders.Count(o => Participating.Contains(o.Status)),
        c.Orders.Where(o => Participating.Contains(o.Status)).Sum(o => (decimal?)o.TotalAmount) ?? 0,
        c.StartDate, c.EndDate, c.Status,
        c.MerchantOrder != null ? c.MerchantOrder.Id : null));

    internal static string Mask(string fullName)
    {
        var parts = fullName.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0) return "عميل ميجا";
        if (parts.Length == 1) return parts[0];
        var last = parts[^1].StartsWith("ال") && parts[^1].Length > 2 ? parts[^1][2..] : parts[^1];
        return $"{parts[0]} {last[0]}.";
    }

    private static AppException NotFound() => AppException.NotFound("campaign_not_found", "الحملة غير موجودة");
}
