using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Mvc.Helpers;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Text.Json;
using SmartFoundation.MVC.Reports;
using SmartFoundation.UI.ViewModels.SmartPrint;



namespace SmartFoundation.Mvc.Controllers.Housing
{
    public partial class HousingController : Controller
    {
        public async Task<IActionResult> BuildingSpaces(int pdf = 0)
        {

            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }

            string? UtilityTypeID_ = Request.Query["U"].FirstOrDefault();
            string? BuildingDetailsID_ = Request.Query["B"].FirstOrDefault();

            UtilityTypeID_ = string.IsNullOrWhiteSpace(UtilityTypeID_)
                ? null
                : UtilityTypeID_.Trim();

            BuildingDetailsID_ = string.IsNullOrWhiteSpace(BuildingDetailsID_)
                ? null
                : BuildingDetailsID_.Trim();

            bool showBuildings = !string.IsNullOrWhiteSpace(UtilityTypeID_);

            bool ready =
                !string.IsNullOrWhiteSpace(UtilityTypeID_) &&
                !string.IsNullOrWhiteSpace(BuildingDetailsID_);






            // Sessions 

            ControllerName = nameof(Housing);
            PageName = nameof(BuildingSpaces);

            var spParameters = new object?[] { "BuildingSpaces", IdaraId, usersId, HostName, UtilityTypeID_, BuildingDetailsID_ };

            //var spParameters = new object?[] { "Permission", IdaraID, userID, HostName, SearchID_, UserID_, distributorID_, RoleID_, Idara_, Dept_, Section_, Divison_ };

            DataSet ds;


            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();


            ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);




            SplitDataSet(ds);

            string? BuildingStartDate_ = null;
            if (!string.IsNullOrWhiteSpace(BuildingDetailsID_)
                && dt1 is not null
                && dt1.Columns.Contains("buildingDetailsID"))
            {
                var selectedBuilding = dt1.AsEnumerable().FirstOrDefault(row =>
                    string.Equals(
                        row["buildingDetailsID"]?.ToString(),
                        BuildingDetailsID_,
                        StringComparison.OrdinalIgnoreCase));

                if (selectedBuilding is not null)
                {
                    if (dt1.Columns.Contains("buildingDetailsStartDate")
                        && selectedBuilding["buildingDetailsStartDate"] != DBNull.Value
                        && DateTime.TryParse(selectedBuilding["buildingDetailsStartDate"]?.ToString(), out var buildingStartDate))
                    {
                        BuildingStartDate_ = buildingStartDate.ToString("yyyy-MM-dd");
                    }
                }
            }

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }




          

           




            string rowIdField = "";
            bool canInsertBuildingSpaces = false;
            bool canUpdateBuildingSpaces = false;
            bool canDeleteBuildingSpaces = false;



            List<OptionItem> UtilityTypeOptions = new();
            List<OptionItem> BuildingOptions = new();
            List<OptionItem> BuildingSpaceTypeOptions = new();
            


           

            FormConfig form = new();


            try
            {

                // ---------------------- DDLValues ----------------------




                JsonResult? result;
                string json;




                //// ---------------------- BuildingUtilityType ----------------------
                result = await _CrudController.GetDDLValues(
                    "buildingUtilityTypeName_A", "buildingUtilityTypeID", "2", nameof(BuildingSpaces), usersId, IdaraId, HostName
               ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                UtilityTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                // ---------------------- BuildingSpaceType ----------------------
                result = await _CrudController.GetDDLValues(
                    "BuildingSpaceTypeName_A", "BuildingSpaceTypeID", "4", nameof(BuildingSpaces), usersId, IdaraId, HostName
                ) as JsonResult;

                json = JsonSerializer.Serialize(result!.Value);

                BuildingSpaceTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)
                    ?? new List<OptionItem>();

                // ---------------------- Buildings filtered by utility type ----------------------
                if (!string.IsNullOrWhiteSpace(UtilityTypeID_))
                {
                    result = await _CrudController.GetDDLValues(
                        "buildingDetailsNo",
                        "buildingDetailsID",
                        "1",
                        nameof(BuildingSpaces),
                        usersId,
                        IdaraId,
                        HostName,
                        "buildingUtilityTypeID",
                        UtilityTypeID_,
                        "اختر المبنى"
                    ) as JsonResult;

                    json = JsonSerializer.Serialize(result!.Value);

                    BuildingOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)
                        ?? new List<OptionItem>();
                }
                else
                {
                    BuildingOptions = new List<OptionItem>
                    {
                        new OptionItem
                        {
                            Value = "-1",
                            Text = "اختر المرفق أولاً",
                            Disabled = true
                        }
                    };
                }

               


                // ----------------------END DDLValues ----------------------


                // Determine which fields should be visible based on SearchID_

                form = new FormConfig
                {
                    Fields = new List<FieldConfig>
    {
        new FieldConfig
        {
            SectionTitle = "اختيار المرفق والمبنى",
            Name = "UtilityType",
            Label = "المرفق",
            Type = "select",
            Select2 = true,
            Options = UtilityTypeOptions,
            ColCss = "3",
            Placeholder = "اختر المرفق",
            Icon = "fa-solid fa-building",
            Value = UtilityTypeID_,
            Required = true,
            RejectValue = "-1",
            RejectMsg = "اختر المرفق",

            NavUrl = "/Housing/BuildingSpaces",
            NavKey = "U",
            OnChangeJs = "sfNav(this)"
        },

        new FieldConfig
        {
            Name = "Building",
            Label = "المبنى",
            Type = "select",
            Select2 = true,
            Options = BuildingOptions,
            ColCss = "3",
            Placeholder = "اختر المبنى",
            Icon = "fa-solid fa-house",
            Value = BuildingDetailsID_,
            Required = true,

            // لا يظهر قبل اختيار المرفق
            IsHidden = !showBuildings,

            NavUrl = "/Housing/BuildingSpaces",

            // المبنى المختار
            NavKey = "B",

            // الاحتفاظ بالمرفق المختار
            NavKey3 = "U",
            NavField3 = "UtilityType",

            RejectValue = "-99999",
            RejectMsg = "اختر المبنى",
            OnChangeJs = "sfNav(this)"
        }
    },

                    Buttons = new List<FormButtonConfig>()
                };

                if (ds != null && ds.Tables.Count > 0 && ds.Tables[0].Rows.Count > 0)
                {
                    // اقرأ الجدول الأول
                    // نبحث عن صلاحيات محددة داخل الجدول
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "INSERTBUILDINGSPACES")
                            canInsertBuildingSpaces = true;

                        if (permissionName == "UPDATEBUILDINGSPACES")
                            canUpdateBuildingSpaces = true;

                        if (permissionName == "DELETEBUILDINGSPACES")
                            canDeleteBuildingSpaces = true;
                    }

                    var spacesTable = dt3 ?? new DataTable("BuildingSpaces");

                    // Dapper returns an empty result set without its column schema.
                    // Keep a stable table structure so the grid remains visible after
                    // selecting a building even when it has no registered spaces yet.
                    if (ready && spacesTable.Columns.Count == 0)
                    {
                        spacesTable.Columns.Add("BuildingSpaceID", typeof(long));
                        spacesTable.Columns.Add("BuildingDetailsID_FK", typeof(long));
                        spacesTable.Columns.Add("BuildingSpaceTypeID_FK", typeof(int));
                        spacesTable.Columns.Add("BuildingSpaceTypeCode", typeof(string));
                        spacesTable.Columns.Add("BuildingSpaceTypeName_A", typeof(string));
                        spacesTable.Columns.Add("BuildingSpaceSequence", typeof(int));
                        spacesTable.Columns.Add("BuildingSpaceName", typeof(string));
                        spacesTable.Columns.Add("BuildingSpaceLength", typeof(decimal));
                        spacesTable.Columns.Add("BuildingSpaceWidth", typeof(decimal));
                        spacesTable.Columns.Add("BuildingSpaceArea", typeof(decimal));
                        spacesTable.Columns.Add("BuildingSpaceStartDate", typeof(DateTime));
                        spacesTable.Columns.Add("BuildingSpaceEndDate", typeof(DateTime));
                        spacesTable.Columns.Add("BuildingSpaceActive", typeof(bool));
                        spacesTable.Columns.Add("BuildingSpaceRemark", typeof(string));
                        spacesTable.Columns.Add("CanceledBy", typeof(string));
                        spacesTable.Columns.Add("CanceledDate", typeof(DateTime));
                        spacesTable.Columns.Add("entryDate", typeof(DateTime));
                        spacesTable.Columns.Add("entryData", typeof(string));
                        spacesTable.Columns.Add("hostName", typeof(string));
                    }

                    if (spacesTable != null && spacesTable.Columns.Count > 0)
                    {

                        // Resolve a correct row id field (case sensitive match to actual DataTable column)
                        rowIdField = "BuildingSpaceID";
                        var possibleIdNames = new[] { "BuildingSpaceID", "buildingSpaceID", "Id", "ID" };

                        rowIdField = possibleIdNames.FirstOrDefault(n => spacesTable.Columns.Contains(n))
                                     ?? spacesTable.Columns[0].ColumnName;

                        //For change table name to arabic 
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["BuildingSpaceID"] = "الرقم المرجعي",
                            ["BuildingSpaceTypeName_A"] = "نوع الفراغ",
                            ["BuildingSpaceSequence"] = "الرقم التسلسلي",
                            ["BuildingSpaceName"] = "اسم الفراغ",
                            ["BuildingSpaceLength"] = "الطول",
                            ["BuildingSpaceWidth"] = "العرض",
                            ["BuildingSpaceArea"] = "المساحة",
                            ["BuildingSpaceStartDate"] = "تاريخ البداية",
                            ["BuildingSpaceEndDate"] = "تاريخ النهاية",
                            ["BuildingSpaceActive"] = "نشط",
                            ["BuildingSpaceRemark"] = "ملاحظات",
                            ["BuildingDetailsID_FK"] = " الرقم المرجعي للمبني",
                            ["BuildingSpaceID"] = " الرقم المرجعي للفراغ",
                            ["buildingDetailsNo"] = "رقم المبنى",
                            ["buildingDetailsRooms"] = "عدد الغرف",
                            ["buildingLevelsCount"] = "عدد الطوابق",
                            ["buildingDetailsArea"] = "المساحة",
                            ["buildingDetailsCoordinates"] = "الاحداثيات",
                            ["buildingTypeName_A"] = "نوع المبنى",
                            ["buildingUtilityTypeName_A"] = "نوع المرفق",
                            ["militaryLocationName_A"] = "موقع المبنى",
                            ["buildingClassName_A"] = "فئة المبنى",
                            ["buildingDetailsTel_1"] = "تليفون 1",
                            ["buildingDetailsTel_2"] = "تليفون 2",
                            ["buildingDetailsRemark"] = "ملاحظات",
                            ["buildingDetailsRemark"] = "ملاحظات",
                            ["buildingActionTypeBuildingAlias"] = "حالة المبنى",
                            ["ElectrcityServicesView"] = "كهرباء",
                            ["WaterServicesView"] = "ماء",
                            ["GasServicesView"] = "غاز",
                            ["buildingRentAmount"] = "الايجار"
                        };


                        // build columns from DataTable schema
                        foreach (DataColumn c in spacesTable.Columns)
                        {
                            string colType = "text";
                            var t = c.DataType;
                            if (t == typeof(bool)) colType = "bool";
                            else if (t == typeof(DateTime)) colType = "date";
                            else if (t == typeof(decimal)) colType = "decimal";
                            else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                                     || t == typeof(float) || t == typeof(double))
                                colType = "number";

                           
                            bool isSpaceInternalColumn =
                                c.ColumnName.Equals("BuildingSpaceSequence", StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.Equals("BuildingSpaceTypeCode", StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.Equals("BuildingSpaceTypeID_FK", StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.Equals("BuildingSpaceActive", StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.Equals("CanceledBy", StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.Equals("CanceledDate", StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.Equals("entryDate", StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.Equals("entryData", StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.Equals("hostName", StringComparison.OrdinalIgnoreCase);

                            
                            
                            bool isBuildingSpaceName = c.ColumnName.Equals("BuildingSpaceName", StringComparison.OrdinalIgnoreCase);


                            


                            List<OptionItem> filterOpts = new();
                            if (isBuildingSpaceName)
                            {
                                var field = c.ColumnName;

                                var distinctVals = spacesTable.AsEnumerable()
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
                                Visible = !(isSpaceInternalColumn),

                                Filter = (isBuildingSpaceName)
                                    ? new TableColumnFilter
                                    {
                                        Enabled = true,
                                        Type = "select",
                                        Options = filterOpts,
                                    }
                                    : new TableColumnFilter
                                    {
                                        Enabled = false
                                    }
                            });
                        }



                        // build rows (plain dictionaries) so JSON serialization is clean
                        foreach (DataRow r in spacesTable.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in spacesTable.Columns)
                            {
                                var val = r[c];
                                if (c.ColumnName.Equals("buildingDetailsArea", StringComparison.OrdinalIgnoreCase) && val != DBNull.Value)
                                {
                                    dict[c.ColumnName] = Convert.ToDecimal(val).ToString("0.00");
                                }
                                else if (c.ColumnName.Equals("buildingRentAmount", StringComparison.OrdinalIgnoreCase) && val != DBNull.Value)
                                {
                                    dict[c.ColumnName] = Convert.ToDecimal(val).ToString("0.00");
                                }
                                else
                                {
                                    dict[c.ColumnName] = val == DBNull.Value ? null : val;
                                }
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

                            // Prefill pXX fields according to BuildingSpacesSP update contract.
                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("BuildingSpaceID");
                            dict["p02"] = Get("BuildingSpaceName");
                            dict["p03"] = Get("BuildingSpaceLength");
                            dict["p04"] = Get("BuildingSpaceWidth");
                            dict["p05"] = Get("BuildingSpaceArea");
                            dict["p06"] = Get("BuildingSpaceStartDate");
                            dict["p07"] = Get("BuildingSpaceEndDate");
                            dict["p08"] = Get("BuildingSpaceRemark");
                            dict["p20"] = Get("buildingDetailsNo");
                           

                            rowsList.Add(dict);
                        }
                    }


                }
            }
            catch (Exception)
            {
                ViewBag.DataSetError = "حدث خطأ أثناء تحميل البيانات. يرجى المحاولة مرة أخرى.";
            }


            // Local helper: map TableColumn -> FieldConfig


            // Local helper: build Edit1 fields (prefer dataset column for general number or fallback)

            // build dynamic field lists
            // REPLACE Add form fields: hide dataset textboxes and use your own custom inputs

            //ADD



            var currentUrl = Request.Path + Request.QueryString;




            // Check in dt2 for buildingUtilityIsRent == "1"
           


            var addFields = new List<FieldConfig>
{
    new FieldConfig { Name = "p01", Type = "hidden", Value = BuildingDetailsID_ },
    new FieldConfig { Name = "p20", Label = "رقم المبنى", Type = "select", Select2 = true, Options = BuildingOptions, ColCss = "3", Required = false, Disabled = true, Value = BuildingDetailsID_ },
    new FieldConfig { Name = "p02", Label = "نوع الفراغ", Type = "select", Select2 = true, Options = BuildingSpaceTypeOptions, ColCss = "3", Required = true, Placeholder = "اختر نوع الفراغ" },
    new FieldConfig { Name = "p03", Label = "اسم الفراغ", Type = "text", ColCss = "6", Required = true, MaxLength = 200 },
    new FieldConfig { Name = "p07", Label = "تاريخ البداية", Type = "date", ColCss = "6", Required = true, Value = BuildingStartDate_ },
    new FieldConfig { Name = "p08", Label = "تاريخ النهاية", Type = "date", ColCss = "6", Required = false },
    new FieldConfig { Name = "p04", Label = "الطول",Type = "text",TextMode = "money_sar", ColCss = "3", Required = false },
    new FieldConfig { Name = "p05", Label = "العرض", Type = "text",TextMode = "money_sar", ColCss = "3", Required = false },
    new FieldConfig { Name = "p06", Label = "المساحة", Type = "text",TextMode = "money_sar", ColCss = "3", Required = false },
    new FieldConfig { Name = "p09", Label = "ملاحظات", Type = "text", ColCss = "3", Required = false, MaxLength = 1000 },
};


            // ✅ Inject required hidden headers (مرة واحدة فقط)
            addFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERTBUILDINGSPACES" });
            addFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });

            addFields.Insert(0, new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl });
            addFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });


          

            var updateFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "redirectAction",      Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController",  Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "redirectUrl",  Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "pageName_",           Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",          Type = "hidden", Value = "UPDATEBUILDINGSPACES" },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig { Name = "p20", Label = "رقم المبنى", Type = "text", ColCss = "3", Required = false,Readonly=true, MaxLength = 200 },
                new FieldConfig { Name = "p02", Label = "اسم الفراغ", Type = "text", ColCss = "3", Required = true, MaxLength = 200 },
                new FieldConfig { Name = "p06", Label = "تاريخ البداية", Type = "date", ColCss = "3", Required = true },
                new FieldConfig { Name = "p07", Label = "تاريخ النهاية", Type = "date", ColCss = "3", Required = false },
                new FieldConfig { Name = "p03", Label = "الطول", Type = "text",TextMode = "money_sar", ColCss = "3", Required = false },
                new FieldConfig { Name = "p04", Label = "العرض", Type = "text",TextMode = "money_sar", ColCss = "3", Required = false },
                new FieldConfig { Name = "p05", Label = "المساحة", Type = "text",TextMode = "money_sar", ColCss = "3", Required = false },
                new FieldConfig { Name = "p08", Label = "ملاحظات", Type = "text", ColCss = "3", Required = false, MaxLength = 1000 },
            };

           



            //Delete fields: show confirmation as a label(not textbox) and show ID as label while still posting p01

            var deleteFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETEBUILDINGSPACES" },

                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig { Name = "p20", Label = "رقم المبنى", Type = "text", ColCss = "6", Required = false,Readonly=true, MaxLength = 200 },
                new FieldConfig { Name = "p02", Label = "اسم الفراغ", Type = "text", ColCss = "6", Required = true,Readonly=true, MaxLength = 200 },


            };


            //bool hasRows = dt1 is not null && dt1.Rows.Count > 0 && rowsList.Count > 0;

            //ViewBag.HideTable = false;
            //string.IsNullOrWhiteSpace(UserID_);

            // then create dsModel (snippet shows toolbar parts that use the dynamic lists)
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
                PageTitle = "فراغات المبنى",
                PanelTitle = "الفراغات التابعة للمبنى",
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
                    ShowAdd = canInsertBuildingSpaces,
                    ShowEdit = canUpdateBuildingSpaces,
                    ShowDelete = canDeleteBuildingSpaces,
                    ShowPrint1 = false,
                    ShowBulkDelete = false,
                    Print1 = new TableAction
                    {
                        Label = "طباعة تقرير",
                        Icon = "fa fa-print",
                        Color = "info",
                        RequireSelection = false,
                        OnClickJs = @"
                        (function () {
                            var u = window.UtilityTypeID_ || '';
                        
                            sfPrintWithBusy(table, {
                              pdf: 1,
                              extraParams: { U: u },
                              busy: { title: 'طباعة سجلات انتظار' }
                            });
                        })();
                        ",

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



                                                     }
                        }
                    },

                    Add = new TableAction
                    {
                        Label = "إضافة فراغ",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة فراغ جديد",
                        OpenForm = new FormConfig
                        {
                            FormId = "InsertForm",
                            Title = "بيانات الفراغ الجديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" /*Icon = "fa fa-save"*/ },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", /*Icon = "fa fa-times",*/ OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" },

                            }
                        }
                    },

                   

                    // Edit: opens populated form for single selection and saves via SP
                    Edit = new TableAction
                    {
                        Label = "تعديل فراغ",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                       // Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل بيانات الفراغ",
                        //ModalMessage = "بسم الله الرحمن الرحيم",
                        OpenForm = new FormConfig
                        {
                            FormId = "employeeEditForm",
                            Title = "تعديل بيانات الفراغ",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = updateFields,
                            //Buttons = new List<FormButtonConfig>
                            //{
                            //    new FormButtonConfig { Text = "تنفيذ", Type = "submit", Color = "success", Icon = "fa fa-check" },
                            //    new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", Icon = "fa fa-times", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            //},
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1


                    },

                    Delete = new TableAction
                    {
                        Label = "إلغاء فراغ",
                        Icon = "fa fa-trash",
                        Color = "danger",
                       // Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        //ModalTitle = "رسالة تحذيرية",
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من إلغاء هذا الفراغ؟",
                        ModalMessageClass = "bg-red-50 border border-red-200 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "employeeDeleteForm",
                            Title = "تأكيد إلغاء الفراغ",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "إلغاء الفراغ", Type = "submit", Color = "danger", Icon = "fa fa-trash" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", Icon = "fa fa-times", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = deleteFields
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


           
         

            ViewBag.UtilityTypeID = UtilityTypeID_;
            return View("HousingDefinitions/BuildingSpaces", vm);
        }
    }
}
