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
        public async Task<IActionResult> SupportTeamManagement(string? onlyActive = "1")
        {
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = "Support";
            PageName = string.IsNullOrWhiteSpace(PageName) ? "SupportTeamManagement" : PageName;

            var spParameters = new object?[]
            {
                PageName ?? "SupportTeamManagement",
                IdaraId,
                usersId,
                HostName,
                onlyActive == "0" ? "0" : "1"
            };

            var memberRowsList = new List<Dictionary<string, object?>>();
            var memberDynamicColumns = new List<TableColumn>();
            var usersOptions = new List<OptionItem>();
            var yesNoOptions = new List<OptionItem>
            {
                new OptionItem { Value = "1", Text = "نعم" },
                new OptionItem { Value = "0", Text = "لا" }
            };

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            SplitDataSet(ds);

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            bool canAccess = false;
            bool canAddMember = false;
            bool canUpdateMember = false;
            bool canDeactivateMember = false;

            foreach (DataRow row in permissionTable.Rows)
            {
                var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                if (permissionName == "STM_ACCESS" || permissionName == "STM_SELECT") canAccess = true;
                if (permissionName == "STM_ADD_MEMBER") canAddMember = true;
                if (permissionName == "STM_UPDATE_MEMBER") canUpdateMember = true;
                if (permissionName == "STM_DEACTIVATE_MEMBER") canDeactivateMember = true;
            }

            if (!canAccess)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            string memberRowIdField = "teamMemberID";

            try
            {
                if (dt1 != null)
                {
                    var memberPossibleIdNames = new[] { "teamMemberID", "TeamMemberID" };
                    memberRowIdField = memberPossibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                       ?? dt1.Columns[0].ColumnName;

                    var memberHeaderMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                    {
                        ["teamMemberID"] = "رقم عضو الدعم",
                        ["userID_FK"] = "رقم المستخدم",
                        ["nationalID"] = "اسم المستخدم",
                        ["usersActive"] = "نشط في المستخدمين",
                        ["canReceiveTickets"] = "يستقبل تذاكر",
                        ["canAssignTickets"] = "يحوّل تذاكر",
                        ["teamMemberActive"] = "نشط في الدعم",
                        ["entryDate"] = "تاريخ الإضافة"
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

                        memberDynamicColumns.Add(new TableColumn
                        {
                            Field = c.ColumnName,
                            Label = memberHeaderMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                            Type = colType,
                            Sortable = true,
                            Visible = true
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
                        dict["p01"] = Get("teamMemberID") ?? Get("TeamMemberID");
                        dict["p02"] = Get("userID_FK");
                        dict["p03"] = (Get("canReceiveTickets")?.ToString()?.Trim() == "True" || Get("canReceiveTickets")?.ToString()?.Trim() == "1") ? "1" : "0";
                        dict["p04"] = (Get("canAssignTickets")?.ToString()?.Trim() == "True" || Get("canAssignTickets")?.ToString()?.Trim() == "1") ? "1" : "0";
                        dict["p05"] = (Get("teamMemberActive")?.ToString()?.Trim() == "True" || Get("teamMemberActive")?.ToString()?.Trim() == "1") ? "1" : "0";

                        memberRowsList.Add(dict);
                    }
                }

                if (dt3 != null && dt3.Columns.Contains("usersID") && dt3.Columns.Contains("nationalID"))
                {
                    foreach (DataRow r in dt3.Rows)
                    {
                        var value = r["usersID"]?.ToString()?.Trim();
                        var text = r["nationalID"]?.ToString()?.Trim();
                        if (!string.IsNullOrWhiteSpace(value) && !string.IsNullOrWhiteSpace(text))
                            usersOptions.Add(new OptionItem { Value = value, Text = text });
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.supportTeamManagementDataSetError = ex.Message;
            }

            var addMemberFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p02", Label = "المستخدم", Type = "select", ColCss = "6", Required = true, Placeholder = "", Options = usersOptions },
                new FieldConfig { Name = "p03", Label = "يستقبل تذاكر", Type = "select", ColCss = "6", Required = true, Placeholder = "", Options = yesNoOptions },
                new FieldConfig { Name = "p04", Label = "يحوّل التذاكر", Type = "select", ColCss = "6", Required = true, Placeholder = "", Options = yesNoOptions },
                new FieldConfig { Name = "p05", Label = "نشط", Type = "select", ColCss = "6", Required = true, Placeholder = "", Options = yesNoOptions }
            };
            addMemberFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addMemberFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            addMemberFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            addMemberFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            addMemberFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "STM_ADD_MEMBER" });
            addMemberFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            addMemberFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addMemberFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });

            var updateMemberFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig { Name = "p03", Label = "يستقبل تذاكر", Type = "select", ColCss = "6", Required = true, Placeholder = "", Options = yesNoOptions },
                new FieldConfig { Name = "p04", Label = "يحوّل التذاكر", Type = "select", ColCss = "6", Required = true, Placeholder = "", Options = yesNoOptions },
                new FieldConfig { Name = "p05", Label = "نشط", Type = "select", ColCss = "6", Required = true, Placeholder = "", Options = yesNoOptions }
            };
            updateMemberFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            updateMemberFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            updateMemberFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            updateMemberFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            updateMemberFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "STM_UPDATE_MEMBER" });
            updateMemberFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            updateMemberFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            updateMemberFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });

            var deactivateMemberFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Type = "hidden" }
            };
            deactivateMemberFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            deactivateMemberFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            deactivateMemberFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            deactivateMemberFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            deactivateMemberFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "STM_DEACTIVATE_MEMBER" });
            deactivateMemberFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });
            deactivateMemberFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            deactivateMemberFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });

            var memberDsModel = new SmartTableDsModel
            {
                PageTitle = "إدارة فريق الدعم",
                Columns = memberDynamicColumns,
                Rows = memberRowsList,
                RowIdField = memberRowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = memberDynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = "أعضاء فريق الدعم",
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowExportPdf = false,
                    ShowAdd = canAddMember,
                    ShowEdit = canUpdateMember,
                    ShowDelete = canDeactivateMember,
                    ShowBulkDelete = false,
                    Add = new TableAction
                    {
                        Label = "إضافة عضو",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة عضو دعم",
                        OpenForm = new FormConfig
                        {
                            FormId = "supportAddMemberForm",
                            Title = "بيانات عضو الدعم",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addMemberFields
                        }
                    },
                    Edit = new TableAction
                    {
                        Label = "تعديل عضو",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل عضو الدعم",
                        OpenForm = new FormConfig
                        {
                            FormId = "supportUpdateMemberForm",
                            Title = "تعديل بيانات عضو الدعم",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Fields = updateMemberFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                    Delete = new TableAction
                    {
                        Label = "تعطيل عضو",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعطيل عضو الدعم",
                        OpenForm = new FormConfig
                        {
                            FormId = "supportDeactivateMemberForm",
                            Title = "تأكيد تعطيل عضو الدعم",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Fields = deactivateMemberFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    }
                }
            };

            var page = new SmartPageViewModel
            {
                PageTitle = memberDsModel.PageTitle,
                PanelTitle = memberDsModel.PanelTitle,
                PanelIcon = "fa-users-gear",
                TableDS = memberDsModel
            };

            return View("SupportTeamManagement", page);
        }
    }
}
