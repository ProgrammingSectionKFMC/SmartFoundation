using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Text.Json;
using static System.Collections.Specialized.BitVector32;


namespace SmartFoundation.Mvc.Controllers.Housing
{
    public partial class HousingController : Controller
    {
        public async Task<IActionResult> WaitingListByResident()
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
            PageName = string.IsNullOrWhiteSpace(PageName) ? "WaitingListByResident" : PageName;

            var spParameters = new object?[]
            {
             PageName ?? "WaitingListByResident",
             IdaraId,
             usersId,
             HostName,
             NationalID_
            };

           

            var rowsList = new List<Dictionary<string, object?>>();
            var rowsList_dt2 = new List<Dictionary<string, object?>>();
            var rowsList_dt3 = new List<Dictionary<string, object?>>();
            var rowsList_dt4 = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();
            var dynamicColumns_dt2 = new List<TableColumn>();
            var dynamicColumns_dt3 = new List<TableColumn>();
            var dynamicColumns_dt4 = new List<TableColumn>();

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

            //  تقسيم الداتا سيت للجدول الأول + جداول أخرى
            SplitDataSet(ds);
            ViewBag.DsTablesCount = ds?.Tables?.Count ?? 0;
            ViewBag.Dt1Count = dt1?.Rows.Count ?? -1;
            ViewBag.Dt2Count = dt2?.Rows.Count ?? -1;
            ViewBag.Dt3Count = dt3?.Rows.Count ?? -1;
            ViewBag.Dt4Count = dt4?.Rows.Count ?? -1;

            ViewBag.Dt1Cols = dt1?.Columns.Count ?? -1;
            ViewBag.Dt2Cols = dt2?.Columns.Count ?? -1;
            ViewBag.Dt3Cols = dt3?.Columns.Count ?? -1;
            ViewBag.Dt4Cols = dt4?.Columns.Count ?? -1;

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
            string rowIdField_dt3 = "";
            string rowIdField_dt4 = "";
            bool canInsertWaitingList = false;
            bool canInsertOCCUBENTLETTER = false;
            bool canUpdateWaitingList = false;
            bool canUpdateOCCUBENTLETTER = false;
            bool canMoveWaitingList = false;
            bool canDeleteWaitingList = false;
            bool canDeleteOCCUBENTLETTER = false;
            bool candeleteMoveWaitingList = false;


            FormConfig form = new();


            List<OptionItem> waitingClassOptions = new();
            List<OptionItem> waitingOrderTypeOptions = new();
            List<OptionItem> idaraOptions = new();
           

            // ---------------------- DDLValues ----------------------




            JsonResult? result;
            string json;




            //// ---------------------- WaitingClass ----------------------
            result = await _CrudController.GetDDLValues(
                "waitingClassName_A", "waitingClassID", "5", nameof(WaitingListByResident), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            waitingClassOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;
            //// ---------------------- militaryUnitOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "waitingOrderTypeName_A", "waitingOrderTypeID", "6", nameof(WaitingListByResident), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            waitingOrderTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;
            
            //// ---------------------- idaraOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "idaraLongName_A", "idaraID", "7", nameof(WaitingListByResident), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            idaraOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


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
                                    Icon="fa-solid fa-id-card",
                                    Placeholder="1xxxxxxxxx",
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
                                    InlineButtonIcon= "fa-solid fa-search",
                                    InlineButtonCss="btn btn-success", 
                                    InlineButtonPosition="end",              // مكان الزر (end / start)
                                    InlineButtonOnClickJs="sfNav(this)",      // استدعاء الدالة العامة )
                                    // ===== بيانات التنقل (sfNav) =====
                                    NavUrl="/Housing/WaitingListByResident", // الصفحة الهدف
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
                          

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                 ,
                                Visible = !(isfirstName_A || isfirstName_E || issecondName_A || issecondName_E || isthirdName_A || isthirdName_E || islastName_A || islastName_E || isrankID_FK || ismilitaryUnitID_FK || ismartialStatusID_FK || isnationalityID_FK || isgenderID_FK || isFullName_E || isbirthdate || isnote )
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
                        rowIdField_dt2 = "ActionID";
                        var possibleIdNames2 = new[] { "ActionID", "actionID", "Id", "ID" };
                        rowIdField_dt2 = possibleIdNames2.FirstOrDefault(n => dt2.Columns.Contains(n))
                                     ?? dt2.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap2 = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["ActionID"] = "الرقم المرجعي",
                            ["NationalID"] = "رقم الهوية",
                            ["GeneralNo"] = "الرقم العام",
                            ["ActionDecisionNo"] = "رقم القرار",
                            ["ActionDecisionDate"] = "تاريخ القرار",
                            ["WaitingClassName"] = "فئة الانتظار",
                            ["WaitingOrderTypeName"] = "النوع",
                            ["ActionNote"] = "ملاحظات",
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



                            dynamicColumns_dt2.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap2.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                 ,
                                Visible = !(isWaitingClassID || isWaitingOrderTypeID || iswaitingClassSequence || isresidentInfoID || isActionID || isNationalID || isFullName_A)
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
                            dict2["p01"] = Get("ActionID") ?? Get("actionID");
                            dict2["p02"] = Get("residentInfoID");
                            dict2["p03"] = Get("NationalID");
                            dict2["p04"] = Get("GeneralNo");
                            dict2["p05"] = Get("ActionDecisionNo");
                            dict2["p06"] = Get("ActionDecisionDate");
                            dict2["p07"] = Get("WaitingClassID");
                            dict2["p08"] = Get("WaitingOrderTypeID");
                            dict2["p09"] = Get("ActionNote");
                            dict2["p10"] = Get("FullName_A");
                            dict2["p11"] = Get("WaitingClassName");
                            dict2["p12"] = Get("WaitingOrderTypeName");


                            rowsList_dt2.Add(dict2);
                        }
                    }

                    if (dt3 != null && dt3.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField_dt3 = "ActionID";
                        var possibleIdNames3 = new[] { "ActionID", "actionID", "Id", "ID" };
                        rowIdField_dt3 = possibleIdNames3.FirstOrDefault(n => dt3.Columns.Contains(n))
                                     ?? dt3.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap3 = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["ActionID"] = "الرقم المرجعي",
                            ["NationalID"] = "رقم الهوية",
                            ["GeneralNo"] = "الرقم العام",
                            ["ActionDecisionNo"] = "رقم القرار",
                            ["ActionDecisionDate"] = "تاريخ القرار",
                            ["WaitingClassName"] = "فئة الانتظار",
                            ["WaitingOrderTypeName"] = "النوع",
                            ["ActionNote"] = "ملاحظات",
                        };

                        // الأعمدة
                        foreach (DataColumn c in dt3.Columns)
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
                            bool isresidentInfoID_FK = c.ColumnName.Equals("residentInfoID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isActionID = c.ColumnName.Equals("ActionID", StringComparison.OrdinalIgnoreCase);
                            bool isNationalID = c.ColumnName.Equals("NationalID", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingClassName = c.ColumnName.Equals("WaitingClassName", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingOrderTypeName = c.ColumnName.Equals("WaitingOrderTypeName", StringComparison.OrdinalIgnoreCase);
                            bool isFullName_A = c.ColumnName.Equals("FullName_A", StringComparison.OrdinalIgnoreCase);



                            dynamicColumns_dt3.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap3.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                 ,
                                Visible = !(isWaitingClassID || isWaitingOrderTypeID || iswaitingClassSequence || isresidentInfoID_FK || isActionID || isNationalID || isWaitingClassName || isWaitingOrderTypeName || isFullName_A)
                            });
                        }

                        // الصفوف
                        foreach (DataRow r in dt3.Rows)
                        {
                            var dict3 = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt3.Columns)
                            {
                                var val = r[c];
                                dict3[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            // p01..p05
                            object? Get(string key) => dict3.TryGetValue(key, out var v) ? v : null;
                            dict3["p01"] = Get("ActionID") ?? Get("actionID");
                            dict3["p02"] = Get("residentInfoID_FK");
                            dict3["p03"] = Get("NationalID");
                            dict3["p04"] = Get("GeneralNo");
                            dict3["p05"] = Get("ActionDecisionNo");
                            dict3["p06"] = Get("ActionDecisionDate");
                            dict3["p07"] = Get("WaitingClassID");
                            dict3["p08"] = Get("WaitingOrderTypeID");
                            dict3["p09"] = Get("ActionNote");
                            dict3["p10"] = Get("FullName_A");
                            dict3["p11"] = Get("WaitingClassName");
                            dict3["p12"] = Get("WaitingOrderTypeName");

                            rowsList_dt3.Add(dict3);
                        }
                    }

                    if (dt4 != null && dt4.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField_dt4 = "ActionID";
                        var possibleIdNames4 = new[] { "ActionID", "actionID", "Id", "ID" };
                        rowIdField_dt4 = possibleIdNames4.FirstOrDefault(n => dt4.Columns.Contains(n))
                                     ?? dt4.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap4 = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["ActionID"] = "الرقم المرجعي",
                            ["NationalID"] = "رقم الهوية",
                            ["GeneralNo"] = "الرقم العام",
                            ["ActionDecisionNo"] = "رقم قرار النقل",
                            ["ActionDecisionDate"] = "تاريخ قرار النقل",
                            ["WaitingClassName"] = "فئة الانتظار",
                            ["WaitingOrderTypeName"] = "النوع",
                            ["ActionNote"] = "ملاحظات",
                            ["currentIdaraName"] = "الادارة المنقول منها",
                            ["MoveToIdaraName"] = "الادارة المراد النقل اليها",
                            ["ActionStatus"] = "حالة الطلب",
                            ["entrydate"] = "وقت وتاريخ الاجراء",
                            
                        };

                        // الأعمدة
                        foreach (DataColumn c in dt4.Columns)
                        {
                            string colType = "text";
                            var t = c.DataType;
                            if (t == typeof(bool)) colType = "bool";
                            else if (t == typeof(DateTime)) colType = "date";
                            else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                                     || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                                colType = "number";


                            bool isActionID = c.ColumnName.Equals("ActionID", StringComparison.OrdinalIgnoreCase);
                            bool isNationalID = c.ColumnName.Equals("NationalID", StringComparison.OrdinalIgnoreCase);

                            bool isWaitingClassID = c.ColumnName.Equals("WaitingClassID", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingOrderTypeID = c.ColumnName.Equals("WaitingOrderTypeID", StringComparison.OrdinalIgnoreCase);

                            bool iswaitingClassSequence = c.ColumnName.Equals("waitingClassSequence", StringComparison.OrdinalIgnoreCase);
                            
                            bool isresidentInfoID = c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase);
                           
                            bool isWaitingClassName = c.ColumnName.Equals("WaitingClassName", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingOrderTypeName = c.ColumnName.Equals("WaitingOrderTypeName", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraId_FK = c.ColumnName.Equals("IdaraId_FK", StringComparison.OrdinalIgnoreCase);
                            bool isMoveToIdaraID = c.ColumnName.Equals("MoveToIdaraID", StringComparison.OrdinalIgnoreCase);
                            bool iscurrentIdaraID = c.ColumnName.Equals("currentIdaraID", StringComparison.OrdinalIgnoreCase);
                            bool isFullName_A = c.ColumnName.Equals("FullName_A", StringComparison.OrdinalIgnoreCase);



                            dynamicColumns_dt4.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap4.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                 ,
                                Visible = !(isWaitingClassID || isWaitingOrderTypeID || iswaitingClassSequence  || isNationalID ||  isWaitingOrderTypeName || isIdaraId_FK || isMoveToIdaraID || iscurrentIdaraID || isFullName_A || isresidentInfoID)
                            });
                        }

                        // الصفوف
                        foreach (DataRow r in dt4.Rows)
                        {
                            var dict4 = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt4.Columns)
                            {
                                var val = r[c];
                                dict4[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            // p01..p05
                            object? Get(string key) => dict4.TryGetValue(key, out var v) ? v : null;
                            dict4["p01"] = Get("ActionID") ?? Get("actionID");
                            dict4["p02"] = Get("residentInfoID");
                            dict4["p03"] = Get("NationalID");
                            dict4["p04"] = Get("GeneralNo");
                            dict4["p05"] = Get("ActionDecisionNo");
                            dict4["p06"] = Get("ActionDecisionDate");
                            dict4["p07"] = Get("WaitingClassID");
                            dict4["p08"] = Get("WaitingOrderTypeID");
                            dict4["p09"] = Get("ActionNote");
                            dict4["p10"] = Get("currentIdaraID");
                            dict4["p11"] = Get("currentIdaraName");
                            dict4["p12"] = Get("MoveToIdaraID");
                            dict4["p13"] = Get("MoveToIdaraName");
                            dict4["p14"] = Get("WaitingClassName");
                            dict4["p15"] = Get("FullName_A");
                            
                                
                            rowsList_dt4.Add(dict4);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.BuildingTypeDataSetError = ex.Message;
            }

            var currentUrl = Request.Path + Request.QueryString;


            // ADD fields
            var addFieldsWaitingList = new List<FieldConfig>
            {
                new FieldConfig { Name = rowIdField_dt2, Type = "hidden" },
                new FieldConfig { Name = "p01", Label = "الرقم المرجعي", Type = "hidden", ColCss = "6", Required = true,Value=residentInfoID_ },
                new FieldConfig { Name = "p02", Label = "رقم الهوية", Type = "hidden", ColCss = "6",Placeholder="1xxxxxxxxx",Value= NationalID_ },
                new FieldConfig { Name = "p03", Label = "الرقم العام", Type = "hidden", ColCss = "6", Required = true,Value=generalNo_FK_ },
                
                


              
                new FieldConfig { Name = "p04", Label = "رقم القرار", Type = "text", ColCss = "3", MaxLength = 50, TextMode = "number",Required=true},
                new FieldConfig { Name = "p05", Label = "تاريخ القرار", Type = "date", ColCss = "3", MaxLength = 50, TextMode = "number",Required=true,Placeholder="YYYY-MM-DD"},

                new FieldConfig { Name = "p06", Label = "فئة سجل الانتظار", Type = "select", ColCss = "3", Required = true, Options= waitingClassOptions },
                new FieldConfig { Name = "p07", Label = "نوع سجل الانتظار", Type = "select", ColCss = "3", Required = true, Options= waitingOrderTypeOptions },
                new FieldConfig { Name = "p08", Label = "ملاحظات", Type = "textarea", ColCss = "6", Required = false },
                
            };

            // hidden fields
            addFieldsWaitingList.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addFieldsWaitingList.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            addFieldsWaitingList.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId.ToString() });
            addFieldsWaitingList.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId.ToString() });
            addFieldsWaitingList.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERTWAITINGLIST" });
            addFieldsWaitingList.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            addFieldsWaitingList.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addFieldsWaitingList.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });
            addFieldsWaitingList.Insert(0, new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl });


         


            // ADD fields
            var addFieldsMoveWaitingList = new List<FieldConfig>
            {
                new FieldConfig { Name = rowIdField_dt2, Type = "hidden" },
                new FieldConfig { Name = "p01", Label = "رقم اكشن السراء", Type = "hidden", ColCss = "6", Required = true},
                new FieldConfig { Name = "p02", Label = "residentInfoID", Type = "hidden", ColCss = "6",Placeholder="1xxxxxxxxx"},
                new FieldConfig { Name = "p03", Label = "NationalID", Type = "hidden", ColCss = "6",Placeholder="1xxxxxxxxx"},
                new FieldConfig { Name = "p04", Label = "GeneralNo", Type = "hidden", ColCss = "6", Required = true},

                new FieldConfig { Name = "p07", Label = "فئة سجل الانتظار", Type = "hidden", ColCss = "3", Required = true, Options= waitingClassOptions },
                new FieldConfig { Name = "p08", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Required = true, Options= waitingOrderTypeOptions },


                new FieldConfig { Name = "p05", Label = "رقم قرار النقل", Type = "text", ColCss = "3", MaxLength = 50, TextMode = "number",Required=true,Readonly = true},
                new FieldConfig { Name = "p06", Label = "تاريخ قرار النقل", Type = "text", ColCss = "3", MaxLength = 50, TextMode = "number",Required=true,Placeholder="YYYY-MM-DD",Readonly=true},

                
                new FieldConfig { Name = "p12", Label = "الادارة المراد نقل السراء اليها", Type = "select", ColCss = "6", Required = true, Options= idaraOptions },
                new FieldConfig { Name = "p13", Label = "ملاحظات", Type = "textarea", ColCss = "6", Required = false },


            };

            // hidden fields
            addFieldsMoveWaitingList.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addFieldsMoveWaitingList.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            addFieldsMoveWaitingList.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId.ToString() });
            addFieldsMoveWaitingList.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId.ToString() });
            addFieldsMoveWaitingList.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "MOVEWAITINGLIST" });
            addFieldsMoveWaitingList.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            addFieldsMoveWaitingList.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addFieldsMoveWaitingList.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });
            addFieldsMoveWaitingList.Insert(0, new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl });




            // ADD fields
            var addFieldsOccubentLetter = new List<FieldConfig>
            {
                new FieldConfig { Name = rowIdField_dt2, Type = "hidden" },
                new FieldConfig { Name = "p01", Label = "الرقم المرجعي", Type = "hidden", ColCss = "6", Required =          true,Value=residentInfoID_ },
                new FieldConfig { Name = "p02", Label = "رقم الهوية", Type = "hidden", ColCss = "6",Placeholder="1xxxxxxxxx",   Value=     NationalID_ },
                new FieldConfig { Name = "p03", Label = "الرقم العام", Type = "hidden", ColCss = "6", Required =        true,Value=generalNo_FK_ },

                new FieldConfig { Name = "p04", Label = "رقم القرار", Type = "text", ColCss = "3", MaxLength = 50, TextMode =       "number",Required=true},
                new FieldConfig { Name = "p05", Label = "تاريخ القرار", Type = "date", ColCss = "3", MaxLength = 50, TextMode =         "number",Required=true,Placeholder="YYYY-MM-DD"},

 
                new FieldConfig { Name = "p08", Label = "ملاحظات", Type = "textarea", ColCss = "6", Required = false },

            };

            // hidden fields
            addFieldsOccubentLetter.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addFieldsOccubentLetter.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            addFieldsOccubentLetter.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId.ToString() });
            addFieldsOccubentLetter.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId.ToString() });
            addFieldsOccubentLetter.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERTOCCUBENTLETTER" });
            addFieldsOccubentLetter.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            addFieldsOccubentLetter.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addFieldsOccubentLetter.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });
            addFieldsOccubentLetter.Insert(0, new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl });

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
                new FieldConfig { Name = "p08", Label = "نوع سجل الانتظار", Type = "select", ColCss = "3", Required = true, Options= waitingOrderTypeOptions },
                new FieldConfig { Name = "p09", Label = "ملاحظات", Type = "textarea", ColCss = "6", Required = false },
            };

              var updateFieldsOccubentLetter = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",      Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController",  Type = "hidden", Value = ControllerName},
                new FieldConfig { Name = "redirectUrl",  Type = "hidden", Value = currentUrl},
                new FieldConfig { Name = "pageName_",           Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",          Type = "hidden", Value = "UPDATEOCCUBENTLETTER" },
                new FieldConfig { Name = "idaraID",             Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",           Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",            Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField_dt3,            Type = "hidden" },




                new FieldConfig { Name = "p01", Label = "الرقم المرجعي", Type = "hidden", ColCss = "6", Required = true,Value=residentInfoID_ },
                new FieldConfig { Name = "p02", Label = "الرقم المرجعي", Type = "hidden", ColCss = "6", Required = true,Value=residentInfoID_ },
                new FieldConfig { Name = "p03", Label = "رقم الهوية", Type = "hidden", ColCss = "6",Placeholder="1xxxxxxxxx",Value= NationalID_ },
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "hidden", ColCss = "6", Required = true,Value=generalNo_FK_ },





                new FieldConfig { Name = "p05", Label = "رقم القرار", Type = "text", ColCss = "3", MaxLength = 50, TextMode = "number",Required=true},
                new FieldConfig { Name = "p06", Label = "تاريخ القرار", Type = "date", ColCss = "3", MaxLength = 50, TextMode = "number",Required=true,Placeholder="YYYY-MM-DD"},

                new FieldConfig { Name = "p09", Label = "ملاحظات", Type = "textarea", ColCss = "6", Required = false },
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
                new FieldConfig { Name = "p10", Label = "الاسم", Type = "text", ColCss = "3",Readonly =true},
                new FieldConfig { Name = "p03", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "3",Placeholder="1xxxxxxxxx",Readonly =true},
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "3", Required = true,Readonly =true},

                new FieldConfig { Name = "p11", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Required = true,Readonly =true},
                new FieldConfig { Name = "p12", Label = "نوع سجل الانتظار", Type = "text", ColCss = "3", Required = true,Readonly =true},



                new FieldConfig { Name = "p05", Label = "رقم القرار", Type = "text", ColCss = "3", MaxLength = 50, TextMode = "number",Required=true ,Readonly =true},
                new FieldConfig { Name = "p06", Label = "تاريخ القرار", Type = "text", ColCss = "3", MaxLength = 50, TextMode = "number",Required=true,Placeholder="YYYY-MM-DD" ,Readonly =true},


                
                new FieldConfig { Name = "p09", Label = "ملاحظات", Type = "textarea", ColCss = "3", Required = false,Readonly =true },

            };


            

            var deleteFieldsOccubentLetter = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "redirectUrl",  Type = "hidden", Value = currentUrl},
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETEOCCUBENTLETTER" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField_dt3, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ActionID" },
                 new FieldConfig { Name = "p10", Label = "الاسم", Type = "text", ColCss = "6",Readonly =true},
                new FieldConfig { Name = "p03", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "6",Placeholder="1xxxxxxxxx",Readonly =true},
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "3", Required = true,Readonly =true},
                new FieldConfig { Name = "p05", Label = "رقم القرار", Type = "text", ColCss = "3", MaxLength = 50, TextMode = "number",Required=true ,Readonly =true},
                new FieldConfig { Name = "p06", Label = "تاريخ القرار", Type = "text", ColCss = "3", MaxLength = 50, TextMode = "number",Required=true,Placeholder="YYYY-MM-DD" ,Readonly =true},



                new FieldConfig { Name = "p09", Label = "ملاحظات", Type = "textarea", ColCss = "3", Required = false,Readonly =true },
            };

            

            var deleteFieldsMoveWaitingList = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "redirectUrl",  Type = "hidden", Value = currentUrl},
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETEMOVEWAITINGLIST" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField_dt4, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ActionID" },
                new FieldConfig { Name = "p02", Type = "hidden", MirrorName = "residentInfoID" },
                new FieldConfig { Name = "p07", Type = "hidden", MirrorName = "WaitingClassID" },
                new FieldConfig { Name = "p08", Type = "hidden", MirrorName = "WaitingOrderTypeID" },
                new FieldConfig { Name = "p15", Label = "الاسم", Type = "text", ColCss = "3",Readonly =true},
                new FieldConfig { Name = "p03", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "3",Placeholder="1xxxxxxxxx",Readonly =true},
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "3", Required = true,Readonly =true},

                new FieldConfig { Name = "p14", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Required = true, Options= waitingClassOptions ,Readonly =true},
                


                new FieldConfig { Name = "p05", Label = "رقم قرار النقل", Type = "text", ColCss = "6", MaxLength = 50, TextMode = "number",Required=true ,Readonly =true},
                new FieldConfig { Name = "p06", Label = "تاريخ قرار النقل", Type = "text", ColCss = "6", MaxLength = 50, TextMode = "number",Required=true,Placeholder="YYYY-MM-DD" ,Readonly =true},


                new FieldConfig { Name = "p11", Label = "الادارة المراد نقل السراء منها", Type = "text", ColCss = "6", Required = true ,Readonly =true },
                new FieldConfig { Name = "p13", Label = "الادارة المراد سنقل السراء اليها", Type = "text", ColCss = "6", Required = true,Readonly =true },
                new FieldConfig { Name = "p09", Label = "ملاحظات", Type = "textarea", ColCss = "6", Required = false,Readonly =true },

            };

            


            var dsModel = new SmartTableDsModel
            {
                PageTitle = "المستفيدين",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100, },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = false,
                AllowExport = false,
                PanelTitle = "المستفيدين",
                ShowFooter = false,
                Selectable = false,
                TabelLabel = "بيانات المستفيد",
                TabelLabelIcon = "fa-solid fa-user",
                ShowToolbar = false,
                EnableCellCopy = true, // تفعيل نسخ الخلايا 



            };

            var dsModel1 = new SmartTableDsModel
            {
                PageTitle = "قوائم الانتظار",
                Columns = dynamicColumns_dt2,
                Rows = rowsList_dt2,
                RowIdField = rowIdField_dt2,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns_dt2.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowRowBorders = false,
                PanelTitle = "قوائم الانتظار",
                TabelLabel= "قوائم الانتظار",
                TabelLabelIcon = "fa-solid fa-list",
                ShowToolbar =true,
                EnableCellCopy = false,
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = canInsertWaitingList,
                    ShowEdit = canUpdateWaitingList,
                    ShowEdit1 = canMoveWaitingList,
                    ShowDelete = canDeleteWaitingList,
                    ShowBulkDelete = false,
                    

                    Add = new TableAction
                    {
                        Label = "إضافة سجل انتظار جديد",
                        Icon = "fa fa-plus",
                        Color = "success",
                        Placement = TableActionPlacement.ActionsMenu,
                        OpenModal = true,
                        ModalTitle = "إدخال بيانات سجل انتظار جديد",
                        //ModalMessage = "ملاحظة: جميع التعديلات مرصودة",
                        ModalMessage = "ملاحظة: جميع التعديلات مرصودة",
                        ModalMessageIcon = "fa-solid fa-circle-info",
                        ModalMessageClass = "bg-sky-100 text-sky-700",



                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeInsertForm",
                            Title = "بيانات سجل انتظار جديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addFieldsWaitingList,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },

                    

                   
                    Edit = new TableAction
                    {
                        Label = "تعديل بيانات انتظار",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        Placement = TableActionPlacement.ActionsMenu,
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

                    Edit1 = new TableAction
                    {
                        Label = "طلب نقل سجل انتظار لادارة اخرى",
                        Icon = "fa fa-paper-plane",
                        Color = "warning",
                        Placement = TableActionPlacement.ActionsMenu,
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "طلب نقل سجل انتظار لادارة اخرى",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "طلب نقل سجل انتظار لادارة اخرى",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = addFieldsMoveWaitingList
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
                        Placement = TableActionPlacement.ActionsMenu,
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

            var dsModel2 = new SmartTableDsModel
            {
                PageTitle = "خطابات التسكين",
                Columns = dynamicColumns_dt3,
                Rows = rowsList_dt3,
                RowIdField = rowIdField_dt3,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns_dt3.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = false,
                ShowRowBorders = false,
                PanelTitle = "خطابات التسكين",
                TabelLabel = "خطابات التسكين",
                TabelLabelIcon = "fa-solid fa-list",
                ShowToolbar = true,
                EnableCellCopy = false,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd2 = canInsertOCCUBENTLETTER,
                    ShowEdit2 = canUpdateOCCUBENTLETTER,
                    ShowDelete2 = canDeleteOCCUBENTLETTER,
                    ShowBulkDelete = false,





                    Add2 = new TableAction
                    {
                        Label = "إضافة خطاب تسكين جديد",
                        Icon = "fa fa-plus",
                        Color = "success",
                        Placement = TableActionPlacement.ActionsMenu,
                        OpenModal = true,
                        ModalTitle = "إدخال بيانات خطاب تسكين جديد",
                        ModalMessage = "ملاحظة: جميع التعديلات مرصودة",
                        ModalMessageIcon = "fa-solid fa-circle-info",
                        ModalMessageClass = "bg-sky-100 text-sky-700",

                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeInsertForm",
                            Title = "بيانات خطاب تسكين جديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addFieldsOccubentLetter,
                            Buttons =
                            {
                                new() { Text = "حفظ", Type = "submit", Color = "success" },
                                new() { Text = "إلغاء", Type = "button", Color = "secondary",
                                        OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },


                    Edit2 = new TableAction
                    {
                        Label = "تعديل خطاب تسكين",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        Placement = TableActionPlacement.ActionsMenu, 
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل خطاب تسكين",
                        ModalMessage = "ملاحظة: جميع التعديلات مرصودة",
                        ModalMessageIcon = "fa-solid fa-circle-info",
                        ModalMessageClass = "bg-sky-100 border border-sky-200 text-sky-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "تعديل خطاب تسكين",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = updateFieldsOccubentLetter
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },



                    Delete2 = new TableAction
                    {
                        Label = "الغاء خطاب تسكين",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        Placement = TableActionPlacement.ActionsMenu,
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تحذير",
                        ModalMessage = "هل أنت متأكد من الغاء بيانات خطاب تسكين؟",
                        ModalMessageIcon = "fa fa-exclamation-triangle text-red-600",
                        ModalMessageClass = "bg-red-50 border border-red-200 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeDeleteForm",
                            Title = "تأكيد الغاء خطاب تسكين",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حذف", Type = "submit", Color = "danger", },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = deleteFieldsOccubentLetter
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                }

            };

            var dsModel3 = new SmartTableDsModel
            {
                PageTitle = "طلبات نقل سجلات الانتظار",
                Columns = dynamicColumns_dt4,
                Rows = rowsList_dt4,
                RowIdField = rowIdField_dt4,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns_dt4.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowRowBorders = false,
                PanelTitle = "طلبات نقل سجلات الانتظار",
                TabelLabel = "طلبات نقل سجلات الانتظار",
                TabelLabelIcon = "fa-solid fa-list",
                ShowToolbar = true,
                EnableCellCopy = false,
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowDelete = candeleteMoveWaitingList,
                    ShowBulkDelete = false,


                    Delete = new TableAction
                    {
                        Label = "الغاء طلب نقل سجل انتظار",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        Placement = TableActionPlacement.ActionsMenu,
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تحذير",
                        ModalMessage = "هل أنت متأكد من الغاء طلب نقل سجل انتظار؟",
                        ModalMessageIcon = "fa fa-exclamation-triangle text-red-600",
                        ModalMessageClass = "bg-red-50 border border-red-200 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "DeleteForm",
                            Title = "تأكيد الغاء طلب نقل سجل انتظار",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "الغاء الطلب", Type = "submit", Color = "danger", },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = deleteFieldsMoveWaitingList
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                }
            };

            dsModel3.StyleRules = new List<TableStyleRule>
                {

                    new TableStyleRule
                    {
                        Target = "row",
                        Field = "ActionStatus",
                        Op = "eq",
                        Value = "مرفوض",
                        CssClass = "row-red",
                        Priority = 1

                    },
                     new TableStyleRule
                    {
                        Target = "row",
                        Field = "ActionStatus",
                        Op = "eq",
                        Value = "ملغى",
                        CssClass = "row-red",
                        Priority = 1

                    },
                      new TableStyleRule
                    {
                        Target = "row",
                        Field = "ActionStatus",
                        Op = "eq",
                        Value = "مقبول",
                        CssClass = "row-green",
                        Priority = 1
                    },

                };

            bool dsModelHasRows = dt1 != null && dt1.Rows.Count > 0;
            bool dsModel1HasRows = dt2 != null && dt2.Rows.Count > 0;
            bool dsModel2HasRows = dt3 != null && dt3.Rows.Count > 0;
            bool dsModel3HasRows = dt4 != null && dt4.Rows.Count > 0;

            
                ViewBag.dsModelHasRows = dsModelHasRows;
                ViewBag.dsModel1HasRows = dsModel1HasRows;
                ViewBag.dsModel2HasRows = dsModel2HasRows;
                ViewBag.dsModel3HasRows = dsModel3HasRows;
            
            //return View("HousingDefinitions/BuildingType", dsModel);

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel1.PageTitle,
                PanelTitle = dsModel1.PanelTitle,
                PanelIcon = "fa fa-list",
                Form =form,
                TableDS = dsModelHasRows ? dsModel : null,
                TableDS2 = dsModelHasRows ? dsModel1 : null,
                TableDS3 = dsModelHasRows ? dsModel2 : null,
                TableDS1 = dsModel3HasRows ? dsModel3 : null

            };

            return View("WaitingList/WaitingListByResident", page);

        }
    }
}
