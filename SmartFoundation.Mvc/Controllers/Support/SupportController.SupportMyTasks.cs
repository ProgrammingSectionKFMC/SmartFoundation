using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers.Support
{
    public partial class SupportController : Controller
    {
        public async Task<IActionResult> SupportMyTasks(string? statusID = null)
        {
            if (!InitPageContext(out var redirect))
                return redirect!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = "Support";
            PageName = "SupportMyTasks";

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();
            var statusOptions = new List<OptionItem>();

            bool canUpdateTaskStatus = false;
            bool canAccess = false;

            try
            {
                var permissionProbeParameters = new object?[]
                {
                    "SupportMyTasks",
                    IdaraId,
                    usersId,
                    HostName,
                    null
                };

                DataSet permissionDs = await _mastersServies.GetDataLoadDataSetAsync(permissionProbeParameters);
                DataTable? permissions = (permissionDs?.Tables?.Count ?? 0) > 0 ? permissionDs.Tables[0] : null;

                if (permissions is null || permissions.Rows.Count == 0)
                {
                    TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                    return RedirectToAction("Index", "Home");
                }

                foreach (DataRow row in permissions.Rows)
                {
                    var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                    if (permissionName == "SMY_ACCESS" || permissionName == "SMY_SELECT") canAccess = true;
                    if (permissionName == "SMY_UPDATE_TASK_STATUS") canUpdateTaskStatus = true;
                }

                if (!canAccess || !canUpdateTaskStatus)
                {
                    TempData["Error"] = "هذه الصفحة مخصصة لموظفي معالجة المهام";
                    return RedirectToAction("Index", "Home");
                }

                bool hasSupervisorPermission = false;
                var supervisorProbeParameters = new object?[]
                {
                    "SupportTicketDetails",
                    IdaraId,
                    usersId,
                    HostName,
                    null
                };
                DataSet supervisorDs = await _mastersServies.GetDataLoadDataSetAsync(supervisorProbeParameters);
                DataTable? supervisorPermissions = (supervisorDs?.Tables?.Count ?? 0) > 0 ? supervisorDs.Tables[0] : null;
                if (supervisorPermissions != null)
                {
                    foreach (DataRow row in supervisorPermissions.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                        if (permissionName == "STD_ASSIGN" || permissionName == "STD_ADD_TASK" || permissionName == "STD_CHANGE_STATUS")
                        {
                            hasSupervisorPermission = true;
                            break;
                        }
                    }

                    if (hasSupervisorPermission)
                    {
                        TempData["Info"] = "هذه صفحة مهام الموظف. تم تحويلك إلى صفحة إدارة التذاكر";
                        return RedirectToAction(nameof(SupportTicketDetails));
                    }
                }
            }
            catch (Exception ex)
            {
                TempData["Error"] = ex.Message;
                return RedirectToAction("Index", "Home");
            }

            JsonResult? result;
            string json;

            result = await _CrudController.GetDDLValues(
                "statusName_A", "statusID", "6", nameof(SupportTicketDetails), usersId, IdaraId, HostName
            ) as JsonResult;
            json = JsonSerializer.Serialize(result?.Value);
            var loadedStatusOptions = JsonSerializer.Deserialize<List<OptionItem>>(json) ?? new List<OptionItem>();
            statusOptions.AddRange(loadedStatusOptions.Where(o => !string.IsNullOrWhiteSpace(o.Value)));

            result = await _CrudController.GetDDLValues(
                "ticketName", "ticketID", "5", nameof(SupportTicketDetails), usersId, IdaraId, HostName
            ) as JsonResult;
            json = JsonSerializer.Serialize(result?.Value);
            var ticketOptions = JsonSerializer.Deserialize<List<OptionItem>>(json) ?? new List<OptionItem>();

            string rowIdField = "ticketTaskID";
            bool columnsInitialized = false;

            foreach (var ticket in ticketOptions)
            {
                var ticketId = ticket.Value?.Trim();
                if (string.IsNullOrWhiteSpace(ticketId))
                    continue;
                if (!long.TryParse(ticketId, out _))
                    continue;

                var spParameters = new object?[]
                {
                    "SupportTicketDetails",
                    IdaraId,
                    usersId,
                    HostName,
                    ticketId
                };

                DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
                DataTable? ticketHeader = (ds?.Tables?.Count ?? 1) > 1 ? ds.Tables[1] : null;
                DataTable? taskTable = (ds?.Tables?.Count ?? 5) > 5 ? ds.Tables[5] : null;

                if (taskTable == null || taskTable.Rows.Count == 0)
                    continue;

                if (!columnsInitialized)
                {
                    var possibleIdNames = new[] { "ticketTaskID", "TicketTaskID" };
                    rowIdField = possibleIdNames.FirstOrDefault(n => taskTable.Columns.Contains(n)) ?? taskTable.Columns[0].ColumnName;

                    var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                    {
                        ["ticketNo"] = "رقم التذكرة",
                        ["ticketTitle"] = "عنوان التذكرة",
                        ["ticketTaskID"] = "رقم المهمة",
                        ["taskNo"] = "رقم المهمة",
                        ["taskTitle"] = "عنوان المهمة",
                        ["taskDescription"] = "وصف المهمة",
                        ["statusName_A"] = "حالة المهمة",
                        ["priorityName_A"] = "أولوية المهمة",
                        ["assignedToNationalID"] = "المكلف",
                        ["assignedDate"] = "تاريخ الإسناد",
                        ["dueDate"] = "تاريخ الاستحقاق",
                        ["completedDate"] = "تاريخ الإنجاز"
                    };

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "ticketNo",
                        Label = "رقم التذكرة",
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = "ticketTitle",
                        Label = "عنوان التذكرة",
                        Type = "text",
                        Sortable = true,
                        Visible = true
                    });

                    foreach (DataColumn c in taskTable.Columns)
                    {
                        if (c.ColumnName.Equals("ticketNo", StringComparison.OrdinalIgnoreCase)
                            || c.ColumnName.Equals("ticketTitle", StringComparison.OrdinalIgnoreCase))
                            continue;

                        string colType = "text";
                        var t = c.DataType;
                        if (t == typeof(bool)) colType = "bool";
                        else if (t == typeof(DateTime)) colType = "date";
                        else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                                 || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                            colType = "number";

                        bool hidden =
                            c.ColumnName.Equals("ticketID_FK", StringComparison.OrdinalIgnoreCase)
                            || c.ColumnName.Equals("statusID_FK", StringComparison.OrdinalIgnoreCase)
                            || c.ColumnName.Equals("priorityID_FK", StringComparison.OrdinalIgnoreCase)
                            || c.ColumnName.Equals("assignedToTeamMemberID_FK", StringComparison.OrdinalIgnoreCase)
                            || c.ColumnName.Equals("assignedToUserID", StringComparison.OrdinalIgnoreCase)
                            || c.ColumnName.Equals("assignedToUserID_FK", StringComparison.OrdinalIgnoreCase);

                        dynamicColumns.Add(new TableColumn
                        {
                            Field = c.ColumnName,
                            Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                            Type = colType,
                            Sortable = true,
                            Visible = !hidden
                        });
                    }

                    columnsInitialized = true;
                }

                string ticketNo = ticketId;
                string ticketTitle = string.Empty;
                if (ticketHeader != null && ticketHeader.Rows.Count > 0)
                {
                    if (ticketHeader.Columns.Contains("ticketNo"))
                        ticketNo = ticketHeader.Rows[0]["ticketNo"]?.ToString()?.Trim() ?? ticketNo;
                    if (ticketHeader.Columns.Contains("ticketTitle"))
                        ticketTitle = ticketHeader.Rows[0]["ticketTitle"]?.ToString()?.Trim() ?? string.Empty;
                }

                foreach (DataRow r in taskTable.Rows)
                {
                    bool isMine = false;

                    if (taskTable.Columns.Contains("assignedToUserID")
                        && string.Equals(r["assignedToUserID"]?.ToString()?.Trim(), usersId?.Trim(), StringComparison.OrdinalIgnoreCase))
                        isMine = true;

                    if (!isMine && taskTable.Columns.Contains("assignedToUserID_FK")
                        && string.Equals(r["assignedToUserID_FK"]?.ToString()?.Trim(), usersId?.Trim(), StringComparison.OrdinalIgnoreCase))
                        isMine = true;

                    if (!isMine && taskTable.Columns.Contains("assignedToNationalID")
                        && string.Equals(r["assignedToNationalID"]?.ToString()?.Trim(), NationalId?.Trim(), StringComparison.OrdinalIgnoreCase))
                        isMine = true;

                    if (!isMine)
                        continue;

                    if (!string.IsNullOrWhiteSpace(statusID)
                        && statusID != "-1"
                        && taskTable.Columns.Contains("statusID_FK")
                        && !string.Equals(r["statusID_FK"]?.ToString()?.Trim(), statusID.Trim(), StringComparison.OrdinalIgnoreCase))
                        continue;

                    var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                    dict["ticketNo"] = ticketNo;
                    dict["ticketTitle"] = ticketTitle;

                    foreach (DataColumn c in taskTable.Columns)
                    {
                        var val = r[c];
                        dict[c.ColumnName] = val == DBNull.Value ? null : val;
                    }

                    object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                    dict["p01"] = ticketId;
                    dict["p12"] = Get("ticketTaskID") ?? Get("TicketTaskID");
                    dict["p13"] = Get("statusID_FK");

                    rowsList.Add(dict);
                }
            }

            var filterForm = new FormConfig
            {
                Fields = new List<FieldConfig>
                {
                    new FieldConfig
                    {
                        SectionTitle = "فلترة المهام",
                        Name = "TaskStatusFilter",
                        Type = "select",
                        Select2 = true,
                        Options = statusOptions,
                        ColCss = "4",
                        Placeholder = "",
                        Value = statusID,
                        NavUrl = "/Support/SupportMyTasks",
                        NavKey = "statusID",
                        OnChangeJs = "sfNav(this)"
                    }
                },
                Buttons = new List<FormButtonConfig>()
            };

            var updateTaskStatusFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig { Name = "p12", Type = "hidden" },
                new FieldConfig { Name = "p13", Label = "حالة المهمة", Type = "select", ColCss = "6", Required = true, Placeholder = "", Options = statusOptions }
            };
            updateTaskStatusFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            updateTaskStatusFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            updateTaskStatusFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            updateTaskStatusFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            updateTaskStatusFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "SMY_UPDATE_TASK_STATUS" });
            updateTaskStatusFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = "SupportMyTasks" });
            updateTaskStatusFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            updateTaskStatusFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "مهامي",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = "المهام المسندة لي",
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowExportPdf = false,
                    ShowAdd = false,
                    ShowEdit = canUpdateTaskStatus,
                    ShowDelete = false,
                    ShowBulkDelete = false,
                    Edit = new TableAction
                    {
                        Label = "تحديث حالة المهمة",
                        Icon = "fa fa-pen-to-square",
                        Color = "primary",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تحديث حالة المهمة",
                        OpenForm = new FormConfig
                        {
                            FormId = "supportMyTasksUpdateTaskStatusForm",
                            Title = "تحديث الحالة",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Fields = updateTaskStatusFields
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
                PanelIcon = "fa-list-check",
                Form = filterForm,
                TableDS = dsModel
            };

            return View("SupportMyTasks", page);
        }
    }
}
