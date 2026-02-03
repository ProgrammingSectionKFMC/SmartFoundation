using Microsoft.AspNetCore.Mvc;
using SmartFoundation.MVC.Reports;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartPrint;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers.Housing
{
    public partial class HousingController : Controller
    {
        public async Task<IActionResult> Residents(int pdf = 0)
        {
            //  قراءة السيشن والكونتكست
            if (!InitPageContext(out var redirect))
                return redirect!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }

            ControllerName = nameof(Housing);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "Residents" : PageName;

            var spParameters = new object?[]
            {
             PageName ?? "Residents",
             IdaraId,
             usersId,
             HostName
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

            //  تقسيم الداتا سيت للجدول الأول + جداول أخرى
            SplitDataSet(ds);

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


            List<OptionItem> rankOptions = new();
            List<OptionItem> militaryUnitOptions = new();
            List<OptionItem> MaritalStatusOptions = new();
            List<OptionItem> NationalityOptions = new();
            List<OptionItem> GenderOptions = new();

            // ---------------------- DDLValues ----------------------

            JsonResult? result;
            string json;

            //// ---------------------- rankOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "rankNameA", "rankID", "2", nameof(Residents), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            rankOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;
            //// ---------------------- militaryUnitOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "militaryUnitName_A", "militaryUnitID", "3", nameof(Residents), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            militaryUnitOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;
            //// ---------------------- MaritalStatus ----------------------
            result = await _CrudController.GetDDLValues(
                "maritalStatusName_A", "maritalStatusID", "4", nameof(Residents), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            MaritalStatusOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;
            //// ---------------------- Nationality ----------------------
            result = await _CrudController.GetDDLValues(
                "nationalityName_A", "nationalityID", "5", nameof(Residents), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            NationalityOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;
            //// ---------------------- Gender ----------------------
            result = await _CrudController.GetDDLValues(
                "genderName_A", "genderID", "6", nameof(Residents), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            GenderOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            //// ---------------------- END DDL ----------------------

            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // صلاحيات
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "INSERT") canInsert = true;
                        if (permissionName == "UPDATE") canUpdate = true;
                        if (permissionName == "DELETE") canDelete = true;
                    }

                    if (dt1 != null && dt1.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField = "residentInfoID";
                        var possibleIdNames = new[] { "residentInfoID", "ResidentInfoID", "Id", "ID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["residentInfoID"] = "الرقم المرجعي",
                            ["NationalID"] = "رقم الهوية",
                            ["generalNo_FK"] = "الرقم العام",
                            ["rankNameA"] = "الرتبة",
                            ["militaryUnitName_A"] = "الوحدة",
                            ["maritalStatusName_A"] = "الحالة الاجتماعية",
                            ["dependinceCounter"] = "عدد التابعين",
                            ["nationalityName_A"] = "الجنسية",
                            ["genderName_A"] = "الجنس",
                            ["FullName_A"] = "الاسم بالعربي",
                            ["FullName_E"] = "الاسم بالانجليزي",
                            ["birthdate"] = "تاريخ الميلاد",
                            ["residentcontactDetails"] = "رقم الجوال",
                            ["note"] = "ملاحظات"
                        };

                        // الأعمدة
                        //foreach (DataColumn c in dt1.Columns)
                        //{
                        //    string colType = "text";
                        //    var t = c.DataType;
                        //    if (t == typeof(bool)) colType = "bool";
                        //    else if (t == typeof(DateTime)) colType = "date";
                        //    else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                        //             || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                        //        colType = "number";

                        //    bool isfirstName_A = c.ColumnName.Equals("firstName_A", StringComparison.OrdinalIgnoreCase);
                        //    bool issecondName_A = c.ColumnName.Equals("secondName_A", StringComparison.OrdinalIgnoreCase);
                        //    bool isthirdName_A = c.ColumnName.Equals("thirdName_A", StringComparison.OrdinalIgnoreCase);
                        //    bool islastName_A = c.ColumnName.Equals("lastName_A", StringComparison.OrdinalIgnoreCase);
                        //    bool isfirstName_E = c.ColumnName.Equals("firstName_E", StringComparison.OrdinalIgnoreCase);
                        //    bool issecondName_E = c.ColumnName.Equals("secondName_E", StringComparison.OrdinalIgnoreCase);
                        //    bool isthirdName_E = c.ColumnName.Equals("thirdName_E", StringComparison.OrdinalIgnoreCase);
                        //    bool islastName_E = c.ColumnName.Equals("lastName_E", StringComparison.OrdinalIgnoreCase);
                        //    bool isrankID_FK = c.ColumnName.Equals("rankID_FK", StringComparison.OrdinalIgnoreCase);
                        //    bool ismilitaryUnitID_FK = c.ColumnName.Equals("militaryUnitID_FK", StringComparison.OrdinalIgnoreCase);
                        //    bool ismartialStatusID_FK = c.ColumnName.Equals("martialStatusID_FK", StringComparison.OrdinalIgnoreCase);
                        //    bool isnationalityID_FK = c.ColumnName.Equals("nationalityID_FK", StringComparison.OrdinalIgnoreCase);
                        //    bool isgenderID_FK = c.ColumnName.Equals("genderID_FK", StringComparison.OrdinalIgnoreCase);



                        //    bool isMilitaryUnitName =   //جديد
                        //    c.ColumnName.Equals("militaryUnitName_A", StringComparison.OrdinalIgnoreCase);

                        //    bool isNote =
                        //    c.ColumnName.Equals("note", StringComparison.OrdinalIgnoreCase);



                        //    dynamicColumns.Add(new TableColumn
                        //    {
                        //        Field = c.ColumnName,
                        //        Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                        //        Type = colType,
                        //        Sortable = true
                        //         ,
                        //        Visible = !(isfirstName_A || isfirstName_E || issecondName_A || issecondName_E || isthirdName_A || isthirdName_E || islastName_A || islastName_E || isrankID_FK || ismilitaryUnitID_FK || ismartialStatusID_FK || isnationalityID_FK || isgenderID_FK),


                        //        truncate = isMilitaryUnitName || isNote // truncate يقص النص الطويل 

                        //    });
                        //}




                        // الأعمدة
                        foreach (DataColumn c in dt1.Columns)
                        {
                            string colType = "text";
                            var t = c.DataType;
                            if (t == typeof(bool)) colType = "bool";
                            else if (t == typeof(DateTime)) colType = "date";
                            else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                                     || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                                colType = "number";

                            bool isfirstName_A = c.ColumnName.Equals("firstName_A", StringComparison.OrdinalIgnoreCase);
                            bool issecondName_A = c.ColumnName.Equals("secondName_A", StringComparison.OrdinalIgnoreCase);
                            bool isthirdName_A = c.ColumnName.Equals("thirdName_A", StringComparison.OrdinalIgnoreCase);
                            bool islastName_A = c.ColumnName.Equals("lastName_A", StringComparison.OrdinalIgnoreCase);
                            bool isfirstName_E = c.ColumnName.Equals("firstName_E", StringComparison.OrdinalIgnoreCase);
                            bool issecondName_E = c.ColumnName.Equals("secondName_E", StringComparison.OrdinalIgnoreCase);
                            bool isthirdName_E = c.ColumnName.Equals("thirdName_E", StringComparison.OrdinalIgnoreCase);
                            bool islastName_E = c.ColumnName.Equals("lastName_E", StringComparison.OrdinalIgnoreCase);

                            bool isrankID_FK = c.ColumnName.Equals("rankID_FK", StringComparison.OrdinalIgnoreCase);
                            bool ismilitaryUnitID_FK = c.ColumnName.Equals("militaryUnitID_FK", StringComparison.OrdinalIgnoreCase);
                            bool ismartialStatusID_FK = c.ColumnName.Equals("martialStatusID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isnationalityID_FK = c.ColumnName.Equals("nationalityID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isgenderID_FK = c.ColumnName.Equals("genderID_FK", StringComparison.OrdinalIgnoreCase);

                            bool isMilitaryUnitName = c.ColumnName.Equals("militaryUnitName_A", StringComparison.OrdinalIgnoreCase);
                            bool isNote = c.ColumnName.Equals("note", StringComparison.OrdinalIgnoreCase);

                            //  فقط هذي الأعمدة نبي لها فلتر select
                            bool isRankName = c.ColumnName.Equals("rankNameA", StringComparison.OrdinalIgnoreCase);
                            bool isUnitName = c.ColumnName.Equals("militaryUnitName_A", StringComparison.OrdinalIgnoreCase);
                            bool isNationalityName = c.ColumnName.Equals("nationalityName_A", StringComparison.OrdinalIgnoreCase); 

                            //  جهز خيارات الفلتر من نفس بيانات الجدول (عشان التطابق يكون صحيح)
                            List<OptionItem> filterOpts = new();
                            if (isRankName || isUnitName || isNationalityName)
                            {
                                var field = c.ColumnName;

                                var distinctVals = dt1.AsEnumerable()
                                    .Select(r => (r[field] == DBNull.Value ? "" : r[field]?.ToString())?.Trim())
                                    .Where(s => !string.IsNullOrWhiteSpace(s))
                                    .Distinct()
                                    .OrderBy(s => s)
                                    .ToList();

                                filterOpts = distinctVals
                                    .Select(s => new OptionItem { Value = s!, Text = s! })
                                    .ToList();
                            }

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,

                                Visible = !(isfirstName_A || isfirstName_E || issecondName_A || issecondName_E || isthirdName_A || isthirdName_E ||
                                            islastName_A || islastName_E || isrankID_FK || ismilitaryUnitID_FK || ismartialStatusID_FK ||
                                            isnationalityID_FK || isgenderID_FK),

                                truncate = isMilitaryUnitName || isNote,

                                //  فلتر للرتبة + الوحدة + الجنسية
                                Filter = (isRankName || isUnitName || isNationalityName)
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





                        // الصفوف
                        foreach (DataRow r in dt1.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt1.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            // p01..p05
                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("residentInfoID") ?? Get("ResidentInfoID");
                            dict["p02"] = Get("NationalID");
                            dict["p03"] = Get("generalNo_FK");
                            dict["p04"] = Get("firstName_A");
                            dict["p05"] = Get("secondName_A");
                            dict["p06"] = Get("thirdName_A");
                            dict["p07"] = Get("lastName_A");
                            dict["p08"] = Get("firstName_E");
                            dict["p09"] = Get("secondName_E");
                            dict["p10"] = Get("thirdName_E");
                            dict["p11"] = Get("lastName_E");
                            dict["p12"] = Get("FullName_A");
                            dict["p13"] = Get("FullName_E");
                            dict["p14"] = Get("rankID_FK");
                            dict["p15"] = Get("rankNameA");
                            dict["p16"] = Get("militaryUnitID_FK");
                            dict["p17"] = Get("militaryUnitName_A");
                            dict["p18"] = Get("martialStatusID_FK");
                            dict["p19"] = Get("maritalStatusName_A");
                            dict["p20"] = Get("dependinceCounter");
                            dict["p21"] = Get("nationalityID_FK");
                            dict["p22"] = Get("nationalityName_A");
                            dict["p23"] = Get("genderID_FK");
                            dict["p24"] = Get("genderName_A");
                            dict["p25"] = Get("birthdate");
                            dict["p26"] = Get("residentcontactDetails");
                            dict["p27"] = Get("note");

                            rowsList.Add(dict);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.BuildingTypeDataSetError = ex.Message;
            }

            // ADD fields
            var addFields = new List<FieldConfig>
            {
                new FieldConfig { Name = rowIdField, Type = "hidden" },

                new FieldConfig { Name = "p01", Label = "رقم الهوية", Type = "nationalid", ColCss = "6",Icon = "fa-solid fa-address-card"  },
                new FieldConfig { Name = "p02", Label = "الرقم العام", Type = "number", ColCss = "6", Required = true , Icon = "fa-solid fa-user-tag",Autocomplete="off" },
                


                new FieldConfig { Name = "p03", Label = "الاسم الاول بالعربي", Type = "text", Required = true, Placeholder = "حقل عربي فقط",  Icon = "fa-solid fa-user", ColCss = "3", MaxLength = 50, TextMode = "arabic",},
                new FieldConfig { Name = "p04", Label = "اسم الاب بالعربي", Type = "text", Required = true, Placeholder = "حقل عربي فقط",  Icon = "fa-solid fa-user", ColCss = "3", MaxLength = 50, TextMode = "arabic",},
                new FieldConfig { Name = "p05", Label = "اسم الجد بالعربي", Type = "text", Required = true, Placeholder = "حقل عربي فقط",  Icon = "fa-solid fa-user", ColCss = "3", MaxLength = 50, TextMode = "arabic",},
                new FieldConfig { Name = "p06", Label = "الاسم الاخير بالعربي", Type = "text", Required = true, Placeholder = "حقل عربي فقط",  Icon = "fa-solid fa-user", ColCss = "3", MaxLength = 50, TextMode = "arabic",},


                new FieldConfig { Name = "p07", Label = "الاسم الاول بالانجليزي", Type = "text",  Placeholder = "حقل انجليزي فقط",  Icon = "fa-solid fa-user", ColCss = "3", MaxLength = 50, TextMode = "english",},
                new FieldConfig { Name = "p08", Label = "اسم الاب بالانجليزي", Type = "text",  Placeholder = "حقل انجليزي فقط",  Icon = "fa-solid fa-user", ColCss = "3", MaxLength = 50, TextMode = "english",},
                new FieldConfig { Name = "p09", Label = "اسم الجد بالانجليزي", Type = "text", Placeholder = "حقل انجليزي فقط",  Icon = "fa-solid fa-user", ColCss = "3", MaxLength = 50, TextMode = "english",},
                new FieldConfig { Name = "p10", Label = "الاسم الاخير بالانجليزي", Type = "text", Placeholder = "حقل انجليزي فقط",  Icon = "fa-solid fa-user", ColCss = "3", MaxLength = 50, TextMode = "english",},

                new FieldConfig { Name = "p11", Label = "الرتبة", Type = "select", ColCss = "3", Required = true, Options= rankOptions,Select2 = true },
                new FieldConfig { Name = "p12", Label = "الوحدة", Type = "select", ColCss = "6", Required = true, Options= militaryUnitOptions,Select2 = true },
                new FieldConfig { Name = "p13", Label = "الحالة الاجتماعية", Type = "select", ColCss = "3", Required = true, Options= MaritalStatusOptions,Select2 = true },
                new FieldConfig { Name = "p14", Label = "الجنسية", Type = "select", ColCss = "3", Required = true, Options= NationalityOptions,Select2 = true },

                new FieldConfig { Name = "p15", Label = "عدد التابعين", Type = "number", ColCss = "3",Icon = "fa-solid fa-user-group"},
                new FieldConfig { Name = "p16", Label = "الجنس", Type = "select", ColCss = "3", Required = true, Options= GenderOptions,Select2 = true },
                new FieldConfig { Name = "p17", Label = "تاريخ الميلاد", Type = "date", ColCss = "3",Icon = "fa fa-calendar" },
                new FieldConfig { Name = "p18", Label = "رقم الجوال", Type = "tel", ColCss = "3", Required = true, HelpText=" مثال : 05XXXXXXXX",Icon = "fa fa-square-phone" },
                new FieldConfig { Name = "p19", Label = "ملاحظات", Type = "textarea", ColCss = "6", Required = false },
                
            };

            // hidden fields
            addFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken",Type ="hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addFields.Insert(0, new FieldConfig { Name = "hostname",Type="hidden",Value = Request.Host.Value });
            addFields.Insert(0, new FieldConfig { Name = "entrydata",Type="hidden",Value =usersId.ToString() });
            addFields.Insert(0, new FieldConfig { Name = "idaraID",Type="hidden",Value =IdaraId.ToString() });
            addFields.Insert(0, new FieldConfig { Name = "ActionType",Type="hidden",Value="INSERT" });
            addFields.Insert(0, new FieldConfig { Name = "pageName_",Type ="hidden",Value=PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectAction",Type="hidden", Value=PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectController",Type="hidden",Value=ControllerName });

            // UPDATE fields
            var updateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",Type="hidden", Value = PageName },
                new FieldConfig { Name = "redirectController",Type = "hidden", Value = ControllerName},
                new FieldConfig { Name = "pageName_",Type="hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",Type="hidden", Value = "UPDATE" },
                new FieldConfig { Name = "idaraID",Type ="hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",Type="hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",Type="hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField,Type="hidden" },



                new FieldConfig { Name = "p01", Label = "الرقم المرجعي",Type ="hidden", ColCss = "3" },
                new FieldConfig { Name = "p02", Label = "رقم الهوية",Type ="nationalid", ColCss = "6" , Readonly=true,Icon = "fa-solid fa-address-card"},
                new FieldConfig { Name = "p03", Label = "الرقم العام",Type = "number", ColCss = "6", Required = true, Icon = "fa-solid fa-user-tag" },

                new FieldConfig { Name = "p04", Label = "الاسم الاول بالعربي",Type= "text", Required = true, Placeholder = "حقل عربي فقط",  Icon = "fa-solid fa-user", ColCss = "3", MaxLength = 50, TextMode = "arabic",},
                new FieldConfig { Name = "p05", Label = "اسم الاب بالعربي", Type="text", Required = true, Placeholder = "حقل عربي فقط",  Icon = "fa-solid fa-user", ColCss = "3", MaxLength = 50, TextMode = "arabic",},
                new FieldConfig { Name = "p06", Label = "اسم الجد بالعربي", Type="text", Required = true, Placeholder = "حقل عربي فقط",  Icon = "fa-solid fa-user", ColCss = "3", MaxLength = 50, TextMode = "arabic",},
                new FieldConfig { Name = "p07", Label = "الاسم الاخير بالعربي",Type ="text", Required = true, Placeholder = "حقل عربي فقط",  Icon = "fa-solid fa-user", ColCss = "3", MaxLength = 50, TextMode = "arabic",},


                new FieldConfig { Name = "p08", Label = "الاسم الاول بالانجليزي", Type = "text",  Placeholder = "حقل انجليزي فقط",  Icon = "fa-solid fa-user", ColCss = "3", MaxLength = 50, TextMode = "english",},
                new FieldConfig { Name = "p09", Label = "اسم الاب بالانجليزي", Type = "text",  Placeholder = "حقل انجليزي فقط",  Icon = "fa-solid fa-user", ColCss = "3", MaxLength = 50, TextMode = "english",},
                new FieldConfig { Name = "p10", Label = "اسم الجد بالانجليزي", Type = "text", Placeholder = "حقل انجليزي فقط",  Icon = "fa-solid fa-user", ColCss = "3", MaxLength = 50, TextMode = "english",},
                new FieldConfig { Name = "p11", Label = "الاسم الاخير بالانجليزي", Type = "text", Placeholder = "حقل انجليزي فقط",  Icon = "fa-solid fa-user", ColCss = "3", MaxLength = 50, TextMode = "english",},

                new FieldConfig { Name = "p14", Label = "الرتبة", Type = "select", ColCss = "3", Required = true, Options= rankOptions,Select2 = true },
                new FieldConfig { Name = "p16", Label = "الوحدة", Type = "select", ColCss = "6", Required = true, Options= militaryUnitOptions,Select2 = true },
                new FieldConfig { Name = "p18", Label = "الحالة الاجتماعية", Type = "select", ColCss = "3", Required = true, Options= MaritalStatusOptions,Select2 = true },
                new FieldConfig { Name = "p21", Label = "الجنسية", Type = "select", ColCss = "3", Required = true, Options= NationalityOptions,Select2 = true },

                new FieldConfig { Name = "p20", Label = "عدد التابعين", Type = "number", ColCss = "3",Icon = "fa-solid fa-user-group" },
                new FieldConfig { Name = "p23", Label = "الجنس", Type = "select", ColCss = "3", Required = true, Options= GenderOptions,Select2 = true },
                new FieldConfig { Name = "p25", Label = "تاريخ الميلاد", Type = "date", ColCss = "3",Icon = "fa fa-calendar" },
                new FieldConfig { Name = "p26", Label = "رقم الجوال", Type = "tel", ColCss = "3", Required = true,Icon = "fa fa-square-phone" },

                new FieldConfig { Name = "p27", Label = "ملاحظات", Type = "textarea", ColCss = "6", Required = false }
            };

            // DELETE fields
            var deleteFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController",Type="hidden", Value = ControllerName },
                new FieldConfig { Name = "pageName_",Type="hidden",Value=PageName },
                new FieldConfig { Name = "ActionType",Type="hidden",Value="DELETE" },
                new FieldConfig { Name = "idaraID",Type="hidden",Value= IdaraId.ToString() },
                new FieldConfig { Name = "hostname",Type ="hidden",Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken",Type="hidden",Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField,Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "residentInfoID" }
            };

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "المستفيدين",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,

                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector=true,
                PanelTitle = "المستفيدين",
                //TabelLabel = "بيانات المستفيدين",
                //TabelLabelIcon = "fa-solid fa-user-group",
                EnableCellCopy = true,
                ShowFilter = true,
                FilterRow = true,   
                FilterDebounce = 250,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,

                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = true,
                    ShowExportPdf = true,
                    ShowAdd = canInsert,
                    ShowEdit = canUpdate,
                    ShowDelete = canDelete,
                    ShowPrint1 = true,
                    ShowBulkDelete = false,
                    Print1 = new TableAction
                    {
                        Label = "طباعة تقرير",
                        Icon = "fa fa-print",
                        Color = "info",
                        RequireSelection = false,
                        OnClickJs = @"
                                sfPrintWithBusy(table, {
                                  pdf: 1,
                                  busy: { title: 'طباعة بيانات المستفيدين'}
                                });
                              "
                    },

                    ExportConfig = new TableExportConfig
                    {
                        EnablePdf = true,
                        PdfEndpoint = "/exports/pdf/table",
                        PdfTitle = "المستفيدين",
                        PdfPaper = "A4",
                        PdfOrientation = "landscape",
                        PdfShowPageNumbers = true,
                        Filename = "Residents",
                        PdfShowGeneratedAt = true, 
                        PdfShowSerial = true,  
                        PdfSerialLabel = "م",  
                        RightHeaderLine1 = "المملكة العربية السعودية",
                        RightHeaderLine2 = "وزارة الدفاع",
                        RightHeaderLine3 = "القوات البرية الملكية السعودية",
                        RightHeaderLine4 = "الإدارة الهندسية للتشغيل والصيانة",
                        RightHeaderLine5 = "مدينة الملك فيصل العسكرية",
                        PdfLogoUrl="/img/ppng.png",


                    },

                            CustomActions = new List<TableAction>
                            {
                            //  Excel "
                            new TableAction
                            {
                                Label = "تصدير Excel",
                                Icon = "fa-regular fa-file-excel",
                                Color = "info",
                                Placement = TableActionPlacement.ActionsMenu,
                                RequireSelection = false,
                                OnClickJs = "table.exportData('excel');"
                            },

                            //  PDF "
                            new TableAction
                            {
                                Label = "تصدير PDF",
                                Icon = "fa-regular fa-file-pdf",
                                Color = "danger",
                                Placement = TableActionPlacement.ActionsMenu,
                                RequireSelection = false,
                                OnClickJs = "table.exportData('pdf');"
                            },

                             //  details "       
                            new TableAction
                            {
                                Label = "عرض التفاصيل",
                                ModalTitle = "<i class='fa-solid fa-circle-info text-emerald-600 text-xl mr-2'></i> تفاصيل المستفيد",
                                Icon = "fa-regular fa-file",
                                OpenModal = true,
                                RequireSelection = true,
                                MinSelection = 1,
                                MaxSelection = 1,
                                

                            },
                        },


                        Add = new TableAction
                        {
                            Label = "إضافة مستفيد",
                            Icon = "fa fa-plus",
                            Color = "success",
                            OpenModal = true,
                            ModalTitle = "<i class='fa-solid fa-user-plus text-emerald-600 text-xl mr-2'></i> إدخال بيانات مستفيد جديد",

                            OpenForm = new FormConfig
                            {
                            FormId = "BuildingTypeInsertForm",
                            Title = "بيانات مستفيد جديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },

                    Edit = new TableAction
                    {
                        Label = "تعديل بيانات مستفيد",
                        Icon = "fa-solid fa-pen",
                        Color = "info",
                        Placement = TableActionPlacement.ActionsMenu,  
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa-solid fa-user-pen text-emerald-600 text-xl mr-2'></i> تعديل بيانات مستفيد",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "تعديل بيانات مستفيد",
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
                        Label = "حذف بيانات مستفيد",
                        Icon = "fa-regular fa-trash-can",
                        Color = "danger",
                        Placement = TableActionPlacement.ActionsMenu,
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من حذف بيانات المستفيد؟",
                        ModalMessageClass = "bg-red-100 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeDeleteForm",
                            Title = "تأكيد حذف بيانات المستفيد",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حذف", Type = "submit", Color = "danger", },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = deleteFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                }
            };

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-solid fa-user-group",
                TableDS = dsModel
            };


            if (pdf == 1)
            {
                //var printTable = dt1;
                //int start1Based = 1; // يبدأ من الصف 200
                //int count = 100;       // يطبع 50 سجل

                //int startIndex = start1Based - 1;
                //int endIndex = Math.Min(dt1.Rows.Count, startIndex + dt1.Rows.Count);

                // جدول خفيف للطباعة
                var printTable = new DataTable();
                printTable.Columns.Add("NationalID", typeof(string));
                printTable.Columns.Add("FullName_A", typeof(string));
                printTable.Columns.Add("generalNo_FK", typeof(string));
                printTable.Columns.Add("rankNameA", typeof(string));
                printTable.Columns.Add("militaryUnitName_A", typeof(string));
                printTable.Columns.Add("maritalStatusName_A", typeof(string));
                printTable.Columns.Add("dependinceCounter", typeof(string));
                printTable.Columns.Add("nationalityName_A", typeof(string));
                printTable.Columns.Add("genderName_A", typeof(string));
                printTable.Columns.Add("birthdate", typeof(string));
                printTable.Columns.Add("residentcontactDetails", typeof(string));

                //for (int i = startIndex; i < endIndex; i++)
                foreach (DataRow r in dt1.Rows)
                {
                    //var r = dt1.Rows[i];

                    printTable.Rows.Add(
                        r["NationalID"],
                        r["FullName_A"],
                        r["generalNo_FK"],
                        r["rankNameA"],
                        r["militaryUnitName_A"],
                        r["maritalStatusName_A"],
                        r["dependinceCounter"],
                        r["nationalityName_A"],
                        r["genderName_A"],
                        r["birthdate"],
                        r["residentcontactDetails"]
                    );
                }

                if (printTable == null || printTable.Rows.Count == 0)
                    return Content("لا توجد بيانات للطباعة.");
                var reportColumns = new List<ReportColumn>
                    {
                        new("NationalID", "رقم الهوية", Align:"center", Weight:2, FontSize:9),
                        new("FullName_A", "الاسم", Align:"center", Weight:5, FontSize:9),
                        new("generalNo_FK", "الرقم العام", Align:"center", Weight:2, FontSize:9),
                        new("rankNameA", "الرتبة", Align:"center", Weight:2, FontSize:9),
                        new("militaryUnitName_A", "الوحدة", Align:"center", Weight:3, FontSize:9),
                        new("maritalStatusName_A", "الحالة الاجتماعية", Align:"center", Weight:3, FontSize:9),
                        new("dependinceCounter", "عدد التابعين", Align:"center", Weight:2, FontSize:9),
                        new("nationalityName_A", "الجنسية", Align:"center", Weight:2, FontSize:9),
                        new("genderName_A", "الجنس", Align:"center", Weight:2, FontSize:9),
                        new("birthdate", "تاريخ الميلاد", Align:"center", Weight:2, FontSize:9),
                        new("residentcontactDetails", "رقم الجوال", Align:"center", Weight:2, FontSize:9),
                    };

                var logo = Path.Combine(_env.WebRootPath, "img", "ppng.png");
                var header = new Dictionary<string, string>
                {
                    ["no"] = usersId,//"١٢٣/٤٥",
                    ["date"] = DateTime.Now.ToString("yyyy/MM/dd"),
                    ["attach"] = "—",
                    ["subject"] = "قائمة المستفيدين",

                    ["right1"] = "المملكة العربية السعودية",
                    ["right2"] = "وزارة الدفاع",
                    ["right3"] = "القوات البرية الملكية السعودية",
                    ["right4"] = "الادارة الهندسية للتشغيل والصيانة",
                    ["right5"] = "إدارة مدينة الملك فيصل العسكرية",

                    //["bismillah"] = "بسم الله الرحمن الرحيم",
                    ["midCaption"] = ""
                };

                var report = DataTableReportBuilder.FromDataTable(
                    reportId: "BuildingType",
                    title: "قائمة المستفيدين",
                    table: printTable,
                    columns: reportColumns,
                    headerFields: header,
                   //footerFields: new(),
                   footerFields: new Dictionary<string, string>
                   {
                       ["تمت الطباعة بواسطة"] = FullName,
                       ["ملاحظة"] = " هذا التقرير للاستخدام الرسمي",
                       ["عدد السجلات"] = dt1.Rows.Count.ToString(),
                       ["تاريخ ووقت الطباعة"] = DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss")
                   },

                    orientation: ReportOrientation.Landscape,
                    headerType: ReportHeaderType.LetterOfficial,
                    logoPath: logo,
                    headerRepeat: ReportHeaderRepeat.FirstPageOnly
                    //headerRepeat: ReportHeaderRepeat.AllPages
                );

                var pdfBytes = QuestPdfReportRenderer.Render(report);
                Response.Headers["Content-Disposition"] = "inline; filename=BuildingType.pdf";
                return File(pdfBytes, "application/pdf");
            }
            return View("WaitingList/Residents", page);
        }
    }
}