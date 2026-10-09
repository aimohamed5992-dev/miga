using System.Net.Http.Json;
using System.Text.Json;
using Miga.Infrastructure.Persistence;

namespace Miga.Api.Tests;

public record Scenario(HttpClient Merchant, Guid MerchantOrderId, string PickupCode, List<Guid> DeliveryIds, List<(HttpClient Client, Guid OrderId)> Customers);

/// <summary>Multi-app setups shared by the driver and admin tests.</summary>
public static class Scenarios
{
    private const int Customer = 1, Merchant = 2, Driver = 3;

    public static async Task<Guid> CityAsync(this MigaApiFactory factory, string nameAr)
    {
        var regions = await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/regions");
        return regions.EnumerateArray().SelectMany(r => r.GetProperty("cities").EnumerateArray())
            .First(c => c.GetProperty("nameAr").GetString() == nameAr).GetProperty("id").GetGuid();
    }

    /// <summary>Registered driver, verified by the admin through the API, optionally online.</summary>
    public static async Task<(HttpClient Client, Guid UserId)> DriverAsync(this MigaApiFactory factory, string city = "الرياض", bool verify = true, bool online = true)
    {
        var client = factory.CreateClient();
        var auth = await client.SignInAsync(MigaApiFactory.NewPhone(), Driver);
        await client.PostAsJsonAsync("/api/driver/register", new
        {
            fullName = "عبدالرحمن السبيعي", nationalId = "1012345678", cityId = await factory.CityAsync(city), vehicleType = "فان", vehiclePlateNumber = "أ ب ج 1234",
        }).EnsureOk();
        if (verify)
        {
            var admin = factory.CreateClient();
            await admin.SignInAsync(MigaApiFactory.AdminPhone, Customer);
            await admin.PostAsync($"/api/admin/drivers/{auth.Account.Id}/verify", null).EnsureOk();
            if (online) await client.PatchAsJsonAsync("/api/driver/availability", new { available = true }).EnsureOk();
        }
        return (client, auth.Account.Id);
    }

    public static async Task<(HttpClient Client, Guid AddressId)> CustomerAsync(this MigaApiFactory factory)
    {
        var client = factory.CreateClient();
        await client.SignInAsync(MigaApiFactory.NewPhone(), Customer);
        var regions = await client.GetFromJsonAsync<JsonElement>("/api/regions");
        var city = regions[0].GetProperty("cities").EnumerateArray().First(c => c.GetProperty("nameAr").GetString() == "الرياض");
        var address = await (await client.PostAsJsonAsync("/api/customer/addresses", new
        {
            addressName = "المنزل", regionId = regions[0].GetProperty("id").GetGuid(), cityId = city.GetProperty("id").GetGuid(),
            districtId = city.GetProperty("districts")[0].GetProperty("id").GetGuid(), phoneNumber = "0551234567", addressDetails = "شارع 5، مبنى 12",
        }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        return (client, address.GetProperty("id").GetGuid());
    }

    /// <summary>
    /// Merchant creates a 3-piece campaign, two customers fill it, merchant takes the aggregated order to Ready.
    /// Returns everything needed to drive the delivery side.
    /// </summary>
    public static async Task<Scenario> ReadyOrderAsync(this MigaApiFactory factory)
    {
        var merchant = factory.CreateClient();
        await merchant.SignInAsync(DemoSeeder.MerchantPhone, Merchant);
        var storeId = (await merchant.GetFromJsonAsync<JsonElement>("/api/merchant/stores")).EnumerateArray()
            .First(s => s.GetProperty("nameAr").GetString() == "أسواق الخير").GetProperty("id").GetGuid();
        var categoryId = (await merchant.GetFromJsonAsync<JsonElement>($"/api/merchant/stores/{storeId}/categories"))[0].GetProperty("id").GetGuid();
        var productId = (await (await merchant.PostAsJsonAsync($"/api/merchant/stores/{storeId}/products", new
        {
            productCategoryId = categoryId, nameAr = $"منتج توصيل {Guid.NewGuid():N}"[..18], price = 100m, stockQuantity = 100, isActive = true, imageUrls = new[] { "p_dates.jpg" },
        }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
        var campaignId = (await (await merchant.PostAsJsonAsync("/api/merchant/campaigns", new
        {
            storeId, productId, titleAr = "حملة التوصيل", campaignPrice = 60m, targetQuantity = 3, maxQuantityPerCustomer = 3, durationDays = 7, publish = true,
        }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();

        var customers = new List<(HttpClient Client, Guid OrderId)>();
        foreach (var qty in new[] { 1, 2 })
        {
            var (client, addressId) = await factory.CustomerAsync();
            await client.PostAsJsonAsync("/api/customer/cart/items", new { productId, campaignId, quantity = qty }).EnsureOk();
            var result = await (await client.PostAsJsonAsync("/api/customer/checkout", new { addressId, paymentMethod = "mada" }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
            customers.Add((client, result.GetProperty("items")[0].GetProperty("orderId").GetGuid()));
        }

        var moId = (await merchant.GetFromJsonAsync<JsonElement>("/api/merchant/orders?tab=new")).GetProperty("items").EnumerateArray()
            .First(o => o.GetProperty("campaignId").GetGuid() == campaignId).GetProperty("id").GetGuid();
        await merchant.PostAsync($"/api/merchant/orders/{moId}/confirm", null).EnsureOk();
        await merchant.PostAsync($"/api/merchant/orders/{moId}/start-preparing", null).EnsureOk();
        var ready = await (await merchant.PostAsync($"/api/merchant/orders/{moId}/ready", null).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
        var deliveryIds = ready.GetProperty("deliveries").EnumerateArray().Select(d => d.GetProperty("id").GetGuid()).ToList();
        return new Scenario(merchant, moId, ready.GetProperty("pickupCode").GetString()!, deliveryIds, customers);
    }
}
