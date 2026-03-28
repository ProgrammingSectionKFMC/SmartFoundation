using Microsoft.AspNetCore.Mvc;
using SmartFoundation.MVC.Reports;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartPrint;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Text.Json;
using static LLama.Common.ChatHistory;

namespace SmartFoundation.Mvc.Controllers.Housing
{
    public partial class HousingController : Controller
    {
        public async Task<IActionResult> HousingExtend(int pdf = 0, int? rowId = null)
        {
            //  قراءة السيشن والكونتكست
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = nameof(Housing);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "HousingExtend" : PageName;

            var spParameters = new object?[]
            {
             PageName ?? "HousingExtend",
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
            //if (permissionTable is null || permissionTable.Rows.Count == 0)
            //{
            //    TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
            //    return RedirectToAction("Index", "Home");
            //}

            string rowIdField = "";
            bool canHOUSINGEXTEND = false;
            bool canEDITHOUSINGEXTEND = false;
            bool canCANCELHOUSINGEXTEND = false;
            bool canSENDHOUSINGEXTENDTOFINANCE = false;
            bool canAPPROVEEXTEND = false;
            bool canEXTENDINSURANCE = false;
           


            List<OptionItem> ExtendTypeOptions = new();
            List<OptionItem> ExtendInsuranceTypeOptions = new();


            // ---------------------- DDLValues ----------------------

            JsonResult? result;
            string json;

            //// ---------------------- rankOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "ExtendReasonTypeName_A", "ExtendReasonTypeID", "2", nameof(HousingExtend), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            ExtendTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            //// ---------------------- rankOptions ----------------------
            result = await _CrudController.GetDDLValues(
                "ExtendInsuranceTypeName_A", "ExtendInsuranceTypeID", "3", nameof(HousingExtend), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            ExtendInsuranceTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


            //// ---------------------- END DDL ----------------------

            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // صلاحيات
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "HOUSINGEXTEND") canHOUSINGEXTEND = true;
                        if (permissionName == "EDITHOUSINGEXTEND") canEDITHOUSINGEXTEND = true;
                        if (permissionName == "CANCELHOUSINGEXTEND") canCANCELHOUSINGEXTEND = true;
                        if (permissionName == "SENDHOUSINGEXTENDTOFINANCE") canSENDHOUSINGEXTENDTOFINANCE = true;
                        if (permissionName == "APPROVEEXTEND") canAPPROVEEXTEND = true;
                        if (permissionName == "EXTENDINSURANCE") canEXTENDINSURANCE = true;


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
                            ["ActionID"] = "رقم الاكشن",
                            ["NationalID"] = "رقم الهوية",
                            ["GeneralNo"] = "الرقم العام",
                            ["LastActionDecisionNo"] = "رقم خطاب الموافقة",
                            ["LastActionDecisionDate"] = "تاريخ خطاب الموافقة",
                            ["ExtendFromDate"] = "بداية الامهال",
                            ["ExtendToDate"] = "نهاية الامهال",
                            ["WaitingClassName"] = "فئة سجل الانتظار",
                            ["WaitingOrderTypeName"] = "نوع سجل الانتظار",
                            ["ActionNote"] = "ملاحظات",
                            ["FullName_A"] = "الاسم",
                            ["buildingActionTypeResidentAlias"] = "الحالة",
                            ["buildingDetailsNo"] = "رقم المنزل",
                            ["ExtendReasonTypeName_A"] = "سبب الامهال",
                            ["WaitingListOrder"] = "الترتيب"
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
                            bool isIdaraId = c.ColumnName.Equals("IdaraId", StringComparison.OrdinalIgnoreCase);
                            bool isresidentInfoID = c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionTypeID = c.ColumnName.Equals("LastActionTypeID", StringComparison.OrdinalIgnoreCase);
                            bool isAssignPeriodID = c.ColumnName.Equals("AssignPeriodID", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingDetailsID = c.ColumnName.Equals("buildingDetailsID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionID = c.ColumnName.Equals("LastActionID", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingOrderTypeName = c.ColumnName.Equals("WaitingOrderTypeName", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingListOrder = c.ColumnName.Equals("WaitingListOrder", StringComparison.OrdinalIgnoreCase);



                            bool isbuildingActionTypeResidentAlias = c.ColumnName.Equals("buildingActionTypeResidentAlias", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingClassName = c.ColumnName.Equals("WaitingClassName", StringComparison.OrdinalIgnoreCase);
                            
                            //  جهز خيارات الفلتر من نفس بيانات الجدول (عشان التطابق يكون صحيح)
                            List<OptionItem> filterOpts = new();
                            if (isbuildingActionTypeResidentAlias || isWaitingClassName )
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
                                Sortable = true
                                //if u want to hide any column 
                                ,
                                Visible = !(isActionID || isWaitingClassID || isWaitingOrderTypeID || iswaitingClassSequence
                                || isresidentInfoID || isIdaraId   || isAssignPeriodID  ||  isWaitingOrderTypeName || isWaitingListOrder ),

                            //  فلتر للرتبة + الوحدة + الجنسية
                                Filter = (isbuildingActionTypeResidentAlias || isWaitingClassName )
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
                            dict["p01"] = Get("ActionID") ?? Get("actionID");
                            dict["p02"] = Get("residentInfoID");
                            dict["p03"] = Get("NationalID");
                            dict["p04"] = Get("GeneralNo");
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
                            dict["p22"] = Get("LastActionDecisionDate");
                            dict["p23"] = Get("LastActionDecisionNo");
                            dict["p24"] = Get("ExtendFromDate");
                            dict["p25"] = Get("ExtendToDate");
                            dict["p27"] = Get("LastActionExtendReasonTypeID");
                            dict["p28"] = Get("Remaining");
                            dict["p29"] = Get("buildingRentAmount");
                            dict["p30"] = Get("InsuranceAmount");
                            dict["p31"] = Get("InsuranceAmountWithRemaining");
                            dict["p32"] = Get("ExtendReasonTypeName_A");
                            


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
            var ExtendFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "HOUSINGEXTEND" },
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
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p18", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "رقم المبنى", Type = "text", ColCss = "3", Readonly = true },


                
                new FieldConfig { Name = "p22", Label = "تاريخ خطاب موافقة الامهال", Type = "date", ColCss = "3",Required = true },
                new FieldConfig { Name = "p23", Label = "رقم خطاب موافقة الامهال", Type = "text", ColCss = "3",Required = true },
                new FieldConfig { Name = "p24", Label = "تاريخ بداية الامهال", Type = "date", ColCss = "3",Required = true },
                new FieldConfig { Name = "p25", Label = "تاريخ نهاية الامهال", Type = "date", ColCss = "3",Required = true },

                new FieldConfig { Name = "p27", Label = "سبب الامهال", Type = "select", ColCss = "4",Required = true,HelpText="المتقاعد والمفصول مطلوب تأمين احترازي يرجى الاختيار بدقة*",Options=ExtendTypeOptions},
                new FieldConfig { Name = "p26", Label = "ملاحظات", Type = "textarea", ColCss = "6",Required = true,HelpText="لايجب ان يتجاوز النص 1000 حرف*",MaxLength=1000 },

                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },


            };

            var EditExtendFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "EDITHOUSINGEXTEND" },
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
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p18", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "رقم المبنى", Type = "text", ColCss = "3", Readonly = true },


                new FieldConfig { Name = "p22", Label = "تاريخ خطاب موافقة الامهال", Type = "date", ColCss = "3",Required = true },
                new FieldConfig { Name = "p23", Label = "رقم خطاب موافقة الامهال", Type = "text", ColCss = "3",Required = true },
                new FieldConfig { Name = "p24", Label = "تاريخ بداية الامهال", Type = "date", ColCss = "3",Required = true },
                new FieldConfig { Name = "p25", Label = "تاريخ نهاية الامهال", Type = "date", ColCss = "3",Required = true },
                new FieldConfig { Name = "p27", Label = "سبب الامهال", Type = "select", ColCss = "4",Required = true,HelpText="المتقاعد والمفصول مطلوب تأمين احترازي يرجى الاختيار بدقة*",Options=ExtendTypeOptions},
                new FieldConfig { Name = "p26", Label = "ملاحظات", Type = "textarea", ColCss = "6",Required = true,HelpText="لايجب ان يتجاوز النص 1000 حرف*",MaxLength=1000 },

                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },


            };


            var CancelExtendFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "CANCELHOUSINGEXTEND" },
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
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p18", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "رقم المبنى", Type = "text", ColCss = "3", Readonly = true },


                new FieldConfig { Name = "p22", Label = "تاريخ خطاب موافقة الامهال", Type = "date", ColCss = "3",Required = true, Readonly = true },
                new FieldConfig { Name = "p23", Label = "رقم خطاب موافقة الامهال", Type = "text", ColCss = "3",Required = true, Readonly = true },
                new FieldConfig { Name = "p24", Label = "تاريخ بداية الامهال", Type = "date", ColCss = "3",Required = true, Readonly = true },
                new FieldConfig { Name = "p25", Label = "تاريخ نهاية الامهال", Type = "date", ColCss = "3",Required = true, Readonly = true },
                new FieldConfig { Name = "p27", Label = "سبب الامهال", Type = "select", ColCss = "4",Required = true,HelpText="المتقاعد والمفصول مطلوب تأمين احترازي يرجى الاختيار بدقة*",Options=ExtendTypeOptions},
                new FieldConfig { Name = "p26", Label = "ملاحظات", Type = "textarea", ColCss = "12",Required = true,HelpText="لايجب ان يتجاوز النص 1000 حرف*",MaxLength=1000 },

                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },


            };


            var SENDHOUSINGEXTENDTOFINANCEFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "SENDHOUSINGEXTENDTOFINANCE" },
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
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p18", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "رقم المبنى", Type = "text", ColCss = "3", Readonly = true },


                new FieldConfig { Name = "p22", Label = "تاريخ خطاب موافقة الامهال", Type = "date", ColCss = "3",Required = true , Readonly = true },
                new FieldConfig { Name = "p23", Label = "رقم خطاب موافقة الامهال", Type = "text", ColCss = "3",Required = true , Readonly = true },
                new FieldConfig { Name = "p24", Label = "تاريخ بداية الامهال", Type = "date", ColCss = "3",Required = true , Readonly = true },
                new FieldConfig { Name = "p25", Label = "تاريخ نهاية الامهال", Type = "date", ColCss = "3",Required = true , Readonly = true },
                new FieldConfig { Name = "p27", Label = "سبب الامهال", Type = "hidden", ColCss = "4",Required = true,HelpText="المتقاعد والمفصول مطلوب تأمين احترازي يرجى الاختيار بدقة*",Options=ExtendTypeOptions},
                new FieldConfig { Name = "p26", Label = "ملاحظات", Type = "textarea", ColCss = "12",Required = true,HelpText="لايجب ان يتجاوز النص 1000 حرف*",MaxLength=1000 },

                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },


            };



            var ApproveExtendFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "ApproveExtend" },
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
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p18", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "رقم المبنى", Type = "text", ColCss = "3", Readonly = true },


                new FieldConfig { Name = "p22", Label = "تاريخ خطاب موافقة الامهال", Type = "date", ColCss = "3",Required = true, Readonly = true },
                new FieldConfig { Name = "p23", Label = "رقم خطاب موافقة الامهال", Type = "text", ColCss = "3",Required = true, Readonly = true },
                new FieldConfig { Name = "p24", Label = "تاريخ بداية الامهال", Type = "date", ColCss = "3",Required = true, Readonly = true },
                new FieldConfig { Name = "p25", Label = "تاريخ نهاية الامهال", Type = "date", ColCss = "3",Required = true, Readonly = true },

                new FieldConfig { Name = "p27", Label = "سبب الامهال", Type = "hidden", ColCss = "4",Required = true,HelpText="المتقاعد والمفصول مطلوب تأمين احترازي يرجى الاختيار بدقة*",Options=ExtendTypeOptions},
                new FieldConfig { Name = "p26", Label = "ملاحظات", Type = "textarea", ColCss = "6",Required = true,HelpText="لايجب ان يتجاوز النص 1000 حرف*",MaxLength=1000 },

                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },


            };

            var ExtendInsuranceFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "EXTENDINSURANCE" },
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
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p18", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "رقم المبنى", Type = "text", ColCss = "3", Readonly = true },



                new FieldConfig { Name = "p22", Label = "تاريخ خطاب موافقة الامهال", Type = "date", ColCss = "3",Required = true, Readonly = true },
                new FieldConfig { Name = "p23", Label = "رقم خطاب موافقة الامهال", Type = "text", ColCss = "3",Required = true, Readonly = true },
                new FieldConfig { Name = "p24", Label = "تاريخ بداية الامهال", Type = "date", ColCss = "3",Required = true, Readonly = true },
                new FieldConfig { Name = "p25", Label = "تاريخ نهاية الامهال", Type = "date", ColCss = "3",Required = true, Readonly = true },

                new FieldConfig { Name = "p27", Label = "ExtendReasonTypeID", Type = "hidden", ColCss = "4",Required = true,Options=ExtendTypeOptions , Readonly = true},

                new FieldConfig { Name = "p32", Label = "سبب الامهال", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p28", Label = "المبالغ الغير مسددة", Type = "text", ColCss = "3", Readonly = true,HelpText="*المطالبات السابقة على المستفيد التي لم يتم استيفائها وقت التدقيق المالي" },
                new FieldConfig { Name = "p29", Label = "buildingRentAmount", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p30", Label = "مبلغ التأمين", Type = "text", ColCss = "3", Readonly = true,HelpText="*قيمة الايجار مضروبة في 40"  },
                new FieldConfig { Name = "p31", Label = "اجمالي التأمين الاحترازي", Type = "text", ColCss = "3", Readonly = true,HelpText="اجمالي المطالبات المتبقية على المستفيد مضاف اليها مبلغ التأمين الاحترازي*"  },
                new FieldConfig { Name = "p35", Label = "تاريخ وثيقة التأمين الاحترازي", Type = "date", ColCss = "4",Required = true },
                new FieldConfig { Name = "p33", Label = "رقم وثيقة التأمين الاحترازي", Type = "text", ColCss = "4",Required = true },
                new FieldConfig { Name = "p36", Label = "نوع تحصيل التأمين الاحترازي", Type = "select", ColCss = "4",Required = true, Options = ExtendInsuranceTypeOptions },


                new FieldConfig { Name = "p26", Label = "ملاحظات", Type = "textarea", ColCss = "6",Required = true,HelpText="*لايجب ان يتجاوز النص 1000 حرف",MaxLength=1000 },

                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },


            };



            //  UPDATE fields (Form Default / Form 46+)  تجريبي نرجع نمسحه او نعدل عليه

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "إمهال المستفيدين",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector=true,
                PanelTitle = "إمهال المستفيدين",
                //TabelLabel = "بيانات المستفيدين",
                //TabelLabelIcon = "fa-solid fa-user-group",
                EnableCellCopy = true,
                ShowColumnVisibility = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,

                    ShowEdit = canHOUSINGEXTEND,
                    ShowEdit1 = canEDITHOUSINGEXTEND,

                    ShowEdit2 = canCANCELHOUSINGEXTEND,
                    ShowDelete = canSENDHOUSINGEXTENDTOFINANCE,
                    ShowDelete1 = canEXTENDINSURANCE,
                    ShowDelete2 = canAPPROVEEXTEND,
                    ShowPrint1 = true,
                    ShowBulkDelete = false,
                    
                    
                    
                    Print1 = new TableAction
                    {
                        Label = "طباعة تقرير",
                        Icon = "fa fa-print",
                        Color = "info",
                        OnClickJs = @"
                            const selectedRows = table.getSelectedRows();
                            if (selectedRows.length === 1) {
                                const row = selectedRows[0];
                                const rowId = row.p01 || row.ActionID;
                        
                                if (!rowId) {
                                    alert('خطأ: لا يمكن العثور على معرف السجل');
                                    return;
                                }
                        
                                sfPrintWithBusy(table, {
                                    pdf: 2,
                                    extraParams: {
                                        rowId: rowId
                                    },
                                    busy: { title: 'طباعة بيانات المستفيدين' }
                                });
                            }
                        ",
                       

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
                                  Value = "24",
                                  Message = "لايمكن طباعة الطلب لعدم انتهاء امهال الساكن",
                                  Priority = 3
                              },



                           }
                        }
                    },



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
                        PdfLogoUrl="/img/ppng.png",


                    },

                            CustomActions = new List<TableAction>
                            {
                            //  Excel "
                            //new TableAction
                            //{
                            //    Label = "تصدير Excel",
                            //    Icon = "fa-regular fa-file-excel",
                            //    Color = "info",
                            //    //Show = true,  // ✅ أضف
                            //    RequireSelection = false,
                            //    OnClickJs = "table.exportData('excel');"
                            //},

                            ////  PDF "
                            //new TableAction
                            //{
                            //    Label = "تصدير PDF",
                            //    Icon = "fa-regular fa-file-pdf",
                            //    Color = "danger",
                            //    //Show = true,  // ✅ أضف
                            //    RequireSelection = false,
                            //    OnClickJs = "table.exportData('pdf');"
                            //},

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


                    Edit = new TableAction
                    {
                        Label = "امهال مستفيد",
                        Icon = "fa-solid fa-pen",
                        Color = "success",
                        Show = true,  // ✅ أضف
                        IsEdit = true,
                        OpenModal = true,

                        ModalTitle = "امهال مستفيد",
                        ModalMessage = "",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",

                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",

                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                           Fields = ExtendFields
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
                                Op = "eq",
                                Value = "48",
                                Message = "تم انشاء الطلب مسبقا",
                                Priority = 3
                            },
                                 new TableActionRule
                            {
                                Field = "LastActionTypeID",
                                Op = "eq",
                                Value = "51",
                                Message = "تم انشاء الطلب مسبقا",
                                Priority = 3
                            },
                                      new TableActionRule
                            {
                                Field = "LastActionTypeID",
                                Op = "eq",
                                Value = "52",
                                Message = "تم انشاء الطلب مسبقا",
                                Priority = 3
                            },

                          }
                       }
                    },

                    Edit1 = new TableAction  // ✅ لازم تحدد Edit1 بدل Delete1!
                    {
                        Label = "تعديل امهال",
                        Icon = "fa-solid fa-edit",
                        Color = "warning",
                        //Show = true,  // ✅ أضف
                        IsEdit = true,
                        OpenModal = true,

                        ModalTitle = "تعديل امهال",
                        ModalMessage = "",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",

                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",

                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = EditExtendFields
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
                                Value = "48",
                                Message = "لايمكن تعديل الطلب",
                                Priority = 3
                            },
                          }
                        }
                    },




                    Edit2 = new TableAction
                    {
                        Label = "الغاء امهال مستفيد",
                        Icon = "fa-solid fa-close",
                        Color = "danger",
                        //Show = true,  // ✅ أضف
                        IsEdit = true,
                        OpenModal = true,

                        ModalTitle = "الغاء امهال مستفيد",
                        ModalMessage = "",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",

                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",

                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                           Fields = CancelExtendFields
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
                                Value = "48",
                                Message = "لايمكن الغاء الطلب",
                                Priority = 3
                            },
                          }
                        }
                    },

                    Delete = new TableAction
                    {
                        Label = "ارسال للتدقيق المالي",
                        Icon = "fa-solid fa-money-bill-wave",
                        Color = "info",
                        //Show = true,  // ✅ أضف
                        IsEdit = true,
                        OpenModal = true,

                        ModalTitle = "ارسال للتدقيق المالي",
                        ModalMessage = "",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",

                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",

                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = SENDHOUSINGEXTENDTOFINANCEFields
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
                                Op = "eq",
                                Value = "2",
                                Message = "لم يتم انشاء الطلب",
                                Priority = 3
                            },
                                 new TableActionRule
                            {
                                Field = "LastActionTypeID",
                                Op = "eq",
                                Value = "24",
                                Message = "لم يتم انشاء الطلب",
                                Priority = 3
                            },
                              new TableActionRule
                            {
                                Field = "LastActionTypeID",
                                Op = "eq",
                                Value = "51",
                                Message = "لايمكن الغاء الطلب",
                                Priority = 3
                            },
                                 new TableActionRule
                            {
                                Field = "LastActionTypeID",
                                Op = "eq",
                                Value = "52",
                                Message = "لايمكن الغاء الطلب",
                                Priority = 3
                            },
                          }
                        }
                    },

                    Delete1 = new TableAction  // ✅ لازم تحدد Edit1 بدل Delete1!
                    {
                        Label = "التأمين الاحترازي",
                        Icon = "fa-solid fa-money-bill-wave",
                        Color = "info",
                        //Show = true,  // ✅ أضف
                        IsEdit = true,
                        OpenModal = true,

                        ModalTitle = "التأمين الاحترازي",
                        ModalMessage = "",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",

                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",

                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = ExtendInsuranceFields
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
                                 Field = "LastActionExtendReasonTypeID",
                                Op = "notin",
                                Value = "1,2",
                                Message = "التأمين الاحترازي غير مطلوب يمكنك اعتماد الطلب مباشرة",
                                Priority = 3
                            },

                                   new TableActionRule
                                {
                                     Field = "LastActionTypeID",
                                    Op = "eq",
                                    Value = "61",
                                    Message = "تم تنفيذ التأمين الاحترازي مسبقا",
                                    Priority = 3
                                },
                          }
                        }
                    },

                    Delete2 = new TableAction  // ✅ لازم تحدد Edit1 بدل Delete1!
                    {
                        Label = "اعتماد الامهال",
                        Icon = "fa-solid fa-check",
                        Color = "success",
                        //Show = true,  // ✅ أضف
                        IsEdit = true,
                        OpenModal = true,

                        ModalTitle = "اعتماد الامهال",
                        ModalMessage = "",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",

                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",

                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = ApproveExtendFields
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
                                Value = "52,61",
                                Message = "لايمكن اعتماد الامهال لوجود اجراءات لم تنتهي او انه تم امهال الساكن مسبقا ",
                                Priority = 3
                            },
                          }
                        }
                    },



                }
            };



            //dsModel.StyleRules = new List<TableStyleRule>
            //    {

            //        new TableStyleRule
            //        {
            //            Target = "row",
            //            Field = "LastActionTypeID",
            //            Op = "eq",
            //            Value = "46",
            //            CssClass = "row-blue",
            //            Priority = 1

            //        },
            //         new TableStyleRule
            //        {
            //            Target = "row",
            //            Field = "LastActionTypeID",
            //            Op = "eq",
            //            Value = "47",
            //            CssClass = "row-yellow",
            //            Priority = 1

            //        },
            //          new TableStyleRule
            //        {
            //            Target = "row",
            //            Field = "LastActionTypeID",
            //            Op = "eq",
            //            Value = "2",
            //            CssClass = "row-green",
            //            Priority = 1
            //        },
            //           new TableStyleRule
            //        {
            //            Target = "row",
            //            Field = "LastActionTypeID",
            //            Op = "eq",
            //            Value = "45",
            //            CssClass = "row-gray",
            //            Priority = 1
            //        },

            //    };



                   dsModel.StyleRules = new List<TableStyleRule>
                        {
                           
                            new TableStyleRule
                            {
                                Target="row", Field="LastActionTypeID", Op="eq", Value="2", Priority=1,
                                PillEnabled=true,
                                PillField="buildingActionTypeResidentAlias",
                                PillTextField="buildingActionTypeResidentAlias",
                                PillCssClass="pill pill-green",
                                PillMode="replace"
                            },
                              new TableStyleRule
                            {
                                Target="row", Field="LastActionTypeID", Op="eq", Value="24", Priority=1,
                                PillEnabled=true,
                                PillField="buildingActionTypeResidentAlias",
                                PillTextField="buildingActionTypeResidentAlias",
                                PillCssClass="pill pill-green",
                                PillMode="replace"
                            },
                            new TableStyleRule
                            {
                                Target="row", Field="LastActionTypeID", Op="eq", Value="48", Priority=1,
                                PillEnabled=true,
                                PillField="buildingActionTypeResidentAlias",
                                PillTextField="buildingActionTypeResidentAlias",
                                PillCssClass="pill pill-yellow",
                                PillMode="replace"
                            },
                             new TableStyleRule
                            {
                                Target="row", Field="LastActionTypeID", Op="eq", Value="51", Priority=1,
                                PillEnabled=true,
                                PillField="buildingActionTypeResidentAlias",
                                PillTextField="buildingActionTypeResidentAlias",
                                PillCssClass="pill pill-red",
                                PillMode="replace"
                            },
                               new TableStyleRule
                            {
                                Target="row", Field="LastActionTypeID", Op="eq", Value="52", Priority=1,
                                PillEnabled=true,
                                PillField="buildingActionTypeResidentAlias",
                                PillTextField="buildingActionTypeResidentAlias",
                                PillCssClass="pill pill-blue",
                                PillMode="replace"
                            },

                                new TableStyleRule
                            {
                                Target="row", Field="LastActionTypeID", Op="eq", Value="61", Priority=1,
                                PillEnabled=true,
                                PillField="buildingActionTypeResidentAlias",
                                PillTextField="buildingActionTypeResidentAlias",
                                PillCssClass="pill pill-yellow",
                                PillMode="replace"
                            },
                                 new TableStyleRule
                            {
                                Target="row", Field="InsuranceStatusNo", Op="eq", Value="0", Priority=1,
                                PillEnabled=true,
                                PillField="InsuranceStatusName",
                                PillTextField="InsuranceStatusName",
                                PillCssClass="pill pill-red",
                                PillMode="replace"
                            },
                               new TableStyleRule
                            {
                                Target="row", Field="InsuranceStatusNo", Op="eq", Value="2", Priority=1,
                                PillEnabled=true,
                                PillField="InsuranceStatusName",
                                PillTextField="InsuranceStatusName",
                                PillCssClass="pill pill-blue",
                                PillMode="replace"
                            },

                                new TableStyleRule
                            {
                                Target="row", Field="InsuranceStatusNo", Op="eq", Value="1", Priority=1,
                                PillEnabled=true,
                                PillField="InsuranceStatusName",
                                PillTextField="InsuranceStatusName",
                                PillCssClass="pill pill-green",
                                PillMode="replace"
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


            if (pdf == 2)
            {
                if (!rowId.HasValue)
                {
                    return Content("خطأ: لم يتم استلام معرف السجل");
                }

                var selectedRow = rowsList.FirstOrDefault(r =>
                    r.TryGetValue("p01", out var id) &&
                    id != null &&
                    Convert.ToInt32(id) == rowId.Value);

                if (selectedRow == null)
                {
                    return Content($"لم يتم العثور على البيانات المطلوبة. معرف السجل: {rowId}, عدد السجلات: {rowsList.Count}");
                }

                // Extract data from selected row
                string residentName = selectedRow.GetValueOrDefault("p15")?.ToString() ?? "";
                string nationalId = selectedRow.GetValueOrDefault("p03")?.ToString() ?? "";
                string generalNo = selectedRow.GetValueOrDefault("p04")?.ToString() ?? "";
                string buildingNo = selectedRow.GetValueOrDefault("p19")?.ToString() ?? "";
                string decisionNo = selectedRow.GetValueOrDefault("p23")?.ToString() ?? "";
                string extendReason = selectedRow.GetValueOrDefault("p32")?.ToString() ?? "";

                // Parse dates
                DateTime? decisionDate = selectedRow.GetValueOrDefault("p22") as DateTime?;
                DateTime? extendFromDate = selectedRow.GetValueOrDefault("p24") as DateTime?;
                DateTime? extendToDate = selectedRow.GetValueOrDefault("p25") as DateTime?;

                string decisionDateStr = decisionDate?.ToString("yyyy/MM/dd") ?? "";
                string extendFromDateStr = extendFromDate?.ToString("yyyy/MM/dd") ?? "";
                string extendToDateStr = extendToDate?.ToString("yyyy/MM/dd") ?? "";

                var logo = Path.Combine(_env.WebRootPath, "img", "ppng.png");

                var header = new Dictionary<string, string>
                {
                    ["no"] = rowId?.ToString() ?? "",
                    ["date"] = DateTime.Now.ToString("yyyy/MM/dd"),
                    ["attach"] = "تجربة استخدام جميع خصائص الخطاب",
                    ["subject"] = "محضر تخصيص مساكن",

                    ["right1"] = "المملكة العربية السعودية",
                    ["right2"] = "وزارة الدفاع",
                    ["right3"] = "القوات البرية الملكية السعودية",
                    ["right4"] = "الإدارة الهندسية للتشغيل والصيانة",
                    ["right5"] = "إدارة مدينة الملك فيصل العسكرية",

                    ["bismillah"] = "بسم الله الرحمن الرحيم",
                    ["midCaption"] = ""
                };

                // =========================
                // جدول 1: بيانات أساسية
                // =========================
                var personInfoTable = ReportTableFactory.CreateOfficialTable(new List<float> { 2, 2, 4, 2 });

                personInfoTable.HeaderRows.Add(new LetterTableRow
                {
                    Cells = new List<LetterTableCell>
        {
            ReportTableFactory.HeaderCell("الرقم العام"),
            ReportTableFactory.HeaderCell("رقم الهوية"),
            ReportTableFactory.HeaderCell("اسم المستفيد"),
            ReportTableFactory.HeaderCell("رقم المبنى")
        }
                });

                personInfoTable.Rows.Add(new LetterTableRow
                {
                    Cells = new List<LetterTableCell>
        {
            ReportTableFactory.ValueCell(generalNo),
            ReportTableFactory.ValueCell(nationalId),
            ReportTableFactory.ValueCell(residentName),
            ReportTableFactory.ValueCell(buildingNo)
        }
                });

                // =========================
                // جدول 2: صف مدموج ColumnSpan
                // =========================
                var mergedTable = ReportTableFactory.CreateOfficialTable(new List<float> { 2, 6 });

                mergedTable.Rows.Add(new LetterTableRow
                {
                    Cells = new List<LetterTableCell>
        {
            new LetterTableCell
            {
                Text = "الجهة",
                Bold = true,
                Align = TextAlign.Center,
                BackgroundColor = "#F3F3F3",
                FontSize = 11
            },
            new LetterTableCell
            {
                Text = "إدارة مدينة الملك فيصل العسكرية",
                Align = TextAlign.Center,
                BackgroundColor = "#FFFFFF",
                FontSize = 11
            }
        }
                });

                // =========================
                // جدول 3: أكثر من صف
                // =========================
                var extendTable = ReportTableFactory.CreateOfficialTable(new List<float> { 2, 2, 2, 2 });

                extendTable.Rows.Add(new LetterTableRow
                {
                    Cells = new List<LetterTableCell>
        {
            ReportTableFactory.HeaderCell("رقم القرار"),
            ReportTableFactory.ValueCell(decisionNo),

            ReportTableFactory.HeaderCell("تاريخ القرار"),
            ReportTableFactory.ValueCell(decisionDateStr)
        }
                });

                extendTable.Rows.Add(new LetterTableRow
                {
                    Cells = new List<LetterTableCell>
        {
            ReportTableFactory.HeaderCell("من تاريخ"),
            ReportTableFactory.ValueCell(extendFromDateStr),

            ReportTableFactory.HeaderCell("إلى تاريخ"),
            ReportTableFactory.ValueCell(extendToDateStr)
        }
                });

                extendTable.Rows.Add(new LetterTableRow
                {
                    Cells = new List<LetterTableCell>
        {
            new LetterTableCell
            {
                Text = "سبب الإمهال",
                Bold = true,
                Align = TextAlign.Center,
                BackgroundColor = "#F3F3F3",
                FontSize = 11,
                ColumnSpan = 1
            },
            new LetterTableCell
            {
                Text = string.IsNullOrWhiteSpace(extendReason) ? "لا يوجد" : extendReason,
                Align = TextAlign.Right,
                BackgroundColor = "#FFFFFF",
                FontSize = 11,
                ColumnSpan = 3
            }
        }
                });

                var report = new ReportResult
                {
                    ReportId = "OfficialLetter01",
                    Title = "خطاب رسمي تجريبي",
                    Kind = ReportKind.Letter,
                    Orientation = ReportOrientation.Portrait,

                    HeaderType = ReportHeaderType.LetterOfficial,
                    LogoPath = logo,
                    ShowFooter = false,

                    HeaderFields = header,

                    LetterTitle = "نموذج تجريبي لاختبار خصائص الخطابات",
                    LetterTitleFontSize = 14,

                    LetterBlocks = new List<LetterBlock>
        {
            // Spacer
            LetterBlockFactory.Spacer(6),

            // Table 1
            LetterBlockFactory.TableBlock(
                personInfoTable,
                paddingTop: 8,
                paddingBottom: 8,
                paddingRight: 0,
                paddingLeft: 0),

            // Table 2
            LetterBlockFactory.TableBlock(
                mergedTable,
                paddingTop: 0,
                paddingBottom: 8),

            // Table 3
            LetterBlockFactory.TableBlock(
                extendTable,
                paddingTop: 0,
                paddingBottom: 12),

            // Divider
            LetterBlockFactory.Divider(paddingTop: 4, paddingBottom: 10),

            // Text Center + Bold
            LetterBlockFactory.TextBlock(
                "سعادة قائد إدارة مدينة الملك فيصل العسكرية حفظه الله",
                fontSize: 13,
                bold: true,
                align: TextAlign.Center,
                paddingTop: 8,
                paddingBottom: 12),

            // Text Right
            LetterBlockFactory.TextBlock(
                "السلام عليكم ورحمة الله وبركاته،",
                fontSize: 12,
                bold: false,
                align: TextAlign.Right,
                paddingTop: 4,
                paddingBottom: 10),

            // Text Justify + LineHeight
            LetterBlockFactory.TextBlock(
                $"نفيد سعادتكم بأنه بناءً على توجيهاتكم الكريمة تم إمهال الساكن / {residentName} " +
                $"المسجل برقم الهوية {nationalId}، وذلك اعتبارًا من تاريخ {extendFromDateStr} " +
                $"إلى تاريخ {extendToDateStr}، حسب رقم القرار {decisionNo}، ونأمل الاطلاع والتوجيه بما يلزم.",
                fontSize: 12,
                bold: false,
                align: TextAlign.Justify,
                paddingTop: 0,
                paddingBottom: 12,
                paddingRight: 0,
                paddingLeft: 0,
                lineHeight: 1.8f),

            // Text Underline
            LetterBlockFactory.TextBlock(
                "ملاحظات:",
                fontSize: 12,
                bold: true,
                underline: true,
                align: TextAlign.Right,
                paddingTop: 6,
                paddingBottom: 6),

            // Text with left/right padding
            LetterBlockFactory.TextBlock(
                $"سبب الإمهال المسجل بالنظام: {(string.IsNullOrWhiteSpace(extendReason) ? "لا يوجد" : extendReason)}",
                fontSize: 11,
                align: TextAlign.Right,
                paddingTop: 0,
                paddingBottom: 12,
                paddingRight: 10,
                paddingLeft: 10,
                lineHeight: 1.6f),

            // Spacer
            LetterBlockFactory.Spacer(8),

            // Divider
            LetterBlockFactory.Divider(paddingTop: 4, paddingBottom: 8),

            // Closing
            LetterBlockFactory.TextBlock(
                "وتفضلوا بقبول فائق الاحترام والتقدير،",
                fontSize: 12,
                align: TextAlign.Right,
                paddingTop: 10,
                paddingBottom: 20),

            // Signature block
            LetterBlockFactory.TextBlock(
                "مدير الإدارة الهندسية\n\nالاسم / ..................\n\n\n\nالتوقيع / ...............",
                fontSize: 11,
                align: TextAlign.Left,
                paddingTop: 10,
                paddingLeft: 50,
                lineHeight: 2.7f)
        }
                };

                var pdfBytes = QuestPdfReportRenderer.Render(report);
                Response.Headers["Content-Disposition"] = "inline; filename=Letter.pdf";
                return File(pdfBytes, "application/pdf");
            }

        
            return View("HousingProcedures/HousingResident", page);
        }
    }
}