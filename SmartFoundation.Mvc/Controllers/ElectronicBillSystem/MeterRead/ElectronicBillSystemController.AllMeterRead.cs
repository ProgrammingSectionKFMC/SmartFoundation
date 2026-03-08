using Microsoft.AspNetCore.Mvc;
using SmartFoundation.MVC.Reports;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartPrint;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Diagnostics.Metrics;
using System.Linq;
using System.Text.Json;
using static LLama.Common.ChatHistory;
using System.Net.Http.Json;


namespace SmartFoundation.Mvc.Controllers.ElectronicBillSystem
{
    public partial class ElectronicBillSystemController : Controller
    {
        public async Task<IActionResult> AllMeterRead(int pdf = 0)
        {
            //  قراءة السيشن والكونتكست
            if (!InitPageContext(out var redirect))
                return redirect!;

            string? MeterServiceTypeID_ = Request.Query["U"].FirstOrDefault();

            MeterServiceTypeID_ = string.IsNullOrWhiteSpace(MeterServiceTypeID_) ? null : MeterServiceTypeID_.Trim();

            bool ready = false;
            bool MeterServiceTypeready = false;



            ControllerName = nameof(ElectronicBillSystem);
            PageName = nameof(AllMeterRead);

            var spParameters = new object?[]
            {
             PageName ?? "AllMeterRead",
             IdaraId,
             usersId,
             HostName,
             MeterServiceTypeID_
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var rowsListbills = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();
            var dynamicColumnsbills = new List<TableColumn>();

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

            //  تقسيم الداتا سيت للجدول الأول + جداول أخرى
            SplitDataSet(ds);


            ready = !string.IsNullOrWhiteSpace(MeterServiceTypeID_);

            if (dt1 != null && dt1.Rows.Count > 0)
            {
                MeterServiceTypeready = true;
            }
            else
            {
                MeterServiceTypeready = false;
            }


            string? PeriodID_ = dt1?.Rows.Count > 0
                    ? dt1.Rows[0]["billPeriodID"]?.ToString()
                     : null;


            //  التحقق من الصلاحيات
            //if (permissionTable is null || permissionTable.Rows.Count == 0)
            //{
            //    TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
            //    return RedirectToAction("Index", "Home");
            //}

            string rowIdField = "";
            string rowbillsIdField = "";
            int count = 0;
            bool openperiod = false;
            bool closeperiod = false;

            if (dt1 != null && dt1.Rows.Count > 0 &&
                dt1.Columns.Contains("billPeriodID") &&
                dt1.Columns.Contains("AssignPeriodID"))
            {
                count = dt1.AsEnumerable()
                    .Count();
            }





            if (dt1 != null && dt1.Rows.Count > 0 && MeterServiceTypeID_ is not null)
            {

                TempData["countBiggerThanzero"] = $"يوجد فترة قراءة عدادت نشطة لهذا الشهر سارع بانهائها !! ";
                openperiod = false;
                closeperiod = true;
            }

            else if ((dt1 == null || dt1.Rows.Count == 0) && MeterServiceTypeID_ is not null)   // ✅ تصحيح: == بدلاً من =
            {
                TempData["countEqualzero"] = $"لايوجد فترة قراءة عدادت نشطة لهذا الشهر قم بانشاء فترة للبدء بقراءة العدادات !! ";
                openperiod = true;
                closeperiod = false;
            }



            bool canOPENMETERREADPERIOD = false;
            bool canCLOSEMETERREADPERIOD = false;
            bool canREADELECTRICITYMETER = false;
            bool canEDITELECTRICITYMETER = false;
            bool canDELETEELECTRICITYMETER = false;
            bool canREADWATERMETER = false;
            bool canEDITWATERMETER = false;
            bool canDELETEWATERMETER = false;
            bool canREADGASMETER = false;
            bool canEDITGASMETER = false;
            bool canDELETEGASMETER = false;


            FormConfig form = new();

            List<OptionItem> MeterServiceTypeOptions = new();
            List<OptionItem> MeterOptions = new();


            // ---------------------- DDLValues ----------------------




            JsonResult? result;
            string json;




            //// ---------------------- MeterServiceTypeOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "meterServiceTypeName_A", "meterServiceTypeID", "3", nameof(AllMeterRead), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            MeterServiceTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            //// ---------------------- MeterServiceTypeOptions ----------------------
            var tMeters = (ds.Tables.Count > 4) ? ds.Tables[4] : null;

            var meterOptions = new List<OptionItem>();
            if (tMeters != null)
            {
                foreach (DataRow r in tMeters.Rows)
                {
                    meterOptions.Add(new OptionItem
                    {
                        Value = r["meterID"]?.ToString(),
                        Text = r["meterNo"]?.ToString(),
                    });
                }
            }

            MeterOptions = meterOptions;


            // //// ---------------------- MeterOptions ----------------------
            // result = await _CrudController.GetDDLValues(
            //     "meterNo", "meterID", "3", nameof(AllMeterRead), usersId, IdaraId, HostName,MeterServiceTypeID_
            //) as JsonResult;


            // json = JsonSerializer.Serialize(result!.Value);

            // MeterOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;



            //// ---------------------- MeterOptions ----------------------
            //            result = await _CrudController.GetDDLValues(
            //    "meterNo",                 // Text
            //    "meterID",                 // Value
            //    "4",
            //    nameof(AllMeterRead),
            //    usersId, IdaraId, HostName
            //) as JsonResult;

            //            json = JsonSerializer.Serialize(result!.Value);
            //            MeterOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


            // ----------------------END DDLValues ----------------------

            try
            {

                form = new FormConfig
                {
                    Fields = new List<FieldConfig>
                                {
                                    new FieldConfig
                                    {
                                        SectionTitle = "اختيار نوع خدمة العدادات",
                                        Name = "MeterServiceType",
                                        Type = "select",
                                        Select2 = true,
                                        Options = MeterServiceTypeOptions,
                                        ColCss = "3",
                                        Placeholder = "اختر نوع خدمة العدادات",
                                        Icon = "fa fa-user",
                                        Value = MeterServiceTypeID_,
                                        OnChangeJs = "sfNav(this)",
                                        NavUrl = "/ElectronicBillSystem/AllMeterRead",
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
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "OPENMETERREADPERIOD") canOPENMETERREADPERIOD = true;
                        if (permissionName == "CLOSEMETERREADPERIOD") canCLOSEMETERREADPERIOD = true;

                        if (permissionName == "READELECTRICITYMETER") canREADELECTRICITYMETER = true;
                        if (permissionName == "EDITELECTRICITYMETER") canEDITELECTRICITYMETER = true;
                        if (permissionName == "DELETEELECTRICITYMETER") canDELETEELECTRICITYMETER = true;
                        if (permissionName == "READWATERMETER") canREADWATERMETER = true;
                        if (permissionName == "EDITWATERMETER") canEDITWATERMETER = true;
                        if (permissionName == "DELETEWATERMETER") canDELETEWATERMETER = true;
                        if (permissionName == "READGASMETER") canREADGASMETER = true;
                        if (permissionName == "EDITGASMETER") canEDITGASMETER = true;
                        if (permissionName == "DELETEGASMETER") canDELETEGASMETER = true;


                    }

                    if (dt1 != null && dt1.Columns.Count > 0)
                    {

                       
                        // RowId
                        rowIdField = "billPeriodID";
                        var possibleIdNames = new[] { "billPeriodID", "BillPeriodID", "Id", "ID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["billPeriodID"] = "الرقم المرجعي للفترة",
                            ["billPeriodName_A"] = "الشهر",
                            ["billPeriodName_E"] = "الفترة بالانجليزي",
                            ["billPeriodStartDate"] = "تاريخ بداية الفترة",
                            ["billPeriodEndDate"] = "تاريخ نهاية الفترة",
                            ["billPeriodYear"] = "السنة",
                            ["AllMetersCount"] = "اجمالي عدد العدادات",
                            ["AllmeterReaded"] = "العدادات المقروءة",
                            ["AllMeterNotReaded"] = "المتبقي",
                            ["billPeriodTypeName_A"] = "نوع الفترة"
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

                            bool isHidden = c.ColumnName.Equals("billPeriodTypeID_FK", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("billPeriodActive", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("IdaraId_FK", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("ClosedBy", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("billPeriodName_E", StringComparison.OrdinalIgnoreCase);




                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                //if u want to hide any column 
                                ,
                                Visible = !(isHidden)
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
                            dict["p01"] = Get("BillPeriodID") ?? Get("billPeriodID");
                            dict["p02"] = Get("billPeriodTypeID_FK");
                            dict["p03"] = Get("billPeriodTypeName_A");
                            dict["p04"] = Get("billPeriodName_A");
                            dict["p05"] = Get("billPeriodName_E");
                            dict["p06"] = Get("billPeriodStartDate");
                            dict["p07"] = Get("billPeriodEndDate");
                            dict["p08"] = Get("billPeriodActive");
                            dict["p09"] = Get("ClosedBy");
                            dict["p10"] = Get("IdaraId_FK");


                            rowsList.Add(dict);
                        }


                       
                    }


                    if (dt2 != null && dt2.Columns.Count > 0)
                    {


                        // RowId
                        rowbillsIdField = "BillsID";
                        var possibleIdNames = new[] { "BillsID", "billsID", "Id", "ID" };
                        rowbillsIdField = possibleIdNames.FirstOrDefault(n => dt2.Columns.Contains(n))
                                     ?? dt2.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["BillsID"] = "الرقم المرجعي",
                            ["BillNumber"] = "رقم الفاتورة",
                            ["PeriodMonth"] = "الشهر",
                            ["PeriodYear"] = "السنة",
                            ["meterNo"] = "رقم العداد",
                            ["meterName_A"] = "اسم العداد",
                            ["buildingDetailsNo"] = "رقم المبنى",
                            ["CurrentRead"] = "القراءة الحالية",
                            ["LastRead"] = "القراءة السابقة",
                            ["ReadDiff"] = "الفرق",
                            ["PriceForSlide1"] = "شريحة 1",
                            ["PriceForSlide2"] = "شريحة 2",
                            ["PriceForSlide3"] = "شريحة 3",
                            ["PriceForSlide4"] = "شريحة 4",
                            ["PriceForSlide5"] = "شريحة 5",
                            ["PriceForSlide6"] = "شريحة 6",
                            ["PriceForSlide7"] = "شريحة 7",
                            ["PriceForSlide8"] = "شريحة 8",
                            ["PriceForSlide9"] = "شريحة 9",
                            ["PriceForSlide10"] = "شريحة 10",
                            ["PRICE"] = "المبلغ",
                            ["PRICETAX"] = "الضريبة",
                            ["meterServicePrice"] = "قيمة الخدمة",
                            ["meterServicePriceWithTAX"] = "قيمة خدمة العداد",
                            ["meterServicePriceTAX"] = "ضريبة الخدمة",
                            ["TotalPrice"] = "الاجمالي",
                            ["avrageMsg"] = "الحالة",
                            
                            ["previosBillTotalPrice"] = "الفاتورة السابقة",
                            ["entryDate"] = "وقت التنفيذ"
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
                            bool isHidden;
                            if (MeterServiceTypeID_ == "1")
                            {
                                isHidden = c.ColumnName.Equals("meterID", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("buildingDetailsID", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("idaraID_FK", StringComparison.OrdinalIgnoreCase)
                                           // || c.ColumnName.Equals("meterReadID", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("entryData", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("avrageNo", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("entryDate", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PeriodMonth", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PeriodYear", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("meterName_A", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("meterServicePriceTAX", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("meterServicePrice", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PriceForSlide3", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PriceForSlide4", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PriceForSlide5", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PriceForSlide6", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PriceForSlide7", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PriceForSlide8", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PriceForSlide9", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PriceForSlide10", StringComparison.OrdinalIgnoreCase);

                            }
                            else if (MeterServiceTypeID_ == "2")
                            {
                                isHidden = c.ColumnName.Equals("meterID", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("buildingDetailsID", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("idaraID_FK", StringComparison.OrdinalIgnoreCase)
                                            //|| c.ColumnName.Equals("meterReadID", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("entryData", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("avrageNo", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("entryDate", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PeriodMonth", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PeriodYear", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("meterName_A", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("meterServicePriceTAX", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("meterServicePrice", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PriceForSlide6", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PriceForSlide7", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PriceForSlide8", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PriceForSlide9", StringComparison.OrdinalIgnoreCase)
                                            || c.ColumnName.Equals("PriceForSlide10", StringComparison.OrdinalIgnoreCase);

                            }
                            else if (MeterServiceTypeID_ == "3")
                            {
                                isHidden = c.ColumnName.Equals("meterID", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("buildingDetailsID", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("idaraID_FK", StringComparison.OrdinalIgnoreCase)
                                            // || c.ColumnName.Equals("meterReadID", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("entryData", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("avrageNo", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("entryDate", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PeriodMonth", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PeriodYear", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("meterName_A", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("meterServicePriceTAX", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("meterServicePrice", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide2", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide3", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide4", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide5", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide6", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide7", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide8", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide9", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide10", StringComparison.OrdinalIgnoreCase);

                            }
                            else 
                            {
                                isHidden = c.ColumnName.Equals("meterID", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("buildingDetailsID", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("idaraID_FK", StringComparison.OrdinalIgnoreCase)
                                             //|| c.ColumnName.Equals("meterReadID", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("entryData", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("avrageNo", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("entryDate", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PeriodMonth", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PeriodYear", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("meterName_A", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("meterServicePriceTAX", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("meterServicePrice", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide1", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide2", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide3", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide4", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide5", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide6", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide7", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide8", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide9", StringComparison.OrdinalIgnoreCase)
                                             || c.ColumnName.Equals("PriceForSlide10", StringComparison.OrdinalIgnoreCase);

                            }





                            dynamicColumnsbills.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                //if u want to hide any column 
                                ,
                                Visible = !(isHidden)
                            });
                        }

                        // الصفوف
                        foreach (DataRow r in dt2.Rows)
                        {
                            var dictbills = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt2.Columns)
                            {
                                var val = r[c];
                                dictbills[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            // p01..p05
                            object? Get(string key) => dictbills.TryGetValue(key, out var v) ? v : null;
                            dictbills["p01"] = Get("BillsID") ?? Get("billsID");
                            dictbills["p02"] = Get("BillNumber");
                            dictbills["p03"] = Get("PeriodMonth");
                            dictbills["p04"] = Get("PeriodYear");
                            dictbills["p05"] = Get("meterID");
                            dictbills["p06"] = Get("meterName_A");
                            dictbills["p07"] = Get("buildingDetailsNo");
                            dictbills["p08"] = Get("buildingDetailsID");
                            dictbills["p09"] = Get("meterReadID");
                            dictbills["p10"] = Get("CurrentRead");
                            dictbills["p11"] = Get("LastRead");
                            dictbills["p12"] = Get("ReadDiff");
                            dictbills["p13"] = Get("TotalPrice");
                            



                            rowsListbills.Add(dictbills);
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
            var OpenMetersReadPeriodFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "OPENMETERREADPERIOD" },
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
                
                new FieldConfig { Name = "p01", Label = "MeterServiceTypeID_", Type = "hidden", Value=MeterServiceTypeID_ },
              

            };

            var CLOSEMetersReadPeriodFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "CLOSEMETERREADPERIOD" },
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
                
               
                new FieldConfig { Name = "p01", Label = "PeriodID_", Type = "text", ColCss = "3", Required = true, Value = PeriodID_ },
                 new FieldConfig { Name = "p02", Label = "MeterServiceTypeID_", Type = "text", Value=MeterServiceTypeID_ },


            };


            var READELECTRICITYMETERFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "READELECTRICITYMETER" },
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
                
                new FieldConfig { Name = "p01", Label = "MeterServiceTypeID_", Type = "hidden", Value=MeterServiceTypeID_ },
                new FieldConfig { Name = "p02", Label = "رقم العداد", Type = "select", ColCss = "3", Required = true, Options= MeterOptions },
                new FieldConfig { Name = "p03", Label = "PeriodID_", Type = "hidden", ColCss = "3", Required = true, Value = PeriodID_ },
                new FieldConfig
                    {
                        Name = "p04",
                        Label = "القراءة الجديدة",
                        Type = "search",
                        TextMode = "numeric",
                        ColCss = "6",
                        Required = true,
                        ExtraButton = new Dictionary<string, object?>
                        {
                            ["Text"] = "تحقق",
                            ["ClassName"] = "btn btn-warning",
                            ["SlotKey"] = "m3"
                        }
                    },


            };

            var EDITELECTRICITYMETERFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "EDITELECTRICITYMETER" },
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
                
                new FieldConfig { Name = "p41", Label = "MeterServiceTypeID_", Type = "text", Value=MeterServiceTypeID_ },
                new FieldConfig { Name = "p01", Label = "BillsID", Type = "text" },
                new FieldConfig { Name = "p05", Label = "MeterID", Type = "number", ColCss = "3", Required = true },
                new FieldConfig { Name = "p09", Label = "ReadID", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p10", Label = "CurrentRead", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p39", Label = "PeriodID_", Type = "text", ColCss = "3", Required = true, Value = PeriodID_ },


            };

            var DELETEELECTRICITYMETERFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETEELECTRICITYMETER" },
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
                
                new FieldConfig { Name = "p41", Label = "MeterServiceTypeID_", Type = "hidden", Value=MeterServiceTypeID_ },
                new FieldConfig { Name = "p01", Label = "BillsID", Type = "text" },
                new FieldConfig { Name = "p05", Label = "MeterID", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p09", Label = "ReadID", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p10", Label = "CurrentRead", Type = "text", ColCss = "3", Required = true },
               

            };


            var READWATERMETERFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "READWATERMETER" },
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
                
                new FieldConfig { Name = "p01", Label = "MeterServiceTypeID_", Type = "hidden", Value=MeterServiceTypeID_ },
                new FieldConfig { Name = "p02", Label = "رقم العداد", Type = "select", ColCss = "3", Required = true, Options= MeterOptions, Select2=true },
                new FieldConfig { Name = "p03", Label = "PeriodID_", Type = "hidden", ColCss = "3", Required = true, Value = PeriodID_ },
               new FieldConfig
                    {
                        Name = "p04",
                        Label = "القراءة الجديدة",
                        Type = "search",
                        TextMode = "numeric",
                        ColCss = "6",
                        ExtraButton = new Dictionary<string, object?>
                        {
                            ["Text"] = "تحقق",
                            ["ClassName"] = "btn btn-warning",
                            ["SlotKey"] = "m3"
                        }
                    },
                    new FieldConfig { Name = "p50", Label = "هل انت متأكد", Type = "checkbox" },



            };

            var EDITWATERMETERFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "EDITWATERMETER" },
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
                
                 new FieldConfig { Name = "p41", Label = "MeterServiceTypeID_", Type = "text", Value=MeterServiceTypeID_ },
                new FieldConfig { Name = "p01", Label = "BillsID", Type = "text" },
                new FieldConfig { Name = "p05", Label = "MeterID", Type = "number", ColCss = "3", Required = true },
                new FieldConfig { Name = "p09", Label = "ReadID", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p10", Label = "CurrentRead", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p39", Label = "PeriodID_", Type = "text", ColCss = "3", Required = true, Value = PeriodID_ },


            };

            var DELETEWATERMETERFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETEWATERMETER" },
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
                
                new FieldConfig { Name = "p41", Label = "MeterServiceTypeID_", Type = "hidden", Value=MeterServiceTypeID_ },
                new FieldConfig { Name = "p01", Label = "BillsID", Type = "text" },
                new FieldConfig { Name = "p05", Label = "MeterID", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p09", Label = "ReadID", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p10", Label = "CurrentRead", Type = "text", ColCss = "3", Required = true },


            };


            var READGASMETERFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "READGASMETER" },
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
                
                new FieldConfig { Name = "p01", Label = "MeterServiceTypeID_", Type = "hidden", Value=MeterServiceTypeID_ },
                new FieldConfig { Name = "p02", Label = "رقم العداد", Type = "select", ColCss = "3", Required = true, Options= MeterOptions },
                new FieldConfig { Name = "p03", Label = "PeriodID_", Type = "hidden", ColCss = "3", Required = true, Value = PeriodID_ },
               new FieldConfig
                    {
                        Name = "p04",
                        Label = "القراءة الجديدة",
                        Type = "search",
                        TextMode = "numeric",
                        ColCss = "6",
                        ExtraButton = new Dictionary<string, object?>
                        {
                            ["Text"] = "تحقق",
                            ["ClassName"] = "btn btn-warning",
                            ["SlotKey"] = "m3"
                        }
                    },


            };

            var EDITGASMETERFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "EDITGASMETER" },
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
                
                 new FieldConfig { Name = "p41", Label = "MeterServiceTypeID_", Type = "text", Value=MeterServiceTypeID_ },
                new FieldConfig { Name = "p01", Label = "BillsID", Type = "text" },
                new FieldConfig { Name = "p05", Label = "MeterID", Type = "number", ColCss = "3", Required = true },
                new FieldConfig { Name = "p09", Label = "ReadID", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p10", Label = "CurrentRead", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p39", Label = "PeriodID_", Type = "text", ColCss = "3", Required = true, Value = PeriodID_ },


            };

            var DELETEGASMETERFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETEGASMETER" },
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
                
                new FieldConfig { Name = "p41", Label = "MeterServiceTypeID_", Type = "hidden", Value=MeterServiceTypeID_ },
                new FieldConfig { Name = "p01", Label = "BillsID", Type = "text" },
                new FieldConfig { Name = "p05", Label = "MeterID", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p09", Label = "ReadID", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p10", Label = "CurrentRead", Type = "text", ColCss = "3", Required = true },


            };


            var extraCtx = new Dictionary<string, object?>
            {
                ["idaraID"] = IdaraId,
                ["entrydata"] = usersId,
                ["hostname"] = HostName
            };

            var extraRequestBase = new Dictionary<string, object?>
            {
                ["pageName_"] = PageName,          // ديناميك حسب الصفحة
                ["ActionType"] = "MeterLastBill",// غيّره حسب احتياجك
                ["tableIndex"] = 0
            };

            var extraMeta_DependsOnSelect_MultiParams = new Dictionary<string, object?>
            {
                ["useRowExtra"] = true,
                ["lazyExtra"] = true,
                ["extraEndpoint"] = "/crud/extradataload",
                ["allowNoSelection"] = true,
                ["EnableSearch"] = false,   // أو true
                ["ShowMeta"] = false,        // أو false
                ["PageSize"] = 5,           // 5/10/20...
                ["Sortable"] = false,        // أو false
                ["showRowNumbers"] = false,
                ["emptyText"] = "لا يوجد بيانات",
                ["extraSlotKey"] = "m1",
                ["extraTitle"] = "الجدول ب",

                ["ctx"] = extraCtx,
                ["extraRequest"] = extraRequestBase,

                // يعتمد على اختيار
                ["extraDependsOn"] = "p02",
                ["extraLoadOnOpen"] = false,
                ["extraEmptyTextBeforeSelect"] = "",

                // ✅ جديد: خارطة باراميترات متعددة من فورم المودل
                // p01 -> parameter_01
                // p02 -> parameter_02
                ["extraParamMap"] = new Dictionary<string, string>
                {
                    ["parameter_01"] = "p01",
                    ["parameter_02"] = "p02",
                    ["parameter_03"] = "p03"
                },
                ["visibleFields"] = new List<string>
                                {
                                    "meterNo","CurrentRead","TotalPrice"
                                },
                ["headerMap"] = new Dictionary<string, string>
                {
                    ["meterID"] = "رقم العداد المرجعيٍ",
                    ["meterNo"] = "رقم العداد",
                    ["TotalPrice"] = "مبلغ الفاتورة السابقة",
                    ["CurrentRead"] = "القراءة السابقة",
                    ["periods_"] = "فترة الفاتورة السابقة",

                },

                // (اختياري) باراميترات ثابتة إضافية مع الخريطة
                //["extraParams"] = new Dictionary<string, object?>
                //{
                //    //["parameter_03"] = "STATIC",
                //    ["parameter_02"] = 1
                //},


            };

            var extraCtx2 = new Dictionary<string, object?>
            {
                ["idaraID"] = IdaraId,
                ["entrydata"] = usersId,
                ["hostname"] = HostName
            };

            var extraRequestBase2 = new Dictionary<string, object?>
            {
                ["pageName_"] = PageName,          // ديناميك حسب الصفحة
                ["ActionType"] = "MeterNewBill",// غيّره حسب احتياجك
                ["tableIndex"] = 0
            };

            var extraMeta2 = new Dictionary<string, object?>
            {
               
              
                ["EnableSearch"] = false,   // أو true
                ["ShowMeta"] = false,        // أو false
                ["PageSize"] = 5,           // 5/10/20...
                ["Sortable"] = false,        // أو false
                ["showRowNumbers"] = false,

                ["extraSlotKey"] = "m3",
                ["extraTitle"] = "الجدول الثاني",
                ["useRowExtra"] = true,
                ["lazyExtra"] = true,
                ["extraEndpoint"] = "/crud/extradataload",
                ["allowNoSelection"] = true,

                ["extraTriggerMode"] = "button",
                ["extraTriggerField"] = "p50",

                ["extraTriggerMode"] = "button",
                ["extraTriggerField"] = "p03",
                ["extraButtonText"] = "تحقق",

                ["ctx"] = extraCtx2,
                ["extraRequest"] = extraRequestBase2,

                ["extraParamMap"] = new Dictionary<string, string>
                {
                    ["parameter_01"] = "p01",
                    ["parameter_04"] = "p04",
                    ["parameter_02"] = "p02"
                },
                ["toggleField"] = "p50",
                ["toggleColumn"] = "checks",
                ["toggleOperator"] = "=",
                ["toggleValue"] = 0,
                ["toggleDefaultHidden"] = true,
                ["toggleRequiredWhenShown"] = true,


                //["toggleField"] = "p50",
                //["toggleColumn"] = "TotalPrice",
                //["toggleOperator"] = "=",
                //["toggleCompareColumn"] = "ServicePriceWithTAX",


                ["visibleFields"] = new List<string>
    {
         "meterNo","LastRead","CurrentRead","ReadDiff","PRICE","PRICETAX","ServicePriceWithTAX","TotalPrice","checks"
    },

                ["headerMap"] = new Dictionary<string, string>
                {
                    ["meterNo"] = "رقم العداد",
                    ["LastRead"] = "القراءة السابقة",
                    ["CurrentRead"] = "القراءة الحالية",
                    ["ReadDiff"] = "فرق القراءة",
                    ["PRICE"] = "المبلغ",
                    ["PRICETAX"] = "الضريبة",
                    ["ServicePriceWithTAX"] = "رسوم الخدمة",
                    ["TotalPrice"] = "الاجمالي"
                }
            };

            var extraEditCtx = new Dictionary<string, object?>
            {
                ["idaraID"] = IdaraId,
                ["entrydata"] = usersId,
                ["hostname"] = HostName
            };

            var extraEditRequestBase = new Dictionary<string, object?>
            {
                ["pageName_"] = PageName,
                ["ActionType"] = "EditBill",
                ["tableIndex"] = 0
            };

            var extraMetaAutoOpen = new Dictionary<string, object?>
            {
                ["extraSlotKey"] = "m1",
                ["extraTitle"] = "بيانات إضافية",
                ["useRowExtra"] = true,
                ["lazyExtra"] = true,
                ["extraEndpoint"] = "/crud/extradataload",
                ["allowNoSelection"] = true,

                // المهم
                ["extraLoadOnOpen"] = true,

                ["ctx"] = extraEditCtx,
                ["extraRequest"] = extraEditRequestBase,

                ["extraParamMap"] = new Dictionary<string, string>
                {
                    ["parameter_01"] = "p01"
                    //,
                    //["parameter_05"] = "p05"
                },

                ["EnableSearch"] = false,
                ["ShowMeta"] = false,
                ["PageSize"] = 10,
                ["Sortable"] = false,
                ["showRowNumbers"] = false,

                ["visibleFields"] = new List<string>
    {
        "meterNo","LastRead", "CurrentRead","ReadDiff", "TotalPrice"
    },

                ["headerMap"] = new Dictionary<string, string>
                {
                    ["meterNo"] = "رقم العداد",
                    ["LastRead"] = "القراءة السابقة",
                    ["CurrentRead"] = "القراءة الحالية",
                    ["ReadDiff"] = "فرق القراءة",
                    ["TotalPrice"] = "الإجمالي"
                }
            };


            //  UPDATE fields (Form Default / Form 46+)  تجريبي نرجع نمسحه او نعدل عليه

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "قراءة العدادات الدورية",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector=true,
                PanelTitle = "قراءة العدادات الدورية",
                //TabelLabel = "بيانات المستفيدين",
                //TabelLabelIcon = "fa-solid fa-user-group",
                EnableCellCopy = true,
                ShowColumnVisibility = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                RenderAsToggle = true,
                ToggleLabel = "فترات القراءة",
                ToggleIcon = "fa-solid fa-newspaper",
                ToggleDefaultOpen = true,
                ShowToggleCount = false,
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,

                    ShowAdd = canOPENMETERREADPERIOD && !MeterServiceTypeready,
                    ShowEdit1 = canCLOSEMETERREADPERIOD && MeterServiceTypeready,
                    
                    
                    ShowBulkDelete = false,
                    
                   


                       CustomActions = new List<TableAction>
                       {
                                
                            new TableAction
                            {
                                Label = "عرض التفاصيل",
                                ModalTitle = "<i class='fa-solid fa-circle-info text-emerald-600 text-xl mr-2'></i> تفاصيل المستفيد",
                                Icon = "fa-regular fa-file",
                                //Show = true,  // ✅ أضف
                                OpenModal = true,
                                RequireSelection = true,
                                MinSelection = 1,
                                MaxSelection = 1,
                                

                            },
                        },

                    Add = new TableAction
                    {
                        Label = "فتح فترة قراءة عدادات",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "فتح فترة قراءة عدادات",
                        ModalMessage = "هل أنت متأكد من فترة قراءة عدادات جديدة لهذه الخدمة؟",
                        ModalMessageClass = "bg-blue-50 text-blue-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassInsertForm",
                            Title = "بيانات فترة قراءة عدادات",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = OpenMetersReadPeriodFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ",   Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },
                    Edit1 = new TableAction
                    {
                        Label = "اغلاق فترة قراءة عدادات",
                        Icon = "fa fa-plus",
                        Color = "danger",
                        OpenModal = true,
                        ModalTitle = "اغلاق فترة قراءة عداداتت",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassInsertForm",
                            Title = "بيانات اغلاق فترة قراءة عدادات",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = CLOSEMetersReadPeriodFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ",   Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
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
                                Field = "AllMeterNotReaded",
                                Op = "neq",
                                Value = "0",
                                Message = "لايمكن اغلاق الفترة قبل انهاء قراءة جميع العدادات ",
                                Priority = 3
                            },


                          }
                        }
                    },
                   
                   


                  

                   

                 

                }
            };



            var metaB = new Dictionary<string, object?>(extraMeta_DependsOnSelect_MultiParams)
            {
                ["extraSlotKey"] = "m2",
                ["extraTitle"] = "بيانات الفاتورة السابقة"
            };

            var metaC = new Dictionary<string, object?>(extraMeta2)
            {
                ["extraSlotKey"] = "m3",
                ["extraTitle"] = "الفاتورة الجديدة المتوقعه"
            };



            var dsModelELECTRICITYMETER = new SmartTableDsModel
            {
                PageTitle = "قراءة العدادات الدورية",
                Columns = dynamicColumnsbills,
                Rows = rowsListbills,
                RowIdField = rowbillsIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumnsbills.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                PanelTitle = "قراءة العدادات الدورية",
                //TabelLabel = "بيانات المستفيدين",
                //TabelLabelIcon = "fa-solid fa-user-group",
                EnableCellCopy = true,
                ShowColumnVisibility = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                RenderAsToggle = true,
                ToggleLabel = "قراءة العدادات",
                ToggleIcon = "fa-solid fa-gauge",
                ToggleDefaultOpen = true,
                ShowToggleCount = false,
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,

                    ShowAdd = canREADELECTRICITYMETER,
                    ShowEdit = canEDITELECTRICITYMETER,
                    ShowDelete = canDELETEELECTRICITYMETER,


                    ShowBulkDelete = false,



                    ExportConfig = new TableExportConfig
                    {
                        EnablePdf = true,
                        PdfEndpoint = "/exports/pdf/table",
                        PdfTitle = " إمهال المستفيدين",
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
                        PdfLogoUrl = "/img/ppng.png",


                    },

                    CustomActions = new List<TableAction>
                            {
 
                             //  details "       
                            new TableAction
                            {
                                Label = "عرض التفاصيل",
                                ModalTitle = "<i class='fa-solid fa-circle-info text-emerald-600 text-xl mr-2'></i> تفاصيل المستفيد",
                                Icon = "fa-regular fa-file",
                                //Show = true,  // ✅ أضف
                                OpenModal = true,
                                RequireSelection = true,
                                MinSelection = 1,
                                MaxSelection = 1,


                            },
                        },

                   

                    Add = new TableAction
                    {
                        Label = "اضافة قراءة عداد كهرباء جديدة",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "اضافة قراءة عداد كهرباء جديدة",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassInsertForm",
                            Title = "بيانات قراءة عداد كهرباء جديدة",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = READELECTRICITYMETERFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ",   Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        },
                        Meta = metaB
                        ,
                        Meta1 = metaC
                    },


                    Edit = new TableAction
                    {
                        Label = "تعديل قراءة عداد كهرباء",
                        Icon = "fa-solid fa-edit",
                        Color = "warning",
                        OpenModal = true,
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,

                        OpenForm = new FormConfig
                        {
                            FormId = "ResidentActionInsert",
                            Title = "إضافة إجراء",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = EDITELECTRICITYMETERFields,
                            Buttons = new List<FormButtonConfig>
        {
            new() { Text="حفظ", Type="submit", Color="success" },
            new() { Text="إلغاء", Type="button", Color="secondary",
                    OnClickJs="this.closest('.sf-modal').__x.$data.closeModal();" }
        }
                        },

                        Meta = extraMetaAutoOpen
                    },







                }
            };


            var dsModelWATERMETER = new SmartTableDsModel
            {
                PageTitle = "قراءة العدادات الدورية",
                Columns = dynamicColumnsbills,
                Rows = rowsListbills,
                RowIdField = rowbillsIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumnsbills.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                PanelTitle = "قراءة العدادات الدورية",
                //TabelLabel = "بيانات المستفيدين",
                //TabelLabelIcon = "fa-solid fa-user-group",
                EnableCellCopy = true,
                ShowColumnVisibility = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                RenderAsToggle = true,
                ToggleLabel = "قراءة العدادات",
                ToggleIcon = "fa-solid fa-gauge",
                ToggleDefaultOpen = true,
                ShowToggleCount = false,
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,

                    ShowAdd = canREADWATERMETER,
                    ShowEdit = canEDITWATERMETER,
                    ShowDelete = canDELETEWATERMETER,


                    ShowBulkDelete = false,



                    ExportConfig = new TableExportConfig
                    {
                        EnablePdf = true,
                        PdfEndpoint = "/exports/pdf/table",
                        PdfTitle = " إمهال المستفيدين",
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
                        PdfLogoUrl = "/img/ppng.png",


                    },

                    CustomActions = new List<TableAction>
                            {
 
                             //  details "       
                            new TableAction
                            {
                                Label = "عرض التفاصيل",
                                ModalTitle = "<i class='fa-solid fa-circle-info text-emerald-600 text-xl mr-2'></i> تفاصيل المستفيد",
                                Icon = "fa-regular fa-file",
                                //Show = true,  // ✅ أضف
                                OpenModal = true,
                                RequireSelection = true,
                                MinSelection = 1,
                                MaxSelection = 1,


                            },
                        },



                    Add = new TableAction
                    {
                        Label = "اضافة قراءة عداد مياه جديدة",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "اضافة قراءة عداد مياه جديدة",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassInsertForm",
                            Title = "بيانات قراءة عداد مياه جديدة",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = READWATERMETERFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ",   Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        },
                        Meta = metaB
                       ,
                        Meta1 = metaC
                    },


                    Edit = new TableAction
                    {
                        Label = "تعديل قراءة عداد مياه",
                        Icon = "fa-solid fa-edit",
                        Color = "warning",
                        OpenModal = true,
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,

                        OpenForm = new FormConfig
                        {
                            FormId = "ResidentActionInsert",
                            Title = "إضافة إجراء",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = EDITWATERMETERFields,
                            Buttons = new List<FormButtonConfig>
        {
            new() { Text="حفظ", Type="submit", Color="success" },
            new() { Text="إلغاء", Type="button", Color="secondary",
                    OnClickJs="this.closest('.sf-modal').__x.$data.closeModal();" }
        }
                        },

                        Meta = extraMetaAutoOpen
                    },







                }
            };


            var dsModelGASMETER = new SmartTableDsModel
            {
                PageTitle = "قراءة العدادات الدورية",
                Columns = dynamicColumnsbills,
                Rows = rowsListbills,
                RowIdField = rowbillsIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumnsbills.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                PanelTitle = "قراءة العدادات الدورية",
                //TabelLabel = "بيانات المستفيدين",
                //TabelLabelIcon = "fa-solid fa-user-group",
                EnableCellCopy = true,
                ShowColumnVisibility = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                RenderAsToggle = true,
                ToggleLabel = "قراءة العدادات",
                ToggleIcon = "fa-solid fa-gauge",
                ToggleDefaultOpen = true,
                ShowToggleCount = false,
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,

                    ShowAdd = canREADGASMETER,
                    ShowEdit = canEDITGASMETER,
                    ShowDelete = canDELETEGASMETER,


                    ShowBulkDelete = false,



                    ExportConfig = new TableExportConfig
                    {
                        EnablePdf = true,
                        PdfEndpoint = "/exports/pdf/table",
                        PdfTitle = " إمهال المستفيدين",
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
                        PdfLogoUrl = "/img/ppng.png",


                    },

                    CustomActions = new List<TableAction>
                            {
 
                             //  details "       
                            new TableAction
                            {
                                Label = "عرض التفاصيل",
                                ModalTitle = "<i class='fa-solid fa-circle-info text-emerald-600 text-xl mr-2'></i> تفاصيل المستفيد",
                                Icon = "fa-regular fa-file",
                                //Show = true,  // ✅ أضف
                                OpenModal = true,
                                RequireSelection = true,
                                MinSelection = 1,
                                MaxSelection = 1,


                            },
                        },



                    Add = new TableAction
                    {
                        Label = "اضافة قراءة عداد غاز جديدة",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "اضافة قراءة عداد غاز جديدة",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassInsertForm",
                            Title = "بيانات قراءة عداد غاز جديدة",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = READGASMETERFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ",   Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        },
                        Meta = metaB
                       ,
                        Meta1 = metaC
                    },


                    Edit = new TableAction
                    {
                        Label = "تعديل قراءة عداد غاز",
                        Icon = "fa-solid fa-edit",
                        Color = "warning",
                        OpenModal = true,
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,

                        OpenForm = new FormConfig
                        {
                            FormId = "ResidentActionInsert",
                            Title = "إضافة إجراء",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = EDITGASMETERFields,
                            Buttons = new List<FormButtonConfig>
        {
            new() { Text="حفظ", Type="submit", Color="success" },
            new() { Text="إلغاء", Type="button", Color="secondary",
                    OnClickJs="this.closest('.sf-modal').__x.$data.closeModal();" }
        }
                        },

                        Meta = extraMetaAutoOpen
                    },







                }
            };






            dsModelELECTRICITYMETER.StyleRules = new List<TableStyleRule>
                        {
                             //new TableStyleRule
                             //{

                             //    Target = "row",
                             //    Field = "avrageNo",
                             //    Op = "eq",
                             //    Value = "5",
                             //    CssClass = "row-red",
                             //    Priority = 1
                             //},
                             //new TableStyleRule
                             //{

                             //    Target = "row",
                             //    Field = "avrageNo",
                             //    Op = "eq",
                             //    Value = "6",
                             //    CssClass = "row-yellow",
                             //    Priority = 1
                             //},

                            new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="5", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-red",
                                PillMode="replace"
                            },
                            new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="6", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-yellow",
                                PillMode="replace"
                            },
                            new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="5", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-red",
                                PillMode="replace"
                            },
                            new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="6", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-yellow",
                                PillMode="replace"
                            },


                             new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="0", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-green",
                                PillMode="replace"
                            },
                             new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="1", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-red",
                                PillMode="replace"
                            },
                              new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="2", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-yellow",
                                PillMode="replace"
                            },
                               new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="3", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-green",
                                PillMode="replace"
                            },

                                new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="0", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-gray",
                                PillMode="replace"
                            },
                                new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="1", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-red",
                                PillMode="replace"
                            },
                              new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="2", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-yellow",
                                PillMode="replace"
                            },
                               new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="3", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-green",
                                PillMode="replace"
                            },

                        };
            dsModelWATERMETER.StyleRules = new List<TableStyleRule>
                        {
                             //new TableStyleRule
                             //{

                             //    Target = "row",
                             //    Field = "avrageNo",
                             //    Op = "eq",
                             //    Value = "5",
                             //    CssClass = "row-red",
                             //    Priority = 1
                             //},
                             //new TableStyleRule
                             //{

                             //    Target = "row",
                             //    Field = "avrageNo",
                             //    Op = "eq",
                             //    Value = "6",
                             //    CssClass = "row-yellow",
                             //    Priority = 1
                             //},

                            new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="5", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-red",
                                PillMode="replace"
                            },
                            new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="6", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-yellow",
                                PillMode="replace"
                            },
                            new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="5", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-red",
                                PillMode="replace"
                            },
                            new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="6", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-yellow",
                                PillMode="replace"
                            },


                             new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="0", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-green",
                                PillMode="replace"
                            },
                             new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="1", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-red",
                                PillMode="replace"
                            },
                              new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="2", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-yellow",
                                PillMode="replace"
                            },
                               new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="3", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-green",
                                PillMode="replace"
                            },

                                new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="0", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-gray",
                                PillMode="replace"
                            },
                                new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="1", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-red",
                                PillMode="replace"
                            },
                              new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="2", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-yellow",
                                PillMode="replace"
                            },
                               new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="3", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-green",
                                PillMode="replace"
                            },

                        };
            dsModelGASMETER.StyleRules = new List<TableStyleRule>
                        {
                             //new TableStyleRule
                             //{

                             //    Target = "row",
                             //    Field = "avrageNo",
                             //    Op = "eq",
                             //    Value = "5",
                             //    CssClass = "row-red",
                             //    Priority = 1
                             //},
                             //new TableStyleRule
                             //{

                             //    Target = "row",
                             //    Field = "avrageNo",
                             //    Op = "eq",
                             //    Value = "6",
                             //    CssClass = "row-yellow",
                             //    Priority = 1
                             //},

                            new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="5", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-red",
                                PillMode="replace"
                            },
                            new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="6", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-yellow",
                                PillMode="replace"
                            },
                            new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="5", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-red",
                                PillMode="replace"
                            },
                            new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="6", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-yellow",
                                PillMode="replace"
                            },


                             new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="0", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-green",
                                PillMode="replace"
                            },
                             new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="1", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-red",
                                PillMode="replace"
                            },
                              new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="2", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-yellow",
                                PillMode="replace"
                            },
                               new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="3", Priority=1,
                                PillEnabled=true,
                                PillField="TotalPrice",
                                PillTextField="TotalPrice",
                                PillCssClass="pill pill-green",
                                PillMode="replace"
                            },

                                new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="0", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-gray",
                                PillMode="replace"
                            },
                                new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="1", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-red",
                                PillMode="replace"
                            },
                              new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="2", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-yellow",
                                PillMode="replace"
                            },
                               new TableStyleRule
                            {
                                Target="row", Field="avrageNo", Op="eq", Value="3", Priority=1,
                                PillEnabled=true,
                                PillField="avrageMsg",
                                PillTextField="avrageMsg",
                                PillCssClass="pill pill-green",
                                PillMode="replace"
                            },

                        };

            dsModel.StyleRules = new List<TableStyleRule>
                        {

                             new TableStyleRule
                            {
                                Target="row", Field="AllMeterNotReaded", Op="neq", Value="0", Priority=1,
                                PillEnabled=true,
                                PillField="AllMeterNotReaded",
                                PillTextField="AllMeterNotReaded",
                                PillCssClass="pill pill-red",
                                PillMode="replace"
                            },

                              new TableStyleRule
                            {
                                Target="row", Field="AllMeterNotReaded", Op="eq", Value="0", Priority=1,
                                PillEnabled=true,
                                PillField="AllMeterNotReaded",
                                PillTextField="AllMeterNotReaded",
                                PillCssClass="pill pill-green",
                                PillMode="replace"
                            },

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

            var vm = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-home",
                Form = form,
                TableDS = ready ? dsModel : null,
                TableDS1 = (ready && MeterServiceTypeready) ? MeterServiceTypeID_ switch
                {
                    "1" => dsModelELECTRICITYMETER,
                    "2" => dsModelWATERMETER,
                    "3" => dsModelGASMETER,
                    _ => null
                } : null

            };
            return View("MeterRead/AllMeterRead", vm);
        }
    }
}