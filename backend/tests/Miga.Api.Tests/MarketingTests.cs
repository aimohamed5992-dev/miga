using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Miga.Infrastructure.Persistence;

namespace Miga.Api.Tests;

/// <summary>Home banners (admin-managed, linked), favorites, driver profile edits, merchant business details, app config.</summary>
[Collection(ApiCollection.Name)]
public class MarketingTests(MigaApiFactory factory)
{
    private const int Customer = 1, Merchant = 2, Admin = 4;

    private static async Task<string> CodeOf(HttpResponseMessage r) =>
        JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement.GetProperty("code").GetString()!;

    private async Task<HttpClient> AdminAsync()
    {
        var admin = factory.CreateClient();
        await admin.SignInAsync(MigaApiFactory.AdminPhone, Admin);
        return admin;
    }

    private async Task<Guid> AnyCampaignAsync() =>
        (await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/campaigns"))
        .GetProperty("items")[0].GetProperty("id").GetGuid();

    [Fact]
    public async Task Home_returns_seeded_banners_with_real_links()
    {
        var home = await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/home");
        var banners = home.GetProperty("banners").EnumerateArray().ToList();
        Assert.True(banners.Count >= 3);
        Assert.All(banners.Take(3), b => Assert.NotEqual("none", b.GetProperty("linkType").GetString()));
    }

    [Fact]
    public async Task Admin_manages_banners_and_customers_see_only_active_ones()
    {
        var admin = await AdminAsync();
        var campaignId = await AnyCampaignAsync();

        var bad = await admin.PostAsJsonAsync("/api/admin/banners", new { imageUrl = "x.jpg", linkType = "campaign", linkId = Guid.NewGuid(), sortOrder = 9, isActive = true });
        Assert.Equal("invalid_link", await CodeOf(bad));
        var noLink = await admin.PostAsJsonAsync("/api/admin/banners", new { imageUrl = "x.jpg", linkType = "store", sortOrder = 9, isActive = true });
        Assert.Equal("link_required", await CodeOf(noLink));

        var created = await (await admin.PostAsJsonAsync("/api/admin/banners", new
        {
            imageUrl = "banner_2.jpg", titleAr = "بانر الاختبار", linkType = "campaign", linkId = campaignId, sortOrder = 50, isActive = true,
        }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        var id = created.GetProperty("id").GetGuid();
        Assert.False(string.IsNullOrEmpty(created.GetProperty("linkTitle").GetString()));

        var home = await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/home");
        Assert.Contains(home.GetProperty("banners").EnumerateArray(), b => b.GetProperty("id").GetGuid() == id);

        // Hidden when inactive or out of schedule.
        await admin.PutAsJsonAsync($"/api/admin/banners/{id}", new
        {
            imageUrl = "banner_2.jpg", titleAr = "بانر الاختبار", linkType = "campaign", linkId = campaignId, sortOrder = 50, isActive = true,
            startsAt = DateTime.UtcNow.AddDays(2),
        }).EnsureOk();
        home = await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/home");
        Assert.DoesNotContain(home.GetProperty("banners").EnumerateArray(), b => b.GetProperty("id").GetGuid() == id);

        await admin.DeleteAsync($"/api/admin/banners/{id}").EnsureOk();
        Assert.DoesNotContain((await admin.GetFromJsonAsync<JsonElement>("/api/admin/banners")).EnumerateArray(), b => b.GetProperty("id").GetGuid() == id);
    }

    [Fact]
    public async Task Only_admins_manage_banners_or_upload_banner_images()
    {
        var customer = factory.CreateClient();
        await customer.SignInAsync(MigaApiFactory.NewPhone(), Customer);
        Assert.Equal(HttpStatusCode.Forbidden, (await customer.GetAsync("/api/admin/banners")).StatusCode);
        using var form = new MultipartFormDataContent { { new ByteArrayContent([1, 2, 3]), "file", "a.png" } };
        Assert.Equal(HttpStatusCode.Forbidden, (await customer.PostAsync("/api/uploads/banners", form)).StatusCode);
    }

    [Fact]
    public async Task Customer_saves_and_removes_favorite_campaigns()
    {
        var customer = factory.CreateClient();
        await customer.SignInAsync(MigaApiFactory.NewPhone(), Customer);
        var campaignId = await AnyCampaignAsync();

        await customer.PutAsync($"/api/customer/favorites/{campaignId}", null).EnsureOk();
        await customer.PutAsync($"/api/customer/favorites/{campaignId}", null).EnsureOk(); // idempotent
        var list = await customer.GetFromJsonAsync<JsonElement>("/api/customer/favorites");
        Assert.Equal(campaignId, Assert.Single(list.EnumerateArray()).GetProperty("id").GetGuid());

        await customer.DeleteAsync($"/api/customer/favorites/{campaignId}").EnsureOk();
        Assert.Empty((await customer.GetFromJsonAsync<JsonElement>("/api/customer/favorites")).EnumerateArray());
        Assert.Equal(HttpStatusCode.NotFound, (await customer.PutAsync($"/api/customer/favorites/{Guid.NewGuid()}", null)).StatusCode);
    }

    [Fact]
    public async Task Driver_changes_city_and_vehicle_but_not_with_deliveries_in_progress()
    {
        var (driver, _) = await factory.DriverAsync();
        var jeddah = await factory.CityAsync("جدة");
        var home = await (await driver.PatchAsJsonAsync("/api/driver/profile", new { cityId = jeddah, vehicleModel = "إيسوزو 2024", plateNumber = "ط ط ط 1111" })
            .EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("جدة", home.GetProperty("cityName").GetString());
        Assert.Equal("ط ط ط 1111", home.GetProperty("vehicle").GetProperty("plateNumber").GetString());

        // Riyadh ready order → driver back in Riyadh accepts it → can't move city mid-delivery.
        var s = await factory.ReadyOrderAsync();
        await driver.PatchAsJsonAsync("/api/driver/profile", new { cityId = await factory.CityAsync("الرياض") }).EnsureOk();
        await driver.PostAsync($"/api/driver/deliveries/{s.DeliveryIds[0]}/accept", null).EnsureOk();
        var refused = await driver.PatchAsJsonAsync("/api/driver/profile", new { cityId = jeddah });
        Assert.Equal("deliveries_in_progress", await CodeOf(refused));
    }

    [Fact]
    public async Task Merchant_sees_business_details_and_app_config_has_support_contacts()
    {
        var merchant = factory.CreateClient();
        await merchant.SignInAsync(DemoSeeder.MerchantPhone, Merchant);
        var b = await merchant.GetFromJsonAsync<JsonElement>("/api/merchant/business");
        Assert.Equal("1010456789", b.GetProperty("commercialRegistrationNumber").GetString());
        Assert.True(b.GetProperty("isVerified").GetBoolean());
        Assert.True(b.GetProperty("storesCount").GetInt32() >= 4);

        var config = await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/config");
        Assert.Equal(5m, config.GetProperty("platformFeePercent").GetDecimal());
        Assert.True(config.GetProperty("support").TryGetProperty("email", out _));
    }
}
