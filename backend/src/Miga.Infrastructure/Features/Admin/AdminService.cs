using Microsoft.EntityFrameworkCore;
using Miga.Domain;
using Miga.Domain.Common;
using Miga.Domain.Entities;
using Miga.Infrastructure.Common;
using Miga.Infrastructure.Notifications;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Features.Admin;

public record AdminCountsDto(
    int Customers, int Merchants, int MerchantsPending, int Drivers, int DriversPending, int DriversOnline, int SuspendedUsers,
    int ActiveStores, int ActiveCampaigns, int CampaignsCompleted30d, int OrdersToday, decimal Gmv30d, decimal Commission30d,
    int DeliveriesInProgress, int FailedDeliveries, int PayoutsRequested, decimal PayoutsRequestedAmount);

public record AdminDayDto(DateTime Date, decimal Gmv, int Orders);

public record AdminTopStoreDto(Guid StoreId, string StoreName, decimal Gmv, int Orders);

public record AdminDashboardDto(AdminCountsDto Counts, IReadOnlyList<AdminDayDto> Days, IReadOnlyList<AdminTopStoreDto> TopStores);

/// <summary>One merchant or driver registration in the review queue. Role-specific fields are null for the other role.</summary>
public record VerificationItemDto(
    Guid UserId, string Type, string FullName, string Phone, DateTime SubmittedAt, string Status, string? RejectionReason, DateTime? ReviewedAt,
    string? BusinessNameAr, string? CommercialRegistrationNumber, string? TaxNumber, string? StoreName, string? StoreCategory,
    string? NationalId, string? City, string? VehicleType, string? VehicleModel, string? PlateNumber, string? DrivingLicenseNumber);

public record AdminUserDto(
    Guid Id, string FullName, string Phone, string? Email, UserType UserType, bool IsActive, DateTime CreatedAt, string Verification,
    string? SuspensionReason, int OrdersCount, decimal TotalSpent, string? BusinessName, int StoresCount,
    string? City, string? VehicleType, int DeliveriesCount, bool IsAvailable, decimal? Rating);

public record AdminStoreRowDto(Guid Id, string NameAr, StoreStatus Status, bool IsVerified, int Products, int Campaigns);

public record AdminActivityDto(Guid Id, string Number, string Title, decimal Amount, string Status, DateTime Date);

public record AdminUserDetailDto(
    AdminUserDto User, int Addresses, string? BankName, string? Iban, string? NationalId, string? DrivingLicenseNumber, string? VehicleModel,
    string? PlateNumber, string? RejectionReason, IReadOnlyList<AdminStoreRowDto> Stores, IReadOnlyList<AdminActivityDto> Recent);

/// <summary>
/// MIGA operations: platform numbers, the merchant/driver review queue (verify or reject with a reason the user sees),
/// and user management (search, details, suspend / reactivate).
/// </summary>
public class AdminService(MigaDbContext db, Notifier notifier, TimeProvider clock)
{
    private DateTime Now => clock.GetUtcNow().UtcDateTime;

    // ---------------------------------------------------------------- dashboard

    public async Task<AdminDashboardDto> DashboardAsync(CancellationToken ct)
    {
        var now = Now;
        var since30 = now.AddDays(-30);
        var since14 = now.Date.AddDays(-13);
        var today = now.Date;
        var inProgress = new List<DeliveryStatus> { DeliveryStatus.DriverAccepted, DeliveryStatus.PickedUp, DeliveryStatus.OutForDelivery };
        var activeCampaign = new List<CampaignStatus> { CampaignStatus.Active, CampaignStatus.Processing };

        var counts = new AdminCountsDto(
            Customers: await db.Users.CountAsync(u => u.UserType == UserType.Customer, ct),
            Merchants: await db.MerchantProfiles.CountAsync(m => m.IsVerified, ct),
            MerchantsPending: await db.MerchantProfiles.CountAsync(m => !m.IsVerified && m.RejectionReason == null, ct),
            Drivers: await db.DriverProfiles.CountAsync(d => d.IsVerified, ct),
            DriversPending: await db.DriverProfiles.CountAsync(d => !d.IsVerified && d.RejectionReason == null, ct),
            DriversOnline: await db.DriverProfiles.CountAsync(d => d.IsVerified && d.IsAvailable && d.User.IsActive, ct),
            SuspendedUsers: await db.Users.CountAsync(u => !u.IsActive, ct),
            ActiveStores: await db.Stores.CountAsync(s => s.Status == StoreStatus.Active, ct),
            ActiveCampaigns: await db.Campaigns.CountAsync(c => activeCampaign.Contains(c.Status), ct),
            CampaignsCompleted30d: await db.Campaigns.CountAsync(c => c.Status == CampaignStatus.Completed && c.CompletedAt >= since30, ct),
            OrdersToday: await db.CampaignOrders.CountAsync(o => o.CreatedAt >= today && o.Status != CampaignOrderStatus.Pending, ct),
            Gmv30d: await db.Payments.Where(p => p.Status == PaymentStatus.Paid && p.PaidAt >= since30).SumAsync(p => (decimal?)p.Amount, ct) ?? 0,
            Commission30d: await db.MerchantOrders.Where(o => o.Status != MerchantOrderStatus.Cancelled && o.CreatedAt >= since30)
                .SumAsync(o => (decimal?)o.PlatformFee, ct) ?? 0,
            DeliveriesInProgress: await db.Deliveries.CountAsync(d => inProgress.Contains(d.Status), ct),
            FailedDeliveries: await db.Deliveries.CountAsync(d => d.Status == DeliveryStatus.Failed, ct),
            PayoutsRequested: await db.MerchantPayouts.CountAsync(p => p.Status == PayoutStatus.Requested, ct),
            PayoutsRequestedAmount: await db.MerchantPayouts.Where(p => p.Status == PayoutStatus.Requested).SumAsync(p => (decimal?)p.Amount, ct) ?? 0);

        // Small window → group in memory (MariaDB 10.4 is picky about grouped date expressions).
        var paid = await db.Payments.AsNoTracking()
            .Where(p => p.Status == PaymentStatus.Paid && p.PaidAt >= since14)
            .Select(p => new { p.Amount, PaidAt = p.PaidAt!.Value, StoreId = p.CampaignOrder.Campaign.StoreId, StoreName = p.CampaignOrder.Campaign.Store.NameAr })
            .ToListAsync(ct);
        var days = Enumerable.Range(0, 14).Select(i => since14.AddDays(i))
            .Select(d => new AdminDayDto(d, paid.Where(p => p.PaidAt.Date == d).Sum(p => p.Amount), paid.Count(p => p.PaidAt.Date == d)))
            .ToList();
        var top = paid.GroupBy(p => (p.StoreId, p.StoreName))
            .Select(g => new AdminTopStoreDto(g.Key.StoreId, g.Key.StoreName, g.Sum(p => p.Amount), g.Count()))
            .OrderByDescending(s => s.Gmv).Take(5).ToList();
        return new AdminDashboardDto(counts, days, top);
    }

    // ---------------------------------------------------------------- review queue

    /// <param name="type">merchant · driver · all</param>
    /// <param name="status">pending · rejected · verified</param>
    public async Task<List<VerificationItemDto>> VerificationsAsync(string type, string status, CancellationToken ct)
    {
        var items = new List<VerificationItemDto>();
        if (type is "merchant" or "all")
        {
            var q = db.MerchantProfiles.AsNoTracking();
            q = status switch
            {
                "verified" => q.Where(m => m.IsVerified),
                "rejected" => q.Where(m => !m.IsVerified && m.RejectionReason != null),
                _ => q.Where(m => !m.IsVerified && m.RejectionReason == null),
            };
            items.AddRange(await q.Select(m => new VerificationItemDto(
                m.UserId, "merchant", m.User.FullName, m.User.PhoneNumber ?? "", m.CreatedAt, status, m.RejectionReason, m.ReviewedAt,
                m.BusinessNameAr, m.CommercialRegistrationNumber, m.TaxNumber,
                m.Stores.OrderBy(s => s.CreatedAt).Select(s => s.NameAr).FirstOrDefault(),
                m.Stores.OrderBy(s => s.CreatedAt).Select(s => s.StoreCategory.NameAr).FirstOrDefault(),
                null, null, null, null, null, null)).ToListAsync(ct));
        }
        if (type is "driver" or "all")
        {
            var q = db.DriverProfiles.AsNoTracking();
            q = status switch
            {
                "verified" => q.Where(d => d.IsVerified),
                "rejected" => q.Where(d => !d.IsVerified && d.RejectionReason != null),
                _ => q.Where(d => !d.IsVerified && d.RejectionReason == null),
            };
            items.AddRange(await q.Select(d => new VerificationItemDto(
                d.UserId, "driver", d.User.FullName, d.User.PhoneNumber ?? "", d.CreatedAt, status, d.RejectionReason, d.ReviewedAt,
                null, null, null, null, null,
                d.NationalId, d.City != null ? d.City.NameAr : null, d.VehicleType, d.VehicleModel, d.VehiclePlateNumber, d.DrivingLicenseNumber))
                .ToListAsync(ct));
        }
        // Oldest first for the pending queue (first come, first served); newest first for history.
        return status == "pending" ? items.OrderBy(i => i.SubmittedAt).ToList() : items.OrderByDescending(i => i.ReviewedAt ?? i.SubmittedAt).ToList();
    }

    /// <summary>Verifies the merchant and activates their stores.</summary>
    public async Task VerifyMerchantAsync(Guid userId, CancellationToken ct)
    {
        var merchant = await db.MerchantProfiles.Include(m => m.Stores).FirstOrDefaultAsync(m => m.UserId == userId, ct)
            ?? throw AppException.NotFound("merchant_not_found", "التاجر غير موجود");
        merchant.IsVerified = true;
        merchant.RejectionReason = null;
        merchant.ReviewedAt = Now;
        foreach (var s in merchant.Stores)
        {
            s.IsVerified = true;
            if (s.Status == StoreStatus.Inactive) s.Status = StoreStatus.Active;
        }
        notifier.Notify(userId, NotificationType.General, "تم توثيق نشاطك التجاري 🎉", "أصبح متجرك ظاهرًا للعملاء، ويمكنك الآن إطلاق حملات الشراء الجماعي.");
        await db.SaveChangesAsync(ct);
    }

    public async Task VerifyDriverAsync(Guid userId, CancellationToken ct)
    {
        var driver = await db.DriverProfiles.FirstOrDefaultAsync(d => d.UserId == userId, ct)
            ?? throw AppException.NotFound("driver_not_found", "المندوب غير موجود");
        driver.IsVerified = true;
        driver.RejectionReason = null;
        driver.ReviewedAt = Now;
        notifier.Notify(userId, NotificationType.General, "تم تفعيل حسابك يا كابتن 🎉", "فعّل حالتك من الصفحة الرئيسية لتبدأ باستقبال طلبات التوصيل.");
        await db.SaveChangesAsync(ct);
    }

    public async Task RejectMerchantAsync(Guid userId, string reason, CancellationToken ct)
    {
        var merchant = await db.MerchantProfiles.FirstOrDefaultAsync(m => m.UserId == userId, ct)
            ?? throw AppException.NotFound("merchant_not_found", "التاجر غير موجود");
        if (merchant.IsVerified) throw AppException.Conflict("already_verified", "التاجر موثّق بالفعل، استخدم الإيقاف بدلًا من الرفض");
        merchant.RejectionReason = reason.Trim();
        merchant.ReviewedAt = Now;
        notifier.Notify(userId, NotificationType.General, "يلزم تعديل بيانات التسجيل", $"لم نتمكن من توثيق نشاطك: {merchant.RejectionReason}. عدّل البيانات وأعد الإرسال.");
        await db.SaveChangesAsync(ct);
    }

    public async Task RejectDriverAsync(Guid userId, string reason, CancellationToken ct)
    {
        var driver = await db.DriverProfiles.FirstOrDefaultAsync(d => d.UserId == userId, ct)
            ?? throw AppException.NotFound("driver_not_found", "المندوب غير موجود");
        if (driver.IsVerified) throw AppException.Conflict("already_verified", "المندوب مفعّل بالفعل، استخدم الإيقاف بدلًا من الرفض");
        driver.RejectionReason = reason.Trim();
        driver.ReviewedAt = Now;
        driver.IsAvailable = false;
        notifier.Notify(userId, NotificationType.General, "يلزم تعديل بيانات التسجيل", $"لم نتمكن من تفعيل حسابك: {driver.RejectionReason}. عدّل البيانات وأعد الإرسال.");
        await db.SaveChangesAsync(ct);
    }

    // ---------------------------------------------------------------- users

    /// <param name="status">all · active · suspended · pending (merchants/drivers awaiting review) · rejected · verified</param>
    public Task<PagedResult<AdminUserDto>> UsersAsync(UserType type, string? q, string status, int page, int pageSize, CancellationToken ct)
    {
        var users = db.Users.AsNoTracking().Where(u => u.UserType == type);
        if (!string.IsNullOrWhiteSpace(q))
        {
            var term = q.Trim();
            // Phones are stored as +9665XXXXXXXX; let admins search with 05… too.
            var phoneTerm = term.StartsWith("05") ? "+966" + term[1..] : term;
            users = users.Where(u => u.FullName.Contains(term) || u.PhoneNumber!.Contains(phoneTerm)
                || (u.MerchantProfile != null && u.MerchantProfile.BusinessNameAr!.Contains(term)));
        }
        users = status switch
        {
            "active" => users.Where(u => u.IsActive),
            "suspended" => users.Where(u => !u.IsActive),
            // Awaiting review only — rejected registrations wait for the user, not for MIGA.
            "pending" => users.Where(u =>
                (u.MerchantProfile != null && !u.MerchantProfile.IsVerified && u.MerchantProfile.RejectionReason == null)
                || (u.DriverProfile != null && !u.DriverProfile.IsVerified && u.DriverProfile.RejectionReason == null)),
            "rejected" => users.Where(u =>
                (u.MerchantProfile != null && !u.MerchantProfile.IsVerified && u.MerchantProfile.RejectionReason != null)
                || (u.DriverProfile != null && !u.DriverProfile.IsVerified && u.DriverProfile.RejectionReason != null)),
            "verified" => users.Where(u => (u.MerchantProfile != null && u.MerchantProfile.IsVerified) || (u.DriverProfile != null && u.DriverProfile.IsVerified)),
            _ => users,
        };
        return Project(users.OrderByDescending(u => u.CreatedAt)).ToPagedAsync(page, pageSize, ct);
    }

    public async Task<AdminUserDetailDto> UserAsync(Guid id, CancellationToken ct)
    {
        var user = await Project(db.Users.AsNoTracking().Where(u => u.Id == id)).FirstOrDefaultAsync(ct)
            ?? throw AppException.NotFound("user_not_found", "المستخدم غير موجود");
        var extra = await db.Users.AsNoTracking().Where(u => u.Id == id).Select(u => new
        {
            Addresses = u.Addresses.Count(a => !a.IsDeleted),
            u.MerchantProfile!.BankName,
            u.MerchantProfile.Iban,
            MerchantRejection = u.MerchantProfile.RejectionReason,
            u.DriverProfile!.NationalId,
            u.DriverProfile.DrivingLicenseNumber,
            u.DriverProfile.VehicleModel,
            u.DriverProfile.VehiclePlateNumber,
            DriverRejection = u.DriverProfile.RejectionReason,
        }).FirstAsync(ct);

        var stores = user.UserType == UserType.Merchant
            ? await db.Stores.AsNoTracking().Where(s => s.Merchant.UserId == id).OrderBy(s => s.CreatedAt)
                .Select(s => new AdminStoreRowDto(s.Id, s.NameAr, s.Status, s.IsVerified, s.Products.Count(p => !p.IsDeleted), s.Campaigns.Count()))
                .ToListAsync(ct)
            : [];

        List<AdminActivityDto> recent = user.UserType switch
        {
            UserType.Customer => await db.CampaignOrders.AsNoTracking().Where(o => o.CustomerId == id).OrderByDescending(o => o.CreatedAt).Take(10)
                .Select(o => new AdminActivityDto(o.Id, o.Number, o.Campaign.TitleAr, o.TotalAmount, o.Status.ToString(), o.CreatedAt)).ToListAsync(ct),
            UserType.Merchant => await db.MerchantOrders.AsNoTracking().Where(o => o.Store.Merchant.UserId == id).OrderByDescending(o => o.CreatedAt).Take(10)
                .Select(o => new AdminActivityDto(o.Id, o.Number, o.Campaign.TitleAr, o.TotalAmount, o.Status.ToString(), o.CreatedAt)).ToListAsync(ct),
            UserType.Driver => await db.Deliveries.AsNoTracking().Where(d => d.DriverUserId == id).OrderByDescending(d => d.AcceptedAt).Take(10)
                .Select(d => new AdminActivityDto(d.Id, d.Number, d.CampaignOrder.Campaign.Product.NameAr, d.Fee, d.Status.ToString(), d.AcceptedAt ?? d.CreatedAt))
                .ToListAsync(ct),
            _ => [],
        };

        return new AdminUserDetailDto(user, extra.Addresses, extra.BankName, extra.Iban, extra.NationalId, extra.DrivingLicenseNumber, extra.VehicleModel,
            extra.VehiclePlateNumber, extra.MerchantRejection ?? extra.DriverRejection, stores, recent);
    }

    /// <summary>
    /// Suspends (with a reason) or reactivates an account. Suspension signs the user out everywhere (refresh tokens revoked,
    /// and every API call is refused from then on), takes a driver offline and hides a merchant's stores.
    /// </summary>
    public async Task SetActiveAsync(Guid adminId, Guid userId, bool active, string? reason, CancellationToken ct)
    {
        if (userId == adminId) throw AppException.BadRequest("cannot_suspend_self", "لا يمكنك إيقاف حسابك");
        var user = await db.Users.Include(u => u.DriverProfile).Include(u => u.MerchantProfile).ThenInclude(m => m!.Stores)
            .FirstOrDefaultAsync(u => u.Id == userId, ct) ?? throw AppException.NotFound("user_not_found", "المستخدم غير موجود");
        if (user.UserType == UserType.Admin) throw AppException.Forbidden("cannot_suspend_admin", "لا يمكن إيقاف حساب مدير");
        if (user.IsActive == active) return;

        var now = Now;
        if (!active)
        {
            if (string.IsNullOrWhiteSpace(reason) || reason.Trim().Length < 3) throw AppException.BadRequest("reason_required", "اكتب سبب الإيقاف");
            user.IsActive = false;
            user.SuspensionReason = reason.Trim();
            user.SuspendedAt = now;
            if (user.DriverProfile != null) user.DriverProfile.IsAvailable = false;
            foreach (var s in user.MerchantProfile?.Stores ?? [])
                if (s.Status == StoreStatus.Active) s.Status = StoreStatus.Suspended;
            await db.RefreshTokens.Where(t => t.UserId == userId && t.RevokedAt == null)
                .ExecuteUpdateAsync(x => x.SetProperty(t => t.RevokedAt, now), ct);
        }
        else
        {
            user.IsActive = true;
            user.SuspensionReason = null;
            user.SuspendedAt = null;
            if (user.MerchantProfile?.IsVerified == true)
                foreach (var s in user.MerchantProfile.Stores)
                    if (s.Status == StoreStatus.Suspended) s.Status = StoreStatus.Active;
            notifier.Notify(userId, NotificationType.General, "تمت إعادة تفعيل حسابك", "يمكنك استخدام ميجا من جديد. شكرًا لتفهمك.");
        }
        await db.SaveChangesAsync(ct);
    }

    private static IQueryable<AdminUserDto> Project(IQueryable<ApplicationUser> users) => users.Select(u => new AdminUserDto(
        u.Id, u.FullName, u.PhoneNumber ?? "", u.Email, u.UserType, u.IsActive, u.CreatedAt,
        u.MerchantProfile != null
            ? (u.MerchantProfile.IsVerified ? "verified" : u.MerchantProfile.RejectionReason != null ? "rejected" : "pending")
            : u.DriverProfile != null
                ? (u.DriverProfile.IsVerified ? "verified" : u.DriverProfile.RejectionReason != null ? "rejected" : "pending")
                : u.UserType == UserType.Customer ? "verified" : "not_submitted",
        u.SuspensionReason,
        u.CampaignOrders.Count(o => o.Status != CampaignOrderStatus.Pending),
        u.CampaignOrders.Where(o => o.Status != CampaignOrderStatus.Pending && o.Status != CampaignOrderStatus.Refunded && o.Status != CampaignOrderStatus.Cancelled)
            .Sum(o => (decimal?)o.TotalAmount) ?? 0,
        u.MerchantProfile != null ? u.MerchantProfile.BusinessNameAr : null,
        u.MerchantProfile != null ? u.MerchantProfile.Stores.Count() : 0,
        u.DriverProfile != null && u.DriverProfile.City != null ? u.DriverProfile.City.NameAr : null,
        u.DriverProfile != null ? u.DriverProfile.VehicleType : null,
        u.Deliveries.Count(d => d.Status == DeliveryStatus.Delivered),
        u.DriverProfile != null && u.DriverProfile.IsAvailable,
        u.DriverProfile != null ? u.DriverProfile.Rating : null));
}
