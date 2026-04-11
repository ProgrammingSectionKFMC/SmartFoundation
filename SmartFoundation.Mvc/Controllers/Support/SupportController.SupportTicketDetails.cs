using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Mvc.Helpers;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Text.Json;
using static QuestPDF.Helpers.Colors;

namespace SmartFoundation.Mvc.Controllers.Support
{
    public partial class SupportController : Controller
    {
        public async Task<IActionResult> SupportTicketDetails(long? ticketID)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = "Support";
            PageName = nameof(SupportTicketDetails);

            string? selectedTicketId = Request.Query["Q1"].FirstOrDefault();
            if (string.IsNullOrWhiteSpace(selectedTicketId) && ticketID.HasValue && ticketID.Value > 0)
                selectedTicketId = ticketID.Value.ToString();
            if (string.IsNullOrWhiteSpace(selectedTicketId))
                selectedTicketId = Request.Query["ticketID"].FirstOrDefault();

            selectedTicketId = string.IsNullOrWhiteSpace(selectedTicketId) ? null : selectedTicketId.Trim();
            bool ready = !string.IsNullOrWhiteSpace(selectedTicketId);

            List<OptionItem> ticketOptions = new();
            List<OptionItem> statusOptions = new();
            List<OptionItem> priorityOptions = new();
            List<OptionItem> memberOptions = new();

            JsonResult? result;
            string json;

            result = await _CrudController.GetDDLValues(
                "ticketName", "ticketID", "5", nameof(SupportTicketDetails), usersId, IdaraId, HostName
            ) as JsonResult;
            json = JsonSerializer.Serialize(result?.Value);
            ticketOptions = JsonSerializer.Deserialize<List<OptionItem>>(json) ?? new List<OptionItem>();

            result = await _CrudController.GetDDLValues(
                "statusName_A", "statusID", "6", nameof(SupportTicketDetails), usersId, IdaraId, HostName
            ) as JsonResult;
            json = JsonSerializer.Serialize(result?.Value);
            statusOptions = JsonSerializer.Deserialize<List<OptionItem>>(json) ?? new List<OptionItem>();

            result = await _CrudController.GetDDLValues(
                "priorityName_A", "priorityID", "7", nameof(SupportTicketDetails), usersId, IdaraId, HostName
            ) as JsonResult;
            json = JsonSerializer.Serialize(result?.Value);
            priorityOptions = JsonSerializer.Deserialize<List<OptionItem>>(json) ?? new List<OptionItem>();

            result = await _CrudController.GetDDLValues(
                "FullName", "teamMemberID", "8", nameof(SupportTicketDetails), usersId, IdaraId, HostName
            ) as JsonResult;
            json = JsonSerializer.Serialize(result?.Value);
            memberOptions = JsonSerializer.Deserialize<List<OptionItem>>(json) ?? new List<OptionItem>();

            var allowedTicketIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            try
            {
                foreach (var statusId in new[] { "2", "5" })
                {
                    var inboxSpParameters = new object?[]
                    {
                        "SupportInbox",
                        IdaraId,
                        usersId,
                        HostName,
                        statusId,
                        null,
                        null,
                        null,
                        null,
                        null,
                        null
                    };

                    DataSet inboxDs = await _mastersServies.GetDataLoadDataSetAsync(inboxSpParameters);
                    DataTable? inboxTickets = (inboxDs?.Tables?.Count ?? 0) > 1 ? inboxDs.Tables[1] : null;

                    if (inboxTickets == null || inboxTickets.Rows.Count == 0 || !inboxTickets.Columns.Contains("ticketID"))
                        continue;

                    foreach (DataRow row in inboxTickets.Rows)
                    {
                        var idVal = row["ticketID"]?.ToString()?.Trim();
                        if (string.IsNullOrWhiteSpace(idVal) || !allowedTicketIds.Add(idVal))
                            continue;

                        var no = inboxTickets.Columns.Contains("ticketNo") ? row["ticketNo"]?.ToString()?.Trim() : idVal;
                        var title = inboxTickets.Columns.Contains("ticketTitle") ? row["ticketTitle"]?.ToString()?.Trim() : "";
                        var txt = string.IsNullOrWhiteSpace(title) ? no : $"{no} - {title}";
                        ticketOptions.Add(new OptionItem { Value = idVal, Text = txt });
                    }
                }
            }
            catch
            {
            }

            
            FormConfig form = new();

            form = new FormConfig
            {
                Fields = new List<FieldConfig>
                {
                       new FieldConfig
                                {
                         SectionTitle = "اختيار التذكرة",
                        Name = "SelectedTicketId",
                        Type = "select",
                        Select2 = true,
                        Options = ticketOptions,
                        ColCss = "4",
                        Placeholder = "",
                        Icon = "fa fa-user",
                        Value = selectedTicketId,
                        NavUrl = "/Support/SupportTicketDetails",
                        NavKey = "Q1",
                        OnChangeJs = "sfNav(this)"
                                },
                     },
                Buttons = new List<FormButtonConfig>
                {

                }
            };

            if (ready && !allowedTicketIds.Contains(selectedTicketId!))
            {
                TempData["Warning"] = "التذكرة المختارة ليست ضمن التذاكر قيد المعالجة أو المعاد فتحها";
                ready = false;
            }

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();

            string rowIdField = "ticketTaskID";
            string ticketNo = selectedTicketId ?? "";
            string ticketTitle = "تفاصيل التذكرة";

            bool canAddReply = false;
            bool canChangeStatus = false;
            bool canAssign = false;
            bool canAddTask = false;
            bool hasOpenTasks = false;

            if (ready)
            {
                try
                {
                    var spParameters = new object?[]
                    {
                        PageName,
                        IdaraId,
                        usersId,
                        HostName,
                        selectedTicketId
                    };

                    DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
                    SplitDataSet(ds);

                    if (permissionTable is null || permissionTable.Rows.Count == 0)
                    {
                        TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                        return RedirectToAction("Index", "Home");
                    }

                    bool canAccess = false;
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                        if (permissionName == "STD_ACCESS" || permissionName == "STD_SELECT") canAccess = true;
                        if (permissionName == "STD_ADD_REPLY") canAddReply = true;
                        if (permissionName == "STD_CHANGE_STATUS") canChangeStatus = true;
                        if (permissionName == "STD_ASSIGN") canAssign = true;
                        if (permissionName == "STD_ADD_TASK") canAddTask = true;
                    }

                    bool isSupervisor = canChangeStatus || canAssign || canAddTask;
                    if (!canAccess || !isSupervisor)
                    {
                        TempData["Error"] = "هذه الصفحة مخصصة لمشرفي النظام فقط";
                        return RedirectToAction("Index", "Home");
                    }

                    if (dt1 != null && dt1.Rows.Count > 0)
                    {
                        ticketNo = dt1.Rows[0]["ticketNo"]?.ToString() ?? ticketNo;
                        ticketTitle = dt1.Rows[0]["ticketTitle"]?.ToString() ?? ticketTitle;
                    }

                    if (dt5 != null && dt5.Columns.Count > 0)
                    {
                        var possibleIdNames = new[] { "ticketTaskID", "TicketTaskID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt5.Columns.Contains(n)) ?? dt5.Columns[0].ColumnName;

                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["ticketTaskID"] = "رقم المهمة",
                            ["taskNo"] = "رقم المهمة",
                            ["taskTitle"] = "عنوان المهمة",
                            ["taskDescription"] = "وصف المهمة",
                            ["statusName_A"] = "الحالة",
                            ["priorityName_A"] = "الأولوية",
                            ["assignedToNationalID"] = "المسند إليه",
                            ["assignedDate"] = "تاريخ الإسناد",
                            ["dueDate"] = "تاريخ الاستحقاق",
                            ["completedDate"] = "تاريخ الإنجاز"
                        };

                        foreach (DataColumn c in dt5.Columns)
                        {
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

                        foreach (DataRow r in dt5.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt5.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = selectedTicketId;
                            dict["p12"] = Get("ticketTaskID") ?? Get("TicketTaskID");
                            dict["p13"] = Get("statusID_FK");
                            rowsList.Add(dict);

                            bool completed = false;
                            var statusText = Get("statusName_A")?.ToString()?.Trim() ?? string.Empty;
                            if (statusText.Contains("مكتمل", StringComparison.OrdinalIgnoreCase)
                                || statusText.Contains("منجز", StringComparison.OrdinalIgnoreCase)
                                || statusText.Contains("closed", StringComparison.OrdinalIgnoreCase)
                                || statusText.Contains("done", StringComparison.OrdinalIgnoreCase))
                                completed = true;

                            if (dt5.Columns.Contains("isCompleted") && bool.TryParse(Get("isCompleted")?.ToString(), out var isCompleted))
                                completed = isCompleted;

                            if (!completed)
                                hasOpenTasks = true;
                        }
                    }
                }
                catch (Exception ex)
                {
                    TempData["Error"] = ex.Message;
                    ready = false;
                }
            }

            bool IsCloseStatus(OptionItem opt)
            {
                var text = opt.Text?.Trim() ?? string.Empty;
                return text.Contains("اغلاق", StringComparison.OrdinalIgnoreCase)
                    || text.Contains("إغلاق", StringComparison.OrdinalIgnoreCase)
                    || text.Contains("مغلق", StringComparison.OrdinalIgnoreCase)
                    || text.Contains("مغلقة", StringComparison.OrdinalIgnoreCase)
                    || text.Contains("Closed", StringComparison.OrdinalIgnoreCase)
                    || text.Contains("Close", StringComparison.OrdinalIgnoreCase);
            }

            var ticketStatusOptions = hasOpenTasks
                ? statusOptions.Where(o => !IsCloseStatus(o)).ToList()
                : statusOptions;

            //if (hasOpenTasks)
            //    TempData["Warning"] = "لا يمكن إغلاق التذكرة قبل اكتمال جميع المهام المرتبطة بها";

            var addReplyFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Type = "hidden", Value = selectedTicketId },
                new FieldConfig { Name = "p02", Label = "نص الرد", Type = "textarea", ColCss = "12", Required = true },
                new FieldConfig
                {
                    Name = "p03",
                    Label = "نوع الرد",
                    Type = "select",
                    ColCss = "6",
                    Required = true,
                    Placeholder = "",
                    Options = new List<OptionItem>
                    {
                        new OptionItem { Value = "0", Text = "رد عام" },
                        new OptionItem { Value = "1", Text = "رد داخلي" }
                    }
                }
            };
            addReplyFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addReplyFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            addReplyFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            addReplyFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            addReplyFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "STD_ADD_REPLY" });
            addReplyFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            addReplyFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addReplyFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });
            addReplyFields.Insert(0, new FieldConfig { Name = "Q1", Type = "hidden", Value = selectedTicketId });

            var changeStatusFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Type = "hidden", Value = selectedTicketId },
                new FieldConfig { Name = "p04", Label = "حالة التذكرة", Type = "select", ColCss = "6", Required = true, Placeholder = "", Options = ticketStatusOptions }
            };
            changeStatusFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            changeStatusFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            changeStatusFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            changeStatusFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            changeStatusFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "STD_CHANGE_STATUS" });
            changeStatusFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            changeStatusFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            changeStatusFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });
            changeStatusFields.Insert(0, new FieldConfig { Name = "Q1", Type = "hidden", Value = selectedTicketId });

            var assignFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Type = "hidden", Value = selectedTicketId },
                new FieldConfig { Name = "p05", Label = "الموظف المحول إليه", Type = "select", ColCss = "6", Required = true, Placeholder = "", Options = memberOptions },
                new FieldConfig { Name = "p06", Label = "ملاحظة", Type = "textarea", ColCss = "12", Required = false }
            };
            assignFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            assignFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            assignFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            assignFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            assignFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "STD_ASSIGN" });
            assignFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            assignFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            assignFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });
            assignFields.Insert(0, new FieldConfig { Name = "Q1", Type = "hidden", Value = selectedTicketId });

            var addTaskFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Type = "hidden", Value = selectedTicketId },
                new FieldConfig { Name = "p07", Label = "عنوان المهمة", Type = "text", ColCss = "12", Required = true, MaxLength = 300 },
                new FieldConfig { Name = "p08", Label = "وصف المهمة", Type = "textarea", ColCss = "12", Required = false },
                new FieldConfig { Name = "p09", Label = "أولوية المهمة", Type = "select", ColCss = "6", Required = false, Placeholder = "", Options = priorityOptions },
                new FieldConfig { Name = "p10", Label = "الموظف المكلف", Type = "select", ColCss = "6", Required = true, Placeholder = "", Options = memberOptions },
                new FieldConfig { Name = "p11", Label = "تاريخ الاستحقاق", Type = "date", ColCss = "6", Required = false }
            };
            addTaskFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addTaskFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            addTaskFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            addTaskFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            addTaskFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "STD_ADD_TASK" });
            addTaskFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            addTaskFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addTaskFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });
            addTaskFields.Insert(0, new FieldConfig { Name = "Q1", Type = "hidden", Value = selectedTicketId });

            var dsModel = new SmartTableDsModel
            {
                PageTitle = $"تفاصيل التذكرة {ticketNo}",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = ticketTitle,
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowExportPdf = false,
                    ShowAdd = canAddReply,
                    ShowEdit = canChangeStatus,
                    ShowAdd1 = canAssign,
                    ShowAdd2 = canAddTask,
                    ShowEdit1 = false,
                    ShowDelete = false,
                    ShowBulkDelete = false,
                    Add = new TableAction
                    {
                        Label = "إضافة رد",
                        Icon = "fa fa-reply",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة رد على التذكرة",
                        OpenForm = new FormConfig
                        {
                            FormId = "supportTicketDetailsAddReplyForm",
                            Title = "الردود",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addReplyFields
                        }
                    },
                    Edit = new TableAction
                    {
                        Label = "تغيير الحالة",
                        Icon = "fa fa-arrows-rotate",
                        Color = "info",
                        OpenModal = true,
                        ModalTitle = "تغيير حالة التذكرة",
                        OpenForm = new FormConfig
                        {
                            FormId = "supportTicketDetailsChangeStatusForm",
                            Title = "الحالة",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Fields = changeStatusFields
                        }
                    },
                    Add1 = new TableAction
                    {
                        Label = "تحويل التذكرة",
                        Icon = "fa fa-share",
                        Color = "warning",
                        OpenModal = true,
                        ModalTitle = "تحويل التذكرة",
                        OpenForm = new FormConfig
                        {
                            FormId = "supportTicketDetailsAssignForm",
                            Title = "التحويل",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Fields = assignFields
                        }
                    },
                    Add2 = new TableAction
                    {
                        Label = "إضافة مهمة",
                        Icon = "fa fa-list-check",
                        Color = "secondary",
                        OpenModal = true,
                        ModalTitle = "إضافة مهمة جديدة",
                        OpenForm = new FormConfig
                        {
                            FormId = "supportTicketDetailsAddTaskForm",
                            Title = "المهام",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addTaskFields
                        }
                    }
                }
            };

            var vm = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-ticket",
                Form = form,
                TableDS = ready ? dsModel : null
            };

            return View("SupportTicketDetails", vm);
        }
    }
}
