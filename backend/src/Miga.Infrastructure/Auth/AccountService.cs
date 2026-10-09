using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Miga.Domain;
using Miga.Domain.Common;
using Miga.Domain.Entities;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Auth;

public enum VerificationStatus
{
    /// <summary>Profile not submitted yet (merchant / driver registration wizard not done).</summary>
    NotSubmitted,
    Pending,
    Verified,

    /// <summary>An admin rejected the registration (see <see cref="AccountInfo.RejectionReason"/>); the user can resubmit.</summary>
    Rejected,
}

public record AccountInfo(
    Guid Id,
    string FullName,
    string PhoneNumber,
    string? Email,
    UserType UserType,
    bool IsProfileComplete,
    VerificationStatus VerificationStatus,
    string? RejectionReason = null);

public record MerchantRegistration(
    string OwnerName,
    string BusinessNameAr,
    string? BusinessNameEn,
    string CommercialRegistrationNumber,
    string? TaxNumber,
    string StoreNameAr,
    string? StoreNameEn,
    Guid StoreCategoryId,
    string? StoreDescriptionAr,
    Guid? StoreCityId);

public record DriverRegistration(
    string FullName,
    string NationalId,
    Guid CityId,
    string VehicleType,
    string VehiclePlateNumber,
    string? VehicleModel,
    string? DrivingLicenseNumber);

/// <summary>Phone sign-in (one account type per number) and profile completion for each role.</summary>
public class AccountService(MigaDbContext db, UserManager<ApplicationUser> users, OtpService otp, TokenService tokens)
{
    public async Task<(AccountInfo Account, TokenPair Tokens)> SignInWithOtpAsync(string phone, string code, UserType appType, CancellationToken ct)
    {
        await otp.VerifyAsync(phone, code, ct);

        var user = await users.Users.FirstOrDefaultAsync(u => u.PhoneNumber == phone, ct);
        // The admin dashboard never creates accounts: only numbers seeded / promoted as Admin may sign in there.
        if (appType == UserType.Admin && user?.UserType != UserType.Admin)
            throw AppException.Forbidden("not_admin", "هذا الرقم غير مصرح له بدخول لوحة الإدارة");
        if (user == null)
        {
            user = new ApplicationUser { UserName = phone, PhoneNumber = phone, PhoneNumberConfirmed = true, UserType = appType };
            Check(await users.CreateAsync(user));
            Check(await users.AddToRoleAsync(user, appType.ToString()));
        }
        else if (user.UserType != appType && user.UserType != UserType.Admin)
        {
            throw AppException.Conflict("phone_registered_as_other_type", $"هذا الرقم مسجل كحساب {Label(user.UserType)}، استخدم تطبيق {Label(user.UserType)}");
        }

        if (!user.IsActive) throw AppException.Forbidden("account_disabled", "تم إيقاف هذا الحساب، تواصل مع الدعم");

        return (await GetAsync(user.Id, ct), await tokens.IssueAsync(user, ct));
    }

    public async Task<AccountInfo> GetAsync(Guid userId, CancellationToken ct)
    {
        var u = await db.Users.AsNoTracking()
            .Include(x => x.CustomerProfile)
            .Include(x => x.MerchantProfile)
            .Include(x => x.DriverProfile)
            .FirstOrDefaultAsync(x => x.Id == userId, ct) ?? throw AppException.NotFound("user_not_found", "الحساب غير موجود");

        var (complete, status, reason) = u.UserType switch
        {
            UserType.Customer => (u.CustomerProfile != null && u.FullName.Length > 0, VerificationStatus.Verified, null),
            UserType.Merchant => (u.MerchantProfile != null,
                Status(u.MerchantProfile != null, u.MerchantProfile?.IsVerified == true, u.MerchantProfile?.RejectionReason), u.MerchantProfile?.RejectionReason),
            UserType.Driver => (u.DriverProfile != null,
                Status(u.DriverProfile != null, u.DriverProfile?.IsVerified == true, u.DriverProfile?.RejectionReason), u.DriverProfile?.RejectionReason),
            _ => (true, VerificationStatus.Verified, (string?)null),
        };
        return new AccountInfo(u.Id, u.FullName, u.PhoneNumber ?? string.Empty, u.Email, u.UserType, complete, status,
            status == VerificationStatus.Rejected ? reason : null);
    }

    public async Task<AccountInfo> CompleteCustomerProfileAsync(Guid userId, string fullName, string? email, CancellationToken ct)
    {
        var user = await db.Users.Include(x => x.CustomerProfile).FirstAsync(x => x.Id == userId, ct);
        user.FullName = fullName.Trim();
        user.Email = string.IsNullOrWhiteSpace(email) ? null : email.Trim();
        user.NormalizedEmail = user.Email?.ToUpperInvariant();
        user.CustomerProfile ??= new CustomerProfile();
        await db.SaveChangesAsync(ct);
        return await GetAsync(userId, ct);
    }

    /// <summary>Creates the merchant profile and the first store. Both await admin verification.</summary>
    public async Task<AccountInfo> RegisterMerchantAsync(Guid userId, MerchantRegistration r, CancellationToken ct)
    {
        var user = await db.Users.Include(x => x.MerchantProfile).ThenInclude(m => m!.Stores).FirstAsync(x => x.Id == userId, ct);
        var resubmit = user.MerchantProfile is { IsVerified: false, RejectionReason: not null };
        if (user.MerchantProfile != null && !resubmit) throw AppException.Conflict("already_registered", "تم تسجيل بيانات النشاط مسبقًا");
        if (!await db.StoreCategories.AnyAsync(c => c.Id == r.StoreCategoryId && c.IsActive, ct))
            throw AppException.BadRequest("invalid_store_category", "قسم المتجر غير صحيح");
        if (r.StoreCityId is { } cityId && !await db.Cities.AnyAsync(c => c.Id == cityId, ct))
            throw AppException.BadRequest("invalid_city", "المدينة غير صحيحة");

        user.FullName = r.OwnerName.Trim();
        if (resubmit)
        {
            // Rejected registration fixed by the merchant: update it in place and send it back to the review queue.
            var m = user.MerchantProfile!;
            m.BusinessNameAr = r.BusinessNameAr.Trim();
            m.BusinessNameEn = r.BusinessNameEn?.Trim();
            m.CommercialRegistrationNumber = r.CommercialRegistrationNumber.Trim();
            m.TaxNumber = r.TaxNumber?.Trim();
            m.RejectionReason = null;
            var first = m.Stores.OrderBy(x => x.CreatedAt).FirstOrDefault();
            if (first != null)
            {
                first.NameAr = r.StoreNameAr.Trim();
                first.NameEn = r.StoreNameEn?.Trim() ?? string.Empty;
                first.StoreCategoryId = r.StoreCategoryId;
                first.DescriptionAr = r.StoreDescriptionAr?.Trim();
                first.CityId = r.StoreCityId ?? first.CityId;
            }
            await db.SaveChangesAsync(ct);
            return await GetAsync(userId, ct);
        }
        var merchant = new MerchantProfile
        {
            BusinessNameAr = r.BusinessNameAr.Trim(),
            BusinessNameEn = r.BusinessNameEn?.Trim(),
            CommercialRegistrationNumber = r.CommercialRegistrationNumber.Trim(),
            TaxNumber = r.TaxNumber?.Trim(),
        };
        merchant.Stores.Add(new Store
        {
            NameAr = r.StoreNameAr.Trim(),
            NameEn = r.StoreNameEn?.Trim() ?? string.Empty,
            StoreCategoryId = r.StoreCategoryId,
            DescriptionAr = r.StoreDescriptionAr?.Trim(),
            CityId = r.StoreCityId,
            // Hidden from customers until MIGA verifies the merchant.
            Status = StoreStatus.Inactive,
        });
        user.MerchantProfile = merchant;
        await db.SaveChangesAsync(ct);
        return await GetAsync(userId, ct);
    }

    public async Task<AccountInfo> RegisterDriverAsync(Guid userId, DriverRegistration r, CancellationToken ct)
    {
        var user = await db.Users.Include(x => x.DriverProfile).FirstAsync(x => x.Id == userId, ct);
        var resubmit = user.DriverProfile is { IsVerified: false, RejectionReason: not null };
        if (user.DriverProfile != null && !resubmit) throw AppException.Conflict("already_registered", "تم تسجيل بياناتك مسبقًا");
        if (!await db.Cities.AnyAsync(c => c.Id == r.CityId && c.IsActive, ct)) throw AppException.BadRequest("invalid_city", "المدينة غير صحيحة");

        user.FullName = r.FullName.Trim();
        // A rejected driver resubmits by updating the same profile, which goes back to the review queue.
        var d = user.DriverProfile ?? new DriverProfile();
        d.NationalId = r.NationalId.Trim();
        d.CityId = r.CityId;
        d.VehicleType = r.VehicleType.Trim();
        d.VehiclePlateNumber = r.VehiclePlateNumber.Trim();
        d.VehicleModel = r.VehicleModel?.Trim();
        d.DrivingLicenseNumber = r.DrivingLicenseNumber?.Trim();
        d.IsAvailable = false;
        d.RejectionReason = null;
        user.DriverProfile = d;
        await db.SaveChangesAsync(ct);
        return await GetAsync(userId, ct);
    }

    private static VerificationStatus Status(bool submitted, bool verified, string? rejectionReason) =>
        !submitted ? VerificationStatus.NotSubmitted
        : verified ? VerificationStatus.Verified
        : rejectionReason != null ? VerificationStatus.Rejected
        : VerificationStatus.Pending;

    private static string Label(UserType t) => t switch
    {
        UserType.Customer => "عميل",
        UserType.Merchant => "تاجر",
        UserType.Driver => "مندوب",
        _ => "مدير",
    };

    private static void Check(IdentityResult r)
    {
        if (!r.Succeeded) throw AppException.BadRequest("identity_error", string.Join("، ", r.Errors.Select(e => e.Description)));
    }
}
