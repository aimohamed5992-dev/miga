using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Miga.Domain;
using Miga.Domain.Common;
using Miga.Domain.Entities;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Features.MerchantSales;

public record DailySalesDto(DateOnly Date, decimal Amount);

public record MerchantDashboardDto(
    IReadOnlyList<DailySalesDto> LastSevenDays, decimal WeekTotal, decimal PreviousWeekTotal,
    int ActiveCampaigns, int OrdersInProgress, int Participants, int Products,
    IReadOnlyList<MerchantOrderSummaryDto> OrdersNeedingAction, IReadOnlyList<MerchantCampaignDto> ActiveCampaignList);

public record MerchantBusinessDto(
    string OwnerName, string Phone, string? BusinessNameAr, string? BusinessNameEn, string? CommercialRegistrationNumber, string? TaxNumber,
    bool IsVerified, DateTime? VerifiedAt, DateTime RegisteredAt, string? BankName, string? Iban, int StoresCount);

public record MonthlySalesDto(int Year, int Month, decimal Amount);

public record WalletTransactionDto(string Type, string Title, string Subtitle, decimal Amount, DateTime Date);

public record EarningsDto(
    decimal Available, decimal PendingSettlement, decimal WithdrawnThisMonth, string? BankName, string? IbanMasked,
    IReadOnlyList<MonthlySalesDto> Monthly, IReadOnlyList<WalletTransactionDto> Transactions);

/// <summary>
/// Merchant dashboard and wallet. Money becomes withdrawable once every customer delivery of an aggregated order
/// is delivered; until then it is "pending settlement". Amounts are net of MIGA's platform fee.
/// </summary>
public partial class MerchantInsightsService(MigaDbContext db, MerchantCampaignService campaigns, MerchantOrderService orders, TimeProvider clock)
{
    private static readonly List<CampaignOrderStatus> Sold =
    [
        CampaignOrderStatus.Paid, CampaignOrderStatus.Confirmed, CampaignOrderStatus.Preparing,
        CampaignOrderStatus.ReadyForDelivery, CampaignOrderStatus.OutForDelivery, CampaignOrderStatus.Delivered,
    ];

    [GeneratedRegex(@"^SA\d{22}$")]
    private static partial Regex SaudiIban();

    public async Task<MerchantDashboardDto> DashboardAsync(Guid userId, Guid? storeId, CancellationToken ct)
    {
        var today = DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime);
        var from = today.AddDays(-13).ToDateTime(TimeOnly.MinValue);

        var sales = await db.CampaignOrders.AsNoTracking()
            .Where(o => o.Campaign.MerchantUserId == userId && (storeId == null || o.Campaign.StoreId == storeId) && Sold.Contains(o.Status) && o.CreatedAt >= from)
            .Select(o => new { o.CreatedAt, o.TotalAmount })
            .ToListAsync(ct);
        var byDay = sales.GroupBy(s => DateOnly.FromDateTime(s.CreatedAt)).ToDictionary(g => g.Key, g => g.Sum(x => x.TotalAmount));
        var week = Enumerable.Range(0, 7).Select(i => today.AddDays(i - 6)).Select(d => new DailySalesDto(d, byDay.GetValueOrDefault(d))).ToList();
        var previous = Enumerable.Range(7, 7).Sum(i => byDay.GetValueOrDefault(today.AddDays(-i)));

        var campaignQuery = db.Campaigns.Where(c => c.MerchantUserId == userId && (storeId == null || c.StoreId == storeId));
        var ordersQuery = db.MerchantOrders.Where(o => o.Store.Merchant.UserId == userId && (storeId == null || o.StoreId == storeId));

        var activeList = await campaigns.ListAsync(userId, MerchantCampaignTab.Active, storeId, 1, 10, ct);
        var needingAction = (await orders.ListAsync(userId, MerchantOrderTab.New, 1, 5, ct)).Items.Where(o => storeId == null || o.StoreId == storeId).ToList();

        return new MerchantDashboardDto(
            week,
            week.Sum(d => d.Amount),
            previous,
            await campaignQuery.CountAsync(c => c.Status == CampaignStatus.Active, ct),
            await ordersQuery.CountAsync(o => o.Status != MerchantOrderStatus.Completed && o.Status != MerchantOrderStatus.Cancelled, ct),
            await db.CampaignOrders.CountAsync(o => o.Campaign.MerchantUserId == userId && (storeId == null || o.Campaign.StoreId == storeId)
                && o.Campaign.Status == CampaignStatus.Active && Sold.Contains(o.Status), ct),
            await db.Products.CountAsync(p => p.Store.Merchant.UserId == userId && (storeId == null || p.StoreId == storeId) && !p.IsDeleted, ct),
            needingAction,
            activeList.Items);
    }

    /// <summary>Registered business details (read-only in the app; changes go through support and re-verification).</summary>
    public async Task<MerchantBusinessDto> BusinessAsync(Guid userId, CancellationToken ct)
    {
        var m = await db.MerchantProfiles.AsNoTracking().Where(x => x.UserId == userId).Select(x => new MerchantBusinessDto(
            x.User.FullName, x.User.PhoneNumber ?? "", x.BusinessNameAr, x.BusinessNameEn, x.CommercialRegistrationNumber, x.TaxNumber,
            x.IsVerified, x.ReviewedAt, x.CreatedAt, x.BankName, x.Iban, x.Stores.Count())).FirstOrDefaultAsync(ct)
            ?? throw AppException.NotFound("merchant_not_found", "أكمل تسجيل بيانات النشاط أولًا");
        return m with { Iban = m.Iban == null ? null : MaskIban(m.Iban) };
    }

    public async Task<EarningsDto> EarningsAsync(Guid userId, CancellationToken ct)
    {
        var merchant = await MerchantAsync(userId, ct);
        var now = clock.GetUtcNow().UtcDateTime;

        var orderRows = await db.MerchantOrders.AsNoTracking()
            .Where(o => o.Store.MerchantId == merchant.Id && o.Status != MerchantOrderStatus.Cancelled)
            .Select(o => new
            {
                o.Number, o.TotalAmount, o.PlatformFee, o.TotalQuantity, o.CreatedAt, Product = o.Campaign.Product.NameAr,
                // A delivery refunded by support (Cancelled) no longer blocks settlement; its amount leaves the order.
                Settled = o.Deliveries.Any() && o.Deliveries.All(d => d.Status == DeliveryStatus.Delivered || d.Status == DeliveryStatus.Cancelled),
                SettledAt = o.Deliveries.Max(d => d.DeliveredAt),
                Refunded = o.Deliveries.Where(d => d.Status == DeliveryStatus.Cancelled).Sum(d => (decimal?)d.CampaignOrder.TotalAmount) ?? 0,
            })
            .ToListAsync(ct);
        // Commission follows the amount actually kept: refunded customers pay no fee.
        decimal Gross(decimal total, decimal refunded) => total - refunded;
        decimal Fee(decimal total, decimal fee, decimal refunded) => total == 0 ? 0 : Math.Round(fee * (total - refunded) / total, 2);
        var payouts = await db.MerchantPayouts.AsNoTracking().Where(p => p.MerchantId == merchant.Id && p.Status != PayoutStatus.Rejected)
            .Select(p => new { p.Amount, p.CreatedAt, p.Iban, p.Status, p.PaidAt }).ToListAsync(ct);

        var settledNet = orderRows.Where(o => o.Settled).Sum(o => Gross(o.TotalAmount, o.Refunded) - Fee(o.TotalAmount, o.PlatformFee, o.Refunded));
        var pendingNet = orderRows.Where(o => !o.Settled).Sum(o => Gross(o.TotalAmount, o.Refunded) - Fee(o.TotalAmount, o.PlatformFee, o.Refunded));
        var monthStart = new DateTime(now.Year, now.Month, 1, 0, 0, 0, DateTimeKind.Utc);

        var monthly = Enumerable.Range(0, 6).Select(i => monthStart.AddMonths(i - 5))
            .Select(m => new MonthlySalesDto(m.Year, m.Month, orderRows.Where(o => o.CreatedAt.Year == m.Year && o.CreatedAt.Month == m.Month).Sum(o => o.TotalAmount)))
            .ToList();

        var transactions = orderRows.Where(o => o.Settled).SelectMany(o => new[]
            {
                new WalletTransactionDto("income", $"دخل طلب مجمّع {o.Number}",
                    o.Refunded > 0 ? $"{o.Product} • بعد استرداد {o.Refunded:0.##} ر.س" : $"{o.Product} • {o.TotalQuantity} قطعة",
                    Gross(o.TotalAmount, o.Refunded), o.SettledAt ?? o.CreatedAt),
                new WalletTransactionDto("fee", "عمولة ميجا", $"طلب {o.Number}", -Fee(o.TotalAmount, o.PlatformFee, o.Refunded), o.SettledAt ?? o.CreatedAt),
            })
            .Concat(payouts.Select(p => new WalletTransactionDto("payout", "سحب إلى الحساب البنكي",
                p.Status == PayoutStatus.Paid ? $"تم التحويل • {MaskIban(p.Iban)}" : $"قيد التحويل • {MaskIban(p.Iban)}", -p.Amount, p.PaidAt ?? p.CreatedAt)))
            .OrderByDescending(t => t.Date).Take(30).ToList();

        return new EarningsDto(
            settledNet - payouts.Sum(p => p.Amount),
            pendingNet,
            payouts.Where(p => p.CreatedAt >= monthStart).Sum(p => p.Amount),
            merchant.BankName,
            merchant.Iban == null ? null : MaskIban(merchant.Iban),
            monthly,
            transactions);
    }

    public async Task SetBankAccountAsync(Guid userId, string bankName, string iban, CancellationToken ct)
    {
        var normalized = iban.Replace(" ", string.Empty).ToUpperInvariant();
        if (!SaudiIban().IsMatch(normalized)) throw AppException.BadRequest("invalid_iban", "رقم الآيبان غير صحيح (SA متبوعًا بـ 22 رقمًا)");
        var merchant = await MerchantAsync(userId, ct);
        merchant.BankName = bankName.Trim();
        merchant.Iban = normalized;
        await db.SaveChangesAsync(ct);
    }

    public async Task<EarningsDto> RequestPayoutAsync(Guid userId, decimal amount, CancellationToken ct)
    {
        if (amount < 100) throw AppException.BadRequest("payout_too_small", "الحد الأدنى للسحب 100 ر.س");
        var merchant = await MerchantAsync(userId, ct);
        if (merchant.Iban == null) throw AppException.BadRequest("bank_account_missing", "أضف الحساب البنكي أولًا");

        // Serialize payouts per merchant so two requests can't both spend the same balance.
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlInterpolatedAsync($"SELECT `Id` FROM `MerchantProfiles` WHERE `Id` = {merchant.Id} FOR UPDATE", ct);
        var available = (await EarningsAsync(userId, ct)).Available;
        if (amount > available) throw AppException.BadRequest("insufficient_balance", $"الرصيد المتاح {available:0.##} ر.س فقط");

        db.MerchantPayouts.Add(new MerchantPayout { MerchantId = merchant.Id, Amount = amount, Iban = merchant.Iban });
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return await EarningsAsync(userId, ct);
    }

    private async Task<MerchantProfile> MerchantAsync(Guid userId, CancellationToken ct) =>
        await db.MerchantProfiles.FirstOrDefaultAsync(m => m.UserId == userId, ct)
        ?? throw AppException.BadRequest("merchant_not_registered", "أكمل تسجيل بيانات النشاط التجاري أولًا");

    private static string MaskIban(string iban) => iban.Length > 6 ? $"{iban[..2]}•• •••• {iban[^4..]}" : iban;
}
