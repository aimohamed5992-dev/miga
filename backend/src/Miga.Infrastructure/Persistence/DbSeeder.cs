using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Miga.Domain.Common;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Miga.Domain;
using Miga.Domain.Entities;

namespace Miga.Infrastructure.Persistence;

/// <summary>Idempotent reference data: roles, Saudi regions → cities → districts, store categories.</summary>
public static class DbSeeder
{
    public static readonly string[] Roles = [nameof(UserType.Customer), nameof(UserType.Merchant), nameof(UserType.Driver), nameof(UserType.Admin)];

    // Region (ar, en) → City (ar, en) → Districts (ar)
    private static readonly (string Ar, string En, (string Ar, string En, string[] Districts)[] Cities)[] Locations =
    [
        ("منطقة الرياض", "Riyadh Region",
        [
            ("الرياض", "Riyadh", ["النرجس", "الياسمين", "الملقا", "العليا", "حطين", "الصحافة", "الربيع", "الندى", "السليمانية", "الملز", "الروضة", "النخيل", "قرطبة", "العارض", "الشفا"]),
            ("الخرج", "Al Kharj", ["الخالدية", "السلام", "الفيصلية", "النهضة"]),
            ("الدرعية", "Diriyah", ["الطريف", "البجيري", "العمارية"]),
        ]),
        ("منطقة مكة المكرمة", "Makkah Region",
        [
            ("جدة", "Jeddah", ["الروضة", "الشاطئ", "السلامة", "الحمراء", "النعيم", "الزهراء", "المرجان", "أبحر الشمالية", "البساتين", "الصفا"]),
            ("مكة المكرمة", "Makkah", ["العزيزية", "الشوقية", "النسيم", "الزاهر", "العوالي"]),
            ("الطائف", "Taif", ["الشهداء", "الحوية", "القمرية", "الفيصلية"]),
        ]),
        ("منطقة المدينة المنورة", "Madinah Region",
        [
            ("المدينة المنورة", "Madinah", ["قباء", "العزيزية", "الدفاع", "شوران", "العوالي"]),
            ("ينبع", "Yanbu", ["الصريف", "البندر", "الشروق"]),
        ]),
        ("المنطقة الشرقية", "Eastern Province",
        [
            ("الدمام", "Dammam", ["الفيصلية", "الشاطئ الغربي", "النور", "الشعلة", "الفردوس"]),
            ("الخبر", "Khobar", ["العقربية", "الثقبة", "الراكة", "الحزام الذهبي", "اليرموك"]),
            ("الظهران", "Dhahran", ["الدوحة", "القصور", "هجر"]),
            ("الأحساء", "Al Ahsa", ["المبرز", "الهفوف", "العيون"]),
        ]),
        ("منطقة القصيم", "Qassim Region", [("بريدة", "Buraydah", ["الريان", "الصفراء", "الإسكان"]), ("عنيزة", "Unaizah", ["الفيحاء", "الريان"])]),
        ("منطقة عسير", "Asir Region", [("أبها", "Abha", ["المنسك", "الموظفين", "شمسان"]), ("خميس مشيط", "Khamis Mushait", ["الراقي", "الموسى"])]),
        ("منطقة تبوك", "Tabuk Region", [("تبوك", "Tabuk", ["المروج", "الفيصلية", "السليمانية"])]),
        ("منطقة حائل", "Hail Region", [("حائل", "Hail", ["النقرة", "الخزامى", "المنتزه"])]),
        ("منطقة الحدود الشمالية", "Northern Borders", [("عرعر", "Arar", ["المساعدية", "الفيصلية"])]),
        ("منطقة جازان", "Jazan Region", [("جازان", "Jazan", ["الشاطئ", "الروضة", "السويس"])]),
        ("منطقة نجران", "Najran Region", [("نجران", "Najran", ["الفيصلية", "الأمير مشعل"])]),
        ("منطقة الباحة", "Al Bahah Region", [("الباحة", "Al Bahah", ["الحاوية", "الظفير"])]),
        ("منطقة الجوف", "Al Jouf Region", [("سكاكا", "Sakaka", ["الشلهوب", "الطوير"])]),
    ];

    // City centres (approximate, WGS84) for the admin map.
    private static readonly Dictionary<string, (decimal Lat, decimal Lng)> CityCoordinates = new()
    {
        ["Riyadh"] = (24.7136m, 46.6753m), ["Al Kharj"] = (24.1556m, 47.3120m), ["Diriyah"] = (24.7340m, 46.5750m),
        ["Jeddah"] = (21.5433m, 39.1728m), ["Makkah"] = (21.3891m, 39.8579m), ["Taif"] = (21.2703m, 40.4158m),
        ["Madinah"] = (24.5247m, 39.5692m), ["Yanbu"] = (24.0895m, 38.0618m),
        ["Dammam"] = (26.4207m, 50.0888m), ["Khobar"] = (26.2794m, 50.2083m), ["Dhahran"] = (26.2361m, 50.0393m), ["Al Ahsa"] = (25.3830m, 49.5860m),
        ["Buraydah"] = (26.3260m, 43.9750m), ["Unaizah"] = (26.0840m, 43.9930m), ["Abha"] = (18.2164m, 42.5053m), ["Khamis Mushait"] = (18.3000m, 42.7333m),
        ["Tabuk"] = (28.3835m, 36.5662m), ["Hail"] = (27.5114m, 41.7208m), ["Arar"] = (30.9753m, 41.0381m), ["Jazan"] = (16.8892m, 42.5511m),
        ["Najran"] = (17.4924m, 44.1277m), ["Al Bahah"] = (20.0129m, 41.4677m), ["Sakaka"] = (29.9697m, 40.2064m),
    };

    // Approximate district centres where known ("City En/District Ar"); other districts fall back to the city centre.
    private static readonly Dictionary<string, (decimal Lat, decimal Lng)> DistrictCoordinates = new()
    {
        ["Riyadh/النرجس"] = (24.8330m, 46.6600m), ["Riyadh/الياسمين"] = (24.8230m, 46.6430m), ["Riyadh/الملقا"] = (24.8050m, 46.6050m),
        ["Riyadh/العليا"] = (24.6950m, 46.6850m), ["Riyadh/حطين"] = (24.7650m, 46.6000m), ["Riyadh/الصحافة"] = (24.8000m, 46.6400m),
        ["Riyadh/الربيع"] = (24.7950m, 46.6600m), ["Riyadh/الندى"] = (24.8050m, 46.6750m), ["Riyadh/السليمانية"] = (24.7050m, 46.7000m),
        ["Riyadh/الملز"] = (24.6650m, 46.7300m), ["Riyadh/الروضة"] = (24.7350m, 46.7700m), ["Riyadh/النخيل"] = (24.7450m, 46.6250m),
        ["Riyadh/قرطبة"] = (24.8100m, 46.7350m), ["Riyadh/العارض"] = (24.8650m, 46.6300m), ["Riyadh/الشفا"] = (24.5600m, 46.7000m),
        ["Jeddah/الروضة"] = (21.5650m, 39.1550m), ["Jeddah/الشاطئ"] = (21.5900m, 39.1100m), ["Jeddah/السلامة"] = (21.5850m, 39.1500m),
        ["Jeddah/الحمراء"] = (21.5300m, 39.1600m), ["Jeddah/النعيم"] = (21.6100m, 39.1450m), ["Jeddah/الزهراء"] = (21.6000m, 39.1250m),
        ["Jeddah/المرجان"] = (21.6600m, 39.1050m), ["Jeddah/أبحر الشمالية"] = (21.7650m, 39.1100m), ["Jeddah/البساتين"] = (21.6750m, 39.1300m),
        ["Jeddah/الصفا"] = (21.5800m, 39.2100m),
    };

    private static readonly (string Ar, string En, string Image)[] StoreCategories =
    [
        ("إلكترونيات", "Electronics", "cat_electronics.png"),
        ("بقالة", "Grocery", "cat_grocery.png"),
        ("أزياء", "Fashion", "cat_fashion.png"),
        ("عناية وجمال", "Beauty", "cat_beauty.png"),
        ("مطاعم", "Restaurants", "cat_restaurants.png"),
        ("المنزل", "Home", "cat_home.png"),
    ];

    public static async Task SeedAsync(IServiceProvider services, CancellationToken ct = default)
    {
        var db = services.GetRequiredService<MigaDbContext>();
        var roles = services.GetRequiredService<RoleManager<IdentityRole<Guid>>>();
        var log = services.GetRequiredService<ILoggerFactory>().CreateLogger(nameof(DbSeeder));

        foreach (var role in Roles)
        {
            if (!await roles.RoleExistsAsync(role)) await roles.CreateAsync(new IdentityRole<Guid>(role));
        }

        if (!await db.Regions.AnyAsync(ct))
        {
            var order = 0;
            foreach (var (ar, en, cities) in Locations)
            {
                var region = new Region { NameAr = ar, NameEn = en, SortOrder = order++ };
                foreach (var (cityAr, cityEn, districts) in cities)
                {
                    var city = new City { NameAr = cityAr, NameEn = cityEn };
                    foreach (var d in districts) city.Districts.Add(new District { NameAr = d });
                    region.Cities.Add(city);
                }
                db.Regions.Add(region);
            }
            log.LogInformation("Seeding {Count} regions", Locations.Length);
        }

        await db.SaveChangesAsync(ct);
        await BackfillCoordinatesAsync(db, ct);

        if (!await db.StoreCategories.AnyAsync(ct))
        {
            var order = 0;
            foreach (var (ar, en, image) in StoreCategories)
            {
                db.StoreCategories.Add(new StoreCategory { NameAr = ar, NameEn = en, ImageUrl = image, SortOrder = order++ });
            }
        }

        await db.SaveChangesAsync(ct);

        // Admin account (signs in with OTP like everyone else). Phone comes from configuration.
        var adminPhone = services.GetRequiredService<IConfiguration>()["Seed:AdminPhone"];
        if (PhoneNumber.TryNormalize(adminPhone, out var phone))
        {
            var users = services.GetRequiredService<UserManager<ApplicationUser>>();
            if (await users.Users.AllAsync(u => u.PhoneNumber != phone, ct))
            {
                var admin = new ApplicationUser { UserName = phone, PhoneNumber = phone, PhoneNumberConfirmed = true, FullName = "مدير ميجا", UserType = UserType.Admin };
                await users.CreateAsync(admin);
                await users.AddToRoleAsync(admin, nameof(UserType.Admin));
                log.LogInformation("Seeded admin {Phone}", phone);
            }
        }
    }

    /// <summary>Fills city / district coordinates that are still empty (databases created before they existed).</summary>
    private static async Task BackfillCoordinatesAsync(MigaDbContext db, CancellationToken ct)
    {
        var cities = await db.Cities.Include(c => c.Districts).Where(c => c.Latitude == null || c.Districts.Any(d => d.Latitude == null)).ToListAsync(ct);
        foreach (var city in cities)
        {
            if (city.Latitude == null && CityCoordinates.TryGetValue(city.NameEn, out var c)) (city.Latitude, city.Longitude) = c;
            foreach (var d in city.Districts.Where(d => d.Latitude == null))
                if (DistrictCoordinates.TryGetValue($"{city.NameEn}/{d.NameAr}", out var p)) (d.Latitude, d.Longitude) = p;
        }
        await db.SaveChangesAsync(ct);
    }
}
