using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace Miga.Api.Tests;

/// <summary>Admin dashboard API: admin-only sign-in, platform numbers, review queue (verify / reject / resubmit), users, suspension.</summary>
[Collection(ApiCollection.Name)]
public class AdminTests(MigaApiFactory factory)
{
    private const int Customer = 1, Merchant = 2, Driver = 3, Admin = 4;

    private static async Task<string> CodeOf(HttpResponseMessage r) =>
        JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement.GetProperty("code").GetString()!;

    private async Task<HttpClient> AdminAsync()
    {
        var admin = factory.CreateClient();
        await admin.SignInAsync(MigaApiFactory.AdminPhone, Admin);
        return admin;
    }

    private async Task<Guid> StoreCategoryAsync() =>
        (await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/store-categories"))[0].GetProperty("id").GetGuid();

    private async Task<Guid> CityAsync() =>
        (await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/regions"))[0].GetProperty("cities")[0].GetProperty("id").GetGuid();

    private async Task<(HttpClient Client, AuthResult Auth)> RegisteredMerchantAsync(string store = "متجر المراجعة")
    {
        var client = factory.CreateClient();
        var auth = await client.SignInAsync(MigaApiFactory.NewPhone(), Merchant);
        await client.PostAsJsonAsync("/api/merchant/register", new
        {
            ownerName = "ماجد العنزي", businessNameAr = "مؤسسة المراجعة", commercialRegistrationNumber = "1010999999",
            storeNameAr = store, storeCategoryId = await StoreCategoryAsync(),
        }).EnsureOk();
        return (client, auth);
    }

    [Fact]
    public async Task Admin_app_accepts_only_admin_numbers_and_never_creates_accounts()
    {
        var admin = factory.CreateClient();
        var auth = await admin.SignInAsync(MigaApiFactory.AdminPhone, Admin);
        Assert.Equal(Admin, auth.Account.UserType);

        var stranger = factory.CreateClient();
        var phone = MigaApiFactory.NewPhone();
        var sent = await (await stranger.PostAsJsonAsync("/api/auth/send-otp", new { phone })).Content.ReadFromJsonAsync<SendOtpResult>();
        var denied = await stranger.PostAsJsonAsync("/api/auth/verify-otp", new { phone, code = sent!.DevCode, userType = Admin });
        Assert.Equal(HttpStatusCode.Forbidden, denied.StatusCode);
        Assert.Equal("not_admin", await CodeOf(denied));

        var users = await admin.GetFromJsonAsync<JsonElement>($"/api/admin/users?type=customer&q={phone}");
        Assert.Equal(0, users.GetProperty("totalCount").GetInt32());
    }

    [Fact]
    public async Task Non_admins_cannot_use_admin_endpoints()
    {
        var customer = factory.CreateClient();
        await customer.SignInAsync(MigaApiFactory.NewPhone(), Customer);
        Assert.Equal(HttpStatusCode.Forbidden, (await customer.GetAsync("/api/admin/dashboard")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await factory.CreateClient().GetAsync("/api/admin/users")).StatusCode);
    }

    [Fact]
    public async Task Dashboard_reports_platform_numbers_for_14_days()
    {
        var admin = await AdminAsync();
        var d = await admin.GetFromJsonAsync<JsonElement>("/api/admin/dashboard");
        var counts = d.GetProperty("counts");
        Assert.True(counts.GetProperty("merchants").GetInt32() >= 1); // demo merchant
        Assert.True(counts.GetProperty("drivers").GetInt32() >= 1); // demo driver
        Assert.True(counts.GetProperty("activeStores").GetInt32() >= 4);
        Assert.True(counts.GetProperty("activeCampaigns").GetInt32() >= 1);
        Assert.Equal(14, d.GetProperty("days").GetArrayLength());
    }

    [Fact]
    public async Task Rejected_merchant_sees_the_reason_resubmits_and_is_then_verified()
    {
        var (merchant, auth) = await RegisteredMerchantAsync();
        var admin = await AdminAsync();

        var queue = await admin.GetFromJsonAsync<JsonElement>("/api/admin/verifications?type=merchant&status=pending");
        var item = queue.EnumerateArray().Single(i => i.GetProperty("userId").GetGuid() == auth.Account.Id);
        Assert.Equal("مؤسسة المراجعة", item.GetProperty("businessNameAr").GetString());
        Assert.Equal("متجر المراجعة", item.GetProperty("storeName").GetString());

        var tooShort = await admin.PostAsJsonAsync($"/api/admin/merchants/{auth.Account.Id}/reject", new { reason = "x" });
        Assert.Equal(HttpStatusCode.BadRequest, tooShort.StatusCode);
        await admin.PostAsJsonAsync($"/api/admin/merchants/{auth.Account.Id}/reject", new { reason = "صورة السجل التجاري غير واضحة" }).EnsureOk();

        var me = await merchant.GetFromJsonAsync<AccountResult>("/api/auth/me");
        Assert.Equal("rejected", me!.VerificationStatus);
        Assert.Equal("صورة السجل التجاري غير واضحة", me.RejectionReason);
        var notes = await merchant.GetFromJsonAsync<JsonElement>("/api/notifications");
        Assert.Contains(notes.EnumerateArray(), n => n.GetProperty("body").GetString()!.Contains("صورة السجل التجاري غير واضحة"));
        Assert.Contains((await admin.GetFromJsonAsync<JsonElement>("/api/admin/verifications?type=merchant&status=rejected")).EnumerateArray(),
            i => i.GetProperty("userId").GetGuid() == auth.Account.Id);
        // Rejected accounts wait for the merchant, so they are not in the "pending" users filter.
        var pendingUsers = await admin.GetFromJsonAsync<JsonElement>("/api/admin/users?type=merchant&status=pending&pageSize=50");
        Assert.DoesNotContain(pendingUsers.GetProperty("items").EnumerateArray(), u => u.GetProperty("id").GetGuid() == auth.Account.Id);
        var rejectedUsers = await admin.GetFromJsonAsync<JsonElement>("/api/admin/users?type=merchant&status=rejected&pageSize=50");
        Assert.Contains(rejectedUsers.GetProperty("items").EnumerateArray(), u => u.GetProperty("id").GetGuid() == auth.Account.Id);
        var verifiedUsers = await admin.GetFromJsonAsync<JsonElement>("/api/admin/users?type=merchant&status=verified&pageSize=50");
        Assert.All(verifiedUsers.GetProperty("items").EnumerateArray(), u => Assert.Equal("verified", u.GetProperty("verification").GetString()));

        // Resubmitting updates the same profile and store (no second store) and goes back to the queue.
        var resubmit = await merchant.PostAsJsonAsync("/api/merchant/register", new
        {
            ownerName = "ماجد العنزي", businessNameAr = "مؤسسة المراجعة الحديثة", commercialRegistrationNumber = "1010999998",
            storeNameAr = "متجر بعد التعديل", storeCategoryId = await StoreCategoryAsync(),
        }).EnsureOk();
        Assert.Equal("pending", (await resubmit.Content.ReadFromJsonAsync<AccountResult>())!.VerificationStatus);
        var stores = await merchant.GetFromJsonAsync<JsonElement>("/api/merchant/stores");
        Assert.Equal("متجر بعد التعديل", Assert.Single(stores.EnumerateArray()).GetProperty("nameAr").GetString());

        await admin.PostAsync($"/api/admin/merchants/{auth.Account.Id}/verify", null).EnsureOk();
        Assert.Equal("verified", (await merchant.GetFromJsonAsync<AccountResult>("/api/auth/me"))!.VerificationStatus);
        var rejectVerified = await admin.PostAsJsonAsync($"/api/admin/merchants/{auth.Account.Id}/reject", new { reason = "سبب متأخر" });
        Assert.Equal("already_verified", await CodeOf(rejectVerified));
    }

    [Fact]
    public async Task Rejected_driver_can_resubmit()
    {
        var driver = factory.CreateClient();
        var auth = await driver.SignInAsync(MigaApiFactory.NewPhone(), Driver);
        var body = new { fullName = "سالم الدوسري", nationalId = "1012345670", cityId = await CityAsync(), vehicleType = "car", vehiclePlateNumber = "ب ج د 4321" };
        await driver.PostAsJsonAsync("/api/driver/register", body).EnsureOk();

        var admin = await AdminAsync();
        var queue = await admin.GetFromJsonAsync<JsonElement>("/api/admin/verifications?type=driver");
        Assert.Equal("ب ج د 4321", queue.EnumerateArray().Single(i => i.GetProperty("userId").GetGuid() == auth.Account.Id).GetProperty("plateNumber").GetString());

        await admin.PostAsJsonAsync($"/api/admin/drivers/{auth.Account.Id}/reject", new { reason = "رخصة القيادة منتهية" }).EnsureOk();
        Assert.Equal("rejected", (await driver.GetFromJsonAsync<AccountResult>("/api/auth/me"))!.VerificationStatus);

        await driver.PostAsJsonAsync("/api/driver/register", body with { vehiclePlateNumber = "ب ج د 9999" }).EnsureOk();
        Assert.Equal("pending", (await driver.GetFromJsonAsync<AccountResult>("/api/auth/me"))!.VerificationStatus);
        await admin.PostAsync($"/api/admin/drivers/{auth.Account.Id}/verify", null).EnsureOk();
        var home = await driver.GetFromJsonAsync<JsonElement>("/api/driver/home");
        Assert.True(home.GetProperty("isVerified").GetBoolean());
        Assert.Equal("ب ج د 9999", home.GetProperty("vehicle").GetProperty("plateNumber").GetString());
    }

    [Fact]
    public async Task Users_are_searchable_by_name_phone_or_business_and_have_details()
    {
        var (_, auth) = await RegisteredMerchantAsync("متجر البحث");
        var admin = await AdminAsync();
        var local = "0" + auth.Account.PhoneNumber[4..];

        var byPhone = await admin.GetFromJsonAsync<JsonElement>($"/api/admin/users?type=merchant&q={local}");
        var row = Assert.Single(byPhone.GetProperty("items").EnumerateArray());
        Assert.Equal("pending", row.GetProperty("verification").GetString());
        Assert.Equal(1, row.GetProperty("storesCount").GetInt32());

        var byBusiness = await admin.GetFromJsonAsync<JsonElement>("/api/admin/users?type=merchant&q=" + Uri.EscapeDataString("مؤسسة المراجعة"));
        Assert.Contains(byBusiness.GetProperty("items").EnumerateArray(), u => u.GetProperty("id").GetGuid() == auth.Account.Id);
        var pending = await admin.GetFromJsonAsync<JsonElement>("/api/admin/users?type=merchant&status=pending&pageSize=50");
        Assert.Contains(pending.GetProperty("items").EnumerateArray(), u => u.GetProperty("id").GetGuid() == auth.Account.Id);

        var detail = await admin.GetFromJsonAsync<JsonElement>($"/api/admin/users/{auth.Account.Id}");
        Assert.Equal("متجر البحث", Assert.Single(detail.GetProperty("stores").EnumerateArray()).GetProperty("nameAr").GetString());

        var demo = await admin.GetFromJsonAsync<JsonElement>("/api/admin/users?type=driver&q=0522222222");
        Assert.Equal("الرياض", Assert.Single(demo.GetProperty("items").EnumerateArray()).GetProperty("city").GetString());
    }

    [Fact]
    public async Task Suspension_cuts_access_immediately_and_reactivation_restores_it()
    {
        var customer = factory.CreateClient();
        var phone = MigaApiFactory.NewPhone();
        var auth = await customer.SignInAsync(phone, Customer);
        var admin = await AdminAsync();

        var noReason = await admin.PatchAsJsonAsync($"/api/admin/users/{auth.Account.Id}/active", new { active = false });
        Assert.Equal("reason_required", await CodeOf(noReason));
        await admin.PatchAsJsonAsync($"/api/admin/users/{auth.Account.Id}/active", new { active = false, reason = "إساءة استخدام" }).EnsureOk();

        // The still-unexpired access token and the refresh token stop working at once.
        Assert.Equal(HttpStatusCode.Unauthorized, (await customer.GetAsync("/api/auth/me")).StatusCode);
        var refresh = await factory.CreateClient().PostAsJsonAsync("/api/auth/refresh", new { refreshToken = auth.RefreshToken });
        Assert.Equal(HttpStatusCode.Unauthorized, refresh.StatusCode);
        var again = factory.CreateClient();
        var sent = await (await again.PostAsJsonAsync("/api/auth/send-otp", new { phone })).Content.ReadFromJsonAsync<SendOtpResult>();
        var signIn = await again.PostAsJsonAsync("/api/auth/verify-otp", new { phone, code = sent!.DevCode, userType = Customer });
        Assert.Equal("account_disabled", await CodeOf(signIn));

        var row = await admin.GetFromJsonAsync<JsonElement>($"/api/admin/users/{auth.Account.Id}");
        Assert.Equal("إساءة استخدام", row.GetProperty("user").GetProperty("suspensionReason").GetString());

        await admin.PatchAsJsonAsync($"/api/admin/users/{auth.Account.Id}/active", new { active = true }).EnsureOk();
        await factory.CreateClient().SignInAsync(phone, Customer);
    }

    [Fact]
    public async Task Suspending_a_merchant_hides_their_stores_until_reactivated()
    {
        var (merchant, auth) = await RegisteredMerchantAsync("متجر سيُوقف");
        var admin = await AdminAsync();
        await admin.PostAsync($"/api/admin/merchants/{auth.Account.Id}/verify", null).EnsureOk();
        var storeId = (await merchant.GetFromJsonAsync<JsonElement>("/api/merchant/stores"))[0].GetProperty("id").GetGuid();
        var publicClient = factory.CreateClient();
        Assert.Equal(HttpStatusCode.OK, (await publicClient.GetAsync($"/api/stores/{storeId}")).StatusCode);

        await admin.PatchAsJsonAsync($"/api/admin/users/{auth.Account.Id}/active", new { active = false, reason = "مخالفة شروط البيع" }).EnsureOk();
        Assert.Equal(HttpStatusCode.NotFound, (await publicClient.GetAsync($"/api/stores/{storeId}")).StatusCode);

        await admin.PatchAsJsonAsync($"/api/admin/users/{auth.Account.Id}/active", new { active = true }).EnsureOk();
        Assert.Equal(HttpStatusCode.OK, (await publicClient.GetAsync($"/api/stores/{storeId}")).StatusCode);
    }

    [Fact]
    public async Task Admin_cannot_suspend_their_own_account()
    {
        var admin = factory.CreateClient();
        var me = await admin.SignInAsync(MigaApiFactory.AdminPhone, Admin);
        var self = await admin.PatchAsJsonAsync($"/api/admin/users/{me.Account.Id}/active", new { active = false, reason = "تجربة" });
        Assert.Equal("cannot_suspend_self", await CodeOf(self));
    }
}
