using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Miga.Infrastructure.Persistence;

namespace Miga.Api.Tests;

/// <summary>
/// Boots the real API against a throwaway MySQL database on XAMPP (miga_test_db),
/// dropped and re-migrated once per test run.
/// </summary>
public class MigaApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    public const string AdminPhone = "+966500000009";
    private static int _phoneSeq = 1000;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("ConnectionStrings:Miga", "Server=127.0.0.1;Port=3306;Database=miga_test_db;User=root;Password=;CharSet=utf8mb4;");
        builder.UseSetting("Jwt:Key", "test-only-signing-key-0123456789-abcdefghij");
        builder.UseSetting("Otp:Secret", "test-otp-secret");
        builder.UseSetting("Otp:ExposeCodeInResponse", "true");
        builder.UseSetting("Seed:AdminPhone", AdminPhone);
        builder.UseSetting("RateLimit:AuthPerMinute", "10000");
        builder.UseSetting("Seed:DemoData", "true");
        // Tests drive campaign expiry explicitly instead of the background timer.
        builder.UseSetting("Jobs:CampaignExpiryEnabled", "false");
        // Tests sign the same number in repeatedly; the cooldown itself is covered by a dedicated test.
        builder.UseSetting("Otp:ResendCooldownSeconds", "0");
        // Shared demo accounts sign in from many tests; the per-phone send limit has its own coverage.
        builder.UseSetting("Otp:MaxSendsPerWindow", "1000");
    }

    public async Task InitializeAsync()
    {
        // Drop before the host starts; Program.cs then migrates + seeds the fresh database.
        var options = new DbContextOptionsBuilder<MigaDbContext>()
            .UseMySql("Server=127.0.0.1;Port=3306;Database=miga_test_db;User=root;Password=;", Microsoft.EntityFrameworkCore.ServerVersion.Parse("10.4.28-mariadb"))
            .Options;
        await using var db = new MigaDbContext(options);
        await db.Database.EnsureDeletedAsync();
        _ = Server; // starts the host
    }

    Task IAsyncLifetime.DisposeAsync() => Task.CompletedTask;

    /// <summary>Unique Saudi mobile per test so OTP cooldowns never collide.</summary>
    public static string NewPhone() => $"05{Interlocked.Increment(ref _phoneSeq):D8}";

    public T Service<T>() where T : notnull => Services.CreateScope().ServiceProvider.GetRequiredService<T>();
}

public static class ApiTestExtensions
{
    /// <summary>Like EnsureSuccessStatusCode, but includes the response body (ProblemDetails) in the failure.</summary>
    public static async Task<HttpResponseMessage> EnsureOk(this Task<HttpResponseMessage> call)
    {
        var r = await call;
        if (!r.IsSuccessStatusCode) throw new HttpRequestException($"{(int)r.StatusCode}: {await r.Content.ReadAsStringAsync()}");
        return r;
    }

    public static async Task<AuthResult> SignInAsync(this HttpClient client, string phone, int userType)
    {
        var sent = await client.PostAsJsonAsync("/api/auth/send-otp", new { phone });
        sent.EnsureSuccessStatusCode();
        var code = (await sent.Content.ReadFromJsonAsync<SendOtpResult>())!.DevCode!;
        var verify = await client.PostAsJsonAsync("/api/auth/verify-otp", new { phone, code, userType });
        verify.EnsureSuccessStatusCode();
        var auth = (await verify.Content.ReadFromJsonAsync<AuthResult>())!;
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        return auth;
    }
}

public record SendOtpResult(string Phone, int ExpiresInSeconds, int ResendAfterSeconds, string? DevCode);

public record AccountResult(Guid Id, string FullName, string PhoneNumber, string? Email, int UserType, bool IsProfileComplete, string VerificationStatus, string? RejectionReason = null);

public record AuthResult(string AccessToken, DateTime AccessTokenExpiresAt, string RefreshToken, AccountResult Account);

public record Problem(int Status, string Title, string Code);

/// <summary>
/// One API + one test database for the whole run. All test classes join this collection, so they share
/// the factory (the database is dropped/migrated once) and never race each other.
/// </summary>
[CollectionDefinition(Name)]
public class ApiCollection : ICollectionFixture<MigaApiFactory>
{
    public const string Name = "api";
}
