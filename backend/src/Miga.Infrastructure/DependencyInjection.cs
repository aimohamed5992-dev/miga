using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Miga.Domain.Entities;
using Miga.Infrastructure.Auth;
using Miga.Infrastructure.Common;
using Miga.Infrastructure.Features.Addresses;
using Miga.Infrastructure.Features.Cart;
using Miga.Infrastructure.Features.Admin;
using Miga.Infrastructure.Features.Driver;
using Miga.Infrastructure.Features.Orders;
using Miga.Infrastructure.Notifications;
using Miga.Infrastructure.Payments;
using Miga.Infrastructure.Features.Catalog;
using Miga.Infrastructure.Features.MerchantCatalog;
using Miga.Infrastructure.Features.MerchantSales;
using Miga.Infrastructure.Features.Marketing;
using Miga.Infrastructure.Files;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure;

public static class DependencyInjection
{
    /// <summary>MySQL (XAMPP MariaDB) via Pomelo + ASP.NET Core Identity stores.</summary>
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration config)
    {
        var connection = config.GetConnectionString("Miga") ?? throw new InvalidOperationException("ConnectionStrings:Miga is missing.");
        var version = config["Database:ServerVersion"] ?? "10.4.28-mariadb";

        services.AddDbContext<MigaDbContext>(options =>
            options.UseMySql(connection, ServerVersion.Parse(version), mysql =>
            {
                mysql.MigrationsAssembly(typeof(MigaDbContext).Assembly.FullName);
                mysql.SchemaBehavior(Pomelo.EntityFrameworkCore.MySql.Infrastructure.MySqlSchemaBehavior.Ignore);
            }));

        services
            .AddIdentityCore<ApplicationUser>(o =>
            {
                // Phone + OTP login: no passwords, phone is the unique identity.
                o.User.RequireUniqueEmail = false;
                o.SignIn.RequireConfirmedPhoneNumber = false;
            })
            .AddRoles<IdentityRole<Guid>>()
            .AddEntityFrameworkStores<MigaDbContext>();

        services.Configure<JwtOptions>(config.GetSection(JwtOptions.Section));
        services.Configure<OtpOptions>(config.GetSection(OtpOptions.Section));
        services.AddSingleton(TimeProvider.System);
        services.AddSingleton<ISmsSender, LogSmsSender>();
        services.AddScoped<OtpService>();
        services.AddScoped<TokenService>();
        services.AddScoped<AccountService>();
        services.AddScoped<AddressService>();
        services.AddScoped<CatalogQueries>();
        services.AddScoped<MerchantCatalogService>();
        services.AddSingleton<IFileStorage, LocalFileStorage>();

        services.Configure<CommerceOptions>(config.GetSection(CommerceOptions.Section));
        services.AddSingleton<IPaymentGateway, MockPaymentGateway>();
        services.AddScoped<Notifier>();
        services.AddScoped<CartService>();
        services.AddScoped<CampaignLifecycleService>();
        services.AddScoped<CheckoutService>();
        services.AddScoped<CustomerOrderQueries>();
        services.AddScoped<MerchantCampaignService>();
        services.AddScoped<MerchantOrderService>();
        services.AddScoped<MerchantInsightsService>();
        services.AddScoped<DriverService>();
        services.AddScoped<AdminService>();
        services.AddScoped<AdminOperationsService>();
        services.AddScoped<AdminMapService>();
        services.AddScoped<Miga.Infrastructure.Features.Settings.PlatformSettingsService>();
        services.AddScoped<MarketingService>();

        return services;
    }
}
