using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Miga.Domain.Entities;

namespace Miga.Infrastructure.Persistence;

public class MigaDbContext(DbContextOptions<MigaDbContext> options)
    : IdentityDbContext<ApplicationUser, IdentityRole<Guid>, Guid>(options)
{
    public DbSet<CustomerProfile> CustomerProfiles => Set<CustomerProfile>();
    public DbSet<MerchantProfile> MerchantProfiles => Set<MerchantProfile>();
    public DbSet<MerchantPayout> MerchantPayouts => Set<MerchantPayout>();
    public DbSet<DriverProfile> DriverProfiles => Set<DriverProfile>();
    public DbSet<OtpCode> OtpCodes => Set<OtpCode>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    public DbSet<Region> Regions => Set<Region>();
    public DbSet<City> Cities => Set<City>();
    public DbSet<District> Districts => Set<District>();
    public DbSet<Address> Addresses => Set<Address>();
    public DbSet<Banner> Banners => Set<Banner>();
    public DbSet<FavoriteCampaign> FavoriteCampaigns => Set<FavoriteCampaign>();
    public DbSet<PlatformSettings> PlatformSettings => Set<PlatformSettings>();

    public DbSet<StoreCategory> StoreCategories => Set<StoreCategory>();
    public DbSet<Store> Stores => Set<Store>();
    public DbSet<ProductCategory> ProductCategories => Set<ProductCategory>();
    public DbSet<Product> Products => Set<Product>();
    public DbSet<ProductImage> ProductImages => Set<ProductImage>();

    public DbSet<Campaign> Campaigns => Set<Campaign>();
    public DbSet<Cart> Carts => Set<Cart>();
    public DbSet<CartItem> CartItems => Set<CartItem>();
    public DbSet<CampaignOrder> CampaignOrders => Set<CampaignOrder>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<MerchantOrder> MerchantOrders => Set<MerchantOrder>();
    public DbSet<Delivery> Deliveries => Set<Delivery>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        // Arabic text everywhere: full Unicode.
        builder.HasCharSet("utf8mb4").UseCollation("utf8mb4_unicode_ci");
        builder.ApplyConfigurationsFromAssembly(typeof(MigaDbContext).Assembly);

        // Ids are assigned in code (Entity.Id = Guid.NewGuid()). Telling EF the key is never store-generated
        // makes new entities attached through navigations (e.g. user.CustomerProfile = new()) INSERTs, not UPDATEs.
        foreach (var type in builder.Model.GetEntityTypes().Where(t => typeof(Entity).IsAssignableFrom(t.ClrType)))
        {
            builder.Entity(type.ClrType).Property(nameof(Entity.Id)).ValueGeneratedNever();
        }

        // MySQL can't index unbounded text; Identity's phone column is the login key here.
        builder.Entity<ApplicationUser>(e =>
        {
            e.Property(x => x.FullName).HasMaxLength(150);
            e.Property(x => x.SuspensionReason).HasMaxLength(500);
            e.Property(x => x.PhoneNumber).HasMaxLength(20);
            e.HasIndex(x => x.PhoneNumber).IsUnique();
        });

        // Every money column: decimal(18,2). Coordinates keep more precision.
        foreach (var property in builder.Model.GetEntityTypes().SelectMany(t => t.GetProperties()))
        {
            if (property.ClrType != typeof(decimal) && property.ClrType != typeof(decimal?)) continue;
            var coordinate = property.Name.EndsWith("Latitude") || property.Name.EndsWith("Longitude");
            property.SetPrecision(coordinate ? 10 : 18);
            property.SetScale(coordinate ? 7 : 2);
        }
    }
}
