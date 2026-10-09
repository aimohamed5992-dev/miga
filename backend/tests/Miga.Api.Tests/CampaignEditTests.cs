using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Miga.Domain;
using Miga.Infrastructure.Persistence;

namespace Miga.Api.Tests;

/// <summary>Merchant edits drafts freely; running campaigns protect customers who already paid.</summary>
[Collection(ApiCollection.Name)]
public class CampaignEditTests(MigaApiFactory factory)
{
    private const int Merchant = 2;

    private static async Task<string> CodeOf(HttpResponseMessage r) =>
        JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement.GetProperty("code").GetString()!;

    private async Task<(HttpClient Merchant, Guid CampaignId, Guid ProductId)> CampaignAsync(bool publish, int target = 10, int? maxPer = 5)
    {
        var merchant = factory.CreateClient();
        await merchant.SignInAsync(DemoSeeder.MerchantPhone, Merchant);
        var storeId = (await merchant.GetFromJsonAsync<JsonElement>("/api/merchant/stores")).EnumerateArray()
            .First(s => s.GetProperty("nameAr").GetString() == "أسواق الخير").GetProperty("id").GetGuid();
        var categoryId = (await merchant.GetFromJsonAsync<JsonElement>($"/api/merchant/stores/{storeId}/categories"))[0].GetProperty("id").GetGuid();
        var productId = (await (await merchant.PostAsJsonAsync($"/api/merchant/stores/{storeId}/products", new
        {
            productCategoryId = categoryId, nameAr = $"منتج تعديل {Guid.NewGuid():N}"[..18], price = 100m, stockQuantity = 200, isActive = true, imageUrls = new[] { "p_oil.jpg" },
        }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
        var campaignId = (await (await merchant.PostAsJsonAsync("/api/merchant/campaigns", new
        {
            storeId, productId, titleAr = "حملة للتعديل", campaignPrice = 70m, targetQuantity = target, maxQuantityPerCustomer = maxPer, durationDays = 5, publish,
        }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
        return (merchant, campaignId, productId);
    }

    private async Task<HttpClient> BuyAsync(Guid productId, Guid campaignId, int qty)
    {
        var (customer, addressId) = await factory.CustomerAsync();
        await customer.PostAsJsonAsync("/api/customer/cart/items", new { productId, campaignId, quantity = qty }).EnsureOk();
        await customer.PostAsJsonAsync("/api/customer/checkout", new { addressId, paymentMethod = "mada" }).EnsureOk();
        return customer;
    }

    [Fact]
    public async Task Draft_is_fully_editable()
    {
        var (merchant, id, _) = await CampaignAsync(publish: false);
        var ends = DateTime.UtcNow.AddDays(10);
        var c = await (await merchant.PatchAsJsonAsync($"/api/merchant/campaigns/{id}", new
        {
            titleAr = "مسودة معدّلة", descriptionAr = "وصف جديد", campaignPrice = 60m, originalPrice = 110m, targetQuantity = 20, maxQuantityPerCustomer = 0, endsAt = ends,
        }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("مسودة معدّلة", c.GetProperty("titleAr").GetString());
        Assert.Equal(60m, c.GetProperty("campaignPrice").GetDecimal());
        Assert.Equal(20, c.GetProperty("targetQuantity").GetInt32());
        Assert.Equal(JsonValueKind.Null, c.GetProperty("maxQuantityPerCustomer").ValueKind);
    }

    [Fact]
    public async Task Running_campaign_locks_price_once_customers_joined_and_notifies_on_changes()
    {
        var (merchant, id, productId) = await CampaignAsync(publish: true);

        // No one joined yet: the price can still change.
        await merchant.PatchAsJsonAsync($"/api/merchant/campaigns/{id}", new { campaignPrice = 65m }).EnsureOk();
        var customer = await BuyAsync(productId, id, 3);
        Assert.Equal("price_locked", await CodeOf(await merchant.PatchAsJsonAsync($"/api/merchant/campaigns/{id}", new { campaignPrice = 50m })));

        Assert.Equal("target_below_sold", await CodeOf(await merchant.PatchAsJsonAsync($"/api/merchant/campaigns/{id}", new { targetQuantity = 2 })));
        Assert.Equal("max_below_existing", await CodeOf(await merchant.PatchAsJsonAsync($"/api/merchant/campaigns/{id}", new { maxQuantityPerCustomer = 2 })));
        Assert.Equal("invalid_end", await CodeOf(await merchant.PatchAsJsonAsync($"/api/merchant/campaigns/{id}", new { endsAt = DateTime.UtcNow.AddMinutes(20) })));
        Assert.Equal("target_exceeds_stock", await CodeOf(await merchant.PatchAsJsonAsync($"/api/merchant/campaigns/{id}", new { targetQuantity = 5000 })));

        var ends = DateTime.UtcNow.AddDays(3);
        var c = await (await merchant.PatchAsJsonAsync($"/api/merchant/campaigns/{id}", new { titleAr = "حملة معدّلة", targetQuantity = 15, endsAt = ends })
            .EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(15, c.GetProperty("targetQuantity").GetInt32());
        Assert.Equal((int)CampaignStatus.Active, c.GetProperty("status").GetInt32());

        var notes = await customer.GetFromJsonAsync<JsonElement>("/api/notifications");
        Assert.Contains(notes.EnumerateArray(), n => n.GetProperty("body").GetString()!.Contains("الكمية المطلوبة أصبحت 15"));
    }

    [Fact]
    public async Task Lowering_the_target_to_what_is_sold_completes_the_campaign()
    {
        var (merchant, id, productId) = await CampaignAsync(publish: true, target: 10);
        await BuyAsync(productId, id, 2);
        await BuyAsync(productId, id, 2);

        var c = await (await merchant.PatchAsJsonAsync($"/api/merchant/campaigns/{id}", new { targetQuantity = 4 }).EnsureOk())
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal((int)CampaignStatus.Completed, c.GetProperty("status").GetInt32());
        var orders = await merchant.GetFromJsonAsync<JsonElement>("/api/merchant/orders?tab=new");
        Assert.Contains(orders.GetProperty("items").EnumerateArray(), o => o.GetProperty("campaignId").GetGuid() == id && o.GetProperty("totalQuantity").GetInt32() == 4);

        Assert.Equal("campaign_not_editable", await CodeOf(await merchant.PatchAsJsonAsync($"/api/merchant/campaigns/{id}", new { titleAr = "بعد الاكتمال" })));
    }

    [Fact]
    public async Task Other_merchants_cannot_edit_the_campaign()
    {
        var (_, id, _) = await CampaignAsync(publish: true);
        var other = factory.CreateClient();
        await other.SignInAsync(MigaApiFactory.NewPhone(), Merchant);
        var r = await other.PatchAsJsonAsync($"/api/merchant/campaigns/{id}", new { titleAr = "سرقة" });
        Assert.True(r.StatusCode is HttpStatusCode.NotFound or HttpStatusCode.Forbidden);
    }
}
