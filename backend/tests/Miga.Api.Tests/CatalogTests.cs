using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Miga.Infrastructure.Persistence;

namespace Miga.Api.Tests;

[Collection(ApiCollection.Name)]
public class CatalogTests(MigaApiFactory factory)
{
    private const int Customer = 1, Merchant = 2;

    private static async Task<string> CodeOf(HttpResponseMessage r) =>
        JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement.GetProperty("code").GetString()!;

    private async Task<(Guid Region, Guid City, Guid District, Guid OtherCityDistrict)> LocationsAsync()
    {
        var regions = await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/regions");
        var riyadhRegion = regions[0];
        var city = riyadhRegion.GetProperty("cities").EnumerateArray().First(c => c.GetProperty("nameAr").GetString() == "الرياض");
        var otherCity = riyadhRegion.GetProperty("cities").EnumerateArray().First(c => c.GetProperty("nameAr").GetString() != "الرياض");
        return (riyadhRegion.GetProperty("id").GetGuid(), city.GetProperty("id").GetGuid(),
            city.GetProperty("districts")[0].GetProperty("id").GetGuid(), otherCity.GetProperty("districts")[0].GetProperty("id").GetGuid());
    }

    // ---------------- addresses ----------------

    [Fact]
    public async Task Addresses_first_is_default_mismatched_location_rejected_and_delete_promotes_next()
    {
        var (region, city, district, otherDistrict) = await LocationsAsync();
        var client = factory.CreateClient();
        await client.SignInAsync(MigaApiFactory.NewPhone(), Customer);

        var home = await (await client.PostAsJsonAsync("/api/customer/addresses", new { addressName = "المنزل", regionId = region, cityId = city, districtId = district, phoneNumber = "0551234567" }).EnsureOk())
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(home.GetProperty("isDefault").GetBoolean());
        Assert.Equal("+966551234567", home.GetProperty("phoneNumber").GetString());
        Assert.Contains("الرياض", home.GetProperty("summary").GetString());

        // District from another city → rejected.
        var bad = await client.PostAsJsonAsync("/api/customer/addresses", new { addressName = "خطأ", regionId = region, cityId = city, districtId = otherDistrict, phoneNumber = "0551234567" });
        Assert.Equal(HttpStatusCode.BadRequest, bad.StatusCode);
        Assert.Equal("invalid_location", await CodeOf(bad));

        var work = await (await client.PostAsJsonAsync("/api/customer/addresses", new { addressName = "العمل", regionId = region, cityId = city, districtId = district, phoneNumber = "0559876543" }))
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.False(work.GetProperty("isDefault").GetBoolean());

        await client.DeleteAsync($"/api/customer/addresses/{home.GetProperty("id").GetGuid()}").EnsureOk();
        var list = await client.GetFromJsonAsync<JsonElement>("/api/customer/addresses");
        Assert.Equal(1, list.GetArrayLength());
        Assert.True(list[0].GetProperty("isDefault").GetBoolean());
    }

    [Fact]
    public async Task Customers_cannot_see_each_others_addresses()
    {
        var (region, city, district, _) = await LocationsAsync();
        var owner = factory.CreateClient();
        await owner.SignInAsync(MigaApiFactory.NewPhone(), Customer);
        var id = (await (await owner.PostAsJsonAsync("/api/customer/addresses", new { addressName = "المنزل", regionId = region, cityId = city, districtId = district, phoneNumber = "0551234567" }))
            .Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();

        var other = factory.CreateClient();
        await other.SignInAsync(MigaApiFactory.NewPhone(), Customer);
        Assert.Equal(HttpStatusCode.NotFound, (await other.GetAsync($"/api/customer/addresses/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await other.DeleteAsync($"/api/customer/addresses/{id}")).StatusCode);
    }

    // ---------------- public catalog ----------------

    [Fact]
    public async Task Home_returns_live_campaigns_only_with_discount_and_progress()
    {
        var home = await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/home");
        Assert.Equal(6, home.GetProperty("categories").GetArrayLength());

        // Other test classes add campaigns to the shared database, so assert on the seeded ones by name.
        var latest = home.GetProperty("latest").EnumerateArray().ToList();
        var titles = latest.Select(c => c.GetProperty("titleAr").GetString()).ToList();
        Assert.Contains("حملة الهاتف الذكي برو", titles);
        Assert.DoesNotContain("تمر سكري فاخر", titles);          // completed → not live
        Assert.DoesNotContain("مجموعة العناية بالبشرة", titles); // failed → not live

        var phone = latest.Single(c => c.GetProperty("titleAr").GetString() == "حملة الهاتف الذكي برو");
        Assert.Equal(23, phone.GetProperty("discountPercent").GetInt32());
        Assert.Equal(73, phone.GetProperty("currentQuantity").GetInt32());
        Assert.Equal("p_phone.jpg", phone.GetProperty("imageUrl").GetString());

        // Ending soon = within 48h, soonest first (rice 9h, headphones 27h).
        var ending = home.GetProperty("endingSoon").EnumerateArray().Select(c => c.GetProperty("titleAr").GetString()).ToList();
        Assert.True(ending.IndexOf("أرز بسمتي بسعر الجملة") < ending.IndexOf("سماعات بعزل الضوضاء"));
        Assert.True(ending.IndexOf("أرز بسمتي بسعر الجملة") >= 0);
    }

    [Theory]
    [InlineData("biggestDiscount", "عطر عود ملكي")]      // 56%
    [InlineData("almostComplete", "أرز بسمتي بسعر الجملة")] // 92%
    public async Task Campaign_sorting(string sort, string expectedFirst)
    {
        var page = await factory.CreateClient().GetFromJsonAsync<JsonElement>($"/api/campaigns?sort={sort}");
        Assert.Equal(expectedFirst, page.GetProperty("items")[0].GetProperty("titleAr").GetString());
    }

    [Fact]
    public async Task Search_finds_campaigns_products_and_stores()
    {
        var r = await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/search?q=" + Uri.EscapeDataString("أرز"));
        Assert.True(r.GetProperty("campaigns").GetArrayLength() >= 1);
        Assert.True(r.GetProperty("products").GetArrayLength() >= 1);

        var stores = await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/search?q=" + Uri.EscapeDataString("الخير"));
        Assert.Equal(1, stores.GetProperty("stores").GetArrayLength());
    }

    [Fact]
    public async Task Product_detail_promotes_its_live_campaign_and_store_lists_tree()
    {
        var client = factory.CreateClient();
        var stores = await client.GetFromJsonAsync<JsonElement>("/api/stores");
        var grocery = stores.GetProperty("items").EnumerateArray().First(s => s.GetProperty("nameAr").GetString() == "أسواق الخير");
        var storeId = grocery.GetProperty("id").GetGuid();

        var tree = await client.GetFromJsonAsync<JsonElement>($"/api/stores/{storeId}/categories");
        var names = tree.EnumerateArray().Select(c => c.GetProperty("nameAr").GetString()).ToList();
        Assert.Contains("أرز وحبوب", names);
        Assert.Contains("قهوة وزيوت", names);
        Assert.Contains("أدوات مطبخ", names);

        var products = await client.GetFromJsonAsync<JsonElement>($"/api/stores/{storeId}/products");
        var rice = products.GetProperty("items").EnumerateArray().First(p => p.GetProperty("nameAr").GetString()!.StartsWith("أرز"));
        var detail = await client.GetFromJsonAsync<JsonElement>($"/api/products/{rice.GetProperty("id").GetGuid()}");
        // The cheapest live campaign for the product is promoted (55 seeded, or a cheaper test campaign).
        Assert.True(detail.GetProperty("activeCampaign").GetProperty("campaignPrice").GetDecimal() <= 55);
    }

    // ---------------- merchant management ----------------

    [Fact]
    public async Task Merchant_manages_categories_and_products_in_own_store()
    {
        var merchant = factory.CreateClient();
        await merchant.SignInAsync(DemoSeeder.MerchantPhone, Merchant);
        var stores = await merchant.GetFromJsonAsync<JsonElement>("/api/merchant/stores");
        Assert.Equal(4, stores.GetArrayLength());
        var storeId = stores.EnumerateArray().First(s => s.GetProperty("nameAr").GetString() == "أسواق الخير").GetProperty("id").GetGuid();

        // Parent + child category; grandchildren are not allowed.
        var parent = await (await merchant.PostAsJsonAsync($"/api/merchant/stores/{storeId}/categories", new { nameAr = "معلبات" }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        var child = await (await merchant.PostAsJsonAsync($"/api/merchant/stores/{storeId}/categories", new { nameAr = "تونة", parentCategoryId = parent.GetProperty("id").GetGuid() }))
            .Content.ReadFromJsonAsync<JsonElement>();
        var grandchild = await merchant.PostAsJsonAsync($"/api/merchant/stores/{storeId}/categories", new { nameAr = "تونة خفيفة", parentCategoryId = child.GetProperty("id").GetGuid() });
        Assert.Equal("invalid_parent", await CodeOf(grandchild));

        // Product in the child category with ordered images.
        var created = await merchant.PostAsJsonAsync($"/api/merchant/stores/{storeId}/products", new
        {
            productCategoryId = child.GetProperty("id").GetGuid(), nameAr = "تونة 12 علبة", price = 59.5m, stockQuantity = 400, isActive = true,
            imageUrls = new[] { "a.jpg", "b.jpg" },
        });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var product = await created.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("a.jpg", product.GetProperty("images")[0].GetString());

        // Category with products can't be deleted; after deleting the product it can (parent + child together).
        var blocked = await merchant.DeleteAsync($"/api/merchant/stores/{storeId}/categories/{parent.GetProperty("id").GetGuid()}");
        Assert.Equal(HttpStatusCode.Conflict, blocked.StatusCode);
        (await merchant.DeleteAsync($"/api/merchant/stores/{storeId}/products/{product.GetProperty("id").GetGuid()}")).EnsureSuccessStatusCode();
        await merchant.DeleteAsync($"/api/merchant/stores/{storeId}/categories/{parent.GetProperty("id").GetGuid()}").EnsureOk();
    }

    [Fact]
    public async Task Product_in_live_campaign_cannot_be_hidden_or_deleted()
    {
        var merchant = factory.CreateClient();
        await merchant.SignInAsync(DemoSeeder.MerchantPhone, Merchant);
        var stores = await merchant.GetFromJsonAsync<JsonElement>("/api/merchant/stores");
        var storeId = stores.EnumerateArray().First(s => s.GetProperty("nameAr").GetString() == "تقنية الجملة").GetProperty("id").GetGuid();
        var products = await merchant.GetFromJsonAsync<JsonElement>($"/api/merchant/stores/{storeId}/products?q=" + Uri.EscapeDataString("هاتف"));
        var phoneId = products.GetProperty("items")[0].GetProperty("id").GetGuid();
        Assert.True(products.GetProperty("items")[0].GetProperty("inActiveCampaign").GetBoolean());

        Assert.Equal(HttpStatusCode.Conflict, (await merchant.DeleteAsync($"/api/merchant/stores/{storeId}/products/{phoneId}")).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await merchant.PatchAsJsonAsync($"/api/merchant/stores/{storeId}/products/{phoneId}/active", new { active = false })).StatusCode);
    }

    [Fact]
    public async Task Merchant_cannot_touch_another_merchants_store_and_new_merchant_store_is_hidden()
    {
        var stranger = factory.CreateClient();
        await stranger.SignInAsync(MigaApiFactory.NewPhone(), Merchant);
        var demoStore = (await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/stores")).GetProperty("items")[0].GetProperty("id").GetGuid();

        Assert.Equal(HttpStatusCode.NotFound, (await stranger.GetAsync($"/api/merchant/stores/{demoStore}/products")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.PostAsJsonAsync($"/api/merchant/stores/{demoStore}/categories", new { nameAr = "اختراق" })).StatusCode);

        // A not-yet-verified merchant: store exists but is not public and can't be activated.
        var categoryId = (await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/store-categories"))[0].GetProperty("id").GetGuid();
        await stranger.PostAsJsonAsync("/api/merchant/register", new
        {
            ownerName = "تاجر جديد", businessNameAr = "مؤسسة جديدة", commercialRegistrationNumber = "1010000001", storeNameAr = "متجر جديد", storeCategoryId = categoryId,
        });
        var myStore = (await stranger.GetFromJsonAsync<JsonElement>("/api/merchant/stores"))[0].GetProperty("id").GetGuid();
        Assert.Equal(HttpStatusCode.NotFound, (await factory.CreateClient().GetAsync($"/api/stores/{myStore}")).StatusCode);
        var activate = await stranger.PatchAsJsonAsync($"/api/merchant/stores/{myStore}/active", new { active = true });
        Assert.Equal("store_not_verified", await CodeOf(activate));
    }

    // ---------------- uploads ----------------

    [Fact]
    public async Task Upload_accepts_real_images_only()
    {
        var client = factory.CreateClient();
        await client.SignInAsync(DemoSeeder.MerchantPhone, Merchant);

        byte[] png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0];
        using var ok = new MultipartFormDataContent { { new ByteArrayContent(png) { Headers = { ContentType = new MediaTypeHeaderValue("image/png") } }, "file", "logo.png" } };
        // Upload under an Arabic culture: the month folder must still be Gregorian (ar-SA formats years as Hijri).
        var culture = System.Globalization.CultureInfo.CurrentCulture;
        System.Globalization.CultureInfo.CurrentCulture = new System.Globalization.CultureInfo("ar-SA");
        HttpResponseMessage r;
        try { r = await client.PostAsync("/api/uploads/stores", ok); }
        finally { System.Globalization.CultureInfo.CurrentCulture = culture; }
        r.EnsureSuccessStatusCode();
        var url = (await r.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("url").GetString()!;
        Assert.StartsWith($"/uploads/stores/{DateTime.UtcNow.ToString("yyyy-MM", System.Globalization.CultureInfo.InvariantCulture)}/", url);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync(url)).StatusCode);

        // A text file renamed to .png is rejected.
        using var fake = new MultipartFormDataContent { { new ByteArrayContent("hello"u8.ToArray()), "file", "evil.png" } };
        Assert.Equal("unsupported_file", await CodeOf(await client.PostAsync("/api/uploads/stores", fake)));

        using var again = new MultipartFormDataContent { { new ByteArrayContent(png), "file", "x.png" } };
        Assert.Equal("invalid_folder", await CodeOf(await client.PostAsync("/api/uploads/..%2F..%2Fetc", again)));
    }

    [Fact]
    public async Task Editing_a_store_without_city_keeps_its_city_and_pickup_address()
    {
        var merchant = factory.CreateClient();
        await merchant.SignInAsync(Miga.Infrastructure.Persistence.DemoSeeder.MerchantPhone, Merchant);
        var categoryId = (await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/store-categories"))[0].GetProperty("id").GetGuid();
        var cityId = await factory.CityAsync("جدة");
        var store = await (await merchant.PostAsJsonAsync("/api/merchant/stores", new
        {
            nameAr = "متجر المدينة", storeCategoryId = categoryId, pickupAddress = "مستودع 3", cityId,
        }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        var id = store.GetProperty("id").GetGuid();

        // An older client sends only the basic fields.
        var edited = await (await merchant.PutAsJsonAsync($"/api/merchant/stores/{id}", new { nameAr = "متجر المدينة 2", storeCategoryId = categoryId })
            .EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("متجر المدينة 2", edited.GetProperty("nameAr").GetString());
        Assert.Equal(cityId, edited.GetProperty("cityId").GetGuid());
        Assert.Equal("مستودع 3", edited.GetProperty("pickupAddress").GetString());
    }
}
