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
        public async Task<IActionResult> TransferRequest_Vehicles_ByUserDept(
            string? chassisNumber,
            int pageNumber = 1,
            int pageSize = 10)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }

            ControllerName = nameof(VehicleController);
            PageName = nameof(TransferRequest_Vehicles_ByUserDept);

            var spParameters = new object?[]
            {
                "TransferRequest_Vehicles_ByUserDept",
                IdaraId,
                usersId,
                HostName,
                usersId,
                IdaraId,
                pageNumber,
                pageSize,
                chassisNumber
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            SplitDataSet(ds);

            //if (permissionTable is null || permissionTable.Rows.Count == 0)
            //{
            //    TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
            //    return RedirectToAction("Index", "Home");
            //}

            string rowIdField = "";
            bool canInsert = false;

            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable.Rows.Count > 0)
                {
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                        if (permissionName == "INSERT")
                            canInsert = true;
                    }

                    DataTable? dataTable = ResolveTransferRequestVehiclesTable();

                    if (dataTable != null && dataTable.Columns.Count > 0)
                    {
                        rowIdField = "chassisNumber";
                        var possibleIdNames = new[] { "chassisNumber", "ChassisNumber", "vehicleID", "VehicleID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dataTable.Columns.Contains(n))
                                     ?? dataTable.Columns[0].ColumnName;

                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["chassisNumber"] = "رقم الشاصي",
                            ["vehicleID"] = "رقم المركبة",
                            ["plateLetters"] = "حروف اللوحة",
                            ["plateNumbers"] = "أرقام اللوحة",
                            ["armyNumber"] = "الرقم العسكري",
                            ["vehicleStatusID_FK"] = "حالة المركبة",
                            ["IdaraID_FK"] = "الإدارة",
                            ["ownerName"] = "المالك",
                            ["vehicleModelName"] = "الموديل",
                            ["vehicleColorName"] = "اللون",
                            ["vehicleTypeName"] = "نوع المركبة",
                            ["vehicleWithUsersID"] = "رقم العهدة",
                            ["CurrentUserID"] = "رقم المستخدم الحالي",
                            ["CustodyStartDate"] = "تاريخ بداية العهدة",
                            ["CustodyNote"] = "ملاحظات العهدة",
                            ["RequestID_FK"] = "رقم الطلب",
                            ["GeneralNo_Snapshot"] = "الرقم العام",
                            ["UserFullName_Snapshot"] = "صاحب العهدة الحالي",
                            ["DeptID_Snapshot"] = "رقم القسم",
                            ["DeptName_Snapshot"] = "القسم",
                            ["SectionID_Snapshot"] = "رقم الشعبة",
                            ["SectionName_Snapshot"] = "الشعبة",
                            ["OrganizationName_Snap"] = "الجهة",
                            ["IdaraID_Snapshot"] = "رقم الإدارة",
                            ["IdaraName_Snap"] = "اسم الإدارة",
                            ["CurrentUserNationalID"] = "رقم الهوية",
                            ["CurrentUserMobile"] = "الجوال",
                            ["CurrentUserName_A"] = "اسم المستخدم الحالي"
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

                            bool isVehicleWithUsersID = c.ColumnName.Equals("vehicleWithUsersID", StringComparison.OrdinalIgnoreCase);
                            bool isCurrentUserID = c.ColumnName.Equals("CurrentUserID", StringComparison.OrdinalIgnoreCase);
                            bool isVehicleStatusID = c.ColumnName.Equals("vehicleStatusID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraID = c.ColumnName.Equals("IdaraID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isRequestID = c.ColumnName.Equals("RequestID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isDeptID = c.ColumnName.Equals("DeptID_Snapshot", StringComparison.OrdinalIgnoreCase);
                            bool isSectionID = c.ColumnName.Equals("SectionID_Snapshot", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraSnapshotID = c.ColumnName.Equals("IdaraID_Snapshot", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,
                                Visible = !(isVehicleWithUsersID || isCurrentUserID || isVehicleStatusID || isIdaraID || isRequestID || isDeptID || isSectionID || isIdaraSnapshotID)
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

                            dict["p01"] = 1;                       // requestTypeID
                            dict["p02"] = Get("chassisNumber");   // chassisNumber
                            dict["p03"] = Get("CurrentUserID");   // fromUserID
                            dict["p05"] = Get("DeptID_Snapshot"); // deptID
                            dict["p06"] = usersId;                // createByUser
                            dict["p07"] = null;                   // note

                            rowsList.Add(dict);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.DataSetError = ex.Message;
            }

            var currentUrl = Request.Path + Request.QueryString;

            var transferFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "TransferRequest_Create" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                new FieldConfig { Name = rowIdField, Type = "hidden" },

                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig { Name = "p02", Type = "hidden", MirrorName = "chassisNumber" },
                new FieldConfig { Name = "p03", Type = "hidden" },
                new FieldConfig { Name = "p05", Type = "hidden", MirrorName = "DeptID_Snapshot" },
                new FieldConfig { Name = "p06", Type = "hidden", Value = usersId },

                new FieldConfig { Name = "UserFullName_Snapshot", Label = "من", Type = "text", ColCss = "6", Readonly = true },
                new FieldConfig { Name = "p04", Label = "إلى", Type = "select", ColCss = "6", Required = true, Options = new List<OptionItem>() },
                new FieldConfig { Name = "p07", Label = "ملاحظات", Type = "textarea", ColCss = "12", Required = false }
            };

            var dsModel = new SmartTableDsModel
            {
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PageTitle = "طلب نقل عربه",
                PanelTitle = "طلب نقل عربه",
                EnableCellCopy = true,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = true,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowAdd = false,
                    ShowEdit = true,
                    ShowDelete = false,
                    ShowBulkDelete = false,

                    Edit = new TableAction
                    {
                        Label = "نقل",
                        Icon = "fa fa-right-left",
                        Color = "success",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "طلب نقل مركبة",
                        ModalMessage = "حدد المنقول إليه ثم احفظ الطلب",
                        ModalMessageClass = "bg-green-50 text-green-700",
                        ModalMessageIcon = "fa-solid fa-circle-info",
                        OpenForm = new FormConfig
                        {
                            FormId = "transferRequestForm",
                            Title = "بيانات طلب النقل",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ الطلب", Type = "submit", Color = "success", Icon = "fa fa-save" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = transferFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    }
                }
            };

            var vm = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa fa-right-left",
                TableDS = dsModel
            };

            ViewBag.TransferEligibleUsersUrl = Url.Action(nameof(TransferRequest_EligibleUsers_Get), "Vehicle");

            return View("TransferRequest_Vehicles_ByUserDept", vm);
        }

        [HttpGet]
        public async Task<IActionResult> TransferRequest_EligibleUsers_Get(string chassisNumber)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return Json(new { success = false, message = "انتهت الجلسة" });

            if (string.IsNullOrWhiteSpace(usersId))
                return Json(new { success = false, message = "انتهت الجلسة" });

            var spParameters = new object?[]
            {
                "TransferRequest_EligibleUsers",
                IdaraId,
                usersId,
                HostName,
                chassisNumber,
                usersId,
                IdaraId
            };

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            SplitDataSet(ds);

            if (permissionTable is null || permissionTable.Rows.Count == 0)
                return Json(new { success = false, message = "لا توجد صلاحية" });

            var fromTable = dt1;
            var toTable = dt2;

            object? from = null;
            if (fromTable != null && fromTable.Rows.Count > 0)
            {
                var r = fromTable.Rows[0];
                from = new
                {
                    FromUserID = r["FromUserID"] == DBNull.Value ? null : r["FromUserID"]?.ToString(),
                    UserFullName_Snapshot = r["UserFullName_Snapshot"] == DBNull.Value ? "" : r["UserFullName_Snapshot"]?.ToString(),
                    DeptID_Snapshot = r["DeptID_Snapshot"] == DBNull.Value ? null : r["DeptID_Snapshot"]?.ToString()
                };
            }

            var to = new List<object>();
            if (toTable != null)
            {
                foreach (DataRow r in toTable.Rows)
                {
                    to.Add(new
                    {
                        ToUserID = r["ToUserID"] == DBNull.Value ? null : r["ToUserID"]?.ToString(),
                        UserFullName_A = r["UserFullName_A"] == DBNull.Value ? "" : r["UserFullName_A"]?.ToString(),
                        GeneralNo = r["GeneralNo"] == DBNull.Value ? "" : r["GeneralNo"]?.ToString()
                    });
                }
            }

            return Json(new { success = true, from, to });
        }

        private DataTable? ResolveTransferRequestVehiclesTable()
        {
            var tables = new[] { dt1, dt2, dt3, dt4, dt5, dt6, dt7, dt8, dt9 };

            foreach (var table in tables)
            {
                if (table == null || table.Columns.Count == 0)
                    continue;

                if (table.Columns.Contains("permissionTypeName_E"))
                    continue;

                if (table.Columns.Contains("IsSuccessful") || table.Columns.Contains("Message_") || table.Columns.Contains("_Message"))
                    continue;

                if (table.Columns.Contains("chassisNumber")
                    || table.Columns.Contains("vehicleID")
                    || table.Columns.Contains("plateNumbers"))
                    return table;
            }

            return null;
        }
    }
}