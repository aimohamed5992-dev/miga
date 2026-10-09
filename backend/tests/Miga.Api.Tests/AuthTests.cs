using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Miga.Domain.Common;

namespace Miga.Api.Tests;

[Collection(ApiCollection.Name)]
public class AuthTests(MigaApiFactory factory)
{
    private const int Customer = 1, Merchant = 2, Driver = 3;

    private static async Task<Problem> ProblemOf(HttpResponseMessage r)
    {
        var json = JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement;
        return new Problem(json.GetProperty("status").GetInt32(), json.GetProperty("title").GetString()!, json.GetProperty("code").GetString()!);
    }

    [Theory]
    [InlineData("0551234567")]
    [InlineData("551234567")]
    [InlineData("+966551234567")]
    [InlineData("00966551234567")]
    [InlineData("٠٥٥١٢٣٤٥٦٧")]
    public void Phone_numbers_normalize_to_E164(string input) => Assert.Equal("+966551234567", PhoneNumber.Normalize(input));

    [Theory]
    [InlineData("0451234567")]
    [InlineData("12345")]
    [InlineData("")]
    public void Invalid_phone_numbers_are_rejected(string input) => Assert.False(PhoneNumber.TryNormalize(input, out _));

    [Fact]
    public async Task Customer_signs_in_then_completes_profile()
    {
        var client = factory.CreateClient();
        var auth = await client.SignInAsync(MigaApiFactory.NewPhone(), Customer);

        Assert.False(auth.Account.IsProfileComplete);
        Assert.Equal(Customer, auth.Account.UserType);

        var me = await client.GetFromJsonAsync<AccountResult>("/api/auth/me");
        Assert.Equal(auth.Account.Id, me!.Id);

        var updated = await client.PutAsJsonAsync("/api/customer/profile", new { fullName = "محمد العتيبي", email = "m@example.com" });
        updated.EnsureSuccessStatusCode();
        var account = await updated.Content.ReadFromJsonAsync<AccountResult>();
        Assert.True(account!.IsProfileComplete);
        Assert.Equal("محمد العتيبي", account.FullName);
    }

    [Fact]
    public async Task Same_number_in_any_format_is_the_same_account()
    {
        var local = MigaApiFactory.NewPhone(); // 05XXXXXXXX
        var first = await factory.CreateClient().SignInAsync(local, Customer);
        var second = await factory.CreateClient().SignInAsync("+966" + local[1..], Customer);
        Assert.Equal(first.Account.Id, second.Account.Id);
    }

    [Fact]
    public async Task Wrong_code_is_rejected_and_locks_after_max_attempts()
    {
        var client = factory.CreateClient();
        var phone = MigaApiFactory.NewPhone();
        (await client.PostAsJsonAsync("/api/auth/send-otp", new { phone })).EnsureSuccessStatusCode();

        var wrong = await client.PostAsJsonAsync("/api/auth/verify-otp", new { phone, code = "99999", userType = Customer });
        var p = await ProblemOf(wrong);
        Assert.Equal(HttpStatusCode.BadRequest, wrong.StatusCode);
        Assert.Equal("otp_invalid", p.Code);
        Assert.Equal("الرمز غير صحيح، حاول مرة أخرى", p.Title);

        for (var i = 0; i < 4; i++) await client.PostAsJsonAsync("/api/auth/verify-otp", new { phone, code = "99999", userType = Customer });
        var locked = await client.PostAsJsonAsync("/api/auth/verify-otp", new { phone, code = "99999", userType = Customer });
        Assert.Equal(HttpStatusCode.TooManyRequests, locked.StatusCode);
        Assert.Equal("otp_attempts", (await ProblemOf(locked)).Code);
    }

    [Fact]
    public async Task Code_cannot_be_reused_and_resend_has_a_cooldown()
    {
        var client = factory.WithWebHostBuilder(b => b.UseSetting("Otp:ResendCooldownSeconds", "60")).CreateClient();
        var phone = MigaApiFactory.NewPhone();
        var sent = await (await client.PostAsJsonAsync("/api/auth/send-otp", new { phone })).Content.ReadFromJsonAsync<SendOtpResult>();

        var tooSoon = await client.PostAsJsonAsync("/api/auth/send-otp", new { phone });
        Assert.Equal(HttpStatusCode.TooManyRequests, tooSoon.StatusCode);
        Assert.Equal("otp_cooldown", (await ProblemOf(tooSoon)).Code);

        (await client.PostAsJsonAsync("/api/auth/verify-otp", new { phone, code = sent!.DevCode, userType = Customer })).EnsureSuccessStatusCode();
        var reuse = await client.PostAsJsonAsync("/api/auth/verify-otp", new { phone, code = sent.DevCode, userType = Customer });
        Assert.Equal("otp_expired", (await ProblemOf(reuse)).Code);
    }

    [Fact]
    public async Task A_customer_number_cannot_sign_in_to_the_merchant_app()
    {
        var phone = MigaApiFactory.NewPhone();
        await factory.CreateClient().SignInAsync(phone, Customer);

        var client = factory.CreateClient();
        var code = (await (await client.PostAsJsonAsync("/api/auth/send-otp", new { phone })).Content.ReadFromJsonAsync<SendOtpResult>())!.DevCode;
        var r = await client.PostAsJsonAsync("/api/auth/verify-otp", new { phone, code, userType = Merchant });
        Assert.Equal(HttpStatusCode.Conflict, r.StatusCode);
        Assert.Equal("phone_registered_as_other_type", (await ProblemOf(r)).Code);
    }

    [Fact]
    public async Task Refresh_token_rotates_and_old_one_is_rejected()
    {
        var client = factory.CreateClient();
        var auth = await client.SignInAsync(MigaApiFactory.NewPhone(), Customer);

        var refreshed = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = auth.RefreshToken });
        refreshed.EnsureSuccessStatusCode();
        var next = await refreshed.Content.ReadFromJsonAsync<AuthResult>();
        Assert.NotEqual(auth.RefreshToken, next!.RefreshToken);

        var reused = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = auth.RefreshToken });
        Assert.Equal(HttpStatusCode.Unauthorized, reused.StatusCode);
    }

    [Fact]
    public async Task Endpoints_enforce_roles()
    {
        var anonymous = factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.GetAsync("/api/auth/me")).StatusCode);

        var customer = factory.CreateClient();
        await customer.SignInAsync(MigaApiFactory.NewPhone(), Customer);
        var r = await customer.PostAsJsonAsync("/api/merchant/register", new { });
        Assert.Equal(HttpStatusCode.Forbidden, r.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await customer.GetAsync("/api/admin/pending")).StatusCode);
    }

    [Fact]
    public async Task Merchant_registers_is_pending_then_admin_verifies()
    {
        var categories = await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/store-categories");
        var categoryId = categories[0].GetProperty("id").GetGuid();

        var merchant = factory.CreateClient();
        var auth = await merchant.SignInAsync(MigaApiFactory.NewPhone(), Merchant);
        Assert.Equal("not_submitted", auth.Account.VerificationStatus);

        var reg = await merchant.PostAsJsonAsync("/api/merchant/register", new
        {
            ownerName = "سعود الحربي",
            businessNameAr = "مؤسسة الخير للتجارة",
            commercialRegistrationNumber = "1010456789",
            storeNameAr = "أسواق الخير",
            storeCategoryId = categoryId,
        });
        reg.EnsureSuccessStatusCode();
        Assert.Equal("pending", (await reg.Content.ReadFromJsonAsync<AccountResult>())!.VerificationStatus);

        var again = await merchant.PostAsJsonAsync("/api/merchant/register", new
        {
            ownerName = "سعود الحربي", businessNameAr = "مؤسسة أخرى", commercialRegistrationNumber = "1010456789", storeNameAr = "متجر ثاني", storeCategoryId = categoryId,
        });
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);

        var admin = factory.CreateClient();
        await admin.SignInAsync(MigaApiFactory.AdminPhone, Customer); // admin may sign in from any app
        var pending = await admin.GetFromJsonAsync<JsonElement>("/api/admin/pending");
        Assert.Contains(pending.GetProperty("merchants").EnumerateArray(), m => m.GetProperty("userId").GetGuid() == auth.Account.Id);

        (await admin.PostAsync($"/api/admin/merchants/{auth.Account.Id}/verify", null)).EnsureSuccessStatusCode();
        Assert.Equal("verified", (await merchant.GetFromJsonAsync<AccountResult>("/api/auth/me"))!.VerificationStatus);
    }

    [Fact]
    public async Task Driver_registration_validates_input_and_city()
    {
        var regions = await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/regions");
        var cityId = regions[0].GetProperty("cities")[0].GetProperty("id").GetGuid();

        var driver = factory.CreateClient();
        await driver.SignInAsync(MigaApiFactory.NewPhone(), Driver);

        var badId = await driver.PostAsJsonAsync("/api/driver/register", new
        {
            fullName = "عبدالرحمن السبيعي", nationalId = "123", cityId, vehicleType = "فان", vehiclePlateNumber = "أ ب ج 1234",
        });
        Assert.Equal(HttpStatusCode.BadRequest, badId.StatusCode);
        Assert.Equal("validation_error", (await ProblemOf(badId)).Code);

        var badCity = await driver.PostAsJsonAsync("/api/driver/register", new
        {
            fullName = "عبدالرحمن السبيعي", nationalId = "1012345678", cityId = Guid.NewGuid(), vehicleType = "فان", vehiclePlateNumber = "أ ب ج 1234",
        });
        Assert.Equal("invalid_city", (await ProblemOf(badCity)).Code);

        var ok = await driver.PostAsJsonAsync("/api/driver/register", new
        {
            fullName = "عبدالرحمن السبيعي", nationalId = "1012345678", cityId, vehicleType = "فان", vehiclePlateNumber = "أ ب ج 1234",
        });
        ok.EnsureSuccessStatusCode();
        Assert.Equal("pending", (await ok.Content.ReadFromJsonAsync<AccountResult>())!.VerificationStatus);
    }

    [Fact]
    public async Task Validation_errors_use_the_shared_problem_shape()
    {
        var r = await factory.CreateClient().PostAsJsonAsync("/api/auth/send-otp", new { phone = "123" });
        var p = await ProblemOf(r);
        Assert.Equal(400, p.Status);
        Assert.Equal("invalid_phone", p.Code);
    }

    [Fact]
    public async Task Expired_or_invalid_token_is_rejected()
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", "not-a-jwt");
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/auth/me")).StatusCode);
    }
}
