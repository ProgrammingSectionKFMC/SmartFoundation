using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;

namespace SmartFoundation.Mvc.Controllers.VIC
{
    public partial class VehiclesController : Controller
    {
        public async Task<IActionResult> Custody_Current_List(
            string? userId,
            string? generalNo,
            string? chassisNumber,
            int pageNumber = 1,
            int pageSize = 10)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });


            ControllerName = nameof(VehiclesController);
            PageName = "Custody_Current_List";

            var spParameters = new object?[]
            {
                PageName,        // @pageName_
                IdaraId,         // @idaraID
                usersId,         // @entrydata
                HostName,        // @hostName
                userId,          // @parameter_01 -> @userID
                generalNo,       // @parameter_02 -> @generalNo
                chassisNumber,   // @parameter_03 -> @chassisNumber
                pageNumber,      // @parameter_04 -> @pageNumber
                pageSize,        // @parameter_05 -> @pageSize
                IdaraId          // @parameter_06 -> @idaraID_FK
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();
            string rowIdField = "vehicleWithUsersID";

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            SplitDataSet(ds);

            var dataTable = dt2;

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            bool canCreateCustody = true;
            bool canTransferCustody = true;
            bool canCloseCustody = true;

            try
            {
                if (dataTable != null && dataTable.Columns.Count > 0)
                {
                    var possibleIdNames = new[] { "vehicleWithUsersID", "VehicleWithUsersID", "Id", "ID" };
                    rowIdField = possibleIdNames.FirstOrDefault(n => dataTable.Columns.Contains(n))
                                 ?? dataTable.Columns[0].ColumnName;

                    var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                    {
                        ["vehicleWithUsersID"] = "رقم العهدة",
                        ["chassisNumber_FK"] = "الشاصي",
                        ["userID_FK"] = "رقم المستخدم",
                        ["RequestID_FK"] = "رقم الطلب",
                        ["startDate"] = "تاريخ بداية العهدة",
                        ["endDate"] = "تاريخ نهاية العهدة",
                        ["note"] = "ملاحظات",
                        ["entryDate"] = "تاريخ الإدخال",
                        ["entryData"] = "مدخل البيانات",
                        ["hostName"] = "اسم الجهاز",
                        ["GeneralNo_Snapshot"] = "رقم المركبة",
                        ["UserFullName_Snapshot"] = "اسم المستخدم",
                        ["DSDID_Snapshot"] = "رقم DSD",
                        ["OrganizationName_Snap"] = "الجهة",
                        ["IdaraName_Snap"] = "الإدارة",
                        ["DeptID_Snapshot"] = "رقم القسم",
                        ["DeptName_Snapshot"] = "القسم",
                        ["SectionID_Snapshot"] = "رقم الشعبة",
                        ["SectionName_Snapshot"] = "الشعبة",
                        ["DivisonName_Snap"] = "الوحدة",
                        ["OrgSnapshotDate"] = "تاريخ اللقطة",
                        ["IdaraID_Snapshot"] = "رقم الإدارة",
                        ["GeneralNo_Current"] = "الرقم العام الحالي",
                        ["NationalID_Current"] = "رقم الهوية",
                        ["MobileNo_Current"] = "الجوال",
                        ["UserFullName_A_Current"] = "اسم المستخدم الحالي",
                        ["UserFullName_E_Current"] = "الاسم الإنجليزي",
                        ["DSDID_Current"] = "رقم DSD الحالي",
                        ["OrganizationName_Current"] = "الجهة الحالية",
                        ["IdaraName_Current"] = "الإدارة الحالية",
                        ["DepartmentName_Current"] = "القسم الحالي",
                        ["SectionName_Current"] = "الشعبة الحالية",
                        ["DivisonName_Current"] = "الوحدة الحالية"
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

                        bool isHidden =
                            c.ColumnName.Equals("vehicleWithUsersID", StringComparison.OrdinalIgnoreCase) ||
                            c.ColumnName.Equals("userID_FK", StringComparison.OrdinalIgnoreCase) ||
                            c.ColumnName.Equals("RequestID_FK", StringComparison.OrdinalIgnoreCase) ||
                            c.ColumnName.Equals("endDate", StringComparison.OrdinalIgnoreCase) ||
                            c.ColumnName.Equals("entryDate", StringComparison.OrdinalIgnoreCase) ||
                            c.ColumnName.Equals("entryData", StringComparison.OrdinalIgnoreCase) ||
                            c.ColumnName.Equals("hostName", StringComparison.OrdinalIgnoreCase) ||
                            c.ColumnName.Equals("DSDID_Snapshot", StringComparison.OrdinalIgnoreCase) ||
                            c.ColumnName.Equals("DeptID_Snapshot", StringComparison.OrdinalIgnoreCase) ||
                            c.ColumnName.Equals("SectionID_Snapshot", StringComparison.OrdinalIgnoreCase) ||
                            c.ColumnName.Equals("OrgSnapshotDate", StringComparison.OrdinalIgnoreCase) ||
                            c.ColumnName.Equals("IdaraID_Snapshot", StringComparison.OrdinalIgnoreCase) ||
                            c.ColumnName.Equals("NationalID_Current", StringComparison.OrdinalIgnoreCase) ||
                            c.ColumnName.Equals("MobileNo_Current", StringComparison.OrdinalIgnoreCase) ||
                            c.ColumnName.Equals("UserFullName_E_Current", StringComparison.OrdinalIgnoreCase) ||
                            c.ColumnName.Equals("DSDID_Current", StringComparison.OrdinalIgnoreCase);

                        dynamicColumns.Add(new TableColumn
                        {
                            Field = c.ColumnName,
                            Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                            Type = colType,
                            Sortable = true,
                            Visible = !isHidden
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

                        dict["p01"] = Get("vehicleWithUsersID");
                        dict["p02"] = Get("chassisNumber_FK");
                        dict["p03"] = Get("userID_FK");
                        dict["p04"] = Get("GeneralNo_Snapshot");
                        dict["p05"] = Get("UserFullName_Snapshot");
                        dict["p06"] = Get("IdaraName_Current");
                        dict["p07"] = Get("DepartmentName_Current");
                        dict["p08"] = Get("SectionName_Current");
                        dict["p09"] = Get("startDate");
                        dict["p10"] = Get("note");

                        rowsList.Add(dict);
                    }
                }
            }
            catch (Exception ex)
            {
                TempData["DataSetError"] = ex.Message;
            }

            var currentUrl = Request.Path + Request.QueryString;

            // =====================================
            // طلبات النقل الموافق عليها
            // =====================================
            var approvedRowsList = new List<Dictionary<string, object?>>();
            var approvedDynamicColumns = new List<TableColumn>();
            string approvedRowIdField = "RequestID";

            var approvedSpParameters = new object?[]
{
    "TransferRequest_Approved_List", // @pageName_
    IdaraId,                         // @idaraID
    usersId,                         // @entrydata
    HostName,                        // @hostName

    null,                            // @parameter_01 -> @requestID
    null,                            // @parameter_02 -> @chassisNumber
    null,                            // @parameter_03 -> @fromUserID
    null,                            // @parameter_04 -> @toUserID
    1,                               // @parameter_05 -> @pageNumber
    50,                              // @parameter_06 -> @pageSize
    IdaraId                          // @parameter_07 -> @idaraID_FK
};

            DataSet approvedDs = await _mastersServies.GetDataLoadDataSetAsync(approvedSpParameters);

            // لا تستخدم SplitDataSet هنا حتى لا تخرب الداتا الأساسية
            DataTable? approvedPermissionTable = approvedDs.Tables.Count > 0 ? approvedDs.Tables[0] : null;
            DataTable? approvedDataTable =
                approvedDs.Tables.Count > 2 && approvedDs.Tables[2].Rows.Count > 0 ? approvedDs.Tables[2] :
                approvedDs.Tables.Count > 1 && approvedDs.Tables[1].Rows.Count > 0 ? approvedDs.Tables[1] :
                null;

            if (approvedDataTable != null && approvedDataTable.Columns.Count > 0)
            {
                var possibleApprovedIdNames = new[] { "RequestID", "requestID", "TransferRequestID", "VehicleTransferRequestID", "Id", "ID" };
                approvedRowIdField = possibleApprovedIdNames.FirstOrDefault(n => approvedDataTable.Columns.Contains(n))
                                     ?? approvedDataTable.Columns[0].ColumnName;

                var approvedHeaderMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                {
                    ["RequestID"] = "رقم الطلب",
                    ["TransferRequestID"] = "رقم الطلب",
                    ["VehicleTransferRequestID"] = "رقم الطلب",
                    ["chassisNumber"] = "رقم الشاصي",
                    ["chassisNumber_FK"] = "رقم الشاصي",
                    ["fromUserID_FK"] = "من المستخدم",
                    ["toUserID_FK"] = "إلى المستخدم",
                    ["fromUserName"] = "اسم المستخدم الحالي",
                    ["toUserName"] = "اسم المنقول إليه",
                    ["requestDate"] = "تاريخ الطلب",
                    ["approvedDate"] = "تاريخ الموافقة",
                    ["lastStatus"] = "آخر حالة",
                    ["statusName"] = "الحالة",
                    ["note"] = "ملاحظات",
                    ["entryDate"] = "تاريخ الإدخال",
                    ["entryData"] = "مدخل البيانات"
                };

                foreach (DataColumn c in approvedDataTable.Columns)
                {
                    string colType = "text";
                    var t = c.DataType;

                    if (t == typeof(bool)) colType = "bool";
                    else if (t == typeof(DateTime)) colType = "date";
                    else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                          || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                        colType = "number";

                    bool isHidden =
                        c.ColumnName.Equals("entryData", StringComparison.OrdinalIgnoreCase) ||
                        c.ColumnName.Equals("entryDate", StringComparison.OrdinalIgnoreCase);

                    approvedDynamicColumns.Add(new TableColumn
                    {
                        Field = c.ColumnName,
                        Label = approvedHeaderMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                        Type = colType,
                        Sortable = true,
                        Visible = !isHidden
                    });
                }

                foreach (DataRow r in approvedDataTable.Rows)
                {
                    var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

                    foreach (DataColumn c in approvedDataTable.Columns)
                    {
                        var val = r[c];
                        dict[c.ColumnName] = val == DBNull.Value ? null : val;
                    }

                    object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;

                    dict["p01"] = Get("RequestID") ?? Get("TransferRequestID") ?? Get("VehicleTransferRequestID");
                    dict["p02"] = Get("chassisNumber") ?? Get("chassisNumber_FK");
                    dict["p03"] = Get("toUserID_FK");
                    dict["p04"] = Get("toUserName");
                    dict["p05"] = Get("approvedDate");
                    dict["p06"] = Get("note");

                    approvedRowsList.Add(dict);
                }
            }

            // =========================
            // فتح عهدة
            // =========================
            var addFieldsCustody = new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Label = "رقم الشاصي", Type = "text", ColCss = "4", Required = true, Placeholder = "اكتب رقم الشاصي" },
                new FieldConfig { Name = "p02", Label = "User ID", Type = "text", ColCss = "4", Required = true, Placeholder = "اكتب رقم المستخدم" },
                new FieldConfig { Name = "p03", Label = "تاريخ بداية العهدة", Type = "date", ColCss = "4", Required = true, Placeholder = "YYYY-MM-DD" },
                new FieldConfig { Name = "p04", Label = "ملاحظات", Type = "textarea", ColCss = "12", Required = false }
            };

            addFieldsCustody.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addFieldsCustody.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            addFieldsCustody.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            addFieldsCustody.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            addFieldsCustody.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT" });
            addFieldsCustody.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = "Custody_Create" });
            addFieldsCustody.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addFieldsCustody.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });
            addFieldsCustody.Insert(0, new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl });

            // =========================
            // نقل عهدة
            // =========================
            var transferFieldsCustody = new List<FieldConfig>
            {
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Label = "رقم الشاصي", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p02", Label = "رقم المستخدم الجديد", Type = "text", ColCss = "4", Required = true, Placeholder = "اكتب User ID الجديد" },
                new FieldConfig { Name = "p03", Label = "تاريخ النقل", Type = "date", ColCss = "4", Required = true, Placeholder = "YYYY-MM-DD" },
                new FieldConfig { Name = "p04", Label = "ملاحظات", Type = "textarea", ColCss = "12", Required = false }
            };

            transferFieldsCustody.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            transferFieldsCustody.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            transferFieldsCustody.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            transferFieldsCustody.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            transferFieldsCustody.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT" });
            transferFieldsCustody.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = "Custody_Transfer" });
            transferFieldsCustody.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            transferFieldsCustody.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });
            transferFieldsCustody.Insert(0, new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl });

            // =========================
            // إغلاق عهدة
            // =========================
            var closeFieldsCustody = new List<FieldConfig>
            {
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "vehicleWithUsersID" },
                new FieldConfig { Name = "p05", Label = "اسم المستخدم", Type = "text", ColCss = "6", Readonly = true },
                new FieldConfig { Name = "p08", Label = "رقم الشاصي", Type = "text", ColCss = "6", Readonly = true },

                new FieldConfig { Name = "p02", Label = "تاريخ الإغلاق", Type = "date", ColCss = "6", Required = true, Placeholder = "YYYY-MM-DD" },
                new FieldConfig { Name = "p03", Label = "ملاحظات", Type = "textarea", ColCss = "6", Required = false }
            };

            closeFieldsCustody.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            closeFieldsCustody.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            closeFieldsCustody.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            closeFieldsCustody.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            closeFieldsCustody.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATE" });
            closeFieldsCustody.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = "Custody_Close" });
            closeFieldsCustody.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            closeFieldsCustody.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });
            closeFieldsCustody.Insert(0, new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl });

            // =========================
            // تنفيذ طلب نقل
            // =========================
            var executeTransferFields = new List<FieldConfig>
            {
                new FieldConfig { Name = approvedRowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = approvedRowIdField },

                new FieldConfig { Name = "p02", Label = "رقم الشاصي", Type = "text", ColCss = "6", Readonly = true },
                new FieldConfig { Name = "p04", Label = "المنقول إليه", Type = "text", ColCss = "6", Readonly = true },
                new FieldConfig { Name = "p05", Label = "تاريخ الموافقة", Type = "text", ColCss = "6", Readonly = true },
                new FieldConfig { Name = "p06", Label = "ملاحظات", Type = "textarea", ColCss = "6", Readonly = true }
            };

            executeTransferFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            executeTransferFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            executeTransferFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId?.ToString() });
            executeTransferFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId?.ToString() });
            executeTransferFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "UPDATE" });
            executeTransferFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = "TransferRequest_Execute" });
            executeTransferFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            executeTransferFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });
            executeTransferFields.Insert(0, new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl });


            var dsModel = new SmartTableDsModel
            {
                PageTitle = "العهد الحالية",
                PanelTitle = "العهد الحالية",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100, 200 },
                QuickSearchFields = new List<string>
                {
                    "chassisNumber_FK",
                    "GeneralNo_Snapshot",
                    "UserFullName_Snapshot",
                    "DepartmentName_Current"
                },
                Searchable = true,
                AllowExport = true,
                ShowRowBorders = false,
                EnablePagination = true,
                ShowPageSizeSelector = true,
                ShowToolbar = true,
                EnableCellCopy = false,
                RenderAsToggle = false,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = true,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,

                    ShowAdd = canCreateCustody,
                    ShowEdit = canTransferCustody,
                    ShowDelete = canCloseCustody,
                    ShowBulkDelete = false,

                    Add = new TableAction
                    {
                        Label = "فتح عهدة",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "فتح عهدة جديدة",
                        ModalMessage = "أدخل بيانات العهدة الجديدة",
                        ModalMessageIcon = "fa-solid fa-circle-info",
                        ModalMessageClass = "bg-sky-100 text-sky-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "CustodyCreateForm",
                            Title = "فتح عهدة",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addFieldsCustody,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },

                    Edit = new TableAction
                    {
                        Label = "نقل عهدة",
                        Icon = "fa fa-right-left",
                        Color = "warning",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "نقل عهدة",
                        ModalMessage = "اختر صفًا واحدًا ثم أدخل بيانات النقل",
                        ModalMessageIcon = "fa-solid fa-circle-info",
                        ModalMessageClass = "bg-sky-100 text-sky-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "CustodyTransferForm",
                            Title = "نقل عهدة",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = transferFieldsCustody
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },

                    Delete = new TableAction
                    {
                        Label = "إغلاق عهدة",
                        Icon = "fa fa-xmark",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "إغلاق عهدة",
                        ModalMessage = "هل أنت متأكد من إغلاق العهدة؟",
                        ModalMessageIcon = "fa fa-exclamation-triangle text-red-600",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "CustodyCloseForm",
                            Title = "إغلاق عهدة",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "danger" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = closeFieldsCustody
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    }
                }
            };

            var approvedDsModel = new SmartTableDsModel
            {
                PageTitle = "طلبات النقل الموافق عليها",
                PanelTitle = "طلبات النقل الموافق عليها",
                Columns = approvedDynamicColumns,
                Rows = approvedRowsList,
                RowIdField = approvedRowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = approvedDynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowRowBorders = false,
                EnablePagination = true,
                ShowPageSizeSelector = true,
                ShowToolbar = true,
                EnableCellCopy = false,
                RenderAsToggle = true,
                ToggleLabel = "عرض طلبات النقل الموافق عليها",
                ToggleIcon = "fa-solid fa-right-left",
                ToggleDefaultOpen = false,
                ShowToggleCount = true,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = true,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowEdit = true,
                    ShowBulkDelete = false,

                    Edit = new TableAction
                    {
                        Label = "تنفيذ",
                        Icon = "fa fa-check",
                        Color = "success",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تنفيذ طلب نقل",
                        ModalMessage = "هل أنت متأكد من تنفيذ الطلب؟ سيتم إغلاق العهدة الحالية وإنشاء عهدة جديدة وإغلاق الطلب.",
                        ModalMessageIcon = "fa fa-exclamation-triangle text-orange-600",
                        ModalMessageClass = "bg-orange-50 text-orange-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "ExecuteTransferRequestForm",
                            Title = "تنفيذ طلب نقل",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "تنفيذ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = executeTransferFields
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
                PanelIcon = "fa fa-hand-holding",
                TableDS = dsModel,
                TableDS1 = approvedDsModel
            };

            return View("Custody_Current_List", page);
        }
    }
}