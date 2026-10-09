using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Miga.Api.Infrastructure;
using Miga.Infrastructure;
using Miga.Infrastructure.Auth;
using Miga.Infrastructure.Persistence;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddInfrastructure(builder.Configuration);

// ---- Authentication: short-lived JWT access tokens (+ rotating refresh tokens) ----
var jwt = builder.Configuration.GetSection(JwtOptions.Section).Get<JwtOptions>() ?? new JwtOptions();
if (jwt.Key.Length < 32) throw new InvalidOperationException("Jwt:Key must be at least 32 characters (set it via user-secrets or environment).");

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false;
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidIssuer = jwt.Issuer,
            ValidAudience = jwt.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            NameClaimType = System.Security.Claims.ClaimTypes.NameIdentifier,
            RoleClaimType = System.Security.Claims.ClaimTypes.Role,
            ClockSkew = TimeSpan.FromSeconds(30),
        };
        // A suspended account loses access at once, not when its access token expires
        // (one primary-key lookup per authenticated request).
        o.Events = new JwtBearerEvents
        {
            OnTokenValidated = async ctx =>
            {
                var id = Guid.TryParse(ctx.Principal?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value, out var g) ? g : Guid.Empty;
                var db = ctx.HttpContext.RequestServices.GetRequiredService<MigaDbContext>();
                if (!await db.Users.AnyAsync(u => u.Id == id && u.IsActive, ctx.HttpContext.RequestAborted)) ctx.Fail("account_disabled");
            },
        };
    });
builder.Services.AddAuthorization();

// ---- CORS for the admin web dashboard (the mobile apps don't need it) ----
// Development allows any localhost port (flutter run -d chrome picks one); production lists origins in Cors:Origins.
var corsOrigins = builder.Configuration.GetSection("Cors:Origins").Get<string[]>() ?? [];
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p
    .SetIsOriginAllowed(origin =>
        corsOrigins.Contains(origin, StringComparer.OrdinalIgnoreCase)
        || (builder.Environment.IsDevelopment() && Uri.TryCreate(origin, UriKind.Absolute, out var u) && u.IsLoopback))
    .AllowAnyHeader()
    .AllowAnyMethod()));

// ---- Abuse protection on sign-in endpoints (per client IP) ----
var authPerMinute = builder.Configuration.GetValue("RateLimit:AuthPerMinute", 30);
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.AddPolicy("auth", http => RateLimitPartition.GetFixedWindowLimiter(
        http.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = authPerMinute, Window = TimeSpan.FromMinutes(1) }));
});

// ---- Errors: ProblemDetails with an Arabic title and a stable `code` ----
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<ApiExceptionHandler>();
builder.Services.AddControllers().ConfigureApiBehaviorOptions(o =>
{
    o.InvalidModelStateResponseFactory = ctx => new BadRequestObjectResult(new ValidationProblemDetails(ctx.ModelState)
    {
        Status = 400,
        Title = "البيانات المدخلة غير صحيحة",
        Extensions = { ["code"] = "validation_error" },
    });
});
builder.Services.AddOpenApi();
builder.Services.AddHostedService<CampaignExpiryWorker>();

var app = builder.Build();

app.UseExceptionHandler();
app.UseStatusCodePages();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

if (app.Environment.IsDevelopment() || app.Environment.IsEnvironment("Testing"))
{
    // Dev convenience: bring the XAMPP database up to date and seed reference data on startup.
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<MigaDbContext>().Database.MigrateAsync();
    await DbSeeder.SeedAsync(scope.ServiceProvider);
    if (app.Configuration.GetValue("Seed:DemoData", false)) await DemoSeeder.SeedAsync(scope.ServiceProvider);
}

// Uploaded images (wwwroot/uploads). Production: serve from object storage / CDN instead.
app.UseStaticFiles();
app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.Run();

/// <summary>Exposed for integration tests (WebApplicationFactory).</summary>
public partial class Program;
