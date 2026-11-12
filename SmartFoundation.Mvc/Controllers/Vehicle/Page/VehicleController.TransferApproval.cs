using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;

namespace SmartFoundation.Mvc.Controllers.Vehicle
{
    public partial class VehicleController : Controller
    {
        public async Task<IActionResult> TransferApproval(
              int pageNumber = 1
            , int pageSize = 50
        )
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = "Vehicle";
            PageName = "TransferApproval";

            long.TryParse(usersId, out long userIdLong);

            #region Tab 1 — Pending Approval (main DataLoad with permissions)

            var pendingParams = new object?[]
            {
                PageName, IdaraId, usersId, HostName,
                userIdLong > 0 ? userIdLong : (long?)null,
                pageNumber, pageSize
            };

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(pendingParams);
            SplitDataSet(ds);

            var pendingColumns = new List<TableColumn>
            {
                new TableColumn { Field = "RequestID", Label = "رقم الطلب", Sortable = true, Visible = false },
                new TableColumn { Field = "chassisNumber_FK", Label = "رقم الهيكل", Sortable = true, Visible = true },
                new TableColumn { Field = "plateNumbers", Label = "رقم اللوحة", Sortable = true, Visible = true },
                new TableColumn { Field = "plateLetters", Label = "حروف اللوحة", Sortable = true, Visible = true },
                new TableColumn { Field = "FromUserName", Label = "من مستخدم", Sortable = true, Visible = true },
                new TableColumn { Field = "ToUserName", Label = "إلى مستخدم", Sortable = true, Visible = true },
                new TableColumn { Field = "entryDate", Label = "تاريخ الطلب", Sortable = true, Visible = true },
                new TableColumn { Field = "aproveNote", Label = "ملاحظات", Sortable = true, Visible = true },
            };

            var pendingRows = new List<Dictionary<string, object?>>();

            bool canAccess = false;
            bool canSelect = false;
            bool canApproveTransfer = false;
            bool canRejectTransfer = false;

            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable != null && permissionTable.Rows.Count > 0)
                {
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var p = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (p == "ACCESS") canAccess = true;
                        if (p == "SELECT") canSelect = true;
                        if (p == "APPROVETRANSFER") canApproveTransfer = true;
                        if (p == "REJECTTRANSFER") canRejectTransfer = true;
                    }

                    if (!canAccess && !canSelect)
                    {
                        TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                        return RedirectToAction("Index", "Home");
                    }
                }

                var dt1 = (ds?.Tables?.Count ?? 0) > 1 ? ds!.Tables[1] : null;

                if (dt1 != null && dt1.Columns.Count > 0)
                {
                    foreach (DataRow r in dt1.Rows)
                    {
                        var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                        foreach (DataColumn c in dt1.Columns)
                        {
                            var val = r[c];
                            dict[c.ColumnName] = val == DBNull.Value ? null : val;
                        }

                        object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;

                        dict["p01"] = Get("RequestID");
                        dict["p02"] = usersId;
                        dict["p03"] = "";

                        pendingRows.Add(dict);
                    }
                }
            }
            catch (Exception ex)
            {
                TempData["DataSetError"] = ex.Message;
            }

            if (!canAccess && !canSelect)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            #endregion

            #region Tab 2 — Approved (auxiliary DataLoad: DEPT_APPROVED)

            var approvedParams = new object?[]
            {
                "TransferApproval_Approved", IdaraId, usersId, HostName,
                userIdLong > 0 ? userIdLong : (long?)null,
                pageNumber, pageSize
            };

            DataSet dsApproved = await _mastersServies.GetDataLoadDataSetAsync(approvedParams);
            var approvedData = (dsApproved?.Tables?.Count ?? 0) > 1 ? dsApproved!.Tables[1] : null;

            var approvedColumns = new List<TableColumn>
            {
                new TableColumn { Field = "RequestID", Label = "رقم الطلب", Sortable = true, Visible = false },
                new TableColumn { Field = "chassisNumber_FK", Label = "رقم الهيكل", Sortable = true, Visible = true },
                new TableColumn { Field = "plateNumbers", Label = "رقم اللوحة", Sortable = true, Visible = true },
                new TableColumn { Field = "plateLetters", Label = "حروف اللوحة", Sortable = true, Visible = true },
                new TableColumn { Field = "RequestTypeNameA", Label = "نوع الطلب", Sortable = true, Visible = true },
                new TableColumn { Field = "FromUserName", Label = "من مستخدم", Sortable = true, Visible = true },
                new TableColumn { Field = "ToUserName", Label = "إلى مستخدم", Sortable = true, Visible = true },
                new TableColumn { Field = "LastActionDate", Label = "تاريخ الاعتماد", Sortable = true, Visible = true },
                new TableColumn { Field = "LastNotes", Label = "ملاحظات الاعتماد", Sortable = true, Visible = true },
            };

            var approvedRows = new List<Dictionary<string, object?>>();

            if (approvedData != null && approvedData.Columns.Count > 0)
            {
                foreach (DataRow r in approvedData.Rows)
                {
                    var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                    foreach (DataColumn c in approvedData.Columns)
                    {
                        var val = r[c];
                        dict[c.ColumnName] = val == DBNull.Value ? null : val;
                    }
                    approvedRows.Add(dict);
                }
            }

            #endregion

            #region Tab 3 — Department History (auxiliary DataLoad: DEPT_HISTORY)

            var deptHistoryParams = new object?[]
            {
                "TransferApproval_DeptHistory", IdaraId, usersId, HostName,
                userIdLong > 0 ? userIdLong : (long?)null,
                pageNumber, pageSize
            };

            DataSet dsDeptHistory = await _mastersServies.GetDataLoadDataSetAsync(deptHistoryParams);
            var deptHistoryData = (dsDeptHistory?.Tables?.Count ?? 0) > 1 ? dsDeptHistory!.Tables[1] : null;

            var deptHistoryColumns = new List<TableColumn>
            {
                new TableColumn { Field = "RequestID", Label = "رقم الطلب", Sortable = true, Visible = false },
                new TableColumn { Field = "chassisNumber_FK", Label = "رقم الهيكل", Sortable = true, Visible = true },
                new TableColumn { Field = "plateNumbers", Label = "رقم اللوحة", Sortable = true, Visible = true },
                new TableColumn { Field = "plateLetters", Label = "حروف اللوحة", Sortable = true, Visible = true },
                new TableColumn { Field = "RequestTypeNameA", Label = "نوع الطلب", Sortable = true, Visible = true },
                new TableColumn { Field = "FromUserName", Label = "من مستخدم", Sortable = true, Visible = true },
                new TableColumn { Field = "ToUserName", Label = "إلى مستخدم", Sortable = true, Visible = true },
                new TableColumn { Field = "LastStatus", Label = "الحالة", Sortable = true, Visible = true },
                new TableColumn { Field = "LastActionDate", Label = "تاريخ آخر إجراء", Sortable = true, Visible = true },
                new TableColumn { Field = "LastNotes", Label = "ملاحظات", Sortable = true, Visible = true },
            };

            var deptHistoryRows = new List<Dictionary<string, object?>>();

            if (deptHistoryData != null && deptHistoryData.Columns.Count > 0)
            {
                foreach (DataRow r in deptHistoryData.Rows)
                {
                    var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                    foreach (DataColumn c in deptHistoryData.Columns)
                    {
                        var val = r[c];
                        dict[c.ColumnName] = val == DBNull.Value ? null : val;
                    }
                    deptHistoryRows.Add(dict);
                }
            }

            #endregion

            #region Form Configs

            var approveTransferFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "TransferApproval" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "APPROVETRANSFER" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "" },

                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig { Name = "p02", Type = "hidden", Value = usersId },
                new FieldConfig
                {
                    Name = "p03",
                    Label = "ملاحظات الاعتماد",
                    Type = "textarea",
                    ColCss = "12",
                    MaxLength = 400,
                },
            };

            var rejectTransferFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "TransferApproval" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "REJECTTRANSFER" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "" },

                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig { Name = "p02", Type = "hidden", Value = usersId },
                new FieldConfig
                {
                    Name = "p03",
                    Label = "سبب الرفض",
                    Type = "textarea",
                    ColCss = "12",
                    Required = true,
                    MaxLength = 400,
                },
            };

            #endregion

            #region Tab 1 — Pending Approval Table

            var pendingCustomActions = new List<TableAction>();

            if (canApproveTransfer)
            {
                pendingCustomActions.Add(new TableAction
                {
                    Label = "اعتماد",
                    Icon = "fa-solid fa-check",
                    Color = "success",
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    OpenModal = true,
                    ModalTitle = "<i class='fa-solid fa-check text-emerald-600 text-xl mr-2'></i> اعتماد طلب النقل",
                    OpenForm = new FormConfig
                    {
                        FormId = "ApproveTransferForm",
                        Title = "اعتماد طلب النقل",
                        Method = "post",
                        ActionUrl = "/crud/update",
                        Fields = approveTransferFields,
                        Buttons = new List<FormButtonConfig>
                        {
                            new FormButtonConfig { Text = "اعتماد", Type = "submit", Color = "success" },
                            new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                        }
                    }
                });
            }

            if (canRejectTransfer)
            {
                pendingCustomActions.Add(new TableAction
                {
                    Label = "رفض",
                    Icon = "fa-solid fa-xmark",
                    Color = "danger",
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    OpenModal = true,
                    ModalTitle = "<i class='fa-solid fa-xmark text-red-600 text-xl mr-2'></i> رفض طلب النقل",
                    OpenForm = new FormConfig
                    {
                        FormId = "RejectTransferForm",
                        Title = "رفض طلب النقل",
                        Method = "post",
                        ActionUrl = "/crud/update",
                        Fields = rejectTransferFields,
                        Buttons = new List<FormButtonConfig>
                        {
                            new FormButtonConfig { Text = "رفض", Type = "submit", Color = "danger" },
                            new FormButtonConfig { Text = "تراجع", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                        }
                    }
                });
            }

            var dsModelPending = new SmartTableDsModel
            {
                PageTitle = "اعتماد طلبات النقل",
                PanelTitle = "بانتظار الاعتماد",
                Columns = pendingColumns,
                Rows = pendingRows,
                RowIdField = "RequestID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = pendingColumns.Where(c => c.Visible).Select(c => c.Field).Take(5).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowRowBorders = true,
                EnablePagination = true,
                ShowPageSizeSelector = true,
                ShowToolbar = true,
                EnableCellCopy = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                ShowColumnVisibility = true,

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsTab = true,
                TabGroupKey = "transfer-approval-page",
                TabKey = "pending-approval",
                TabLabel = "بانتظار الاعتماد",
                TabIcon = "fa-solid fa-hourglass-half",
                TabDefaultActive = true,
                ShowTabCount = true,
                TabOrder = 1,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = true,
                    ShowExportPdf = false,
                    ShowPrint1 = false,
                    ShowBulkDelete = false,
                    ShowAdd = false,
                    ShowEdit = false,
                    ShowDelete = false,
                    CustomActions = pendingCustomActions,
                },

                StyleRules = new List<TableStyleRule>(),
            };

            #endregion

            #region Tab 2 — Approved Table (view-only)

            var dsModelApproved = new SmartTableDsModel
            {
                PageTitle = "اعتماد طلبات النقل",
                PanelTitle = "طلبات معتمدة",
                Columns = approvedColumns,
                Rows = approvedRows,
                RowIdField = "RequestID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = approvedColumns.Where(c => c.Visible).Select(c => c.Field).Take(5).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowRowBorders = true,
                EnablePagination = true,
                ShowPageSizeSelector = true,
                ShowToolbar = true,
                EnableCellCopy = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                ShowColumnVisibility = true,

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsTab = true,
                TabGroupKey = "transfer-approval-page",
                TabKey = "approved-transfers",
                TabLabel = "معتمدة",
                TabIcon = "fa-solid fa-circle-check",
                TabDefaultActive = false,
                ShowTabCount = true,
                TabOrder = 2,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = true,
                    ShowExportPdf = false,
                    ShowPrint1 = false,
                    ShowBulkDelete = false,
                    ShowAdd = false,
                    ShowEdit = false,
                    ShowDelete = false,
                    CustomActions = new List<TableAction>(),
                },

                StyleRules = new List<TableStyleRule>(),
            };

            #endregion

            #region Tab 3 — Department History Table

            var dsModelDeptHistory = new SmartTableDsModel
            {
                PageTitle = "اعتماد طلبات النقل",
                PanelTitle = "سجل القسم",
                Columns = deptHistoryColumns,
                Rows = deptHistoryRows,
                RowIdField = "RequestID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = deptHistoryColumns.Where(c => c.Visible).Select(c => c.Field).Take(5).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowRowBorders = true,
                EnablePagination = true,
                ShowPageSizeSelector = true,
                ShowToolbar = true,
                EnableCellCopy = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                ShowColumnVisibility = true,

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsTab = true,
                TabGroupKey = "transfer-approval-page",
                TabKey = "dept-history",
                TabLabel = "السجل",
                TabIcon = "fa-solid fa-clock-rotate-left",
                TabDefaultActive = false,
                ShowTabCount = true,
                TabOrder = 3,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = true,
                    ShowExportPdf = false,
                    ShowPrint1 = false,
                    ShowBulkDelete = false,
                    ShowAdd = false,
                    ShowEdit = false,
                    ShowDelete = false,
                    CustomActions = new List<TableAction>(),
                },

                StyleRules = new List<TableStyleRule>
                {
                    new TableStyleRule
                    {
                        Target = "cell", Field = "LastStatus", Op = "eq", Value = "Created",
                        Priority = 1, PillEnabled = true, PillField = "LastStatus",
                        PillTextField = "LastStatus", PillCssClass = "pill pill-blue", PillMode = "replace"
                    },
                    new TableStyleRule
                    {
                        Target = "cell", Field = "LastStatus", Op = "eq", Value = "Approved",
                        Priority = 1, PillEnabled = true, PillField = "LastStatus",
                        PillTextField = "LastStatus", PillCssClass = "pill pill-green", PillMode = "replace"
                    },
                    new TableStyleRule
                    {
                        Target = "cell", Field = "LastStatus", Op = "eq", Value = "Rejected",
                        Priority = 1, PillEnabled = true, PillField = "LastStatus",
                        PillTextField = "LastStatus", PillCssClass = "pill pill-red", PillMode = "replace"
                    },
                    new TableStyleRule
                    {
                        Target = "cell", Field = "LastStatus", Op = "eq", Value = "Cancelled",
                        Priority = 1, PillEnabled = true, PillField = "LastStatus",
                        PillTextField = "LastStatus", PillCssClass = "pill pill-gray", PillMode = "replace"
                    },
                    new TableStyleRule
                    {
                        Target = "cell", Field = "LastStatus", Op = "eq", Value = "Closed",
                        Priority = 1, PillEnabled = true, PillField = "LastStatus",
                        PillTextField = "LastStatus", PillCssClass = "pill pill-gray", PillMode = "replace"
                    },
                }
            };

            #endregion

            var page = new SmartPageViewModel
            {
                PageTitle = dsModelPending.PageTitle,
                PanelTitle = dsModelPending.PanelTitle,
                PanelIcon = "fa-solid fa-clipboard-check",
                TableDS = dsModelPending,
                TableDS1 = dsModelApproved,
                TableDS2 = dsModelDeptHistory,
            };

            return View("TransferApproval", page);
        }
    }
}
