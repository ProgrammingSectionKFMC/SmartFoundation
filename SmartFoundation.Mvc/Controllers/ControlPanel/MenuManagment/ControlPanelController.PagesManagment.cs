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

            var rowsListSubPrograms = new List<Dictionary<string, object?>>();
            var dynamicColumnsSubPrograms = new List<TableColumn>();

            var rowsListMenu = new List<Dictionary<string, object?>>();
            var dynamicColumnsMenu = new List<TableColumn>();

            var rowsListPermissions = new List<Dictionary<string, object?>>();
            var dynamicColumnsPermissions = new List<TableColumn>();

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            SplitDataSet(ds);


            //if (permissionTable is null || permissionTable.Rows.Count == 0)
            //{
            //    TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
            //    return RedirectToAction("Index", "Home");
            //}

            string? rowProgramsIdField = "";
            string? rowSubProgramsIDField = "";
            string? rowmenuDistributorIDField = "";
            string? rowdistributorPermissionTypeIDField = "";


            bool canADDPROGRAM = false;
            bool canADDMENU = false;
            bool canADDPERMISSION = false;

            bool canEDITMENU = false;
            bool canEDITPERMISSION = false;
            bool canEDITPPROGRAM = false;

            bool canDELETEPROGRAM = false;
            bool canDELETEMENU = false;
            bool canDELETEPERMISSION = false;

            bool showPrograms = SearchID_ == "1";
            bool showSubPrograms = SearchID_ == "2";
            bool showMenu = SearchID_ == "3";
            bool showPermissions = SearchID_ == "4";


            List<OptionItem> ActiveOptions = new()
                    {
                        new OptionItem { Value = "1", Text = "نشط" },
                        new OptionItem { Value = "0", Text = "غير نشط" }
                    };


            // ---------------------- DDLValues ----------------------

            JsonResult? result;
            string json;


            List<OptionItem> programOptions = new();
            List<OptionItem> UsersAuthOptions = new();
            List<OptionItem> sideMenuOptions = new();
            List<OptionItem> pageOptions = new();
            List<OptionItem> pagePermissionTypeOptions = new();
            List<OptionItem> permissionAuthLevelOptions = new();

            //// ---------------------- programOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "programName_A", "programID", "5", nameof(PagesManagment), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            programOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            //// ---------------------- UsersAuthOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "UsersAuthTypeName_A", "UsersAuthTypeID", "6", nameof(PagesManagment), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            UsersAuthOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            //// ---------------------- sideMenuOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "menuName_A", "menuID", "7", nameof(PagesManagment), usersId, IdaraId, HostName
           ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            sideMenuOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            //// ---------------------- pageOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "menuName_A", "menuID", "8", nameof(PagesManagment), usersId, IdaraId, HostName
           ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            pageOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            //// ---------------------- pagePermissionTypeOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "permissionTypeName_A", "permissionTypeID", "9", nameof(PagesManagment), usersId, IdaraId, HostName
           ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            pagePermissionTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            //// ---------------------- permissionAuthLevelOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "permissionAuthLvlName_A", "permissionAuthLvlID", "10", nameof(PagesManagment), usersId, IdaraId, HostName
           ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            permissionAuthLevelOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


            //// ---------------------- END ----------------------



            FormConfig form = new();



            try
            {
                List<OptionItem> permissinTypeOptions = new()
                {
                    new OptionItem { Value = "1", Text = "برنامج" },
                    new OptionItem { Value = "2", Text = "قائمة جانبية" },
                    new OptionItem { Value = "3", Text = "صفحة" },
                    new OptionItem { Value = "4", Text = "صلاحية" },
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
                        if (permissionName == "ADDPROGRAM") canADDPROGRAM = true;
                        if (permissionName == "ADDMENU") canADDMENU = true;
                        if (permissionName == "ADDPERMISSION") canADDPERMISSION = true;

                        if (permissionName == "EDITMENU") canEDITMENU = true;
                        if (permissionName == "EDITPERMISSION") canEDITPERMISSION = true;
                        if (permissionName == "EDITPROGRAM") canEDITPPROGRAM = true;

                        if (permissionName == "DELETEPROGRAM") canDELETEPROGRAM = true;
                        if (permissionName == "DELETEMENU") canDELETEMENU = true;
                        if (permissionName == "DELETEPERMISSION") canDELETEPERMISSION = true;
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


                            bool isprogramActiveBit = c.ColumnName.Equals("programActiveBit", StringComparison.OrdinalIgnoreCase);



                            dynamicColumnsPrograms.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,
                                Visible = !(isprogramActiveBit)
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
                            dict["p08"] = Get("programSerial");
                            dict["p09"] = Get("programActiveBit");

                            rowsListPrograms.Add(dict);
                        }
                    }

                    // ========== dt2: SubPrograms ==========
                    if (dt2 != null && dt2.Columns.Count > 0)
                    {
                        rowSubProgramsIDField = "menuID";
                        var possibleIdNames = new[] { "menuID", "MenuID", "Id", "ID" };
                        rowSubProgramsIDField = possibleIdNames.FirstOrDefault(n => dt2.Columns.Contains(n))
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
                            ["menuActive"] = "الحالة",
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
                                            c.ColumnName.Equals("parentMenuID_FK", StringComparison.OrdinalIgnoreCase) ||
                                            c.ColumnName.Equals("isDashboard", StringComparison.OrdinalIgnoreCase);

                            dynamicColumnsSubPrograms.Add(new TableColumn
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
                            dict["p07"] = Get("menuDescription");
                            dict["p08"] = Get("parentMenuID_FK");
                            dict["p09"] = Get("programID_FK");
                            dict["p10"] = Get("menuSerial");
                            dict["p11"] = Get("menuActive");
                            dict["p12"] = Get("isDashboard");
                            dict["p13"] = Get("PageLvl");

                            rowsListSubPrograms.Add(dict);
                        }
                    }
                    // ========== dt3: Menu ==========
                    if (dt3 != null && dt3.Columns.Count > 0)
                    {
                        rowmenuDistributorIDField = "menuDistributorID";
                        var possibleIdNames = new[] { "menuDistributorID", "menuDistributorID", "Id", "ID" };
                        rowmenuDistributorIDField = possibleIdNames.FirstOrDefault(n => dt3.Columns.Contains(n))
                                     ?? dt3.Columns[0].ColumnName;

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
                            ["menuActive"] = "الحالة",
                            ["isDashboard"] = "لوحة تحكم",
                            ["PageLvl"] = "المستوى"
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

                            bool isHidden = c.ColumnName.Equals("programID_FK", StringComparison.OrdinalIgnoreCase) ||
                                            c.ColumnName.Equals("parentMenuID_FK", StringComparison.OrdinalIgnoreCase) ||
                                            c.ColumnName.Equals("isDashboard", StringComparison.OrdinalIgnoreCase);

                            dynamicColumnsMenu.Add(new TableColumn
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
                            dict["p01"] = Get("menuDistributorID");
                            dict["p02"] = Get("menuID");
                            dict["p03"] = Get("menuName_A");
                            dict["p04"] = Get("menuName_E");
                            dict["p05"] = Get("distributorID");
                            dict["p06"] = Get("menuLink");
                            dict["p07"] = Get("menuDescription");
                            dict["p08"] = Get("parentMenuID_FK");
                            dict["p09"] = Get("programID_FK");
                            dict["p10"] = Get("menuSerial");
                            dict["p11"] = Get("menuActive");
                            dict["p12"] = Get("isDashboard");
                            dict["p13"] = Get("PageLvl");

                            rowsListMenu.Add(dict);
                        }
                    }

                    // ========== dt4: Permissions ==========
                    if (dt4 != null && dt4.Columns.Count > 0)
                    {

                        rowdistributorPermissionTypeIDField = "distributorPermissionTypeID";
                        var possibleIdNames = new[] { "distributorPermissionTypeID", "distributorPermissionTypeID", "Id", "ID" };
                        rowdistributorPermissionTypeIDField = possibleIdNames.FirstOrDefault(n => dt4.Columns.Contains(n))
                                     ?? dt4.Columns[0].ColumnName;

                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["distributorPermissionTypeID"] = "المعرف",
                            ["permissionTypeID_FK"] = "نوع الصلاحية",
                            ["DistributorID_FK"] = "رقم الموزع",
                            ["distributorName_A"] = "اسم الموزع",
                            ["distributorType_FK"] = "نوع الموزع",
                            ["permissionTypeName_A"] = "اسم الصلاحية",
                            ["permissionTypeName_E"] = "اسم الصلاحية بالانجليزي",
                            ["permissionAuthLvlName_A"] = "من يمكنه اعطاء الصلاحية ؟",
                            ["distributorPermissionTypeStartDate"] = "تاريخ البداية",
                            ["distributorPermissionTypeEndDate"] = "تاريخ النهاية",
                            ["distributorPermissionTypeActive"] = "الحالة"
                        };

                        foreach (DataColumn c in dt4.Columns)
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

                        foreach (DataRow r in dt4.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt4.Columns)
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
                            dict["p06"] = Get("distributorPermissionTypeActive");
                            dict["p07"] = Get("permissionAuthLvl");
                            dict["p08"] = Get("permissionTypeName_A");
                            dict["p09"] = Get("permissionTypeName_E");

                            rowsListPermissions.Add(dict);
                        }
                    }
                }
            }
            catch (Exception)
            {
                ViewBag.DataSetError = "حدث خطأ أثناء تحميل البيانات. يرجى المحاولة مرة أخرى.";
            }

            var currentUrl = Request.Path + Request.QueryString;



            




             var AddProgramFieldFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "AddProgram" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },


                new FieldConfig { Name = rowProgramsIdField, Type = "hidden" },


                new FieldConfig { Name = "p01", Label = "programID", Type = "hidden", ColCss = "3", Readonly = false },
                new FieldConfig { Name = "p02", Label = "اسم البرنامج (عربي)", Type = "text", TextMode = "arabic", ColCss = "3", Readonly = false ,Required = true },
                new FieldConfig { Name = "p03", Label = "اسم البرنامج (إنجليزي)", Type = "text", TextMode="english", ColCss = "3", Readonly = false ,Required = true },
                new FieldConfig { Name = "p04", Label = "الوصف", Type = "text", ColCss = "3", Readonly = false ,Required = true },
                new FieldConfig { Name = "p05", Label = "programActive", Type = "hidden", ColCss = "3", Readonly = false ,Required = true },
                new FieldConfig { Name = "p06", Label = "الرابط", Type = "text", ColCss = "3", Readonly = false ,Required = true },
                new FieldConfig { Name = "p07", Label = "الأيقونة", Type = "text", TextMode="english", ColCss = "3", Readonly = false ,Required = true },
                new FieldConfig { Name = "p08", Label = "الترتيب", Type = "hidden", ColCss = "3", Readonly = false  },



            };


            var EditProgramFieldFields = new List<FieldConfig>
            {

                 new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "EditProgram" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },


                new FieldConfig { Name = rowProgramsIdField, Type = "hidden" },


                new FieldConfig { Name = "p01", Label = "programID", Type = "hidden", ColCss = "3", Readonly = false },
                new FieldConfig { Name = "p02", Label = "اسم البرنامج (عربي)", Type = "text", TextMode = "arabic", ColCss = "3", Readonly = false ,Required = true },
                new FieldConfig { Name = "p03", Label = "اسم البرنامج (إنجليزي)", Type = "text", TextMode="english", ColCss = "3", Readonly = false ,Required = true },
                new FieldConfig { Name = "p04", Label = "الوصف", Type = "text", ColCss = "3", Readonly = false ,Required = true },
                new FieldConfig { Name = "p05", Label = "programActive", Type = "hidden", ColCss = "3", Readonly = false ,Required = true },
                new FieldConfig { Name = "p06", Label = "الرابط", Type = "text", ColCss = "3", Readonly = false ,Required = true },
                new FieldConfig { Name = "p07", Label = "الأيقونة", Type = "text", TextMode="english", ColCss = "3", Readonly = false ,Required = true },
                new FieldConfig { Name = "p08", Label = "الترتيب", Type = "text", ColCss = "3", Readonly = false ,Required = true },

            };


            var DeleteProgramFieldFields = new List<FieldConfig>
            {

                  new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DeleteProgram" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },


                new FieldConfig { Name = rowProgramsIdField, Type = "hidden" },


                new FieldConfig { Name = "p01", Label = "programID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p02", Label = "اسم البرنامج (عربي)", Type = "text", TextMode = "arabic", ColCss = "3", Readonly = true ,Required = true },
                new FieldConfig { Name = "p03", Label = "اسم البرنامج (إنجليزي)", Type = "text", TextMode="english", ColCss = "3", Readonly = true ,Required = true },
                new FieldConfig { Name = "p04", Label = "الوصف", Type = "text", ColCss = "3", Readonly = true ,Required = true },
                new FieldConfig { Name = "p05", Label = "programActive", Type = "hidden", ColCss = "3", Readonly = true ,Required = true },
                new FieldConfig { Name = "p06", Label = "الرابط", Type = "text", ColCss = "3", Readonly = true ,Required = true },
                new FieldConfig { Name = "p07", Label = "الأيقونة", Type = "text", TextMode="english", ColCss = "3", Readonly = true ,Required = true },
                new FieldConfig { Name = "p08", Label = "الترتيب", Type = "text", ColCss = "3", Readonly = true ,Required = true },
                new FieldConfig { Name = "p09", Label = "حالة البرنامج", Type = "select", ColCss = "3",Options=ActiveOptions ,Required = true },

            };

            var AddMenuListFieldFields = new List<FieldConfig>
            {
            
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "AddMenuList" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
            
            
                new FieldConfig { Name = rowProgramsIdField, Type = "hidden" },
            
            
                new FieldConfig { Name = "p01", Label = "البرنامج التابع لها القائمة", Type = "select", ColCss = "3",Required = true,Options = programOptions},
                new FieldConfig { Name = "p02", Label = "اسم القائمة (عربي)", Type = "text", TextMode = "arabic", ColCss = "3", Readonly = false ,Required = true },
                new FieldConfig { Name = "p03", Label = "اسم القائمة (إنجليزي)", Type = "text", TextMode="english", ColCss = "3", Readonly = false ,Required = true },
                new FieldConfig { Name = "p04", Label = "الوصف", Type = "text", ColCss = "3", Readonly = false ,Required = true },
                new FieldConfig { Name = "p05", Label = "الترتيب", Type = "number", ColCss = "3", Readonly = false ,Required = true },
            
            
            };

            var EditMenuListFieldFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "EditMenuList" },
                new FieldConfig { Name = "redirectUrl",        Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig { Name = "p02", Label = "رقم القائمة", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "البرنامج التابع لها القائمة", Type = "select", ColCss = "3", Required = true, Options = programOptions },
                new FieldConfig { Name = "p03", Label = "اسم القائمة (عربي)", Type = "text", TextMode = "arabic", ColCss = "3", Required = true },
                new FieldConfig { Name = "p04", Label = "اسم القائمة (إنجليزي)", Type = "text", TextMode = "english", ColCss = "3", Required = true },
                new FieldConfig { Name = "p07", Label = "الوصف", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p10", Label = "الترتيب", Type = "number", ColCss = "3", Required = true },
            };

            var DeleteMenuListFieldFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DeleteMenuList" },
                new FieldConfig { Name = "redirectUrl",        Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig { Name = "p02", Label = "رقم القائمة", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p03", Label = "اسم القائمة (عربي)", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p11", Label = "الحالة", Type = "select", ColCss = "3", Options = ActiveOptions, Required = true },
            };

            var AddPageFieldFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "AddPage" },
                new FieldConfig { Name = "redirectUrl",        Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig { Name = "p01", Label = "البرنامج", Type = "select", Select2 = true, ColCss = "3", Required = true, Options = programOptions },
                new FieldConfig
                {
                    Name = "p02",
                    Label = "القائمة الجانبية",
                    Type = "select",
                    Select2 = true,
                    ColCss = "3",
                    Required = false,
                    Options = new List<OptionItem> { new OptionItem { Value = "-1", Text = "بدون قائمة جانبية" } },
                    DependsOn = "p01",
                    DependsUrl = "/crud/DDLFiltered?FK=programID_FK&textcol=menuName_A&ValueCol=menuID&PageName=PagesManagment&TableIndex=7"
                },
                new FieldConfig { Name = "p03", Label = "اسم الصفحة (عربي)", Type = "text", TextMode = "arabic", ColCss = "3", Required = true },
                new FieldConfig { Name = "p04", Label = "اسم الصفحة (إنجليزي)", Type = "text", TextMode = "english", ColCss = "3", Required = true },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p06", Label = "الرابط", Type = "text", TextMode = "english", ColCss = "3", Required = true },
                new FieldConfig { Name = "p07", Label = "الترتيب", Type = "number", ColCss = "3", Required = true },
                new FieldConfig { Name = "p10", Label = "المستوى", Type = "select", ColCss = "3", Options = UsersAuthOptions, Required = true },
            };

            var EditPageFieldFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "EditPage" },
                new FieldConfig { Name = "redirectUrl",        Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig { Name = "p02", Label = "رقم الصفحة", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "البرنامج", Type = "select", Select2 = true, ColCss = "3", Required = false, Options = programOptions },
                new FieldConfig { Name = "p08", Label = "القائمة الجانبية", Type = "select", Select2 = true, ColCss = "3", Required = false, Options = sideMenuOptions },
                new FieldConfig { Name = "p03", Label = "اسم الصفحة (عربي)", Type = "text", TextMode = "arabic", ColCss = "3", Required = true },
                new FieldConfig { Name = "p04", Label = "اسم الصفحة (إنجليزي)", Type = "text", TextMode = "english", ColCss = "3", Required = true },
                new FieldConfig { Name = "p07", Label = "الوصف", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p06", Label = "الرابط", Type = "text", TextMode = "english", ColCss = "3", Required = true },
                new FieldConfig { Name = "p10", Label = "الترتيب", Type = "number", ColCss = "3", Required = true },
                new FieldConfig { Name = "p13", Label = "المستوى", Type = "select", ColCss = "3", Options = UsersAuthOptions, Required = true },
            };

            var DeletePageFieldFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DeletePage" },
                new FieldConfig { Name = "redirectUrl",        Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig { Name = "p02", Label = "رقم الصفحة", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p03", Label = "اسم الصفحة (عربي)", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p11", Label = "الحالة", Type = "select", ColCss = "3", Options = ActiveOptions, Required = true },
            };

            var AddPagePermissionFieldFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "AddPagePermission" },
                new FieldConfig { Name = "redirectUrl",        Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig { Name = "p01", Label = "البرنامج", Type = "select", Select2 = true, ColCss = "3", Required = true, Options = programOptions },
                new FieldConfig
                {
                    Name = "p02",
                    Label = "الصفحة",
                    Type = "select",
                    Select2 = true,
                    ColCss = "3",
                    Required = true,
                    Options = new List<OptionItem> { new OptionItem { Value = "-1", Text = "اختر البرنامج أولاً" } },
                    DependsOn = "p01",
                    DependsUrl = "/crud/DDLFiltered?FK=programID_FK&textcol=menuName_A&ValueCol=menuID&PageName=PagesManagment&TableIndex=8"
                },
                new FieldConfig { Name = "p03", Label = "اسم الصلاحية (عربي)", Type = "text", TextMode = "arabic", ColCss = "3", Required = true },
                new FieldConfig { Name = "p04", Label = "اسم الصلاحية (إنجليزي)", Type = "text", TextMode = "english", ColCss = "3", Required = true },
                new FieldConfig { Name = "p05", Label = "مستوى الصلاحية", Type = "select", Select2 = true, ColCss = "3", Required = true, Options = permissionAuthLevelOptions },
            };

            var EditPagePermissionFieldFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "EditPagePermission" },
                new FieldConfig { Name = "redirectUrl",        Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig { Name = "p01", Label = "المعرف", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p02", Label = "نوع الصلاحية", Type = "select", Select2 = true, ColCss = "3", Readonly = true, Required = true, Options = pagePermissionTypeOptions },
                new FieldConfig { Name = "p08", Label = "اسم الصلاحية (عربي)", Type = "text", TextMode = "arabic", ColCss = "3", Required = true },
                new FieldConfig { Name = "p09", Label = "اسم الصلاحية (إنجليزي)", Type = "text", TextMode = "english", ColCss = "3", Required = true },
                new FieldConfig { Name = "p07", Label = "مستوى الصلاحية", Type = "select", Select2 = true, ColCss = "3", Required = true, Options = permissionAuthLevelOptions },
            };

            var DeletePagePermissionFieldFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DeletePagePermission" },
                new FieldConfig { Name = "redirectUrl",        Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig { Name = "p01", Label = "المعرف", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p02", Label = "نوع الصلاحية", Type = "select", Select2 = true, ColCss = "3", Readonly = true, Required = true, Options = pagePermissionTypeOptions },
                new FieldConfig { Name = "p08", Label = "اسم الصلاحية (عربي)", Type = "text", TextMode = "arabic", ColCss = "3", Readonly = true, Required = true },
                new FieldConfig { Name = "p09", Label = "اسم الصلاحية (إنجليزي)", Type = "text", TextMode = "english", ColCss = "3", Readonly = true, Required = true },
                new FieldConfig { Name = "p06", Label = "الحالة", Type = "select", ColCss = "3", Options = ActiveOptions, Required = true },
            };




            // ✅ إنشاء الـ Models بالبيانات الصحيحة
            var dsModelPrograms = new SmartTableDsModel
            {
                Columns = dynamicColumnsPrograms,
                Rows = rowsListPrograms,
                RowIdField = "programID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumnsPrograms.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PageTitle = "إدارة البرامج",
                PanelTitle = "إدارة البرامج",
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = canADDPROGRAM,
                    ShowAdd1 = false,
                    ShowEdit = canEDITPPROGRAM,
                    ShowDelete = canDELETEPROGRAM,
                    ShowBulkDelete = false,
                    Add = new TableAction
                    {
                        Label = "إضافة برنامج جديد",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة برنامج جديد",
                        OpenForm = new FormConfig
                        {
                            FormId = "InsertForm",
                            Title = "بيانات برنامج جديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = AddProgramFieldFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" },
                            }
                        }
                    },
                    Edit = new TableAction
                    {
                        Label = "تعديل برنامج",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل برنامج",
                        OpenForm = new FormConfig
                        {
                            FormId = "programEditForm",
                            Title = "تعديل بيانات برنامج",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = EditProgramFieldFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                    Delete = new TableAction
                    {
                        Label = "ايقاف / تنشيط برنامج",
                        Icon = "fa fa-recycle",
                        Color = "warning",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من ايقاف / تنشيط البرنامج؟",
                        OpenForm = new FormConfig
                        {
                            FormId = "programDeleteForm",
                            Title = "تأكيد ايقاف / تنشيط البرنامج",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "تنفيذ", Type = "submit", Color = "danger", Icon = "fa fa-save" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", Icon = "fa fa-times", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = DeleteProgramFieldFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                }
            };

            dsModelPrograms.StyleRules = new List<TableStyleRule>
            {
                new TableStyleRule { Target = "cell", Field = "programActive", Op = "eq", Value = "نشط", Priority = 1, PillEnabled = true, PillField = "programActive", PillTextField = "programActive", PillCssClass = "pill pill-green", PillMode = "replace" },
                new TableStyleRule { Target = "cell", Field = "programActive", Op = "neq", Value = "نشط", Priority = 1, PillEnabled = true, PillField = "programActive", PillTextField = "programActive", PillCssClass = "pill pill-red", PillMode = "replace" },
            };

            var dsModelSubPrograms = new SmartTableDsModel
            {
                Columns = dynamicColumnsSubPrograms,
                Rows = rowsListSubPrograms,
                RowIdField = "menuID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumnsSubPrograms.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PageTitle = "إدارة القوائم الجانبية",
                PanelTitle = "إدارة القوائم الجانبية",
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = canADDPROGRAM,
                    ShowEdit = canEDITPPROGRAM,
                    ShowDelete = canDELETEPROGRAM,
                    ShowBulkDelete = false,
                    Add = new TableAction
                    {
                        Label = "إضافة قائمة جانبية",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة قائمة جانبية",
                        OpenForm = new FormConfig
                        {
                            FormId = "sideMenuInsertForm",
                            Title = "بيانات القائمة الجانبية",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = AddMenuListFieldFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" },
                            }
                        }
                    },
                    Edit = new TableAction
                    {
                        Label = "تعديل قائمة جانبية",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل قائمة جانبية",
                        OpenForm = new FormConfig
                        {
                            FormId = "sideMenuEditForm",
                            Title = "تعديل بيانات القائمة الجانبية",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = EditMenuListFieldFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                    Delete = new TableAction
                    {
                        Label = "ايقاف / تنشيط قائمة جانبية",
                        Icon = "fa fa-recycle",
                        Color = "warning",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من ايقاف / تنشيط القائمة الجانبية؟",
                        OpenForm = new FormConfig
                        {
                            FormId = "sideMenuDeleteForm",
                            Title = "تأكيد ايقاف / تنشيط القائمة الجانبية",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "تنفيذ", Type = "submit", Color = "danger", Icon = "fa fa-save" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", Icon = "fa fa-times", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = DeleteMenuListFieldFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                }
            };

            var dsModelMenu = new SmartTableDsModel
            {
                Columns = dynamicColumnsMenu,
                Rows = rowsListMenu,
                RowIdField = "menuDistributorID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumnsMenu.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PageTitle = "إدارة الصفحات",
                PanelTitle = "إدارة الصفحات",
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = canADDMENU,
                    ShowEdit = canEDITMENU,
                    ShowDelete = canDELETEMENU,
                    ShowBulkDelete = false,
                    Add = new TableAction
                    {
                        Label = "إضافة صفحة",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة صفحة جديدة",
                        OpenForm = new FormConfig
                        {
                            FormId = "pageInsertForm",
                            Title = "بيانات الصفحة",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = AddPageFieldFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" },
                            }
                        }
                    },
                    Edit = new TableAction
                    {
                        Label = "تعديل صفحة",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل صفحة",
                        OpenForm = new FormConfig
                        {
                            FormId = "pageEditForm",
                            Title = "تعديل بيانات الصفحة",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = EditPageFieldFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                    Delete = new TableAction
                    {
                        Label = "ايقاف / تنشيط صفحة",
                        Icon = "fa fa-recycle",
                        Color = "warning",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من ايقاف / تنشيط الصفحة؟",
                        OpenForm = new FormConfig
                        {
                            FormId = "pageDeleteForm",
                            Title = "تأكيد ايقاف / تنشيط الصفحة",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "تنفيذ", Type = "submit", Color = "danger", Icon = "fa fa-save" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", Icon = "fa fa-times", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = DeletePageFieldFields
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
                RowIdField = "distributorPermissionTypeID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumnsPermissions.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PageTitle = "إدارة صلاحيات الصفحات",
                PanelTitle = "إدارة صلاحيات الصفحات",
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = true,
                    ShowColumns = true,
                    ShowAdd = canADDPERMISSION,
                    ShowEdit = canEDITPERMISSION,
                    ShowDelete = canDELETEPERMISSION,
                    Add = new TableAction
                    {
                        Label = "إضافة صلاحية صفحة",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة صلاحية صفحة",
                        OpenForm = new FormConfig
                        {
                            FormId = "pagePermissionInsertForm",
                            Title = "بيانات صلاحية الصفحة",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = AddPagePermissionFieldFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" },
                            }
                        }
                    },
                    Edit = new TableAction
                    {
                        Label = "تعديل صلاحية صفحة",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل صلاحية صفحة",
                        OpenForm = new FormConfig
                        {
                            FormId = "pagePermissionEditForm",
                            Title = "تعديل صلاحية الصفحة",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = EditPagePermissionFieldFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                    Delete = new TableAction
                    {
                        Label = "ايقاف / تنشيط صلاحية صفحة",
                        Icon = "fa fa-recycle",
                        Color = "warning",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من ايقاف / تنشيط صلاحية الصفحة؟",
                        OpenForm = new FormConfig
                        {
                            FormId = "pagePermissionDeleteForm",
                            Title = "تأكيد ايقاف / تنشيط صلاحية الصفحة",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "تنفيذ", Type = "submit", Color = "danger", Icon = "fa fa-save" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", Icon = "fa fa-times", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = DeletePagePermissionFieldFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                }
            };









            var vm = new SmartPageViewModel
            {
                PageTitle = "إدارة الصفحات",
                PanelTitle = "إدارة الصفحات",
                PanelIcon = "fa-user-shield",
                Form = form,
                TableDS = showPrograms ? dsModelPrograms : null,
                TableDS1 = showSubPrograms ? dsModelSubPrograms : null,
                TableDS2 = showMenu ? dsModelMenu : null,
                TableDS3 = showPermissions ? dsModelPermission : null
            };



            return View("MenuManagment/PagesManagment", vm);
        }
    }
}
