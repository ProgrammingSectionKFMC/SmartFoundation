using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Mvc.Services.DataLoad;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;


namespace SmartFoundation.Mvc.Controllers.ControlPanel
{
   
    public partial class ControlPanelController : Controller
    {
        public async Task<IActionResult> ManagerList([FromServices] RequestScopedDataLoadService requestDataLoad)
        {
            //  تهيئة بيانات الصفحة (السيشن + ControllerName + PageName...)
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = nameof(ControlPanel);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "ManagerList" : PageName;

            var ddlParameters = new Dictionary<string, object?>(
               StringComparer.OrdinalIgnoreCase)
            {
                ["pageName_"] = PageName ?? "FinancialAuditForUser"
            };

            if (IdaraId != null)
                ddlParameters["idaraID"] = Convert.ToInt32(IdaraId);

            if (usersId != null)
                ddlParameters["entrydata"] = Convert.ToInt32(usersId);

            if (HostName != null)
                ddlParameters["hostname"] = HostName;

            // معاملات تحميل بيانات الصفحة.
            // نضيف رقم الهوية فقط عند وجوده.
            var pageParameters = new Dictionary<string, object?>(
                ddlParameters,
                StringComparer.OrdinalIgnoreCase);

           


            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();

            DataSet ds = await requestDataLoad.GetDataLoadDataSetAsync(pageParameters);

            //  تقسيم الداتا سيت للجدول الأول + جداول أخرى
            SplitDataSet(ds);

            //  التحقق من الصلاحيات
            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            string rowIdField = "";
            bool canInsertManagerList = false;
            bool canUpdateManagerList = false;
            bool canDeleteManagerList = false;



            List<OptionItem> ManagerListTypeOptions = new();



            DataSet ddlDs = await requestDataLoad
               .GetDataLoadDataSetAsync(ddlParameters);

            static List<OptionItem> ReadOptions(
                DataSet source,
                int tableIndex,
                string textColumn,
                string valueColumn)
            {
                if (tableIndex < 0 ||
                    tableIndex >= source.Tables.Count)
                {
                    throw new InvalidOperationException(
                        $"DDL table index {tableIndex} not found.");
                }

                DataTable table = source.Tables[tableIndex];

                if (!table.Columns.Contains(textColumn) ||
                    !table.Columns.Contains(valueColumn))
                {
                    throw new InvalidOperationException(
                        $"DDL columns mismatch at table {tableIndex}.");
                }

                var options = new List<OptionItem>();

                foreach (DataRow row in table.Rows)
                {
                    string value = row[valueColumn]
                        ?.ToString()?.Trim() ?? "";

                    string text = row[textColumn]
                        ?.ToString()?.Trim() ?? "";

                    if (!string.IsNullOrEmpty(value))
                    {
                        options.Add(new OptionItem
                        {
                            Value = value,
                            Text = text
                        });
                    }
                }

                if (options.Count == 0)
                {
                    options.Add(new OptionItem
                    {
                        Value = "-1",
                        Text = "لاتوجد خيارات"
                    });
                }

                return options;
            }

            ManagerListTypeOptions = ReadOptions(
                ddlDs,
                2,
                "ManagerListTypeName_A",
                "ManagerListTypeID");



            // END DDL

            try
            {

               
                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // 🔐 قراءة الصلاحيات من الجدول الأول
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "INSERTMANAGERLIST") canInsertManagerList = true;
                        if (permissionName == "UPDATEMANAGERLIST") canUpdateManagerList = true;
                        if (permissionName == "DELETEMANAGERLIST") canDeleteManagerList = true;
                    }



                    if (dt1 != null && dt1.Rows.Count > 0)
                    {
                        // 🔑 تحديد حقل الـ Id
                        rowIdField = "ManagerListID";
                        var possibleIdNames = new[] { "ManagerListID", "managerListID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // 🏷️ عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["ManagerListID"] = "الرقم المرجعي",
                            ["ManagerListTypeName_A"] = "النوع",
                            ["ManagerListName"] = "الاسم",
                            ["ManagerListRank"] = "الرتبة",
                            ["ManagerListPosition"] = "المنصب",
                            ["ManagerListStartDate"] = "تاريخ البداية",
                            ["ManagerListDescription"] = "ملاحظات"
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
                            bool isManagerListTypeID_FK = c.ColumnName.Equals("ManagerListTypeID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isManagerListEndDate = c.ColumnName.Equals("ManagerListEndDate", StringComparison.OrdinalIgnoreCase);
                            bool isManagerListActive = c.ColumnName.Equals("ManagerListActive", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraID_FK = c.ColumnName.Equals("IdaraID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isentryData = c.ColumnName.Equals("entryData", StringComparison.OrdinalIgnoreCase);
                            bool ishostName = c.ColumnName.Equals("hostName", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,
                                Visible = !(isManagerListTypeID_FK || isManagerListEndDate || isManagerListActive || isIdaraID_FK || isentryData || ishostName)
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
                                if (rowIdField.Equals("ManagerListID", StringComparison.OrdinalIgnoreCase) &&
                                    dict.TryGetValue("ManagerListID", out var alt))
                                    dict["ManagerListID"] = alt;
                                else if (rowIdField.Equals("ManagerListID", StringComparison.OrdinalIgnoreCase) &&
                                         dict.TryGetValue("ManagerListID", out var alt2))
                                    dict["ManagerListID"] = alt2;
                            }


                         
                            // تعبئة p01..p04 لاستخدامها في الفورم
                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("ManagerListID") ?? Get("managerListID");
                            dict["p02"] = Get("ManagerListTypeID_FK");
                            dict["p03"] = Get("ManagerListName");
                            dict["p04"] = Get("ManagerListRank");
                            dict["p05"] = Get("ManagerListPosition");
                            dict["p06"] = Get("ManagerListStartDate");
                            dict["p07"] = Get("ManagerListEndDate");
                            dict["p08"] = Get("ManagerListDescription");
                            dict["p09"] = Get("ManagerListActive");
                            dict["p10"] = Get("IdaraID_FK");
                            dict["p11"] = Get("entryDate");
                            dict["p12"] = Get("entryData");
                            dict["p13"] = Get("hostName");

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


                new FieldConfig{Name = "p02",Label = "النوع",Type = "select",ColCss = "6",Required = true,Options = ManagerListTypeOptions},
                new FieldConfig { Name = "p04", Label = "الرتبة", Type = "text", ColCss = "6", Required = true,TextMode="arabic"},
                new FieldConfig { Name = "p03", Label = "الاسم", Type = "text", ColCss = "6", Required = true,TextMode="arabic"},
                new FieldConfig { Name = "p05", Label = "المنصب", Type = "text", ColCss = "6", Required = true,TextMode="arabic"},
                new FieldConfig { Name = "p08", Label = "ملاحظات",  Type = "textarea", ColCss = "6", Required = true }

            };

            // hidden fields المشتركة
            addFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden" });
            addFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERTMANAGERLIST" });
            addFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });

            // ✏️ UPDATE fields
            var updateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",      Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController",  Type = "hidden", Value = ControllerName},
                new FieldConfig { Name = "pageName_",           Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",          Type = "hidden", Value = "UPDATEMANAGERLIST" },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden" },
              


                new FieldConfig { Name = "p01",Label = "ManagerListID",Type = "hidden",ColCss = "6",Required = true},
                new FieldConfig { Name = "p02",Label = "النوع",Type = "select",ColCss = "6",Required = true,Readonly=true,Options = ManagerListTypeOptions},
                new FieldConfig { Name = "p04", Label = "الرتبة", Type = "text", ColCss = "6", Required = true,TextMode="arabic"},
                new FieldConfig { Name = "p03", Label = "الاسم", Type = "text", ColCss = "6", Required = true,TextMode="arabic"},
                new FieldConfig { Name = "p05", Label = "المنصب", Type = "text", ColCss = "6", Required = true,TextMode="arabic"},
                new FieldConfig { Name = "p08", Label = "ملاحظات",  Type = "textarea", ColCss = "6", Required = true }


            };


            //  SmartTable model
            var dsModel = new SmartFoundation.UI.ViewModels.SmartTable.SmartTableDsModel
            {
                PageTitle = "بيانات المدراء",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = "بيانات المدراء ",
               
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = canInsertManagerList,
                    ShowEdit = canUpdateManagerList,
                    ShowDelete = canDeleteManagerList,
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
                        Label = "إضافة بيانات جديدة",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إدخال بيانات جديدة",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassInsertForm",
                            Title = "بيانات جديدة",
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
                        Label = "تعديل بيانات",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        //Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل بيانات ",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm", 
                            Title = "تعديل بيانات ",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = updateFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    }
                   
                }
            };


            var page = new SmartFoundation.UI.ViewModels.SmartPage.SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-sitemap",
                TableDS = dsModel
            };

            return View("ManagerList/ManagerList", page);

        }
    }
}
