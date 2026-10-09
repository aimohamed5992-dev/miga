using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Miga.Domain;
using Miga.Infrastructure.Persistence;

namespace Miga.Api.Tests;

/// <summary>End-to-end across all three apps: customers buy → campaign completes → merchant prepares → drivers deliver.</summary>
[Collection(ApiCollection.Name)]
public class DriverTests(MigaApiFactory factory)
{
    private const int Customer = 1, Merchant = 2, Driver = 3;

    private static async Task<string> CodeOf(HttpResponseMessage r) =>
        JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement.GetProperty("code").GetString()!;

    private Task<Guid> CityAsync(string nameAr) => factory.CityAsync(nameAr);

    private Task<(HttpClient Client, Guid UserId)> DriverAsync(string city = "الرياض", bool verify = true, bool online = true) =>
        factory.DriverAsync(city, verify, online);

    private Task<(HttpClient Client, Guid AddressId)> CustomerAsync() => factory.CustomerAsync();

    private Task<Scenario> ReadyOrderAsync() => factory.ReadyOrderAsync();


    [Fact]
    public async Task Full_delivery_cycle_completes_orders_and_settles_the_merchant()
    {
        var s = await ReadyOrderAsync();
        var (driver, _) = await DriverAsync();

        var requests = await driver.GetFromJsonAsync<JsonElement>("/api/driver/requests");
        var mine = requests.EnumerateArray().Where(r => s.DeliveryIds.Contains(r.GetProperty("id").GetGuid())).ToList();
        Assert.Equal(2, mine.Count);
        Assert.False(mine[0].TryGetProperty("customerName", out _)); // identity hidden before accepting

        foreach (var id in s.DeliveryIds)
        {
            var accepted = await (await driver.PostAsync($"/api/driver/deliveries/{id}/accept", null).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal("شارع 5، مبنى 12", accepted.GetProperty("addressDetails").GetString());
        }

        // Pickup needs the merchant's code; the aggregated order completes once everything left the warehouse.
        Assert.Equal("invalid_pickup_code", await CodeOf(await driver.PostAsJsonAsync($"/api/driver/deliveries/{s.DeliveryIds[0]}/pickup", new { pickupCode = "0000x" })));
        await driver.PostAsJsonAsync($"/api/driver/deliveries/{s.DeliveryIds[0]}/pickup", new { pickupCode = s.PickupCode }).EnsureOk();
        var half = await s.Merchant.GetFromJsonAsync<JsonElement>($"/api/merchant/orders/{s.MerchantOrderId}");
        Assert.Equal((int)MerchantOrderStatus.Ready, half.GetProperty("order").GetProperty("status").GetInt32());
        await driver.PostAsJsonAsync($"/api/driver/deliveries/{s.DeliveryIds[1]}/pickup", new { pickupCode = s.PickupCode }).EnsureOk();
        var done = await s.Merchant.GetFromJsonAsync<JsonElement>($"/api/merchant/orders/{s.MerchantOrderId}");
        Assert.Equal((int)MerchantOrderStatus.Completed, done.GetProperty("order").GetProperty("status").GetInt32());

        foreach (var id in s.DeliveryIds) await driver.PostAsync($"/api/driver/deliveries/{id}/start", null).EnsureOk();

        // Each customer sees the driver and their own delivery code, and hands it over.
        var settledBefore = (await s.Merchant.GetFromJsonAsync<JsonElement>("/api/merchant/earnings")).GetProperty("available").GetDecimal();
        // Quantities are 1 and 2, so quantity identifies which delivery belongs to which customer.
        var deliveryByQuantity = new Dictionary<int, Guid>();
        foreach (var id in s.DeliveryIds)
        {
            deliveryByQuantity[(await driver.GetFromJsonAsync<JsonElement>($"/api/driver/deliveries/{id}")).GetProperty("quantity").GetInt32()] = id;
        }
        foreach (var (client, orderId) in s.Customers)
        {
            var order = await client.GetFromJsonAsync<JsonElement>($"/api/customer/orders/{orderId}");
            Assert.Equal((int)CampaignOrderStatus.OutForDelivery, order.GetProperty("order").GetProperty("status").GetInt32());
            Assert.Equal("عبدالرحمن السبيعي", order.GetProperty("delivery").GetProperty("driverName").GetString());
            var deliveryId = deliveryByQuantity[order.GetProperty("order").GetProperty("quantity").GetInt32()];

            Assert.Equal("invalid_delivery_code", await CodeOf(await driver.PostAsJsonAsync($"/api/driver/deliveries/{deliveryId}/deliver", new { deliveryCode = "99999" })));
            var code = order.GetProperty("delivery").GetProperty("deliveryCode").GetString();
            await driver.PostAsJsonAsync($"/api/driver/deliveries/{deliveryId}/deliver", new { deliveryCode = code }).EnsureOk();

            var after = await client.GetFromJsonAsync<JsonElement>($"/api/customer/orders/{orderId}");
            Assert.Equal((int)CampaignOrderStatus.Delivered, after.GetProperty("order").GetProperty("status").GetInt32());
        }

        // All delivered → net 180 − 9 becomes withdrawable; driver earned 2 × 15.
        var settled = (await s.Merchant.GetFromJsonAsync<JsonElement>("/api/merchant/earnings")).GetProperty("available").GetDecimal();
        Assert.Equal(settledBefore + 171, settled);
        var earnings = await driver.GetFromJsonAsync<JsonElement>("/api/driver/earnings");
        Assert.Equal(30, earnings.GetProperty("total").GetDecimal());
        Assert.Equal(2, earnings.GetProperty("deliveries").GetInt32());
        var home = await driver.GetFromJsonAsync<JsonElement>("/api/driver/home");
        Assert.Equal(30, home.GetProperty("todayEarnings").GetDecimal());
        Assert.Equal("الرياض", home.GetProperty("cityName").GetString());
        Assert.False(string.IsNullOrEmpty(home.GetProperty("vehicle").GetProperty("plateNumber").GetString()));
    }

    [Fact]
    public async Task Two_drivers_racing_for_one_delivery_only_one_wins()
    {
        var s = await ReadyOrderAsync();
        var (d1, _) = await DriverAsync();
        var (d2, _) = await DriverAsync();

        var responses = await Task.WhenAll(
            d1.PostAsync($"/api/driver/deliveries/{s.DeliveryIds[0]}/accept", null),
            d2.PostAsync($"/api/driver/deliveries/{s.DeliveryIds[0]}/accept", null));
        Assert.Equal(1, responses.Count(r => r.IsSuccessStatusCode));
        Assert.Equal(1, responses.Count(r => r.StatusCode == HttpStatusCode.Conflict));
    }

    [Fact]
    public async Task Requests_are_city_scoped_and_need_a_verified_online_driver()
    {
        var s = await ReadyOrderAsync();

        var (jeddah, _) = await DriverAsync(city: "جدة");
        var seen = await jeddah.GetFromJsonAsync<JsonElement>("/api/driver/requests");
        Assert.DoesNotContain(seen.EnumerateArray(), r => s.DeliveryIds.Contains(r.GetProperty("id").GetGuid()));

        var (pending, _) = await DriverAsync(verify: false);
        var blocked = await pending.GetAsync("/api/driver/requests");
        Assert.Equal(HttpStatusCode.Forbidden, blocked.StatusCode);
        Assert.Equal("driver_not_verified", await CodeOf(blocked));

        var (offline, _) = await DriverAsync(online: false);
        Assert.Equal(0, (await offline.GetFromJsonAsync<JsonElement>("/api/driver/requests")).GetArrayLength());
        Assert.Equal("driver_unavailable", await CodeOf(await offline.PostAsync($"/api/driver/deliveries/{s.DeliveryIds[0]}/accept", null)));
    }

    [Fact]
    public async Task Release_returns_the_delivery_and_failure_notifies_customer_and_merchant()
    {
        var s = await ReadyOrderAsync();
        var (driver, _) = await DriverAsync();
        var (other, _) = await DriverAsync();

        await driver.PostAsync($"/api/driver/deliveries/{s.DeliveryIds[0]}/accept", null).EnsureOk();
        await driver.PostAsync($"/api/driver/deliveries/{s.DeliveryIds[0]}/release", null).EnsureOk();
        await other.PostAsync($"/api/driver/deliveries/{s.DeliveryIds[0]}/accept", null).EnsureOk(); // back in the pool

        await other.PostAsJsonAsync($"/api/driver/deliveries/{s.DeliveryIds[0]}/pickup", new { pickupCode = s.PickupCode }).EnsureOk();
        Assert.Equal("invalid_delivery_transition", await CodeOf(await other.PostAsync($"/api/driver/deliveries/{s.DeliveryIds[0]}/release", null)));
        await other.PostAsync($"/api/driver/deliveries/{s.DeliveryIds[0]}/start", null).EnsureOk();

        var failed = await (await other.PostAsJsonAsync($"/api/driver/deliveries/{s.DeliveryIds[0]}/fail", new { reason = "العميل لا يرد" }).EnsureOk())
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal((int)DeliveryStatus.Failed, failed.GetProperty("status").GetInt32());

        var merchantNotes = await s.Merchant.GetFromJsonAsync<JsonElement>("/api/notifications");
        Assert.Contains(merchantNotes.EnumerateArray(), n => n.GetProperty("title").GetString() == "تعذّر تسليم توصيلة");
        var anyCustomerNotified = false;
        foreach (var (client, _) in s.Customers)
        {
            var notes = await client.GetFromJsonAsync<JsonElement>("/api/notifications");
            anyCustomerNotified |= notes.EnumerateArray().Any(n => n.GetProperty("title").GetString() == "تعذّر تسليم طلبك");
        }
        Assert.True(anyCustomerNotified);
    }
}
