using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;


namespace SmartFoundation.Mvc.Controllers.Housing
{

    public partial class HousingController : Controller
    {
        public async Task<IActionResult> OtherWaitingListManagment()
        {
            //  تهيئة بيانات الصفحة (السيشن + ControllerName + PageName...)
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = nameof(Housing);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "OtherWaitingListManagment" : PageName;

            var spParameters = new object?[]
            {
             PageName ?? "OtherWaitingListManagment",
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
            bool canInsertOtherWaitingList = false;
            bool canUpdateOtherWaitingList = false;
            bool canDeleteOtherWaitingList = false;

            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // 🔐 قراءة الصلاحيات من الجدول الأول
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "INSERTOTHERWAITINGLIST") canInsertOtherWaitingList = true;
                        if (permissionName == "UPDATEOTHERWAITINGLIST") canUpdateOtherWaitingList = true;
                        if (permissionName == "DELETEOTHERWAITINGLIST") canDeleteOtherWaitingList = true;
                    }

                    if (dt1 != null && dt1.Rows.Count > 0)
                    {
                        // 🔑 تحديد حقل الـ Id
                        rowIdField = "waitingClassID";
                        var possibleIdNames = new[] { "waitingClassID", "WaitingClassID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // 🏷️ عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["waitingClassID"] = "الرقم المرجعي",
                            ["waitingClassName_A"] = "فئة سجل الانتظار بالعربي",
                            ["waitingClassName_E"] = "فئة سجل الانتظار بالانجليزي",
                            ["waitingClassDescription"] = "ملاحظات"
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
                            bool isidara_FK = c.ColumnName.Equals("idara_FK", StringComparison.OrdinalIgnoreCase);
                            bool iswaitingClassRoot = c.ColumnName.Equals("waitingClassRoot", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,
                                Visible = !(isidara_FK || iswaitingClassRoot)
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
                                if (rowIdField.Equals("waitingClassID", StringComparison.OrdinalIgnoreCase) &&
                                    dict.TryGetValue("waitingClassID", out var alt))
                                    dict["waitingClassID"] = alt;
                                else if (rowIdField.Equals("WaitingClassID", StringComparison.OrdinalIgnoreCase) &&
                                         dict.TryGetValue("WaitingClassID", out var alt2))
                                    dict["WaitingClassID"] = alt2;
                            }

                            // تعبئة p01..p04 لاستخدامها في الفورم
                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("waitingClassID") ?? Get("WaitingClassID");
                            dict["p02"] = Get("waitingClassName_A");
                            dict["p03"] = Get("waitingClassName_E");
                            dict["p04"] = Get("waitingClassRoot");
                            dict["p05"] = Get("idara_FK");
                            dict["p06"] = Get("waitingClassDescription");

                            rowsList.Add(dict);
                        }
                    }
                }
            }
            catch (Exception)
            {
                ViewBag.buildingClassDataSetError = "حدث خطأ أثناء تحميل البيانات. يرجى المحاولة مرة أخرى.";
            }

            //  ADD fields
            var addFields = new List<FieldConfig>
            {
                new FieldConfig { Name = rowIdField, Type = "hidden" },

                new FieldConfig
                {
                    Name = "p01",
                    Label = "اسم سجل الانتظار الجانبي بالعربي",
                    Autocomplete = "off",
                    Type = "text",
                    ColCss = "6",
                    Required = true,
                    TextMode = "arabic",
                    //InputPattern = @"^[\u0621-\u064A\u0640\s]+$",
                    HelpText = "اكتب أحرف عربية فقط",


                },
                new FieldConfig { Name = "p02", Label = "اسم سجل الانتظار الجانبي بالانجليزي", Type = "text", ColCss = "6", Required = false,TextMode="english"},
                new FieldConfig { Name = "p10", Label = "ملاحظات", Type = "textarea",   Required = false, ColCss = "6" }
        };

            // hidden fields المشتركة
            addFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden" });
            addFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERTOTHERWAITINGLIST" });
            addFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });

            // ✏️ UPDATE fields
            var updateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",      Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController",  Type = "hidden", Value = ControllerName},
                new FieldConfig { Name = "pageName_",           Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",          Type = "hidden", Value = "UPDATEOTHERWAITINGLIST" },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden" },
                new FieldConfig { Name = rowIdField,            Type = "hidden" },

                new FieldConfig { Name = "p01", Label = "الرقم المرجعي",        Type = "hidden", Readonly = true, ColCss = "3" },
                new FieldConfig { Name = "p02", Label = "اسم سجل الانتظار الجانبي بالعربي",    Type = "text",   Required = true,  ColCss = "6", TextMode = "arabic"  },
                new FieldConfig { Name = "p03", Label = "اسم سجل الانتظار الجانبي بالانجليزي", Type = "text",   Required = false, ColCss = "6", TextMode="english" },
                new FieldConfig { Name = "p10", Label = "سبب التعديل", Type = "textarea",   Required = true, ColCss = "6" }};

            // 🗑️ DELETE fields
            var deleteFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETEOTHERWAITINGLIST" },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden" },
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "waitingClassID" },
                new FieldConfig { Name = "p02", Label = "اسم سجل الانتظار الجانبي بالعربي",    Type = "text",   Required = false,Readonly=true,  ColCss = "6", TextMode = "arabic"  },
                new FieldConfig { Name = "p03", Label = "اسم سجل الانتظار الجانبي بالانجليزي", Type = "text",   Required = false,Readonly=true, ColCss = "6", TextMode="english" },
                new FieldConfig { Name = "p10", Label = "سبب الحذف", Type = "textarea",   Required = true, ColCss = "6" }
        };

            //  SmartTable model
            var dsModel = new SmartFoundation.UI.ViewModels.SmartTable.SmartTableDsModel
            {
                PageTitle = "ادارة سجلات الانتظار الجانبية",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = "ادارة سجلات الانتظار الجانبية ",

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = canInsertOtherWaitingList,
                    ShowEdit = canUpdateOtherWaitingList,
                    ShowDelete = canDeleteOtherWaitingList,
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
                        Label = "إضافة سجل انتظار جانبي",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة سجل انتظار جانبي",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassInsertForm",
                            Title = "بيانات سجل الانتظار الجانبي",
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
                        Label = "تعديل سجل انتظار جانبي",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        //Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل بيانات سجل انتظار جانبي",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "تعديل بيانات سجل انتظار جانبي",
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
                        Label = "حذف سجل انتظار جانبي",
                        Icon = "fa fa-trash",
                        Color = "danger",
                       // Placement = TableActionPlacement.ActionsMenu,
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من حذف هذا السجل ؟",
                        ModalMessageClass = "bg-red-50 border border-red-200 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassDeleteForm",
                            Title = "تأكيد حذف السجل",
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

            return View("WaitingList/OtherWaitingListManagment", page);

        }
    }
}
