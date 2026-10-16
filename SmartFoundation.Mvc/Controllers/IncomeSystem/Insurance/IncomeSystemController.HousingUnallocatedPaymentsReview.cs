using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartDrawer;
using SmartFoundation.UI.ViewModels.SmartTable;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;

namespace SmartFoundation.Mvc.Controllers.IncomeSystem
{
    public partial class IncomeSystemController : Controller
    {
        // نسخة للمراجعة: تستخدم مكونات ExtendInsurance وآلية الاستعراض في FinancialAuditForExtendAndEvictions.
        // يلزم ربط PageDL وMasters_ExtraDataLoad وصلاحية INSERTUNALLOCATEDPAYMENTREFUND قبل التشغيل.

        [ResponseCache(
    Duration = 0,
    Location = ResponseCacheLocation.None,
    NoStore = true
)]
        public async Task<IActionResult> HousingUnallocatedPaymentsReview()
        {
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = nameof(IncomeSystem);
            PageName = string.IsNullOrWhiteSpace(PageName)
                ? "HousingUnallocatedPaymentsReview"
                : PageName;

            var spParameters = new object?[]
            {
                PageName ?? "HousingUnallocatedPaymentsReview",
                IdaraId,
                usersId,
                HostName
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            SplitDataSet(ds);

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            // يمنع التسجيل حتى اعتماد PageSP وربطه واختباره فعليًا.
            bool canRegisterRefund = false;
            bool canCancelRefund = false;
            foreach (DataRow row in permissionTable.Rows)
            {
                var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim();
                if (string.Equals(permissionName, "INSERTUNALLOCATEDPAYMENTREFUND", StringComparison.OrdinalIgnoreCase))
                    canRegisterRefund = true;
                if (string.Equals(permissionName, "CANCELUNALLOCATEDPAYMENTREFUND", StringComparison.OrdinalIgnoreCase))
                    canCancelRefund = true;

            }

            // dt1 من PageDL؛ order_ فريد لكل مستفيد/خدمة ضمن نتيجة التحميل.
            string rowIdField = "order_";

            var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                //["order_"] = "م",
                //["residentInfoID"] = "الرقم المرجعي للمستفيد",
                //["NationalID"] = "رقم الهوية",
                //["generalNo_FK"] = "الرقم العام",
                //["FullName_A"] = "الاسم",
                //["BillChargeTypeName_A"] = "نوع الخدمة",
                //["FirstOccupancyDate"] = "تاريخ أول إشغال",
                //["PaymentCount"] = "عدد الحركات",
                //["TotalPositivePayments"] = "إجمالي السدادات",
                //["TotalOldRefunds"] = "الاستردادات القديمة",
                //["EligiblePositivePayments"] = "السدادات المؤهلة",
                //["PaymentsRequiringReview"] = "سداد بحاجة للمراجعة",
                //["RawGeneralBalance"] = "الرصيد العام الصافي",
                //["TotalNewRefunds"] = "المبالغ المعالجة",
                //["RemainingForReview"] = "المتبقي بانتظار المعالجة"
            };

            if (dt1 != null && dt1.Columns.Count > 0)
            {
                rowIdField = dt1.Columns.Contains("order_")
                    ? "order_"
                    : dt1.Columns[0].ColumnName;

                foreach (DataColumn c in dt1.Columns)
                {
                    string colType = "text";
                    var t = c.DataType;
                    if (t == typeof(bool)) colType = "bool";
                    else if (t == typeof(DateTime)) colType = "date";
                    else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                             || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                        colType = "number";

                    bool isHidden =  c.ColumnName.Equals("BillChargeTypeID", StringComparison.OrdinalIgnoreCase)
                        || c.ColumnName.Equals("FirstOccupancyDate", StringComparison.OrdinalIgnoreCase)
                        || c.ColumnName.Equals("PaymentCount", StringComparison.OrdinalIgnoreCase)
                        || c.ColumnName.Equals("PaymentsRequiringReview", StringComparison.OrdinalIgnoreCase)
                        || c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase)
                        || c.ColumnName.Equals("TotalPositivePayments", StringComparison.OrdinalIgnoreCase)
                        || c.ColumnName.Equals("TotalOldRefunds", StringComparison.OrdinalIgnoreCase)
                        || c.ColumnName.Equals("EligiblePositivePayments", StringComparison.OrdinalIgnoreCase);

                    dynamicColumns.Add(new TableColumn
                    {
                        Field = c.ColumnName,
                        Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                        Type = colType,
                        Sortable = true,
                        Visible = !isHidden,
                        Filter = new TableColumnFilter { Enabled = false }
                    });
                }

                foreach (DataRow r in dt1.Rows)
                {
                    var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                    foreach (DataColumn c in dt1.Columns)
                        dict[c.ColumnName] = r[c] == DBNull.Value ? null : r[c];

                    object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;

                    // العقد المقترح لمسار CRUD؛ المعرّفات تُراجع مجددًا على الخادم.
                    dict["p01"] = Get("residentInfoID");
                    dict["p02"] = Get("BillChargeTypeID");
                    dict["p03"] = null; // مبلغ الاسترداد (يكتبه المحاسب)
                    dict["p04"] = null; // تاريخ الإعادة (يكتبه المحاسب)
                    dict["p05"] = null; // مرجع الإعادة (يكتبه المحاسب)
                    dict["p06"] = null; // تفاصيل الإعادة (يكتبها المحاسب)
                    dict["p07"] = "4"; // Housing.billPaymentType
                    dict["p08"] = Guid.NewGuid().ToString("D");
                    rowsList.Add(dict);
                }
            }

            // نفس قالب الاستعراض في FinancialAuditForExtendAndEvictions.
            var paidFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", Readonly = true },
                new FieldConfig { Name = "p02", Type = "hidden", Readonly = true }
            };

            var refundFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERTUNALLOCATEDPAYMENTREFUND" },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Label = "الرقم المرجعي للمستفيد", Type = "hidden", Readonly = true },
                new FieldConfig { Name = "p02", Label = "نوع الخدمة", Type = "hidden", Readonly = true },
                new FieldConfig { Name = "p03", Label = "المبلغ المعاد", Type = "text",TextMode="money_sar", Required = true, ColCss = "4" },
                new FieldConfig { Name = "p04", Label = "تاريخ إعادة المبلغ", Type = "date", Required = true, ColCss = "4" },
                new FieldConfig { Name = "p05", Label = "رقم مستند الإعادة", Type = "text", Required = true, ColCss = "4" },
                new FieldConfig { Name = "p06", Label = "جميع تفاصيل إعادة المبلغ", Type = "textarea", Required = true, ColCss = "12" },
                new FieldConfig { Name = "p07", Label = "نوع العملية", Type = "hidden", Value = "4", Readonly = true },
                new FieldConfig { Name = "p08", Label = "RequestKey", Type = "hidden", Readonly = true }
            };

            var extraPaidCtx = new Dictionary<string, object?>
            {
                ["idaraID"] = IdaraId,
                ["entrydata"] = usersId,
                ["hostname"] = HostName
            };
            var extraPaidRequestBase = new Dictionary<string, object?>
            {
                ["pageName_"] = PageName,
                ["ActionType"] = "GetUnallocatedPaymentsByResident",
                ["tableIndex"] = 0
            };
            var extraMetaPaid = new Dictionary<string, object?>
            {
                ["extraSlotKey"] = "m1",
                ["extraTitle"] = "تفاصيل السدادات والاستردادات القديمة",
                ["useRowExtra"] = true,
                ["lazyExtra"] = true,
                ["extraEndpoint"] = "/crud/extradataload",
                ["allowNoSelection"] = true,
                ["emptyText"] = "لا توجد سدادات مسجلة",
                ["extraLoadOnOpen"] = true,
                ["ctx"] = extraPaidCtx,
                ["extraRequest"] = extraPaidRequestBase,
                ["extraParamMap"] = new Dictionary<string, string>
                {
                    ["parameter_01"] = "p01",
                    ["parameter_02"] = "p02"
                },
                ["EnableSearch"] = true,
                ["ShowMeta"] = true,
                ["PageSize"] = 10,
                ["Sortable"] = true,
                ["showRowNumbers"] = true,
                ["visibleFields"] = new List<string>
                {
                    "paymentID", "deductName", "buildingPaymentTypeName_A",
                    "issueYear", "issueMonth", "paymentDate", "amount", "PaymentMovementText"
                },
                ["headerMap"] = new Dictionary<string, string>
                {
                    ["paymentID"] = "رقم الحركة",
                    ["deductName"] = "نوع السداد",
                    ["buildingPaymentTypeName_A"] = "طريقة السداد",
                    ["issueYear"] = "السنة",
                    ["issueMonth"] = "الشهر",
                    ["paymentDate"] = "تاريخ السداد",
                    ["amount"] = "المبلغ",
                    ["PaymentMovementText"] = "نوع الحركة"
                }
            };


            var extraMetaRefund = new Dictionary<string, object?>
            {
                ["extraSlotKey"] = "m2",
                ["extraTitle"] = "المبالغ المعادة المسجلة",
                ["useRowExtra"] = true,
                ["lazyExtra"] = true,
                ["extraEndpoint"] = "/crud/extradataload",
                ["allowNoSelection"] = true,
                ["emptyText"] = "لا توجد مبالغ معادة مسجلة",
                ["extraLoadOnOpen"] = true,

                ["ctx"] = extraPaidCtx,

                ["extraRequest"] = new Dictionary<string, object?>
                {
                    ["pageName_"] = PageName,
                    ["ActionType"] = "GetUnallocatedRefundsByResident",
                    ["tableIndex"] = 0
                },

                ["extraParamMap"] = new Dictionary<string, string>
                {
                    ["parameter_01"] = "p01",
                    ["parameter_02"] = "p02"
                },

                ["EnableSearch"] = true,
                ["ShowMeta"] = true,
                ["PageSize"] = 10,
                ["Sortable"] = true,
                ["showRowNumbers"] = true,

                ["visibleFields"] = new List<string>
    {
        "RefundID",
        "RefundAmount",
        "RefundDate",
        "RefundReference",
        "RefundDetails",
        "RefundStatusText",
        "AllocationCount",
        "TotalAllocated",
        "AllocationDetails",
        "EntryDate"
    },

                ["headerMap"] = new Dictionary<string, string>
                {
                    ["RefundID"] = "رقم الاسترداد",
                    ["RefundAmount"] = "المبلغ المعاد",
                    ["RefundDate"] = "تاريخ إعادة المبلغ",
                    ["RefundReference"] = "رقم مستند الإعادة",
                    ["RefundDetails"] = "تفاصيل الإعادة",
                    ["RefundStatusText"] = "حالة الاسترداد",
                    ["AllocationCount"] = "عدد الحركات المخصصة",
                    ["TotalAllocated"] = "إجمالي المبلغ المخصص",
                    ["AllocationDetails"] = "تفاصيل توزيع المبلغ",
                    ["EntryDate"] = "تاريخ التسجيل"
                }
            };

            var dsModel = new SmartTableDsModel
            {
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = new List<string> { "NationalID", "generalNo_FK", "FullName_A" },
                Searchable = true,
                AllowExport = true,
                PageTitle = "مراجعة الأرصدة العامة واستردادات المستفيدين",
                PanelTitle = "مراجعة الأرصدة العامة واستردادات المستفيدين",
                EnableCellCopy = true,
                ShowColumnVisibility = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                Selectable = true,
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowEdit = canRegisterRefund,
                    ShowEdit1 = canRegisterRefund,
                    ShowEdit2 = canRegisterRefund,
                    ShowPrint = false,
                    ShowPrint1 = false,
                    ShowBulkDelete = false,


                    // SmartDrawer - Unallocated Refunds


                    Drawers = new List<SmartDrawerConfig>
                            {
                                new SmartDrawerConfig
                                {
                                    Id = "sf-refund-drawer",
                                    Show = true,
                                    Title = "استعراض المبالغ المعادة",
                                    Subtitle = "سجل المبالغ المعادة للمستفيد حسب نوع الخدمة",
                                    Icon = "fa-solid fa-money-bill-transfer",
                                    Size = SmartDrawerSize.Large,
                                    Side = SmartDrawerSide.Left,
                            
                                    Table = new SmartTableDsModel
                                    {
                                        StoredProcedureName = "",
                                        Operation = "select",
                            
                                        Rows = new List<Dictionary<string, object?>>(),
                                        RowIdField = "RefundID",


                                        StyleRules = new List<TableStyleRule>
                                        {
                                            // الاسترداد المؤكد - أخضر
                                            new TableStyleRule
                                            {
                                                Target = "row",
                                                Field = "RefundStatus",
                                                Op = "eq",
                                                Value = "1",
                                                Priority = 1,
                                        
                                                PillEnabled = true,
                                                PillField = "RefundStatusText",
                                                PillTextField = "RefundStatusText",
                                                PillCssClass = "pill pill-green",
                                                PillMode = "replace"
                                            },
                                        
                                            // الاسترداد الملغى - أحمر
                                            new TableStyleRule
                                            {
                                                Target = "row",
                                                Field = "RefundStatus",
                                                Op = "eq",
                                                Value = "2",
                                                Priority = 1,
                                        
                                                PillEnabled = true,
                                                PillField = "RefundStatusText",
                                                PillTextField = "RefundStatusText",
                                                PillCssClass = "pill pill-red",
                                                PillMode = "replace"
                                            }
                                        },
                                        

                                        PageSize = 10,
                                        PageSizes = new List<int> { 10, 25, 50 },
                            
                                        Searchable = true,
                                        Selectable = true,
                                        ShowToolbar = true,
                                        ShowColumnVisibility = true,
                                        AllowExport = false,
                                        EnableCellCopy = true,
                            
                                        // ================================================
                                        // Toolbar - إلغاء تسجيل الاسترداد
                                        // ================================================
                                        Toolbar = new TableToolbarConfig
                                        {
                                            ShowRefresh = false,
                                            ShowColumns = true,
                                            ShowExportCsv = false,
                                            ShowExportExcel = false,
                                            ShowExportPdf = false,
                                            ShowPrint = false,
                                            ShowPrint1 = false,
                                            ShowPrint2 = false,
                                            ShowPrint3 = false,
                                            ShowBulkDelete = false,
                            
                                            ShowDelete = canCancelRefund,
                            
                                            Delete = canCancelRefund
                                                ? new TableAction
                                                {
                                                    Label = "إلغاء تسجيل الاسترداد",
                                                    Icon = "fa-solid fa-ban",
                                                    Color = "danger",
                                                    Show = true,
                            
                                                    // يظهر أعلى الجدول
                                                    Placement = TableActionPlacement.Button,
                            
                                                    // اختيار سجل واحد فقط
                                                    RequireSelection = true,
                                                    MinSelection = 1,
                                                    MaxSelection = 1,
                            
                                                    // منع إلغاء أي سجل غير مؤكد
                                                    Guards = new TableActionGuards
                                                    {
                                                        AppliesTo = "any",
                                                        DisableWhenAny = new List<TableActionRule>
                                                        {
                                                            new TableActionRule
                                                            {
                                                                Field = "RefundStatus",
                                                                Op = "neq",
                                                                Value = "1",
                                                                Message =
                                                                    "لا يمكن إلغاء استرداد غير مؤكد أو سبق إلغاؤه",
                                                                Priority = 3
                                                            }
                                                        }
                                                    },
                            
                                                    // ربط رقم الاسترداد من الصف المحدد
                                                    Meta = new Dictionary<string, object?>
                                                    {
                                                        ["formParamMap"] =
                                                            new Dictionary<string, string>
                                                            {
                                                                ["p01"] = "RefundID"
                                                            }
                                                    },
                            
                                                    OpenModal = true,
                                                    ModalTitle = "إلغاء تسجيل الاسترداد",
                                                    ModalMessage =
                                                        "سيتم إلغاء تسجيل الاسترداد مع الاحتفاظ بالسجل وتفاصيله وسجل التدقيق.",
                            
                                                    // ====================================
                                                    // نموذج إلغاء تسجيل الاسترداد
                                                    // ====================================
                                                    OpenForm = new FormConfig
                                                    {
                                                        FormId = "CancelUnallocatedRefundForm",
                                                        Title = "إلغاء تسجيل الاسترداد",
                                                        Method = "post",
                                                        ActionUrl = "/crud/update",
                            
                                                        Fields = new List<FieldConfig>
                                                        {
                                                            new FieldConfig
                                                            {
                                                                Name = "pageName_",
                                                                Type = "hidden",
                                                                Value = PageName
                                                            },
                            
                                                            new FieldConfig
                                                            {
                                                                Name = "ActionType",
                                                                Type = "hidden",
                                                                Value =
                                                                    "CANCELUNALLOCATEDPAYMENTREFUND"
                                                            },
                            
                                                            new FieldConfig
                                                            {
                                                                Name = "redirectAction",
                                                                Type = "hidden",
                                                                Value = PageName
                                                            },
                            
                                                            new FieldConfig
                                                            {
                                                                Name = "redirectController",
                                                                Type = "hidden",
                                                                Value = ControllerName
                                                            },
                            
                                                            // RefundID -> p01
                                                            new FieldConfig
                                                            {
                                                                Name = "p01",
                                                                Type = "hidden",
                                                                Readonly = true
                                                            },
                            
                                                            // CancellationReason -> p02
                                                            new FieldConfig
                                                            {
                                                                Name = "p02",
                                                                Label =
                                                                    "سبب إلغاء تسجيل الاسترداد",
                                                                Type = "textarea",
                                                                Required = true,
                                                                ColCss = "12",
                                                                MaxLength = 1000
                                                            }
                                                        }
                                                    }
                                                }
                                                : null
                                        },
                            
                                        // ================================================
                                        // أعمدة جدول الاستردادات
                                        // ================================================
                                        Columns = new List<TableColumn>
                                        {
                                            new TableColumn
                                            {
                                                Field = "RefundID",
                                                Label = "رقم الاسترداد",
                                                Type = "number",
                                                Visible = true,
                                                Sortable = true
                                            },
                            
                                            new TableColumn
                                            {
                                                Field = "RefundAmount",
                                                Label = "المبلغ المعاد",
                                                Type = "number",
                                                Visible = true,
                                                Sortable = true
                                            },
                            
                                            new TableColumn
                                            {
                                                Field = "RefundDate",
                                                Label = "تاريخ الإعادة",
                                                Type = "date",
                                                Visible = true,
                                                Sortable = true
                                            },
                            
                                            new TableColumn
                                            {
                                                Field = "RefundReference",
                                                Label = "رقم المستند",
                                                Type = "text",
                                                Visible = true,
                                                Sortable = true
                                            },
                            
                                            new TableColumn
                                            {
                                                Field = "RefundDetails",
                                                Label = "تفاصيل الإعادة",
                                                Type = "text",
                                                Visible = true
                                            },
                            
                                            new TableColumn
                                            {
                                                Field = "RefundStatusText",
                                                Label = "الحالة",
                                                Type = "text",
                                                Visible = true,
                                                Sortable = true
                                            },
                            
                                            new TableColumn
                                            {
                                                Field = "RefundStatus",
                                                Label = "رمز الحالة",
                                                Type = "number",
                                                Visible = false
                                            },
                            
                                            new TableColumn
                                            {
                                                Field = "AllocationCount",
                                                Label = "عدد الحركات",
                                                Type = "number",
                                                Visible = true
                                            },
                            
                                            new TableColumn
                                            {
                                                Field = "TotalAllocated",
                                                Label = "إجمالي المخصص",
                                                Type = "number",
                                                Visible = true
                                            },
                            
                                            new TableColumn
                                            {
                                                Field = "AllocationDetails",
                                                Label = "تفاصيل التوزيع",
                                                Type = "text",
                                                Visible = true
                                            },
                            
                                            new TableColumn
                                            {
                                                Field = "EntryDate",
                                                Label = "تاريخ التسجيل",
                                                Type = "date",
                                                Visible = true,
                                                Sortable = true
                                            }
                                        }
                                    },
                            
                                    EmptyText = "لم يتم تحميل سجلات المبالغ المعادة بعد"
                                }
                            },
                            


                    Edit = new TableAction
                    {
                        Label = "معالجة مبالغ زائدة",
                        Icon = "fa fa-check",
                        Color = "success",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تسجيل إعادة مبالغ زائدة",
                        ModalMessage = "التسجيل توثيق لمبلغ أُعيد فعليًا، وليس تنفيذ عملية صرف. تحقق من المستند والرصيد قبل الحفظ.",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OpenForm = new FormConfig
                        {
                            FormId = "UnallocatedPaymentRefundForm",
                            Title = "تسجيل مبلغ معاد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            SubmitText = "حفظ",
                            CancelText = "إلغاء",
                            Fields = refundFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                        Guards = new TableActionGuards
                        {
                            AppliesTo = "any",
                            DisableWhenAny = new List<TableActionRule>
                            {
                                new TableActionRule
                                {
                                    Field = "RemainingForReview",
                                    Op = "eq",
                                    Value = "0",
                                    Message = "لا يوجد مبلغ متبقٍ للتوثيق",
                                    Priority = 3
                                }
                            }
                        }
                    },
                    Edit1 = new TableAction
                    {
                        Label = "استعراض تفاصيل الرصيد ",
                        Icon = "fa fa-money-bill",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "استعراض تفاصيل الرصيد",
                        Show = true,
                        OpenForm = new FormConfig
                        {
                            FormId = "UnallocatedPaymentDetailsForm",
                            Title = "استعراض تفاصيل الرصيد",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig
                                {
                                    Text = "انهاء",
                                    Type = "button",
                                    Color = "secondary",
                                    OnClickJs = "window.__sfTableActive?.closeModal();"
                                }
                            },
                            Fields = paidFields
                        },
                        Meta = extraMetaPaid,
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },

                    Edit2 = new TableAction
                    {
                        Label = "استعراض المبالغ المعادة",
                        Icon = "fa fa-file-invoice-dollar",
                        Color = "primary",
                        IsEdit = true,
                        Show = true,

                        OpenModal = false,
                        OpenDrawer = true,
                        DrawerId = "sf-refund-drawer",

                        DrawerParamMap = new Dictionary<string, string>
                        {
                            ["parameter_01"] = "p01",
                            ["parameter_02"] = "p02"
                        },
                        DrawerTitleTemplate =
    "استعراض المبالغ المعادة للمستفيد: {FullName_A}",

                        DrawerSubtitleTemplate =
    "الرقم المرجعي: {residentInfoID} | نوع الخدمة: {BillChargeTypeName_A}",



                        ModalTitle = "استعراض المبالغ المعادة",

                        OpenForm = new FormConfig
                        {
                            FormId = "UnallocatedRefundDetailsForm",
                            Title = "سجل المبالغ المعادة",
                            Method = "post",
                            ActionUrl = "/crud/update",

                            Buttons = new List<FormButtonConfig>
        {
            new FormButtonConfig
            {
                Text = "إنهاء",
                Type = "button",
                Color = "secondary",
                OnClickJs = "window.__sfTableActive?.closeModal();"
            }
        },

                            Fields = paidFields
                        },

                        Meta = extraMetaRefund,

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
                PanelIcon = "fa-layer-group",
                TableDS = dsModel,


            };


            ViewData["SmartDrawers"] = dsModel.Toolbar.Drawers;

            return View("Insurance/HousingUnallocatedPaymentsReview", page);

        }
    }
}
