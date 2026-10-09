using System.ComponentModel.DataAnnotations;
using Miga.Domain;
using Miga.Infrastructure.Auth;
using Status = Miga.Infrastructure.Auth.VerificationStatus;

namespace Miga.Api.Contracts;

public record SendOtpRequest([Required] string Phone);

public record SendOtpResponse(string Phone, int ExpiresInSeconds, int ResendAfterSeconds, string? DevCode);

/// <param name="UserType">Which app is signing in: Customer (1), Merchant (2) or Driver (3).</param>
public record VerifyOtpRequest([Required] string Phone, [Required, StringLength(6, MinimumLength = 4)] string Code, [Required] UserType UserType);

public record RefreshRequest([Required] string RefreshToken);

public record AccountResponse(
    Guid Id,
    string FullName,
    string PhoneNumber,
    string? Email,
    UserType UserType,
    bool IsProfileComplete,
    string VerificationStatus,
    string? RejectionReason)
{
    public static AccountResponse From(AccountInfo a) => new(
        a.Id,
        a.FullName,
        a.PhoneNumber,
        a.Email,
        a.UserType,
        a.IsProfileComplete,
        a.VerificationStatus switch
        {
            Status.NotSubmitted => "not_submitted",
            Status.Pending => "pending",
            Status.Rejected => "rejected",
            _ => "verified",
        },
        a.RejectionReason);
}

public record AuthResponse(string AccessToken, DateTime AccessTokenExpiresAt, string RefreshToken, AccountResponse Account)
{
    public static AuthResponse From(TokenPair t, AccountInfo a) => new(t.AccessToken, t.AccessTokenExpiresAt, t.RefreshToken, AccountResponse.From(a));
}

public record CustomerProfileRequest([Required, StringLength(150, MinimumLength = 3)] string FullName, [EmailAddress, StringLength(256)] string? Email);

public record MerchantRegisterRequest(
    [Required, StringLength(150, MinimumLength = 3)] string OwnerName,
    [Required, StringLength(200, MinimumLength = 2)] string BusinessNameAr,
    [StringLength(200)] string? BusinessNameEn,
    [Required, RegularExpression(@"^\d{10}$", ErrorMessage = "رقم السجل التجاري يتكون من 10 أرقام")] string CommercialRegistrationNumber,
    [RegularExpression(@"^\d{15}$", ErrorMessage = "الرقم الضريبي يتكون من 15 رقمًا")] string? TaxNumber,
    [Required, StringLength(200, MinimumLength = 2)] string StoreNameAr,
    [StringLength(200)] string? StoreNameEn,
    [Required] Guid StoreCategoryId,
    [StringLength(1000)] string? StoreDescriptionAr,
    Guid? StoreCityId);

public record DriverRegisterRequest(
    [Required, StringLength(150, MinimumLength = 3)] string FullName,
    [Required, RegularExpression(@"^[12]\d{9}$", ErrorMessage = "رقم الهوية / الإقامة يتكون من 10 أرقام ويبدأ بـ 1 أو 2")] string NationalId,
    [Required] Guid CityId,
    [Required, StringLength(50)] string VehicleType,
    [Required, StringLength(20)] string VehiclePlateNumber,
    [StringLength(100)] string? VehicleModel,
    [StringLength(30)] string? DrivingLicenseNumber);
