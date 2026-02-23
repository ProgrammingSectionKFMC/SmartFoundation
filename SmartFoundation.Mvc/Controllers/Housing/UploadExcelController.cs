using ExcelDataReader;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers.Housing
{
    /*
     * NuGet:
     *  - ExcelDataReader
     *  - ExcelDataReader.DataSet
     *  - Microsoft.Data.SqlClient
     *
     * IMPORTANT (Program.cs) - مرة واحدة فقط:
     *  System.Text.Encoding.RegisterProvider(System.Text.CodePagesEncodingProvider.Instance);
     */

    public class UploadExcelController : Controller
    {
        private readonly IWebHostEnvironment _env;
        private readonly IAntiforgery _antiforgery;
        private readonly IConfiguration _cfg;

        public UploadExcelController(IWebHostEnvironment env, IAntiforgery antiforgery, IConfiguration cfg)
        {
            _env = env;
            _antiforgery = antiforgery;
            _cfg = cfg;
        }

        // ===============================
        // Session Keys
        // ===============================
        private const string SessionKeyExcelPreview = "UploadExcel.Preview";
        private const string SessionKeyExcelColumns = "UploadExcel.Columns";
        private const string SessionKeyExcelFilePath = "UploadExcel.FilePath";
        private const string SessionKeyExcelRelative = "UploadExcel.Relative";
        private const string SessionKeyExcelFileName = "UploadExcel.OriginalFileName";
        private const string SessionKeyExcelUploadedAt = "UploadExcel.UploadedAt";

        // ===============================
        // Session helpers
        // ===============================
        private List<Dictionary<string, object?>> GetPreviewRows()
        {
            var json = HttpContext.Session.GetString(SessionKeyExcelPreview);
            if (string.IsNullOrWhiteSpace(json)) return new List<Dictionary<string, object?>>();
            return JsonSerializer.Deserialize<List<Dictionary<string, object?>>>(json)
                   ?? new List<Dictionary<string, object?>>();
        }

        private void SavePreviewRows(List<Dictionary<string, object?>> rows)
            => HttpContext.Session.SetString(SessionKeyExcelPreview, JsonSerializer.Serialize(rows));

        private List<string> GetPreviewColumns()
        {
            var json = HttpContext.Session.GetString(SessionKeyExcelColumns);
            if (string.IsNullOrWhiteSpace(json)) return new List<string>();
            return JsonSerializer.Deserialize<List<string>>(json) ?? new List<string>();
        }

        private void SavePreviewColumns(List<string> cols)
            => HttpContext.Session.SetString(SessionKeyExcelColumns, JsonSerializer.Serialize(cols));

        private void SaveExcelFileInfo(string fullPath, string relative, string originalFileName)
        {
            HttpContext.Session.SetString(SessionKeyExcelFilePath, fullPath);
            HttpContext.Session.SetString(SessionKeyExcelRelative, relative);
            HttpContext.Session.SetString(SessionKeyExcelFileName, originalFileName ?? "");
            HttpContext.Session.SetString(SessionKeyExcelUploadedAt, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
        }

        private string? GetExcelFilePath() => HttpContext.Session.GetString(SessionKeyExcelFilePath);
        private string? GetExcelOriginalFileName() => HttpContext.Session.GetString(SessionKeyExcelFileName);
        private string? GetExcelUploadedAt() => HttpContext.Session.GetString(SessionKeyExcelUploadedAt);

        // ===============================
        // Request type
        // ===============================
        private bool IsAjaxRequest()
        {
            var xrw = Request.Headers["X-Requested-With"].ToString();
            if (!string.IsNullOrWhiteSpace(xrw) && xrw.Equals("XMLHttpRequest", StringComparison.OrdinalIgnoreCase))
                return true;

            var accept = Request.Headers["Accept"].ToString();
            if (!string.IsNullOrWhiteSpace(accept) && accept.Contains("application/json", StringComparison.OrdinalIgnoreCase))
                return true;

            return false;
        }

        // ===============================
        // Unified Toastr responder:
        // - Ajax => JSON
        // - Normal form submit => Redirect(Index) + TempData
        // ===============================
        private IActionResult RespondSuccess(string msg, object? data = null)
        {
            TempData["Success"] = msg;
            if (IsAjaxRequest())
                return Ok(new { ok = true, message = msg, data });

            return RedirectToAction(nameof(Index));
        }

        private IActionResult RespondWarning(string msg, object? data = null)
        {
            TempData["Warning"] = msg;
            if (IsAjaxRequest())
                return Ok(new { ok = false, message = msg, data });

            return RedirectToAction(nameof(Index));
        }

        private IActionResult RespondError(string msg, object? data = null)
        {
            TempData["Error"] = msg;
            if (IsAjaxRequest())
                return Ok(new { ok = false, message = msg, data });

            return RedirectToAction(nameof(Index));
        }

        // ===============================
        // GET: الصفحة
        // ===============================
        [HttpGet]
        public IActionResult Index()
        {
            var previewCols = GetPreviewColumns();
            var previewRows = GetPreviewRows();

            var options = previewCols
                .Select(c => new OptionItem { Value = c, Text = c })
                .ToList();

            if (!previewCols.Any())
            {
                options = new List<OptionItem>
                {
                    new OptionItem { Value = "", Text = "لا يوجد أعمدة — ارفع ملف أولاً" }
                };
            }

            var columns = new List<TableColumn>();
            if (previewCols.Count > 0)
            {
                foreach (var c in previewCols)
                {
                    columns.Add(new TableColumn
                    {
                        Field = c,
                        Label = c,
                        Type = "text",
                        Sortable = true,
                        Visible = true,
                        truncate = true
                    });
                }
            }
            else
            {
                columns.Add(new TableColumn
                {
                    Field = "Info",
                    Label = "المعاينة",
                    Type = "text",
                    Sortable = false,
                    Visible = true,
                    truncate = true
                });

                previewRows = new List<Dictionary<string, object?>>
                {
                    new Dictionary<string, object?> { ["Info"] = "ارفع ملف Excel لعرض البيانات هنا." }
                };
            }

            var tokens = _antiforgery.GetAndStoreTokens(HttpContext);

            var uploadFields = new List<FieldConfig>
            {
                new FieldConfig { Name="__RequestVerificationToken", Type="hidden", Value=tokens.RequestToken ?? "" },
                new FieldConfig
                {
                    Name = "attachments",
                    Label = "ارفع ملف Excel",
                    Type = "fileupload",
                    ColCss = "6",
                    Accept = ".xls,.xlsx",
                    AllowedMimeTypes = new List<string>
                    {
                        "application/vnd.ms-excel",
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                    },
                    ErrorMessageType = "يجب رفع ملف Excel فقط (.xls أو .xlsx).",
                    ErrorMessageSize = "حجم الملف أكبر من 10MB.",
                    ErrorMessageCount = "يسمح برفع ملف واحد فقط.",
                    ErrorMessageTotal = "إجمالي الحجم أكبر من 10MB.",
                    Multiple = false,
                    MaxFiles = 1,
                    MaxFileSize = 10,
                    MaxTotalSize = 10,
                    AllowEmptyFile = false,
                    Required = true,
                    EnablePreview = false,
                    SaveMode = "physical",
                    UploadFolder = "uploads",
                    UploadSubFolder = "excel",
                    FileNameMode = "uuid",
                    KeepOriginalExtension = true,
                    SanitizeFileName = true,
                    BlockDoubleExtension = true,
                    AutoUpload = false
                }
            };

            var processFields = new List<FieldConfig>
            {
                new FieldConfig { Name="__RequestVerificationToken", Type="hidden", Value=tokens.RequestToken ?? "" },
                new FieldConfig { Name="p14", Label="اختر العمود الأول",  Type="select", ColCss="4", Options=options },
                new FieldConfig { Name="p15", Label="اختر العمود الثاني", Type="select", ColCss="4", Options=options },
                new FieldConfig { Name="p03", Label="اختر العمود الثالث", Type="select", ColCss="4", Options=options },
            };

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "رفع ملف Excel",
                PanelTitle = "رفع ملف Excel",
                Columns = columns,
                Rows = previewRows,
                RowIdField = null,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50 },
                Searchable = true,
                ShowFilter = false,
                FilterRow = true,
                ShowColumnVisibility = true,
                Toolbar = new TableToolbarConfig
                {
                    ShowAdd = true,
                    ShowAdd1 = true,
                    ShowEdit = false,
                    ShowDelete = false,
                    ShowExportExcel = true,
                    ShowExportPdf = false,
                    ShowColumns = true,
                    ShowRefresh = true,

                    Add = new TableAction
                    {
                        Label = "رفع Excel",
                        Icon = "fa-solid fa-file-excel",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "رفع ملف Excel",
                        OpenForm = new FormConfig
                        {
                            FormId = "UploadExcelForm",
                            Method = "post",
                            Enctype = "multipart/form-data",
                            ActionUrl = Url.Action(nameof(Upload), "UploadExcel")!,
                            Fields = uploadFields
                        }
                    },

                    Add1 = new TableAction
                    {
                        Label = "معالجة الملف واعتماده",
                        Icon = "fa-solid fa-check",
                        Color = "primary",
                        OpenModal = true,
                        ModalTitle = "معالجة الملف واعتماده",
                        OpenForm = new FormConfig
                        {
                            FormId = "ProcessExcelForm",
                            Method = "post",
                            Enctype = "application/x-www-form-urlencoded",
                            ActionUrl = Url.Action(nameof(Process), "UploadExcel")!,
                            Fields = processFields
                        }
                    },
                }
            };

            return View("Index", new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-solid fa-file-excel",
                TableDS = dsModel
            });
        }

        // ===============================
        // POST: Upload Excel + Preview
        // ===============================
        [HttpPost]
        [ValidateAntiForgeryToken]
        [RequestSizeLimit(20 * 1024 * 1024)]
        [RequestFormLimits(MultipartBodyLengthLimit = 20 * 1024 * 1024)]
        public async Task<IActionResult> Upload()
        {
            try
            {
                var file =
                    Request.Form.Files.GetFile("attachments")
                    ?? Request.Form.Files.GetFile("attachments[]")
                    ?? Request.Form.Files.FirstOrDefault();

                if (file == null || file.Length == 0)
                    return RespondError("لم يتم اختيار ملف.");

                var ext = (Path.GetExtension(file.FileName ?? "") ?? "").ToLowerInvariant();
                var allowedExt = new HashSet<string> { ".xls", ".xlsx" };
                if (!allowedExt.Contains(ext))
                    return RespondError("يجب رفع ملف Excel فقط (.xls أو .xlsx).");

                var allowedMime = new HashSet<string>
                {
                    "application/vnd.ms-excel",
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                };
                if (!allowedMime.Contains(file.ContentType ?? ""))
                    return RespondError("نوع الملف غير صحيح.");

                const long maxBytes = 10L * 1024L * 1024L;
                if (file.Length > maxBytes)
                    return RespondError("حجم الملف أكبر من 10MB.");

                var saveDir = Path.Combine(_env.WebRootPath, "uploads", "excel");
                Directory.CreateDirectory(saveDir);

                var storedName = Guid.NewGuid().ToString("N") + ext;
                var fullPath = Path.Combine(saveDir, storedName);

                await using (var fs = System.IO.File.Create(fullPath))
                {
                    await file.CopyToAsync(fs);
                }

                var relative = $"/uploads/excel/{storedName}";
                SaveExcelFileInfo(fullPath, relative, file.FileName ?? storedName);

                DataTable dt = ReadExcelToDataTable(fullPath, useHeaderRow: true, sheetIndex: 0);

                var cols = dt.Columns.Cast<DataColumn>()
                    .Select(c => string.IsNullOrWhiteSpace(c.ColumnName) ? $"Column{c.Ordinal + 1}" : c.ColumnName.Trim())
                    .ToList();

                for (int i = 0; i < dt.Columns.Count; i++)
                {
                    if (string.IsNullOrWhiteSpace(dt.Columns[i].ColumnName))
                        dt.Columns[i].ColumnName = cols[i];
                }

                var preview = DataTableToPreview(dt, maxRows: 200);

                SavePreviewColumns(cols);
                SavePreviewRows(preview);

                return RespondSuccess($"تم رفع ملف الإكسل وقراءة البيانات بنجاح. عدد الصفوف: {dt.Rows.Count}", new
                {
                    relative,
                    rowsCount = dt.Rows.Count,
                    colsCount = dt.Columns.Count,
                    previewCount = preview.Count,
                    refresh = true
                });
            }
            catch (Exception ex)
            {
                return RespondError("فشل رفع/قراءة ملف الإكسل: " + ex.Message);
            }
        }

        // ===============================
        // POST: Process -> DB
        // ===============================
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Process(string? p14, string? p15, string? p03)
        {
            try
            {
                var path = GetExcelFilePath();
                if (string.IsNullOrWhiteSpace(path) || !System.IO.File.Exists(path))
                {
                    var at = GetExcelUploadedAt();
                    var extra = string.IsNullOrWhiteSpace(at) ? "" : $" (آخر رفع: {at})";
                    return RespondError("لا يوجد ملف Excel محفوظ للمعالجة. ارفع الملف أولاً." + extra);
                }

                p14 = (p14 ?? "").Trim();
                p15 = (p15 ?? "").Trim();
                p03 = (p03 ?? "").Trim();

                if (string.IsNullOrWhiteSpace(p14) || string.IsNullOrWhiteSpace(p15) || string.IsNullOrWhiteSpace(p03))
                    return RespondError("الرجاء اختيار جميع الأعمدة المطلوبة.");

                if (p14.Equals(p15, StringComparison.OrdinalIgnoreCase)
                    || p14.Equals(p03, StringComparison.OrdinalIgnoreCase)
                    || p15.Equals(p03, StringComparison.OrdinalIgnoreCase))
                    return RespondError("تم اختيار نفس العمود أكثر من مرة. الرجاء اختيار أعمدة مختلفة لكل قائمة.");

                DataTable dt = ReadExcelToDataTable(path, useHeaderRow: true, sheetIndex: 0);

                var colSet = new HashSet<string>(
                    dt.Columns.Cast<DataColumn>().Select(c => c.ColumnName),
                    StringComparer.OrdinalIgnoreCase);

                if (!colSet.Contains(p14) || !colSet.Contains(p15) || !colSet.Contains(p03))
                    return RespondError("أحد الأعمدة المختارة غير موجود في ملف الإكسل.");

                // ✅ فراغات الأعمدة المختارة => رفض مع توضيح الصفوف
                var emptyReport = FindEmptyCells(dt, new[] { p14, p15, p03 }, maxShowRows: 15);
                if (emptyReport.Count > 0)
                {
                    var sb = new StringBuilder();
                    foreach (var kv in emptyReport)
                        sb.Append($"العمود ({kv.Key}) يحتوي على قيم فارغة في الصفوف: {string.Join(", ", kv.Value)}. ");
                    return RespondError(sb.ToString().Trim());
                }

                // TVP
                var tvp = new DataTable();
                tvp.Columns.Add("RowNo", typeof(int));
                tvp.Columns.Add("UploadExcel1", typeof(string));
                tvp.Columns.Add("UploadExcel2", typeof(string));
                tvp.Columns.Add("UploadExcel3", typeof(string));

                int rowNo = 0;
                foreach (DataRow r in dt.Rows)
                {
                    rowNo++;
                    var v1 = r[p14]?.ToString();
                    var v2 = r[p15]?.ToString();
                    var v3 = r[p03]?.ToString();

                    // تجاهل صف فاضي بالكامل فقط
                    if (string.IsNullOrWhiteSpace(v1) && string.IsNullOrWhiteSpace(v2) && string.IsNullOrWhiteSpace(v3))
                        continue;

                    tvp.Rows.Add(rowNo, v1, v2, v3);
                }

                if (tvp.Rows.Count == 0)
                    return RespondError("لا توجد بيانات صالحة للإدخال.");

                var cs = _cfg.GetConnectionString("Default");
                if (string.IsNullOrWhiteSpace(cs))
                    return RespondError("ConnectionString (Default) غير موجود. تأكد من appsettings.json.");

                string fileHash = ComputeSha256Hex(path);
                var originalName = GetExcelOriginalFileName() ?? Path.GetFileName(path);

                await using var con = new SqlConnection(cs);
                await con.OpenAsync();

                await using var cmd = new SqlCommand("[Housing].[UploadExcel_ImportSelected3Cols]", con);
                cmd.CommandType = CommandType.StoredProcedure;

                cmd.Parameters.AddWithValue("@Column1Name", p14);
                cmd.Parameters.AddWithValue("@Column2Name", p15);
                cmd.Parameters.AddWithValue("@Column3Name", p03);
                cmd.Parameters.AddWithValue("@FileHash", fileHash);
                cmd.Parameters.AddWithValue("@OriginalFileName", originalName);

                var pRows = cmd.Parameters.AddWithValue("@Rows", tvp);
                pRows.SqlDbType = SqlDbType.Structured;
                pRows.TypeName = "Housing.UploadExcelRowType";

                bool ok;
                string msg;
                int insertedRows = 0;

                await using var rd = await cmd.ExecuteReaderAsync();
                if (!await rd.ReadAsync())
                    return RespondError("لم يتم استلام نتيجة من إجراء الإدخال.");

                ok = rd["IsSuccessful"] != DBNull.Value && Convert.ToBoolean(rd["IsSuccessful"]);
                msg = rd["Message_"]?.ToString() ?? "";
                if (rd["InsertedRows"] != DBNull.Value)
                    insertedRows = Convert.ToInt32(rd["InsertedRows"]);

                if (!ok)
                    return RespondWarning(string.IsNullOrWhiteSpace(msg) ? "تعذر إدخال البيانات." : msg, new { fileHash });


                ClearExcelSession(deletePhysicalFile: true);
                return RespondSuccess(
                    $"{msg} | صفوف الإكسل: {dt.Rows.Count} | المُرسلة: {tvp.Rows.Count} | المُدخلة: {insertedRows}",
                    new
                    {
                        totalExcelRows = dt.Rows.Count,
                        sentRows = tvp.Rows.Count,
                        insertedRows,
                        selectedColumns = new[] { p14, p15, p03 },
                        fileHash,
                        refresh = true
                    });
            }
            catch (SqlException ex)
            {
                return RespondError("خطأ SQL أثناء الإدخال: " + ex.Message);
            }
            catch (Exception ex)
            {
                return RespondError("فشل الإدخال: " + ex.Message);
            }
        }

        // ===============================
        // Excel Helpers
        // ===============================
        private static DataTable ReadExcelToDataTable(string fullPath, bool useHeaderRow, int sheetIndex)
        {
            using var stream = System.IO.File.Open(fullPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            using var reader = ExcelReaderFactory.CreateReader(stream);

            var ds = reader.AsDataSet(new ExcelDataSetConfiguration
            {
                ConfigureDataTable = _ => new ExcelDataTableConfiguration { UseHeaderRow = useHeaderRow }
            });

            if (ds.Tables.Count == 0)
                throw new InvalidOperationException("ملف الإكسل لا يحتوي على أي Sheets.");

            if (sheetIndex < 0 || sheetIndex >= ds.Tables.Count)
                sheetIndex = 0;

            var dt = ds.Tables[sheetIndex];

            for (int i = 0; i < dt.Columns.Count; i++)
            {
                if (string.IsNullOrWhiteSpace(dt.Columns[i].ColumnName))
                    dt.Columns[i].ColumnName = $"Column{i + 1}";
            }

            return dt;
        }

        private static List<Dictionary<string, object?>> DataTableToPreview(DataTable dt, int maxRows)
        {
            var list = new List<Dictionary<string, object?>>();
            int take = Math.Min(dt.Rows.Count, Math.Max(0, maxRows));

            for (int r = 0; r < take; r++)
            {
                var row = dt.Rows[r];
                var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

                foreach (DataColumn col in dt.Columns)
                {
                    var val = row[col];
                    dict[col.ColumnName] = val == DBNull.Value ? null : val;
                }

                list.Add(dict);
            }

            return list;
        }

        private static Dictionary<string, List<int>> FindEmptyCells(DataTable dt, IEnumerable<string> columns, int maxShowRows)
        {
            var result = new Dictionary<string, List<int>>(StringComparer.OrdinalIgnoreCase);
            foreach (var col in columns) result[col] = new List<int>();

            for (int i = 0; i < dt.Rows.Count; i++)
            {
                int excelRowNo = i + 2; // header row = 1

                foreach (var colName in columns)
                {
                    if (result[colName].Count >= maxShowRows) continue;

                    var v = dt.Rows[i][colName];
                    var s = v == DBNull.Value ? null : v?.ToString();

                    if (string.IsNullOrWhiteSpace(s))
                        result[colName].Add(excelRowNo);
                }
            }

            return result.Where(kv => kv.Value.Count > 0)
                         .ToDictionary(kv => kv.Key, kv => kv.Value, StringComparer.OrdinalIgnoreCase);
        }

        private static string ComputeSha256Hex(string filePath)
        {
            using var sha = SHA256.Create();
            using var fs = System.IO.File.OpenRead(filePath);
            var hash = sha.ComputeHash(fs);
            var sb = new StringBuilder(hash.Length * 2);
            foreach (var b in hash)
                sb.Append(b.ToString("x2"));
            return sb.ToString();
        }


        // ✅ تفريغ بيانات الإكسل من السيشن (يرجع الصفحة فاضية)
        private void ClearExcelSession(bool deletePhysicalFile = true)
        {
            // احفظ المسار قبل الحذف من السيشن
            var path = GetExcelFilePath();

            HttpContext.Session.Remove(SessionKeyExcelPreview);
            HttpContext.Session.Remove(SessionKeyExcelColumns);
            HttpContext.Session.Remove(SessionKeyExcelFilePath);
            HttpContext.Session.Remove(SessionKeyExcelRelative);
            HttpContext.Session.Remove(SessionKeyExcelFileName);
            HttpContext.Session.Remove(SessionKeyExcelUploadedAt);

            // (اختياري) حذف الملف من wwwroot/uploads/excel بعد الاستيراد
            if (deletePhysicalFile && !string.IsNullOrWhiteSpace(path))
            {
                try
                {
                    if (System.IO.File.Exists(path))
                        System.IO.File.Delete(path);
                }
                catch
                {
                    // تجاهل: لا نوقف العملية بسبب فشل حذف ملف
                }
            }
        }
    }
}