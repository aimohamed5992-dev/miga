using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Miga.Infrastructure.Persistence;

namespace Miga.Api.Controllers;

[ApiController]
[Route("api/health")]
public class HealthController(MigaDbContext db) : ControllerBase
{
    /// <summary>API + database status with a few reference-data counts.</summary>
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct) => Ok(new
    {
        status = "ok",
        database = await db.Database.CanConnectAsync(ct) ? "connected" : "unreachable",
        regions = await db.Regions.CountAsync(ct),
        cities = await db.Cities.CountAsync(ct),
        districts = await db.Districts.CountAsync(ct),
        storeCategories = await db.StoreCategories.CountAsync(ct),
        roles = await db.Roles.Select(r => r.Name).ToListAsync(ct),
    });
}
