using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using SmartFoundation.MVC.Reports;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers.IncomeSystem
{
    public partial class IncomeSystemController : Controller
    {
        public async Task<IActionResult> FinancialAuditForExtendAndEvictions(int pdf = 0)
        {
            //  قراءة السيشن والكونتكست
            if (!InitPageContext(out var redirect))
                return redirect!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }



            string? residentInfoID_ = Request.Query["U"].FirstOrDefault();

            residentInfoID_ = string.IsNullOrWhiteSpace(residentInfoID_) ? null : residentInfoID_.Trim();

            bool ready = false;

            ready = !string.IsNullOrWhiteSpace(residentInfoID_);


            ControllerName = nameof(Housing);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "FinancialAuditForExtendAndEvictions" : PageName;

            var spParameters = new object?[]
            {
             PageName ?? "FinancialAuditForExtendAndEvictions",
             IdaraId,
             usersId,
             HostName,
             residentInfoID_
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var rowsList_dt3 = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();
            var dynamicColumns_dt3 = new List<TableColumn>();

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

            //  تقسيم الداتا سيت للجدول الأول + جداول أخرى
            SplitDataSet(ds);


            decimal AllAmount = 0m;
            decimal RentAmount = 0m;
            decimal ServiceAmount = 0m;
            string residentInfoIDvalue = "";
            decimal insuranceRentAmount = 0m;
            decimal buildingRentAmount = 0m;

            decimal AllinsuranceRentAmount = 0m;


            if (dt1 != null && dt1.Rows.Count > 0)
            {
                DataRow rows = dt1.Rows[0];
                if (dt1.Columns.Contains("residentInfoID") && rows["residentInfoID"] != DBNull.Value)
                    residentInfoIDvalue = rows["residentInfoID"].ToString();
            }


            


            if (dt4 != null && dt4.Rows.Count > 0)
            {
                DataRow row = dt4.Rows[0];

                if (dt4.Columns.Contains("AllAmountresidual") && row["AllAmountresidual"] != DBNull.Value)
                    AllAmount = Convert.ToDecimal(row["AllAmountresidual"]);

                if (dt4.Columns.Contains("RentBillsAmountresidual") && row["RentBillsAmountresidual"] != DBNull.Value)
                    RentAmount = Convert.ToDecimal(row["RentBillsAmountresidual"]);

                if (dt4.Columns.Contains("ServiceBillsAmountresidual") && row["ServiceBillsAmountresidual"] != DBNull.Value)
                    ServiceAmount = Convert.ToDecimal(row["ServiceBillsAmountresidual"]);

              


                if (AllAmount > 0)
                    TempData["Foridara"] = $"متبقي على المستفيد مطالبات بقيمة {AllAmount} ⃁ قم بالتحقق منها الان";

                if (AllAmount < 0)
                    TempData["ForResident"] = $"متبقي للمستفيد مبالغ زائدة بقيمة {AllAmount} ⃁ قم بالتحقق منها الان";

                if (AllAmount == 0)
                    TempData["countZero"] = $"لايوجد مطالبات على المستفيد";
              

            }



            if (dt8 != null && dt8.Rows.Count > 0)
            {
                DataRow rowss = dt8.Rows[0];
                if (dt8.Columns.Contains("insuranceRentAmount") && rowss["insuranceRentAmount"] != DBNull.Value)
                    insuranceRentAmount = Convert.ToDecimal(rowss["insuranceRentAmount"]);
                if (dt8.Columns.Contains("buildingRentAmount") && rowss["buildingRentAmount"] != DBNull.Value)
                    buildingRentAmount = Convert.ToDecimal(rowss["buildingRentAmount"]);
            }

            AllinsuranceRentAmount = insuranceRentAmount + AllAmount;

            string msgrent = "";
            string msgservice = "";
            string colorrent = "";
            string colorservice = "";

            if (RentAmount > 0)
                msgrent = $"مبالغ الايجار المطالب بها تبلغ {RentAmount} قم بتحصيلها من المستفيد بالكامل";
            if (RentAmount > 0)
                colorrent = $"mb-4 rounded-lg border border-red-200 bg-red-50 p-4 text-red-800";

            if (RentAmount < 0)
                msgrent = $"مبالغ الايجار الزائدة تبلغ {RentAmount} قم باعادتها للمستفيد بالكامل";
            if (RentAmount < 0)
                colorrent = $"mb-4 rounded-lg border border-yellow-200 bg-yellow-50 p-4 text-yellow-800";

            if (RentAmount == 0)
                msgrent = $"لايوجد مبالغ مطالب بها المستفيد";
            if (RentAmount == 0)
                colorrent = $"mb-4 rounded-lg border border-green-200 bg-green-50 p-4 text-green-800";


            if (ServiceAmount > 0)
                msgservice = $"مبالغ فواتير الخدمات المطالب بها تبلغ {ServiceAmount} قم بتحصيلها من المستفيد بالكامل";
            if (ServiceAmount > 0)
                colorservice = $"mb-4 rounded-lg border border-red-200 bg-red-50 p-4 text-red-800";


            if (ServiceAmount < 0)
                msgservice = $"مبالغ فواتير الخدمات الزائدة تبلغ {ServiceAmount} قم باعادتها للمستفيد بالكامل";
            if (ServiceAmount < 0)
                colorservice = $"mb-4 rounded-lg border border-yellow-200 bg-yellow-50 p-4 text-yellow-800";

            if (ServiceAmount == 0)
                msgservice = $"لايوجد مبالغ مطالب بها المستفيد";
            if (ServiceAmount == 0)
                colorservice = $"mb-4 rounded-lg border border-green-200 bg-green-50 p-4 text-green-800";






            //  التحقق من الصلاحيات
            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            string rowIdField = "";
            string rowIdField_dt3 = "";
            bool canMeterReadForOccubentAndExit = false;
            bool canUpdateMeterReadForOccubentAndExit = false;
           


            List<OptionItem> ResidentDetailsOptions = new();
            List<OptionItem> RentbillPaymentTypeOptions = new();
            List<OptionItem> ServicebillPaymentTypeOptions = new();
            List<OptionItem> insuranceOptions = new();


            // ---------------------- DDLValues ----------------------

            JsonResult? result;
            string json;

          

            FormConfig form = new();

            try
            {

                //// ---------------------- ResidentDetailsOptions ----------------------
                result = await _CrudController.GetDDLValues(
                     "FullName_A", "residentInfoID", "2", PageName, usersId, IdaraId, HostName
                ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                ResidentDetailsOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


                //// ---------------------- RentbillPaymentTypeOptions ----------------------
                if (RentAmount >= 0)
                    result = await _CrudController.GetDDLValues(
                         "billPaymentTypeName_A", "billPaymentTypeID", "5", PageName, usersId, IdaraId, HostName
                    ) as JsonResult;

                if (RentAmount < 0)
                    result = await _CrudController.GetDDLValues(
                          "billPaymentTypeName_A", "billPaymentTypeID", "6", PageName, usersId, IdaraId, HostName
                     ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);

                RentbillPaymentTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                //// ---------------------- ServicebillPaymentTypeOptions ----------------------
                if (ServiceAmount >= 0)
                    result = await _CrudController.GetDDLValues(
                         "billPaymentTypeName_A", "billPaymentTypeID", "5", PageName, usersId, IdaraId, HostName
                    ) as JsonResult;

                if (ServiceAmount < 0)
                    result = await _CrudController.GetDDLValues(
                          "billPaymentTypeName_A", "billPaymentTypeID", "6", PageName, usersId, IdaraId, HostName
                     ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);

                ServicebillPaymentTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                //// ---------------------- insuranceOptions ----------------------
                
                    result = await _CrudController.GetDDLValues(
                         "billPaymentTypeName_A", "billPaymentTypeID", "7", PageName, usersId, IdaraId, HostName
                    ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);

                insuranceOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


                //// ---------------------- END DDL ----------------------


                form = new FormConfig
                {
                    Fields = new List<FieldConfig>
                                {
                                    new FieldConfig
                                    {
                                        SectionTitle = "اختيار الساكن",
                                        Name = "WaitingList",
                                        Type = "select",
                                        Select2 = true,
                                        Options = ResidentDetailsOptions,
                                        ColCss = "3",
                                        Placeholder = "اختر الساكن",
                                        Icon = "fa fa-user",
                                        Value = residentInfoID_,
                                        OnChangeJs = "sfNav(this)",
                                        NavUrl = "/IncomeSystem/FinancialAuditForExtendAndEvictions",
                                        NavKey = "U",
                                    },
                                },

                    Buttons = new List<FormButtonConfig>
                    {
                        //           new FormButtonConfig
                        //  {
                        //      Text="بحث",
                        //      Icon="fa-solid fa-search",
                        //      Type="button",
                        //      Color="success",
                        //      // Replace the OnClickJs of the "تجربة" button with this:
                        //      OnClickJs = "(function(){"
                        //+ "var hidden=document.querySelector('input[name=Users]');"
                        //+ "if(!hidden){toastr.error('لا يوجد حقل مستخدم');return;}"
                        //+ "var userId = (hidden.value||'').trim();"
                        //+ "var anchor = hidden.parentElement.querySelector('.sf-select');"
                        //+ "var userName = anchor && anchor.querySelector('.truncate') ? anchor.querySelector('.truncate').textContent.trim() : '';"
                        //+ "if(!userId){toastr.info('اختر مستخدم أولاً');return;}"
                        //+ "var url = '/ControlPanel/Permission?Q1=' + encodeURIComponent(userId);"
                        //+ "window.location.href = url;"
                        //+ "})();"
                        //  },

                    }


                };

                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // صلاحيات



                
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim();

                        if (string.IsNullOrWhiteSpace(permissionName))
                            continue;

                        if (permissionName.Equals("MeterReadForOccubentAndExit", StringComparison.OrdinalIgnoreCase))
                        {
                            canMeterReadForOccubentAndExit = true;
                        }

                        if (permissionName.Equals("UpdateMeterReadForOccubentAndExit", StringComparison.OrdinalIgnoreCase))
                        {
                            canUpdateMeterReadForOccubentAndExit = true;
                        }
                    }



                    if (dt1 != null && dt1.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField = "residentInfoID";
                        var possibleIdNames = new[] { "residentInfoID", "residentInfoID", "Id", "ID" };
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
                            ["IdaraName"] = "موقع ملف المستفيد",
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
                                Visible = !(isfirstName_A || isfirstName_E || issecondName_A || issecondName_E || isthirdName_A || isthirdName_E || islastName_A || islastName_E || isrankID_FK || ismilitaryUnitID_FK || ismartialStatusID_FK || isnationalityID_FK || isgenderID_FK || isFullName_E || isbirthdate || isnote || isIdaraID)
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


                    if (dt3 != null && dt3.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField_dt3 = "Order_";
                        var possibleIdNames3 = new[] { "Order_", "order_", "Id", "ID" };
                        rowIdField_dt3 = possibleIdNames3.FirstOrDefault(n => dt3.Columns.Contains(n))
                                     ?? dt3.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap3 = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            

                            ["TotalRentBillsAmount"] = "اجمالي مطالبات الايجار",
                            ["TotalRentBillsPaid"] = "اجمالي المسدد من الايجار",
                            ["RentBillsAmountresidual"] = "المتبقي من الايجار",
                            ["TotalServiceBillsAmount"] = "اجمالي مطالبات فواتير الخدمات",
                            ["TotalServiceBillsPaid"] = "اجمالي المسدد من فواتير الخدمات",
                            ["ServiceBillsAmountresidual"] = "المتبقي من فواتير الخدمات",
                            ["AllAmountresidual"] = "اجمالي المطالبات",
                            ["RentBillsStatus"] = "حالة مطالبات الايجار",
                            ["ServiceBillStatus"] = "حالة مطالبات فواتير الخدمات"
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


                            bool isresidentInfoID = c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase);

                            bool isOrder_ = c.ColumnName.Equals("Order_", StringComparison.OrdinalIgnoreCase);
                            bool isRentBillsStatusID = c.ColumnName.Equals("RentBillsStatusID", StringComparison.OrdinalIgnoreCase);
                            bool isServiceBillStatusID = c.ColumnName.Equals("ServiceBillStatusID", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraID = c.ColumnName.Equals("IdaraID", StringComparison.OrdinalIgnoreCase);



                            dynamicColumns_dt3.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap3.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                 ,
                                Visible = !( isresidentInfoID  || isOrder_|| isRentBillsStatusID || isServiceBillStatusID || isIdaraID)
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

                            // Helper to ensure 0 values are displayed as "0" for decimal/numeric fields
                            object? GetNumeric(string key)
                            {
                                var value = Get(key);
                                
                                if (value is decimal d) return d.ToString("0.00");
                                if (value is int i) return i.ToString();
                                return value?.ToString() ?? "0";
                            }

                            dict3["p01"] = Get("Order_");
                            dict3["p02"] = Get("residentInfoID");
                            dict3["p03"] = GetNumeric("TotalRentBillsAmount");
                            dict3["p04"] = GetNumeric("TotalRentBillsPaid");
                            dict3["p05"] = GetNumeric("RentBillsAmountresidual");
                            dict3["p06"] = Get("RentBillsStatus");
                            dict3["p07"] = GetNumeric("TotalServiceBillsAmount");
                            dict3["p08"] = GetNumeric("TotalServiceBillsPaid");
                            dict3["p09"] = GetNumeric("ServiceBillsAmountresidual");
                            dict3["p10"] = Get("ServiceBillStatus");

                            rowsList_dt3.Add(dict3);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.BuildingTypeDataSetError = ex.Message;
            }



            var currentUrl = Request.Path;


            // UPDATE fields
            var RentBillPayFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "MeterRead" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                // hidden p01 actually posted to SP


                

                new FieldConfig { Name = "p01", Label = "Order_", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p02", Label = "residentInfoID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p03", Label = "اجمالي مطالبات الايجار", Type = "text", ColCss = "3", Readonly = true }, 
                new FieldConfig { Name = "p04", Label = "اجمالي المسدد من الايجار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p05", Label = "المتبقي من الايجار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p06", Label = "حالة مطالبات الايجار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p12", Label = "وسيلة الدفع", Type = "select", ColCss = "3", Required = true, Options= RentbillPaymentTypeOptions },

                 new FieldConfig { Name = "p11", Label = "ملاحظات", Type = "text", ColCss = "6",Required = true,HelpText="يجب ان لاتتجاوز 1000 حرف*",MaxLength=1050 },

                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },


            };



            var ServiceBillPayFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "UpdateMeterRead" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                // hidden p01 actually posted to SP
                 new FieldConfig { Name = "p01", Label = "Order_", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p02", Label = "residentInfoID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p07", Label = "اجمالي مطالبات فواتير الخدمات", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "اجمالي المسدد من فواتير الخدمات", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "المتبقي من فواتير الخدمات", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "حالة مطالبات فواتير الخدمات", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p12", Label = "وسيلة الدفع", Type = "select", ColCss = "3", Required = true, Options= ServicebillPaymentTypeOptions },

                 new FieldConfig { Name = "p11", Label = "ملاحظات", Type = "text", ColCss = "6",Required = true,HelpText="يجب ان لاتتجاوز 1000 حرف*",MaxLength=1050 },

                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },


            };


            var insuranceFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "UpdateMeterRead" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                // hidden p01 actually posted to SP
                 new FieldConfig { Name = "p01", Label = "Order_", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p02", Label = "residentInfoID", Type = "hidden", ColCss = "3", Readonly = true,Value=residentInfoIDvalue },
                new FieldConfig { Name = "p30", Label = "مطالبات الايجار", Type = "text", ColCss = "3", Readonly = true,Value=RentAmount.ToString() },
                new FieldConfig { Name = "p31", Label = "مطالبات الفواتير", Type = "text", ColCss = "3", Readonly = true,Value=ServiceAmount.ToString() },
                new FieldConfig { Name = "p32", Label = "مبلغ التامين الاحترازي", Type = "text", ColCss = "3", Readonly = true,Value=insuranceRentAmount.ToString() },
                new FieldConfig { Name = "p33", Label = "مبلغ التامين المطالب به", Type = "text", ColCss = "3", Readonly = true,Value=AllinsuranceRentAmount.ToString() },
                new FieldConfig { Name = "p34", Label = "وسيلة الدفع", Type = "select", ColCss = "3", Required = true, Options= insuranceOptions },

                 new FieldConfig { Name = "p11", Label = "ملاحظات", Type = "text", ColCss = "6",Required = true,HelpText="يجب ان لاتتجاوز 1000 حرف*",MaxLength=1050 },

                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },


            };


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
                PageTitle = "قراءة عدادات التسكين والاخلاء",
                PanelTitle = "قراءة عدادات التسكين والاخلاء",
                EnableCellCopy = true,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowDelete = canUpdateMeterReadForOccubentAndExit,
                    ShowEdit = canMeterReadForOccubentAndExit,
                    ShowPrint1 = false,
                    ShowPrint = false,
                    ShowBulkDelete = false,
                    ShowExportPdf = false,



                   
                    Edit = new TableAction
                    {
                        Label = "قراءة عداد",
                        Icon = "fa fa-edit",
                        Color = "success",
                        //Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        //ModalTitle = "رسالة تحذيرية",
                        ModalTitle = "قراءة عداد",
                        ModalMessage = "تأكد من قراءة العداد بشكل صحيح لايمكن التراجع عن هذا الاجراء بعد التسكين النهائي",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OpenForm = new FormConfig
                        {
                            FormId = "employeeDeleteForm",
                            Title = "تأكيد قراءة عداد",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success", Icon = "fa fa-check" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = RentBillPayFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,


                        Guards = new TableActionGuards
                        {
                                AppliesTo = "any",
                                DisableWhenAny = new List<TableActionRule>
                            {

                                  new TableActionRule
                                {
                                    Field = "LastActionTypeID",
                                    Op = "neq",
                                    Value = "46",
                                    Message = "تم ارسال طلب قراءة العدادات مسبقا",
                                    Priority = 3
                                }

                            }
                        }
                    },


                    Delete = new TableAction
                    {
                        Label = "تعديل قراءة العداد",
                        Icon = "fa fa-edit",
                        Color = "warning",
                        //Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        //ModalTitle = "رسالة تحذيرية",
                        ModalTitle = "تعديل قراءة العداد",
                        ModalMessage = "يجب توخي الحذر عند تسجيل القراءة لعدم امكانية تعديلها بعد اسكان المستفيد بشكل نهائي",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OpenForm = new FormConfig
                        {
                            FormId = "employeeDeleteForm",
                            Title = "تأكيد تعديل قراءة العداد",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success", Icon = "fa fa-check" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = ServiceBillPayFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,


                        Guards = new TableActionGuards
                        {
                            AppliesTo = "any",
                            DisableWhenAny = new List<TableActionRule>
                        {

                                          new TableActionRule
                                        {
                                            Field = "LastActionTypeID",
                                            Op = "neq",
                                            Value = "47",
                                            Message = "لايمكن تعديل قراءة العداد ",
                                            Priority = 3
                                        }

                                    }
                        }
                    },

                   



                 

                }
            };


            var dsModel3 = new SmartTableDsModel
            {
                PageTitle = "التدقيق المالي لحالات الامهال والاخلاء",
                Columns = dynamicColumns_dt3,
                Rows = rowsList_dt3,
                RowIdField = rowIdField_dt3,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns_dt3.Select(c => c.Field).Take(4).ToList(),
                Searchable = false,
                AllowExport = false,
                ShowRowBorders = false,
                EnablePagination = false, // جديد
                ShowPageSizeSelector = false, // جديد
                PanelTitle = "التدقيق المالي لحالات الامهال والاخلاء",
                //TabelLabel = "خطابات التسكين",
                //TabelLabelIcon = "fa-solid fa-list",
                ShowToolbar = true,
                EnableCellCopy = false,
                RenderAsToggle = true,
                ToggleLabel = "التسوية المالية",
                ToggleIcon = "fa-solid fa-file-signature",
                ToggleDefaultOpen = true,
                ShowToggleCount = false,


                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = true,
                    ShowEdit2 = true,
                    ShowDelete2 = true,
                    ShowBulkDelete = false,




                    Add = new TableAction
                    {
                        Label = "التأمين الاحترازي",
                        Icon = "fa-solid fa-money-bill-1-wave",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "<i class='fa-solid fa-money-bill-1-wave text-emerald-600 text-xl mr-2'></i> تحصيل التأمين الاحترازي",
                        ModalMessage = "في حال وجود مطالبات على المستفيد لم يتم تسويتها سيتم اضافتها للتأمين الاحترازي وفي حال وجود مبالغ زائدة للمستفيد سيتم حسمها من التأمين الاحترازي",
                        ModalMessageIcon = "fa-solid fa-circle-info",
                        ModalMessageClass = "mb-4 rounded-lg border border-blue-200 bg-blue-50 p-4 text-blue-800",

                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeInsertForm",
                            Title = "التأمين الاحترازي",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = insuranceFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },


                    Edit2 = new TableAction
                    {
                        Label = "سداد / اعادة مبالغ الايجار",
                        Icon = "fa fa-home",
                        Color = "info",
                        //Placement = TableActionPlacement.ActionsMenu, 
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "سداد / اعادة مبالغ الايجار",
                        ModalMessage = msgrent,
                        ModalMessageIcon = "fa-solid fa-circle-info",
                        ModalMessageClass = colorrent,
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "سداد / اعادة مبالغ الايجار",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = RentBillPayFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },


                    Delete2 = new TableAction
                     {
                         Label = "سداد / اعادة مبالغ فواتير الخدمات",
                         Icon = "fa fa-money-bill-alt",
                         Color = "info",
                         //Placement = TableActionPlacement.ActionsMenu, 
                         IsEdit = true,
                         OpenModal = true,
                         ModalTitle = "سداد / اعادة مبالغ فواتير الخدمات",
                         ModalMessage = msgservice,
                         ModalMessageIcon = "fa-solid fa-circle-info",
                         ModalMessageClass = colorservice,
                         OpenForm = new FormConfig
                         {
                             FormId = "BuildingTypeEditForm",
                             Title = "سداد / اعادة مبالغ فواتير الخدمات",
                             Method = "post",
                             ActionUrl = "/crud/update",
                             SubmitText = "حفظ التعديلات",
                             CancelText = "إلغاء",
                             Fields = ServiceBillPayFields
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
                            Field = "RentBillsStatusID",
                            Op = "eq",
                            Value = "0",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "RentBillsStatus",
                            PillTextField = "RentBillsStatus",
                            PillCssClass = "pill pill-red",
                            PillMode = "replace"
                        },
                        new TableStyleRule
                        {
                            Target = "row",
                            Field = "RentBillsStatusID",
                            Op = "eq",
                            Value = "1",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "RentBillsStatus",
                            PillTextField = "RentBillsStatus",
                            PillCssClass = "pill pill-yellow",
                            PillMode = "replace"
                        },

                        new TableStyleRule
                        {

                            Target = "row",
                            Field = "RentBillsStatusID",
                            Op = "eq",
                            Value = "2",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "RentBillsStatus",
                            PillTextField = "RentBillsStatus",
                            PillCssClass = "pill pill-green",
                            PillMode = "replace"
                        },


                          new TableStyleRule
                        {
                            Target = "row",
                            Field = "RentBillsStatusID",
                            Op = "eq",
                            Value = "0",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "RentBillsAmountresidual",
                            PillTextField = "RentBillsAmountresidual",
                            PillCssClass = "pill pill-red",
                            PillMode = "replace"
                        },
                        new TableStyleRule
                        {
                            Target = "row",
                            Field = "RentBillsStatusID",
                            Op = "eq",
                            Value = "1",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "RentBillsAmountresidual",
                            PillTextField = "RentBillsAmountresidual",
                            PillCssClass = "pill pill-yellow",
                            PillMode = "replace"
                        },

                        new TableStyleRule
                        {

                            Target = "row",
                            Field = "RentBillsStatusID",
                            Op = "eq",
                            Value = "2",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "RentBillsStatus",
                            PillTextField = "RentBillsAmountresidual",
                            PillCssClass = "pill pill-green",
                            PillMode = "replace"
                        },








                         new TableStyleRule
                        {
                            Target = "row",
                            Field = "ServiceBillStatusID",
                            Op = "eq",
                            Value = "0",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "ServiceBillStatus",
                            PillTextField = "ServiceBillStatus",
                            PillCssClass = "pill pill-red",
                            PillMode = "replace"
                        },
                        new TableStyleRule
                        {
                            Target = "row",
                            Field = "ServiceBillStatusID",
                            Op = "eq",
                            Value = "1",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "ServiceBillStatus",
                            PillTextField = "ServiceBillStatus",
                            PillCssClass = "pill pill-yellow",
                            PillMode = "replace"
                        },

                        new TableStyleRule
                        {

                            Target = "row",
                            Field = "ServiceBillStatusID",
                            Op = "eq",
                            Value = "2",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "ServiceBillStatus",
                            PillTextField = "ServiceBillStatus",
                            PillCssClass = "pill pill-green",
                            PillMode = "replace"
                        },


                        new TableStyleRule
                        {
                            Target = "row",
                            Field = "ServiceBillStatusID",
                            Op = "eq",
                            Value = "0",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "ServiceBillsAmountresidual",
                            PillTextField = "ServiceBillsAmountresidual",
                            PillCssClass = "pill pill-red",
                            PillMode = "replace"
                        },
                        new TableStyleRule
                        {
                            Target = "row",
                            Field = "ServiceBillStatusID",
                            Op = "eq",
                            Value = "1",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "ServiceBillsAmountresidual",
                            PillTextField = "ServiceBillsAmountresidual",
                            PillCssClass = "pill pill-yellow",
                            PillMode = "replace"
                        },

                        new TableStyleRule
                        {

                            Target = "row",
                            Field = "ServiceBillStatusID",
                            Op = "eq",
                            Value = "2",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "ServiceBillsAmountresidual",
                            PillTextField = "ServiceBillsAmountresidual",
                            PillCssClass = "pill pill-green",
                            PillMode = "replace"
                        },

                    };



            bool dsModelHasRows = dt1 != null && dt1.Rows.Count > 0;

            bool dsModel3HasRows = dt3 != null && dt3.Rows.Count > 0;



            ViewBag.dsModelHasRows = dsModelHasRows;
            ViewBag.dsModel2HasRows = dsModel3HasRows;


            //return View("HousingDefinitions/BuildingType", dsModel);

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel3.PageTitle,
                PanelTitle = dsModel3.PanelTitle,
                PanelIcon = "fa fa-list",

                Form = form,
                TableDS = dsModelHasRows ? dsModel : null,
                TableDS1 = dsModel3HasRows ? dsModel3 : null

            };



            //var page = new SmartPageViewModel
            //{
            //   PageTitle = dsModel.PageTitle,
            //   PanelTitle = dsModel.PanelTitle,
            //   PanelIcon = "fa-bolt",
            //   Form = form,
            //   TableDS = ready ? dsModel : null
            //};


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
            return View("FinancialAudit/FinancialAuditForExtendAndEvictions", page);
        }
    }
}