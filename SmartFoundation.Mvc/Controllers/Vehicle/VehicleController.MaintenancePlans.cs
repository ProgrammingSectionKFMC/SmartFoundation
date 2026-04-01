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
        public async Task<IActionResult> MaintenancePlans(
              string? chassisNumber = null
            , string? active = null
        )
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = "Vehicle";
            PageName = "MaintenancePlan_List";

            var spParameters = new object?[]
            {
                "MaintenancePlan_List",
                IdaraId,
                usersId,
                HostName,
                string.IsNullOrWhiteSpace(chassisNumber) ? null : chassisNumber, // @parameter_01
                string.IsNullOrWhiteSpace(active) ? null : active,               // @parameter_02
                1,                                                               // @parameter_03 => pageNumber
                50                                                               // @parameter_04 => pageSize
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            SplitDataSet(ds);

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            string rowIdField = "PlanID";

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
                    var possibleIdNames = new[] { "PlanID", "planID", "Id", "ID" };
                    rowIdField = possibleIdNames.FirstOrDefault(n => dataTable.Columns.Contains(n))
                                 ?? dataTable.Columns[0].ColumnName;

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "PlanID",
                        Label = "رقم الخطة",
                        Type = "number",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "chassisNumber_FK",
                        Label = "الشاصي",
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "plateDisplay",
                        Label = "اللوحة",
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "periodMonths",
                        Label = "الدورية (شهر)",
                        Type = "number",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "nextDueDate",
                        Label = "الموعد القادم",
                        Type = "date",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "planActiveText",
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

                        var plateLetters = Get("plateLetters")?.ToString() ?? "";
                        var plateNumbers = Get("plateNumbers")?.ToString() ?? "";
                        var activeVal = Get("planActive")?.ToString();

                        dict["plateDisplay"] = $"{plateLetters} {plateNumbers}".Trim();
                        dict["planActiveValue"] = activeVal == "1" ? "1" : "0";
                        dict["planActiveText"] = activeVal == "1" ? "مفعلة" : "موقفة";
                        dict["toggleActiveValue"] = activeVal == "1" ? "0" : "1";
                        dict["toggleActionLabel"] = activeVal == "1" ? "تعطيل" : "تفعيل";

                        // باراميترات التعديل
                        dict["p01"] = Get("PlanID");
                        dict["p02"] = Get("chassisNumber_FK");
                        dict["p03"] = Get("periodMonths");
                        dict["p04"] = NormalizeDateForInput(Get("nextDueDate"));
                        dict["p05"] = dict["planActiveValue"];

                        // باراميترات التفعيل/التعطيل
                        dict["toggle_p01"] = Get("PlanID");
                        dict["toggle_p02"] = dict["toggleActiveValue"];

                        rowsList.Add(dict);
                    }
                }
            }
            catch (Exception ex)
            {
                TempData["DataSetError"] = ex.Message;
            }

            var currentUrl = Request.Path + Request.QueryString;

            var activeOptions = new List<OptionItem>
            {
                new OptionItem { Value = "1", Text = "مفعلة" },
                new OptionItem { Value = "0", Text = "موقفة" }
            };

            var insertFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "MaintenancePlan_Upsert" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = "MaintenancePlans" },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig
                {
                    Name = "p01",
                    Label = "رقم الهيكل",
                    Type = "text",
                    ColCss = "6",
                    Required = true,
                    Placeholder = "ابحث عن المركبة بالشاصي أو اللوحة"
                },
                new FieldConfig
                {
                    Name = "p02",
                    Label = "كل كم شهر",
                    Type = "number",
                    ColCss = "3",
                    Required = true
                },
                new FieldConfig
                {
                    Name = "p03",
                    Label = "الموعد القادم",
                    Type = "date",
                    ColCss = "3",
                    Required = true
                },
                new FieldConfig
                {
                    Name = "p04",
                    Label = "الحالة",
                    Type = "select",
                    Options = activeOptions,
                    ColCss = "6",
                    Select2 = true,
                    Required = true,
                    Value = "1"
                }
            };

            var updateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "MaintenancePlan_Upsert" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATE" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = "MaintenancePlans" },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = rowIdField },

                new FieldConfig
                {
                    Name = "p02",
                    Label = "رقم الهيكل",
                    Type = "text",
                    ColCss = "6",
                    Required = true,
                    MirrorName = "p02",
                    Placeholder = "ابحث عن المركبة بالشاصي أو اللوحة"
                },
                new FieldConfig
                {
                    Name = "p03",
                    Label = "كل كم شهر",
                    Type = "number",
                    ColCss = "3",
                    Required = true,
                    MirrorName = "p03"
                },
                new FieldConfig
                {
                    Name = "p04",
                    Label = "الموعد القادم",
                    Type = "date",
                    ColCss = "3",
                    Required = true,
                    MirrorName = "p04"
                },
                new FieldConfig
                {
                    Name = "p05",
                    Label = "الحالة",
                    Type = "select",
                    Options = activeOptions,
                    ColCss = "6",
                    Select2 = true,
                    Required = true,
                    MirrorName = "p05"
                }
            };

            var setActiveFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "MaintenancePlan_SetActive" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATE" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = "MaintenancePlans" },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = rowIdField },
                new FieldConfig { Name = "p02", Type = "hidden", MirrorName = "toggle_p02" }
            };

            var autoGenerateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "MaintenancePlan_AutoGenerate" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = "MaintenancePlans" },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") }
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
                ShowDelete = false,
                ShowBulkDelete = false,
                CustomActions = new List<TableAction>()
            };

            if (canInsert)
            {
                toolbar.Add = new TableAction
                {
                    Label = "إضافة",
                    Icon = "fa fa-plus",
                    Color = "success",
                    IsEdit = false,
                    OpenModal = true,
                    ModalTitle = "إضافة خطة صيانة دورية",
                    ModalMessage = "سيتم إضافة خطة صيانة دورية جديدة",
                    ModalMessageIcon = "fa-solid fa-circle-info",
                    ModalMessageClass = "bg-green-50 text-green-700",
                    OpenForm = new FormConfig
                    {
                        FormId = "InsertMaintenancePlanForm",
                        Title = "إضافة خطة صيانة دورية",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        SubmitText = "حفظ",
                        CancelText = "إلغاء",
                        Fields = insertFields
                    }
                };

                toolbar.CustomActions.Add(new TableAction
                {
                    Label = "Auto Generate",
                    Icon = "fa fa-play",
                    Color = "warning",
                    OpenModal = true,
                    RequireSelection = false,
                    ModalTitle = "تشغيل التوليد الآلي",
                    ModalMessage = "سيتم تشغيل إنشاء أوامر الصيانة الدورية المستحقة",
                    ModalMessageIcon = "fa-solid fa-circle-info",
                    ModalMessageClass = "bg-yellow-50 text-yellow-700",
                    OpenForm = new FormConfig
                    {
                        FormId = "AutoGenerateMaintenancePlanForm",
                        Title = "تشغيل التوليد الآلي",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        SubmitText = "تشغيل",
                        CancelText = "إلغاء",
                        Fields = autoGenerateFields
                    }
                });
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
                    ModalTitle = "تعديل خطة صيانة دورية",
                    ModalMessage = "سيتم تعديل الخطة المحددة",
                    ModalMessageIcon = "fa-solid fa-circle-info",
                    ModalMessageClass = "bg-blue-50 text-blue-700",
                    OpenForm = new FormConfig
                    {
                        FormId = "UpdateMaintenancePlanForm",
                        Title = "تعديل خطة صيانة دورية",
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

                toolbar.CustomActions.Add(new TableAction
                {
                    Label = "تفعيل/تعطيل",
                    Icon = "fa fa-toggle-on",
                    Color = "warning",
                    IsEdit = true,
                    OpenModal = true,
                    ModalTitle = "تغيير حالة الخطة",
                    ModalMessage = "سيتم تفعيل أو تعطيل الخطة المحددة",
                    ModalMessageIcon = "fa-solid fa-circle-info",
                    ModalMessageClass = "bg-yellow-50 text-yellow-700",
                    OpenForm = new FormConfig
                    {
                        FormId = "SetActiveMaintenancePlanForm",
                        Title = "تفعيل / تعطيل خطة",
                        Method = "post",
                        ActionUrl = "/crud/update",
                        SubmitText = "تنفيذ",
                        CancelText = "إلغاء",
                        Fields = setActiveFields
                    },
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1
                });
            }

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "خطط الصيانة الدورية",
                PanelTitle = "خطط الصيانة الدورية",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = new List<string> { "PlanID", "chassisNumber_FK", "plateDisplay", "periodMonths", "planActiveText" },
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
            ViewBag.FilterActive = active;
            ViewBag.VehicleSearchUrl = Url.Action("GetVehicleSearch", "Vehicle");

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa fa-calendar",
                TableDS = dsModel
            };

            return View("MaintenancePlans", page);
        }
    }
}