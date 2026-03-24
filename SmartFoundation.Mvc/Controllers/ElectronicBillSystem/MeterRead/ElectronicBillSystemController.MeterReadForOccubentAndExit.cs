using Microsoft.AspNetCore.Mvc;
using SmartFoundation.MVC.Reports;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Diagnostics.Metrics;
using System.Linq;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers.ElectronicBillSystem
{
    public partial class ElectronicBillSystemController : Controller
    {
        public async Task<IActionResult> MeterReadForOccubentAndExit(int pdf = 0)
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
          

            ready = !string.IsNullOrWhiteSpace(residentInfoID_) && residentInfoID_ != "-1";

           


            ControllerName = nameof(ElectronicBillSystem);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "MeterReadForOccubentAndExit" : PageName;

            var spParameters = new object?[]
            {
             PageName ?? "MeterReadForOccubentAndExit",
             IdaraId,
             usersId,
             HostName,
             residentInfoID_
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

            //  تقسيم الداتا سيت للجدول الأول + جداول أخرى
            SplitDataSet(ds);

            if (dt2 != null && dt2.Rows.Count > 0)
            {
                TempData["JobsAvaliable"] = $"يوجد عدد  {dt2.Rows.Count} ساكنين مطلوب انهاء القراءات الخاصة بهم";
            }
            else
            {
                TempData["NoJobs"] = "لا توجد قراءات مطلوبة";
            }

            //  التحقق من الصلاحيات
            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            string rowIdField = "";
            bool canMeterReadForOccubentAndExit = false;
            bool canUpdateMeterReadForOccubentAndExit = false;


            string? ExitOrOccubent_ = dt1?.Rows.Count > 0
                   ? dt1.Rows[0]["buildingActionRoot"]?.ToString()
                    : null;


            List<OptionItem> ResidentDetailsOptions = new();


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
                                        NavUrl = "/ElectronicBillSystem/MeterReadForOccubentAndExit",
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
                        rowIdField = "meterID";
                        var possibleIdNames = new[] { "meterID", "MeterID", "Id", "ID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["ActionID"] = "رقم الاكشن",
                            ["NationalID"] = "رقم الهوية",
                            ["GeneralNo"] = "الرقم العام",
                            ["WaitingClassName"] = "فئة سجل الانتظار",
                            ["ActionNote"] = "ملاحظات",
                            ["FullName_A"] = "الاسم",
                            ["ReadStatus"] = "الحالة",
                            ["meterReadValue"] = "اخر قراءة للعداد",
                            ["meterServiceTypeName_A"] = "نوع الخدمة",
                            ["meterTypeName_A"] = "نوع العداد",
                            ["meterMaxRead"] = "القراءة القصوى للعداد",
                            ["meterNo"] = "رقم العداد",
                            ["ReadType"] = "نوع الطلب",
                            ["buildingDetailsNo"] = "رقم المنزل"
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
                            bool isActionID = c.ColumnName.Equals("ActionID", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingClassID = c.ColumnName.Equals("WaitingClassID", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingOrderTypeID = c.ColumnName.Equals("WaitingOrderTypeID", StringComparison.OrdinalIgnoreCase);
                            bool iswaitingClassSequence = c.ColumnName.Equals("waitingClassSequence", StringComparison.OrdinalIgnoreCase);
                            bool isresidentInfoID_FK = c.ColumnName.Equals("residentInfoID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraId = c.ColumnName.Equals("IdaraId", StringComparison.OrdinalIgnoreCase);
                            bool isresidentInfoID = c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionTypeID = c.ColumnName.Equals("LastActionTypeID", StringComparison.OrdinalIgnoreCase);
                            bool isAssignPeriodID = c.ColumnName.Equals("AssignPeriodID", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingDetailsID = c.ColumnName.Equals("buildingDetailsID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionID = c.ColumnName.Equals("LastActionID", StringComparison.OrdinalIgnoreCase);
                          
                            bool isActionDecisionNo = c.ColumnName.Equals("ActionDecisionNo", StringComparison.OrdinalIgnoreCase);
                            bool isActionDecisionDate = c.ColumnName.Equals("ActionDecisionDate", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingOrderTypeName = c.ColumnName.Equals("WaitingOrderTypeName", StringComparison.OrdinalIgnoreCase);
                            bool ismeterID = c.ColumnName.Equals("meterID", StringComparison.OrdinalIgnoreCase);


                            bool isNationalID = c.ColumnName.Equals("NationalID", StringComparison.OrdinalIgnoreCase);
                            bool isGeneralNo = c.ColumnName.Equals("GeneralNo", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingClassName = c.ColumnName.Equals("WaitingClassName", StringComparison.OrdinalIgnoreCase);
                            bool isFullName_A = c.ColumnName.Equals("FullName_A", StringComparison.OrdinalIgnoreCase);

                            bool isbuildingActionTypeResidentAlias = c.ColumnName.Equals("buildingActionTypeResidentAlias", StringComparison.OrdinalIgnoreCase);
                            bool isReadStatusInt = c.ColumnName.Equals("ReadStatusInt", StringComparison.OrdinalIgnoreCase);
                            bool ismeterReadID = c.ColumnName.Equals("meterReadID", StringComparison.OrdinalIgnoreCase);




                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                //if u want to hide any column 
                                ,
                                Visible = !(isActionID || isWaitingClassID || isWaitingOrderTypeID || iswaitingClassSequence
                                || isresidentInfoID_FK || isIdaraId || isresidentInfoID || isAssignPeriodID || isbuildingDetailsID || isLastActionID|| isActionDecisionNo || isActionDecisionDate || isWaitingOrderTypeName || isNationalID || isGeneralNo || isWaitingClassName || isFullName_A ||  isbuildingActionTypeResidentAlias || isReadStatusInt || ismeterReadID)
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
                            dict["p01"] = Get("ActionID") ?? Get("actionID");
                            dict["p02"] = Get("residentInfoID");
                            dict["p03"] = Get("NationalID");
                            dict["p04"] = Get("GeneralNo");
                            dict["p05"] = Get("ActionDecisionNo");
                            dict["p06"] = Get("ActionDecisionDate");
                            dict["p07"] = Get("WaitingClassID");
                            dict["p08"] = Get("WaitingClassName");
                            dict["p09"] = Get("WaitingOrderTypeID");
                            dict["p10"] = Get("WaitingOrderTypeName");
                            dict["p11"] = Get("waitingClassSequence");
                            dict["p12"] = Get("ActionNote");
                            dict["p13"] = Get("IdaraId");
                            dict["p14"] = Get("WaitingListOrder");
                            dict["p15"] = Get("FullName_A");
                            dict["p16"] = Get("LastActionTypeID");
                            dict["p17"] = Get("buildingActionTypeResidentAlias");
                            dict["p18"] = Get("buildingDetailsID");
                            dict["p19"] = Get("buildingDetailsNo");
                            dict["p20"] = Get("AssignPeriodID");
                            dict["p21"] = Get("LastActionID");
                            dict["p22"] = Get("meterReadValue");
                            dict["p23"] = Get("meterID");
                            dict["p24"] = Get("meterServiceTypeName_A");
                            dict["p25"] = Get("meterTypeName_A");
                            dict["p26"] = Get("meterMaxRead");
                            dict["p28"] = Get("meterReadID");
                            dict["p29"] = Get("LastActionDate");
                            dict["p30"] = Get("meterServiceTypeID");
                            dict["p31"] = Get("buildingActionRoot");


                            rowsList.Add(dict);
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
            var MeterReadFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "METERREADFOROCCUBENTANDEXIT" },
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
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ActionID" },
                new FieldConfig { Name = "p02", Label = "residentInfoID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p14", Label = "الترتيب", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p15", Label = "الاسم", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p03", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p05", Label = "رقم الطلب", Type = "hidden", ColCss = "3", Readonly = true  },
                new FieldConfig { Name = "p06", Label = "تاريخ الطلب", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p18", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },


               
                //new FieldConfig { Name = "p23", Label = "meterID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p24", Label = "نوع الخدمة", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p25", Label = "نوع العداد", Type = "hidden", ColCss = "3", Readonly = true }, 
                new FieldConfig { Name = "p22", Label = "اخر قراءة للعداد", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p26", Label = "القراءة القصوى للعداد", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p28", Label = "meterReadID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p29", Label = "LastActionDate", Type = "hidden", ColCss = "3", Readonly = true },

                // new FieldConfig { Name = "p27", Label = "تسجيل القراءة", Type = "number", ColCss = "12",Required = true,HelpText="يجب ان تكون القراءة ارقام فقط*",MaxLength=3900 },

                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p31", Label = "buildingActionRoot", Type = "hidden", ColCss = "3", Readonly = true },

                  new FieldConfig { Name = "p30", Label = "MeterServiceTypeID_", Type = "hidden" },
                new FieldConfig { Name = "p23", Label = "رقم العداد", Type = "hidden", ColCss = "3", Required = true},

                new FieldConfig
                    {
                        Name = "p27",
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
                new FieldConfig { Name = "p50", Label = "النظام لاحظ وجود قراءة غير طبيعيه هل انت متأكد من ادراج القراءة وانها صحيحة؟", Type = "checkbox",Required = true,ColCss = "12" },
                    new FieldConfig { Name = "p99", Type = "hidden", Value = "0" },


            };



            var UpdateMeterReadFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "UPDATEMETERREADFOROCCUBENTANDEXIT" },
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
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ActionID" },
                new FieldConfig { Name = "p02", Label = "residentInfoID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p14", Label = "الترتيب", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p15", Label = "الاسم", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p03", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p05", Label = "رقم الطلب", Type = "hidden", ColCss = "3", Readonly = true  },
                new FieldConfig { Name = "p06", Label = "تاريخ الطلب", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p18", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },



                new FieldConfig { Name = "p23", Label = "meterID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p24", Label = "نوع الخدمة", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p25", Label = "نوع العداد", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p22", Label = "اخر قراءة للعداد", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p26", Label = "القراءة القصوى للعداد", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p28", Label = "meterReadID", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p29", Label = "LastActionDate", Type = "hidden", ColCss = "3", Readonly = true },

                 new FieldConfig { Name = "p27", Label = "تسجيل القراءة", Type = "number", ColCss = "12",Required = true,HelpText="يجب ان تكون القراءة ارقام فقط*",MaxLength=3900 },

                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },




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

            var visibleFieldsextraMeta_DependsOnSelect_MultiParams = ExitOrOccubent_ == "1"
            ? new List<string> { "meterNo", "CurrentRead" }
            : new List<string> { "meterNo", "CurrentRead", "TotalPrice" };



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
                ["extraDependsOn"] = "p23",
                ["extraLoadOnOpen"] = true,
                ["extraEmptyTextBeforeSelect"] = "",

                // ✅ جديد: خارطة باراميترات متعددة من فورم المودل
                // p01 -> parameter_01
                // p02 -> parameter_02
                ["extraParamMap"] = new Dictionary<string, string>
                {
                    ["parameter_01"] = "p30",
                    ["parameter_02"] = "p23"
                    //,
                    //["parameter_03"] = "p03"
                },
                ["visibleFields"] = visibleFieldsextraMeta_DependsOnSelect_MultiParams,

                //= new List<string>
                //                {
                //                    "meterNo","CurrentRead","TotalPrice"
                //                },
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

            var visibleFieldsextraMeta2 = ExitOrOccubent_ == "1"
                ? new List<string> { "meterNo", "LastRead", "CurrentRead", "ReadDiff" }
                : new List<string> { "meterNo", "LastRead", "CurrentRead", "ReadDiff", "PRICE", "PRICETAX", "ServicePriceWithTAX", "TotalPrice" };


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
                ["extraTriggerField"] = "p03",
                ["extraButtonText"] = "تحقق",

                ["ctx"] = extraCtx2,
                ["extraRequest"] = extraRequestBase2,

                ["extraParamMap"] = new Dictionary<string, string>
                {
                    ["parameter_01"] = "p30",
                    ["parameter_04"] = "p27",
                    ["parameter_02"] = "p23"
                },

                ["verifyField"] = "p99",
                ["verifyResetFields"] = new List<string> { "p23", "p27" },
                ["verifyRequiredMessage"] = "يجب الضغط على زر التحقق أولاً قبل الحفظ",

                ["rowColorColumn"] = "checks",
                ["rowColorOperator"] = "=",
                ["rowColorValue"] = "0",
                ["rowColorTrueStyle"] = "background:#f74f53;color:#ffffff;",
                ["rowColorFalseStyle"] = "",

                //["rowColorTrueStyle"] = "background:#fef2f2;color:#991b1b;",
                //["rowColorFalseStyle"] = "background:#f0fdf4;color:#166534;",

                //["rowColorColumn"] = "TotalPrice",
                //["rowColorOperator"] = ">",
                //["rowColorCompareColumn"] = "ServicePriceWithTAX",
                //["rowColorTrueClass"] = "bg-red-50 text-red-800",
                //["rowColorFalseClass"] = "bg-green-50 text-green-800"

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
                //["toggleDefaultHidden"] = true,
                //["toggleRequiredWhenShown"] = true,


                ["visibleFields"] = visibleFieldsextraMeta2,

                //            new List<string>
                //{
                //     "meterNo","LastRead","CurrentRead","ReadDiff","PRICE","PRICETAX","ServicePriceWithTAX","TotalPrice"
                //},

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
                ["extraTitle"] = "تفاصيل",
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

                    ["parameter_01"] = "p30",
                    ["parameter_02"] = "p23"
                },

                ["EnableSearch"] = false,
                ["ShowMeta"] = false,
                ["PageSize"] = 10,
                ["Sortable"] = false,
                ["showRowNumbers"] = false,

                ["visibleFields"] = new List<string>
    {
        "meterServiceTypeName_A","meterNo","LastRead", "CurrentRead","ReadDiff", "TotalPrice"
    },

                ["headerMap"] = new Dictionary<string, string>
                {
                    ["meterServiceTypeName_A"] = "نوع الخدمة",
                    ["meterNo"] = "رقم العداد",
                    ["LastRead"] = "القراءة السابقة",
                    ["CurrentRead"] = "القراءة الحالية",
                    ["ReadDiff"] = "فرق القراءة",
                    ["TotalPrice"] = "الإجمالي"
                }
            };


            //  UPDATE fields (Form Default / Form 46+)  تجريبي نرجع نمسحه او نعدل عليه
            var extraTitlemetaB = ExitOrOccubent_ == "1"
                        ? "بيانات القراءة السابقة"
                        : "بيانات الفاتورة السابقة";


            var metaB = new Dictionary<string, object?>(extraMeta_DependsOnSelect_MultiParams)
            {
                ["extraSlotKey"] = "m2",
                ["extraTitle"] = extraTitlemetaB
            };

            var extraTitlemetaC = ExitOrOccubent_ == "1"
                        ? "قراءة التسكين الجديدة المتوقعة بعد التنفيذ"
                        : "فاتورة الاخلاء الجديدة المتوقعة بعد التنفيذ";

            var metaC = new Dictionary<string, object?>(extraMeta2)
            {
                ["extraSlotKey"] = "m3",
                ["extraTitle"] = extraTitlemetaC
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
                   
                    ShowAdd = canMeterReadForOccubentAndExit,
                    ShowPrint1 = false,
                    ShowPrint = false,
                    ShowBulkDelete = false,
                    ShowExportPdf = false,

                    Add = new TableAction
                    {
                        Label = "اضافة قراءة عداد",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "اضافة قراءة عداد",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassInsertForm",
                            Title = "بيانات قراءة عداد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = MeterReadFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ",   Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,

                        Meta = metaB
                        ,
                        Meta1 = metaC
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
                            Fields = UpdateMeterReadFields
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
                                            Op = "notin",
                                            Value = "47,60",
                                            Message = "لايمكن تعديل قراءة العداد ",
                                            Priority = 3
                                        }

                                    }
                        }
                    },

                   



                 

                }
            };

            //var dsModel = new SmartTableDsModel
            //{
            //    PageTitle = "قراءة عدادات التسكين والاخلاء",
            //    Columns = dynamicColumns,
            //    Rows = rowsList,
            //    RowIdField = rowIdField,
            //    PageSize = 10,
            //    PageSizes = new List<int> { 10, 25, 50, 200, },
            //    QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
            //    Searchable = true,
            //    AllowExport = true,
            //    ShowPageSizeSelector=true,
            //    PanelTitle = "قراءة عدادات التسكين والاخلاء",
            //    //TabelLabel = "بيانات المستفيدين",
            //    //TabelLabelIcon = "fa-solid fa-user-group",
            //    EnableCellCopy = true,
            //    Toolbar = new TableToolbarConfig
            //    {
            //        ShowRefresh = false,
            //        ShowColumns = true,
            //        ShowExportCsv = false,
            //        ShowExportExcel = false,
            //        ShowEdit = true,

            //        ShowPrint1 = false,
            //        ShowPrint = false,
            //        ShowBulkDelete = false,
            //        ShowExportPdf = false,


            //        Edit = new TableAction
            //        {
            //            Label = "تسجيل قراءة العداد",
            //            Icon = "fa-solid fa-bolt",
            //            Color = "success",
            //            IsEdit = true,
            //            OpenModal = true,

            //            ModalTitle = "",
            //            ModalMessage = "يجب توخي الحذر عند تسجيل القراءة لعدم امكانية تعديلها بعد اسكان المستفيد بشكل نهائي",
            //            ModalMessageClass = "bg-red-50 text-red-700",
            //            ModalMessageIcon = "fa-solid fa-triangle-exclamation",

            //            OnBeforeOpenJs = "sfRouteEditForm(table, act);",

            //            OpenForm = new FormConfig
            //            {
            //                FormId = "BuildingTypeEditForm",
            //                Title = "",
            //                Method = "post",
            //                ActionUrl = "/crud/update",
            //                SubmitText = "حفظ التعديلات",
            //                CancelText = "إلغاء",
            //                Fields = MeterReadFields
            //            },

            //            RequireSelection = true,
            //            MinSelection = 1,
            //            MaxSelection = 1,

            //            Guards = new TableActionGuards
            //            {
            //                AppliesTo = "any",
            //                DisableWhenAny = new List<TableActionRule>
            //            {

            //                  new TableActionRule
            //                {
            //                    Field = "LastActionTypeID",
            //                    Op = "neq",
            //                    Value = "46",
            //                    Message = "تم ارسال طلب قراءة العدادات مسبقا",
            //                    Priority = 3
            //                }

            //            }
            //            }
            //        },


            //        Delete = new TableAction
            //        {
            //            Label = "تسجيل قراءة العداد",
            //            Icon = "fa-solid fa-bolt",
            //            Color = "success",
            //            IsEdit = true,
            //            OpenModal = true,

            //            ModalTitle = "",
            //            ModalMessage = "يجب توخي الحذر عند تسجيل القراءة لعدم امكانية تعديلها بعد اسكان المستفيد بشكل نهائي",
            //            ModalMessageClass = "bg-red-50 text-red-700",
            //            ModalMessageIcon = "fa-solid fa-triangle-exclamation",

            //            OnBeforeOpenJs = "sfRouteEditForm(table, act);",

            //            OpenForm = new FormConfig
            //            {
            //                FormId = "BuildingTypeEditForm",
            //                Title = "",
            //                Method = "post",
            //                ActionUrl = "/crud/update",
            //                SubmitText = "حفظ التعديلات",
            //                CancelText = "إلغاء",
            //                Fields = MeterReadFields
            //            },

            //            RequireSelection = true,
            //            MinSelection = 1,
            //            MaxSelection = 1,

            //            Guards = new TableActionGuards
            //            {
            //                AppliesTo = "any",
            //                DisableWhenAny = new List<TableActionRule>
            //            {

            //                  new TableActionRule
            //                {
            //                    Field = "LastActionTypeID",
            //                    Op = "neq",
            //                    Value = "46",
            //                    Message = "تم ارسال طلب قراءة العدادات مسبقا",
            //                    Priority = 3
            //                }

            //            }
            //            }
            //        },


            //    }

            //};


               dsModel.StyleRules = new List<TableStyleRule>
                    {
                        new TableStyleRule
                        {
                            Target = "row",
                            Field = "ReadStatusInt",
                            Op = "eq",
                            Value = "1",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "ReadStatus",
                            PillTextField = "ReadStatus",
                            PillCssClass = "pill pill-green",
                            PillMode = "replace"
                        },

                        new TableStyleRule
                        {
                            Target = "row",
                            Field = "ReadStatusInt",
                            Op = "eq",
                            Value = "0",
                            Priority = 1,

                            PillEnabled = true,
                            PillField = "ReadStatus",
                            PillTextField = "ReadStatus",
                            PillCssClass = "pill pill-yellow",
                            PillMode = "replace"
                        },

                        
                        //new TableStyleRule
                        //{
                        //    Target = "row",
                        //    Field = "LastActionTypeID",
                        //    Op = "eq",
                        //    Value = "45",
                        //    Priority = 1,

                        //    PillEnabled = true,
                        //    PillField = "buildingActionTypeResidentAlias",
                        //    PillTextField = "buildingActionTypeResidentAlias", //  من DB
                        //    PillCssClass = "pill pill-gray",
                        //    PillMode = "replace"
                        //}
                    };







            var page = new SmartPageViewModel
            {
               PageTitle = dsModel.PageTitle,
               PanelTitle = dsModel.PanelTitle,
               PanelIcon = "fa-bolt",
               Form = form,
               TableDS = ready ? dsModel : null
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
            return View("MeterRead/MeterReadForOccubentAndExit", page);
        }
    }
}