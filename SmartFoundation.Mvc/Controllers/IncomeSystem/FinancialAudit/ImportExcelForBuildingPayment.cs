using ExcelDataReader;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
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


           



            if (!InitPageContext(out var redirect))
                return redirect!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            if (IsBrowserRefresh())
                ClearExcelSession(deletePhysicalFile: true);

            var referer = Request.Headers["Referer"].FirstOrDefault();
            bool isDirectOpen = string.IsNullOrWhiteSpace(referer);

            if (isDirectOpen)
                ClearExcelSession(deletePhysicalFile: true);

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


            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();
            //  تقسيم الداتا سيت للجدول الأول + جداول أخرى
            SplitDataSet(ds);

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }


            string rowIdField = "";
            bool canInsert = false;
            bool canView = false;

            //if (permissionTable is null || permissionTable.Rows.Count == 0)
            //{
            //    TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
            //    return RedirectToAction("Index", "Home");
            //}

            List<OptionItem> BillChargeTypeOptions = new();
            List<OptionItem> monthOptions = new();
            List<OptionItem> yearOptions = new();
           


            // ---------------------- DDLValues ----------------------

            JsonResult? result;
            string json;

            //// ---------------------- insuranceOptions ----------------------

            result = await _CrudController.GetDDLValues(
                 "BillChargeTypeName_A", "BillChargeTypeID", "1", PageName, usersId, IdaraId, HostName
            ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            BillChargeTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


            //// ---------------------- insuranceOptions ----------------------

            result = await _CrudController.GetDDLValues(
                 "Year_", "Year_", "2", PageName, usersId, IdaraId, HostName
            ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            yearOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;
            //// ---------------------- insuranceOptions ----------------------

            result = await _CrudController.GetDDLValues(
                 "ArabicMonthName", "MonthNumber", "3", PageName, usersId, IdaraId, HostName
            ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            monthOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


            //// ---------------------- END DDL ----------------------



            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // صلاحيات
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "IMPORTEXCELFORBUILDINGPAYMENT") canView = true;

                    }

                    if (dt4 != null && dt4.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField = "deductListID";
                        var possibleIdNames = new[] { "deductListID", "DeductListID", "Id", "ID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt4.Columns.Contains(n))
                                     ?? dt4.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["deductListID"] = "الرقم المرجعي",
                            ["deductTypeName_A"] = "نوع المسير",
                            ["BillChargeTypeName_A"] = "الخدمة",
                            ["deductName"] = "وصف المسير",
                            ["issueMonth"] = "الشهر",
                            ["issueYear"] = "السنة",
                            ["paymentNo"] = "رقم المسير",
                            ["paymentDate"] = "تاريخ المسير",
                            ["description"] = "ملاحظات"
                        };





                        // الأعمدة
                        foreach (DataColumn c in dt4.Columns)
                        {
                            string colType = "text";
                            var t = c.DataType;
                            if (t == typeof(bool)) colType = "bool";
                            else if (t == typeof(DateTime)) colType = "date";
                            else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                                     || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                                colType = "number";

                            bool isHidden = c.ColumnName.Equals("deductTypeID_FK", StringComparison.OrdinalIgnoreCase)
                                          || c.ColumnName.Equals("deductUID", StringComparison.OrdinalIgnoreCase)
                                          || c.ColumnName.Equals("amountTypeID_FK", StringComparison.OrdinalIgnoreCase)
                                          || c.ColumnName.Equals("paymentTypeID_FK", StringComparison.OrdinalIgnoreCase)
                                          || c.ColumnName.Equals("BillChargeTypeID_FK", StringComparison.OrdinalIgnoreCase)
                                          || c.ColumnName.Equals("DeductListStatusID_FK", StringComparison.OrdinalIgnoreCase)
                                          || c.ColumnName.Equals("IdaraId_FK", StringComparison.OrdinalIgnoreCase)
                                          || c.ColumnName.Equals("entryDate", StringComparison.OrdinalIgnoreCase)
                                          || c.ColumnName.Equals("entryData", StringComparison.OrdinalIgnoreCase)
                                          || c.ColumnName.Equals("hostName", StringComparison.OrdinalIgnoreCase)
                                          || c.ColumnName.Equals("deductActive", StringComparison.OrdinalIgnoreCase);
                           

                            //  فقط هذي الأعمدة نبي لها فلتر select
                            bool isdeductTypeName_A = c.ColumnName.Equals("deductTypeName_A", StringComparison.OrdinalIgnoreCase);
                            bool isBillChargeTypeName_A = c.ColumnName.Equals("BillChargeTypeName_A", StringComparison.OrdinalIgnoreCase);
                           

                            //  جهز خيارات الفلتر من نفس بيانات الجدول (عشان التطابق يكون صحيح)
                            List<OptionItem> filterOpts = new();
                            if (isdeductTypeName_A || isBillChargeTypeName_A )
                            {
                                var field = c.ColumnName;

                                var distinctVals = dt4.AsEnumerable()
                                    .Select(r => (r[field] == DBNull.Value ? "" : r[field]?.ToString())?.Trim())
                                    .Where(s => !string.IsNullOrWhiteSpace(s))
                                    .Distinct()
                                    .OrderBy(s => s)
                                    .ToList();

                                filterOpts = distinctVals
                                    .Select(s => new OptionItem { Value = s!, Text = s! })
                                    .ToList();
                            }

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,

                                Visible = !(isHidden),

                                //truncate = isMilitaryUnitName || isNote,

                                //  فلتر للرتبة + الوحدة + الجنسية
                                Filter = (isdeductTypeName_A || isBillChargeTypeName_A)
                                    ? new TableColumnFilter
                                    {
                                        Enabled = true,
                                        Type = "select",
                                        Options = filterOpts
                                    }
                                    : new TableColumnFilter
                                    {
                                        Enabled = false
                                    }
                            });
                        }





                        // الصفوف
                        foreach (DataRow r in dt4.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

                            foreach (DataColumn c in dt4.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;


                            //===============================================================================================
                            // تحديد رقم المستفيد الأساسي (RowId)
                            dict["p01"] = Get("deductListID") ?? Get("DeductListID");
                           
                            rowsList.Add(dict);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.BuildingTypeDataSetError = ex.Message;
            }



            ////------------------------------
            var previewCols = GetPreviewColumns();
            var previewRows = GetPreviewRows();

            var excelPath = GetExcelFilePath();
            bool hasExcelFile = !string.IsNullOrWhiteSpace(excelPath) && System.IO.File.Exists(excelPath);

            bool hasExcelPreview = previewCols.Count > 0 && previewRows.Count > 0;

            bool isInfoOnly = (previewCols.Count == 1 &&
                               previewCols[0].Equals("Info", StringComparison.OrdinalIgnoreCase));

            bool canProcess = hasExcelFile && hasExcelPreview && !isInfoOnly;

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
                new FieldConfig { Name="p07", Label="سنة الحسم", Type="select", ColCss="4", Options=yearOptions, Required = true, Placeholder = "الرجاء اختيار السنة" },

                  // ✅ FIXED - Corrected syntax
                  new FieldConfig
                  {
                      Name = "p06",
                      Label = "شهر الحسم",
                      Type = "select",
                      Options = new List<OptionItem> { },
                      ColCss = "4",
                      Required = true,
                      
                      Placeholder = "الرجاء اختيار الشهر",
                      DependsOn = "p07",
                      DependsUrl = "/crud/DDLFiltered?FK=Year_&textcol=ArabicMonthName&ValueCol=MonthNumber&PageName=ImportExcelForBuildingPayment&TableIndex=3"
                  },
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


            var ShowFields = new List<FieldConfig>
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


                new FieldConfig { Name="p01", Label="نوع المسير", Type="hidden", ColCss="4", Options=BillChargeTypeOptions, Required = true },
                

            };

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "رفع ومعالجة المسيرات",
                PanelTitle = "رفع ومعالجة المسيرات",
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
                //RenderAsToggle = true,
                //ToggleLabel = "استيراد Excel جديد",
                //ToggleIcon = "fa-solid fa-newspaper",
                //ToggleDefaultOpen = true,
                //ShowToggleCount = false,

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsToggle = false,
                RenderAsSection = false,
                RenderAsTab = true,
                TabGroupKey = "ImportExcelForBuildingPaymentpage",
                TabKey = "deductListUpload",
                TabLabel = "استيراد Excel جديد",
                TabIcon = "fa-solid fa-upload",
                TabDefaultActive = false,
                ShowTabCount = false,
                TabOrder = 2,
                Toolbar = new TableToolbarConfig
                {
                    ShowAdd = true,
                    ShowAdd1 = true,
                    EnableAdd1 = canProcess,
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



            var extraEditCtx = new Dictionary<string, object?>
            {
                ["idaraID"] = IdaraId,
                ["entrydata"] = usersId,
                ["hostname"] = HostName
            };

            var extraEditRequestBase = new Dictionary<string, object?>
            {
                ["pageName_"] = PageName,
                ["ActionType"] = "GetBuildingPaymentByDeductList",
                ["tableIndex"] = 0
            };

            var extraMetaAutoOpen = new Dictionary<string, object?>
            {
                ["extraSlotKey"] = "m1",
                ["extraTitle"] = "بيانات المسير",
                ["useRowExtra"] = true,
                ["lazyExtra"] = true,
                ["extraEndpoint"] = "/crud/extradataload",
                ["allowNoSelection"] = true,

                // المهم
                ["extraLoadOnOpen"] = true,

                ["ctx"] = extraEditCtx,
                ["extraRequest"] = extraEditRequestBase,

                ["extraParamMap"] = new Dictionary<string, string>
                {
                    ["parameter_01"] = "p01"
                    //,
                    //["parameter_05"] = "p05"
                },

                ["EnableSearch"] = false,
                ["ShowMeta"] = false,
                ["PageSize"] = 10,
                ["Sortable"] = false,
                ["showRowNumbers"] = false,

                ["visibleFields"] = new List<string>
    {
        "deductListID_FK","generalNo_FK","IDNumber", "unitID","amount"
    },

                ["headerMap"] = new Dictionary<string, string>
                {
                    ["generalNo_FK"] = "الرقم العام",
                    ["IDNumber"] = "الهوية الوطنية",
                    ["unitID"] = "رمز الوحدة",
                    ["amount"] = "المبلغ",
                    ["deductListID_FK"] = "الرقم المرجعي للمسير"
                }
            };



            var dsModelDeductListDetails = new SmartTableDsModel
            {
                PageTitle = "رفع ومعالجة المسيرات",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                PanelTitle = "رفع ومعالجة المسيرات",
                //TabelLabel = "بيانات المستفيدين",
                //TabelLabelIcon = "fa-solid fa-user-group",
                EnableCellCopy = true,
                ShowColumnVisibility = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                //RenderAsToggle = true,
                //ToggleLabel = "فترات القراءة",
                //ToggleIcon = "fa-solid fa-newspaper",
                //ToggleDefaultOpen = true,
                //ShowToggleCount = false,

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsToggle = false,
                RenderAsSection = false,
                RenderAsTab = true,
                TabGroupKey = "ImportExcelForBuildingPaymentpage",
                TabKey = "deductListView",
                TabLabel = "استعراض المسيرات",
                TabIcon = "fa-solid fa-newspaper",
                TabDefaultActive = true,
                ShowTabCount = true,
                TabOrder = 1,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,

                    ShowAdd = canView ,
                    ShowEdit1 = canView,


                    ShowBulkDelete = false,




                    CustomActions = new List<TableAction>
                       {

                            new TableAction
                            {
                                Label = "عرض التفاصيل",
                                ModalTitle = "<i class='fa-solid fa-circle-info text-emerald-600 text-xl mr-2'></i> تفاصيل المستفيد",
                                Icon = "fa-regular fa-file",
                                //Show = true,  // ✅ أضف
                                OpenModal = true,
                                RequireSelection = true,
                                MinSelection = 1,
                                MaxSelection = 1,


                            },
                        },


                    Edit1 = new TableAction
                    {
                        Label = "استعراض تفاصيل المسير",
                        Icon = "fa fa-newspaper",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "استعراض تفاصيل المسير",
                        
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassInsertForm",
                            Title = "بيانات استعراض تفاصيل المسير",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = ShowFields,
                            Buttons = new List<FormButtonConfig>
                            {
                               // new FormButtonConfig { Text = "حفظ",   Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        },
                        Meta = extraMetaAutoOpen,
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,

                        Guards = new TableActionGuards
                        {
                            AppliesTo = "any",
                            DisableWhenAny = new List<TableActionRule>
                        {

                              new TableActionRule
                            {
                                Field = "AllMeterNotReaded",
                                Op = "eq",
                                Value = "0",
                                Message = "لايمكن اغلاق الفترة قبل انهاء قراءة جميع العدادات ",
                                Priority = 3
                            },


                          }
                        }
                    },

                }
            };
   
           

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa fa-list",
                TableDS = dsModel,
                TableDS1 = dsModelDeductListDetails
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

        private static List<OptionItem> BuildMonthOptions(int selectedYear)
        {
            var now = DateTime.Now;
            int maxMonth = (selectedYear < now.Year) ? 12
                         : (selectedYear == now.Year) ? now.Month
                         : 0;

            var months = new (int Val, string Text)[]
            {
        (1,"يناير"), (2,"فبراير"), (3,"مارس"), (4,"أبريل"),
        (5,"مايو"), (6,"يونيو"), (7,"يوليو"), (8,"أغسطس"),
        (9,"سبتمبر"), (10,"أكتوبر"), (11,"نوفمبر"), (12,"ديسمبر")
            };

            return months
                .Where(m => m.Val <= maxMonth)
                .Select(m => new OptionItem { Value = m.Val.ToString(), Text = m.Text })
                .ToList();
        }

        [HttpGet]
        public IActionResult GetMonthsByYear(int year)
        {
            // حماية بسيطة: لا تسمح بسنة أكبر من الحالية
            if (year > DateTime.Now.Year)
                return Ok(new List<OptionItem>());

            return Ok(BuildMonthOptions(year));
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