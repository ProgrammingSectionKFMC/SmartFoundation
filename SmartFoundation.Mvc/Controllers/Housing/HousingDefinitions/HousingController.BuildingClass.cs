using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;


namespace SmartFoundation.Mvc.Controllers.Housing
{
    public partial class HousingController : Controller
    {
        public async Task<IActionResult> BuildingClass()
        {
            //  تهيئة بيانات الصفحة (السيشن + ControllerName + PageName...)
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = nameof(Housing);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "BuildingClass" : PageName;

            var spParameters = new object?[]
            {
             PageName ?? "BuildingClass",
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
            bool canInsert = false;
            bool canUpdate = false;
            bool canDelete = false;

            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // 🔐 قراءة الصلاحيات من الجدول الأول
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "INSERT") canInsert = true;
                        if (permissionName == "UPDATE") canUpdate = true;
                        if (permissionName == "DELETE") canDelete = true;
                    }

                    if (dt1 != null && dt1.Rows.Count > 0)
                    {
                        // 🔑 تحديد حقل الـ Id
                        rowIdField = "buildingClassID";
                        var possibleIdNames = new[] { "buildingClassID", "BuildingClassID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // 🏷️ عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["buildingClassID"] = "الرقم المرجعي",
                            ["buildingClassName_A"] = "فئة المبنى بالعربي",
                            ["buildingClassName_E"] = "فئة المبنى بالانجليزي",
                            ["buildingClassDescription"] = "ملاحظات"
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
                            bool isbuildingClassOrder = c.ColumnName.Equals("buildingClassOrder", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingClassActive = c.ColumnName.Equals("buildingClassActive", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,
                                Visible = !(isbuildingClassOrder || isbuildingClassActive)
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
                                if (rowIdField.Equals("buildingClassID", StringComparison.OrdinalIgnoreCase) &&
                                    dict.TryGetValue("buildingClassID", out var alt))
                                    dict["buildingClassID"] = alt;
                                else if (rowIdField.Equals("BuildingClassID", StringComparison.OrdinalIgnoreCase) &&
                                         dict.TryGetValue("BuildingClassID", out var alt2))
                                    dict["BuildingClassID"] = alt2;
                            }

                            // تعبئة p01..p04 لاستخدامها في الفورم
                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("buildingClassID") ?? Get("BuildingClassID");
                            dict["p02"] = Get("buildingClassName_A");
                            dict["p03"] = Get("buildingClassName_E");
                            dict["p04"] = Get("buildingClassDescription");

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
                new FieldConfig { Name = rowIdField, Type = "hidden" },

                new FieldConfig
                {
                    Name = "p01",
                    Label = "اسم الفئة بالعربي",
                    Autocomplete = "off",
                    Type = "text",
                    ColCss = "6",
                    Required = true,
                    TextMode = "arabic",
                    //InputPattern = @"^[\u0621-\u064A\u0640\s]+$",
                    HelpText = "اكتب أحرف عربية فقط",
                    

                },
                new FieldConfig { Name = "p02", Label = "اسم الفئة بالانجليزي", Type = "text", ColCss = "6", Required = false,TextMode="english"},
                new FieldConfig { Name = "p03", Label = "ملاحظات",  Type = "textarea", ColCss = "6", Required = false }
            };

            // hidden fields المشتركة
            addFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            addFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId.ToString() });
            addFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId.ToString() });
            addFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT" });
            addFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });

            // ✏️ UPDATE fields
            var updateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",      Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController",  Type = "hidden", Value = ControllerName},
                new FieldConfig { Name = "pageName_",           Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",          Type = "hidden", Value = "UPDATE" },
                new FieldConfig { Name = "idaraID",             Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",           Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",            Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField,            Type = "hidden" },

                new FieldConfig { Name = "p01", Label = "الرقم المرجعي",        Type = "hidden", Readonly = true, ColCss = "3" },
                new FieldConfig { Name = "p02", Label = "اسم الفئة بالعربي",    Type = "text",   Required = true,  ColCss = "6", TextMode = "arabic"  },
                new FieldConfig { Name = "p03", Label = "اسم الفئة بالانجليزي", Type = "text",   Required = false, ColCss = "6", TextMode="english" },
                new FieldConfig { Name = "p10", Label = "ملاحظات",              Type = "textarea",   Required = false, ColCss = "6" }
            };

            // 🗑️ DELETE fields
            var deleteFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETE" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "buildingClassID" }
            };

            //  SmartTable model
            var dsModel = new SmartFoundation.UI.ViewModels.SmartTable.SmartTableDsModel
            {
                PageTitle = "فئات المباني",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = "فئات المباني ",
               
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
                        Label = "إضافة فئة",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إدخال فئة جديدة",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassInsertForm",
                            Title = "بيانات الفئة الجديدة",
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
                        Label = "تعديل فئة",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        //Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل بيانات فئة",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm", 
                            Title = "تعديل بيانات فئة",
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
                        Label = "حذف فئة",
                        Icon = "fa fa-trash",
                        Color = "danger",
                       // Placement = TableActionPlacement.ActionsMenu, 
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من حذف هذا الفئة؟",
                        ModalMessageClass = "bg-red-50 border border-red-200 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassDeleteForm",
                            Title = "تأكيد حذف الفئة",
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

            return View("HousingDefinitions/BuildingClass", page);

        }
    }
}
