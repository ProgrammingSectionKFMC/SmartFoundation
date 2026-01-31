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
        public async Task<IActionResult> AssignStatus(int pdf = 0)
        {

            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }

            string? AssignPeriodOptionsID_ = Request.Query["U"].FirstOrDefault();

            AssignPeriodOptionsID_ = string.IsNullOrWhiteSpace(AssignPeriodOptionsID_) ? null : AssignPeriodOptionsID_.Trim();

            bool ready = false;

            ready = !string.IsNullOrWhiteSpace(AssignPeriodOptionsID_);




            // Sessions 

            ControllerName = nameof(AssignStatus);
            PageName = nameof(AssignStatus);

            var spParameters = new object?[] { "AssignStatus", IdaraId, usersId, HostName, AssignPeriodOptionsID_ };

            DataSet ds;


            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();


            ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);



            SplitDataSet(ds);



            //string? AssignPeriodID = null;  // تعريف المتغير هنا

            //if (dt3 != null && dt3.Rows.Count > 0)
            //{
            //    var value = dt3.Rows[0]["AssignPeriodID"];
            //    AssignPeriodID = dt3.Rows[0]["AssignPeriodID"].ToString();
            //    var AssignPeriodStartdate = dt3.Rows[0]["AssignPeriodStartdate"];
            //    var FullName = dt3.Rows[0]["FullName"];

            //    TempData["AssignPeriodAvaliable"] = $"محضر التخصيص منشئ بواسطة {FullName} نشط منذ {AssignPeriodStartdate} ";
            //}
            //else
            //{
            //    TempData["NoAssignPeriod"] = "لا يوجد محضر تخصيص نشط";
            //}

            // ✅ LINQ - واضح وآمن
            //var count = dt1.AsEnumerable()
            //    .Count(row =>
            //    {
            //        var actionTypeId = row["LastActionTypeID"];
            //        if (actionTypeId == DBNull.Value) return false;

            //        int value = Convert.ToInt32(actionTypeId);
            //        return value == 38 || value == 40;
            //    });

            int count = 0;

            if (dt1 != null && dt1.Rows.Count > 0 &&
                dt1.Columns.Contains("LastActionTypeID") &&
                dt1.Columns.Contains("AssignPeriodID"))
            {
                count = dt1.AsEnumerable()
                    .Count(row =>
                    {
                        var actionTypeId = row["LastActionTypeID"];
                        var assignPeriodId = row["AssignPeriodID"];

                        if (actionTypeId == DBNull.Value || assignPeriodId == DBNull.Value)
                            return false;

                        int actionValue = Convert.ToInt32(actionTypeId);
                        int periodValue = Convert.ToInt32(assignPeriodId);

                        // ✅ الشرط المركب: (38 OR 40) AND AssignPeriodID = 4
                        return (actionValue == 38 || actionValue == 40) && periodValue == Convert.ToInt32(AssignPeriodOptionsID_);
                    });
            }

            if (dt1 != null && dt1.Rows.Count > 0)
            {
                if (count > 0)
                {
                    TempData["countBiggerThanzero"] = $"متبقي لديك عدد {count} مستفيد في هذا المحضر لم تقم بإنهاء اجراءاتهم لحد الان !! ";
                }
                else if (count == 0)  // ✅ تصحيح: == بدلاً من =
                {
                    TempData["countEqualzero"] = "تم انهاء اجراءات جميع المستفيدين بنجاح قم باغلاق المحضر الان";
                }
            }



            string rowIdField = "";
            bool canENDASSIGNPERIOD = false;
            bool canASSIGNSTATUS = false;





            List<OptionItem> AssignPeriodOptions = new();
            List<OptionItem> BuildingActionTypeCasesOptions = new();




            FormConfig form = new();


            try
            {

                // ---------------------- DDLValues ----------------------




                JsonResult? result;
                string json;




                //// ---------------------- AssignPeriodType ----------------------
                result = await _CrudController.GetDDLValues(
                    "AssignPeriodDescrption", "AssignPeriodID", "2", PageName, usersId, IdaraId, HostName
               ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                AssignPeriodOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


                //// ---------------------- BuildingActionTypeCases ----------------------
                result = await _CrudController.GetDDLValues(
                    "buildingActionTypeName_A", "buildingActionTypeID", "3", PageName, usersId, IdaraId, HostName
               ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                BuildingActionTypeCasesOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


                // ----------------------END DDLValues ----------------------


                // Determine which fields should be visible based on SearchID_

                form = new FormConfig
                            {
                                 Fields = new List<FieldConfig>
                                {
                                    new FieldConfig
                                    {
                                        SectionTitle = "اختيار محضر التخصيص",
                                        Name = "WaitingList",
                                        Type = "select",
                                        Select2 = true,
                                        Options = AssignPeriodOptions,
                                        ColCss = "3",
                                        Placeholder = "اختر محضر التخصيص",
                                        Icon = "fa fa-user",
                                        Value = AssignPeriodOptionsID_,
                                        OnChangeJs = "sfNav(this)",
                                        NavUrl = "/Housing/AssignStatus",
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

                        if (permissionName == "ASSIGNSTATUS")
                            canASSIGNSTATUS = true;
                        if (permissionName == "ENDASSIGNPERIOD")
                            canENDASSIGNPERIOD = true;
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
                            ["ActionID"] = "رقم الاكشن",
                            ["NationalID"] = "رقم الهوية",
                            ["GeneralNo"] = "الرقم العام",
                            ["ActionDecisionNo"] = "رقم الطلب",
                            ["ActionDecisionDate"] = "تاريخ الطلب",
                            ["WaitingClassName"] = "فئة سجل الانتظار",
                            ["WaitingOrderTypeName"] = "نوع سجل الانتظار",
                            ["ActionNote"] = "ملاحظات",
                            ["FullName_A"] = "الاسم",
                            ["buildingActionTypeResidentAlias"] = "الحالة",
                            ["buildingDetailsNo"] = "رقم المنزل",
                            ["WaitingListOrder"] = "ترتيب الانتظار حسب الفئة"
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
                            bool isresidentInfoID_FK = c.ColumnName.Equals("residentInfoID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraId = c.ColumnName.Equals("IdaraId", StringComparison.OrdinalIgnoreCase);
                            bool isresidentInfoID = c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionTypeID = c.ColumnName.Equals("LastActionTypeID", StringComparison.OrdinalIgnoreCase);
                            bool isAssignPeriodID = c.ColumnName.Equals("AssignPeriodID", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingDetailsID = c.ColumnName.Equals("buildingDetailsID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionID = c.ColumnName.Equals("LastActionID", StringComparison.OrdinalIgnoreCase);
                            
                            

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                //if u want to hide any column 
                                ,
                                Visible = !(isActionID || isWaitingClassID || isWaitingOrderTypeID || iswaitingClassSequence
                                || isresidentInfoID_FK || isIdaraId || isresidentInfoID || isLastActionTypeID  || isbuildingDetailsID || isLastActionID)
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
                            dict["p16"] = Get("LastActionTypeID");
                            dict["p17"] = Get("buildingActionTypeResidentAlias");
                            dict["p18"] = Get("buildingDetailsID");
                            dict["p19"] = Get("buildingDetailsNo");
                            dict["p20"] = Get("AssignPeriodID");
                            dict["p21"] = Get("LastActionID");


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
            var UrlWithoutQueryString = Request.Path;


            var ENDASSIGNPERIODFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "ENDASSIGNPERIOD" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = HostName },

                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = UrlWithoutQueryString },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },


                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },

              

                // hidden p01 actually posted to SP
               
                new FieldConfig { Name = "p01", Label = "ملاحظات انهاء محضر التخصيص", Type = "textarea", ColCss = "6", Required = true },
                 new FieldConfig { Name = "p02", Label = "AssignPeriodID", Type = "hidden", ColCss = "6",Value =AssignPeriodOptionsID_ },
                //new FieldConfig
                //    {
                //        SectionTitle="رفع صورة",
                //        Name="Emg",
                //        Label="اعتماد محضر التخصيص",
                //        Type="file",
                //        Required=true,
                //        Icon="fa-solid fa-check",
                //        ColCss="col-span-12 md:col-span-3"
                //    },

            };





            //Delete fields: show confirmation as a label(not textbox) and show ID as label while still posting p01
            var ASSIGNSTATUSFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "ASSIGNSTATUS" },
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
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "المبنى", Type = "text", ColCss = "3", Readonly = true },
                 new FieldConfig
                {
                    Name = "p23",
                    Label = "حالة المستفيد",
                    Type = "select",
                    Options = BuildingActionTypeCasesOptions,
                    ColCss = "6",
                    Select2 = false,
                    Required = true
                },
                new FieldConfig { Name = "p22", Label = "ملاحظات", Type = "text", ColCss = "6",Required = true },
                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p18", Label = "buildingDetailsNo", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },


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
                Searchable = true,
                AllowExport = true,
                PageTitle = "معالجة محاضر التخصيص",
                PanelTitle = "معالجة محاضر التخصيص",
                EnableCellCopy = true,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd1 = canENDASSIGNPERIOD,
                    ShowEdit = canASSIGNSTATUS,
                    ShowPrint1 = false,
                    ShowPrint = false,
                    ShowBulkDelete = false,
                    ShowExportPdf = false,



                    Add1 = new TableAction
                    {
                        Label = "انهاء محضر التخصيص",
                        Icon = "fa fa-newspaper",
                        Color = "info",
                        // Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        //ModalTitle = "رسالة تحذيرية",
                        ModalTitle = "انهاء محضر تخصيص نشط",
                        ModalMessage = "هل أنت متأكد من انهاء محضر التخصيص ؟ لايمكن التراجع عن هذا الاجراء !",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassInsertForm",
                            Title = "بيانات محضر التخصيص ",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = ENDASSIGNPERIODFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ",   Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        },

                        Guards = new TableActionGuards
                        {
                            AppliesTo = "all",
                            DisableWhenAny = new List<TableActionRule>
                            {

                                new TableActionRule
                                {
                                    Field = "Count_",
                                    Op = "neq",
                                    Value = "0",
                                    Message = "لايمكن انهاء المحضر لوجود مستفيدين لم يتم معالجتهم بهذا المحضر !!",
                                    Priority = 3
                                }
                            }
                        }
                    },

                   
                    Edit = new TableAction
                    {
                        Label = "معالجة تخصيص مستفيد",
                        Icon = "fa fa-check",
                        Color = "success",
                        //Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        //ModalTitle = "رسالة تحذيرية",
                        ModalTitle = "معالجة تخصيص مستفيد",
                        ModalMessage = "ملاحظة : لايمكن التراجع عن هذا الاجراء",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OpenForm = new FormConfig
                        {
                            FormId = "employeeDeleteForm",
                            Title = "تأكيد معالجة تخصيص مستفيد",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success", Icon = "fa fa-check" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = ASSIGNSTATUSFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,


                        Guards = new TableActionGuards
                        {
                            AppliesTo = "any",
                            DisableWhenAny = new List<TableActionRule>
                            {

                                  new TableActionRule
                                {
                                    Field = "LastActionTypeID",
                                    Op = "eq",
                                    Value = "45",
                                    Message = "تم معالجة طلب المستفيد مسبقا",
                                    Priority = 3
                                },
                                  new TableActionRule
                                {
                                    Field = "LastActionTypeID",
                                    Op = "eq",
                                    Value = "39",
                                    Message = "تم معالجة طلب المستفيد مسبقا",
                                    Priority = 3
                                },
                                 new TableActionRule
                                {
                                    Field = "LastActionTypeID",
                                    Op = "eq",
                                    Value = "41",
                                    Message = "تم معالجة طلب المستفيد مسبقا",
                                    Priority = 3
                                },
                                 new TableActionRule
                                {
                                    Field = "LastActionTypeID",
                                    Op = "eq",
                                    Value = "42",
                                    Message = "تم معالجة طلب المستفيد مسبقا",
                                    Priority = 3
                                },

                            }
                        }
                    },

                    Print1 = new TableAction
                    {
                        Label = "طباعة خطاب",
                        Icon = "fa fa-print",
                        Color = "primary",
                        //Placement = TableActionPlacement.ActionsMenu,
                        RequireSelection = false,
                        OnClickJs = @"
                                sfPrintWithBusy(table, {
                                  pdf: 2,
                                  busy: { title: 'طباعة خطاب تجريبي'}
                                });
                                "

                    },


                    ExportConfig = new TableExportConfig
                    {
                        EnablePdf = true,
                        PdfEndpoint = "/exports/pdf/table",
                        PdfTitle = "المستفيدين",
                        PdfPaper = "A4",
                        PdfOrientation = "landscape",
                        PdfShowPageNumbers = true,
                        Filename = "Residents",
                        PdfShowGeneratedAt = true,
                        PdfShowSerial = true,
                        PdfSerialLabel = "م",
                        RightHeaderLine1 = "المملكة العربية السعودية",
                        RightHeaderLine2 = "وزارة الدفاع",
                        RightHeaderLine3 = "القوات البرية الملكية السعودية",
                        RightHeaderLine4 = "الإدارة الهندسية للتشغيل والصيانة",
                        RightHeaderLine5 = "مدينة الملك فيصل العسكرية",
                        PdfLogoUrl = "/img/ppng.png",


                    },

                    CustomActions = new List<TableAction>
                            {
                            //  Excel "
                            //new TableAction
                            //{
                            //    Label = "تصدير Excel",
                            //    Icon = "fa-regular fa-file-excel",
                            //    Color = "info",
                            //    Placement = TableActionPlacement.ActionsMenu,
                            //    RequireSelection = false,
                            //    OnClickJs = "table.exportData('excel');"
                            //},

                            //  PDF "
                            new TableAction
                            {
                                Label = "تصدير PDF",
                                Icon = "fa-regular fa-file-pdf",
                                Color = "danger",
                               // Placement = TableActionPlacement.ActionsMenu,
                                RequireSelection = false,
                                OnClickJs = "table.exportData('pdf');"
                            },

                             //  details "       
                            new TableAction
                            {
                                Label = "عرض التفاصيل",
                                ModalTitle = "<i class='fa-solid fa-circle-info text-emerald-600 text-xl mr-2'></i> تفاصيل المستفيد",
                                Icon = "fa-regular fa-file",
                                OpenModal = true,
                                RequireSelection = true,
                                MinSelection = 1,
                                MaxSelection = 1,


                            },
                        },
                }
            };


            dsModel.StyleRules = new List<TableStyleRule>
                {

                    new TableStyleRule
                    {
                        Target = "row",
                        Field = "LastActionTypeID",
                        Op = "eq",
                        Value = "45",
                        CssClass = "row-green",
                        Priority = 1

                    },
                      new TableStyleRule
                    {
                        Target = "row",
                        Field = "LastActionTypeID",
                        Op = "eq",
                        Value = "39",
                        CssClass = "row-yellow",
                        Priority = 1
                    },
                       new TableStyleRule
                    {
                        Target = "row",
                        Field = "buildingLastActionTypeIDActionTypeResidentAlias",
                        Op = "eq",
                        Value = "41",
                        CssClass = "row-yellow",
                        Priority = 1
                    },

                        new TableStyleRule
                    {
                        Target = "row",
                        Field = "LastActionTypeID",
                        Op = "eq",
                        Value = "42",
                        CssClass = "row-red",
                        Priority = 1
                    },

                };

            var vm = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-home",
                Form = form,
                TableDS = ready ? dsModel : null
            };



            if (pdf == 2)
            {
                var logo = Path.Combine(_env.WebRootPath, "img", "ppng.png");

                var header = new Dictionary<string, string>
                {
                    ["no"] = AssignPeriodOptionsID_ ?? "",
                    ["date"] = DateTime.Now.ToString("yyyy/MM/dd"),
                    ["attach"] = "بيان بأسماء المستفيدين المخصص لهم",
                    ["subject"] = "محضر تخصيص مساكن",

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



            return View("WaitingList/AssignStatus", vm);
        }
    }
}
