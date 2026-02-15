using Microsoft.AspNetCore.Mvc;
using SmartFoundation.MVC.Reports;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartPrint;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers.ElectronicBillSystem
{
    public partial class ElectronicBillSystemController : Controller
    {
        public async Task<IActionResult> Meters(int pdf = 0)
        {
            //  قراءة السيشن والكونتكست
            if (!InitPageContext(out var redirect))
                return redirect!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }

            ControllerName = nameof(ElectronicBillSystem);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "Meters" : PageName;

            var spParameters = new object?[]
            {
             PageName ?? "Meters",
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
            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            string rowIdField = "";
            bool canINSERTNEWMETER = false;
            bool canINSERTNEWMETERTYPE = false;
            bool canUpdate = false;
            bool canDelete = false;
            bool canUPDATENATIONALIDFORRESIDENT = false;



            // ---------------------- DDLValues ----------------------


            List<OptionItem> meterTypeOptions = new();
            List<OptionItem> MeterServiceTypeOptions = new();

            JsonResult? result;
                string json;




                 //// ---------------------- meterTypeOptions ----------------------
                 result = await _CrudController.GetDDLValues(
                    "meterTypeName_A", "meterTypeID", "2", nameof(Meters), usersId, IdaraId, HostName
               ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                meterTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            //// ---------------------- meterTypeOptions ----------------------
            result = await _CrudController.GetDDLValues(
                    "meterServiceTypeName_A", "meterServiceTypeID", "3", nameof(Meters), usersId, IdaraId, HostName
               ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                meterTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


                // ----------------------END DDLValues ----------------------


                try
                {
                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // صلاحيات
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "INSERTNEWMETER") canINSERTNEWMETER = true;
                        if (permissionName == "INSERTNEWMETERTYPE") canINSERTNEWMETERTYPE = true;
                        if (permissionName == "UPDATE") canUpdate = true;
                        if (permissionName == "DELETE") canDelete = true;
                        if (permissionName == "UPDATENATIONALIDFORRESIDENT") canUPDATENATIONALIDFORRESIDENT = true;
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
                            ["meterID"] = "رقم التسلسلي",
                            ["meterTypeID_FK"] = "نوع العداد",
                            ["meterNo"] = "رقم العداد",
                            ["meterName_A"] = "اسم العداد (عربي)",
                            ["meterName_E"] = "اسم العداد (إنجليزي)",
                            ["meterDescription"] = "الوصف",
                            ["meterStartDate"] = "تاريخ البدء",
                            ["meterEndDate"] = "تاريخ الانتهاء",
                            ["IdaraId_FK"] = "الإدارة"
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

                            // Hide foreign key columns
                            bool isMeterTypeFK = c.ColumnName.Equals("meterTypeID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraFK = c.ColumnName.Equals("IdaraId_FK", StringComparison.OrdinalIgnoreCase);
                            
                            // Add filter for meter type if needed
                         

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,
                                Visible = !(isMeterTypeFK || isIdaraFK),  // Hide FK columns only
                              
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
                            dict["p01"] = Get("meterID") ?? Get("meterID");
                            dict["p02"] = Get("meterTypeID_FK");
                            dict["p03"] = Get("meterNo");
                            dict["p04"] = Get("meterName_A");
                            dict["p05"] = Get("meterName_E");
                            dict["p06"] = Get("meterDescription");
                            dict["p07"] = Get("meterStartDate");
                            dict["p08"] = Get("meterEndDate");
                            dict["p09"] = Get("meterServiceTypeID");
                            dict["p10"] = Get("meterTypeName_A ");
                            dict["p11"] = Get("meterTypeName_E");
                            dict["p12"] = Get("meterTypeDescription");
                            dict["p13"] = Get("meterTypeConversionFactor");
                            dict["p14"] = Get("meterMaxRead");
                            dict["p15"] = Get("meterTypeStartDate");
                            dict["p16"] = Get("meterTypeEndDate");
                            dict["p17"] = Get("meterServicePrice");
                            dict["p18"] = Get("MeterNote");
                           

                            rowsList.Add(dict);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.BuildingTypeDataSetError = ex.Message;
            }

            // ADD fields
            var addNewMeterFields = new List<FieldConfig>
            {
                new FieldConfig { Name = rowIdField, Type = "hidden" },

                new FieldConfig 
                { 
                    Name = "p02", 
                    Label = "نوع العداد", 
                    Type = "select", 
                    ColCss = "6", 
                    Required = true, 
                    Options = meterTypeOptions,  // Load from meterType table (dt2)
                    Select2 = true,
                    Icon = "fa-solid fa-gauge"
                },
                
                new FieldConfig 
                { 
                    Name = "p03", 
                    Label = "رقم العداد", 
                    Type = "text", 
                    ColCss = "6", 
                    Required = true,
                    Icon = "fa-solid fa-hashtag",
                    MaxLength = 50
                },
                
                new FieldConfig 
                { 
                    Name = "p04", 
                    Label = "اسم العداد (عربي)", 
                    Type = "text", 
                    ColCss = "6", 
                    Required = true,
                    TextMode = "arabic",
                    Icon = "fa-solid fa-gauge-simple-high",
                    MaxLength = 100
                },
                
                new FieldConfig 
                { 
                    Name = "p05", 
                    Label = "اسم العداد (إنجليزي)", 
                    Type = "text", 
                    ColCss = "6",
                    TextMode = "english",
                    Icon = "fa-solid fa-gauge-simple-high",
                    MaxLength = 100
                },
                
                new FieldConfig 
                { 
                    Name = "p06", 
                    Label = "الوصف", 
                    Type = "textarea", 
                    ColCss = "12",
                    MaxLength = 500
                },
                
                new FieldConfig 
                { 
                    Name = "p07", 
                    Label = "تاريخ البدء", 
                    Type = "date", 
                    ColCss = "6",
                    Required = true,
                    Icon = "fa fa-calendar"
                },
                
                new FieldConfig 
                { 
                    Name = "p08", 
                    Label = "تاريخ الانتهاء", 
                    Type = "date", 
                    ColCss = "6",
                    Icon = "fa fa-calendar"
                },
                
                new FieldConfig 
                { 
                    Name = "p09", 
                    Label = "الإدارة", 
                    Type = "hidden",  // Auto-filled from session
                    Value = IdaraId
                }
            };

        

            // Form for adding a NEW METER TYPE (not a meter!)
            var addNewMeterTypeFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "meterTypeID", Type = "hidden" },  // PK, auto-generated

                new FieldConfig 
                { 
                    Name = "p09", 
                    Label = "نوع خدمة العداد", 
                    Type = "select", 
                    ColCss = "6", 
                    Required = true, 
                    Options = meterTypeOptions,  // Load from MeterServiceType table if exists
                    Select2 = true,
                    Icon = "fa-solid fa-server",
                    HelpText = "اختر نوع خدمة العداد (كهرباء، ماء، إلخ)"
                },
                
                new FieldConfig 
                { 
                    Name = "p10", 
                    Label = "اسم نوع العداد (عربي)", 
                    Type = "text", 
                    ColCss = "3", 
                    Required = true,
                    TextMode = "arabic",
                    Icon = "fa-solid fa-tag",
                    MaxLength = 100,
                    Placeholder = "مثال: عداد كهرباء رقمي"
                },
                
                new FieldConfig 
                { 
                    Name = "p11", 
                    Label = "اسم نوع العداد (إنجليزي)", 
                    Type = "text", 
                    ColCss = "3",
                    TextMode = "english",
                    Icon = "fa-solid fa-tag",
                    MaxLength = 100,
                    Placeholder = "Example: Digital Electric Meter"
                },
                
               
                
                new FieldConfig 
                { 
                    Name = "p13", 
                    Label = "معامل التحويل", 
                    Type = "number", 
                    ColCss = "4",
                    Required = true,
                    Icon = "fa-solid fa-calculator",
                    HelpText = "معامل تحويل القراءة إلى وحدة القياس الفعلية",
                    Value = "1"
                },
                
                new FieldConfig 
                { 
                    Name = "p14", 
                    Label = "الحد الأقصى للقراءة", 
                    Type = "number", 
                    ColCss = "4",
                    Icon = "fa-solid fa-gauge-high",
                    HelpText = "أقصى قراءة ممكنة للعداد"
                },
                
                new FieldConfig 
                { 
                    Name = "p15", 
                    Label = "تاريخ البدء", 
                    Type = "date", 
                    ColCss = "4",
                    Required = true,
                    Icon = "fa fa-calendar"
                },
                
                new FieldConfig 
                { 
                    Name = "p16", 
                    Label = "تاريخ الانتهاء", 
                    Type = "hidden", 
                    ColCss = "4",
                    Icon = "fa fa-calendar",
                    HelpText = "اتركه فارغاً إذا كان نشطاً"
                },


                   new FieldConfig
                {
                    Name = "p17",
                    Label = "سعر الخدمة للعداد",
                    Type = "number",
                    ColCss = "4",
                    Icon = "fa-solid fa-money-bill-1-wave"
                },

                 new FieldConfig
                {
                    Name = "p18",
                    Label = "الوصف",
                    Type = "textarea",
                    ColCss = "6",
                    MaxLength = 500,
                    Placeholder = "وصف تفصيلي لنوع العداد"
                },


            };

            // hidden fields
            addNewMeterTypeFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken",Type ="hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addNewMeterTypeFields.Insert(0, new FieldConfig { Name = "hostname",Type="hidden",Value = Request.Host.Value });
            addNewMeterTypeFields.Insert(0, new FieldConfig { Name = "entrydata",Type="hidden",Value =usersId.ToString() });
            addNewMeterTypeFields.Insert(0, new FieldConfig { Name = "idaraID",Type="hidden",Value =IdaraId.ToString() });
            addNewMeterTypeFields.Insert(0, new FieldConfig { Name = "ActionType",Type="hidden",Value="INSERTNEWMETERTYPE" });
            addNewMeterTypeFields.Insert(0, new FieldConfig { Name = "pageName_",Type ="hidden",Value=PageName });
            addNewMeterTypeFields.Insert(0, new FieldConfig { Name = "redirectAction",Type="hidden", Value=PageName });
            addNewMeterTypeFields.Insert(0, new FieldConfig { Name = "redirectController",Type="hidden",Value=ControllerName });





            // UPDATE fields
            var updateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATE" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField, Type = "hidden" },

                // ✅ METER FIELDS (not resident fields!)
                new FieldConfig { Name = "p01", Label = "رقم العداد", Type = "hidden", Readonly = true },
                
                new FieldConfig 
                { 
                    Name = "p02", 
                    Label = "نوع العداد", 
                    Type = "select", 
                    ColCss = "6", 
                    Required = true, 
                    Options = meterTypeOptions,  // Load from dt2
                    Select2 = true,
                    Icon = "fa-solid fa-gauge"
                },
                
                new FieldConfig 
                { 
                    Name = "p03", 
                    Label = "الرقم التسلسلي للعداد", 
                    Type = "text", 
                    ColCss = "6", 
                    Required = true,
                    Icon = "fa-solid fa-hashtag",
                    MaxLength = 50
                },
                
                new FieldConfig 
                { 
                    Name = "p04", 
                    Label = "اسم العداد (عربي)", 
                    Type = "text", 
                    ColCss = "6", 
                    Required = true,
                    TextMode = "arabic",
                    Icon = "fa-solid fa-gauge-simple-high",
                    MaxLength = 100
                },
                
                new FieldConfig 
                { 
                    Name = "p05", 
                    Label = "اسم العداد (إنجليزي)", 
                    Type = "text", 
                    ColCss = "6",
                    TextMode = "english",
                    Icon = "fa-solid fa-gauge-simple-high",
                    MaxLength = 100
                },
                
                new FieldConfig 
                { 
                    Name = "p06", 
                    Label = "الوصف", 
                    Type = "textarea", 
                    ColCss = "12",
                    MaxLength = 500
                },
                
                new FieldConfig 
                { 
                    Name = "p07", 
                    Label = "تاريخ البدء", 
                    Type = "date", 
                    ColCss = "6",
                    Required = true,
                    Icon = "fa fa-calendar"
                },
                
                new FieldConfig 
                { 
                    Name = "p08", 
                    Label = "تاريخ الانتهاء", 
                    Type = "date", 
                    ColCss = "6",
                    Icon = "fa fa-calendar"
                },
                
                new FieldConfig 
                { 
                    Name = "p09", 
                    Label = "الإدارة", 
                    Type = "hidden",
                    Value = IdaraId
                }
            };

            // DELETE fields
            var deleteFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "DELETE" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                
                // ✅ Show meter info for confirmation
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "meterID" },
                
                new FieldConfig 
                { 
                    Name = "p03", 
                    Label = "الرقم التسلسلي", 
                    Type = "text", 
                    ColCss = "6", 
                    Readonly = true,
                    Icon = "fa-solid fa-hashtag"
                },
                
                new FieldConfig 
                { 
                    Name = "p04", 
                    Label = "اسم العداد", 
                    Type = "text", 
                    ColCss = "6", 
                    Readonly = true,
                    Icon = "fa-solid fa-gauge"
                },
                
                new FieldConfig 
                { 
                    Name = "p07", 
                    Label = "تاريخ البدء", 
                    Type = "date", 
                    ColCss = "6", 
                    Readonly = true,
                    Icon = "fa fa-calendar"
                }
            };

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "إدارة العدادات",  // Changed from "المستفيدين"
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = "إدارة العدادات",  // Changed
                //TabelLabel = "بيانات المستفيدين",
                //TabelLabelIcon = "fa-solid fa-user-group",
                EnableCellCopy = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                ShowColumnVisibility=true,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowExportPdf = false,
                    ShowAdd = canINSERTNEWMETERTYPE,  // This will now show "Add Meter Type"
                    ShowAdd1 = canINSERTNEWMETER,  // This will now show "Add Meter Type"
                    ShowEdit = canINSERTNEWMETERTYPE,
                    ShowDelete = canDelete,
                    ShowPrint1 = false,
                    ShowBulkDelete = false,

                    CustomActions = new List<TableAction>
                    {
                        new TableAction
                        {
                            Label = "عرض التفاصيل",
                            ModalTitle = "<i class='fa-solid fa-circle-info text-emerald-600 text-xl mr-2'></i> تفاصيل العداد",
                            Icon = "fa-regular fa-file",
                            OpenModal = true,
                            RequireSelection = true,
                            MinSelection = 1,
                            MaxSelection = 1,
                        },
               
                    },

                    // ✅ CHANGED: This is now for adding METER TYPE (not meter)
                  

                    Add = new TableAction
                    {
                        Label = "إضافة نوع عداد جديد",  // ✅ Changed label
                        Icon = "fa fa-layer-group",  // ✅ Changed icon
                        Color = "primary",  // ✅ Changed color to differentiate
                        OpenModal = true,
                        ModalTitle = "<i class='fa-solid fa-sitemap text-blue-600 text-xl mr-2'></i> إضافة نوع عداد جديد",

                        OpenForm = new FormConfig
                        {
                            FormId = "MeterTypeInsertForm",
                            Title = "بيانات نوع العداد الجديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addNewMeterTypeFields,  // ✅ Now uses MeterType fields
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "primary" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },

                    Add1 = new TableAction
                    {
                        Label = "إضافة عداد جديد",
                        Icon = "fa fa-plus-circle",
                        Color = "success",
                        OpenModal = true,
                        RequireSelection = false,  // Don't require selection for adding
                        ModalTitle = "<i class='fa-solid fa-gauge-high text-emerald-600 text-xl mr-2'></i> إضافة عداد جديد",

                        OpenForm = new FormConfig
                        {
                            FormId = "AddNewMeterForm",
                            Title = "بيانات عداد جديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addNewMeterFields,  // ✅ Use addNewMeterFields here
                            Buttons = new List<FormButtonConfig>
                                {
                                    new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                    new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                                }
                        }
                    },


                    Edit = new TableAction
                    {
                        Label = "تعديل بيانات عداد",  // ✅ Changed
                        Icon = "fa-solid fa-pen",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa-solid fa-pen-to-square text-emerald-600 text-xl mr-2'></i> تعديل بيانات عداد",  // ✅ Changed
                        OpenForm = new FormConfig
                        {
                            FormId = "MeterEditForm",  // ✅ Changed
                            Title = "تعديل بيانات عداد",  // ✅ Changed
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
                        Label = "حذف عداد",  // ✅ Changed
                        Icon = "fa-regular fa-trash-can",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من حذف بيانات العداد؟",  // ✅ Changed
                        ModalMessageClass = "bg-red-100 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "MeterDeleteForm",  // ✅ Changed
                            Title = "تأكيد حذف بيانات العداد",  // ✅ Changed
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حذف", Type = "submit", Color = "danger", },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = deleteFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                }
            };


            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-solid fa-gauge-high",  // ✅ Changed from "fa-solid fa-user-group"
                TableDS = dsModel
            };


          

            return View("Meter/Meters", page);
        }
    }
}