
using SmartFoundation.Application.Services;
using System.Data;

namespace SmartFoundation.Mvc.Services
{
    public sealed class DashboardMetricsRefreshWorker : BackgroundService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly DashboardDisplaySessionStore _sessionStore;
        private readonly ILogger<DashboardMetricsRefreshWorker> _logger;

        public DashboardMetricsRefreshWorker(
            IServiceScopeFactory scopeFactory,
            DashboardDisplaySessionStore sessionStore,
            ILogger<DashboardMetricsRefreshWorker> logger)
        {
            _scopeFactory = scopeFactory;
            _sessionStore = sessionStore;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(
            CancellationToken stoppingToken)
        {
            // Delay initial work to avoid startup contention.
            await Task.Delay(TimeSpan.FromSeconds(60), stoppingToken);

            using var timer = new PeriodicTimer(
                TimeSpan.FromSeconds(60));

            do
            {
                try
                {
                    var contexts =
                        _sessionStore.GetActiveMetricsContexts();

                    foreach (var context in contexts)
                    {
                        stoppingToken.ThrowIfCancellationRequested();

                        try
                        {
                            await RefreshContextAsync(
                                context,
                                stoppingToken);
                        }
                        catch (OperationCanceledException)
                            when (stoppingToken.IsCancellationRequested)
                        {
                            throw;
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(
                                ex,
                                "Dashboard background refresh failed.");
                        }
                    }
                }
                catch (OperationCanceledException)
                    when (stoppingToken.IsCancellationRequested)
                {
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(
                        ex,
                        "Dashboard refresh cycle failed.");
                }
            }
            while (await timer.WaitForNextTickAsync(stoppingToken));
        }

        private async Task RefreshContextAsync(
            DashboardMetricsContext context,
            CancellationToken cancellationToken)
        {
            using var scope = _scopeFactory.CreateScope();

            var mastersServies =
                scope.ServiceProvider.GetRequiredService<MastersServies>();

            var cacheService =
                scope.ServiceProvider.GetRequiredService<
                    DashboardMetricsCacheService>();

            // Never refresh on session existence alone.
            // Verify current server-side VIEWDASHBOARD permission.
            var permissionParameters = new Dictionary<string, object?>
            {
                ["pageName_"] = context.PageName,
                ["idaraID"] = context.IdaraId,
                ["entrydata"] = context.UserId,
                ["hostname"] = context.HostName,
                ["parameter_20"] = "HEADER_PERMISSION_ONLY"
            };

            DataSet permissionDs = await mastersServies
                .GetDataLoadDataSetAsync(permissionParameters);

            bool permitted =
                permissionDs.Tables.Count > 0 &&
                permissionDs.Tables[0].Columns.Contains(
                    "permissionTypeName_E") &&
                permissionDs.Tables[0].Rows
                    .Cast<DataRow>()
                    .Any(row =>
                        string.Equals(
                            row["permissionTypeName_E"]?
                                .ToString()?.Trim(),
                            "VIEWDASHBOARD",
                            StringComparison.OrdinalIgnoreCase));

            if (!permitted)
                return;

            cancellationToken.ThrowIfCancellationRequested();

            var scopeParameters = new Dictionary<string, object?>
            {
                ["pageName_"] = context.PageName,
                ["idaraID"] = context.IdaraId,
                ["entrydata"] = context.UserId,
                ["hostname"] = context.HostName,
                ["parameter_20"] = "DASHBOARD_SCOPE_ONLY"
            };

            DataSet scopeDs = await mastersServies
                .GetDataLoadDataSetAsync(scopeParameters);

            if (scopeDs.Tables.Count < 2)
                return;

            DataTable scopeTable = scopeDs.Tables[1];

            if (!scopeTable.Columns.Contains("idaraID") ||
                !scopeTable.Columns.Contains("TrustedIdaraID") ||
                !scopeTable.Columns.Contains("ShowFullDashboard") ||
                scopeTable.Rows.Count == 0)
            {
                return;
            }

            string[] ids = scopeTable.Rows.Cast<DataRow>()
                .Select(r => Convert.ToInt32(r["idaraID"]))
                .Distinct()
                .OrderBy(id => id)
                .Select(id => id.ToString(
                    System.Globalization.CultureInfo.InvariantCulture))
                .ToArray();

            int trustedIdara = Convert.ToInt32(
                scopeTable.Rows[0]["TrustedIdaraID"]);

            bool showFull = Convert.ToBoolean(
                scopeTable.Rows[0]["ShowFullDashboard"]);

            string scopeKey =
                $"{trustedIdara}:{(showFull ? 1 : 0)}:{string.Join(",", ids)}";

            await cacheService.RefreshAsync(
                context,
                scopeKey,
                cancellationToken);
        }
    }
}
