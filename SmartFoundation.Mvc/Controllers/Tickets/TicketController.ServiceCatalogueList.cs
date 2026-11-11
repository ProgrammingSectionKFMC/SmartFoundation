using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Mvc.Helpers;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Globalization;
using System.Linq;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers.Tickets
{
    public partial class TicketController : Controller
    {
        // دالة مساعدة مشتركة: تحول JsonResult إلى List<OptionItem> بأمان
        private static List<OptionItem> DeserializeOptionItems(JsonResult? result)
        {
            if (result?.Value is null)
                return new List<OptionItem>();

            return JsonSerializer.Deserialize<List<OptionItem>>(
                       JsonSerializer.Serialize(result.Value))
                   ?? new List<OptionItem>();
        }

        public async Task<IActionResult> ServiceCatalogueList()
        {
            if (!InitPageContext(out var redirect))
                return redirect!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = nameof(TicketController).Replace("Controller", "");
            PageName = "ServiceCatalogueList";

            var spParameters = new object?[]
            {
                PageName,
                IdaraId,
                usersId,
                HostName,
                null,
                null
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();

            // 🚀 تحميل متوازي: DataSet + جميع القوائم المنسدلة دفعة واحدة
            var dsTask = _mastersServies.GetDataLoadDataSetAsync(spParameters);
            var ticketClassTask = _CrudController.GetDDLValues("ticketClassName_A", "ticketClassID", "2", nameof(ServiceCatalogueList), usersId, IdaraId, HostName);
            var priorityTask = _CrudController.GetDDLValues("priorityName_A", "priorityID", "3", nameof(ServiceCatalogueList), usersId, IdaraId, HostName);

            // انتظر انتهاء الكل دفعة واحدة
            await Task.WhenAll(dsTask, ticketClassTask, priorityTask);

            // استخرج الـ DataSet
            DataSet ds = dsTask.Result;
            SplitDataSet(ds);

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            bool canInsertService = false;
            bool canUpdateService = false;
            bool canDeleteService = false;

            string rowIdField = "serviceID";

            // استخرج القوائم
            List<OptionItem> ticketClassOptions = DeserializeOptionItems(ticketClassTask.Result as JsonResult);
            List<OptionItem> priorityOptions = DeserializeOptionItems(priorityTask.Result as JsonResult);

            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // صلاحيات
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                        if (permissionName == "INSERTSERVICE") canInsertService = true;
                        if (permissionName == "UPDATESERVICE") canUpdateService = true;
                        if (permissionName == "DELETESERVICE") canDeleteService = true;
                    }

                    if (dt1 != null && dt1.Columns.Count > 0)
                    {
                        // RowId
                        var possibleIdNames = new[] { "serviceID", "ServiceID", "Id", "ID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["serviceID"]         = "الرقم المرجعي",
                            ["serviceCode"]       = "كود الخدمة",
                            ["serviceName_A"]     = "اسم الخدمة",
                            ["serviceName_E"]     = "Service Name",
                            ["serviceDesc"]       = "الوصف",
                            ["departmentName"]    = "الإدارة",
                            ["divisionSectionName"] = "القسم",
                            ["priorityName_A"]    = "الأولوية",
                            ["ticketClassName_A"] = "فئة التذكرة",
                            ["serviceStatusText"] = "الحالة",
                            ["serviceActive"]     = "نشط"
                        };

                        // الأعمدة
                        foreach (DataColumn c in dt1.Columns)
                        {
                            string colType = "text";
                            var t = c.DataType;
                            if (t == typeof(bool)) colType = "bool";
                            else if (t == typeof(DateTime)) colType = "date";
                            else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                                     || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                                colType = "number";

                            bool isPriorityName      = c.ColumnName.Equals("priorityName_A",    StringComparison.OrdinalIgnoreCase);
                            bool isServiceActive     = c.ColumnName.Equals("serviceStatusText", StringComparison.OrdinalIgnoreCase);
                            bool isServiceActiveRaw  = c.ColumnName.Equals("serviceActive",     StringComparison.OrdinalIgnoreCase);

                            // أعمدة تُخفى
                            bool isHidden =
                                c.ColumnName.EndsWith("ID_FK",            StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.Equals("idaraID_FK",         StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.Equals("priorityName_E",     StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.Equals("ticketClassName_E",  StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.Equals("requiresLocation",   StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.Equals("allowsChildTickets", StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.Equals("requiresQualityReview", StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.StartsWith("routing",        StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.StartsWith("sla",            StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.StartsWith("firstResponse",  StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.StartsWith("assignment",     StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.StartsWith("operational",    StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.StartsWith("finalClosure",   StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.Equals("activeRoutingRuleID", StringComparison.OrdinalIgnoreCase) ||
                                c.ColumnName.Equals("activeTargetDSDID",  StringComparison.OrdinalIgnoreCase);

                            List<OptionItem> filterOpts = new();
                            if (isPriorityName)
                            {
                                var distinctVals = dt1.AsEnumerable()
                                    .Select(r => (r[c.ColumnName] == DBNull.Value ? "" : r[c.ColumnName]?.ToString())?.Trim())
                                    .Where(s => !string.IsNullOrWhiteSpace(s))
                                    .Distinct()
                                    .OrderBy(s => s)
                                    .ToList();
                                filterOpts = distinctVals.Select(s => new OptionItem { Value = s!, Text = s! }).ToList();
                            }
                            else if (isServiceActive)
                            {
                                filterOpts = new List<OptionItem>
                                {
                                    new OptionItem { Value = "نشطة",     Text = "نشطة" },
                                    new OptionItem { Value = "غير نشطة", Text = "غير نشطة" }
                                };
                            }
                            else if (isServiceActiveRaw)
                            {
                                filterOpts = new List<OptionItem>
                                {
                                    new OptionItem { Value = "1", Text = "نشط" },
                                    new OptionItem { Value = "0", Text = "غير نشط" }
                                };
                            }

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,
                                Align = "left",
                                Visible = !isHidden,
                                Tooltip = CodeColumnHint(c.ColumnName),
                                Filter = (isPriorityName || isServiceActive || isServiceActiveRaw)
                                    ? new TableColumnFilter { Enabled = true, Type = "select", Options = filterOpts }
                                    : new TableColumnFilter { Enabled = false }
                            });
                        }

                        // الصفوف
                        foreach (DataRow r in dt1!.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

                            foreach (DataColumn c in dt1.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;

                            // تحديد بيانات الخدمة (p01, p02, etc.)
                            dict["p01"] = Get("serviceID");
                            dict["p02"] = Get("serviceCode");
                            dict["p03"] = Get("serviceName_A");
                            dict["p04"] = Get("serviceName_E");
                            dict["p05"] = Get("serviceDesc");
                            dict["p06"] = Get("ticketClassID_FK");
                            // p07..p10 match Masters_CRUD INSERT_SERVICE / UPDATE_SERVICE parameter_07..10
                            dict["p07"] = Get("defaultPriorityID_FK");
                            dict["p08"] = Get("requiresLocation");
                            dict["p09"] = Get("allowsChildTickets");
                            dict["p10"] = Get("requiresQualityReview");
                            dict["p13"] = Get("serviceActive");
                            dict["p14"] = Get("departmentName");
                            dict["p15"] = Get("divisionSectionName");
                            dict["p16"] = Get("routingDepartmentName");
                            dict["p17"] = Get("routingDivisionName");
                            dict["p18"] = Get("routingSectionName");
                            dict["p19"] = Get("routingDistributorID");
                            dict["p20"] = Get("activeTargetDSDID");
                            dict["p21"] = Get("queueDistributorID_FK");

                            rowsList.Add(dict);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.ServiceCatalogueError = ex.Message;
            }

            // ADD fields
            var addFields = new List<FieldConfig>
            {
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                // Service code is generated by ServiceSP (SRV-00042), so it is not asked for here.
                new FieldConfig { Name = "p03", Label = "اسم الخدمة (عربي)", Placeholder = "حقل عربي فقط", Type = "text", Required = true, ColCss = "6", MaxLength = 500, TextMode = "arabic", Icon = "fa-solid fa-tag" },
                new FieldConfig { Name = "p04", Label = "اسم الخدمة (إنجليزي) — اختياري", Placeholder = "حقل انجليزي فقط", Type = "text", ColCss = "6", MaxLength = 500, TextMode = "english", Icon = "fa-solid fa-tag" },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "textarea", ColCss = "12", MaxLength = 2000, Icon = "fa-solid fa-align-left" },
                new FieldConfig { Name = "p06", Label = "فئة التذكرة", Type = "select", Options = ticketClassOptions, ColCss = "6", Select2 = true, Icon = "fa-solid fa-layer-group" },
                new FieldConfig { Name = "p07", Label = "الأولوية الافتراضية", Type = "select", Options = priorityOptions, ColCss = "6", Select2 = true, Icon = "fa-solid fa-flag" },
                new FieldConfig { Name = "p08", Label = "يتطلب موقع", Type = "checkbox", ColCss = "4", Icon = "fa-solid fa-location-dot" },
                new FieldConfig { Name = "p09", Label = "يسمح بتذاكر فرعية", Type = "checkbox", ColCss = "4", Icon = "fa-solid fa-sitemap" },
                new FieldConfig { Name = "p10", Label = "يتطلب مراجعة جودة", Type = "checkbox", ColCss = "4", Icon = "fa-solid fa-clipboard-check" }
            };

            // hidden fields
            addFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            addFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            addFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            addFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT_SERVICE" });
            addFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });

            // UPDATE fields
            var updateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATE_SERVICE" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Label = "الرقم المرجعي", Type = "hidden" },
                new FieldConfig { Name = "p02", Label = "كود الخدمة (تلقائي)", Type = "text", Readonly = true, ColCss = "6", Icon = "fa-solid fa-code" },
                new FieldConfig { Name = "p03", Label = "اسم الخدمة (عربي)", Type = "text", Required = true, ColCss = "6", MaxLength = 500, TextMode = "arabic", Icon = "fa-solid fa-tag" },
                new FieldConfig { Name = "p04", Label = "اسم الخدمة (إنجليزي)", Type = "text", ColCss = "6", MaxLength = 500, TextMode = "english", Icon = "fa-solid fa-tag" },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "textarea", ColCss = "12", MaxLength = 2000, Icon = "fa-solid fa-align-left" },
                new FieldConfig { Name = "p06", Label = "فئة التذكرة", Type = "select", Options = ticketClassOptions, ColCss = "6", Select2 = true, Icon = "fa-solid fa-layer-group" },
                new FieldConfig { Name = "p07", Label = "الأولوية الافتراضية", Type = "select", Options = priorityOptions, ColCss = "6", Select2 = true, Icon = "fa-solid fa-flag" },
                new FieldConfig { Name = "p08", Label = "يتطلب موقع", Type = "checkbox", ColCss = "4", Icon = "fa-solid fa-location-dot" },
                new FieldConfig { Name = "p09", Label = "يسمح بتذاكر فرعية", Type = "checkbox", ColCss = "4", Icon = "fa-solid fa-sitemap" },
                new FieldConfig { Name = "p10", Label = "يتطلب مراجعة جودة", Type = "checkbox", ColCss = "4", Icon = "fa-solid fa-clipboard-check" }
            };

            // DELETE fields
            var deleteFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "DELETE_SERVICE" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "serviceID" },
                new FieldConfig { Name = "p02", Label = "كود الخدمة", Type = "text", Readonly = true, ColCss = "6", Icon = "fa-solid fa-code" },
                new FieldConfig { Name = "p03", Label = "اسم الخدمة", Type = "text", Readonly = true, ColCss = "6", Icon = "fa-solid fa-tag" }
            };

            int totalServices = rowsList.Count;
            int activeServices = rowsList.Count(row => row.TryGetValue("serviceActive", out var sv) && sv?.ToString() is "1" or "True" or "true");

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "دليل الخدمات",
                PanelTitle = $"دليل الخدمات ({activeServices} نشطة من أصل {totalServices})",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = "serviceID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                EnableCellCopy = true,
                //ShowFilter = true,
                ShowAdvancedFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                ShowColumnVisibility = true,
                EnableColumnReorder = true,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = true,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = true,
                    ShowExportPdf = false,
                    ShowAdd = canInsertService,
                    ShowEdit = canUpdateService,
                    ShowDelete = canDeleteService,
                    ShowBulkDelete = false,

                    CustomActions = new List<TableAction>
                    {
                        // details
                        new TableAction
                        {
                            Label = "عرض التفاصيل",
                            ModalTitle = "<i class='mr-2 text-xl fa-solid fa-circle-info text-emerald-600'></i> تفاصيل الخدمة",
                            Icon = "fa-regular fa-file",
                            Placement = TableActionPlacement.ActionsMenu,
                            OpenModal = true,
                            RequireSelection = true,
                            MinSelection = 1,
                            MaxSelection = 1
                        }
                    },

                    Add = canInsertService ? new TableAction
                    {
                        Label = "إضافة خدمة",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "<i class='mr-2 text-xl fa-solid fa-plus-circle text-emerald-600'></i> إضافة خدمة جديدة",
                        OpenForm = new FormConfig
                        {
                            FormId = "ServiceCatalogueInsertForm",
                            Title = "بيانات خدمة جديدة",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success", Icon = "fa fa-check" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    } : null,

                    Edit = canUpdateService ? new TableAction
                    {
                        Label = "تعديل الخدمة",
                        Icon = "fa-solid fa-pen",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='mr-2 text-xl fa-solid fa-pen text-info-600'></i> تعديل الخدمة",
                        OpenForm = new FormConfig
                        {
                            FormId = "ServiceCatalogueUpdateForm",
                            Title = "تعديل بيانات الخدمة",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = updateFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    } : null,

                    Delete = canDeleteService ? new TableAction
                    {
                        Label = "حذف الخدمة",
                        Icon = "fa-regular fa-trash-can",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='mr-2 text-xl text-red-600 fa fa-exclamation-triangle'></i> تحذير",
                        ModalMessage = "سيتم تعطيل الخدمة الحالية. هذا الإجراء مرصود ويمكن التراجع عنه من قاعدة البيانات فقط.",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "ServiceCatalogueDeleteForm",
                            Title = "تأكيد حذف الخدمة",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حذف", Type = "submit", Color = "danger", Icon = "fa fa-trash" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = deleteFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    } : null
                }
            };

            // Style rules for status pills
            dsModel.StyleRules = new List<TableStyleRule>
            {
                new()
                {
                    Target = "row",
                    Field = "priorityName_A",
                    Op = "eq",
                    Value = "حرج",
                    Priority = 1,
                    PillEnabled = true,
                    PillField = "priorityName_A",
                    PillTextField = "priorityName_A",
                    PillCssClass = "pill pill-red",
                    PillMode = "replace"
                },
                new()
                {
                    Target = "row",
                    Field = "priorityName_A",
                    Op = "eq",
                    Value = "مرتفع",
                    Priority = 2,
                    PillEnabled = true,
                    PillField = "priorityName_A",
                    PillTextField = "priorityName_A",
                    PillCssClass = "pill pill-orange",
                    PillMode = "replace"
                },
                new()
                {
                    Target = "row",
                    Field = "priorityName_A",
                    Op = "eq",
                    Value = "متوسط",
                    Priority = 3,
                    PillEnabled = true,
                    PillField = "priorityName_A",
                    PillTextField = "priorityName_A",
                    PillCssClass = "pill pill-blue",
                    PillMode = "replace"
                },
                new()
                {
                    Target = "row",
                    Field = "priorityName_A",
                    Op = "eq",
                    Value = "منخفض",
                    Priority = 4,
                    PillEnabled = true,
                    PillField = "priorityName_A",
                    PillTextField = "priorityName_A",
                    PillCssClass = "pill pill-green",
                    PillMode = "replace"
                },
                new()
                {
                    Target = "row",
                    Field = "serviceStatusText",
                    Op = "eq",
                    Value = "نشطة",
                    Priority = 1,
                    PillEnabled = true,
                    PillField = "serviceStatusText",
                    PillTextField = "serviceStatusText",
                    PillCssClass = "pill pill-green",
                    PillMode = "replace"
                },
                new()
                {
                    Target = "row",
                    Field = "serviceStatusText",
                    Op = "eq",
                    Value = "غير نشطة",
                    Priority = 1,
                    PillEnabled = true,
                    PillField = "serviceStatusText",
                    PillTextField = "serviceStatusText",
                    PillCssClass = "pill pill-red",
                    PillMode = "replace"
                },
                // serviceActive: numeric path (SQL bit returned as int)
                new()
                {
                    Target = "row",
                    Field = "serviceActive",
                    Op = "eq",
                    Value = "1",
                    Priority = 1,
                    PillEnabled = true,
                    PillField = "serviceActive",
                    PillText = "نشط",
                    PillCssClass = "pill pill-green",
                    PillMode = "replace"
                },
                // serviceActive: bool path (SQL bit returned as bool)
                new()
                {
                    Target = "row",
                    Field = "serviceActive",
                    Op = "eq",
                    Value = true,
                    Priority = 1,
                    PillEnabled = true,
                    PillField = "serviceActive",
                    PillText = "نشط",
                    PillCssClass = "pill pill-green",
                    PillMode = "replace"
                },
                // serviceActive inactive: numeric path
                new()
                {
                    Target = "row",
                    Field = "serviceActive",
                    Op = "eq",
                    Value = "0",
                    Priority = 1,
                    PillEnabled = true,
                    PillField = "serviceActive",
                    PillText = "غير نشط",
                    PillCssClass = "pill pill-red",
                    PillMode = "replace"
                },
                // serviceActive inactive: bool path
                new()
                {
                    Target = "row",
                    Field = "serviceActive",
                    Op = "eq",
                    Value = false,
                    Priority = 1,
                    PillEnabled = true,
                    PillField = "serviceActive",
                    PillText = "غير نشط",
                    PillCssClass = "pill pill-red",
                    PillMode = "replace"
                }
            };

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-solid fa-concierge-bell",
                TableDS = dsModel
            };

            return View("ServiceCatalogueList", page);
        }

        private async Task<List<OptionItem>> GetServiceCatalogueDsdOptionsAsync()
        {
            return await GetTicketDdlOptionsAsync("dsdName_A", "DSDID", "1", "DSDDL", "اختر الجهة المستهدفة");
        }
    }
}

