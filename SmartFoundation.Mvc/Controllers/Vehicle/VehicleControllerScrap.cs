using Microsoft.AspNetCore.Mvc;
using SmartFoundation.MVC.Reports;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartPrint;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Text.Json;
using static LLama.Common.ChatHistory;

namespace SmartFoundation.Mvc.Controllers.VIC
{
    public partial class VehiclesController : Controller
    {
        public async Task<IActionResult> Scrap(
              string? scrapID = null
            , string? chassisNumber = null
            , string? status = null
            , string? dateFrom = null
            , string? dateTo = null
            , int pageNumber = 1
            , int pageSize = 50
            , string? print = null
        )

        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = nameof(VehiclesController);
            PageName = "Scrap";

            var spParameters = new object?[]
            {
                PageName,
                IdaraId,
                usersId,
                HostName,
                string.IsNullOrWhiteSpace(scrapID) ? null : scrapID,
                string.IsNullOrWhiteSpace(chassisNumber) ? null : chassisNumber,
                string.IsNullOrWhiteSpace(status) ? null : status,
                string.IsNullOrWhiteSpace(dateFrom) ? null : dateFrom,
                string.IsNullOrWhiteSpace(dateTo) ? null : dateTo,
                pageNumber,
                pageSize
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();
            string rowIdField = "ScrapID";

            var scrapTypeOptions = new List<OptionItem>
            {
                new OptionItem { Value = "1", Text = "إتلاف نهائي" },
                new OptionItem { Value = "2", Text = "خارج الخدمة" }
            };

            var statusOptions = new List<OptionItem>
            {
                new OptionItem { Value = "Draft", Text = "Draft" },
                new OptionItem { Value = "Approved", Text = "Approved" },
                new OptionItem { Value = "Cancelled", Text = "Cancelled" }
            };

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

            SplitDataSet(ds);

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            bool canScrapList = false;
            bool canAddScrap = false;
            bool canUpdateScrap = false;
            bool canSelectScrap = false;
            bool canApproveScrap = false;
            bool canCancelScrap = false;

            try
            {
                foreach (DataRow row in permissionTable.Rows)
                {
                    var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                    if (permissionName == "SCRAP_LIST") canScrapList = true;
                    if (permissionName == "ADDSCRAP") canAddScrap = true;
                    if (permissionName == "UPDATESCRAP") canUpdateScrap = true;
                    if (permissionName == "SELECTSCRAP") canSelectScrap = true;
                    if (permissionName == "APPROVESCRAP") canApproveScrap = true;
                    if (permissionName == "CANCELSCRAP") canCancelScrap = true;
                }

                if (!canScrapList)
                {
                    TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                    return RedirectToAction("Index", "Home");
                }

                //مؤقتًا داخل الصفحة الرئيسية نفسها
                //bool canInsert = true;
                //bool canUpdate = true;
                //bool canApprove = true;
                //bool canCancel = true;

                var dataTable = (dt2 != null && dt2.Rows.Count > 0) ? dt2 : dt1;

                if (dataTable != null && dataTable.Columns.Count > 0)
                {
                    var possibleIdNames = new[] { "ScrapID", "scrapID", "Id", "ID" };
                    rowIdField = possibleIdNames.FirstOrDefault(n => dataTable.Columns.Contains(n))
                                 ?? dataTable.Columns[0].ColumnName;

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "ScrapID",
                        Label = "رقم المحضر",
                        Type = "number",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "chassisNumber_FK",
                        Label = "رقم الهيكل",
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "plateDisplay",
                        Label = "اللوحة",
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "armyNumber",
                        Label = "رقم الجيش",
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "ScrapDate",
                        Label = "تاريخ الإتلاف",
                        Type = "date",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "ScrapTypeText",
                        Label = "نوع الإتلاف",
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "RefNo",
                        Label = "المرجع",
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "Reason",
                        Label = "السبب",
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "Status",
                        Label = "الحالة",
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "ApprovedDateText",
                        Label = "تاريخ الاعتماد",
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });

                    foreach (DataRow r in dataTable.Rows)
                    {
                        var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

                        foreach (DataColumn c in dataTable.Columns)
                        {
                            var val = r[c];
                            dict[c.ColumnName] = val == DBNull.Value ? null : val;
                        }

                        object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;

                        var plateLetters = Get("plateLetters")?.ToString();
                        var plateNumbers = Get("plateNumbers")?.ToString();
                        var scrapTypeId = Get("ScrapTypeID_FK")?.ToString();
                        var statusValue = Get("Status")?.ToString()?.Trim();

                        dict["plateDisplay"] = string.IsNullOrWhiteSpace(plateLetters) && string.IsNullOrWhiteSpace(plateNumbers)
                            ? null
                            : $"{plateNumbers} {plateLetters}".Trim();

                        dict["ScrapTypeText"] = scrapTypeId switch
                        {
                            "1" => "إتلاف نهائي",
                            "2" => "خارج الخدمة",
                            _ => scrapTypeId
                        };

                        var approvedDateNormalized = NormalizeDateForInput(Get("ApprovedDate"));
                        dict["ApprovedDateText"] = string.IsNullOrWhiteSpace(approvedDateNormalized) ? "" : approvedDateNormalized;

                        dict["IsDraftRow"] = statusValue == "Draft" ? "1" : "0";
                        dict["IsApprovedRow"] = statusValue == "Approved" ? "1" : "0";
                        dict["IsCancelledRow"] = statusValue == "Cancelled" ? "1" : "0";

                        dict["p01"] = Get("ScrapID");
                        dict["p02"] = Get("chassisNumber_FK");
                        dict["p03"] = Get("ScrapDate");
                        dict["p04"] = Get("ScrapTypeID_FK");
                        dict["p05"] = Get("RefNo");
                        dict["p06"] = Get("Reason");
                        dict["p07"] = Get("Note");
                        dict["p08"] = Get("Notes");
                        dict["p09"] = Get("ApprovedDate");
                        dict["p10"] = Get("Status"); ;
                        dict["p11"] = Get("plateDisplay");
                        dict["p12"] = Get("armyNumber");

                        rowsList.Add(dict);
                    }
                }

            }
            catch (Exception ex)
            {
                TempData["DataSetError"] = ex.Message;
            }

                 var currentUrl = Request.Path + Request.QueryString;

                var insertFields = new List<FieldConfig>
                {
                    new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                    new FieldConfig { Name = "ActionType", Type = "hidden", Value = "ADDSCRAP" },
                    new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                    new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                    new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                    new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                    new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                    new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },

                    new FieldConfig
                    {
                        Name = "p01",
                        Label = "رقم الهيكل",
                        Type = "text",
                        ColCss = "6",
                        Required = true,
                        Placeholder = "أدخل رقم الهيكل"
                    },
                    new FieldConfig
                    {
                        Name = "p02",
                        Label = "تاريخ الإتلاف",
                        Type = "date",
                        ColCss = "6",
                        Required = true
                    },
                    new FieldConfig
                    {
                        Name = "p03",
                        Label = "نوع الإتلاف",
                        Type = "select",
                        Options = scrapTypeOptions,
                        ColCss = "6",
                        Select2 = true,
                        Required = true,
                        Placeholder = "اختر نوع الإتلاف"
                    },
                    new FieldConfig
                    {
                        Name = "p04",
                        Label = "المرجع",
                        Type = "text",
                        ColCss = "6",
                        MaxLength = 200
                    },
                    new FieldConfig
                    {
                        Name = "p05",
                        Label = "السبب",
                        Type = "textarea",
                        ColCss = "12",
                        MaxLength = 800,
                        Required = true
                    },
                    new FieldConfig
                    {
                        Name = "p06",
                        Label = "Note",
                        Type = "textarea",
                        ColCss = "12",
                        MaxLength = 2000
                    },
                    new FieldConfig
                    {
                        Name = "p07",
                        Label = "Notes",
                        Type = "textarea",
                        ColCss = "12",
                        MaxLength = 2000
                    }
                };

                var updateFields = new List<FieldConfig>
                {
                    new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                    new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATESCRAP" },
                    new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                    new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                    new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                    new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                    new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                    new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },

                    new FieldConfig { Name = rowIdField, Type = "hidden" },
                    new FieldConfig { Name = "p01", Type = "hidden", MirrorName = rowIdField },

                    new FieldConfig
                    {
                        Name = "p02",
                        Label = "رقم الهيكل",
                        Type = "text",
                        ColCss = "6",
                        Required = true,
                        MirrorName = "p02"
                    },
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
                    new FieldConfig
                    {
                        Name = "p05",
                        Label = "المرجع",
                        Type = "text",
                        ColCss = "6",
                        MaxLength = 200,
                        MirrorName = "p05"
                    },
                    new FieldConfig
                    {
                        Name = "p06",
                        Label = "السبب",
                        Type = "textarea",
                        ColCss = "12",
                        MaxLength = 800,
                        Required = true,
                        MirrorName = "p06"
                    },
                    new FieldConfig
                    {
                        Name = "p07",
                        Label = "Note",
                        Type = "textarea",
                        ColCss = "12",
                        MaxLength = 2000,
                        MirrorName = "p07"
                    },
                    new FieldConfig
                    {
                        Name = "p08",
                        Label = "Notes",
                        Type = "textarea",
                        ColCss = "12",
                        MaxLength = 2000,
                        MirrorName = "p08"
                    }
                };

                var viewFields = new List<FieldConfig>
                {
                    new FieldConfig { Name = "p01", Label = "رقم المحضر", Type = "text", ColCss = "4", Readonly = true },
                    new FieldConfig { Name = "p02", Label = "رقم الهيكل", Type = "text", ColCss = "4", Readonly = true },
                    new FieldConfig { Name = "p11", Label = "اللوحة", Type = "text", ColCss = "4", Readonly = true },

                    new FieldConfig { Name = "p12", Label = "رقم الجيش", Type = "text", ColCss = "4", Readonly = true },
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

                    new FieldConfig { Name = "p05", Label = "المرجع", Type = "text", ColCss = "6", Readonly = true },
                    new FieldConfig { Name = "p06", Label = "السبب", Type = "textarea", ColCss = "12", Readonly = true },
                    new FieldConfig { Name = "p07", Label = "Note", Type = "textarea", ColCss = "12", Readonly = true },
                    new FieldConfig { Name = "p08", Label = "Notes", Type = "textarea", ColCss = "12", Readonly = true },

                    new FieldConfig { Name = "p10", Label = "تاريخ الاعتماد", Type = "date", ColCss = "6", Readonly = true },
                    new FieldConfig { Name = "p09", Label = "الحالة", Type = "text", ColCss = "6", Readonly = true }
                };

                var approveFields = new List<FieldConfig>
                {
                    new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                    new FieldConfig { Name = "ActionType", Type = "hidden", Value = "APPROVESCRAP" },
                    new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                    new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                    new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                    new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                    new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                    new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },

                    new FieldConfig { Name = rowIdField, Type = "hidden" },
                    new FieldConfig { Name = "p01", Type = "hidden", MirrorName = rowIdField },
                    new FieldConfig { Name = "p02", Type = "hidden", Value = usersId },

                    new FieldConfig
                    {
                        Name = "p03",
                        Label = "ملاحظة الاعتماد",
                        Type = "textarea",
                        ColCss = "12",
                        MaxLength = 1000
                    }
                };

                var cancelFields = new List<FieldConfig>
                {
                   new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                   new FieldConfig { Name = "ActionType", Type = "hidden", Value = "CANCELSCRAP" },
                    new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                    new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                    new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                    new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                    new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                    new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },

                    new FieldConfig { Name = rowIdField, Type = "hidden" },
                    new FieldConfig { Name = "p01", Type = "hidden", MirrorName = rowIdField },
                    new FieldConfig { Name = "p02", Type = "hidden", Value = usersId },

                    new FieldConfig
                    {
                        Name = "p03",
                        Label = "ملاحظة الإلغاء",
                        Type = "textarea",
                        ColCss = "12",
                        MaxLength = 1000,
                        Required = true
                    }
                };

                var toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = true,
                    ShowExportPdf = true,
                    ShowAdd = true,
                    ShowEdit = true,
                    ShowEdit1 = true,
                    ShowDelete = true,
                    ShowDelete1 = true,
                    ShowDelete2 = true,
                    ShowBulkDelete = false
                };

                if (canAddScrap)
                {
                    toolbar.Add = new TableAction
                    {
                        Label = "إضافة محضر إتلاف",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة محضر إتلاف",
                        ModalMessage = "أدخل بيانات محضر الإتلاف",
                        ModalMessageIcon = "fa-solid fa-circle-info",
                        ModalMessageClass = "bg-green-50 text-green-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "InsertScrapForm",
                            Title = "إضافة محضر إتلاف",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            SubmitText = "حفظ",
                            CancelText = "إلغاء",
                            Fields = insertFields
                        }
                    };
                }

                if (canUpdateScrap)
                {
                    toolbar.Edit = new TableAction
                    {
                        Label = "تعديل",
                        Icon = "fa fa-edit",
                        Color = "primary",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل محضر إتلاف",
                        ModalMessage = "سيتم تعديل المحضر المحدد",
                        ModalMessageIcon = "fa-solid fa-circle-info",
                        ModalMessageClass = "bg-blue-50 text-blue-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "UpdateScrapForm",
                            Title = "تعديل محضر إتلاف",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ",
                            CancelText = "إلغاء",
                            Fields = updateFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    };
                }
                if (canSelectScrap)
                {
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
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
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
                            SubmitText = "اعتماد",
                            CancelText = "إلغاء",
                            Fields = approveFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    };
                }

                if (canCancelScrap)
                {
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
                            SubmitText = "تأكيد الإلغاء",
                            CancelText = "رجوع",
                            Fields = cancelFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    };
                }

                toolbar.Delete2 = new TableAction
                {
                    Label = "طباعة",
                    Icon = "fa fa-print",
                    Color = "secondary",
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    OnClickJs = @"
var rows = table.getSelectedRows();
if (!rows || rows.length !== 1) return false;

var r = rows[0];
var id = r.ScrapID || r.scrapID || r.p01;
if (!id) { alert('تعذر تحديد رقم المحضر'); return false; }

var url = '/Vehicle/Scrap?scrapID=' + encodeURIComponent(id) + '&print=1';
window.open(url, '_blank');
return false;"
                };

                var dsModel = new SmartTableDsModel
                {
                    PageTitle = "الإتلاف",
                    PanelTitle = "الإتلاف",
                    Columns = dynamicColumns,
                    Rows = rowsList,
                    RowIdField = rowIdField,
                    PageSize = 10,
                    PageSizes = new List<int> { 10, 25, 50, 100 },
                    QuickSearchFields = new List<string>
                    {
                        "ScrapID",
                        "chassisNumber_FK",
                        "plateDisplay",
                        "armyNumber",
                        "RefNo",
                        "Reason",
                        "Status"
                    },
                    Searchable = true,
                    AllowExport = true,
                    ShowRowBorders = false,
                    EnablePagination = true,
                    ShowPageSizeSelector = true,
                    ShowToolbar = true,
                    EnableCellCopy = false,
                    Toolbar = toolbar
                };

                ViewBag.FilterScrapID = scrapID;
                ViewBag.FilterChassisNumber = chassisNumber;
                ViewBag.FilterStatus = status;
                ViewBag.FilterDateFrom = dateFrom;
                ViewBag.FilterDateTo = dateTo;
                ViewBag.FilterPrint = print;
                ViewBag.StatusOptions = statusOptions;

                var page = new SmartPageViewModel
                {
                    PageTitle = dsModel.PageTitle,
                    PanelTitle = dsModel.PanelTitle,
                    PanelIcon = "fa fa-car-burst",
                    TableDS = dsModel
                };



            return View("Scrap", page);
           
        }
    }
}