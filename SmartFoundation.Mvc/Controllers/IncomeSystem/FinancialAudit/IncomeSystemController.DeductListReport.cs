using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
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
        public async Task<IActionResult> DeductListReport(int? year, int? month, long? reportID, int pdf = 0)

        {
            //  قراءة السيشن والكونتكست
            if (!InitPageContext(out var redirect))
                return redirect!;


            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            string? year_ = Request.Query["year"].FirstOrDefault();
            string? month_ = Request.Query["month"].FirstOrDefault();

            year_ = string.IsNullOrWhiteSpace(year_) ? null : year_.Trim();
            month_ = string.IsNullOrWhiteSpace(month_) ? null : month_.Trim();


            ControllerName = nameof(IncomeSystem);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "DeductListReport" : PageName;


           


            var spParameters = new object?[]
            {
                PageName ?? "DeductListReport",
                IdaraId,
                usersId,
                HostName,
                year,
                month,
                reportID
            };


            // ============================================================
            // الجدول الأول - المسيرات
            // ============================================================

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();


            // ============================================================
            // الجدول الثاني - تفاصيل المسير
            // ============================================================

            var rowsList2 = new List<Dictionary<string, object?>>();
            var dynamicColumns2 = new List<TableColumn>();


            // ============================================================
            // الجدول الثالث - ملفات الحسم الواردة
            // ============================================================

            var rowsList3 = new List<Dictionary<string, object?>>();
            var dynamicColumns3 = new List<TableColumn>();


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
            string rowIdField2 = "";
            string rowIdField3 = "";


            bool canCREATEDEDUCTLISTREPORT = false;
            bool canAPPROVEDEDUCTLISTREPORT = false;
            bool canSENDDEDUCTLISTREPORT = false;
            bool canCANCELDEDUCTLISTREPORT = false;



            // ============================================================
            // القوائم المنسدلة
            // ============================================================

            List<OptionItem> yearOptions = new();
            List<OptionItem> monthOptions = new();
            List<OptionItem> serviceOptions = new();

            // ---------------------- DDLValues ----------------------

            JsonResult? result;
            string json;
            //// ---------------------- year Options ----------------------
            result = await _CrudController.GetDDLValues(
                "YearNo", "YearID", "5", nameof(DeductListReport), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            yearOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            // ---------------------- Month Options ----------------------



            // ---------------------- Month Options ----------------------

            if (!string.IsNullOrWhiteSpace(year_))
            {
                result = await _CrudController.GetDDLValues(
                    "MonthNo",
                    "MonthID",
                    "6",
                    nameof(DeductListReport),
                    usersId,
                    IdaraId,
                    HostName,
                    "YearNo",
                    year_
                ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);

                monthOptions =
                    JsonSerializer.Deserialize<List<OptionItem>>(json)
                    ?? new List<OptionItem>();
            }





            // ---------------------- Service Options ----------------------

            serviceOptions.Add(new OptionItem
            {
                Value = "",
                Text = "اختر الخدمة المفوترة"
            });


            if (dt4 != null && dt4.Rows.Count > 0)
            {
                foreach (DataRow row in dt4.Rows)
                {
                    serviceOptions.Add(new OptionItem
                    {
                        Value = row["meterServiceTypeID"]?.ToString() ?? "",
                        Text = row["meterServiceTypeName_A"]?.ToString() ?? ""
                    });
                }
            }


            // ---------------------- END DDL ----------------------



            FormConfig form = new();



            try
            {

                // ============================================================
                // نموذج البحث
                // ============================================================

                form = new FormConfig
                {
                    FormId = "deductReportFilter",
                    Method = "get",
                    ActionUrl = "/IncomeSystem/DeductListReport",

                    Fields = new List<FieldConfig>
                    {

                        new FieldConfig
                    {
                        SectionTitle = "البحث",
                        Label = "السنة",
                        Name = "year",
                        Type = "select",
                        ColCss = "3",
                    
                        Value = year_,
                    
                        Required = true,
                        Options = yearOptions,
                        Placeholder = "الرجاء الاختيار",
                    
                        NavUrl = "/IncomeSystem/DeductListReport",
                        NavKey = "year",
                    
                        OnChangeJs = "sfNav(this)"
                    },
                    
                    new FieldConfig
                    {
                        Label = "الشهر",
                        Name = "month",
                        Type = "select",
                        ColCss = "3",
                    
                        Value = month_,
                    
                        Required = true,
                        Options = monthOptions,
                        Placeholder = "الرجاء الاختيار",
                    
                        NavUrl = "/IncomeSystem/DeductListReport",
                    
                        NavKey = "month",
                    
                        NavKey3 = "year",
                        NavField3 = "year",
                    
                        OnChangeJs = "sfNav(this)"
                    }

                    },

                    //Buttons = new List<FormButton>
                    //{
                    //    new FormButton
                    //    {
                    //        Text = "عرض",
                    //        Type = "submit",
                    //        Color = "primary"
                    //    }
                    //}
                };



                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {

                    // ============================================================
                    // الصلاحيات
                    // ============================================================

                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?
                            .ToString()?
                            .Trim()
                            .ToUpper();


                        if (permissionName == "CREATEDEDUCTLISTREPORT")
                            canCREATEDEDUCTLISTREPORT = true;

                        if (permissionName == "APPROVEDEDUCTLISTREPORT")
                            canAPPROVEDEDUCTLISTREPORT = true;

                        if (permissionName == "SENDDEDUCTLISTREPORT")
                            canSENDDEDUCTLISTREPORT = true;

                        if (permissionName == "CANCELDEDUCTLISTREPORT")
                            canCANCELDEDUCTLISTREPORT = true;
                    }



                    // ============================================================
                    // الجدول الأول
                    // مسيرات الحسم
                    // ============================================================

                    if (dt1 != null && dt1.Columns.Count > 0)
                    {

                        // RowId

                        rowIdField = "DeductListReportID";

                        var possibleIdNames = new[]
                        {
                            "DeductListReportID",
                            "Id",
                            "ID"
                        };

                        rowIdField = possibleIdNames
                            .FirstOrDefault(n => dt1.Columns.Contains(n))
                            ?? dt1.Columns[0].ColumnName;



                        // عناوين الأعمدة بالعربي

                        var headerMap = new Dictionary<string, string>(
                            StringComparer.OrdinalIgnoreCase)
                        {
                            ["DeductListReportID"] = "رقم السجل",

                            ["ReportNo"] = "رقم المسير",

                            ["PeriodYear"] = "السنة",
                            ["PeriodMonth"] = "الشهر",

                            ["BillingType"] = "النوع",

                            ["meterServiceTypeName_A"] = "الخدمة",

                            ["CalculationMethod"] = "طريقة الحساب",

                            ["ReportStatus"] = "حالة الإرسال",

                            ["InvoiceCount"] = "عدد الفواتير",

                            ["AmountBeforeTax"] = "الاجمالي قبل الضريبة",
                            ["TaxAmount"] = "الضريبة",

                            ["TotalAmount"] = "الاجمالي",

                            ["ImportedAmount"] = "اجمالي المبلغ الوارد",

                            ["DifferenceAmount"] = "فرق المبلغ بين الصادر والوارد",

                            ["ImportedRows"] = "صفوف الحسم الوارده",

                            ["ReportStatusArabic"] = "حالة المسير",

                            ["ApprovedDate"] = "تاريخ الاعتماد",
                            ["ApprovedBy"] = "اعتمد بواسطه",
                            ["SentDate"] = "تاريخ الارسال",
                  ["SentBy"] = "ارسل بواسطه",

                  ["ExternalReferenceNo"] = "رقم الخطاب الصادر",
                  ["ExternalReferenceDate"] = "تاريخ الخطاب الصادر",
                  ["Notes"] = "الملاحظات",

                            ["SentDate"] = "تاريخ الإرسال"
                        };



                        // الأعمدة

                        foreach (DataColumn c in dt1.Columns)
                        {

                            string colType = "text";

                            var t = c.DataType;


                            if (t == typeof(bool))
                                colType = "bool";

                            else if (t == typeof(DateTime))
                                colType = "date";

                            else if (
                                t == typeof(byte) ||
                                t == typeof(short) ||
                                t == typeof(int) ||
                                t == typeof(long) ||
                                t == typeof(float) ||
                                t == typeof(double) ||
                                t == typeof(decimal))
                            {
                                colType = "number";
                            }



                            bool isDeductListReportID =
                                c.ColumnName.Equals(
                                    "DeductListReportID",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isIdaraID_FK =
                                c.ColumnName.Equals(
                                    "IdaraID_FK",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isMeterServiceTypeID_FK =
                                c.ColumnName.Equals(
                                    "MeterServiceTypeID_FK",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isentryData =
                                c.ColumnName.Equals(
                                    "entryData",
                                    StringComparison.OrdinalIgnoreCase);


                            bool ishostName =
                                c.ColumnName.Equals(
                                    "hostName",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isentryDate =
                                c.ColumnName.Equals(
                                    "entryDate",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isIsCurrent =
                                c.ColumnName.Equals(
                                    "IsCurrent",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isRevisionNo =
                                c.ColumnName.Equals(
                                    "RevisionNo",
                                    StringComparison.OrdinalIgnoreCase);

                            bool isBillingType =
                                c.ColumnName.Equals(
                                    "BillingType",
                                    StringComparison.OrdinalIgnoreCase);

                            bool isCalculationMethod =
                                c.ColumnName.Equals(
                                    "CalculationMethod",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isReportStatus =
                                c.ColumnName.Equals(
                                    "ReportStatus",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isidaraLongName_A =
                                c.ColumnName.Equals(
                                    "idaraLongName_A",
                                    StringComparison.OrdinalIgnoreCase);



                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,

                                Label = headerMap.TryGetValue(
                                    c.ColumnName,
                                    out var label)
                                    ? label
                                    : c.ColumnName,

                                Type = colType,

                                Sortable = true,

                                Visible = !(
                                    isDeductListReportID ||
                                    isIdaraID_FK ||
                                    isMeterServiceTypeID_FK ||
                                    isentryData ||
                                    ishostName ||
                                    isentryDate ||
                                    isIsCurrent ||
                                    isBillingType ||
                                    isCalculationMethod ||
                                    isReportStatus ||
                                    isidaraLongName_A ||
                                    isRevisionNo)
                            });

                        }



                        // الصفوف

                        foreach (DataRow r in dt1.Rows)
                        {

                            var dict = new Dictionary<string, object?>(
                                StringComparer.OrdinalIgnoreCase);


                            foreach (DataColumn c in dt1.Columns)
                            {
                                var val = r[c];

                                dict[c.ColumnName] =
                                    val == DBNull.Value
                                    ? null
                                    : val;
                            }



                            // p01..p07

                            object? Get(string key) =>
                                dict.TryGetValue(key, out var v)
                                    ? v
                                    : null;


                            dict["p01"] = Get("DeductListReportID");

                            dict["p02"] = Get("PeriodYear");

                            dict["p03"] = Get("PeriodMonth");

                            dict["p04"] = Get("BillingType");

                            dict["p05"] = Get("MeterServiceTypeID_FK");

                            dict["p06"] = Get("CalculationMethod");

                            dict["p07"] = Get("ReportNo");

                            dict["p40"] = Get("meterServiceTypeName_A");



                            rowsList.Add(dict);
                        }

                    }



                    // ============================================================
                    // الجدول الثاني
                    // تفاصيل المسير
                    // ============================================================

                    if (dt2 != null && dt2.Columns.Count > 0)
                    {

                        // RowId

                        rowIdField2 = "DeductListReportDetailsID";

                        var possibleIdNames2 = new[]
                        {
                            "DeductListReportDetailsID",
                            "Id",
                            "ID"
                        };

                        rowIdField2 = possibleIdNames2
                            .FirstOrDefault(n => dt2.Columns.Contains(n))
                            ?? dt2.Columns[0].ColumnName;



                        // عناوين الأعمدة بالعربي

                        var headerMap2 = new Dictionary<string, string>(
                            StringComparer.OrdinalIgnoreCase)
                        {
                            ["BillNumber"] = "رقم الفاتورة",

                            ["ResidentFullName_A"] = "اسم الساكن",

                            ["GeneralNo_FK"] = "الرقم العام",

                            ["BuildingDetailsNo"] = "المنزل",

                            ["MeterNo"] = "العداد",

                            ["BillsFromDate"] = "من",

                            ["BillsToDate"] = "إلى",

                            ["CalculationMethodName_A"] = "طريقة احتساب الفاتورة",

                            ["TotalAmount"] = "الإجمالي"
                        };



                        // الأعمدة

                        foreach (DataColumn c in dt2.Columns)
                        {

                            string colType = "text";

                            var t = c.DataType;


                            if (t == typeof(bool))
                                colType = "bool";

                            else if (t == typeof(DateTime))
                                colType = "date";

                            else if (
                                t == typeof(byte) ||
                                t == typeof(short) ||
                                t == typeof(int) ||
                                t == typeof(long) ||
                                t == typeof(float) ||
                                t == typeof(double) ||
                                t == typeof(decimal))
                            {
                                colType = "number";
                            }



                            bool isDeductListReportDetailsID =
                                c.ColumnName.Equals(
                                    "DeductListReportDetailsID",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isDeductListReportID_FK =
                                c.ColumnName.Equals(
                                    "DeductListReportID_FK",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isBillsID_FK =
                                c.ColumnName.Equals(
                                    "BillsID_FK",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isResidentInfoID_FK =
                                c.ColumnName.Equals(
                                    "ResidentInfoID_FK",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isBuildingDetailsID_FK =
                                c.ColumnName.Equals(
                                    "BuildingDetailsID_FK",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isMeterID_FK =
                                c.ColumnName.Equals(
                                    "MeterID_FK",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isIDNumber =
                                c.ColumnName.Equals(
                                    "IDNumber",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isentryDate =
                                c.ColumnName.Equals(
                                    "entryDate",
                                    StringComparison.OrdinalIgnoreCase);



                            dynamicColumns2.Add(new TableColumn
                            {
                                Field = c.ColumnName,

                                Label = headerMap2.TryGetValue(
                                    c.ColumnName,
                                    out var label)
                                    ? label
                                    : c.ColumnName,

                                Type = colType,

                                Sortable = true,

                                Visible = !(
                                    isDeductListReportDetailsID ||
                                    isDeductListReportID_FK ||
                                    isBillsID_FK ||
                                    isResidentInfoID_FK ||
                                    isBuildingDetailsID_FK ||
                                    isMeterID_FK ||
                                    isIDNumber ||
                                    isentryDate)
                            });

                        }



                        // الصفوف

                        foreach (DataRow r in dt2.Rows)
                        {

                            var dict = new Dictionary<string, object?>(
                                StringComparer.OrdinalIgnoreCase);


                            foreach (DataColumn c in dt2.Columns)
                            {
                                var val = r[c];

                                dict[c.ColumnName] =
                                    val == DBNull.Value
                                    ? null
                                    : val;
                            }



                            rowsList2.Add(dict);
                        }

                    }



                    // ============================================================
                    // الجدول الثالث
                    // ملفات الحسم الواردة
                    // ============================================================

                    if (dt3 != null && dt3.Columns.Count > 0)
                    {

                        // RowId

                        rowIdField3 = "DeductListReportImportID";

                        var possibleIdNames3 = new[]
                        {
                            "DeductListReportImportID",
                            "Id",
                            "ID"
                        };

                        rowIdField3 = possibleIdNames3
                            .FirstOrDefault(n => dt3.Columns.Contains(n))
                            ?? dt3.Columns[0].ColumnName;



                        // عناوين الأعمدة بالعربي

                        var headerMap3 = new Dictionary<string, string>(
                            StringComparer.OrdinalIgnoreCase)
                        {
                            ["paymentNo"] = "رقم ملف الحسم",

                            ["paymentDate"] = "تاريخه",

                            ["OriginalFileName"] = "اسم الملف",

                            ["UploadedAt"] = "تاريخ الرفع",

                            ["ImportedRows"] = "الصفوف",

                            ["ImportedAmount"] = "إجمالي الحسم"
                        };



                        // الأعمدة

                        foreach (DataColumn c in dt3.Columns)
                        {

                            string colType = "text";

                            var t = c.DataType;


                            if (t == typeof(bool))
                                colType = "bool";

                            else if (t == typeof(DateTime))
                                colType = "date";

                            else if (
                                t == typeof(byte) ||
                                t == typeof(short) ||
                                t == typeof(int) ||
                                t == typeof(long) ||
                                t == typeof(float) ||
                                t == typeof(double) ||
                                t == typeof(decimal))
                            {
                                colType = "number";
                            }



                            bool isDeductListReportImportID =
                                c.ColumnName.Equals(
                                    "DeductListReportImportID",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isDeductListReportID_FK =
                                c.ColumnName.Equals(
                                    "DeductListReportID_FK",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isDeductListID_FK =
                                c.ColumnName.Equals(
                                    "DeductListID_FK",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isentryData =
                                c.ColumnName.Equals(
                                    "entryData",
                                    StringComparison.OrdinalIgnoreCase);


                            bool ishostName =
                                c.ColumnName.Equals(
                                    "hostName",
                                    StringComparison.OrdinalIgnoreCase);


                            bool isentryDate =
                                c.ColumnName.Equals(
                                    "entryDate",
                                    StringComparison.OrdinalIgnoreCase);



                            dynamicColumns3.Add(new TableColumn
                            {
                                Field = c.ColumnName,

                                Label = headerMap3.TryGetValue(
                                    c.ColumnName,
                                    out var label)
                                    ? label
                                    : c.ColumnName,

                                Type = colType,

                                Sortable = true,

                                Visible = !(
                                    isDeductListReportImportID ||
                                    isDeductListReportID_FK ||
                                    isDeductListID_FK ||
                                    isentryData ||
                                    ishostName ||
                                    isentryDate)
                            });

                        }



                        // الصفوف

                        foreach (DataRow r in dt3.Rows)
                        {

                            var dict = new Dictionary<string, object?>(
                                StringComparer.OrdinalIgnoreCase);


                            foreach (DataColumn c in dt3.Columns)
                            {
                                var val = r[c];

                                dict[c.ColumnName] =
                                    val == DBNull.Value
                                    ? null
                                    : val;
                            }



                            rowsList3.Add(dict);
                        }

                    }

                }

            }
            catch (Exception)
            {
                ViewBag.DeductListReportDataSetError =
                    "حدث خطأ أثناء تحميل البيانات. يرجى المحاولة مرة أخرى.";
            }



            var currentUrl = Request.Path + Request.QueryString;



            // ============================================================
            // CREATE fields
            // إنشاء مسير
            // ============================================================

            var CreateFields = new List<FieldConfig>
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
                        Value = "CREATEDEDUCTLISTREPORT"
                    },
                
                    new FieldConfig
                    {
                        Name = "redirectUrl",
                        Type = "hidden",
                        Value = currentUrl
                    },
                
                    new FieldConfig
                    {
                        Name = "redirectAction",
                        Type = "hidden",
                        Value = PageName
                    },
                
                    new FieldConfig
                    {
                        Name = "redirectController",
                        Type = "hidden",
                        Value = ControllerName
                    },
                
                    new FieldConfig
                    {
                        Name = "__RequestVerificationToken",
                        Type = "hidden",
                        Value =
                            Request.Headers["RequestVerificationToken"]
                            .FirstOrDefault() ?? ""
                    },
                
                    new FieldConfig
                    {
                        Name = "p01",
                        Type = "hidden"
                    },
                
                
                    // ============================================================
                    // السنة
                    // ============================================================
                
                    new FieldConfig
                    {
                        Name = "p02",
                        Label = "السنة",
                        Type = "select",
                        ColCss = "3",
                        Required = true,
                        Options = yearOptions,
                        Value=year_,
                        Readonly=true,
                        Placeholder = "اختر السنة"
                    },
                
                
                    // ============================================================
                    // الشهر - يعتمد على السنة
                    // ============================================================
                
                    new FieldConfig
                    {
                        Name = "p03",
                        Label = "الشهر",
                        Type = "select",
                        ColCss = "3",
                        Value=month_,
                        Required = true,
                        Options = monthOptions,
                        Readonly = true
                       // Options = new List<OptionItem>(),
                
                        //Placeholder = "اختر السنة أولاً",
                
                        //DependsOn = "p02",
                
                        //DependsUrl = "/crud/DDLFiltered?FK=YearNo&textcol=MonthNo&ValueCol=MonthID&PageName=DeductListReport&TableIndex=6"
                    },
                
                
                    new FieldConfig
                    {
                        Name = "p04",
                        Label = "BillingType",
                        Type = "hidden",
                        Value = "SERVICE"
                    },
                
                
                    new FieldConfig
                    {
                        Name = "p05",
                        Label = "الخدمة",
                        Type = "select",
                        ColCss = "6",
                        Required = true,
                        Options = serviceOptions,
                        Select2 = true
                    },
                
                
                    new FieldConfig
                    {
                        Name = "p06",
                        Label = "CalculationMethod",
                        Type = "hidden",
                        Value = "ALL_METHODS"
                    },
                
                
                    new FieldConfig
                    {
                        Name = "p09",
                        Label = "ملاحظات",
                        Type = "textarea",
                        ColCss = "6",
                        MaxLength = 1000,
                        HelpText = "لايجب ان يتجاوز النص 1000 حرف*"
                    }
                
                };



            // ============================================================
            // APPROVE fields
            // اعتماد المسير
            // ============================================================

            var ApproveFields = new List<FieldConfig>
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
                    Value = "APPROVEDEDUCTLISTREPORT"
                },

                new FieldConfig
                {
                    Name = "redirectUrl",
                    Type = "hidden",
                    Value = currentUrl
                },

                new FieldConfig
                {
                    Name = "redirectAction",
                    Type = "hidden",
                    Value = PageName
                },

                new FieldConfig
                {
                    Name = "redirectController",
                    Type = "hidden",
                    Value = ControllerName
                },

                new FieldConfig
                {
                    Name = "__RequestVerificationToken",
                    Type = "hidden",
                    Value =
                        Request.Headers["RequestVerificationToken"]
                        .FirstOrDefault() ?? ""
                },


                // selection context

                new FieldConfig
                {
                    Name = rowIdField,
                    Type = "hidden"
                },


                // hidden p01 actually posted to SP

                new FieldConfig
                {
                    Name = "p01",
                    Type = "hidden",
                    MirrorName = "DeductListReportID"
                },

                new FieldConfig
                {
                    Name = "p07",
                    Label = "رقم المسير",
                    Type = "text",
                    ColCss = "3",
                    Readonly = true
                },

                 new FieldConfig
                {
                    Name = "p40",
                    Label = "نوع الخدمة",
                    Type = "text",
                    ColCss = "4",
                    Readonly = true
                },


                new FieldConfig
                {
                    Name = "p02",
                    Label = "السنة",
                    Type = "text",
                    ColCss = "3",
                    Readonly = true
                },


                new FieldConfig
                {
                    Name = "p03",
                    Label = "الشهر",
                    Type = "text",
                    ColCss = "2",
                    Readonly = true
                },

               

                new FieldConfig
                {
                    Name = "p04",
                    Label = "BillingType",
                    Type = "hidden",
                    Readonly = true
                },


                new FieldConfig
                {
                    Name = "p05",
                    Label = "MeterServiceTypeID_FK",
                    Type = "hidden",
                    Readonly = true
                },


                new FieldConfig
                {
                    Name = "p06",
                    Label = "CalculationMethod",
                    Type = "hidden",
                    Readonly = true
                },


                

            };



            // ============================================================
            // SEND fields
            // تسجيل إرسال المسير
            // ============================================================

            var SendFields = new List<FieldConfig>
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
                    Value = "SENDDEDUCTLISTREPORT"
                },

                new FieldConfig
                {
                    Name = "redirectUrl",
                    Type = "hidden",
                    Value = currentUrl
                },

                new FieldConfig
                {
                    Name = "redirectAction",
                    Type = "hidden",
                    Value = PageName
                },

                new FieldConfig
                {
                    Name = "redirectController",
                    Type = "hidden",
                    Value = ControllerName
                },

                new FieldConfig
                {
                    Name = "__RequestVerificationToken",
                    Type = "hidden",
                    Value =
                        Request.Headers["RequestVerificationToken"]
                        .FirstOrDefault() ?? ""
                },


                // selection context

                new FieldConfig
                {
                    Name = rowIdField,
                    Type = "hidden"
                },


                // hidden p01 actually posted to SP

                new FieldConfig
                {
                    Name = "p01",
                    Type = "hidden",
                    MirrorName = "DeductListReportID"
                },

                new FieldConfig
                {
                    Name = "p07",
                    Label = "رقم المسير",
                    Type = "text",
                    ColCss = "3",
                    Readonly = true
                },


                new FieldConfig
                {
                    Name = "p40",
                    Label = "نوع الخدمة",
                    Type = "text",
                    ColCss = "4",
                    Readonly = true
                },

                new FieldConfig
                {
                    Name = "p02",
                    Label = "السنة",
                    Type = "text",
                    ColCss = "3",
                    Readonly = true
                },


                new FieldConfig
                {
                    Name = "p03",
                    Label = "الشهر",
                    Type = "text",
                    ColCss = "2",
                    Readonly = true
                },


                new FieldConfig
                {
                    Name = "p04",
                    Label = "BillingType",
                    Type = "hidden",
                    Readonly = true
                },


                new FieldConfig
                {
                    Name = "p05",
                    Label = "MeterServiceTypeID_FK",
                    Type = "hidden",
                    Readonly = true
                },


                new FieldConfig
                {
                    Name = "p06",
                    Label = "CalculationMethod",
                    Type = "hidden",
                    Readonly = true
                },


                

                new FieldConfig
                {
                    Name = "p08",
                    Label = "رقم الخطاب الصادر",
                    Type = "text",
                    ColCss = "6",
                    Required=true,
                    MaxLength = 100
                },

                new FieldConfig
                {
                    Name = "p09",
                    Label = "تاريخ الخطاب الصادر",
                    Type = "date",
                    ColCss = "6",
                    Required = true
                }

            };


            // ============================================================
            // Delete fields
            // حذف المسير
            // ============================================================

            var DeleteFields = new List<FieldConfig>
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
                    Value = "CANCELDEDUCTLISTREPORT"
                },

                new FieldConfig
                {
                    Name = "redirectUrl",
                    Type = "hidden",
                    Value = currentUrl
                },

                new FieldConfig
                {
                    Name = "redirectAction",
                    Type = "hidden",
                    Value = PageName
                },

                new FieldConfig
                {
                    Name = "redirectController",
                    Type = "hidden",
                    Value = ControllerName
                },

                new FieldConfig
                {
                    Name = "__RequestVerificationToken",
                    Type = "hidden",
                    Value =
                        Request.Headers["RequestVerificationToken"]
                        .FirstOrDefault() ?? ""
                },


                // selection context

                new FieldConfig
                {
                    Name = rowIdField,
                    Type = "hidden"
                },


                // hidden p01 actually posted to SP

                new FieldConfig
                {
                    Name = "p01",
                    Type = "hidden",
                    MirrorName = "DeductListReportID"
                },

                new FieldConfig
                {
                    Name = "p07",
                    Label = "رقم المسير",
                    Type = "text",
                    ColCss = "3",
                    Readonly = true
                },


                new FieldConfig
                {
                    Name = "p40",
                    Label = "نوع الخدمة",
                    Type = "text",
                    ColCss = "4",
                    Readonly = true
                },

                new FieldConfig
                {
                    Name = "p02",
                    Label = "السنة",
                    Type = "text",
                    ColCss = "3",
                    Readonly = true
                },


                new FieldConfig
                {
                    Name = "p03",
                    Label = "الشهر",
                    Type = "text",
                    ColCss = "2",
                    Readonly = true
                },


                new FieldConfig
                {
                    Name = "p04",
                    Label = "BillingType",
                    Type = "hidden",
                    Readonly = true
                },


                new FieldConfig
                {
                    Name = "p05",
                    Label = "MeterServiceTypeID_FK",
                    Type = "hidden",
                    Readonly = true
                },


                new FieldConfig
                {
                    Name = "p06",
                    Label = "CalculationMethod",
                    Type = "hidden",
                    Readonly = true
                }




                

            };




            //=============================================================

            var DeductDetailsFields = new List<FieldConfig>
{
    new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
    new FieldConfig { Name = "ActionType", Type = "hidden", Value = "GetDeductListReportDetails" },
    new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
    new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
    new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
    new FieldConfig
    {
        Name = "__RequestVerificationToken",
        Type = "hidden",
        Value = Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? ""
    },
    new FieldConfig { Name = rowIdField, Type = "hidden" },
    new FieldConfig
    {
        Name = "p01",
        Type = "hidden",
        MirrorName = "DeductListReportID"
    },
    new FieldConfig
    {
        Name = "p07",
        Label = "رقم المسير",
        Type = "hidden",
        Readonly = true,
        ColCss = "6"
    }
};


            var extraDeductDetailsCtx = new Dictionary<string, object?>
            {
                ["idaraID"] = IdaraId,
                ["entrydata"] = usersId,
                ["hostname"] = HostName
            };

            var extraDeductDetailsRequest = new Dictionary<string, object?>
            {
                ["pageName_"] = PageName,
                ["ActionType"] = "GetDeductListReportDetails",
                ["tableIndex"] = 0
            };

            var extraMetaDeductDetails = new Dictionary<string, object?>
            {
                ["extraSlotKey"] = "m1",
                ["extraTitle"] = "تفاصيل المسير",
                ["useRowExtra"] = true,
                ["lazyExtra"] = true,
                ["extraEndpoint"] = "/crud/extradataload",
                ["allowNoSelection"] = false,
                ["emptyText"] = "لا توجد تفاصيل في هذا المسير",
                ["extraLoadOnOpen"] = true,

                ["ctx"] = extraDeductDetailsCtx,
                ["extraRequest"] = extraDeductDetailsRequest,

                ["extraParamMap"] = new Dictionary<string, string>
                {
                    ["parameter_01"] = "DeductListReportID"
                },

                ["EnableSearch"] = true,
                ["ShowMeta"] = true,
                ["PageSize"] = 10,
                ["Sortable"] = true,
                ["showRowNumbers"] = true,

                ["visibleFields"] = new List<string>
    {
        "BillNumber",
        "ResidentFullName_A",
        "GeneralNo_FK",
        "BuildingDetailsNo",
        "MeterNo",
        "BillsFromDate",
        "BillsToDate",
        "CalculationMethodName_A",
        "TotalAmount"
    },

                ["headerMap"] = new Dictionary<string, string>
                {
                    ["BillNumber"] = "رقم الفاتورة",
                    ["ResidentFullName_A"] = "اسم الساكن",
                    ["GeneralNo_FK"] = "الرقم العام",
                    ["BuildingDetailsNo"] = "المنزل",
                    ["MeterNo"] = "العداد",
                    ["BillsFromDate"] = "من",
                    ["BillsToDate"] = "إلى",
                    ["CalculationMethodName_A"] = "طريقة احتساب الفاتورة",
                    ["TotalAmount"] = "الإجمالي"
                }
            };

            // ============================================================
            // الجدول الأول
            // ============================================================

            var dsModel = new SmartTableDsModel
            {

                PageTitle = "مسيرات الحسم",

                Columns = dynamicColumns,

                Rows = rowsList,

                RowIdField = rowIdField,

                PageSize = 25,

                PageSizes = new List<int>
                {
                    10,
                    25,
                    50,
                    100
                },

                QuickSearchFields = new List<string>
                {
                    "ReportNo",
                    "ReportStatus",
                    "meterServiceTypeName_A"
                },

                Searchable = true,

                AllowExport = true,

                ShowPageSizeSelector = true,

                PanelTitle = "المسيرات الصادرة للجهة المالية",

                EnableCellCopy = true,


                Toolbar = new TableToolbarConfig
                {

                    ShowRefresh = false,

                    ShowColumns = true,

                    ShowExportCsv = false,

                    ShowExportExcel = false,


                    ShowAdd = canCREATEDEDUCTLISTREPORT,

                    ShowEdit = canAPPROVEDEDUCTLISTREPORT,

                    ShowEdit1 = canSENDDEDUCTLISTREPORT,

                    ShowEdit2 = canCREATEDEDUCTLISTREPORT || canAPPROVEDEDUCTLISTREPORT || canSENDDEDUCTLISTREPORT,


                    ShowDelete = canCANCELDEDUCTLISTREPORT,

                    ShowBulkDelete = false,

                    ShowPrint1 = true,



                    // ====================================================
                    // إنشاء مسير
                    // ====================================================

                    Add = new TableAction
                    {

                        Label = "إنشاء مسير",

                        Icon = "fa fa-plus",

                        Color = "primary",

                        OpenModal = true,

                        ModalTitle = "إنشاء مسير حسم",

                        OpenForm = new FormConfig
                        {

                            FormId = "deductReportCreate",

                            Title = "",

                            Method = "post",

                            ActionUrl = "/crud/insert",

                            SubmitText = "إنشاء",

                            CancelText = "إلغاء",

                            Fields = CreateFields

                        }

                    },



                    // ====================================================
                    // اعتماد المسير
                    // ====================================================

                    Edit = new TableAction
                    {

                        Label = "اعتماد",

                        Icon = "fa fa-check",

                        Color = "success",

                        Show = true,

                        IsEdit = true,

                        OpenModal = true,


                        ModalTitle = "اعتماد مسير حسم",

                        ModalMessage = "ملاحظة : بعد الاعتماد لايمكن التعديل على المسير",

                        ModalMessageClass =
                            "bg-red-50 text-red-700",

                        ModalMessageIcon =
                            "fa-solid fa-triangle-exclamation",


                        OnBeforeOpenJs =
                            "sfRouteEditForm(table, act);",


                        OpenForm = new FormConfig
                        {

                            FormId = "deductReportApprove",

                            Title = "",

                            Method = "post",

                            ActionUrl = "/crud/update",

                            SubmitText = "اعتماد",

                            CancelText = "إلغاء",

                            Fields = ApproveFields

                        },


                        RequireSelection = true,

                        MinSelection = 1,

                        MaxSelection = 1,


                        Guards = new TableActionGuards
                        {

                            AppliesTo = "any",

                            DisableWhenAny =
                                new List<TableActionRule>
                                {

                                    new TableActionRule
                                    {
                                        Field = "ReportStatus",

                                        Op = "neq",

                                        Value = "DRAFT",

                                        Message =
                                            "لايمكن اعتماد المسير في حالته الحالية",

                                        Priority = 3
                                    }

                                }

                        }

                    },



                    // ====================================================
                    // تسجيل الإرسال
                    // ====================================================

                    Edit1 = new TableAction
                    {

                        Label = "تسجيل الإرسال",

                        Icon = "fa fa-paper-plane",

                        Color = "info",

                        Show = true,

                        IsEdit = true,

                        OpenModal = true,


                        ModalTitle = "ارسال مسير الحسم",

                        ModalMessage = "بعد الارسال لايمكن التعديل على مسير الحسم",

                        ModalMessageClass =
                            "bg-red-50 text-red-700",

                        ModalMessageIcon =
                            "fa-solid fa-triangle-exclamation",


                        OnBeforeOpenJs =
                            "sfRouteEditForm(table, act);",


                        OpenForm = new FormConfig
                        {

                            FormId = "deductReportSend",

                            Title = "",

                            Method = "post",

                            ActionUrl = "/crud/update",

                            SubmitText = "تأكيد الإرسال",

                            CancelText = "إلغاء",

                            Fields = SendFields

                        },


                        RequireSelection = true,

                        MinSelection = 1,

                        MaxSelection = 1,


                        Guards = new TableActionGuards
                        {

                            AppliesTo = "any",

                            DisableWhenAny =
                                new List<TableActionRule>
                                {

                                    new TableActionRule
                                    {
                                        Field = "ReportStatus",

                                        Op = "neq",

                                        Value = "APPROVED",

                                        Message =
                                            "لايمكن تسجيل إرسال المسير قبل اعتماده",

                                        Priority = 3
                                    }

                                }

                        }

                    },

                    Edit2 = new TableAction
                    {
                        Label = "استعراض تفاصيل المسير",
                        Icon = "fa fa-list",
                        Color = "secondary",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تفاصيل المسير",
                        Show = true,

                        OpenForm = new FormConfig
                        {
                            FormId = "deductReportDetails",
                            Title = "تفاصيل المسير",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Fields = DeductDetailsFields,
                            Buttons = new List<FormButtonConfig>
        {
            new FormButtonConfig
            {
                Text = "إنهاء",
                Type = "button",
                Color = "secondary",
                OnClickJs = "window.__sfTableActive?.closeModal();"
            }
        }
                        },

                        Meta = extraMetaDeductDetails,

                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },


                    Delete = new TableAction
                    {
                        Label = "حذف المسير",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "حذف المسير",
                        ModalMessage = "عند الحذف لايمكن التراجع عن هذا الاجراء",

                        ModalMessageClass =
                            "bg-red-50 text-red-700",

                        ModalMessageIcon =
                            "fa-solid fa-triangle-exclamation",
                        Show = true,

                        OpenForm = new FormConfig
                        {
                            FormId = "deductReportDelete",
                            Title = "تأكيد حذف المسير",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حذف",   Type = "submit", Color = "danger",  },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = DeleteFields
                        },



                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,

                        Guards = new TableActionGuards
                        {

                            AppliesTo = "any",

                            DisableWhenAny =
                                new List<TableActionRule>
                                {

                                    new TableActionRule
                                    {
                                        Field = "ReportStatus",

                                        Op = "neq",

                                        Value = "DRAFT",

                                        Message =
                                            "لايمكن حذف المسير ",

                                        Priority = 3
                                    }

                                }

                        }
                    },


                    Print1 = new TableAction
                    {
                        Label = "طباعة المسير",
                        Icon = "fa fa-print",
                        Color = "info",

                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                        

                        Guards = new TableActionGuards
                        {

                            AppliesTo = "any",

                            DisableWhenAny =
                                new List<TableActionRule>
                                {

                                    new TableActionRule
                                    {
                                        Field = "ReportStatus",

                                        Op = "notin",

                                        Value = "APPROVED,SENT",

                                        Message =
                                            "لايمكن طباعة المسير قبل اعتماده ",

                                        Priority = 3
                                    }

                                }

                        },

                        OnClickJs = @"
    sfPrintWithBusy(table, {
        pdf: 1,
        extraParams: {
            reportID: row.DeductListReportID
        },
        busy: {
            title: 'طباعة مسير الحسم'
        }
    });
"
                    },

                }

            };



            // ============================================================
            // الجدول الثاني
            // تفاصيل المسير
            // ============================================================

            var dsModel2 = new SmartTableDsModel
            {

                PageTitle = "تفاصيل المسير",

                Columns = dynamicColumns2,

                Rows = rowsList2,

                RowIdField = rowIdField2,

                PageSize = 25,

                PageSizes = new List<int>
                {
                    25,
                    50,
                    100
                },

                QuickSearchFields =
                    dynamicColumns2
                    .Select(c => c.Field)
                    .Take(4)
                    .ToList(),

                Searchable = true,

                AllowExport = true,

                ShowPageSizeSelector = true,

                PanelTitle = "الفواتير المرسلة",

                EnableCellCopy = true,


                Toolbar = new TableToolbarConfig
                {

                    ShowRefresh = false,

                    ShowColumns = true,

                    ShowExportCsv = false,

                    ShowExportExcel = false,

                    ShowAdd = false,

                    ShowEdit = false,

                    ShowDelete = false,

                    ShowBulkDelete = false

                }

            };



            // ============================================================
            // الجدول الثالث
            // ملفات الحسم الواردة
            // ============================================================

            var dsModel3 = new SmartTableDsModel
            {

                PageTitle = "ملفات الحسم الواردة",

                Columns = dynamicColumns3,

                Rows = rowsList3,

                RowIdField = rowIdField3,

                PageSize = 25,

                PageSizes = new List<int>
                {
                    25,
                    50,
                    100
                },

                QuickSearchFields =
                    dynamicColumns3
                    .Select(c => c.Field)
                    .Take(4)
                    .ToList(),

                Searchable = true,

                AllowExport = true,

                ShowPageSizeSelector = true,

                PanelTitle = "ردود الجهة المالية",

                EnableCellCopy = true,


                Toolbar = new TableToolbarConfig
                {

                    ShowRefresh = false,

                    ShowColumns = true,

                    ShowExportCsv = false,

                    ShowExportExcel = false,

                    ShowAdd = false,

                    ShowEdit = false,

                    ShowDelete = false,

                    ShowBulkDelete = false

                }

            };



            // ============================================================
            // التحقق من وجود بيانات
            // ============================================================

            //bool dsModelHasRows =
            //    dt1 != null &&
            //    dt1.Rows.Count > 0;


            //bool dsModel2HasRows =
            //    dt2 != null &&
            //    dt2.Rows.Count > 0;


            //bool dsModel3HasRows =
            //    dt3 != null &&
            //    dt3.Rows.Count > 0;

            bool hasSelectedPeriod =
    year.HasValue &&
    year.Value > 0 &&
    month.HasValue &&
    month.Value is >= 1 and <= 12;

            bool dsModelHasRows =
                hasSelectedPeriod;
                //&&
                //dt1 != null &&
                //dt1.Rows.Count > 0;



            // ============================================================
            // الطباعة
            // ============================================================


            if (pdf == 1)
            {
                if (!reportID.HasValue || reportID.Value <= 0)
                    return Content("لم يتم تحديد مسير للطباعة.");

                var printParameters = new Dictionary<string, object?>
                {
                    ["pageName_"] = "DeductListReport",
                    ["ActionType"] = "GetDeductListReportPrint",
                    ["idaraID"] = IdaraId,
                    ["entrydata"] = usersId,
                    ["hostname"] = HostName,
                    ["parameter_01"] = reportID.Value
                };

                DataSet printDataSet =
                    await _mastersServies.GetExtraDataLoadDataSetAsync(printParameters);

                if (printDataSet.Tables.Count < 2 ||
                    printDataSet.Tables[0].Rows.Count == 0)
                {
                    return Content("المسير المحدد غير موجود أو لا يتبع لإدارتك.");
                }

                DataTable reportHeaderTable = printDataSet.Tables[0];
                DataTable reportDetailsTable = printDataSet.Tables[1];

                if (reportDetailsTable.Rows.Count == 0)
                    return Content("لا توجد فواتير داخل المسير المحدد.");

                DataRow reportRow = reportHeaderTable.Rows[0];

                string reportNo = reportRow["ReportNo"]?.ToString() ?? "";
                string serviceName =
                    reportRow["meterServiceTypeName_A"]?.ToString() ?? "خدمة";
                string periodMonth = reportRow["PeriodMonth"]?.ToString() ?? "";
                string periodYear = reportRow["PeriodYear"]?.ToString() ?? "";

                string reportSubject =
                    $"مسير حسم {serviceName} لشهر {periodMonth} لعام {periodYear}";

                var printTable = new DataTable();

                printTable.Columns.Add("BillNumber", typeof(string));
                printTable.Columns.Add("ResidentFullName_A", typeof(string));
                printTable.Columns.Add("GeneralNo_FK", typeof(string));
                printTable.Columns.Add("MilitaryUnitName_A", typeof(string));
                printTable.Columns.Add("BuildingDetailsNo", typeof(string));
                printTable.Columns.Add("BillsFromDate", typeof(string));
                printTable.Columns.Add("BillsToDate", typeof(string));
                printTable.Columns.Add("AmountBeforeTax", typeof(decimal));
                printTable.Columns.Add("TaxAmount", typeof(decimal));
                printTable.Columns.Add("TotalAmount", typeof(decimal));

                foreach (DataRow detailRow in reportDetailsTable.Rows)
                {
                    printTable.Rows.Add(
                        detailRow["BillNumber"]?.ToString() ?? "",
                        detailRow["ResidentFullName_A"]?.ToString() ?? "",
                        detailRow["GeneralNo_FK"]?.ToString() ?? "",
                        detailRow["MilitaryUnitName_A"]?.ToString() ?? "غير محددة",
                        detailRow["BuildingDetailsNo"]?.ToString() ?? "",
                        detailRow["BillsFromDate"] == DBNull.Value
                            ? ""
                            : Convert.ToDateTime(detailRow["BillsFromDate"])
                                .ToString("yyyy/MM/dd"),
                        detailRow["BillsToDate"] == DBNull.Value
                            ? ""
                            : Convert.ToDateTime(detailRow["BillsToDate"])
                                .ToString("yyyy/MM/dd"),
                        detailRow["AmountBeforeTax"] == DBNull.Value
                            ? 0m
                            : Convert.ToDecimal(detailRow["AmountBeforeTax"]),
                        detailRow["TaxAmount"] == DBNull.Value
                            ? 0m
                            : Convert.ToDecimal(detailRow["TaxAmount"]),
                        detailRow["TotalAmount"] == DBNull.Value
                            ? 0m
                            : Convert.ToDecimal(detailRow["TotalAmount"])
                    );
                }

                var reportColumns = new List<ReportColumn>
    {
        new("BillNumber", "رقم الفاتورة", Align: "center", Weight: 2, FontSize: 8),
        new("ResidentFullName_A", "اسم الساكن", Align: "center", Weight: 4, FontSize: 8),
        new("GeneralNo_FK", "الرقم العام", Align: "center", Weight: 2, FontSize: 8),
        new("MilitaryUnitName_A", "الوحدة", Align: "center", Weight: 3, FontSize: 8),
        new("BuildingDetailsNo", "المنزل", Align: "center", Weight: 2, FontSize: 8),
        new("BillsFromDate", "من", Align: "center", Weight: 2, FontSize: 8),
        new("BillsToDate", "إلى", Align: "center", Weight: 2, FontSize: 8),
        new("AmountBeforeTax", "قبل الضريبة", Align: "center", Weight: 2, FontSize: 8),
        new("TaxAmount", "الضريبة", Align: "center", Weight: 2, FontSize: 8),
        new("TotalAmount", "الإجمالي", Align: "center", Weight: 2, FontSize: 8)
    };

                var logo = Path.Combine(
                    _env.WebRootPath,
                    "img",
                    "Royal_Saudi_Land_Forces.png");

                var header = new Dictionary<string, string>
                {
                    ["no"] = reportNo,
                    ["date"] = DateTime.Now.ToString("yyyy/MM/dd"),
                    ["attach"] = "—",
                    ["subject"] = reportSubject,

                    ["right1"] = "المملكة العربية السعودية",
                    ["right2"] = "وزارة الدفاع",
                    ["right3"] = "القوات البرية الملكية السعودية",
                    ["right4"] = OrganizationName,
                    ["right5"] = IdaraName,
                    ["midCaption"] = ""
                };

                var report = DataTableReportBuilder.FromDataTable(
                    reportId: $"DeductListReport_{reportNo}",
                    title: reportSubject,
                    table: printTable,
                    columns: reportColumns,
                    headerFields: header,
                    footerFields: new Dictionary<string, string>
                    {
                        ["عدد الفواتير"] =
                            reportRow["InvoiceCount"]?.ToString() ?? "0",

                        //["إجمالي المسير"] =
                        //    Convert.ToDecimal(
                        //        reportRow["TotalAmount"] == DBNull.Value
                        //            ? 0m
                        //            : reportRow["TotalAmount"]
                        //    ).ToString("N2"),

                        ["تمت الطباعة بواسطة"] = FullName ?? "",
                        ["تاريخ ووقت الطباعة"] =
                            DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss")
                    },
                    orientation: ReportOrientation.Landscape,
                    headerType: ReportHeaderType.LetterOfficial,
                    logoPath: logo,
                    headerRepeat: ReportHeaderRepeat.AllPages
                    
                );

                report.GroupByKey = "MilitaryUnitName_A";
                report.GroupTitle = "الوحدة";
                report.StartEachGroupOnNewPage = true;

                var pdfBytes = QuestPdfReportRenderer.Render(report);

                Response.Headers["Content-Disposition"] =
                    $"inline; filename=DeductListReport_{reportNo}.pdf";

                return File(pdfBytes, "application/pdf");
            }


            // ============================================================
            // الصفحة
            // ============================================================

            var page = new SmartPageViewModel
            {

                Form = form,

                PageTitle = dsModel.PageTitle,

                PanelTitle = "إرسال ومتابعة مسيرات الحسم",

                PanelIcon = "fa-file-invoice-dollar",

                TableDS =
                //dsModel
                //,
                dsModelHasRows
                ? dsModel
                : null
                //,


                //TableDS2 =
                //    reportID.HasValue
                //    ? dsModel2
                //    : null,


                //TableDS3 =
                //    reportID.HasValue
                //    ? dsModel3
                //    : null

            };



            return View(
                "FinancialAudit/DeductListReport",
                page);
        }
    }
}
