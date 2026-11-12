using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using SmartFoundation.UI.ViewModels.SmartDynamicFields;
using System.Data;
using System.Linq;
using SmartFoundation.MVC.Reports;

namespace SmartFoundation.Mvc.Controllers.Vehicle
{
    public partial class VehicleController : Controller
    {
        [Route("Vehicle/GeneralMaintenance")]
        public async Task<IActionResult> GeneralMaintenance(int pdf = 0, int? rowId = null)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = "Vehicle";
            PageName = "GeneralMaintenance";

            #region Parallel Data Loading

            var activeOrdersTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[] { PageName, IdaraId, usersId, HostName,
                    "LIST_ORDERS", null, null, 266, null, 1,
                    null, null, 1, 10000, null });

            var historyOrdersTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[] { PageName, IdaraId, usersId, HostName,
                    "LIST_ORDERS", null, null, 266, null, 0,
                    null, null, 1, 10000, null });

            var vehicleTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[] { "Vehicle_Search", IdaraId, usersId, HostName, "%" });

            await Task.WhenAll(activeOrdersTask, historyOrdersTask, vehicleTask);

            #endregion

            #region Vehicle DDL

            var vehicleOptions = new List<OptionItem>();
            var armyNumberLookup = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            DataSet vehicleDs = await vehicleTask;
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

            #region Workshop Options

            var workshopOptions = new List<(string id, string name)>();
            var workshopLookup = new Dictionary<string, string>();

            try
            {
                var wsDs = await _mastersServies.GetDataLoadDataSetAsync(
                    new object?[] { "GeneralMaintenance", IdaraId, usersId, HostName, "LIST_WORKSHOPS" });

                DataTable? wsTable = (wsDs?.Tables?.Count ?? 0) > 1 ? wsDs!.Tables[1] : null;
                if (wsTable != null)
                {
                    foreach (DataRow r in wsTable.Rows)
                    {
                        string id = r["typesID"]?.ToString() ?? "";
                        string name = r["typesName_A"]?.ToString() ?? "";
                        if (!string.IsNullOrEmpty(id))
                        {
                            workshopOptions.Add((id, name));
                            workshopLookup[id] = name;
                        }
                    }
                }
            }
            catch { }

            #endregion

            #region Visible Fields

            var activeVisibleFields = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "jobOrderNumber", "armyNumber", "MaintOrdStartDate",
                "faultSummary", "orderStatus"
            };

            var historyVisibleFields = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "jobOrderNumber", "armyNumber", "MaintOrdStartDate", "MaintOrdEndDate",
                "faultSummary", "correctiveSummary", "workshopNames", "orderStatus"
            };

            var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["armyNumber"] = "الرقم العسكري",
                ["MaintOrdStartDate"] = "تاريخ البداية",
                ["MaintOrdEndDate"] = "تاريخ النهاية",
                ["jobOrderNumber"] = "رقم أمر العمل",
                ["faultSummary"] = "الأعطال والقصور",
                ["correctiveSummary"] = "الإجراء التصحيحي",
                ["workshopNames"] = "الورش",
                ["orderStatus"] = "الحالة"
            };

            List<TableColumn> BuildColumns(DataTable data, HashSet<string> fields)
            {
                var cols = new List<TableColumn>();
                foreach (DataColumn c in data.Columns)
                {
                    if (!fields.Contains(c.ColumnName)) continue;

                    cols.Add(new TableColumn
                    {
                        Field = c.ColumnName,
                        Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });
                }

                foreach (var fieldName in fields)
                {
                    if (cols.Any(c => c.Field.Equals(fieldName, StringComparison.OrdinalIgnoreCase))) continue;
                    if (!data.Columns.Contains(fieldName))
                    {
                        cols.Add(new TableColumn
                        {
                            Field = fieldName,
                            Label = headerMap.TryGetValue(fieldName, out var label) ? label : fieldName,
                            Type = "text",
                            Sortable = true,
                            Visible = true
                        });
                    }
                }

                return cols;
            }

            string TruncateAtWord(string text, int maxLength)
            {
                if (string.IsNullOrEmpty(text) || text.Length <= maxLength) return text;
                var spaceIdx = text.LastIndexOf(' ', maxLength);
                return spaceIdx > 0 ? text.Substring(0, spaceIdx) : text.Substring(0, maxLength);
            }

            #endregion

            #region Process Active Orders (Tab 1)

            bool canAccess = false;
            bool canSelect = false;
            bool canInsertOrder = false;
            bool canUpdateOrder = false;
            bool canCloseOrder = false;

            var orderRows = new List<Dictionary<string, object?>>();
            List<TableColumn> orderColumns = new();

            DataSet ds = await activeOrdersTask;
            SplitDataSet(ds);

            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable != null && permissionTable.Rows.Count > 0)
                {
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var p = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                        if (p == "ACCESS") canAccess = true;
                        if (p == "SELECT") canSelect = true;
                        if (p == "INSERT_GENERAL_ORDER") canInsertOrder = true;
                        if (p == "UPDATE_GENERAL_ORDER") canUpdateOrder = true;
                        if (p == "CLOSE_GENERAL_ORDER") canCloseOrder = true;
                    }

                    if (!canAccess && !canSelect)
                    {
                        TempData["Error"] = "تم رصد دخول غير مصرح به";
                        return RedirectToAction("Index", "Home");
                    }

                    DataTable? orderData = dt1;

                    if (orderData != null && orderData.Columns.Count > 0)
                    {
                        orderColumns = BuildColumns(orderData, activeVisibleFields);

                        foreach (DataRow r in orderData.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in orderData.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;

                            dict["p01"] = Get("MaintOrdID");
                            dict["p02"] = Get("chassisNumber_FK") ?? Get("chassisNumber");
                            dict["p03"] = NormalizeDateForInput(Get("MaintOrdStartDate"));
                            dict["p04"] = NormalizeDateForInput(Get("MaintOrdEndDate"));
                            dict["p05"] = Get("MaintOrdDesc");
                            dict["p06"] = Get("closeNote");
                            dict["armyNumber"] = Get("armyNumber");
                            dict["armyNumber_display"] = Get("armyNumber");

                            dict["orderStatus"] = Get("MaintOrdActive") is bool b && b
                                || Get("MaintOrdActive")?.ToString()?.Trim() == "1"
                                || Get("MaintOrdActive")?.ToString()?.Trim().Equals("true", StringComparison.OrdinalIgnoreCase) == true
                                ? "نشط" : "مكتمل";

                            var faultDesc = Get("faultSummary")?.ToString()?.Trim() ?? "";
                            if (string.IsNullOrEmpty(faultDesc)) faultDesc = Get("MaintOrdDesc")?.ToString()?.Trim() ?? "";
                            dict["faultSummary"] = faultDesc.Length > 100
                                ? TruncateAtWord(faultDesc, 95) + "..."
                                : faultDesc;

                            orderRows.Add(dict);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                TempData["DataSetError"] = ex.Message;
            }

            #endregion

            #region Process History Orders (Tab 2)

            var historyRows = new List<Dictionary<string, object?>>();
            List<TableColumn> historyColumns = new();

            DataSet dsHistory = await historyOrdersTask;
            DataTable? historyTable = (dsHistory?.Tables?.Count ?? 0) > 1 ? dsHistory!.Tables[1] : dt2;

            if (historyTable != null && historyTable.Columns.Count > 0)
            {
                historyColumns = BuildColumns(historyTable, historyVisibleFields);

                foreach (DataRow r in historyTable.Rows)
                {
                    var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                    foreach (DataColumn c in historyTable.Columns)
                    {
                        var val = r[c];
                        dict[c.ColumnName] = val == DBNull.Value ? null : val;
                    }

                    object? GetHist(string key) => dict.TryGetValue(key, out var v) ? v : null;

                    var wsIds = dict.TryGetValue("workshopIDs", out var wsVal) ? wsVal?.ToString() : null;
                    if (!string.IsNullOrEmpty(wsIds))
                    {
                        var names = wsIds.Split(',')
                            .Select(id => workshopLookup.TryGetValue(id.Trim(), out var n) ? n : id.Trim())
                            .Where(n => !string.IsNullOrEmpty(n));
                        dict["workshopNames"] = string.Join("، ", names);
                    }

                    dict["orderStatus"] = GetHist("MaintOrdActive") is bool hb && hb
                        || GetHist("MaintOrdActive")?.ToString()?.Trim() == "1"
                        || GetHist("MaintOrdActive")?.ToString()?.Trim().Equals("true", StringComparison.OrdinalIgnoreCase) == true
                        ? "نشط" : "مكتمل";

                    var histFault = GetHist("faultSummary")?.ToString()?.Trim() ?? "";
                    if (string.IsNullOrEmpty(histFault)) histFault = GetHist("MaintOrdDesc")?.ToString()?.Trim() ?? "";
                    dict["faultSummary"] = histFault.Length > 100
                        ? TruncateAtWord(histFault, 95) + "..."
                        : histFault;

                    var histCorr = GetHist("correctiveSummary")?.ToString()?.Trim() ?? "";
                    dict["correctiveSummary"] = histCorr.Length > 100
                        ? TruncateAtWord(histCorr, 95) + "..."
                        : histCorr;

                    historyRows.Add(dict);
                }
            }

            #endregion

            var currentUrl = Request.Path + Request.QueryString;

            #region Form: Insert Order

            var addOrderFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT_GENERAL_ORDER" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },

                new FieldConfig { Name = "p01", Label = "المركبة", Type = "select", ColCss = "4", Required = true, Options = vehicleOptions, Select2 = true, OnChangeJs = "sfSetArmyNumber(this)" },
                new FieldConfig { Name = "armyNumber_display", Label = "الرقم العسكري", Type = "", ColCss = "4", Readonly = true, Placeholder = "دحماس 999", HelpText = "ادخال 10 ارقام" },
                new FieldConfig { Name = "p02", Label = "تاريخ البداية", Type = "date", ColCss = "4", Required = true },
                new FieldConfig { Name = "p09", Type = "hidden" }
            };

            var generalFaultFieldsConfig = new SmartDynamicFieldsConfig
            {
                Id = "general-maintenance-faults",
                FormId = "generalInsertForm",
                OutputName = "p09",
                RenderOutputInput = false,
                SyncOutputOnChange = true,
                RowNumberProperty = "lineNo",
                MinRows = 1,
                MaxRows = 16,
                AllowAdd = true,
                AllowRemove = true,
                AllowReorder = false,
                AddButtonText = "إضافة عطل",
                RemoveButtonText = "حذف العطل",
                EmptyValidationMessage = "يجب إدخال عطل واحد على الأقل",
                MaxRowsMessage = "لا يمكن إضافة أكثر من 16 عطلًا",
                Fields = new List<SmartDynamicFieldDefinition>
                {
                    new()
                    {
                        Name = "faultDescription",
                        Label = "العطل",
                        Type = SmartDynamicFieldType.Text,
                        Required = true,
                        MaxLength = 500,
                        Placeholder = "أدخل العطل أو القصور",
                        ColCss = "col-span-12"
                    }
                }
            };

            var generalEditFaultFieldsConfig = new SmartDynamicFieldsConfig
            {
                Id = "general-maintenance-edit-faults",
                FormId = "generalEditForm",
                OutputName = "p09",
                RenderOutputInput = false,
                SyncOutputOnChange = true,
                RowNumberProperty = "lineNo",
                MinRows = 1,
                MaxRows = 16,
                AllowAdd = true,
                AllowRemove = true,
                AllowReorder = false,
                AddButtonText = "إضافة عطل",
                RemoveButtonText = "حذف العطل",
                EmptyValidationMessage = "يجب إدخال عطل واحد على الأقل",
                MaxRowsMessage = "لا يمكن إضافة أكثر من 16 عطلًا",
                Fields = new List<SmartDynamicFieldDefinition>
                {
                    new()
                    {
                        Name = "faultId",
                        Type = SmartDynamicFieldType.Hidden
                    },
                    new()
                    {
                        Name = "faultDescription",
                        Label = "العطل",
                        Type = SmartDynamicFieldType.Text,
                        Required = true,
                        MaxLength = 500,
                        Placeholder = "أدخل العطل أو القصور",
                        ColCss = "col-span-12"
                    }
                }
            };

            #endregion

            #region Form: Update Order

            var updateOrderFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATE_GENERAL_ORDER" },
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
                new FieldConfig { Name = "p05", Type = "hidden" },
                new FieldConfig { Name = "p09", Type = "hidden" }
            };

            #endregion

            #region Form: Close Order

            var closeOrderFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "CLOSE_GENERAL_ORDER" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },

                new FieldConfig { Name = "p01", Label = "رقم أمر الصيانة", Type = "hidden" },
                new FieldConfig { Name = "p07", Label = "تاريخ الإغلاق", Type = "date", ColCss = "12", Required = true },
                new FieldConfig { Name = "p09", Type = "hidden" }
            };

            foreach (var (id, name) in workshopOptions)
            {
                closeOrderFields.Add(new FieldConfig
                {
                    Name = $"__ws_{id}",
                    Label = name,
                    Type = "checkbox",
                    ColCss = "2"
                });
            }

            closeOrderFields.Add(new FieldConfig { Name = "p08", Type = "hidden" });

            #endregion

            #region Tab 1 — Active Orders

            var toolbar = new TableToolbarConfig
            {
                ShowRefresh = true,
                ShowColumns = true,
                ShowPrint = true
            };

            if (canInsertOrder)
            {
                toolbar.ShowAdd = true;
                toolbar.Add = new TableAction
                {
                    Label = "إضافة أمر صيانة عامة",
                    Icon = "fa fa-plus",
                    Color = "success",
                    OnClickJs = "sfOpenGeneralInsertModal",
                    OpenModal = true,
                    ModalTitle = "إدخال أمر صيانة عامة",
                    Meta = new Dictionary<string, object?>
                    {
                        ["smartDynamicFields"] = generalFaultFieldsConfig
                    },
                    OpenForm = new FormConfig
                    {
                        FormId = "generalInsertForm",
                        Title = "إدخال أمر صيانة عامة",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = addOrderFields,
                        Buttons = new List<FormButtonConfig>
                        {
                            new FormButtonConfig { Text = "حفظ", Type = "button", Color = "success", OnClickJs = "sfSubmitGeneralInsert(this)" },
                            new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                        }
                    }
                };
            }

            if (canUpdateOrder)
            {
                toolbar.ShowEdit = true;
                toolbar.Edit = new TableAction
                {
                    Label = "تعديل أمر صيانة",
                    Icon = "fa-pen-to-square",
                    Color = "info",
                    IsEdit = true,
                    OnClickJs = "sfOpenGeneralEditModal",
                    OpenModal = true,
                    ModalTitle = "تعديل أمر صيانة عامة",
                    Meta = new Dictionary<string, object?>
                    {
                        ["smartDynamicFields"] = generalEditFaultFieldsConfig
                    },
                    OpenForm = new FormConfig
                    {
                        FormId = "generalEditForm",
                        Title = "تعديل أمر صيانة عامة",
                        Method = "post",
                        ActionUrl = "/crud/update",
                        Fields = updateOrderFields,
                        Buttons = new List<FormButtonConfig>
                        {
                            new FormButtonConfig { Text = "حفظ", Type = "button", Color = "success", OnClickJs = "sfSubmitGeneralEdit(this)" },
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
                toolbar.ShowAdd1 = true;
                toolbar.Add1 = new TableAction
                {
                    Label = "إغلاق أمر صيانة",
                    Icon = "fa fa-lock",
                    Color = "warning",
                    OnClickJs = "sfOpenGeneralCloseModal",
                    OpenModal = true,
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    ModalTitle = "إغلاق أمر صيانة عامة",
                    OpenForm = new FormConfig
                    {
                        FormId = "generalCloseForm",
                        Title = "إغلاق أمر صيانة عامة",
                        Method = "post",
                        ActionUrl = "/crud/update",
                        Fields = closeOrderFields,
                        Buttons = new List<FormButtonConfig>
                        {
                            new FormButtonConfig { Text = "إغلاق الأمر", Type = "button", Color = "warning", OnClickJs = "sfSubmitGeneralClose(this)" },
                            new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                        }
                    }
                };
            }

            var statusActiveRule = new TableStyleRule
            {
                Target = "row", Field = "orderStatus", Op = "eq", Value = "نشط",
                Priority = 1, PillEnabled = true,
                PillField = "orderStatus", PillTextField = "orderStatus",
                PillCssClass = "pill pill-green", PillMode = "replace"
            };

            var statusClosedRule = new TableStyleRule
            {
                Target = "row", Field = "orderStatus", Op = "eq", Value = "مكتمل",
                Priority = 1, PillEnabled = true,
                PillField = "orderStatus", PillTextField = "orderStatus",
                PillCssClass = "pill pill-gray", PillMode = "replace"
            };

            var faultStyle = new TableStyleRule
            {
                Target = "cell",
                Field = "faultSummary",
                CssClass = "text-gray-500 text-xs"
            };

            var dsModelActive = new SmartTableDsModel
            {
                RenderMode = SmartTableRenderMode.Tab,
                RenderAsTab = true,
                TabGroupKey = "general-maintenance",
                TabKey = "active-orders",
                TabLabel = "أوامر الصيانة النشطة",
                ShowFilter = false,
                FilterRow = false,
                Columns = orderColumns,
                Rows = orderRows,
                RowIdField = "MaintOrdID",
                PageSize = 50,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                Searchable = true,
                AllowExport = true,
                PageTitle = "الصيانة العامة",
                PanelTitle = "أوامر الصيانة العامة النشطة",
                Toolbar = toolbar,
                StyleRules = new List<TableStyleRule> { statusActiveRule, statusClosedRule, faultStyle }
            };

            #endregion

            #region Tab 2 — History

            var historyToolbar = new TableToolbarConfig
            {
                ShowRefresh = true,
                ShowColumns = true,
                ShowPrint = true,
                ShowPrint1 = true,
                Print1 = new TableAction
                {
                    Label = "طباعة نموذج الصيانة",
                    Icon = "fa fa-print",
                    Color = "info",
                    OnClickJs = @"
                        const selectedRows = table.getSelectedRows();
                        if (selectedRows.length === 1) {
                            const row = selectedRows[0];
                            const rowId = row.MaintOrdID || row.p01;
                            if (!rowId) { alert('خطأ: لا يمكن العثور على معرف أمر الصيانة'); return; }
                            sfPrintWithBusy(table, {
                                pdf: 2,
                                extraParams: { rowId: rowId },
                                busy: { title: 'طباعة نموذج تفتيش وصيانة المعدات' }
                            });
                        }
                    ",
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1
                }
            };

            var dsModelHistory = new SmartTableDsModel
            {
                RenderMode = SmartTableRenderMode.Tab,
                TabGroupKey = "general-maintenance",
                TabKey = "history-orders",
                TabLabel = "السجل",
                ShowFilter = false,
                FilterRow = false,
                Columns = historyColumns,
                Rows = historyRows,
                RowIdField = "MaintOrdID",
                PageSize = 50,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                Searchable = true,
                AllowExport = true,
                Toolbar = historyToolbar,
                StyleRules = new List<TableStyleRule> { statusActiveRule, statusClosedRule, faultStyle }
            };

            #endregion

            ViewData["ArmyNumberLookup"] = System.Text.Json.JsonSerializer.Serialize(armyNumberLookup);

            var page = new SmartPageViewModel
            {
                PageTitle = dsModelActive.PageTitle,
                PanelTitle = dsModelActive.PanelTitle,
                PanelIcon = "fa-solid fa-screwdriver-wrench",
                TableDS = dsModelActive,
                TableDS1 = dsModelHistory
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

                var faultDs = await _mastersServies.GetDataLoadDataSetAsync(
                    new object?[] { "GeneralMaintenance", IdaraId, usersId, HostName, "LIST_FAULTS", rowId.Value });

                DataTable? faultDataTable = (faultDs?.Tables?.Count ?? 0) > 1 ? faultDs!.Tables[1] : null;

                var faults = new List<(string desc, string action)>();

                if (faultDataTable != null)
                {
                    foreach (DataRow fr in faultDataTable.Rows)
                    {
                        string fd = fr.Table.Columns.Contains("FaultDescription") ? fr["FaultDescription"]?.ToString() ?? "" : "";
                        string ca = fr.Table.Columns.Contains("CorrectiveAction") ? fr["CorrectiveAction"]?.ToString() ?? "" : "";
                        faults.Add((fd, ca));
                    }
                }

                LetterTableCell H(string ar, string en, int span = 1, float size = 6.4f) => new LetterTableCell
                {
                    Text = $"{ar}\n{en}",
                    Bold = true,
                    Align = TextAlign.Center,
                    BackgroundColor = "#FFFFFF",
                    FontSize = size,
                    ColumnSpan = span
                };

                LetterTableCell V(string text = "", int span = 1, TextAlign align = TextAlign.Center, float size = 7f) => new LetterTableCell
                {
                    Text = text,
                    Bold = false,
                    Align = align,
                    BackgroundColor = "#FFFFFF",
                    FontSize = size,
                    ColumnSpan = span
                };

                LetterTableCell R(string text, int span = 1, float size = 6.4f) => new LetterTableCell
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
                worksheet.BorderWidth = 1.1f;
                worksheet.BorderColor = "#000000";
                worksheet.CellPadding = 1.35f;
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
                        V("60-60", 2, TextAlign.Center, 7.2f),
                        V(vehicleDesc, 5, TextAlign.Center, 7.2f),
                        V(jobOrderNumber, 5, TextAlign.Center, 7.2f)
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
                        V("أولي", 2, TextAlign.Center, 7.2f),
                        V(startDateStr, 2, TextAlign.Center, 7.2f),
                        V("", 2),
                        V("", 2),
                        V("", 1),
                        V(armyNumber, 3, TextAlign.Center, 7.2f)
                    }
                });

                worksheet.Rows.Add(new LetterTableRow
                {
                    Cells = new()
                    {
                        H("١٠- المرجع المناسب", "APPLICABLE REFERENCE", 3),
                        R("تاريخ الكراسة الفنية:\nTM DATE:", 6, 6.4f),
                        H("١١- عدد ساعات الإصلاح", "MANHOURS", 3)
                    }
                });

                worksheet.Rows.Add(new LetterTableRow
                {
                    Cells = new()
                    {
                        V("", 3),
                        R("رقم الكراسة الفنية:\nTM NUMBER:", 6, 6.4f),
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

                for (int i = 0; i < 17; i++)
                {
                    var fault = i < faults.Count ? faults[i] : default;

                    string initialLabel = i switch
                    {
                        0 => "الاسم\nNAME",
                        1 => "الرقم\nJOB ID",
                        2 => "التوقيع\nSIG",
                        _ => ""
                    };

                    worksheet.Rows.Add(new LetterTableRow
                    {
                        ExtendVertical = true,
                        MinRowHeight = 22f,
                        Cells = new()
                        {
                            V(initialLabel, 1, TextAlign.Center, 5.8f),
                            V("", 1, TextAlign.Center, 5.8f),
                            V(fault.desc, 4, TextAlign.Right, 6.8f),
                            V(fault.action, 3, TextAlign.Right, 6.8f),
                            V("", 2),
                            V("", 1)
                        }
                    });
                }

                var report = new ReportResult
                {
                    ReportId = "MaintenanceWorksheet",
                    Title = "",
                    Kind = ReportKind.Letter,
                    Orientation = ReportOrientation.Portrait,
                    HeaderType = ReportHeaderType.Standard,
                    HeaderFields = new Dictionary<string, string>(),
                    ShowFooter = false,
                    LetterBlocks = new List<LetterBlock>
                    {
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
                            paddingTop: 6,
                            paddingBottom: 0,
                            paddingRight: 0,
                            paddingLeft: 0),

                        LetterBlockFactory.FooterBlock(
                            right: "نموذج القوات البرية رقم 2404",
                            center: "مطبعة سلاح الصيانة",
                            left: "LAND FORCES FORM 2404",
                            fontSize: 6.3f,
                            paddingTop: 4)
                    }
                };

                var pdfBytes = QuestPdfReportRenderer.Render(report);
                Response.Headers["Content-Disposition"] = "inline; filename=MaintenanceWorksheet.pdf";
                return File(pdfBytes, "application/pdf");
            }

            #endregion

            return View("Page/GeneralMaintenance", page);
        }

        [HttpGet]
        [Route("Vehicle/GetGeneralFaults")]
        public async Task<IActionResult> GetGeneralFaults(int maintOrdID)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (maintOrdID <= 0)
                return BadRequest(new { success = false, message = "رقم أمر الصيانة غير صالح" });

            try
            {
                var detailsDs = await _mastersServies.GetDataLoadDataSetAsync(
                    new object?[] { "GeneralMaintenance", IdaraId, usersId, HostName,
                        "LIST_DETAILS", maintOrdID });

                DataTable? permissionRows = (detailsDs?.Tables?.Count ?? 0) > 0
                    ? detailsDs!.Tables[0]
                    : null;

                bool canLoadFaults = permissionRows != null && permissionRows.AsEnumerable().Any(r =>
                {
                    var permission = r.Table.Columns.Contains("permissionTypeName_E")
                        ? r["permissionTypeName_E"]?.ToString()?.Trim().ToUpperInvariant()
                        : null;
                    return permission is "UPDATE_GENERAL_ORDER" or "CLOSE_GENERAL_ORDER";
                });

                if (!canLoadFaults)
                    return StatusCode(StatusCodes.Status403Forbidden,
                        new { success = false, message = "لا تملك صلاحية عرض أعطال أمر الصيانة" });

                DataTable? orderDetails = (detailsDs?.Tables?.Count ?? 0) > 1
                    ? detailsDs!.Tables[1]
                    : null;

                if (orderDetails == null || orderDetails.Rows.Count == 0)
                    return NotFound(new { success = false, message = "أمر الصيانة غير موجود ضمن إدارتك" });

                var ds = await _mastersServies.GetDataLoadDataSetAsync(
                    new object?[] { "GeneralMaintenance", IdaraId, usersId, HostName,
                        "LIST_FAULTS", maintOrdID });

                DataTable? faultTable = (ds?.Tables?.Count ?? 0) > 1 ? ds!.Tables[1] : null;

                var rows = new List<Dictionary<string, object?>>();

                if (faultTable != null)
                {
                    foreach (DataRow r in faultTable.Rows)
                    {
                        var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                        foreach (DataColumn c in faultTable.Columns)
                        {
                            var val = r[c];
                            dict[c.ColumnName] = val == DBNull.Value ? null : val;
                        }
                        rows.Add(dict);
                    }
                }

                return Json(new { success = true, items = rows });
            }
            catch (Exception)
            {
                return StatusCode(StatusCodes.Status500InternalServerError,
                    new { success = false, message = "تعذر تحميل أعطال أمر الصيانة" });
            }
        }
    }
}
