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
        public async Task<IActionResult> BuildingDetails()
        {

            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }

            string? UtilityTypeID_ = Request.Query["U"].FirstOrDefault();

            UtilityTypeID_ = string.IsNullOrWhiteSpace(UtilityTypeID_) ? null : UtilityTypeID_.Trim();

            bool ready = false;

            ready = !string.IsNullOrWhiteSpace(UtilityTypeID_);




            // Sessions 

            ControllerName = nameof(ControlPanel);
            PageName = nameof(BuildingDetails);

            var spParameters = new object?[] { "BuildingDetails", IdaraId, usersId, HostName, UtilityTypeID_ };

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
            bool canInsert = false;
            bool canUpdate = false;
            bool canDelete = false;



            List<OptionItem> UtilityTypeOptions = new();
            List<OptionItem> BuildingRentTypeOptions = new();
            List<OptionItem> BuildingTypeOptions = new();
            List<OptionItem> MilitaryLocationOptions = new();
            List<OptionItem> BuildingClassOptions = new();



            FormConfig form = new();


            try
            {

                // ---------------------- DDLValues ----------------------




                JsonResult? result;
                string json;




                //// ---------------------- BuildingUtilityType ----------------------
                result = await _CrudController.GetDDLValues(
                    "buildingUtilityTypeName_A", "buildingUtilityTypeID", "2", nameof(BuildingDetails), usersId, IdaraId, HostName
               ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                UtilityTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                // ---------------------- BuildingRentType ----------------------
                result = await _CrudController.GetDDLValues(
                    "buildingRentTypeName_A", "buildingRentTypeID", "3", nameof(BuildingDetails), usersId, IdaraId, HostName
                ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                BuildingRentTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                // ---------------------- BuildingType ----------------------
                result = await _CrudController.GetDDLValues(
                    "buildingTypeName_A", "buildingTypeID", "4", nameof(BuildingDetails), usersId, IdaraId, HostName
                ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                BuildingTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                // ---------------------- MilitaryLocation ----------------------
                result = await _CrudController.GetDDLValues(
                    "militaryLocationName_A", "militaryLocationID", "5", nameof(BuildingDetails), usersId, IdaraId, HostName
                ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                MilitaryLocationOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

                // ---------------------- BuildingClass ----------------------
                result = await _CrudController.GetDDLValues(
                    "buildingClassName_A", "buildingClassID", "6", nameof(BuildingDetails), usersId, IdaraId, HostName
                ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                BuildingClassOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;



                // ----------------------END DDLValues ----------------------


                // Determine which fields should be visible based on SearchID_

                form = new FormConfig
                {
                    Fields = new List<FieldConfig>
                {
                       new FieldConfig
                                {
                                    SectionTitle = "اختيار المرفق",
                                    Name = "UtilityType",
                                    Type = "select",
                                    Select2 = true,
                                    Options = UtilityTypeOptions,
                                    ColCss = "3",
                                    Placeholder = "اختر المرفق",
                                    Icon = "fa fa-user",
                                    Value = UtilityTypeID_,
                                    // ===== تنقّل (sfNav) =====
                                    NavUrl  = "/Housing/BuildingDetails",
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

                        if (permissionName == "INSERT")
                            canInsert = true;

                        if (permissionName == "UPDATE")
                            canUpdate = true;

                        if (permissionName == "DELETE")
                            canDelete = true;
                    }

                    if (ds != null && ds.Tables.Count > 0)
                    {

                        // Resolve a correct row id field (case sensitive match to actual DataTable column)
                        rowIdField = "permissionID";
                        var possibleIdNames = new[] { "permissionID", "PermissionID", "Id", "ID" };

                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        //For change table name to arabic 
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["buildingDetailsNo"] = "رقم المبنى",
                            ["buildingDetailsRooms"] = "عدد الغرف",
                            ["buildingLevelsCount"] = "عدد الطوابق",
                            ["buildingDetailsArea"] = "مكان المبنى",
                            ["buildingDetailsCoordinates"] = "احداثيات المبنى",
                            ["buildingTypeName_A"] = "نوع المبنى",
                            ["buildingUtilityTypeName_A"] = "نوع المرفق",
                            ["militaryLocationName_A"] = "حي المبنى",
                            ["buildingClassName_A"] = "فئة المبنى",
                            ["buildingDetailsTel_1"] = "تليفون 1",
                            ["buildingDetailsTel_2"] = "تليفون 2",
                            ["buildingDetailsRemark"] = "ملاحظات",
                            ["buildingRentTypeName_A"] = "نوع الايجار",
                            ["buildingRentAmount"] = "الايجار"
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

                            bool isbuildingDetailsID = c.ColumnName.Equals("buildingDetailsID", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingTypeID_FK = c.ColumnName.Equals("buildingTypeID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingUtilityTypeID_FK = c.ColumnName.Equals("buildingUtilityTypeID_FK", StringComparison.OrdinalIgnoreCase);
                            bool ismilitaryLocationID_FK = c.ColumnName.Equals("militaryLocationID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingClassID_FK = c.ColumnName.Equals("buildingClassID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingDetailsStartDate = c.ColumnName.Equals("buildingDetailsStartDate", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingDetailsEndDate = c.ColumnName.Equals("buildingDetailsEndDate", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingDetailsActive = c.ColumnName.Equals("buildingDetailsActive", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingRentStartDate = c.ColumnName.Equals("buildingRentStartDate", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingRentEndDate = c.ColumnName.Equals("buildingRentEndDate", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraId_FK = c.ColumnName.Equals("IdaraId_FK", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingDetailsTel_1 = c.ColumnName.Equals("buildingDetailsTel_1", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingDetailsTel_2 = c.ColumnName.Equals("buildingDetailsTel_2", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingRentTypeID = c.ColumnName.Equals("buildingRentTypeID", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                //if u want to hide any column 
                                ,
                                Visible = !(isbuildingDetailsID || isbuildingTypeID_FK || isbuildingUtilityTypeID_FK || ismilitaryLocationID_FK
                                || isbuildingClassID_FK || isbuildingDetailsStartDate || isbuildingDetailsEndDate || isbuildingDetailsActive
                                || isbuildingRentStartDate || isbuildingRentEndDate || isIdaraId_FK || isbuildingDetailsTel_1 || isbuildingDetailsTel_2 || isbuildingRentTypeID)
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
                                if (rowIdField.Equals("permissionID", StringComparison.OrdinalIgnoreCase) &&
                                    dict.TryGetValue("permissionID", out var alt))
                                    dict["permissionID"] = alt;
                                else if (rowIdField.Equals("permissionID", StringComparison.OrdinalIgnoreCase) &&
                                         dict.TryGetValue("permissionID", out var alt2))
                                    dict["permissionID"] = alt2;
                            }

                            // Prefill pXX fields on the row so Edit form (which uses pXX names) loads the selected row values
                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("buildingDetailsID") ?? Get("buildingDetailsID") ?? Get("BuildingDetailsID") ?? Get("ID");
                            dict["p02"] = Get("buildingDetailsNo");
                            dict["p03"] = Get("buildingDetailsRooms");
                            dict["p04"] = Get("buildingLevelsCount");
                            dict["p05"] = Get("buildingDetailsArea");
                            dict["p06"] = Get("buildingDetailsCoordinates");
                            dict["p07"] = Get("buildingTypeID_FK");
                            dict["p08"] = Get("buildingUtilityTypeID_FK");
                            dict["p09"] = Get("militaryLocationID_FK");
                            dict["p10"] = Get("buildingClassID_FK");
                            dict["p11"] = Get("buildingDetailsTel_1");
                            dict["p12"] = Get("buildingDetailsTel_2");
                            dict["p13"] = Get("buildingRentTypeID");
                            dict["p14"] = Get("buildingRentAmount");
                            dict["p15"] = Get("buildingDetailsStartDate");
                            dict["p16"] = Get("buildingDetailsRemark");
                            dict["p17"] = Get("IdaraId_FK");
                            dict["p18"] = Get("buildingDetailsEndDate");

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




            // Check in dt2 for buildingUtilityIsRent == "1"
            bool buildingUtilityIsRent = false;
            string buildingUtilityIsRentValue = "0";

            if (dt2 != null && dt2.Columns.Contains("buildingUtilityIsRent"))
            {
                var row = dt2.AsEnumerable()
                    .FirstOrDefault(r => r["buildingUtilityTypeID"]?.ToString() == UtilityTypeID_);

                if (row != null)
                {
                    buildingUtilityIsRentValue = row["buildingUtilityIsRent"]?.ToString()?.Trim() ?? "0";
                    buildingUtilityIsRent = (buildingUtilityIsRentValue == "True");
                }
            }


            var addFields = new List<FieldConfig>
{
    // keep id hidden first so row id can flow when needed
    new FieldConfig { Name = rowIdField, Type = "hidden" },



    new FieldConfig { Name = "p02", Label = "اسم المبنى", Type = "text",   ColCss = "3", Required = true},
    new FieldConfig { Name = "p03", Label = "عدد الغرف", Type = "number", ColCss = "3", Required = true },
    new FieldConfig { Name = "p04", Label = "عدد الطوابق", Type = "number", ColCss = "3", Required = true },
    new FieldConfig { Name = "p05", Label = "مساحة المبنى", Type = "number", ColCss = "3", Required = true },
    new FieldConfig { Name = "p06", Label = "احداثيات المبنى", Type = "text", ColCss = "3", Required = true },
    new FieldConfig { Name = "p16", Label = "نوع المبنى", Type = "select", ColCss = "3", Required = true, Options = BuildingTypeOptions, Select2=true  },
    new FieldConfig { Name = "p07", Label = "فئة المبنى", Type = "select", ColCss = "6", Required = true, Options = BuildingClassOptions, Select2=true  },
    new FieldConfig { Name = "p08", Label = "موقع المبنى", Type = "select", ColCss = "6", Required = true, Options = MilitaryLocationOptions, Select2=true },
    new FieldConfig { Name = "p09", Label = "تيلفون المبنى 1", Type = "tel", ColCss = "3", Required = false },
    new FieldConfig { Name = "p10", Label = "تيلفون المبنى 2", Type = "tel", ColCss = "3", Required = false },

    new FieldConfig { Name = "p13", Label = "تاريخ بداية المبنى", Type = "date", ColCss = "3", Required = true },
    new FieldConfig { Name = "p18", Label = "تاريخ نهاية المبنى", Type = "date", ColCss = "3" },
    new FieldConfig { Name = "p14", Label = "ملاحظات", Type = "text", ColCss = "6", Required = false },
    new FieldConfig { Name = "p15", Label = "UtilityTypeID_", Type = "hidden", ColCss = "3", Required = false,Value =UtilityTypeID_ },
};

            // ✅ إذا فيه إيجار: أضف p12/p13 بمكانها الصحيح قبل p14
            if (buildingUtilityIsRent)
            {
                // حطهم بعد p10 مباشرة (بدون أرقام Insert ثابتة)
                var idxAfterP10 = addFields.FindIndex(f => f.Name == "p10");
                if (idxAfterP10 < 0) idxAfterP10 = addFields.Count - 1;

                addFields.Insert(idxAfterP10 + 1, new FieldConfig { Name = "p11", Label = "نوع الايجار", Type = "select", ColCss = "3", Required = true, Options = BuildingRentTypeOptions });
                addFields.Insert(idxAfterP10 + 2, new FieldConfig { Name = "p12", Label = "مبلغ الايجار", Type = "text", ColCss = "3", Required = true });
            }

            // ✅ Inject required hidden headers (مرة واحدة فقط)
            addFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName });
            addFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId });
            addFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId });
            addFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT" });
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
                new FieldConfig { Name = "ActionType",          Type = "hidden", Value = "UPDATE" },
                new FieldConfig { Name = "idaraID",             Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata",           Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname",            Type = "hidden", Value = HostName},
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField,            Type = "hidden" },

                new FieldConfig { Name = "p01", Label = "المعرف",   Type = "hidden", Readonly = true, ColCss = "3" },
                new FieldConfig { Name = "p02", Label = "اسم المبنى", Type = "text",   ColCss = "3", Required = true ,Value =buildingUtilityIsRent.ToString()},
                new FieldConfig { Name = "p03", Label = "عدد الغرف", Type = "number", ColCss = "3", Required = true },
                new FieldConfig { Name = "p04", Label = "عدد الطوابق", Type = "number", ColCss = "3", Required = true },
                new FieldConfig { Name = "p05", Label = "مساحة المبنى", Type = "number", ColCss = "3", Required = true },
                new FieldConfig { Name = "p06", Label = "احداثيات المبنى", Type = "number", ColCss = "3", Required = true },
                new FieldConfig { Name = "p07", Label = "نوع المبنى", Type = "select", ColCss = "3", Required = true,   Options =         BuildingTypeOptions },
                new FieldConfig { Name = "p08", Label = "نوع المرفق", Type = "hidden", ColCss = "3", Required = true,   Value= UtilityTypeID_ },
                new FieldConfig { Name = "p09", Label = "موقع المبنى", Type = "select", ColCss = "6", Required = true,  Options =        MilitaryLocationOptions },
                new FieldConfig { Name = "p10", Label = "فئة المبنى", Type = "select", ColCss = "6", Required = true,   Options =         BuildingClassOptions },
                new FieldConfig { Name = "p11", Label = "تيلفون المبنى 1", Type = "number", ColCss = "3", Required = false },
                new FieldConfig { Name = "p12", Label = "تيلفون المبنى 2", Type = "number", ColCss = "3", Required = false },

                new FieldConfig { Name = "p15", Label = "تاريخ بداية المبنى", Type = "date", ColCss = "3", Required = true },
                new FieldConfig { Name = "p18", Label = "تاريخ نهاية المبنى", Type = "date", ColCss = "3" },

                new FieldConfig { Name = "p16", Label = "ملاحظات", Type = "text", ColCss = "3", Required = false },
                new FieldConfig { Name = "p17", Label = "UtilityTypeID_", Type = "hidden", ColCss = "3", Required = false,Value =UtilityTypeID_ },
            };

            if (buildingUtilityIsRent)
            {
                // Find the index after the last phone field (e.g., after "p12" or "p11" depending on your field names)
                var idxAfterPhone = updateFields.FindIndex(f => f.Name == "p12");
                if (idxAfterPhone < 0) idxAfterPhone = updateFields.Count - 1;

                updateFields.Insert(idxAfterPhone + 1, new FieldConfig
                {
                    Name = "p13",
                    Label = "نوع الايجار",
                    Type = "select",
                    ColCss = "3",
                    Required = true,
                    Options = BuildingRentTypeOptions
                });
                updateFields.Insert(idxAfterPhone + 2, new FieldConfig
                {
                    Name = "p14",
                    Label = "مبلغ الايجار",
                    Type = "number",
                    ColCss = "3",
                    Required = true
                });
            }



            //Delete fields: show confirmation as a label(not textbox) and show ID as label while still posting p01

            var deleteFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETE" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = HostName },

                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "UtilityTypeID_", Type = "hidden", Value = UtilityTypeID_ },


                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },

                // hidden p01 actually posted to SP
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "UtilityTypeID_" }
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
                PageTitle = "المباني",
                PanelTitle = "المباني ",

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = canInsert,
                    ShowEdit = canUpdate,
                    ShowDelete = canDelete,
                    ShowBulkDelete = false,

                    Add = new TableAction
                    {
                        Label = "إضافة مبنى",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة مبنى جديد",
                        OpenForm = new FormConfig
                        {
                            FormId = "InsertForm",
                            Title = "بيانات المبنى الجديد",
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
                        Label = "تعديل مبنى",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                       // Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل بيانات المبنى",
                        //ModalMessage = "بسم الله الرحمن الرحيم",
                        OpenForm = new FormConfig
                        {
                            FormId = "employeeEditForm",
                            Title = "تعديل بيانات المبنى",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = updateFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1


                    },

                    Delete = new TableAction
                    {
                        Label = "حذف مبنى",
                        Icon = "fa fa-trash",
                        Color = "danger",
                       // Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        //ModalTitle = "رسالة تحذيرية",
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من حذف هذا المبنى؟",
                        ModalMessageClass = "bg-red-50 border border-red-200 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "employeeDeleteForm",
                            Title = "تأكيد حذف المبنى",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حذف", Type = "submit", Color = "danger", Icon = "fa fa-save" },
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

            //var vm = new FormTableViewModel
            //{
            //    Form = form,
            //    Table = dsModel,
            //    PageTitle = dsModel.PageTitle,
            //    PanelTitle = dsModel.PanelTitle
            //};
            //return View("Permission/Permission", vm);
            var vm = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-home",
                Form = form,
                //TableDS = dsModel
                TableDS = ready ? dsModel : null

            };

            return View("HousingDefinitions/BuildingDetails", vm);
        }
    }
}
