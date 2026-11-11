using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers.Housing
{
    public partial class HousingController : Controller
    {
        // New, separate page; uses the same SmartRenderer + SmartTable + SmartForm architecture
        // as the user-supplied HousingController.HousingResident.cs (2026-11-10).
        // No pdf parameter, no print block, and no Print1 action.
        public async Task<IActionResult> HousingHistoricalResident()
        {
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = nameof(Housing);
            PageName = nameof(HousingHistoricalResident);

            // T controls only the UI. SQL derives main/side from Housing.WaitingClass.idara_FK.
            string listType = (Request.Query["T"].FirstOrDefault() ?? "").Trim().ToUpperInvariant();
            if (listType != "MAIN" && listType != "SIDE") listType = "";

            string selectedClassRaw = (Request.Query["U"].FirstOrDefault() ?? "").Trim();
            if (!int.TryParse(selectedClassRaw, out int selectedClassId) || selectedClassId <= 0)
                selectedClassRaw = "";

            // Masters_DataLoad: permissionTable, dt1 rows, dt2 categories, dt3 eligible houses.
            var spParameters = new object?[]
{
    PageName,
    IdaraId,
    usersId,
    HostName,
    string.IsNullOrWhiteSpace(selectedClassRaw)
        ? "0"
        : selectedClassRaw
};

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            SplitDataSet(ds);

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            // Never show a table for a tampered/mismatched class and type.
            bool isReady = listType.Length != 0
                && selectedClassRaw.Length != 0
                && dt2 != null
                && dt2.AsEnumerable().Any(r =>
                       string.Equals(r["waitingClassID"]?.ToString(), selectedClassRaw, System.StringComparison.Ordinal)
                    && string.Equals(r["ListType"]?.ToString(), listType, System.StringComparison.OrdinalIgnoreCase));

            List<OptionItem> categoryOptions = new();
            List<OptionItem> buildingOptions = new();
            if (listType.Length != 0)
            {
                // Identical GetDDLValues pattern used by the project's existing housing pages.
                var classResult = await _CrudController.GetDDLValues(
                    "waitingClassName_A", "waitingClassID", "2", PageName,
                    usersId, IdaraId, HostName, "ListType", listType, "اختر فئة الانتظار") as JsonResult;
                categoryOptions = JsonSerializer.Deserialize<List<OptionItem>>(
                    JsonSerializer.Serialize(classResult?.Value)) ?? new List<OptionItem>();
            }

            if (isReady)
            {
                var buildingResult = await _CrudController.GetDDLValues(
                    "buildingDetailsNo", "buildingDetailsID", "3", PageName,
                    usersId, IdaraId, HostName) as JsonResult;
                buildingOptions = JsonSerializer.Deserialize<List<OptionItem>>(
                    JsonSerializer.Serialize(buildingResult?.Value)) ?? new List<OptionItem>();
            }

            var typeOptions = new List<OptionItem>
            {
                new() { Value = "MAIN", Text = "القوائم الرئيسية" },
                new() { Value = "SIDE", Text = "القوائم الجانبية" }
            };

            var filterFields = new List<FieldConfig>
            {
                new FieldConfig
                {
                    SectionTitle = "اختيار نوع قائمة الانتظار",
                    Name = "ListType", Label = "نوع القائمة", Type = "select", Select2 = true,
                    Options = typeOptions, ColCss = "3", Placeholder = "اختر نوع القائمة",
                    Value = listType,
                    OnChangeJs = "sfNav(this)",
                    NavUrl = "/Housing/HousingHistoricalResident",
                    NavKey = "T", NavKey2 = "U", NavVal2 = "0"
                }
            };

            if (listType.Length != 0)
            {
                filterFields.Add(new FieldConfig
                {
                    Name = "WaitingClass",
                    Label = "فئة سجل الانتظار",
                    Type = "select",
                    Select2 = true,
                    Options = categoryOptions,
                    ColCss = "3",
                    Placeholder = "اختر فئة الانتظار",
                    Value = isReady ? selectedClassRaw : null,
                    OnChangeJs = "sfNav(this)",
                    NavUrl = "/Housing/HousingHistoricalResident",
                    NavKey = "U",
                    NavKey2 = "T",
                    NavVal2 = listType
                });
            }

            var filterForm = new FormConfig
            {
                Fields = filterFields,
                Buttons = new List<FormButtonConfig>()
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();
            string rowIdField = "ActionID";
            bool canHistoricalStart = false;
            bool canHistoricalCustody = false;
            bool canHistoricalFinalize = false;
            bool canHistoricalCancel = false;

            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // صلاحيات
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "HISTORICALRESIDENTSTART") canHistoricalStart = true;
                        if (permissionName == "HISTORICALRESIDENTFINALIZE") canHistoricalFinalize = true;
                        if (permissionName == "HISTORICALRESIDENTCUSTODY") canHistoricalCustody = true;
                        if (permissionName == "HISTORICALRESIDENTCANCEL") canHistoricalCancel = true;

                    }

                    if (isReady && dt1 != null && dt1.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField = "ActionID";
                        var possibleIdNames = new[] { "ActionID", "actionID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["ActionID"] = "رقم الاكشن",
                            ["NationalID"] = "رقم الهوية",
                            ["GeneralNo"] = "الرقم العام",
                            ["ActionDecisionNo"] = "رقم الطلب",
                            ["ActionDecisionDate"] = "تاريخ الطلب",
                            ["WaitingClassName"] = "فئة سجل الانتظار",
                            ["WaitingOrderTypeName"] = "نوع سجل الانتظار",
                            ["ActionNote"] = "ملاحظات",
                            ["FullName_A"] = "الاسم",
                            ["buildingActionTypeResidentAlias"] = "الحالة",
                            ["buildingDetailsNo"] = "رقم المنزل (إن وجد)",
                            ["OccupentDate"] = "تاريخ السكن",
                            ["OccupentType"] = "نوع قائمة الانتظار",
                            ["CustdyRecord"] = "جرد العهد",
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
                            bool isresidentInfoID_FK = c.ColumnName.Equals("residentInfoID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraId = c.ColumnName.Equals("IdaraId", StringComparison.OrdinalIgnoreCase);
                            bool isresidentInfoID = c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionTypeID = c.ColumnName.Equals("LastActionTypeID", StringComparison.OrdinalIgnoreCase);
                            bool isAssignPeriodID = c.ColumnName.Equals("AssignPeriodID", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingDetailsID = c.ColumnName.Equals("buildingDetailsID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionID = c.ColumnName.Equals("LastActionID", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingOrderTypeName = c.ColumnName.Equals("WaitingOrderTypeName", StringComparison.OrdinalIgnoreCase);
                            bool ismeterscount = c.ColumnName.Equals("meterscount", StringComparison.OrdinalIgnoreCase);
                            bool isActionTypeID = c.ColumnName.Equals("ActionTypeID", StringComparison.OrdinalIgnoreCase);



                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                //if u want to hide any column 
                                ,
                                Visible = !(isActionID || isWaitingClassID || isWaitingOrderTypeID || iswaitingClassSequence
                                || isresidentInfoID_FK || isIdaraId || isresidentInfoID || isAssignPeriodID || isbuildingDetailsID || isLastActionID || isLastActionTypeID || isWaitingOrderTypeName || ismeterscount || isActionTypeID)
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
                            dict["p22"] = Get("meterscount");
                            dict["p32"] = Get("CustdyRecord");


                            if (Get("LastActionTypeID") == null
                                || Get("LastActionTypeID")?.ToString() is "34" or "35")
                            {
                                dict["buildingActionTypeResidentAlias"] = "بانتظار التسكين الاستثنائي";
                            }

                            rowsList.Add(dict);
                        }
                    }
                }
            }
            catch (Exception)
            {
                ViewBag.HousingHistoricalResidentDataSetError = "حدث خطأ أثناء تحميل البيانات. يرجى المحاولة مرة أخرى.";
            }


            // Preserve both T and U after every CRUD POST.
            var currentUrl = Request.Path.ToString() + Request.QueryString.ToString();

            // Additional action only on this page: start historical housing on a selected waiting root.
            var StartHistoricalFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "HISTORICALRESIDENTSTART" },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ActionID" },
                new FieldConfig { Name = "p02", Type = "hidden", Readonly = true },
                new FieldConfig { Name = "p15", Label = "الاسم", Type = "text", ColCss = "6", Readonly = true, Icon = "fa-solid fa-user" },
                new FieldConfig { Name = "p03", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "3", Readonly = true, Icon = "fa-solid fa-address-card" },
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "3", Readonly = true, Icon = "fa-solid fa-user-tag" },
                new FieldConfig { Name = "p05", Type = "hidden", Readonly = true },
                new FieldConfig { Name = "p06", Type = "hidden", Readonly = true },
                new FieldConfig { Name = "p07", Type = "hidden", Readonly = true },
                new FieldConfig { Name = "p08", Type = "hidden", Readonly = true },
                new FieldConfig { Name = "p09", Type = "hidden", Readonly = true },
                new FieldConfig { Name = "p10", Type = "hidden", Readonly = true },
                new FieldConfig { Name = "p11", Type = "hidden", Readonly = true },
                new FieldConfig { Name = "p14", Type = "hidden", Readonly = true },
                new FieldConfig { Name = "p16", Type = "hidden", Readonly = true },
                new FieldConfig { Name = "p20", Type = "hidden", Readonly = true },
                new FieldConfig { Name = "p21", Type = "hidden", Readonly = true },
                new FieldConfig
                {
                    Name = "p18", Label = "اختيار المنزل", Type = "select", Select2 = true,
                    Options = buildingOptions, ColCss = "6", Required = true,
                    Placeholder = "اختر المنزل المؤهل للتسكين", Icon = "fa-solid fa-house"
                },
                new FieldConfig { Name = "p25", Label = "تاريخ التسكين الفعلي", Type = "date", ColCss = "6", Required = true, Icon = "fa-regular fa-calendar-days" },
                new FieldConfig { Name = "p42", Label = "سبب التسكين الاستثنائي", Type = "textarea", ColCss = "12", Required = true, MaxLength = 950, HelpText = "سبب إلزامي للتدقيق، 950 حرفًا كحد أقصى", Icon = "fa-regular fa-note-sticky" }
            };

            var CustdyFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "HISTORICALRESIDENTCUSTODY" },
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
                new FieldConfig { Name = "p06", Label = "تاريخ الطلب", Type = "hidden", ColCss = "3", Readonly = true, Icon = "fa fa-calendar" },
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p18", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p32", Label = "تسجيل الملاحظات", Type = "textarea", ColCss = "12",Required = true,HelpText="لايجب ان يتجاوز النص 4000 حرف*",MaxLength=3900 },
                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p22", Label = "meterscount", Type = "hidden", ColCss = "3", Readonly = true },


            };

            var FinalOccupentFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "HISTORICALRESIDENTFINALIZE" },
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
                new FieldConfig { Name = "p15", Label = "الاسم", Type = "text", ColCss = "3", Readonly = true, Icon = "fa-solid fa-user" },
                new FieldConfig { Name = "p03", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "3", Readonly = true, Icon = "fa-solid fa-address-card" },
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "3", Readonly = true, Icon = "fa-solid fa-user-tag" },
                new FieldConfig { Name = "p05", Label = "رقم الطلب", Type = "hidden", ColCss = "3", Readonly = true  },
                new FieldConfig { Name = "p06", Label = "تاريخ الطلب", Type = "hidden", ColCss = "3", Readonly = true,Icon = "fa fa-calendar" },
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Readonly = true, Icon = "fa-solid fa-layer-group" },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p18", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },

                new FieldConfig { Name = "p42", Label = "ملاحظات التسكين", Type = "textarea", ColCss = "12",Required = true,HelpText="الحد الأقصى 950 حرفًا",MaxLength=950, Icon = "fa-regular fa-note-sticky" },

                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },

            };



            var CANCELHOUSINGRESIDENTFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "HISTORICALRESIDENTCANCEL" },
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
                new FieldConfig { Name = "p15", Label = "الاسم", Type = "text", ColCss = "3", Readonly = true, Icon = "fa-solid fa-user" },
                new FieldConfig { Name = "p03", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "3", Readonly = true, Icon = "fa-solid fa-address-card" },
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "3", Readonly = true, Icon = "fa-solid fa-user-tag" },
                new FieldConfig { Name = "p05", Label = "رقم الطلب", Type = "hidden", ColCss = "3", Readonly = true  },
                new FieldConfig { Name = "p06", Label = "تاريخ الطلب", Type = "hidden", ColCss = "3", Readonly = true,Icon = "fa fa-calendar" },
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Readonly = true, Icon = "fa-solid fa-layer-group" },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p18", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },

                new FieldConfig { Name = "p42", Label = "سبب الغاء التسكين", Type = "textarea", ColCss = "12",Required = true,HelpText="الحد الأقصى 950 حرفًا",MaxLength=950, Icon = "fa-regular fa-note-sticky" },

                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },

            };


            var dsModel = new SmartTableDsModel
            {
                PageTitle = "التسكين الاستثنائي بأثر رجعي",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                PanelTitle = "التسكين الاستثنائي بأثر رجعي",
                //TabelLabel = "بيانات المستفيدين",
                //TabelLabelIcon = "fa-solid fa-user-group",
                EnableCellCopy = true,
                ShowColumnVisibility = true,
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = true,
                    ShowExportPdf = true,
                    ShowAdd = canHistoricalStart,
                    ShowEdit = canHistoricalCustody,  // Button always visible
                    ShowEdit1 = canHistoricalFinalize,  // Button always visible
                    ShowDelete = canHistoricalCancel,  // Button always visible
                    ShowBulkDelete = false,

                    ExportConfig = new TableExportConfig
                    {
                        EnablePdf = true,
                        PdfEndpoint = "/exports/pdf/table",
                        PdfTitle = "المستفيدين",
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
                        PdfLogoUrl = "/img/Royal_Saudi_Land_Forces.png",


                    },

                    CustomActions = new List<TableAction>
                            {
                            //  Excel "
                            //new TableAction
                            //{
                            //    Label = "تصدير Excel",
                            //    Icon = "fa-regular fa-file-excel",
                            //    Color = "info",
                            //    Placement = TableActionPlacement.ActionsMenu,
                            //    RequireSelection = false,
                            //    OnClickJs = "table.exportData('excel');"
                            //},

                            ////  PDF "
                            //new TableAction
                            //{
                            //    Label = "تصدير PDF",
                            //    Icon = "fa-regular fa-file-pdf",
                            //    Color = "danger",
                            //    Placement = TableActionPlacement.ActionsMenu,
                            //    RequireSelection = false,
                            //    OnClickJs = "table.exportData('pdf');"
                            //},

                             //  details "       
                            new TableAction
                            {
                                Label = "عرض التفاصيل",
                                ModalTitle = "<i class='fa-solid fa-circle-info text-emerald-600 text-xl mr-2'></i> تفاصيل المستفيد",
                                Icon = "fa-regular fa-file",
                                OpenModal = true,
                                RequireSelection = true,
                                MinSelection = 1,
                                MaxSelection = 1,


                            },
                        },


                    Add = new TableAction
                    {
                        Label = "بدء التسكين الاستثنائي",
                        Icon = "fa-solid fa-house-circle-check",
                        Color = "primary",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "بدء التسكين الاستثنائي بأثر رجعي",
                        ModalMessage = "تأكد من المنزل وتاريخ التسكين الفعلي. سيتم تسجيل الإجراءات التاريخية في دورة واحدة.",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        OpenForm = new FormConfig
                        {
                            FormId = "HistoricalResidentStartForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "بدء إجراءات التسكين",
                            CancelText = "إلغاء",
                            Fields = StartHistoricalFields
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
                                    Field = "LastActionTypeID", Op = "in", Value = "45,46,47,2",
                                    Message = "تم بدء التسكين الاستثنائي لهذا السجل.", Priority = 3
                                }
                            }
                        }
                    },

                    Edit = new TableAction
                    {
                        Label = "تسجيل الملاحظات وطلب قراءة العدادات",
                        Icon = "fa-solid fa-chair",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,

                        ModalTitle = "تسجيل العهد والملاحظات",
                        ModalMessage = "ملاحظة في حال وجود عدادت مرتبطة بالمنزل سيتم احالة الطلب للقسم المسؤول لاكمال الاجراءات",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",

                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",

                        OpenForm = new FormConfig
                        {
                            FormId = "HistoricalResidentEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = CustdyFields
                        },

                        //Meta = new Dictionary<string, object?>
                        //{
                        //    ["routeBy"] = "p16",
                        //    ["routes"] = new Dictionary<string, object?>
                        //    {
                        //        ["45"] = new Dictionary<string, object?>
                        //        {
                        //            ["title"] = "تسجيل العهد والملاحظات",
                        //            ["message"] = "ملاحظة في حال وجود عدادت مرتبطة بالمنزل سيتم احالة الطلب للقسم المسؤول لاكمال الاجراءات",
                        //            ["fields"] = CustdyFields
                        //        },
                        //        ["47"] = new Dictionary<string, object?>
                        //        {
                        //            ["title"] = "تسكين المستفيد بشكل نهائي",
                        //            ["message"] = "سيتم تنفيذ تسكين المستفيد بشكل نهائي ولايمكن التراجع عن ذلك",
                        //            ["fields"] = FinalOccupentFields
                        //        }

                        //    }
                        //},

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
                                Value = "45",
                                Message = "لايمكن تنفيذ هذا الاجراء",
                                Priority = 3
                            },
                          }
                        }
                    },


                    Edit1 = new TableAction
                    {
                        Label = "تسكين المستفيد بشكل نهائي",
                        Icon = "fa-solid fa-key",
                        Color = "success",
                        IsEdit = true,
                        OpenModal = true,

                        ModalTitle = "تسكين المستفيد بشكل نهائي",
                        ModalMessage = "سيتم تنفيذ تسكين المستفيد بشكل نهائي ولايمكن التراجع عن ذلك",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",

                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",

                        OpenForm = new FormConfig
                        {
                            FormId = "HistoricalResidentEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = FinalOccupentFields
                        },

                        //Meta = new Dictionary<string, object?>
                        //{
                        //    ["routeBy"] = "p16",
                        //    ["routes"] = new Dictionary<string, object?>
                        //    {
                        //        ["45"] = new Dictionary<string, object?>
                        //        {
                        //            ["title"] = "تسجيل العهد والملاحظات",
                        //            ["message"] = "ملاحظة في حال وجود عدادت مرتبطة بالمنزل سيتم احالة الطلب للقسم المسؤول لاكمال الاجراءات",
                        //            ["fields"] = CustdyFields
                        //        },
                        //        ["47"] = new Dictionary<string, object?>
                        //        {
                        //            ["title"] = "تسكين المستفيد بشكل نهائي",
                        //            ["message"] = "سيتم تنفيذ تسكين المستفيد بشكل نهائي ولايمكن التراجع عن ذلك",
                        //            ["fields"] = FinalOccupentFields
                        //        }

                        //    }
                        //},

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
                                Message = "لايمكن تنفيذ هذا الاجراء",
                                Priority = 3
                            },
                          }
                        }
                    },

                    Delete = new TableAction
                    {
                        Label = "إلغاء تسكين مستفيد",
                        Icon = "fa-solid fa-close",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,

                        ModalTitle = "إلغاء تسكين مستفيد",
                        ModalMessage = "في حال الغاء تسكين المستفيد سيخصم من الفرص المتاحة له حسب النظام وفي حال كان هذا التخصيص الثاني له سيتم الغاء احقيته في السكن ولايمكن التراجع عن ذلك",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",

                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",

                        OpenForm = new FormConfig
                        {
                            FormId = "HistoricalResidentEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = CANCELHOUSINGRESIDENTFields
                        },

                        //Meta = new Dictionary<string, object?>
                        //{
                        //    ["routeBy"] = "p16",
                        //    ["routes"] = new Dictionary<string, object?>
                        //    {
                        //        ["45"] = new Dictionary<string, object?>
                        //        {
                        //            ["title"] = "تسجيل العهد والملاحظات",
                        //            ["message"] = "ملاحظة في حال وجود عدادت مرتبطة بالمنزل سيتم احالة الطلب للقسم المسؤول لاكمال الاجراءات",
                        //            ["fields"] = CustdyFields
                        //        },
                        //        ["47"] = new Dictionary<string, object?>
                        //        {
                        //            ["title"] = "تسكين المستفيد بشكل نهائي",
                        //            ["message"] = "سيتم تنفيذ تسكين المستفيد بشكل نهائي ولايمكن التراجع عن ذلك",
                        //            ["fields"] = FinalOccupentFields
                        //        }

                        //    }
                        //},

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
                                Value = "45,46,47",
                                Message = "لايمكن الغاء التسكين بعد طلب قراءة العدادات او التسكين النهائي ولكن بإمكانك اخلاء الساكن عن طريق صفحة الاخلاء",
                                Priority = 3
                            },
                          }
                        }
                    },
                }
            };



            dsModel.StyleRules = new List<TableStyleRule>
                        {
                            new TableStyleRule
                            {
                                Target="row", Field="LastActionTypeID", Op="eq", Value="46", Priority=1,
                                PillEnabled=true,
                                PillField="buildingActionTypeResidentAlias",
                                PillTextField="buildingActionTypeResidentAlias",
                                PillCssClass="pill pill-gray",
                                PillMode="replace"
                            },
                            new TableStyleRule
                            {
                                Target="row", Field="LastActionTypeID", Op="eq", Value="47", Priority=1,
                                PillEnabled=true,
                                PillField="buildingActionTypeResidentAlias",
                                PillTextField="buildingActionTypeResidentAlias",
                                PillCssClass="pill pill-yellow",
                                PillMode="replace"
                            },
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
                                Target="row", Field="LastActionTypeID", Op="eq", Value="45", Priority=1,
                                PillEnabled=true,
                                PillField="buildingActionTypeResidentAlias",
                                PillTextField="buildingActionTypeResidentAlias",
                                PillCssClass="pill pill-blue",
                                PillMode="replace"
                            }
                        };



            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-solid fa-user-group",
                Panel = new SmartPagePanelConfig
                {
                    Show = true,
                    ShowIcon = true,
                    ShowSubtitle = true,
                    ShowDescription = true,
                    ShowBadges = true,
                    Layout = "compact",
                    Title = "التسكين الاستثنائي بأثر رجعي",
                    Subtitle = "بدء الإجراءات بأثر رجعي واستكمال العهد والعدادات والتسكين النهائي",
                    Description = "تاريخ التسكين الفعلي يُحدد عند بدء العملية ويُحفظ حتى اعتماد التسكين النهائي",
                    Icon = "fa-user-group",
                    Badges = new List<SmartPagePanelBadge>
                    {
                        new() { Label = "البحث", Value = "اختيار المستفيد", Icon = "fa-solid fa-search", Tone = "success" },
                        new() { Label = "بدء الاجراء", Value = "بدء التسكين الاستثنائي", Icon = "fa-solid fa-sign-in", Tone = "info" },
                        new() { Label = "اعتماد التسكين", Value = "اعتماد تسكين المستفيد", Icon = "fa-solid fa-check", Tone = "default" }
                    }
                },
                Form = filterForm,
                TableDS = isReady ? dsModel : null
            };


            return View("HousingProcedures/HousingHistoricalResident", page);
        }
    }
}
