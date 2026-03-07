using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Application.Services;
using SmartFoundation.UI.ViewModels.SmartForm;
using System.Data;
using System.Linq;

//  NEW (مطلوب للرفع )
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers
{
    [Route("crud")]
    public class CrudController : Controller
    {
        private readonly MastersServies _mastersServies;

        //  NEW (مطلوب للرفع )
        private readonly IWebHostEnvironment _env;

        public CrudController(MastersServies mastersCrudServies)
        {
            _mastersServies = mastersCrudServies;
        }


        [ActivatorUtilitiesConstructor]
        public CrudController(MastersServies mastersCrudServies, IWebHostEnvironment env)
        {
            _mastersServies = mastersCrudServies;
            _env = env;
        }


        private async Task ApplyDynamicFileUploadsAsync(Dictionary<string, object?> parameters)
        {
            if (_env == null) return;


            if (Request?.Form?.Files == null || Request.Form.Files.Count == 0) return;


            var groups = Request.Form.Files
                .GroupBy(f => f.Name, StringComparer.OrdinalIgnoreCase);

            foreach (var g in groups)
            {
                var fieldName = g.Key?.Trim();
                if (string.IsNullOrWhiteSpace(fieldName)) continue;


                if (fieldName.Length != 3 || (fieldName[0] != 'p' && fieldName[0] != 'P')) continue;
                if (!int.TryParse(fieldName.Substring(1, 2), out var idx) || idx < 1 || idx > 50) continue;

                //  مسار  يجي من الفورم  hidden)
                var folder = (Request.Form[$"{fieldName}__folder"].ToString() ?? "").Trim();
                var sub = (Request.Form[$"{fieldName}__subfolder"].ToString() ?? "").Trim();

                // fallback لو ما أرسلت مسارات
                if (string.IsNullOrWhiteSpace(folder)) folder = "uploads";
                if (string.IsNullOrWhiteSpace(sub)) sub = $"{parameters.GetValueOrDefault("pageName_") ?? "general"}/{fieldName}";

                //  القيود  من الفورم )
                int maxFiles = int.TryParse(Request.Form[$"{fieldName}__maxFiles"], out var mf) ? mf : 10;
                long maxFileSizeBytes = long.TryParse(Request.Form[$"{fieldName}__maxFileSizeMb"], out var mfs)
                    ? (mfs * 1024L * 1024L)
                    : (25L * 1024L * 1024L);
                long maxTotalBytes = long.TryParse(Request.Form[$"{fieldName}__maxTotalMb"], out var mt)
                    ? (mt * 1024L * 1024L)
                    : (100L * 1024L * 1024L);

                var files = g.ToList();
                if (files.Count > maxFiles)
                    throw new InvalidOperationException($"عدد الملفات تجاوز الحد المسموح ({fieldName})");

                long total = 0;
                foreach (var file in files)
                {
                    total += file?.Length ?? 0;

                    if (file == null || file.Length == 0)
                        throw new InvalidOperationException($"ملف فارغ غير مسموح ({fieldName})");

                    if (file.Length > maxFileSizeBytes)
                        throw new InvalidOperationException($"حجم الملف أكبر من المسموح ({fieldName})");


                    var parts = (file.FileName ?? "").Split('.', StringSplitOptions.RemoveEmptyEntries);
                    if (parts.Length >= 3)
                        throw new InvalidOperationException($"امتداد مزدوج غير مسموح ({fieldName})");
                }

                if (total > maxTotalBytes)
                    throw new InvalidOperationException($"إجمالي الملفات أكبر من المسموح ({fieldName})");

                //  حفظ  داخل wwwroot/{folder}/{sub}/
                var saveDir = Path.Combine(_env.WebRootPath, folder, sub);
                Directory.CreateDirectory(saveDir);

                var savedPaths = new List<string>();

                foreach (var file in files)
                {
                    var ext = Path.GetExtension(file.FileName ?? "").ToLowerInvariant();
                    var storedName = Guid.NewGuid().ToString("N") + ext;

                    var fullPath = Path.Combine(saveDir, storedName);
                    await using var fs = System.IO.File.Create(fullPath);
                    await file.CopyToAsync(fs);

                    savedPaths.Add($"/{folder}/{sub}/{storedName}".Replace("\\", "/"));
                }


                parameters[$"parameter_{idx:00}"] = savedPaths.Count > 0
                    ? JsonSerializer.Serialize(savedPaths)
                    : DBNull.Value;
            }
        }

        // REMOVE any TempData like: CrudMessageType, CrudMessage, InsertMessage, UpdateMessage, DeleteMessage, CrudError.
        // KEEP ONLY Toastr buckets: Success, Warning, Error (optional: Info).

        // 0=error, 1=success, 2=warning — read from any table/row
        private static (int? code, string? message) ExtractResult(DataSet ds)
        {
            int? code = null;
            string? message = null;
            if (ds == null) return (code, message);

            foreach (DataTable t in ds.Tables)
            {
                if (t.Rows.Count == 0) continue;

                var msgCol = t.Columns.Cast<DataColumn>().FirstOrDefault(c =>
                    c.ColumnName.Equals("Message_", StringComparison.OrdinalIgnoreCase) ||
                    c.ColumnName.Equals("Message", StringComparison.OrdinalIgnoreCase) ||
                    c.ColumnName.Equals("SuccessMessage", StringComparison.OrdinalIgnoreCase));

                var codeCol = t.Columns.Cast<DataColumn>().FirstOrDefault(c =>
                    c.ColumnName.Equals("IsSuccessful", StringComparison.OrdinalIgnoreCase) ||
                    c.ColumnName.Equals("Success", StringComparison.OrdinalIgnoreCase));

                foreach (DataRow r in t.Rows)
                {
                    if (msgCol != null && r[msgCol] != DBNull.Value && string.IsNullOrWhiteSpace(message))
                        message = r[msgCol]?.ToString();

                    if (!code.HasValue && codeCol != null && r[codeCol] != DBNull.Value)
                    {
                        var v = r[codeCol];
                        if (v is int i) code = i;
                        else if (v is bool b) code = b ? 1 : 0;
                        else if (int.TryParse(v.ToString(), out var parsed)) code = parsed;
                    }

                    if (code.HasValue && !string.IsNullOrWhiteSpace(message)) break;
                }

                if (code.HasValue || !string.IsNullOrWhiteSpace(message)) break;
            }

            return (code, message);
        }

        // NEW: only set Toastr buckets
        // Map 0=Error, 1=Success, 2=Warning, 3=Info
        private void SetToastTempData(int? code, string? message)
        {
            string bucket = code switch
            {
                0 => "Error",
                1 => "Success",
                2 => "Warning",
                3 => "Info",
                _ => "Info"
            };

            if (string.IsNullOrWhiteSpace(message))
            {
                message = code switch
                {
                    0 => "حدث خطأ أثناء التنفيذ.",
                    1 => "تم تنفيذ العملية بنجاح.",
                    2 => "تم التنفيذ مع تحذير.",
                    3 => "معلومة.",
                    _ => "تمت المعالجة."
                };
            }

            // keep only Toastr buckets
            TempData.Remove("Success");
            TempData.Remove("Warning");
            TempData.Remove("Error");
            TempData.Remove("Info");

            TempData[bucket] = message;
        }

        [HttpPost("insert")]
        public async Task<IActionResult> Insert()
        {
            try
            {
                var f = Request.Form;

                string pageName = f.TryGetValue("pageName_", out var pv) && !string.IsNullOrWhiteSpace(pv) ? pv.ToString() : "";
                string actionType = f.TryGetValue("ActionType", out var av) && !string.IsNullOrWhiteSpace(av) ? av.ToString() : "";
                int? idaraID = f.TryGetValue("idaraID", out var idv) && int.TryParse(idv, out var idParsed) ? idParsed : 0;
                int? entryData = f.TryGetValue("entrydata", out var edv) && int.TryParse(edv, out var entryParsed) ? entryParsed : 0;
                string hostName = f.TryGetValue("hostname", out var hv) && !string.IsNullOrWhiteSpace(hv) ? hv.ToString() : "";

                var parameters = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase)
                {
                    ["pageName_"] = pageName,
                    ["ActionType"] = actionType.ToUpperInvariant(),
                    ["idaraID"] = idaraID,
                    ["entrydata"] = entryData,
                    ["hostname"] = hostName
                };

                for (int idx = 1; idx <= 50; idx++)
                {
                    var key = $"p{idx:00}";
                    parameters[$"parameter_{idx:00}"] = f.TryGetValue(key, out var val) && !string.IsNullOrWhiteSpace(val)
                        ? val.ToString() : DBNull.Value;
                }

                //  NEW 
                await ApplyDynamicFileUploadsAsync(parameters);

                var ds = await _mastersServies.GetCrudDataSetAsync(parameters);
                var (code, message) = ExtractResult(ds);
                SetToastTempData(code, message);

                var redirectAction = f.TryGetValue("redirectAction", out var ra) ? ra.ToString() : null;
                var redirectController = f.TryGetValue("redirectController", out var rc) ? rc.ToString() : null;
                var redirectUrl = f.TryGetValue("redirectUrl", out var ru) ? ru.ToString() : null;

                if (!string.IsNullOrWhiteSpace(redirectUrl))
                {
                    return Redirect(redirectUrl);
                }
                else
                {
                    if (!string.IsNullOrWhiteSpace(redirectAction))
                    {
                        // 1) Base path using Url.Action (without query)
                        var baseUrl = Url.Action(redirectAction, redirectController) ?? "/";

                        // 2) Gather Q* keys and order them Q1, Q2, Q3...
                        var qPairs = new List<(int order, string key, string value)>();
                        foreach (var key in f.Keys)
                        {
                            if (string.IsNullOrWhiteSpace(key)) continue;
                            if (!key.StartsWith("Q", StringComparison.OrdinalIgnoreCase)) continue;

                            // Extract numeric suffix (default 0 if none)
                            int order = 0;
                            var suffix = key.Substring(1);
                            int.TryParse(suffix, out order);

                            var val = f[key].ToString();
                            if (!string.IsNullOrWhiteSpace(val))
                                qPairs.Add((order, key, val));
                        }

                        qPairs.Sort((a, b) => a.order.CompareTo(b.order)); // ensures Q1, Q2, Q3...

                        // 3) Build query string manually in desired order
                        var sb = new System.Text.StringBuilder();
                        for (int i = 0; i < qPairs.Count; i++)
                        {
                            var (order, key, value) = qPairs[i];
                            if (i > 0) sb.Append('&');
                            sb.Append(Uri.EscapeDataString(key));
                            sb.Append('=');
                            sb.Append(Uri.EscapeDataString(value));
                        }

                        var fullUrl = sb.Length > 0 ? $"{baseUrl}?{sb}" : baseUrl;
                        return Redirect(fullUrl);
                    }
                }

                var referer = Request.Headers["Referer"].ToString();
                if (!string.IsNullOrWhiteSpace(referer)) return Redirect(referer);
                return RedirectToAction("Index", "Home");
            }
            catch (Exception ex)
            {
                SetToastTempData(0, "Insert failed: " + ex.Message);
                var referer = Request.Headers["Referer"].ToString();
                if (!string.IsNullOrWhiteSpace(referer)) return Redirect(referer);
                return RedirectToAction("Index", "Home");
            }
        }

        [HttpPost("update")]
        public async Task<IActionResult> Update()
        {
            try
            {
                var f = Request.Form;

                string pageName = f.TryGetValue("pageName_", out var pv) && !string.IsNullOrWhiteSpace(pv) ? pv.ToString() : "";
                string actionType = f.TryGetValue("ActionType", out var av) && !string.IsNullOrWhiteSpace(av) ? av.ToString() : "UPDATE";
                int? idaraID = f.TryGetValue("idaraID", out var idv) && int.TryParse(idv, out var idParsed) ? idParsed : 1;
                int? entryData = f.TryGetValue("entrydata", out var edv) && int.TryParse(edv, out var entryParsed) ? entryParsed : 60014016;
                string hostName = f.TryGetValue("hostname", out var hv) && !string.IsNullOrWhiteSpace(hv) ? hv.ToString() : Request.Host.Value;

                var parameters = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase)
                {
                    ["pageName_"] = pageName,
                    ["ActionType"] = actionType.ToUpperInvariant(),
                    ["idaraID"] = idaraID,
                    ["entrydata"] = entryData,
                    ["hostname"] = hostName
                };

                for (int idx = 1; idx <= 50; idx++)
                {
                    var key = $"p{idx:00}";
                    parameters[$"parameter_{idx:00}"] = f.TryGetValue(key, out var val) && !string.IsNullOrWhiteSpace(val)
                        ? val.ToString() : DBNull.Value;
                }


                await ApplyDynamicFileUploadsAsync(parameters);

                var ds = await _mastersServies.GetCrudDataSetAsync(parameters);
                var (code, message) = ExtractResult(ds);
                SetToastTempData(code, message);

                var redirectAction = f.TryGetValue("redirectAction", out var ra) ? ra.ToString() : null;
                var redirectController = f.TryGetValue("redirectController", out var rc) ? rc.ToString() : null;
                var redirectUrl = f.TryGetValue("redirectUrl", out var ru) ? ru.ToString() : null;

                if (!string.IsNullOrWhiteSpace(redirectUrl))
                {
                    return Redirect(redirectUrl);
                }
                else
                {
                    var routeValues = new Dictionary<string, object>();
                    if (f.TryGetValue("Q1", out var q1) && !string.IsNullOrWhiteSpace(q1)) routeValues["Q1"] = q1.ToString();

                    if (!string.IsNullOrWhiteSpace(redirectAction))
                    {
                        return routeValues.Count > 0
                            ? RedirectToAction(redirectAction, redirectController, routeValues)
                            : RedirectToAction(redirectAction, redirectController);
                    }

                    var referer = Request.Headers["Referer"].ToString();
                    if (!string.IsNullOrWhiteSpace(referer)) return Redirect(referer);
                    return RedirectToAction("Index", "Home");
                }
            }
            catch (Exception ex)
            {
                SetToastTempData(0, "Update failed: " + ex.Message);
                var referer = Request.Headers["Referer"].ToString();
                if (!string.IsNullOrWhiteSpace(referer)) return Redirect(referer);
                return RedirectToAction("Index", "Home");
            }
        }

        [HttpPost("delete")]
        public async Task<IActionResult> Delete()
        {
            try
            {
                var f = Request.Form;

                string pageName = f.TryGetValue("pageName_", out var pv) && !string.IsNullOrWhiteSpace(pv) ? pv.ToString() : "BuildingType";
                string actionType = f.TryGetValue("ActionType", out var av) && !string.IsNullOrWhiteSpace(av) ? av.ToString() : "DELETE";
                int? idaraID = f.TryGetValue("idaraID", out var idv) && int.TryParse(idv, out var idParsed) ? idParsed : 1;
                int? entryData = f.TryGetValue("entrydata", out var edv) && int.TryParse(edv, out var entryParsed) ? entryParsed : 60014016;
                string hostName = f.TryGetValue("hostname", out var hv) && !string.IsNullOrWhiteSpace(hv) ? hv.ToString() : Request.Host.Value;

                var parameters = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase)
                {
                    ["pageName_"] = pageName,
                    ["ActionType"] = actionType.ToUpperInvariant(),
                    ["idaraID"] = idaraID,
                    ["entrydata"] = entryData,
                    ["hostname"] = hostName
                };

                for (int idx = 1; idx <= 50; idx++)
                {
                    var key = $"p{idx:00}";
                    parameters[$"parameter_{idx:00}"] = f.TryGetValue(key, out var val) && !string.IsNullOrWhiteSpace(val)
                        ? val.ToString() : DBNull.Value;
                }

                var ds = await _mastersServies.GetCrudDataSetAsync(parameters);
                var (code, message) = ExtractResult(ds);
                SetToastTempData(code, message);

                var redirectAction = f.TryGetValue("redirectAction", out var ra) ? ra.ToString() : null;
                var redirectController = f.TryGetValue("redirectController", out var rc) ? rc.ToString() : null;
                var redirectUrl = f.TryGetValue("redirectUrl", out var ru) ? ru.ToString() : null;

                if (!string.IsNullOrWhiteSpace(redirectUrl))
                {
                    return Redirect(redirectUrl);
                }
                else
                {
                    var routeValues = new Dictionary<string, object>();
                    if (f.TryGetValue("Q1", out var q1) && !string.IsNullOrWhiteSpace(q1)) routeValues["Q1"] = q1.ToString();

                    if (!string.IsNullOrWhiteSpace(redirectAction))
                    {
                        return routeValues.Count > 0
                            ? RedirectToAction(redirectAction, redirectController, routeValues)
                            : RedirectToAction(redirectAction, redirectController);
                    }

                    var referer = Request.Headers["Referer"].ToString();
                    if (!string.IsNullOrWhiteSpace(referer)) return Redirect(referer);
                    return RedirectToAction("Index", "Home");
                }
            }
            catch (Exception ex)
            {
                SetToastTempData(0, "Delete failed: " + ex.Message);
                var referer = Request.Headers["Referer"].ToString();
                if (!string.IsNullOrWhiteSpace(referer)) return Redirect(referer);
                return RedirectToAction("Index", "Home");
            }
        }

        [HttpGet("DDLFiltered")]
        public async Task<IActionResult> DDLFiltered(
            string? DDlValues, string? FK, string? textcol, string? ValueCol, string? TableIndex, string? PageName)
        {
            int tableIndexInt = 0;
            if (!string.IsNullOrWhiteSpace(TableIndex))
                int.TryParse(TableIndex, out tableIndexInt);

            var usersIdStr = HttpContext.Session.GetString("usersID");
            var idaraIdStr = HttpContext.Session.GetString("IdaraID");
            var hostName = HttpContext.Session.GetString("HostName") ?? string.Empty;

            if (string.IsNullOrWhiteSpace(usersIdStr) || string.IsNullOrWhiteSpace(idaraIdStr))
                return Unauthorized();

            int userID = Convert.ToInt32(usersIdStr);
            int IdaraID = Convert.ToInt32(idaraIdStr);


            if (!int.TryParse(DDlValues, out int ddlValueId) || ddlValueId == -1)
                return Json(new List<object> { new { value = "-99999", text = "الرجاء الاختيار" } });

            

            var ds = await _mastersServies.GetDataLoadDataSetAsync(PageName, IdaraID, userID, hostName);
            var table = (ds?.Tables?.Count ?? 0) > tableIndexInt ? ds.Tables[tableIndexInt] : null;

            if (ds == null)
                return Json(new { error = "ds is null" });

            if ((ds.Tables?.Count ?? 0) <= tableIndexInt)
                return Json(new { error = "TableIndex خارج النطاق", tableIndexInt, TablesCount = ds.Tables.Count });

            if (table == null)
                return Json(new { error = "table is null", tableIndexInt, TablesCount = ds.Tables.Count });

            if (string.IsNullOrWhiteSpace(FK) || !table.Columns.Contains(FK))
                return Json(new { error = "FK غير موجود", FK, cols = table.Columns.Cast<DataColumn>().Select(c => c.ColumnName).ToList() });

            if (string.IsNullOrWhiteSpace(ValueCol) || !table.Columns.Contains(ValueCol))
                return Json(new { error = "ValueCol غير موجود", ValueCol, cols = table.Columns.Cast<DataColumn>().Select(c => c.ColumnName).ToList() });

            if (string.IsNullOrWhiteSpace(textcol) || !table.Columns.Contains(textcol))
                return Json(new { error = "textcol غير موجود", textcol, cols = table.Columns.Cast<DataColumn>().Select(c => c.ColumnName).ToList() });

            var items = new List<object>();

            if (table is not null && table.Rows.Count > 0 && table.Columns.Contains(FK))
            {

                items.Add(new { value = "-99999", text = "الرجاء الاختيار" });
                foreach (DataRow row in table.Rows)
                {
                    var fk = row[FK]?.ToString()?.Trim();
                    if (fk == ddlValueId.ToString())
                    {
                        var value = row[ValueCol]?.ToString()?.Trim() ?? "";
                        var text = row[textcol]?.ToString()?.Trim() ?? "";
                        if (!string.IsNullOrEmpty(value))
                            items.Add(new { value, text });
                    }
                }
            }

            if (!items.Any())
                items.Add(new { value = "-1", text = "لاتوجد خيارات" });

            return Json(items);
        }



        [HttpGet("GetDDLValues")]
        public async Task<IActionResult> GetDDLValues(
            string? textcol,
            string? ValueCol,
            string? TableIndex,
            string? PageName,
            string? usersId,
            string? IdaraId,
            string? HostName,
            string? FilterColumn = null,
            string? FilterValue = null,
             string? FirstOption = null)
        {
            int TableIndexInt = 0;
            if (!string.IsNullOrWhiteSpace(TableIndex))
                int.TryParse(TableIndex, out TableIndexInt);

            var ds = await _mastersServies.GetDataLoadDataSetAsync(PageName, IdaraId, usersId, HostName);
            var table = (ds?.Tables?.Count ?? 0) > TableIndexInt ? ds.Tables[TableIndexInt] : null;

            var items = new List<object>();
            if (table is not null && table.Rows.Count > 0)
            {
                if (!string.IsNullOrEmpty(FirstOption))
                {
                    items.Add(new { Value = "-1", Text = FirstOption });
                }

                // Check if filtering is needed
                bool shouldFilter = !string.IsNullOrWhiteSpace(FilterColumn)
                                 && !string.IsNullOrWhiteSpace(FilterValue)
                                 && table.Columns.Contains(FilterColumn);

                foreach (DataRow row in table.Rows)
                {
                    // Apply filter if specified
                    if (shouldFilter)
                    {
                        var filterColumnValue = row[FilterColumn]?.ToString()?.Trim() ?? "";
                        if (filterColumnValue != FilterValue?.Trim())
                            continue; // Skip this row if it doesn't match the filter
                    }

                    var value = row[ValueCol]?.ToString()?.Trim() ?? "";
                    var text = row[textcol]?.ToString()?.Trim() ?? "";

                    if (!string.IsNullOrEmpty(value))

                        items.Add(new { Value = value, Text = text });
                }
            }

            if (!items.Any())
                items.Add(new { Value = "-1", Text = "لاتوجد خيارات" });

            return Json(items);
        }



        public sealed class DdlValuesRequest
        {
            public string? TextCol { get; set; }
            public string? ValueCol { get; set; }
            public int TableIndex { get; set; }

            public string? PageName { get; set; }
            public string? UsersId { get; set; }
            public string? IdaraId { get; set; }
            public string? HostName { get; set; }

            // ✅ أهم شيء: باراميترات متعددة
            public Dictionary<string, object?>? Parameters { get; set; }

            public string? FirstOption { get; set; }
        }

        [HttpPost("GetDDLValues2")]
        public async Task<IActionResult> GetDDLValues2([FromBody] DdlValuesRequest req)
        {
            // حمايات بسيطة
            var textcol = (req.TextCol ?? "").Trim();
            var valueCol = (req.ValueCol ?? "").Trim();

            if (string.IsNullOrWhiteSpace(textcol) || string.IsNullOrWhiteSpace(valueCol))
                return Json(new[] { new { Value = "-1", Text = "مدخلات غير صحيحة" } });

            // ✅ هنا نحتاج DataSet حسب PageName ولكن مع Parameters
            // لازم نمرر parameters للـ SP / DataEngine بدل تجاهلها
            var ds = await _mastersServies.GetDataLoadDataSetAsync(
                req.PageName, req.IdaraId, req.UsersId, req.HostName,
                req.Parameters // ✅ جديد
            );

            var idx = req.TableIndex;
            var table = (ds?.Tables?.Count ?? 0) > idx ? ds!.Tables[idx] : null;

            var items = new List<object>();

            if (!string.IsNullOrWhiteSpace(req.FirstOption))
                items.Add(new { Value = "-1", Text = req.FirstOption });

            if (table is not null && table.Rows.Count > 0)
            {
                foreach (DataRow row in table.Rows)
                {
                    var value = row[valueCol]?.ToString()?.Trim() ?? "";
                    var text = row[textcol]?.ToString()?.Trim() ?? "";

                    if (!string.IsNullOrEmpty(value))
                        items.Add(new { Value = value, Text = text });
                }
            }

            if (!items.Any())
                items.Add(new { Value = "-1", Text = "لاتوجد خيارات" });

            return Json(items);
        }


        public sealed class ExtraDataLoadRequest
        {
            public string? pageName_ { get; set; }
            public string? ActionType { get; set; }
            public int? idaraID { get; set; }
            public int? entrydata { get; set; }
            public string? hostname { get; set; }

            // اختياري: لو تبي جدول واحد فقط
            public int? tableIndex { get; set; }

            // parameter_01..10 أو p01..p10
            public Dictionary<string, object?>? parameters { get; set; }
        }

        
        [HttpPost("extradataload")]
        public async Task<IActionResult> ExtraDataLoad([FromBody] ExtraDataLoadRequest req)
        {
            if (string.IsNullOrWhiteSpace(req.pageName_) || string.IsNullOrWhiteSpace(req.ActionType))
                return Json(new { success = false, message = "pageName_ و ActionType مطلوبة." });

            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase)
            {
                ["pageName_"] = req.pageName_!.Trim(),
                ["ActionType"] = req.ActionType!.Trim(),
                ["idaraID"] = req.idaraID,
                ["entrydata"] = req.entrydata,
                ["hostname"] = req.hostname
            };

            // parameter_01..10 (يدعم p01..p10 أيضاً)
            if (req.parameters is not null)
            {
                for (int i = 1; i <= 10; i++)
                {
                    object? v = null;
                    if (req.parameters.TryGetValue($"parameter_{i:00}", out var vv1)) v = vv1;
                    else if (req.parameters.TryGetValue($"p{i:00}", out var vv2)) v = vv2;

                    if (v is null) continue;
                    dict[$"parameter_{i:00}"] = v;
                }
            }

            DataSet ds;
            try
            {
                ds = await _mastersServies.GetExtraDataLoadDataSetAsync(dict);
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }

            // ✅ لو المستخدم طلب جدول محدد فقط
            if (req.tableIndex.HasValue)
            {
                var ti = req.tableIndex.Value;
                if (ti < 0 || ti >= ds.Tables.Count)
                    return Json(new { success = false, message = $"tableIndex خارج النطاق. المتاح 0..{ds.Tables.Count - 1}" });

                return Json(new
                {
                    success = true,
                    table = ToTableDto(ds.Tables[ti], ti)
                });
            }

            // ✅ رجّع كل الجداول
            var tables = new List<object>();
            for (int ti = 0; ti < ds.Tables.Count; ti++)
                tables.Add(ToTableDto(ds.Tables[ti], ti));

            // (اختياري) إذا تحب “data” يكون أول جدول لتوافق سريع
            var data = ds.Tables.Count > 0 ? ToRows(ds.Tables[0]) : new List<Dictionary<string, object?>>();

            return Json(new { success = true, data, tables });

            // ---------------- local helpers ----------------
            static object ToTableDto(DataTable t, int index) => new
            {
                index,
                name = string.IsNullOrWhiteSpace(t.TableName) ? $"Table{index}" : t.TableName,
                columns = t.Columns.Cast<DataColumn>().Select(c => new { name = c.ColumnName, type = c.DataType.Name }).ToList(),
                rows = ToRows(t)
            };

            static List<Dictionary<string, object?>> ToRows(DataTable t)
            {
                var rows = new List<Dictionary<string, object?>>(t.Rows.Count);
                foreach (DataRow r in t.Rows)
                {
                    var d = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                    foreach (DataColumn c in t.Columns)
                        d[c.ColumnName] = r[c] == DBNull.Value ? null : r[c];
                    rows.Add(d);
                }
                return rows;
            }
        }


        public sealed class RenderFormRequest
        {
            public FormConfig? form { get; set; }
            public Dictionary<string, object?>? row { get; set; }
        }

        [HttpPost("renderform")]
        public IActionResult RenderForm([FromBody] RenderFormRequest req)
        {
            if (req.form == null) return Content("", "text/html");

            // بدّل $row.xxx داخل Values
            void ReplaceTokens(FieldConfig f)
            {
                if (!string.IsNullOrWhiteSpace(f.Value) && f.Value.StartsWith("$row.", StringComparison.OrdinalIgnoreCase))
                {
                    var key = f.Value.Substring(5);
                    if (req.row != null && req.row.TryGetValue(key, out var v))
                        f.Value = v?.ToString() ?? "";
                    else
                        f.Value = "";
                }
            }

            if (req.form.Fields != null)
                foreach (var fld in req.form.Fields) ReplaceTokens(fld);

            // يرندر الـ SmartForm الرسمي
            return ViewComponent("SmartForm", new { model = req.form });
        }
    }
}
