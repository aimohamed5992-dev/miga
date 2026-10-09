using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Miga.Domain;
using Miga.Domain.Entities;
using Miga.Infrastructure.Features.Orders;
using Miga.Infrastructure.Persistence;

namespace Miga.Api.Tests;

/// <summary>Cart → checkout → campaign completion / expiry / cancellation, against the real database.</summary>
[Collection(ApiCollection.Name)]
public class OrderFlowTests(MigaApiFactory factory)
{
    private const int Customer = 1;

    private async Task<T> WithDb<T>(Func<MigaDbContext, Task<T>> work)
    {
        using var scope = factory.Services.CreateScope();
        return await work(scope.ServiceProvider.GetRequiredService<MigaDbContext>());
    }

    /// <summary>Fresh campaign on the demo rice product so every test controls its own numbers.</summary>
    private Task<(Guid CampaignId, Guid ProductId)> NewCampaignAsync(int target, int current = 0, int? maxPer = null, TimeSpan? endsIn = null) => WithDb(async db =>
    {
        var product = await db.Products.Include(p => p.Store).ThenInclude(s => s.Merchant).FirstAsync(p => p.NameAr.StartsWith("أرز بسمتي") && p.Store.Merchant.User.PhoneNumber == DemoSeeder.MerchantPhone);
        var c = new Campaign
        {
            StoreId = product.StoreId, ProductId = product.Id, MerchantUserId = product.Store.Merchant.UserId,
            TitleAr = $"حملة اختبار {Guid.NewGuid():N}"[..20], OriginalPrice = product.Price, CampaignPrice = 50,
            TargetQuantity = target, CurrentQuantity = current, MaxQuantityPerCustomer = maxPer,
            StartDate = DateTime.UtcNow.AddHours(-1), EndDate = DateTime.UtcNow + (endsIn ?? TimeSpan.FromDays(2)), Status = CampaignStatus.Active,
        };
        db.Campaigns.Add(c);
        await db.SaveChangesAsync();
        return (c.Id, product.Id);
    });

    /// <summary>Signed-in customer with one saved address.</summary>
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

    private static async Task<JsonElement> BuyAsync(HttpClient client, Guid addressId, Guid productId, Guid campaignId, int qty, string method = "mada")
    {
        await client.PostAsJsonAsync("/api/customer/cart/items", new { productId, campaignId, quantity = qty }).EnsureOk();
        return await (await client.PostAsJsonAsync("/api/customer/checkout", new { addressId, paymentMethod = method }).EnsureOk())
            .Content.ReadFromJsonAsync<JsonElement>();
    }

    private static JsonElement Item(JsonElement checkout) => checkout.GetProperty("items")[0];

    [Fact]
    public async Task Cart_merges_lines_enforces_limits_and_groups_by_store()
    {
        var (campaignId, productId) = await NewCampaignAsync(target: 50, maxPer: 3);
        var (client, _) = await CustomerAsync();

        await client.PostAsJsonAsync("/api/customer/cart/items", new { productId, campaignId, quantity = 2 }).EnsureOk();
        var over = await client.PostAsJsonAsync("/api/customer/cart/items", new { productId, campaignId, quantity = 2 }); // 4 > 3
        Assert.Equal(HttpStatusCode.BadRequest, over.StatusCode);

        var cart = await (await client.PostAsJsonAsync("/api/customer/cart/items", new { productId, campaignId, quantity = 1 }).EnsureOk())
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(1, cart.GetProperty("stores").GetArrayLength());
        var line = cart.GetProperty("stores")[0].GetProperty("items")[0];
        Assert.Equal(3, line.GetProperty("quantity").GetInt32());
        Assert.Equal(150, cart.GetProperty("total").GetDecimal());
        Assert.Equal((89 - 50) * 3, cart.GetProperty("savings").GetDecimal());
    }

    [Fact]
    public async Task Checkout_pays_records_order_and_increments_campaign()
    {
        var (campaignId, productId) = await NewCampaignAsync(target: 50);
        var (client, addressId) = await CustomerAsync();

        var result = await BuyAsync(client, addressId, productId, campaignId, 4);
        Assert.True(Item(result).GetProperty("success").GetBoolean());
        Assert.Equal(200, result.GetProperty("totalCharged").GetDecimal());

        var orderId = Item(result).GetProperty("orderId").GetGuid();
        var order = await client.GetFromJsonAsync<JsonElement>($"/api/customer/orders/{orderId}");
        Assert.Equal((int)CampaignOrderStatus.Paid, order.GetProperty("order").GetProperty("status").GetInt32());
        Assert.Equal(4, order.GetProperty("order").GetProperty("campaignCurrentQuantity").GetInt32());
        Assert.True(order.GetProperty("canCancel").GetBoolean());
        Assert.Equal((int)PaymentStatus.Paid, order.GetProperty("payment").GetProperty("status").GetInt32());

        var cart = await client.GetFromJsonAsync<JsonElement>("/api/customer/cart");
        Assert.Equal(0, cart.GetProperty("itemsCount").GetInt32());

        var notifications = await client.GetFromJsonAsync<JsonElement>("/api/notifications");
        Assert.Contains(notifications.EnumerateArray(), n => n.GetProperty("title").GetString() == "تم الانضمام للحملة");

        // One order per customer per campaign.
        var again = await client.PostAsJsonAsync("/api/customer/cart/items", new { productId, campaignId, quantity = 1 });
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
    }

    [Fact]
    public async Task Failed_payment_takes_nothing_and_keeps_the_cart()
    {
        var (campaignId, productId) = await NewCampaignAsync(target: 50);
        var (client, addressId) = await CustomerAsync();

        var result = await BuyAsync(client, addressId, productId, campaignId, 2, method: "test_fail");
        Assert.False(Item(result).GetProperty("success").GetBoolean());
        Assert.Equal("payment_failed", Item(result).GetProperty("code").GetString());
        Assert.Equal(0, result.GetProperty("totalCharged").GetDecimal());

        Assert.Equal(2, (await client.GetFromJsonAsync<JsonElement>("/api/customer/cart")).GetProperty("itemsCount").GetInt32());
        Assert.Equal(0, await WithDb(db => db.Campaigns.Where(c => c.Id == campaignId).Select(c => c.CurrentQuantity).FirstAsync()));
        Assert.Equal(0, (await client.GetFromJsonAsync<JsonElement>("/api/customer/orders")).GetProperty("totalCount").GetInt32());

        // Retrying with a working method succeeds (the failed attempt doesn't count as "already joined").
        var retry = await (await client.PostAsJsonAsync("/api/customer/checkout", new { addressId, paymentMethod = "mada" }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(Item(retry).GetProperty("success").GetBoolean());
    }

    [Fact]
    public async Task Reaching_the_target_completes_campaign_and_creates_merchant_order_with_deliveries()
    {
        var (campaignId, productId) = await NewCampaignAsync(target: 3);
        var stockBefore = await WithDb(db => db.Products.Where(p => p.Id == productId).Select(p => p.StockQuantity).FirstAsync());

        var (a, addrA) = await CustomerAsync();
        var first = await BuyAsync(a, addrA, productId, campaignId, 1);
        Assert.False(Item(first).GetProperty("campaignCompleted").GetBoolean());

        var (b, addrB) = await CustomerAsync();
        var second = await BuyAsync(b, addrB, productId, campaignId, 2);
        Assert.True(Item(second).GetProperty("campaignCompleted").GetBoolean());

        await WithDb(async db =>
        {
            var campaign = await db.Campaigns.FirstAsync(c => c.Id == campaignId);
            Assert.Equal(CampaignStatus.Completed, campaign.Status);

            var mo = await db.MerchantOrders.Include(m => m.Deliveries).FirstAsync(m => m.CampaignId == campaignId);
            Assert.Equal(3, mo.TotalQuantity);
            Assert.Equal(2, mo.CustomersCount);
            Assert.Equal(150, mo.TotalAmount);
            Assert.Equal(7.5m, mo.PlatformFee);
            Assert.Equal(MerchantOrderStatus.SentToMerchant, mo.Status);
            Assert.Equal(2, mo.Deliveries.Count);
            Assert.All(mo.Deliveries, d => Assert.Matches(@"^\d{4}$", d.DeliveryCode));

            Assert.All(await db.CampaignOrders.Where(o => o.CampaignId == campaignId).ToListAsync(), o => Assert.Equal(CampaignOrderStatus.Confirmed, o.Status));
            Assert.Equal(stockBefore - 3, await db.Products.Where(p => p.Id == productId).Select(p => p.StockQuantity).FirstAsync());
            return 0;
        });

        var notes = await a.GetFromJsonAsync<JsonElement>("/api/notifications");
        Assert.Contains(notes.EnumerateArray(), n => n.GetProperty("title").GetString() == "اكتملت الحملة 🎉");
        Assert.False((await a.GetFromJsonAsync<JsonElement>($"/api/customer/orders/{Item(first).GetProperty("orderId").GetGuid()}")).GetProperty("canCancel").GetBoolean());
    }

    [Fact]
    public async Task Concurrent_buyers_can_never_oversell_the_last_pieces()
    {
        var (campaignId, productId) = await NewCampaignAsync(target: 3);
        var buyers = new List<(HttpClient Client, Guid Address)>();
        for (var i = 0; i < 6; i++)
        {
            var c = await CustomerAsync();
            await c.Client.PostAsJsonAsync("/api/customer/cart/items", new { productId, campaignId, quantity = 1 }).EnsureOk();
            buyers.Add(c);
        }

        // 6 customers hit checkout at the same moment for 3 remaining pieces.
        var results = await Task.WhenAll(buyers.Select(async b =>
            await (await b.Client.PostAsJsonAsync("/api/customer/checkout", new { addressId = b.Address, paymentMethod = "mada" }).EnsureOk())
                .Content.ReadFromJsonAsync<JsonElement>()));

        Assert.Equal(3, results.Count(r => Item(r).GetProperty("success").GetBoolean()));
        Assert.All(results.Where(r => !Item(r).GetProperty("success").GetBoolean()),
            r => Assert.Contains(Item(r).GetProperty("code").GetString(), new[] { "not_enough_quantity", "campaign_not_active" }));

        await WithDb(async db =>
        {
            var campaign = await db.Campaigns.FirstAsync(c => c.Id == campaignId);
            Assert.Equal(3, campaign.CurrentQuantity);
            Assert.Equal(CampaignStatus.Completed, campaign.Status);
            Assert.Equal(3, await db.CampaignOrders.CountAsync(o => o.CampaignId == campaignId && o.Status == CampaignOrderStatus.Confirmed));
            Assert.Equal(1, await db.MerchantOrders.CountAsync(m => m.CampaignId == campaignId));
            return 0;
        });
    }

    [Fact]
    public async Task Customer_can_cancel_before_completion_with_full_refund()
    {
        var (campaignId, productId) = await NewCampaignAsync(target: 50);
        var (client, addressId) = await CustomerAsync();
        var orderId = Item(await BuyAsync(client, addressId, productId, campaignId, 3)).GetProperty("orderId").GetGuid();

        var cancelled = await (await client.PostAsJsonAsync($"/api/customer/orders/{orderId}/cancel", new { reason = "غيّرت رأيي" }).EnsureOk())
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal((int)CampaignOrderStatus.Cancelled, cancelled.GetProperty("order").GetProperty("status").GetInt32());
        Assert.Equal((int)PaymentStatus.Refunded, cancelled.GetProperty("payment").GetProperty("status").GetInt32());
        Assert.Equal(0, cancelled.GetProperty("order").GetProperty("campaignCurrentQuantity").GetInt32());

        var twice = await client.PostAsJsonAsync($"/api/customer/orders/{orderId}/cancel", new { reason = "مرة أخرى" });
        Assert.Equal(HttpStatusCode.Conflict, twice.StatusCode);

        var past = await client.GetFromJsonAsync<JsonElement>("/api/customer/orders?scope=past");
        Assert.Equal(1, past.GetProperty("totalCount").GetInt32());
    }

    [Fact]
    public async Task Expired_campaign_fails_and_refunds_everyone()
    {
        var (campaignId, productId) = await NewCampaignAsync(target: 50);
        var (client, addressId) = await CustomerAsync();
        var orderId = Item(await BuyAsync(client, addressId, productId, campaignId, 2)).GetProperty("orderId").GetGuid();

        await WithDb(db => db.Campaigns.Where(c => c.Id == campaignId).ExecuteUpdateAsync(s => s.SetProperty(c => c.EndDate, DateTime.UtcNow.AddMinutes(-1))));
        using (var scope = factory.Services.CreateScope())
        {
            Assert.True(await scope.ServiceProvider.GetRequiredService<CampaignLifecycleService>().ExpireDueAsync(default) >= 1);
        }

        var order = await client.GetFromJsonAsync<JsonElement>($"/api/customer/orders/{orderId}");
        Assert.Equal((int)CampaignStatus.Failed, order.GetProperty("order").GetProperty("campaignStatus").GetInt32());
        Assert.Equal((int)CampaignOrderStatus.Refunded, order.GetProperty("order").GetProperty("status").GetInt32());
        Assert.Equal((int)PaymentStatus.Refunded, order.GetProperty("payment").GetProperty("status").GetInt32());

        var notes = await client.GetFromJsonAsync<JsonElement>("/api/notifications");
        Assert.Contains(notes.EnumerateArray(), n => n.GetProperty("title").GetString() == "لم تكتمل الحملة");
    }

    [Fact]
    public async Task Regular_product_lines_are_reported_not_charged()
    {
        var (_, productId) = await NewCampaignAsync(target: 50);
        var (client, addressId) = await CustomerAsync();
        await client.PostAsJsonAsync("/api/customer/cart/items", new { productId, quantity = 1 }).EnsureOk();

        var result = await (await client.PostAsJsonAsync("/api/customer/checkout", new { addressId, paymentMethod = "mada" }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("product_orders_unsupported", Item(result).GetProperty("code").GetString());
        Assert.Equal(0, result.GetProperty("totalCharged").GetDecimal());
    }
}
