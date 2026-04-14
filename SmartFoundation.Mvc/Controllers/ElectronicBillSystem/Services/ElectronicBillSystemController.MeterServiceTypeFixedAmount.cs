using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Text.Json;


namespace SmartFoundation.Mvc.Controllers.ElectronicBillSystem
{
    public partial class ElectronicBillSystemController : Controller
    {
        public async Task<IActionResult> MeterServiceTypeFixedAmount()
        {
            //  تهيئة بيانات الصفحة (السيشن + ControllerName + PageName...)
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = nameof(ElectronicBillSystem);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "MeterServiceTypeFixedAmount" : PageName;

            var spParameters = new object?[]
            {
             PageName ?? "MeterServiceTypeFixedAmount",
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
            bool canINSERTSERVICEFIXEDAMOUNT = false;
            bool canEDITSERVICEFIXEDAMOUNT = false;
            bool canDELETESERVICEFIXEDAMOUNT = false;

            List<OptionItem> meterServiceTypeOptions = new();


            // ---------------------- DDLValues ----------------------




            JsonResult? result;
            string json;




            //// ---------------------- WaitingClass ----------------------
            result = await _CrudController.GetDDLValues(
                "meterServiceTypeName_A", "meterServiceTypeID", "2", nameof(MeterServiceTypeFixedAmount), usersId, IdaraId, HostName
           ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            meterServiceTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;
            //// ---------------------- militaryUnitOptions ----------------------

            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // 🔐 قراءة الصلاحيات من الجدول الأول
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "INSERTSERVICEFIXEDAMOUNT") canINSERTSERVICEFIXEDAMOUNT = true;
                        if (permissionName == "EDITSERVICEFIXEDAMOUNT") canEDITSERVICEFIXEDAMOUNT = true;
                        if (permissionName == "DELETESERVICEFIXEDAMOUNT") canDELETESERVICEFIXEDAMOUNT = true;
                    }

                    if (dt1 != null && dt1.Rows.Count > 0)
                    {
                        // 🔑 تحديد حقل الـ Id
                        rowIdField = "MeterServiceTypeFixedAmountID";
                        var possibleIdNames = new[] { "MeterServiceTypeFixedAmountID", "meterServiceTypeFixedAmountID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // 🏷️ عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["MeterServiceTypeFixedAmountID"] = "الرقم المرجعي",
                            ["FixedAmount"] = "المبلغ",
                            ["meterServiceTypeName_A"] = "الخدمة",
                            ["MeterServiceTypeFixedAmountStartDate"] = "بداية الخدمة"
                        };

                        // 🧱 الأعمدة
                        foreach (DataColumn c in dt1.Columns)
                        {
                            string colType = "text";
                            var t = c.DataType;
                            if (t == typeof(bool)) colType = "bool";
                            else if (t == typeof(DateTime)) colType = "date";
                            else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                                     || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                                colType = "number";


                            // إخفاء بعض الأعمدة
                            bool isMeterServiceTypeID_FK = c.ColumnName.Equals("MeterServiceTypeID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isMeterServiceTypeFixedAmountEndDate = c.ColumnName.Equals("MeterServiceTypeFixedAmountEndDate", StringComparison.OrdinalIgnoreCase);
                            bool isMeterServiceTypeFixedAmountActive = c.ColumnName.Equals("MeterServiceTypeFixedAmountActive", StringComparison.OrdinalIgnoreCase);
                            bool isidaraID_FK = c.ColumnName.Equals("idaraID_FK", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,
                                Visible = !(isMeterServiceTypeID_FK || isMeterServiceTypeFixedAmountEndDate|| isMeterServiceTypeFixedAmountActive || isidaraID_FK)
                            });
                        }

                        //  الصفوف
                        foreach (DataRow r in dt1.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt1.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            // التأكد من وجود حقل الـ Id
                            if (!dict.ContainsKey(rowIdField))
                            {
                                if (rowIdField.Equals("MeterServiceTypeFixedAmountID", StringComparison.OrdinalIgnoreCase) &&
                                    dict.TryGetValue("MeterServiceTypeFixedAmountID", out var alt))
                                    dict["MeterServiceTypeFixedAmountID"] = alt;
                                else if (rowIdField.Equals("MeterServiceTypeFixedAmountID", StringComparison.OrdinalIgnoreCase) &&
                                         dict.TryGetValue("MeterServiceTypeFixedAmountID", out var alt2))
                                    dict["MeterServiceTypeFixedAmountID"] = alt2;
                            }

                            // تعبئة p01..p04 لاستخدامها في الفورم
                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("MeterServiceTypeFixedAmountID") ?? Get("meterServiceTypeFixedAmountID");
                            dict["p02"] = Get("MeterServiceTypeID_FK");
                            dict["p03"] = Get("FixedAmount");
                            dict["p04"] = Get("MeterServiceTypeFixedAmountStartDate");
                            dict["p05"] = Get("MeterServiceTypeFixedAmountEndDate");
                            dict["p06"] = Get("MeterServiceTypeFixedAmountActive");
                            dict["p07"] = Get("idaraID_FK");
                            dict["p08"] = Get("meterServiceTypeName_A");

                            rowsList.Add(dict);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.buildingClassDataSetError = ex.Message;
            }

            //  ADD fields
            var addFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "INSERTSERVICEFIXEDAMOUNT" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField, Type = "hidden" },


                new FieldConfig { Name = rowIdField, Type = "hidden" },

                new FieldConfig { Name = "p01", Label = "الرقم المرجعي",  Type = "hidden", ColCss = "6", Required = false },
                new FieldConfig { Name = "p08", Label = "الخدمة",  Type = "hidden", ColCss = "4", Required = false },
                new FieldConfig { Name = "p02", Label = "نوع الخدمة", Type = "select", ColCss = "6", Required = true,Options = meterServiceTypeOptions},
                new FieldConfig { Name = "p03", Label = "السعر",  Type = "money_sar", ColCss = "4", Required = true },
                new FieldConfig { Name = "p04", Label = "تاريخ بدء سعر الخدمة",  Type = "date", ColCss = "4", Required = true },
                new FieldConfig { Name = "p05", Label = "تاريخ نهاية سعر الخدمة",  Type = "hidden", ColCss = "6", Required = false },
                new FieldConfig { Name = "p06", Label = "نشط",  Type = "hidden", ColCss = "6", Required = false },
                new FieldConfig { Name = "p07", Label = "idaraID",  Type = "hidden", ColCss = "6", Required = false },
            };

          

            // ✏️ UPDATE fields
            var updateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",      Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController",  Type = "hidden", Value = ControllerName},
                new FieldConfig { Name = "pageName_",           Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",          Type = "hidden", Value = "EDITSERVICEFIXEDAMOUNT" },
                new FieldConfig { Name = "idaraID",             Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",           Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",            Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField,            Type = "hidden" },

                new FieldConfig { Name = "p01", Label = "الرقم المرجعي",  Type = "hidden", ColCss = "6", Required = false },
                new FieldConfig { Name = "p08", Label = "الخدمة",  Type = "text", ColCss = "4", Required = true,Readonly = true },
                new FieldConfig { Name = "p02", Label = "نوع الخدمة", Type = "hidden", ColCss = "6", Required = false,Options = meterServiceTypeOptions},
                new FieldConfig { Name = "p03", Label = "السعر",  Type = "money_sar", ColCss = "4", Required = true },
                new FieldConfig { Name = "p04", Label = "تاريخ بدء سعر الخدمة",  Type = "date", ColCss = "4", Required = true },
                new FieldConfig { Name = "p05", Label = "تاريخ نهاية سعر الخدمة",  Type = "hidden", ColCss = "6", Required = false },
                new FieldConfig { Name = "p06", Label = "نشط",  Type = "hidden", ColCss = "6", Required = false },
                new FieldConfig { Name = "p07", Label = "idaraID",  Type = "hidden", ColCss = "6", Required = false },
            };

            // 🗑️ DELETE fields
            var deleteFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETESERVICEFIXEDAMOUNT" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField, Type = "hidden" },


                new FieldConfig { Name = "p01", Label = "الرقم المرجعي",  Type = "hidden", ColCss = "6", Required = false,Readonly = true },
                new FieldConfig { Name = "p08", Label = "الخدمة",  Type = "text", ColCss = "4", Required = true,Readonly = true },
                new FieldConfig { Name = "p02", Label = "نوع الخدمة", Type = "hidden", ColCss = "6", Required = false,Options = meterServiceTypeOptions},
                new FieldConfig { Name = "p03", Label = "السعر",  Type = "money_sar", ColCss = "4", Required = true,Readonly = true },
                new FieldConfig { Name = "p04", Label = "تاريخ بدء سعر الخدمة",  Type = "date", ColCss = "4", Required = true,Readonly = true },
                new FieldConfig { Name = "p05", Label = "تاريخ نهاية سعر الخدمة",  Type = "hidden", ColCss = "6", Required = false,Readonly = true },
                new FieldConfig { Name = "p06", Label = "نشط",  Type = "hidden", ColCss = "6", Required = false,Readonly = true },
                new FieldConfig { Name = "p07", Label = "idaraID",  Type = "hidden", ColCss = "6", Required = false,Readonly = true },
            };

            //  SmartTable model
            var dsModel = new SmartFoundation.UI.ViewModels.SmartTable.SmartTableDsModel
            {
                PageTitle = "أسعار الخدمات الثابتة",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = false,
                AllowExport = true,
                PanelTitle = "أسعار الخدمات الثابتة ",
                EnablePagination = false,
                ShowPageSizeSelector = false,
               
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = canINSERTSERVICEFIXEDAMOUNT,
                    ShowEdit = canEDITSERVICEFIXEDAMOUNT,
                    ShowDelete = canDELETESERVICEFIXEDAMOUNT,
                    ShowBulkDelete = false,
                    ShowExportPdf=false,
                    ExportConfig = new TableExportConfig
                    {
                        EnablePdf = true,
                        PdfEndpoint = "/exports/pdf/table",
                        PdfTitle = "المستفيدين",
                        PdfPaper = "A4",
                        PdfOrientation = "portrait",
                        PdfShowPageNumbers = true,
                        Filename = "Residents",
                        PdfShowGeneratedAt = false, 
                    },

                    Add = new TableAction
                    {
                        Label = "إضافة سعر خدمة جديد",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة سعر خدمة جديد",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassInsertForm",
                            Title = "بيانات سعر الخدمة الجديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ",   Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },

                    Edit = new TableAction
                    {
                        Label = "تعديل سعر خدمة",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        //Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل بيانات سعر خدمة",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm", 
                            Title = "تعديل بيانات سعر خدمة",
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
                        Label = "حذف سعر خدمة",
                        Icon = "fa fa-trash",
                        Color = "danger",
                       // Placement = TableActionPlacement.ActionsMenu, 
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من حذف سعر هذه الخدمة؟ \n لن يحسب اي مطالبات على المباني التي يوجد بها هذه الخدمة ولايوجد عدادات مرتبطه بها من لحظه تنفيذ الحذف",
                        ModalMessageClass = "bg-red-50 border border-red-200 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassDeleteForm",
                            Title = "تأكيد حذف سعر خدمة",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حذف",   Type = "submit", Color = "danger",  },
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

            //return View("HousingDefinitions/BuildingClass", dsModel);

            var page = new SmartFoundation.UI.ViewModels.SmartPage.SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-sitemap",
                TableDS = dsModel
            };

            return View("Services/MeterServiceTypeFixedAmount", page);

        }
    }
}
