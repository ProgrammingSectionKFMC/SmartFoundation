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
            bool readyToSend = false;

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
            var rowsList_dt10 = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();
            var dynamicColumns_dt3 = new List<TableColumn>();
            var dynamicColumns_dt10 = new List<TableColumn>();

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

            //  تقسيم الداتا سيت للجدول الأول + جداول أخرى
            SplitDataSet(ds);

           

           



            decimal AllAmount = 0m;
            decimal RentAmount = 0m;
            decimal RentRemaining = 0m;
            decimal ElectrictyAmount = 0m;
            decimal ElectrictyRemaining = 0m;
            decimal WatarAmount = 0m;
            decimal WatarRemaining = 0m;
            decimal GasAmount = 0m;
            decimal GasRemaining = 0m;
            decimal PeneltyAmount = 0m;
            decimal PeneltyRemaining = 0m;
            decimal AllRemaining = 0m;


            string residentInfoIDvalue = "";
            string buildingDetailsIDvalue = "";
            string buildingDetailsNovalue = "";
            string LastActionIDvalue = "";
            string ActionIDvalue = "";
            string LastActionTypeIDvalue = "";
            string LastActionDatevalue = "";
            string LastActionExtendReasonTypeIDvalue = "";


            decimal insuranceRentAmount = 0m;
            decimal buildingRentAmount = 0m;

            decimal AllinsuranceRentAmount = 0m;


            decimal readyToSendAmount = 0m;


            if (dt1 != null && dt1.Rows.Count > 0)
            {
                DataRow rows = dt1.Rows[0];
                if (dt1.Columns.Contains("residentInfoID") && rows["residentInfoID"] != DBNull.Value)
                    residentInfoIDvalue = rows["residentInfoID"].ToString();

                if (dt1.Columns.Contains("buildingDetailsID") && rows["buildingDetailsID"] != DBNull.Value)
                    buildingDetailsIDvalue = rows["buildingDetailsID"].ToString();

                if (dt1.Columns.Contains("buildingDetailsNo") && rows["buildingDetailsNo"] != DBNull.Value)
                    buildingDetailsNovalue = rows["buildingDetailsNo"].ToString();

                if (dt1.Columns.Contains("LastActionID") && rows["LastActionID"] != DBNull.Value)
                    LastActionIDvalue = rows["LastActionID"].ToString();

                if (dt1.Columns.Contains("ActionID") && rows["ActionID"] != DBNull.Value)
                    ActionIDvalue = rows["ActionID"].ToString();

                if (dt1.Columns.Contains("LastActionTypeID") && rows["LastActionTypeID"] != DBNull.Value)
                    LastActionTypeIDvalue = rows["LastActionTypeID"].ToString();


                if (dt1.Columns.Contains("LastActionDate") && rows["LastActionDate"] != DBNull.Value)
                    LastActionDatevalue = rows["LastActionDate"].ToString();

                if (dt1.Columns.Contains("LastActionExtendReasonTypeID") && rows["LastActionExtendReasonTypeID"] != DBNull.Value)
                    LastActionExtendReasonTypeIDvalue = rows["LastActionExtendReasonTypeID"].ToString();



            }


            


            if (dt4 != null && dt4.Rows.Count > 0)
            {
                DataRow row = dt4.Rows[0];

                if (dt4.Columns.Contains("AllRemaining") && row["AllRemaining"] != DBNull.Value)
                    AllRemaining = Convert.ToDecimal(row["AllRemaining"]);

                if (dt4.Columns.Contains("RentRemaining") && row["RentRemaining"] != DBNull.Value)
                    RentRemaining = Convert.ToDecimal(row["RentRemaining"]);

                if (dt4.Columns.Contains("WatarRemaining") && row["WatarRemaining"] != DBNull.Value)
                    WatarRemaining = Convert.ToDecimal(row["WatarRemaining"]);

              
                if (dt4.Columns.Contains("GasRemaining") && row["GasRemaining"] != DBNull.Value)
                    GasRemaining = Convert.ToDecimal(row["GasRemaining"]);

              
                if (dt4.Columns.Contains("PeneltyRemaining") && row["PeneltyRemaining"] != DBNull.Value)
                    PeneltyRemaining = Convert.ToDecimal(row["PeneltyRemaining"]);

              


                //if (AllAmount > 0)
                //    TempData["Foridara"] = $"متبقي على المستفيد مطالبات بقيمة {AllAmount} ⃁ قم بالتحقق منها الان";

                //if (AllAmount < 0)
                //    TempData["ForResident"] = $"متبقي للمستفيد مبالغ زائدة بقيمة {AllAmount} ⃁ قم بالتحقق منها الان";

                //if (AllAmount == 0)
                //    TempData["countZero"] = $"لايوجد مطالبات على المستفيد";
              

            }



            if (dt8 != null && dt8.Rows.Count > 0)
            {
                DataRow rowss = dt8.Rows[0];
                if (dt8.Columns.Contains("insuranceRentAmount") && rowss["insuranceRentAmount"] != DBNull.Value)
                    insuranceRentAmount = Convert.ToDecimal(rowss["insuranceRentAmount"]);
                if (dt8.Columns.Contains("buildingRentAmount") && rowss["buildingRentAmount"] != DBNull.Value)
                    buildingRentAmount = Convert.ToDecimal(rowss["buildingRentAmount"]);
            }


            if (dt10 != null && dt10.Rows.Count > 0)
            {
                DataRow rowsss = dt10.Rows[0];
                if (dt10.Columns.Contains("BillsStatusID") && rowsss["BillsStatusID"] != DBNull.Value)
                    readyToSendAmount = Convert.ToDecimal(rowsss["BillsStatusID"]);
            }


            if(LastActionTypeIDvalue == "51")
            {
                readyToSend = true;
            }

            if (LastActionTypeIDvalue == "57" && readyToSendAmount == 2)
            {
                readyToSend = true;
            }

            AllinsuranceRentAmount = insuranceRentAmount + AllAmount;

            string msgrent = "";
            string msgservice = "";
            string colorrent = "";
            string colorservice = "";

            //if (RentAmount > 0)
            //    msgrent = $"مبالغ الايجار المطالب بها تبلغ {RentAmount} قم بتحصيلها من المستفيد بالكامل";
            //if (RentAmount > 0)
            //    colorrent = $"mb-4 rounded-lg border border-red-200 bg-red-50 p-4 text-red-800";

            //if (RentAmount < 0)
            //    msgrent = $"مبالغ الايجار الزائدة تبلغ {RentAmount} قم باعادتها للمستفيد بالكامل";
            //if (RentAmount < 0)
            //    colorrent = $"mb-4 rounded-lg border border-yellow-200 bg-yellow-50 p-4 text-yellow-800";

            //if (RentAmount == 0)
            //    msgrent = $"لايوجد مبالغ مطالب بها المستفيد";
            //if (RentAmount == 0)
            //    colorrent = $"mb-4 rounded-lg border border-green-200 bg-green-50 p-4 text-green-800";


            //if (ServiceAmount > 0)
            //    msgservice = $"مبالغ فواتير الخدمات المطالب بها تبلغ {ServiceAmount} قم بتحصيلها من المستفيد بالكامل";
            //if (ServiceAmount > 0)
            //    colorservice = $"mb-4 rounded-lg border border-red-200 bg-red-50 p-4 text-red-800";


            //if (ServiceAmount < 0)
            //    msgservice = $"مبالغ فواتير الخدمات الزائدة تبلغ {ServiceAmount} قم باعادتها للمستفيد بالكامل";
            //if (ServiceAmount < 0)
            //    colorservice = $"mb-4 rounded-lg border border-yellow-200 bg-yellow-50 p-4 text-yellow-800";

            //if (ServiceAmount == 0)
            //    msgservice = $"لايوجد مبالغ مطالب بها المستفيد";
            //if (ServiceAmount == 0)
            //    colorservice = $"mb-4 rounded-lg border border-green-200 bg-green-50 p-4 text-green-800";






            //  التحقق من الصلاحيات
            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            string rowIdField = "";
            string rowIdField_dt3 = "";
            string rowIdField_dt10 = "";
            bool canFINANCIALAUDITFOREXTENDANDEVICTIONS = false;
            bool canFINANCIALSETTLEMENT = false;
            bool canREVIEWCLAIMSANDPAYMENTS = false;
            bool canPAYMENTANDREFUNDFOREXTENDANDEXIT = false;
            
           


            List<OptionItem> ResidentDetailsOptions = new();
            List<OptionItem> PayPaymentTypeOptions = new();
            List<OptionItem> RefundPaymentTypeOptions = new();
            List<OptionItem> BillChargeTypeOptions = new();
            List<OptionItem> billPaymentTypeOptions = new();
            List<OptionItem> SETTLEMENTOptions = new();


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
               
                    result = await _CrudController.GetDDLValues(
                         "billPaymentTypeName_A", "billPaymentTypeID", "5", PageName, usersId, IdaraId, HostName
                    ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                RefundPaymentTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                //// ---------------------- ServicebillPaymentTypeOptions ----------------------
               
                    result = await _CrudController.GetDDLValues(
                          "billPaymentTypeName_A", "billPaymentTypeID", "6", PageName, usersId, IdaraId, HostName
                     ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);

                 PayPaymentTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                //// ---------------------- BillChargeTypeOptions ----------------------

                result = await _CrudController.GetDDLValues(
                         "BillChargeTypeName_A", "BillChargeTypeID", "7", PageName, usersId, IdaraId, HostName
                    ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);

                BillChargeTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                //// ---------------------- rankOptions ----------------------
                result = await _CrudController.GetDDLValues(
                    "billPaymentTypeName_A", "billPaymentTypeID", "9", nameof(FinancialAuditForExtendAndEvictions), usersId, IdaraId, HostName
               ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                billPaymentTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                //// ---------------------- SETTLEMENTOptions ----------------------
                result = await _CrudController.GetDDLValues(
                    "billPaymentTypeName_A", "billPaymentTypeID", "11", nameof(FinancialAuditForExtendAndEvictions), usersId, IdaraId, HostName
               ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                SETTLEMENTOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


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

                        if (permissionName.Equals("FINANCIALAUDITFOREXTENDANDEVICTIONS", StringComparison.OrdinalIgnoreCase))
                        {
                            canFINANCIALAUDITFOREXTENDANDEVICTIONS = true;
                        }
                        if (permissionName.Equals("FINANCIALSETTLEMENT", StringComparison.OrdinalIgnoreCase))
                        {
                            canFINANCIALSETTLEMENT = true;
                        }
                        if (permissionName.Equals("REVIEWCLAIMSANDPAYMENTS", StringComparison.OrdinalIgnoreCase))
                        {
                            canREVIEWCLAIMSANDPAYMENTS = true;
                        }
                        if (permissionName.Equals("PAYMENTANDREFUNDFOREXTENDANDEXIT", StringComparison.OrdinalIgnoreCase))
                        {
                            canPAYMENTANDREFUNDFOREXTENDANDEXIT = true;
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
                            ["buildingDetailsNo"] = "رقم المنزل",
                            ["buildingRentAmount"] = "مبلغ الايجار",
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
                            bool isIdaraName = c.ColumnName.Equals("IdaraName", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingDetailsID = c.ColumnName.Equals("buildingDetailsID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionID = c.ColumnName.Equals("LastActionID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionTypeID = c.ColumnName.Equals("LastActionTypeID", StringComparison.OrdinalIgnoreCase);
                            bool isActionID = c.ColumnName.Equals("ActionID", StringComparison.OrdinalIgnoreCase);
                            bool isBillsStatusID = c.ColumnName.Equals("BillsStatusID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionExtendReasonTypeID = c.ColumnName.Equals("LastActionExtendReasonTypeID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionDate = c.ColumnName.Equals("LastActionDate", StringComparison.OrdinalIgnoreCase);


                           

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                 ,
                                Visible = !(isfirstName_A || isfirstName_E || issecondName_A || issecondName_E || isthirdName_A || isthirdName_E || islastName_A || islastName_E || isrankID_FK || ismilitaryUnitID_FK || ismartialStatusID_FK || isnationalityID_FK || isgenderID_FK || isFullName_E || isbirthdate || isnote || isIdaraID || isIdaraName || isbuildingDetailsID || isLastActionID || isLastActionTypeID || isActionID || isBillsStatusID || isLastActionID || isLastActionExtendReasonTypeID || isLastActionDate)
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

                            object? GetNumeric(string key)
                            {
                                var value = Get(key);
                                if (value is decimal d) return d.ToString("0.00");
                                if (value is int i) return i.ToString();
                                return value?.ToString() ?? "0";
                            }
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
                            dict["p28"] = Get("buildingDetailsID");
                            dict["p29"] = Get("buildingDetailsNo");
                            dict["p40"] = Get("LastActionExtendReasonTypeID");
                            dict["AllAmountresidual"] = AllAmount.ToString("0.00");
                            dict["AllAmountIsNegative"] = AllAmount < 0 ? "true" : "false";
                            dict["AllAmountIsPositve"] = AllAmount > 0 ? "true" : "false";


                            rowsList.Add(dict);
                        }
                    }


                    if (dt3 != null && dt3.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField_dt3 =
                                    dt3.Columns.Cast<DataColumn>()
                                       .FirstOrDefault(c =>
                                           c.ColumnName.Equals("RowId", StringComparison.OrdinalIgnoreCase) ||
                                           c.ColumnName.Equals("order_", StringComparison.OrdinalIgnoreCase) ||
                                           c.ColumnName.Equals("Order_", StringComparison.OrdinalIgnoreCase) ||
                                           c.ColumnName.Equals("Id", StringComparison.OrdinalIgnoreCase) ||
                                           c.ColumnName.Equals("ID", StringComparison.OrdinalIgnoreCase))
                                       ?.ColumnName
                                    ?? dt3.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap3 = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            

                           
                            ["Order_"] = "م",
                            ["residentInfoID"] = "الرقم المرجعي",
                            ["BillChargeTypeName_A"] = "النوع",
                            ["buildingDetailsNo"] = "رقم المبنى",
                            ["SumBillsTotalPrice"] = "المطلوب",
                            ["SumTotalPaidBills"] = "المسدد",
                            ["Remaining"] = "المتبقي / الفائض",
                            ["BillsStatus"] = "الحالة"
                            





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

                            bool isHidden =  c.ColumnName.Equals("BillChargeTypeID", StringComparison.OrdinalIgnoreCase)
                                           || c.ColumnName.Equals("buildingDetailsID", StringComparison.OrdinalIgnoreCase)
                                           //|| c.ColumnName.Equals("order_", StringComparison.OrdinalIgnoreCase)
                                           || c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase)
                                           || c.ColumnName.Equals("BillsStatusID", StringComparison.OrdinalIgnoreCase)
                                           ;
                           


                            dynamicColumns_dt3.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap3.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                 ,
                                Visible = !(isHidden)
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

                            dict3["p01"] = Get("order_");
                            dict3["p02"] = Get("residentInfoID");
                            dict3["p03"] = GetNumeric("BillChargeTypeID");
                            dict3["p04"] = GetNumeric("BillChargeTypeName_A");
                            dict3["p05"] = GetNumeric("buildingDetailsID");
                            dict3["p06"] = Get("buildingDetailsNo");
                            dict3["p07"] = GetNumeric("SumBillsTotalPrice");
                            dict3["p08"] = GetNumeric("SumTotalPaidBills");
                            dict3["p09"] = GetNumeric("Remaining");
                            dict3["p10"] = Get("BillsStatus");
                            dict3["p11"] = Get("BillsStatusID");

                            rowsList_dt3.Add(dict3);
                        }
                    }


                    if (dt10 != null && dt10.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField_dt10 =
                                    dt10.Columns.Cast<DataColumn>()
                                       .FirstOrDefault(c =>
                                           c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase) ||
                                           c.ColumnName.Equals("ResidentInfoID", StringComparison.OrdinalIgnoreCase))
                                       ?.ColumnName
                                    ?? dt10.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap10 = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            

                           
                            ["residentInfoID"] = "الرقم المرجعي",
                            ["Remaining"] = "اجمالي المتبقي او الفائض",
                            ["SumBillsTotalPrice"] = "اجمالي المطالبات",
                            ["SumTotalPaidBills"] = "اجمالي المدفوعات",
                            ["BillsStatus"] = "الحالة"
                            

                        };

                        // الأعمدة
                        foreach (DataColumn c in dt10.Columns)
                        {
                            string colType = "text";
                            var t = c.DataType;
                            if (t == typeof(bool)) colType = "bool";
                            else if (t == typeof(DateTime)) colType = "date";
                            else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                                     || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                                colType = "number";


                            bool isHidden =  c.ColumnName.Equals("BillChargeTypeID", StringComparison.OrdinalIgnoreCase)
                                           || c.ColumnName.Equals("buildingDetailsID", StringComparison.OrdinalIgnoreCase)
                                           || c.ColumnName.Equals("BillsStatusID", StringComparison.OrdinalIgnoreCase);



                            dynamicColumns_dt10.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap10.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                 ,
                                Visible = !(isHidden)
                            });
                        }

                        // الصفوف
                        foreach (DataRow r in dt10.Rows)
                        {
                            var dict10 = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt10.Columns)
                            {
                                var val = r[c];
                                dict10[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            // p01..p05
                            object? Get(string key) => dict10.TryGetValue(key, out var v) ? v : null;

                            // Helper to ensure 0 values are displayed as "0" for decimal/numeric fields
                            object? GetNumeric(string key)
                            {
                                var value = Get(key);
                                
                                if (value is decimal d) return d.ToString("0.00");
                                if (value is int i) return i.ToString();
                                return value?.ToString() ?? "0";
                            }

                            dict10["p01"] = Get("residentInfoID");
                            dict10["p02"] = Get("SumBillsTotalPrice");
                            dict10["p03"] = GetNumeric("SumTotalPaidBills");
                            dict10["p04"] = GetNumeric("Remaining");
                            dict10["p05"] = GetNumeric("BillsStatus");
                            dict10["p06"] = Get("BillsStatusID");
                          

                            rowsList_dt10.Add(dict10);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.BuildingTypeDataSetError = ex.Message;
            }



            var currentUrl = Request.Path + Request.QueryString;
            var currentUrlonly = Request.Path;

            var ApproveExtendOrExitFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "FINANCIALAUDITFOREXTENDANDEVICTIONS" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrlonly },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                // hidden p01 actually posted to SP
                 new FieldConfig { Name = "p01", Label = "Order_", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p02", Label = "residentInfoID", Type = "hidden", ColCss = "3", Readonly = true,Value=residentInfoIDvalue },
                new FieldConfig { Name = "p03", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true,Value=buildingDetailsIDvalue },
                new FieldConfig { Name = "p11", Label = "ملاحظات", Type = "textarea", ColCss = "6",Required = true,HelpText="يجب ان لاتتجاوز 4000 حرف*",MaxLength=3900 },
                //new FieldConfig { Name = "p30", Label = "ملاحظات", Type = "text", ColCss = "6",Value = LastActionDatevalue },
                //new FieldConfig { Name = "p40", Label = "سبب الامهال", Type = "select", ColCss = "4",Required = true,HelpText="المتقاعد والمفصول مطلوب تأمين احترازي يرجى الاختيار بدقة*",Options=billPaymentTypeOptions,Value=LastActionExtendReasonTypeIDvalue},
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true,Value = LastActionTypeIDvalue },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true,Value = buildingDetailsNovalue },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true,Value=LastActionIDvalue },
                new FieldConfig { Name = "p22", Label = "ActionID", Type = "hidden", ColCss = "3", Readonly = true,Value=ActionIDvalue },


            };

            // UPDATE fields
            var BillsFields = new List<FieldConfig>
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
                new FieldConfig { Name = "p03", Label = "BillChargeTypeID", Type = "hidden", ColCss = "3", Readonly = true }, 
                new FieldConfig { Name = "p04", Label = "BillChargeTypeName_A", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p05", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p06", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true,Value=buildingDetailsNovalue },
                new FieldConfig { Name = "p07", Label = "SumBillsTotalPrice", Type = "hidden", ColCss = "3", Readonly = true,Value=buildingDetailsIDvalue },
                new FieldConfig { Name = "p08", Label = "SumTotalPaidBills", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "Remaining", Type = "hidden", ColCss = "3", Required = true },
                new FieldConfig { Name = "p10", Label = "BillsStatus", Type = "hidden", ColCss = "3", Required = true },
                new FieldConfig { Name = "p11", Label = "BillsStatusID", Type = "hidden", ColCss = "3", Required = true},


                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },


            };

            var PaidFields = new List<FieldConfig>
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
                new FieldConfig { Name = "p03", Label = "BillChargeTypeID", Type = "hidden", ColCss = "3", Readonly = true }, 
                new FieldConfig { Name = "p04", Label = "BillChargeTypeName_A", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p05", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p06", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true,Value=buildingDetailsNovalue },
                new FieldConfig { Name = "p07", Label = "SumBillsTotalPrice", Type = "hidden", ColCss = "3", Readonly = true,Value=buildingDetailsIDvalue },
                new FieldConfig { Name = "p08", Label = "SumTotalPaidBills", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "Remaining", Type = "hidden", ColCss = "3", Required = true },
                new FieldConfig { Name = "p10", Label = "BillsStatus", Type = "hidden", ColCss = "3", Required = true },
                new FieldConfig { Name = "p11", Label = "BillsStatusID", Type = "hidden", ColCss = "3", Required = true },


                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },


            };




            var PayMoneyFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "PAYMENTANDREFUNDFOREXTENDANDEXIT" },
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
                new FieldConfig { Name = "p03", Label = "BillChargeTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p04", Label = "BillChargeTypeName_A", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p05", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p06", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true,Value=buildingDetailsNovalue },
                new FieldConfig { Name = "p07", Label = "SumBillsTotalPrice", Type = "hidden", ColCss = "3", Readonly = true,Value=buildingDetailsIDvalue },
                new FieldConfig { Name = "p08", Label = "SumTotalPaidBills", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "BillsStatus", Type = "hidden", ColCss = "3", Required = true },
                new FieldConfig { Name = "p11", Label = "BillsStatusID", Type = "hidden", ColCss = "3", Required = true},


                new FieldConfig { Name = "p12", Label = "نوع العملية", Type = "select", ColCss = "3", Required = true, Options= PayPaymentTypeOptions },
                new FieldConfig { Name = "p13", Label = "رقم العملية", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p14", Label = "تاريخ العملية", Type = "date", ColCss = "3", Required = true },
                new FieldConfig { Name = "p09", Label = "المبلغ", Type = "text",TextMode="money_sar",Icon = "/img/Saudi_Riyal_Symbol.svg", ColCss = "3", Required = true },
                new FieldConfig { Name = "p27", Label = "ملاحظات", Type = "textarea", ColCss = "6", Required = true },

                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true,Value = LastActionTypeIDvalue },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true,Value=LastActionIDvalue },
                new FieldConfig { Name = "p22", Label = "ActionID", Type = "hidden", ColCss = "3", Readonly = true,Value=ActionIDvalue },

            };


            var RefundMoneyFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "PAYMENTANDREFUNDFOREXTENDANDEXIT" },
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
                new FieldConfig { Name = "p03", Label = "BillChargeTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p04", Label = "BillChargeTypeName_A", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p05", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p06", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true,Value=buildingDetailsNovalue },
                new FieldConfig { Name = "p07", Label = "SumBillsTotalPrice", Type = "hidden", ColCss = "3", Readonly = true,Value=buildingDetailsIDvalue },
                new FieldConfig { Name = "p08", Label = "SumTotalPaidBills", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "BillsStatus", Type = "hidden", ColCss = "3", Required = true },
                new FieldConfig { Name = "p11", Label = "BillsStatusID", Type = "hidden", ColCss = "3", Required = true},


                new FieldConfig { Name = "p12", Label = "نوع العملية", Type = "select", ColCss = "3", Required = true, Options= RefundPaymentTypeOptions },
                new FieldConfig { Name = "p13", Label = "رقم العملية", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p14", Label = "تاريخ العملية", Type = "date", ColCss = "3", Required = true },
                new FieldConfig { Name = "p09", Label = "المبلغ", Type = "text",TextMode="money_sar",Icon = "/img/Saudi_Riyal_Symbol.svg", ColCss = "3", Required = true },
                new FieldConfig { Name = "p27", Label = "ملاحظات", Type = "textarea", ColCss = "6", Required = true },

                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true,Value = LastActionTypeIDvalue },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true,Value=LastActionIDvalue },
                new FieldConfig { Name = "p22", Label = "ActionID", Type = "hidden", ColCss = "3", Readonly = true,Value=ActionIDvalue },

            };



            var SattlmentFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "FINANCIALSETTLEMENT" },
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
                new FieldConfig { Name = "p03", Label = "BillChargeTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p04", Label = "الرصيد المسحوب منه", Type = "text", ColCss = "4", Readonly = true, },
                new FieldConfig { Name = "p30", Label = "الرصيد المسحوب اليه", Type = "select", ColCss = "4", Readonly = true,Required = true,Options = BillChargeTypeOptions },
                new FieldConfig { Name = "p05", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p06", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true,Value=buildingDetailsNovalue },
                new FieldConfig { Name = "p07", Label = "SumBillsTotalPrice", Type = "hidden", ColCss = "3", Readonly = true,Value=buildingDetailsIDvalue },
                new FieldConfig { Name = "p08", Label = "SumTotalPaidBills", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "Remining", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "BillsStatus", Type = "hidden", ColCss = "3", Required = true },
                new FieldConfig { Name = "p11", Label = "BillsStatusID", Type = "hidden", ColCss = "3", Required = true},


                new FieldConfig { Name = "p12", Label = "نوع العملية", Type = "hidden", ColCss = "3", Required = true, Value="6" },
                new FieldConfig { Name = "p13", Label = "رقم العملية", Type = "hidden", ColCss = "3", Required = true },
                new FieldConfig { Name = "p14", Label = "تاريخ العملية", Type = "hidden", ColCss = "3", Required = true },
                new FieldConfig { Name = "p39", Label = "المبلغ", Type = "text",TextMode="money_sar",Icon = "/img/Saudi_Riyal_Symbol.svg", ColCss = "4", Required = true },
                new FieldConfig { Name = "p27", Label = "ملاحظات", Type = "textarea", ColCss = "6", Required = true },

                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true,Value = LastActionTypeIDvalue },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true,Value=LastActionIDvalue },
                new FieldConfig { Name = "p22", Label = "ActionID", Type = "hidden", ColCss = "3", Readonly = true,Value=ActionIDvalue },

            };







            var extraBillsCtx = new Dictionary<string, object?>
            {
                ["idaraID"] = IdaraId,
                ["entrydata"] = usersId,
                ["hostname"] = HostName
            };

            var extraBillsRequestBase = new Dictionary<string, object?>
            {
                ["pageName_"] = PageName,
                ["ActionType"] = "GetBillsTotalPriceForResident",
                ["tableIndex"] = 0
            };

            //        var extraMetaBills = new Dictionary<string, object?>
            //        {
            //            ["extraSlotKey"] = "m1",
            //            ["extraTitle"] = "بيانات المطالبات",
            //            ["useRowExtra"] = true,
            //            ["lazyExtra"] = true,
            //            ["extraEndpoint"] = "/crud/extradataload",
            //            ["allowNoSelection"] = true,
            //            ["emptyText"] = "لاتوجد مطالبات مسجلة",
            //            ["showPrint"]= true,

            //            // المهم
            //            ["extraLoadOnOpen"] = true,

            //            ["ctx"] = extraBillsCtx,
            //            ["extraRequest"] = extraBillsRequestBase,

            //            ["extraParamMap"] = new Dictionary<string, string>
            //            {
            //                ["parameter_01"] = "p02"
            //                ,
            //                ["parameter_02"] = "p03"
            //                ,
            //                ["parameter_03"] = "p05"
            //            },

            //            ["EnableSearch"] = true,
            //            ["ShowMeta"] = true,
            //            ["PageSize"] = 10,
            //            ["Sortable"] = true,
            //            ["showRowNumbers"] = true,

            //            ["visibleFields"] = new List<string>
            //{
            //    "BillsID","BillNumber","BillChargeTypeName_A", "buildingDetailsNo","TotalPrice"
            //},

            //            ["headerMap"] = new Dictionary<string, string>
            //            {
            //                ["BillsID"] = "الرقم المرجعي",
            //                ["BillNumber"] = "رقم الفاتورة",
            //                ["BillChargeTypeName_A"] = "الخدمة",
            //                ["buildingDetailsNo"] = "رقم المبنى",
            //                ["TotalPrice"] = "المبلغ"
            //            }
            //        };

            var extraMetaBills = new Dictionary<string, object?>
            {
                ["extraSlotKey"] = "m1",
                //["extraTitle"] = "بيانات المطالبات",
                ["useRowExtra"] = true,
                ["lazyExtra"] = true,
                ["extraEndpoint"] = "/crud/extradataload",
                ["allowNoSelection"] = true,
                ["emptyText"] = "لاتوجد مطالبات مسجلة",


                ["showPrint"] = true,
                ["printTitle"] = "المطالبات",
                ["printOrientation"] = "portrait", // أو landscape
                ["showPageNumbers"] = true,        // أو false
                ["showPrintSerial"] = true,        // أو false
                ["printSerialLabel"] = "م",


                ["printFields"] = new List<string>
                {
                    //"BillsID",
                    "BillNumber",
                    "BillChargeTypeName_A",
                    "buildingDetailsNo",
                    "TotalPrice"
                },

                ["printHeaderMap"] = new Dictionary<string, string>
                {
                    //["BillsID"] = "الرقم المرجعي",
                    ["BillNumber"] = "رقم الفاتورة",
                    ["BillChargeTypeName_A"] = "الخدمة",
                    ["buildingDetailsNo"] = "رقم المبنى",
                    ["TotalPrice"] = "المبلغ"
                },

                ["extraLoadOnOpen"] = true,
                ["ctx"] = extraBillsCtx,
                ["extraRequest"] = extraBillsRequestBase,

                ["extraParamMap"] = new Dictionary<string, string>
                {
                    ["parameter_01"] = "p02",
                    ["parameter_02"] = "p03",
                    ["parameter_03"] = "p05"
                },

                ["EnableSearch"] = true,
                ["ShowMeta"] = true,
                ["PageSize"] = 10,
                ["Sortable"] = true,
                ["showRowNumbers"] = true,

                ["visibleFields"] = new List<string>
                {
                    "BillsID","BillNumber","BillChargeTypeName_A", "buildingDetailsNo","TotalPrice"
                },

                ["headerMap"] = new Dictionary<string, string>
                {
                    ["BillsID"] = "الرقم المرجعي",
                    ["BillNumber"] = "رقم الفاتورة",
                    ["BillChargeTypeName_A"] = "الخدمة",
                    ["buildingDetailsNo"] = "رقم المبنى",
                    ["TotalPrice"] = "المبلغ"
                }
            };


            var extraPaidCtx = new Dictionary<string, object?>
            {
                ["idaraID"] = IdaraId,
                ["entrydata"] = usersId,
                ["hostname"] = HostName
            };

            var extraPaidRequestBase = new Dictionary<string, object?>
            {
                ["pageName_"] = PageName,
                ["ActionType"] = "GetBillsPaidByResident",
                ["tableIndex"] = 0
            };



            var extraMetaPaid = new Dictionary<string, object?>
            {
                ["extraSlotKey"] = "m1",
                ["extraTitle"] = "بيانات المدفوعات",
                ["useRowExtra"] = true,
                ["lazyExtra"] = true,
                ["extraEndpoint"] = "/crud/extradataload",
                ["allowNoSelection"] = true,
                ["emptyText"] = "لاتوجد مدفوعات مسجلة",
                // المهم
                ["extraLoadOnOpen"] = true,

                ["ctx"] = extraPaidCtx,
                ["extraRequest"] = extraPaidRequestBase,

                ["extraParamMap"] = new Dictionary<string, string>
                {
                    ["parameter_01"] = "p02"
                    ,
                    ["parameter_02"] = "p03"
                    ,
                    ["parameter_03"] = "p05"
                },

                ["EnableSearch"] = true,
                ["ShowMeta"] = true,
                ["PageSize"] = 10,
                ["Sortable"] = true,
                ["showRowNumbers"] = true,
                ["visibleFields"] = new List<string>
    {
       "BillChargeTypeName_A","FullName_A","buildingDetailsNo","amount"
    },
               

                ["headerMap"] = new Dictionary<string, string>
                {
                    ["FullName_A"] = "الاسم",
                    ["buildingDetailsNo"] = "المبنى",
                    ["BillChargeTypeName_A"] = "الخدمة",
                    ["amount"] = "المبلغ"
                }
            };


            var dsModel = new SmartTableDsModel
            {

                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageTitle = "التدقيق المالي لحالات الامهال والاخلاء",
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
                RenderAsToggle = false,
                ToggleLabel = "بيانات المستفيد",
                ToggleIcon = "fa-solid fa-newspaper",
                ToggleDefaultOpen = true,
                ShowToggleCount = false,
                Selectable = false,
                
                

              
            };

            var selectedFields = AllRemaining < 0 ? PayMoneyFields : RefundMoneyFields;

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
                Selectable = true,
                HeaderColor = "#1e3a8a", // تختار لون الهيدر بكيفك

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowEdit = canREVIEWCLAIMSANDPAYMENTS,
                    ShowEdit1 = canREVIEWCLAIMSANDPAYMENTS,
                    ShowEdit2 = canPAYMENTANDREFUNDFOREXTENDANDEXIT,
                    ShowDelete = canFINANCIALSETTLEMENT,
                    ShowBulkDelete = false,




                    //Add = new TableAction
                    //{
                    //    Label = "التأمين الاحترازي",
                    //    Icon = "fa-solid fa-money-bill-1-wave",
                    //    Color = "success",
                    //    OpenModal = true,
                    //    ModalTitle = "<i class='fa-solid fa-money-bill-1-wave text-emerald-600 text-xl mr-2'></i> تحصيل التأمين الاحترازي",
                    //    ModalMessage = "في حال وجود مطالبات على المستفيد لم يتم تسويتها سيتم اضافتها للتأمين الاحترازي وفي حال وجود مبالغ زائدة للمستفيد سيتم حسمها من التأمين الاحترازي",
                    //    ModalMessageIcon = "fa-solid fa-circle-info",
                    //    ModalMessageClass = "mb-4 rounded-lg border border-blue-200 bg-blue-50 p-4 text-blue-800",
                    //    Show = true,
                    //    OpenForm = new FormConfig
                    //    {
                    //        FormId = "BuildingTypeInsertForm",
                    //        Title = "التأمين الاحترازي",
                    //        Method = "post",
                    //        ActionUrl = "/crud/insert",
                    //        Fields = insuranceFields,
                    //        Buttons = new List<FormButtonConfig>
                    //        {
                    //            new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                    //            new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                    //        }
                    //    },
                    //    RequireSelection = true,
                    //    MinSelection = 1,
                    //    MaxSelection = 1

                    //},


                    

                    Edit = new TableAction
                    {
                        Label = "استعراض المطالبات",
                        Icon = "fa fa-list-alt",
                        Color = "info",
                        //Placement = TableActionPlacement.ActionsMenu, 
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "استعراض المطالبات",
                        //ModalMessage = msgrent,
                        //ModalMessageIcon = "fa-solid fa-circle-info",
                        //ModalMessageClass = colorrent,
                        Show = true,
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "استعراض المطالبات",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = BillsFields,
                            Buttons = new List<FormButtonConfig>
                            {
                               // new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "انهاء", Type = "button", Color = "secondary", OnClickJs = "window.__sfTableActive?.closeModal();"  }
                            }
                        },
                        Meta = extraMetaBills,
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
                                        Field = "SumBillsTotalPrice",
                                        Op = "eq",
                                        Value = "0",
                                        Message = "لايوجد مطالبات للاستعراض",
                                        Priority = 3
                                    },


                                  }
                        }

                    },


                    Edit1 = new TableAction
                     {
                         Label = "استعراض السدادات",
                         Icon = "fa fa-money-bill",
                         Color = "info",
                         //Placement = TableActionPlacement.ActionsMenu, 
                         IsEdit = true,
                         OpenModal = true,
                         ModalTitle = "استعراض السدادات",
                         
                         //ModalMessage = msgservice,
                         //ModalMessageIcon = "fa-solid fa-circle-info",
                         //ModalMessageClass = colorservice,
                        Show = true,
                        OpenForm = new FormConfig
                         {
                             FormId = "BuildingTypeEditForm",
                             Title = "استعراض السدادات",
                             Method = "post",
                             ActionUrl = "/crud/update",
                             SubmitText = "حفظ التعديلات",
                             CancelText = "إلغاء",
                             Fields = PaidFields,
                            Buttons = new List<FormButtonConfig>
                            {
                               // new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "انهاء", Type = "button", Color = "secondary", OnClickJs = "window.__sfTableActive?.closeModal();"  }
                            }
                        },
                        Meta = extraMetaPaid,
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
                                        Field = "SumTotalPaidBills",
                                        Op = "eq",
                                        Value = "0",
                                        Message = "لايوجد مدفوعات للاستعراض",
                                        Priority = 3
                                    },


                                  }
                        }
                    },



                    Edit2 = new TableAction
                    {
                        Label = "دفع المطالبات / اعادة مبالغ",
                        Icon = "/img/Saudi_Riyal_Symbol.svg",
                        Color = "success",
                        
                        //Placement = TableActionPlacement.ActionsMenu, 
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "دفع المطالبات / اعادة مبالغ",
                        ModalMessage = msgservice,
                        ModalMessageIcon = "fa-solid fa-circle-info",
                        ModalMessageClass = colorservice,
                        Show = true,
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "دفع المطالبات / اعادة مبالغ",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                           // Fields = PayMoneyFields,
                            Buttons = new List<FormButtonConfig>
                            {
                               new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "انهاء", Type = "button", Color = "secondary", OnClickJs = "window.__sfTableActive?.closeModal();"  }
                            }
                        },

                        Meta = new Dictionary<string, object?>
                        {
                            ["dynamicFieldsByRow"] = true,
                            ["dynamicFieldsField"] = "p11",

                            ["dynamicFieldsMap"] = new Dictionary<string, object?>
                            {
                                ["0"] = PayMoneyFields,
                                ["1"] = RefundMoneyFields
                                //,
                                //["2"] = ApproveExtendOrExitFields
                            },

                            ["dynamicFieldsDefault"] = PayMoneyFields
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
                                        Field = "BillsStatusID",
                                        Op = "eq",
                                        Value = "2",
                                        Message = "لايوجد مطالبات ولامدفوعات للمعالجة",
                                        Priority = 3
                                    },


                                  }
                        }
                    },



                    Delete = new TableAction
                    {
                        Label = "التسوية المالية",
                        Icon = "fa fa-exchange-alt",
                        Color = "warning",
                        
                        //Placement = TableActionPlacement.ActionsMenu, 
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "التسوية المالية",
                        ModalMessage = msgservice,
                        ModalMessageIcon = "fa-solid fa-circle-info",
                        ModalMessageClass = colorservice,
                        Show = true,


                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "التسوية المالية",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = SattlmentFields,
                            Buttons = new List<FormButtonConfig>
                            {
                               new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "انهاء", Type = "button", Color = "secondary", OnClickJs = "window.__sfTableActive?.closeModal();"  }
                            }
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
                                        Field = "BillsStatusID",
                                        Op = "neq",
                                        Value = "1",
                                        Message = "لايوجد مبالغ للتسوية",
                                        Priority = 3
                                    },
                                       

                                  }
                         }
                    },


                }

            };
            
            
            var dsModel10 = new SmartTableDsModel
            {
                PageTitle = "التدقيق المالي لحالات الامهال والاخلاء",
                Columns = dynamicColumns_dt10,
                Rows = rowsList_dt10,
                RowIdField = rowIdField_dt10,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns_dt10.Select(c => c.Field).Take(4).ToList(),
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
                ToggleLabel = "اجمالي المطالبات",
                ToggleIcon = "fa-solid fa-file-signature",
                ToggleDefaultOpen = true,
                ShowToggleCount = false,
                Selectable = false,
                HeaderColor = "#92400e", // تختار لون الهيدر بكيفك

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = canFINANCIALAUDITFOREXTENDANDEVICTIONS ,
                    EnableAdd = readyToSend && canFINANCIALAUDITFOREXTENDANDEVICTIONS ,
                    
                    ShowBulkDelete = false,


                    Add = new TableAction
                    {
                        Label = "اعتماد التدقيق المالي وارساله لقسم الاسكان",
                        Icon = "fa fa-check",
                        Color = "success",
                        IsEdit = false,
                        OpenModal = true,
                        ModalTitle = "اعتماد الامهال",
                        ModalMessage = "لايمكن التراجع بعد اعتماد التدقيق المالي وارساله لقسم الاسكان",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OpenForm = new FormConfig
                        {
                            FormId = "employeeDeleteForm",
                            Title = "تأكيد اعتماد التدقيق المالي وارساله لقسم الاسكان",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success", Icon = "fa fa-check" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = ApproveExtendOrExitFields
                        },

                    },

                }

            };


            dsModel3.StyleRules = new List<TableStyleRule>
                    {

                         new TableStyleRule
                        {
                            Target = "row",
                            Field = "BillsStatusID",
                            Op = "eq",
                            Value = "0",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "BillsStatus",
                            PillTextField = "BillsStatus",
                            PillCssClass = "pill pill-red",
                            PillMode = "replace"
                        },
                        new TableStyleRule
                        {
                            Target = "row",
                            Field = "BillsStatusID",
                            Op = "eq",
                            Value = "1",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "BillsStatus",
                            PillTextField = "BillsStatus",
                            PillCssClass = "pill pill-yellow",
                            PillMode = "replace"
                        },

                        new TableStyleRule
                        {

                            Target = "row",
                            Field = "BillsStatusID",
                            Op = "eq",
                            Value = "2",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "BillsStatus",
                            PillTextField = "BillsStatus",
                            PillCssClass = "pill pill-green",
                            PillMode = "replace"
                        },


                          new TableStyleRule
                        {
                            Target = "row",
                            Field = "BillsStatusID",
                            Op = "eq",
                            Value = "0",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "Remaining",
                            PillTextField = "Remaining",
                            PillCssClass = "pill pill-red",
                            PillMode = "replace"
                        },

                           new TableStyleRule
                        {
                            Target = "row",
                            Field = "BillsStatusID",
                            Op = "eq",
                            Value = "1",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "Remaining",
                            PillTextField = "Remaining",
                            PillCssClass = "pill pill-yellow",
                            PillMode = "replace"
                        },

                            new TableStyleRule
                        {
                            Target = "row",
                            Field = "BillsStatusID",
                            Op = "eq",
                            Value = "2",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "Remaining",
                            PillTextField = "Remaining",
                            PillCssClass = "pill pill-green",
                            PillMode = "replace"
                        },

                    };
          
            dsModel10.StyleRules = new List<TableStyleRule>
                    {

                         new TableStyleRule
                        {
                            Target = "row",
                            Field = "BillsStatusID",
                            Op = "eq",
                            Value = "0",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "Remaining",
                            PillTextField = "Remaining",
                            PillCssClass = "pill pill-red",
                            PillMode = "replace"
                        },
                        new TableStyleRule
                        {
                            Target = "row",
                            Field = "BillsStatusID",
                            Op = "eq",
                            Value = "1",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "Remaining",
                            PillTextField = "Remaining",
                            PillCssClass = "pill pill-yellow",
                            PillMode = "replace"
                        },

                        new TableStyleRule
                        {

                            Target = "row",
                            Field = "BillsStatusID",
                            Op = "eq",
                            Value = "2",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "Remaining",
                            PillTextField = "Remaining",
                            PillCssClass = "pill pill-green",
                            PillMode = "replace"
                        },


                          new TableStyleRule
                        {
                            Target = "row",
                            Field = "BillsStatusID",
                            Op = "eq",
                            Value = "0",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "BillsStatus",
                            PillTextField = "BillsStatus",
                            PillCssClass = "pill pill-red",
                            PillMode = "replace"
                        },

                           new TableStyleRule
                        {
                            Target = "row",
                            Field = "BillsStatusID",
                            Op = "eq",
                            Value = "1",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "BillsStatus",
                            PillTextField = "BillsStatus",
                            PillCssClass = "pill pill-yellow",
                            PillMode = "replace"
                        },

                            new TableStyleRule
                        {
                            Target = "row",
                            Field = "BillsStatusID",
                            Op = "eq",
                            Value = "2",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "BillsStatus",
                            PillTextField = "BillsStatus",
                            PillCssClass = "pill pill-green",
                            PillMode = "replace"
                        },

                    };



            bool dsModelHasRows = dt1 != null && dt1.Rows.Count > 0;

            bool dsModel3HasRows = dt3 != null && dt3.Rows.Count > 0;

            bool dsModel10HasRows = dt10 != null && dt10.Rows.Count > 0;



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
                TableDS1 = dsModel10HasRows ? dsModel10 : null,
                TableDS2 = dsModel3HasRows ? dsModel3 : null

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
            return View("FinancialAudit/FinancialAuditForExtendAndEvictions", page);
        }
    }
}