using Microsoft.AspNetCore.Mvc;
using SmartFoundation.MVC.Reports;
using SmartFoundation.UI.ViewModels.SmartCharts;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;

namespace SmartFoundation.Mvc.Controllers.Vehicle
{
    public partial class VehicleController : Controller
    {
        [Route("Vehicle/PeriodicMaintenance")]
        public async Task<IActionResult> PeriodicMaintenance(int pdf = 0, int? rowId = null)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = "Vehicle";
            PageName = "PeriodicMaintenance";

            #region Parallel Data Loading

            var monitoringTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[] { PageName, IdaraId, usersId, HostName,
                    "LIST_MONITORING", null, null });

            var historyTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[] { PageName, IdaraId, usersId, HostName,
                    "LIST_HISTORY", 1, 10000 });

            var vehicleTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[] { "Vehicle_AvailableForPeriodic", IdaraId, usersId, HostName });

            var groupsTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[] { PageName, IdaraId, usersId, HostName,
                    "LIST_GROUPS" });

            await Task.WhenAll(monitoringTask, historyTask, vehicleTask, groupsTask);

            #endregion

            #region Permissions

            bool canAccess = false;
            bool canSelect = false;
            bool canInsertOrder = false;
            bool canUpdateOrder = false;
            bool canCloseOrder = false;
            bool canUpsertDetail = false;
            bool canDeleteDetail = false;

            DataSet dsMonitoring = monitoringTask.Result;
            SplitDataSet(dsMonitoring);

            if (permissionTable != null)
            {
                foreach (DataRow row in permissionTable.Rows)
                {
                    var p = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                    if (p == "ACCESS") canAccess = true;
                    if (p == "SELECT") canSelect = true;
                    if (p == "INSERT_PERIODIC_ORDER") canInsertOrder = true;
                    if (p == "UPDATE_PERIODIC_ORDER") canUpdateOrder = true;
                    if (p == "CLOSE_PERIODIC_ORDER") canCloseOrder = true;
                    if (p == "UPSERT_PERIODIC_DETAIL") canUpsertDetail = true;
                    if (p == "DELETE_PERIODIC_DETAIL") canDeleteDetail = true;
                }
            }

            if (!canAccess && !canSelect)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به";
                return RedirectToAction("Index", "Home");
            }

            #endregion

            try
            {

            #region Vehicle DDL

            var vehicleOptions = new List<OptionItem>();
            var armyNumberLookup = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            var vehicleGroupLookup = new Dictionary<string, Dictionary<string, object?>>(StringComparer.OrdinalIgnoreCase);

            DataSet vehicleDs = vehicleTask.Result;
            DataTable? vehicleTable = (vehicleDs?.Tables?.Count ?? 0) > 1
                ? vehicleDs!.Tables[1]
                : (vehicleDs?.Tables?.Count ?? 0) > 0 ? vehicleDs!.Tables[0] : null;

            if (vehicleTable != null)
            {
                foreach (DataRow r in vehicleTable.Rows)
                {
                    var chassis = vehicleTable.Columns.Contains("chassisNumber")
                        ? r["chassisNumber"]?.ToString() : null;
                    if (string.IsNullOrWhiteSpace(chassis)) continue;

                    var plateLetters = vehicleTable.Columns.Contains("plateLetters")
                        ? r["plateLetters"]?.ToString()?.Trim() : "";
                    var plateNumbers = vehicleTable.Columns.Contains("plateNumbers")
                        ? r["plateNumbers"]?.ToString()?.Trim() : "";
                    var plate = $"{plateLetters} {plateNumbers}".Trim();

                    var armyNum = vehicleTable.Columns.Contains("armyNumber")
                        ? r["armyNumber"]?.ToString()?.Trim() : "";
                    if (!string.IsNullOrWhiteSpace(armyNum))
                        armyNumberLookup[chassis] = armyNum;

                    var text = string.IsNullOrWhiteSpace(plate) ? chassis : $"{chassis} — {plate}";
                    vehicleOptions.Add(new OptionItem { Value = chassis, Text = text });
                }
            }

            #endregion

            #region Groups DDL

            var groupOptions = new List<OptionItem>
            {
                new OptionItem { Value = "", Text = "— اختر المجموعة —" }
            };

            DataSet groupsDs = groupsTask.Result;
            DataTable? groupsTable = (groupsDs?.Tables?.Count ?? 0) > 1 ? groupsDs!.Tables[1] : null;

            if (groupsTable != null)
            {
                foreach (DataRow r in groupsTable.Rows)
                {
                    var id = r["GroupID"]?.ToString();
                    var code = r["GroupCode"]?.ToString()?.Trim();
                    var name = r["GroupName_A"]?.ToString()?.Trim();
                    if (!string.IsNullOrEmpty(id) && !string.IsNullOrEmpty(name))
                        groupOptions.Add(new OptionItem { Value = id, Text = $"{name} ({code})" });
                }
            }

            #endregion

            #region Process Monitoring Data

            DataTable? dtMonitoring = dt1;

            DataTable dtGroupA = dtMonitoring?.Clone();
            DataTable dtGroupB = dtMonitoring?.Clone();
            DataTable dtGroupC = dtMonitoring?.Clone();
            DataTable dtUnassigned = dtMonitoring?.Clone();

            int overdueCount = 0, onTimeCount = 0, inProgressCount = 0,
                completedCount = 0, notStartedCount = 0;

            if (dtMonitoring != null)
            {
                foreach (DataRow r in dtMonitoring.Rows)
                {
                    var chassis = r["chassisNumber"]?.ToString();
                    if (string.IsNullOrWhiteSpace(chassis)) continue;

                    var status = r["statusName"]?.ToString();
                    switch (status)
                    {
                        case "متأخر": overdueCount++; break;
                        case "في الموعد": onTimeCount++; break;
                        case "جاري": inProgressCount++; break;
                        case "مكتمل": completedCount++; break;
                        case "لم يبدأ": notStartedCount++; break;
                    }

                    var groupCode = r["GroupCode"]?.ToString();
                    switch (groupCode)
                    {
                        case "A": dtGroupA?.ImportRow(r); break;
                        case "B": dtGroupB?.ImportRow(r); break;
                        case "C": dtGroupC?.ImportRow(r); break;
                        default: dtUnassigned?.ImportRow(r); break;
                    }

                    var groupId = r["GroupID"]?.ToString();
                    if (!string.IsNullOrEmpty(groupId))
                    {
                        vehicleGroupLookup[chassis] = new Dictionary<string, object?>
                        {
                            ["groupID"] = groupId,
                            ["groupCode"] = groupCode
                        };
                    }
                }
            }

            #endregion

            #region Process History

            var historyColumns = new List<TableColumn>();
            var historyRows = new List<Dictionary<string, object?>>();

            DataSet dsHistory = historyTask.Result;
            DataTable? historyTable = (dsHistory?.Tables?.Count ?? 0) > 1 ? dsHistory!.Tables[1] : dt2;

            if (historyTable != null && historyTable.Columns.Count > 0)
            {
                var historyHeaderMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                {
                    ["MaintOrdID"] = "رقم أمر الصيانة",
                    ["chassisNumber"] = "رقم الهيكل",
                    ["armyNumber"] = "الرقم العسكري",
                    ["MaintOrdStartDate"] = "تاريخ البداية",
                    ["MaintOrdEndDate"] = "تاريخ النهاية",
                    ["MaintOrdDesc"] = "الوصف",
                    ["entryDate"] = "تاريخ الإدخال",
                    ["jobOrderNumber"] = "رقم أمر العمل",
                    ["odometer"] = "عداد المركبة",
                    ["GroupCode"] = "المجموعة"
                };

                var historyHiddenFields = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
                {
                    "IdaraID_FK", "entryData", "hostName", "MaintOrdActive",
                    "MaintOrdTypeID_FK", "vehicleID", "chassisNumber_FK",
                    "plateLetters", "plateNumbers", "closeNote", "GroupName_A"
                };

                foreach (DataColumn c in historyTable.Columns)
                {
                    string colType = "text";
                    var t = c.DataType;
                    if (t == typeof(bool)) colType = "bool";
                    else if (t == typeof(DateTime)) colType = "date";
                    else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                             || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                        colType = "number";

                    historyColumns.Add(new TableColumn
                    {
                        Field = c.ColumnName,
                        Label = historyHeaderMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                        Type = colType,
                        Sortable = true,
                        Visible = !historyHiddenFields.Contains(c.ColumnName)
                    });
                }

                foreach (DataRow r in historyTable.Rows)
                {
                    var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                    foreach (DataColumn c in historyTable.Columns)
                    {
                        var val = r[c];
                        dict[c.ColumnName] = val == DBNull.Value ? null : val;
                    }
                    historyRows.Add(dict);
                }
            }

            #endregion

            #region Donut Chart

            var totalCount = overdueCount + onTimeCount + inProgressCount + completedCount + notStartedCount;

            var charts = new SmartChartsConfig
            {
                Dir = "rtl",
                Cards = new List<ChartCardConfig>
                {
                    // PeriodicMaintenance START — 5 KPI Cards matching Donut colors
                    // RTL: لم يبدأ | متأخر | جاري | في الموعد | مكتمل — Grid الـ12 عمود لا يقسم على 5،
                    // لذلك ColCss = marker فقط (pm-kpi-col) والتقسيم عبر CSS محصور بـ .page-pm (grid-template-columns: repeat(5,...)).
                    new ChartCardConfig { Id = "periodic_kpi_notstarted", Type = ChartCardType.Kpi, Title = "لم يبدأ", Icon = "fa-solid fa-hourglass-start", Tone = ChartTone.Warning, ColCss = "pm-kpi-col", ExtraCss = "pm-kpi-card pm-kpi-card--warning", Size = ChartCardSize.Sm, BigValue = notStartedCount.ToString("0"), Note = (totalCount == 0 ? "0" : (100.0 * notStartedCount / totalCount).ToString("0.#")) + "%" },
                    new ChartCardConfig { Id = "periodic_kpi_overdue", Type = ChartCardType.Kpi, Title = "متأخر", Icon = "fa-solid fa-triangle-exclamation", Tone = ChartTone.Danger, ColCss = "pm-kpi-col", ExtraCss = "pm-kpi-card pm-kpi-card--danger pm-kpi-card--attention", Size = ChartCardSize.Sm, BigValue = overdueCount.ToString("0"), Note = overdueCount > 0 ? "يتطلب إجراء • " + (totalCount == 0 ? "0" : (100.0 * overdueCount / totalCount).ToString("0.#")) + "%" : "لا توجد حالات متأخرة" },
                    new ChartCardConfig { Id = "periodic_kpi_inprogress", Type = ChartCardType.Kpi, Title = "جاري", Icon = "fa-solid fa-screwdriver-wrench", Tone = ChartTone.Info, ColCss = "pm-kpi-col", ExtraCss = "pm-kpi-card pm-kpi-card--info", Size = ChartCardSize.Sm, BigValue = inProgressCount.ToString("0"), Note = (totalCount == 0 ? "0" : (100.0 * inProgressCount / totalCount).ToString("0.#")) + "%" },
                    new ChartCardConfig { Id = "periodic_kpi_intime", Type = ChartCardType.Kpi, Title = "في الموعد", Icon = "fa-solid fa-clock", Tone = ChartTone.Success, ColCss = "pm-kpi-col", ExtraCss = "pm-kpi-card pm-kpi-card--success", Size = ChartCardSize.Sm, BigValue = onTimeCount.ToString("0"), Note = (totalCount == 0 ? "0" : (100.0 * onTimeCount / totalCount).ToString("0.#")) + "%" },
                    new ChartCardConfig { Id = "periodic_kpi_completed", Type = ChartCardType.Kpi, Title = "مكتمل", Icon = "fa-solid fa-circle-check", Tone = ChartTone.Neutral, ColCss = "pm-kpi-col", ExtraCss = "pm-kpi-card pm-kpi-card--neutral", Size = ChartCardSize.Sm, BigValue = completedCount.ToString("0"), Note = (totalCount == 0 ? "0" : (100.0 * completedCount / totalCount).ToString("0.#")) + "%" },
                    // PeriodicMaintenance END
                    new ChartCardConfig
                    {
                        Id = "periodic_status_donut",
                        Type = ChartCardType.Donut,
                        Title = "توزيع حالة الصيانة الدورية",
                        ColCss = "col-span-12",
                        ExtraCss = "pm-status-donut-card",
                        Dir = "rtl",
                        DonutMode = "donut",
                        DonutThickness = 0.34m,
                        DonutShowLegend = true,
                        DonutShowCenterText = true,
                        DonutValueFormat = "0",
                        IsEmpty = totalCount == 0,
                        EmptyMessage = "لا توجد مركبات مسجلة",
                        Slices = new List<DonutSlice>
                        {
                            new DonutSlice { Label = "لم يبدأ",   Value = notStartedCount, Color = "#f59e0b" },
                            new DonutSlice { Label = "متأخر",     Value = overdueCount,    Color = "#ef4444" },
                            new DonutSlice { Label = "جاري",      Value = inProgressCount, Color = "#3b82f6" },
                            new DonutSlice { Label = "في الموعد", Value = onTimeCount,    Color = "#22c55e" },
                            new DonutSlice { Label = "مكتمل",     Value = completedCount,  Color = "#6b7280" }
                        }
                    }
                    // PeriodicMaintenance END
                }
            };

            #endregion

            #region Forms

            var currentUrl = Request.Path + Request.QueryString;

            var addOrderFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT_PERIODIC_ORDER" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },

                new FieldConfig { Name = "p01", Label = "المركبة",  Type = "select", ColCss = "4", Required = true, Options = vehicleOptions, Select2 = true, OnChangeJs = "sfSetArmyNumber(this)" },
                new FieldConfig { Name = "armyNumber_display", Label = "الرقم العسكري", Type = "", ColCss = "4", Readonly = true, Placeholder = "دحماس 999", HelpText = "ادخال 10 ارقام" },
                new FieldConfig { Name = "p02", Label = "مجموعة الصيانة", Type = "select", ColCss = "4", Required = true, Options = groupOptions, Select2 = true },
                new FieldConfig { Name = "p03", Label = "ملاحظات", Type = "textarea", ColCss = "12" }
            };

            var updateOrderFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATE_PERIODIC_ORDER" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },

                new FieldConfig { Name = "p01", Label = "رقم أمر الصيانة", Type = "hidden" },
                new FieldConfig { Name = "p02", Label = "رقم الهيكل", Type = "hidden" },
                new FieldConfig { Name = "armyNumber_display", Label = "الرقم العسكري", Type = "text", ColCss = "6", Readonly = true },
                new FieldConfig { Name = "p03", Label = "تاريخ البداية", Type = "date", ColCss = "6" },
                new FieldConfig { Name = "p04", Label = "تاريخ النهاية", Type = "date", ColCss = "6" },
                new FieldConfig { Name = "p05", Label = "ملاحظات", Type = "textarea", ColCss = "12" }
            };

            var closeOrderFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "CLOSE_PERIODIC_ORDER" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },

                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig { Name = "p02", Label = "تاريخ الإغلاق", Type = "date", ColCss = "6", Required = true, Value = DateTime.Today.ToString("yyyy-MM-dd") },
                new FieldConfig { Name = "p03", Label = "عداد المركبة", Type = "number", ColCss = "6" },
                new FieldConfig { Name = "p04", Type = "hidden" }
            };

            // PeriodicMaintenance START — Move Group modal fields
            var moveGroupFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "MOVE_GROUP" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig { Name = "currentGroup_display", Label = "المجموعة الحالية", Type = "text", ColCss = "6", Readonly = true },
                new FieldConfig { Name = "p02", Label = "المجموعة الجديدة", Type = "select", ColCss = "6", Required = true, Options = groupOptions, Select2 = true }
            };
            // PeriodicMaintenance END

            #endregion

            #region Monitoring Columns

            var monitoringHeaderMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["chassisNumber"] = "رقم الهيكل",
                ["armyNumber"] = "الرقم العسكري",
                ["vehicleDesc"] = "المركبة",
                ["lastMaintenanceDate"] = "آخر صيانة",
                ["lastJobOrderNumber"] = "رقم أمر العمل",
                ["statusName"] = "الحالة",
                ["openOrderID"] = "أمر مفتوح"
            };

            var monitoringVisibleFields = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "vehicleDesc", "armyNumber", "lastMaintenanceDate", "lastJobOrderNumber", "statusName"
            };

            List<TableColumn> BuildMonitoringColumns()
            {
                var cols = new List<TableColumn>();
                foreach (var kvp in monitoringHeaderMap)
                {
                    if (!monitoringVisibleFields.Contains(kvp.Key)) continue;
                    var isDate = kvp.Key.IndexOf("Date", StringComparison.OrdinalIgnoreCase) >= 0
                                 && kvp.Key != "lastMaintenanceDate";
                    cols.Add(new TableColumn
                    {
                        Field = kvp.Key,
                        Label = kvp.Value,
                        Type = isDate ? "date" : "text",
                        Sortable = true,
                        Visible = true
                    });
                }
                return cols;
            }

            List<Dictionary<string, object?>> BuildMonitoringRows(DataTable? source)
            {
                var rows = new List<Dictionary<string, object?>>();
                if (source == null) return rows;

                foreach (DataRow r in source.Rows)
                {
                    var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                    foreach (DataColumn c in source.Columns)
                    {
                        var val = r[c];
                        dict[c.ColumnName] = val == DBNull.Value ? null : val;
                    }

                    dict["p01"] = dict.TryGetValue("openOrderID", out var oid) ? oid : null;
                    dict["p02"] = dict.TryGetValue("chassisNumber", out var ch) ? ch : null;
                    dict["p03"] = null;
                    dict["p04"] = null;
                    dict["p05"] = null;
                    dict["armyNumber_display"] = dict.TryGetValue("armyNumber", out var an) ? an : null;

                    rows.Add(dict);
                }
                return rows;
            }

            #endregion

            #region Toolbar Actions

            List<TableStyleRule> GetStatusStyleRules() => new()
            {
                new TableStyleRule
                {
                    Target = "row", Field = "statusName", Op = "eq", Value = "متأخر",
                    Priority = 1, PillEnabled = true,
                    PillField = "statusName", PillTextField = "statusName",
                    PillCssClass = "pill pill-red", PillMode = "replace"
                },
                new TableStyleRule
                {
                    Target = "row", Field = "statusName", Op = "eq", Value = "في الموعد",
                    Priority = 1, PillEnabled = true,
                    PillField = "statusName", PillTextField = "statusName",
                    PillCssClass = "pill pill-green", PillMode = "replace"
                },
                new TableStyleRule
                {
                    Target = "row", Field = "statusName", Op = "eq", Value = "جاري",
                    Priority = 1, PillEnabled = true,
                    PillField = "statusName", PillTextField = "statusName",
                    PillCssClass = "pill pill-blue", PillMode = "replace"
                },
                new TableStyleRule
                {
                    Target = "row", Field = "statusName", Op = "eq", Value = "مكتمل",
                    Priority = 1, PillEnabled = true,
                    PillField = "statusName", PillTextField = "statusName",
                    PillCssClass = "pill pill-gray", PillMode = "replace"
                },
                new TableStyleRule
                {
                    Target = "row", Field = "statusName", Op = "eq", Value = "لم يبدأ",
                    Priority = 1, PillEnabled = true,
                    PillField = "statusName", PillTextField = "statusName",
                    PillCssClass = "pill pill-yellow", PillMode = "replace"
                },
                new TableStyleRule
                {
                    Target = "cell", Field = "GroupCode", Op = "eq", Value = "A",
                    Priority = 2, PillEnabled = true,
                    PillField = "GroupCode", PillTextField = "GroupCode",
                    PillCssClass = "pill pill-blue", PillMode = "replace"
                },
                new TableStyleRule
                {
                    Target = "cell", Field = "GroupCode", Op = "eq", Value = "B",
                    Priority = 2, PillEnabled = true,
                    PillField = "GroupCode", PillTextField = "GroupCode",
                    PillCssClass = "pill pill-green", PillMode = "replace"
                },
                new TableStyleRule
                {
                    Target = "cell", Field = "GroupCode", Op = "eq", Value = "C",
                    Priority = 2, PillEnabled = true,
                    PillField = "GroupCode", PillTextField = "GroupCode",
                    PillCssClass = "pill pill-yellow", PillMode = "replace"
                }
            };

            TableToolbarConfig BuildMonitoringToolbar()
            {
                var tb = new TableToolbarConfig
                {
                    ShowRefresh = true,
                    ShowColumns = true,
                    ShowPrint = true
                };

                if (canInsertOrder)
                {
                    tb.ShowAdd = true;
                    tb.Add = new TableAction
                    {
                        Label = "إضافة أمر صيانة دورية",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إدخال أمر صيانة دورية",
                        OpenForm = new FormConfig
                        {
                            FormId = "periodicInsertForm",
                            Title = "إدخال أمر صيانة دورية",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addOrderFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "button", Color = "success", OnClickJs = "sfSubmitPeriodicInsert(this)" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    };
                }

                if (canUpdateOrder)
                {
                    tb.ShowEdit = true;
                    tb.Edit = new TableAction
                    {
                        Label = "تعديل أمر صيانة",
                        Icon = "fa-pen-to-square",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل أمر صيانة دورية",
                        OpenForm = new FormConfig
                        {
                            FormId = "periodicEditForm",
                            Title = "تعديل أمر صيانة دورية",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Fields = updateOrderFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    };
                }

                if (canCloseOrder)
                {
                    tb.ShowEdit1 = true;
                    tb.Edit1 = new TableAction
                    {
                        Label = "إغلاق أمر صيانة",
                        Icon = "fa fa-lock",
                        Color = "warning",
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                        OnClickJs = "sfOpenClosePeriodicModal",
                        OpenForm = new FormConfig
                        {
                            FormId = "periodicCloseForm",
                            Title = "إغلاق أمر صيانة دورية",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Fields = closeOrderFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "إغلاق الأمر", Type = "button", Color = "warning", OnClickJs = "sfSubmitCloseChecklist(this)" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    };
                }

                // PeriodicMaintenance START — Move Group toolbar action
                if (canUpdateOrder)
                {
                    tb.ShowAdd2 = true;
                    tb.Add2 = new TableAction
                    {
                        Label = "نقل مجموعة المركبة",
                        Icon = "fa fa-exchange-alt",
                        Color = "secondary",
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                        OnClickJs = "sfOpenMoveGroupModal",
                        OpenForm = new FormConfig
                        {
                            FormId = "periodicMoveGroupForm",
                            Title = "نقل مجموعة المركبة",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Fields = moveGroupFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "تأكيد النقل", Type = "button", Color = "success", OnClickJs = "sfSubmitMoveGroup(this)" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    };
                }
                // PeriodicMaintenance END

                return tb;
            }

            #endregion

            #region Build Tabs

            var monitoringCols = BuildMonitoringColumns();
            var monitoringToolbar = BuildMonitoringToolbar();
            var styleRules = GetStatusStyleRules();

            var tabGroupA = new SmartTableDsModel
            {
                RenderMode = SmartTableRenderMode.Tab,
                RenderAsTab = true,
                TabGroupKey = "periodic-monitoring",
                TabKey = "group-a",
                TabLabel = "المجموعة أ",
                ShowTabCount = true,
                Columns = monitoringCols,
                Rows = BuildMonitoringRows(dtGroupA),
                RowIdField = "chassisNumber",
                PageSize = 50,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                Searchable = true,
                AllowExport = true,
                PanelTitle = "المركبات — المجموعة أ",
                Toolbar = monitoringToolbar,
                StyleRules = styleRules
            };

            var tabGroupB = new SmartTableDsModel
            {
                RenderMode = SmartTableRenderMode.Tab,
                RenderAsTab = true,
                TabGroupKey = "periodic-monitoring",
                TabKey = "group-b",
                TabLabel = "المجموعة ب",
                ShowTabCount = true,
                Columns = monitoringCols,
                Rows = BuildMonitoringRows(dtGroupB),
                RowIdField = "chassisNumber",
                PageSize = 50,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                Searchable = true,
                AllowExport = true,
                PanelTitle = "المركبات — المجموعة ب",
                Toolbar = monitoringToolbar,
                StyleRules = styleRules
            };

            var tabGroupC = new SmartTableDsModel
            {
                RenderMode = SmartTableRenderMode.Tab,
                RenderAsTab = true,
                TabGroupKey = "periodic-monitoring",
                TabKey = "group-c",
                TabLabel = "المجموعة ج",
                ShowTabCount = true,
                Columns = monitoringCols,
                Rows = BuildMonitoringRows(dtGroupC),
                RowIdField = "chassisNumber",
                PageSize = 50,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                Searchable = true,
                AllowExport = true,
                PanelTitle = "المركبات — المجموعة ج",
                Toolbar = monitoringToolbar,
                StyleRules = styleRules
            };

            var tabAll = new SmartTableDsModel
            {
                RenderMode = SmartTableRenderMode.Tab,
                RenderAsTab = true,
                TabGroupKey = "periodic-monitoring",
                TabKey = "all",
                TabLabel = "الكل",
                ShowTabCount = true,
                Columns = monitoringCols,
                Rows = BuildMonitoringRows(dtMonitoring),
                RowIdField = "chassisNumber",
                PageSize = 50,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                Searchable = true,
                AllowExport = true,
                PanelTitle = "جميع المركبات",
                Toolbar = monitoringToolbar,
                StyleRules = styleRules
            };

            var tabUnassigned = new SmartTableDsModel
            {
                RenderMode = SmartTableRenderMode.Tab,
                RenderAsTab = true,
                TabGroupKey = "periodic-monitoring",
                TabKey = "unassigned",
                TabLabel = "غير معينة",
                ShowTabCount = true,
                Columns = monitoringCols,
                Rows = BuildMonitoringRows(dtUnassigned),
                RowIdField = "chassisNumber",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                Searchable = true,
                AllowExport = true,
                PanelTitle = "مركبات غير معينة لمجموعة"
            };

            var historyGroupStyleRules = new List<TableStyleRule>
            {
                new TableStyleRule
                {
                    Target = "row", Field = "GroupCode", Op = "eq", Value = "A",
                    Priority = 2, PillEnabled = true,
                    PillField = "GroupCode", PillTextField = "GroupCode",
                    PillCssClass = "pill pill-blue", PillMode = "replace"
                },
                new TableStyleRule
                {
                    Target = "row", Field = "GroupCode", Op = "eq", Value = "B",
                    Priority = 2, PillEnabled = true,
                    PillField = "GroupCode", PillTextField = "GroupCode",
                    PillCssClass = "pill pill-green", PillMode = "replace"
                },
                new TableStyleRule
                {
                    Target = "row", Field = "GroupCode", Op = "eq", Value = "C",
                    Priority = 2, PillEnabled = true,
                    PillField = "GroupCode", PillTextField = "GroupCode",
                    PillCssClass = "pill pill-yellow", PillMode = "replace"
                }
            };

            var historyToolbar = new TableToolbarConfig
            {
                ShowPrint = true,
                ShowPrint1 = true,
                Print1 = new TableAction
                {
                    Label = "طباعة نموذج الصيانة",
                    Icon = "fa fa-print",
                    Color = "info",
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    OnClickJs = @"
                        const selectedRows = table.getSelectedRows();
                        if (selectedRows.length === 1) {
                            const row = selectedRows[0];
                            const rowId = row.MaintOrdID || row.p01;
                            if (!rowId) { alert('خطأ'); return; }
                            sfPrintWithBusy(table, {
                                pdf: 2,
                                extraParams: { rowId: rowId },
                                busy: { title: 'طباعة نموذج تفتيش وصيانة المعدات' }
                            });
                        }
                    "
                }
            };

            var tabHistory = new SmartTableDsModel
            {
                RenderMode = SmartTableRenderMode.Tab,
                TabGroupKey = "periodic-monitoring",
                TabKey = "history",
                TabLabel = "السجل",
                ShowTabCount = true,
                Columns = historyColumns,
                Rows = historyRows,
                RowIdField = "MaintOrdID",
                PageSize = 50,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                Searchable = true,
                AllowExport = true,
                Toolbar = historyToolbar,
                StyleRules = historyGroupStyleRules
            };

            #endregion

            ViewData["ArmyNumberLookup"] = System.Text.Json.JsonSerializer.Serialize(armyNumberLookup);
            ViewData["VehicleGroupLookup"] = System.Text.Json.JsonSerializer.Serialize(vehicleGroupLookup);

            var page = new SmartPageViewModel
            {
                PageTitle = "الصيانة الدورية",
                PanelTitle = "متابعة الصيانة الدورية",
                PanelIcon = "fa-solid fa-wrench",
                Charts = charts,
                TableDS = tabGroupA,
                TableDS1 = tabGroupB,
                TableDS2 = tabGroupC,
                TableDS3 = tabAll,
                TableDS4 = tabUnassigned,
                TableDS5 = tabHistory
            };

            #region Print Worksheet (pdf = 2)

            if (pdf == 2)
            {
                if (!rowId.HasValue)
                    return Content("خطأ: لم يتم استلام معرف أمر الصيانة");

                var selectedRow = historyRows.FirstOrDefault(r =>
                    r.TryGetValue("MaintOrdID", out var id) &&
                    id != null && Convert.ToInt32(id) == rowId.Value);

                if (selectedRow == null)
                    return Content($"لم يتم العثور على البيانات المطلوبة. معرف أمر الصيانة: {rowId}");

                string jobOrderNumber = selectedRow.GetValueOrDefault("jobOrderNumber")?.ToString() ?? "";
                string plateLetters = selectedRow.GetValueOrDefault("plateLetters")?.ToString() ?? "";
                string plateNumbers = selectedRow.GetValueOrDefault("plateNumbers")?.ToString() ?? "";
                string armyNumber = selectedRow.GetValueOrDefault("armyNumber")?.ToString() ?? "";

                string vehicleDesc = selectedRow.GetValueOrDefault("vehicleDesc")?.ToString()
                    ?? $"{plateLetters} {plateNumbers}".Trim();

                DateTime? startDate = selectedRow.GetValueOrDefault("MaintOrdStartDate") as DateTime?;
                string startDateStr = startDate?.ToString("yyyy/MM/dd") ?? "";

                string groupCode = selectedRow.GetValueOrDefault("GroupCode")?.ToString() ?? "";

                var detailDs = await _mastersServies.GetDataLoadDataSetAsync(
                    new object?[] { "PeriodicMaintenance", IdaraId, usersId, HostName, "LIST_DETAILS", rowId.Value });

                DataTable? detailDataTable = (detailDs?.Tables?.Count ?? 0) > 1 ? detailDs!.Tables[1] : null;

                var checklistItems = new List<(string itemText, string correctiveAction)>();

                if (detailDataTable != null)
                {
                    foreach (DataRow dr in detailDataTable.Rows)
                    {
                        string itemNameA = dr.Table.Columns.Contains("itemName")
                            ? dr["itemName"]?.ToString() ?? ""
                            : "";

                        string itemNameE = dr.Table.Columns.Contains("itemName_E")
                            ? dr["itemName_E"]?.ToString() ?? ""
                            : "";

                        string correctiveAction = dr.Table.Columns.Contains("CorrectiveAction")
                            ? dr["CorrectiveAction"]?.ToString() ?? ""
                            : "";

                        string notes = dr.Table.Columns.Contains("Notes")
                            ? dr["Notes"]?.ToString() ?? ""
                            : "";

                        string itemText =
                            !string.IsNullOrWhiteSpace(itemNameA) && !string.IsNullOrWhiteSpace(itemNameE)
                                ? $"{itemNameA}\n{itemNameE}"
                                : !string.IsNullOrWhiteSpace(itemNameA)
                                    ? itemNameA
                                    : itemNameE;

                        if (itemNameA.Contains("قراءة العداد")) continue;

                        checklistItems.Add((itemText, string.IsNullOrWhiteSpace(correctiveAction) ? notes : correctiveAction));
                    }
                }

                LetterTableCell H(string ar, string en, int span = 1, float size = 6.2f) => new LetterTableCell
                {
                    Text = $"{ar}\n{en}",
                    Bold = true,
                    Align = TextAlign.Center,
                    BackgroundColor = "#FFFFFF",
                    FontSize = size,
                    ColumnSpan = span
                };

                LetterTableCell V(string text = "", int span = 1, TextAlign align = TextAlign.Center, float size = 6.8f) => new LetterTableCell
                {
                    Text = text ?? "",
                    Bold = false,
                    Align = align,
                    BackgroundColor = "#FFFFFF",
                    FontSize = size,
                    ColumnSpan = span
                };

                LetterTableCell R(string text, int span = 1, float size = 6.2f) => new LetterTableCell
                {
                    Text = text,
                    Bold = true,
                    Align = TextAlign.Right,
                    BackgroundColor = "#FFFFFF",
                    FontSize = size,
                    ColumnSpan = span
                };

                var worksheet = ReportTableFactory.CreateOfficialTable(
                    new List<float> { 1.5f, 1.0f, 2.0f, 2.2f, 2.2f, 1.4f, 2.4f, 2.4f, 2.2f, 4.1f, 4.4f, 4.4f }
                );

                worksheet.ExtendVertical = false;
                worksheet.BorderWidth = 1.0f;
                worksheet.BorderColor = "#000000";
                worksheet.CellPadding = 1.15f;
                worksheet.MinRowHeight = 30f;

                worksheet.Rows.Add(new LetterTableRow
                {
                    Cells = new()
                    {
                        H("١- الوحدة", "UNIT", 2),
                        H("٢- التسمية والموديل", "NOMENCLATURE & MODEL", 5),
                        H("٣- رقم أمر العمل", "JOB ORDER NO.", 5)
                    }
                });

                worksheet.Rows.Add(new LetterTableRow
                {
                    Cells = new()
                    {
                        V("60-60", 2, TextAlign.Center, 7f),
                        V(vehicleDesc, 5, TextAlign.Center, 7f),
                        V(jobOrderNumber, 5, TextAlign.Center, 7f)
                    }
                });

                worksheet.Rows.Add(new LetterTableRow
                {
                    Cells = new()
                    {
                        H("٤- نوع التفتيش", "TYPE INSPECTION", 2),
                        H("٥- التاريخ", "DATE", 2),
                        H("٦- عدد الطلقات", "ROUND FIRED", 2),
                        H("٧- الساعات", "HOURS", 2),
                        H("٨- الأميال", "MILES", 1),
                        H("٩- رقم التخزين / التسجيل / التسلسل", "REGISTRATION / SERIAL / FSN", 3)
                    }
                });

                worksheet.Rows.Add(new LetterTableRow
                {
                    Cells = new()
                    {
                        V("دورية", 2, TextAlign.Center, 7f),
                        V(startDateStr, 2, TextAlign.Center, 7f),
                        V("", 2),
                        V("", 2),
                        V("", 1),
                        V(armyNumber, 3, TextAlign.Center, 7f)
                    }
                });

                worksheet.Rows.Add(new LetterTableRow
                {
                    Cells = new()
                    {
                        H("١٠- المرجع المناسب", "APPLICABLE REFERENCE", 3),
                        R("تاريخ الكراسة الفنية:\nTM DATE:", 6, 6.2f),
                        H("١١- عدد ساعات الإصلاح", "MANHOURS", 3)
                    }
                });

                worksheet.Rows.Add(new LetterTableRow
                {
                    Cells = new()
                    {
                        V("", 3),
                        R("رقم الكراسة الفنية:\nTM NUMBER:", 6, 6.2f),
                        V("", 3)
                    }
                });

                worksheet.Rows.Add(new LetterTableRow
                {
                    Cells = new()
                    {
                        H("١٢- تاريخ الانتهاء من الإصلاح", "COMPLETION DATE", 2),
                        H("١٣- توقيع المشرف على الصيانة", "SIG. MAINT. SUPERVISOR", 4),
                        H("١٤- توقيع الذين قاموا بالتفتيش الأولي", "SIG. INITIAL INSP.", 3, 6.6f),
                        H("١٥- توقيع الذين قاموا بالتفتيش النهائي", "SIG. FINAL INSP.", 3)
                    }
                });

                worksheet.Rows.Add(new LetterTableRow
                {
                    Cells = new()
                    {
                        V("\n\n", 2),
                        V("رئيس الرقباء\nمنصور مشبب آل زهر\n\n", 4, TextAlign.Center, 7f),
                        V("الموظف م8\nياسر سعد القحطاني\n\n", 3, TextAlign.Center, 7f),
                        V("\n\n", 3)
                    }
                });

                worksheet.Rows.Add(new LetterTableRow
                {
                    Cells = new()
                    {
                        H("١٦- رقم وتوقيع من قام بالإصلاح", "INITIAL WHEN CORRECTED", 2, 5.5f),
                        H("١٧- الأعطال والقصور", "DEFICIENCIES & SHORTCOMINGS", 4, 6f),
                        H("١٨- الإجراء التصحيحي", "CORRECTIVE ACTION", 3, 6f),
                        H("١٩- رقم التخزين الفيدرالي للقطعة", "FSN", 2, 5.5f),
                        H("٢٠- مستوى خط الإصلاح", "MAINT. LEVEL", 1, 5.5f)
                    }
                });

                int itemRows = Math.Max(15, checklistItems.Count);

                for (int i = 0; i < itemRows; i++)
                {
                    string itemText = i < checklistItems.Count ? checklistItems[i].itemText : "";
                    string actionText = i < checklistItems.Count ? checklistItems[i].correctiveAction : "";

                    string initialLabel = i switch
                    {
                        0 => "الاسم\nNAME",
                        1 => "الرقم\nJOB ID",
                        2 => "التوقيع\nSIG",
                        _ => ""
                    };

                    worksheet.Rows.Add(new LetterTableRow
                    {
                        ExtendVertical = false,
                        MinRowHeight = 27f,
                        Cells = new()
                        {
                            V(initialLabel, 1, TextAlign.Center, 5.8f),
                            V("", 1, TextAlign.Center, 5.8f),
                            V(itemText, 4, TextAlign.Right, 6.5f),
                            V(actionText, 3, TextAlign.Right, 6.5f),
                            V("", 2, TextAlign.Center, 6.5f),
                            V("", 1, TextAlign.Center, 6.5f)
                        }
                    });
                }

                var reportBlocks = new List<LetterBlock>
                {
                    !string.IsNullOrWhiteSpace(groupCode)
                        ? LetterBlockFactory.TextBlock(
                            groupCode,
                            fontSize: 12f,
                            bold: true,
                            align: TextAlign.Left,
                            paddingTop: 0,
                            paddingBottom: 0)
                        : LetterBlockFactory.Spacer(0),

                    LetterBlockFactory.TextBlock(
                        "نموذج تفتيش وصيانة المعدات (كراسة القوات البرية الفنية رقم ٣٨-٧٥٠)",
                        fontSize: 8.6f,
                        bold: true,
                        align: TextAlign.Center,
                        paddingTop: 0,
                        paddingBottom: 0),

                    LetterBlockFactory.TextBlock(
                        "EQUIPMENT INSPECTION & MAINTENANCE WORKSHEET (SAATM 38 - 750)",
                        fontSize: 6.7f,
                        bold: true,
                        align: TextAlign.Center,
                        paddingTop: 0,
                        paddingBottom: 2),

                    LetterBlockFactory.TableBlock(
                        worksheet,
                        paddingTop: 4,
                        paddingBottom: 0,
                        paddingRight: 0,
                        paddingLeft: 0),

                    LetterBlockFactory.FooterBlock(
                        right: "نموذج القوات البرية رقم 2404",
                        center: "مطبعة سلاح الصيانة",
                        left: "LAND FORCES FORM 2404",
                        fontSize: 6.3f,
                        paddingTop: 3)
                };

                var report = new ReportResult
                {
                    ReportId = "PeriodicMaintenanceWorksheet",
                    Title = "",
                    Kind = ReportKind.Letter,
                    Orientation = ReportOrientation.Portrait,
                    HeaderType = ReportHeaderType.Standard,
                    HeaderFields = new Dictionary<string, string>(),
                    ShowFooter = false,
                    LetterBlocks = reportBlocks
                };

                var pdfBytes = QuestPdfReportRenderer.Render(report);
                Response.Headers["Content-Disposition"] = "inline; filename=PeriodicMaintenanceWorksheet.pdf";
                return File(pdfBytes, "application/pdf");
            }

            #endregion

            return View("Page/PeriodicMaintenance", page);
            }
            catch (Exception ex)
            {
                TempData["Error"] = ex.Message;
                return RedirectToAction("Index", "Home");
            }
        }

        [Route("Vehicle/GetPeriodicDetails")]
        public async Task<IActionResult> GetPeriodicDetails(int maintOrdID)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            var ds = await _mastersServies.GetDataLoadDataSetAsync(
                new object?[] { "PeriodicMaintenance", IdaraId, usersId, HostName,
                    "LIST_DETAILS", maintOrdID });

            DataTable? detailTable = (ds?.Tables?.Count ?? 0) > 1 ? ds!.Tables[1] : dt1;

            var rows = new List<Dictionary<string, object?>>();

            if (detailTable != null)
            {
                foreach (DataRow r in detailTable.Rows)
                {
                    var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                    foreach (DataColumn c in detailTable.Columns)
                    {
                        var val = r[c];
                        dict[c.ColumnName] = val == DBNull.Value ? null : val;
                    }
                    rows.Add(dict);
                }
            }

            return Json(new { success = true, items = rows });
        }
    }
}
