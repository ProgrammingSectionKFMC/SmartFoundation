using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Mvc.Helpers;
using SmartFoundation.UI.ViewModels.SmartDrawer;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers.Tickets
{
    public partial class TicketController : Controller
    {
        public async Task<IActionResult> TicketList()
        {
            if (!InitPageContext(out var redirect))
                return redirect!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = nameof(TicketController).Replace("Controller", "");
            PageName = "TicketList";

            string? filterStatusID = Request.Query["parameter_03"].FirstOrDefault();
            string? filterServiceID = Request.Query["parameter_04"].FirstOrDefault();
            string? filterDSDID = Request.Query["parameter_06"].FirstOrDefault();

            var spParameters = new object?[]
            {
                PageName,
                IdaraId,
                usersId,
                HostName,
                null,
                null,
                filterStatusID,
                filterServiceID,
                null,
                filterDSDID
            };

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            SplitDataSet(ds);

            if (IsFailedTicketListDataLoad(dt1))
            {
                TempData["Warning"] = "تعذر تحميل قائمة التذاكر عبر مسار البوابة.";
                dt1 = new DataTable();
            }

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            // ---- Permission flags (Housing pattern) ----
            bool canCreateTicket = false;
            bool canViewQualityInbox = false;
            bool canRouteTicket = false, canRejectTicket = false, canAssignTicket = false, canReassignTicket = false;
            bool canStartWork = false, canResolveTicket = false, canPauseTicket = false;
            bool canResumeTicket = false, canRaiseArbitration = false, canCreateChildTicket = false;
            bool canCloseTicket = false, canReopenTicket = false;
            bool canSubmitQualityReview = false, canFinalizeQualityReview = false;
            bool canUpdatePriority = false;
            bool canRequestClarification = false, canRespondClarification = false;

            foreach (DataRow row in permissionTable.Rows)
            {
                var perm = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                if (perm == "INSERT_TICKET") canCreateTicket = true;
                if (perm == "SUBMIT_QUALITY_REVIEW" || perm == "FINALIZE_QUALITY_REVIEW") canViewQualityInbox = true;
                if (perm == "ROUTE_TICKET") canRouteTicket = true;
                if (perm == "REJECT_TICKET") canRejectTicket = true;
                if (perm == "ASSIGN_TICKET") canAssignTicket = true;
                if (perm == "REASSIGN_TICKET") canReassignTicket = true;
                if (perm == "UPDATE_PRIORITY") canUpdatePriority = true;
                if (perm == "START_WORK") canStartWork = true;
                if (perm == "RESOLVE_TICKET") canResolveTicket = true;
                if (perm == "PAUSE_TICKET") canPauseTicket = true;
                if (perm == "RESUME_TICKET") canResumeTicket = true;
                if (perm == "RAISE_ARBITRATION") canRaiseArbitration = true;
                if (perm == "CREATE_CHILD_TICKET") canCreateChildTicket = true;
                if (perm == "CLOSE_TICKET") canCloseTicket = true;
                if (perm == "REOPEN_TICKET") canReopenTicket = true;
                if (perm == "SUBMIT_QUALITY_REVIEW") canSubmitQualityReview = true;
                if (perm == "FINALIZE_QUALITY_REVIEW") canFinalizeQualityReview = true;
                if (perm == "REQUEST_CLARIFICATION") canRequestClarification = true;
                if (perm == "RESPOND_CLARIFICATION") canRespondClarification = true;
            }

            // ---- Supplement permissions from TicketDetails page ----
            // Action permissions (INSERT_TICKET, ROUTE_TICKET, etc.) may be assigned to the
            // TicketDetails menu item rather than TicketList in the live permission data.
            // This second call ensures action buttons appear for users who have TicketDetails perms.
            try
            {
                var dsDetailPerms = await _mastersServies.GetDataLoadDataSetAsync(
                    "TicketDetails", IdaraId, usersId, HostName);
                var detailPermTable = (dsDetailPerms?.Tables?.Count ?? 0) > 0 ? dsDetailPerms!.Tables[0] : null;
                if (detailPermTable != null)
                {
                    foreach (DataRow row in detailPermTable.Rows)
                    {
                        var perm = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                        if (perm == "INSERT_TICKET") canCreateTicket = true;
                        if (perm == "SUBMIT_QUALITY_REVIEW" || perm == "FINALIZE_QUALITY_REVIEW") canViewQualityInbox = true;
                        if (perm == "ROUTE_TICKET") canRouteTicket = true;
                        if (perm == "REJECT_TICKET") canRejectTicket = true;
                        if (perm == "ASSIGN_TICKET") canAssignTicket = true;
                        if (perm == "REASSIGN_TICKET") canReassignTicket = true;
                        if (perm == "UPDATE_PRIORITY") canUpdatePriority = true;
                        if (perm == "START_WORK") canStartWork = true;
                        if (perm == "RESOLVE_TICKET") canResolveTicket = true;
                        if (perm == "PAUSE_TICKET") canPauseTicket = true;
                        if (perm == "RESUME_TICKET") canResumeTicket = true;
                        if (perm == "RAISE_ARBITRATION") canRaiseArbitration = true;
                        if (perm == "CREATE_CHILD_TICKET") canCreateChildTicket = true;
                        if (perm == "CLOSE_TICKET") canCloseTicket = true;
                        if (perm == "REOPEN_TICKET") canReopenTicket = true;
                        if (perm == "SUBMIT_QUALITY_REVIEW") canSubmitQualityReview = true;
                        if (perm == "FINALIZE_QUALITY_REVIEW") canFinalizeQualityReview = true;
                        if (perm == "REQUEST_CLARIFICATION") canRequestClarification = true;
                        if (perm == "RESPOND_CLARIFICATION") canRespondClarification = true;
                    }
                }
            }
            catch (Exception)
            {
                // silently ignore — supplemental perms are best-effort
            }

            List<OptionItem> statusOptions = new();
            List<OptionItem> serviceOptions = new();

            statusOptions = await GetTicketDdlOptionsAsync("ticketStatusName_A", "ticketStatusID", "2", PageName);
            serviceOptions = await GetTicketDdlOptionsAsync("serviceName_A", "serviceID", "3", PageName);

            // ---- DDLs for ticket actions ----
            List<OptionItem> pauseReasonOptions = new(), arbReasonOptions = new();
            List<OptionItem> qrResultOptions = new(), actionPriorityOptions = new(), actionClassOptions = new();
            List<OptionItem> clarificationReasonOptions = new(), clarificationTargetDsdOptions = new();
            List<OptionItem> dsdOptions = new();
            pauseReasonOptions = await GetTicketDdlOptionsAsync("pauseReasonName_A", "pauseReasonID", "1", "PauseReasonDDL");
            arbReasonOptions = await GetTicketDdlOptionsAsync("arbitrationReasonName_A", "arbitrationReasonID", "1", "ArbitrationReasonDDL");
            qrResultOptions = await GetTicketDdlOptionsAsync("qualityReviewResultName_A", "qualityReviewResultID", "1", "QualityReviewResultDDL");
            actionPriorityOptions = await GetTicketDdlOptionsAsync("priorityName_A", "priorityID", "1", "PriorityDDL");
            actionClassOptions = await GetTicketDdlOptionsAsync("ticketClassName_A", "ticketClassID", "1", "TicketClassDDL");
            clarificationReasonOptions = await GetClarificationReasonOptionsAsync();
            clarificationTargetDsdOptions = await GetServiceCatalogueDsdOptionsAsync();
            dsdOptions = await GetTicketDdlOptionsAsync("dsdName_A", "DSDID", "1", "DSDDL");

            var columns = new List<TableColumn>();
            var rows = new List<Dictionary<string, object?>>();

            if (dt1 != null && dt1.Columns.Count > 0)
            {
                var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                {
                    ["ticketID"] = "م",
                    ["ticketNo"] = "رقم التذكرة",
                    ["title"] = "العنوان",
                    ["serviceName_A"] = "الخدمة",
                    ["serviceName_E"] = "الخدمة (EN)",
                    ["requesterName"] = "مقدم الطلب",
                    ["requesterTypeName_A"] = "نوع مقدم الطلب",
                    ["requesterTypeName_E"] = "نوع مقدم الطلب (EN)",
                    ["priorityName_A"] = "الأولوية",
                    ["priorityName_E"] = "الأولوية (EN)",
                    ["ticketStatusName_A"] = "الحالة",
                    ["ticketStatusName_E"] = "الحالة (EN)",
                    ["ticketStatusCode"] = "رمز الحالة",
                    ["elapsedMinutes"] = "الدقائق المنقضية",
                    ["elapsedDisplay"] = "الوقت المنقضي",
                    ["assignedUserName"] = "المسند إليه",
                    ["currentDSDName_A"] = "الجهة الحالية",
                    ["assignedUserID_FK"] = "المستخدم المسؤول",
                    ["currentDSDID_FK"] = "القسم",
                    ["entryDate"] = "تاريخ الإنشاء"
                };

                var preferredColumnCandidates = new List<string[]>
                {
                    new[] { "ticketNo", "ticketNumber", "ticket_no" },
                    new[] { "title", "ticketTitle", "title_A" },
                    new[] { "serviceName_A", "serviceName", "serviceName_E" },
                    new[] { "requesterName" },
                    new[] { "priorityName_A", "priorityName", "priorityName_E" },
                    new[] { "ticketStatusName_A", "statusName", "ticketStatusName_E", "ticketStatusCode" },
                    new[] { "assignedUserName" },
                    new[] { "currentDSDName_A" },
                    new[] { "entryDate", "createdDate", "createdAt", "ticketDate" }
                };
                var actualColumnNames = dt1.Columns.Cast<DataColumn>()
                    .Select(column => column.ColumnName)
                    .ToList();
                var preferredVisibleFields = preferredColumnCandidates
                    .Select(candidates => actualColumnNames.FirstOrDefault(name => candidates.Contains(name, StringComparer.OrdinalIgnoreCase)))
                    .Where(name => !string.IsNullOrWhiteSpace(name))
                    .Select(name => name!)
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToList();
                var preferredVisibleFieldSet = new HashSet<string>(preferredVisibleFields, StringComparer.OrdinalIgnoreCase);
                bool usePreferredVisibility = preferredVisibleFields.Count >= 4;

                var hiddenCols = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
                {
                    "ticketID", "serviceName_E", "ticketStatusName_E", "ticketStatusCode",
                    "currentDSDID_FK", "assignedUserID_FK", "priorityName_E",
                    "requesterTypeName_E", "elapsedMinutes",
                    "requesterName", "requesterTypeName_A", "assignedUserName"
                };

                var forcedVisibleColumns = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
                {
                    "requesterName",
                    "assignedUserName",
                    "currentDSDName_A"
                };

                var statusFilterVals = new List<OptionItem>();
                var priorityFilterVals = new List<OptionItem>();
                var serviceFilterVals = new List<OptionItem>();

                if (dt1.Rows.Count > 0)
                {
                    bool hasStatusCol = dt1.Columns.Contains("ticketStatusName_A");
                    bool hasPriorityCol = dt1.Columns.Contains("priorityName_A");
                    bool hasServiceCol = dt1.Columns.Contains("serviceName_A");

                    if (hasStatusCol)
                        statusFilterVals = dt1.AsEnumerable()
                            .Select(r => r["ticketStatusName_A"] == DBNull.Value ? "" : r["ticketStatusName_A"]?.ToString()?.Trim())
                            .Where(s => !string.IsNullOrWhiteSpace(s))
                            .Distinct().OrderBy(s => s)
                            .Select(s => new OptionItem { Value = s!, Text = s! }).ToList();

                    if (hasPriorityCol)
                        priorityFilterVals = dt1.AsEnumerable()
                            .Select(r => r["priorityName_A"] == DBNull.Value ? "" : r["priorityName_A"]?.ToString()?.Trim())
                            .Where(s => !string.IsNullOrWhiteSpace(s))
                            .Distinct().OrderBy(s => s)
                            .Select(s => new OptionItem { Value = s!, Text = s! }).ToList();

                    if (hasServiceCol)
                        serviceFilterVals = dt1.AsEnumerable()
                            .Select(r => r["serviceName_A"] == DBNull.Value ? "" : r["serviceName_A"]?.ToString()?.Trim())
                            .Where(s => !string.IsNullOrWhiteSpace(s))
                            .Distinct().OrderBy(s => s)
                            .Select(s => new OptionItem { Value = s!, Text = s! }).ToList();
                }

                foreach (DataColumn col in dt1.Columns)
                {
                    string colType = GetColType(col.DataType);
                    bool isHidden = hiddenCols.Contains(col.ColumnName);
                    bool isVisible = forcedVisibleColumns.Contains(col.ColumnName) || (usePreferredVisibility
                        ? preferredVisibleFieldSet.Contains(col.ColumnName)
                        : !isHidden);
                    string label = headerMap.TryGetValue(col.ColumnName, out var lbl) ? lbl : col.ColumnName;

                    var tc = new TableColumn
                    {
                        Field = col.ColumnName,
                        Label = label,
                        Type = colType,
                        Sortable = true,
                        Visible = isVisible
                    };

                    // ticketNo → opens the ticket SmartDrawer (remote link handled by sf-drawer.js)
                    if (col.ColumnName == "ticketNo")
                    {
                        tc.Type = "link";
                        tc.LinkTemplate = "#sf-drawer:sf-ticket-drawer:/Ticket/TicketDrawer/{ticketID}";
                    }

                    // title → truncate long titles
                    if (col.ColumnName == "title")
                        tc.truncate = true;

                    // entryDate → use text type to preserve C# formatting
                    if (col.ColumnName == "entryDate")
                    {
                        tc.Type = "text";
                    }

                    // Column filters
                    if (col.ColumnName == "ticketStatusName_A")
                    {
                        tc.Filter = new TableColumnFilter
                        {
                            Enabled = true,
                            Type = "select",
                            Options = statusFilterVals
                        };
                    }
                    else if (col.ColumnName == "priorityName_A")
                    {
                        tc.Filter = new TableColumnFilter
                        {
                            Enabled = true,
                            Type = "select",
                            Options = priorityFilterVals
                        };
                    }
                    else if (col.ColumnName == "serviceName_A")
                    {
                        tc.Filter = new TableColumnFilter
                        {
                            Enabled = true,
                            Type = "select",
                            Options = serviceFilterVals
                        };
                    }
                    else
                    {
                        tc.Filter = new TableColumnFilter { Enabled = false };
                    }

                    columns.Add(tc);
                }

                if (usePreferredVisibility)
                {
                    var reorderedColumns = new List<TableColumn>();
                    foreach (var field in preferredVisibleFields)
                    {
                        var col = columns.FirstOrDefault(c => string.Equals(c.Field, field, StringComparison.OrdinalIgnoreCase));
                        if (col != null)
                            reorderedColumns.Add(col);
                    }

                    reorderedColumns.AddRange(columns.Where(c => !preferredVisibleFieldSet.Contains(c.Field)));

                    columns = reorderedColumns;
                }

                foreach (DataRow dr in dt1.Rows)
                {
                    var dict = new Dictionary<string, object?>();
                    foreach (DataColumn col in dt1.Columns)
                        dict[col.ColumnName] = dr[col] == DBNull.Value ? null : dr[col];
                    dict["p01"] = dict.ContainsKey("ticketID") ? dict["ticketID"] : null;

                    // Compute SLA elapsed display from elapsedMinutes
                    var elapsed = dict.ContainsKey("elapsedMinutes") && dict["elapsedMinutes"] != null
                        ? Convert.ToInt32(dict["elapsedMinutes"])
                        : (int?)null;
                    dict["elapsedDisplay"] = elapsed.HasValue
                        ? $"{elapsed.Value / 60}h {elapsed.Value % 60}m"
                        : null;

                    // Format entryDate as an English short month date.
                    if (dict.ContainsKey("entryDate") && dict["entryDate"] is DateTime entryDate)
                    {
                        dict["entryDate"] = entryDate.ToString("MMM d, yyyy", System.Globalization.CultureInfo.InvariantCulture);
                    }

                    rows.Add(dict);
                }

                if (canRespondClarification && rows.Count > 0)
                {
                    var openClarificationMap = await GetOpenClarificationRequestMapAsync(
                        rows.Select(row => long.TryParse(row.GetValueOrDefault("ticketID")?.ToString(), out var ticketId)
                            ? ticketId
                            : 0));

                    foreach (var row in rows)
                    {
                        var ticketId = long.TryParse(row.GetValueOrDefault("ticketID")?.ToString(), out var parsedTicketId)
                            ? parsedTicketId
                            : 0;

                        row["openClarificationRequestID"] = openClarificationMap.TryGetValue(ticketId, out var clarificationRequestId)
                            ? clarificationRequestId
                            : null;
                    }
                }
            }

            var styleRules = new List<TableStyleRule>
            {
                new() { Target="cell", Field="requesterName", Op="contains", Value="", Priority=0,
                    PillEnabled=true, PillField="requesterName", PillTextField="requesterTypeName_A",
                    PillCssClass="block mt-0.5 text-xs text-slate-500", PillMode="append" },

                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="NEW", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-gray", PillMode="replace" },

                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="ROUTED", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-blue", PillMode="replace" },

                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="ASSIGNED", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-blue", PillMode="replace" },

                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="IN_PROGRESS", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-green", PillMode="replace" },

                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="CLARIFICATION", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-yellow", PillMode="replace" },

                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="ARBITRATION", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-purple", PillMode="replace" },

                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="PAUSED", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-orange", PillMode="replace" },

                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="RESOLVED", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-green", PillMode="replace" },

                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="CLOSED", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-gray", PillMode="replace" },

                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="REJECTED", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-red", PillMode="replace" },

                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="REOPENED", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-yellow", PillMode="replace" },

                new() { Target="row", Field="priorityName_A", Op="eq", Value="حرج", Priority=2,
                    PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A",
                    PillCssClass="pill pill-red", PillMode="replace" },

                new() { Target="row", Field="priorityName_A", Op="eq", Value="مرتفع", Priority=2,
                    PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A",
                    PillCssClass="pill pill-orange", PillMode="replace", PillSvg = SfIcons.Check },


                new() { Target="row", Field="priorityName_A", Op="eq", Value="متوسط", Priority=2,
                    PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A",
                    PillCssClass="pill pill-blue", PillMode="replace" },

                new() { Target="row", Field="priorityName_A", Op="eq", Value="منخفض", Priority=2,
                    PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A",
                    PillCssClass="pill pill-green", PillMode="replace" },

                new() { Target="row", Field="priorityName_A", Op="eq", Value="مخطط", Priority=2,
                    PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A",
                    PillCssClass="pill pill-gray", PillMode="replace" }
            };

            var tabGroupKey = "ticket-inbox";

            var currentUrl = Request.Path + Request.QueryString;

            // p03 always carries the logged-in user's ID.
            // The JS requesterTypeToggle() handles showing/hiding p04 (resident) vs _p03display client-side.
            var requesterUserValue = usersId;

            var toolbar = new TableToolbarConfig
            {
                ShowAdd = canCreateTicket,
                ShowEdit = false,
                ShowDelete = false,
                ShowRefresh = true,
                ShowColumns = true,
                ShowExportExcel = true,
                ShowExportPdf = false
            };

            // Ticket SmartDrawer: content is loaded from /Ticket/TicketDrawer/{id} on ticket number click.
            toolbar.Drawers.Add(new SmartDrawerConfig
            {
                Id = "sf-ticket-drawer",
                Title = "تفاصيل التذكرة",
                Icon = "fa-solid fa-ticket",
                Side = SmartDrawerSide.Left,
                Size = SmartDrawerSize.Large,
                EmptyText = "جاري التحميل..."
            });

            if (canCreateTicket)
            {
                var addFields = await BuildCreateTicketFieldsAsync(requesterUserValue);

                toolbar.Add = new TableAction
                {
                    Label = "تذكرة جديدة",
                    Icon = "fa fa-plus",
                    Color = "success",
                    OpenModal = true,
                    ModalTitle = "إنشاء تذكرة جديدة",
                    OpenForm = new FormConfig
                    {
                        FormId = "createTicketForm",
                        Title = "إنشاء تذكرة جديدة",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = addFields,
                        Buttons = new List<FormButtonConfig>
                            {
                                new() { Text = "إرسال التذكرة", Type = "submit", Color = "success", Icon = "fa fa-paper-plane" },
                                new() { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                    }
                };
            }

            // ---- Ticket action buttons (HousingExtend pattern) ----
            var ticketActions = new List<TableAction>();

            if (canRouteTicket)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "توجيه",
                    Icon = "fa fa-route",
                    Color = "primary",
                    OpenModal = true,
                    ModalTitle = "توجيه",
                    Placement = TableActionPlacement.Button,
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                    OpenForm = new FormConfig
                    {
                        FormId = "routeTicketForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "ROUTE_TICKET" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden" },
                            new() { Label = "القسم", Name = "p03", Type = "select", Options = dsdOptions, Required = true, ColCss = "12", Select2 = true }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "notin", Value = "NEW,REOPENED", Message = "متاح فقط للتذاكر الجديدة أو المعاد فتحها", Priority = 1 }
                        }
                    }
                });
            }

            if (canRejectTicket)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "رفض",
                    Icon = "fa fa-ban",
                    Color = "danger",
                    OpenModal = true,
                    ModalTitle = "رفض",
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                    OpenForm = new FormConfig
                    {
                        FormId = "rejectTicketForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "REJECT_TICKET" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden" },
                            new() { Label = "سبب الرفض", Name = "p02", Type = "text", ColCss = "12" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "notin", Value = "NEW,REOPENED", Message = "متاح فقط للتذاكر الجديدة أو المعاد فتحها", Priority = 1 }
                        }
                    }
                });
            }

            if (canAssignTicket)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "تعيين",
                    Icon = "fa fa-user-plus",
                    Color = "primary",
                    OpenModal = true,
                    ModalTitle = "تعيين",
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                    OpenForm = new FormConfig
                    {
                        FormId = "assignTicketForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "ASSIGN_TICKET" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden" },
                            new() { Name = "currentDSDID_FK", Type = "hidden" },
                            new()
                            {
                                Label = "الموظف",
                                Name = "p02",
                                Type = "select",
                                Options = new List<OptionItem>(), // Initial empty state
                                Required = true,
                                ColCss = "6",
                                Select2 = true,
                                DependsOn = "currentDSDID_FK",
                                DependsUrl = "/crud/DDLFiltered?FK=DSDID&textcol=fullName_A&ValueCol=usersID&PageName=DsdUsersAllDDL&TableIndex=1"
                            }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "neq", Value = "ROUTED", Message = "متاح فقط للتذاكر الموجهة", Priority = 1 }
                        }
                    }
                });
            }

            if (canReassignTicket)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "إعادة إسناد",
                    Icon = "fa fa-user-pen",
                    Color = "warning",
                    OpenModal = true,
                    ModalTitle = "إعادة إسناد التذكرة",
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                    OpenForm = new FormConfig
                    {
                        FormId = "reassignTicketForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "REASSIGN_TICKET" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden" },
                            new() { Label = "القسم المستلم", Name = "p03", Type = "select", Options = dsdOptions, Required = true, ColCss = "12", Select2 = true },
                            new()
                            {
                                Label = "الموظف الجديد",
                                Name = "p02",
                                Type = "select",
                                Options = new List<OptionItem>(),
                                Required = true,
                                ColCss = "12",
                                Select2 = true,
                                DependsOn = "p03",
                                DependsUrl = "/crud/DDLFiltered?FK=DSDID&textcol=fullName_A&ValueCol=usersID&PageName=DsdUsersAllDDL&TableIndex=1"
                            }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "notin", Value = "ASSIGNED,IN_PROGRESS,PAUSED,CLARIFICATION", Message = "متاح فقط للتذاكر المعيّنة أو الجارية أو المتوقفة أو بانتظار التوضيح", Priority = 1 }
                        }
                    }
                });
            }

            if (canUpdatePriority)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "تعديل الأولوية",
                    Icon = "fa fa-signal",
                    Color = "warning",
                    OpenModal = true,
                    ModalTitle = "تعديل أولوية التذكرة",
                    Placement = TableActionPlacement.ActionsMenu,
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                    OpenForm = new FormConfig
                    {
                        FormId = "updatePriorityForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "UPDATE_PRIORITY" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden" },
                            new() { Label = "الأولوية الجديدة", Name = "p02", Type = "select", Options = actionPriorityOptions, Required = true, ColCss = "12", Select2 = true },
                            new() { Label = "ملاحظات", Name = "p03", Type = "text", ColCss = "12" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "in", Value = "CLOSED,REJECTED", Message = "غير متاح للتذاكر المغلقة أو المرفوضة", Priority = 1 }
                        }
                    }
                });
            }

            if (canStartWork)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "بدء العمل",
                    Icon = "fa fa-play",
                    Color = "success",
                    OpenModal = true,
                    ModalTitle = "بدء العمل",
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                    OpenForm = new FormConfig
                    {
                        FormId = "startWorkForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "START_WORK" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden" },
                            new() { Label = "ملاحظات", Name = "p02", Type = "text", ColCss = "12" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "notin", Value = "ASSIGNED,REOPENED", Message = "متاح فقط للتذاكر المعينة أو المعاد فتحها", Priority = 1 }
                        }
                    }
                });
            }

            if (canResolveTicket)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "حل",
                    Icon = "fa fa-check",
                    Color = "success",
                    OpenModal = true,
                    ModalTitle = "حل",
                    Placement = TableActionPlacement.ActionsMenu,
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                    OpenForm = new FormConfig
                    {
                        FormId = "resolveTicketForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "RESOLVE_TICKET" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden" },
                            new() { Label = "ملاحظات", Name = "p02", Type = "text", ColCss = "12" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "notin", Value = "IN_PROGRESS,CLARIFICATION", Message = "متاح فقط للتذاكر قيد العمل", Priority = 1 }
                        }
                    }
                });
            }

            if (canPauseTicket)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "إيقاف مؤقت",
                    Icon = "fa fa-pause",
                    Color = "warning",
                    OpenModal = true,
                    ModalTitle = "إيقاف مؤقت",
                    Placement = TableActionPlacement.ActionsMenu,
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                    OpenForm = new FormConfig
                    {
                        FormId = "pauseTicketForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "PAUSE_TICKET" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden" },
                            new() { Label = "السبب", Name = "p02", Type = "select", Options = pauseReasonOptions, ColCss = "12" },
                            new() { Label = "ملاحظات", Name = "p03", Type = "text", ColCss = "12" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "notin", Value = "IN_PROGRESS,CLARIFICATION", Message = "متاح فقط للتذاكر قيد العمل", Priority = 1 }
                        }
                    }
                });
            }

            if (canRequestClarification)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "طلب توضيح",
                    Icon = "fa fa-circle-question",
                    Color = "orange",
                    OpenModal = true,
                    ModalTitle = "طلب توضيح",
                    Placement = TableActionPlacement.ActionsMenu,
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    OnBeforeOpenJs = @"
                        var r = row || table.getSelectedRows?.()[0];
                        var fs = act.openForm && act.openForm.fields;
                        if (fs && r) {
                            fs.forEach(function(f) {
                                if (f.name === 'p02') f.value = '';
                                if (f.name === 'p03') f.value = r.currentDSDID_FK || r['currentDSDID_FK'] || '';
                                if (f.name === 'p04') f.value = '';
                                if (f.name === 'p05') f.value = '';
                            });
                        }
                    ",
                    OpenForm = new FormConfig
                    {
                        FormId = "requestClarificationForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "REQUEST_CLARIFICATION" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden" },
                            new() { Name = "p02", Type = "hidden", Value = string.Empty },
                            new() { Label = "الجهة المطلوب منها التوضيح", Name = "p03", Type = "select", Options = clarificationTargetDsdOptions, Required = true, ColCss = "6", Select2 = true },
                            new() { Label = "سبب طلب التوضيح", Name = "p04", Type = "select", Options = clarificationReasonOptions, Required = true, ColCss = "6", Select2 = true },
                            new() { Label = "ملاحظات الطلب", Name = "p05", Type = "textarea", Required = true, ColCss = "6", Placeholder = "اكتب تفاصيل التوضيح المطلوب" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "in", Value = "PAUSED,CLARIFICATION,RESOLVED,CLOSED,REJECTED", Message = "متاح فقط للتذاكر النشطة غير الموقوفة أو المغلقة", Priority = 1 }
                        }
                    }
                });
            }

            if (canRespondClarification)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "الرد على التوضيح",
                    Icon = "fa fa-reply",
                    Color = "primary",
                    OpenModal = true,
                    ModalTitle = "الرد على التوضيح",
                    Placement = TableActionPlacement.ActionsMenu,
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    // Edit forms are filled from the row, whose p01 is the ticketID; RESPOND_CLARIFICATION
                    // needs the open clarificationRequestID in p01 instead.
                    Meta = new Dictionary<string, object?>
                    {
                        ["formParamMap"] = new Dictionary<string, string>
                        {
                            ["p01"] = "openClarificationRequestID"
                        }
                    },
                    OnBeforeOpenJs = @"
                        var r = row || table.getSelectedRows?.()[0];
                        var fs = act.openForm && act.openForm.fields;
                        if (fs && r) {
                            fs.forEach(function(f) {
                                if (f.name === 'p01') f.value = r.openClarificationRequestID || r['openClarificationRequestID'] || '';
                                if (f.name === 'p02') f.value = '';
                            });
                        }
                    ",
                    OpenForm = new FormConfig
                    {
                        FormId = "respondClarificationForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "RESPOND_CLARIFICATION" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden", Value = string.Empty },
                            new() { Label = "الرد", Name = "p02", Type = "textarea", Required = true, ColCss = "12", Placeholder = "اكتب الرد على طلب التوضيح" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "neq", Value = "CLARIFICATION", Message = "متاح فقط للتذاكر التي تنتظر توضيحاً", Priority = 1 }
                        }
                    }
                });
            }

            if (canRaiseArbitration)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "تحكيم",
                    Icon = "fa fa-gavel",
                    Color = "info",
                    OpenModal = true,
                    ModalTitle = "تحكيم",
                    Placement = TableActionPlacement.ActionsMenu,
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                    OpenForm = new FormConfig
                    {
                        FormId = "arbitrationForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "RAISE_ARBITRATION" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden" },
                            new() { Label = "السبب", Name = "p02", Type = "select", Options = arbReasonOptions, ColCss = "12" },
                            new() { Label = "ملاحظات", Name = "p04", Type = "text", ColCss = "12" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "notin", Value = "IN_PROGRESS,CLARIFICATION", Message = "متاح فقط للتذاكر قيد العمل", Priority = 1 }
                        }
                    }
                });
            }

            if (canCreateChildTicket)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "تذكرة فرعية",
                    Icon = "fa fa-sitemap",
                    Color = "secondary",
                    OpenModal = true,
                    ModalTitle = "تذكرة فرعية",
                    Placement = TableActionPlacement.ActionsMenu,
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    OnBeforeOpenJs = @"
                        var rows = table.getSelectedRows();
                        if (rows && rows.length === 1) {
                            var r = rows[0];
                            var fs = act.openForm && act.openForm.fields;
                            if (fs) {
                                fs.forEach(function(f) {
                                    if (f.name === 'p02') f.value = r.serviceID_FK || r['serviceID_FK'] || '';
                                    if (f.name === 'p10') f.value = r.currentDSDID_FK || r['currentDSDID_FK'] || '';
                                });
                            }
                        }
                    ",
                    OpenForm = new FormConfig
                    {
                        FormId = "childTicketForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "CREATE_CHILD_TICKET" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden" },
                            new() { Name = "p02", Type = "hidden" },
                            new() { Name = "p04", Type = "hidden", Value = "2" },
                            new() { Name = "p10", Type = "hidden" },
                            new() { Label = "العنوان", Name = "p07", Type = "text", Required = true, ColCss = "12" },
                            new() { Label = "الوصف", Name = "p08", Type = "text", ColCss = "12" },
                            new() { Label = "الأولوية", Name = "p09", Type = "select", Options = actionPriorityOptions, ColCss = "6" },
                            new() { Label = "الفئة", Name = "p03", Type = "select", Options = actionClassOptions, ColCss = "6" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "notin", Value = "IN_PROGRESS,CLARIFICATION", Message = "متاح فقط للتذاكر قيد العمل", Priority = 1 },
                            new() { Field = "allowsChildTickets", Op = "neq", Value = "True", Message = "هذه التذكرة لا تسمح بتذاكر فرعية", Priority = 2 }
                        }
                    }
                });
            }

            if (canResumeTicket)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "استئناف",
                    Icon = "fa fa-play-circle",
                    Color = "success",
                    OpenModal = true,
                    ModalTitle = "استئناف",
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    Placement = TableActionPlacement.ActionsMenu,
                    OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                    OpenForm = new FormConfig
                    {
                        FormId = "resumeTicketForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "RESUME_TICKET" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden" },
                            new() { Label = "ملاحظات", Name = "p02", Type = "text", ColCss = "12" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "neq", Value = "PAUSED", Message = "متاح فقط للتذاكر المتوقفة مؤقتاً", Priority = 1 }
                        }
                    }
                });
            }

            if (canSubmitQualityReview)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "مراجعة جودة",
                    Icon = "fa fa-clipboard-check",
                    Color = "info",
                    OpenModal = true,
                    ModalTitle = "مراجعة جودة",
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                    OpenForm = new FormConfig
                    {
                        FormId = "qualityReviewForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "SUBMIT_QUALITY_REVIEW" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden" },
                            new() { Label = "النتيجة", Name = "p02", Type = "select", Options = qrResultOptions, Required = true, ColCss = "6" },
                            new() { Label = "النطاق", Name = "p03", Type = "text", ColCss = "6" },
                            new() { Label = "ملاحظات", Name = "p04", Type = "text", ColCss = "12" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "neq", Value = "RESOLVED", Message = "متاح فقط للتذاكر المحلولة", Priority = 1 }
                        }
                    }
                });
            }

            if (canFinalizeQualityReview)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "إنهاء المراجعة",
                    Icon = "fa fa-check-double",
                    Color = "success",
                    OpenModal = true,
                    ModalTitle = "إنهاء المراجعة",
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                    OpenForm = new FormConfig
                    {
                        FormId = "finalizeQRForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "FINALIZE_QUALITY_REVIEW" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden" },
                            new() { Label = "ملاحظات", Name = "p02", Type = "text", ColCss = "12" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "neq", Value = "RESOLVED", Message = "متاح فقط للتذاكر المحلولة", Priority = 1 }
                        }
                    }
                });
            }

            if (canCloseTicket)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "إغلاق",
                    Icon = "fa fa-lock",
                    Color = "success",
                    Placement = TableActionPlacement.ActionsMenu,
                    OpenModal = true,
                    ModalTitle = "إغلاق",
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                    OpenForm = new FormConfig
                    {
                        FormId = "closeTicketForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "CLOSE_TICKET" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden" },
                            new() { Label = "ملاحظات", Name = "p02", Type = "text", ColCss = "12" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "neq", Value = "RESOLVED", Message = "متاح فقط للتذاكر المحلولة", Priority = 1 }
                        }
                    }
                });
            }

            if (canReopenTicket)
            {
                ticketActions.Add(new TableAction
                {
                    Label = "إعادة فتح",
                    Icon = "fa fa-redo",
                    Color = "warning",
                    Placement = TableActionPlacement.ActionsMenu,
                    OpenModal = true,
                    ModalTitle = "إعادة فتح",
                    RequireSelection = true,
                    MinSelection = 1,
                    MaxSelection = 1,
                    IsEdit = true,
                    OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                    OpenForm = new FormConfig
                    {
                        FormId = "reopenTicketForm",
                        Method = "post",
                        ActionUrl = "/crud/insert",
                        Fields = new List<FieldConfig>
                        {
                            new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                            new() { Name = "ActionType", Type = "hidden", Value = "REOPEN_TICKET" },
                            new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                            new() { Name = "entrydata", Type = "hidden", Value = usersId },
                            new() { Name = "hostname", Type = "hidden", Value = HostName },
                            new() { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                            new() { Name = "p01", Type = "hidden" },
                            new() { Label = "السبب", Name = "p02", Type = "text", ColCss = "12" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "neq", Value = "CLOSED", Message = "متاح فقط للتذاكر المغلقة", Priority = 1 }
                        }
                    }
                });
            }

            toolbar.CustomActions = ticketActions;

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "قائمة التذاكر",
                PanelTitle = "التذاكر",
                StorageKey = "TicketList:Main:v5",
                Columns = columns,
                Rows = rows,
                RowIdField = "p01",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                EnableCellCopy = true,
                ShowColumnVisibility = true,
                // QuickSearchFields = columns.Where(c => c.Visible).Select(c => c.Field).Take(4).ToList(),
                Toolbar = toolbar,
                StyleRules = styleRules,
                // RenderMode = SmartTableRenderMode.Tab,
                RenderAsTab = false,
                TabGroupKey = tabGroupKey,
                TabKey = "all-tickets",
                TabLabel = "جميع التذاكر",
                TabIcon = "fa-solid fa-list",
                TabDefaultActive = true,
                ShowTabCount = true,
                ShowFilter = true,
                FilterRow = true,
                TabOrder = 1
            };

            // Arbitration inbox lives on TicketAdmin (TicketController.TicketAdmin).

            // ---- Quality Review Inbox tab ----
            SmartTableDsModel? qrInboxModel = null;
            if (canViewQualityInbox)
            {
                DataSet dsQR = await _mastersServies.GetDataLoadDataSetAsync(
                    "PendingReviews", IdaraId, usersId, HostName
                );
                DataTable? dtQR = (dsQR?.Tables?.Count ?? 0) > 1 ? dsQR!.Tables[1] : null;

                if (dtQR != null && dtQR.Columns.Count > 0)
                {
                    var qrCols = new List<TableColumn>();
                    var qrRows = new List<Dictionary<string, object?>>();

                    foreach (DataColumn col in dtQR.Columns)
                        qrCols.Add(new TableColumn { Field = col.ColumnName, Label = TranslateListColumn(col.ColumnName), Type = GetColType(col.DataType), Sortable = true });

                    foreach (DataRow dr in dtQR.Rows)
                    {
                        var dict = new Dictionary<string, object?>();
                        foreach (DataColumn col in dtQR.Columns)
                            dict[col.ColumnName] = dr[col] == DBNull.Value ? null : dr[col];
                        qrRows.Add(dict);
                    }

                    qrInboxModel = new SmartTableDsModel
                    {
                        PanelTitle = "صندوق مراجعة الجودة",
                        Columns = qrCols,
                        Rows = qrRows,
                        RowIdField = "qualityReviewID",
                        PageSize = 10,
                        Searchable = true,
                        ShowTabCount = true,
                        Toolbar = new TableToolbarConfig { ShowAdd = false, ShowEdit = false, ShowDelete = false, ShowRefresh = true },
                        RenderMode = SmartTableRenderMode.Tab,
                        RenderAsTab = true,
                        TabGroupKey = tabGroupKey,
                        TabKey = "quality-inbox",
                        TabLabel = "صندوق مراجعة الجودة",
                        TabIcon = "fa-solid fa-clipboard-check",
                        TabOrder = 2
                    };
                }
            }

            var page = new SmartPageViewModel
            {
                PageTitle = "قائمة التذاكر",
                PanelTitle = "قائمة التذاكر",
                PanelIcon = "fa-solid fa-ticket",
                TableDS = dsModel,
                TableDS1 = qrInboxModel
            };

            return View("TicketList", page);
        }
    

        private static bool IsFailedTicketListDataLoad(DataTable? table)
                {
                        if (table == null || table.Columns.Count == 0 || table.Rows.Count == 0)
                                return false;

                        return table.Columns.Contains("IsSuccessful")
                                && table.Columns.Contains("Message_")
                                && !table.Columns.Contains("ticketNo");
                }

        private static string GetColType(Type t)
        {
            if (t == typeof(bool)) return "bool";
            if (t == typeof(DateTime)) return "date";
            if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                return "number";
            return "text";
        }

        private static string TranslateListColumn(string name) => name switch
        {
            "ticketID" => " رقم التذكرة",
            "ticketNo" => "رقم التذكرة",
            "title" => "العنوان",
            "serviceName_A" => "الخدمة",
            "serviceName_E" => "الخدمة",
            "priorityName_A" => "الأولوية",
            "ticketStatusName_A" => "الحالة",
            "ticketStatusName_E" => "الحالة",
            "ticketStatusCode" => "الحالة",
            "currentDSDID_FK" => "القسم",
            "assignedUserID_FK" => "المستخدم المسؤول",
            "entryDate" => "تاريخ الإنشاء",
            "qualityReviewID" => "رقم المراجعة",
            "ticketID_FK" => "معرف التذكرة",
            "title_A" => "العنوان",
            "reviewScope" => "نطاق المراجعة",
            _ => name
        };
    }
}
