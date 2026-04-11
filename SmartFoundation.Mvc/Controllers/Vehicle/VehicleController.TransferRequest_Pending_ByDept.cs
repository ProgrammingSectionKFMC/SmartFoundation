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
        public async Task<IActionResult> TransferRequest_Pending_ByDept()
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = nameof(VehicleController);
            PageName = string.IsNullOrWhiteSpace(PageName)
                ? "TransferRequest_Pending_ByDept"
                : PageName;

            var spParameters = new object?[]
            {
                PageName ?? "TransferRequest_Pending_ByDept",
                IdaraId,
                usersId,
                HostName,
                "60014017",   // @parameter_01 => @userID
                IdaraId,   // @parameter_02 => @idaraID_FK
                1,         // @parameter_03 => @pageNumber
                50         // @parameter_04 => @pageSize
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

            SplitDataSet(ds);

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            string rowIdField = "RequestID";

            bool canAccess = false;
            bool canSelect = false;
            bool canApprove = false;
            bool canReject = false;
            bool canCancel = false;

            try
            {
                foreach (DataRow row in permissionTable.Rows)
                {
                    var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                    if (permissionName == "ACCESS") canAccess = true;
                    if (permissionName == "SELECT") canSelect = true;
                    if (permissionName == "UPDATE")
                    {
                        canApprove = true;
                        canReject = true;
                    }
                    if (permissionName == "DELETE") canCancel = true;
                }

               

                var dataTable = dt3 ?? dt2 ?? dt1;

                if (dataTable != null && dataTable.Columns.Count > 0)
                {
                    var possibleIdNames = new[] { "RequestID", "requestID", "Id", "ID" };
                    rowIdField = possibleIdNames.FirstOrDefault(n => dataTable.Columns.Contains(n))
                                 ?? dataTable.Columns[0].ColumnName;

                    var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                    {
                        ["RequestID"] = "رقم الطلب",
                        ["chassisNumber_FK"] = "رقم الشاصي",
                        ["fromUserID_FK"] = "من المستخدم",
                        ["toUserID_FK"] = "إلى المستخدم",
                        ["deptID_FK"] = "القسم",
                        ["entryDate"] = "تاريخ الإنشاء",
                        ["aproveNote"] = "الملاحظات",
                        ["plateNumbers"] = "رقم اللوحة",
                        ["plateLetters"] = "حروف اللوحة",
                        ["armyNumber"] = "الرقم العسكري",
                        ["FromUserName"] = "من المستخدم",
                        ["ToUserName"] = "إلى المستخدم",
                        ["Status"] = "الحالة",
                        ["ActionDate"] = "تاريخ آخر إجراء"
                    };

                    foreach (DataColumn c in dataTable.Columns)
                    {
                        string colType = "text";
                        var t = c.DataType;

                        if (t == typeof(bool)) colType = "bool";
                        else if (t == typeof(DateTime)) colType = "date";
                        else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                              || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                            colType = "number";

                        bool isFromUserID = c.ColumnName.Equals("fromUserID_FK", StringComparison.OrdinalIgnoreCase);
                        bool isToUserID = c.ColumnName.Equals("toUserID_FK", StringComparison.OrdinalIgnoreCase);
                        bool isDeptID = c.ColumnName.Equals("deptID_FK", StringComparison.OrdinalIgnoreCase);

                        dynamicColumns.Add(new TableColumn
                        {
                            Field = c.ColumnName,
                            Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                            Type = colType,
                            Sortable = true,
                            Visible = !(isFromUserID || isToUserID || isDeptID)
                        });
                    }

                    foreach (DataRow r in dataTable.Rows)
                    {
                        var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

                        foreach (DataColumn c in dataTable.Columns)
                        {
                            var val = r[c];
                            dict[c.ColumnName] = val == DBNull.Value ? null : val;
                        }

                        object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;

                        dict["p01"] = Get("RequestID") ?? Get("requestID");
                        dict["p02"] = usersId;
                        dict["p03"] = Get("aproveNote");
                        dict["p04"] = Get("chassisNumber_FK");
                        dict["p05"] = Get("FromUserName");
                        dict["p06"] = Get("ToUserName");
                        dict["p07"] = Get("Status");

                        rowsList.Add(dict);
                    }
                }
            }
            catch (Exception ex)
            {
                TempData["DataSetError"] = ex.Message;
            }

            var currentUrl = Request.Path + Request.QueryString;

            var approveFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "TransferRequest_Approve" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATE" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = rowIdField },
                new FieldConfig { Name = "p02", Type = "hidden", Value = usersId },
                new FieldConfig
                {
                    Name = "p03",
                    Label = "ملاحظات الاعتماد",
                    Type = "textarea",
                    ColCss = "12",
                    MaxLength = 1000
                }
            };

            var rejectFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "TransferRequest_Reject" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATE" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = rowIdField },
                new FieldConfig { Name = "p02", Type = "hidden", Value = usersId },
                new FieldConfig
                {
                    Name = "p03",
                    Label = "سبب الرفض",
                    Type = "textarea",
                    ColCss = "12",
                    MaxLength = 1000,
                    Required = true
                }
            };

            var cancelFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "TransferRequest_Cancel" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "DELETE" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = rowIdField },
                new FieldConfig { Name = "p02", Type = "hidden", Value = usersId },
                new FieldConfig
                {
                    Name = "p03",
                    Label = "سبب الإلغاء",
                    Type = "textarea",
                    ColCss = "12",
                    MaxLength = 1000
                }
            };

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "طلبات النقل",
                PanelTitle = "طلبات النقل",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(5).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowRowBorders = false,
                EnablePagination = true,
                ShowPageSizeSelector = true,
                ShowToolbar = true,
                EnableCellCopy = false,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = true,
                    ShowExportPdf = true,

                    ShowEdit = canApprove,
                    ShowEdit1 = canReject,
                    ShowDelete = canCancel,
                    ShowBulkDelete = false,

                    Edit = new TableAction
                    {
                        Label = "اعتماد",
                        Icon = "fa fa-check",
                        Color = "success",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "اعتماد طلب نقل",
                        ModalMessage = "سيتم اعتماد الطلب المحدد",
                        ModalMessageIcon = "fa-solid fa-circle-info",
                        ModalMessageClass = "bg-green-50 text-green-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "TransferRequestApproveForm",
                            Title = "اعتماد طلب نقل",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "اعتماد",
                            CancelText = "إلغاء",
                            Fields = approveFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },

                    Edit1 = new TableAction
                    {
                        Label = "رفض",
                        Icon = "fa fa-times",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "رفض طلب نقل",
                        ModalMessage = "سيتم رفض الطلب المحدد",
                        ModalMessageIcon = "fa fa-exclamation-triangle text-red-600",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "TransferRequestRejectForm",
                            Title = "رفض طلب نقل",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "رفض",
                            CancelText = "إلغاء",
                            Fields = rejectFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },

                    Delete = new TableAction
                    {
                        Label = "إلغاء",
                        Icon = "fa fa-ban",
                        Color = "warning",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تحذير",
                        ModalMessage = "هل أنت متأكد من إلغاء طلب النقل؟",
                        ModalMessageIcon = "fa fa-exclamation-triangle text-red-600",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "TransferRequestCancelForm",
                            Title = "تأكيد إلغاء طلب النقل",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "إلغاء الطلب", Type = "submit", Color = "warning" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = cancelFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    }
                }
            };

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa fa-list",
                TableDS = dsModel
            };

            return View("TransferRequest_Pending_ByDept", page);
        }
    }
}