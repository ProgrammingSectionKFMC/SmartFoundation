using Microsoft.AspNetCore.Mvc;
using SmartFoundation.MVC.Reports;
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
        public async Task<IActionResult> OtherWaitingList(int pdf = 0)
        {


            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }

            string? waitingClassID_ = Request.Query["U"].FirstOrDefault();

            waitingClassID_ = string.IsNullOrWhiteSpace(waitingClassID_) ? null : waitingClassID_.Trim();

            bool ready = false;

            ready = !string.IsNullOrWhiteSpace(waitingClassID_);




            // Sessions 

            ControllerName = nameof(Housing);
            PageName = nameof(OtherWaitingList);

            var spParameters = new object?[] { "OtherWaitingList", IdaraId, usersId, HostName, waitingClassID_ };

            DataSet ds;


            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();


            ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);



           
                SplitDataSet(ds);

            bool printdthasvalue = dt1 != null && dt1.Rows.Count > 0;


            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }





            string rowIdField = "";
            bool canMOVETOOCCUPENTPROCEDURES = false;




            List<OptionItem> WaitingListOptions = new();
            List<OptionItem> buildingDetailsNoOptions = new();




            FormConfig form = new();


            try
            {

                // ---------------------- DDLValues ----------------------




                JsonResult? result;
                string json;




                //// ---------------------- BuildingUtilityType ----------------------
                result = await _CrudController.GetDDLValues(
                    "waitingClassName_A", "waitingClassID", "2", nameof(OtherWaitingList), usersId, IdaraId, HostName
               ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                WaitingListOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


                //// ---------------------- HousesType ----------------------
                result = await _CrudController.GetDDLValues(
                    "buildingDetailsNo", "buildingDetailsID", "3", PageName, usersId, IdaraId, HostName
               ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                buildingDetailsNoOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


                // ----------------------END DDLValues ----------------------


                // Determine which fields should be visible based on SearchID_

                form = new FormConfig
                            {
                                 Fields = new List<FieldConfig>
                                {
                                    new FieldConfig
                                    {
                                        SectionTitle = "اختيار فئة قائمة الانتظار",
                                        Name = "OtherWaitingList",
                                        Type = "select",
                                        Select2 = true,
                                        Options = WaitingListOptions,
                                        ColCss = "3",
                                        Placeholder = "اختر فئة سجلات الانتظار",
                                        Icon = "fa fa-user",
                                        Value = waitingClassID_,
                                        OnChangeJs = "sfNav(this)",
                                        NavUrl = "/Housing/OtherWaitingList",
                                        NavKey = "U",
                                    },
                                },

                    Buttons = new List<FormButtonConfig>
                    {
                        //           new FormButtonConfig
                        //  {
                        //      Text="بحث",
                        //      Icon="fa-solid fa-search",
                        //      Type="button",
                        //      Color="success",
                        //      // Replace the OnClickJs of the "تجربة" button with this:
                        //      OnClickJs = "(function(){"
                        //+ "var hidden=document.querySelector('input[name=Users]');"
                        //+ "if(!hidden){toastr.error('لا يوجد حقل مستخدم');return;}"
                        //+ "var userId = (hidden.value||'').trim();"
                        //+ "var anchor = hidden.parentElement.querySelector('.sf-select');"
                        //+ "var userName = anchor && anchor.querySelector('.truncate') ? anchor.querySelector('.truncate').textContent.trim() : '';"
                        //+ "if(!userId){toastr.info('اختر مستخدم أولاً');return;}"
                        //+ "var url = '/ControlPanel/Permission?Q1=' + encodeURIComponent(userId);"
                        //+ "window.location.href = url;"
                        //+ "})();"
                        //  },

                    }


                };

                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // اقرأ الجدول الأول


                    // نبحث عن صلاحيات محددة داخل الجدول
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "MOVETOOCCUPENTPROCEDURES")
                            canMOVETOOCCUPENTPROCEDURES = true;

                       
                    }


                    if (dt1 != null && dt1.Columns.Count > 0)
                    {

                        // Resolve a correct row id field (case sensitive match to actual DataTable column)
                        rowIdField = "ActionID";
                        var possibleIdNames = new[] { "ActionID", "actionID", "Id", "ID" };

                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        //For change table name to arabic 
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["ActionID"] = "رقم الاكشن",
                            ["NationalID"] = "رقم الهوية",
                            ["GeneralNo"] = "الرقم العام",
                            ["ActionDecisionNo"] = "رقم الطلب",
                            ["ActionDecisionDate"] = "تاريخ الطلب",
                            ["WaitingClassName"] = "فئة سجل الانتظار",
                            ["WaitingOrderTypeName"] = "نوع سجل الانتظار",
                            ["ActionNote"] = "ملاحظات",
                            ["FullName_A"] = "الاسم",
                            ["rankNameA"] = "الرتبة",
                            ["WaitingListOrder"] = "الترتيب"
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

                            bool isActionID = c.ColumnName.Equals("ActionID", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingClassID = c.ColumnName.Equals("WaitingClassID", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingOrderTypeID = c.ColumnName.Equals("WaitingOrderTypeID", StringComparison.OrdinalIgnoreCase);
                            bool iswaitingClassSequence = c.ColumnName.Equals("waitingClassSequence", StringComparison.OrdinalIgnoreCase);

                            bool isIdaraId = c.ColumnName.Equals("IdaraId", StringComparison.OrdinalIgnoreCase);
                            bool isresidentInfoID = c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionTypeID = c.ColumnName.Equals("LastActionTypeID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionID = c.ColumnName.Equals("LastActionID", StringComparison.OrdinalIgnoreCase);

                            bool isWaitingOrderTypeName = c.ColumnName.Equals("WaitingOrderTypeName", StringComparison.OrdinalIgnoreCase);
                            bool isrankNameA = c.ColumnName.Equals("rankNameA", StringComparison.OrdinalIgnoreCase);

                            List<OptionItem> filterOpts = new();
                            if (isWaitingOrderTypeName || isrankNameA)
                            {
                                var field = c.ColumnName;

                                var distinctVals = dt1.AsEnumerable()
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
                                Visible = !(isActionID || isWaitingClassID || isWaitingOrderTypeID || iswaitingClassSequence
                                 || isIdaraId || isresidentInfoID || isLastActionTypeID || isLastActionID),

                                   Filter = (isWaitingOrderTypeName || isrankNameA)
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
                        foreach (DataRow r in dt1.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt1.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            //Ensure the row id key actually exists with correct casing
                            //if (!dict.ContainsKey(rowIdField))
                           // {
                                // Try to copy from a differently cased variant
                            //    if (rowIdField.Equals("ActionID", StringComparison.OrdinalIgnoreCase) &&
                             //       dict.TryGetValue("ActionID", out var alt))
                             //       dict["ActionID"] = alt;
                             //   else if (rowIdField.Equals("ActionID", StringComparison.OrdinalIgnoreCase) &&
                             //            dict.TryGetValue("ActionID", out var alt2))
                             //       dict["ActionID"] = alt2;
                            //}

                            // Prefill pXX fields on the row so Edit form (which uses pXX names) loads the selected row values
                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("ActionID") ?? Get("actionID");
                            dict["p02"] = Get("residentInfoID");
                            dict["p03"] = Get("NationalID");
                            dict["p04"] = Get("GeneralNo");
                            dict["p05"] = Get("ActionDecisionNo");
                            dict["p06"] = Get("ActionDecisionDate");
                            dict["p07"] = Get("WaitingClassID");
                            dict["p08"] = Get("WaitingClassName");
                            dict["p09"] = Get("WaitingOrderTypeID");
                            dict["p10"] = Get("WaitingOrderTypeName");
                            dict["p11"] = Get("waitingClassSequence");
                            dict["p12"] = Get("ActionNote");
                            dict["p13"] = Get("IdaraId");
                            dict["p14"] = Get("WaitingListOrder");
                            dict["p15"] = Get("FullName_A");

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

            //ADD

            var currentUrl = Request.Path + Request.QueryString;


            //Delete fields: show confirmation as a label(not textbox) and show ID as label while still posting p01

            var MOVETOASSIGNLISTFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "MOVETOOCCUPENTPROCEDURES" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = HostName },

                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },


                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },



                // hidden p01 actually posted to SP
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ActionID" },
                new FieldConfig { Name = "p02", Label = "residentInfoID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p14", Label = "الترتيب", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p15", Label = "الاسم", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p03", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p05", Label = "رقم الطلب", Type = "text", ColCss = "3", Readonly = true  },
                new FieldConfig { Name = "p06", Label = "تاريخ الطلب", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "المبنى", Type = "select",Select2 = true, ColCss = "3", Readonly = true,Required = true,Options = buildingDetailsNoOptions },
                new FieldConfig { Name = "p12", Label = "ملاحظات", Type = "text", ColCss = "6",Required = true },
                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },



            };


           



            // then create dsModel (snippet shows toolbar parts that use the dynamic lists)
            var dsModel = new SmartTableDsModel
            {

                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = printdthasvalue,
                AllowExport = true,
                PageTitle = "قوائم الانتظار الجانبية",
                PanelTitle = "قوائم الانتظار الجانبية",
                EnableCellCopy = true,
                ShowColumnVisibility = printdthasvalue,
                ShowFilter = printdthasvalue,
                FilterRow = printdthasvalue,
                FilterDebounce = 250,
                ShowPageSizeSelector = printdthasvalue,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowDelete = canMOVETOOCCUPENTPROCEDURES && printdthasvalue,
                    ShowPrint1 = canMOVETOOCCUPENTPROCEDURES && printdthasvalue,
                    ShowBulkDelete = false,

                    Print1 = new TableAction
                    {
                        Label = "طباعة تقرير",
                        Icon = "fa fa-print",
                        Color = "info",
                        RequireSelection = false,
                        OnClickJs = @"
                        (function () {
                            var u = window.waitingClassID_ || '';
                        
                            sfPrintWithBusy(table, {
                              pdf: 1,
                              extraParams: { U: u },
                              busy: { title: 'طباعة سجلات انتظار' }
                            });
                        })();
                        ",
                        //OnClickJs = @"
                        //        sfPrintWithBusy(table, {
                        //          pdf: 1,
                        //          busy: { title: 'طباعة سجلات انتظار'}
                        //        });
                        //      ",
                    },
                    Delete = new TableAction
                    {
                        Label = "نقل لاجراءات التسكين",
                        Icon = "fa fa-check",
                        Color = "success",
                       // Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        //ModalTitle = "رسالة تحذيرية",
                        ModalTitle = "نقل المستفيد لاجراءات التسكين",
                        ModalMessage = "ملاحظة : جميع الاجراءات مرصودة من قبل النظام",
                        ModalMessageClass = "bg-blue-50 text-blue-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OpenForm = new FormConfig
                        {
                            FormId = "employeeDeleteForm",
                            Title = "تأكيد نقل المستفيد لقائمة التخصيص",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "نقل المستفيد", Type = "submit", Color = "success", Icon = "fa fa-check" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = MOVETOASSIGNLISTFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1


                        //Guards = new TableActionGuards
                        //{
                        //    AppliesTo = "any",
                        //    DisableWhenAny = new List<TableActionRule>
                        //    {

                        //        new TableActionRule
                        //        {
                        //            Field = "WaitingListOrder",
                        //            Op = "neq",
                        //            Value = "1",
                        //            Message = "لايمكن التخصيص لهذا المستفيد لانه ليس براس القائمة في فئته !!",
                        //            Priority = 3
                        //        }
                        //    }
                        //}
                    },
                }
            };


            if (pdf == 1)
            {

                if (dt1 == null || dt1.Rows.Count == 0)
                    return Content("لا توجد بيانات للطباعة." + dt1.Rows.Count.ToString());

                string class_ = dt1.Rows[0]["WaitingClassName"]?.ToString() ?? "";

                // جدول جديد خفيف للطباعة
                var printTable = new DataTable();
                printTable.Columns.Add("WaitingListOrder", typeof(string));
                printTable.Columns.Add("FullName_A", typeof(string));
                printTable.Columns.Add("NationalID", typeof(string));
                printTable.Columns.Add("GeneralNo", typeof(string));
                printTable.Columns.Add("rankNameA", typeof(string));
                printTable.Columns.Add("ActionDecisionNo", typeof(string));
                printTable.Columns.Add("ActionDecisionDate", typeof(string));
                printTable.Columns.Add("WaitingClassName", typeof(string));
                //printTable.Columns.Add("WaitingOrderTypeName", typeof(string));

                foreach (DataRow r in dt1.Rows)
                {
                    printTable.Rows.Add(
                        r["WaitingListOrder"]?.ToString() ?? "",
                        r["FullName_A"]?.ToString() ?? "",
                        r["NationalID"]?.ToString() ?? "",
                        r["GeneralNo"]?.ToString() ?? "",
                        r["rankNameA"]?.ToString() ?? "",
                        r["ActionDecisionNo"]?.ToString() ?? "",
                        r["ActionDecisionDate"]?.ToString() ?? "",
                        r["WaitingClassName"]?.ToString() ?? ""
                    //,
                    //r["WaitingOrderTypeName"]?.ToString() ?? ""
                    );
                }

                if (printTable.Rows.Count == 0)
                    return Content("لا توجد بيانات للطباعة.");

                var reportColumns = new List<ReportColumn>
    {
        new("WaitingListOrder", "الترتيب", Align:"center", Weight:1, FontSize:9),
        new("FullName_A", "الاسم", Align:"center", Weight:4, FontSize:9),
        new("NationalID", "رقم الهوية", Align:"center", Weight:2, FontSize:9),
        new("GeneralNo", "الرقم العام", Align:"center", Weight:2, FontSize:9),
        new("rankNameA", "الرتبة", Align:"center", Weight:2, FontSize:9),
        new("ActionDecisionNo", "رقم الطلب", Align:"center", Weight:2, FontSize:9),
        new("ActionDecisionDate", "تاريخ الطلب", Align:"center", Weight:2, FontSize:9),
        new("WaitingClassName", "فئة الانتظار", Align:"center", Weight:3, FontSize:9),
        //new("WaitingOrderTypeName", "نوع سجل الانتظار", Align:"center", Weight:2, FontSize:9),
    };

                var logo = Path.Combine(_env.WebRootPath, "img", "Royal_Saudi_Land_Forces.png");
                var header = new Dictionary<string, string>
                {
                    ["no"] = "",
                    ["date"] = DateTime.Now.ToString("yyyy/MM/dd"),
                    ["attach"] = "—",
                    ["subject"] = "سجلات الانتظار" + class_,
                    ["right1"] = "المملكة العربية السعودية",
                    ["right2"] = "وزارة الدفاع",
                    ["right3"] = "القوات البرية الملكية السعودية",
                    ["right4"] = "الادارة الهندسية للتشغيل والصيانة",
                    ["right5"] = IdaraName,
                    ["midCaption"] = ""
                };

                var report = DataTableReportBuilder.FromDataTable(
                    reportId: "BuildingType",
                    title: "سجلات الانتظار لفئة " + class_,
                    table: printTable,
                    columns: reportColumns,
                    headerFields: header,
                    footerFields: new Dictionary<string, string>
                    {
                        ["تمت الطباعة بواسطة"] = FullName ?? "",
                        ["ملاحظة"] = "هذا التقرير للاستخدام الرسمي",
                        ["عدد السجلات"] = printTable.Rows.Count.ToString(),
                        ["تاريخ ووقت الطباعة"] = DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss")
                    },
                    orientation: ReportOrientation.Landscape,
                    headerType: ReportHeaderType.LetterOfficial,
                    logoPath: logo,
                    headerRepeat: ReportHeaderRepeat.FirstPageOnly
                );

                var pdfBytes = QuestPdfReportRenderer.Render(report);
                Response.Headers["Content-Disposition"] = "inline; filename=BuildingType.pdf";
                return File(pdfBytes, "application/pdf");
            }



            var vm = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-home",
                Form = form,
                TableDS = ready ? dsModel : null
            };


            ViewBag.WaitingClassID = waitingClassID_;

            return View("WaitingList/OtherWaitingList", vm);
        }
    }
}
