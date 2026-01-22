using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Security;


namespace SmartFoundation.Mvc.Controllers.Housing
{
    public partial class HousingController : Controller
    {
        public async Task<IActionResult> BuildingUtilityType()
        {
            //  قراءة السيشن والكونتكست
            if (!InitPageContext(out var redirect))
                return redirect!;
            ControllerName = nameof(Housing);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "BuildingUtilityType" : PageName;

            var spParameters = new object?[]
            {
             PageName ?? "BuildingUtilityType",
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

            // ---------------------- ISRent DDLValues ----------------------
            List<OptionItem> IsRentOptions = new()
                {
                    new OptionItem { Value = "1", Text = "نعم" },
                    new OptionItem { Value = "0", Text = "لا" }
                };
            // ---------------------- ISRent DDLValues ----------------------



            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // صلاحيات
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "INSERT") canInsert = true;
                        if (permissionName == "UPDATE") canUpdate = true;
                        if (permissionName == "DELETE") canDelete = true;
                    }

                    if (dt1 != null && dt1.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField = "buildingUtilityTypeID";
                        var possibleIdNames = new[] { "buildingUtilityTypeID", "BuildingUtilityTypeID", "Id", "ID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["buildingUtilityTypeID"] = "الرقم المرجعي",
                            ["buildingUtilityTypeName_A"] = "نوع المرفق بالعربي",
                            ["buildingUtilityTypeName_E"] = "نوع المرفق بالانجليزي",
                            ["buildingUtilityTypeDescription"] = "ملاحظات",
                            ["buildingUtilityTypeActive"] = "نشط",
                            ["buildingUtilityTypeStartDate"] = "بداية المرفق",
                            ["buildingUtilityTypeEndDate"] = "نهاية المرفق",
                            ["buildingUtilityIsRent"] = "يتطلب ايجار"
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

                            bool isbuildingUtilityTypeActive =
                                c.ColumnName.Equals("buildingUtilityTypeActive", StringComparison.OrdinalIgnoreCase);

                            // نخفي العمود الـ Active مثل ما كنت تسوي
                            if (isbuildingUtilityTypeActive)
                            {
                                dynamicColumns.Add(new TableColumn
                                {
                                    Field = c.ColumnName,
                                    Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                    Type = colType,
                                    Sortable = true,
                                    Visible = false
                                });
                            }
                            // هنا نخصص عمود يتطلب ايجار ليعرض النص الجديد
                            else if (c.ColumnName.Equals("buildingUtilityIsRent", StringComparison.OrdinalIgnoreCase))
                            {
                                dynamicColumns.Add(new TableColumn
                                {
                                    Field = "buildingUtilityIsRentText", // ✅ حقل العرض
                                    Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : "يتطلب ايجار",
                                    Type = "text",
                                    Sortable = true
                                });
                            }
                            else
                            {
                                dynamicColumns.Add(new TableColumn
                                {
                                    Field = c.ColumnName,
                                    Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                    Type = colType,
                                    Sortable = true,
                                    Visible = true
                                });
                            }
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

                            var isRentRaw = Get("buildingUtilityIsRent")?.ToString();

                            // نخزن القيمة الأصلية عشان الفورم (الـ select)
                            dict["buildingUtilityIsRent"] = isRentRaw;

                            // نخزن قيمة نصية جديدة للعرض في الجدول
                            dict["buildingUtilityIsRentText"] = isRentRaw == "1"
                                ? "نعم"
                                : isRentRaw == "0"
                                    ? "لا"
                                    : "";

                            dict["p01"] = Get("buildingUtilityTypeID") ?? Get("BuildingUtilityTypeID");
                            dict["p02"] = Get("buildingUtilityTypeName_A");
                            dict["p03"] = Get("buildingUtilityTypeName_E");
                            dict["p04"] = Get("buildingUtilityTypeDescription");
                            dict["p05"] = Get("buildingUtilityTypeActive");
                            dict["p06"] = Get("buildingUtilityTypeStartDate");
                            dict["p07"] = Get("buildingUtilityTypeEndDate");
                            dict["p08"] = isRentRaw;

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
            var addFields = new List<FieldConfig>
            {
                new FieldConfig { Name = rowIdField, Type = "hidden" },

                new FieldConfig { Name = "p01", Label = "نوع المرفق بالعربي", Type = "text", ColCss = "6",Placeholder = "حقل عربي فقط",Icon = "fa fa-home", Required = true,MaxLength = 50,TextMode = "arabic" },
                new FieldConfig { Name = "p02", Label = "اسم نوع المرفق بالانجليزي", Type = "text", Required = true,Placeholder = "حقل انجليزي فقط",Icon = "fa fa-home",ColCss = "6",MaxLength = 50,TextMode = "english",},
                new FieldConfig { Name = "p04", Label = "بداية المرفق", Type = "date", ColCss = "3", Required = true, Icon = "fa fa-calendar", HelpText = "يجب اختيار التاريخ" },
                new FieldConfig { Name = "p05", Label = "نهاية المرفق", Type = "date", ColCss = "3", Required = false,Icon = "fa fa-calendar" },
                new FieldConfig { Name = "p06", Label = "يتطلب ايجار", Type = "select",Options=IsRentOptions, ColCss = "3", Required = true },
                 new FieldConfig { Name = "p03", Label = "ملاحظات", Type = "textarea", ColCss = "6" },
                 new FieldConfig { Name = "p03", Label = "ملاحظات", Type = "textarea", ColCss = "3" },
            };

            // hidden fields
            addFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            addFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId.ToString() });
            addFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId.ToString() });
            addFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT" });
            addFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });

            // UPDATE fields
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

             

                new FieldConfig { Name = "p01", Label = "الرقم المرجعي",Type = "hidden", Readonly = true, ColCss = "3" },
                new FieldConfig { Name = "p02", Label = "نوع المرفق بالعربي",Type = "text", Required = true, TextMode = "arabic", ColCss = "6" },
                new FieldConfig { Name = "p03", Label = "نوع المرفق بالانجليزي", Type ="text",ColCss = "6", Required = true, TextMode = "english" },
                new FieldConfig { Name = "p06", Label = "بداية المرفق", Type = "date", Required = true, ColCss = "3" },
                new FieldConfig { Name = "p07", Label = "نهاية المرفق", Type = "date", Required = false, ColCss = "3" },
                new FieldConfig { Name = "p08", Label = "يتطلب ايجار", Type = "select",Options=IsRentOptions, Required = true, ColCss = "3" },
                new FieldConfig { Name = "p04", Label = "ملاحظات", Type = "textarea",   ColCss = "6" },
                new FieldConfig { Name = "p05", Label = "buildingUtilityTypeActive",Type = "hidden",ColCss = "6" },



            };

            // DELETE fields
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
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "buildingUtilityTypeID" }
            };

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "أنواع المرافق",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> {10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = "أنواع المرافق ",
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
                        Label = "إضافة نوع مرفق جديد",
                        Icon = "fa fa-plus",
                        Color = "success",
                        
                        OpenModal = true,
                        ModalTitle = "إدخال بيانات نوع المرفق الجديد",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingUtilityInsertForm",
                            Title = "بيانات نوع المرفق الجديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },

                    Edit = new TableAction
                    {
                        Label = "تعديل نوع المرفق",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل بيانات نوع المرفق",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "تعديل بيانات نوع مرفق",
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
                        Label = "حذف نوع مباني",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        Placement = TableActionPlacement.ActionsMenu,
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من حذف هذا نوع المباني؟",
                        ModalMessageClass = "bg-red-50 border border-red-200 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeDeleteForm",
                            Title = "تأكيد حذف نوع المباني",
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

            //return View("HousingDefinitions/BuildingType", dsModel);
            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-layer-group",
                TableDS = dsModel
            };

            return View("HousingDefinitions/BuildingUtilityType", page);
        }
    }
}
