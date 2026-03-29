using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Reflection;
using System.Text.Json;
using static System.Collections.Specialized.BitVector32;


namespace SmartFoundation.Mvc.Controllers.Housing
{
    public partial class HousingController : Controller
    {
        public async Task<IActionResult> RentExemption()
        {
            //  قراءة السيشن والكونتكست
            if (!InitPageContext(out var redirect))
                return redirect!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }

            string? NationalID_ = Request.Query["NID"].FirstOrDefault();

            ControllerName = nameof(Housing);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "RentExemption" : PageName;

            var spParameters = new object?[]
            {
             PageName ?? "RentExemption",
             IdaraId,
             usersId,
             HostName,
             NationalID_
            };

           

            var rowsList = new List<Dictionary<string, object?>>();
            var rowsList_dt2 = new List<Dictionary<string, object?>>();

            var dynamicColumns = new List<TableColumn>();
            var dynamicColumns_dt2 = new List<TableColumn>();


            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

            //  تقسيم الداتا سيت للجدول الأول + جداول أخرى
            SplitDataSet(ds);


            

            string residentInfoIdaraID = "";
            


           


            if (dt1 != null && dt1.Rows.Count > 0)
            {
                DataRow rows = dt1.Rows[0];
                if (dt1.Columns.Contains("IdaraID") && rows["IdaraID"] != DBNull.Value)
                    residentInfoIdaraID = rows["IdaraID"].ToString();
            }



            //  التحقق من الصلاحيات
            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }


            if (!string.IsNullOrWhiteSpace(NationalID_) && (dt1 == null || dt1.Rows.Count == 0))
            {
                TempData["Error"] = "لم يتم العثور على نتائج لرقم الهوية: " + NationalID_;
                
            }


            string? residentInfoID_ = null;
            if (dt1 != null && dt1.Columns.Contains("NationalID") && dt1.Columns.Contains("residentInfoID"))
            {
                var row = dt1.AsEnumerable()
                    .FirstOrDefault(r => r["NationalID"] != DBNull.Value && r["NationalID"].ToString() == NationalID_);
                if (row != null)
                {
                    var val = row["residentInfoID"];
                    residentInfoID_ = val == DBNull.Value ? null : val.ToString();
                }
            }

            string? generalNo_FK_ = null;
            if (dt1 != null && dt1.Columns.Contains("NationalID") && dt1.Columns.Contains("generalNo_FK"))
            {
                var row = dt1.AsEnumerable()
                    .FirstOrDefault(r => r["NationalID"] != DBNull.Value && r["NationalID"].ToString() == NationalID_);
                if (row != null)
                {
                    var val = row["generalNo_FK"];
                    generalNo_FK_ = val == DBNull.Value ? null : val.ToString();
                }
            }



            string rowIdField = "";
            string rowIdField_dt2 = "";

            bool canInsertWaitingList = false;
            bool canInsertOCCUBENTLETTER = false;
            bool canUpdateWaitingList = false;
            bool canUpdateOCCUBENTLETTER = false;
            bool canMoveWaitingList = false;
            bool canDeleteWaitingList = false;
            bool canDeleteOCCUBENTLETTER = false;
            bool candeleteMoveWaitingList = false;
            bool canDELETERESIDENTALLWAITINGLIST = false;


            FormConfig form = new();


            List<OptionItem> waitingClassOptions = new();
            List<OptionItem> waitingOrderTypeOptions = new();


            // ---------------------- DDLValues ----------------------




            JsonResult? result;
            string json;




            //// ---------------------- WaitingClass ----------------------
            result = await _CrudController.GetDDLValues(
                "waitingClassName_A", "waitingClassID", "5", nameof(RentExemption), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            waitingClassOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;
            //// ---------------------- militaryUnitOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "waitingOrderTypeName_A", "waitingOrderTypeID", "6", nameof(RentExemption), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            waitingOrderTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;
            

            //// ---------------------- END DDL ----------------------

            try
            {

                form = new FormConfig
                {
                    Fields = new List<FieldConfig>
                    {
                                new FieldConfig
                                {
                                    SectionTitle= "نوع البحث",                 
                                    Label="البحث برقم الهوية الوطنية", 
                                    Name="NationalID",
                                    Type="text",
                                    ColCss="3",
                                    Icon="fa-solid fa-address-card",
                                    Placeholder="أدخل الرقم (مثال: 1xxxxxxxxx)",
                                    //HelpText="عشرةأرقام فقط*",
                                    Value= NationalID_,                 // القيمة الافتراضية (من السيرفر)
                                    MaxLength=10,
                                    Required=true,
                                    InputLang= "number",
                                    InputPattern= @"^[0-9]{10}$",
                                    PatternMsg= "رقم الهوية يجب أن يكون 10 أرقام",
                                    RequiredMsg= "الرجاء كتابة رقم الهوية الوطنية",
                                    IsNumericOnly=true,
                                    SubmitOnEnter =true,  // يفعل زر  Enter جديد
                                    // ===== زر داخل نفس الحقل =====
                                    InlineButton=true,               // تفعيل زر داخل الحقل
                                    InlineButtonText="بحـث",              // نص الزر
                                    InlineButtonIcon= "fa-solid fa-magnifying-glass",
                                    InlineButtonCss="btn btn-success", 
                                    InlineButtonPosition="end",              // مكان الزر (end / start)
                                    InlineButtonOnClickJs="sfNav(this)",      // استدعاء الدالة العامة )
                                    // ===== بيانات التنقل (sfNav) =====
                                    NavUrl="/Housing/RentExemption", // الصفحة الهدف
                                    NavKey="NID",                            // اسم باراميتر الـ QueryString

                                    }
                              }
                        };

                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // صلاحيات
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "INSERTWAITINGLIST") canInsertWaitingList = true;
                        if (permissionName == "INSERTOCCUBENTLETTER") canInsertOCCUBENTLETTER = true;
                        if (permissionName == "UPDATEWAITINGLIST") canUpdateWaitingList = true;
                        if (permissionName == "UPDATEOCCUBENTLETTER") canUpdateOCCUBENTLETTER = true;
                        if (permissionName == "MOVEWAITINGLIST") canMoveWaitingList = true;
                        if (permissionName == "DELETEWAITINGLIST") canDeleteWaitingList = true;
                        if (permissionName == "DELETEOCCUBENTLETTER") canDeleteOCCUBENTLETTER = true;
                        if (permissionName == "DELETEMOVEWAITINGLIST") candeleteMoveWaitingList = true;
                        if (permissionName == "DELETERESIDENTALLWAITINGLIST") canDELETERESIDENTALLWAITINGLIST = true;
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
                            ["maritalStatusName_A"] = "الحالة",
                            ["dependinceCounter"] = "التابعين",
                            ["nationalityName_A"] = "الجنسية",
                            ["genderName_A"] = "الجنس",
                            ["FullName_A"] = "الاسم بالعربي",
                            ["FullName_E"] = "الاسم بالانجليزي",
                            ["birthdate"] = "تاريخ الميلاد",
                            ["residentcontactDetails"] = "الجوال",
                            ["IdaraName"] = "موقع ملف المستفيد",
                            ["WaitingListCount"] = "عدد سجلات الانتظار",
                            ["WaitingListByLetterCount"] = "عدد خطابات التسكين",
                            ["note"] = "ملاحظات"
                        };

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
                            bool isresidentInfoID = c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase);
                            bool isFullName_E = c.ColumnName.Equals("FullName_E", StringComparison.OrdinalIgnoreCase);
                            bool isbirthdate = c.ColumnName.Equals("birthdate", StringComparison.OrdinalIgnoreCase);
                            bool isnote = c.ColumnName.Equals("note", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraID = c.ColumnName.Equals("IdaraID", StringComparison.OrdinalIgnoreCase);
                          

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                 ,
                                Visible = !(isfirstName_A || isfirstName_E || issecondName_A || issecondName_E || isthirdName_A || isthirdName_E || islastName_A || islastName_E || isrankID_FK || ismilitaryUnitID_FK || ismartialStatusID_FK || isnationalityID_FK || isgenderID_FK || isFullName_E || isbirthdate || isnote || isIdaraID|| isresidentInfoID)
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

                    if (dt2 != null && dt2.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField_dt2 = "residentRentExemptionID";
                        var possibleIdNames2 = new[] { "residentRentExemptionID", "ResidentRentExemptionID", "Id", "ID" };
                        rowIdField_dt2 = possibleIdNames2.FirstOrDefault(n => dt2.Columns.Contains(n))
                                     ?? dt2.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap2 = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["residentRentExemptionID"] = "الرقم المرجعي",
                            ["residentRentExemptionLetterNo"] = "رقم قرار الاعفاء",
                            ["residentRentExemptionLetterDate"] = "تاريخ قرار الاعفاء",
                            ["residentRentExemptionStartDate"] = "بداية الاعفاء",
                            ["residentRentExemptionEndDate"] = "نهاية الاعفاء",
                            ["residentRentExemptionDescription"] = "ملاحظات",
                            ["ResidentRentExemptionTypeName_A"] = "نوع الاعفاء",
                            ["RentExemptionStatusText"] = "حالة الاعفاء",
                            ["ResidentRentExemptionTypePercentage"] = "نسبة الاعفاء من الايجار"
                        };

                        // الأعمدة
                        foreach (DataColumn c in dt2.Columns)
                        {
                            string colType = "text";
                            var t = c.DataType;
                            if (t == typeof(bool)) colType = "bool";
                            else if (t == typeof(DateTime)) colType = "date";
                            else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                                     || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                                colType = "number";

                            bool isWaitingClassID = c.ColumnName.Equals("WaitingClassID", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingOrderTypeID = c.ColumnName.Equals("WaitingOrderTypeID", StringComparison.OrdinalIgnoreCase);
                            bool iswaitingClassSequence = c.ColumnName.Equals("waitingClassSequence", StringComparison.OrdinalIgnoreCase);
                            bool isresidentInfoID = c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase);
                            bool isActionID = c.ColumnName.Equals("ActionID", StringComparison.OrdinalIgnoreCase);
                            bool isNationalID = c.ColumnName.Equals("NationalID", StringComparison.OrdinalIgnoreCase);
                            bool isFullName_A = c.ColumnName.Equals("FullName_A", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionTypeID = c.ColumnName.Equals("LastActionTypeID", StringComparison.OrdinalIgnoreCase);



                            dynamicColumns_dt2.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap2.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                 ,
                                Visible = !(isWaitingClassID || isWaitingOrderTypeID || iswaitingClassSequence || isresidentInfoID ||  isNationalID || isFullName_A|| isLastActionTypeID)
                            });
                        }

                        // الصفوف
                        foreach (DataRow r in dt2.Rows)
                        {
                            var dict2 = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt2.Columns)
                            {
                                var val = r[c];
                                dict2[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            // p01..p05
                            object? Get(string key) => dict2.TryGetValue(key, out var v) ? v : null;
                            dict2["p01"] = Get("residentRentExemptionID") ?? Get("ResidentRentExemptionID");
                            dict2["p02"] = Get("residentRentExemptionTypeID_FK");
                            dict2["p03"] = Get("residentInfoID_FK");
                            dict2["p04"] = Get("residentRentExemptionActive");
                            dict2["p05"] = Get("residentRentExemptionStartDate");
                            dict2["p06"] = Get("residentRentExemptionEndDate");
                            dict2["p07"] = Get("residentRentExemptionDescription");
                            dict2["p08"] = Get("WaitingOrderTypeID");
                            dict2["p09"] = Get("idaraID_FK");
                            dict2["p10"] = Get("ResidentRentExemptionTypeName_A");
                            dict2["p11"] = Get("ResidentRentExemptionTypePercentage");
                            

                            rowsList_dt2.Add(dict2);
                        }
                    }

                }
            }
            catch (Exception ex)
            {
                ViewBag.BuildingTypeDataSetError = ex.Message;
            }

            var currentUrl = Request.Path + Request.QueryString;



           

            // UPDATE fields
                var updateFieldsWaitingList = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",      Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController",  Type = "hidden", Value = ControllerName},
                new FieldConfig { Name = "redirectUrl",  Type = "hidden", Value = currentUrl},
                new FieldConfig { Name = "pageName_",           Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",          Type = "hidden", Value = "UPDATEWAITINGLIST" },
                new FieldConfig { Name = "idaraID",             Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",           Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",            Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField_dt2,            Type = "hidden" },




                new FieldConfig { Name = "p01", Label = "الرقم المرجعي", Type = "hidden", ColCss = "6", Required = true,Value=residentInfoID_ },
                new FieldConfig { Name = "p02", Label = "الرقم المرجعي", Type = "hidden", ColCss = "6", Required = true,Value=residentInfoID_ },
                new FieldConfig { Name = "p03", Label = "رقم الهوية", Type = "hidden", ColCss = "6",Placeholder="1xxxxxxxxx",Value= NationalID_ },
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "hidden", ColCss = "6", Required = true,Value=generalNo_FK_ },





                new FieldConfig { Name = "p05", Label = "رقم القرار", Type = "text", ColCss = "3", MaxLength = 50, TextMode = "number",Required=true},
                new FieldConfig { Name = "p06", Label = "تاريخ القرار", Type = "date", ColCss = "3", MaxLength = 50, TextMode = "number",Required=true,Placeholder="YYYY-MM-DD"},

                new FieldConfig { Name = "p07", Label = "فئة سجل الانتظار", Type = "hidden", ColCss = "3", Required = true, Options= waitingClassOptions },
                new FieldConfig { Name = "p08", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Required = true, Options= waitingOrderTypeOptions,Select2=true },
                new FieldConfig { Name = "p09", Label = "ملاحظات", Type = "textarea", ColCss = "3", Required = false },
            };

              


           


            // DELETE fields
            var deleteFieldsWaitingList = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "redirectUrl",  Type = "hidden", Value = currentUrl},
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETEWAITINGLIST" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField_dt2, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ActionID" },
                new FieldConfig { Name = "p20", Label = "residentInfoID_", Type = "hidden", ColCss = "3",Readonly =true,Value=residentInfoID_},
                new FieldConfig { Name = "p10", Label = "الاسم", Type = "text", ColCss = "3",Readonly =true},
                new FieldConfig { Name = "p03", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "3",Placeholder="1xxxxxxxxx",Readonly =true},
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "3", Required = true,Readonly =true},

                new FieldConfig { Name = "p11", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Required = true,Readonly =true},
                new FieldConfig { Name = "p12", Label = "نوع سجل الانتظار", Type = "text", ColCss = "3", Required = true,Readonly =true},



                new FieldConfig { Name = "p05", Label = "رقم القرار", Type = "text", ColCss = "3", MaxLength = 50, TextMode = "number",Required=true ,Readonly =true},
                new FieldConfig { Name = "p06", Label = "تاريخ القرار", Type = "text", ColCss = "3", MaxLength = 50, TextMode = "number",Required=true,Placeholder="YYYY-MM-DD" ,Readonly =true},


                
                new FieldConfig { Name = "p09", Label = "ملاحظات", Type = "textarea", ColCss = "3", Required = false,Readonly =true },

            };


       


            var dsModel = new SmartTableDsModel
            {
                PageTitle = "بيانات المستفيد",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = false, // جديد

                AllowExport = true,
                ShowRowBorders = false,
                PanelTitle = "بيانات المستفيد",
                EnablePagination = false, // جديد
                ShowPageSizeSelector = false, // جديد
                ShowToolbar = residentInfoIdaraID == IdaraId,
                EnableCellCopy = false,
                //RenderAsToggle = true,
                //ToggleLabel = "بيانات المستفيد",
                //ToggleIcon = "fa-solid fa-list",
                //ToggleDefaultOpen = true,
                //ShowToggleCount = false,
                RenderMode = SmartTableRenderMode.Tab,
                RenderAsToggle = false,
                RenderAsSection = false,
                RenderAsTab = true,
                TabGroupKey = "waiting-list-by-resident",
                TabKey = "resident-info",
                TabLabel = "بيانات المستفيد",
                TabIcon = "fa-solid fa-user",
                TabDefaultActive = true,
                ShowTabCount = false,
                TabOrder = 1,

                ViewMode = TableViewMode.Table,
                Selectable = true,




                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = canInsertWaitingList && residentInfoIdaraID == IdaraId,
                    ShowEdit = canDELETERESIDENTALLWAITINGLIST && residentInfoIdaraID == IdaraId,
                    ShowEdit1 = canMoveWaitingList && residentInfoIdaraID == IdaraId,
                    ShowDelete = canDeleteWaitingList && residentInfoIdaraID == IdaraId,
                    ShowBulkDelete = false,

                
                }
            };

            var dsModel1 = new SmartTableDsModel
            {
                PageTitle = "إدارة سجلات الانتظار لمستفيد",
                Columns = dynamicColumns_dt2,
                Rows = rowsList_dt2,
                RowIdField = rowIdField_dt2,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns_dt2.Select(c => c.Field).Take(4).ToList(),
                Searchable = false, // جديد
                AllowExport = true,
                ShowRowBorders = false, 
                PanelTitle = "إدارة سجلات الانتظار لمستفيد",
                EnablePagination = false, // جديد
                ShowPageSizeSelector=false, // جديد
                //TabelLabel= "قوائم الانتظار",
                //TabelLabelIcon = "fa-solid fa-list",
                ShowToolbar = residentInfoIdaraID == IdaraId,
                EnableCellCopy = false,
                //RenderAsToggle = true,
                //ToggleLabel = "عرض قوائم الانتظار للمستفيد بإدارتك",
                //ToggleIcon = "fa-solid fa-list",
                //ToggleDefaultOpen = residentInfoIdaraID == IdaraId,
                //ShowToggleCount = true,

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsToggle = false,
                RenderAsSection = false,
                RenderAsTab = true,
                TabGroupKey = "waiting-list-by-resident",
                TabKey = "resident-waiting-lists",
                TabLabel = "قوائم الانتظار",
                TabIcon = "fa-solid fa-list",
                TabDefaultActive = false,
                ShowTabCount = true,
                TabOrder = 3,




                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = canInsertWaitingList && residentInfoIdaraID == IdaraId,
                    ShowEdit = canUpdateWaitingList && residentInfoIdaraID == IdaraId,
                    ShowEdit1 = canMoveWaitingList && residentInfoIdaraID == IdaraId,
                    ShowDelete = canDeleteWaitingList && residentInfoIdaraID == IdaraId,
                    ShowBulkDelete = false,
                    

       
                   
                    Edit = new TableAction
                    {
                        Label = "تعديل بيانات انتظار",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        //Placement = TableActionPlacement.ActionsMenu,
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل بيانات انتظار",
                        ModalMessage = "ملاحظة: جميع التعديلات مرصودة",
                        ModalMessageIcon = "fa-solid fa-circle-info",
                        ModalMessageClass = "bg-sky-100 text-sky-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "تعديل بيانات انتظار",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = updateFieldsWaitingList
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },

                 
                    

                    Delete = new TableAction
                    {
                        Label = "الغاء بيانات انتظار",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        //Placement = TableActionPlacement.ActionsMenu,
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تحذير",
                        ModalMessage = "هل أنت متأكد من الغاء بيانات الانتظار؟",
                        ModalMessageIcon = "fa fa-exclamation-triangle text-red-600",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeDeleteForm",
                            Title = "تأكيد الغاء بيانات الانتظار",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حذف", Type = "submit", Color = "danger", },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = deleteFieldsWaitingList
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                }
            };

        

      

            bool dsModelHasRows = dt1 != null && dt1.Rows.Count > 0;
            bool dsModel1HasRows = dt2 != null && dt2.Rows.Count > 0;


                ViewBag.dsModelHasRows = dsModelHasRows;
                ViewBag.dsModel1HasRows = dsModel1HasRows;

            
            //return View("HousingDefinitions/BuildingType", dsModel);

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel1.PageTitle,
                PanelTitle = dsModel1.PanelTitle,
                PanelIcon = "fa fa-list",

                Form =form,
                TableDS = dsModelHasRows ? dsModel : null,
                TableDS1 = dsModelHasRows ? dsModel1 : null,


            };

            return View("WaitingList/RentExemption", page);

        }
    }
}