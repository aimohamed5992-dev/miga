using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Miga.Domain;

namespace Miga.Api.Tests;

/// <summary>Admin operations: campaigns, orders, failed-delivery resolution (retry / refund) and merchant withdrawals.</summary>
[Collection(ApiCollection.Name)]
public class AdminOperationsTests(MigaApiFactory factory)
{
    private const int Admin = 4;

    private static async Task<string> CodeOf(HttpResponseMessage r) =>
        JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement.GetProperty("code").GetString()!;

    private async Task<HttpClient> AdminAsync()
    {
        var admin = factory.CreateClient();
        await admin.SignInAsync(MigaApiFactory.AdminPhone, Admin);
        return admin;
    }

    /// <summary>Ready order → one driver picks up both deliveries and starts them. Returns delivery ids keyed by quantity (1 and 2).</summary>
    private async Task<(Scenario S, HttpClient Driver, Dictionary<int, Guid> ByQuantity)> OnTheWayAsync()
    {
        var s = await factory.ReadyOrderAsync();
        var (driver, _) = await factory.DriverAsync();
        var byQuantity = new Dictionary<int, Guid>();
        foreach (var id in s.DeliveryIds)
        {
            var d = await (await driver.PostAsync($"/api/driver/deliveries/{id}/accept", null).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
            byQuantity[d.GetProperty("quantity").GetInt32()] = id;
            await driver.PostAsJsonAsync($"/api/driver/deliveries/{id}/pickup", new { pickupCode = s.PickupCode }).EnsureOk();
            await driver.PostAsync($"/api/driver/deliveries/{id}/start", null).EnsureOk();
        }
        return (s, driver, byQuantity);
    }

    /// <summary>The customer's delivery code for an order, read from their own order screen.</summary>
    private static async Task<string> DeliveryCodeAsync(Scenario s, Guid deliveryId, HttpClient driver)
    {
        var quantity = (await driver.GetFromJsonAsync<JsonElement>($"/api/driver/deliveries/{deliveryId}")).GetProperty("quantity").GetInt32();
        foreach (var (client, orderId) in s.Customers)
        {
            var order = await client.GetFromJsonAsync<JsonElement>($"/api/customer/orders/{orderId}");
            if (order.GetProperty("order").GetProperty("quantity").GetInt32() == quantity) return order.GetProperty("delivery").GetProperty("deliveryCode").GetString()!;
        }
        throw new InvalidOperationException("delivery not found");
    }

    [Fact]
    public async Task Admin_cancels_a_running_campaign_and_customers_are_refunded()
    {
        var merchant = factory.CreateClient();
        await merchant.SignInAsync(Miga.Infrastructure.Persistence.DemoSeeder.MerchantPhone, 2);
        var storeId = (await merchant.GetFromJsonAsync<JsonElement>("/api/merchant/stores"))[0].GetProperty("id").GetGuid();
        var categoryId = (await merchant.GetFromJsonAsync<JsonElement>($"/api/merchant/stores/{storeId}/categories"))[0].GetProperty("id").GetGuid();
        var productId = (await (await merchant.PostAsJsonAsync($"/api/merchant/stores/{storeId}/products", new
        {
            productCategoryId = categoryId, nameAr = $"منتج إلغاء {Guid.NewGuid():N}"[..18], price = 100m, stockQuantity = 50, isActive = true, imageUrls = new[] { "p_rice.jpg" },
        }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
        var campaignId = (await (await merchant.PostAsJsonAsync("/api/merchant/campaigns", new
        {
            storeId, productId, titleAr = "حملة ستُلغى إداريًا", campaignPrice = 70m, targetQuantity = 10, durationDays = 5, publish = true,
        }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
        var (customer, addressId) = await factory.CustomerAsync();
        await customer.PostAsJsonAsync("/api/customer/cart/items", new { productId, campaignId, quantity = 2 }).EnsureOk();
        var orderId = (await (await customer.PostAsJsonAsync("/api/customer/checkout", new { addressId, paymentMethod = "mada" }).EnsureOk())
            .Content.ReadFromJsonAsync<JsonElement>()).GetProperty("items")[0].GetProperty("orderId").GetGuid();

        var admin = await AdminAsync();
        var list = await admin.GetFromJsonAsync<JsonElement>("/api/admin/campaigns?status=active&q=" + Uri.EscapeDataString("حملة ستُلغى إداريًا"));
        var row = Assert.Single(list.GetProperty("items").EnumerateArray());
        Assert.Equal(2, row.GetProperty("currentQuantity").GetInt32());
        Assert.Equal(1, row.GetProperty("participants").GetInt32());

        await admin.PostAsJsonAsync($"/api/admin/campaigns/{campaignId}/cancel", new { reason = "مخالفة سياسة التسعير" }).EnsureOk();
        var order = await customer.GetFromJsonAsync<JsonElement>($"/api/customer/orders/{orderId}");
        Assert.Equal((int)CampaignOrderStatus.Refunded, order.GetProperty("order").GetProperty("status").GetInt32());
        var notes = await merchant.GetFromJsonAsync<JsonElement>("/api/notifications");
        Assert.Contains(notes.EnumerateArray(), n => n.GetProperty("body").GetString()!.Contains("مخالفة سياسة التسعير"));
        Assert.Equal("campaign_not_cancellable",
            await CodeOf(await admin.PostAsJsonAsync($"/api/admin/campaigns/{campaignId}/cancel", new { reason = "مرة أخرى" })));
    }

    [Fact]
    public async Task Orders_and_aggregated_orders_are_listed_and_searchable()
    {
        var s = await factory.ReadyOrderAsync();
        var admin = await AdminAsync();
        var orderNumber = (await s.Customers[0].Client.GetFromJsonAsync<JsonElement>($"/api/customer/orders/{s.Customers[0].OrderId}")).GetProperty("order").GetProperty("number").GetString()!;

        var orders = await admin.GetFromJsonAsync<JsonElement>($"/api/admin/orders?status=active&q={orderNumber}");
        var row = Assert.Single(orders.GetProperty("items").EnumerateArray());
        Assert.Equal((int)PaymentStatus.Paid, row.GetProperty("paymentStatus").GetInt32());
        Assert.Equal((int)DeliveryStatus.Pending, row.GetProperty("deliveryStatus").GetInt32());

        var mos = await admin.GetFromJsonAsync<JsonElement>("/api/admin/merchant-orders?status=open&pageSize=50");
        var mo = mos.GetProperty("items").EnumerateArray().Single(o => o.GetProperty("id").GetGuid() == s.MerchantOrderId);
        Assert.Equal(2, mo.GetProperty("deliveries").GetInt32());
        Assert.Equal(9m, mo.GetProperty("platformFee").GetDecimal()); // 5% of 180

        var waiting = await admin.GetFromJsonAsync<JsonElement>("/api/admin/deliveries?status=waiting&pageSize=50");
        Assert.Equal(2, waiting.GetProperty("items").EnumerateArray().Count(d => s.DeliveryIds.Contains(d.GetProperty("id").GetGuid())));
    }

    [Fact]
    public async Task Live_map_shows_open_deliveries_their_store_and_the_driver_at_the_reported_location()
    {
        var (_, driver, byQuantity) = await OnTheWayAsync();
        var driverId = (await driver.GetFromJsonAsync<JsonElement>("/api/auth/me")).GetProperty("id").GetGuid();
        await driver.PostAsJsonAsync("/api/driver/location", new { latitude = 24.7742m, longitude = 46.7385m }).EnsureOk();
        Assert.Equal(HttpStatusCode.BadRequest, (await driver.PostAsJsonAsync("/api/driver/location", new { latitude = 124m, longitude = 46m })).StatusCode);

        var admin = await AdminAsync();
        var map = await admin.GetFromJsonAsync<JsonElement>("/api/admin/map");
        var d = map.GetProperty("drivers").EnumerateArray().Single(x => x.GetProperty("userId").GetGuid() == driverId);
        Assert.False(d.GetProperty("position").GetProperty("approximate").GetBoolean());
        Assert.Equal(24.7742, d.GetProperty("position").GetProperty("lat").GetDouble(), 4);
        Assert.Equal(2, d.GetProperty("activeDeliveries").GetInt32());

        var deliveries = map.GetProperty("deliveries").EnumerateArray().Where(x => byQuantity.ContainsValue(x.GetProperty("id").GetGuid())).ToList();
        Assert.Equal(2, deliveries.Count);
        Assert.All(deliveries, x => Assert.Equal(driverId, x.GetProperty("driverUserId").GetGuid()));
        var storeId = deliveries[0].GetProperty("storeId").GetGuid();
        Assert.Contains(map.GetProperty("stores").EnumerateArray(), x => x.GetProperty("id").GetGuid() == storeId);
        // Destinations without saved GPS sit near their district / city centre and say so.
        Assert.All(deliveries, x => Assert.InRange(x.GetProperty("destination").GetProperty("lat").GetDouble(), 16, 32));

        // Other cities' deliveries are filtered out by cityId.
        var jeddah = await factory.CityAsync("جدة");
        var jeddahMap = await admin.GetFromJsonAsync<JsonElement>($"/api/admin/map?cityId={jeddah}");
        Assert.DoesNotContain(jeddahMap.GetProperty("deliveries").EnumerateArray(), x => byQuantity.ContainsValue(x.GetProperty("id").GetGuid()));
    }

    [Fact]
    public async Task Failed_delivery_can_be_retried_with_the_same_driver()
    {
        var (s, driver, byQuantity) = await OnTheWayAsync();
        var id = byQuantity[1];
        await driver.PostAsJsonAsync($"/api/driver/deliveries/{id}/fail", new { reason = "العميل لا يرد" }).EnsureOk();

        var admin = await AdminAsync();
        var failed = await admin.GetFromJsonAsync<JsonElement>("/api/admin/deliveries?status=failed&pageSize=50");
        var row = failed.GetProperty("items").EnumerateArray().Single(d => d.GetProperty("id").GetGuid() == id);
        Assert.Equal("العميل لا يرد", row.GetProperty("failureReason").GetString());

        await admin.PostAsJsonAsync($"/api/admin/deliveries/{id}/retry", new { note = "العميل متاح بعد المغرب" }).EnsureOk();
        var back = await driver.GetFromJsonAsync<JsonElement>($"/api/driver/deliveries/{id}");
        Assert.Equal((int)DeliveryStatus.PickedUp, back.GetProperty("status").GetInt32());
        await driver.PostAsync($"/api/driver/deliveries/{id}/start", null).EnsureOk();
        await driver.PostAsJsonAsync($"/api/driver/deliveries/{id}/deliver", new { deliveryCode = await DeliveryCodeAsync(s, id, driver) }).EnsureOk();

        Assert.Equal("delivery_not_failed", await CodeOf(await admin.PostAsJsonAsync($"/api/admin/deliveries/{id}/retry", new { })));
    }

    [Fact]
    public async Task Refunding_a_failed_delivery_refunds_the_customer_and_settles_the_rest_for_the_merchant()
    {
        var (s, driver, byQuantity) = await OnTheWayAsync();
        var before = (await s.Merchant.GetFromJsonAsync<JsonElement>("/api/merchant/earnings")).GetProperty("available").GetDecimal();

        // Quantity 2 (120 SAR) is delivered; quantity 1 (60 SAR) fails and is refunded.
        await driver.PostAsJsonAsync($"/api/driver/deliveries/{byQuantity[2]}/deliver",
            new { deliveryCode = await DeliveryCodeAsync(s, byQuantity[2], driver) }).EnsureOk();
        await driver.PostAsJsonAsync($"/api/driver/deliveries/{byQuantity[1]}/fail", new { reason = "العنوان غير صحيح" }).EnsureOk();
        var stuck = (await s.Merchant.GetFromJsonAsync<JsonElement>("/api/merchant/earnings")).GetProperty("available").GetDecimal();
        Assert.Equal(before, stuck); // not settled while a delivery is unresolved

        var admin = await AdminAsync();
        await admin.PostAsJsonAsync($"/api/admin/deliveries/{byQuantity[1]}/refund", new { reason = "تعذّر الوصول للعميل" }).EnsureOk();

        foreach (var (client, orderId) in s.Customers)
        {
            var order = await client.GetFromJsonAsync<JsonElement>($"/api/customer/orders/{orderId}");
            var expected = order.GetProperty("order").GetProperty("quantity").GetInt32() == 1 ? CampaignOrderStatus.Refunded : CampaignOrderStatus.Delivered;
            Assert.Equal((int)expected, order.GetProperty("order").GetProperty("status").GetInt32());
        }

        // 120 kept − 5% commission on what was kept (6) = 114.
        var after = (await s.Merchant.GetFromJsonAsync<JsonElement>("/api/merchant/earnings")).GetProperty("available").GetDecimal();
        Assert.Equal(before + 114m, after);
    }

    [Fact]
    public async Task Withdrawals_are_paid_with_a_reference_or_rejected_back_to_the_balance()
    {
        // Make sure the demo merchant has a settled balance.
        var (s, driver, byQuantity) = await OnTheWayAsync();
        foreach (var id in byQuantity.Values)
            await driver.PostAsJsonAsync($"/api/driver/deliveries/{id}/deliver", new { deliveryCode = await DeliveryCodeAsync(s, id, driver) }).EnsureOk();
        await s.Merchant.PutAsJsonAsync("/api/merchant/bank-account", new { bankName = "مصرف الراجحي", iban = "SA0380000000608010167519" }).EnsureOk();
        var start = (await s.Merchant.GetFromJsonAsync<JsonElement>("/api/merchant/earnings")).GetProperty("available").GetDecimal();

        await s.Merchant.PostAsJsonAsync("/api/merchant/payouts", new { amount = 100m }).EnsureOk();
        await s.Merchant.PostAsJsonAsync("/api/merchant/payouts", new { amount = 100m }).EnsureOk();
        Assert.Equal(start - 200, (await s.Merchant.GetFromJsonAsync<JsonElement>("/api/merchant/earnings")).GetProperty("available").GetDecimal());

        var admin = await AdminAsync();
        var queue = await admin.GetFromJsonAsync<JsonElement>("/api/admin/payouts?status=requested&pageSize=50");
        var mine = queue.GetProperty("items").EnumerateArray().Where(p => p.GetProperty("iban").GetString() == "SA0380000000608010167519").ToList();
        Assert.True(mine.Count >= 2);
        Assert.Equal("مصرف الراجحي", mine[0].GetProperty("bankName").GetString());
        var (paidId, rejectedId) = (mine[^2].GetProperty("id").GetGuid(), mine[^1].GetProperty("id").GetGuid());

        await admin.PostAsJsonAsync($"/api/admin/payouts/{paidId}/paid", new { reference = "TRX-2026-0042" }).EnsureOk();
        await admin.PostAsJsonAsync($"/api/admin/payouts/{rejectedId}/reject", new { reason = "اسم صاحب الحساب لا يطابق السجل" }).EnsureOk();
        Assert.Equal("payout_already_processed", await CodeOf(await admin.PostAsJsonAsync($"/api/admin/payouts/{paidId}/paid", new { reference = "TRX-x" })));

        var earnings = await s.Merchant.GetFromJsonAsync<JsonElement>("/api/merchant/earnings");
        Assert.Equal(start - 100, earnings.GetProperty("available").GetDecimal()); // the rejected 100 is back
        Assert.Contains(earnings.GetProperty("transactions").EnumerateArray(), t => t.GetProperty("subtitle").GetString()!.StartsWith("تم التحويل"));
        var notes = await s.Merchant.GetFromJsonAsync<JsonElement>("/api/notifications");
        Assert.Contains(notes.EnumerateArray(), n => n.GetProperty("body").GetString()!.Contains("TRX-2026-0042"));

        var paid = await admin.GetFromJsonAsync<JsonElement>("/api/admin/payouts?status=paid&pageSize=50");
        Assert.Contains(paid.GetProperty("items").EnumerateArray(), p => p.GetProperty("transferReference").GetString() == "TRX-2026-0042");
    }

    [Fact]
    public async Task Non_admins_cannot_process_operations()
    {
        var (driver, _) = await factory.DriverAsync();
        Assert.Equal(HttpStatusCode.Forbidden, (await driver.GetAsync("/api/admin/deliveries")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await driver.PostAsJsonAsync($"/api/admin/payouts/{Guid.NewGuid()}/paid", new { reference = "TRX-1" })).StatusCode);
    }
}
