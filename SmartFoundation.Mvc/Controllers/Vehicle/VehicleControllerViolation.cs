using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;

namespace SmartFoundation.Mvc.Controllers.VIC
{
    public partial class VehiclesController : Controller
    {
        public async Task<IActionResult> Violation(int pdf = 0)
        {
            if (!InitPageContext(out var redirect))
                return redirect!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }

            ControllerName = "Vehicle";
            PageName = string.IsNullOrWhiteSpace(PageName) ? "Violation" : PageName;

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();
            var violationTypeOptions = new List<OptionItem>();
            var chassisOptions = new List<OptionItem>();

            string rowIdField = "violationID";

            bool canADDVIOLATION = false;
            bool canEDITVIOLATION = false;
            bool canPAYVIOLATION = false;

            DataTable? dtPermissions = null;
            DataTable? dtList = null;
            DataTable? dtLookups = null;
            DataTable? dtVehicleSearch = null;

            try
            {
                // ------------------------------------------------------------
                // Permissions
                // ------------------------------------------------------------
                var dsPermissions = await _mastersServies.GetDataLoadDataSetAsync(new object?[]
                {
                    "Violation",
                    IdaraId,
                    usersId,
                    HostName
                });

                SplitDataSet(dsPermissions);
                dtPermissions = permissionTable;

                if (dtPermissions is null || dtPermissions.Rows.Count == 0)
                {
                    TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                    return RedirectToAction("Index", "Home");
                }

                foreach (DataRow row in dtPermissions.Rows)
                {
                    var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                    if (permissionName == "ADDVIOLATION") canADDVIOLATION = true;
                    if (permissionName == "EDITVIOLATION") canEDITVIOLATION = true;
                    if (permissionName == "PAYVIOLATION") canPAYVIOLATION = true;
                }

                // ------------------------------------------------------------
                // Violations List
                // ------------------------------------------------------------
                var dsList = await _mastersServies.GetDataLoadDataSetAsync(new object?[]
                {
                    "Violation_List",
                    IdaraId,
                    usersId,
                    HostName,
                    null,   // p01 = chassisNumber
                    null,   // p02 = violationTypeID
                    null,   // p03 = Paid
                    null,   // p04 = FromDate
                    null,   // p05 = ToDate
                    1,      // p06 = Page
                    50,     // p07 = PageSize
                    IdaraId // p08 = idaraID_FK
                });

                if (dsList != null && dsList.Tables.Count > 1)
                    dtList = dsList.Tables[1];
                else if (dsList != null && dsList.Tables.Count > 0)
                    dtList = dsList.Tables[0];

                // ------------------------------------------------------------
                // Violation Types Lookups
                // ------------------------------------------------------------
                var dsLookups = await _mastersServies.GetDataLoadDataSetAsync(new object?[]
                {
                    "Violation_GetLookups",
                    IdaraId,
                    usersId,
                    HostName,
                    1 // p01 = ActiveOnly
                });

                if (dsLookups != null && dsLookups.Tables.Count > 1)
                    dtLookups = dsLookups.Tables[1];
                else if (dsLookups != null && dsLookups.Tables.Count > 0)
                    dtLookups = dsLookups.Tables[0];

                if (dtLookups != null && dtLookups.Rows.Count > 0)
                {
                    foreach (DataRow r in dtLookups.Rows)
                    {
                        violationTypeOptions.Add(new OptionItem
                        {
                            Value = r["typesID"]?.ToString() ?? "",
                            Text = r["typesName_A"]?.ToString() ?? ""
                        });
                    }
                }

                // ------------------------------------------------------------
                // Vehicle Search for Chassis dropdown
                // ------------------------------------------------------------
                var dsVehicleSearch = await _mastersServies.GetDataLoadDataSetAsync(new object?[]
                {
                    "Vehicle_Search",
                    IdaraId,
                    usersId,
                    HostName,
                   "1",   // p01 = q
                    null,   // p02 = plateLetters
                    null,   // p03 = plateNumbers
                    200,    // p04 = Top
                    IdaraId // p05 = idaraID_FK
                });

                if (dsVehicleSearch != null && dsVehicleSearch.Tables.Count > 1)
                    dtVehicleSearch = dsVehicleSearch.Tables[1];
                else if (dsVehicleSearch != null && dsVehicleSearch.Tables.Count > 0)
                    dtVehicleSearch = dsVehicleSearch.Tables[0];

                if (dtVehicleSearch != null && dtVehicleSearch.Rows.Count > 0)
                {
                    foreach (DataRow r in dtVehicleSearch.Rows)
                    {
                        var chassis = dtVehicleSearch.Columns.Contains("chassisNumber")
                            ? r["chassisNumber"]?.ToString()
                            : dtVehicleSearch.Columns.Contains("chassisNumber_FK")
                                ? r["chassisNumber_FK"]?.ToString()
                                : "";

                        if (!string.IsNullOrWhiteSpace(chassis))
                        {
                            chassisOptions.Add(new OptionItem
                            {
                                Value = chassis,
                                Text = chassis
                            });
                        }
                    }
                }

                // ------------------------------------------------------------
                // Grid
                // ------------------------------------------------------------
                if (dtList != null && dtList.Columns.Count > 0)
                {
                    rowIdField = dtList.Columns.Contains("violationID")
                        ? "violationID"
                        : dtList.Columns[0].ColumnName;

                    var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                    {
                        ["violationID"] = "رقم المخالفة",
                        ["chassisNumber_FK"] = "رقم الشاصي",
                        ["plateLetters"] = "حروف اللوحة",
                        ["plateNumbers"] = "أرقام اللوحة",
                        ["ViolationTypeName_A"] = "نوع المخالفة",
                        ["violationDate"] = "تاريخ المخالفة",
                        ["violationPrice"] = "قيمة المخالفة",
                        ["violationLocation"] = "موقع المخالفة",
                        ["PaymentDate"] = "تاريخ السداد",
                        ["PaymentStatusName_A"] = "حالة السداد",
                        ["armyNumber"] = "الرقم العسكري",
                        ["yearModel"] = "سنة الصنع"
                    };

                    foreach (DataColumn c in dtList.Columns)
                    {
                        string colType = "text";
                        var t = c.DataType;

                        if (t == typeof(bool)) colType = "bool";
                        else if (t == typeof(DateTime)) colType = "date";
                        else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                              || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                            colType = "number";

                        bool isHidden =
                               c.ColumnName.Equals("vehicleID", StringComparison.OrdinalIgnoreCase)
                            || c.ColumnName.Equals("violationTypeRoot_FK", StringComparison.OrdinalIgnoreCase)
                            || c.ColumnName.Equals("entryPayment", StringComparison.OrdinalIgnoreCase)
                            || c.ColumnName.Equals("entryDate", StringComparison.OrdinalIgnoreCase)
                            || c.ColumnName.Equals("entryData", StringComparison.OrdinalIgnoreCase)
                            || c.ColumnName.Equals("hostName", StringComparison.OrdinalIgnoreCase)
                            || c.ColumnName.Equals("ViolationTypeName_E", StringComparison.OrdinalIgnoreCase)
                            || c.ColumnName.Equals("IdaraID_FK", StringComparison.OrdinalIgnoreCase)
                            || c.ColumnName.Equals("IsPaid", StringComparison.OrdinalIgnoreCase);

                        bool isViolationTypeName =
                            c.ColumnName.Equals("ViolationTypeName_A", StringComparison.OrdinalIgnoreCase);

                        bool isPaymentStatusName =
                            c.ColumnName.Equals("PaymentStatusName_A", StringComparison.OrdinalIgnoreCase);

                        List<OptionItem> filterOpts = new();

                        if (isViolationTypeName || isPaymentStatusName)
                        {
                            var field = c.ColumnName;

                            var distinctVals = dtList.AsEnumerable()
                                .Select(r => (r[field] == DBNull.Value ? "" : r[field]?.ToString())?.Trim())
                                .Where(s => !string.IsNullOrWhiteSpace(s))
                                .Distinct()
                                .OrderBy(s => s)
                                .ToList();

                            filterOpts = distinctVals
                                .Select(s => new OptionItem
                                {
                                    Value = s!,
                                    Text = s!
                                })
                                .ToList();
                        }

                        dynamicColumns.Add(new TableColumn
                        {
                            Field = c.ColumnName,
                            Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                            Type = colType,
                            Sortable = true,
                            Visible = !isHidden,
                            Filter = (isViolationTypeName || isPaymentStatusName)
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

                    foreach (DataRow r in dtList.Rows)
                    {
                        var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

                        foreach (DataColumn c in dtList.Columns)
                        {
                            var val = r[c];
                            dict[c.ColumnName] = val == DBNull.Value ? null : val;
                        }

                        object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;

                        // Edit
                        dict["p01"] = Get("violationID");
                        dict["p02"] = Get("violationTypeRoot_FK");
                        dict["p03"] = Get("chassisNumber_FK");
                        dict["p04"] = Get("violationDate");
                        dict["p05"] = Get("violationPrice");
                        dict["p06"] = Get("violationLocation");

                        // Payment
                        dict["pay_p01"] = Get("violationID");
                        dict["pay_p02"] = Get("PaymentDate");

                        rowsList.Add(dict);
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.DataSetError = ex.Message;
            }

            // ------------------------------------------------------------
            // Add
            // ------------------------------------------------------------
            var addViolationFields = new List<FieldConfig>
            {
                new FieldConfig
                {
                    Name = "p01",
                    Label = "نوع المخالفة",
                    Type = "select",
                    Select2=true,
                    ColCss = "6",
                    Required = true,
                    Options = violationTypeOptions,
                    Icon = "fa-solid fa-list"
                },
                new FieldConfig
                {
                    Name = "p02",
                    Label = "رقم الشاصي",
                    Type = "select",
                    Select2=true,
                    ColCss = "6",
                    Required = true,
                    Options = chassisOptions,
                    Icon = "fa-solid fa-car-side"
                },
                new FieldConfig
                {
                    Name = "p03",
                    Label = "تاريخ المخالفة",
                    Type = "date",
                    ColCss = "4",
                    Required = true,
                    Icon = "fa fa-calendar"
                },
                new FieldConfig
                {
                    Name = "p04",
                    Label = "قيمة المخالفة",
                    Type = "text",
                    TextMode="money_sar",
                    ColCss = "4",
                    Required = true,
                    Icon = "/img/Saudi_Riyal_Symbol.svg",
                    MaxLength = 5
                },
                new FieldConfig
                {
                    Name = "p05",
                    Label = "موقع المخالفة",
                    Type = "text",
                    ColCss = "4",
                    Required = true,
                    Icon = "fa-solid fa-location-dot",
                    MaxLength = 200
                },

                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = "" },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() ?? "" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() ?? "" },

                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT" },
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "Violation_Upsert" },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = "Violation" },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = "Vehicle" },
            };

            // ------------------------------------------------------------
            // Edit
            // ------------------------------------------------------------
            var editViolationFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Type = "hidden" },

                new FieldConfig
                {
                    Name = "p02",
                    Label = "نوع المخالفة",
                    Type = "select",
                    ColCss = "6",
                    Required = true,
                    Options = violationTypeOptions,
                    Icon = "fa-solid fa-list"
                },
                new FieldConfig
                {
                    Name = "p03",
                    Label = "رقم الشاصي",
                    Type = "text",
                    ColCss = "6",
                    Readonly = true,
                    Icon = "fa-solid fa-car-side"
                },
                new FieldConfig
                {
                    Name = "p04",
                    Label = "تاريخ المخالفة",
                    Type = "date",
                    ColCss = "4",
                    Required = true,
                    Icon = "fa fa-calendar"
                },
                new FieldConfig
                {
                    Name = "p05",
                    Label = "قيمة المخالفة",
                    Type = "text",
                    ColCss = "4",
                    Required = true,
                    Icon = "fa-solid fa-money-bill-1-wave",
                    MaxLength = 50
                },
                new FieldConfig
                {
                    Name = "p06",
                    Label = "موقع المخالفة",
                    Type = "text",
                    ColCss = "4",
                    Required = true,
                    Icon = "fa-solid fa-location-dot",
                    MaxLength = 200
                },

                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = "" },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() ?? "" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() ?? "" },

                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATE" },
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "Violation_Upsert" },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = "Violation" },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = "Vehicle" },
            };

            // ------------------------------------------------------------
            // Payment
            // ------------------------------------------------------------
            var payViolationFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Type = "hidden", Value = "" },

                new FieldConfig
                {
                    Name = "p02",
                    Label = "تاريخ السداد",
                    Type = "date",
                    ColCss = "12",
                    Required = true,
                    Icon = "fa fa-calendar"
                },

                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = "" },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() ?? "" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() ?? "" },

                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "PAYMENT" },
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "Violation_SetPayment" },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = "Violation" },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = "Vehicle" },
            };

            // ------------------------------------------------------------
            // Table
            // ------------------------------------------------------------
            var dsModel = new SmartTableDsModel
            {
                PageTitle = "المخالفات",
                PanelTitle = "إدارة المخالفات",
                RowIdField = rowIdField,
                Columns = dynamicColumns,
                Rows = rowsList,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50 },
                Searchable = true,
                ShowFilter = true,
                FilterRow = true,
                ShowColumnVisibility = true,
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowExportPdf = false,
                    ShowPrint1 = false,
                    ShowBulkDelete = false,

                    ShowAdd = canADDVIOLATION,
                    ShowEdit = canEDITVIOLATION,
                    ShowDelete = canPAYVIOLATION,

                    Add = new TableAction
                    {
                        Label = "إضافة مخالفة",
                        Icon = "fa fa-plus-circle",
                        Color = "success",
                        OpenModal = true,
                        RequireSelection = false,
                        ModalTitle = "إضافة مخالفة",
                        OpenForm = new FormConfig
                        {
                            FormId = "AddViolationForm",
                            Title = "إضافة مخالفة",
                            Method = "post",
                            ActionUrl = "/Crud/Insert",
                            Fields = addViolationFields
                        }
                    },

                    Edit = new TableAction
                    {
                        Label = "تعديل مخالفة",
                        Icon = "fa-solid fa-pen",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                        ModalTitle = "تعديل مخالفة",
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        OpenForm = new FormConfig
                        {
                            FormId = "EditViolationForm",
                            Title = "تعديل مخالفة",
                            Method = "post",
                            ActionUrl = "/Crud/Update",
                            Fields = editViolationFields
                        }
                    },

                    Delete = new TableAction
                    {
                        Label = "تسجيل سداد مخالفة",
                        Icon = "fa-solid fa-money-bill-wave",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                        ModalTitle = "تسجيل سداد مخالفة",
                        OpenForm = new FormConfig
                        {
                            FormId = "PayViolationForm",
                            Title = "تسجيل سداد مخالفة",
                            Method = "post",
                            ActionUrl = "/Crud/Update",
                            Fields = payViolationFields
                        },
                        Guards = new TableActionGuards
                        {
                            AppliesTo = "any",
                            DisableWhenAny = new List<TableActionRule>
                            {
                                new TableActionRule
                                {
                                    Field = "IsPaid",
                                    Op = "eq",
                                    Value = "True",
                                    Message = "المخالفة مسددة مسبقًا",
                                    Priority = 1
                                },
                                new TableActionRule
                                {
                                    Field = "IsPaid",
                                    Op = "eq",
                                    Value = "1",
                                    Message = "المخالفة مسددة مسبقًا",
                                    Priority = 1
                                }
                            }
                        }
                    },

                    CustomActions = new List<TableAction>
                    {
                        new TableAction
                        {
                            Label = "عرض التفاصيل",
                            Icon = "fa-regular fa-file",
                            OpenModal = true,
                            RequireSelection = true,
                            MinSelection = 1,
                            MaxSelection = 1,
                            ModalTitle = "عرض التفاصيل"
                        }
                    }
                }
            };

            dsModel.StyleRules = new List<TableStyleRule>
{
    new TableStyleRule
    {
        Target = "row",
        Field = "PaymentStatusName_A",
        Op = "eq",
        Value = "مسددة",
        Priority = 1,
        PillEnabled = true,
        PillField = "PaymentStatusName_A",
        PillTextField = "PaymentStatusName_A",
        PillCssClass = "pill pill-green",
        PillMode = "replace"
    },
    new TableStyleRule
    {
        Target = "row",
        Field = "PaymentStatusName_A",
        Op = "eq",
        Value = "غير مسددة",
        Priority = 1,
        PillEnabled = true,
        PillField = "PaymentStatusName_A",
        PillTextField = "PaymentStatusName_A",
        PillCssClass = "pill pill-red",
        PillMode = "replace"
    }
};

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-solid fa-triangle-exclamation",
                TableDS = dsModel
            };

            return View("Violation", page);
        }
    }
}