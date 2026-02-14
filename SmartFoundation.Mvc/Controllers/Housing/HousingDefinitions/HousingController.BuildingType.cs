using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using SmartFoundation.MVC.Reports;



namespace SmartFoundation.Mvc.Controllers.Housing
{
    public partial class HousingController : Controller
    {

        
        public async Task<IActionResult> BuildingType(int pdf = 0)
        {
            //  قراءة السيشن والكونتكست
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = nameof(Housing);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "BuildingType" : PageName;

            var spParameters = new object?[]
            {
             PageName ?? "BuildingType",
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
                        rowIdField = "BuildingTypeID";
                        var possibleIdNames = new[] { "buildingTypeID", "BuildingTypeID", "Id", "ID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["buildingTypeID"] = "الرقم المرجعي",
                            ["buildingTypeCode"] = "رمز نوع المباني",
                            ["buildingTypeName_A"] = "اسم نوع المباني بالعربي",
                            ["buildingTypeName_E"] = "اسم نوع المباني بالانجليزي",
                            ["buildingTypeDescription"] = "ملاحظات"
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

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
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
                            dict["p01"] = Get("buildingTypeID") ?? Get("BuildingTypeID");
                            dict["p02"] = Get("buildingTypeCode");
                            dict["p03"] = Get("buildingTypeName_A");
                            dict["p04"] = Get("buildingTypeName_E");
                            dict["p05"] = Get("buildingTypeDescription");

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

                new FieldConfig { Name = "p01", Label = "رمز نوع المباني", Type ="text", ColCss ="3",Icon = "fa fa-building" },
                new FieldConfig { Name = "p02", Label = "اسم نوع المباني بالعربي", Type = "text", Required = true,Placeholder = "حقل عربي فقط",Icon = "fa fa-home",ColCss = "3",MaxLength = 50,TextMode = "arabic",},
                new FieldConfig { Name = "p03", Label = "اسم نوع المباني بالانجليزي", Type = "text", ColCss = "3" ,Icon = "fa fa-home", TextMode = "english",Placeholder = "حقل انجليزي فقط"},
                new FieldConfig { Name = "p04", Label = "ملاحظات", Type = "textarea", ColCss = "6", Required = false }
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

                new FieldConfig { Name = "p01", Label = "الرقم المرجعي",Type ="hidden", Readonly = true, ColCss = "3" },
                new FieldConfig { Name = "p02", Label = "رمز نوع المباني",Type ="text", Required = true,  ColCss = "3",Icon = "fa fa-building" },
                new FieldConfig { Name = "p03", Label = "اسم نوع المباني بالعربي", Type ="text",ColCss = "3", Required = true, TextMode = "arabic",Icon = "fa fa-home" },
                new FieldConfig { Name = "p04", Label = "اسم نوع المباني بالانجليزي", Type ="text", ColCss = "3",TextMode = "english",Icon = "fa fa-home" },
                new FieldConfig { Name = "p10", Label = "ملاحظات",Type ="textarea",ColCss = "6" }
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
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "BuildingTypeID" }
            };

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "انواع المباني",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = "أنواع المباني",
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = canInsert,
                    ShowEdit = canUpdate,
                    ShowDelete = canDelete,
                    ShowPrint = false, // شرطك
                    ShowPrint1 = false, // شرطك
                    ShowBulkDelete = false,

                    Add = new TableAction
                    {
                        Label = "إضافة نوع مباني جديد",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إدخال بيانات نوع المباني الجديد",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeInsertForm",
                            Title = "بيانات نوع المباني الجديد",
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
                        Label = "تعديل نوع المباني",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                       // Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل بيانات نوع مباني",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "تعديل بيانات نوع مباني",
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
                       // Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من حذف هذا نوع المباني؟",
                        ModalMessageClass = "bg-red-50 text-red-700",
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

                    Print = new TableAction
                    {
                        Label = "طباعة أنواع المباني",
                        Icon = "fa fa-print",
                        Color = "primary",
                        Placement = TableActionPlacement.ActionsMenu,
                        RequireSelection = false,
                        OnClickJs = @"
                                sfPrintWithBusy(table, {
                                  pdf: 1,
                                  busy: { title: 'طباعة أنواع المباني'}
                                });
                                "

                    },

                    Print1 = new TableAction
                    {
                        Label = "طباعة خطاب تجريبي",
                        Icon = "fa fa-print",
                        Color = "primary",
                        Placement = TableActionPlacement.ActionsMenu,
                        RequireSelection = false,
                        OnClickJs = @"
                                sfPrintWithBusy(table, {
                                  pdf: 2,
                                  busy: { title: 'طباعة خطاب تجريبي'}
                                });
                                "

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



            // ===== PDF Export (same request, no extra DB call) =====
            if (pdf == 1)
            {
                var printTable = dt1;

                if (printTable == null || printTable.Rows.Count == 0)
                    return Content("لا توجد بيانات للطباعة.");


                var reportColumns = new List<ReportColumn>
{
    new("buildingTypeCode",   "رمز نوع المباني",       Align:"center", Weight:1, FontSize:9),
    new("buildingTypeName_A", "اسم نوع المباني بالعربي",Align:"center", Weight:2, FontSize:10),
    new("buildingTypeName_E", "اسم نوع المباني بالإنجليزي",Align:"center", Weight:2, FontSize:9),
    //new ReportColumn("buildingTypeDescription", "ملاحظات",Align: "right",  Weight: 4, FontSize:9),
};

              

                var logo = Path.Combine(_env.WebRootPath, "img", "ppng.png");

                var header = new Dictionary<string, string>
                {
                    ["no"] = "١٢٣/٤٥",
                    ["date"] = DateTime.Now.ToString("yyyy/MM/dd"),
                    ["attach"] = "—",
                    ["subject"] = "تقرير أنواع المباني",

                    ["right1"] = "المملكة العربية السعودية",
                    ["right2"] = "وزارة الدفاع",
                    ["right3"] = "القوات البرية الملكية السعودية",
                    ["right4"] = "الادارة الهندسية للتشغيل والصيانة",
                    ["right5"] = "إدارة مدينة الملك فيصل العسكرية",

                    ["bismillah"] = "بسم الله الرحمن الرحيم",
                    ["midCaption"] = ""
                };

                var report = DataTableReportBuilder.FromDataTable(
                    reportId: "BuildingType",
                    title: "تقرير أنواع المباني",
                    table: printTable,
                    columns: reportColumns,
                    headerFields: header,
                    //footerFields: new(),
                   footerFields: new(),
                    
                    orientation: ReportOrientation.Landscape,
                    headerType: ReportHeaderType.LetterOfficial,
                    logoPath: logo
                );
                


                

                var pdfBytes = QuestPdfReportRenderer.Render(report);
                Response.Headers["Content-Disposition"] = "inline; filename=BuildingType.pdf";
                return File(pdfBytes, "application/pdf");


            }


            if (pdf == 2)
            {
                var logo = Path.Combine(_env.WebRootPath, "img", "ppng.png");

                var header = new Dictionary<string, string>
                {
                    ["no"] = "١٢٣/٤٥",
                    ["date"] = DateTime.Now.ToString("yyyy/MM/dd"),
                    ["attach"] = "—",
                    ["subject"] = "خطاب رسمي",

                    ["right1"] = "المملكة العربية السعودية",
                    ["right2"] = "وزارة الدفاع",
                    ["right3"] = "القوات البرية الملكية السعودية",
                    ["right4"] = "الادارة الهندسية للتشغيل والصيانة",
                    ["right5"] = "إدارة مدينة الملك فيصل العسكرية",

                    ["bismillah"] = "بسم الله الرحمن الرحيم",
                    ["midCaption"] = ""
                };

                var report = new ReportResult
                {
                    ReportId = "OfficialLetter01",
                    Title = "خطاب رسمي",
                    Kind = ReportKind.Letter,

                    // هنا اختَر الاتجاه اللي تبيه للخطاب
                    Orientation = ReportOrientation.Portrait, // أو Landscape

                    HeaderType = ReportHeaderType.LetterOfficial,
                    LogoPath = logo,
                    ShowFooter = false,

                    HeaderFields = header,

                    LetterBlocks = new List<LetterBlock>
        {
            new LetterBlock
            {
                Text = "سعادة قائد إدارة مدينة الملك فيصل العسكرية حفظه الله",
                FontSize = 13,
                Bold = true,
                PaddingBottom = 12,
                PaddingTop = 30,
                Align = TextAlign.Center
            },

            new LetterBlock
            {
                Text = "السلام عليكم ورحمة الله وبركاته،",
                FontSize = 12,
                PaddingBottom = 10,
                PaddingTop = 15,
                Align = TextAlign.Right
            },

            new LetterBlock
            {
                Text = "نفيد سعادتكم بأنه بناءً على توجيهاتكم الكريمة ...",
                FontSize = 12,
                Align = TextAlign.Justify,
                LineHeight = 1.8f,
                PaddingBottom = 16
            },

            new LetterBlock
            {
                Text = "وتفضلوا بقبول فائق الاحترام والتقدير،",
                FontSize = 12,
                PaddingTop = 20,
                Align = TextAlign.Right
            },

            new LetterBlock
            {
                Text = "مدير الإدارة الهندسية\nالاسم / ..................\nالتوقيع / ...............",
                FontSize = 11,
                Align = TextAlign.Left,
                PaddingTop = 30,
                PaddingLeft = 120
            }
        }
                };

                var pdfBytes = QuestPdfReportRenderer.Render(report);
                Response.Headers["Content-Disposition"] = "inline; filename=Letter.pdf";
                return File(pdfBytes, "application/pdf");
            }




            return View("HousingDefinitions/BuildingType", page);

        }

        public IActionResult Print()
        {
            if (TempData["PdfBytes"] == null)
                return Content("لا يوجد ملف للطباعة");

            ViewBag.PdfBase64 = TempData["PdfBytes"];
            return View();
        }

    }
}
