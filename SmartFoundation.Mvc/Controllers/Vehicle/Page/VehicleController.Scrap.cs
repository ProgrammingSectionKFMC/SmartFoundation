using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using SmartFoundation.UI.ViewModels.SmartDynamicFields;
using System.Data;
using System.Linq;
using SmartFoundation.MVC.Reports;

namespace SmartFoundation.Mvc.Controllers.Vehicle
{
    public partial class VehicleController : Controller
    {
        [Route("Vehicle/Scrap")]
        public async Task<IActionResult> Scrap(
              string? scrapID = null
            , string? chassisNumber = null
            , string? status = null
            , string? dateFrom = null
            , string? dateTo = null
            , int pageNumber = 1
            , int pageSize = 50
            , int pdf = 0
            , int? rowId = null)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = "Vehicle";
            PageName = "Scrap";

            #region Load Data

            DataSet? ds = null;
            DataSet? vehicleDs = null;

            var dsTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[]
                {
                    PageName,
                    IdaraId,
                    usersId,
                    HostName,
                    "LIST",
                    null,
                    null,
                    string.IsNullOrWhiteSpace(chassisNumber) ? null : chassisNumber,
                    string.IsNullOrWhiteSpace(status) ? null : status,
                    string.IsNullOrWhiteSpace(dateFrom) ? null : dateFrom,
                    string.IsNullOrWhiteSpace(dateTo) ? null : dateTo,
                    pageNumber,
                    pageSize
                });

            var vehicleTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[] { "Vehicle_Search", IdaraId, usersId, HostName, "%" });

            await Task.WhenAll(dsTask, vehicleTask);

            ds = dsTask.Result;
            vehicleDs = vehicleTask.Result;

            SplitDataSet(ds);

            #endregion

            #region Vehicle Options

            var vehicleOptions = new List<OptionItem>();
            DataTable? vehicleTable = (vehicleDs?.Tables?.Count ?? 0) > 1
                ? vehicleDs!.Tables[1]
                : (vehicleDs?.Tables?.Count ?? 0) > 0 ? vehicleDs!.Tables[0] : null;

            if (vehicleTable != null)
            {
                foreach (DataRow r in vehicleTable.Rows)
                {
                    var chassis = vehicleTable.Columns.Contains("chassisNumber")
                        ? r["chassisNumber"]?.ToString() : null;
                    if (string.IsNullOrWhiteSpace(chassis)) continue;

                    var armyNum = vehicleTable.Columns.Contains("armyNumber")
                        ? r["armyNumber"]?.ToString()?.Trim() ?? "" : "";
                    var plateLetters = vehicleTable.Columns.Contains("plateLetters")
                        ? r["plateLetters"]?.ToString()?.Trim() ?? "" : "";
                    var plateNumbers = vehicleTable.Columns.Contains("plateNumbers")
                        ? r["plateNumbers"]?.ToString()?.Trim() ?? "" : "";
                    var plate = $"{plateLetters} {plateNumbers}".Trim();

                    var text = string.IsNullOrWhiteSpace(armyNum)
                        ? chassis
                        : $"{armyNum} — {chassis}";
                    if (!string.IsNullOrWhiteSpace(plate))
                        text += $" — {plate}";

                    vehicleOptions.Add(new OptionItem { Value = chassis, Text = text });
                }
            }

            #endregion

            #region Permissions

            bool canAccess = false;
            bool canSelect = false;
            bool canInsertScrap = false;
            bool canUpdateScrap = false;
            bool canApproveScrap = false;
            bool canCancelScrap = false;
            bool canPrint = false;

            if (permissionTable != null && permissionTable.Rows.Count > 0)
            {
                foreach (DataRow row in permissionTable.Rows)
                {
                    var p = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                    if (p == "ACCESS") canAccess = true;
                    if (p == "SELECT") canSelect = true;
                    if (p == "INSERT_SCRAP") canInsertScrap = true;
                    if (p == "UPDATE_SCRAP") canUpdateScrap = true;
                    if (p == "APPROVE_SCRAP") canApproveScrap = true;
                    if (p == "CANCEL_SCRAP") canCancelScrap = true;
                    if (p == "PRINT") canPrint = true;
                }
            }

            #endregion

            #region Options

            var scrapTypeOptions = new List<OptionItem>
            {
                new OptionItem { Value = "1", Text = "إتلاف نهائي" },
                new OptionItem { Value = "2", Text = "خارج الخدمة" }
            };

            #endregion

            #region Process Grid Rows

            var rowsList = new List<Dictionary<string, object?>>();
            var columns = new List<TableColumn>();
            string rowIdField = "ScrapID";

            var dataTable = (dt2 != null && dt2.Rows.Count > 0) ? dt2 : dt1;

            if (dataTable != null && dataTable.Columns.Count > 0)
            {
                columns.Add(new TableColumn { Field = "ScrapID", Label = "رقم المحضر", Type = "number", Sortable = true, Visible = true });
                columns.Add(new TableColumn { Field = "armyNumber", Label = "رقم الجيش", Type = "text", Sortable = true, Visible = true });
                columns.Add(new TableColumn { Field = "chassisNumber_FK", Label = "رقم الهيكل", Type = "text", Sortable = true, Visible = true });
                columns.Add(new TableColumn { Field = "plateDisplay", Label = "اللوحة", Type = "text", Sortable = true, Visible = true });
                columns.Add(new TableColumn { Field = "ScrapDate", Label = "تاريخ الإتلاف", Type = "date", Sortable = true, Visible = true });
                columns.Add(new TableColumn { Field = "ScrapTypeText", Label = "نوع الإتلاف", Type = "text", Sortable = true, Visible = true });
                columns.Add(new TableColumn { Field = "Reason", Label = "السبب", Type = "text", Sortable = true, Visible = true });
                columns.Add(new TableColumn { Field = "StatusText", Label = "الحالة", Type = "text", Sortable = true, Visible = true });
                columns.Add(new TableColumn { Field = "ApprovedDateText", Label = "تاريخ الاعتماد", Type = "text", Sortable = true, Visible = true });

                foreach (DataRow r in dataTable.Rows)
                {
                    var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                    foreach (DataColumn c in dataTable.Columns)
                    {
                        var val = r[c];
                        dict[c.ColumnName] = val == DBNull.Value ? null : val;
                    }

                    string Get(string key) => dict.TryGetValue(key, out var v) ? v?.ToString() ?? "" : "";

                    var plateLetters = Get("plateLetters");
                    var plateNumbers = Get("plateNumbers");
                    var scrapTypeId = Get("ScrapTypeID_FK");
                    var statusValue = Get("Status").Trim();

                    dict["plateDisplay"] = string.IsNullOrWhiteSpace(plateLetters) && string.IsNullOrWhiteSpace(plateNumbers)
                        ? null
                        : $"{plateLetters} {plateNumbers}".Trim();

                    dict["ScrapTypeText"] = scrapTypeId switch
                    {
                        "1" => "إتلاف نهائي",
                        "2" => "خارج الخدمة",
                        _ => scrapTypeId
                    };

                    var approvedDate = dict.TryGetValue("ApprovedDate", out var ad) ? ad : null;
                    dict["ApprovedDateText"] = NormalizeDateForInput(approvedDate) ?? "";

                    dict["IsDraftRow"] = statusValue == "Draft" ? "1" : "0";
                    dict["IsApprovedRow"] = statusValue == "Approved" ? "1" : "0";
                    dict["IsCancelledRow"] = statusValue == "Cancelled" ? "1" : "0";

                    dict["StatusText"] = statusValue switch
                    {
                        "Draft"     => "بانتظار الاعتماد",
                        "Approved"  => "تم الاعتماد",
                        "Cancelled" => "تم الإلغاء",
                        _ => statusValue
                    };

                    dict["p01"] = Get("ScrapID");
                    dict["p02"] = Get("chassisNumber_FK");
                    dict["p03"] = Get("ScrapDate");
                    dict["p04"] = Get("ScrapTypeID_FK");
                    dict["p05"] = Get("RefNo");
                    dict["p06"] = Get("Reason");
                    dict["p07"] = Get("Note");
                    dict["p08"] = Get("Notes");
                    dict["p09"] = Get("ApprovedDate");
                    dict["p10"] = Get("Status");
                    dict["p11"] = Get("plateDisplay");
                    dict["p12"] = Get("armyNumber");

                    rowsList.Add(dict);
                }
            }

            #endregion

            #region Form Configurations

            var currentUrl = Request.Path + Request.QueryString;

            var insertFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT_SCRAP" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },

                new FieldConfig { Name = "p01", Type = "hidden", Value = "" },
                new FieldConfig
                {
                    Name = "p02",
                    Label = "المركبة",
                    Type = "select",
                    ColCss = "6",
                    Required = true,
                    Options = vehicleOptions,
                    Select2 = true,
                    Placeholder = "ابحث برقم الجيش أو رقم الهيكل"
                },
                new FieldConfig
                {
                    Name = "p03",
                    Label = "تاريخ الإتلاف",
                    Type = "date",
                    ColCss = "6",
                    Required = true
                },
                new FieldConfig
                {
                    Name = "p04",
                    Label = "نوع الإتلاف",
                    Type = "select",
                    Options = scrapTypeOptions,
                    ColCss = "6",
                    Select2 = true,
                    Required = true,
                    Placeholder = "اختر نوع الإتلاف"
                },
                new FieldConfig { Name = "p05", Type = "hidden", Value = "" },
                new FieldConfig { Name = "p06", Type = "hidden", Value = "" },
                new FieldConfig { Name = "p07", Type = "hidden", Value = "" },
                new FieldConfig { Name = "p08", Type = "hidden", Value = "" }
            };

            var scrapReasonFieldsConfig = new SmartDynamicFieldsConfig
            {
                Id = "scrap-reasons",
                FormId = "InsertScrapForm",
                OutputName = "p06",
                RenderOutputInput = false,
                SyncOutputOnChange = false,
                MinRows = 1,
                MaxRows = 16,
                AllowAdd = true,
                AllowRemove = true,
                AllowReorder = false,
                AddButtonText = "إضافة سبب",
                RemoveButtonText = "حذف السبب",
                EmptyValidationMessage = "يجب إدخال سبب واحد على الأقل",
                MaxRowsMessage = "لا يمكن إضافة أكثر من 16 سببًا",
                Fields = new List<SmartDynamicFieldDefinition>
                {
                    new()
                    {
                        Name = "reasonDescription",
                        Label = "السبب",
                        Type = SmartDynamicFieldType.Text,
                        Required = true,
                        MaxLength = 800,
                        Placeholder = "أدخل سبب الإتلاف",
                        ColCss = "col-span-12"
                    }
                }
            };

            var updateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATE_SCRAP" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },

                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = rowIdField },
                new FieldConfig { Name = "p02", Type = "hidden", MirrorName = "p02" },

                new FieldConfig
                {
                    Name = "p03",
                    Label = "تاريخ الإتلاف",
                    Type = "date",
                    ColCss = "6",
                    Required = true,
                    MirrorName = "p03"
                },
                new FieldConfig
                {
                    Name = "p04",
                    Label = "نوع الإتلاف",
                    Type = "select",
                    Options = scrapTypeOptions,
                    ColCss = "6",
                    Select2 = true,
                    Required = true,
                    MirrorName = "p04"
                },
                new FieldConfig { Name = "p05", Type = "hidden", MirrorName = "p05" },
                new FieldConfig
                {
                    Name = "p06",
                    Label = "السبب",
                    Type = "textarea",
                    ColCss = "12",
                    MaxLength = 400,
                    Required = true,
                    MirrorName = "p06"
                },
                new FieldConfig { Name = "p07", Type = "hidden", MirrorName = "p07" },
                new FieldConfig { Name = "p08", Type = "hidden", MirrorName = "p08" }
            };

            var viewFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Label = "رقم المحضر", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p12", Label = "رقم الجيش", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p02", Label = "رقم الهيكل", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p11", Label = "اللوحة", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p03", Label = "تاريخ الإتلاف", Type = "date", ColCss = "4", Readonly = true },
                new FieldConfig
                {
                    Name = "p04",
                    Label = "نوع الإتلاف",
                    Type = "select",
                    Options = scrapTypeOptions,
                    ColCss = "4",
                    Select2 = true,
                    Disabled = true
                },
                new FieldConfig { Name = "p06", Label = "السبب", Type = "textarea", ColCss = "12", Readonly = true },
                new FieldConfig { Name = "p10", Label = "الحالة", Type = "text", ColCss = "6", Readonly = true, MirrorName = "StatusText" },
                new FieldConfig { Name = "p09", Label = "تاريخ الاعتماد", Type = "date", ColCss = "6", Readonly = true }
            };

            var approveFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "APPROVE_SCRAP" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },

                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig
                {
                    Name = "p20",
                    Label = "ملاحظة الاعتماد",
                    Type = "textarea",
                    ColCss = "12",
                    MaxLength = 1000
                }
            };

            var cancelFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "CANCEL_SCRAP" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },

                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig
                {
                    Name = "p20",
                    Label = "سبب الإلغاء",
                    Type = "textarea",
                    ColCss = "12",
                    MaxLength = 1000,
                    Required = true
                }
            };

            #endregion

            #region Toolbar

            var toolbar = new TableToolbarConfig
            {
                ShowRefresh = true,
                ShowColumns = true,
                ShowExportCsv = false,
                ShowExportExcel = true,
                ShowExportPdf = true
            };

            if (canInsertScrap)
            {
                toolbar.ShowAdd = true;
                toolbar.Add = new TableAction
                {
                    Label = "إضافة محضر إتلاف",
                    Icon = "fa fa-plus",
                    Color = "success",
                    OnClickJs = "sfOpenScrapInsertModal",
                    OpenModal = true,
                    ModalTitle = "إضافة محضر إتلاف",
                    ModalMessage = "أدخل بيانات محضر الإتلاف",
                    ModalMessageIcon = "fa-solid fa-circle-info",
                    ModalMessageClass = "bg-green-50 text-green-700",
                    Meta = new Dictionary<string, object?>
                    {
                        ["smartDynamicFields"] = scrapReasonFieldsConfig
                    },
                    OpenForm = new FormConfig
                    {
                        FormId = "InsertScrapForm",
                        Title = "إضافة محضر إتلاف",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = insertFields,
                        Buttons = new List<FormButtonConfig>
                        {
                            new FormButtonConfig { Text = "حفظ", Type = "button", Color = "success", OnClickJs = "sfSubmitScrapInsert(this)" },
                            new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                        }
                    }
                };
            }

            // زر التعديل معطل مؤقتاً — محاضر الإتلاف لا تُعدّل بعد الحفظ
            // if (canUpdateScrap)
            // {
            //     toolbar.ShowEdit = true;
            //     toolbar.Edit = new TableAction
            //     {
            //         Label = "تعديل",
            //         Icon = "fa fa-edit",
            //         Color = "primary",
            //         IsEdit = true,
            //         OpenModal = true,
            //         ModalTitle = "تعديل محضر إتلاف",
            //         ModalMessage = "سيتم تعديل المحضر المحدد",
            //         ModalMessageIcon = "fa-solid fa-circle-info",
            //         ModalMessageClass = "bg-blue-50 text-blue-700",
            //         OpenForm = new FormConfig
            //         {
            //             FormId = "UpdateScrapForm",
            //             Title = "تعديل محضر إتلاف",
            //             Method = "post",
            //             ActionUrl = "/crud/update",
            //             Fields = updateFields,
            //             Buttons = new List<FormButtonConfig>
            //             {
            //                 new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
            //                 new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
            //             }
            //         },
            //         RequireSelection = true,
            //         MinSelection = 1,
            //         MaxSelection = 1
            //     };
            // }

            if (canSelect)
            {
                toolbar.ShowEdit1 = true;
                toolbar.Edit1 = new TableAction
                {
                    Label = "عرض",
                    Icon = "fa fa-eye",
                    Color = "info",
                    IsEdit = true,
                    OpenModal = true,

                    ModalTitle = "عرض محضر الإتلاف",
                    ModalMessage = "عرض فقط",
                    ModalMessageIcon = "fa-solid fa-circle-info",
                    ModalMessageClass = "bg-sky-100 text-sky-700",
                    OpenForm = new FormConfig
                    {
                        FormId = "ViewScrapForm",
                        Title = "",
                        Method = "post",
                        ActionUrl = "#",
                        SubmitText = "",
                        CancelText = "إغلاق",
                        Fields = viewFields
                    },
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1
                };
            }

            if (canApproveScrap)
            {
                toolbar.ShowDelete = true;
                toolbar.Delete = new TableAction
                {
                    Label = "اعتماد",
                    Icon = "fa fa-check",
                    Color = "success",
                    IsEdit = true,
                    OpenModal = true,

                    ModalTitle = "اعتماد محضر الإتلاف",
                    ModalMessage = "هل أنت متأكد من اعتماد محضر الإتلاف؟",
                    ModalMessageIcon = "fa fa-exclamation-triangle text-green-600",
                    ModalMessageClass = "bg-green-50 text-green-700",
                    OpenForm = new FormConfig
                    {
                        FormId = "ApproveScrapForm",
                        Title = "اعتماد محضر الإتلاف",
                        Method = "post",
                        ActionUrl = "/crud/update",
                        Fields = approveFields,
                        Buttons = new List<FormButtonConfig>
                        {
                            new FormButtonConfig { Text = "اعتماد", Type = "submit", Color = "success" },
                            new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                        }
                    },
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1
                };
            }

            if (canCancelScrap)
            {
                toolbar.ShowDelete1 = true;
                toolbar.Delete1 = new TableAction
                {
                    Label = "إلغاء",
                    Icon = "fa fa-times",
                    Color = "danger",
                    IsEdit = true,
                    OpenModal = true,

                    ModalTitle = "إلغاء محضر الإتلاف",
                    ModalMessage = "هل أنت متأكد من إلغاء محضر الإتلاف؟",
                    ModalMessageIcon = "fa fa-exclamation-triangle text-red-600",
                    ModalMessageClass = "bg-red-50 text-red-700",
                    OpenForm = new FormConfig
                    {
                        FormId = "CancelScrapForm",
                        Title = "إلغاء محضر الإتلاف",
                        Method = "post",
                        ActionUrl = "/crud/update",
                        Fields = cancelFields,
                        Buttons = new List<FormButtonConfig>
                        {
                            new FormButtonConfig { Text = "تأكيد الإلغاء", Type = "submit", Color = "danger" },
                            new FormButtonConfig { Text = "رجوع", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                        }
                    },
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1
                };
            }

            if (canPrint)
            {
                toolbar.ShowDelete2 = true;
                toolbar.Delete2 = new TableAction
                {
                    Label = "طباعة",
                    Icon = "fa fa-print",
                    Color = "secondary",
                    IsEdit = true,
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    OnClickJs = @"
                        const selectedRows = table.getSelectedRows();
                        if (selectedRows.length === 1) {
                            const row = selectedRows[0];
                            const rowId = row.ScrapID || row.scrapID || row.p01;
                            if (!rowId) { toastr.warning('تعذر تحديد رقم المحضر'); return; }
                            sfPrintWithBusy(table, {
                                pdf: 2,
                                extraParams: { rowId: rowId },
                                busy: { title: 'طباعة محضر الإتلاف' }
                            });
                        }
                    "
                };
            }

            #endregion

            #region Style Rules

            var draftRule = new TableStyleRule
            {
                Target = "row", Field = "Status", Op = "eq", Value = "Draft",
                Priority = 1, PillEnabled = true,
                PillField = "StatusText", PillTextField = "StatusText",
                PillCssClass = "pill pill-yellow", PillMode = "replace"
            };

            var approvedRule = new TableStyleRule
            {
                Target = "row", Field = "Status", Op = "eq", Value = "Approved",
                Priority = 1, PillEnabled = true,
                PillField = "StatusText", PillTextField = "StatusText",
                PillCssClass = "pill pill-green", PillMode = "replace"
            };

            var cancelledRule = new TableStyleRule
            {
                Target = "row", Field = "Status", Op = "eq", Value = "Cancelled",
                Priority = 1, PillEnabled = true,
                PillField = "StatusText", PillTextField = "StatusText",
                PillCssClass = "pill pill-gray", PillMode = "replace"
            };

            #endregion

            #region SmartTableDsModel

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "الإتلاف",
                PanelTitle = "محاضر الإتلاف",
                Columns = columns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = new List<string>
                {
                    "ScrapID", "chassisNumber_FK", "plateDisplay",
                    "armyNumber", "Reason", "StatusText"
                },
                Searchable = true,
                AllowExport = true,
                Toolbar = toolbar,
                StyleRules = new List<TableStyleRule> { draftRule, approvedRule, cancelledRule }
            };

            #endregion

            #region Print Scrap Worksheet (pdf = 2)

            if (pdf == 2)
            {
                if (!rowId.HasValue)
                    return Content("خطأ: لم يتم استلام معرف طلب التشليح");

                var selectedRow = rowsList.FirstOrDefault(r =>
                    r.TryGetValue("ScrapID", out var id) &&
                    id != null && Convert.ToInt32(id) == rowId.Value);

                if (selectedRow == null)
                    return Content($"لم يتم العثور على بيانات طلب التشليح. رقم الطلب: {rowId}");

                string scrapId = selectedRow.GetValueOrDefault("ScrapID")?.ToString() ?? "";
                string jobOrderNumber = selectedRow.GetValueOrDefault("jobOrderNumber")?.ToString()
                    ?? selectedRow.GetValueOrDefault("JobOrderNumber")?.ToString()
                    ?? scrapId;

                string armyNumber = selectedRow.GetValueOrDefault("armyNumber")?.ToString()
                    ?? selectedRow.GetValueOrDefault("ArmyNo")?.ToString()
                    ?? "";

                string scrapChassis = selectedRow.GetValueOrDefault("chassisNumber")?.ToString()
                    ?? selectedRow.GetValueOrDefault("chassisNumber_FK")?.ToString()
                    ?? "";

                string plateLetters = selectedRow.GetValueOrDefault("plateLetters")?.ToString() ?? "";
                string plateNumbers = selectedRow.GetValueOrDefault("plateNumbers")?.ToString() ?? "";
                string plate = $"{plateLetters} {plateNumbers}".Trim();

                string vehicleDesc = selectedRow.GetValueOrDefault("vehicleDesc")?.ToString()
                    ?? selectedRow.GetValueOrDefault("VehicleDesc")?.ToString()
                    ?? selectedRow.GetValueOrDefault("vehicleName")?.ToString()
                    ?? plate;

                DateTime? scrapDate = selectedRow.GetValueOrDefault("ScrapDate") as DateTime?;
                string scrapDateStr = scrapDate?.ToString("yyyy/MM/dd") ?? "";

                string reasonText = selectedRow.GetValueOrDefault("Reason")?.ToString()
                    ?? selectedRow.GetValueOrDefault("reason")?.ToString()
                    ?? "";

                string reasonHeader = "بعد الكشف على العربة الموضح بياناتها أعلاه وجد بها الأسباب التالية";

                var reasons = reasonText
                    .Replace("\r\n", "\n")
                    .Replace("\r", "\n")
                    .Split('\n', StringSplitOptions.RemoveEmptyEntries)
                    .Select(x => x.Trim())
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .Where(x => !x.Contains("بعد الكشف على العربة"))
                    .Where(x => !x.Contains("الأسباب التالية"))
                    .Select(x =>
                    {
                        x = System.Text.RegularExpressions.Regex.Replace(x, @"^\s*[\d٠-٩]+\s*[\.\-\)]\s*", "");
                        return x.Trim();
                    })
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .ToList();

                LetterTableCell H(string ar, string en, int span = 1, float size = 6.4f) => new LetterTableCell
                {
                    Text = $"{ar}\n{en}",
                    Bold = true,
                    Align = TextAlign.Center,
                    BackgroundColor = "#FFFFFF",
                    FontSize = size,
                    ColumnSpan = span
                };

                LetterTableCell V(string text = "", int span = 1, TextAlign align = TextAlign.Center, float size = 7f) => new LetterTableCell
                {
                    Text = text,
                    Bold = false,
                    Align = align,
                    BackgroundColor = "#FFFFFF",
                    FontSize = size,
                    ColumnSpan = span
                };

                LetterTableCell B(string text = "", int span = 1, TextAlign align = TextAlign.Center, float size = 7f) => new LetterTableCell
                {
                    Text = text,
                    Bold = true,
                    Align = align,
                    BackgroundColor = "#FFFFFF",
                    FontSize = size,
                    ColumnSpan = span
                };

                LetterTableCell R(string text, int span = 1, float size = 6.4f) => new LetterTableCell
                {
                    Text = text,
                    Bold = true,
                    Align = TextAlign.Right,
                    BackgroundColor = "#FFFFFF",
                    FontSize = size,
                    ColumnSpan = span
                };

                var worksheet = ReportTableFactory.CreateOfficialTable(
                    new List<float> { 1.7f, 1.8f, 2.0f, 2.4f, 2.4f, 1.5f, 2.2f, 2.2f, 2.2f, 3.5f, 3.8f, 3.8f }
                );

                worksheet.ExtendVertical = false;
                worksheet.BorderWidth = 1.1f;
                worksheet.BorderColor = "#000000";
                worksheet.CellPadding = 1.8f;
                worksheet.MinRowHeight = 28f;

    worksheet.Rows.Add(new LetterTableRow
    {
        Cells = new()
        {
            H("١- الوحدة", "UNIT", 2),
            H("٢- التسمية والموديل", "NOMENCLATURE & MODEL", 5),
            H("٣- رقم أمر العمل", "JOB ORDER NO.", 5)
        }
    });

    worksheet.Rows.Add(new LetterTableRow
    {
        Cells = new()
        {
            V("60-60", 2, TextAlign.Center, 7.2f),
            V(vehicleDesc, 5, TextAlign.Center, 7.2f),
            V("", 5, TextAlign.Center, 7.2f)
        }
    });

    worksheet.Rows.Add(new LetterTableRow
    {
        Cells = new()
        {
            H("٤- نوع التفتيش", "TYPE INSPECTION", 2),
            H("٥- التاريخ", "DATE", 2),
            H("٦- عدد الطلقات", "ROUND FIRED", 2),
            H("٧- الساعات", "HOURS", 2),
            H("٨- الأميال", "MILES", 1),
            H("٩- رقم التخزين / التسجيل / التسلسل", "REGISTRATION / SERIAL / FSN", 3)
        }
    });

    worksheet.Rows.Add(new LetterTableRow
    {
        Cells = new()
        {
            V("أولي", 2, TextAlign.Center, 7.2f),
            V(scrapDateStr, 2, TextAlign.Center, 7.2f),
            V("", 2),
            V("", 2),
            V("", 1),
            V(!string.IsNullOrWhiteSpace(armyNumber) ? armyNumber : scrapChassis, 3, TextAlign.Center, 7.2f)
        }
    });

    worksheet.Rows.Add(new LetterTableRow
    {
        Cells = new()
        {
            H("١٠- المرجع المناسب", "APPLICABLE REFERENCE", 3),
            R("تاريخ الكراسة الفنية:\nTM DATE:", 6, 6.4f),
            H("١١- عدد ساعات الإصلاح", "MANHOURS", 3)
        }
    });

    worksheet.Rows.Add(new LetterTableRow
    {
        Cells = new()
        {
            V("", 3),
            R("رقم الكراسة الفنية:\nTM NUMBER:", 6, 6.4f),
            V("", 3)
        }
    });

    worksheet.Rows.Add(new LetterTableRow
    {
        Cells = new()
        {
            H("١٢- تاريخ الانتهاء من الإصلاح", "COMPLETION DATE", 2),
            H("١٣- توقيع المشرف على الصيانة", "SIG. MAINT. SUPERVISOR", 3),
            H("١٤- توقيع الذين قاموا بالتفتيش الأولي", "SIG. INITIAL INSP.", 3),
            H("١٥- توقيع الذين قاموا بالتفتيش النهائي", "SIG. FINAL INSP.", 4)
        }
    });

    worksheet.Rows.Add(new LetterTableRow
    {
        Cells = new()
        {
            V("\n\n", 2),
            V("رئيس الرقباء\nمنصور مشبب آل زهر\n\n", 3, TextAlign.Center, 7f),
            V("الموظف م8\nياسر سعد القحطاني\n\n", 3, TextAlign.Center, 7f),
            V("\n\n", 4)
        }
    });

    worksheet.Rows.Add(new LetterTableRow
    {
        Cells = new()
        {
            H("١٦- رقم وتوقيع من قام بالإصلاح", "INITIAL WHEN CORRECTED", 2, 5.5f),
            H("١٧- الأعطال والقصور", "DEFICIENCIES & SHORTCOMINGS", 4, 6f),
            H("١٨- الإجراء التصحيحي", "CORRECTIVE ACTION", 3, 6f),
            H("١٩- رقم التخزين الفيدرالي للقطعة", "FSN", 2, 5.5f),
            H("٢٠- مستوى خط الإصلاح", "MAINT. LEVEL", 1, 5.5f)
        }
    });

    worksheet.Rows.Add(new LetterTableRow
    {
        Cells = new()
        {
            V("", 2),
            V($"{reasonHeader}:", 9, TextAlign.Right, 7.1f),
            V("", 1)
        }
    });

    for (int i = 0; i < 8; i++)
    {
        string reason = i < reasons.Count ? $"{i + 1}. {reasons[i]}" : $"{i + 1}.";

        worksheet.Rows.Add(new LetterTableRow
        {
            ExtendVertical = true,
            Cells = new()
            {
                V("", 2),
                V(reason, 9, TextAlign.Right, 6.9f),
                V("", 1)
            }
        });
    }

    worksheet.Rows.Add(new LetterTableRow
    {
        Cells = new()
        {
            V("", 2),
            V("تكلفة إصلاح المركبة تفوق قيمة المركبة، لذا أُعد هذا التقرير لغرض تشليح المركبة وإسقاطها.", 9, TextAlign.Center, 7.5f),
            V("", 1)
        }
    });

    worksheet.Rows.Add(new LetterTableRow
    {
        Cells = new()
        {
            V("فني\n\n\n\nحسين القحطاني\nفني ميكانيكي بنزين", 3, TextAlign.Center, 7f),
            V("فني\n\n\n\nإبراهيم الشهري\nفني ميكانيكي بنزين", 3, TextAlign.Center, 7f),
            V("رقيب أول\n\n\n\nمحمد عبدالله الأحمري\nمشرف شعبة البنزين", 3, TextAlign.Center, 7f),
            V("مصدق / رئيس رقباء\n\n\n\nمنصور مشبب آل زهر\nمدير قسم صيانة العربات", 3, TextAlign.Center, 7f)
        }
    });

                var report = new ReportResult
                {
                    ReportId = "ScrapWorksheet",
                    Title = "",
                    Kind = ReportKind.Letter,
                    Orientation = ReportOrientation.Portrait,
                    HeaderType = ReportHeaderType.Standard,
                    HeaderFields = new Dictionary<string, string>(),
                    ShowFooter = false,
                    LetterBlocks = new List<LetterBlock>
                    {
                        LetterBlockFactory.TextBlock(
                            "نموذج تفتيش وصيانة المعدات (كراسة القوات البرية الفنية رقم ٧٥٠-٢٨)",
                            fontSize: 8.6f,
                            bold: true,
                            align: TextAlign.Center,
                            paddingTop: 0,
                            paddingBottom: 0),

                        LetterBlockFactory.TextBlock(
                            "EQUIPMENT INSPECTION & MAINTENANCE WORKSHEET (SAATM 38-750)",
                            fontSize: 6.7f,
                            bold: true,
                            align: TextAlign.Center,
                            paddingTop: 0,
                            paddingBottom: 2),

                        LetterBlockFactory.TableBlock(
                            worksheet,
                            paddingTop: 6,
                            paddingBottom: 0,
                            paddingRight: 0,
                            paddingLeft: 0),

                        LetterBlockFactory.FooterBlock(
                            right: "نموذج القوات البرية رقم 2404",
                            center: "مطبعة سلاح الصيانة",
                            left: "LAND FORCES FORM 2404",
                            fontSize: 6.3f,
                            paddingTop: 4)
                    }
                };

                var pdfBytes = QuestPdfReportRenderer.Render(report);
                Response.Headers["Content-Disposition"] = $"inline; filename=ScrapWorksheet_{scrapId}.pdf";
                return File(pdfBytes, "application/pdf");
            }

            #endregion

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa fa-car-burst",
                TableDS = dsModel
            };

            return View("Page/Scrap", page);
        }
    }
}
