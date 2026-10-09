using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Miga.Domain;
using Miga.Domain.Entities;
using Miga.Infrastructure.Persistence;

namespace Miga.Api.Tests;

/// <summary>Merchant campaigns (wizard, publish, extend, cancel), aggregated order flow, dashboard and wallet.</summary>
[Collection(ApiCollection.Name)]
public class MerchantSalesTests(MigaApiFactory factory)
{
    private const int Customer = 1, Merchant = 2, Driver = 3;

    private static async Task<string> CodeOf(HttpResponseMessage r) =>
        JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement.GetProperty("code").GetString()!;

    private async Task<T> WithDb<T>(Func<MigaDbContext, Task<T>> work)
    {
        using var scope = factory.Services.CreateScope();
        return await work(scope.ServiceProvider.GetRequiredService<MigaDbContext>());
    }

    /// <summary>Demo merchant signed in + a brand-new product (stock 500, price 100) in the grocery store.</summary>
    private async Task<(HttpClient Merchant, Guid StoreId, Guid ProductId)> MerchantWithProductAsync()
    {
        var merchant = factory.CreateClient();
        await merchant.SignInAsync(DemoSeeder.MerchantPhone, Merchant);
        var stores = await merchant.GetFromJsonAsync<JsonElement>("/api/merchant/stores");
        var storeId = stores.EnumerateArray().First(s => s.GetProperty("nameAr").GetString() == "أسواق الخير").GetProperty("id").GetGuid();
        var categoryId = (await merchant.GetFromJsonAsync<JsonElement>($"/api/merchant/stores/{storeId}/categories"))[0].GetProperty("id").GetGuid();
        var product = await (await merchant.PostAsJsonAsync($"/api/merchant/stores/{storeId}/products", new
        {
            productCategoryId = categoryId, nameAr = $"منتج اختبار {Guid.NewGuid():N}"[..18], price = 100m, stockQuantity = 500, isActive = true, imageUrls = new[] { "p_rice.jpg" },
        }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        return (merchant, storeId, product.GetProperty("id").GetGuid());
    }

    private static object CampaignBody(Guid storeId, Guid productId, int target = 10, decimal price = 60, bool publish = true, int days = 7) =>
        new { storeId, productId, titleAr = "حملة تاجر للاختبار", campaignPrice = price, targetQuantity = target, maxQuantityPerCustomer = Math.Min(5, target), durationDays = days, publish };

    private async Task<(HttpClient Client, Guid AddressId)> CustomerAsync()
    {
        var client = factory.CreateClient();
        await client.SignInAsync(MigaApiFactory.NewPhone(), Customer);
        var regions = await client.GetFromJsonAsync<JsonElement>("/api/regions");
        var city = regions[0].GetProperty("cities").EnumerateArray().First(c => c.GetProperty("nameAr").GetString() == "الرياض");
        var address = await (await client.PostAsJsonAsync("/api/customer/addresses", new
        {
            addressName = "المنزل", regionId = regions[0].GetProperty("id").GetGuid(), cityId = city.GetProperty("id").GetGuid(),
            districtId = city.GetProperty("districts")[0].GetProperty("id").GetGuid(), phoneNumber = "0551234567",
        }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        return (client, address.GetProperty("id").GetGuid());
    }

    private static async Task<JsonElement> BuyAsync(HttpClient client, Guid addressId, Guid productId, Guid campaignId, int qty)
    {
        await client.PostAsJsonAsync("/api/customer/cart/items", new { productId, campaignId, quantity = qty }).EnsureOk();
        var r = await (await client.PostAsJsonAsync("/api/customer/checkout", new { addressId, paymentMethod = "mada" }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(r.GetProperty("items")[0].GetProperty("success").GetBoolean(), r.ToString());
        return r.GetProperty("items")[0];
    }

    [Fact]
    public async Task Wizard_validates_saves_draft_publishes_and_allows_one_live_campaign_per_product()
    {
        var (merchant, storeId, productId) = await MerchantWithProductAsync();

        var tooExpensive = await merchant.PostAsJsonAsync("/api/merchant/campaigns", CampaignBody(storeId, productId, price: 100));
        Assert.Equal("invalid_campaign_price", await CodeOf(tooExpensive));
        var overStock = await merchant.PostAsJsonAsync("/api/merchant/campaigns", CampaignBody(storeId, productId, target: 600));
        Assert.Equal("target_exceeds_stock", await CodeOf(overStock));

        var draft = await (await merchant.PostAsJsonAsync("/api/merchant/campaigns", CampaignBody(storeId, productId, publish: false)).EnsureOk())
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal((int)CampaignStatus.Draft, draft.GetProperty("status").GetInt32());
        Assert.Equal(40, draft.GetProperty("discountPercent").GetInt32());
        var draftId = draft.GetProperty("id").GetGuid();
        Assert.Equal(HttpStatusCode.NotFound, (await factory.CreateClient().GetAsync($"/api/campaigns/{draftId}")).StatusCode); // drafts are private

        var published = await (await merchant.PostAsync($"/api/merchant/campaigns/{draftId}/publish", null).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal((int)CampaignStatus.Active, published.GetProperty("status").GetInt32());
        Assert.Equal(HttpStatusCode.OK, (await factory.CreateClient().GetAsync($"/api/campaigns/{draftId}")).StatusCode);

        var second = await merchant.PostAsJsonAsync("/api/merchant/campaigns", CampaignBody(storeId, productId));
        Assert.Equal("product_has_active_campaign", await CodeOf(second));
    }

    [Fact]
    public async Task Extending_moves_end_date_and_notifies_participants_cancel_refunds_them()
    {
        var (merchant, storeId, productId) = await MerchantWithProductAsync();
        var campaign = await (await merchant.PostAsJsonAsync("/api/merchant/campaigns", CampaignBody(storeId, productId)).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        var campaignId = campaign.GetProperty("id").GetGuid();
        var (customer, addressId) = await CustomerAsync();
        var orderId = (await BuyAsync(customer, addressId, productId, campaignId, 2)).GetProperty("orderId").GetGuid();

        var extended = await (await merchant.PostAsJsonAsync($"/api/merchant/campaigns/{campaignId}/extend", new { days = 3 }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(campaign.GetProperty("endDate").GetDateTime().AddDays(3), extended.GetProperty("endDate").GetDateTime(), TimeSpan.FromSeconds(1));
        Assert.Contains((await customer.GetFromJsonAsync<JsonElement>("/api/notifications")).EnumerateArray(), n => n.GetProperty("title").GetString() == "تم تمديد الحملة");

        var participants = await merchant.GetFromJsonAsync<JsonElement>($"/api/merchant/campaigns/{campaignId}/participants");
        Assert.Equal(1, participants.GetProperty("totalCount").GetInt32());

        var cancelled = await (await merchant.PostAsJsonAsync($"/api/merchant/campaigns/{campaignId}/cancel", new { reason = "نفاد المخزون" }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal((int)CampaignStatus.Cancelled, cancelled.GetProperty("status").GetInt32());
        var order = await customer.GetFromJsonAsync<JsonElement>($"/api/customer/orders/{orderId}");
        Assert.Equal((int)CampaignOrderStatus.Refunded, order.GetProperty("order").GetProperty("status").GetInt32());
        Assert.Equal((int)PaymentStatus.Refunded, order.GetProperty("payment").GetProperty("status").GetInt32());
    }

    [Fact]
    public async Task Completed_campaign_flows_through_merchant_order_statuses_and_notifies_drivers()
    {
        // A verified, available driver in Riyadh should be offered the deliveries when the order is ready.
        var driver = factory.CreateClient();
        var driverAuth = await driver.SignInAsync(MigaApiFactory.NewPhone(), Driver);
        var regions = await driver.GetFromJsonAsync<JsonElement>("/api/regions");
        var riyadh = regions[0].GetProperty("cities").EnumerateArray().First(c => c.GetProperty("nameAr").GetString() == "الرياض").GetProperty("id").GetGuid();
        await driver.PostAsJsonAsync("/api/driver/register", new { fullName = "كابتن الاختبار", nationalId = "1012345678", cityId = riyadh, vehicleType = "فان", vehiclePlateNumber = "أ ب ج 1234" }).EnsureOk();
        await WithDb(db => db.DriverProfiles.Where(d => d.UserId == driverAuth.Account.Id)
            .ExecuteUpdateAsync(s => s.SetProperty(d => d.IsVerified, true).SetProperty(d => d.IsAvailable, true)));

        var (merchant, storeId, productId) = await MerchantWithProductAsync();
        var campaignId = (await (await merchant.PostAsJsonAsync("/api/merchant/campaigns", CampaignBody(storeId, productId, target: 3)).EnsureOk())
            .Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();

        var (a, addrA) = await CustomerAsync();
        var (b, addrB) = await CustomerAsync();
        await BuyAsync(a, addrA, productId, campaignId, 1);
        var last = await BuyAsync(b, addrB, productId, campaignId, 2);
        Assert.True(last.GetProperty("campaignCompleted").GetBoolean());

        var list = await merchant.GetFromJsonAsync<JsonElement>("/api/merchant/orders?tab=new");
        var mo = list.GetProperty("items").EnumerateArray().First(o => o.GetProperty("campaignId").GetGuid() == campaignId);
        var moId = mo.GetProperty("id").GetGuid();

        var detail = await merchant.GetFromJsonAsync<JsonElement>($"/api/merchant/orders/{moId}");
        Assert.Equal(180, detail.GetProperty("order").GetProperty("totalAmount").GetDecimal());
        Assert.Equal(9, detail.GetProperty("platformFee").GetDecimal());
        Assert.Equal(171, detail.GetProperty("netAmount").GetDecimal());
        Assert.Equal(3, detail.GetProperty("districts")[0].GetProperty("quantity").GetInt32());
        Assert.Equal(2, detail.GetProperty("deliveries").GetArrayLength());

        // Skipping a step is rejected.
        Assert.Equal("invalid_order_transition", await CodeOf(await merchant.PostAsync($"/api/merchant/orders/{moId}/ready", null)));

        await merchant.PostAsync($"/api/merchant/orders/{moId}/confirm", null).EnsureOk();
        await merchant.PostAsync($"/api/merchant/orders/{moId}/start-preparing", null).EnsureOk();
        var customerOrder = await a.GetFromJsonAsync<JsonElement>("/api/customer/orders");
        Assert.Contains(customerOrder.GetProperty("items").EnumerateArray(), o => o.GetProperty("status").GetInt32() == (int)CampaignOrderStatus.Preparing);

        var ready = await (await merchant.PostAsync($"/api/merchant/orders/{moId}/ready", null).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal((int)MerchantOrderStatus.Ready, ready.GetProperty("order").GetProperty("status").GetInt32());
        Assert.Matches(@"^\d{4}$", ready.GetProperty("pickupCode").GetString()!);
        Assert.Contains((await driver.GetFromJsonAsync<JsonElement>("/api/notifications")).EnumerateArray(), n => n.GetProperty("title").GetString() == "طلبات توصيل جديدة");

        // Another merchant can't see it.
        var stranger = factory.CreateClient();
        await stranger.SignInAsync(MigaApiFactory.NewPhone(), Merchant);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.GetAsync($"/api/merchant/orders/{moId}")).StatusCode);
    }

    [Fact]
    public async Task Dashboard_and_wallet_settle_after_delivery_and_payouts_respect_balance()
    {
        var (merchant, storeId, productId) = await MerchantWithProductAsync();
        var campaignId = (await (await merchant.PostAsJsonAsync("/api/merchant/campaigns", CampaignBody(storeId, productId, target: 4)).EnsureOk())
            .Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
        var (c, addr) = await CustomerAsync();
        await BuyAsync(c, addr, productId, campaignId, 4); // max per customer = target (4), completes: 4 × 60 = 240, fee 12, net 228

        var dashboard = await merchant.GetFromJsonAsync<JsonElement>($"/api/merchant/dashboard?storeId={storeId}");
        Assert.Equal(7, dashboard.GetProperty("lastSevenDays").GetArrayLength());
        Assert.True(dashboard.GetProperty("weekTotal").GetDecimal() >= 240);

        Assert.Equal("invalid_iban", await CodeOf(await merchant.PutAsJsonAsync("/api/merchant/bank-account", new { bankName = "الراجحي", iban = "SA123" })));
        (await merchant.PutAsJsonAsync("/api/merchant/bank-account", new { bankName = "مصرف الراجحي", iban = "SA03 8000 0000 6080 1016 7519" })).EnsureSuccessStatusCode();

        var before = await merchant.GetFromJsonAsync<JsonElement>("/api/merchant/earnings");
        Assert.True(before.GetProperty("pendingSettlement").GetDecimal() >= 228);
        Assert.StartsWith("SA•• ••••", before.GetProperty("ibanMasked").GetString());

        // Nothing is withdrawable until the customers receive their orders.
        var tooEarly = await merchant.PostAsJsonAsync("/api/merchant/payouts", new { amount = before.GetProperty("available").GetDecimal() + 228 });
        Assert.Equal("insufficient_balance", await CodeOf(tooEarly));

        await WithDb(db => db.Deliveries.Where(d => d.MerchantOrder.CampaignId == campaignId)
            .ExecuteUpdateAsync(s => s.SetProperty(d => d.Status, DeliveryStatus.Delivered).SetProperty(d => d.DeliveredAt, DateTime.UtcNow)));
        var settled = await merchant.GetFromJsonAsync<JsonElement>("/api/merchant/earnings");
        var available = settled.GetProperty("available").GetDecimal();
        Assert.True(available >= 228);
        Assert.Contains(settled.GetProperty("transactions").EnumerateArray(), t => t.GetProperty("type").GetString() == "fee" && t.GetProperty("amount").GetDecimal() == -12);

        var after = await (await merchant.PostAsJsonAsync("/api/merchant/payouts", new { amount = 200 }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(available - 200, after.GetProperty("available").GetDecimal());
    }
}
