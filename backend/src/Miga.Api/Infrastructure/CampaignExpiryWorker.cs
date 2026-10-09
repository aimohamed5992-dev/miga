using Miga.Infrastructure.Features.Orders;

namespace Miga.Api.Infrastructure;

/// <summary>Every minute: campaigns past their end date become Failed (with refunds) or Completed if they filled up.</summary>
public class CampaignExpiryWorker(IServiceScopeFactory scopes, IConfiguration config, ILogger<CampaignExpiryWorker> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!config.GetValue("Jobs:CampaignExpiryEnabled", true)) return;
        var interval = TimeSpan.FromSeconds(config.GetValue("Jobs:CampaignExpiryIntervalSeconds", 60));
        using var timer = new PeriodicTimer(interval);
        do
        {
            try
            {
                using var scope = scopes.CreateScope();
                var expired = await scope.ServiceProvider.GetRequiredService<CampaignLifecycleService>().ExpireDueAsync(stoppingToken);
                if (expired > 0) log.LogInformation("Closed {Count} expired campaigns", expired);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                log.LogError(ex, "Campaign expiry run failed");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
