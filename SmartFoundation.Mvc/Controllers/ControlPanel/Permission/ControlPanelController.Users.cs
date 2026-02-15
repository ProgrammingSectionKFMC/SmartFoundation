using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Text.Json;
using static System.Collections.Specialized.BitVector32;


namespace SmartFoundation.Mvc.Controllers.ControlPanel
{
    public partial class ControlPanelController : Controller
    {
        public async Task<IActionResult> Users()
        {
            //  تهيئة بيانات الصفحة (السيشن + ControllerName + PageName...)
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = nameof(ControlPanel);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "Users" : PageName;

            var spParameters = new object?[]
            {
             PageName ?? "Users",
             IdaraId,
             usersId,
             HostName
            };
            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

            //  تقسيم الداتا سيت للجدول الأول + جداول أخرى
            SplitDataSet(ds);

            string isAdminValue = "0";
            bool isAdmin = false;  // ✅ Default to false (not admin)

            if (dt10 != null && dt10.Rows.Count > 0)
            {
                DataRow rows = dt10.Rows[0];
                if (dt10.Columns.Contains("isAdmin") && rows["isAdmin"] != DBNull.Value)
                    isAdminValue = rows["isAdmin"].ToString();
            }

            // ✅ Fix: Set isAdmin = true when user IS an admin (values 1 or 2)
            if (isAdminValue == "1")
                isAdmin = true;

            //  التحقق من الصلاحيات
            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            string rowIdField = "";
            bool canInsert = false;
            bool canUpdate = false;
            bool canDelete = false;
            bool canUPDATENATIONALID = false;


            List<OptionItem> IdaraOptions = new();
            List<OptionItem> UsersAuthTypeOptions = new();
            List<OptionItem> userTypeOptions = new();
            List<OptionItem> genderOptions = new();
            List<OptionItem> nationalityOptions = new();
            List<OptionItem> religionOptions = new();
            List<OptionItem> maritalStatusOptions = new();
            List<OptionItem> EducationOptions = new();
            List<OptionItem> DeptOptions = new();

            string MsgUpdateNationalID = "";

            // ---------------------- DDLValues ----------------------
            JsonResult? result;
            string json;


            // ---------------------- IdaraOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "idaraLongName_A", "idaraID", "2", nameof(Users), usersId, IdaraId, HostName
            ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            IdaraOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            // ---------------------- UsersAuthTypeOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "UsersAuthTypeName_A", "UsersAuthTypeID", "3", nameof(Users), usersId, IdaraId, HostName
            ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            UsersAuthTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            // ---------------------- userTypeOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "userTypeName_A", "userTypeID", "4", nameof(Users), usersId, IdaraId, HostName
            ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            userTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            // ---------------------- gender ----------------------
            result = await _CrudController.GetDDLValues(
                "genderName_A", "genderID", "5", nameof(Users), usersId, IdaraId, HostName
            ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            genderOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            // ---------------------- nationalityOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "nationalityName_A", "nationalityID", "6", nameof(Users), usersId, IdaraId, HostName
            ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            nationalityOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            // ---------------------- religionOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "religionName_A", "religionID", "7", nameof(Users), usersId, IdaraId, HostName
            ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            religionOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            // ---------------------- maritalStatusOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "maritalStatusName_A", "maritalStatusID", "8", nameof(Users), usersId, IdaraId, HostName
            ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            maritalStatusOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            // ---------------------- EducationOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "educationName_A", "educationID", "9", nameof(Users), usersId, IdaraId, HostName
            ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            EducationOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


            // ---------------------- EducationOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "distributorName_A", "distributorID", "11", nameof(Users), usersId, IdaraId, HostName
            ) as JsonResult;

            json = JsonSerializer.Serialize(result!.Value);

            DeptOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;






            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // 🔐 قراءة الصلاحيات من الجدول الأول
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "INSERTUSERS") canInsert = true;
                        if (permissionName == "UPDATEUSERS") canUpdate = true;
                        if (permissionName == "DELETEUSERS") canDelete = true;
                        if (permissionName == "UPDATENATIONALID") canUPDATENATIONALID = true;
                    }



                    if (canUPDATENATIONALID == false)
                        MsgUpdateNationalID = "ملاحظة: انت لاتملك صلاحية التعديل على رقم الهوية الوطنية";

                    if (canUPDATENATIONALID == true)
                        MsgUpdateNationalID = "ملاحظة: انت تملك صلاحية التعديل على رقم الهوية الوطنية كن حذرا عند التعديل";



                    if (dt1 != null && dt1.Rows.Count > 0)
                    {
                        // 🔑 تحديد حقل الـ Id
                        rowIdField = "usersID";
                        var possibleIdNames = new[] { "usersID", "UsersID", "Id", "ID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // 🏷️ عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["usersID"] = "المرجع",
                            ["nationalID"] = "رقم الهوية",
                            ["GeneralNo"] = "الرقم العام",
                            ["FullName"] = "الاسم",
                            ["UsersAuthTypeName_A"] = "الصلاحية",
                            ["ActiveStatus"] = "الحالة",
                            ["userTypeName_A"] = "الفئة",
                            ["idaraLongName_A"] = "الادارة",
                            ["EntryFullName"] = "منفذ الاجراء",
                            ["distributorName_A"] = "القسم",
                            ["entryDate"] = "تاريخ التنفيذ"
                        };

                        // 🧱 الأعمدة
                        foreach (DataColumn c in dt1.Columns)
                        {
                            string colType = "text";
                            var t = c.DataType;
                            if (t == typeof(bool)) colType = "bool";
                            else if (t == typeof(DateTime)) colType = "date";
                            else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                                     || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                                colType = "number";


                            // إخفاء بعض الأعمدة
                            bool isUsersAuthTypeID = c.ColumnName.Equals("UsersAuthTypeID", StringComparison.OrdinalIgnoreCase);
                            bool isuserActive = c.ColumnName.Equals("userActive", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraID = c.ColumnName.Equals("IdaraID", StringComparison.OrdinalIgnoreCase);
                            bool isfirstName_A = c.ColumnName.Equals("firstName_A", StringComparison.OrdinalIgnoreCase);
                            bool issecondName_A = c.ColumnName.Equals("secondName_A", StringComparison.OrdinalIgnoreCase);
                            bool isthirdName_A = c.ColumnName.Equals("thirdName_A", StringComparison.OrdinalIgnoreCase);
                            bool islastName_A = c.ColumnName.Equals("lastName_A", StringComparison.OrdinalIgnoreCase);
                            bool isfirstName_E = c.ColumnName.Equals("firstName_E", StringComparison.OrdinalIgnoreCase);
                            bool issecondName_E = c.ColumnName.Equals("secondName_E", StringComparison.OrdinalIgnoreCase);
                            bool isthirdName_E = c.ColumnName.Equals("thirdName_E", StringComparison.OrdinalIgnoreCase);
                            bool islastName_E = c.ColumnName.Equals("lastName_E", StringComparison.OrdinalIgnoreCase);
                            bool isuserTypeID_FK = c.ColumnName.Equals("userTypeID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isnationalIDIssueDate = c.ColumnName.Equals("nationalIDIssueDate", StringComparison.OrdinalIgnoreCase);
                            bool isdateOfBirth = c.ColumnName.Equals("dateOfBirth", StringComparison.OrdinalIgnoreCase);
                            bool isgenderID_FK = c.ColumnName.Equals("genderID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isnationalityID_FK = c.ColumnName.Equals("nationalityID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isreligionID_FK = c.ColumnName.Equals("religionID_FK", StringComparison.OrdinalIgnoreCase);
                            bool ismaritalStatusID_FK = c.ColumnName.Equals("maritalStatusID_FK", StringComparison.OrdinalIgnoreCase);
                            bool iseducationID_FK = c.ColumnName.Equals("educationID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isdistributorID = c.ColumnName.Equals("distributorID", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,
                                Visible = !(isUsersAuthTypeID || isuserActive || isIdaraID|| isfirstName_A || issecondName_A || isthirdName_A || islastName_A || isfirstName_E || issecondName_E || isthirdName_E || islastName_E || isuserTypeID_FK || isnationalIDIssueDate || isdateOfBirth || isgenderID_FK || isnationalityID_FK || isreligionID_FK || ismaritalStatusID_FK || iseducationID_FK || isdistributorID)
                            });
                        }

                        //  الصفوف
                        foreach (DataRow r in dt1.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt1.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            // التأكد من وجود حقل الـ Id
                          
                            


                            // تعبئة p01..p04 لاستخدامها في الفورم
                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("usersID") ?? Get("UsersID");
                            dict["p02"] = Get("nationalID");
                            dict["p03"] = Get("GeneralNo");
                            dict["p04"] = Get("firstName_A");
                            dict["p05"] = Get("secondName_A");
                            dict["p06"] = Get("thirdName_A");
                            dict["p07"] = Get("forthName_A");
                            dict["p08"] = Get("lastName_A");
                            dict["p09"] = Get("firstName_E");
                            dict["p10"] = Get("secondName_E");
                            dict["p11"] = Get("thirdName_E");
                            dict["p12"] = Get("forthName_E");
                            dict["p13"] = Get("lastName_E");
                            dict["p14"] = Get("UsersAuthTypeID");
                            dict["p15"] = Get("ActiveStatus");
                            dict["p16"] = Get("userTypeID_FK");
                            dict["p17"] = Get("IdaraID");
                            dict["p22"] = Get("nationalIDIssueDate");
                            dict["p23"] = Get("dateOfBirth");
                            dict["p24"] = Get("genderID_FK");
                            dict["p25"] = Get("nationalityID_FK");
                            dict["p26"] = Get("religionID_FK");
                            dict["p27"] = Get("maritalStatusID_FK");
                            dict["p28"] = Get("educationID_FK");
                            dict["p36"] = Get("distributorID");

                            rowsList.Add(dict);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.buildingClassDataSetError = ex.Message;
            }



            var currentUrl = Request.Path;

            var InsertUserFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",      Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController",  Type = "hidden", Value = ControllerName},
                new FieldConfig { Name = "pageName_",           Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",          Type = "hidden", Value = "INSERTUSERS" },
                new FieldConfig { Name = "idaraID",             Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",           Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",            Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField,   Type = "hidden" },

                new FieldConfig { Name = "p01", Label = "الرقم المرجعي",Type = "hidden", Readonly = true, ColCss = "3" },
                new FieldConfig { Name = "p02", Label = "رقم الهوية الوطنية",Type = "text",   Required = true,  ColCss = "3", TextMode = "number",MaxLength=10   },
                 new FieldConfig { Name = "p03", Label = "الرقم العام",Type = "text",   Required = true, ColCss = "3", TextMode="number",MaxLength=10 },
                                 new FieldConfig { Name = "p23", Label = "تاريخ الميلاد",Type = "date",   Required = true, ColCss = "3" },
                new FieldConfig { Name = "p22", Label = "تاريخ اصدار الهوية",Type = "date",   Required = true, ColCss = "3" },
               new FieldConfig { Name = "p17", Label = "الادارة",Type = "select",   Required = true, ColCss = "6", Options= IdaraOptions},
                new FieldConfig
                {
                    Name = "p36",
                    Label = "القسم",
                    Type = "select",
                    Select2 = true,
                    Options = DeptOptions, // Use the DeptOptions you already loaded
                    ColCss = "6",
                    Required = true,
                    DependsOn = "p17",
                    DependsUrl = "/crud/DDLFiltered?FK=IdaraID&textcol=distributorName_A&ValueCol=distributorID&PageName=Users&TableIndex=11"
                },

                new FieldConfig { Name = "p04", Label = "الاسم الاول بالعربي",Type = "text",   Required = true, ColCss = "3", TextMode = "arabic" },
                new FieldConfig { Name = "p05", Label = "الاسم الثاني بالعربي",Type = "text",   Required = true, ColCss = "3", TextMode = "arabic" },
                new FieldConfig { Name = "p06", Label = "الاسم الثالث بالعربي",Type = "text",   Required = true, ColCss = "3", TextMode = "arabic" },

                new FieldConfig { Name = "p08", Label = "الاسم الاخير بالعربي",Type = "text",   Required = true, ColCss = "3", TextMode = "arabic" },

                new FieldConfig { Name = "p09", Label = "الاسم الاول بالانجليزي",Type = "text",   Required = false, ColCss = "3", TextMode="english" },
                new FieldConfig { Name = "p10", Label = "الاسم الثاني بالانجليزي",Type = "text",   Required = false, ColCss = "3", TextMode="english" },

                new FieldConfig { Name = "p11", Label = "الاسم الثالث بالانجليزي",Type = "text",   Required = false, ColCss = "3", TextMode="english" },

                new FieldConfig { Name = "p13", Label = "الاسم الاخير بالانجليزي",Type = "text",   Required = false, ColCss = "3", TextMode="english" },


                new FieldConfig { Name = "p14", Label = "صلاحية النظام",Type = "select",   Required = true, ColCss = "3", Options= UsersAuthTypeOptions,Select2 = true },

                new FieldConfig { Name = "p16", Label = "نوع المستخدم",Type = "select",   Required = true, ColCss = "3", Options= userTypeOptions,Select2 = true },
                



                
                new FieldConfig { Name = "p24", Label = "الجنس",Type = "select",   Required = true, ColCss = "3", Options= genderOptions,Select2 = true },
                new FieldConfig { Name = "p25", Label = "الجنسية",Type = "select",   Required = true, ColCss = "3", Options= nationalityOptions,Select2 = true },
                new FieldConfig { Name = "p26", Label = "الديانة",Type = "select",   Required = true, ColCss = "3", Options= religionOptions,Select2 = true },
                new FieldConfig {Name = "p27", Label = "الحالة الاجتماعية", Type = "select", Required = true, ColCss = "3", Options = maritalStatusOptions, Select2 = true},
                new FieldConfig {Name = "p28", Label = "الدرجة العلمية", Type = "select", Required = true, ColCss = "3", Options = EducationOptions, Select2 = true},


                 new FieldConfig { Name = "p20", Label = "ملاحظات",Type = "textarea",   Required = false, ColCss = "3" },

            };


            var UpdateUserFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",      Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController",  Type = "hidden", Value = ControllerName},
                new FieldConfig { Name = "pageName_",           Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",          Type = "hidden", Value = "UPDATEUSERS" },
                new FieldConfig { Name = "idaraID",             Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",           Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",            Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField,   Type = "hidden" },

                new FieldConfig { Name = "p01", Label = "الرقم المرجعي",Type = "hidden", Readonly = true, ColCss = "3" },
                new FieldConfig { Name = "p02", Label = "رقم الهوية الوطنية",Type = "text",   Required = true,  ColCss = "3", TextMode = "number",MaxLength=10 ,Readonly = !canUPDATENATIONALID  },
                 new FieldConfig { Name = "p03", Label = "الرقم العام",Type = "text",   Required = true, ColCss = "3", TextMode="number",MaxLength=10 },
                new FieldConfig { Name = "p23", Label = "تاريخ الميلاد",Type = "date",   Required = true, ColCss = "3" },
                new FieldConfig { Name = "p22", Label = "تاريخ اصدار الهوية",Type = "date",   Required = true, ColCss = "3" },
                 new FieldConfig { Name = "p17", Label = "الادارة",Type = "select",   Required = true, ColCss = "6", Options= IdaraOptions, Value=IdaraId},
                new FieldConfig
                {
                    Name = "p36",
                    Label = "القسم",
                    Type = "select",
                    Select2 = true,
                    Options = DeptOptions, // Use the DeptOptions you already loaded
                    ColCss = "6",
                    Required = true,
                    DependsOn = "p17",
                    DependsUrl = "/crud/DDLFiltered?FK=IdaraID&textcol=distributorName_A&ValueCol=distributorID&PageName=Users&TableIndex=11"
                },

                new FieldConfig { Name = "p04", Label = "الاسم الاول بالعربي",Type = "text",   Required = true, ColCss = "3", TextMode = "arabic" },
                new FieldConfig { Name = "p05", Label = "الاسم الثاني بالعربي",Type = "text",   Required = true, ColCss = "3", TextMode = "arabic" },
                new FieldConfig { Name = "p06", Label = "الاسم الثالث بالعربي",Type = "text",   Required = true, ColCss = "3", TextMode = "arabic" },

                new FieldConfig { Name = "p08", Label = "الاسم الاخير بالعربي",Type = "text",   Required = true, ColCss = "3", TextMode = "arabic" },

                new FieldConfig { Name = "p09", Label = "الاسم الاول بالانجليزي",Type = "text",   Required = false, ColCss = "3", TextMode="english" },
                new FieldConfig { Name = "p10", Label = "الاسم الثاني بالانجليزي",Type = "text",   Required = false, ColCss = "3", TextMode="english" },

                new FieldConfig { Name = "p11", Label = "الاسم الثالث بالانجليزي",Type = "text",   Required = false, ColCss = "3", TextMode="english" },

                new FieldConfig { Name = "p13", Label = "الاسم الاخير بالانجليزي",Type = "text",   Required = false, ColCss = "3", TextMode="english" },


                new FieldConfig { Name = "p14", Label = "صلاحية النظام",Type = "select",   Required = true, ColCss = "3", Options= UsersAuthTypeOptions,Select2 = true },

                new FieldConfig { Name = "p16", Label = "نوع المستخدم",Type = "select",   Required = true, ColCss = "3", Options= userTypeOptions,Select2 = true },





                new FieldConfig { Name = "p24", Label = "الجنس",Type = "select",   Required = true, ColCss = "3", Options= genderOptions,Select2 = true },
                new FieldConfig { Name = "p25", Label = "الجنسية",Type = "select",   Required = true, ColCss = "3", Options= nationalityOptions,Select2 = true },
                new FieldConfig { Name = "p26", Label = "الديانة",Type = "select",   Required = true, ColCss = "3", Options= religionOptions,Select2 = true },
                new FieldConfig {Name = "p27", Label = "الحالة الاجتماعية", Type = "select", Required = true, ColCss = "3", Options = maritalStatusOptions, Select2 = true},
                new FieldConfig {Name = "p28", Label = "الدرجة العلمية", Type = "select", Required = true, ColCss = "3", Options = EducationOptions, Select2 = true},


                 new FieldConfig { Name = "p35", Label = "ملاحظات",Type = "textarea",   Required = true, ColCss = "3" },

            };


            var DeleteUserFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",      Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController",  Type = "hidden", Value = ControllerName},
                new FieldConfig { Name = "pageName_",           Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",          Type = "hidden", Value = "DELETEUSERS" },
                new FieldConfig { Name = "idaraID",             Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",           Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",            Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField,   Type = "hidden" },

                new FieldConfig { Name = "p01", Label = "الرقم المرجعي",Type = "hidden", Readonly = true, ColCss = "3" },
                new FieldConfig { Name = "p02", Label = "رقم الهوية الوطنية",Type = "text",   Required = true,  ColCss = "6", TextMode = "number",MaxLength=10 ,Readonly=true  },
                 new FieldConfig { Name = "p03", Label = "الرقم العام",Type = "text",   Required = true, ColCss = "6", TextMode="number",MaxLength=10,Readonly=true },

                new FieldConfig { Name = "p22", Label = "تاريخ اصدار الهوية",Type = "hidden",   Required = true, ColCss = "3" },
                new FieldConfig { Name = "p17", Label = "الادارة",Type = "hidden",   Required = true, ColCss = "3", Options= IdaraOptions,Select2 = true, Value=IdaraId, Disabled = true },

                new FieldConfig { Name = "p04", Label = "الاسم الاول بالعربي",Type = "text",   Required = true, ColCss = "3", TextMode = "arabic",Readonly=true },
                new FieldConfig { Name = "p05", Label = "الاسم الثاني بالعربي",Type = "text",   Required = true, ColCss = "3", TextMode = "arabic",Readonly=true },
                new FieldConfig { Name = "p06", Label = "الاسم الثالث بالعربي",Type = "text",   Required = true, ColCss = "3", TextMode = "arabic",Readonly=true },

                new FieldConfig { Name = "p08", Label = "الاسم الاخير بالعربي",Type = "text",   Required = true, ColCss = "3", TextMode = "arabic",Readonly=true },

                new FieldConfig { Name = "p09", Label = "الاسم الاول بالانجليزي",Type = "hidden",   Required = false, ColCss = "3", TextMode="english" },
                new FieldConfig { Name = "p10", Label = "الاسم الثاني بالانجليزي",Type = "hidden",   Required = false, ColCss = "3", TextMode="english" },

                new FieldConfig { Name = "p11", Label = "الاسم الثالث بالانجليزي",Type = "hidden",   Required = false, ColCss = "3", TextMode="english" },

                new FieldConfig { Name = "p13", Label = "الاسم الاخير بالانجليزي",Type = "hidden",   Required = false, ColCss = "3", TextMode="english" },


                new FieldConfig { Name = "p14", Label = "صلاحية النظام",Type = "hidden",   Required = true, ColCss = "3", Options= UsersAuthTypeOptions,Select2 = true,Readonly=true },

                new FieldConfig { Name = "p16", Label = "نوع المستخدم",Type = "hidden",   Required = true, ColCss = "3", Options= userTypeOptions,Select2 = true,Readonly=true },





                new FieldConfig { Name = "p23", Label = "تاريخ الميلاد",Type = "hidden",   Required = true, ColCss = "3" },
                new FieldConfig { Name = "p24", Label = "الجنس",Type = "hidden",   Required = true, ColCss = "3", Options= genderOptions,Select2 = true },
                new FieldConfig { Name = "p25", Label = "الجنسية",Type = "hidden",   Required = true, ColCss = "3", Options= nationalityOptions,Select2 = true },
                new FieldConfig { Name = "p26", Label = "الديانة",Type = "hidden",   Required = true, ColCss = "3", Options= religionOptions,Select2 = true },
                new FieldConfig {Name = "p27", Label = "الحالة الاجتماعية", Type = "hidden", Required = true, ColCss = "3", Options = maritalStatusOptions, Select2 = true},
                new FieldConfig {Name = "p28", Label = "الدرجة العلمية", Type = "hidden", Required = true, ColCss = "3", Options = EducationOptions, Select2 = true},


                 new FieldConfig { Name = "p35", Label = "ملاحظات",Type = "textarea",   Required = true, ColCss = "6" },

            };

            // 🗑️ DELETE fields

            //  SmartTable model
            var dsModel = new SmartFoundation.UI.ViewModels.SmartTable.SmartTableDsModel
            {
                PageTitle = "ادارة المستخدمين",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = "ادارة المستخدمين ",
               
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = canInsert,
                    ShowEdit = canUpdate,
                    ShowDelete = canDelete,
                    ShowBulkDelete = false,
                    ShowExportPdf=true,
                    ExportConfig = new TableExportConfig
                    {
                        EnablePdf = true,
                        PdfEndpoint = "/exports/pdf/table",
                        PdfTitle = "المستفيدين",
                        PdfPaper = "A4",
                        PdfOrientation = "portrait",
                        PdfShowPageNumbers = true,
                        Filename = "Residents",
                        PdfShowGeneratedAt = false, 
                    },

                    Add = new TableAction
                    {
                        Label = "إضافة مستخدم جديد",
                        Icon = "fa fa-user-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إدخال مستخدم جديد",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassInsertForm",
                            Title = "إضافة مستخدم جديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = InsertUserFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ",   Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },

                    Edit = new TableAction
                    {
                        Label = "تعديل مستخدم",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        //Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = MsgUpdateNationalID,
                        ModalMessageClass = "bg-red-50 border border-red-200 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm", 
                            Title = "تعديل بيانات مستخدم",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = UpdateUserFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },

                    Delete = new TableAction
                    {
                        Label = "حذف مستخدم",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        //Placement = TableActionPlacement.ActionsMenu, 
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من حذف هذا المستخدم؟",
                        ModalMessageClass = "bg-red-50 border border-red-200 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassDeleteForm",
                            Title = "تأكيد حذف المستخدم",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حذف",   Type = "submit", Color = "danger",  },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = DeleteUserFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                }
            };

            //return View("HousingDefinitions/BuildingClass", dsModel);

            var page = new SmartFoundation.UI.ViewModels.SmartPage.SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-sitemap",
                TableDS = dsModel
            };

            return View("Permission/Users", page);

        }
    }
}
