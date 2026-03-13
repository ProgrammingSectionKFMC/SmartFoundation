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
        public async Task<IActionResult> HousingHandover()
        {

            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }

            string? LastActionTypeID_ = Request.Query["U"].FirstOrDefault();

            LastActionTypeID_ = string.IsNullOrWhiteSpace(LastActionTypeID_) ? null : LastActionTypeID_.Trim();

            bool ready = false;

            ready = !string.IsNullOrWhiteSpace(LastActionTypeID_);




            // Sessions 

            ControllerName = nameof(Housing);
            PageName = nameof(HousingHandover);

            var spParameters = new object?[] { "HousingHandover", IdaraId, usersId, HostName, LastActionTypeID_ };

            //var spParameters = new object?[] { "Permission", IdaraID, userID, HostName, SearchID_, UserID_, distributorID_, RoleID_, Idara_, Dept_, Section_, Divison_ };

            DataSet ds;


            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();


            ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);




            SplitDataSet(ds);

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }





            string rowIdField = "";
            bool canHousingHandover = false;




            List<OptionItem> LastActionTypeBuildingAliasOptions = new();
            List<OptionItem> NextBuildingActionTypeIDOptions = new();




            FormConfig form = new();


            try
            {

                // ---------------------- DDLValues ----------------------




                JsonResult? result;
                string json;




                //// ---------------------- buildingActionTypeBuildingAlias ----------------------
                result = await _CrudController.GetDDLValues(
                    "buildingActionTypeBuildingAlias", "BuildingActionTypeID_FK", "2", nameof(HousingHandover), usersId, IdaraId, HostName
               ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                LastActionTypeBuildingAliasOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


                //// ---------------------- buildingActionTypeBuildingAlias ----------------------
                result = await _CrudController.GetDDLValuesWithExtraParams(
                "buildingActionTypeName_A",
                "NextBuildingActionTypeID_FK",
                "3",
                nameof(HousingHandover),
                usersId,
                IdaraId,
                HostName,
                null,
                null,
                null,
                LastActionTypeID_
                ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);
                NextBuildingActionTypeIDOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;



                // ----------------------END DDLValues ----------------------


                // Determine which fields should be visible based on SearchID_

                form = new FormConfig
                {
                    Fields = new List<FieldConfig>
                {
                       new FieldConfig
                                {
                                    SectionTitle = "اختيار الحالة",
                                    Name = "UtilityType",
                                    Type = "select",
                                    Select2 = true,
                                    Options = LastActionTypeBuildingAliasOptions,
                                    ColCss = "3",
                                    Placeholder = "اختر الحالة",
                                    Icon = "fa fa-user",
                                    Value = LastActionTypeID_,
                                    // ===== تنقّل (sfNav) =====
                                    NavUrl  = "/Housing/HousingHandover",
                                    NavKey  = "U",        // قيمة الحقل (UtilityType)
                                    NavKey2 = "S",        // ثابت
                                    NavVal2 = "1",
                                    OnChangeJs = "sfNav(this)"
                                },
                     },
                    Buttons = new List<FormButtonConfig>
                    {

                    }
                };

                if (ds != null && ds.Tables.Count > 0 && ds.Tables[0].Rows.Count > 0)
                {
                    // اقرأ الجدول الأول
                    // نبحث عن صلاحيات محددة داخل الجدول
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "HOUSINGHANDOVERRESPONSIBLEINBUILDINGMAINTENANCEDEPARTMENT" ||
                            permissionName == "HOUSINGHANDOVERRESPONSIBLEINQUALITYDEPARTMENT" ||
                            permissionName == "HOUSINGHANDOVERRESPONSIBLEINGENERALSERVICESDEPARTMENT" ||
                            permissionName == "HOUSINGHANDOVERRESPONSIBLEINHOUSINGDEPARTMENT" ||
                            permissionName == "HOUSINGHANDOVERRESPONSIBLEINEXECUTIONDEPARTMENT")
                            canHousingHandover = true;

                    }

                    if (ds != null && ds.Tables.Count > 0)
                    {

                        // Resolve a correct row id field (case sensitive match to actual DataTable column)
                        rowIdField = "buildingDetailsID";
                        var possibleIdNames = new[] { "buildingDetailsID", "BuildingDetailsID", "Id", "ID" };

                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        //For change table name to arabic 
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["buildingDetailsNo"] = "رقم المبنى",
                            ["buildingDetailsID"] = "الرقم المرجعي",
                            ["militaryLocationName_A"] = "الموقع / الحي",
                            ["militaryAreaCityName_A"] = "المدينة",
                            ["militaryAreaName_A"] = "المنطقة",
                            ["buildingUtilityTypeName_A"] = "نوع المبنى",
                            ["LastActionTypeName"] = "حالة المبنى",
                            ["LastActionEntryDatestring"] = "تاريخ تنفيذ الاجراء",
                            ["LastActionNote"] = "ملاحظات",
                            ["LastActionTypeBuildingAlias"] = "حالة المبنى"

                        };


                        // build columns from DataTable schema
                        foreach (DataColumn c in dt1.Columns)
                        {
                            string colType = "text";
                            var t = c.DataType;
                            if (t == typeof(bool)) colType = "bool";
                            else if (t == typeof(DateTime)) colType = "date";
                            else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                                     || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                                colType = "number";

                            bool isHidden =  c.ColumnName.Equals("LastActionTypeID", StringComparison.OrdinalIgnoreCase)
                                          || c.ColumnName.Equals("LastActionID", StringComparison.OrdinalIgnoreCase)
                                          || c.ColumnName.Equals("LastActionEntryDate", StringComparison.OrdinalIgnoreCase)
                                          ;

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



                        // build rows (plain dictionaries) so JSON serialization is clean
                        foreach (DataRow r in dt1.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt1.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            // Ensure the row id key actually exists with correct casing
                            if (!dict.ContainsKey(rowIdField))
                            {
                                // Try to copy from a differently cased variant
                                if (rowIdField.Equals("buildingDetailsID", StringComparison.OrdinalIgnoreCase) &&
                                    dict.TryGetValue("buildingDetailsID", out var alt))
                                    dict["buildingDetailsID"] = alt;
                                else if (rowIdField.Equals("buildingDetailsID", StringComparison.OrdinalIgnoreCase) &&
                                         dict.TryGetValue("buildingDetailsID", out var alt2))
                                    dict["buildingDetailsID"] = alt2;
                            }

                            // Prefill pXX fields on the row so Edit form (which uses pXX names) loads the selected row values
                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("buildingDetailsID") ?? Get("buildingDetailsID") ?? Get("BuildingDetailsID") ?? Get("ID");
                            dict["p02"] = Get("buildingDetailsNo");
                            dict["p03"] = Get("militaryLocationName_A");
                            dict["p04"] = Get("militaryAreaCityName_A");
                            dict["p05"] = Get("militaryAreaName_A");
                            dict["p06"] = Get("buildingUtilityTypeName_A");
                            dict["p07"] = Get("LastActionTypeID");
                            dict["p08"] = Get("LastActionTypeName");
                            dict["p09"] = Get("LastActionTypeBuildingAlias");
                            dict["p12"] = Get("LastActionID");
                            dict["p13"] = Get("LastActionEntryDatestring");
                            dict["p14"] = Get("LastActionEntryDate");


                            rowsList.Add(dict);
                        }
                    }


                }
            }
            catch (Exception ex)
            {
                ViewBag.DataSetError = ex.Message;
                //TempData["info"] = ex.Message;
            }


            // Local helper: map TableColumn -> FieldConfig


            // Local helper: build Edit1 fields (prefer dataset column for general number or fallback)

            // build dynamic field lists
            // REPLACE Add form fields: hide dataset textboxes and use your own custom inputs

            //ADD



            var currentUrl = Request.Path + Request.QueryString;


            var HousingHandoverFields = new List<FieldConfig>
{
    new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
    new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "HousingHandoverAction" },
    new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId },
    new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId },
    new FieldConfig { Name = "hostname",           Type = "hidden", Value = HostName },
    new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
    new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
    new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
    new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                // selection context
              
    new FieldConfig { Name = rowIdField, Type = "hidden" },



    new FieldConfig { Name = "p01", Label = "الرقم المرجعي", Type = "hidden",   ColCss = "3", Required = true,Readonly = true},
    new FieldConfig { Name = "p02", Label = "رقم المبنى", Type = "text",   ColCss = "3", Required = true,Readonly = true},
    new FieldConfig { Name = "p05", Label = "المنطقة", Type = "hidden", ColCss = "3", Required = true,Readonly = true },
    new FieldConfig { Name = "p04", Label = "المدينة", Type = "text", ColCss = "3", Required = true,Readonly = true },
    new FieldConfig { Name = "p03", Label = "الموقع / الحي", Type = "text", ColCss = "3", Required = true,Readonly = true },
    new FieldConfig { Name = "p06", Label = "نوع المبنى", Type = "text", ColCss = "3", Required = true,Readonly = true },
    new FieldConfig { Name = "p07", Label = "الاجراء التالي", Type = "select", ColCss = "6", Required = true, Options = NextBuildingActionTypeIDOptions, Select2=true,Readonly = true },
    new FieldConfig { Name = "p08", Label = "حالة المبنى 1", Type = "hidden", ColCss = "6", Required = false ,Readonly = true},
    new FieldConfig { Name = "p09", Label = "حالة المبنى 2", Type = "hidden", ColCss = "6", Required = false,Readonly = true },
    new FieldConfig { Name = "p10", Label = "LastActionTypeID_", Type = "hidden", ColCss = "3", Required = false,Value =LastActionTypeID_,Readonly = true },
    new FieldConfig { Name = "p11", Label = "ملاحظات", Type = "textarea", ColCss = "6", Required = true },
    new FieldConfig { Name = "p12", Label = "LastActionID", Type = "hidden", ColCss = "6", Required = true },
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
                PageTitle = "اجراءات المباني",
                PanelTitle = "اجراءات المباني",

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = canHousingHandover,

                    ShowBulkDelete = false,
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


                    Add = new TableAction
                    {
                        Label = "اتخاذ اجراء جديد",
                        Icon = "fa fa-gavel",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "اتخاذ اجراء جديد",
                        ModalMessage ="الرجاء التأكد من بيانات المبنى, لايمكن التراجع عن هذا الاجراء",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OpenForm = new FormConfig
                        {
                            FormId = "InsertForm",
                            Title = "بيانات الاجراء الجديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = HousingHandoverFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" /*Icon = "fa fa-save"*/ },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", /*Icon = "fa fa-times",*/ OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" },

                            }
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },


                }
            };

            var vm = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-home",
                Form = form,
                //TableDS = dsModel
                TableDS = ready ? dsModel : null

            };

            return View("HousingProcedures/HousingHandover", vm);
        }
    }
}
