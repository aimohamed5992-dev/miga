using System.Net;

namespace Miga.Api.Tests;

[Collection(ApiCollection.Name)]
public class CorsTests(MigaApiFactory factory)
{
    [Fact]
    public async Task Unknown_origins_get_no_cors_headers()
    {
        // Tests run in the "Testing" environment, so the development localhost allowance is off.
        var req = new HttpRequestMessage(HttpMethod.Options, "/api/admin/dashboard");
        req.Headers.Add("Origin", "https://evil.example");
        req.Headers.Add("Access-Control-Request-Method", "GET");
        var res = await factory.CreateClient().SendAsync(req);
        Assert.False(res.Headers.Contains("Access-Control-Allow-Origin"));
    }
}
