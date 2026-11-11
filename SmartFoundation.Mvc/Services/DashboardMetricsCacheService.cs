
using Microsoft.Extensions.Caching.Memory;
using SmartFoundation.Application.Services;
using System.Data;

namespace SmartFoundation.Mvc.Services
{
    public sealed class DashboardMetricsCacheService
    {
        private readonly IMemoryCache _cache;
        private readonly MastersServies _mastersServies;

        private static readonly SemaphoreSlim[] Locks =
            Enumerable.Range(0, 32)
                .Select(_ => new SemaphoreSlim(1, 1))
                .ToArray();

        private sealed record Snapshot(
            DataSet Metrics,
            DateTimeOffset UpdatedAtUtc
        );

        public DashboardMetricsCacheService(
            IMemoryCache cache,
            MastersServies mastersServies)
        {
            _cache = cache;
            _mastersServies = mastersServies;
        }

        private static string GetKey(
    DashboardMetricsContext context,
    string scopeKey)
        {
            return $"HCC:Background:v2:{context.PageName}:{context.IdaraId}:{context.UserId}:{context.HostName}:{scopeKey}";
        }

        public bool TryGetSnapshot(
    DashboardMetricsContext context,
    string scopeKey,
    out DataSet? metrics,
    out DateTimeOffset? updatedAtUtc)
        {
            if (_cache.TryGetValue<Snapshot>(
                GetKey(context, scopeKey), out var snapshot)
                && snapshot != null)
            {
                metrics = snapshot.Metrics.Copy();
                updatedAtUtc = snapshot.UpdatedAtUtc;
                return true;
            }

            metrics = null;
            updatedAtUtc = null;
            return false;
        }

        public async Task<bool> RefreshAsync(
    DashboardMetricsContext context,
    string scopeKey,
    CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(scopeKey))
                throw new UnauthorizedAccessException(
                    "Dashboard scope is unavailable.");

            string key = GetKey(context, scopeKey);

            int lockIndex = (int)(
                (uint)StringComparer.Ordinal.GetHashCode(key)
                % (uint)Locks.Length);

            var gate = Locks[lockIndex];

            await gate.WaitAsync(cancellationToken);

            try
            {
                // Avoid recalculating a recently refreshed snapshot.
                if (_cache.TryGetValue<Snapshot>(key, out var existing)
                    && existing != null
                    && DateTimeOffset.UtcNow - existing.UpdatedAtUtc
                        < TimeSpan.FromMinutes(5))
                {
                    return true;
                }

                var parameters = new object?[]
                {
                    context.PageName,
                    context.IdaraId,
                    context.UserId,
                    context.HostName
                };

                DataSet ds = await _mastersServies
                    .GetDataLoadDataSetAsync(parameters);

                // Keep the existing minimum until the
                // expected SQL result-set contract is verified.
                if (ds.Tables.Count < 12)
                    throw new InvalidOperationException(
                        "Dashboard metrics result is incomplete.");

                var metrics = new DataSet();

                // Tables[0] contains user permissions.
                // Never store it in the shared metrics snapshot.
                for (int i = 1; i < ds.Tables.Count; i++)
                    metrics.Tables.Add(ds.Tables[i].Copy());

                // Verify that the authorization scope has not changed
                // while SQL metrics were being calculated.
                var scopeParameters = new Dictionary<string, object?>
                {
                    ["pageName_"] = context.PageName,
                    ["idaraID"] = context.IdaraId,
                    ["entrydata"] = context.UserId,
                    ["hostname"] = context.HostName,
                    ["parameter_20"] = "DASHBOARD_SCOPE_ONLY"
                };

                DataSet scopeDs = await _mastersServies
                    .GetDataLoadDataSetAsync(scopeParameters);

                if (scopeDs.Tables.Count < 2)
                    return false;

                DataTable scope = scopeDs.Tables[1];

                if (!scope.Columns.Contains("idaraID") ||
                    !scope.Columns.Contains("TrustedIdaraID") ||
                    !scope.Columns.Contains("ShowFullDashboard") ||
                    scope.Rows.Count == 0)
                {
                    return false;
                }

                string[] ids = scope.Rows.Cast<DataRow>()
                    .Select(r => Convert.ToInt32(r["idaraID"]))
                    .Distinct()
                    .OrderBy(id => id)
                    .Select(id => id.ToString(
                        System.Globalization.CultureInfo.InvariantCulture))
                    .ToArray();

                int trustedIdara = Convert.ToInt32(
                    scope.Rows[0]["TrustedIdaraID"]);

                bool showFull = Convert.ToBoolean(
                    scope.Rows[0]["ShowFullDashboard"]);

                string currentScopeKey =
                    $"{trustedIdara}:{(showFull ? 1 : 0)}:{string.Join(",", ids)}";

                if (!string.Equals(
                        scopeKey,
                        currentScopeKey,
                        StringComparison.Ordinal))
                {
                    return false;
                }

                cancellationToken.ThrowIfCancellationRequested();

                // Verify VIEWDASHBOARD before publishing the snapshot.
                var permissionParameters = new Dictionary<string, object?>
                {
                    ["pageName_"] = context.PageName,
                    ["idaraID"] = context.IdaraId,
                    ["entrydata"] = context.UserId,
                    ["hostname"] = context.HostName,
                    ["parameter_20"] = "HEADER_PERMISSION_ONLY"
                };

                DataSet permissionDs = await _mastersServies
                    .GetDataLoadDataSetAsync(permissionParameters);

                bool permitted =
                    permissionDs.Tables.Count > 0 &&
                    permissionDs.Tables[0].Columns.Contains("permissionTypeName_E") &&
                    permissionDs.Tables[0].Rows.Cast<DataRow>().Any(row =>
                        string.Equals(
                            row["permissionTypeName_E"]?.ToString()?.Trim(),
                            "VIEWDASHBOARD",
                            StringComparison.OrdinalIgnoreCase));

                if (!permitted)
                    return false;

                cancellationToken.ThrowIfCancellationRequested();

                // Publish only a snapshot matching the current scope.
                var snapshot = new Snapshot(
                    metrics,
                    DateTimeOffset.UtcNow);

                _cache.Set(
                    key,
                    snapshot,
                    TimeSpan.FromMinutes(30));



                return true;
            }
            finally
            {
                gate.Release();
            }
        }
    }
}
