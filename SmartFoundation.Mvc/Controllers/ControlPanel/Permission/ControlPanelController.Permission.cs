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
        public async Task<IActionResult> Permission()
        {

            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }

            string? SearchID_ = Request.Query["S"].FirstOrDefault();
            string? UserID_ = Request.Query["U"].FirstOrDefault();
            string? distributorID_ = Request.Query["di"].FirstOrDefault();
            string? RoleID_ = Request.Query["Ro"].FirstOrDefault();
            string? Idara_ = Request.Query["Ida"].FirstOrDefault() ?? null;
            string? Dept_ = Request.Query["Dep"].FirstOrDefault() ?? null;
            string? Section_ = Request.Query["Sec"].FirstOrDefault() ?? null;
            string? Divison_ = Request.Query["Div"].FirstOrDefault() ?? null;
            UserID_ = string.IsNullOrWhiteSpace(UserID_) ? null : UserID_.Trim();
            distributorID_ = string.IsNullOrWhiteSpace(distributorID_) ? null : distributorID_.Trim();
            Idara_ = string.IsNullOrWhiteSpace(Idara_) ? null : Idara_.Trim();
            Dept_ = string.IsNullOrWhiteSpace(Dept_) ? null : Dept_.Trim();
            Section_ = string.IsNullOrWhiteSpace(Section_) ? null : Section_.Trim();
            Divison_ = string.IsNullOrWhiteSpace(Divison_) ? null : Divison_.Trim();

            
            bool ready =
            SearchID_ == "1" ? !string.IsNullOrWhiteSpace(UserID_) :
            SearchID_ == "2" ? !string.IsNullOrWhiteSpace(distributorID_) :
            SearchID_ == "3" ? !string.IsNullOrWhiteSpace(RoleID_) :
            SearchID_ == "4" ? !string.IsNullOrWhiteSpace(Idara_) :
            SearchID_ == "5" ? !string.IsNullOrWhiteSpace(Dept_) : false;



            // Sessions 

            ControllerName = nameof(ControlPanel);
            PageName = nameof(Permission);

            var spParameters = new object?[] { "Permission", IdaraId, usersId, HostName, SearchID_, UserID_, distributorID_, RoleID_, Idara_,Dept_,Section_,Divison_ };

            //var spParameters = new object?[] { "Permission", IdaraID, userID, HostName, SearchID_, UserID_, distributorID_, RoleID_, Idara_, Dept_, Section_, Divison_ };

            DataSet ds;


            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();


            ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

            DataTable? permissionTable = (ds?.Tables?.Count ?? 0) > 0 ? ds.Tables[0] : null;

            //DataTable? rawDt1 = (ds?.Tables?.Count ?? 0) > 1 ? ds.Tables[1] : null;
            //if (rawDt1 != null)
            //{
            //    if (!string.IsNullOrWhiteSpace(Q1))
            //    {
            //        // Escape single quotes for DataView filter
            //        var escaped = Q1.Replace("'", "''");

            //        // Exact match (use LIKE '%value%' for contains)
            //        var view = new DataView(rawDt1)
            //        {
            //            RowFilter = $"userID = '{escaped}'"
            //            // RowFilter = $"buildingTypeName_A LIKE '%{escaped}%'" // contains alternative
            //        };
            //        dt1 = view.ToTable();
            //    }
            //    else
            //    {
            //        dt1 = rawDt1.Clone();
            //    }
            //}
            //else
            //{
            //    dt1 = null;
            //}

            dt1 = (ds?.Tables?.Count ?? 0) > 1 ? ds.Tables[1] : null;
            dt2 = (ds?.Tables?.Count ?? 0) > 2 ? ds.Tables[2] : null;
            dt3 = (ds?.Tables?.Count ?? 0) > 3 ? ds.Tables[3] : null;
            dt4 = (ds?.Tables?.Count ?? 0) > 4 ? ds.Tables[4] : null;
            dt5 = (ds?.Tables?.Count ?? 0) > 5 ? ds.Tables[5] : null;
            dt6 = (ds?.Tables?.Count ?? 0) > 6 ? ds.Tables[6] : null;
            dt7 = (ds?.Tables?.Count ?? 0) > 7 ? ds.Tables[7] : null;
            dt8 = (ds?.Tables?.Count ?? 0) > 8 ? ds.Tables[8] : null;
            dt9 = (ds?.Tables?.Count ?? 0) > 9 ? ds.Tables[9] : null;

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            string rowIdField = "";
            bool canInsert = false;
            bool canInsertFullAccess = false;
            bool canUpdate = false;
            bool canDelete = false;


            List<OptionItem> permissionsOptions = new();
            List<OptionItem> distributorOptions = new();
            List<OptionItem> UsersOptions = new();
            List<OptionItem> idarasOptions = new();
            List<OptionItem> DeptOptions = new();
            List<OptionItem> secOptions = new();
            List<OptionItem> divOptions = new();
            List<OptionItem> RoleOptions = new();
            List<OptionItem> distributorToGivepermissionOptions = new();


            FormConfig form = new();

            try
            {

                // ---------------------- DDLValues ----------------------
                JsonResult? result;
                string json;
                // ---------------------- permissin Type ----------------------

                List<OptionItem> permissinTypeOptions = new()
                {

                    new OptionItem { Value = "1", Text = "مستخدم" },
                    new OptionItem { Value = "2", Text = "موزع" },
                    new OptionItem { Value = "3", Text = "دور" },
                    new OptionItem { Value = "4", Text = "ادارة" },
                    new OptionItem { Value = "5", Text = "قسم" },

                };

                // ---------------------- Users ----------------------
                result = await _CrudController.GetDDLValues(
                    "FullName", "userID_", "2", nameof(Permission), usersId, IdaraId, HostName
                ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);

                UsersOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                // ---------------------- Distributors ----------------------
                result = await _CrudController.GetDDLValues(
                    "distributorName_A", "distributorID", "3", nameof(Permission), usersId, IdaraId, HostName, null, null
                ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);

                distributorOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                // ---------------------- permissions ----------------------
                result = await _CrudController.GetDDLValues(
                    "permissionTypeName_A", "distributorPermissionTypeID", "4", nameof(Permission), usersId, IdaraId, HostName, null, null
                ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);

                permissionsOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                // ---------------------- idara ----------------------
                result = await _CrudController.GetDDLValues(
                    "idaraLongName_A", "idaraID", "5", nameof(Permission), usersId, IdaraId, HostName, "idaraID", IdaraId
                ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);

                idarasOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                // ---------------------- Depts ----------------------
                result = await _CrudController.GetDDLValues(
                    "deptName_A", "deptID", "6", nameof(Permission), usersId, IdaraId, HostName, "idaraID", IdaraId
                ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);

                DeptOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                // ---------------------- Sections ----------------------
                result = await _CrudController.GetDDLValues(
                    "secName_A", "secID", "7", nameof(Permission), usersId, IdaraId, HostName, "deptID", Dept_
                ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);

                secOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                // ---------------------- Divisons ----------------------
                result = await _CrudController.GetDDLValues(
                    "divName_A", "divID", "8", nameof(Permission), usersId, IdaraId, HostName, "secID", Section_
                ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);

                divOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                // ---------------------- Role ----------------------
                result = await _CrudController.GetDDLValues(
                    "roleName_A", "roleID", "9", nameof(Permission), usersId, IdaraId, HostName
                ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);

                RoleOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                // ---------------------- distributorToGivepermission ----------------------
                result = await _CrudController.GetDDLValues(
                    "distributorName_A", "distributorID", "10", nameof(Permission), usersId, IdaraId, HostName, null, null
                ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);

                distributorToGivepermissionOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                // ----------------------END DDLValues ----------------------

                // Determine which fields should be visible based on SearchID_
                bool showUsers = SearchID_ == "1";
                bool showDistributors = SearchID_ == "2";
                bool showRoles = SearchID_ == "3";
                bool showIdara = SearchID_ == "4";
                bool showDeptFields = SearchID_ == "5";

                form = new FormConfig
                {
                    Fields = new List<FieldConfig>
                {
                    // ========= البيانات الشخصية =========

                        //غيرنا الطريقة خلينا التنفيذ داخل دوال موجودة في ملف sf-form.js   sfToggle(this) sfNav(this)  اسم الدوال
                        // الهدف تسهيل + نختصر الكنترولات

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
                                ToggleGroup = "permSearch", // اسم مجموعة التبديل: أي حقل يحمل نفس القيمة سيتم إخفاؤه/إظهاره 
                                ToggleMap   = "1:Users|2:Distributors|3:Roles|4:Idara|5:Dept,Section,Divison", // خريطة الإظهار حسب قيمة الاختيار: 1=Users | 2=Distributors | 3=Roles | 4=Idara | 5=Dept,Section,Divison
                                NavUrl = "/ControlPanel/Permission",
                                NavKey = "S",
                                OnChangeJs = "sfToggle(this); sfNav(this);"  //الدوال اللي تنفذ
                            },

                          new FieldConfig
                            {
                                Name = "Users",
                                Type = "select",
                                Options = UsersOptions,
                                ColCss = "3",
                                Placeholder = "اختر المستخدم",
                                Icon = "fa fa-user",
                                Value = UserID_,
                                IsHidden = !showUsers,
                                Select2 = true,
                                // ===== بيانات التنقّل (sfNav) =====
                                NavUrl  = "/ControlPanel/Permission",
                                NavKey  = "U",// قيمة الحقل بتروح هنا: U=UserID
                                NavKey2 = "S",
                                NavVal2 = "1",
                                OnChangeJs = "sfNav(this)"
                            },

                          new FieldConfig
                                {
                                    Name = "Distributors",
                                    Type = "select",
                                    Options = distributorToGivepermissionOptions,
                                    ColCss = "3",
                                    Placeholder = "اختر الموزع",
                                    Select2 = true,
                                    Icon = "fa fa-user",
                                    Value = distributorID_,
                                    IsHidden = !showDistributors,
                                    // ===== بيانات التنقّل (sfNav) =====
                                    NavUrl  = "/ControlPanel/Permission",
                                    NavKey  = "di",        
                                    NavKey2 = "S",        
                                    NavVal2 = "2",
                                    OnChangeJs = "sfNav(this)"
                                },

                         new FieldConfig
                                {
                                    Name = "Roles",
                                    Type = "select",
                                    Options = RoleOptions,
                                    ColCss = "3",
                                    Placeholder = "اختر الدور",
                                    Select2 = true,
                                    Icon = "fa fa-user",
                                    Value = RoleID_,
                                    IsHidden = !showRoles,
                                    // ===== بيانات التنقّل (sfNav) =====
                                    NavUrl  = "/ControlPanel/Permission",
                                    NavKey  = "Ro",        // قيمة الحقل
                                    NavKey2 = "S",         
                                    NavVal2 = "3",
                                    OnChangeJs = "sfNav(this)"
                                },

                         new FieldConfig
                                    {
                                        Name = "Idara",
                                        Type = "select",
                                        Options = idarasOptions,
                                        ColCss = "3",
                                        Placeholder = "اختر الادارة",
                                        Select2 = true,
                                        Icon = "fa fa-user",
                                        Value = Idara_,
                                        IsHidden = !showIdara,
                                        // ===== بيانات التنقّل (sfNav) =====
                                        NavUrl  = "/ControlPanel/Permission",
                                        NavKey  = "Ida",      // قيمة الحقل (Idara)
                                        NavKey2 = "S",        // ثابت
                                        NavVal2 = "4",
                                        OnChangeJs = "sfNav(this)"
                                    },

                          new FieldConfig
                                    {
                                        Name = "Dept",
                                        Type = "select",
                                        Options = DeptOptions,
                                        ColCss = "3",
                                        Select2 = true,
                                        Placeholder = "اختر القسم",
                                        Icon = "fa fa-user",
                                        Value = Dept_,
                                        IsHidden = !showDeptFields,
                                        // ===== بيانات التنقّل (sfNav) =====
                                        NavUrl  = "/ControlPanel/Permission",
                                        NavKey  = "Dep",     // قيمة الحقل
                                        NavKey2 = "S",       // ثابت
                                        NavVal2 = "5",
                                        OnChangeJs = "sfNav(this)"
                                    },

                          new FieldConfig
                                    {
                                        Name = "Section",
                                        Type = "select",
                                        Options = secOptions,
                                        ColCss = "3",
                                        Placeholder = "اختر الفرع",
                                        Select2 = true,
                                        Icon = "fa fa-user",
                                        Value = Section_,
                                        IsHidden = !showDeptFields,
                                        DependsOn = "Dept",
                                        DependsUrl = "/crud/DDLFiltered?FK=deptID_FK&textcol=secName_A&ValueCol=secID&PageName=Permission&TableIndex=7",
                                        // ===== بيانات التنقّل (sfNav) =====
                                        NavUrl  = "/ControlPanel/Permission",
                                        NavKey  = "Sec",     // قيمة الفرع من هذا الحقل
                                        NavKey2 = "S",
                                        NavVal2 = "5",       // ثابت
                                        NavKey3   = "Dep",   // باراميتر القسم
                                        NavField3 = "Dept",  // يجيب قيمته من حقل Dept تلقائياً
                                        OnChangeJs = "sfNav(this)"
                                    },

                          new FieldConfig
                                    {
                                        Name = "Divison",
                                        Type = "select",
                                        Options = divOptions,
                                        ColCss = "3",
                                        Placeholder = "اختر الشعبة",
                                        Select2 = true,
                                        Icon = "fa fa-user",
                                        Value = Divison_,
                                        IsHidden = !showDeptFields,
                                        DependsOn = "Section",
                                        DependsUrl = "/crud/DDLFiltered?FK=secID_FK&textcol=divName_A&ValueCol=divID&PageName=Permission&TableIndex=8",
                                        // ===== بيانات التنقّل (sfNav) =====
                                        NavUrl  = "/ControlPanel/Permission",
                                        NavKey  = "Div",      // قيمة الشعبة من هذا الحقل
                                        NavKey2 = "S",
                                        NavVal2 = "5",        // ثابت
                                        NavKey3   = "Dep",    // باراميتر القسم
                                        NavField3 = "Dept",   //  يجيب قيمته من حقل Dept
                                        NavKey4   = "Sec",    // باراميتر الفرع
                                        NavField4 = "Section",// يجيب قيمته من حقل Section
                                        OnChangeJs = "sfNav(this)"
                                    },
                                },
                           };

                if (ds != null && ds.Tables.Count > 0 && ds.Tables[0].Rows.Count > 0)
                {
                    // اقرأ الجدول الأول


                    // نبحث عن صلاحيات محددة داخل الجدول
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "INSERT")
                            canInsert = true;

                        if (permissionName == "INSERTFULLACCESS")
                            canInsertFullAccess = true;

                        if (permissionName == "UPDATE")
                            canUpdate = true;


                        if (permissionName == "DELETE")
                            canDelete = true;
                    }


                    if (ds != null && ds.Tables.Count > 0)
                    {

                        // Resolve a correct row id field (case sensitive match to actual DataTable column)
                        rowIdField = "permissionID";
                        var possibleIdNames = new[] { "permissionID", "PermissionID", "Id", "ID" };

                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        //For change table name to arabic 
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["permissionID"] = "المعرف",
                            ["menuName_A"] = "اسم الصفحة",
                            ["permissionTypeName_A"] = "الصلاحية",
                            ["permissionStartDate"] = "تاريخ بداية الصلاحية",
                            ["permissionEndDate"] = "تاريخ نهاية الصلاحية",
                            ["permissionNote"] = "ملاحظات"
                        };


                        // build columns from DataTable schema
                        foreach (DataColumn c in dt1.Columns)
                        {
                            string colType = "text";
                            var t = c.DataType;
                            if (t == typeof(bool)) colType = "bool";
                            else if (t == typeof(DateTime)) colType = "date";
                            else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                                     || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                                colType = "number";

                            bool isuserID = c.ColumnName.Equals("userID", StringComparison.OrdinalIgnoreCase);
                            bool isPermissionID = c.ColumnName.Equals("PermissionID", StringComparison.OrdinalIgnoreCase);
                            bool isdistributorID_FK = c.ColumnName.Equals("distributorID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isRoleID_FK = c.ColumnName.Equals("RoleID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraID_FK = c.ColumnName.Equals("IdaraID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isDSDID_FK = c.ColumnName.Equals("DSDID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isdeptID = c.ColumnName.Equals("deptID", StringComparison.OrdinalIgnoreCase);
                            bool issecID = c.ColumnName.Equals("secID", StringComparison.OrdinalIgnoreCase);
                            bool isdivID = c.ColumnName.Equals("divID", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                //if u want to hide any column 
                                ,
                                Visible = !(isuserID  || isdistributorID_FK || isRoleID_FK || isIdaraID_FK || isDSDID_FK || isdeptID || issecID || isdivID) 
                            });
                        }



                        // build rows (plain dictionaries) so JSON serialization is clean
                        foreach (DataRow r in dt1.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt1.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            // Ensure the row id key actually exists with correct casing
                            if (!dict.ContainsKey(rowIdField))
                            {
                                // Try to copy from a differently cased variant
                                if (rowIdField.Equals("permissionID", StringComparison.OrdinalIgnoreCase) &&
                                    dict.TryGetValue("permissionID", out var alt))
                                    dict["permissionID"] = alt;
                                else if (rowIdField.Equals("permissionID", StringComparison.OrdinalIgnoreCase) &&
                                         dict.TryGetValue("permissionID", out var alt2))
                                    dict["permissionID"] = alt2;
                            }

                            // Prefill pXX fields on the row so Edit form (which uses pXX names) loads the selected row values
                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("permissionID") ?? Get("permissionID") ?? Get("Id") ?? Get("ID");
                            dict["p02"] = Get("menuName_A");
                            dict["p03"] = Get("permissionTypeName_A");
                            dict["p04"] = Get("permissionStartDate");
                            dict["p05"] = Get("permissionEndDate");
                            dict["p06"] = Get("permissionNote");

                            rowsList.Add(dict);
                        }
                    }


                }
            }
            catch (Exception ex)
            {
                ViewBag.DataSetError = ex.Message;
                //TempData["info"] = ex.Message;
            }


            // Local helper: map TableColumn -> FieldConfig


            // Local helper: build Edit1 fields (prefer dataset column for general number or fallback)

            // build dynamic field lists
            // REPLACE Add form fields: hide dataset textboxes and use your own custom inputs

            //ADD
            object? p08Value = Idara_;
            if (SearchID_ == "5")
            {
                p08Value = IdaraId;
            }


            var currentUrl = Request.Path + Request.QueryString;

            var addFields = new List<FieldConfig>
            {

                // keep id hidden first so row id can flow when needed
                new FieldConfig { Name = rowIdField, Type = "hidden" },

                // your custom textboxes
                new FieldConfig
                {
                    Name = "p01",
                    Label = "الموزع",
                    Type = "select",
                    //Select2=true,
                    Options = distributorOptions,
                    ColCss = "3",
                    Required = true
                },

                new FieldConfig
                {
                    Name = "p02",
                    Label = "الصلاحية",
                    Type = "select",
                    //Select2=true,
                    Options = new List<OptionItem> { new OptionItem { Value = "-1", Text = "اختر الموزع أولاً"     } }, //       Initial empty state
                    ColCss = "3",

                    Required = true,
                    DependsOn = "p01",
                    DependsUrl = "/crud/DDLFiltered?FK=distributorID_FK&textcol=permissionTypeName_A&ValueCol=distributorPermissionTypeID&PageName=Permission&TableIndex=4"
                },
                new FieldConfig { Name = "p03", Label = "تاريخ بداية الصلاحية", Type = "date", ColCss = "3", Required = false, Icon = "fa-solid fa-calendar-days" },
                new FieldConfig { Name = "p04", Label = "تاريخ نهاية الصلاحية", Type = "date", ColCss = "3", Required = false,Icon = "fa-solid fa-calendar-days" },
                new FieldConfig { Name = "p05", Label = "ملاحظات", Type = "textarea", ColCss = "6", Required = false },

                  new FieldConfig { Name = "p06",Value=UserID_, Type = "hidden" },
                  new FieldConfig { Name = "p07",Value=RoleID_, Type = "hidden" },
                  
                  new FieldConfig { Name = "p08", Value = p08Value as string, Type = "hidden" },
                  new FieldConfig { Name = "p09",Value=Dept_, Type = "hidden" },
                  new FieldConfig { Name = "p10",Value=Section_, Type = "hidden" },
                  new FieldConfig { Name = "p11",Value=Divison_, Type = "hidden" },
                  new FieldConfig { Name = "p12",Value=distributorID_, Type = "hidden" },
                  new FieldConfig { Name = "p13",Value=SearchID_, Type = "hidden" },
            };



            // Inject required hidden headers for the add (insert) form BEFORE building dsModel:
            addFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName });
            addFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId });
            addFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId });
            addFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT" }); // upper-case
            addFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });



            // Optional: help the generic endpoint know where to go back
            
            addFields.Insert(0, new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl });
            addFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });
            addFields.Insert(0, new FieldConfig { Name = "UserID_", Type = "hidden", Value = UserID_ });




            var addFields1 = new List<FieldConfig>
            {
                // keep id hidden first so row id can flow when needed
                new FieldConfig { Name = rowIdField, Type = "hidden" },

                // your custom textboxes
                new FieldConfig
                {
                    Name = "p01",
                    Label = "الموزع",
                    Type = "select",
                    Options = distributorOptions,
                    ColCss = "3",
                    Required = true
                },

                new FieldConfig { Name = "p02", Label = "تاريخ بداية الصلاحية", Type = "date", ColCss = "3", Required = false,Icon = "fa-solid fa-calendar-days" },
                new FieldConfig { Name = "p03", Label = "تاريخ نهاية الصلاحية", Type = "date", ColCss = "3", Required = false,Icon = "fa-solid fa-calendar-days" },
                new FieldConfig { Name = "p04", Label = "ملاحظات", Type = "textarea", ColCss = "6", Required = false },

                  new FieldConfig { Name = "p05",Value=UserID_, Type = "hidden" },
                  new FieldConfig { Name = "p06",Value=RoleID_, Type = "hidden" },

                  new FieldConfig { Name = "p07", Value = p08Value as string, Type = "hidden" },
                  new FieldConfig { Name = "p08",Value=Dept_, Type = "hidden" },
                  new FieldConfig { Name = "p09",Value=Section_, Type = "hidden" },
                  new FieldConfig { Name = "p10",Value=Divison_, Type = "hidden" },
                  new FieldConfig { Name = "p11",Value=distributorID_, Type = "hidden" },
                  new FieldConfig { Name = "p12",Value=SearchID_, Type = "hidden" },
            };



            // Inject required hidden headers for the add (insert) form BEFORE building dsModel:
            addFields1.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addFields1.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName });
            addFields1.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId });
            addFields1.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId });
            addFields1.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERTFULLACCESS" }); // upper-case
            addFields1.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });


           
            // Optional: help the generic endpoint know where to go back
            addFields1.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addFields1.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });
            addFields1.Insert(0, new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl });
            addFields1.Insert(0, new FieldConfig { Name = "UserID_", Type = "hidden", Value = UserID_ });



            

            var updateFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "redirectAction",      Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController",  Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "redirectUrl",  Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "pageName_",           Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",          Type = "hidden", Value = "UPDATE" },
                new FieldConfig { Name = "idaraID",             Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata",           Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname",            Type = "hidden", Value = HostName},
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField,            Type = "hidden" },

                new FieldConfig { Name = "p01", Label = "المعرف",             Type = "hidden", Readonly = true, ColCss = "3" },
                new FieldConfig { Name = "p02", Label = "اسم الصفحة",         Type = "hidden", Required = true,  ColCss = "3" },
                new FieldConfig { Name = "p03", Label = "الصلاحية", Type = "hidden",   ColCss = "3", TextMode = "arabic" },
                // new FieldConfig
                //{
                //    Name = "p02",
                //    Label = "الموزع",
                //    Type = "select",
                //    Options = distributorOptions,
                //    ColCss = "3",
                //    Required = true,
                //},

                //new FieldConfig
                //{
                //    Name = "p03",
                //    Label = "الصلاحية",
                //    Type = "select",
                //    Options = new List<OptionItem> { new OptionItem { Value = "-1", Text = "اختر الموزع أولاً"     } }, //       Initial empty state
                //    ColCss = "3",
                //    Required = true,
                //    DependsOn = "p02",
                //    DependsUrl = "/crud/DDLFiltered?FK=distributorID_FK&textcol=permissionTypeName_A&ValueCol=distributorPermissionTypeID&PageName=Permission&TableIndex=4"
                //},
                new FieldConfig { Name = "p04", Label = "تاريخ بداية الصلاحية", Type = "date", Required = false, ColCss = "3",Icon = "fa-solid fa-calendar-days"},
                 new FieldConfig { Name = "p05", Label = "تاريخ نهاية الصلاحية", Type = "date", Required = false, ColCss = "3",Icon = "fa-solid fa-calendar-days" },
                new FieldConfig { Name = "p06", Label = "ملاحظات",            Type = "textarea",   ColCss = "6" }
            };


            // Delete fields: show confirmation as a label (not textbox) and show ID as label while still posting p01
            var deleteFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETE" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = HostName },

                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "UserID_", Type = "hidden", Value = UserID_ },


                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },

                // hidden p01 actually posted to SP
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "permissionID" }
            };


            //bool hasRows = dt1 is not null && dt1.Rows.Count > 0 && rowsList.Count > 0;

            ViewBag.HideTable = false;
            //string.IsNullOrWhiteSpace(UserID_);

            // then create dsModel (snippet shows toolbar parts that use the dynamic lists)
            var dsModel = new SmartTableDsModel
            {
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PageTitle = "إدارة الصلاحيات",
                PanelTitle = "إدارة الصلاحيات ",
                
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
                            Fields = addFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" /*Icon = "fa fa-save"*/ },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", /*Icon = "fa fa-times",*/ OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" },

                            }
                        }
                    },

                    Add1 = new TableAction
                    {
                        Label = "إضافة وصول كامل",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة وصول كامل",
                        OpenForm = new FormConfig
                        {
                            FormId = "InsertBackageForm",
                            Title = "إضافة وصول كامل",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addFields1,
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
                            Fields = updateFields
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
                            Fields = deleteFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                }
            };

            var vm = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-user-shield",
                Form = form,
                //TableDS = dsModel
                TableDS = ready ? dsModel : null

            };

            return View("Permission/Permission", vm);
        }
    }
}