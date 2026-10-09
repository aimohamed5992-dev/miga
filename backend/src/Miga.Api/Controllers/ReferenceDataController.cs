using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Miga.Infrastructure.Persistence;

namespace Miga.Api.Controllers;

/// <summary>Public lookups used by registration and address screens.</summary>
[ApiController]
[Route("api")]
public class ReferenceDataController(MigaDbContext db) : ControllerBase
{
    /// <summary>Region → City → District tree (for the cascading address pickers).</summary>
    [HttpGet("regions")]
    [ResponseCache(Duration = 3600)]
    public async Task<object> Regions(CancellationToken ct) =>
        await db.Regions.AsNoTracking()
            .Where(r => r.IsActive)
            .OrderBy(r => r.SortOrder)
            .Select(r => new
            {
                r.Id,
                r.NameAr,
                r.NameEn,
                Cities = r.Cities.Where(c => c.IsActive).OrderBy(c => c.NameAr).Select(c => new
                {
                    c.Id,
                    c.NameAr,
                    c.NameEn,
                    Districts = c.Districts.Where(d => d.IsActive).OrderBy(d => d.NameAr).Select(d => new { d.Id, d.NameAr }),
                }),
            })
            .ToListAsync(ct);

    [HttpGet("store-categories")]
    [ResponseCache(Duration = 3600)]
    public async Task<object> StoreCategories(CancellationToken ct) =>
        await db.StoreCategories.AsNoTracking()
            .Where(c => c.IsActive)
            .OrderBy(c => c.SortOrder)
            .Select(c => new { c.Id, c.NameAr, c.NameEn, c.ImageUrl })
            .ToListAsync(ct);
}
