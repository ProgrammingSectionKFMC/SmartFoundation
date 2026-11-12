using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using SmartFoundation.MVC.Reports;
using System.Data;

namespace SmartFoundation.Mvc.Controllers.Vehicle
{
    public partial class VehicleController : Controller
    {
        [Route("Vehicle/Violation")]
        public async Task<IActionResult> Violation(
              int pdf = 0
            , string? violationID = null
            , string? chassisNumber = null
            , string? violationTypeID = null
            , bool? paid = null
            , string? fromDate = null
            , string? toDate = null
            , int pageNumber = 1
            , int pageSize = 50)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = "Vehicle";
            PageName = "Violation";

            #region Load Data

            DataSet? ds = null;
            DataSet? vehicleDs = null;
            DataSet? lookupsDs = null;

            var dsTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[]
                {
                    PageName,
                    IdaraId,
                    usersId,
                    HostName,
                    "LIST",
                    null,
                    string.IsNullOrWhiteSpace(chassisNumber) ? null : chassisNumber,
                    string.IsNullOrWhiteSpace(violationTypeID) ? null : violationTypeID,
                    paid.HasValue ? (paid.Value ? "1" : "0") : null,
                    string.IsNullOrWhiteSpace(fromDate) ? null : fromDate,
                    string.IsNullOrWhiteSpace(toDate) ? null : toDate,
                    pageNumber,
                    pageSize
                });

            var vehicleTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[] { "Vehicle_Search", IdaraId, usersId, HostName, "%" });

            var lookupsTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[] { "Violation_GetLookups", IdaraId, usersId, HostName, "LOOKUPS" });

            await Task.WhenAll(dsTask, vehicleTask, lookupsTask);

            ds = dsTask.Result;
            vehicleDs = vehicleTask.Result;
            lookupsDs = lookupsTask.Result;

            SplitDataSet(ds);

            #endregion

            #region Vehicle Options (Value = vehicleID)

            var vehicleOptions = new List<OptionItem>();
            DataTable? vehicleTable = (vehicleDs?.Tables?.Count ?? 0) > 1
                ? vehicleDs!.Tables[1]
                : (vehicleDs?.Tables?.Count ?? 0) > 0 ? vehicleDs!.Tables[0] : null;

            if (vehicleTable != null)
            {
                foreach (DataRow r in vehicleTable.Rows)
                {
                    var vid = vehicleTable.Columns.Contains("vehicleID")
                        ? r["vehicleID"]?.ToString() : null;
                    if (string.IsNullOrWhiteSpace(vid)) continue;

                    var chassis = vehicleTable.Columns.Contains("chassisNumber")
                        ? r["chassisNumber"]?.ToString()?.Trim() ?? "" : "";
                    var armyNum = vehicleTable.Columns.Contains("armyNumber")
                        ? r["armyNumber"]?.ToString()?.Trim() ?? "" : "";
                    var plateLetters = vehicleTable.Columns.Contains("plateLetters")
                        ? r["plateLetters"]?.ToString()?.Trim() ?? "" : "";
                    var plateNumbers = vehicleTable.Columns.Contains("plateNumbers")
                        ? r["plateNumbers"]?.ToString()?.Trim() ?? "" : "";
                    var plate = $"{plateLetters} {plateNumbers}".Trim();

                    var text = string.IsNullOrWhiteSpace(armyNum)
                        ? chassis
                        : $"{armyNum} — {chassis}";
                    if (!string.IsNullOrWhiteSpace(plate))
                        text += $" — {plate}";

                    vehicleOptions.Add(new OptionItem { Value = vid, Text = text });
                }
            }

            #endregion

            #region Violation Type Options

            var violationTypeOptions = new List<OptionItem>();
            DataTable? lookupsTable = (lookupsDs?.Tables?.Count ?? 0) > 1
                ? lookupsDs!.Tables[1]
                : (lookupsDs?.Tables?.Count ?? 0) > 0 ? lookupsDs!.Tables[0] : null;

            if (lookupsTable != null)
            {
                foreach (DataRow r in lookupsTable.Rows)
                {
                    var id = lookupsTable.Columns.Contains("typesID")
                        ? r["typesID"]?.ToString() : null;
                    if (string.IsNullOrWhiteSpace(id)) continue;

                    var nameAr = lookupsTable.Columns.Contains("typesName_A")
                        ? r["typesName_A"]?.ToString()?.Trim() ?? "" : "";

                    violationTypeOptions.Add(new OptionItem { Value = id, Text = nameAr });
                }
            }

            #endregion

            #region Permissions

            bool canAccess = false;
            bool canSelect = false;
            bool canAddViolation = false;
            bool canEditViolation = false;
            bool canPayViolation = false;

            if (permissionTable != null && permissionTable.Rows.Count > 0)
            {
                foreach (DataRow row in permissionTable.Rows)
                {
                    var p = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                    if (p == "ACCESS") canAccess = true;
                    if (p == "SELECT") canSelect = true;
                    if (p == "ADD_VIOLATION") canAddViolation = true;
                    if (p == "EDIT_VIOLATION") canEditViolation = true;
                    if (p == "SET_PAYMENT") canPayViolation = true;
                }
            }

            #endregion

            #region Process Grid Rows

            var rowsList = new List<Dictionary<string, object?>>();
            var columns = new List<TableColumn>();
            string rowIdField = "violationID";

            var dataTable = (dt2 != null && dt2.Rows.Count > 0) ? dt2 : dt1;

            if (dataTable != null && dataTable.Columns.Count > 0)
            {
                columns.Add(new TableColumn { Field = "violationID", Label = "رقم المخالفة", Type = "number", Sortable = true, Visible = true });
                columns.Add(new TableColumn { Field = "violationTypeName", Label = "نوع المخالفة", Type = "text", Sortable = true, Visible = true });
                columns.Add(new TableColumn { Field = "chassisNumber_FK", Label = "رقم الهيكل", Type = "text", Sortable = true, Visible = true });
                columns.Add(new TableColumn { Field = "plateDisplay", Label = "اللوحة", Type = "text", Sortable = true, Visible = true });
                columns.Add(new TableColumn { Field = "violationDate", Label = "تاريخ المخالفة", Type = "date", Sortable = true, Visible = true });
                columns.Add(new TableColumn { Field = "violationPrice", Label = "قيمة المخالفة", Type = "money", Sortable = true, Visible = true });
                columns.Add(new TableColumn { Field = "violationLocation", Label = "موقع المخالفة", Type = "text", Sortable = true, Visible = true });
                columns.Add(new TableColumn { Field = "PaymentStatusText", Label = "الحالة", Type = "text", Sortable = true, Visible = true });
                columns.Add(new TableColumn { Field = "PaymentDateText", Label = "تاريخ السداد", Type = "date", Sortable = true, Visible = true });

                foreach (DataRow r in dataTable.Rows)
                {
                    var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                    foreach (DataColumn c in dataTable.Columns)
                    {
                        var val = r[c];
                        dict[c.ColumnName] = val == DBNull.Value ? null : val;
                    }

                    string Get(string key) => dict.TryGetValue(key, out var v) ? v?.ToString() ?? "" : "";

                    var plateLetters = Get("plateLetters");
                    var plateNumbers = Get("plateNumbers");
                    var typeId = Get("violationTypeRoot_FK");

                    dict["plateDisplay"] = string.IsNullOrWhiteSpace(plateLetters) && string.IsNullOrWhiteSpace(plateNumbers)
                        ? null
                        : $"{plateLetters} {plateNumbers}".Trim();

                    dict["violationTypeName"] = violationTypeOptions.FirstOrDefault(o => o.Value == typeId)?.Text ?? typeId;

                    var isPaidStr = Get("IsPaid");
                    bool isPaid = isPaidStr == "1" || Get("PaymentDate").Length > 0;
                    dict["IsPaidFlag"] = isPaid ? "1" : "0";
                    dict["PaymentStatusText"] = isPaid ? "مدفوعة" : "غير مدفوعة";

                    var paymentDate = dict.TryGetValue("PaymentDate", out var pd) ? pd : null;
                    dict["PaymentDateText"] = NormalizeDateForInput(paymentDate) ?? "";

                    dict["p01"] = Get("violationID");
                    dict["p02"] = Get("vehicleID");
                    dict["p03"] = typeId;
                    dict["p04"] = NormalizeDateForInput(Get("violationDate"));
                    dict["p05"] = Get("violationPrice");
                    dict["p06"] = Get("violationLocation");
                    dict["p07"] = Get("PaymentDate");
                    dict["p11"] = dict["plateDisplay"];

                    rowsList.Add(dict);
                }
            }

            #endregion

            #region Form Configurations

            var currentUrl = Request.Path + Request.QueryString;

            var insertFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "ADD_VIOLATION" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },

                new FieldConfig { Name = "p01", Type = "hidden", Value = "" },
                new FieldConfig
                {
                    Name = "p02",
                    Label = "المركبة",
                    Type = "select",
                    ColCss = "12",
                    Required = true,
                    Options = vehicleOptions,
                    Select2 = true,
                    Placeholder = "ابحث برقم الجيش أو رقم الهيكل"
                },
                new FieldConfig
                {
                    Name = "p03",
                    Label = "نوع المخالفة",
                    Type = "select",
                    Options = violationTypeOptions,
                    ColCss = "6",
                    Select2 = true,
                    Required = true,
                    Placeholder = "اختر نوع المخالفة"
                },
                new FieldConfig
                {
                    Name = "p04",
                    Label = "تاريخ المخالفة",
                    Type = "date",
                    ColCss = "6",
                    Required = true
                },
                new FieldConfig
                {
                    Name = "p05",
                    Label = "قيمة المخالفة",
                    Type = "text",
                    TextMode = "money_sar",
                    Icon = "/img/Saudi_Riyal_Symbol.svg",
                    ColCss = "6",
                    MaxLength = 18
                },
                new FieldConfig
                {
                    Name = "p06",
                    Label = "موقع المخالفة",
                    Type = "text",
                    ColCss = "6",
                    MaxLength = 300
                }
            };

            var updateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "EDIT_VIOLATION" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },

                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig { Name = "p02", Type = "hidden" },

                new FieldConfig
                {
                    Name = "p03",
                    Label = "نوع المخالفة",
                    Type = "select",
                    Options = violationTypeOptions,
                    ColCss = "6",
                    Select2 = true,
                    Required = true
                },
                new FieldConfig
                {
                    Name = "p04",
                    Label = "تاريخ المخالفة",
                    Type = "date",
                    ColCss = "6",
                    Required = true
                },
                new FieldConfig
                {
                    Name = "p05",
                    Label = "قيمة المخالفة",
                    Type = "text",
                    TextMode = "money_sar",
                    Icon = "/img/Saudi_Riyal_Symbol.svg",
                    ColCss = "6",
                    MaxLength = 18
                },
                new FieldConfig
                {
                    Name = "p06",
                    Label = "موقع المخالفة",
                    Type = "text",
                    ColCss = "6",
                    MaxLength = 300
                }
            };

            var viewFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Label = "رقم المخالفة", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p03", Label = "نوع المخالفة", Type = "text", ColCss = "4", Readonly = true, MirrorName = "violationTypeName" },
                new FieldConfig { Name = "p02", Label = "رقم المركبة", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p11", Label = "اللوحة", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p04", Label = "تاريخ المخالفة", Type = "date", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p05", Label = "قيمة المخالفة", Type = "number", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p06", Label = "موقع المخالفة", Type = "textarea", ColCss = "12", Readonly = true },
                new FieldConfig { Name = "p08", Label = "الحالة", Type = "text", ColCss = "6", Readonly = true, MirrorName = "PaymentStatusText" },
                new FieldConfig { Name = "p07", Label = "تاريخ السداد", Type = "date", ColCss = "6", Readonly = true }
            };

            var paymentFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "SET_PAYMENT" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },

                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig
                {
                    Name = "p10",
                    Label = "تاريخ السداد",
                    Type = "date",
                    ColCss = "6",
                    Required = true
                },
                new FieldConfig
                {
                    Name = "p11",
                    Label = "رقم سند الصرف",
                    Type = "text",
                    ColCss = "6",
                    MaxLength = 100,
                    Required = true
                }
            };

            #endregion

            #region Toolbar

            var toolbar = new TableToolbarConfig
            {
                ShowRefresh = true,
                ShowColumns = true,
                ShowExportCsv = false,
                ShowExportExcel = true,
                ShowExportPdf = true
            };

            if (canAddViolation)
            {
                toolbar.ShowAdd = true;
                toolbar.Add = new TableAction
                {
                    Label = "إضافة مخالفة",
                    Icon = "fa fa-plus",
                    Color = "success",
                    OpenModal = true,
                    ModalTitle = "إضافة مخالفة",
                    ModalMessage = "أدخل بيانات المخالفة",
                    ModalMessageIcon = "fa-solid fa-circle-info",
                    ModalMessageClass = "bg-green-50 text-green-700",
                    OpenForm = new FormConfig
                    {
                        FormId = "InsertViolationForm",
                        Title = "إضافة مخالفة",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        SubmitText = "حفظ",
                        CancelText = "إلغاء",
                        Fields = insertFields
                    }
                };
            }

            if (canEditViolation)
            {
                toolbar.ShowEdit = true;
                toolbar.Edit = new TableAction
                {
                    Label = "تعديل",
                    Icon = "fa fa-edit",
                    Color = "primary",
                    IsEdit = true,
                    OpenModal = true,
                    ModalTitle = "تعديل مخالفة",
                    ModalMessage = "سيتم تعديل المخالفة المحددة",
                    ModalMessageIcon = "fa-solid fa-circle-info",
                    ModalMessageClass = "bg-blue-50 text-blue-700",
                    OpenForm = new FormConfig
                    {
                        FormId = "UpdateViolationForm",
                        Title = "تعديل مخالفة",
                        Method = "post",
                        ActionUrl = "/crud/update",
                        SubmitText = "حفظ",
                        CancelText = "إلغاء",
                        Fields = updateFields
                    },
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1
                };
            }

            toolbar.ShowEdit1 = true;
            toolbar.Edit1 = new TableAction
            {
                Label = "عرض",
                Icon = "fa fa-eye",
                Color = "info",
                IsEdit = true,
                OpenModal = true,
                ModalTitle = "عرض مخالفة",
                ModalMessage = "عرض فقط",
                ModalMessageIcon = "fa-solid fa-circle-info",
                ModalMessageClass = "bg-sky-100 text-sky-700",
                OpenForm = new FormConfig
                {
                    FormId = "ViewViolationForm",
                    Title = "",
                    Method = "post",
                    ActionUrl = "#",
                    SubmitText = "",
                    CancelText = "إغلاق",
                    Fields = viewFields
                },
                RequireSelection = true,
                MinSelection = 1,
                MaxSelection = 1
            };

            if (canPayViolation)
            {
                toolbar.ShowDelete = true;
                toolbar.Delete = new TableAction
                {
                    Label = "تسجيل سداد",
                    Icon = "fa fa-money-check-dollar",
                    Color = "success",
                    IsEdit = true,
                    OpenModal = true,
                    ModalTitle = "تسجيل سداد المخالفة",
                    ModalMessage = "هل أنت متأكد من تسجيل سداد المخالفة؟",
                    ModalMessageIcon = "fa fa-exclamation-triangle text-green-600",
                    ModalMessageClass = "bg-green-50 text-green-700",
                    OpenForm = new FormConfig
                    {
                        FormId = "PayViolationForm",
                        Title = "تسجيل سداد المخالفة",
                        Method = "post",
                        ActionUrl = "/crud/update",
                        SubmitText = "تأكيد السداد",
                        CancelText = "إلغاء",
                        Fields = paymentFields
                    },
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1
                };
            }

            toolbar.ShowPrint1 = true;
            toolbar.Print1 = new TableAction
            {
                Label = "طباعة تقرير",
                Icon = "fa fa-print",
                Color = "info",
                RequireSelection = false,
                OnClickJs = "sfPrintWithBusy(table, { pdf: 1, busy: { title: 'طباعة قائمة المخالفات' } });"
            };

            #endregion

            #region Style Rules

            var unpaidRule = new TableStyleRule
            {
                Target = "row", Field = "IsPaidFlag", Op = "eq", Value = "0",
                Priority = 1, PillEnabled = true,
                PillField = "PaymentStatusText", PillTextField = "PaymentStatusText",
                PillCssClass = "pill pill-yellow", PillMode = "replace"
            };

            var paidRule = new TableStyleRule
            {
                Target = "row", Field = "IsPaidFlag", Op = "eq", Value = "1",
                Priority = 1, PillEnabled = true,
                PillField = "PaymentStatusText", PillTextField = "PaymentStatusText",
                PillCssClass = "pill pill-green", PillMode = "replace"
            };

            #endregion

            #region SmartTableDsModel

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "المخالفات",
                PanelTitle = "إدارة المخالفات",
                Columns = columns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 50,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = new List<string>
                {
                    "violationID", "chassisNumber_FK", "plateDisplay",
                    "violationTypeName", "violationLocation", "PaymentStatusText"
                },
                Searchable = true,
                AllowExport = true,
                Toolbar = toolbar,
                StyleRules = new List<TableStyleRule> { unpaidRule, paidRule }
            };

            #endregion

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-solid fa-triangle-exclamation",
                TableDS = dsModel
            };

            #region Print Violations List (pdf = 1)

            if (pdf == 1)
            {
                if (rowsList.Count == 0)
                    return Content("لا توجد بيانات للطباعة.");

                var printTable = new DataTable();
                printTable.Columns.Add("violationID", typeof(string));
                printTable.Columns.Add("violationTypeName", typeof(string));
                printTable.Columns.Add("chassisNumber_FK", typeof(string));
                printTable.Columns.Add("plateDisplay", typeof(string));
                printTable.Columns.Add("violationDate", typeof(string));
                printTable.Columns.Add("violationPrice", typeof(string));
                printTable.Columns.Add("PaymentStatusText", typeof(string));

                string GetRow(Dictionary<string, object?> d, string k) =>
                    d.TryGetValue(k, out var v) ? v?.ToString() ?? "" : "";

                foreach (var r in rowsList)
                {
                    printTable.Rows.Add(
                        GetRow(r, "violationID"),
                        GetRow(r, "violationTypeName"),
                        GetRow(r, "chassisNumber_FK"),
                        GetRow(r, "plateDisplay"),
                        GetRow(r, "violationDate"),
                        GetRow(r, "violationPrice"),
                        GetRow(r, "PaymentStatusText")
                    );
                }

                var reportColumns = new List<ReportColumn>
                {
                    new("violationID", "رقم المخالفة", Align: "center", Weight: 1, FontSize: 9),
                    new("violationTypeName", "نوع المخالفة", Align: "center", Weight: 3, FontSize: 9),
                    new("chassisNumber_FK", "رقم الهيكل", Align: "center", Weight: 3, FontSize: 9),
                    new("plateDisplay", "اللوحة", Align: "center", Weight: 2, FontSize: 9),
                    new("violationDate", "تاريخ المخالفة", Align: "center", Weight: 2, FontSize: 9),
                    new("violationPrice", "قيمة المخالفة", Align: "center", Weight: 2, FontSize: 9),
                    new("PaymentStatusText", "حالة السداد", Align: "center", Weight: 2, FontSize: 9),
                };

                var logo = Path.Combine(_env.WebRootPath, "img", "ppng.png");
                var header = new Dictionary<string, string>
                {
                    ["no"] = usersId,
                    ["date"] = DateTime.Now.ToString("yyyy/MM/dd"),
                    ["attach"] = "—",
                    ["subject"] = "تقرير مخالفات المركبات",
                    ["right1"] = "المملكة العربية السعودية",
                    ["right2"] = "وزارة الدفاع",
                    ["right3"] = "القوات البرية الملكية السعودية",
                    ["right4"] = "الادارة الهندسية للتشغيل والصيانة",
                    ["right5"] = IdaraName ?? "",
                    ["midCaption"] = ""
                };

                var report = DataTableReportBuilder.FromDataTable(
                    reportId: "ViolationList",
                    title: "تقرير مخالفات المركبات",
                    table: printTable,
                    columns: reportColumns,
                    headerFields: header,
                    footerFields: new Dictionary<string, string>
                    {
                        ["تمت الطباعة بواسطة"] = FullName ?? "",
                        ["ملاحظة"] = "هذا التقرير للاستخدام الرسمي",
                        ["عدد السجلات"] = rowsList.Count.ToString(),
                        ["تاريخ ووقت الطباعة"] = DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss")
                    },
                    orientation: ReportOrientation.Landscape,
                    headerType: ReportHeaderType.LetterOfficial,
                    logoPath: logo,
                    headerRepeat: ReportHeaderRepeat.FirstPageOnly);

                var pdfBytes = QuestPdfReportRenderer.Render(report);
                Response.Headers["Content-Disposition"] = "inline; filename=ViolationList.pdf";
                return File(pdfBytes, "application/pdf");
            }

            #endregion

            return View("Page/Violation", page);
        }
    }
}
