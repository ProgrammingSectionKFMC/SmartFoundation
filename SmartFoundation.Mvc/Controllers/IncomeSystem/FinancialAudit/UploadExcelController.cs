using ExcelDataReader;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers.IncomeSystem
{
    // ✅ مهم: Partial + بدون : Controller + بدون Constructor (DI موجود في Base)
    public partial class IncomeSystemController
    {
        // ✅ مسار الفيو الصحيح
        //private const string UploadExcelViewPath = "~/Views/IncomeSystem/FinancialAudit/ImportExcelForBuildingPayment.cshtml";

        // ===============================
        // Session Keys  (✅ تم تغيير الاسم لمنع تداخل جلسات UploadExcel القديمة)
        // ===============================
        private const string SessionKeyExcelPreview = "ImportExcelForBuildingPayment.Preview";
        private const string SessionKeyExcelColumns = "ImportExcelForBuildingPayment.Columns";
        private const string SessionKeyExcelFilePath = "ImportExcelForBuildingPayment.FilePath";
        private const string SessionKeyExcelRelative = "ImportExcelForBuildingPayment.Relative";
        private const string SessionKeyExcelFileName = "ImportExcelForBuildingPayment.OriginalFileName";
        private const string SessionKeyExcelUploadedAt = "ImportExcelForBuildingPayment.UploadedAt";

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
        // Detect Browser Reload (F5 / Ctrl+R)
        // ===============================
        private bool IsBrowserRefresh()
        {
            var cc = Request.Headers["Cache-Control"].ToString();
            if (!string.IsNullOrWhiteSpace(cc) && cc.Contains("max-age=0", StringComparison.OrdinalIgnoreCase))
                return true;

            var pragma = Request.Headers["Pragma"].ToString();
            if (!string.IsNullOrWhiteSpace(pragma) && pragma.Contains("no-cache", StringComparison.OrdinalIgnoreCase))
                return true;

            return false;
        }

        // ===============================
        // Unified Toastr responder (✅ RedirectToAction تم تغييره)
        // ===============================
        private IActionResult RespondSuccess(string msg, object? data = null)
        {
            TempData["Success"] = msg;

            if (IsAjaxRequest())
                return Ok(new { ok = true, message = msg, data });

            return RedirectToAction(nameof(ImportExcelForBuildingPayment));
        }

        private IActionResult RespondWarning(string msg, object? data = null)
        {
            TempData["Warning"] = msg;

            if (IsAjaxRequest())
                return Ok(new { ok = false, message = msg, data });

            return RedirectToAction(nameof(ImportExcelForBuildingPayment));
        }

        private IActionResult RespondError(string msg, object? data = null)
        {
            TempData["Error"] = msg;

            if (IsAjaxRequest())
                return Ok(new { ok = false, message = msg, data });

            return RedirectToAction(nameof(ImportExcelForBuildingPayment));
        }

        // ===============================
        // GET: صفحة الاستيراد (✅ الاسم الجديد)
        // ===============================
        [HttpGet]
        [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
        public async Task<IActionResult> ImportExcelForBuildingPayment()
        {
            // تنظيف ملفات قديمة (اختياري)
            CleanupOldExcelFiles(olderThanDays: 1);

            if (IsBrowserRefresh())
                ClearExcelSession(deletePhysicalFile: true);

            if (!InitPageContext(out var redirect))
                return redirect!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = "IncomeSystem";
            PageName = nameof(ImportExcelForBuildingPayment);

            var spParameters = new object?[]
           {
             PageName ?? "ImportExcelForBuildingPayment",
             IdaraId,
             usersId,
             HostName
           };

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

            //  تقسيم الداتا سيت للجدول الأول + جداول أخرى
            SplitDataSet(ds);


            //if (permissionTable is null || permissionTable.Rows.Count == 0)
            //{
            //    TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
            //    return RedirectToAction("Index", "Home");
            //}

            List<OptionItem> BillChargeTypeOptions = new();
            List<OptionItem> monthOptions = new()
                {
                    new OptionItem { Value = "1", Text = "يناير" },
                    new OptionItem { Value = "2", Text = "فبراير" },
                    new OptionItem { Value = "3", Text = "مارس" },
                    new OptionItem { Value = "4", Text = "أبريل" },
                    new OptionItem { Value = "5", Text = "مايو" },
                    new OptionItem { Value = "6", Text = "يونيو" },
                    new OptionItem { Value = "7", Text = "يوليو" },
                    new OptionItem { Value = "8", Text = "أغسطس" },
                    new OptionItem { Value = "9", Text = "سبتمبر" },
                    new OptionItem { Value = "10", Text = "أكتوبر" },
                    new OptionItem { Value = "11", Text = "نوفمبر" },
                    new OptionItem { Value = "12", Text = "ديسمبر" }
                };

            List<OptionItem> yearOptions = new();
            for (int year = 2017; year <= 2037; year++)
            {
                yearOptions.Add(new OptionItem { Value = year.ToString(), Text = year.ToString() });
            }



            // ---------------------- DDLValues ----------------------

            JsonResult? result;
            string json;

            //// ---------------------- insuranceOptions ----------------------

            result = await _CrudController.GetDDLValues(
                 "BillChargeTypeName_A", "BillChargeTypeID", "1", PageName, usersId, IdaraId, HostName
            ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            BillChargeTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


            //// ---------------------- END DDL ----------------------

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
            var currentUrl = Request.Path;

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

            // First, fix the form fields (p08-p10 should NOT be select with BillChargeTypeOptions):
            var processFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "FINANCIALAUDITFOREXTENDANDEVICTIONS" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl",        Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name="__RequestVerificationToken", Type="hidden", Value=tokens.RequestToken ?? "" },


                new FieldConfig { Name="p05", Label="نوع المسير", Type="select", ColCss="4", Options=BillChargeTypeOptions, Required = true },
                new FieldConfig { Name="p06", Label="شهر الحسم", Type="select", ColCss="4", Options=monthOptions, Required = true,Select2=true, Placeholder = "اختر الشهر" },
                new FieldConfig { Name="p07", Label="سنة الحسم", Type="select", ColCss="4", Options=yearOptions, Required = true,Select2=true, Placeholder = "اختر السنة",Value = DateTime.Now.Year.ToString()},
                new FieldConfig { Name="p08", Label="رقم المسير", Type="text", ColCss="4", Required = true },
                new FieldConfig { Name="p09", Label="تاريخ المسير", Type="date", ColCss="4", Required = true },
                new FieldConfig { Name="p10", Label="الوصف", Type="textarea", ColCss="4", Required = true },

                new FieldConfig { Name="p11", Label="IdaraId_FK", Type="hidden", ColCss="4", Required = true   , Value = IdaraId },
                new FieldConfig { Name="p12", Label="entryData", Type="hidden", ColCss="4", Required = true    , Value = usersId },
                new FieldConfig { Name="p13", Label="hostName", Type="hidden", ColCss="4", Required = true , Value = HostName},


                new FieldConfig { Name="p01", Label="العمود المخصص للهوية الوطنية", Type="select", ColCss="3",Select2=true, Options=options, Required = true },
                new FieldConfig { Name="p03", Label="العمود المخصص للرقم العام",   Type="select", ColCss="3",Select2=true, Options=options, Required = true },
                new FieldConfig { Name="p02", Label="العمود المخصص للوحدة",        Type="select", ColCss="3",Select2=true, Options=options, Required = true },
                new FieldConfig { Name="p04", Label="العمود المخصص لمبلغ الحسم",   Type="select", ColCss="3",Select2=true, Options=options, Required = true },

            };

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "استيراد Excel (Building Payment)",
                PanelTitle = "استيراد Excel (Building Payment)",
                Columns = columns,
                Rows = previewRows,
                RowIdField = null,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50 },
                Searchable = true,
                ShowFilter = false,
                FilterRow = true,
                ShowColumnVisibility = true,
                Selectable = false,
                Toolbar = new TableToolbarConfig
                {
                    ShowAdd = true,
                    ShowAdd1 = true,
                    ShowEdit = false,
                    ShowDelete = false,
                    ShowExportExcel = true,
                    ShowExportPdf = false,
                    ShowColumns = true,
                    ShowRefresh = false,

                    Add = new TableAction
                    {
                        Label = "رفع Excel",
                        Icon = "fa-solid fa-file-excel",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "رفع ملف Excel",
                        OpenForm = new FormConfig
                        {
                            FormId = "ImportExcelForBuildingPaymentUploadForm",
                            Method = "post",
                            Enctype = "multipart/form-data",
                            ActionUrl = Url.Action(nameof(ImportExcelForBuildingPaymentUpload), "IncomeSystem")!,
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
                            FormId = "ImportExcelForBuildingPaymentProcessForm",
                            Method = "post",
                            Enctype = "application/x-www-form-urlencoded",
                            ActionUrl = Url.Action(nameof(ImportExcelForBuildingPaymentProcess), "IncomeSystem")!,
                            Fields = processFields
                        }
                    },
                }
            };

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa fa-list",
                TableDS = dsModel
            };

            // ✅ نفس الفيو (تقدر تغيره لاحقاً)
            return View("FinancialAudit/ImportExcelForBuildingPayment", page);
        }

        // ===============================
        // POST: Upload Excel + Preview (✅ الاسم الجديد)
        // ===============================
        [HttpPost]
        [ValidateAntiForgeryToken]
        [RequestSizeLimit(20 * 1024 * 1024)]
        [RequestFormLimits(MultipartBodyLengthLimit = 20 * 1024 * 1024)]
        public async Task<IActionResult> ImportExcelForBuildingPaymentUpload()
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
                    await file.CopyToAsync(fs);

                var relative = $"/uploads/excel/{storedName}";
                SaveExcelFileInfo(fullPath, relative, file.FileName ?? storedName);

                // ✅ تحقق التوقيع قبل القراءة
                var sigErr = ValidateExcelSignature(fullPath, ext);
                if (sigErr != null)
                {
                    ClearExcelSession(deletePhysicalFile: true);
                    return RespondError(sigErr + " إذا كان الملف محمي بكلمة مرور قم بفتحه في Excel ثم Save As بدون حماية.");
                }

                DataTable dt;
                try
                {
                    dt = ReadExcelToDataTable(fullPath, useHeaderRow: true, sheetIndex: 0);
                }
                catch (Exception ex)
                {
                    ClearExcelSession(deletePhysicalFile: true);
                    return RespondError("فشل قراءة الإكسل. تأكد أن الملف Excel صحيح وغير مشفر بكلمة مرور. التفاصيل: " + ex.Message);
                }

                var cols = dt.Columns.Cast<DataColumn>()
                    .Select(c => string.IsNullOrWhiteSpace(c.ColumnName) ? $"Column{c.Ordinal + 1}" : c.ColumnName.Trim())
                    .ToList();

                for (int i = 0; i < dt.Columns.Count; i++)
                {
                    if (string.IsNullOrWhiteSpace(dt.Columns[i].ColumnName))
                        dt.Columns[i].ColumnName = cols[i];
                }

                var preview = DataTableToPreview(dt, maxRows: 20000);

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
        // POST: Process -> DB (✅ الاسم الجديد)
        // ===============================
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ImportExcelForBuildingPaymentProcess(
            string? p01, string? p02, string? p03, string? p04, string? p05, 
            string? p06, string? p07, string? p08, string? p09, string? p10, string? p11, string? p12, string? p13)
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

                // Trim all parameters
                p01 = (p01 ?? "").Trim();
                p02 = (p02 ?? "").Trim();
                p03 = (p03 ?? "").Trim();
                p04 = (p04 ?? "").Trim();
                p05 = (p05 ?? "").Trim();
                p06 = (p06 ?? "").Trim();
                p07 = (p07 ?? "").Trim();
                p08 = (p08 ?? "").Trim();
                p09 = (p09 ?? "").Trim();
                p10 = (p10 ?? "").Trim();
                p11 = (p11 ?? "").Trim();
                p12 = (p12 ?? "").Trim();
                p13 = (p13 ?? "").Trim();

                // Validate p05 (BillChargeTypeID)
                if (string.IsNullOrWhiteSpace(p05))
                    return RespondError("الرجاء اختيار نوع المسير.");

                if (!int.TryParse(p05, out var billChargeTypeId) || billChargeTypeId <= 0)
                    return RespondError("قيمة نوع المسير غير صحيحة.");

                // Validate p06 (Month)
                if (string.IsNullOrWhiteSpace(p06))
                    return RespondError("الرجاء اختيار شهر الحسم.");

                // Validate p07 (Year)
                if (string.IsNullOrWhiteSpace(p07))
                    return RespondError("الرجاء اختيار سنة الحسم.");

                // Validate p08 (DeductListNo)
                if (string.IsNullOrWhiteSpace(p08))
                    return RespondError("الرجاء إدخال رقم المسير.");

                // Validate p09 (DeductListDate) - optional date validation
                if (!string.IsNullOrWhiteSpace(p09))
                {
                    if (!DateTime.TryParse(p09, out _))
                        return RespondError("تاريخ المسير غير صحيح.");
                }

                if (string.IsNullOrWhiteSpace(p10))
                    return RespondError("الرجاء كتابة الوصف.");
                // p10 (Notes) is optional

                // Validate column selections
                if (string.IsNullOrWhiteSpace(p01) || string.IsNullOrWhiteSpace(p02) || 
                    string.IsNullOrWhiteSpace(p03) || string.IsNullOrWhiteSpace(p04))
                    return RespondError("الرجاء اختيار جميع الأعمدة المطلوبة.");

                var selected = new[] { p01, p02, p03, p04 }
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .Select(x => x!.Trim())
                    .ToList();

                var duplicates = selected
                    .GroupBy(x => x, StringComparer.OrdinalIgnoreCase)
                    .Where(g => g.Count() > 1)
                    .Select(g => g.Key)
                    .ToList();

                if (duplicates.Any())
                    return RespondError($"تم تكرار العمود: {string.Join("، ", duplicates)}. الرجاء اختيار أعمدة مختلفة.");

                DataTable dt = ReadExcelToDataTable(path, useHeaderRow: true, sheetIndex: 0);

                var colSet = new HashSet<string>(
                    dt.Columns.Cast<DataColumn>().Select(c => c.ColumnName),
                    StringComparer.OrdinalIgnoreCase);

                if (!colSet.Contains(p01) || !colSet.Contains(p02) || !colSet.Contains(p03) || !colSet.Contains(p04))
                    return RespondError("أحد الأعمدة المختارة غير موجود في ملف الإكسل.");

                var emptyReport = FindEmptyCells(dt, new[] { p01, p02, p03, p04 }, maxShowRows: 15);
                if (emptyReport.Count > 0)
                {
                    var sb = new StringBuilder();
                    foreach (var kv in emptyReport)
                        sb.Append($"العمود ({kv.Key}) يحتوي على قيم فارغة في الصفوف: {string.Join(", ", kv.Value)}. ");
                    return RespondError(sb.ToString().Trim());
                }

                var tvp = new DataTable();
                tvp.Columns.Add("RowNo", typeof(int));
                tvp.Columns.Add("IDNumber", typeof(string));
                tvp.Columns.Add("unitID", typeof(string));
                tvp.Columns.Add("generalNo_FK", typeof(string));
                tvp.Columns.Add("amount", typeof(decimal));

                int rowNo = 0;
                int sentRows = 0;

                foreach (DataRow r in dt.Rows)
                {
                    rowNo++;

                    var v1 = r[p01]?.ToString();
                    var v2 = r[p02]?.ToString();
                    var v3 = r[p03]?.ToString();
                    var v4 = r[p04]?.ToString();

                    if (string.IsNullOrWhiteSpace(v1) && string.IsNullOrWhiteSpace(v2) && 
                        string.IsNullOrWhiteSpace(v3) && string.IsNullOrWhiteSpace(v4))
                        continue;

                    tvp.Rows.Add(rowNo, v1, v2, v3, v4);
                    sentRows++;
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

                await using var cmd = new SqlCommand("[Housing].[ImportExcelForBuildingPayment]", con);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.CommandTimeout = 120;

                // Original parameters
                cmd.Parameters.AddWithValue("@NationalIDs", p01);
                cmd.Parameters.AddWithValue("@UnitNumbers", p02);
                cmd.Parameters.AddWithValue("@GeneralNumbers", p03);
                cmd.Parameters.AddWithValue("@Amounts", p04);

                // ✅ Send p05-p10 as per stored procedure signature
                cmd.Parameters.Add("@BillChargeTypeID", SqlDbType.Int).Value = billChargeTypeId; // p05
                cmd.Parameters.AddWithValue("@IssueMonth", string.IsNullOrWhiteSpace(p06) ? (object)DBNull.Value : p06); // p06
                cmd.Parameters.AddWithValue("@IssueYear", string.IsNullOrWhiteSpace(p07) ? (object)DBNull.Value : p07); // p07
                cmd.Parameters.AddWithValue("@DeductListNo", string.IsNullOrWhiteSpace(p08) ? (object)DBNull.Value : p08); // p08
                cmd.Parameters.AddWithValue("@DeductListDate", string.IsNullOrWhiteSpace(p09) ? (object)DBNull.Value : p09); // p09
                cmd.Parameters.AddWithValue("@Notes", string.IsNullOrWhiteSpace(p10) ? (object)DBNull.Value : p10); // p10

                cmd.Parameters.AddWithValue("@IdaraId_FK", string.IsNullOrWhiteSpace(p11) ? (object)DBNull.Value : p11); // p11
                cmd.Parameters.AddWithValue("@entryData", string.IsNullOrWhiteSpace(p12) ? (object)DBNull.Value : p12); // p12
                cmd.Parameters.AddWithValue("@hostName", string.IsNullOrWhiteSpace(p13) ? (object)DBNull.Value : p13); // p13

               

                cmd.Parameters.AddWithValue("@FileHash", fileHash);
                cmd.Parameters.AddWithValue("@OriginalFileName", originalName);

                var pRows = cmd.Parameters.AddWithValue("@Rows", tvp);
                pRows.SqlDbType = SqlDbType.Structured;
                pRows.TypeName = "Housing.ImportExcelForBuildingPaymentRowType";

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
                    $"{msg} | صفوف الإكسل: {dt.Rows.Count} | المُرسلة: {sentRows} | المُدخلة: {insertedRows}",
                    new
                    {
                        totalExcelRows = dt.Rows.Count,
                        sentRows,
                        insertedRows,
                        selectedColumns = new[] { p01, p02, p03, p04 },
                        billChargeTypeId,
                        issueMonth = p06,
                        issueYear = p07,
                        deductListNo = p08,
                        deductListDate = p09,
                        notes = p10,
                        idaraId = p11,
                        entryData = p12,
                        hostName = p13,
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
                int excelRowNo = i + 2;

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

        private void ClearExcelSession(bool deletePhysicalFile = true)
        {
            var path = GetExcelFilePath();

            HttpContext.Session.Remove(SessionKeyExcelPreview);
            HttpContext.Session.Remove(SessionKeyExcelColumns);
            HttpContext.Session.Remove(SessionKeyExcelFilePath);
            HttpContext.Session.Remove(SessionKeyExcelRelative);
            HttpContext.Session.Remove(SessionKeyExcelFileName);
            HttpContext.Session.Remove(SessionKeyExcelUploadedAt);

            if (deletePhysicalFile && !string.IsNullOrWhiteSpace(path))
            {
                try
                {
                    if (System.IO.File.Exists(path))
                        System.IO.File.Delete(path);
                }
                catch { }
            }
        }

        private static bool LooksLikeXlsx(string filePath)
        {
            Span<byte> b = stackalloc byte[4];
            using var fs = System.IO.File.OpenRead(filePath);
            if (fs.Read(b) < 4) return false;
            return b[0] == 0x50 && b[1] == 0x4B && b[2] == 0x03 && b[3] == 0x04;
        }

        private static bool LooksLikeXls(string filePath)
        {
            Span<byte> b = stackalloc byte[8];
            using var fs = System.IO.File.OpenRead(filePath);
            if (fs.Read(b) < 8) return false;
            return b[0] == 0xD0 && b[1] == 0xCF && b[2] == 0x11 && b[3] == 0xE0
                && b[4] == 0xA1 && b[5] == 0xB1 && b[6] == 0x1A && b[7] == 0xE1;
        }

        private static string? ValidateExcelSignature(string filePath, string extLower)
        {
            if (extLower == ".xlsx" && !LooksLikeXlsx(filePath))
                return "الملف ليس XLSX صالح (قد يكون ملف مختلف تم تغيير امتداده).";
            if (extLower == ".xls" && !LooksLikeXls(filePath))
                return "الملف ليس XLS صالح (قد يكون ملف مختلف تم تغيير امتداده).";
            return null;
        }

        // تنظيف الملفات القديمة من مجلد uploads/excel
        private void CleanupOldExcelFiles(int olderThanDays = 7)
        {
            try
            {
                var dir = Path.Combine(_env.WebRootPath, "uploads", "excel");
                if (!Directory.Exists(dir)) return;

                var cutoff = DateTime.Now.AddDays(-olderThanDays);

                foreach (var file in Directory.GetFiles(dir, "*.*"))
                {
                    var ext = Path.GetExtension(file).ToLowerInvariant();
                    if (ext != ".xls" && ext != ".xlsx") continue;

                    var lastWrite = System.IO.File.GetLastWriteTime(file);
                    if (lastWrite < cutoff)
                        System.IO.File.Delete(file);
                }
            }
            catch
            {
                // تجاهل (أو سجل في ErrorLog)
            }
        }
    }
}