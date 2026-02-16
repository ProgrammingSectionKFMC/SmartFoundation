using Microsoft.AspNetCore.Mvc;
using SmartFoundation.MVC.Reports;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartPrint;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers.ElectronicBillSystem
{
    public partial class ElectronicBillSystemController : Controller
    {
        public async Task<IActionResult> Meters(int pdf = 0)
        {
            //  قراءة السيشن والكونتكست
            if (!InitPageContext(out var redirect))
                return redirect!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }

            ControllerName = nameof(ElectronicBillSystem);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "Meters" : PageName;

            var spParameters = new object?[]
            {
             PageName ?? "Meters",
             IdaraId,
             usersId,
             HostName
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var rowsmeterTypeList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();
            var dynamicmeterTypeColumns = new List<TableColumn>();

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
            string rowIdmeterTypeField = "";
            bool canINSERTNEWMETER = false;
            bool canINSERTNEWMETERTYPE = false;
            bool canUPDATENEWMETERTYPE = false;
            bool canDELETENEWMETERTYPE = false;



            // ---------------------- DDLValues ----------------------


            List<OptionItem> meterTypeOptions = new();
            List<OptionItem> MeterServiceTypeOptions = new();

            JsonResult? result;
                string json;




                 //// ---------------------- meterTypeOptions ----------------------
                 result = await _CrudController.GetDDLValues(
                    "meterTypeName_A", "meterTypeID", "2", nameof(Meters), usersId, IdaraId, HostName
               ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                meterTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            //// ---------------------- meterTypeOptions ----------------------
            result = await _CrudController.GetDDLValues(
                    "meterServiceTypeName_A", "meterServiceTypeID", "3", nameof(Meters), usersId, IdaraId, HostName
               ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                meterTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


                // ----------------------END DDLValues ----------------------


                try
                {
                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // صلاحيات
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "INSERTNEWMETER") canINSERTNEWMETER = true;
                        if (permissionName == "INSERTNEWMETERTYPE") canINSERTNEWMETERTYPE = true;
                        if (permissionName == "UPDATENEWMETERTYPE") canUPDATENEWMETERTYPE = true;
                        if (permissionName == "DELETENEWMETERTYPE") canDELETENEWMETERTYPE = true;
                    }

                    if (dt1 != null && dt1.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField = "meterID";
                        var possibleIdNames = new[] { "meterID", "MeterID", "Id", "ID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["meterID"] = "رقم التسلسلي",
                            ["meterTypeID_FK"] = "نوع العداد",
                            ["meterNo"] = "رقم العداد",
                            ["meterName_A"] = "اسم العداد (عربي)",
                            ["meterName_E"] = "اسم العداد (إنجليزي)",
                            ["meterDescription"] = "الوصف",
                            ["meterStartDate"] = "تاريخ البدء",
                            ["meterEndDate"] = "تاريخ الانتهاء",
                            ["IdaraId_FK"] = "الإدارة"
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

                            // Hide foreign key columns
                            bool isMeterTypeFK = c.ColumnName.Equals("meterTypeID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraFK = c.ColumnName.Equals("IdaraId_FK", StringComparison.OrdinalIgnoreCase);
                            
                            // Add filter for meter type if needed
                         

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,
                                Visible = !(isMeterTypeFK || isIdaraFK),  // Hide FK columns only
                              
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
                            dict["p01"] = Get("meterID") ?? Get("meterID");
                            dict["p02"] = Get("meterTypeID_FK");
                            dict["p03"] = Get("meterNo");
                            dict["p04"] = Get("meterName_A");
                            dict["p05"] = Get("meterName_E");
                            dict["p06"] = Get("meterDescription");
                            dict["p07"] = Get("meterStartDate");
                            dict["p08"] = Get("meterEndDate");
                            dict["p09"] = Get("meterServiceTypeID");
                            dict["p10"] = Get("meterTypeName_A ");
                            dict["p11"] = Get("meterTypeName_E");
                            dict["p12"] = Get("meterTypeDescription");
                            dict["p13"] = Get("meterTypeConversionFactor");
                            dict["p14"] = Get("meterMaxRead");
                            dict["p15"] = Get("meterTypeStartDate");
                            dict["p16"] = Get("meterTypeEndDate");
                            dict["p17"] = Get("meterServicePrice");
                            dict["p18"] = Get("MeterNote");
                           

                            rowsList.Add(dict);
                        }
                    }



                    if (dt2 != null && dt2.Columns.Count > 0)
                    {
                        // RowId
                        rowIdmeterTypeField = "meterTypeID";
                        var possiblemeterTypeIdNames = new[] { "meterTypeID", "MeterTypeID", "Id", "ID" };
                        rowIdmeterTypeField = possiblemeterTypeIdNames.FirstOrDefault(n => dt2.Columns.Contains(n))
                                     ?? dt2.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMapmeterType = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["meterID"] = "رقم التسلسلي",
                            ["meterTypeID_FK"] = "نوع العداد",
                            ["meterNo"] = "رقم العداد",
                            ["meterName_A"] = "اسم العداد (عربي)",
                            ["meterName_E"] = "اسم العداد (إنجليزي)",
                            ["meterDescription"] = "الوصف",
                            ["meterStartDate"] = "تاريخ البدء",
                            ["meterEndDate"] = "تاريخ الانتهاء",
                            ["IdaraId_FK"] = "الإدارة"
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

                            // Hide foreign key columns
                            bool isMeterTypeFK = c.ColumnName.Equals("meterTypeID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraFK = c.ColumnName.Equals("IdaraId_FK", StringComparison.OrdinalIgnoreCase);

                            // Add filter for meter type if needed


                            dynamicmeterTypeColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMapmeterType.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,
                                Visible = !(isMeterTypeFK || isIdaraFK),  // Hide FK columns only

                            });
                        }





                        // الصفوف
                        foreach (DataRow r in dt2.Rows)
                        {
                            var dictmeterType = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt2.Columns)
                            {
                                var val = r[c];
                                dictmeterType[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            // p01..p05
                            object? Get(string key) => dictmeterType.TryGetValue(key, out var v) ? v : null;
                            dictmeterType["p01"] = Get("meterTypeID") ?? Get("meterTypeID");
                            dictmeterType["p02"] = Get("meterServiceTypeID_FK");
                            dictmeterType["p03"] = Get("meterTypeName_A");
                            dictmeterType["p04"] = Get("meterTypeName_E");
                            dictmeterType["p05"] = Get("meterTypeDescription");
                            dictmeterType["p06"] = Get("meterTypeConversionFactor");
                            dictmeterType["p07"] = Get("meterMaxRead");
                            dictmeterType["p08"] = Get("meterTypeStartDate");
                            dictmeterType["p09"] = Get("meterTypeEndDate");
                            dictmeterType["p10"] = Get("meterTypeActive ");
                            dictmeterType["p11"] = Get("IdaraId_FK");
                            dictmeterType["p12"] = Get("entryDate");
                            dictmeterType["p13"] = Get("entryData");
                            dictmeterType["p14"] = Get("hostName");
                            dictmeterType["p15"] = Get("meterServicePrice");



                            rowsmeterTypeList.Add(dictmeterType);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.BuildingTypeDataSetError = ex.Message;
            }




            // Form for adding a NEW METER TYPE (not a meter!)
            var addNewMeterTypeFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "meterTypeID", Type = "hidden" },  // PK, auto-generated

                new FieldConfig 
                { 
                    Name = "p09", 
                    Label = "نوع خدمة العداد", 
                    Type = "select", 
                    ColCss = "6", 
                    Required = true, 
                    Options = meterTypeOptions,  // Load from MeterServiceType table if exists
                    
                    Icon = "fa-solid fa-server",
                    HelpText = "اختر نوع خدمة العداد (كهرباء، ماء، إلخ)"
                },
                
                new FieldConfig 
                { 
                    Name = "p10", 
                    Label = "اسم نوع العداد (عربي)", 
                    Type = "text", 
                    ColCss = "3", 
                    Required = true,
                    TextMode = "arabic",
                    Icon = "fa-solid fa-tag",
                    MaxLength = 100,
                    Placeholder = "مثال: عداد كهرباء رقمي"
                },
                
                new FieldConfig 
                { 
                    Name = "p11", 
                    Label = "اسم نوع العداد (إنجليزي)", 
                    Type = "text", 
                    ColCss = "3",
                    TextMode = "english",
                    Icon = "fa-solid fa-tag",
                    MaxLength = 100,
                    Placeholder = "Example: Digital Electric Meter"
                },
                
               
                
                new FieldConfig 
                { 
                    Name = "p13", 
                    Label = "معامل التحويل", 
                    Type = "number", 
                    ColCss = "4",
                    Required = true,
                    Icon = "fa-solid fa-calculator",
                    HelpText = "معامل تحويل القراءة إلى وحدة القياس الفعلية",
                    Value = "1"
                },
                
                new FieldConfig 
                { 
                    Name = "p14", 
                    Label = "الحد الأقصى للقراءة", 
                    Type = "number", 
                    ColCss = "4",
                    Icon = "fa-solid fa-gauge-high",
                    HelpText = "أقصى قراءة ممكنة للعداد"
                },
                
                new FieldConfig 
                { 
                    Name = "p15", 
                    Label = "تاريخ البدء", 
                    Type = "date", 
                    ColCss = "4",
                    Required = true,
                    Icon = "fa fa-calendar"
                },
                
                new FieldConfig 
                { 
                    Name = "p16", 
                    Label = "تاريخ الانتهاء", 
                    Type = "hidden", 
                    ColCss = "4",
                    Icon = "fa fa-calendar",
                    HelpText = "اتركه فارغاً إذا كان نشطاً"
                },


                   new FieldConfig
                {
                    Name = "p17",
                    Label = "سعر الخدمة للعداد",
                    Type = "number",
                    ColCss = "4",
                    Icon = "fa-solid fa-money-bill-1-wave"
                },

                 new FieldConfig
                {
                    Name = "p18",
                    Label = "الوصف",
                    Type = "textarea",
                    ColCss = "6",
                    MaxLength = 500,
                    Required = true,
                    Placeholder = "وصف تفصيلي لنوع العداد"
                },
                   new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
               new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value },
               new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId.ToString() },
               new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId.ToString() },
               new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERTNEWMETERTYPE" },
               new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
               new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
               new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },

            };


            var updateNewMeterTypeFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Type = "hidden" },  // PK, auto-generated

                new FieldConfig
                {
                    Name = "p02",
                    Label = "نوع خدمة العداد",
                    Type = "select",
                    ColCss = "6",
                    Required = true,
                    Options = meterTypeOptions,  // Load from MeterServiceType table if exists
                    
                    Icon = "fa-solid fa-server",
                    HelpText = "اختر نوع خدمة العداد (كهرباء، ماء، إلخ)"
                },

                new FieldConfig
                {
                    Name = "p03",
                    Label = "اسم نوع العداد (عربي)",
                    Type = "text",
                    ColCss = "3",
                    Required = true,
                    TextMode = "arabic",
                    Icon = "fa-solid fa-tag",
                    MaxLength = 100,
                    Placeholder = "مثال: عداد كهرباء رقمي"
                },

                new FieldConfig
                {
                    Name = "p04",
                    Label = "اسم نوع العداد (إنجليزي)",
                    Type = "text",
                    ColCss = "3",
                    TextMode = "english",
                    Icon = "fa-solid fa-tag",
                    MaxLength = 100,
                    Placeholder = "Example: Digital Electric Meter"
                },



                new FieldConfig
                {
                    Name = "p06",
                    Label = "معامل التحويل",
                    Type = "number",
                    ColCss = "4",
                    Required = true,
                    Icon = "fa-solid fa-calculator",
                    HelpText = "معامل تحويل القراءة إلى وحدة القياس الفعلية",
                    Value = "1"
                },

                new FieldConfig
                {
                    Name = "p07",
                    Label = "الحد الأقصى للقراءة",
                    Type = "number",
                    ColCss = "4",
                    Icon = "fa-solid fa-gauge-high",
                    HelpText = "أقصى قراءة ممكنة للعداد"
                },

                new FieldConfig
                {
                    Name = "p08",
                    Label = "تاريخ البدء",
                    Type = "date",
                    ColCss = "4",
                    Required = true,
                    Icon = "fa fa-calendar"
                },

                new FieldConfig
                {
                    Name = "p09",
                    Label = "تاريخ الانتهاء",
                    Type = "hidden",
                    ColCss = "4",
                    Icon = "fa fa-calendar",
                    HelpText = "اتركه فارغاً إذا كان نشطاً"
                },


                   new FieldConfig
                {
                    Name = "p15",
                    Label = "سعر الخدمة للعداد",
                    Type = "number",
                    ColCss = "4",
                    Icon = "fa-solid fa-money-bill-1-wave"
                },

                 new FieldConfig
                {
                    Name = "p18",
                    Label = "الوصف",
                    Type = "textarea",
                    Required = true,
                    ColCss = "6",
                    MaxLength = 500,
                    Placeholder = "سبب التعديل لنوع العداد"
                },
                  

               new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
               new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value },
               new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId.ToString() },
               new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId.ToString() },
               new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATENEWMETERTYPE" },
               new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
               new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
               new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },

        };


            var deleteNewMeterTypeFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Type = "hidden" },  // PK, auto-generated

                new FieldConfig
                {
                    Name = "p03",
                    Label = "نوع خدمة العداد",
                    Type = "text",
                    ColCss = "6",
                    Required = true,
                    Options = meterTypeOptions,  // Load from MeterServiceType table if exists
                    Readonly = true,
                    Icon = "fa-solid fa-server",
                    HelpText = "اختر نوع خدمة العداد (كهرباء، ماء، إلخ)"
                },

                new FieldConfig
                {
                    Name = "p03",
                    Label = "اسم نوع العداد (عربي)",
                    Type = "text",
                    ColCss = "3",
                    Required = true,
                    Readonly = true,
                    TextMode = "arabic",
                    Icon = "fa-solid fa-tag",
                    MaxLength = 100,
                    Placeholder = "مثال: عداد كهرباء رقمي"
                },

                new FieldConfig
                {
                    Name = "p04",
                    Label = "اسم نوع العداد (إنجليزي)",
                    Type = "text",
                    ColCss = "3",
                    Readonly = true,
                    TextMode = "english",
                    Icon = "fa-solid fa-tag",
                    MaxLength = 100,
                    Placeholder = "Example: Digital Electric Meter"
                },



                new FieldConfig
                {
                    Name = "p06",
                    Label = "معامل التحويل",
                    Type = "number",
                    ColCss = "4",
                    Readonly = true,
                    Required = true,
                    Icon = "fa-solid fa-calculator",
                    HelpText = "معامل تحويل القراءة إلى وحدة القياس الفعلية",
                    Value = "1"
                },

                new FieldConfig
                {
                    Name = "p07",
                    Label = "الحد الأقصى للقراءة",
                    Type = "number",
                    ColCss = "4",
                    Readonly = true,
                    Icon = "fa-solid fa-gauge-high",
                    HelpText = "أقصى قراءة ممكنة للعداد"
                },

                new FieldConfig
                {
                    Name = "p08",
                    Label = "تاريخ البدء",
                    Type = "date",
                    ColCss = "4",
                    Readonly = true,
                    Required = true,
                    Icon = "fa fa-calendar"
                },

                new FieldConfig
                {
                    Name = "p09",
                    Label = "تاريخ الانتهاء",
                    Type = "hidden",
                    ColCss = "4",
                    Readonly = true,
                    Icon = "fa fa-calendar",
                    HelpText = "اتركه فارغاً إذا كان نشطاً"
                },


                   new FieldConfig
                {
                    Name = "p15",
                    Label = "سعر الخدمة للعداد",
                    Type = "number",
                    ColCss = "4",
                    Readonly = true,
                    Icon = "fa-solid fa-money-bill-1-wave"
                },

                 new FieldConfig
                {
                    Name = "p18",
                    Label = "سبب الحذف",
                    Type = "textarea",
                    ColCss = "6",
                    MaxLength = 500,
                    Required = true,
                    Placeholder = "سبب الحذف لنوع العداد"
                },


               new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
               new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value },
               new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId.ToString() },
               new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId.ToString() },
               new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATENEWMETERTYPE" },
               new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
               new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
               new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },

        };


            var addNewMeterFields = new List<FieldConfig>
            {
                new FieldConfig { Name = rowIdField, Type = "hidden" },

                new FieldConfig
                {
                    Name = "p02",
                    Label = "نوع العداد",
                    Type = "select",
                    ColCss = "6",
                    Required = true,
                    Options = meterTypeOptions,  // Load from meterType table (dt2)
                    Select2 = true,
                    Icon = "fa-solid fa-gauge"
                },

                new FieldConfig
                {
                    Name = "p03",
                    Label = "رقم العداد",
                    Type = "text",
                    ColCss = "6",
                    Required = true,
                    Icon = "fa-solid fa-hashtag",
                    MaxLength = 50
                },

                new FieldConfig
                {
                    Name = "p04",
                    Label = "اسم العداد (عربي)",
                    Type = "text",
                    ColCss = "6",
                    Required = true,
                    TextMode = "arabic",
                    Icon = "fa-solid fa-gauge-simple-high",
                    MaxLength = 100
                },

                new FieldConfig
                {
                    Name = "p05",
                    Label = "اسم العداد (إنجليزي)",
                    Type = "text",
                    ColCss = "6",
                    TextMode = "english",
                    Icon = "fa-solid fa-gauge-simple-high",
                    MaxLength = 100
                },

                new FieldConfig
                {
                    Name = "p06",
                    Label = "الوصف",
                    Type = "textarea",
                    ColCss = "12",
                    MaxLength = 500
                },

                new FieldConfig
                {
                    Name = "p07",
                    Label = "تاريخ البدء",
                    Type = "date",
                    ColCss = "6",
                    Required = true,
                    Icon = "fa fa-calendar"
                },

                new FieldConfig
                {
                    Name = "p08",
                    Label = "تاريخ الانتهاء",
                    Type = "date",
                    ColCss = "6",
                    Icon = "fa fa-calendar"
                },

                new FieldConfig
                {
                    Name = "p09",
                    Label = "الإدارة",
                    Type = "hidden",  // Auto-filled from session
                    Value = IdaraId
                },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
               new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value },
               new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId.ToString() },
               new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId.ToString() },
               new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERTNEWMETER" },
               new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
               new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
               new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
            };




            // UPDATE fields


            var dsModel = new SmartTableDsModel
            {
                PageTitle = "إدارة العدادات",  // Changed from "المستفيدين"
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = "إدارة العدادات",  // Changed
                //TabelLabel = "بيانات المستفيدين",
                //TabelLabelIcon = "fa-solid fa-user-group",
                EnableCellCopy = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                ShowColumnVisibility=true,
                RenderAsToggle = true,
                ToggleLabel = "ادارة العدادات",
                ToggleIcon = "fa-solid fa-bolt",
                ToggleDefaultOpen = true,
                ShowToggleCount = true,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowExportPdf = false,
                    ShowAdd = canINSERTNEWMETER,  // This will now show "Add Meter Type"
                    ShowEdit = canINSERTNEWMETER,
                    ShowDelete = canINSERTNEWMETER,
                    ShowPrint1 = false,
                    ShowBulkDelete = false,

                    CustomActions = new List<TableAction>
                    {
                        new TableAction
                        {
                            Label = "عرض التفاصيل",
                            ModalTitle = "<i class='fa-solid fa-circle-info text-emerald-600 text-xl mr-2'></i> تفاصيل العداد",
                            Icon = "fa-regular fa-file",
                            OpenModal = true,
                            RequireSelection = true,
                            MinSelection = 1,
                            MaxSelection = 1,
                        },
               
                    },

                    // ✅ CHANGED: This is now for adding METER TYPE (not meter)
                  


                    Add = new TableAction
                    {
                        Label = "إضافة عداد جديد",
                        Icon = "fa fa-plus-circle",
                        Color = "success",
                        OpenModal = true,
                        RequireSelection = false,  // Don't require selection for adding
                        ModalTitle = "<i class='fa-solid fa-gauge-high text-emerald-600 text-xl mr-2'></i> إضافة عداد جديد",

                        OpenForm = new FormConfig
                        {
                            FormId = "AddNewMeterForm",
                            Title = "بيانات عداد جديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addNewMeterFields,  // ✅ Use addNewMeterFields here
                            Buttons = new List<FormButtonConfig>
                                {
                                    new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                    new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                                }
                        }
                    },


                    Edit = new TableAction
                    {
                        Label = "تعديل بيانات عداد",  // ✅ Changed
                        Icon = "fa-solid fa-pen",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa-solid fa-pen-to-square text-emerald-600 text-xl mr-2'></i> تعديل بيانات عداد",  // ✅ Changed
                        OpenForm = new FormConfig
                        {
                            FormId = "MeterEditForm",  // ✅ Changed
                            Title = "تعديل بيانات عداد",  // ✅ Changed
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = addNewMeterFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },


                    Delete = new TableAction
                    {
                        Label = "حذف عداد",  // ✅ Changed
                        Icon = "fa-regular fa-trash-can",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من حذف بيانات العداد؟",  // ✅ Changed
                        ModalMessageClass = "bg-red-100 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "MeterDeleteForm",  // ✅ Changed
                            Title = "تأكيد حذف بيانات العداد",  // ✅ Changed
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حذف", Type = "submit", Color = "danger", },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = addNewMeterFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                }
            };



            var dsModelmeterType = new SmartTableDsModel
            {
                PageTitle = "أنواع العدادات",  // Changed from "المستفيدين"
                Columns = dynamicmeterTypeColumns,
                Rows = rowsmeterTypeList,
                RowIdField = rowIdmeterTypeField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200 },
                QuickSearchFields = dynamicmeterTypeColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = "إدارة العدادات",  // Changed
                //TabelLabel = "بيانات المستفيدين",
                //TabelLabelIcon = "fa-solid fa-user-group",
                EnableCellCopy = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                ShowColumnVisibility = true,
                RenderAsToggle = true,
                ToggleLabel = "أنواع العدادات",
                ToggleIcon = "fa-solid fa-toggle-on",
                ToggleDefaultOpen = true,
                ShowToggleCount = true,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowExportPdf = false,
                    ShowAdd = canINSERTNEWMETERTYPE,  // This will now show "Add Meter Type"
                    ShowEdit = canINSERTNEWMETERTYPE,
                    ShowDelete = canDELETENEWMETERTYPE,
                    ShowPrint1 = false,
                    ShowBulkDelete = false,

                    CustomActions = new List<TableAction>
                    {
                        new TableAction
                        {
                            Label = "عرض التفاصيل",
                            ModalTitle = "<i class='fa-solid fa-circle-info text-emerald-600 text-xl mr-2'></i> تفاصيل العداد",
                            Icon = "fa-regular fa-file",
                            OpenModal = true,
                            RequireSelection = true,
                            MinSelection = 1,
                            MaxSelection = 1,
                        },

                    },

                    // ✅ CHANGED: This is now for adding METER TYPE (not meter)


                    Add = new TableAction
                    {
                        Label = "إضافة نوع عداد جديد",  // ✅ Changed label
                        Icon = "fa fa-plus",  // ✅ Changed icon
                        Color = "success",  // ✅ Changed color to differentiate
                        OpenModal = true,
                        ModalTitle = "<i class='fa-solid fa-sitemap text-blue-600 text-xl mr-2'></i> إضافة نوع عداد جديد",

                        OpenForm = new FormConfig
                        {
                            FormId = "MeterTypeInsertForm",
                            Title = "بيانات نوع عداد جديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addNewMeterTypeFields,  // ✅ Now uses MeterType fields
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "primary" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },

                    Edit = new TableAction
                    {
                        Label = "تعديل بيانات نوع عداد",  // ✅ Changed
                        Icon = "fa-solid fa-pen",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa-solid fa-pen-to-square text-emerald-600 text-xl mr-2'></i> تعديل بيانات عداد",  // ✅ Changed
                        OpenForm = new FormConfig
                        {
                            FormId = "MeterEditForm",  // ✅ Changed
                            Title = "تعديل بيانات عداد",  // ✅ Changed
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = updateNewMeterTypeFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },


                    Delete = new TableAction
                    {
                        Label = "حذف نوع عداد",  // ✅ Changed
                        Icon = "fa-regular fa-trash-can",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من حذف بيانات نوع العداد؟",  // ✅ Changed
                        ModalMessageClass = "bg-red-100 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "MeterDeleteForm",  // ✅ Changed
                            Title = "تأكيد حذف بيانات العداد",  // ✅ Changed
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حذف", Type = "submit", Color = "danger", },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = deleteNewMeterTypeFields
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
                PanelIcon = "fa-solid fa-gauge-high",  // ✅ Changed from "fa-solid fa-user-group"
                TableDS = dsModel,
                TableDS1 = dsModelmeterType
            };


          

            return View("Meter/Meters", page);
        }
    }
}