using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Mvc.Helpers;
using SmartFoundation.Mvc.Services.DataLoad;
using SmartFoundation.UI.ViewModels.SmartDrawer;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;


namespace SmartFoundation.Mvc.Controllers.Tickets
{
    public partial class TicketController : Controller
    {
        public async Task<IActionResult> TicketList([FromServices] RequestScopedDataLoadService requestDataLoad)
        {
            //  قراءة السيشن والكونتكست
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = "Ticket";
            PageName = string.IsNullOrWhiteSpace(PageName) ? "TicketList" : PageName;

            var ddlParameters = new Dictionary<string, object?>(
               StringComparer.OrdinalIgnoreCase)
            {
                ["pageName_"] = PageName ?? "TicketList"
            };

            if (IdaraId != null)
                ddlParameters["idaraID"] = Convert.ToInt32(IdaraId);

            if (usersId != null)
                ddlParameters["entrydata"] = Convert.ToInt32(usersId);

            if (HostName != null)
                ddlParameters["hostname"] = HostName;

            // معاملات تحميل بيانات الصفحة.
            // نضيف فلاتر القائمة فقط عند وجودها: parameter_03 الحالة، parameter_04 الخدمة، parameter_06 الجهة.
            var pageParameters = new Dictionary<string, object?>(
                ddlParameters,
                StringComparer.OrdinalIgnoreCase);

            foreach (var filterKey in new[] { "parameter_03", "parameter_04", "parameter_06" })
            {
                var filterValue = Request.Query[filterKey].FirstOrDefault();
                if (!string.IsNullOrWhiteSpace(filterValue) && int.TryParse(filterValue, out var filterId))
                    pageParameters[filterKey] = filterId;
            }

            // Masters_DataLoad -> [Tickets].[TicketListDL]
            // [0] الصلاحيات  [1] التذاكر  [2] الحالات  [3] الخدمات  [4] أسباب الإيقاف  [5] أسباب التحكيم
            // [6] نتائج مراجعة الجودة  [7] الأولويات  [8] فئات التذاكر  [9] أسباب طلب التوضيح
            // [10] الجهات  [11] موظفو الجهات  [12] صندوق مراجعة الجودة  [13] طلبات التوضيح المفتوحة
            // [14] أنواع مقدم الطلب  [15] السكان  [16] المباني  [17] أسباب البلاغ
            DataSet ds = await requestDataLoad.GetDataLoadDataSetAsync(pageParameters);


            //  تقسيم الداتا سيت للجدول الأول + جداول أخرى
            SplitDataSet(ds);

            //  التحقق من الصلاحيات
            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            DataTable? dt12 = ds.Tables.Count > 12 ? ds.Tables[12] : null;
            DataTable? dt13 = ds.Tables.Count > 13 ? ds.Tables[13] : null;
            DataTable? dt14 = ds.Tables.Count > 14 ? ds.Tables[14] : null;

            string rowIdField = "";
            bool canINSERT_TICKET = false;
            bool canROUTE_TICKET = false;
            bool canREJECT_TICKET = false;
            bool canASSIGN_TICKET = false;
            bool canREASSIGN_TICKET = false;
            bool canUPDATE_PRIORITY = false;
            bool canSTART_WORK = false;
            bool canRESOLVE_TICKET = false;
            bool canPAUSE_TICKET = false;
            bool canRESUME_TICKET = false;
            bool canRAISE_ARBITRATION = false;
            bool canCREATE_CHILD_TICKET = false;
            bool canCLOSE_TICKET = false;
            bool canREOPEN_TICKET = false;
            bool canSUBMIT_QUALITY_REVIEW = false;
            bool canFINALIZE_QUALITY_REVIEW = false;
            bool canREQUEST_CLARIFICATION = false;
            bool canRESPOND_CLARIFICATION = false;

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();
            var rowsList_dt12 = new List<Dictionary<string, object?>>();
            var dynamicColumns_dt12 = new List<TableColumn>();


            List<OptionItem> pauseReasonOptions = new();
            List<OptionItem> arbReasonOptions = new();
            List<OptionItem> qrResultOptions = new();
            List<OptionItem> actionPriorityOptions = new();
            List<OptionItem> actionClassOptions = new();
            List<OptionItem> clarificationReasonOptions = new();
            List<OptionItem> dsdOptions = new();
            List<OptionItem> clarificationTargetDsdOptions = new();
            List<OptionItem> residentOptions = new();
            List<OptionItem> buildingOptions = new();
            List<OptionItem> groupedServiceOptions = new();


            DataSet ddlDs = await requestDataLoad
                   .GetDataLoadDataSetAsync(ddlParameters);

            static List<OptionItem> ReadOptions(
                DataSet source,
                int tableIndex,
                string textColumn,
                string valueColumn)
            {
                if (tableIndex < 0 ||
                    tableIndex >= source.Tables.Count)
                {
                    throw new InvalidOperationException(
                        $"DDL table index {tableIndex} not found.");
                }

                DataTable table = source.Tables[tableIndex];

                if (!table.Columns.Contains(textColumn) ||
                    !table.Columns.Contains(valueColumn))
                {
                    throw new InvalidOperationException(
                        $"DDL columns mismatch at table {tableIndex}.");
                }

                var options = new List<OptionItem>();

                foreach (DataRow row in table.Rows)
                {
                    string value = row[valueColumn]
                        ?.ToString()?.Trim() ?? "";

                    string text = row[textColumn]
                        ?.ToString()?.Trim() ?? "";

                    if (!string.IsNullOrEmpty(value))
                    {
                        options.Add(new OptionItem
                        {
                            Value = value,
                            Text = text
                        });
                    }
                }

                if (options.Count == 0)
                {
                    options.Add(new OptionItem
                    {
                        Value = "-1",
                        Text = "لاتوجد خيارات"
                    });
                }

                return options;
            }

            pauseReasonOptions = ReadOptions(ddlDs, 4, "pauseReasonName_A", "pauseReasonID");
            arbReasonOptions = ReadOptions(ddlDs, 5, "arbitrationReasonName_A", "arbitrationReasonID");
            qrResultOptions = ReadOptions(ddlDs, 6, "qualityReviewResultName_A", "qualityReviewResultID");
            actionPriorityOptions = ReadOptions(ddlDs, 7, "priorityName_A", "priorityID");
            actionClassOptions = ReadOptions(ddlDs, 8, "ticketClassName_A", "ticketClassID");
            clarificationReasonOptions = ReadOptions(ddlDs, 9, "clarificationReasonName_A", "clarificationReasonID");
            dsdOptions = ReadOptions(ddlDs, 10, "dsdName_A", "DSDID");
            clarificationTargetDsdOptions = dsdOptions;
            residentOptions = ReadOptions(ddlDs, 15, "FullName_A", "residentInfoID");
            buildingOptions = ReadOptions(ddlDs, 16, "buildingDetailsNo", "buildingDetailsNo");
            groupedServiceOptions = BuildGroupedServiceOptions(
                ddlDs.Tables.Count > 3 ? ddlDs.Tables[3] : null,
                ddlDs.Tables.Count > 8 ? ddlDs.Tables[8] : null);

            // END DDL

            // نوع العمود حسب نوع البيانات (نفس قاعدة صفحات الإسكان)
            static string ColumnType(DataColumn c)
            {
                var t = c.DataType;
                if (t == typeof(bool)) return "bool";
                if (t == typeof(DateTime)) return "date";
                if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                    || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                    return "number";
                return "text";
            }

            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // صلاحيات
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "INSERT_TICKET") canINSERT_TICKET = true;
                        if (permissionName == "ROUTE_TICKET") canROUTE_TICKET = true;
                        if (permissionName == "REJECT_TICKET") canREJECT_TICKET = true;
                        if (permissionName == "ASSIGN_TICKET") canASSIGN_TICKET = true;
                        if (permissionName == "REASSIGN_TICKET") canREASSIGN_TICKET = true;
                        if (permissionName == "UPDATE_PRIORITY") canUPDATE_PRIORITY = true;
                        if (permissionName == "START_WORK") canSTART_WORK = true;
                        if (permissionName == "RESOLVE_TICKET") canRESOLVE_TICKET = true;
                        if (permissionName == "PAUSE_TICKET") canPAUSE_TICKET = true;
                        if (permissionName == "RESUME_TICKET") canRESUME_TICKET = true;
                        if (permissionName == "RAISE_ARBITRATION") canRAISE_ARBITRATION = true;
                        if (permissionName == "CREATE_CHILD_TICKET") canCREATE_CHILD_TICKET = true;
                        if (permissionName == "CLOSE_TICKET") canCLOSE_TICKET = true;
                        if (permissionName == "REOPEN_TICKET") canREOPEN_TICKET = true;
                        if (permissionName == "SUBMIT_QUALITY_REVIEW") canSUBMIT_QUALITY_REVIEW = true;
                        if (permissionName == "FINALIZE_QUALITY_REVIEW") canFINALIZE_QUALITY_REVIEW = true;
                        if (permissionName == "REQUEST_CLARIFICATION") canREQUEST_CLARIFICATION = true;
                        if (permissionName == "RESPOND_CLARIFICATION") canRESPOND_CLARIFICATION = true;
                    }

                    // ===================== [1] التذاكر =====================
                    if (dt1 != null && dt1.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField = "ticketID";
                        var possibleIdNames = new[] { "ticketID", "TicketID", "Id", "ID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
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
                            ["assignedUserName"] = "المسند إليه",
                            ["assignedUserID_FK"] = "المستخدم المسؤول",
                            ["currentDSDID_FK"] = "القسم",
                            ["entryDate"] = "تاريخ الإنشاء"
                        };

                        // الأعمدة
                        foreach (DataColumn c in dt1.Columns)
                        {
                            string colType = ColumnType(c);
                            bool isticketID = c.ColumnName.Equals("ticketID", StringComparison.OrdinalIgnoreCase);
                            bool isserviceName_E = c.ColumnName.Equals("serviceName_E", StringComparison.OrdinalIgnoreCase);
                            bool isrequesterTypeName_A = c.ColumnName.Equals("requesterTypeName_A", StringComparison.OrdinalIgnoreCase);
                            bool isrequesterTypeName_E = c.ColumnName.Equals("requesterTypeName_E", StringComparison.OrdinalIgnoreCase);
                            bool ispriorityName_E = c.ColumnName.Equals("priorityName_E", StringComparison.OrdinalIgnoreCase);
                            bool isticketStatusName_E = c.ColumnName.Equals("ticketStatusName_E", StringComparison.OrdinalIgnoreCase);
                            bool isticketStatusCode = c.ColumnName.Equals("ticketStatusCode", StringComparison.OrdinalIgnoreCase);
                            bool iselapsedMinutes = c.ColumnName.Equals("elapsedMinutes", StringComparison.OrdinalIgnoreCase);
                            bool iscurrentDSDID_FK = c.ColumnName.Equals("currentDSDID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isassignedUserID_FK = c.ColumnName.Equals("assignedUserID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isticketNo = c.ColumnName.Equals("ticketNo", StringComparison.OrdinalIgnoreCase);
                            bool istitle = c.ColumnName.Equals("title", StringComparison.OrdinalIgnoreCase);
                            bool isentryDate = c.ColumnName.Equals("entryDate", StringComparison.OrdinalIgnoreCase);

                            bool isticketStatusName_A = c.ColumnName.Equals("ticketStatusName_A", StringComparison.OrdinalIgnoreCase);
                            bool ispriorityName_A = c.ColumnName.Equals("priorityName_A", StringComparison.OrdinalIgnoreCase);
                            bool isserviceName_A = c.ColumnName.Equals("serviceName_A", StringComparison.OrdinalIgnoreCase);

                            //  جهز خيارات الفلتر من نفس بيانات الجدول (عشان التطابق يكون صحيح)
                            List<OptionItem> filterOpts = new();
                            if (isticketStatusName_A || ispriorityName_A || isserviceName_A)
                            {
                                var field = c.ColumnName;

                                var distinctVals = dt1.AsEnumerable()
                                    .Select(r => (r[field] == DBNull.Value ? "" : r[field]?.ToString())?.Trim())
                                    .Where(s => !string.IsNullOrWhiteSpace(s))
                                    .Distinct()
                                    .OrderBy(s => s)
                                    .ToList();

                                filterOpts = distinctVals
                                    .Select(s => new OptionItem { Value = s!, Text = s! })
                                    .ToList();
                            }


                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                // رقم التذكرة يفتح نافذة التفاصيل، والتاريخ نص منسق
                                Type = isticketNo ? "link" : isentryDate ? "text" : colType,
                                LinkTemplate = isticketNo ? "#sf-drawer:sf-ticket-drawer:/Ticket/TicketDrawer/{ticketID}" : null,
                                truncate = istitle,
                                Sortable = true
                                //if u want to hide any column
                                ,
                                Visible = !(isticketID || isserviceName_E || isrequesterTypeName_A || isrequesterTypeName_E
                                || ispriorityName_E || isticketStatusName_E || isticketStatusCode || iselapsedMinutes
                                || iscurrentDSDID_FK || isassignedUserID_FK),

                                //  فلتر للحالة + الأولوية + الخدمة
                                Filter = (isticketStatusName_A || ispriorityName_A || isserviceName_A)
                                    ? new TableColumnFilter
                                    {
                                        Enabled = true,
                                        Type = "select",
                                        Options = filterOpts,
                                    }
                                    : new TableColumnFilter
                                    {
                                        Enabled = false
                                    }
                            });


                        }

                        // ticketID -> طلب التوضيح المفتوح (الجدول [13])
                        var openClarifications = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                        if (dt13 != null && dt13.Columns.Contains("ticketID_FK") && dt13.Columns.Contains("clarificationRequestID"))
                        {
                            foreach (DataRow cr in dt13.Rows)
                            {
                                var ticketKey = cr["ticketID_FK"]?.ToString()?.Trim();
                                if (!string.IsNullOrEmpty(ticketKey))
                                    openClarifications[ticketKey] = cr["clarificationRequestID"] == DBNull.Value ? null : cr["clarificationRequestID"];
                            }
                        }

                        // الصفوف
                        foreach (DataRow r in dt1.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt1.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("ticketID");

                            // الوقت المنقضي من دقائق SLA
                            object? elapsed = Get("elapsedMinutes");
                            dict["elapsedDisplay"] = elapsed == null
                                ? null
                                : $"{Convert.ToInt32(elapsed) / 60}h {Convert.ToInt32(elapsed) % 60}m";

                            // التاريخ بصيغة قصيرة
                            if (Get("entryDate") is DateTime entryDate)
                                dict["entryDate"] = entryDate.ToString("MMM d, yyyy", System.Globalization.CultureInfo.InvariantCulture);

                            // طلب التوضيح المفتوح على التذكرة (لزر الرد على التوضيح)
                            dict["openClarificationRequestID"] =
                                openClarifications.TryGetValue(Get("ticketID")?.ToString() ?? "", out var crId) ? crId : null;

                            rowsList.Add(dict);
                        }
                    }

                    // ===================== [12] صندوق مراجعة الجودة =====================
                    if (dt12 != null && dt12.Columns.Count > 0)
                    {
                        var headerMap_dt12 = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["qualityReviewID"] = "رقم المراجعة",
                            ["ticketID_FK"] = "معرف التذكرة",
                            ["ticketNo"] = "رقم التذكرة",
                            ["title"] = "العنوان",
                            ["reviewScope"] = "نطاق المراجعة",
                            ["entryDate"] = "تاريخ الإنشاء"
                        };

                        foreach (DataColumn c in dt12.Columns)
                        {
                            bool isticketID_FK = c.ColumnName.Equals("ticketID_FK", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns_dt12.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap_dt12.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = ColumnType(c),
                                Sortable = true,
                                Visible = !isticketID_FK
                            });
                        }

                        foreach (DataRow r in dt12.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt12.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("qualityReviewID");

                            rowsList_dt12.Add(dict);
                        }
                    }
                }
            }
            catch (Exception)
            {
                ViewBag.BuildingTypeDataSetError = "حدث خطأ أثناء تحميل البيانات. يرجى المحاولة مرة أخرى.";
            }


            // الإبقاء على فلاتر القائمة بعد الحفظ
            var currentUrl = Request.Path + Request.QueryString;
            var requestToken = Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "";


            // INSERT fields (تذكرة جديدة)
            var InsertTicketFields = BuildCreateTicketFields(
                PageName, currentUrl, requestToken, dt14, residentOptions, groupedServiceOptions, buildingOptions);


            // ---- Ticket action buttons (HousingExtend pattern) ----
            var ticketActions = new List<TableAction>();

            if (canROUTE_TICKET)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "ROUTE_TICKET" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
                            // hidden p01 actually posted to SP
                            new() { Name = "p01", Type = "hidden", MirrorName = "ticketID" },
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

            if (canREJECT_TICKET)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "REJECT_TICKET" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
                            // hidden p01 actually posted to SP
                            new() { Name = "p01", Type = "hidden", MirrorName = "ticketID" },
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

            if (canASSIGN_TICKET)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "ASSIGN_TICKET" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
                            // hidden p01 actually posted to SP
                            new() { Name = "p01", Type = "hidden", MirrorName = "ticketID" },
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
                                DependsUrl = "/crud/DDLFiltered?FK=DSDID&textcol=fullName_A&ValueCol=usersID&PageName=TicketList&TableIndex=11"
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

            if (canREASSIGN_TICKET)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "REASSIGN_TICKET" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
                            // hidden p01 actually posted to SP
                            new() { Name = "p01", Type = "hidden", MirrorName = "ticketID" },
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
                                DependsUrl = "/crud/DDLFiltered?FK=DSDID&textcol=fullName_A&ValueCol=usersID&PageName=TicketList&TableIndex=11"
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

            if (canUPDATE_PRIORITY)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "UPDATE_PRIORITY" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
                            // hidden p01 actually posted to SP
                            new() { Name = "p01", Type = "hidden", MirrorName = "ticketID" },
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

            if (canSTART_WORK)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "START_WORK" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
                            // hidden p01 actually posted to SP
                            new() { Name = "p01", Type = "hidden", MirrorName = "ticketID" },
                            new() { Label = "ملاحظات", Name = "p02", Type = "text", ColCss = "12" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "notin", Value = "ASSIGNED,REOPENED", Message = "متاح فقط للتذاكر المعينة أو المعاد فتحها", Priority = 1 },
                            new() { Field = "assignedUserID_FK", Op = "neq", Value = usersId, Message = "متاح فقط للموظف المسند إليه التذكرة", Priority = 2 }
                        }
                    }
                });
            }

            if (canRESOLVE_TICKET)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "RESOLVE_TICKET" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
                            // hidden p01 actually posted to SP
                            new() { Name = "p01", Type = "hidden", MirrorName = "ticketID" },
                            new() { Label = "ملاحظات", Name = "p02", Type = "text", ColCss = "12" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "notin", Value = "IN_PROGRESS,CLARIFICATION", Message = "متاح فقط للتذاكر قيد العمل", Priority = 1 },
                            new() { Field = "assignedUserID_FK", Op = "neq", Value = usersId, Message = "متاح فقط للموظف المسند إليه التذكرة", Priority = 2 }
                        }
                    }
                });
            }

            if (canPAUSE_TICKET)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "PAUSE_TICKET" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
                            // hidden p01 actually posted to SP
                            new() { Name = "p01", Type = "hidden", MirrorName = "ticketID" },
                            new() { Label = "السبب", Name = "p02", Type = "select", Options = pauseReasonOptions, ColCss = "12" },
                            new() { Label = "ملاحظات", Name = "p03", Type = "text", ColCss = "12" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "notin", Value = "IN_PROGRESS,CLARIFICATION", Message = "متاح فقط للتذاكر قيد العمل", Priority = 1 },
                            new() { Field = "assignedUserID_FK", Op = "neq", Value = usersId, Message = "متاح فقط للموظف المسند إليه التذكرة", Priority = 2 }
                        }
                    }
                });
            }

            if (canREQUEST_CLARIFICATION)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "REQUEST_CLARIFICATION" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
                            // hidden p01 actually posted to SP
                            new() { Name = "p01", Type = "hidden", MirrorName = "ticketID" },
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

            if (canRESPOND_CLARIFICATION)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "RESPOND_CLARIFICATION" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
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

            if (canRAISE_ARBITRATION)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "RAISE_ARBITRATION" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
                            // hidden p01 actually posted to SP
                            new() { Name = "p01", Type = "hidden", MirrorName = "ticketID" },
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

            if (canCREATE_CHILD_TICKET)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "CREATE_CHILD_TICKET" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
                            // hidden p01 actually posted to SP
                            new() { Name = "p01", Type = "hidden", MirrorName = "ticketID" },
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

            if (canRESUME_TICKET)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "RESUME_TICKET" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
                            // hidden p01 actually posted to SP
                            new() { Name = "p01", Type = "hidden", MirrorName = "ticketID" },
                            new() { Label = "ملاحظات", Name = "p02", Type = "text", ColCss = "12" }
                        }
                    },
                    Guards = new TableActionGuards
                    {
                        AppliesTo = "any",
                        DisableWhenAny = new List<TableActionRule>
                        {
                            new() { Field = "ticketStatusCode", Op = "neq", Value = "PAUSED", Message = "متاح فقط للتذاكر المتوقفة مؤقتاً", Priority = 1 },
                            new() { Field = "assignedUserID_FK", Op = "neq", Value = usersId, Message = "متاح فقط للموظف المسند إليه التذكرة", Priority = 2 }
                        }
                    }
                });
            }

            if (canSUBMIT_QUALITY_REVIEW)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "SUBMIT_QUALITY_REVIEW" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
                            // hidden p01 actually posted to SP
                            new() { Name = "p01", Type = "hidden", MirrorName = "ticketID" },
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

            if (canFINALIZE_QUALITY_REVIEW)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "FINALIZE_QUALITY_REVIEW" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
                            // hidden p01 actually posted to SP
                            new() { Name = "p01", Type = "hidden", MirrorName = "ticketID" },
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

            if (canCLOSE_TICKET)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "CLOSE_TICKET" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
                            // hidden p01 actually posted to SP
                            new() { Name = "p01", Type = "hidden", MirrorName = "ticketID" },
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

            if (canREOPEN_TICKET)
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
                            new() { Name = "pageName_", Type = "hidden", Value = PageName },
                            new() { Name = "ActionType", Type = "hidden", Value = "REOPEN_TICKET" },
                            new() { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                            new() { Name = "redirectAction",     Type = "hidden", Value = PageName },
                            new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                            new() { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                            // selection context
                            new() { Name = rowIdField, Type = "hidden" },
                            // hidden p01 actually posted to SP
                            new() { Name = "p01", Type = "hidden", MirrorName = "ticketID" },
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


            var dsModel = new SmartTableDsModel
            {
                PageTitle = "قائمة التذاكر",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                PanelTitle = "التذاكر",
                StorageKey = "TicketList:Main:v6",
                EnableCellCopy = true,
                ShowColumnVisibility = true,
                ShowFilter = true,
                FilterRow = true,

                RenderAsTab = false,
                TabGroupKey = "ticket-inbox",
                TabKey = "all-tickets",
                TabLabel = "جميع التذاكر",
                TabIcon = "fa-solid fa-list",
                TabDefaultActive = true,
                ShowTabCount = true,
                TabOrder = 1,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = true,
                    ShowColumns = true,
                    ShowExportExcel = true,
                    ShowExportPdf = false,

                    ShowAdd = canINSERT_TICKET,
                    ShowEdit = false,
                    ShowDelete = false,

                    Add = new TableAction
                    {
                        Label = "تذكرة جديدة",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إنشاء تذكرة جديدة",
                        OpenForm = new FormConfig
                        {
                            FormId = "createTicketForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            SubmitText = "إرسال التذكرة",
                            CancelText = "إلغاء",
                            Fields = InsertTicketFields
                        },
                    },

                    // نافذة تفاصيل التذكرة تُحمَّل من /Ticket/TicketDrawer/{id} عند الضغط على رقم التذكرة
                    Drawers =
                    {
                        new SmartDrawerConfig
                        {
                            Id = "sf-ticket-drawer",
                            Title = "تفاصيل التذكرة",
                            Icon = "fa-solid fa-ticket",
                            Side = SmartDrawerSide.Left,
                            Size = SmartDrawerSize.Large,
                            EmptyText = "جاري التحميل..."
                        }
                    },

                    CustomActions = ticketActions,
                }
            };


            dsModel.StyleRules = new List<TableStyleRule>
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


            // ===================== [12] صندوق مراجعة الجودة =====================
            var dsModel1 = new SmartTableDsModel
            {
                PageTitle = "قائمة التذاكر",
                Columns = dynamicColumns_dt12,
                Rows = rowsList_dt12,
                RowIdField = "qualityReviewID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                Searchable = true,
                ShowPageSizeSelector = true,
                PanelTitle = "صندوق مراجعة الجودة",

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsToggle = false,
                RenderAsSection = false,
                RenderAsTab = true,
                TabGroupKey = "ticket-inbox",
                TabKey = "quality-inbox",
                TabLabel = "صندوق مراجعة الجودة",
                TabIcon = "fa-solid fa-clipboard-check",
                TabDefaultActive = false,
                ShowTabCount = true,
                TabOrder = 2,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = true,
                    ShowAdd = false,
                    ShowEdit = false,
                    ShowDelete = false
                }
            };

            // صندوق مراجعة الجودة يظهر فقط لمن يملك تسجيل المراجعة أو اعتمادها
            bool canViewQualityInbox = canSUBMIT_QUALITY_REVIEW || canFINALIZE_QUALITY_REVIEW;


            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PageTitle,
                PanelIcon = "fa-solid fa-ticket",
                TableDS = dsModel,
                TableDS1 = canViewQualityInbox ? dsModel1 : null
            };


            return View("TicketList", page);
        }
    }
}
