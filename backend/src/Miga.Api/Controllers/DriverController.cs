using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Miga.Api.Infrastructure;
using Miga.Infrastructure.Features.Driver;

namespace Miga.Api.Controllers;

public record AvailabilityRequest(bool Available);
public record LocationRequest([Range(-90, 90)] decimal Latitude, [Range(-180, 180)] decimal Longitude);
public record PickupRequest([Required, StringLength(10)] string PickupCode);
public record DeliverRequest([Required, StringLength(10)] string DeliveryCode, [StringLength(500)] string? ProofImageUrl);
public record DriverProfileRequest(Guid? CityId, [StringLength(50)] string? VehicleType, [StringLength(100)] string? VehicleModel, [StringLength(20)] string? PlateNumber);

public record FailDeliveryRequest([Required, StringLength(300, MinimumLength = 2)] string Reason);

/// <summary>Driver app: availability, nearby requests, delivery flow and earnings. Operations require a verified driver.</summary>
[ApiController]
[Route("api/driver")]
[Authorize(Roles = "Driver")]
public class DriverController(DriverService drivers) : ControllerBase
{
    [HttpGet("home")]
    public Task<DriverHomeDto> Home(CancellationToken ct) => drivers.HomeAsync(User.UserId(), ct);

    [HttpPatch("availability")]
    public async Task<IActionResult> Availability(AvailabilityRequest req, CancellationToken ct)
    {
        await drivers.SetAvailabilityAsync(User.UserId(), req.Available, ct);
        return NoContent();
    }

    /// <summary>Current position, sent by the app every so often while the driver is online (admin live map).</summary>
    [HttpPost("location")]
    public async Task<IActionResult> Location(LocationRequest req, CancellationToken ct)
    {
        await drivers.ReportLocationAsync(User.UserId(), req.Latitude, req.Longitude, ct);
        return NoContent();
    }

    /// <summary>Change work city (not while deliveries are in progress) and/or vehicle details.</summary>
    [HttpPatch("profile")]
    public Task<DriverHomeDto> UpdateProfile(DriverProfileRequest req, CancellationToken ct) =>
        drivers.UpdateProfileAsync(User.UserId(), req.CityId, req.VehicleType, req.VehicleModel, req.PlateNumber, ct);

    [HttpGet("requests")]
    public Task<List<DeliveryRequestDto>> Requests(CancellationToken ct) => drivers.RequestsAsync(User.UserId(), ct);

    /// <param name="scope">active · history</param>
    [HttpGet("deliveries")]
    public Task<List<DriverDeliveryDto>> Deliveries([FromQuery] string scope = "active", CancellationToken ct = default) =>
        drivers.DeliveriesAsync(User.UserId(), scope == "history", ct);

    [HttpGet("deliveries/{id:guid}")]
    public Task<DriverDeliveryDto> Delivery(Guid id, CancellationToken ct) => drivers.GetAsync(User.UserId(), id, ct);

    [HttpPost("deliveries/{id:guid}/accept")]
    public Task<DriverDeliveryDto> Accept(Guid id, CancellationToken ct) => drivers.AcceptAsync(User.UserId(), id, ct);

    [HttpPost("deliveries/{id:guid}/release")]
    public async Task<IActionResult> Release(Guid id, CancellationToken ct)
    {
        await drivers.ReleaseAsync(User.UserId(), id, ct);
        return NoContent();
    }

    [HttpPost("deliveries/{id:guid}/pickup")]
    public Task<DriverDeliveryDto> Pickup(Guid id, PickupRequest req, CancellationToken ct) => drivers.PickUpAsync(User.UserId(), id, req.PickupCode, ct);

    [HttpPost("deliveries/{id:guid}/start")]
    public Task<DriverDeliveryDto> Start(Guid id, CancellationToken ct) => drivers.StartAsync(User.UserId(), id, ct);

    [HttpPost("deliveries/{id:guid}/deliver")]
    public Task<DriverDeliveryDto> Deliver(Guid id, DeliverRequest req, CancellationToken ct) =>
        drivers.DeliverAsync(User.UserId(), id, req.DeliveryCode, req.ProofImageUrl, ct);

    [HttpPost("deliveries/{id:guid}/fail")]
    public Task<DriverDeliveryDto> Fail(Guid id, FailDeliveryRequest req, CancellationToken ct) => drivers.FailAsync(User.UserId(), id, req.Reason, ct);

    /// <param name="period">week · month</param>
    [HttpGet("earnings")]
    public Task<DriverEarningsDto> Earnings([FromQuery] EarningsPeriod period = EarningsPeriod.Week, CancellationToken ct = default) =>
        drivers.EarningsAsync(User.UserId(), period, ct);
}
