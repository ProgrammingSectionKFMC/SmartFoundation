using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers.ControlPanel
{
    public partial class ControlPanelController : Controller
    {
        public async Task<IActionResult> PagesManagment()
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            string? SearchID_ = Request.Query["S"].FirstOrDefault();
            bool ready = true;

            ControllerName = nameof(ControlPanel);
            PageName = nameof(PagesManagment);

            var spParameters = new object?[] { "PagesManagment", IdaraId, usersId, HostName, SearchID_ };

            // ✅ قوائم منفصلة لكل جدول
            var rowsListPrograms = new List<Dictionary<string, object?>>();
            var dynamicColumnsPrograms = new List<TableColumn>();

            var rowsListMenu = new List<Dictionary<string, object?>>();
            var dynamicColumnsMenu = new List<TableColumn>();

            var rowsListPermissions = new List<Dictionary<string, object?>>();
            var dynamicColumnsPermissions = new List<TableColumn>();

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            SplitDataSet(ds);


            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            string? rowProgramsIdField = "";
            string? rowmenuDistributorIDField = "";
            string? rowdistributorPermissionTypeIDField = "";
            bool canInsert = false;
            bool canInsertFullAccess = false;
            bool canUpdate = false;
            bool canDelete = false;

            bool showPrograms = SearchID_ == "1";
            bool showMenu = SearchID_ == "2";
            bool showPermissions = SearchID_ == "3";

            FormConfig form = new();

            try
            {
                List<OptionItem> permissinTypeOptions = new()
                {
                    new OptionItem { Value = "1", Text = "برنامج" },
                    new OptionItem { Value = "2", Text = "صفحة" },
                    new OptionItem { Value = "3", Text = "صلاحية" },
                };

                form = new FormConfig
                {
                    Fields = new List<FieldConfig>
                    {
                        new FieldConfig
                        {
                            SectionTitle = "نوع البحث",
                            Name = "permissinType",
                            Type = "select",
                            Select2 = true,
                            Options = permissinTypeOptions,
                            ColCss = "3",
                            Value = SearchID_,
                            Placeholder = "اختر نوع البحث",
                            Icon = "fa fa-user",
                            NavUrl = "/ControlPanel/PagesManagment",
                            NavKey = "S",
                            OnChangeJs = "sfNav(this);"
                        },
                    },
                };

                // ✅ قراءة الصلاحيات من الجدول الأول
                if (ds != null && ds.Tables.Count > 0 && ds.Tables[0].Rows.Count > 0)
                {
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                        if (permissionName == "INSERT") canInsert = true;
                        if (permissionName == "UPDATE") canUpdate = true;
                        if (permissionName == "DELETE") canDelete = true;
                        if (permissionName == "INSERTFULLACCESS") canInsertFullAccess = true;
                    }

                    // ========== dt1: Programs ==========
                    if (dt1 != null && dt1.Columns.Count > 0)
                    {

                        // RowId
                        rowProgramsIdField = "programID";
                        var possibleIdNames = new[] { "programID", "ProgramID", "Id", "ID" };
                        rowProgramsIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["programID"] = "رقم البرنامج",
                            ["programName_A"] = "اسم البرنامج (عربي)",
                            ["programName_E"] = "اسم البرنامج (إنجليزي)",
                            ["programDescription"] = "الوصف",
                            ["programActive"] = "نشط",
                            ["programLink"] = "الرابط",
                            ["programIcon"] = "الأيقونة",
                            ["programSerial"] = "الترتيب"
                        };

                        foreach (DataColumn c in dt1.Columns)
                        {
                            string colType = "text";
                            var t = c.DataType;
                            if (t == typeof(bool)) colType = "bool";
                            else if (t == typeof(DateTime)) colType = "date";
                            else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || 
                                     t == typeof(long) || t == typeof(float) || t == typeof(double) || 
                                     t == typeof(decimal))
                                colType = "number";

                            dynamicColumnsPrograms.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,
                                Visible = true
                            });
                        }

                        foreach (DataRow r in dt1.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt1.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("programID");
                            dict["p02"] = Get("programName_A");
                            dict["p03"] = Get("programName_E");
                            dict["p04"] = Get("programDescription");
                            dict["p05"] = Get("programActive");
                            dict["p06"] = Get("programLink");
                            dict["p07"] = Get("programIcon");

                            rowsListPrograms.Add(dict);
                        }
                    }

                    // ========== dt2: Menu ==========
                    if (dt2 != null && dt2.Columns.Count > 0)
                    {
                        rowmenuDistributorIDField = "menuDistributorID";
                        var possibleIdNames = new[] { "menuDistributorID", "menuDistributorID", "Id", "ID" };
                        rowmenuDistributorIDField = possibleIdNames.FirstOrDefault(n => dt2.Columns.Contains(n))
                                     ?? dt2.Columns[0].ColumnName;

                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["menuDistributorID"] = "المعرف",
                            ["menuID"] = "رقم القائمة",
                            ["menuName_A"] = "اسم القائمة (عربي)",
                            ["menuName_E"] = "اسم القائمة (إنجليزي)",
                            ["distributorID"] = "رقم الموزع",
                            ["distributorName_A"] = "اسم الموزع",
                            ["menuDescription"] = "الوصف",
                            ["parentMenuID_FK"] = "القائمة الأب",
                            ["menuLink"] = "الرابط",
                            ["programID_FK"] = "البرنامج",
                            ["menuSerial"] = "الترتيب",
                            ["menuActive"] = "نشط",
                            ["isDashboard"] = "لوحة تحكم",
                            ["PageLvl"] = "المستوى"
                        };

                        foreach (DataColumn c in dt2.Columns)
                        {
                            string colType = "text";
                            var t = c.DataType;
                            if (t == typeof(bool)) colType = "bool";
                            else if (t == typeof(DateTime)) colType = "date";
                            else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || 
                                     t == typeof(long) || t == typeof(float) || t == typeof(double) || 
                                     t == typeof(decimal))
                                colType = "number";

                            bool isHidden = c.ColumnName.Equals("programID_FK", StringComparison.OrdinalIgnoreCase) ||
                                            c.ColumnName.Equals("parentMenuID_FK", StringComparison.OrdinalIgnoreCase);

                            dynamicColumnsMenu.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,
                                Visible = !isHidden
                            });
                        }

                        foreach (DataRow r in dt2.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt2.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("menuDistributorID");
                            dict["p02"] = Get("menuID");
                            dict["p03"] = Get("menuName_A");
                            dict["p04"] = Get("menuName_E");
                            dict["p05"] = Get("distributorID");
                            dict["p06"] = Get("menuLink");

                            rowsListMenu.Add(dict);
                        }
                    }

                    // ========== dt3: Permissions ==========
                    if (dt3 != null && dt3.Columns.Count > 0)
                    {

                        rowdistributorPermissionTypeIDField = "distributorPermissionTypeID";
                        var possibleIdNames = new[] { "distributorPermissionTypeID", "distributorPermissionTypeID", "Id", "ID" };
                        rowdistributorPermissionTypeIDField = possibleIdNames.FirstOrDefault(n => dt3.Columns.Contains(n))
                                     ?? dt3.Columns[0].ColumnName;

                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["distributorPermissionTypeID"] = "المعرف",
                            ["permissionTypeID_FK"] = "نوع الصلاحية",
                            ["DistributorID_FK"] = "رقم الموزع",
                            ["distributorName_A"] = "اسم الموزع",
                            ["distributorType_FK"] = "نوع الموزع",
                            ["permissionTypeName_A"] = "اسم الصلاحية",
                            ["permissionTypeName_E"] = "Permission Name",
                            ["distributorPermissionTypeStartDate"] = "تاريخ البداية",
                            ["distributorPermissionTypeEndDate"] = "تاريخ النهاية",
                            ["distributorPermissionTypeActive"] = "نشط"
                        };

                        foreach (DataColumn c in dt3.Columns)
                        {
                            string colType = "text";
                            var t = c.DataType;
                            if (t == typeof(bool)) colType = "bool";
                            else if (t == typeof(DateTime)) colType = "date";
                            else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || 
                                     t == typeof(long) || t == typeof(float) || t == typeof(double) || 
                                     t == typeof(decimal))
                                colType = "number";

                            bool isHidden = c.ColumnName.Equals("permissionTypeID_FK", StringComparison.OrdinalIgnoreCase) ||
                                            c.ColumnName.Equals("DistributorID_FK", StringComparison.OrdinalIgnoreCase) ||
                                            c.ColumnName.Equals("permissionAuthLvl", StringComparison.OrdinalIgnoreCase) ||
                                            c.ColumnName.Equals("distributorType_FK", StringComparison.OrdinalIgnoreCase);

                            dynamicColumnsPermissions.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,
                                Visible = !isHidden
                            });
                        }

                        foreach (DataRow r in dt3.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt3.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("distributorPermissionTypeID");
                            dict["p02"] = Get("permissionTypeID_FK");
                            dict["p03"] = Get("DistributorID_FK");
                            dict["p04"] = Get("distributorPermissionTypeStartDate");
                            dict["p05"] = Get("distributorPermissionTypeEndDate");

                            rowsListPermissions.Add(dict);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.DataSetError = ex.Message;
            }

            var currentUrl = Request.Path + Request.QueryString;



             var AddPorgramFieldFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "AddPorgram" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },


                new FieldConfig { Name = rowProgramsIdField, Type = "hidden" },


                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ActionID" },
                new FieldConfig { Name = "p02", Label = "residentInfoID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p14", Label = "الترتيب", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p15", Label = "الاسم", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p03", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p18", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p22", Label = "تاريخ الاخلاء", Type = "date", ColCss = "3",Required = true },
                new FieldConfig { Name = "p12", Label = "ملاحظات", Type = "textarea", ColCss = "12",Required = true,HelpText="لايجب ان يتجاوز النص 1000 حرف*",MaxLength=1000 },


            };


            var EditPorgramFieldFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "EditPorgram" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },


                new FieldConfig { Name = rowProgramsIdField, Type = "hidden" },


                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ActionID" },
                new FieldConfig { Name = "p02", Label = "residentInfoID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p14", Label = "الترتيب", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p15", Label = "الاسم", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p03", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p18", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p22", Label = "تاريخ الاخلاء", Type = "date", ColCss = "3",Required = true },
                new FieldConfig { Name = "p12", Label = "ملاحظات", Type = "textarea", ColCss = "12",Required = true,HelpText="لايجب ان يتجاوز النص 1000 حرف*",MaxLength=1000 },


            };


            var DeletePorgramFieldFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DeletePorgram" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },


                new FieldConfig { Name = rowProgramsIdField, Type = "hidden" },


                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ActionID" },
                new FieldConfig { Name = "p02", Label = "residentInfoID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p14", Label = "الترتيب", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p15", Label = "الاسم", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p03", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p18", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p22", Label = "تاريخ الاخلاء", Type = "date", ColCss = "3",Required = true },
                new FieldConfig { Name = "p12", Label = "ملاحظات", Type = "textarea", ColCss = "12",Required = true,HelpText="لايجب ان يتجاوز النص 1000 حرف*",MaxLength=1000 },


            };



            // ✅ إنشاء الـ Models بالبيانات الصحيحة
            var dsModelPrograms = new SmartTableDsModel
            {
                Columns = dynamicColumnsPrograms,
                Rows = rowsListPrograms,
                RowIdField = "programID",  // ✅ ثابت
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumnsPrograms.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PageTitle = "إدارة البرامج",
                PanelTitle = "إدارة البرامج",
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = true,
                    ShowColumns = true,
                    ShowAdd = canInsert,
                    ShowEdit = canUpdate,
                    ShowDelete = canDelete,
                    // أضف Actions هنا لاحقاً
                }
            };

            var dsModelMenu = new SmartTableDsModel
            {
                Columns = dynamicColumnsMenu,
                Rows = rowsListMenu,
                RowIdField = "menuDistributorID",  // ✅ ثابت
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumnsMenu.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PageTitle = "إدارة القوائم",
                PanelTitle = "إدارة القوائم",

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = canInsert,
                    ShowAdd1 = canInsertFullAccess,
                    ShowEdit = canUpdate,
                    ShowDelete = canDelete,
                    ShowBulkDelete = false,

                    Add = new TableAction
                    {
                        Label = "إضافة صلاحية",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة صلاحية جديدة",
                        OpenForm = new FormConfig
                        {
                            FormId = "InsertForm",
                            Title = "بيانات الموظف الجديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = AddPorgramFieldFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" /*Icon = "fa fa-save"*/ },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", /*Icon = "fa fa-times",*/ OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" },

                            }
                        }
                    },

                  

                    // Edit: opens populated form for single selection and saves via SP
                    Edit = new TableAction
                    {
                        Label = "تعديل صلاحية",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل بيانات الموظف",
                        //ModalMessage = "بسم الله الرحمن الرحيم",
                        OpenForm = new FormConfig
                        {
                            FormId = "employeeEditForm",
                            Title = "تعديل بيانات الموظف",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = EditPorgramFieldFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1


                    },

                    Delete = new TableAction
                    {
                        Label = "ايقاف صلاحية",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        //ModalTitle = "رسالة تحذيرية",
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من حذف هذا السجل؟",
                        OpenForm = new FormConfig
                        {
                            FormId = "employeeDeleteForm",
                            Title = "تأكيد حذف السجل",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حذف", Type = "submit", Color = "danger", Icon = "fa fa-save" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", Icon = "fa fa-times", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = DeletePorgramFieldFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                }
            };

            var dsModelPermission = new SmartTableDsModel
            {
                Columns = dynamicColumnsPermissions,
                Rows = rowsListPermissions,
                RowIdField = "distributorPermissionTypeID",  // ✅ ثابت
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumnsPermissions.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PageTitle = "إدارة الصلاحيات",
                PanelTitle = "إدارة الصلاحيات",
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = true,
                    ShowColumns = true,
                    ShowAdd = canInsert,
                    ShowEdit = canUpdate,
                    ShowDelete = canDelete,
                }
            };

            var vm = new SmartPageViewModel
            {
                PageTitle = "إدارة الصفحات",
                PanelTitle = "إدارة الصفحات",
                PanelIcon = "fa-user-shield",
                Form = form,
                TableDS = showPrograms ? dsModelPrograms : null,
                TableDS1 = showMenu ? dsModelMenu : null,
                TableDS2 = showPermissions ? dsModelPermission : null
            };



            return View("MenuManagment/PagesManagment", vm);
        }
    }
}