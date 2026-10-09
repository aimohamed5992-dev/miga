using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Miga.Api.Contracts;
using Miga.Api.Infrastructure;
using Miga.Infrastructure.Auth;
using Miga.Infrastructure.Persistence;

namespace Miga.Api.Controllers;

[ApiController]
[Route("api/customer")]
[Authorize(Roles = "Customer")]
public class CustomerProfileController(AccountService accounts) : ControllerBase
{
    /// <summary>"أكمل بياناتك" screen.</summary>
    [HttpPut("profile")]
    public async Task<AccountResponse> UpdateProfile(CustomerProfileRequest req, CancellationToken ct) =>
        AccountResponse.From(await accounts.CompleteCustomerProfileAsync(User.UserId(), req.FullName, req.Email, ct));
}

[ApiController]
[Route("api/merchant")]
[Authorize(Roles = "Merchant")]
public class MerchantProfileController(AccountService accounts) : ControllerBase
{
    /// <summary>3-step registration wizard: business info + first store. Result: pending verification.</summary>
    [HttpPost("register")]
    public async Task<AccountResponse> Register(MerchantRegisterRequest r, CancellationToken ct) =>
        AccountResponse.From(await accounts.RegisterMerchantAsync(
            User.UserId(),
            new MerchantRegistration(r.OwnerName, r.BusinessNameAr, r.BusinessNameEn, r.CommercialRegistrationNumber, r.TaxNumber,
                r.StoreNameAr, r.StoreNameEn, r.StoreCategoryId, r.StoreDescriptionAr, r.StoreCityId),
            ct));
}

[ApiController]
[Route("api/driver")]
[Authorize(Roles = "Driver")]
public class DriverProfileController(AccountService accounts) : ControllerBase
{
    /// <summary>3-step registration wizard: personal info, vehicle. Result: pending verification.</summary>
    [HttpPost("register")]
    public async Task<AccountResponse> Register(DriverRegisterRequest r, CancellationToken ct) =>
        AccountResponse.From(await accounts.RegisterDriverAsync(
            User.UserId(),
            new DriverRegistration(r.FullName, r.NationalId, r.CityId, r.VehicleType, r.VehiclePlateNumber, r.VehicleModel, r.DrivingLicenseNumber),
            ct));
}
