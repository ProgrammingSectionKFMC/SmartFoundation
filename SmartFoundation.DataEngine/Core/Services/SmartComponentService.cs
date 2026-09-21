// خدمة تنفيذ عام عبر Dapper مع أمان + Logging + Validation
using Dapper;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using SmartFoundation.DataEngine.Core.Interfaces;
using SmartFoundation.DataEngine.Core.Models;
using SmartFoundation.DataEngine.Core.Utilities;
using System.Data;
using System.Diagnostics;
using System.Linq;
using System.Text.Json;

namespace SmartFoundation.DataEngine.Core.Services
{
    public class SmartComponentService : ISmartComponentService
    {
        private readonly ConnectionFactory _factory;
        private readonly IConfiguration _config;
        private readonly ILogger<SmartComponentService> _logger;

        public SmartComponentService(ConnectionFactory factory, IConfiguration config, ILogger<SmartComponentService> logger)
        {
            _factory = factory;
            _config = config;
            _logger = logger;
        }

        public async Task<SmartResponse> ExecuteAsync(SmartRequest request, CancellationToken ct = default)
        {
            var sw = Stopwatch.StartNew();

            var resp = new SmartResponse
            {
                Page = request.Paging?.Page ?? 1,
                Size = request.Paging?.Size ?? 10
            };

            try
            {
                if (string.IsNullOrWhiteSpace(request.SpName))
                    throw new ArgumentException("لايوجد بيانات");

                // القائمة البيضاء
                var whitelist = _config.GetSection("SmartData:Whitelist").Get<string[]>() ?? [];
                if (whitelist.Length > 0 && !whitelist.Contains(request.SpName, StringComparer.OrdinalIgnoreCase))
                {
                    _logger.LogWarning("محاولة استدعاء SP غير مسموح: {SpName}", request.SpName);
                    throw new UnauthorizedAccessException($"Stored Procedure '{request.SpName}' is not allowed.");
                }

                var maxSize = _config.GetValue<int?>("SmartData:MaxPageSize") ?? 100;
                if (resp.Size > maxSize) resp.Size = maxSize;

                using var conn = _factory.Create();
                await conn.OpenAsync(ct);

                var dp = new DynamicParameters();

                // Only add paging, sorting and filtering for select operations
                if (request.Operation?.ToLower() == "select")
                {
                    dp.Add("@Operation", "select");
                    dp.Add("@Page", resp.Page);
                    dp.Add("@Size", resp.Size);

                    if (!string.IsNullOrWhiteSpace(request.Sort?.Field))
                    {
                        dp.Add("@SortField", request.Sort!.Field);
                        dp.Add("@SortDir", request.Sort!.Dir ?? "asc");
                    }

                    // الفلاتر (JSON)
                    if (request.Filters is { Count: > 0 })
                    {
                        foreach (var f in request.Filters)
                            if (string.IsNullOrWhiteSpace(f.Field))
                                throw new ArgumentException("Filter field name is required.");

                        var filtersJson = JsonSerializer.Serialize(request.Filters);
                        dp.Add("@FiltersJson", filtersJson);
                    }
                }

                // الباراميترات
                if (request.Params is not null)
                {
                    foreach (var kv in request.Params)
                    {
                        if (string.IsNullOrWhiteSpace(kv.Key))
                            throw new ArgumentException("Parameter key is required.");

                        object? val = kv.Value;

                        if (val is JsonElement je)
                        {
                            val = je.ValueKind switch
                            {
                                JsonValueKind.String => je.GetString(),
                                JsonValueKind.Number => je.TryGetInt64(out var l) ? l : je.GetDouble(),
                                JsonValueKind.True => true,
                                JsonValueKind.False => false,
                                JsonValueKind.Null => null,
                                _ => je.ToString()
                            };
                        }

                        if (val is bool b) val = b ? 1 : 0;
                        if (val is string s && string.IsNullOrWhiteSpace(s)) val = null;

                        dp.Add("@" + kv.Key, val ?? DBNull.Value);
                    }
                }

                // Multiple Result Sets
                // Multiple Result Sets
                // تنفيذ البروسيجر مرة واحدة فقط وقراءة جميع النتائج
                using var grid = await conn.QueryMultipleAsync(
                    new CommandDefinition(
                        request.SpName,
                        dp,
                        commandType: CommandType.StoredProcedure,
                        cancellationToken: ct));

                var datasets = new List<List<Dictionary<string, object?>>>();

                while (!grid.IsConsumed)
                {
                    var rows = await grid.ReadAsync();
                    var list = new List<Dictionary<string, object?>>();

                    foreach (var row in rows)
                    {
                        var dict = (IDictionary<string, object?>)row;

                        list.Add(
                            dict.ToDictionary(
                                kv => kv.Key,
                                kv => kv.Value));
                    }

                    // نضيف الجدول حتى لو كان فارغًا للمحافظة على ترتيب DataSet
                    datasets.Add(list);
                }

                resp.Datasets = datasets;

                resp.Data = datasets.FirstOrDefault()
                    ?? new List<Dictionary<string, object?>>();

                resp.Total = resp.Data.Count;

                // قراءة الرسالة من أول مجموعة إن وجدت
                var firstSet = datasets.FirstOrDefault();

                if (firstSet?.Count > 0)
                {
                    var msgKey = firstSet[0].Keys.FirstOrDefault(
                        key => key.Equals(
                            "Message",
                            StringComparison.OrdinalIgnoreCase));

                    if (msgKey != null && firstSet[0][msgKey] != null)
                    {
                        resp.Message = firstSet[0][msgKey]?.ToString();
                    }
                }

                // استخراج Total وMessage من آخر مجموعة إذا كانت ملخصًا
                var lastSet = datasets.LastOrDefault();

                if (lastSet?.Count == 1)
                {
                    var lastRow = lastSet[0];

                    if (lastRow.TryGetValue("Total", out var totalValue) ||
                        lastRow.TryGetValue("total", out totalValue))
                    {
                        resp.Total = Convert.ToInt32(totalValue ?? 0);
                    }

                    var msgKey = lastRow.Keys.FirstOrDefault(
                        key => key.Equals(
                            "Message",
                            StringComparison.OrdinalIgnoreCase));

                    if (msgKey != null && lastRow[msgKey] != null)
                    {
                        resp.Message = lastRow[msgKey]?.ToString();
                    }
                }

                // تتبّع عدّ المجموعات لإثبات التحميل الصحيح
                _logger.LogInformation("SETS={Count}", resp.Datasets?.Count ?? -1);
                resp.Message = resp.Message is not null && resp.Message.Length > 0
                    ? $"{resp.Message} | SETS={(resp.Datasets?.Count ?? 0)}"
                    : $"SETS={(resp.Datasets?.Count ?? 0)}";

                resp.Success = true;
                _logger.LogInformation("تم تنفيذ {SpName} في {Duration}ms مع {Count} سجل",
                    request.SpName, sw.ElapsedMilliseconds, resp.Total);
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "فشل تنفيذ الإجراء المخزن {SpName}. DurationMs={DurationMs}",
                    request.SpName,
                    sw.ElapsedMilliseconds
                );

                // لا نخفي الاستثناء الأصلي؛ تحتاجه طبقة الأخطاء المركزية
                // لتسجيل سبب SQL الحقيقي في dbo.ErrorLog.
                throw;
            }
            finally
            {
                sw.Stop();
                resp.DurationMs = sw.ElapsedMilliseconds;
            }

            return resp;
        }
    }
}
