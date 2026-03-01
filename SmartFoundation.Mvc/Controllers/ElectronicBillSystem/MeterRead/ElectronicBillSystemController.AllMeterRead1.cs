using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Text.Json;


namespace SmartFoundation.Mvc.Controllers.ElectronicBillSystem
{
    public partial class ElectronicBillSystemController : Controller
    {
        public async Task<IActionResult> AllMeterRead1()
        {


            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }

            string? MeterServiceTypeID_ = Request.Query["U"].FirstOrDefault();

            MeterServiceTypeID_ = string.IsNullOrWhiteSpace(MeterServiceTypeID_) ? null : MeterServiceTypeID_.Trim();

            bool ready = false;

            




            // Sessions 

            ControllerName = nameof(ElectronicBillSystem);
            PageName = nameof(AllMeterRead1);

            var spParameters = new object?[] { "AllMeterRead", IdaraId, usersId, HostName, MeterServiceTypeID_ };

            DataSet ds;


            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();


            ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);



           
                SplitDataSet(ds);


            ready = !string.IsNullOrWhiteSpace(MeterServiceTypeID_);


            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }


           
            bool openperiod = false;
            bool closeperiod = false;


            if (dt1 != null && dt1.Rows.Count > 0 && MeterServiceTypeID_ is not null)
            {
                
              TempData["countBiggerThanzero"] = $"يوجد فترة قراءة عدادت نشطة لهذا الشهر سارع بانهائها !! ";
                openperiod = false;
                closeperiod = true;
            }

            else if ((dt1 == null || dt1.Rows.Count == 0) && MeterServiceTypeID_ is not null)   // ✅ تصحيح: == بدلاً من =
            {
                TempData["countEqualzero"] = $"لايوجد فترة قراءة عدادت نشطة لهذا الشهر قم بانشاء فترة للبدء بقراءة العدادات !! ";
                openperiod = true;
                closeperiod = false;
            }


            string rowIdField = "";
            bool canOPENMETERREADPERIOD = false;
            bool canCLOSEMETERREADPERIOD = false;
            bool canREADELECTRICITYMETER = false;
            bool canEDITELECTRICITYMETER = false;
            bool canDELETEELECTRICITYMETER = false;
            bool canREADWATERMETER = false;
            bool canEDITWATERMETER = false;
            bool canDELETEWATERMETER = false;
            bool canREADGASMETER = false;
            bool canEDITGASMETER = false;
            bool canDELETEGASMETER = false;




            List<OptionItem> MeterServiceTypeOptions = new();




            FormConfig form = new();


            try
            {

                // ---------------------- DDLValues ----------------------




                JsonResult? result;
                string json;




                //// ---------------------- BuildingUtilityType ----------------------
                result = await _CrudController.GetDDLValues(
                    "meterServiceTypeName_A", "meterServiceTypeID", "3", nameof(AllMeterRead1), usersId, IdaraId, HostName
               ) as JsonResult;


                json = JsonSerializer.Serialize(result!.Value);

                MeterServiceTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json)!;


                // ----------------------END DDLValues ----------------------


                // Determine which fields should be visible based on SearchID_

                           form = new FormConfig
                            {
                                 Fields = new List<FieldConfig>
                                {
                                    new FieldConfig
                                    {
                                        SectionTitle = "اختيار نوع خدمة العدادات",
                                        Name = "MeterServiceType",
                                        Type = "select",
                                        Select2 = true,
                                        Options = MeterServiceTypeOptions,
                                        ColCss = "3",
                                        Placeholder = "اختر نوع خدمة العدادات",
                                        Icon = "fa fa-user",
                                        Value = MeterServiceTypeID_,
                                        OnChangeJs = "sfNav(this)",
                                        NavUrl = "/ElectronicBillSystem/AllMeterRead",
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

                        if (permissionName == "OPENMETERREADPERIOD") canOPENMETERREADPERIOD = true;
                        if (permissionName == "CLOSEMETERREADPERIOD") canCLOSEMETERREADPERIOD = true;

                        if (permissionName == "READELECTRICITYMETER") canREADELECTRICITYMETER = true;
                        if (permissionName == "EDITELECTRICITYMETER") canEDITELECTRICITYMETER = true;
                        if (permissionName == "DELETEELECTRICITYMETER") canDELETEELECTRICITYMETER = true;
                        if (permissionName == "READWATERMETER") canREADWATERMETER = true;
                        if (permissionName == "EDITWATERMETER") canEDITWATERMETER = true;
                        if (permissionName == "DELETEWATERMETER") canDELETEWATERMETER = true;
                        if (permissionName == "READGASMETER") canREADGASMETER = true;
                        if (permissionName == "EDITGASMETER") canEDITGASMETER = true;
                        if (permissionName == "DELETEGASMETER") canDELETEGASMETER = true;

                       
                    }


                    if (dt1 != null && dt1.Columns.Count > 0)
                    {

                        // Resolve a correct row id field (case sensitive match to actual DataTable column)
                        rowIdField = "billPeriodID";
                        var possibleIdNames = new[] { "BillPeriodID", "billPeriodID", "Id", "ID" };

                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        //For change table name to arabic 
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["billPeriodID"] = "الرقم المرجعي",
                            ["billPeriodName_A"] = "الفترة بالعربي",
                            ["billPeriodName_E"] = "الفترة بالانجليزي",
                            ["billPeriodStartDate"] = "تاريخ بداية الفترة",
                            ["billPeriodEndDate"] = "تاريخ نهائة الفترة",
                            ["billPeriodTypeName_A"] = "نوع الفترة"
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

                            bool isHidden = c.ColumnName.Equals("billPeriodTypeID_FK", StringComparison.OrdinalIgnoreCase)
                                            ||  c.ColumnName.Equals("billPeriodActive", StringComparison.OrdinalIgnoreCase)
                                            ||  c.ColumnName.Equals("IdaraId_FK", StringComparison.OrdinalIgnoreCase)
                                            ||  c.ColumnName.Equals("ClosedBy", StringComparison.OrdinalIgnoreCase);
                           
                            
                            

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                //if u want to hide any column 
                                ,
                                Visible = !(isHidden)
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
                            dict["p01"] = Get("BillPeriodID") ?? Get("billPeriodID");
                            dict["p02"] = Get("billPeriodTypeID_FK");
                            dict["p03"] = Get("billPeriodTypeName_A");
                            dict["p04"] = Get("billPeriodName_A");
                            dict["p05"] = Get("billPeriodName_E");
                            dict["p06"] = Get("billPeriodStartDate");
                            dict["p07"] = Get("billPeriodEndDate");
                            dict["p08"] = Get("billPeriodActive");
                            dict["p09"] = Get("ClosedBy");
                            dict["p10"] = Get("IdaraId_FK");
                           

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


            //ready = !string.IsNullOrWhiteSpace(MeterServiceTypeID_);
            // && (canOPENMETERREADPERIOD == true || canCLOSEMETERREADPERIOD == true)

            //ADD

            var currentUrl = Request.Path + Request.QueryString;


            //Delete fields: show confirmation as a label(not textbox) and show ID as label while still posting p01

            var MOVETOASSIGNLISTFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "MOVETOASSIGNLIST" },
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
                new FieldConfig { Name = "p12", Label = "ملاحظات", Type = "text", ColCss = "6" },
                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },



            };






            // then create dsModel (snippet shows toolbar parts that use the dynamic lists)
            var dsModel = new SmartTableDsModel
            {
                PageTitle = "إمهال المستفيدين",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                PanelTitle = "إمهال المستفيدين",
                //TabelLabel = "بيانات المستفيدين",
                //TabelLabelIcon = "fa-solid fa-user-group",
                EnableCellCopy = true,
                ShowColumnVisibility = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,

                    ShowEdit = true,
                    ShowEdit1 = true,
                    ShowDelete = true,
                    ShowDelete1 = true,
                    ShowDelete2 = true,

                    ShowBulkDelete = false,



                    ExportConfig = new TableExportConfig
                    {
                        EnablePdf = true,
                        PdfEndpoint = "/exports/pdf/table",
                        PdfTitle = " إمهال المستفيدين",
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
                            //    //Show = true,  // ✅ أضف
                            //    RequireSelection = false,
                            //    OnClickJs = "table.exportData('excel');"
                            //},

                            ////  PDF "
                            //new TableAction
                            //{
                            //    Label = "تصدير PDF",
                            //    Icon = "fa-regular fa-file-pdf",
                            //    Color = "danger",
                            //    //Show = true,  // ✅ أضف
                            //    RequireSelection = false,
                            //    OnClickJs = "table.exportData('pdf');"
                            //},

                             //  details "       
                            new TableAction
                            {
                                Label = "عرض التفاصيل",
                                ModalTitle = "<i class='fa-solid fa-circle-info text-emerald-600 text-xl mr-2'></i> تفاصيل المستفيد",
                                Icon = "fa-regular fa-file",
                                //Show = true,  // ✅ أضف
                                OpenModal = true,
                                RequireSelection = true,
                                MinSelection = 1,
                                MaxSelection = 1,


                            },
                        },


                    Edit = new TableAction
                    {
                        Label = "امهال مستفيد",
                        Icon = "fa-solid fa-pen",
                        Color = "success",
                        Show = true,  // ✅ أضف
                        IsEdit = true,
                        OpenModal = true,

                        ModalTitle = "",
                        ModalMessage = "",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",

                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",

                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = MOVETOASSIGNLISTFields
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
                                Value = "48",
                                Message = "تم انشاء الطلب مسبقا",
                                Priority = 3
                            },
                                 new TableActionRule
                            {
                                Field = "LastActionTypeID",
                                Op = "eq",
                                Value = "51",
                                Message = "تم انشاء الطلب مسبقا",
                                Priority = 3
                            },
                                      new TableActionRule
                            {
                                Field = "LastActionTypeID",
                                Op = "eq",
                                Value = "52",
                                Message = "تم انشاء الطلب مسبقا",
                                Priority = 3
                            },

                          }
                        }
                    },

                    Edit1 = new TableAction  // ✅ لازم تحدد Edit1 بدل Delete1!
                    {
                        Label = "تعديل امهال",
                        Icon = "fa-solid fa-edit",
                        Color = "warning",
                        //Show = true,  // ✅ أضف
                        IsEdit = true,
                        OpenModal = true,

                        ModalTitle = "",
                        ModalMessage = "",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",

                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",

                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = MOVETOASSIGNLISTFields
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
                                Op = "neq",
                                Value = "48",
                                Message = "لايمكن تعديل الطلب",
                                Priority = 3
                            },
                          }
                        }
                    },


                    Delete = new TableAction
                    {
                        Label = "الغاء امهال مستفيد",
                        Icon = "fa-solid fa-close",
                        Color = "danger",
                        //Show = true,  // ✅ أضف
                        IsEdit = true,
                        OpenModal = true,

                        ModalTitle = "",
                        ModalMessage = "",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",

                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",

                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = MOVETOASSIGNLISTFields
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
                                Op = "neq",
                                Value = "48",
                                Message = "لايمكن الغاء الطلب",
                                Priority = 3
                            },
                          }
                        }
                    },

                    Delete1 = new TableAction
                    {
                        Label = "ارسال للتدقيق المالي",
                        Icon = "fa-solid fa-money-bill-wave",
                        Color = "info",
                        //Show = true,  // ✅ أضف
                        IsEdit = true,
                        OpenModal = true,

                        ModalTitle = "",
                        ModalMessage = "",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",

                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",

                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = MOVETOASSIGNLISTFields
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
                                Value = "2",
                                Message = "لم يتم انشاء الطلب",
                                Priority = 3
                            },
                                 new TableActionRule
                            {
                                Field = "LastActionTypeID",
                                Op = "eq",
                                Value = "24",
                                Message = "لم يتم انشاء الطلب",
                                Priority = 3
                            },
                              new TableActionRule
                            {
                                Field = "LastActionTypeID",
                                Op = "eq",
                                Value = "51",
                                Message = "لايمكن الغاء الطلب",
                                Priority = 3
                            },
                                 new TableActionRule
                            {
                                Field = "LastActionTypeID",
                                Op = "eq",
                                Value = "52",
                                Message = "لايمكن الغاء الطلب",
                                Priority = 3
                            },
                          }
                        }
                    },

                    Delete2 = new TableAction  // ✅ لازم تحدد Edit1 بدل Delete1!
                    {
                        Label = "اعتماد الامهال",
                        Icon = "fa-solid fa-check",
                        Color = "success",
                        //Show = true,  // ✅ أضف
                        IsEdit = true,
                        OpenModal = true,

                        ModalTitle = "",
                        ModalMessage = "",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",

                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",

                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = MOVETOASSIGNLISTFields
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
                                Op = "neq",
                                Value = "52",
                                Message = "لايمكن اعتماد الامهال لعدم انتهاء التدقيق المالي ",
                                Priority = 3
                            },
                          }
                        }
                    },

                }
            };






            var vm = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-home",
                Form = form,
                TableDS = ready ? dsModel : null
            };

            return View("MeterRead/AllMeterRead", vm);
        }
    }
}
