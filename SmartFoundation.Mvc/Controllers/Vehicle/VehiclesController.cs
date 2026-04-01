using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using SmartFoundation.Application.Services;
using SmartFoundation.Mvc.Models;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Reflection.Metadata.Ecma335;

namespace SmartFoundation.Mvc.Controllers.VIC
{
    public partial class VehiclesController : Controller
    {
        

        //        private readonly VehicleService _vehicleService;


        //        private readonly IConfiguration _configuration;

        //        private const int PARENT_OWNER = 1;
        //        private const int PARENT_MANUFACTURER = 2;
        //        private const int PARENT_MODEL = 3;
        //        private const int PARENT_CLASS = 4;
        //        private const int PARENT_USE_TYPE = 5;
        //        private const int PARENT_COLOR = 6;
        //        private const int PARENT_COUNTRY = 7;
        //        private const int PARENT_REGISTRATION_TYPE = 8;
        //        private const int PARENT_REGION = 9;
        //        private const int PARENT_FUEL = 172;
        //        private const int PARENT_VEHICLE_TYPE = 175;

        //        public VehiclesController(
        //     VehicleService vehicleService,
        //     IConfiguration configuration,
        //     MastersServies mastersServies,
        //     CrudController crudController,
        //     IWebHostEnvironment env)
        //        {
        //            _vehicleService = vehicleService;
        //            _configuration = configuration;
        //            _mastersServies = mastersServies;
        //            _CrudController = crudController;
        //            _env = env;
        //        }

        //        /* =========================================================
        //           Description:
        //           شاشة المركبات الرئيسية.
        //           - تجلب قائمة المركبات من VIC.Vehicle_List_EXT_DL
        //           - تبني صفوف الجدول
        //           - تضبط أعمدة العرض
        //           - تجهز نموذج الإضافة والتعديل
        //           - التعديل هنا يتم بنفس أسلوب الإسكان:
        //             من بيانات الصف المحدد مباشرة عبر IsEdit = true
        //             بدون fetch وبدون أكشن Edit مستقلة
        //           Type: UI / LIST
        //        ========================================================= */
        //        public async Task<IActionResult> Index()
        //        {
        //            var controllerName = "Vehicle";
        //            var actionName = "Index";
        //            var rowIdField = "chassisNumber";
        //            var menuLink = "/Vehicle/Index";
        //            var crudPageName = "Vehicle_Upsert";

        //            var usersIdStr = HttpContext.Session.GetString("usersID");
        //            var idaraIdStr = HttpContext.Session.GetString("IdaraID");

        //            var usersId = int.TryParse(usersIdStr, out var u) ? u : 0;
        //            var idaraId = int.TryParse(idaraIdStr, out var i) ? i : 1;
        //            var hostName = Request.Host.Value;

        //            var rows = new List<Dictionary<string, object?>>();

        //            var q = Request.Query["q"].FirstOrDefault();
        //            var ownerId = Request.Query["ownerID_FK"].FirstOrDefault();
        //            var plateLetters = Request.Query["plateLetters"].FirstOrDefault();

        //            int? plateNumbers = null;
        //            if (int.TryParse(Request.Query["plateNumbers"].FirstOrDefault(), out var pn))
        //                plateNumbers = pn;

        //            bool? hasCustody = null;
        //            if (bool.TryParse(Request.Query["HasCustody"].FirstOrDefault(), out var hc))
        //                hasCustody = hc;

        //            bool? hasActiveRequest = null;
        //            if (bool.TryParse(Request.Query["HasActiveRequest"].FirstOrDefault(), out var har))
        //                hasActiveRequest = har;

        //            int pageNumber = 1;
        //            if (int.TryParse(Request.Query["PageNumber"].FirstOrDefault(), out var pg) && pg > 0)
        //                pageNumber = pg;

        //            int pageSize = 50;
        //            if (int.TryParse(Request.Query["PageSize"].FirstOrDefault(), out var ps) && ps > 0)
        //                pageSize = ps;

        //            var dt = await GetVehicleListExt(
        //                usersId,
        //                menuLink,
        //                q,
        //                ownerId,
        //                plateLetters,
        //                plateNumbers,
        //                hasCustody,
        //                hasActiveRequest,
        //                pageNumber,
        //                pageSize,
        //                idaraId.ToString()
        //            );

        //            foreach (DataRow r in dt.Rows)
        //            {
        //                var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

        //                foreach (DataColumn c in dt.Columns)
        //                {
        //                    var val = r[c];
        //                    dict[c.ColumnName] = val == DBNull.Value ? null : val;
        //                }

        //                object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;

        //                dict["p01"] = Get("chassisNumber");
        //                dict["p02"] = Get("ownerID_FK");
        //                dict["p03"] = Get("manufacturerID_FK");
        //                dict["p04"] = Get("modelID_FK");
        //                dict["p05"] = Get("classID_FK");
        //                dict["p06"] = Get("useTypeID_FK");
        //                dict["p07"] = Get("colorID_FK");
        //                dict["p08"] = Get("countryID_FK");
        //                dict["p09"] = Get("registrationTypeID_FK");
        //                dict["p10"] = Get("regionID_FK");
        //                dict["p11"] = Get("fuelTypeID_FK");
        //                dict["p12"] = Get("vehicleTypeID_FK");
        //                dict["p13"] = Get("yearModel");
        //                dict["p14"] = Get("capacity");
        //                dict["p15"] = Get("serialNumber");
        //                dict["p16"] = Get("plateLetters");
        //                dict["p17"] = Get("plateNumbers");
        //                dict["p18"] = Get("armyNumber");
        //                dict["p19"] = Get("vehicleNote");

        //                rows.Add(dict);
        //            }

        //            var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        //            {
        //                ["vehicleID"] = "رقم المركبة",
        //                ["chassisNumber"] = "رقم الشاصي",
        //                ["ownerID_FK"] = "المالك",
        //                ["plateLetters"] = "حروف اللوحة",
        //                ["plateNumbers"] = "أرقام اللوحة",
        //                ["armyNumber"] = "الرقم العسكري",
        //                ["yearModel"] = "الموديل",
        //                ["entryDate"] = "تاريخ الإدخال",
        //                ["CurrentUserID"] = "المستخدم الحالي",
        //                ["CustodyStartDate"] = "تاريخ بداية العهدة",
        //                ["ActiveRequestLastActionDate"] = "آخر إجراء",
        //                ["vehicleNote"] = "ملاحظات المركبة",
        //                ["ActiveRequestLastStatus"] = "حالة الطلب",
        //                ["ActiveRequestID"] = "رقم الطلب"
        //            };

        //            var columns = new List<TableColumn>();

        //            if (rows.Count > 0)
        //            {
        //                foreach (var key in rows[0].Keys)
        //                {
        //                    if (key.StartsWith("p", StringComparison.OrdinalIgnoreCase) &&
        //                        key.Length <= 3 &&
        //                        int.TryParse(key.Substring(1), out _))
        //                    {
        //                        continue;
        //                    }

        //                    columns.Add(new TableColumn
        //                    {
        //                        Field = key,
        //                        Label = headerMap.TryGetValue(key, out var arabicName) ? arabicName : key,
        //                        Type = "text",
        //                        Sortable = true,
        //                        Visible = true
        //                    });
        //                }
        //            }

        //            var owners = await GetTypesRootOptions(usersId, menuLink, PARENT_OWNER);
        //            var manufacturers = await GetTypesRootOptions(usersId, menuLink, PARENT_MANUFACTURER);
        //            var models = await GetTypesRootOptions(usersId, menuLink, PARENT_MODEL);
        //            var classes = await GetTypesRootOptions(usersId, menuLink, PARENT_CLASS);
        //            var useTypes = await GetTypesRootOptions(usersId, menuLink, PARENT_USE_TYPE);
        //            var colors = await GetTypesRootOptions(usersId, menuLink, PARENT_COLOR);
        //            var countries = await GetTypesRootOptions(usersId, menuLink, PARENT_COUNTRY);
        //            var regTypes = await GetTypesRootOptions(usersId, menuLink, PARENT_REGISTRATION_TYPE);
        //            var regions = await GetTypesRootOptions(usersId, menuLink, PARENT_REGION);
        //            var fuels = await GetTypesRootOptions(usersId, menuLink, PARENT_FUEL);
        //            var vehicleTypes = await GetTypesRootOptions(usersId, menuLink, PARENT_VEHICLE_TYPE);

        //            TempData["DataSetError"] =
        //                $"owners={owners.Count}, manufacturers={manufacturers.Count}, models={models.Count}, classes={classes.Count}, colors={colors.Count}, fuels={fuels.Count}, vehicleTypes={vehicleTypes.Count}";

        //            var addFields = new List<FieldConfig>
        //            {
        //                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "" },
        //                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = actionName },
        //                new FieldConfig { Name = "redirectController", Type = "hidden", Value = controllerName },
        //                new FieldConfig { Name = "pageName_", Type = "hidden", Value = crudPageName },
        //                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT" },
        //                new FieldConfig { Name = "idaraID", Type = "hidden", Value = idaraId.ToString() },
        //                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId.ToString() },
        //                new FieldConfig { Name = "hostname", Type = "hidden", Value = hostName },
        //                new FieldConfig { Name = rowIdField, Type = "hidden" },

        //                new FieldConfig { Name = "p01", Label = "رقم الهيكل", Type = "text", ColCss = "6", Required = true },
        //                new FieldConfig { Name = "p02", Label = "المالك", Type = "select", ColCss = "6", Options = owners },
        //                new FieldConfig { Name = "p03", Label = "الشركة المصنعة", Type = "select", ColCss = "6", Options = manufacturers },
        //                new FieldConfig { Name = "p04", Label = "طراز المركبة", Type = "select", ColCss = "6", Options = models },
        //                new FieldConfig { Name = "p05", Label = "صنف المركبة", Type = "select", ColCss = "6", Options = classes },
        //                new FieldConfig { Name = "p06", Label = "نوع الاستخدام", Type = "select", ColCss = "6", Options = useTypes },
        //                new FieldConfig { Name = "p07", Label = "لون المركبة", Type = "select", ColCss = "6", Options = colors },
        //                new FieldConfig { Name = "p08", Label = "الدولة المصنعة", Type = "select", ColCss = "6", Options = countries },
        //                new FieldConfig { Name = "p09", Label = "نوع التسجيل", Type = "select", ColCss = "6", Options = regTypes },
        //                new FieldConfig { Name = "p10", Label = "المنطقة", Type = "select", ColCss = "6", Options = regions },
        //                new FieldConfig { Name = "p11", Label = "نوع الوقود", Type = "select", ColCss = "6", Options = fuels },
        //                new FieldConfig { Name = "p12", Label = "نوع العربة", Type = "select", ColCss = "6", Options = vehicleTypes },
        //                new FieldConfig { Name = "p13", Label = "الموديل", Type = "number", ColCss = "4" },
        //                new FieldConfig { Name = "p14", Label = "السعة", Type = "number", ColCss = "4" },
        //                new FieldConfig { Name = "p15", Label = "الرقم التسلسلي", Type = "text", ColCss = "4" },
        //                new FieldConfig { Name = "p16", Label = "حروف اللوحة", Type = "text", ColCss = "6" },
        //                new FieldConfig { Name = "p17", Label = "أرقام اللوحة", Type = "number", ColCss = "6" },
        //                new FieldConfig { Name = "p18", Label = "الرقم العسكري", Type = "text", ColCss = "6" },
        //                new FieldConfig { Name = "p19", Label = "ملاحظات", Type = "textarea", ColCss = "6" }
        //            };

        //            var updateFields = new List<FieldConfig>
        //            {
        //                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "" },
        //                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = actionName },
        //                new FieldConfig { Name = "redirectController", Type = "hidden", Value = controllerName },
        //                new FieldConfig { Name = "pageName_", Type = "hidden", Value = crudPageName },
        //                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATE" },
        //                new FieldConfig { Name = "idaraID", Type = "hidden", Value = idaraId.ToString() },
        //                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId.ToString() },
        //                new FieldConfig { Name = "hostname", Type = "hidden", Value = hostName },
        //                new FieldConfig { Name = rowIdField, Type = "hidden" },

        //                new FieldConfig { Name = "p01", Label = "رقم الهيكل", Type = "text", Readonly = true, ColCss = "6", Required = true },
        //                new FieldConfig { Name = "p02", Label = "المالك", Type = "select", ColCss = "6", Options = owners },
        //                new FieldConfig { Name = "p03", Label = "الشركة المصنعة", Type = "select", ColCss = "6", Options = manufacturers },
        //                new FieldConfig { Name = "p04", Label = "طراز المركبة", Type = "select", ColCss = "6", Options = models },
        //                new FieldConfig { Name = "p05", Label = "صنف المركبة", Type = "select", ColCss = "6", Options = classes },
        //                new FieldConfig { Name = "p06", Label = "نوع الاستخدام", Type = "select", ColCss = "6", Options = useTypes },
        //                new FieldConfig { Name = "p07", Label = "لون المركبة", Type = "select", ColCss = "6", Options = colors },
        //                new FieldConfig { Name = "p08", Label = "الدولة المصنعة", Type = "select", ColCss = "6", Options = countries },
        //                new FieldConfig { Name = "p09", Label = "نوع التسجيل", Type = "select", ColCss = "6", Options = regTypes },
        //                new FieldConfig { Name = "p10", Label = "المنطقة", Type = "select", ColCss = "6", Options = regions },
        //                new FieldConfig { Name = "p11", Label = "نوع الوقود", Type = "select", ColCss = "6", Options = fuels },
        //                new FieldConfig { Name = "p12", Label = "نوع العربة", Type = "select", ColCss = "6", Options = vehicleTypes },
        //                new FieldConfig { Name = "p13", Label = "الموديل", Type = "number", ColCss = "4" },
        //                new FieldConfig { Name = "p14", Label = "السعة", Type = "number", ColCss = "4" },
        //                new FieldConfig { Name = "p15", Label = "الرقم التسلسلي", Type = "text", ColCss = "4" },
        //                new FieldConfig { Name = "p16", Label = "حروف اللوحة", Type = "text", ColCss = "6" },
        //                new FieldConfig { Name = "p17", Label = "أرقام اللوحة", Type = "number", ColCss = "6" },
        //                new FieldConfig { Name = "p18", Label = "الرقم العسكري", Type = "text", ColCss = "6" },
        //                new FieldConfig { Name = "p19", Label = "ملاحظات", Type = "textarea", ColCss = "6" }
        //            };

        //            var printFields = new List<FieldConfig>
        //            {
        //                new FieldConfig { Name = "print_vehicleID", Label = "رقم المركبة", Type = "checkbox", ColCss = "4", Value = "true" },
        //                new FieldConfig { Name = "print_chassisNumber", Label = "رقم الشاصي", Type = "checkbox", ColCss = "4", Value = "true" },
        //                new FieldConfig { Name = "print_ownerID_FK", Label = "المالك", Type = "checkbox", ColCss = "4", Value = "true" },
        //                new FieldConfig { Name = "print_plateLetters", Label = "حروف اللوحة", Type = "checkbox", ColCss = "4", Value = "true" },
        //                new FieldConfig { Name = "print_plateNumbers", Label = "أرقام اللوحة", Type = "checkbox", ColCss = "4", Value = "true" },
        //                new FieldConfig { Name = "print_armyNumber", Label = "الرقم العسكري", Type = "checkbox", ColCss = "4", Value = "true" },
        //                new FieldConfig { Name = "print_yearModel", Label = "الموديل", Type = "checkbox", ColCss = "4", Value = "true" },
        //                new FieldConfig { Name = "print_vehicleNote", Label = "ملاحظات المركبة", Type = "checkbox", ColCss = "4", Value = "true" },
        //                new FieldConfig { Name = "print_entryDate", Label = "تاريخ الإدخال", Type = "checkbox", ColCss = "4" }
        //            };

        //            var tableModel = new SmartTableDsModel
        //            {
        //                ShowFilter = true,
        //                FilterRow = true,
        //                Columns = columns,
        //                Rows = rows,
        //                RowIdField = rowIdField,
        //                PageSize = 10,
        //                PageSizes = new List<int> { 10, 25, 50, 100 },
        //                QuickSearchFields = new List<string> { "chassisNumber", "plateNumbers", "armyNumber" },
        //                Searchable = true,
        //                AllowExport = true,
        //                PageTitle = "المركبات",
        //                PanelTitle = "قائمة المركبات",
        //                EnableCellCopy = true,
        //                Toolbar = new TableToolbarConfig
        //                {
        //                    ShowRefresh = true,
        //                    ShowColumns = true,
        //                    ShowAdvancedFilter = true,
        //                    ShowPrint = true,
        //                    ShowExportPdf = true,
        //                    ShowExportCsv = false,
        //                    ShowExportExcel = false,

        //                    ShowAdd = true,
        //                    ShowAdd1 = true,
        //                    ShowAdd2 = true,
        //                    ShowEdit = true,
        //                    ShowDelete = false,
        //                    ShowBulkDelete = false,

        //                    Add = new TableAction
        //                    {
        //                        Label = "إضافة مركبة",
        //                        Icon = "fa fa-plus",
        //                        Color = "success",
        //                        OpenModal = true,
        //                        ModalTitle = "إدخال مركبة جديدة",
        //                        OpenForm = new FormConfig
        //                        {
        //                            FormId = "vehicleInsertForm",
        //                            Title = "إدخال مركبة جديدة",
        //                            Method = "post",
        //                            ActionUrl = "/crud/insert",
        //                            Fields = addFields,
        //                            Buttons = new List<FormButtonConfig>
        //                            {
        //                                new FormButtonConfig
        //                                {
        //                                    Text = "حفظ",
        //                                    Type = "submit",
        //                                    Color = "success"
        //                                },
        //                                new FormButtonConfig
        //                                {
        //                                    Text = "إلغاء",
        //                                    Type = "button",
        //                                    Color = "secondary",
        //                                    OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();"
        //                                }
        //                            }
        //                        }
        //                    },

        //                    Add1 = new TableAction
        //                    {
        //                        Label = "عرض التفاصيل",
        //                        Icon = "fa fa-file-lines",
        //                        Color = "secondary",
        //                        RequireSelection = true,
        //                        MinSelection = 1,
        //                        MaxSelection = 1,
        //                        OnClickJs = @"
        //try {
        //    const row = table.getSelectedRowFromCurrentData?.() || (table.getSelectedRows?.()[0] ?? null);
        //    if (!row) {
        //        alert('اختر صف أولاً');
        //        return false;
        //    }

        //    const id = row.chassisNumber || row.p01;
        //    if (!id) {
        //        alert('ما فيه رقم هيكل');
        //        return false;
        //    }

        //    window.location.href = '/Vehicle/Profile?id=' + encodeURIComponent(id);
        //    return true;
        //} catch (e) {
        //    console.error(e);
        //    alert('خطأ في التنفيذ');
        //    return false;
        //}"
        //                    },

        //                    Add2 = new TableAction
        //                    {
        //                        Label = "فلترة",
        //                        Icon = "fa fa-filter",
        //                        Color = "primary",
        //                        OpenModal = true,
        //                        ModalTitle = "فلترة المركبات",
        //                        OpenForm = new FormConfig
        //                        {
        //                            FormId = "vehicleFilterForm",
        //                            Title = "فلترة المركبات",
        //                            Method = "get",
        //                            ActionUrl = "/Vehicle/Index",
        //                            Fields = new List<FieldConfig>
        //                            {
        //                                new FieldConfig
        //                                {
        //                                    Name = "q",
        //                                    Label = "بحث عام",
        //                                    Type = "text",
        //                                    ColCss = "4",
        //                                    Value = q
        //                                },
        //                                new FieldConfig
        //                                {
        //                                    Name = "ownerID_FK",
        //                                    Label = "المالك",
        //                                    Type = "select",
        //                                    ColCss = "4",
        //                                    Options = owners,
        //                                    Value = ownerId
        //                                },
        //                                new FieldConfig
        //                                {
        //                                    Name = "plateLetters",
        //                                    Label = "حروف اللوحة",
        //                                    Type = "text",
        //                                    ColCss = "4",
        //                                    Value = plateLetters
        //                                },
        //                                new FieldConfig
        //                                {
        //                                    Name = "plateNumbers",
        //                                    Label = "أرقام اللوحة",
        //                                    Type = "number",
        //                                    ColCss = "4",
        //                                    Value = plateNumbers?.ToString()
        //                                },
        //                                new FieldConfig
        //                                {
        //                                    Name = "HasCustody",
        //                                    Label = "لها عهدة",
        //                                    Type = "select",
        //                                    ColCss = "4",
        //                                    Options = new List<OptionItem>
        //                                    {
        //                                        new OptionItem { Value = "", Text = "الكل" },
        //                                        new OptionItem { Value = "true", Text = "نعم" },
        //                                        new OptionItem { Value = "false", Text = "لا" }
        //                                    },
        //                                    Value = hasCustody?.ToString()?.ToLower()
        //                                },
        //                                new FieldConfig
        //                                {
        //                                    Name = "HasActiveRequest",
        //                                    Label = "لها طلب نشط",
        //                                    Type = "select",
        //                                    ColCss = "4",
        //                                    Options = new List<OptionItem>
        //                                    {
        //                                        new OptionItem { Value = "", Text = "الكل" },
        //                                        new OptionItem { Value = "true", Text = "نعم" },
        //                                        new OptionItem { Value = "false", Text = "لا" }
        //                                    },
        //                                    Value = hasActiveRequest?.ToString()?.ToLower()
        //                                }
        //                            },
        //                            Buttons = new List<FormButtonConfig>
        //                            {
        //                                new FormButtonConfig
        //                                {
        //                                    Text = "تطبيق الفلترة",
        //                                    Type = "submit",
        //                                    Color = "primary",
        //                                    Icon = "fa fa-filter"
        //                                },
        //                                new FormButtonConfig
        //                                {
        //                                    Text = "إلغاء",
        //                                    Type = "button",
        //                                    Color = "secondary",
        //                                    OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();"
        //                                }
        //                            }
        //                        }
        //                    },

        //                    Edit = new TableAction
        //                    {
        //                        Label = "تعديل بيانات مركبة",
        //                        Icon = "fa-pen-to-square",
        //                        Color = "info",
        //                        IsEdit = true,
        //                        OpenModal = true,
        //                        ModalTitle = "تعديل بيانات مركبة",
        //                        OpenForm = new FormConfig
        //                        {
        //                            FormId = "vehicleEditForm",
        //                            Title = "تعديل بيانات المركبة",
        //                            Method = "post",
        //                            ActionUrl = "/crud/update",
        //                            SubmitText = "حفظ التعديلات",
        //                            CancelText = "إلغاء",
        //                            Fields = updateFields
        //                        },
        //                        RequireSelection = true,
        //                        MinSelection = 1,
        //                        MaxSelection = 1
        //                    },
        //                    Print = new TableAction
        //                    {
        //                        Label = "طباعة",
        //                        Icon = "fa fa-print",
        //                        Color = "primary",
        //                        OpenModal = true,
        //                        ModalTitle = "اختيار أعمدة الطباعة",
        //                        OpenForm = new FormConfig
        //                        {
        //                            FormId = "vehiclePrintForm",
        //                            Title = "اختيار أعمدة الطباعة",
        //                            Method = "post",
        //                            ActionUrl = "#",
        //                            Fields = printFields,
        //                            Buttons = new List<FormButtonConfig>
        //        {
        //            new FormButtonConfig
        //            {
        //                Text = "طباعة",
        //                Type = "button",
        //                Color = "primary",
        //                Icon = "fa fa-print",
        //                OnClickJs = "return window.printVehicleSelectedColumns();"
        //            },
        //            new FormButtonConfig
        //            {
        //                Text = "إلغاء",
        //                Type = "button",
        //                Color = "secondary",
        //                OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();"
        //            }
        //        }
        //                        }
        //                    }
        //                }
        //            };

        //            var vm = new SmartPageViewModel
        //            {
        //                PageTitle = "المركبات",
        //                PanelTitle = "قائمة المركبات",
        //                PanelIcon = "fa fa-car",
        //                TableDS = tableModel
        //            };

        //            return View(vm);
        //        }

        //        /* =========================================================
        //           Description:
        //           جلب قائمة المركبات مع الفلاتر.
        //           Type: READ / LIST
        //        ========================================================= */
        //        private async Task<DataTable> GetVehicleListExt(
        //            int usersId,
        //            string menuLink,
        //            string? q,
        //            string? ownerId,
        //            string? plateLetters,
        //            int? plateNumbers,
        //            bool? hasCustody,
        //            bool? hasActiveRequest,
        //            int pageNumber,
        //            int pageSize,
        //            string? idaraId)
        //        {
        //            var dt = new DataTable();
        //            var connectionString = ResolveConnectionString();

        //            if (string.IsNullOrWhiteSpace(connectionString))
        //                return dt;

        //            await using var conn = new SqlConnection(connectionString);
        //            await using var cmd = new SqlCommand("VIC.Vehicle_List_EXT_DL", conn)
        //            {
        //                CommandType = CommandType.StoredProcedure
        //            };

        //            cmd.Parameters.AddWithValue("@UsersID", usersId);
        //            cmd.Parameters.AddWithValue("@MenuLink", menuLink ?? (object)DBNull.Value);
        //            cmd.Parameters.AddWithValue("@SkipPermission", 1);

        //            cmd.Parameters.AddWithValue("@q", string.IsNullOrWhiteSpace(q) ? (object)DBNull.Value : q);
        //            cmd.Parameters.AddWithValue("@ownerID_FK", string.IsNullOrWhiteSpace(ownerId) ? (object)DBNull.Value : ownerId);
        //            cmd.Parameters.AddWithValue("@plateLetters", string.IsNullOrWhiteSpace(plateLetters) ? (object)DBNull.Value : plateLetters);
        //            cmd.Parameters.AddWithValue("@plateNumbers", plateNumbers.HasValue ? plateNumbers.Value : (object)DBNull.Value);
        //            cmd.Parameters.AddWithValue("@HasCustody", hasCustody.HasValue ? hasCustody.Value : (object)DBNull.Value);
        //            cmd.Parameters.AddWithValue("@HasActiveRequest", hasActiveRequest.HasValue ? hasActiveRequest.Value : (object)DBNull.Value);
        //            cmd.Parameters.AddWithValue("@PageNumber", pageNumber);
        //            cmd.Parameters.AddWithValue("@PageSize", pageSize);
        //            cmd.Parameters.AddWithValue("@idaraID_FK", string.IsNullOrWhiteSpace(idaraId) ? (object)DBNull.Value : idaraId);

        //            await conn.OpenAsync();

        //            using var adapter = new SqlDataAdapter(cmd);
        //            adapter.Fill(dt);

        //            return dt;
        //        }

        //        /* =========================================================
        //           Description:
        //           تحميل قوائم الاختيار من TypesRoot عبر Vehicle_GetLookups_DL
        //           لاستخدامها في النماذج.
        //           Type: READ / LOOKUPS
        //        ========================================================= */
        //        private async Task<List<OptionItem>> GetTypesRootOptions(int usersId, string menuLink, int parentId)
        //        {
        //            var list = new List<OptionItem>();
        //            var connectionString = ResolveConnectionString();

        //            if (string.IsNullOrWhiteSpace(connectionString))
        //                return list;

        //            await using var conn = new SqlConnection(connectionString);
        //            await using var cmd = new SqlCommand("VIC.Vehicle_GetLookups_DL", conn)
        //            {
        //                CommandType = CommandType.StoredProcedure
        //            };

        //            cmd.Parameters.AddWithValue("@UsersID", usersId);
        //            cmd.Parameters.AddWithValue("@MenuLink", menuLink ?? (object)DBNull.Value);
        //            cmd.Parameters.AddWithValue("@SkipPermission", 1);
        //            cmd.Parameters.AddWithValue("@TypesRoot_ParentID", parentId);

        //            await conn.OpenAsync();
        //            await using var reader = await cmd.ExecuteReaderAsync();

        //            while (await reader.ReadAsync())
        //            {
        //                list.Add(new OptionItem
        //                {
        //                    Value = reader["typesID"]?.ToString() ?? "",
        //                    Text = reader["typesName_A"]?.ToString()
        //                           ?? reader["typesName_E"]?.ToString()
        //                           ?? ""
        //                });
        //            }

        //            return list;
        //        }

        //        /* =========================================================
        //           Description:
        //           استخراج ConnectionString من الإعدادات.
        //        ========================================================= */
        //        private string? ResolveConnectionString()
        //        {
        //            return _configuration.GetConnectionString("Default")
        //                   ?? _configuration.GetConnectionString("DefaultConnection")
        //                   ?? _configuration.GetConnectionString("SmartConnection")
        //                   ?? _configuration.GetConnectionString("DATACOREV");
        //        }

        //        /* =========================================================
        //           Description:
        //           صفحة ملف المركبة التفصيلية.
        //           Type: READ / PROFILE
        //        ========================================================= */
        //        public async Task<IActionResult> Profile(string id)
        //        {
        //            if (string.IsNullOrWhiteSpace(id))
        //                return NotFound();

        //            var connectionString = ResolveConnectionString();
        //            if (string.IsNullOrWhiteSpace(connectionString))
        //                return Content("No Connection");

        //            var ds = new DataSet();

        //            using (var conn = new SqlConnection(connectionString))
        //            using (var cmd = new SqlCommand("VIC.Vehicle_Profile_Get_DL", conn))
        //            {
        //                cmd.CommandType = CommandType.StoredProcedure;

        //                cmd.Parameters.AddWithValue("@UsersID", 0);
        //                cmd.Parameters.AddWithValue("@MenuLink", DBNull.Value);
        //                cmd.Parameters.AddWithValue("@SkipPermission", 1);
        //                cmd.Parameters.AddWithValue("@chassisNumber", id);
        //                cmd.Parameters.AddWithValue("@TopDocuments", 20);
        //                cmd.Parameters.AddWithValue("@TopInsurance", 20);
        //                cmd.Parameters.AddWithValue("@TopMaintenance", 20);
        //                cmd.Parameters.AddWithValue("@TopViolations", 50);
        //                cmd.Parameters.AddWithValue("@idaraID_FK", DBNull.Value);

        //                await conn.OpenAsync();

        //                using (var adapter = new SqlDataAdapter(cmd))
        //                {
        //                    adapter.Fill(ds);
        //                }
        //            }

        //            var vm = new VehicleProfileVM
        //            {
        //                Summary = ds.Tables.Count > 0 ? ds.Tables[0] : new DataTable(),
        //                Documents = ds.Tables.Count > 1 ? ds.Tables[1] : new DataTable(),
        //                Insurance = ds.Tables.Count > 2 ? ds.Tables[2] : new DataTable(),
        //                Maintenance = ds.Tables.Count > 3 ? ds.Tables[3] : new DataTable(),
        //                Violations = ds.Tables.Count > 4 ? ds.Tables[4] : new DataTable()
        //            };

        //            return View("Profile", vm);
    
    }
}