using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;

namespace SmartFoundation.Mvc.Controllers.Support
{
    public partial class SupportController : Controller
    {
        public async Task<IActionResult> SupportInbox(
            string? statusID = null,
            string? priorityID = null,
            string? ticketTypeID = null,
            string? assignedToID = null,
            string? dateFrom = null,
            string? dateTo = null,
            string? searchText = null)
        {
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = "Support";
            PageName = string.IsNullOrWhiteSpace(PageName) ? "SupportInbox" : PageName;

            var spParameters = new object?[]
            {
                PageName ?? "SupportInbox",
                IdaraId,
                usersId,
                HostName,
                statusID,
                priorityID,
                ticketTypeID,
                assignedToID,
                dateFrom,
                dateTo,
                searchText
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();
            var statusOptions = new List<OptionItem>();
            var memberOptions = new List<OptionItem>();

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            SplitDataSet(ds);

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            bool canAccess = false;
            bool canAssign = false;
            bool canChangeStatus = false;
            bool canBulkAssign = false;

            foreach (DataRow row in permissionTable.Rows)
            {
                var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                if (permissionName == "SIN_ACCESS" || permissionName == "SIN_SELECT") canAccess = true;
                if (permissionName == "SIN_ASSIGN") canAssign = true;
                if (permissionName == "SIN_CHANGE_STATUS") canChangeStatus = true;
                if (permissionName == "SIN_BULK_ASSIGN") canBulkAssign = true;
            }
            // Ticket status updates are handled from SupportTicketDetails only.
            canChangeStatus = false;

            if (!canAccess)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            string rowIdField = "ticketID";

            try
            {
                if (dt1 != null)
                {
                    var possibleIdNames = new[] { "ticketID", "TicketID" };
                    rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                 ?? dt1.Columns[0].ColumnName;

                    var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                    {
                        ["ticketID"] = "الرقم المرجعي",
                        ["ticketNo"] = "رقم التذكرة",
                        ["ticketTitle"] = "العنوان",
                        ["ticketDescription"] = "الوصف",
                        ["ticketTypeName_A"] = "النوع",
                        ["priorityName_A"] = "الأولوية",
                        ["statusName_A"] = "الحالة",
                        ["createdByNationalID"] = "مقدم التذكرة",
                        ["assignedToNationalID"] = "المسند إليه",
                        ["affectedPageName"] = "الصفحة",
                        ["affectedActionName"] = "الإجراء",
                        ["entryDate"] = "تاريخ الإنشاء",
                        ["assignedDate"] = "تاريخ التحويل",
                        ["closedDate"] = "تاريخ الإغلاق"
                    };

                    foreach (DataColumn c in dt1.Columns)
                    {
                        string colType = "text";
                        var t = c.DataType;
                        if (t == typeof(bool)) colType = "bool";
                        else if (t == typeof(DateTime)) colType = "date";
                        else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                                 || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                            colType = "number";

                        bool hidden =
                            c.ColumnName.Equals("createdByUserID_FK", StringComparison.OrdinalIgnoreCase)
                            || c.ColumnName.Equals("assignedToTeamMemberID_FK", StringComparison.OrdinalIgnoreCase)
                            || c.ColumnName.Equals("assignedToUserID", StringComparison.OrdinalIgnoreCase);

                        dynamicColumns.Add(new TableColumn
                        {
                            Field = c.ColumnName,
                            Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                            Type = colType,
                            Sortable = true,
                            Visible = !hidden
                        });
                    }

                    foreach (DataRow r in dt1.Rows)
                    {
                        var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                        foreach (DataColumn c in dt1.Columns)
                        {
                            var val = r[c];
                            dict[c.ColumnName] = val == DBNull.Value ? null : val;
                        }

                        object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                        dict["p01"] = Get("ticketID") ?? Get("TicketID");
                        rowsList.Add(dict);
                    }
                }

                if (dt2 != null && dt2.Columns.Contains("statusID") && dt2.Columns.Contains("statusName_A"))
                {
                    foreach (DataRow r in dt2.Rows)
                    {
                        var value = r["statusID"]?.ToString()?.Trim();
                        var text = r["statusName_A"]?.ToString()?.Trim();
                        if (!string.IsNullOrWhiteSpace(value) && !string.IsNullOrWhiteSpace(text))
                            statusOptions.Add(new OptionItem { Value = value, Text = text });
                    }
                }

                if (dt5 != null && dt5.Columns.Contains("teamMemberID"))
                {
                    foreach (DataRow r in dt5.Rows)
                    {
                        var value = r["teamMemberID"]?.ToString()?.Trim();
                        var text = (r.Table.Columns.Contains("userName") ? r["userName"]?.ToString()?.Trim() : null)
                                   ?? (r.Table.Columns.Contains("nationalID") ? r["nationalID"]?.ToString()?.Trim() : null)
                                   ?? value;

                        if (!string.IsNullOrWhiteSpace(value) && !string.IsNullOrWhiteSpace(text))
                            memberOptions.Add(new OptionItem { Value = value, Text = text });
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.supportInboxDataSetError = ex.Message;
            }

            var assignFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig { Name = "p03", Label = "الموظف المحول إليه", Type = "select", ColCss = "6", Required = true, Placeholder = "", Options = memberOptions },
                new FieldConfig { Name = "p04", Label = "ملاحظة", Type = "textarea", ColCss = "12", Required = false }
            };
            assignFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            assignFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            assignFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            assignFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            assignFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "SIN_ASSIGN" });
            assignFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            assignFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            assignFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });

            var changeStatusFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig { Name = "p02", Label = "حالة التذكرة", Type = "select", ColCss = "6", Required = true, Placeholder = "", Options = statusOptions }
            };
            changeStatusFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            changeStatusFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            changeStatusFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            changeStatusFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            changeStatusFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "SIN_CHANGE_STATUS" });
            changeStatusFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            changeStatusFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            changeStatusFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });

            var bulkAssignFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p03", Label = "الموظف المحول إليه", Type = "select", ColCss = "6", Required = true, Placeholder = "", Options = memberOptions },
                new FieldConfig { Name = "p04", Label = "ملاحظة", Type = "textarea", ColCss = "12", Required = false },
                new FieldConfig { Name = "p05", Label = "أرقام التذاكر (CSV)", Type = "textarea", ColCss = "12", Required = true, Placeholder = "مثال: 101,102,103" }
            };
            bulkAssignFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            bulkAssignFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            bulkAssignFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            bulkAssignFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            bulkAssignFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "SIN_BULK_ASSIGN" });
            bulkAssignFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            bulkAssignFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            bulkAssignFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "صندوق تذاكر الدعم",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = "تذاكر الدعم",
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowExportPdf = false,
                    ShowAdd = canAssign,
                    ShowEdit = canChangeStatus,
                    ShowAdd1 = canBulkAssign,
                    ShowDelete = false,
                    ShowBulkDelete = false,
                    Add = new TableAction
                    {
                        Label = "تحويل تذكرة",
                        Icon = "fa fa-share",
                        Color = "warning",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تحويل التذكرة",
                        OpenForm = new FormConfig
                        {
                            FormId = "supportInboxAssignForm",
                            Title = "تحويل التذكرة",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Fields = assignFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                    Edit = new TableAction
                    {
                        Label = "تغيير الحالة",
                        Icon = "fa fa-arrows-rotate",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تحديث حالة التذكرة",
                        OpenForm = new FormConfig
                        {
                            FormId = "supportInboxChangeStatusForm",
                            Title = "حالة التذكرة",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Fields = changeStatusFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                    Add1 = new TableAction
                    {
                        Label = "تحويل جماعي",
                        Icon = "fa fa-users",
                        Color = "secondary",
                        OpenModal = true,
                        ModalTitle = "تحويل جماعي للتذاكر",
                        OpenForm = new FormConfig
                        {
                            FormId = "supportInboxBulkAssignForm",
                            Title = "تحويل جماعي",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Fields = bulkAssignFields
                        }
                    }
                }
            };

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-inbox",
                TableDS = dsModel
            };

            return View("SupportInbox", page);
        }
    }
}


