using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Globalization;

namespace SmartFoundation.Mvc.Controllers.Support
{
    public partial class SupportController : Controller
    {
        public async Task<IActionResult> SupportMyTickets()
        {
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = "Support";
            PageName = string.IsNullOrWhiteSpace(PageName) ? "SupportMyTickets" : PageName;

            var spParameters = new object?[]
            {
                PageName ?? "SupportMyTickets",
                IdaraId,
                usersId,
                HostName
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();
            var ticketTypeOptions = new List<OptionItem>();
            var priorityOptions = new List<OptionItem>();
            var pageOptions = new List<OptionItem>();
            var actionOptions = new List<OptionItem>();

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            SplitDataSet(ds);

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            bool canAccess = false;
            bool canInsert = false;

            foreach (DataRow row in permissionTable.Rows)
            {
                var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                if (permissionName == "SMT_ACCESS" || permissionName == "SMT_SELECT") canAccess = true;
                if (permissionName == "SMT_CREATE_TICKET") canInsert = true;
            }

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
                        ["ticketTitle"] = "عنوان التذكرة",
                        ["ticketDescription"] = "وصف المشكلة",
                        ["ticketTypeName_A"] = "نوع التذكرة",
                        ["priorityName_A"] = "الأولوية",
                        ["statusName_A"] = "الحالة",
                        ["affectedPageName"] = "اسم الصفحة",
                        ["affectedPageUrl"] = "رابط الصفحة",
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

                        dynamicColumns.Add(new TableColumn
                        {
                            Field = c.ColumnName,
                            Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                            Type = colType,
                            Sortable = true,
                            Visible = !c.ColumnName.Equals("ticketID", StringComparison.OrdinalIgnoreCase)
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
                        dict["p02"] = Get("ticketNo");
                        dict["p03"] = Get("ticketTitle");
                        dict["p04"] = Get("ticketDescription");

                        rowsList.Add(dict);
                    }
                }

                if (dt2 != null && dt2.Columns.Contains("ticketTypeID") && dt2.Columns.Contains("ticketTypeName_A"))
                {
                    foreach (DataRow r in dt2.Rows)
                    {
                        var value = r["ticketTypeID"]?.ToString()?.Trim();
                        var text = r["ticketTypeName_A"]?.ToString()?.Trim();
                        if (!string.IsNullOrWhiteSpace(value) && !string.IsNullOrWhiteSpace(text))
                            ticketTypeOptions.Add(new OptionItem { Value = value, Text = text });
                    }
                }

                if (dt3 != null && dt3.Columns.Contains("priorityID") && dt3.Columns.Contains("priorityName_A"))
                {
                    foreach (DataRow r in dt3.Rows)
                    {
                        var value = r["priorityID"]?.ToString()?.Trim();
                        var text = r["priorityName_A"]?.ToString()?.Trim();
                        if (!string.IsNullOrWhiteSpace(value) && !string.IsNullOrWhiteSpace(text))
                            priorityOptions.Add(new OptionItem { Value = value, Text = text });
                    }
                }

                if (dt4 != null && dt4.Columns.Contains("menuName_A"))
                {
                    var seenPages = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                    foreach (DataRow r in dt4.Rows)
                    {
                        var pageName = r["menuName_A"]?.ToString()?.Trim();
                        if (!string.IsNullOrWhiteSpace(pageName) && seenPages.Add(pageName))
                            pageOptions.Add(new OptionItem { Value = pageName, Text = pageName });
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.supportMyTicketsDataSetError = ex.Message;
            }

            var addFields = new List<FieldConfig>
            {
                new FieldConfig
                {
                    Name = "p01",
                    Label = "نوع التذكرة",
                    Type = "select",
                    ColCss = "6",
                    Required = true,
                    Placeholder = "",
                    Options = ticketTypeOptions
                },
                new FieldConfig
                {
                    Name = "p02",
                    Label = "الأولوية",
                    Type = "select",
                    ColCss = "6",
                    Required = true,
                    Placeholder = "",
                    Options = priorityOptions
                },
                new FieldConfig
                {
                    Name = "p03",
                    Label = "عنوان التذكرة",
                    Type = "text",
                    ColCss = "12",
                    Required = true,
                    MaxLength = 300
                },
                new FieldConfig
                {
                    Name = "p04",
                    Label = "وصف التذكرة",
                    Type = "textarea",
                    ColCss = "12",
                    Required = true
                },
                new FieldConfig
                {
                    Name = "p05",
                    Label = "اسم الصفحة (اختياري)",
                    Type = "select",
                    ColCss = "6",
                    Required = false,
                    Select2 = true,
                    Placeholder = "",
                    Options = pageOptions,
                    OnChangeJs = "sfSupportPageChanged(this)"
                },
                new FieldConfig
                {
                    Name = "p06",
                    Label = "رابط الصفحة (اختياري)",
                    Type = "text",
                    ColCss = "6",
                    Required = false,
                    Readonly = true,
                    Placeholder = "يتم تعبئته تلقائيا عند اختيار الصفحة"
                },
                new FieldConfig
                {
                    Name = "p07",
                    Label = "الإجراء داخل الصفحة (اختياري)",
                    Type = "select",
                    ColCss = "6",
                    Required = false,
                    Select2 = true,
                    Placeholder = "",
                    Disabled = true,
                    Options = actionOptions
                },
                new FieldConfig
                {
                    Name = "p08",
                    Label = "تفاصيل إضافية للخطأ",
                    Type = "textarea",
                    ColCss = "6",
                    Required = false
                }
            };

            addFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            addFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            addFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            addFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "SMT_CREATE_TICKET" });
            addFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "تذاكري",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = "تذاكر الدعم الخاصة بي",
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = canInsert,
                    ShowEdit = false,
                    ShowDelete = false,
                    ShowBulkDelete = false,
                    ShowExportPdf = false,
                    Add = new TableAction
                    {
                        Label = "تذكرة جديدة",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إنشاء تذكرة دعم",
                        OpenForm = new FormConfig
                        {
                            FormId = "supportMyTicketsInsertForm",
                            Title = "بيانات التذكرة",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ",   Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    }
                }
            };

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-life-ring",
                TableDS = dsModel
            };

            return View("SupportMyTickets", page);
        }

        [HttpGet]
        public async Task<IActionResult> SupportMyTicketsPageMeta(string? pageName = null)
        {
            if (!InitPageContext(out _))
                return Unauthorized();

            if (string.IsNullOrWhiteSpace(usersId))
                return Unauthorized();

            var selectedPageName = (pageName ?? string.Empty).Trim();
            if (string.IsNullOrWhiteSpace(selectedPageName))
            {
                return Json(new
                {
                    pageUrl = string.Empty,
                    actions = Array.Empty<object>()
                });
            }

            try
            {
                var spParameters = new object?[]
                {
                    "SupportMyTickets",
                    IdaraId,
                    usersId,
                    HostName
                };

                DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
                DataTable? pagesTable = (ds?.Tables?.Count ?? 0) > 4 ? ds.Tables[4] : null;
                DataTable? actionsTable = (ds?.Tables?.Count ?? 0) > 5 ? ds.Tables[5] : null;

                string pageUrl = string.Empty;
                long? selectedMenuId = null;

                if (pagesTable != null)
                {
                    foreach (DataRow row in pagesTable.Rows)
                    {
                        var nameA = pagesTable.Columns.Contains("menuName_A") ? row["menuName_A"]?.ToString()?.Trim() : null;
                        var nameE = pagesTable.Columns.Contains("menuName_E") ? row["menuName_E"]?.ToString()?.Trim() : null;

                        if (string.Equals(nameA, selectedPageName, StringComparison.OrdinalIgnoreCase)
                            || string.Equals(nameE, selectedPageName, StringComparison.OrdinalIgnoreCase))
                        {
                            if (pagesTable.Columns.Contains("menuLink"))
                                pageUrl = row["menuLink"]?.ToString()?.Trim() ?? string.Empty;

                            if (pagesTable.Columns.Contains("menuID")
                                && long.TryParse(row["menuID"]?.ToString()?.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out var menuIdParsed))
                            {
                                selectedMenuId = menuIdParsed;
                            }
                            break;
                        }
                    }
                }

                var actions = new List<object>();
                var seenActions = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

                if (actionsTable != null)
                {
                    foreach (DataRow row in actionsTable.Rows)
                    {
                        if (selectedMenuId.HasValue && actionsTable.Columns.Contains("menuID"))
                        {
                            if (!long.TryParse(row["menuID"]?.ToString()?.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out var actionMenuId))
                                continue;
                            if (actionMenuId != selectedMenuId.Value)
                                continue;
                        }
                        else if (actionsTable.Columns.Contains("menuName_A"))
                        {
                            var actionPageName = row["menuName_A"]?.ToString()?.Trim();
                            if (!string.Equals(actionPageName, selectedPageName, StringComparison.OrdinalIgnoreCase))
                                continue;
                        }

                        var actionNameA = actionsTable.Columns.Contains("permissionTypeName_A")
                            ? row["permissionTypeName_A"]?.ToString()?.Trim()
                            : null;
                        var actionNameE = actionsTable.Columns.Contains("permissionTypeName_E")
                            ? row["permissionTypeName_E"]?.ToString()?.Trim()
                            : null;

                        if (string.IsNullOrWhiteSpace(actionNameA))
                            continue;

                        if (!string.IsNullOrWhiteSpace(actionNameE)
                            && (actionNameE.Equals("ACCESS", StringComparison.OrdinalIgnoreCase)
                                || actionNameE.Equals("SELECT", StringComparison.OrdinalIgnoreCase)
                                || actionNameE.EndsWith("_ACCESS", StringComparison.OrdinalIgnoreCase)
                                || actionNameE.EndsWith("_SELECT", StringComparison.OrdinalIgnoreCase)))
                        {
                            continue;
                        }

                        if (!seenActions.Add(actionNameA))
                            continue;

                        actions.Add(new { value = actionNameA, text = actionNameA });
                    }
                }

                return Json(new
                {
                    pageUrl,
                    actions
                });
            }
            catch (Exception ex)
            {
                return Json(new
                {
                    pageUrl = string.Empty,
                    actions = Array.Empty<object>(),
                    error = ex.Message
                });
            }
        }
    }
}
