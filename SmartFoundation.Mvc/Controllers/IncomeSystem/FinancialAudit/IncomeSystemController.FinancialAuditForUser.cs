using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using SmartFoundation.MVC.Reports;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using SmartFoundation.UI.ViewModels.SmartDrawer;
using SmartFoundation.UI.ViewModels.SmartAccordion;
using System.Data;
using System.Linq;
using System.Text.Json;
using SmartFoundation.Mvc.Services.DataLoad;




namespace SmartFoundation.Mvc.Controllers.IncomeSystem
{
    public partial class IncomeSystemController : Controller
    {
        //public async Task<IActionResult> FinancialAuditForUser(int pdf = 0)
        public async Task<IActionResult> FinancialAuditForUser(
    [FromServices] RequestScopedDataLoadService requestDataLoad,
    int pdf = 0,
    long? printResidentID = null,
    long? printBuildingID = null,
    int? printServiceID = null)
        {
            //  قراءة السيشن والكونتكست
            if (!InitPageContext(out var redirect))
                return redirect!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }



            string? NationalID_ = Request.Query["U"].FirstOrDefault();

            NationalID_ = string.IsNullOrWhiteSpace(NationalID_) ? null : NationalID_.Trim();

            bool ready = false;
            bool readyToSend = false;

            ready = !string.IsNullOrWhiteSpace(NationalID_);


            ControllerName = nameof(IncomeSystem);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "FinancialAuditForUser" : PageName;

            //var spParameters = new object?[]
            //{
            // PageName ?? "FinancialAuditForUser",
            // IdaraId,
            // usersId,
            // HostName,
            // NationalID_
            //};

            // معاملات تحميل القوائم دون رقم المستفيد.
            // مطابقة للمعاملات التي كانت تمررها GetDDLValues.
            var ddlParameters = new Dictionary<string, object?>(
                StringComparer.OrdinalIgnoreCase)
            {
                ["pageName_"] = PageName ?? "FinancialAuditForUser"
            };

            if (IdaraId != null)
                ddlParameters["idaraID"] = Convert.ToInt32(IdaraId);

            if (usersId != null)
                ddlParameters["entrydata"] = Convert.ToInt32(usersId);

            if (HostName != null)
                ddlParameters["hostname"] = HostName;

            // معاملات تحميل بيانات الصفحة.
            // نضيف رقم الهوية فقط عند وجوده.
            var pageParameters = new Dictionary<string, object?>(
                ddlParameters,
                StringComparer.OrdinalIgnoreCase);

            if (NationalID_ != null)
                pageParameters["parameter_01"] = NationalID_;

            var rowsList = new List<Dictionary<string, object?>>();
            var rowsList_dt3 = new List<Dictionary<string, object?>>();
            var rowsList_dt10 = new List<Dictionary<string, object?>>();
            var rowsList_general = new List<Dictionary<string, object?>>();

            var dynamicColumns = new List<TableColumn>();
            var dynamicColumns_dt3 = new List<TableColumn>();
            var dynamicColumns_dt10 = new List<TableColumn>();
            var dynamicColumns_general = new List<TableColumn>();

            //DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            DataSet ds = await requestDataLoad.GetDataLoadDataSetAsync(pageParameters);

            //  تقسيم الداتا سيت للجدول الأول + جداول أخرى
            // تقسيم الداتا سيت
            SplitDataSet(ds);

            // اسم المستفيد لعرضه في عنوان Drawer الرصيد العام
            string generalResidentName =
                dt1 != null &&
                dt1.Rows.Count > 0 &&
                dt1.Columns.Contains("FullName_A") &&
                dt1.Rows[0]["FullName_A"] != DBNull.Value
                    ? dt1.Rows[0]["FullName_A"].ToString()?.Trim() ?? ""
                    : "";

            // اسم المستفيد لعرضه في عنوان Drawer الرصيد العام
            string generalResidentNationalID =
                dt1 != null &&
                dt1.Rows.Count > 0 &&
                dt1.Columns.Contains("NationalID") &&
                dt1.Rows[0]["NationalID"] != DBNull.Value
                    ? dt1.Rows[0]["NationalID"].ToString()?.Trim() ?? ""
                    : "";

            // الرصيد العام - Result Set 11
            // محفوظ في dt10 دون تغيير ترتيب الجداول السابقة
            if (dt10 != null &&
                dt10.Columns.Contains("BillChargeTypeID") &&
                dt10.Columns.Contains("Remaining"))
            {
                var generalHeaders = new Dictionary<string, string>(
                    StringComparer.OrdinalIgnoreCase)
                {
                    ["BillChargeTypeName_A"] = "نوع الخدمة",
                    ["SumBillsTotalPrice"] = "إجمالي المطالبات",
                    ["SumTotalPaidBills"] = "إجمالي المدفوعات",
                    ["Remaining"] = "الرصيد المتبقي / الفائض",
                    ["BillsStatus"] = "الحالة"
                };

                foreach (DataColumn c in dt10.Columns)
                {
                    bool hidden =
                        c.ColumnName.Equals("order_", StringComparison.OrdinalIgnoreCase) ||
                        c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase) ||
                        c.ColumnName.Equals("BillChargeTypeID", StringComparison.OrdinalIgnoreCase) ||
                        c.ColumnName.Equals("BillsStatusID", StringComparison.OrdinalIgnoreCase);

                    var type = c.DataType;

                    dynamicColumns_general.Add(new TableColumn
                    {
                        Field = c.ColumnName,
                        Label = generalHeaders.TryGetValue(c.ColumnName, out var label)
                            ? label
                            : c.ColumnName,

                        Type = type == typeof(decimal) ||
                               type == typeof(int) ||
                               type == typeof(long)
                            ? "number"
                            : "text",

                        Sortable = true,
                        Visible = !hidden
                    });
                }

                foreach (DataRow r in dt10.Rows)
                {
                    var row = new Dictionary<string, object?>(
                        StringComparer.OrdinalIgnoreCase);

                    foreach (DataColumn c in dt10.Columns)
                    {
                        row[c.ColumnName] =
                            r[c] == DBNull.Value ? null : r[c];
                    }

                    row["FullName_A"] = generalResidentName;
                    row["NationalID"] = generalResidentNationalID;

                    rowsList_general.Add(row);
                }
            }

            bool hasresident = true;

            if (!string.IsNullOrWhiteSpace(NationalID_) && (dt1 == null || dt1.Rows.Count == 0))
            {
                hasresident = false;
                TempData["Error"] = "لم يتم العثور على نتائج لرقم الهوية: " + NationalID_;


            }




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



            if (LastActionTypeIDvalue == "51")
            {
                readyToSend = true;
            }

            if (LastActionTypeIDvalue == "57" && readyToSendAmount == 0)
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
           // bool canFinancialAuditForUser = false;
            bool canFINANCIALSETTLEMENTFORUSER = false;
            bool canREVIEWCLAIMSANDPAYMENTSFORUSER = false;
            bool canPAYMENTANDREFUNDFORUSER = false;
            bool canINSERTGENERALBALANCEREFUND = false;
            bool canCANCELGENERALBALANCEREFUND = false;
            bool canLINKGENERALBALANCETOBUILDING = false;
            bool canCANCELGENERALBALANCEBUILDINGALLOCATION = false;





            //List<OptionItem> PayPaymentTypeOptions = new();
            //List<OptionItem> RefundPaymentTypeOptions = new();
            //List<OptionItem> BillChargeTypeOptions = new();
            //List<OptionItem> billPaymentTypeOptions = new();
            //List<OptionItem> SETTLEMENTOptions = new();


            //JsonResult? result;
            //string json;


            List<OptionItem> PayPaymentTypeOptions = new();
            List<OptionItem> RefundPaymentTypeOptions = new();
            List<OptionItem> BillChargeTypeOptions = new();




            FormConfig form = new();

            try
            {


                // Load DDL data once using the request-scoped service.
                // No NationalID: preserve the original GetDDLValues contract.
                DataSet ddlDs = await requestDataLoad
                    .GetDataLoadDataSetAsync(ddlParameters);

                static List<OptionItem> ReadOptions(
                    DataSet source,
                    int tableIndex,
                    string textColumn,
                    string valueColumn)
                {
                    if (tableIndex < 0 ||
                        tableIndex >= source.Tables.Count)
                    {
                        throw new InvalidOperationException(
                            $"DDL table index {tableIndex} not found.");
                    }

                    DataTable table = source.Tables[tableIndex];

                    if (!table.Columns.Contains(textColumn) ||
                        !table.Columns.Contains(valueColumn))
                    {
                        throw new InvalidOperationException(
                            $"DDL columns mismatch at table {tableIndex}.");
                    }

                    var options = new List<OptionItem>();

                    foreach (DataRow row in table.Rows)
                    {
                        string value = row[valueColumn]
                            ?.ToString()?.Trim() ?? "";

                        string text = row[textColumn]
                            ?.ToString()?.Trim() ?? "";

                        if (!string.IsNullOrEmpty(value))
                        {
                            options.Add(new OptionItem
                            {
                                Value = value,
                                Text = text
                            });
                        }
                    }

                    if (options.Count == 0)
                    {
                        options.Add(new OptionItem
                        {
                            Value = "-1",
                            Text = "لاتوجد خيارات"
                        });
                    }

                    return options;
                }

                RefundPaymentTypeOptions = ReadOptions(
                    ddlDs,
                    4,
                    "billPaymentTypeName_A",
                    "billPaymentTypeID");

                PayPaymentTypeOptions = ReadOptions(
                    ddlDs,
                    5,
                    "billPaymentTypeName_A",
                    "billPaymentTypeID");

                BillChargeTypeOptions = ReadOptions(
                    ddlDs,
                    6,
                    "BillChargeTypeName_A",
                    "BillChargeTypeID");

                // END DDL


                //// ---------------------- RentbillPaymentTypeOptions ----------------------

                //    result = await _CrudController.GetDDLValues(
                //         "billPaymentTypeName_A", "billPaymentTypeID", "4", PageName, usersId, IdaraId, HostName
                //    ) as JsonResult;


                //json = JsonSerializer.Serialize(result!.Value);

                //RefundPaymentTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                ////// ---------------------- ServicebillPaymentTypeOptions ----------------------

                //    result = await _CrudController.GetDDLValues(
                //          "billPaymentTypeName_A", "billPaymentTypeID", "5", PageName, usersId, IdaraId, HostName
                //     ) as JsonResult;

                //json = JsonSerializer.Serialize(result!.Value);

                // PayPaymentTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                ////// ---------------------- BillChargeTypeOptions ----------------------

                //result = await _CrudController.GetDDLValues(
                //         "BillChargeTypeName_A", "BillChargeTypeID", "6", PageName, usersId, IdaraId, HostName
                //    ) as JsonResult;

                //json = JsonSerializer.Serialize(result!.Value);

                //BillChargeTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                // //// ---------------------- rankOptions ----------------------
                // result = await _CrudController.GetDDLValues(
                //     "billPaymentTypeName_A", "billPaymentTypeID", "8", nameof(FinancialAuditForUser), usersId, IdaraId, HostName
                //) as JsonResult;


                // json = JsonSerializer.Serialize(result!.Value);

                // billPaymentTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                // //// ---------------------- SETTLEMENTOptions ----------------------
                // result = await _CrudController.GetDDLValues(
                //     "billPaymentTypeName_A", "billPaymentTypeID", "10", nameof(FinancialAuditForUser), usersId, IdaraId, HostName
                //) as JsonResult;


                // json = JsonSerializer.Serialize(result!.Value);

                // SETTLEMENTOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


                //// ---------------------- END DDL ----------------------


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
                    Placeholder="1xxxxxxxxx",
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
                    NavUrl="/IncomeSystem/FinancialAuditForUser", // الصفحة الهدف
                    NavKey="U",                            // اسم باراميتر الـ QueryString

                    }
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

                        //if (permissionName.Equals("FinancialAuditForUser", StringComparison.OrdinalIgnoreCase))
                        //{
                        //    canFinancialAuditForUser = true;
                        //}
                        if (permissionName.Equals("FINANCIALSETTLEMENTFORUSER", StringComparison.OrdinalIgnoreCase))
                        {
                            canFINANCIALSETTLEMENTFORUSER = true;
                        }
                        if (permissionName.Equals("REVIEWCLAIMSANDPAYMENTSFORUSER", StringComparison.OrdinalIgnoreCase))
                        {
                            canREVIEWCLAIMSANDPAYMENTSFORUSER = true;
                        }
                        if (permissionName.Equals("PAYMENTANDREFUNDFORUSER", StringComparison.OrdinalIgnoreCase))
                        {
                            canPAYMENTANDREFUNDFORUSER = true;
                        }
                        if (permissionName.Equals("INSERTGENERALBALANCEREFUND",StringComparison.OrdinalIgnoreCase))
                        {
                            canINSERTGENERALBALANCEREFUND = true;
                        }

                        if (permissionName.Equals("CANCELGENERALBALANCEREFUND",StringComparison.OrdinalIgnoreCase))
                        {
                            canCANCELGENERALBALANCEREFUND = true;
                        }

                        if (permissionName.Equals("LINKGENERALBALANCETOBUILDING", StringComparison.OrdinalIgnoreCase))
                        {
                            canLINKGENERALBALANCETOBUILDING = true;
                        }

                        if (permissionName.Equals("CANCELGENERALBALANCEBUILDINGALLOCATION",StringComparison.OrdinalIgnoreCase))
                        {
                            canCANCELGENERALBALANCEBUILDINGALLOCATION = true;
                        }

                    }



                    if (dt1 != null && dt1.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField = "order_";
                        var possibleIdNames = new[] { "order_", "Order_", "Id", "ID" };
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
                            bool isorder_ = c.ColumnName.Equals("order_", StringComparison.OrdinalIgnoreCase);


                           

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                 ,
                                Visible = !(isfirstName_A || isfirstName_E || issecondName_A || issecondName_E || isthirdName_A || isthirdName_E || islastName_A || islastName_E || isrankID_FK || ismilitaryUnitID_FK || ismartialStatusID_FK || isnationalityID_FK || isgenderID_FK || isFullName_E || isbirthdate || isnote || isIdaraID || isIdaraName || isbuildingDetailsID || isLastActionID || isLastActionTypeID || isActionID || isBillsStatusID || isLastActionID || isLastActionExtendReasonTypeID || isLastActionDate || isorder_)
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


                    if (dt2 != null && dt2.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField_dt3 =
                                    dt2.Columns.Cast<DataColumn>()
                                       .FirstOrDefault(c =>
                                           c.ColumnName.Equals("RowId", StringComparison.OrdinalIgnoreCase) ||
                                           c.ColumnName.Equals("order_", StringComparison.OrdinalIgnoreCase) ||
                                           c.ColumnName.Equals("Order_", StringComparison.OrdinalIgnoreCase) ||
                                           c.ColumnName.Equals("Id", StringComparison.OrdinalIgnoreCase) ||
                                           c.ColumnName.Equals("ID", StringComparison.OrdinalIgnoreCase))
                                       ?.ColumnName
                                    ?? dt2.Columns[0].ColumnName;

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
                        foreach (DataColumn c in dt2.Columns)
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
                                           || c.ColumnName.Equals("order_", StringComparison.OrdinalIgnoreCase)
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
                        foreach (DataRow r in dt2.Rows)
                        {
                            var dict3 = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt2.Columns)
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


                    if (dt9 != null && dt9.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField_dt10 =
                                    dt9.Columns.Cast<DataColumn>()
                                       .FirstOrDefault(c =>
                                           c.ColumnName.Equals("order_", StringComparison.OrdinalIgnoreCase) ||
                                           c.ColumnName.Equals("order_", StringComparison.OrdinalIgnoreCase))
                                       ?.ColumnName
                                    ?? dt9.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap10 = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            

                           
                            ["buildingDetailsNo"] = "رقم المبنى",
                            ["Remaining"] = "اجمالي المتبقي او الفائض",
                            ["SumBillsTotalPrice"] = "اجمالي المطالبات",
                            ["SumTotalPaidBills"] = "اجمالي المدفوعات",
                            ["buildingRentAmount"] = "ايجار المبنى",
                            ["BillsStatus"] = "الحالة"
                            

                        };

                        // الأعمدة
                        foreach (DataColumn c in dt9.Columns)
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
                                           || c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase)
                                           || c.ColumnName.Equals("order_", StringComparison.OrdinalIgnoreCase)
                                           || c.ColumnName.Equals("CanLinkGeneralBalance", StringComparison.OrdinalIgnoreCase)
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
                        foreach (DataRow r in dt9.Rows)
                        {
                            var dict10 = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt9.Columns)
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
            catch (Exception)
            {
                ViewBag.BuildingTypeDataSetError = "حدث خطأ أثناء تحميل البيانات. يرجى المحاولة مرة أخرى.";
            }



            var currentUrl = Request.Path + Request.QueryString;

           

            // UPDATE fields
            var BillsFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "REVIEWCLAIMSANDPAYMENTSFORUSER" },
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
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "REVIEWCLAIMSANDPAYMENTSFORUSER" },
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
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "PAYMENTANDREFUNDFORUSER" },
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
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "PAYMENTANDREFUNDFORUSER" },
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
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "FINANCIALSETTLEMENTFORUSER" },
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
                new FieldConfig { Name = "p30", Label = "الرصيد المسحوب اليه", Type = "select", ColCss = "4", Required = true,Options = BillChargeTypeOptions },
                new FieldConfig { Name = "p05", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p06", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true,Value=buildingDetailsNovalue },
                new FieldConfig { Name = "p07", Label = "SumBillsTotalPrice", Type = "hidden", ColCss = "3", Readonly = true,Value=buildingDetailsIDvalue },
                new FieldConfig { Name = "p08", Label = "SumTotalPaidBills", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "Remining", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "BillsStatus", Type = "hidden", ColCss = "3", Required = true },
                new FieldConfig { Name = "p11", Label = "BillsStatusID", Type = "hidden", ColCss = "3", Required = true},


                new FieldConfig { Name = "p12", Label = "نوع العملية", Type = "hidden", ColCss = "3", Required = true, Value="6" },
               // new FieldConfig { Name = "p13", Label = "رقم العملية", Type = "hidden", ColCss = "3", Required = true },
               new FieldConfig
{
    Name = "p13",
    Label = "معرف عملية التسوية",
    Type = "hidden",
    Value = Guid.NewGuid().ToString("N")
},
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

            var extraMetaBills = new Dictionary<string, object?>
            {
                ["extraSlotKey"] = "m1",
                ["extraTitle"] = "بيانات المطالبات",
                ["useRowExtra"] = true,
                ["lazyExtra"] = true,
                ["extraEndpoint"] = "/crud/extradataload",
                ["allowNoSelection"] = true,
                ["emptyText"] = "لاتوجد مطالبات مسجلة",

                // المهم
                ["extraLoadOnOpen"] = true,

                ["ctx"] = extraBillsCtx,
                ["extraRequest"] = extraBillsRequestBase,

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
       "BillChargeTypeName_A","FullName_A","buildingDetailsNo","amount","deductName","buildingPaymentTypeName_A"
    },
               

                ["headerMap"] = new Dictionary<string, string>
                {
                    ["FullName_A"] = "الاسم",
                    ["buildingDetailsNo"] = "المبنى",
                    ["BillChargeTypeName_A"] = "الخدمة",
                    ["deductName"] = "نوع السداد",
                    ["buildingPaymentTypeName_A"] = "طريقة السداد",
                    ["amount"] = "المبلغ"
                }
            };


            var dsModel = new SmartTableDsModel
            {

                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageTitle = "التدقيق المالي العام",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns_dt3.Select(c => c.Field).Take(4).ToList(),
                Searchable = false,
                AllowExport = false,
                ShowRowBorders = false,
                EnablePagination = false, // جديد
                ShowPageSizeSelector = false, // جديد
                PanelTitle = "التدقيق المالي العام",
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

            // جدول الرصيد العام المستقل
            // عرض فقط، دون إجراءات مالية في هذه المرحلة

            var dsModelGeneral = new SmartTableDsModel
            {
                PageTitle = "التدقيق المالي العام",
                PanelTitle = "سدادت غير مرتبطه بمبنى",

                Columns = dynamicColumns_general,
                Rows = rowsList_general,
                RowIdField = "order_",

                PageSize = 10,
                Searchable = false,
                AllowExport = false,

                ShowToolbar = true,
                EnablePagination = false,
                ShowPageSizeSelector = false,
                ShowRowBorders = false,

                Selectable = true,

                RenderAsToggle = true,
                ToggleLabel = "سدادت غير مرتبطه بمبنى",
                ToggleIcon = "fa-solid fa-wallet",
                ToggleDefaultOpen = true,
                ShowToggleCount = false,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = false,
                    ShowSearch = false,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowExportPdf = false,
                    ShowPrint = false,
                    ShowPrint1 = false,
                    ShowPrint2 = false,
                    ShowPrint3 = false,
                    ShowFullscreen = false,
                    ShowDensityToggle = false,

                    ShowEdit = true,

                    Edit = new TableAction
                    {
                        Label = "إدارة السدادت غير مرتبطه بمبنى",
                        Icon = "fa-solid fa-wallet",
                        Color = "primary",
                        Show = true,
                        IsEdit = true,

                        OpenModal = false,
                        OpenDrawer = true,
                        DrawerId = "sf-general-balance-drawer",

                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,

                        DrawerTitleTemplate =
                 "إدارة السدادت غير مرتبطه بمبنى - {BillChargeTypeName_A}",

                        DrawerSubtitleTemplate =
                 " للمستفيد:  {FullName_A} صاحب الهوية رقم : {NationalID} ",

                        DrawerParamMap = new Dictionary<string, string>
                        {
                            ["parameter_01"] = "residentInfoID",
                            ["parameter_02"] = "BillChargeTypeID"
                        },

                        Meta = new Dictionary<string, object?>
                        {
                            ["extraEndpoint"] = "/crud/extradataload",

                            ["extraRequest"] = new Dictionary<string, object?>
                            {
                                ["pageName_"] = PageName,
                                ["ActionType"] = "GetGeneralBalancePaymentsByResident",
                                ["tableIndex"] = 0
                            }
                        }
                    }
                }
            };


            var generalRefundForm = new FormConfig
            {
                FormId = "GeneralBalanceRefundForm",
                Title = "إعادة مبلغ للمستفيد",
                Method = "post",
                ActionUrl = "/crud/insert",


                ShowSubmit = false,
                ShowReset = false,

                Fields = new List<FieldConfig>
    {
        new FieldConfig
        {
            Name = "pageName_",
            Type = "hidden",
            Value = PageName
        },
        new FieldConfig
        {
            Name = "ActionType",
            Type = "hidden",
            Value = "INSERTGENERALBALANCEREFUND"
        },
        new FieldConfig
        {
            Name = "redirectUrl",
            Type = "hidden",
            Value = currentUrl
        },
        new FieldConfig
        {
            Name = "p01",
            Type = "hidden"
        },
        new FieldConfig
        {
            Name = "p02",
            Type = "hidden"
        },
        new FieldConfig
        {
            Name = "p03",
            Label = "رقم السداد الأصلي",
            Type = "text",
            Readonly = true,
            Required = true,
            ColCss = "2"
        },
        new FieldConfig
        {
            Name = "p09",
            Label = "الرصيد المتاح للاعادة",
            Type = "text",
            Readonly = true,
            ColCss = "2"
        },
        new FieldConfig
        {
            Name = "p04",
            Label = "المبلغ المطلوب إعادته",
            Type = "text",
            TextMode = "money_sar",
            Icon = "/img/Saudi_Riyal_Symbol.svg",
            Required = true,
            ColCss = "2"
        },
        new FieldConfig
        {
            Name = "p05",
            Label = "تاريخ إعادة المبلغ",
            Type = "date",
            Required = true,
            ColCss = "3"
        },
        new FieldConfig
        {
            Name = "p06",
            Label = "رقم مستند الإعادة",
            Type = "text",
            Required = true,
            MaxLength = 200,
            ColCss = "3"
        },
        new FieldConfig
        {
            Name = "p07",
            Label = "تفاصيل إعادة المبلغ",
            Type = "textarea",
            Required = true,
            ColCss = "12"
        },
        new FieldConfig
        {
            Name = "p08",
            Type = "hidden",
            Value = Guid.NewGuid().ToString("D")
        }
    },

                Buttons = new List<FormButtonConfig>
{
    new FormButtonConfig
    {
        Text = "تنفيذ الإعادة",
        Type = "submit",
        Color = "success",
        Icon = "fa-solid fa-check"
    },
    new FormButtonConfig
    {
        Text = "إلغاء",
        Type = "button",
        Color = "secondary"
    }
}
            };


            var cancelGeneralBalanceRefundForm = new FormConfig
            {
                FormId = "GeneralBalanceRefundCancelForm",
                Title = "إلغاء معالجة الإعادة",

                LabelText = "سيؤدي الإلغاء إلى إلغاء العملية كاملة، حتى لو كانت موزعة على عدة سدادات.",

                Method = "post",
                ActionUrl = "/crud/insert",

                // المعاينة فقط - لا يوجد تنفيذ مالي الآن
                ShowSubmit = false,
                ShowReset = false,

                Buttons = new List<FormButtonConfig>
{
    new FormButtonConfig
    {
        Text = "تأكيد إلغاء المعالجة",
        Type = "submit",
        Color = "danger",
        Icon = "fa-solid fa-ban"
    }
},

                Fields = new List<FieldConfig>
    {
        new FieldConfig
        {
            Name = "pageName_",
            Type = "hidden",
            Value = PageName
        },
        new FieldConfig
        {
            Name = "ActionType",
            Type = "hidden",
            Value = "CANCELGENERALBALANCEREFUND"
        },
        new FieldConfig
        {
            Name = "redirectUrl",
            Type = "hidden",
            Value = currentUrl
        },
        new FieldConfig
        {
            Name = "p22",
            Type = "hidden"
        },
        new FieldConfig
        {
            Name = "p07",
            Label = "سبب إلغاء المعالجة",
            Type = "textarea",
            Required = true,
            RequiredMsg = "سبب الإلغاء مطلوب",
            MaxLength = 1000,
            ColCss = "12"
        }
    }
            };

            // إلغاء ربط الرصيد بمبنى - مجهز ومخفي مؤقتًا
            var cancelGeneralBalanceBuildingForm = new FormConfig
            {
                FormId = "GeneralBalanceBuildingCancelForm",
                Title = "إلغاء ربط الرصيد بمبنى",
                Method = "post",
                ActionUrl = "/crud/insert",

                ShowSubmit = false,
                ShowReset = false,

                Fields = new List<FieldConfig>
    {
        new FieldConfig
        {
            Name = "pageName_",
            Type = "hidden",
            Value = PageName
        },
        new FieldConfig
        {
            Name = "ActionType",
            Type = "hidden",
            Value = "CANCELGENERALBALANCEBUILDINGALLOCATION"
        },
        new FieldConfig
        {
            Name = "redirectUrl",
            Type = "hidden",
            Value = currentUrl
        },
        new FieldConfig
        {
            Name = "p22",
            Type = "hidden"
        },
        new FieldConfig
        {
            Name = "p07",
            Label = "سبب إلغاء الربط",
            Type = "textarea",
            Required = true,
            RequiredMsg = "سبب الإلغاء مطلوب",
            MaxLength = 1000,
            ColCss = "12"
        }
    },

                Buttons = new List<FormButtonConfig>
    {
        new FormButtonConfig
        {
            Text = "تأكيد إلغاء الربط",
            Type = "submit",
            Color = "danger",
            Icon = "fa-solid fa-ban"
        }
    }
            };

            // ==============================================
            // ربط الرصيد العام بمبنى - قائمة المباني المؤهلة
            // ==============================================

            var generalBalanceLinkBuildingOptions = new List<OptionItem>
{
    //new OptionItem
    //{
    //    Value = "-1",
    //    Text = "اختر المبنى"
    //}
};

            if (canLINKGENERALBALANCETOBUILDING &&
                long.TryParse(residentInfoIDvalue, out var linkResidentId) &&
                linkResidentId > 0)
            {
                var linkBuildingDs =
                    await _mastersServies.GetExtraDataLoadDataSetAsync(
                        new Dictionary<string, object?>
                        {
                            ["pageName_"] = "FinancialAuditForUser",
                            ["ActionType"] =
                                "GetGeneralBalanceLinkBuildingsByResident",
                            ["idaraID"] = IdaraId,
                            ["entrydata"] = usersId,
                            ["hostname"] = HostName,
                            ["parameter_01"] = linkResidentId
                        });

                if (linkBuildingDs.Tables.Count > 0)
                {
                    var linkBuildings = linkBuildingDs.Tables[0];

                    if (linkBuildings.Columns.Contains("buildingDetailsID") &&
                        linkBuildings.Columns.Contains("buildingDetailsNo"))
                    {
                        foreach (DataRow b in linkBuildings.Rows)
                        {
                            var id = b["buildingDetailsID"]?
                                .ToString()?.Trim();

                            var no = b["buildingDetailsNo"]?
                                .ToString()?.Trim();

                            if (string.IsNullOrWhiteSpace(id))
                                continue;

                            generalBalanceLinkBuildingOptions.Add(
                                new OptionItem
                                {
                                    Value = id,
                                    Text = string.IsNullOrWhiteSpace(no)
                                        ? id
                                        : no //+ " (" + id + ")"
                                });
                        }
                    }
                }
            }


            // ==============================================
            // SmartForm - ربط الرصيد العام بمبنى
            // ==============================================

            var generalBalanceLinkForm = new FormConfig
            {
                FormId = "GeneralBalanceLinkBuildingForm",
                Title = "ربط الرصيد العام بمبنى",
                Method = "post",
                ActionUrl = "/crud/insert",

                ShowSubmit = false,
                ShowReset = false,

                Fields = new List<FieldConfig>
    {
        new FieldConfig
        {
            Name = "pageName_",
            Type = "hidden",
            Value = PageName
        },

        new FieldConfig
        {
            Name = "ActionType",
            Type = "hidden",
            Value = "LINKGENERALBALANCETOBUILDING"
        },

        new FieldConfig
        {
            Name = "redirectUrl",
            Type = "hidden",
            Value = currentUrl
        },

        new FieldConfig
        {
            Name = "p01",
            Type = "hidden"
        },

        new FieldConfig
        {
            Name = "p02",
            Type = "hidden"
        },

        new FieldConfig
        {
            Name = "p03",
            Label = "رقم السداد الأصلي",
            Type = "text",
            Readonly = true,
            Required = true,
            ColCss = "3"
        },

        new FieldConfig
        {
            Name = "p10",
            Label = "المبلغ المتاح",
            Type = "text",
            Readonly = true,
            ColCss = "2"
        },

        new FieldConfig
        {
            Name = "p09",
            Label = "المبنى المراد الربط به",
            Type = "select",
            Options = generalBalanceLinkBuildingOptions,
            Select2 = false,
            Placeholder = "اختر المبنى",
            Required = true,
            RejectValue = "-1",
            RejectMsg = "اختر مبنى صحيحًا",
            ColCss = "3"
        },

        new FieldConfig
        {
            Name = "p04",
            Label = "مبلغ الربط",
            Type = "text",
            TextMode = "money_sar",
            Icon = "/img/Saudi_Riyal_Symbol.svg",
            Required = true,
            ColCss = "2"
        },

        new FieldConfig
        {
            Name = "p05",
            Label = "تاريخ الربط",
            Type = "hidden",
            Value = DateTime.Today.ToString("yyyy-MM-dd"),
            Required = true,
            ColCss = "3"
        },

        new FieldConfig
        {
            Name = "p06",
            Label = "رقم مستند التحويل",
            Type = "text",
            MaxLength = 50,
            Required = true,
            ColCss = "2"
        },

        new FieldConfig
        {
            Name = "p07",
            Label = "سبب / تفاصيل الربط",
            Type = "textarea",
            MaxLength = 1000,
            Required = true,
            ColCss = "12"
        },

        new FieldConfig
        {
            Name = "p08",
            Type = "hidden",
            Value = Guid.NewGuid().ToString("D")
        }
    },

                Buttons = new List<FormButtonConfig>
    {
        new FormButtonConfig
        {
            Text = "تنفيذ الربط",
            Type = "submit",
            Color = "success",
            Icon = "fa-solid fa-link"
        },

        new FormButtonConfig
        {
            Text = "إلغاء",
            Type = "button",
            Color = "secondary"
        }
    }
            };

            // Drawer الرصيد العام
            // مرحلة أولى: اختبار العرض فقط، دون عمليات مالية.

            dsModel.Toolbar.Drawers = new List<SmartDrawerConfig>
{
    new SmartDrawerConfig
    {
        Id = "sf-general-balance-drawer",
        Show = true,

        Title = "إدارة الرصيد العام",
        Subtitle = "تفاصيل حركات الرصيد العام للمستفيد",
        Icon = "fa-solid fa-wallet",

        Size = SmartDrawerSize.Large,
        Side = SmartDrawerSide.Left,

        Table = new SmartTableDsModel
        {
            PageTitle = "تفاصيل الرصيد العام",
            PanelTitle = "السدادات",

            RowIdField = "paymentID",

            Rows = new List<Dictionary<string, object?>>(),

            Columns = new List<TableColumn>
{
    new TableColumn
    {
        Field = "paymentID",
        Label = "رقم السداد",
        Type = "number",
        Visible = true
    },
    new TableColumn
    {
        Field = "issueYear",
        Label = "السنة",
        Type = "number",
        Visible = true
    },
    new TableColumn
    {
        Field = "issueMonth",
        Label = "الشهر",
        Type = "number",
        Visible = true
    },
    new TableColumn
    {
        Field = "paymentDate",
        Label = "تاريخ السداد",
        Type = "text",
        Visible = true
    },
    new TableColumn
    {
        Field = "OriginalAmount",
        Label = "المبلغ الأصلي",
        Type = "number",
        Visible = true
    },
    new TableColumn
    {
        Field = "LegacyUsed",
        Label = "المعالج تاريخيًا",
        Type = "number",
        Visible = true
    },
    new TableColumn
    {
        Field = "NewRefundUsed",
        Label = "الإعادات الجديدة",
        Type = "number",
        Visible = true
    },
    new TableColumn
{
    Field = "BuildingAllocated",
    Label = "المرتبط بالمباني",
    Type = "number",
    Visible = true
},
    new TableColumn
    {
        Field = "AvailableAmount",
        Label = "المبلغ المتاح",
        Type = "number",
        Visible = true
    },
        new TableColumn
    {
        Field = "ProcessingStatus",
        Label = "حالة المعالجة",
        Type = "text",
        Visible = true
    }
},

// =======================================
// إجراءات صفوف جدول السدادات
// =======================================
RowActions = new List<TableAction>
{
    new TableAction
    {
        Label = "سجل الإعادات",
        Icon = "fa-solid fa-clock-rotate-left",
        Color = "info",

        Placement = TableActionPlacement.ActionsMenu,

        OpenAccordionModal = true,
        AccordionId = "sf-refund-accordion-test"
    }
},

PageSize = 10,
Searchable = false,
Selectable = true,
ShowToolbar = true,
AllowExport = false,

Toolbar = new TableToolbarConfig
{
    ShowRefresh = false,
    ShowColumns = false,
    ShowSearch = false,
    ShowExportCsv = false,
    ShowExportExcel = false,
    ShowExportPdf = false,
    ShowPrint = false,
    ShowFullscreen = false,
    ShowDensityToggle = false,

    ShowEdit = canINSERTGENERALBALANCEREFUND,
    ShowEdit2 = canINSERTGENERALBALANCEREFUND,
    ShowEdit1 = canLINKGENERALBALANCETOBUILDING
    && generalBalanceLinkBuildingOptions.Count > 1,

    Edit = new TableAction
    {
        Label = "إعادة مبلغ للمستفيد",
        Icon = "fa-solid fa-money-bill-transfer",
        Color = "warning",

        Show = canINSERTGENERALBALANCEREFUND,
        IsEdit = true,

        OpenModal = true,
        ModalTitle = "إعادة مبلغ للمستفيد",
        OpenForm = generalRefundForm,

        Meta = new Dictionary<string, object?>
        {
            ["formParamMap"] = new Dictionary<string, string>
            {
                ["p01"] = "residentInfoID",
                ["p02"] = "BillChargeTypeID",
                ["p03"] = "paymentID",
                ["p09"] = "AvailableAmount"
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
                    Field = "IsEligible",
                    Op = "eq",
                    Value = "0",
                    Message = "السداد غير مؤهل للمعالجة"
                },
                new TableActionRule
                {
                    Field = "ProcessingStatus",
                    Op = "eq",
                    Value = "تمت المعالجة",
                    Message = "تمت معالجة كامل مبلغ السداد"
                },
                new TableActionRule
                {
                    Field = "ProcessingStatus",
                    Op = "eq",
                    Value = "تعارض مالي - يتطلب المراجعة",
                    Message = "يجب مراجعة التعارض المالي أولاً"
                }
            }
        }
    }

    ,

// =======================================
// زر استعراض عمليات إعادة المبالغ
// =======================================


Edit2 = new TableAction
{
    Label = "استعراض الإعادات",
    Icon = "fa-solid fa-clock-rotate-left",
    Color = "info",

    Placement = TableActionPlacement.Button,

    OpenAccordionModal = true,
    AccordionId = "sf-refund-accordion-test",

      RequireSelection = true,
    MinSelection = 1,
    MaxSelection = 1
},

// ==============================================
// ربط الرصيد العام بمبنى
// ==============================================
Edit1 = new TableAction
{
    Label = "ربط الرصيد بمبنى",
    Icon = "fa-solid fa-link",
    Color = "success",

    Show = canLINKGENERALBALANCETOBUILDING
        && generalBalanceLinkBuildingOptions.Count > 1,

    IsEdit = true,

    OpenModal = true,
ModalTitle = "ربط الرصيد العام بمبنى",

ModalMessage =
    "تنبيه: عند تنفيذ ربط الرصيد العام بالمبنى، " +
    "سيتم تحويل المبلغ المحدد من الرصيد العام إلى رصيد المبنى. " +
    "لا يمكن إلغاء هذا الربط أو التراجع عنه . " +
    "يرجى التأكد من صحة السداد والمبنى والمبلغ قبل تنفيذ العملية.",

ModalMessageIcon = "fa-solid fa-triangle-exclamation",

ModalMessageClass =
    "mb-4 rounded-lg border border-amber-200 " +
    "bg-amber-50 p-4 text-amber-900",

OpenForm = generalBalanceLinkForm,

    Meta = new Dictionary<string, object?>
    {
        ["formParamMap"] = new Dictionary<string, string>
        {
            ["p01"] = "residentInfoID",
            ["p02"] = "BillChargeTypeID",
            ["p03"] = "paymentID",
            ["p10"] = "AvailableAmount"
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
                Field = "IsEligible",
                Op = "eq",
                Value = "0",
                Message = "السداد غير مؤهل للربط"
            },
            new TableActionRule
            {
                Field = "ProcessingStatus",
                Op = "eq",
                Value = "تمت المعالجة",
                Message = "لا يوجد مبلغ متاح للربط"
            },
            new TableActionRule
            {
                Field = "ProcessingStatus",
                Op = "eq",
                Value = "تعارض مالي - يتطلب المراجعة",
                Message = "يوجد تعارض مالي يتطلب المراجعة"
            }
        }
    }
}
}
        },

       Accordion = new SmartAccordionConfig
{
    Id = "sf-refund-accordion-test",

    Title = "سجل عمليات إعادة المبالغ",

    Description = "عمليات إعادة المبالغ المرتبطة بالسداد المحدد",

    RenderInModal = true,

    ModalTitle = "سجل عمليات إعادة المبالغ",

    AllowMultipleOpen = false,

    // البحث والتصفية والترقيم
    Searchable = true,
    EnableStatusFilter = true,
    ShowSummary = true,
    EnablePagination = true,

    PageSize = 5,
    PageSizes = new List<int> { 5, 10, 20 },


   Actions = (
    canCANCELGENERALBALANCEREFUND
    ? new List<SmartAccordionAction>
    {
        new SmartAccordionAction
        {
            Key = "CANCELGENERALBALANCEREFUND",
            Text = "إلغاء المعالجة",
            Icon = "fa-solid fa-ban",
            Tone = "danger",

            VisibleWhenField = "RefundStatusText",
            VisibleWhenEquals = "مؤكدة",

            OpenForm = cancelGeneralBalanceRefundForm,

            FormParamMap = new Dictionary<string, string>
            {
                ["p22"] = "RefundID"
            }
        }
    }
    : new List<SmartAccordionAction>()
)
//.Concat(
//    false && canCANCELGENERALBALANCEBUILDINGALLOCATION
//    ? new List<SmartAccordionAction>
.Concat(
    canCANCELGENERALBALANCEBUILDINGALLOCATION
    ? new List<SmartAccordionAction>
    {
        new SmartAccordionAction
        {
            Key = "CANCELGENERALBALANCEBUILDINGALLOCATION",
            Text = "إلغاء ربط الرصيد بالمبنى",
            Icon = "fa-solid fa-link-slash",
            Tone = "danger",

            VisibleWhenField = "RefundStatusText",
            VisibleWhenEquals = "مرتبطة بمبنى",

            OpenForm = cancelGeneralBalanceBuildingForm,

            FormParamMap = new Dictionary<string, string>
            {
                ["p22"] = "RefundID"
            }
        }
    }
    : new List<SmartAccordionAction>()
)
.ToList(),
    


    // ==========================================
    // تحميل الإعادات الحقيقية من قاعدة البيانات
    // ==========================================
    DataSource = new SmartAccordionDataSource
    {
        Endpoint = "/crud/extradataload",

        PageName = "FinancialAuditForUser",

        ActionType = "GetGeneralRefundsByPayment",

        TableIndex = 0,

        // إرسال رقم السداد الذي اختاره المستخدم
        ParameterMap = new Dictionary<string, string>
        {
            ["parameter_01"] = "paymentID"
        },

        // معرف كل عملية إعادة
        IdField = "RefundID",

        // بيانات رأس البطاقة
        TitleField = "AccordionTitle",
        SubtitleField = "RefundDateText",
        AmountField = "AllocatedAmountText",
        StatusField = "RefundStatusText",
        StatusToneField = "RefundStatusTone",

        // ==========================================
        // التفاصيل التي تظهر عند توسيع العملية
        // ==========================================
        DetailFields = new List<SmartAccordionFieldMap>
        {
            new SmartAccordionFieldMap
            {
                Label = "رقم مستند الإعادة",
                Field = "RefundReference"
            },

            new SmartAccordionFieldMap
            {
                Label = "تاريخ الإعادة",
                Field = "RefundDateText"
            },

            new SmartAccordionFieldMap
            {
                Label = "رقم السداد الأصلي",
                Field = "SelectedPaymentID"
            },

            new SmartAccordionFieldMap
            {
                Label = "المبلغ المعاد من هذا السداد",
                Field = "AllocatedAmountText"
            },

            new SmartAccordionFieldMap
            {
                Label = "إجمالي مبلغ عملية الإعادة",
                Field = "RefundAmountText"
            },

            new SmartAccordionFieldMap
            {
                Label = "تفاصيل الإعادة",
                Field = "RefundDetails"
            },

            new SmartAccordionFieldMap
            {
                Label = "رقم الحركة المالية",
                Field = "LedgerPaymentIDText"
            },

            new SmartAccordionFieldMap
            {
                Label = "حالة المطابقة المحاسبية",
                Field = "LedgerStatusText"
            },

            new SmartAccordionFieldMap
            {
                Label = "سبب الإلغاء",
                Field = "CancellationReasonText"
            }
        },

        // التحميل عند الضغط على زر الاستعراض فقط
        LoadOnPageReady = false,

        ReloadOnDrawerOpen = false
    }
},

        EmptyText = "لا توجد حركات للعرض"
    }
};

            var selectedFields = AllRemaining < 0 ? PayMoneyFields : RefundMoneyFields;



            var dsModel3 = new SmartTableDsModel
            {
                PageTitle = "التدقيق المالي العام",
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
                PanelTitle = "التدقيق المالي العام",
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

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowEdit = canREVIEWCLAIMSANDPAYMENTSFORUSER,
                    ShowEdit1 = canREVIEWCLAIMSANDPAYMENTSFORUSER,
                    ShowEdit2 = canPAYMENTANDREFUNDFORUSER,
                    ShowDelete = canFINANCIALSETTLEMENTFORUSER,
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
                        OpenModal = false,
                        OpenDrawer = true,
                        DrawerId = "sf-audit-bills-drawer",

                        OnBeforeOpenJs =
    "const d=document.getElementById('sf-audit-bills-drawer');" +
    "if(d&&row){" +
    "d.dataset.printResidentId=String(row.p02??'');" +
    "d.dataset.printServiceId=String(row.p03??'');" +
    "d.dataset.printBuildingId=String(row.p05??'');" +
    "}",

                        DrawerParamMap = new Dictionary<string, string>
                        {
                            ["parameter_01"] = "p02",
                            ["parameter_02"] = "p03",
                            ["parameter_03"] = "p05"
                        },

                        DrawerSubtitleTemplate =
    "الخدمة: {BillChargeTypeName_A} | المبنى: {buildingDetailsNo}",

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
                        OpenModal = false,
                        OpenDrawer = true,
                        DrawerId = "sf-audit-payments-drawer",

                        OnBeforeOpenJs =
    "const d=document.getElementById('sf-audit-payments-drawer');" +
    "if(d&&row){" +
    "d.dataset.printResidentId=String(row.p02??'');" +
    "d.dataset.printServiceId=String(row.p03??'');" +
    "d.dataset.printBuildingId=String(row.p05??'');" +
    "}",

                        DrawerParamMap = new Dictionary<string, string>
                        {
                            ["parameter_01"] = "p02",
                            ["parameter_02"] = "p03",
                            ["parameter_03"] = "p05"
                        },

                        DrawerSubtitleTemplate =
    "الخدمة: {BillChargeTypeName_A} | المبنى: {buildingDetailsNo}",

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


            // ============================================================
            // Financial Audit - Bills and Payments Drawers
            // ============================================================

            dsModel.Toolbar.Drawers = new List<SmartDrawerConfig>
{
    // ========================================
    // 1. Bills Drawer
    // ========================================
    new SmartDrawerConfig
    {
        Id = "sf-audit-bills-drawer",
        Show = true,
        Title = "استعراض المطالبات",
        Subtitle = "المطالبات المالية للمستفيد حسب الخدمة والمبنى",
        Icon = "fa-solid fa-file-invoice",
        Side = SmartDrawerSide.Left,
        Size = SmartDrawerSize.Large,

        Table = new SmartTableDsModel
        {
            StoredProcedureName = "",
            Operation = "select",

            Rows = new List<Dictionary<string, object?>>(),
            RowIdField = "BillsID",

            Columns = new List<TableColumn>
            {
                new TableColumn
                {
                    Field = "BillsID",
                    Label = "الرقم المرجعي",
                    Type = "number",
                    Visible = true,
                    Sortable = true
                },
                new TableColumn
                {
                    Field = "BillNumber",
                    Label = "رقم الفاتورة",
                    Type = "text",
                    Visible = true,
                    Sortable = true
                },
                new TableColumn
                {
                    Field = "BillChargeTypeName_A",
                    Label = "الخدمة",
                    Type = "text",
                    Visible = true,
                    Sortable = true
                },
                new TableColumn
                {
                    Field = "buildingDetailsNo",
                    Label = "رقم المبنى",
                    Type = "text",
                    Visible = true,
                    Sortable = true
                },
                new TableColumn
                {
                    Field = "TotalPrice",
                    Label = "المبلغ",
                    Type = "number",
                    Visible = true,
                    Sortable = true
                }
            },

            PageSize = 10,
            PageSizes = new List<int> { 10, 25, 50 },

            Searchable = true,
            Selectable = false,
            ShowToolbar = true,
            ShowColumnVisibility = true,
            EnablePagination = true,
            EnableCellCopy = true,
            AllowExport = false,

            Toolbar = new TableToolbarConfig
            {
                ShowRefresh = false,
                ShowColumns = true,
                ShowExportCsv = false,
                ShowExportExcel = false,
                ShowExportPdf = false,
                ShowPrint = false,
                ShowPrint1 = true,

Print1 = new TableAction
{
    Label = "طباعة المطالبات",
    Icon = "fa fa-print",
    Color = "primary",

   OnClickJs = @"
    const d = document.getElementById('sf-audit-bills-drawer');
    const r = Number(d?.dataset.printResidentId);
    const b = Number(d?.dataset.printBuildingId);
    const s = Number(d?.dataset.printServiceId);

    const u = (
        new URLSearchParams(window.location.search).get('U') ||
        document.querySelector('[name=NationalID]')?.value ||
        ''
    ).trim();

    if (!r || !b || !s || !u) {
        table.showToast(
            'بيانات المستفيد أو التقرير غير مكتملة، يرجى إعادة اختيار المستفيد',
            'error'
        );
        return;
    }

    sfPrintWithBusy(table, {
        pdf: 2,
        extraParams: {
            U: u,
            printResidentID: r,
            printBuildingID: b,
            printServiceID: s
        },
        busy: {
            title: 'طباعة المطالبات المالية'
        }
    });
"
},
            }
        }
    },

    // ========================================
    // 2. Payments Drawer
    // ========================================
    new SmartDrawerConfig
    {
        Id = "sf-audit-payments-drawer",
        Show = true,
        Title = "استعراض السدادات",
        Subtitle = "حركات السداد والتسويات المالية",
        Icon = "fa-solid fa-money-bill-transfer",
        Side = SmartDrawerSide.Left,
        Size = SmartDrawerSize.Large,

        Table = new SmartTableDsModel
        {
            StoredProcedureName = "",
            Operation = "select",

            Rows = new List<Dictionary<string, object?>>(),
            RowIdField = "paymentID",

            Columns = new List<TableColumn>
            {
                new TableColumn
                {
                    Field = "BillChargeTypeName_A",
                    Label = "الخدمة",
                    Type = "text",
                    Visible = true,
                    Sortable = true
                },
                new TableColumn
                {
                    Field = "deductName",
                    Label = "نوع السداد",
                    Type = "text",
                    Visible = true,
                    Sortable = true
                },
                new TableColumn
                {
                    Field = "FullName_A",
                    Label = "الاسم",
                    Type = "text",
                    Visible = true,
                    Sortable = true
                },
                new TableColumn
                {
                    Field = "buildingDetailsNo",
                    Label = "المبنى",
                    Type = "text",
                    Visible = true,
                    Sortable = true
                },
                new TableColumn
                {
                    Field = "amount",
                    Label = "المبلغ",
                    Type = "number",
                    Visible = true,
                    Sortable = true
                },
                new TableColumn
                {
                    Field = "buildingPaymentTypeName_A",
                    Label = "طريقة السداد",
                    Type = "text",
                    Visible = true,
                    Sortable = true
                }
            },

            PageSize = 10,
            PageSizes = new List<int> { 10, 25, 50 },

            Searchable = true,
            Selectable = false,
            ShowToolbar = true,
            ShowColumnVisibility = true,
            EnablePagination = true,
            EnableCellCopy = true,
            AllowExport = false,

            Toolbar = new TableToolbarConfig
            {
                ShowRefresh = false,
                ShowColumns = true,
                ShowExportCsv = false,
                ShowExportExcel = false,
                ShowExportPdf = false,
                ShowPrint = false,
                ShowPrint1 = true,

Print1 = new TableAction
{
    Label = "طباعة السدادات",
    Icon = "fa fa-print",
    Color = "primary",

    OnClickJs = @"
    const d = document.getElementById('sf-audit-payments-drawer');
    const r = Number(d?.dataset.printResidentId);
    const b = Number(d?.dataset.printBuildingId);
    const s = Number(d?.dataset.printServiceId);

    const u = (
        new URLSearchParams(window.location.search).get('U') ||
        document.querySelector('[name=NationalID]')?.value ||
        ''
    ).trim();

    if (!r || !b || !s || !u) {
        table.showToast(
            'بيانات المستفيد أو التقرير غير مكتملة، يرجى إعادة اختيار المستفيد',
            'error'
        );
        return;
    }

    sfPrintWithBusy(table, {
        pdf: 3,
        extraParams: {
            U: u,
            printResidentID: r,
            printBuildingID: b,
            printServiceID: s
        },
        busy: {
            title: 'طباعة السدادات المالية'
        }
    });
"
},
            }
        }
    }
};


            var dsModel10 = new SmartTableDsModel
            {
                PageTitle = "التدقيق المالي العام",
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
                PanelTitle = "التدقيق المالي العام",
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

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    //ShowAdd = canFinancialAuditForUser ,
                    //EnableAdd = readyToSend && canFinancialAuditForUser ,
                    ShowAdd = false,
                    EnableAdd = false,

                    ShowBulkDelete = false,


                   

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
                            PillCssClass = "pill pill-gray",
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
                            PillCssClass = "pill pill-gray",
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
                            PillCssClass = "pill pill-gray",
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
                            PillCssClass = "pill pill-gray",
                            PillMode = "replace"
                        },

                    };



            bool dsModelHasRows =
                dt1 != null && dt1.Rows.Count > 0;

            bool dsModelGeneralHasRows =
                ready && dt10 != null && dt10.Rows.Count > 0;

            bool dsModel3HasRows =
                dt2 != null && dt2.Rows.Count > 0;

            bool dsModel10HasRows =
                dt9 != null && dt9.Rows.Count > 0;

            ViewBag.dsModelHasRows = dsModelHasRows;
            ViewBag.dsModel2HasRows = dsModel3HasRows;
            ViewBag.dsModel3HasRows = dsModel10HasRows;


            //return View("HousingDefinitions/BuildingType", dsModel);

           

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel3.PageTitle,
                PanelTitle = dsModel3.PanelTitle,
                PanelIcon = "fa fa-list",

                Form = form,

                // 1. بيانات المستفيد
                TableDS = dsModelHasRows && hasresident
        ? dsModel : null,

                // 2. الرصيد العام المستقل
                TableDS1 = dsModelGeneralHasRows && hasresident
        ? dsModelGeneral : null,

                // 3. إجمالي مطالبات المباني
                TableDS2 = dsModel10HasRows && hasresident
        ? dsModel10 : null,

                // 4. التسوية المالية للمباني
                TableDS3 = dsModel3HasRows && hasresident
        ? dsModel3 : null
            };



            // ============================================================
            // Official PDF: Claims (pdf=2) / Payments (pdf=3)
            // ============================================================
            if (pdf == 2 || pdf == 3)
            {
                // الصفحة الحالية تحدد مصدر الرصيد والصلاحية.
                // عيّن هذين السطرين كما هو موضح أسفل الكود.
                var auditPrintBalanceTable = dt2;
                bool auditPrintCanReview = canREVIEWCLAIMSANDPAYMENTSFORUSER;

                if (!auditPrintCanReview)
                    return Forbid();

                if (!ready)
                {
                    return BadRequest(
                        "تعذر الطباعة: معامل U الخاص باختيار المستفيد غير موجود.");
                }

                if (!printResidentID.HasValue || printResidentID.Value <= 0)
                {
                    return BadRequest(
                        "تعذر الطباعة: رقم المستفيد printResidentID غير صحيح.");
                }

                if (!printBuildingID.HasValue || printBuildingID.Value <= 0)
                {
                    return BadRequest(
                        "تعذر الطباعة: رقم المبنى printBuildingID غير صحيح.");
                }

                if (!printServiceID.HasValue || printServiceID.Value <= 0)
                {
                    return BadRequest(
                        "تعذر الطباعة: نوع الخدمة printServiceID غير صحيح.");
                }

                // لا نقبل طباعة مستفيد/خدمة/مبنى خارج نتائج
                // التدقيق المحملة للمستخدم ضمن إدارته.
                if (auditPrintBalanceTable == null ||
                    !auditPrintBalanceTable.Columns.Contains("residentInfoID") ||
                    !auditPrintBalanceTable.Columns.Contains("buildingDetailsID") ||
                    !auditPrintBalanceTable.Columns.Contains("BillChargeTypeID"))
                {
                    return BadRequest("تعذر التحقق من نطاق التقرير.");
                }

                bool validPrintSelection =
                    auditPrintBalanceTable.AsEnumerable().Any(r =>
                        r["residentInfoID"]?.ToString() ==
                            printResidentID.Value.ToString() &&
                        r["buildingDetailsID"]?.ToString() ==
                            printBuildingID.Value.ToString() &&
                        r["BillChargeTypeID"]?.ToString() ==
                            printServiceID.Value.ToString());

                if (!validPrintSelection)
                    return Forbid();

                string actionType = pdf == 2
                    ? "GetBillsTotalPriceForResident"
                    : "GetBillsPaidByResident";

                string reportTitle = pdf == 2
                    ? "كشف المطالبات المالية"
                    : "كشف السدادات والحركات المالية";

                var printParameters = new Dictionary<string, object?>
                {
                    ["pageName_"] = PageName,
                    ["ActionType"] = actionType,
                    ["idaraID"] = IdaraId,
                    ["entrydata"] = usersId,
                    ["hostname"] = HostName,
                    ["parameter_01"] = printResidentID.Value,
                    ["parameter_02"] = printServiceID.Value,
                    ["parameter_03"] = printBuildingID.Value
                };

                DataSet printDs =
                    await _mastersServies.GetExtraDataLoadDataSetAsync(printParameters);

                if (printDs.Tables.Count == 0 || printDs.Tables[0].Rows.Count == 0)
                    return Content("لا توجد بيانات للطباعة.");

                DataTable source = printDs.Tables[0];
                DataTable printTable = new DataTable();
                var columns = new List<ReportColumn>();

                if (pdf == 2)
                {
                    string[] required =
                    {
            "BillNumber",
            "BillChargeTypeName_A",
            "buildingDetailsNo",
            "TotalPrice"
        };

                    if (required.Any(c => !source.Columns.Contains(c)))
                        return Content("أعمدة بيانات المطالبات غير مكتملة.");

                    // جلب اسم المستفيد من بيانات التدقيق المحملة والموثقة
                    DataRow? claimResidentRow =
                        dt1 != null &&
                        dt1.Columns.Contains("residentInfoID") &&
                        dt1.Columns.Contains("FullName_A")
                            ? dt1.AsEnumerable().FirstOrDefault(r =>
                                r["residentInfoID"] != DBNull.Value &&
                                r["residentInfoID"]?.ToString() ==
                                    printResidentID.Value.ToString())
                            : null;

                    if (claimResidentRow == null ||
                        claimResidentRow["FullName_A"] == DBNull.Value ||
                        string.IsNullOrWhiteSpace(
                            claimResidentRow["FullName_A"]?.ToString()))
                    {
                        return Content("تعذر تحديد اسم المستفيد للطباعة.");
                    }

                    string claimResidentName =
                        claimResidentRow["FullName_A"].ToString()!.Trim();

                    printTable.Columns.Add("BillNumber", typeof(string));
                    printTable.Columns.Add("FullName_A", typeof(string));
                    printTable.Columns.Add("BillChargeTypeName_A", typeof(string));
                    printTable.Columns.Add("buildingDetailsNo", typeof(string));
                    printTable.Columns.Add("TotalPrice", typeof(decimal));

                    foreach (DataRow r in source.Rows)
                    {
                        printTable.Rows.Add(
                            r["BillNumber"]?.ToString() ?? "",
                            claimResidentName,
                            r["BillChargeTypeName_A"]?.ToString() ?? "",
                            r["buildingDetailsNo"]?.ToString() ?? "",
                            r["TotalPrice"] == DBNull.Value
                                ? 0m : Convert.ToDecimal(r["TotalPrice"])
                        );
                    }

                    columns.Add(new("BillNumber", "رقم الفاتورة",
    Align: "center", Weight: 2, FontSize: 8));

                    columns.Add(new("FullName_A", "المستفيد",
                        Align: "center", Weight: 4, FontSize: 8));

                    columns.Add(new("BillChargeTypeName_A", "الخدمة",
                        Align: "center", Weight: 2, FontSize: 8));

                    columns.Add(new("buildingDetailsNo", "المنزل",
                        Align: "center", Weight: 2, FontSize: 8));

                    columns.Add(new("TotalPrice", "المبلغ",
                        Align: "center", Weight: 2, FontSize: 8));
                }
                else
                {
                    string[] required =
                    {
            "BillChargeTypeName_A",
            "deductName",
            "FullName_A",
            "buildingDetailsNo",
            "amount",
            "buildingPaymentTypeName_A"
        };

                    if (required.Any(c => !source.Columns.Contains(c)))
                        return Content("أعمدة بيانات السدادات غير مكتملة.");

                    printTable.Columns.Add("BillChargeTypeName_A", typeof(string));
                    printTable.Columns.Add("deductName", typeof(string));
                    printTable.Columns.Add("FullName_A", typeof(string));
                    printTable.Columns.Add("buildingDetailsNo", typeof(string));
                    printTable.Columns.Add("amount", typeof(decimal));
                    printTable.Columns.Add("buildingPaymentTypeName_A", typeof(string));

                    foreach (DataRow r in source.Rows)
                    {
                        printTable.Rows.Add(
                            r["BillChargeTypeName_A"]?.ToString() ?? "",
                            r["deductName"]?.ToString() ?? "",
                            r["FullName_A"]?.ToString() ?? "",
                            r["buildingDetailsNo"]?.ToString() ?? "",
                            r["amount"] == DBNull.Value
                                ? 0m : Convert.ToDecimal(r["amount"]),
                            r["buildingPaymentTypeName_A"]?.ToString() ?? ""
                        );
                    }

                    columns.Add(new("BillChargeTypeName_A", "الخدمة",
                        Align: "center", Weight: 2, FontSize: 8));
                    columns.Add(new("deductName", "نوع السداد",
                        Align: "center", Weight: 4, FontSize: 8));
                    columns.Add(new("FullName_A", "المستفيد",
                        Align: "center", Weight: 4, FontSize: 8));
                    columns.Add(new("buildingDetailsNo", "المنزل",
                        Align: "center", Weight: 2, FontSize: 8));
                    columns.Add(new("amount", "المبلغ",
                        Align: "center", Weight: 2, FontSize: 8));
                    columns.Add(new("buildingPaymentTypeName_A", "طريقة السداد",
                        Align: "center", Weight: 3, FontSize: 8));
                }

                DataRow selectedBalance = auditPrintBalanceTable
                    .AsEnumerable()
                    .First(r =>
                        r["residentInfoID"]?.ToString() ==
                            printResidentID.Value.ToString() &&
                        r["buildingDetailsID"]?.ToString() ==
                            printBuildingID.Value.ToString() &&
                        r["BillChargeTypeID"]?.ToString() ==
                            printServiceID.Value.ToString());

                string serviceName =
                    auditPrintBalanceTable.Columns.Contains("BillChargeTypeName_A")
                        ? selectedBalance["BillChargeTypeName_A"]?.ToString() ?? ""
                        : "";

                string homeNumber =
                    auditPrintBalanceTable.Columns.Contains("buildingDetailsNo")
                        ? selectedBalance["buildingDetailsNo"]?.ToString() ?? ""
                        : "";

                string subject =
                    $"{reportTitle} - {serviceName} - المنزل {homeNumber}";

                var logo = Path.Combine(
                    _env.WebRootPath,
                    "img",
                    "Royal_Saudi_Land_Forces.png");

                var header = new Dictionary<string, string>
                {
                    ["no"] = "—",
                    ["date"] = DateTime.Now.ToString("yyyy/MM/dd"),
                    ["attach"] = "—",
                    ["subject"] = subject,
                    ["right1"] = "المملكة العربية السعودية",
                    ["right2"] = "وزارة الدفاع",
                    ["right3"] = "القوات البرية الملكية السعودية",
                    ["right4"] = OrganizationName,
                    ["right5"] = IdaraName,
                    ["midCaption"] = ""
                };

                var report = DataTableReportBuilder.FromDataTable(
                    reportId:
                        $"{PageName}_{actionType}_{printResidentID}_{printBuildingID}_{printServiceID}",
                    title: subject,
                    table: printTable,
                    columns: columns,
                    headerFields: header,
                    footerFields: new Dictionary<string, string>
                    {
                        ["عدد السجلات"] = printTable.Rows.Count.ToString(),
                        ["الرقم المرجعي للمستفيد"] = printResidentID.Value.ToString(),
                        ["تمت الطباعة بواسطة"] = FullName ?? "",
                        ["تاريخ ووقت الطباعة"] =
                            DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss")
                    },
                    orientation: ReportOrientation.Landscape,
                    headerType: ReportHeaderType.LetterOfficial,
                    logoPath: logo,
                    headerRepeat: ReportHeaderRepeat.AllPages
                );

                byte[] bytes = QuestPdfReportRenderer.Render(report);

                Response.Headers["Content-Disposition"] =
                    $"inline; filename={PageName}_{actionType}.pdf";

                return File(bytes, "application/pdf");
            }

            return View("FinancialAudit/FinancialAuditForUser", page);

        }
    }
}
