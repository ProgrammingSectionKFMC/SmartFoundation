
using Microsoft.Extensions.Caching.Memory;
using System.Data;

namespace SmartFoundation.Mvc.Controllers.HousingCommandCenter
{
    public partial class HousingCommandCenterDashboardController
    {
        private static readonly SemaphoreSlim[] _dashboardCacheLocks =
    Enumerable.Range(0, 32)
        .Select(_ => new SemaphoreSlim(1, 1))
        .ToArray();

        private async Task<DataSet> LoadDashboardMetricsAsync()
        {
            string scopeKey = await GetDashboardScopeKeyAsync();

            if (!string.IsNullOrWhiteSpace(IdaraId) &&
                !string.IsNullOrWhiteSpace(usersId))
            {
                var context = new SmartFoundation.Mvc.Services.DashboardMetricsContext(
                    PageName,
                    IdaraId,
                    usersId,
                    HostName ?? string.Empty);

                if (_dashboardMetricsCacheService.TryGetSnapshot(
         context,
         scopeKey,
         out var backgroundMetrics,
         out var updatedAtUtc)
                     && backgroundMetrics != null
                    && updatedAtUtc.HasValue
                    && DateTimeOffset.UtcNow - updatedAtUtc.Value
                        < TimeSpan.FromMinutes(10))
                {


                    string verifiedScopeKey = await GetDashboardScopeKeyAsync();

                    if (!string.Equals(
                            scopeKey,
                            verifiedScopeKey,
                            StringComparison.Ordinal))
                    {
                        throw new UnauthorizedAccessException(
                            "Dashboard scope changed while reading cache.");
                    }

                    return backgroundMetrics;
                }
            }


            // فصل بيانات كل مستخدم وإدارة، دون مشاركة الصلاحيات.
            string cacheKey =
    $"HCC:Metrics:v2:{IdaraId}:{usersId}:{scopeKey}";

            if (_memoryCache.TryGetValue<DataSet>(cacheKey, out var cached)
    && cached != null)
            {
                string verifiedScopeKey = await GetDashboardScopeKeyAsync();

                if (!string.Equals(
                        scopeKey,
                        verifiedScopeKey,
                        StringComparison.Ordinal))
                {
                    throw new UnauthorizedAccessException(
                        "Dashboard scope changed while reading cache.");
                }

                return cached.Copy();
            }

            int lockIndex = (int)(
    (uint)StringComparer.Ordinal.GetHashCode(cacheKey)
    % (uint)_dashboardCacheLocks.Length);

            var gate = _dashboardCacheLocks[lockIndex];

            await gate.WaitAsync();

            try
            {
                if (_memoryCache.TryGetValue<DataSet>(
    cacheKey, out cached) && cached != null)
                {
                    string verifiedScopeKey = await GetDashboardScopeKeyAsync();

                    if (!string.Equals(
                            scopeKey,
                            verifiedScopeKey,
                            StringComparison.Ordinal))
                    {
                        throw new UnauthorizedAccessException(
                            "Dashboard scope changed while reading cache.");
                    }

                    return cached.Copy();
                }

                var parameters = new object?[]
                {
                    PageName,
                    IdaraId,
                    usersId,
                    HostName
                };

                DataSet ds = await _mastersServies
                    .GetDataLoadDataSetAsync(parameters);

                if (ds.Tables.Count < 12)
                    throw new InvalidOperationException(
                        "Dashboard metrics result is incomplete.");

                // تخزين المؤشرات فقط، دون جدول الصلاحيات.
                var metrics = new DataSet();

                for (int i = 1; i < ds.Tables.Count; i++)
                    metrics.Tables.Add(ds.Tables[i].Copy());

                string currentScopeKey = await GetDashboardScopeKeyAsync();

                if (!string.Equals(
                        scopeKey,
                        currentScopeKey,
                        StringComparison.Ordinal))
                {
                    throw new UnauthorizedAccessException(
                        "Dashboard scope changed during metrics loading.");
                }

                _memoryCache.Set(
                    cacheKey,
                    metrics,
                    TimeSpan.FromMinutes(5));

                return metrics.Copy();
            }
            finally
            {
                gate.Release();
            }
        }





        private async Task<DataSet> LoadAuthorizedDashboardAsync()
        {
            // التحقق من الصلاحية من SQL دون تشغيل حسابات المؤشرات.
            var permissionParameters = new Dictionary<string, object?>
            {
                ["pageName_"] = "HousingCommandCenterDashboard",
                ["idaraID"] = IdaraId,
                ["entrydata"] = usersId,
                ["hostname"] = HostName ?? "",
                ["parameter_20"] = "HEADER_PERMISSION_ONLY"
            };

            DataSet permissionDs = await _mastersServies
                .GetDataLoadDataSetAsync(permissionParameters);

            if (permissionDs.Tables.Count == 0)
                throw new UnauthorizedAccessException();

            DataTable permissions = permissionDs.Tables[0];

            bool permitted =
                permissions.Columns.Contains("permissionTypeName_E") &&
                permissions.Rows.Cast<DataRow>().Any(row =>
                    string.Equals(
                        row["permissionTypeName_E"]?.ToString()?.Trim(),
                        "VIEWDASHBOARD",
                        StringComparison.OrdinalIgnoreCase));

            if (!permitted)
                throw new UnauthorizedAccessException();

            // جداول المؤشرات فقط، إما من Cache أو من SQL.
            DataSet metrics = await LoadDashboardMetricsAsync();

            // إعادة تركيب DataSet بنفس ترتيب النظام الحالي.
            var result = new DataSet();

            result.Tables.Add(permissions.Copy());

            foreach (DataTable table in metrics.Tables)
                result.Tables.Add(table.Copy());

            return result;
        }


        private async Task<string> GetDashboardScopeKeyAsync()
        {
            var parameters = new Dictionary<string, object?>
            {
                ["pageName_"] = PageName,
                ["idaraID"] = IdaraId,
                ["entrydata"] = usersId,
                ["hostname"] = HostName ?? "",
                ["parameter_20"] = "DASHBOARD_SCOPE_ONLY"
            };

            DataSet ds = await _mastersServies
                .GetDataLoadDataSetAsync(parameters);

            // Table[0] = permissions, Table[1] = allowed departments.
            if (ds.Tables.Count < 2)
                throw new UnauthorizedAccessException(
                    "Dashboard scope data is unavailable.");

            DataTable scope = ds.Tables[1];

            if (!scope.Columns.Contains("idaraID") ||
                !scope.Columns.Contains("TrustedIdaraID") ||
                !scope.Columns.Contains("ShowFullDashboard"))
            {
                throw new UnauthorizedAccessException(
                    "Dashboard scope contract is invalid.");
            }

            if (scope.Rows.Count == 0)
                throw new UnauthorizedAccessException(
                    "No enabled departments are available.");

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

            return $"{trustedIdara}:{(showFull ? 1 : 0)}:{string.Join(",", ids)}";
        }


        private async Task<bool> CanAccessDashboardDepartmentAsync(
    long targetIdaraID)
        {
            if (targetIdaraID <= 0)
                return false;

            var parameters = new Dictionary<string, object?>
            {
                ["pageName_"] = PageName,
                ["idaraID"] = IdaraId,
                ["entrydata"] = usersId,
                ["hostname"] = HostName ?? "",
                ["parameter_20"] = "DASHBOARD_SCOPE_ONLY"
            };

            DataSet ds = await _mastersServies
                .GetDataLoadDataSetAsync(parameters);

            if (ds.Tables.Count < 2)
                return false;

            DataTable allowedDepartments = ds.Tables[1];

            if (!allowedDepartments.Columns.Contains("idaraID") ||
                !allowedDepartments.Columns.Contains("TrustedIdaraID") ||
                !allowedDepartments.Columns.Contains("ShowFullDashboard"))
            {
                return false;
            }

            return allowedDepartments.Rows
                .Cast<DataRow>()
                .Any(row =>
                    row["idaraID"] != DBNull.Value &&
                    Convert.ToInt64(row["idaraID"]) == targetIdaraID);
        }


    }
}
