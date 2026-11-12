using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers.Tickets
{
    public partial class TicketController : Controller
    {
        public async Task<IActionResult> TicketAdmin()
        {
            if (!InitPageContext(out var redirect))
                return redirect!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = nameof(TicketController).Replace("Controller", "");
            PageName = "TicketAdmin";

            DataSet dsServices = await _mastersServies.GetDataLoadDataSetAsync(
                "ServiceCatalogueList", IdaraId, usersId, HostName, null, null
            );
            SplitDataSet(dsServices);

            DataSet dsAdminPerms = await _mastersServies.GetDataLoadDataSetAsync(
                "TicketAdmin", IdaraId, usersId, HostName
            );
            if ((dsAdminPerms?.Tables?.Count ?? 0) > 0)
            {
                if (permissionTable != null)
                    permissionTable.Merge(dsAdminPerms.Tables[0]);
                else
                    permissionTable = dsAdminPerms.Tables[0];
            }

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            // Each button needs its own permission; Masters_CRUD enforces the same names (ActionType without '_').
            bool canInsertService = false, canUpdateService = false, canDeleteService = false;
            bool canInsertClass = false, canUpdateClass = false, canDeleteClass = false;
            bool canInsertPriority = false, canUpdatePriority = false, canDeletePriority = false;
            bool canInsertStatus = false, canUpdateStatus = false, canDeleteStatus = false;
            bool canInsertPauseReason = false, canUpdatePauseReason = false, canDeletePauseReason = false;
            bool canInsertArbReason = false, canUpdateArbReason = false, canDeleteArbReason = false;
            bool canInsertQRR = false, canUpdateQRR = false, canDeleteQRR = false;
            bool canManageRoutingRules = false, canManageSLAPolicies = false, canApproveServiceSuggestion = false;

            foreach (DataRow row in permissionTable.Rows)
            {
                var perm = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                if (perm == "INSERTSERVICE") canInsertService = true;
                if (perm == "UPDATESERVICE") canUpdateService = true;
                if (perm == "DELETESERVICE") canDeleteService = true;
                if (perm == "INSERTTICKETCLASS") canInsertClass = true;
                if (perm == "UPDATETICKETCLASS") canUpdateClass = true;
                if (perm == "DELETETICKETCLASS") canDeleteClass = true;
                if (perm == "INSERTPRIORITY") canInsertPriority = true;
                if (perm == "UPDATEPRIORITY") canUpdatePriority = true;
                if (perm == "DELETEPRIORITY") canDeletePriority = true;
                if (perm == "INSERTTICKETSTATUS") canInsertStatus = true;
                if (perm == "UPDATETICKETSTATUS") canUpdateStatus = true;
                if (perm == "DELETETICKETSTATUS") canDeleteStatus = true;
                if (perm == "INSERTPAUSEREASON") canInsertPauseReason = true;
                if (perm == "UPDATEPAUSEREASON") canUpdatePauseReason = true;
                if (perm == "DELETEPAUSEREASON") canDeletePauseReason = true;
                if (perm == "INSERTARBITRATIONREASON") canInsertArbReason = true;
                if (perm == "UPDATEARBITRATIONREASON") canUpdateArbReason = true;
                if (perm == "DELETEARBITRATIONREASON") canDeleteArbReason = true;
                if (perm == "INSERTQUALITYREVIEWRESULT") canInsertQRR = true;
                if (perm == "UPDATEQUALITYREVIEWRESULT") canUpdateQRR = true;
                if (perm == "DELETEQUALITYREVIEWRESULT") canDeleteQRR = true;
                if (perm == "MANAGEROUTINGRULES") canManageRoutingRules = true;
                if (perm == "MANAGESLAPOLICIES") canManageSLAPolicies = true;
                if (perm == "APPROVESERVICESUGGESTION") canApproveServiceSuggestion = true;
            }

            // DDL pages return [0] permissions, [1] data.
            List<OptionItem> ticketClassOptions = await GetDDLAsync("ticketClassName_A", "ticketClassID", "1", "TicketClassDDL");
            List<OptionItem> priorityOptions = await GetDDLAsync("priorityName_A", "priorityID", "1", "PriorityDDL");

            var tabGroupKey = "ticket-admin";
            string currentUrl = $"/{ControllerName}/TicketAdmin";

            SmartTableDsModel BuildLookupTab(DataTable? dt, string rowIdCol, string tabKey, string tabLabel, string tabIcon, int tabOrder, bool isDefault,
                string pageNameForCrud,
                string insertAction, string updateAction, string deleteAction,
                bool canInsert, bool canUpdate, bool canDelete,
                Dictionary<string, string> headerMap, HashSet<string> hiddenCols,
                List<FieldConfig> insertVisible, List<FieldConfig> updateVisible,
                Dictionary<string, string>? editFieldMap = null)
            {
                var columns = new List<TableColumn>();
                var rows = new List<Dictionary<string, object?>>();

                if (dt != null && dt.Columns.Count > 0)
                {
                    foreach (DataColumn col in dt.Columns)
                    {
                        string colType = GetColType(col.DataType);
                        bool isHidden = hiddenCols.Contains(col.ColumnName);
                        string label = headerMap.TryGetValue(col.ColumnName, out var lbl) ? lbl : col.ColumnName;

                        columns.Add(new TableColumn
                        {
                            Field = col.ColumnName,
                            Label = label,
                            // Dates and yes/no flags are pre-formatted as text by FormatAdminDisplayValues.
                            Type = colType is "date" or "bool" ? "text" : colType,
                            Sortable = true,
                            Visible = !isHidden,
                            Tooltip = CodeColumnHint(col.ColumnName)
                        });
                    }

                    foreach (DataRow dr in dt.Rows)
                    {
                        var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                        foreach (DataColumn col in dt.Columns)
                            dict[col.ColumnName] = dr[col] == DBNull.Value ? null : dr[col];
                        dict["p01"] = dict.ContainsKey(rowIdCol) ? dict[rowIdCol] : null;

                        if (editFieldMap != null)
                        {
                            foreach (var kvp in editFieldMap)
                            {
                                if (!dict.ContainsKey(kvp.Key) && dict.ContainsKey(kvp.Value))
                                    dict[kvp.Key] = dict[kvp.Value];
                            }
                        }

                        // Display values only; the p.. aliases above keep the raw values for the edit forms.
                        FormatAdminDisplayValues(dict);

                        rows.Add(dict);
                    }
                }

                var toolbar = new TableToolbarConfig
                {
                    ShowRefresh = true,
                    ShowColumns = true,
                    ShowExportExcel = true,
                    ShowAdd = canInsert,
                    ShowEdit = canUpdate,
                    ShowDelete = canDelete
                };

                if (canInsert)
                {
                    var addFields = BuildCrudFields(pageNameForCrud, insertAction, currentUrl, insertVisible);
                    toolbar.Add = new TableAction
                    {
                        Label = "إضافة",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = $"إضافة {tabLabel}",
                        ModalMessage = "ملاحظة: جميع التعديلات مرصودة",
                        ModalMessageIcon = "fa-solid fa-circle-info",
                        ModalMessageClass = "bg-sky-100 text-sky-700",
                        OpenForm = new FormConfig
                        {
                            FormId = $"{tabKey}InsertForm",
                            Title = $"إضافة {tabLabel} جديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new() { Text = "حفظ", Type = "submit", Color = "success", Icon = "fa fa-check" },
                                new() { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    };
                }

                if (canUpdate)
                {
                    var editFields = BuildCrudFields(pageNameForCrud, updateAction, currentUrl, updateVisible, hasP01: true);
                    toolbar.Edit = new TableAction
                    {
                        Label = "تعديل",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        IsEdit = true,
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                        OpenModal = true,
                        ModalTitle = $"تعديل {tabLabel}",
                        OpenForm = new FormConfig
                        {
                            FormId = $"{tabKey}EditForm",
                            Title = $"تعديل {tabLabel}",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Fields = editFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new() { Text = "حفظ التعديلات", Type = "submit", Color = "info", Icon = "fa fa-check" },
                                new() { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    };
                }

                if (canDelete)
                {
                    var deleteFields = BuildCrudFields(pageNameForCrud, deleteAction, currentUrl,
                        new List<FieldConfig> { new() { Name = "p01", Type = "hidden" } },
                        hasP01: true, isDelete: true);

                    toolbar.Delete = new TableAction
                    {
                        Label = "حذف",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        IsEdit = true,
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                        OpenModal = true,
                        ModalTitle = "تحذير",
                        ModalMessage = $"هل أنت متأكد من حذف هذا الـ{tabLabel}؟",
                        ModalMessageIcon = "fa fa-exclamation-triangle text-red-600",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = $"{tabKey}DeleteForm",
                            Title = $"تأكيد حذف {tabLabel}",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new() { Text = "حذف", Type = "submit", Color = "danger", Icon = "fa fa-trash" },
                                new() { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = deleteFields
                        }
                    };
                }

                return new SmartTableDsModel
                {
                    PageTitle = tabLabel,
                    PanelTitle = tabLabel,
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
                    QuickSearchFields = columns.Where(c => c.Visible).Select(c => c.Field).Take(4).ToList(),
                    Toolbar = toolbar,
                    RenderMode = SmartTableRenderMode.Tab,
                    RenderAsTab = true,
                    TabGroupKey = tabGroupKey,
                    TabKey = tabKey,
                    TabLabel = tabLabel,
                    TabIcon = tabIcon,
                    TabDefaultActive = isDefault,
                    ShowTabCount = true,
                    TabOrder = tabOrder,
                    ShowToolbar = true,
                    EnablePagination = true
                };
            }

            // One call returns every lookup with its description (the DDL pages only return code/name,
            // which left the edit form's description empty and wiped it on save).
            // Tables: 0 permissions, 1 status, 2 pause reason, 3 arbitration reason,
            //         4 quality review result, 5 ticket class, 6 priority.
            var dsLookups = await _mastersServies.GetDataLoadDataSetAsync("TicketAdminLookup", IdaraId, usersId, HostName);
            DataTable? Lookup(int index) => (dsLookups?.Tables?.Count ?? 0) > index ? dsLookups!.Tables[index] : null;

            DataTable? dtStatus = Lookup(1);
            DataTable? dtPauseReason = Lookup(2);
            DataTable? dtArbReason = Lookup(3);
            DataTable? dtQRR = Lookup(4);
            DataTable? dtClass = Lookup(5);
            DataTable? dtPriority = Lookup(6);

            // Responsible unit: department -> branch -> section, each list filtered by the unit chosen above it.
            var unitTree = await LoadServiceUnitTreeAsync();
            AddServiceUnitColumns(dt1, unitTree);
            const string unitListUrl = "/crud/DDLFiltered?FK=parentDSDID&textcol=nodeName_A&ValueCol=DSDID&PageName=DSDTreeDDL&TableIndex=1";
            List<FieldConfig> ServiceUnitFields() => new()
            {
                new() { Label = "القسم", Name = "p11", Type = "select", Required = true, ColCss = "4", Select2 = true,
                        Options = unitTree.Departments, HelpText = "الجهة المسؤولة عن الخدمة: اختر القسم، ثم الفرع والشعبة إن وجدت." },
                new() { Label = "الفرع (اختياري)", Name = "p12", Type = "select", ColCss = "4", Select2 = true,
                        Options = new List<OptionItem>(), DependsOn = "p11", DependsUrl = unitListUrl },
                new() { Label = "الشعبة (اختياري)", Name = "p13", Type = "select", ColCss = "4", Select2 = true,
                        Options = new List<OptionItem>(), DependsOn = "p12", DependsUrl = unitListUrl }
            };

            var serviceHeaderMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["responsibleUnit"] = "الجهة المسؤولة",
                ["serviceID"] = "رقم الخدمة",
                ["serviceCode"] = "كود الخدمة",
                ["serviceName_A"] = "اسم الخدمة",
                ["serviceName_E"] = "اسم الخدمة (إنجليزي)",
                ["serviceDesc"] = "الوصف",
                ["idaraID_FK"] = "الإدارة",
                ["ticketClassID_FK"] = "فئة التذكرة",
                ["ticketClassName_A"] = "فئة التذكرة",
                ["ticketClassName_E"] = "فئة التذكرة",
                ["defaultPriorityID_FK"] = "الأولوية الافتراضية",
                ["priorityName_A"] = "الأولوية",
                ["priorityName_E"] = "الأولوية",
                ["requiresLocation"] = "يتطلب موقع",
                ["allowsChildTickets"] = "تذاكر فرعية",
                ["requiresQualityReview"] = "مراجعة جودة",
                ["serviceActive"] = "نشط"
            };
            var serviceHidden = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "serviceID", "idaraID_FK", "ticketClassID_FK", "defaultPriorityID_FK",
                "serviceName_E", "ticketClassName_E", "priorityName_E", "serviceActive",
                "unitDeptDSDID", "unitSecDSDID", "unitDivDSDID"
            };

            var serviceModel = BuildLookupTab(
                dt1, "serviceID", "services", "الخدمات", "fa-solid fa-concierge-bell", 1, true,
                "ServiceCatalogueList",
                "INSERT_SERVICE", "UPDATE_SERVICE", "DELETE_SERVICE",
                canInsertService, canUpdateService, canDeleteService,
                serviceHeaderMap, serviceHidden,
                new List<FieldConfig>
                {
                    // Service code is generated by ServiceSP (SRV-00042), so it is not asked for here.
                    new() { Label = "اسم الخدمة (عربي)", Name = "p03", Type = "text", Required = true, ColCss = "6", MaxLength = 200, TextMode = "arabic" },
                    new() { Label = "اسم الخدمة (إنجليزي) — اختياري", Name = "p04", Type = "text", ColCss = "6", MaxLength = 200, TextMode = "english" },
                    new() { Label = "الوصف", Name = "p05", Type = "textarea", ColCss = "12", MaxLength = 1000 },
                    new() { Label = "فئة التذكرة", Name = "p06", Type = "select", Options = ticketClassOptions, ColCss = "6", Select2 = true },
                    new() { Label = "الأولوية الافتراضية", Name = "p07", Type = "select", Options = priorityOptions, ColCss = "6", Select2 = true },
                    new() { Label = "يتطلب موقع", Name = "p08", Type = "checkbox", ColCss = "4" },
                    new() { Label = "يسمح بتذاكر فرعية", Name = "p09", Type = "checkbox", ColCss = "4" },
                    new() { Label = "يتطلب مراجعة جودة", Name = "p10", Type = "checkbox", ColCss = "4" }
                }.Concat(ServiceUnitFields()).ToList(),
                new List<FieldConfig>
                {
                    new() { Label = "كود الخدمة (تلقائي)", Name = "p02", Type = "text", Readonly = true, ColCss = "6", Tooltip = CodeColumnHint("serviceCode") },
                    new() { Label = "اسم الخدمة (عربي)", Name = "p03", Type = "text", Required = true, ColCss = "6", MaxLength = 200 },
                    new() { Label = "اسم الخدمة (إنجليزي) — اختياري", Name = "p04", Type = "text", ColCss = "6", MaxLength = 200 },
                    new() { Label = "الوصف", Name = "p05", Type = "textarea", ColCss = "12", MaxLength = 1000 },
                    new() { Label = "فئة التذكرة", Name = "p06", Type = "select", Options = ticketClassOptions, ColCss = "6", Select2 = true },
                    new() { Label = "الأولوية الافتراضية", Name = "p07", Type = "select", Options = priorityOptions, ColCss = "6", Select2 = true },
                    new() { Label = "يتطلب موقع", Name = "p08", Type = "checkbox", ColCss = "4" },
                    new() { Label = "يسمح بتذاكر فرعية", Name = "p09", Type = "checkbox", ColCss = "4" },
                    new() { Label = "يتطلب مراجعة جودة", Name = "p10", Type = "checkbox", ColCss = "4" }
                }.Concat(ServiceUnitFields()).ToList(),
                new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                {
                    ["p02"] = "serviceCode", ["p03"] = "serviceName_A", ["p04"] = "serviceName_E",
                    ["p05"] = "serviceDesc", ["p06"] = "ticketClassID_FK", ["p07"] = "defaultPriorityID_FK",
                    ["p08"] = "requiresLocation", ["p09"] = "allowsChildTickets", ["p10"] = "requiresQualityReview",
                    ["p11"] = "unitDeptDSDID", ["p12"] = "unitSecDSDID", ["p13"] = "unitDivDSDID"
                }
            );
            serviceModel.StyleRules = new List<TableStyleRule>
            {
                new() { Target="row", Field="priorityName_A", Op="eq", Value="حرج", Priority=2,
                    PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A",
                    PillCssClass="pill pill-red", PillMode="replace" },
                new() { Target="row", Field="priorityName_A", Op="eq", Value="عالي", Priority=2,
                    PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A",
                    PillCssClass="pill pill-orange", PillMode="replace" },
                new() { Target="row", Field="priorityName_A", Op="eq", Value="متوسط", Priority=2,
                    PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A",
                    PillCssClass="pill pill-blue", PillMode="replace" },
                new() { Target="row", Field="priorityName_A", Op="eq", Value="منخفض", Priority=2,
                    PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A",
                    PillCssClass="pill pill-green", PillMode="replace" }
            };

            // ---- Column filters for services tab (ported from ServiceCatalog) ----
            if (dt1 != null && dt1.Rows.Count > 0)
            {
                var classFilterVals = dt1.AsEnumerable()
                    .Select(r => r.Table.Columns.Contains("ticketClassName_A") && r["ticketClassName_A"] != DBNull.Value ? r["ticketClassName_A"]?.ToString()?.Trim() : "")
                    .Where(s => !string.IsNullOrWhiteSpace(s))
                    .Distinct().OrderBy(s => s)
                    .Select(s => new OptionItem { Value = s!, Text = s! }).ToList();

                var priorityFilterVals = dt1.AsEnumerable()
                    .Select(r => r.Table.Columns.Contains("priorityName_A") && r["priorityName_A"] != DBNull.Value ? r["priorityName_A"]?.ToString()?.Trim() : "")
                    .Where(s => !string.IsNullOrWhiteSpace(s))
                    .Distinct().OrderBy(s => s)
                    .Select(s => new OptionItem { Value = s!, Text = s! }).ToList();

                foreach (var col in serviceModel.Columns)
                {
                    if (col.Field == "ticketClassName_A" && classFilterVals.Count > 0)
                        col.Filter = new TableColumnFilter { Enabled = true, Type = "select", Options = classFilterVals };
                    else if (col.Field == "priorityName_A" && priorityFilterVals.Count > 0)
                        col.Filter = new TableColumnFilter { Enabled = true, Type = "select", Options = priorityFilterVals };
                }
            }

            var genericHeaderMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["ticketClassID"] = "رقم الفئة", ["ticketClassCode"] = "الكود", ["ticketClassName_A"] = "الاسم (عربي)",
                ["ticketClassName_E"] = "الاسم (إنجليزي)", ["ticketClassDesc"] = "الوصف", ["ticketClassActive"] = "نشط",
                ["entryDate"] = "تاريخ الإنشاء", ["entryData"] = "المستخدم",
                ["priorityID"] = "رقم الأولوية", ["priorityCode"] = "الكود", ["priorityName_A"] = "الاسم (عربي)",
                ["priorityName_E"] = "الاسم (إنجليزي)", ["priorityDesc"] = "الوصف", ["priorityLevel"] = "المستوى",
                ["priorityActive"] = "نشط",
                ["ticketStatusID"] = "رقم الحالة", ["ticketStatusCode"] = "الكود", ["ticketStatusName_A"] = "الاسم (عربي)",
                ["ticketStatusName_E"] = "الاسم (إنجليزي)", ["ticketStatusDesc"] = "الوصف", ["ticketStatusActive"] = "نشط",
                ["pauseReasonID"] = "رقم السبب", ["pauseReasonCode"] = "الكود", ["pauseReasonName_A"] = "الاسم (عربي)",
                ["pauseReasonName_E"] = "الاسم (إنجليزي)", ["pauseReasonDesc"] = "الوصف", ["pauseReasonActive"] = "نشط",
                ["arbitrationReasonID"] = "رقم السبب", ["arbitrationReasonCode"] = "الكود", ["arbitrationReasonName_A"] = "الاسم (عربي)",
                ["arbitrationReasonName_E"] = "الاسم (إنجليزي)", ["arbitrationReasonDesc"] = "الوصف", ["arbitrationReasonActive"] = "نشط",
                ["qualityReviewResultID"] = "رقم النتيجة", ["qualityReviewResultCode"] = "الكود", ["qualityReviewResultName_A"] = "الاسم (عربي)",
                ["qualityReviewResultName_E"] = "الاسم (إنجليزي)", ["qualityReviewResultDesc"] = "الوصف", ["qualityReviewResultActive"] = "نشط"
            };

            var lookupHidden = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "ticketClassID", "ticketClassName_E", "ticketClassActive", "entryData", "hostName",
                "priorityID", "priorityName_E", "priorityActive",
                "ticketStatusID", "ticketStatusName_E", "ticketStatusActive",
                "pauseReasonID", "pauseReasonName_E", "pauseReasonActive",
                "arbitrationReasonID", "arbitrationReasonName_E", "arbitrationReasonActive",
                "qualityReviewResultID", "qualityReviewResultName_E", "qualityReviewResultActive"
            };

            var classModel = BuildLookupTab(
                dtClass, "ticketClassID", "ticket-classes", "فئات التذاكر", "fa-solid fa-layer-group", 2, false,
                "TicketAdmin",
                "INSERT_TICKETCLASS", "UPDATE_TICKETCLASS", "DELETE_TICKETCLASS",
                canInsertClass, canUpdateClass, canDeleteClass,
                genericHeaderMap, lookupHidden,
                new List<FieldConfig>
                {
                    new() { Label = "الاسم (عربي)", Name = "p03", Type = "text", Required = true, ColCss = "6", MaxLength = 200, TextMode = "arabic" },
                    new() { Label = "الاسم (إنجليزي)", Name = "p04", Type = "text", ColCss = "6", MaxLength = 200, TextMode = "english" },
                    new() { Label = "الوصف", Name = "p05", Type = "textarea", ColCss = "12", MaxLength = 1000 }
                },
                new List<FieldConfig>
                {
                    new() { Label = "الكود (تلقائي)", Name = "p02", Type = "text", Readonly = true, ColCss = "6", Tooltip = CodeColumnHint("ticketClassCode") },
                    new() { Label = "الاسم (عربي)", Name = "p03", Type = "text", Required = true, ColCss = "6", MaxLength = 200 },
                    new() { Label = "الاسم (إنجليزي)", Name = "p04", Type = "text", ColCss = "6", MaxLength = 200 },
                    new() { Label = "الوصف", Name = "p05", Type = "textarea", ColCss = "12", MaxLength = 1000 }
                },
                new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                {
                    ["p02"] = "ticketClassCode", ["p03"] = "ticketClassName_A", ["p04"] = "ticketClassName_E", ["p05"] = "ticketClassDesc"
                }
            );

            var priorityHeaderMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["priorityID"] = "رقم الأولوية", ["priorityCode"] = "الكود", ["priorityName_A"] = "الاسم (عربي)",
                ["priorityName_E"] = "الاسم (إنجليزي)", ["priorityDesc"] = "الوصف", ["priorityLevel"] = "المستوى",
                ["priorityActive"] = "نشط", ["entryDate"] = "تاريخ الإنشاء"
            };
            var priorityHidden2 = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "priorityID", "priorityName_E", "priorityActive", "entryData", "hostName"
            };

            var priorityModel = BuildLookupTab(
                dtPriority, "priorityID", "priorities", "الأولويات", "fa-solid fa-signal", 3, false,
                "TicketAdmin",
                "INSERT_PRIORITY", "UPDATE_PRIORITY", "DELETE_PRIORITY",
                canInsertPriority, canUpdatePriority, canDeletePriority,
                priorityHeaderMap, priorityHidden2,
                new List<FieldConfig>
                {
                    new() { Label = "الاسم (عربي)", Name = "p03", Type = "text", Required = true, ColCss = "4", MaxLength = 200, TextMode = "arabic" },
                    new() { Label = "الاسم (إنجليزي)", Name = "p04", Type = "text", ColCss = "4", MaxLength = 200, TextMode = "english" },
                    new() { Label = "الوصف", Name = "p05", Type = "textarea", ColCss = "12", MaxLength = 1000 },
                    new() { Label = "المستوى", Name = "p06", Type = "text", ColCss = "6", TextMode = "number", RequiredMsg = "الرجاء إدخال المستوى" }
                },
                new List<FieldConfig>
                {
                    new() { Label = "الكود (تلقائي)", Name = "p02", Type = "text", Readonly = true, ColCss = "4", Tooltip = CodeColumnHint("priorityCode") },
                    new() { Label = "الاسم (عربي)", Name = "p03", Type = "text", Required = true, ColCss = "4", MaxLength = 200 },
                    new() { Label = "الاسم (إنجليزي)", Name = "p04", Type = "text", ColCss = "4", MaxLength = 200 },
                    new() { Label = "الوصف", Name = "p05", Type = "textarea", ColCss = "12", MaxLength = 1000 },
                    new() { Label = "المستوى", Name = "p06", Type = "text", ColCss = "6", TextMode = "number" }
                },
                new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                {
                    ["p02"] = "priorityCode", ["p03"] = "priorityName_A", ["p04"] = "priorityName_E", ["p05"] = "priorityDesc", ["p06"] = "priorityLevel"
                }
            );
            priorityModel.StyleRules = new List<TableStyleRule>
            {
                new() { Target="row", Field="priorityCode", Op="eq", Value="CRITICAL", Priority=1,
                    PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A",
                    PillCssClass="pill pill-red", PillMode="replace" },
                new() { Target="row", Field="priorityCode", Op="eq", Value="HIGH", Priority=1,
                    PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A",
                    PillCssClass="pill pill-orange", PillMode="replace" },
                new() { Target="row", Field="priorityCode", Op="eq", Value="MEDIUM", Priority=1,
                    PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A",
                    PillCssClass="pill pill-blue", PillMode="replace" },
                new() { Target="row", Field="priorityCode", Op="eq", Value="LOW", Priority=1,
                    PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A",
                    PillCssClass="pill pill-green", PillMode="replace" },
                new() { Target="row", Field="priorityCode", Op="eq", Value="PLANNED", Priority=1,
                    PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A",
                    PillCssClass="pill pill-gray", PillMode="replace" }
            };

            var statusHeaderMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["ticketStatusID"] = "رقم الحالة", ["ticketStatusCode"] = "الكود", ["ticketStatusName_A"] = "الاسم (عربي)",
                ["ticketStatusName_E"] = "الاسم (إنجليزي)", ["ticketStatusDesc"] = "الوصف", ["ticketStatusActive"] = "نشط",
                ["entryDate"] = "تاريخ الإنشاء"
            };
            var statusHidden = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "ticketStatusID", "ticketStatusName_E", "ticketStatusActive", "entryData", "hostName"
            };

            var statusModel = BuildLookupTab(
                dtStatus, "ticketStatusID", "statuses", "حالات التذكرة", "fa-solid fa-circle-half-stroke", 4, false,
                "TicketAdmin",
                "INSERT_TICKETSTATUS", "UPDATE_TICKETSTATUS", "DELETE_TICKETSTATUS",
                canInsertStatus, canUpdateStatus, canDeleteStatus,
                statusHeaderMap, statusHidden,
                new List<FieldConfig>
                {
                    new() { Label = "الاسم (عربي)", Name = "p03", Type = "text", Required = true, ColCss = "6", MaxLength = 200, TextMode = "arabic" },
                    new() { Label = "الاسم (إنجليزي)", Name = "p04", Type = "text", ColCss = "6", MaxLength = 200, TextMode = "english" },
                    new() { Label = "الوصف", Name = "p05", Type = "textarea", ColCss = "12", MaxLength = 1000 }
                },
                new List<FieldConfig>
                {
                    new() { Label = "الكود (تلقائي)", Name = "p02", Type = "text", Readonly = true, ColCss = "6", Tooltip = CodeColumnHint("ticketStatusCode") },
                    new() { Label = "الاسم (عربي)", Name = "p03", Type = "text", Required = true, ColCss = "6", MaxLength = 200 },
                    new() { Label = "الاسم (إنجليزي)", Name = "p04", Type = "text", ColCss = "6", MaxLength = 200 },
                    new() { Label = "الوصف", Name = "p05", Type = "textarea", ColCss = "12", MaxLength = 1000 }
                },
                new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                {
                    ["p02"] = "ticketStatusCode", ["p03"] = "ticketStatusName_A", ["p04"] = "ticketStatusName_E", ["p05"] = "ticketStatusDesc"
                }
            );
            statusModel.StyleRules = new List<TableStyleRule>
            {
                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="NEW", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-gray", PillMode="replace" },
                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="IN_PROGRESS", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-green", PillMode="replace" },
                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="RESOLVED", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-green", PillMode="replace" },
                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="CLOSED", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-gray", PillMode="replace" },
                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="REJECTED", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-red", PillMode="replace" },
                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="ARBITRATION", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-purple", PillMode="replace" },
                new() { Target="row", Field="ticketStatusCode", Op="eq", Value="PAUSED", Priority=1,
                    PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A",
                    PillCssClass="pill pill-orange", PillMode="replace" }
            };

            var pauseReasonHeaderMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["pauseReasonID"] = "رقم السبب", ["pauseReasonCode"] = "الكود", ["pauseReasonName_A"] = "الاسم (عربي)",
                ["pauseReasonName_E"] = "الاسم (إنجليزي)", ["pauseReasonDesc"] = "الوصف", ["pauseReasonActive"] = "نشط",
                ["entryDate"] = "تاريخ الإنشاء"
            };
            var pauseReasonHidden = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "pauseReasonID", "pauseReasonName_E", "pauseReasonActive", "entryData", "hostName"
            };

            var pauseReasonModel = BuildLookupTab(
                dtPauseReason, "pauseReasonID", "pause-reasons", "أسباب الإيقاف", "fa-solid fa-pause-circle", 5, false,
                "TicketAdmin",
                "INSERT_PAUSEREASON", "UPDATE_PAUSEREASON", "DELETE_PAUSEREASON",
                canInsertPauseReason, canUpdatePauseReason, canDeletePauseReason,
                pauseReasonHeaderMap, pauseReasonHidden,
                new List<FieldConfig>
                {
                    new() { Label = "الاسم (عربي)", Name = "p03", Type = "text", Required = true, ColCss = "6", MaxLength = 200, TextMode = "arabic" },
                    new() { Label = "الاسم (إنجليزي)", Name = "p04", Type = "text", ColCss = "6", MaxLength = 200, TextMode = "english" },
                    new() { Label = "الوصف", Name = "p05", Type = "textarea", ColCss = "12", MaxLength = 1000 }
                },
                new List<FieldConfig>
                {
                    new() { Label = "الكود (تلقائي)", Name = "p02", Type = "text", Readonly = true, ColCss = "6", Tooltip = CodeColumnHint("pauseReasonCode") },
                    new() { Label = "الاسم (عربي)", Name = "p03", Type = "text", Required = true, ColCss = "6", MaxLength = 200 },
                    new() { Label = "الاسم (إنجليزي)", Name = "p04", Type = "text", ColCss = "6", MaxLength = 200 },
                    new() { Label = "الوصف", Name = "p05", Type = "textarea", ColCss = "12", MaxLength = 1000 }
                },
                new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                {
                    ["p02"] = "pauseReasonCode", ["p03"] = "pauseReasonName_A", ["p04"] = "pauseReasonName_E", ["p05"] = "pauseReasonDesc"
                }
            );

            var arbReasonHeaderMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["arbitrationReasonID"] = "رقم السبب", ["arbitrationReasonCode"] = "الكود", ["arbitrationReasonName_A"] = "الاسم (عربي)",
                ["arbitrationReasonName_E"] = "الاسم (إنجليزي)", ["arbitrationReasonDesc"] = "الوصف", ["arbitrationReasonActive"] = "نشط",
                ["entryDate"] = "تاريخ الإنشاء"
            };
            var arbReasonHidden = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "arbitrationReasonID", "arbitrationReasonName_E", "arbitrationReasonActive", "entryData", "hostName"
            };

            var arbReasonModel = BuildLookupTab(
                dtArbReason, "arbitrationReasonID", "arbitration-reasons", "أسباب التحكيم", "fa-solid fa-gavel", 6, false,
                "TicketAdmin",
                "INSERT_ARBITRATIONREASON", "UPDATE_ARBITRATIONREASON", "DELETE_ARBITRATIONREASON",
                canInsertArbReason, canUpdateArbReason, canDeleteArbReason,
                arbReasonHeaderMap, arbReasonHidden,
                new List<FieldConfig>
                {
                    new() { Label = "الاسم (عربي)", Name = "p03", Type = "text", Required = true, ColCss = "6", MaxLength = 200, TextMode = "arabic" },
                    new() { Label = "الاسم (إنجليزي)", Name = "p04", Type = "text", ColCss = "6", MaxLength = 200, TextMode = "english" },
                    new() { Label = "الوصف", Name = "p05", Type = "textarea", ColCss = "12", MaxLength = 1000 }
                },
                new List<FieldConfig>
                {
                    new() { Label = "الكود (تلقائي)", Name = "p02", Type = "text", Readonly = true, ColCss = "6", Tooltip = CodeColumnHint("arbitrationReasonCode") },
                    new() { Label = "الاسم (عربي)", Name = "p03", Type = "text", Required = true, ColCss = "6", MaxLength = 200 },
                    new() { Label = "الاسم (إنجليزي)", Name = "p04", Type = "text", ColCss = "6", MaxLength = 200 },
                    new() { Label = "الوصف", Name = "p05", Type = "textarea", ColCss = "12", MaxLength = 1000 }
                },
                new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                {
                    ["p02"] = "arbitrationReasonCode", ["p03"] = "arbitrationReasonName_A", ["p04"] = "arbitrationReasonName_E", ["p05"] = "arbitrationReasonDesc"
                }
            );

            var qrrHeaderMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["qualityReviewResultID"] = "رقم النتيجة", ["qualityReviewResultCode"] = "الكود", ["qualityReviewResultName_A"] = "الاسم (عربي)",
                ["qualityReviewResultName_E"] = "الاسم (إنجليزي)", ["qualityReviewResultDesc"] = "الوصف", ["qualityReviewResultActive"] = "نشط",
                ["entryDate"] = "تاريخ الإنشاء"
            };
            var qrrHidden = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "qualityReviewResultID", "qualityReviewResultName_E", "qualityReviewResultActive", "entryData", "hostName"
            };

            var qrrModel = BuildLookupTab(
                dtQRR, "qualityReviewResultID", "quality-review-results", "نتائج المراجعة", "fa-solid fa-clipboard-check", 7, false,
                "TicketAdmin",
                "INSERT_QUALITYREVIEWRESULT", "UPDATE_QUALITYREVIEWRESULT", "DELETE_QUALITYREVIEWRESULT",
                canInsertQRR, canUpdateQRR, canDeleteQRR,
                qrrHeaderMap, qrrHidden,
                new List<FieldConfig>
                {
                    new() { Label = "الاسم (عربي)", Name = "p03", Type = "text", Required = true, ColCss = "6", MaxLength = 200, TextMode = "arabic" },
                    new() { Label = "الاسم (إنجليزي)", Name = "p04", Type = "text", ColCss = "6", MaxLength = 200, TextMode = "english" },
                    new() { Label = "الوصف", Name = "p05", Type = "textarea", ColCss = "12", MaxLength = 1000 }
                },
                new List<FieldConfig>
                {
                    new() { Label = "الكود (تلقائي)", Name = "p02", Type = "text", Readonly = true, ColCss = "6", Tooltip = CodeColumnHint("qualityReviewResultCode") },
                    new() { Label = "الاسم (عربي)", Name = "p03", Type = "text", Required = true, ColCss = "6", MaxLength = 200 },
                    new() { Label = "الاسم (إنجليزي)", Name = "p04", Type = "text", ColCss = "6", MaxLength = 200 },
                    new() { Label = "الوصف", Name = "p05", Type = "textarea", ColCss = "12", MaxLength = 1000 }
                },
                new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                {
                    ["p02"] = "qualityReviewResultCode", ["p03"] = "qualityReviewResultName_A", ["p04"] = "qualityReviewResultName_E", ["p05"] = "qualityReviewResultDesc"
                }
            );

            var arbInboxModel = await BuildArbitrationInboxTabAsync(tabGroupKey, 8);

            var page = new SmartPageViewModel
            {
                PageTitle = "إدارة نظام التذاكر",
                PanelTitle = "إدارة نظام التذاكر",
                PanelIcon = "fa-solid fa-sliders",
                TableDS = serviceModel,
                TableDS1 = classModel,
                TableDS2 = priorityModel,
                TableDS3 = statusModel,
                TableDS4 = pauseReasonModel,
                TableDS5 = arbReasonModel,
                TableDS6 = qrrModel,
                TableDS7 = arbInboxModel
            };

            return View("TicketAdmin", page);
        }

        /// <summary>
        /// Org units for the service form (TicketDL page DSDTreeDDL): table 1 is the unit tree
        /// (DSDID, dsdLevel, parentDSDID, nodeName_A, dsdName_A), table 2 each service's active routing target.
        /// </summary>
        private sealed class ServiceUnitTree
        {
            public List<OptionItem> Departments { get; } = new();
            public Dictionary<string, (int Level, string Parent, string Path)> Units { get; } = new();
            public Dictionary<string, string> ServiceTargets { get; } = new();
        }

        private async Task<ServiceUnitTree> LoadServiceUnitTreeAsync()
        {
            var tree = new ServiceUnitTree();
            var ds = await _mastersServies.GetDataLoadDataSetAsync("DSDTreeDDL", IdaraId, usersId, HostName);

            var units = (ds?.Tables?.Count ?? 0) > 1 ? ds!.Tables[1] : null;
            if (units != null && units.Columns.Contains("DSDID") && !IsGatewayErrorTable(units))
            {
                foreach (DataRow row in units.Rows)
                {
                    var id = row["DSDID"]?.ToString()?.Trim();
                    if (string.IsNullOrEmpty(id))
                        continue;

                    int.TryParse(row["dsdLevel"]?.ToString(), out var level);
                    tree.Units[id] = (level, row["parentDSDID"]?.ToString()?.Trim() ?? "0", row["dsdName_A"]?.ToString() ?? "");
                    if (level == 1)
                        tree.Departments.Add(new OptionItem { Value = id, Text = row["nodeName_A"]?.ToString() ?? id });
                }
            }

            var targets = (ds?.Tables?.Count ?? 0) > 2 ? ds!.Tables[2] : null;
            if (targets != null && targets.Columns.Contains("serviceID") && targets.Columns.Contains("targetDSDID"))
            {
                foreach (DataRow row in targets.Rows)
                {
                    var serviceId = row["serviceID"]?.ToString()?.Trim();
                    var target = row["targetDSDID"]?.ToString()?.Trim();
                    if (!string.IsNullOrEmpty(serviceId) && !string.IsNullOrEmpty(target))
                        tree.ServiceTargets[serviceId] = target;
                }
            }

            tree.Departments.Insert(0, new OptionItem { Value = "", Text = "الرجاء اختيار القسم" });
            return tree;
        }

        /// <summary>
        /// Adds the service's responsible unit to the services table: a readable path for the grid
        /// and the department / branch / section unit ids that fill the edit form's three lists.
        /// </summary>
        private static void AddServiceUnitColumns(DataTable? services, ServiceUnitTree tree)
        {
            if (services == null || !services.Columns.Contains("serviceID"))
                return;

            foreach (var name in new[] { "responsibleUnit", "unitDeptDSDID", "unitSecDSDID", "unitDivDSDID" })
                if (!services.Columns.Contains(name))
                    services.Columns.Add(name, typeof(string));

            if (services.Columns.Contains("serviceName_A"))
                services.Columns["responsibleUnit"]!.SetOrdinal(services.Columns["serviceName_A"]!.Ordinal + 1);

            foreach (DataRow row in services.Rows)
            {
                var serviceId = row["serviceID"]?.ToString()?.Trim() ?? "";
                if (!tree.ServiceTargets.TryGetValue(serviceId, out var target) || !tree.Units.TryGetValue(target, out var unit))
                {
                    row["responsibleUnit"] = "-";
                    continue;
                }

                row["responsibleUnit"] = unit.Path;

                // Walk up from the target unit to fill each level (section -> branch -> department).
                var current = target;
                while (tree.Units.TryGetValue(current, out var node))
                {
                    var column = node.Level switch { 1 => "unitDeptDSDID", 2 => "unitSecDSDID", 3 => "unitDivDSDID", _ => null };
                    if (column != null)
                        row[column] = current;
                    if (node.Level <= 1 || node.Parent == "0")
                        break;
                    current = node.Parent;
                }
            }
        }

        /// <summary>
        /// Explains the automatic code of each lookup (shown as a hint on the code column header).
        /// English codes without a prefix (NEW, HIGH, CLARIFICATION ...) are system codes the ticket flow relies on.
        /// </summary>
        private static string? CodeColumnHint(string column)
        {
            const string system = " — الأكواد الإنجليزية الكاملة ثابتة للنظام";

            return column.ToLowerInvariant() switch
            {
                "servicecode" => "SRV = Service = خدمة",
                "ticketclasscode" => "CLS = Class = فئة التذكرة",
                "prioritycode" => "PRI = Priority = الأولوية" + system,
                "ticketstatuscode" => "STS = Status = حالة التذكرة" + system,
                "pausereasoncode" => "PSR = Pause Reason = سبب الإيقاف" + system,
                "arbitrationreasoncode" => "ARB = Arbitration = سبب التحكيم",
                "qualityreviewresultcode" => "QRR = Quality Review Result = نتيجة مراجعة الجودة" + system,
                _ => null
            };
        }

        private static bool IsAdminFlagColumn(string column) => column.ToLowerInvariant() switch
        {
            "requireslocation" or "allowschildtickets" or "requiresqualityreview" => true,
            _ => false
        };

        private static string? ArbitrationStatusName(string? code) => code?.Trim().ToUpperInvariant() switch
        {
            "OPEN" => "مفتوحة",
            "DECIDED" => "تم القرار",
            "CANCELLED" => "ملغاة",
            _ => null
        };

        /// <summary>
        /// Turns raw admin values into readable text: dates as yyyy-MM-dd, flags as نعم / لا.
        /// The data layer returns every column as text, so this works on the values themselves.
        /// </summary>
        private static void FormatAdminDisplayValues(Dictionary<string, object?> row)
        {
            foreach (var key in row.Keys.ToList())
            {
                var value = row[key];
                if (value is null)
                    continue;

                if (key.EndsWith("Date", StringComparison.OrdinalIgnoreCase)
                    && DateTime.TryParse(value.ToString(), out var date))
                {
                    row[key] = date.ToString("yyyy-MM-dd");
                }
                else if (IsAdminFlagColumn(key))
                {
                    var text = value.ToString()?.Trim();
                    row[key] = text == "1" || string.Equals(text, "true", StringComparison.OrdinalIgnoreCase) ? "نعم" : "لا";
                }
            }
        }

        /// <summary>
        /// Open arbitration cases tab; shown only to users with an arbitration permission on TicketDetails.
        /// </summary>
        private async Task<SmartTableDsModel?> BuildArbitrationInboxTabAsync(string tabGroupKey, int tabOrder)
        {
            // Arbitration permissions are granted on the TicketDetails menu item, not TicketAdmin.
            var dsDetailPerms = await _mastersServies.GetDataLoadDataSetAsync(
                "TicketDetails", IdaraId, usersId, HostName);
            var detailPermTable = (dsDetailPerms?.Tables?.Count ?? 0) > 0 ? dsDetailPerms!.Tables[0] : null;

            var detailPerms = detailPermTable?.Rows.Cast<DataRow>()
                .Select(row => row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper())
                .ToHashSet() ?? new HashSet<string?>();
            var canDecide = detailPerms.Contains("DECIDE_ARBITRATION");
            var canCancel = detailPerms.Contains("CANCEL_ARBITRATION");
            var canViewArbitrationInbox = canDecide || canCancel || detailPerms.Contains("RAISE_ARBITRATION");

            if (!canViewArbitrationInbox)
                return null;

            DataSet dsArb = await _mastersServies.GetDataLoadDataSetAsync(
                "OpenArbitrations", IdaraId, usersId, HostName
            );
            DataTable? dtArb = (dsArb?.Tables?.Count ?? 0) > 1 ? dsArb!.Tables[1] : null;
            if (dtArb == null || dtArb.Columns.Count == 0 || IsGatewayErrorTable(dtArb))
                return null;

            var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["arbitrationCaseID"] = "رقم حالة التحكيم",
                ["ticketID_FK"] = "معرف التذكرة",
                ["ticketNo"] = "رقم التذكرة",
                ["title_A"] = "العنوان",
                ["title"] = "العنوان",
                ["arbitrationReasonName_A"] = "سبب التحكيم",
                ["arbitrationReasonName_E"] = "سبب التحكيم",
                ["arbitrationStatus"] = "حالة التحكيم",
                ["entryDate"] = "تاريخ الإنشاء"
            };

            // Arabic reason/title are shown; the English duplicates and the internal ticket id are hidden.
            var hiddenCols = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "ticketID_FK", "arbitrationReasonName_E", "title" };
            if (!dtArb.Columns.Contains("title_A"))
                hiddenCols.Remove("title");

            var arbCols = new List<TableColumn>();
            foreach (DataColumn col in dtArb.Columns)
            {
                arbCols.Add(new TableColumn
                {
                    Field = col.ColumnName,
                    Label = headerMap.TryGetValue(col.ColumnName, out var label) ? label : col.ColumnName,
                    Type = "text",
                    Sortable = true,
                    Visible = !hiddenCols.Contains(col.ColumnName)
                });
            }

            var arbRows = ConvertTableToDictionaryList(dtArb);
            foreach (var row in arbRows)
            {
                if (row.TryGetValue("arbitrationStatus", out var status)
                    && ArbitrationStatusName(status?.ToString()) is { } statusName)
                    row["arbitrationStatus"] = statusName;
                row["p01"] = row.GetValueOrDefault("arbitrationCaseID");
                FormatAdminDisplayValues(row);
            }

            // Decision actions (Masters_CRUD DECIDE_ARBITRATION: p01 case, p02 type, p03 target unit, p04 notes).
            var arbActions = new List<TableAction>();
            List<FieldConfig> ArbitrationFormBase(string actionType) => new()
            {
                new() { Name = "pageName_", Type = "hidden", Value = "TicketDetails" },
                new() { Name = "ActionType", Type = "hidden", Value = actionType },
                new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new() { Name = "entrydata", Type = "hidden", Value = usersId },
                new() { Name = "hostname", Type = "hidden", Value = HostName },
                new() { Name = "redirectUrl", Type = "hidden", Value = "/Ticket/TicketAdmin" },
                new() { Name = "p01", Type = "hidden" }
            };

            if (canDecide)
            {
                var decideFields = ArbitrationFormBase("DECIDE_ARBITRATION");
                decideFields.Add(new FieldConfig
                {
                    Label = "القرار", Name = "p02", Type = "select", Required = true, ColCss = "12",
                    Value = "UPHOLD",
                    Options = new List<OptionItem>
                    {
                        new() { Value = "UPHOLD", Text = "تأييد — تستمر التذكرة في نفس الجهة" },
                        new() { Value = "REDIRECT", Text = "تحويل — تُحوَّل التذكرة إلى جهة أخرى" }
                    },
                    ShowFieldsWhen = new Dictionary<string, List<string>> { ["REDIRECT"] = new() { "p03" } }
                });
                decideFields.Add(new FieldConfig
                {
                    Label = "الجهة المحوَّل إليها", Name = "p03", Type = "select", Required = true, ColCss = "12", Select2 = true,
                    Options = await GetTicketDdlOptionsAsync("dsdName_A", "DSDID", "1", "DSDDL"),
                    HelpText = "تُعاد التذكرة إلى حالة «موجّه» بدون موظف، ليعيّنها مشرف الجهة الجديدة."
                });
                decideFields.Add(new FieldConfig { Label = "مبررات القرار", Name = "p04", Type = "textarea", Required = true, ColCss = "12", MaxLength = 2000 });

                arbActions.Add(new TableAction
                {
                    Label = "قرار التحكيم", Icon = "fa-solid fa-scale-balanced", Color = "success",
                    OpenModal = true, ModalTitle = "قرار التحكيم", Placement = TableActionPlacement.Button,
                    RequireSelection = true, MinSelection = 1, MaxSelection = 1, IsEdit = true,
                    OpenForm = new FormConfig { FormId = "decideArbitrationForm", Method = "post", ActionUrl = "/crud/insert", Fields = decideFields }
                });
            }

            if (canCancel)
            {
                var cancelFields = ArbitrationFormBase("CANCEL_ARBITRATION");
                cancelFields.Add(new FieldConfig { Label = "سبب الإلغاء", Name = "p02", Type = "textarea", Required = true, ColCss = "12", MaxLength = 2000 });

                arbActions.Add(new TableAction
                {
                    Label = "إلغاء التحكيم", Icon = "fa-solid fa-ban", Color = "danger",
                    OpenModal = true, ModalTitle = "إلغاء التحكيم", Placement = TableActionPlacement.Button,
                    RequireSelection = true, MinSelection = 1, MaxSelection = 1, IsEdit = true,
                    OpenForm = new FormConfig { FormId = "cancelArbitrationForm", Method = "post", ActionUrl = "/crud/insert", Fields = cancelFields }
                });
            }

            return new SmartTableDsModel
            {
                PanelTitle = "صندوق التحكيم",
                Columns = arbCols,
                Rows = arbRows,
                RowIdField = "arbitrationCaseID",
                PageSize = 10,
                Searchable = true,
                ShowTabCount = true,
                Toolbar = new TableToolbarConfig { ShowAdd = false, ShowEdit = false, ShowDelete = false, ShowRefresh = true, CustomActions = arbActions },
                RenderMode = SmartTableRenderMode.Tab,
                RenderAsTab = true,
                TabGroupKey = tabGroupKey,
                TabKey = "arbitration-inbox",
                TabLabel = "صندوق التحكيم",
                TabIcon = "fa-solid fa-gavel",
                TabOrder = tabOrder
            };
        }

        private List<FieldConfig> BuildCrudFields(string pageName, string actionType, string redirectUrl,
            List<FieldConfig> visibleFields, bool hasP01 = false, bool isDelete = false, string redirectAction = "TicketAdmin")
        {
            var fields = new List<FieldConfig>
            {
                new() { Name = "redirectUrl", Type = "hidden", Value = redirectUrl },
                new() { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new() { Name = "redirectAction", Type = "hidden", Value = redirectAction },
                new() { Name = "pageName_", Type = "hidden", Value = pageName },
                new() { Name = "ActionType", Type = "hidden", Value = actionType },
                new() { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new() { Name = "entrydata", Type = "hidden", Value = usersId },
                new() { Name = "hostname", Type = "hidden", Value = HostName }
            };

            if (hasP01)
                fields.Add(new FieldConfig { Name = "p01", Type = "hidden" });

            fields.AddRange(visibleFields);
            return fields;
        }
    }
}
