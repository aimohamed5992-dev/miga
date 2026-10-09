using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace Miga.Api.Tests;

/// <summary>Platform settings edited from the admin dashboard: validation, public config, and the fee applied to new aggregated orders.</summary>
[Collection(ApiCollection.Name)]
public class SettingsTests(MigaApiFactory factory)
{
    [Fact]
    public async Task Admin_changes_commission_and_support_and_new_orders_use_the_new_rate()
    {
        var admin = factory.CreateClient();
        await admin.SignInAsync(MigaApiFactory.AdminPhone, 4);
        var before = await admin.GetFromJsonAsync<JsonElement>("/api/admin/settings");

        try
        {
            Assert.Equal(HttpStatusCode.BadRequest, (await admin.PutAsJsonAsync("/api/admin/settings", new { platformFeePercent = 45m, deliveryFee = 15m })).StatusCode);
            Assert.Equal(HttpStatusCode.BadRequest,
                (await admin.PutAsJsonAsync("/api/admin/settings", new { platformFeePercent = 5m, deliveryFee = 15m, supportEmail = "not-an-email" })).StatusCode);

            var saved = await (await admin.PutAsJsonAsync("/api/admin/settings", new
            {
                platformFeePercent = 10m, deliveryFee = 20m, supportPhone = "920001234", supportWhatsApp = "+966500000099", supportEmail = "care@miga.sa",
            }).EnsureOk()).Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal("966500000099", saved.GetProperty("support").GetProperty("whatsApp").GetString());
            Assert.False(string.IsNullOrEmpty(saved.GetProperty("updatedBy").GetString()));

            // Apps read the same values (anonymous).
            var config = await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/config");
            Assert.Equal(10m, config.GetProperty("platformFeePercent").GetDecimal());
            Assert.Equal("care@miga.sa", config.GetProperty("support").GetProperty("email").GetString());

            // A campaign completing now is charged 10% and its deliveries pay 20.
            var s = await factory.ReadyOrderAsync(); // 3 × 60 = 180
            var mo = await s.Merchant.GetFromJsonAsync<JsonElement>($"/api/merchant/orders/{s.MerchantOrderId}");
            Assert.Equal(18m, mo.GetProperty("platformFee").GetDecimal());
            var deliveries = await admin.GetFromJsonAsync<JsonElement>("/api/admin/deliveries?status=all&pageSize=100");
            Assert.All(deliveries.GetProperty("items").EnumerateArray().Where(d => s.DeliveryIds.Contains(d.GetProperty("id").GetGuid())),
                d => Assert.Equal(20m, d.GetProperty("fee").GetDecimal()));
        }
        finally
        {
            var support = before.GetProperty("support");
            await admin.PutAsJsonAsync("/api/admin/settings", new
            {
                platformFeePercent = before.GetProperty("platformFeePercent").GetDecimal(),
                deliveryFee = before.GetProperty("deliveryFee").GetDecimal(),
                supportPhone = support.GetProperty("phone").GetString(),
                supportWhatsApp = support.GetProperty("whatsApp").GetString(),
                supportEmail = support.GetProperty("email").GetString(),
            });
        }
    }
}
