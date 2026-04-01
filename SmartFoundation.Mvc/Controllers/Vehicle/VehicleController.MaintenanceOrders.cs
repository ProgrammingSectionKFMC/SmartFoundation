using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;

namespace SmartFoundation.Mvc.Controllers.Vehicle
{
    public partial class VehicleController : Controller
    {
        public async Task<IActionResult> MaintenanceOrders(
              string? chassisNumber = null
            , string? maintOrdTypeID = null
            , string? active = null
            , string? fromDate = null
            , string? toDate = null
        )
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = "Vehicle";
            PageName = "MaintenanceOrder_List";

            var spParameters = new object?[]
            {
                "MaintenanceOrder_List",
                IdaraId,
                usersId,
                HostName,
                string.IsNullOrWhiteSpace(chassisNumber) ? null : chassisNumber,   // @parameter_01
                string.IsNullOrWhiteSpace(maintOrdTypeID) ? null : maintOrdTypeID, // @parameter_02
                string.IsNullOrWhiteSpace(active) ? null : active,                 // @parameter_03
                string.IsNullOrWhiteSpace(fromDate) ? null : fromDate,             // @parameter_04
                string.IsNullOrWhiteSpace(toDate) ? null : toDate,                 // @parameter_05
                1,                                                                 // @parameter_06 => pageNumber
                50                                                                 // @parameter_07 => pageSize
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();

            var maintenanceTypeOptions = new List<OptionItem>
            {
                new OptionItem { Value = "265", Text = "صيانة دورية" },
                new OptionItem { Value = "266", Text = "صيانة عطل" },
                new OptionItem { Value = "267", Text = "صيانة حادث" }
            };

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            SplitDataSet(ds);

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            string rowIdField = "MaintOrdID";

            bool canAccess = false;
            bool canSelect = false;
            bool canInsert = false;
            bool canUpdate = false;

            try
            {
                foreach (DataRow row in permissionTable.Rows)
                {
                    var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                    if (permissionName == "ACCESS") canAccess = true;
                    if (permissionName == "SELECT") canSelect = true;
                    if (permissionName == "INSERT") canInsert = true;
                    if (permissionName == "UPDATE") canUpdate = true;
                }

                if (!canAccess && !canSelect)
                {
                    TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                    return RedirectToAction("Index", "Home");
                }

                var dataTable = dt2 ?? dt3 ?? dt1;

                if (dataTable != null && dataTable.Columns.Count > 0)
                {
                    var possibleIdNames = new[] { "MaintOrdID", "maintOrdID", "Id", "ID" };
                    rowIdField = possibleIdNames.FirstOrDefault(n => dataTable.Columns.Contains(n))
                                 ?? dataTable.Columns[0].ColumnName;

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "MaintOrdID",
                        Label = "رقم الأمر",
                        Type = "number",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "MaintOrdTypeName",
                        Label = "نوع الصيانة",
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "chassisNumber_FK",
                        Label = "رقم الهيكل",
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "MaintOrdStartDate",
                        Label = "تاريخ البداية",
                        Type = "date",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "MaintOrdEndDate",
                        Label = "تاريخ النهاية",
                        Type = "date",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "MaintOrdDesc",
                        Label = "الوصف",
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "MaintOrdActiveText",
                        Label = "الحالة",
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });

                    foreach (DataRow r in dataTable.Rows)
                    {
                        var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

                        foreach (DataColumn c in dataTable.Columns)
                        {
                            var val = r[c];
                            dict[c.ColumnName] = val == DBNull.Value ? null : val;
                        }

                        object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;

                        var maintTypeId = Get("MaintOrdTypeID_FK")?.ToString();
                        var activeVal = Get("MaintOrdActive")?.ToString();

                        dict["MaintOrdTypeID_Value"] = maintTypeId;
                        dict["MaintOrdTypeName"] = maintTypeId switch
                        {
                            "265" => "صيانة دورية",
                            "266" => "صيانة عطل",
                            "267" => "صيانة حادث",
                            _ => maintTypeId
                        };

                        dict["MaintOrdActiveValue"] = activeVal == "1" ? "1" : "0";
                        dict["MaintOrdActiveText"] = activeVal == "1" ? "مفتوح" : "مغلق";

                        // باراميترات التعديل
                        dict["p01"] = Get("MaintOrdID");
                        dict["p02"] = dict["MaintOrdTypeID_Value"];
                        dict["p03"] = Get("chassisNumber_FK");
                        dict["p04"] = NormalizeDateForInput(Get("MaintOrdStartDate"));
                        dict["p05"] = NormalizeDateForInput(Get("MaintOrdEndDate"));
                        dict["p06"] = Get("MaintOrdDesc");
                        dict["p07"] = dict["MaintOrdActiveValue"];

                        // باراميترات الإغلاق
                        dict["close_p01"] = Get("MaintOrdID");
                        dict["close_p02"] = DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss");

                        // زر بنود الصيانة
                        dict["details_p01"] = Get("MaintOrdID");

                        rowsList.Add(dict);
                    }
                }
            }
            catch (Exception ex)
            {
                TempData["DataSetError"] = ex.Message;
            }

            var currentUrl = Request.Path + Request.QueryString;

            var insertFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "MaintenanceOrder_Upsert" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = "MaintenanceOrders" },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig
                {
                    Name = "p01",
                    Label = "نوع الصيانة",
                    Type = "select",
                    Options = maintenanceTypeOptions,
                    ColCss = "6",
                    Select2 = true,
                    Required = true,
                    Placeholder = "اختر نوع الصيانة"
                },
                new FieldConfig
                {
                    Name = "p02",
                    Label = "رقم الهيكل",
                    Type = "text",
                    ColCss = "6",
                    Required = true,
                    Placeholder = "ابحث عن المركبة بالشاصي أو اللوحة"
                },
                new FieldConfig
                {
                    Name = "p03",
                    Label = "تاريخ البداية",
                    Type = "date",
                    ColCss = "6",
                    Required = true
                },
                new FieldConfig
                {
                    Name = "p04",
                    Label = "تاريخ النهاية",
                    Type = "date",
                    ColCss = "6"
                },
                new FieldConfig
                {
                    Name = "p05",
                    Label = "الوصف",
                    Type = "textarea",
                    ColCss = "12",
                    MaxLength = 1000
                },
                new FieldConfig
                {
                    Name = "p06",
                    Type = "hidden",
                    Value = "1"
                }
            };

            var updateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "MaintenanceOrder_Upsert" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATE" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = "MaintenanceOrders" },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = rowIdField },

                new FieldConfig
                {
                    Name = "p02",
                    Label = "نوع الصيانة",
                    Type = "select",
                    Options = maintenanceTypeOptions,
                    ColCss = "6",
                    Select2 = true,
                    Required = true,
                    MirrorName = "p02"
                },
                new FieldConfig
                {
                    Name = "p03",
                    Label = "رقم الهيكل",
                    Type = "text",
                    ColCss = "6",
                    Required = true,
                    MirrorName = "p03",
                    Placeholder = "ابحث عن المركبة بالشاصي أو اللوحة"
                },
                new FieldConfig
                {
                    Name = "p04",
                    Label = "تاريخ البداية",
                    Type = "date",
                    ColCss = "6",
                    Required = true,
                    MirrorName = "p04"
                },
                new FieldConfig
                {
                    Name = "p05",
                    Label = "تاريخ النهاية",
                    Type = "date",
                    ColCss = "6",
                    MirrorName = "p05"
                },
                new FieldConfig
                {
                    Name = "p06",
                    Label = "الوصف",
                    Type = "textarea",
                    ColCss = "12",
                    MaxLength = 1000,
                    MirrorName = "p06"
                },
                new FieldConfig
                {
                    Name = "p07",
                    Type = "hidden",
                    MirrorName = "p07"
                }
            };

            var closeFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "MaintenanceOrder_Close" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATE" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = "MaintenanceOrders" },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = rowIdField },
                new FieldConfig { Name = "p02", Type = "hidden", MirrorName = "close_p02" }
            };

            var toolbar = new TableToolbarConfig
            {
                ShowRefresh = false,
                ShowColumns = true,
                ShowExportCsv = false,
                ShowExportExcel = true,
                ShowExportPdf = true,

                ShowAdd = canInsert,
                ShowEdit = canUpdate,
                ShowDelete = canUpdate,
                ShowBulkDelete = false,

                CustomActions = new List<TableAction>
                {
                    new TableAction
                    {
                        Label = "بنود الصيانة",
                        Icon = "fa fa-list-check",
                        Color = "info",
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                        OnClickJs = "var rows = table.getSelectedRows(); if (!rows || rows.length !== 1) return false; var id = rows[0].MaintOrdID || rows[0].maintOrdID || rows[0].details_p01 || rows[0].p01; if (!id) return false; window.location.href = '/Vehicle/MaintenanceDetails?maintOrdID=' + id; return false;"
                    }
                }
            };

            if (canInsert)
            {
                toolbar.Add = new TableAction
                {
                    Label = "إضافة أمر",
                    Icon = "fa fa-plus",
                    Color = "success",
                    IsEdit = false,
                    OpenModal = true,
                    ModalTitle = "إضافة أمر صيانة",
                    ModalMessage = "سيتم إضافة أمر صيانة جديد",
                    ModalMessageIcon = "fa-solid fa-circle-info",
                    ModalMessageClass = "bg-green-50 text-green-700",
                    OpenForm = new FormConfig
                    {
                        FormId = "InsertMaintenanceOrderForm",
                        Title = "إضافة أمر صيانة",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        SubmitText = "حفظ",
                        CancelText = "إلغاء",
                        Fields = insertFields
                    }
                };
            }

            if (canUpdate)
            {
                toolbar.Edit = new TableAction
                {
                    Label = "تعديل",
                    Icon = "fa fa-edit",
                    Color = "primary",
                    IsEdit = true,
                    OpenModal = true,
                    ModalTitle = "تعديل أمر صيانة",
                    ModalMessage = "سيتم تعديل الأمر المحدد",
                    ModalMessageIcon = "fa-solid fa-circle-info",
                    ModalMessageClass = "bg-blue-50 text-blue-700",
                    OpenForm = new FormConfig
                    {
                        FormId = "UpdateMaintenanceOrderForm",
                        Title = "تعديل أمر صيانة",
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

                toolbar.Delete = new TableAction
                {
                    Label = "إغلاق أمر",
                    Icon = "fa fa-times",
                    Color = "danger",
                    IsEdit = true,
                    OpenModal = true,
                    ModalTitle = "إغلاق أمر صيانة",
                    ModalMessage = "هل أنت متأكد من إغلاق أمر الصيانة؟",
                    ModalMessageIcon = "fa fa-exclamation-triangle text-red-600",
                    ModalMessageClass = "bg-red-50 text-red-700",
                    OpenForm = new FormConfig
                    {
                        FormId = "CloseMaintenanceOrderForm",
                        Title = "إغلاق أمر صيانة",
                        Method = "post",
                        ActionUrl = "/crud/update",
                        SubmitText = "إغلاق",
                        CancelText = "إلغاء",
                        Fields = closeFields
                    },
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1
                };
            }

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "أوامر الصيانة",
                PanelTitle = "أوامر الصيانة",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(5).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowRowBorders = false,
                EnablePagination = true,
                ShowPageSizeSelector = true,
                ShowToolbar = true,
                EnableCellCopy = false,
                Toolbar = toolbar
            };

            ViewBag.FilterChassisNumber = chassisNumber;
            ViewBag.FilterMaintOrdTypeID = maintOrdTypeID;
            ViewBag.FilterActive = active;
            ViewBag.FilterFromDate = fromDate;
            ViewBag.FilterToDate = toDate;

            ViewBag.MaintenanceTemplatePreviewUrl = Url.Action("GetMaintenanceTemplatePreview", "Vehicle");
            ViewBag.VehicleSearchUrl = Url.Action("GetVehicleSearch", "Vehicle");

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa fa-wrench",
                TableDS = dsModel
            };

            return View("MaintenanceOrders", page);
        }

        [HttpGet]
        public async Task<IActionResult> GetMaintenanceTemplatePreview(string? maintOrdTypeID)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return Json(new { success = false, message = "تعذر تهيئة الصفحة" });

            if (string.IsNullOrWhiteSpace(usersId))
                return Json(new { success = false, message = "المستخدم غير معرف" });

            if (string.IsNullOrWhiteSpace(maintOrdTypeID))
                return Json(new { success = true, items = new List<object>() });

            try
            {
                var spParameters = new object?[]
                {
                    "MaintenanceTemplate_List",
                    IdaraId,
                    usersId,
                    HostName,
                    maintOrdTypeID,
                    1
                };

                DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

                DataTable? dataTable = null;

                if (ds.Tables.Count == 1)
                    dataTable = ds.Tables[0];
                else if (ds.Tables.Count > 1)
                    dataTable = ds.Tables[1] ?? ds.Tables[0];

                var items = new List<object>();

                if (dataTable != null && dataTable.Rows.Count > 0)
                {
                    foreach (DataRow row in dataTable.Rows)
                    {
                        items.Add(new
                        {
                            TemplateItemName_A = dataTable.Columns.Contains("TemplateItemName_A")
                                ? row["TemplateItemName_A"]?.ToString() ?? ""
                                : "",
                            TemplateOrder = dataTable.Columns.Contains("TemplateOrder")
                                ? row["TemplateOrder"]?.ToString() ?? ""
                                : ""
                        });
                    }
                }

                return Json(new { success = true, items });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        [HttpGet]
        public async Task<IActionResult> GetVehicleSearch(string? q)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return Json(new { success = false, items = new List<object>() });

            if (string.IsNullOrWhiteSpace(usersId))
                return Json(new { success = false, items = new List<object>() });

            if (string.IsNullOrWhiteSpace(q))
                return Json(new { success = true, items = new List<object>() });

            try
            {
                var spParameters = new object?[]
                {
                    "Vehicle_Search",
                    IdaraId,
                    usersId,
                    HostName,
                    q,
                    null,
                    null,
                    20,
                    IdaraId
                };

                DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

                DataTable? dataTable = null;

                if (ds.Tables.Count == 1)
                    dataTable = ds.Tables[0];
                else if (ds.Tables.Count > 1)
                    dataTable = ds.Tables[1] ?? ds.Tables[0];

                var items = new List<object>();

                if (dataTable != null && dataTable.Rows.Count > 0)
                {
                    foreach (DataRow row in dataTable.Rows)
                    {
                        var chassis = dataTable.Columns.Contains("chassisNumber")
                            ? row["chassisNumber"]?.ToString() ?? ""
                            : "";

                        var plateLetters = dataTable.Columns.Contains("plateLetters")
                            ? row["plateLetters"]?.ToString() ?? ""
                            : "";

                        var plateNumbers = dataTable.Columns.Contains("plateNumbers")
                            ? row["plateNumbers"]?.ToString() ?? ""
                            : "";

                        var label = chassis;
                        var platePart = $"{plateLetters} {plateNumbers}".Trim();

                        if (!string.IsNullOrWhiteSpace(platePart))
                            label = $"{chassis} - {platePart}";

                        items.Add(new
                        {
                            value = chassis,
                            label = label
                        });
                    }
                }

                return Json(new { success = true, items });
            }
            catch
            {
                return Json(new { success = false, items = new List<object>() });
            }
        }

        private static string? NormalizeDateForInput(object? value)
        {
            if (value == null) return null;

            if (value is DateTime dt)
                return dt.ToString("yyyy-MM-dd");

            if (DateTime.TryParse(value.ToString(), out var parsed))
                return parsed.ToString("yyyy-MM-dd");

            return value.ToString();
        }
    }
}