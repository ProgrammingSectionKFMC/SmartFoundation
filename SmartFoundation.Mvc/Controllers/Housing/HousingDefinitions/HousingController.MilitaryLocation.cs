using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Security;
using System.Text.Json;


namespace SmartFoundation.Mvc.Controllers.Housing
{
    public partial class HousingController : Controller
    {
        public async Task<IActionResult> MilitaryLocation()
        {
            //  تهيئة بيانات الصفحة (السيشن + ControllerName + PageName...)
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = nameof(Housing);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "MilitaryLocation" : PageName;

            var spParameters = new object?[]
            {
             PageName ?? "MilitaryLocation",
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

            // ---------------------- DDLValues ----------------------

            List<OptionItem> CityOptions = new();


            JsonResult? result;
            string json;
            // ---------------------- City ddl ----------------------


            result = await _CrudController.GetDDLValues(
                   "militaryAreaCityName_A", "militaryAreaCityID", "2", nameof(MilitaryLocation), usersId, IdaraId, HostName
               ) as JsonResult;


            json = JsonSerializer.Serialize(result!.Value);

            CityOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;

            // ---------------------- END City ddl ----------------------



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
                        rowIdField = "militaryLocationID";
                        var possibleIdNames = new[] { "militaryLocationID", "militaryLocationID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // 🏷️ عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["militaryLocationID"] = "الرقم المرجعي",
                            ["militaryLocationCode"] = "رمز الموقع",
                            ["militaryLocationName_A"] = "اسم الموقع بالعربي",
                            ["militaryLocationName_E"] = "اسم الموقع بالانجليزي",
                            ["militaryLocationCoordinates"] = "احداثيات الموقع ",
                            ["militaryLocationDescription"] = "وصف الموقع",
                            ["militaryAreaCityName_A"] = "المدينة"
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
                            bool ismilitaryLocationActive = c.ColumnName.Equals("militaryLocationActive", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraId_FK = c.ColumnName.Equals("IdaraId_FK", StringComparison.OrdinalIgnoreCase);
                            bool ismilitaryAreaCityID_FK = c.ColumnName.Equals("militaryAreaCityID_FK", StringComparison.OrdinalIgnoreCase);
                            

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,
                                Visible = !(ismilitaryLocationActive || isIdaraId_FK || ismilitaryAreaCityID_FK)
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
                                if (rowIdField.Equals("militaryLocationID", StringComparison.OrdinalIgnoreCase) &&
                                    dict.TryGetValue("militaryLocationID", out var alt))
                                    dict["militaryLocationID"] = alt;
                                else if (rowIdField.Equals("militaryLocationID", StringComparison.OrdinalIgnoreCase) &&
                                         dict.TryGetValue("militaryLocationID", out var alt2))
                                    dict["militaryLocationID"] = alt2;
                            }

                            // تعبئة p01..p04 لاستخدامها في الفورم
                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("militaryLocationID") ?? Get("MilitaryLocationID");
                            dict["p02"] = Get("militaryLocationCode");
                            dict["p03"] = Get("militaryAreaCityID_FK");
                            dict["p04"] = Get("militaryAreaCityName_A");
                            dict["p05"] = Get("militaryLocationName_A");
                            dict["p06"] = Get("militaryLocationName_E");
                            dict["p07"] = Get("militaryLocationCoordinates");
                            dict["p08"] = Get("militaryLocationDescription");

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
                new FieldConfig { Name = "p01", Label = "رمز الموقع", Type = "text", ColCss = "6", Required = false},
                new FieldConfig { Name = "p02", Label = "المدينة", Type = "select",Options =CityOptions, ColCss = "6", Required = true,Select2 = true},
                new FieldConfig {  Name = "p04", Label = "اسم الموقع بالعربي", Autocomplete = "off", Type = "text",  ColCss = "6",  Required = true, TextMode = "arabic", HelpText = "اكتب أحرف عربية فقط" },
                new FieldConfig { Name = "p05", Label = "اسم الموقع بالانجليزي", Type = "text", ColCss = "6", Required = false,TextMode="english"},
                new FieldConfig { Name = "p06", Label = "احداثيات الموقع", Type = "text", ColCss = "6", Required = false},
                new FieldConfig { Name = "p07", Label = "وصف الموقع ", Type = "textarea", ColCss = "6", Required = false},
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
                new FieldConfig { Name = "p02", Label = "رمز الموقع",    Type = "text",  ColCss = "6" },
                new FieldConfig { Name = "p03", Label = "المدينة", Type = "select",Options =CityOptions, ColCss = "6", Required = true,Select2 = true},
                new FieldConfig { Name = "p05", Label = "اسم الموقع بالعربي", Type = "text",   Required = true, ColCss = "6", TextMode="arabic",HelpText = "اكتب أحرف عربية فقط",},
                new FieldConfig { Name = "p06", Label = "اسم الموقع بالانجليزي", Type = "text",   Required = false, ColCss = "6", TextMode="english",HelpText = "اكتب أحرف انجليزية فقط",},
                new FieldConfig { Name = "p07", Label = "احداثيات الموقع", Type = "text",   Required = false, ColCss = "6" },
                new FieldConfig { Name = "p08", Label = "وصف الموقع", Type = "textarea",   Required = false, ColCss = "6" }
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
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "militaryLocationID" }
            };

            //  SmartTable model
            var dsModel = new SmartFoundation.UI.ViewModels.SmartTable.SmartTableDsModel
            {
                PageTitle = "المواقع",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = "المواقع ",
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = true,
                    ShowAdd = canInsert,
                    ShowEdit = canUpdate,
                    ShowDelete = canDelete,
                    ShowBulkDelete = false,

                    Add = new TableAction
                    {
                        Label = "إضافة موقع جديد",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إدخال موقع جديد",
                        OpenForm = new FormConfig
                        {
                            FormId = "militaryLocationInsertForm",
                            Title = "بيانات الموقع الجديد",
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
                        Label = "تعديل موقع",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                       // Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل بيانات موقع",
                        OpenForm = new FormConfig
                        {
                            FormId = "militaryLocationEditForm", // أبقيته كما هو عندك
                            Title = "تعديل بيانات موقع",
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
                        Label = "حذف موقع",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        //Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من حذف هذا الموقع؟",
                        ModalMessageClass = "bg-red-50 border border-red-200 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassDeleteForm",
                            Title = "تأكيد حذف موقع",
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

            

            var page = new SmartFoundation.UI.ViewModels.SmartPage.SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-sitemap",
                TableDS = dsModel
            };

            return View("HousingDefinitions/militaryLocation", page);

        }
    }
}
