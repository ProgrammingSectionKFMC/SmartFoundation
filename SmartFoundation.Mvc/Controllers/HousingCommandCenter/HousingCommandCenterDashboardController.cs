using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartCharts;
using SmartFoundation.UI.ViewModels.SmartPage;
using System.Data;
using System.Globalization;

namespace SmartFoundation.Mvc.Controllers.HousingCommandCenter
{
    public partial class HousingCommandCenterDashboardController : Controller
    {
        // ═══════════════════════════════════════════════════════
        //  لوحة الألوان
        // ═══════════════════════════════════════════════════════
        private static class Color
        {

            public const string RoyalBlue = "#1a56db";
            public const string Teal = "#0694a2";
            public const string Amber = "#d97706";
            public const string Emerald = "#057a55";
            public const string Violet = "#6d28d9";

            // ── ألوان الإدارات
            public const string Navy = "#1e3a8a";
            public const string SteelBlue = "#1d4ed8";
            public const string Green = "#065f46";
            public const string Cyan = "#155e75";
            public const string Purple = "#5b21b6";
            public const string Orange = "#92400e";
            public const string Slate = "#1e3a5f";

            // ── للبيانات والتفاصيل ──
            public const string Red = "#991b1b";
            public const string Gold = "#b45309";
            public const string Indigo = "#3730a3";
        }

        public async Task<IActionResult> Index()
        {
            // تهيئة بيانات المستخدم والسيشن
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = "HousingCommandCenterDashboard";
            PageName = "HousingCommandCenterDashboard";

            var spParameters = new object?[]
            {
        PageName,
        IdaraId,
        usersId,
        HostName
            };

            DataSet ds;

            try
            {
                ds = await _mastersServies
                    .GetDataLoadDataSetAsync(spParameters);

                SplitDataSet(ds);
            }
            catch (Exception)
            {
                TempData["Error"] =
                    "حدث خطأ أثناء تحميل بيانات لوحة القيادة. يرجى المحاولة مرة أخرى.";

                return RedirectToAction("Index", "Home");
            }

            // dt1 = الإدارات القادمة من HousingCommandCenterDashboardDL

            var metrics = BuildMetrics();

            ViewBag.CommandCenterMetricCount = metrics.Count;

            ApplyHousingOccupancySummary(metrics, dt2);

            ApplyAllocationEfficiencySummary(metrics, dt2, dt3);

            ApplyFinancialSummary(metrics, dt4);

            var departments =
                BuildDepartmentsFromDatabase(dt1, dt2, dt3, dt4,dt10, metrics);
            ViewBag.CommandCenterDepartmentCount = departments.Count;

            var card =
                BuildCommandCenterCard(metrics, departments);

            var vm = new SmartPageViewModel
            {
                PageTitle = "لوحة قيادة الإدارات التشغيلية والصيانة",

                Charts = new SmartChartsConfig
                {
                    ChartsId = "housingCommandCenterDashboard",
                    Dir = "rtl",
                    Cards = new List<ChartCardConfig>
            {
                card
            }
                }
            };

            return View(vm);
        }

        public async Task<IActionResult> Department(string id)
        {
            //----------------------------------------------------------
            // Context
            //----------------------------------------------------------
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = "HousingCommandCenterDashboard";
            PageName = "HousingCommandCenterDashboard";

            //----------------------------------------------------------
            // DataLoad
            //----------------------------------------------------------
            var spParameters = new object?[]
            {
        PageName,
        IdaraId,
        usersId,
        HostName
            };

            DataSet ds;

            try
            {
                ds = await _mastersServies
                    .GetDataLoadDataSetAsync(spParameters);

                SplitDataSet(ds);
            }
            catch (Exception)
            {
                TempData["Error"] =
                    "حدث خطأ أثناء تحميل بيانات الإدارة. يرجى المحاولة مرة أخرى.";

                return RedirectToAction("Index");
            }

            //----------------------------------------------------------
            // Metrics
            //----------------------------------------------------------
            var metrics = BuildMetrics();

            //----------------------------------------------------------
            // Build departments from live DB data
            //----------------------------------------------------------
            var departments =
                BuildDepartmentsFromDatabase(
                    dt1,
                    dt2,
                    dt3,
                    dt4,
                    dt10,
                    metrics);

            //----------------------------------------------------------
            // Requested department
            //----------------------------------------------------------
            var department =
                departments.FirstOrDefault(
                    d => d.Key == id);

            if (department == null)
                return RedirectToAction("Index");

            //----------------------------------------------------------
            // ViewModel
            //----------------------------------------------------------
            var vm = new DepartmentDetailViewModel
            {
                Department = department,
                Metrics = metrics,

                HousingDetail =
        BuildHousingDetailFromDatabase(
            dt2,
            id),

                OccupancyLocations =
        BuildOccupancyLocationsFromDatabase(
            dt5,
            id),

                HousingReadiness =
    BuildHousingReadinessFromDatabase(
        dt6,
        id),

                HousingProcedures =
    BuildHousingProceduresFromDatabase(
        dt7,
        dt8,
        dt9,
        dt10,
        id),

                FinanceDetail =
    BuildFinanceDetailFromDatabase(
        dt4,
        dt11,
        id)

            };


            return View(vm);
        }







        public async Task<IActionResult> BuildingDetails(
            string id,
            string section,
            string status)
        {
            //----------------------------------------------------------
            // Context
            //----------------------------------------------------------
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = "HousingCommandCenterDashboard";
            PageName = "HousingCommandCenterDashboard";

            //----------------------------------------------------------
            // Target department
            //----------------------------------------------------------
            if (!long.TryParse(
                    id,
                    NumberStyles.None,
                    CultureInfo.InvariantCulture,
                    out var targetIdaraID)
                || targetIdaraID <= 0)
            {
                return RedirectToAction("Index");
            }

            //----------------------------------------------------------
            // Normalize drill-down arguments
            //----------------------------------------------------------
            section =
                (section ?? string.Empty)
                .Trim()
                .ToLowerInvariant();

            status =
                (status ?? string.Empty)
                .Trim()
                .ToUpperInvariant();

            //----------------------------------------------------------
            // Server-side allowlist
            //----------------------------------------------------------
            var occupancyStatuses =
                new HashSet<string>(
                    StringComparer.OrdinalIgnoreCase)
                {
                    "OCCUPIED",
                    "VACANT"
                };

            var readinessStatuses =
                new HashSet<string>(
                    StringComparer.OrdinalIgnoreCase)
                {
                    "OCCUPIED",
                    "READY",
                    "ALLOCATION",
                    "MAINTENANCE",
                    "QUALITY",
                    "GENERAL_SERVICES",
                    "HOUSING_DEPARTMENT",
                    "EXECUTION",
                    "VACANT_PENDING",
                    "NO_ACTIVE_ACTION",
                    "OTHER"
                };

            bool validRequest =
                section switch
                {
                    "occupancy" =>
                        occupancyStatuses.Contains(status),

                    "readiness" =>
                        readinessStatuses.Contains(status),

                    _ => false
                };

            if (!validRequest)
            {
                return RedirectToAction(
                    "Department",
                    new { id });
            }

            //----------------------------------------------------------
            // DataLoad
            //
            // parameter_01 = targetIdaraID
            // parameter_02 = section
            // parameter_03 = status
            //----------------------------------------------------------
            var spParameters = new object?[]
            {
                PageName,
                IdaraId,
                usersId,
                HostName,
                targetIdaraID,
                section,
                status
            };

            DataSet ds;

            try
            {
                ds = await _mastersServies
                    .GetDataLoadDataSetAsync(spParameters);
            }
            catch (Exception)
            {
                TempData["Error"] =
                    "حدث خطأ أثناء تحميل تفاصيل الوحدات السكنية. يرجى المحاولة مرة أخرى.";

                return RedirectToAction(
                    "Department",
                    new { id });
            }

            //----------------------------------------------------------
            // Detail mode result sets:
            //
            // Table[0] = Permissions
            // Table[1] = Building Details
            //
            // Do NOT call SplitDataSet here.
            //----------------------------------------------------------
            DataTable? detailsTable =
                ds.Tables.Count > 1
                    ? ds.Tables[1]
                    : null;

            //----------------------------------------------------------
            // Build ViewModel
            //----------------------------------------------------------
            var vm = new DepBuildingDetailsViewModel
            {
                DepartmentId = id,
                Section = section,
                Status = status,
                Title =
                    GetBuildingDetailsTitle(
                        section,
                        status),
                Rows =
                    BuildBuildingDetailsRows(
                        detailsTable)
            };

            return View(vm);
        }



        public async Task<IActionResult> ProcedureDetails(
    string id,
    string workflow = "ALL")
        {
            //----------------------------------------------------------
            // Context
            //----------------------------------------------------------
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName =
                "HousingCommandCenterDashboard";

            PageName =
                "HousingCommandCenterDashboard";


            //----------------------------------------------------------
            // Target department
            //----------------------------------------------------------
            if (!long.TryParse(
                    id,
                    NumberStyles.None,
                    CultureInfo.InvariantCulture,
                    out var targetIdaraID)
                || targetIdaraID <= 0)
            {
                return RedirectToAction("Index");
            }


            //----------------------------------------------------------
            // Normalize workflow
            //----------------------------------------------------------
            workflow =
                (workflow ?? string.Empty)
                .Trim()
                .ToUpperInvariant();


            //----------------------------------------------------------
            // Server-side allowlist
            //----------------------------------------------------------
            var allowedWorkflows =
                new HashSet<string>(
                    StringComparer.OrdinalIgnoreCase)
                {
            "ALL",
            "ALLOCATION",
            "EXTEND",
            "EXIT"
                };

            if (!allowedWorkflows.Contains(workflow))
            {
                return RedirectToAction(
                    "Department",
                    new { id });
            }


            //----------------------------------------------------------
            // DataLoad
            //
            // parameter_01 = targetIdaraID
            // parameter_02 = procedure
            // parameter_03 = workflow
            //----------------------------------------------------------
            var spParameters = new object?[]
            {
        PageName,
        IdaraId,
        usersId,
        HostName,
        targetIdaraID,
        "procedure",
        workflow
            };

            DataSet ds;

            try
            {
                ds = await _mastersServies
                    .GetDataLoadDataSetAsync(
                        spParameters);
            }
            catch (Exception)
            {
                TempData["Error"] =
                    "حدث خطأ أثناء تحميل تفاصيل إجراءات الإسكان. يرجى المحاولة مرة أخرى.";

                return RedirectToAction(
                    "Department",
                    new { id });
            }


            //----------------------------------------------------------
            // Detail Mode Result Sets:
            //
            // Table[0] = Permissions
            // Table[1] = Procedure Details
            //
            // Do NOT call SplitDataSet.
            //----------------------------------------------------------
            DataTable? detailsTable =
                ds.Tables.Count > 1
                    ? ds.Tables[1]
                    : null;


            //----------------------------------------------------------
            // ViewModel
            //----------------------------------------------------------
            var vm =
                new DepProcedureDetailsViewModel
                {
                    DepartmentId = id,

                    Workflow = workflow,

                    Title =
                        GetProcedureDetailsTitle(
                            workflow),

                    Rows =
                        BuildProcedureDetailsRows(
                            detailsTable)
                };

            return View(vm);
        }






        public async Task<IActionResult> FinancialDetails(
    string id,
    string mode = "CLAIMS",
    string? searchText = null,
    int? billChargeTypeID = null,
    string? sortKey = null,
    int pageNumber = 1,
    int pageSize = 25)
        {
            //----------------------------------------------------------
            // Context
            //----------------------------------------------------------
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName =
                "HousingCommandCenterDashboard";

            PageName =
                "HousingCommandCenterDashboard";


            //----------------------------------------------------------
            // Target department
            //----------------------------------------------------------
            if (!long.TryParse(
                    id,
                    NumberStyles.None,
                    CultureInfo.InvariantCulture,
                    out var targetIdaraID)
                || targetIdaraID <= 0)
            {
                return RedirectToAction("Index");
            }


            //----------------------------------------------------------
            // Normalize mode
            //----------------------------------------------------------
            mode =
                (mode ?? string.Empty)
                .Trim()
                .ToUpperInvariant();


            var allowedModes =
                new HashSet<string>(
                    StringComparer.OrdinalIgnoreCase)
                {
            "CLAIMS",
            "PAYMENTS",
            "DEFICIT",
            "SURPLUS",
            "BALANCED"
                };


            if (!allowedModes.Contains(mode))
            {
                return RedirectToAction(
                    "Department",
                    new { id });
            }


            //----------------------------------------------------------
            // Normalize search
            //----------------------------------------------------------
            searchText =
                string.IsNullOrWhiteSpace(searchText)
                    ? null
                    : searchText.Trim();


            //----------------------------------------------------------
            // Page size
            //----------------------------------------------------------
            if (pageSize != 25 &&
                pageSize != 50)
            {
                pageSize = 25;
            }


            if (pageNumber <= 0)
            {
                pageNumber = 1;
            }


            //----------------------------------------------------------
            // Charge type
            //
            // Charge type filtering applies only to:
            // CLAIMS / PAYMENTS
            //----------------------------------------------------------
            if (mode != "CLAIMS" &&
                mode != "PAYMENTS")
            {
                billChargeTypeID = null;
            }
            else if (billChargeTypeID <= 0)
            {
                billChargeTypeID = null;
            }


            //----------------------------------------------------------
            // Sort
            //----------------------------------------------------------
            sortKey =
                (sortKey ?? string.Empty)
                .Trim()
                .ToUpperInvariant();


            string defaultSortKey;

            HashSet<string> allowedSortKeys;


            switch (mode)
            {
                case "CLAIMS":
                case "PAYMENTS":

                    defaultSortKey =
                        "TOTAL_DESC";

                    allowedSortKeys =
                        new HashSet<string>(
                            StringComparer.OrdinalIgnoreCase)
                        {
                    "TOTAL_DESC",
                    "TOTAL_ASC",
                    "LATEST",
                    "OLDEST"
                        };

                    break;


                case "DEFICIT":

                    defaultSortKey =
                        "BALANCE_DESC";

                    allowedSortKeys =
                        new HashSet<string>(
                            StringComparer.OrdinalIgnoreCase)
                        {
                    "BALANCE_DESC",
                    "BALANCE_ASC",
                    "CLAIM_NEWEST",
                    "PAYMENT_NEWEST"
                        };

                    break;


                case "SURPLUS":

                    defaultSortKey =
                        "BALANCE_DESC";

                    allowedSortKeys =
                        new HashSet<string>(
                            StringComparer.OrdinalIgnoreCase)
                        {
                    "BALANCE_DESC",
                    "BALANCE_ASC",
                    "PAYMENT_NEWEST",
                    "CLAIM_NEWEST"
                        };

                    break;


                default: // BALANCED

                    defaultSortKey =
                        "ACTIVITY_NEWEST";

                    allowedSortKeys =
                        new HashSet<string>(
                            StringComparer.OrdinalIgnoreCase)
                        {
                    "ACTIVITY_NEWEST",
                    "TOTAL_DESC",
                    "TOTAL_ASC"
                        };

                    break;
            }


            if (!allowedSortKeys.Contains(sortKey))
            {
                sortKey =
                    defaultSortKey;
            }


            //----------------------------------------------------------
            // DataLoad
            //
            // parameter_01 = targetIdaraID
            // parameter_02 = finance
            // parameter_03 = mode
            // parameter_04 = searchText
            // parameter_05 = billChargeTypeID
            // parameter_06 = sortKey
            // parameter_07 = pageNumber
            // parameter_08 = pageSize
            //----------------------------------------------------------
            var spParameters = new object?[]
            {
        PageName,
        IdaraId,
        usersId,
        HostName,

        targetIdaraID,
        "finance",
        mode,
        searchText,
        billChargeTypeID,
        sortKey,
        pageNumber,
        pageSize
            };


            DataSet ds;

            try
            {
                ds = await _mastersServies
                    .GetDataLoadDataSetAsync(
                        spParameters);
            }
            catch (Exception)
            {
                TempData["Error"] =
                    "حدث خطأ أثناء تحميل التفاصيل المالية. يرجى المحاولة مرة أخرى.";

                return RedirectToAction(
                    "Department",
                    new { id });
            }


            //----------------------------------------------------------
            // Detail Mode Result Sets
            //
            // Table[0] = Permissions
            // Table[1] = Financial Residents
            // Table[2] = Paging / Meta
            // Table[3] = Charge Types
            //
            // Do NOT call SplitDataSet.
            //----------------------------------------------------------
            DataTable? detailsTable =
                ds.Tables.Count > 1
                    ? ds.Tables[1]
                    : null;

            DataTable? metaTable =
                ds.Tables.Count > 2
                    ? ds.Tables[2]
                    : null;

            DataTable? chargeTypesTable =
                ds.Tables.Count > 3
                    ? ds.Tables[3]
                    : null;


            DataRow? metaRow =
                metaTable != null &&
                metaTable.Rows.Count > 0
                    ? metaTable.Rows[0]
                    : null;


            //----------------------------------------------------------
            // Effective values returned by SQL
            //----------------------------------------------------------
            var effectivePageNumber =
                metaRow == null
                    ? pageNumber
                    : DbInt(
                          metaRow,
                          "PageNumber")
                      ?? pageNumber;

            var effectivePageSize =
                metaRow == null
                    ? pageSize
                    : DbInt(
                          metaRow,
                          "PageSize")
                      ?? pageSize;


            //----------------------------------------------------------
            // ViewModel
            //----------------------------------------------------------
            var vm =
                new DepFinancialDetailsViewModel
                {
                    DepartmentId =
                        id,

                    DepartmentName =
                        metaRow == null
                            ? string.Empty
                            : DbString(
                                metaRow,
                                "IdaraName"),

                    Mode =
                        mode,

                    Title =
                        GetFinancialDetailsTitle(
                            mode),

                    SearchText =
                        metaRow == null
                            ? searchText ?? string.Empty
                            : DbString(
                                metaRow,
                                "SearchText"),

                    BillChargeTypeID =
                        metaRow == null
                            ? billChargeTypeID
                            : DbInt(
                                metaRow,
                                "BillChargeTypeID"),

                    SortKey =
                        metaRow == null
                            ? sortKey
                            : DbString(
                                metaRow,
                                "SortKey"),

                    PageNumber =
                        effectivePageNumber,

                    PageSize =
                        effectivePageSize,

                    TotalRows =
                        metaRow == null
                            ? 0
                            : DbLong(
                                metaRow,
                                "TotalRows")
                              ?? 0,

                    TotalPages =
                        metaRow == null
                            ? 0
                            : DbLong(
                                metaRow,
                                "TotalPages")
                              ?? 0,

                    TotalClaims =
                        metaRow == null
                            ? 0m
                            : DbDecimal(
                                metaRow,
                                "TotalClaims")
                              ?? 0m,

                    TotalPayments =
                        metaRow == null
                            ? 0m
                            : DbDecimal(
                                metaRow,
                                "TotalPayments")
                              ?? 0m,

                    DeficitAmount =
                        metaRow == null
                            ? 0m
                            : DbDecimal(
                                metaRow,
                                "DeficitAmount")
                              ?? 0m,

                    SurplusAmount =
                        metaRow == null
                            ? 0m
                            : DbDecimal(
                                metaRow,
                                "SurplusAmount")
                              ?? 0m,

                    ClaimsCount =
                        metaRow == null
                            ? 0
                            : DbLong(
                                metaRow,
                                "ClaimsCount")
                              ??
                              DbLong(
                                  metaRow,
                                  "BillsCount")
                              ?? 0,

                    PaymentsCount =
                        metaRow == null
                            ? 0
                            : DbLong(
                                metaRow,
                                "PaymentsCount")
                              ?? 0,

                    Rows =
                        BuildFinancialDetailsRows(
                            detailsTable,
                            effectivePageNumber,
                            effectivePageSize),

                    ChargeTypes =
                        BuildFinancialChargeTypes(
                            chargeTypesTable)
                };


            return View(vm);
        }





        public async Task<IActionResult> ResidentFinancialDetails(
    string id,
    long residentInfoID,
    string? returnMode = null)
        {
            //----------------------------------------------------------
            // Context
            //----------------------------------------------------------
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName =
                "HousingCommandCenterDashboard";

            PageName =
                "HousingCommandCenterDashboard";


            //----------------------------------------------------------
            // Target department
            //----------------------------------------------------------
            if (!long.TryParse(
                    id,
                    NumberStyles.None,
                    CultureInfo.InvariantCulture,
                    out var targetIdaraID)
                || targetIdaraID <= 0)
            {
                return RedirectToAction("Index");
            }


            //----------------------------------------------------------
            // Resident
            //----------------------------------------------------------
            if (residentInfoID <= 0)
            {
                return RedirectToAction(
                    "Department",
                    new { id });
            }


            //----------------------------------------------------------
            // Return mode
            //----------------------------------------------------------
            returnMode =
                (returnMode ?? string.Empty)
                .Trim()
                .ToUpperInvariant();


            var allowedReturnModes =
                new HashSet<string>(
                    StringComparer.OrdinalIgnoreCase)
                {
            "CLAIMS",
            "PAYMENTS",
            "DEFICIT",
            "SURPLUS",
            "BALANCED"
                };


            if (!allowedReturnModes.Contains(returnMode))
            {
                returnMode = "CLAIMS";
            }


            //----------------------------------------------------------
            // DataLoad
            //
            // parameter_01 = targetIdaraID
            // parameter_02 = finance
            // parameter_03 = RESIDENT
            // parameter_04 = NULL
            // parameter_05 = NULL
            // parameter_06 = NULL
            // parameter_07 = NULL
            // parameter_08 = NULL
            // parameter_09 = residentInfoID
            //----------------------------------------------------------
            var spParameters = new object?[]
            {
        PageName,
        IdaraId,
        usersId,
        HostName,

        targetIdaraID,       // parameter_01
        "finance",           // parameter_02
        "RESIDENT",          // parameter_03
        null,                // parameter_04
        null,                // parameter_05
        null,                // parameter_06
        null,                // parameter_07
        null,                // parameter_08
        residentInfoID       // parameter_09
            };


            DataSet ds;

            try
            {
                ds = await _mastersServies
                    .GetDataLoadDataSetAsync(
                        spParameters);
            }
            catch (Exception)
            {
                TempData["Error"] =
                    "حدث خطأ أثناء تحميل التفاصيل المالية للمستفيد.";

                return RedirectToAction(
                    "FinancialDetails",
                    new
                    {
                        id,
                        mode = returnMode
                    });
            }


            //----------------------------------------------------------
            // Result Sets
            //
            // Table[0] = Permissions
            // Table[1] = Beneficiary / Financial Position
            // Table[2] = Summary By Charge Type
            // Table[3] = Claims
            // Table[4] = Payments
            //
            // Do NOT call SplitDataSet.
            //----------------------------------------------------------
            DataTable? summaryTable =
                ds.Tables.Count > 1
                    ? ds.Tables[1]
                    : null;

            DataTable? chargeTypesTable =
                ds.Tables.Count > 2
                    ? ds.Tables[2]
                    : null;

            DataTable? claimsTable =
                ds.Tables.Count > 3
                    ? ds.Tables[3]
                    : null;

            DataTable? paymentsTable =
                ds.Tables.Count > 4
                    ? ds.Tables[4]
                    : null;


            //----------------------------------------------------------
            // SQL intentionally returns no summary row when:
            // - resident does not exist
            // - resident has no financial movement in selected Idara
            //----------------------------------------------------------
            if (summaryTable == null ||
                summaryTable.Rows.Count == 0)
            {
                TempData["Error"] =
                    "لا توجد حركة مالية لهذا المستفيد ضمن الإدارة المحددة.";

                return RedirectToAction(
                    "FinancialDetails",
                    new
                    {
                        id,
                        mode = returnMode
                    });
            }


            var row =
                summaryTable.Rows[0];


            //----------------------------------------------------------
            // ViewModel
            //----------------------------------------------------------
            var vm =
                new DepResidentFinancialDetailsViewModel
                {
                    DepartmentId =
                        id,

                    ReturnMode =
                        returnMode,

                    ResidentInfoID =
                        DbLong(
                            row,
                            "residentInfoID")
                        ?? residentInfoID,

                    GeneralNo =
                        DbString(
                            row,
                            "GeneralNo"),

                    RankName =
                        DbString(
                            row,
                            "RankName"),

                    FullName =
                        DbString(
                            row,
                            "FullName"),

                    MilitaryUnitName =
                        DbString(
                            row,
                            "MilitaryUnitName"),

                    IdaraID =
                        DbLong(
                            row,
                            "IdaraID"),

                    IdaraName =
                        DbString(
                            row,
                            "IdaraName"),

                    TotalClaims =
                        DbDecimal(
                            row,
                            "TotalClaims")
                        ?? 0m,

                    TotalPayments =
                        DbDecimal(
                            row,
                            "TotalPayments")
                        ?? 0m,

                    BalanceDifference =
                        DbDecimal(
                            row,
                            "BalanceDifference")
                        ?? 0m,

                    FinancialStatus =
                        DbString(
                            row,
                            "FinancialStatus"),

                    BalanceAmount =
                        DbDecimal(
                            row,
                            "BalanceAmount")
                        ?? 0m,

                    ClaimsCount =
                        DbLong(
                            row,
                            "ClaimsCount")
                        ?? 0,

                    PaymentsCount =
                        DbLong(
                            row,
                            "PaymentsCount")
                        ?? 0,

                    LastClaimDate =
                        DbDate(
                            row,
                            "LastClaimDate"),

                    LastPaymentDate =
                        DbDate(
                            row,
                            "LastPaymentDate"),

                    LastActionID =
                        DbLong(
                            row,
                            "LastActionID"),

                    LastActionTypeID =
                        DbInt(
                            row,
                            "LastActionTypeID"),

                    HousingStatus =
                        DbString(
                            row,
                            "HousingStatus"),

                    LastActionBuildingID =
                        DbLong(
                            row,
                            "LastActionBuildingID"),

                    LastActionBuildingNo =
                        DbString(
                            row,
                            "LastActionBuildingNo"),

                    LastActionDate =
                        DbDate(
                            row,
                            "LastActionDate"),

                    ChargeTypes =
                        BuildResidentFinancialTypeSummary(
                            chargeTypesTable),

                    Claims =
                        BuildResidentFinancialClaims(
                            claimsTable),

                    Payments =
                        BuildResidentFinancialPayments(
                            paymentsTable)
                };


            return View(vm);
        }


        // ───────────────────────────────────────────────────────
        private static ChartCardConfig BuildCommandCenterCard(
     List<HousingCommandCenterMetric> metrics,
     List<HousingCommandCenterDepartment> departments)
        {
            var summaryRow = BuildSummaryRow(metrics, departments);

            return new ChartCardConfig
            {
                Type = ChartCardType.HousingCommandCenter,
                Id = "hcc_exec_final",
                Title = "لوحة قيادة الإدارات التشغيلية والصيانة",
                Subtitle = "قراءة تنفيذية نهائية لملف السكن، التخصيص، الطلبات، الماليات، والصيانة الوقائية",
                Icon = "fa-solid fa-building-shield",
                Tone = ChartTone.Info,
                ColCss = "12",
                Dir = "rtl",
                ShowHeader = false,
                Variant = ChartCardVariant.Soft,
                ExtraCss = "hccm-dashboard-card",

                HousingCommandCenterBoardOptions =
                    new HousingCommandCenterBoardOptions
                    {
                        TitleText =
                            "لوحة قيادة الإدارات التشغيلية والصيانة",

                        SubtitleText =
                            "خمسة معايير قرار رئيسية تعكس الجاهزية السكنية، كفاءة التخصيص، أداء الطلبات، الكفاءة المالية، والصيانة والجودة",

                        ShowHeader = false,
                        ShowSummaryRow = false,
                        ShowDepartmentRanking = false,
                        ShowMetricProgressBar = true,
                        ShowMetricTargetActual = true,
                        AutoCalculatePercentages = true,
                        PreferredCardsPerRow = 5,
                        PercentFormat = "0.0",
                        NumberFormat = "0"
                    },

                HousingCommandCenterMetrics = metrics,
                HousingCommandCenterDepartments = departments,
                HousingCommandCenterSummaryRow = summaryRow
            };
        }

        private static decimal? CalculateWorkflowEfficiency(
    decimal targetDays,
    int completedCount,
    decimal? averageDays)
        {
            if (completedCount <= 0 ||
                !averageDays.HasValue)
            {
                return null;
            }

            if (averageDays.Value <= 0)
            {
                return 100m;
            }

            return Math.Round(
                Math.Min(
                    100m,
                    targetDays /
                    averageDays.Value *
                    100m),
                1);
        }


        private static
        (
            int CompletedCount,
            decimal? AverageDays,
            decimal? EfficiencyPercent
        )
        GetDepartmentWorkflowPerformance(
            DataTable? table,
            string idaraID,
            string workflowKey,
            decimal targetDays)
        {
            if (table == null)
            {
                return (0, null, null);
            }

            var row =
                table
                    .AsEnumerable()
                    .FirstOrDefault(r =>
                        Convert.ToString(
                            r["idaraID"],
                            CultureInfo.InvariantCulture)
                            == idaraID
                        &&
                        string.Equals(
                            Convert.ToString(
                                r["WorkflowKey"],
                                CultureInfo.InvariantCulture),
                            workflowKey,
                            StringComparison.OrdinalIgnoreCase));

            if (row == null)
            {
                return (0, null, null);
            }

            var completedCount =
                row["CompletedCount"] == DBNull.Value
                    ? 0
                    : Convert.ToInt32(
                        row["CompletedCount"],
                        CultureInfo.InvariantCulture);

            decimal? averageDays =
                row["AverageDays"] == DBNull.Value
                    ? null
                    : Convert.ToDecimal(
                        row["AverageDays"],
                        CultureInfo.InvariantCulture);

            var efficiency =
                CalculateWorkflowEfficiency(
                    targetDays,
                    completedCount,
                    averageDays);

            return
            (
                completedCount,
                averageDays,
                efficiency
            );
        }


        private static List<HousingCommandCenterDepartment>
    BuildDepartmentsFromDatabase(
        DataTable? idaraTable,
        DataTable? occupancyTable,
        DataTable? waitingTable,
        DataTable? financialTable,
        DataTable? workflowPerformanceTable,
        List<HousingCommandCenterMetric> metrics)
        {
            var departments =
                new List<HousingCommandCenterDepartment>();

            if (idaraTable == null || idaraTable.Rows.Count == 0)
                return departments;

            var departmentColors = new[]
            {
        Color.Navy,
        Color.Green,
        Color.SteelBlue,
        Color.Cyan,
        Color.Purple,
        Color.Orange,
        Color.Slate
    };

            var sortOrder = 1;

            foreach (DataRow row in idaraTable.Rows)
            {
                if (row["idaraID"] == DBNull.Value)
                    continue;

                var idaraID =
                    Convert.ToString(
                        row["idaraID"],
                        CultureInfo.InvariantCulture);

                if (string.IsNullOrWhiteSpace(idaraID))
                    continue;

                var longName =
                    row["idaraLongName_A"] == DBNull.Value
                        ? string.Empty
                        : row["idaraLongName_A"]?.ToString()?.Trim()
                            ?? string.Empty;

                var shortName =
                    row["idaraShortName_A"] == DBNull.Value
                        ? string.Empty
                        : row["idaraShortName_A"]?.ToString()?.Trim()
                            ?? string.Empty;

                if (string.IsNullOrWhiteSpace(shortName))
                    shortName = longName;

                var color =
                    departmentColors[
                        (sortOrder - 1) % departmentColors.Length];

                //----------------------------------------------------------
                // بيانات جاهزية السكن ونسبة الإشغال لهذه الإدارة
                //----------------------------------------------------------
                DataRow? occupancyRow = null;

                if (occupancyTable != null)
                {
                    occupancyRow =
                        occupancyTable
                            .AsEnumerable()
                            .FirstOrDefault(r =>
                                Convert.ToString(
                                    r["idaraID"],
                                    CultureInfo.InvariantCulture)
                                == idaraID);
                }

                decimal totalHousingUnits = 0;
                decimal occupiedHousingUnits = 0;
                decimal unoccupiedHousingUnits = 0;
                decimal occupancyPercent = 0;

                if (occupancyRow != null)
                {
                    totalHousingUnits =
                        occupancyRow["TotalHousingUnits"] == DBNull.Value
                            ? 0
                            : Convert.ToDecimal(
                                occupancyRow["TotalHousingUnits"],
                                CultureInfo.InvariantCulture);

                    occupiedHousingUnits =
                        occupancyRow["OccupiedHousingUnits"] == DBNull.Value
                            ? 0
                            : Convert.ToDecimal(
                                occupancyRow["OccupiedHousingUnits"],
                                CultureInfo.InvariantCulture);

                    unoccupiedHousingUnits =
                        occupancyRow["UnoccupiedHousingUnits"] == DBNull.Value
                            ? 0
                            : Convert.ToDecimal(
                                occupancyRow["UnoccupiedHousingUnits"],
                                CultureInfo.InvariantCulture);

                    occupancyPercent =
                        occupancyRow["OccupancyPercent"] == DBNull.Value
                            ? 0
                            : Convert.ToDecimal(
                                occupancyRow["OccupancyPercent"],
                                CultureInfo.InvariantCulture);
                }

                // لا يوجد مخزون سكني لدى الإدارة
                // لذلك لا يوجد إخفاق في مؤشر الإشغال
                if (totalHousingUnits <= 0)
                {
                    occupancyPercent = 100m;
                }


                //----------------------------------------------------------
                // قوائم الانتظار الحالية لهذه الإدارة
                //----------------------------------------------------------
                DataRow? waitingRow = null;

                if (waitingTable != null)
                {
                    waitingRow =
                        waitingTable
                            .AsEnumerable()
                            .FirstOrDefault(r =>
                                Convert.ToString(
                                    r["idaraID"],
                                    CultureInfo.InvariantCulture)
                                == idaraID);
                }

                decimal currentWaitingCount = 0;

                if (waitingRow != null)
                {
                    currentWaitingCount =
                        waitingRow["CurrentWaitingCount"] == DBNull.Value
                            ? 0
                            : Convert.ToDecimal(
                                waitingRow["CurrentWaitingCount"],
                                CultureInfo.InvariantCulture);
                }


                // ------------------------------------------


                decimal allocationEfficiencyPercent;

                if (currentWaitingCount <= 0)
                {
                    // لا توجد قائمة انتظار، فلا توجد مشكلة تخصيص
                    allocationEfficiencyPercent = 100m;
                }
                else
                {
                    // عدد الحالات التي يوجد لها مقابل عددي من المنازل الشاغرة
                    var conflictingCount =
                        Math.Min(
                            currentWaitingCount,
                            unoccupiedHousingUnits);

                    // كلما زاد وجود منتظرين بالتزامن مع الشواغر انخفضت الكفاءة
                    allocationEfficiencyPercent =
                        Math.Round(
                            100m -
                            (
                                conflictingCount * 100m /
                                currentWaitingCount
                            ),
                            1);
                }

                // العجز العددي الحقيقي
                var waitingDeficit =
                    Math.Max(
                        currentWaitingCount - unoccupiedHousingUnits,
                        0m);



                //------------------------------------------------


                //----------------------------------------------------------
                // البيانات المالية
                //----------------------------------------------------------
                DataRow? financialRow = null;

                if (financialTable != null)
                {
                    financialRow =
                        financialTable
                            .AsEnumerable()
                            .FirstOrDefault(r =>
                                Convert.ToString(
                                    r["idaraID"],
                                    CultureInfo.InvariantCulture)
                                == idaraID);
                }

                decimal totalClaims = 0m;
                decimal totalPayments = 0m;

                decimal amountToCollect = 0m;
                decimal amountToRefund = 0m;

                decimal totalFinancialGap = 0m;
                decimal netFinancialPosition = 0m;

                decimal? balancedBeneficiariesPercent = null;
                decimal? financialEfficiencyPercent = null;

                int financialBeneficiariesCount = 0;
                int balancedBeneficiariesCount = 0;
                int deficitBeneficiariesCount = 0;
                int surplusBeneficiariesCount = 0;


                if (financialRow != null)
                {
                    financialBeneficiariesCount =
                        financialRow["FinancialBeneficiariesCount"] == DBNull.Value
                            ? 0
                            : Convert.ToInt32(
                                financialRow["FinancialBeneficiariesCount"],
                                CultureInfo.InvariantCulture);


                    balancedBeneficiariesCount =
                        financialRow["BalancedBeneficiariesCount"] == DBNull.Value
                            ? 0
                            : Convert.ToInt32(
                                financialRow["BalancedBeneficiariesCount"],
                                CultureInfo.InvariantCulture);


                    deficitBeneficiariesCount =
                        financialRow["DeficitBeneficiariesCount"] == DBNull.Value
                            ? 0
                            : Convert.ToInt32(
                                financialRow["DeficitBeneficiariesCount"],
                                CultureInfo.InvariantCulture);


                    surplusBeneficiariesCount =
                        financialRow["SurplusBeneficiariesCount"] == DBNull.Value
                            ? 0
                            : Convert.ToInt32(
                                financialRow["SurplusBeneficiariesCount"],
                                CultureInfo.InvariantCulture);


                    totalClaims =
                        financialRow["TotalClaims"] == DBNull.Value
                            ? 0m
                            : Convert.ToDecimal(
                                financialRow["TotalClaims"],
                                CultureInfo.InvariantCulture);


                    totalPayments =
                        financialRow["TotalPayments"] == DBNull.Value
                            ? 0m
                            : Convert.ToDecimal(
                                financialRow["TotalPayments"],
                                CultureInfo.InvariantCulture);


                    amountToCollect =
                        financialRow["AmountToCollect"] == DBNull.Value
                            ? 0m
                            : Convert.ToDecimal(
                                financialRow["AmountToCollect"],
                                CultureInfo.InvariantCulture);


                    amountToRefund =
                        financialRow["AmountToRefund"] == DBNull.Value
                            ? 0m
                            : Convert.ToDecimal(
                                financialRow["AmountToRefund"],
                                CultureInfo.InvariantCulture);


                    totalFinancialGap =
                        financialRow["TotalFinancialGap"] == DBNull.Value
                            ? 0m
                            : Convert.ToDecimal(
                                financialRow["TotalFinancialGap"],
                                CultureInfo.InvariantCulture);


                    netFinancialPosition =
                        financialRow["NetFinancialPosition"] == DBNull.Value
                            ? 0m
                            : Convert.ToDecimal(
                                financialRow["NetFinancialPosition"],
                                CultureInfo.InvariantCulture);


                    balancedBeneficiariesPercent =
                        financialRow["BalancedBeneficiariesPercent"] == DBNull.Value
                            ? null
                            : Convert.ToDecimal(
                                financialRow["BalancedBeneficiariesPercent"],
                                CultureInfo.InvariantCulture);


                    financialEfficiencyPercent =
                        financialRow["FinancialEfficiencyPercent"] == DBNull.Value
                            ? null
                            : Convert.ToDecimal(
                                financialRow["FinancialEfficiencyPercent"],
                                CultureInfo.InvariantCulture);
                }

                //----------------------------------------------------------
                // مؤشرات الإدارة
                //----------------------------------------------------------
                //----------------------------------------------------------
                // كفاءة إجراءات الإسكان
                //----------------------------------------------------------

                var allocationWorkflow =
                    GetDepartmentWorkflowPerformance(
                        workflowPerformanceTable,
                        idaraID,
                        "ALLOCATION",
                        30m);

                var extendWorkflow =
                    GetDepartmentWorkflowPerformance(
                        workflowPerformanceTable,
                        idaraID,
                        "EXTEND",
                        5m);

                var exitWorkflow =
                    GetDepartmentWorkflowPerformance(
                        workflowPerformanceTable,
                        idaraID,
                        "EXIT",
                        5m);


                var procedureEfficiencies =
                    new decimal?[]
                    {
        allocationWorkflow.EfficiencyPercent,
        extendWorkflow.EfficiencyPercent,
        exitWorkflow.EfficiencyPercent
                    }
                    .Where(x => x.HasValue)
                    .Select(x => x!.Value)
                    .ToList();


                decimal? housingProceduresEfficiencyPercent =
                    procedureEfficiencies.Count > 0
                        ? Math.Round(
                            procedureEfficiencies.Average(),
                            1)
                        : null;


                var procedureNotes =
                    new List<string>();


                if (allocationWorkflow.EfficiencyPercent.HasValue)
                {
                    procedureNotes.Add(
                        $"التسكين: متوسط {allocationWorkflow.AverageDays:0.0} يوم " +
                        $"| الهدف 30 يوم " +
                        $"| الكفاءة {allocationWorkflow.EfficiencyPercent:0.0}% " +
                        $"| مكتمل {allocationWorkflow.CompletedCount}");
                }


                if (extendWorkflow.EfficiencyPercent.HasValue)
                {
                    procedureNotes.Add(
                        $"الإمهال: متوسط {extendWorkflow.AverageDays:0.0} يوم " +
                        $"| الهدف 5 أيام " +
                        $"| الكفاءة {extendWorkflow.EfficiencyPercent:0.0}% " +
                        $"| مكتمل {extendWorkflow.CompletedCount}");
                }


                if (exitWorkflow.EfficiencyPercent.HasValue)
                {
                    procedureNotes.Add(
                        $"الإخلاء: متوسط {exitWorkflow.AverageDays:0.0} يوم " +
                        $"| الهدف 5 أيام " +
                        $"| الكفاءة {exitWorkflow.EfficiencyPercent:0.0}% " +
                        $"| مكتمل {exitWorkflow.CompletedCount}");
                }


                var housingProceduresNote =
                    procedureNotes.Count > 0
                        ? string.Join(
                            " | ",
                            procedureNotes)
                        : "لا توجد دورات مكتملة يمكن احتساب الكفاءة منها.";



                var departmentMetrics =
                    metrics
                        .OrderBy(x => x.SortOrder)
                        .Select(metric =>
                        {
                            //--------------------------------------------------
                            // الكارد الأول: جاهزية السكن ونسب الإشغال
                            //--------------------------------------------------
                            if (metric.Key == "m_housing_readiness")
                            {
                                return new HousingCommandCenterDepartmentMetric
                                {
                                    MetricKey = metric.Key,

                                    // إجمالي الوحدات
                                    Target = totalHousingUnits,

                                    // الوحدات المشغولة
                                    Actual = occupiedHousingUnits,

                                    // نستخدم النسبة المحسوبة من SQL
                                    CompletionPercent = occupancyPercent,

                                    DisplayText =
                                        $"{occupancyPercent:0.0}%",

                                    Tone = metric.Tone,
                                    Color = metric.Color,
                                    

                                    Note =
                                        $"إجمالي الوحدات: {totalHousingUnits:0} | " +
                                        $"المشغولة: {occupiedHousingUnits:0} | " +
                                        $"غير المشغولة: {unoccupiedHousingUnits:0} | " +
                                        $"نسبة الإشغال: {occupancyPercent:0.0}%"
                                };
                            }


                            //--------------------------------------------------
                            // الكارد الثاني:
                            // قوائم الانتظار مقابل الوحدات غير المشغولة
                            //--------------------------------------------------
                            if (metric.Key == "m_allocation_balance")
                            {
                                return new HousingCommandCenterDepartmentMetric
                                {
                                    MetricKey = metric.Key,

                                    // المنتظرون
                                    Actual = currentWaitingCount,

                                    // المنازل الشاغرة
                                    Target = unoccupiedHousingUnits,

                                    // كفاءة التخصيص هي النسبة التي تدخل في أداء الإدارة
                                    CompletionPercent = allocationEfficiencyPercent,

                                    DisplayText =
                                        $"{allocationEfficiencyPercent:0.0}%",

                                    Tone = metric.Tone,

                                    Color = metric.Color,

                                    Note =
                                        $"المنتظرون: {currentWaitingCount:0} | " +
                                        $"المنازل الشاغرة: {unoccupiedHousingUnits:0} | " +
                                        $"المنتظرون بعد التغطية: {waitingDeficit:0} | " +
                                        $"كفاءة التخصيص: {allocationEfficiencyPercent:0.0}%"
                                };
                            }


                            //--------------------------------------------------
                            // كفاءة إجراءات الإسكان
                            //--------------------------------------------------
                            if (metric.Key == "m_housing_procedures")
                            {
                                return new HousingCommandCenterDepartmentMetric
                                {
                                    MetricKey = metric.Key,

                                    Target =
                                        housingProceduresEfficiencyPercent.HasValue
                                            ? 100m
                                            : null,

                                    Actual =
                                        housingProceduresEfficiencyPercent,

                                    CompletionPercent =
                                        housingProceduresEfficiencyPercent,

                                    DisplayText =
                                        housingProceduresEfficiencyPercent.HasValue
                                            ? $"{housingProceduresEfficiencyPercent.Value:0.0}%"
                                            : "—",

                                    Tone = metric.Tone,

                                    Color = metric.Color,

                                    Note =
                                        housingProceduresNote
                                };
                            }
                            //---------------------------------------------------

                            if (metric.Key == "m_finance_utilities")
                            {
                                return new HousingCommandCenterDepartmentMetric
                                {
                                    MetricKey =
                                        metric.Key,

                                    //--------------------------------------------------
                                    // إجمالي السدادات
                                    //--------------------------------------------------
                                    Actual =
                                        totalPayments,

                                    //--------------------------------------------------
                                    // إجمالي المطالبات
                                    //--------------------------------------------------
                                    Target =
                                        totalClaims,

                                    //--------------------------------------------------
                                    // الكفاءة الجديدة
                                    //--------------------------------------------------
                                    CompletionPercent =
                                        financialEfficiencyPercent,

                                    DisplayText =
                                        financialEfficiencyPercent.HasValue
                                            ? $"{financialEfficiencyPercent.Value:0.0}%"
                                            : "—",

                                    Tone =
                                        metric.Tone,

                                    Color =
                                        metric.Color,

                                    Note =
                                        financialEfficiencyPercent.HasValue
                                            ?
                                                $"المستفيدون الماليون: {financialBeneficiariesCount:N0} | " +
                                                $"المتوازنون: {balancedBeneficiariesCount:N0} | " +
                                                $"بعجز: {deficitBeneficiariesCount:N0} | " +
                                                $"بفائض: {surplusBeneficiariesCount:N0} | " +
                                                $"إجمالي المطالبات: {totalClaims:N2} | " +
                                                $"إجمالي السدادات: {totalPayments:N2} | " +
                                                $"مطلوب تحصيله: {amountToCollect:N2} | " +
                                                $"مطلوب إعادته: {amountToRefund:N2} | " +
                                                $"الكفاءة المالية: {financialEfficiencyPercent.Value:0.0}%"
                                            :
                                                "لا توجد حركة مالية للمستفيدين يمكن احتساب الكفاءة منها."
                                };
                            }

                            //--------------------------------------------------
                            // بقية المؤشرات لم تربط بعد
                            //--------------------------------------------------
                            return new HousingCommandCenterDepartmentMetric
                            {
                                MetricKey = metric.Key,
                                Target = null,
                                Actual = null,
                                CompletionPercent = null,
                                DisplayText = "—",
                                Tone = metric.Tone,
                                Color = metric.Color,
                                Note = "لم يتم ربط هذا المؤشر بالبيانات الحية بعد."
                            };
                        })
                        .ToList();

                //----------------------------------------------------------
                // الأداء العام حاليًا يعتمد على المؤشرات المرتبطة فقط
                //----------------------------------------------------------
                var availablePercentages =
                    departmentMetrics
                        .Where(x => x.CompletionPercent.HasValue)
                        .Select(x => x.CompletionPercent!.Value)
                        .ToList();

                decimal? overallCompletionPercent =
                    availablePercentages.Count > 0
                        ? Math.Round(
                            availablePercentages.Average(),
                            1)
                        : null;

                departments.Add(
                    new HousingCommandCenterDepartment
                    {
                        Key = idaraID,
                        SortOrder = sortOrder,

                        Name = longName,
                        ShortName = shortName,

                        Icon = "fa-solid fa-building",
                        Emoji = "🏢",

                        Tone = "info",
                        Color = color,

                        Href =
                            $"/HousingCommandCenterDashboard/Department?id={idaraID}",

                        OverallCompletionPercent =
                            overallCompletionPercent,

                        Metrics = departmentMetrics
                    });

                sortOrder++;
            }

            return departments;
        }

        // ═══════════════════════════════════════════════════════
        //  المعايير — 5 ألوان مختلفة تماماً وزاهية
        // ═══════════════════════════════════════════════════════
        private static List<HousingCommandCenterMetric> BuildMetrics() =>
        [
           new HousingCommandCenterMetric
            {
                Key        = "m_housing_readiness",
                SortOrder  = 1,

                Title      = "جاهزية السكن ونسب الإشغال",
                ShortTitle = "جاهزية السكن ونسب الإشغال",

                Subtitle =
                    "يقيس نسبة الوحدات السكنية المشغولة من إجمالي الوحدات السكنية",
                FormulaText =  "تقاس النسبة من نسبة الوحدات السكنية المشغولة من إجمالي الوحدات السكنية.",

                Target = 100,
                Actual = 0,

                Unit = "%",
            
                // معنى القيم داخل هذا الكارد
                ActualLabel = "المشغول",
                TargetLabel = "الإجمالي",
                RemainingLabel = "غير المشغول",
            
                // Actual و Target هنا أعداد وحدات وليست نسبًا مئوية
                ShowValueUnit = false,

                Icon  = "fa-solid fa-building-circle-check",
                Emoji = "🏛️",
                Tone  = "info",
                Color = Color.Gold,


                Hint =
                    "نسبة الإشغال = عدد الوحدات المشغولة ÷ إجمالي الوحدات السكنية × 100"
            },
            new HousingCommandCenterMetric
            {
                Key        = "m_allocation_balance",
                SortOrder  = 2,

                Title = "كفاءة تخصيص السكن للمنتظرين",
                ShortTitle = "كفاءة تخصيص السكن للمنتظرين",
                Subtitle = "يوضح كفاءة الإدارة في معالجة قوائم الانتظار في ضوء وجود منازل شاغرة",
                FormulaText =   "تبدأ الكفاءة من 100% وتنخفض بحسب نسبة وجود منتظرين بالتزامن مع وجود منازل شاغرة.",

                Target = 0,
                Actual = 0,
                CompletionPercent = 0,

                Unit = "%",

                ActualLabel = "المنتظرون",
                TargetLabel = "المنازل الشاغرة",
                RemainingLabel = "المنتظرون بعد تغطية المنازل الشاغرة",

                ShowValueUnit = false,






                Icon = "fa-solid fa-users-viewfinder",
                Emoji = "👥",
                Tone = "info",
                Color = Color.Teal,

                Hint = "يقيس المؤشر كفاءة الإدارة في تخصيص السكن للمنتظرين، وينخفض عند وجود منتظرين بالتزامن مع وجود منازل شاغرة."

            },
            new HousingCommandCenterMetric
{
    Key = "m_housing_procedures",
    SortOrder = 3,

    Title = "كفاءة إجراءات الإسكان",
    ShortTitle = "كفاءة إجراءات الإسكان",

    Subtitle =
        "يقيس سرعة إنجاز التسكين والإمهال والإخلاء مقارنة بالمدد المستهدفة",

    FormulaText = "تقارن متوسط مدة كل مسار بالمدة المستهدفة له بحد أقصى 100%، ثم تحسب متوسط المسارات المكتملة. المستهدف: التسكين 30 يومًا، الإمهال 5 أيام، الإخلاء 5 أيام.",
    Target = 100,
    Actual = 0,
    CompletionPercent = null,

    Unit = "%",

    ActualLabel = "الكفاءة",
    TargetLabel = "الهدف",
    RemainingLabel = "الفجوة",

    ShowValueUnit = true,

    Icon = "fa-solid fa-stopwatch",
    Emoji = "⏱️",

    Tone = "info",
    Color = Color.Emerald,

    Hint =
        "يتم احتساب كل مسار مقابل مدته المستهدفة بحد أقصى 100%، " +
        "ثم يؤخذ متوسط المسارات التي لديها دورات مكتملة فقط."
},
           new HousingCommandCenterMetric
            {
                Key = "m_finance_utilities",
                SortOrder = 4,

                Title = "كفاءة التحصيل والتسوية المالية",
                ShortTitle = "الكفاءة المالية",

                Subtitle =
                    "يقيس كفاءة تسوية المطالبات المالية بمختلف أنواعها مقابل السدادات الفعلية لكل إدارة",

                Target = 0,
                Actual = 0,
                CompletionPercent = 0,

                Unit = "%",

                ActualLabel = "إجمالي السدادات",
                TargetLabel = "إجمالي المطالبات",
                RemainingLabel = "العجز / الفائض",

                ShowValueUnit = false,

                Icon = "fa-solid fa-coins",
                Emoji = "💰",

                Tone = "success",
                Color = Color.RoyalBlue,
                FormulaText = "تبدأ الكفاءة من 100% وتنخفض بحسب مجموع فروقات أرصدة المستفيدين مقارنة بإجمالي مطالباتهم، بحيث لا يلغي فائض مستفيد عجز مستفيد آخر.",

                Hint =
                    "تقيس كفاءة التسوية مدى تقارب إجمالي السدادات من إجمالي المطالبات، " +
                    "ويؤثر كل من العجز والفائض على نسبة الكفاءة."
            },
            //,
            //new HousingCommandCenterMetric
            //{
            //    Key        = "m_maintenance_quality",
            //    SortOrder  = 5,
            //    Title      = "الصيانة الوقائية والجودة والخدمات والمركبات",
            //    ShortTitle = "الصيانة والجودة",
            //    Subtitle   = "يركز على فعالية الصيانة الوقائية للمباني والأسطول والمرافق، وسرعة الإحالات للجودة والخدمات العامة وإغلاقها",
            //    Target = 100, Actual = 86, Unit = "%",
            //    Icon = "fa-solid fa-tools", Emoji = "⚙️",
            //    Tone  = "success",
            //    Color = Color.Violet,      // بنفسجي ملكي
            //    Hint  = "الإدارة القوية هنا تكون أقل اعتمادًا على الصيانة الطارئة وأكثر قدرة على المحافظة على الجاهزية."
            //}
        ];

        // ═══════════════════════════════════════════════════════
        //  الإدارات — 7 ألوان مختلفة تماماً
        // ═══════════════════════════════════════════════════════
        private static List<HousingCommandCenterDepartment> BuildDepartments() =>
        [
            BuildDepartment("dep_01", 1,
                "إدارة مدينة الملك فيصل العسكرية للتشغيل والصيانة",
                "مدينة الملك فيصل",
                "fa-solid fa-city", "🏙️", "success", Color.Navy,
                [
                    DM("m_housing_readiness",  100, 90, "جاهزية السكن والأصول",
                       "إجمالي الوحدات: 1,482 | مشغولة: 1,355 | شاغرة: 67 | تحت الصيانة: 28 | إحالة جودة: 14 | إحالة خدمات عامة: 10 | جاهزة للتسكين: 8"),
                    DM("m_allocation_balance",  100, 88, "الإشغال وقوائم الانتظار",
                       "الفئات السكنية: ضباط كبار: 92، ضباط: 214، ضباط صف: 276، أفراد: 418، مدنيون: 165 | التوزيع الحي: القادسية: 224، النخيل: 205، الربوة: 198"),
                    DM("m_requests_sla",        100, 90, "الطلبات وSLA",
                       "الطلبات المفتوحة: تسكين: 84، إمهال: 42، إخلاء: 31 | الإمهال 5.7 يوم مقابل هدف 4.0، الإخلاء 4.9 مقابل 3.0"),
                    DM("m_finance_utilities",   100, 95, "الماليات والاستهلاك",
                       "الشهر الماضي 412,000 ر.س | المحصّل: 3,941,000 ر.س | غير المحصّل: 597,000 ر.س | كفاءة الكهرباء 78%، الماء 64%"),
                    DM("m_maintenance_quality", 100, 88, "الصيانة والجودة",
                       "المنجزة: 221 من 260 عمل | جاهزية الأسطول: 86% | إحالات جودة 14 | السلامة 87%، الغاز 91%")
                ]),

            BuildDepartment("dep_02", 2,
                "إدارة مدينة الملك عبدالعزيز العسكرية للتشغيل والصيانة",
                "مدينة الملك عبدالعزيز",
                "fa-solid fa-fort-awesome", "🏙️", "success", Color.SteelBlue,
                [
                    DM("m_housing_readiness",  100, 87, "جاهزية السكن والأصول",
                       "إجمالي الوحدات: 1,320 | مشغولة: 1,188 | شاغرة: 74 | تحت الصيانة: 31 | جاهزة للتسكين: 7"),
                    DM("m_allocation_balance",  100, 82, "الإشغال وقوائم الانتظار",
                       "أفراد 362، ضباط صف 244، ضباط 186، مدنيون 141 | انتظار: أفراد 63، ضباط صف 47"),
                    DM("m_requests_sla",        100, 76, "الطلبات وSLA",
                       "تسكين 71، إمهال 36، إخلاء 28 | الإمهال 5.2 يوم مقابل هدف 4.0، الإخلاء 4.5 مقابل 3.0"),
                    DM("m_finance_utilities",   100, 83, "الماليات والاستهلاك",
                       "الشهر الماضي 376,000 ر.س | كفاءة التحصيل 87% | الكهرباء 76% | الماء 67%"),
                    DM("m_maintenance_quality", 100, 86, "الصيانة والجودة",
                       "198 من 236 عمل | جاهزية الأسطول: 84% | إحالات جودة 11")
                ]),

            BuildDepartment("dep_03", 3,
                "إدارة التشغيل والصيانة للمنشآت العسكرية بالرياض",
                "منشآت الرياض",
                "fa-solid fa-building", "🏙️", "success", Color.Green,
                [
                    DM("m_housing_readiness",  100, 88, "جاهزية السكن والأصول",
                       "إجمالي الوحدات: 1,268 | مشغولة: 1,142 | شاغرة: 63 | تحت الصيانة: 29 | جاهزة للتسكين: 8"),
                    DM("m_allocation_balance",  100, 83, "الإشغال وقوائم الانتظار",
                       "أفراد 341، ضباط صف 228، ضباط 179 | انتظار: أفراد 49، ضباط صف 35"),
                    DM("m_requests_sla",        100, 77, "الطلبات وSLA",
                       "تسكين 62، إمهال 28، إخلاء 22 | الإمهال 5.1 يوم، الإخلاء 4.2، التسكين 3.4"),
                    DM("m_finance_utilities",   100, 85, "الماليات والاستهلاك",
                       "الشهر الماضي 335,000 ر.س | الكهرباء 74% | الماء 61%"),
                    DM("m_maintenance_quality", 100, 89, "الصيانة والجودة",
                       "186 من 209 أعمال | جاهزية الأسطول: 88% | مستوى الجودة والسلامة مرتفع")
                ]),

            BuildDepartment("dep_04", 4,
                "إدارة التشغيل والصيانة للمنشآت العسكرية بجازان",
                "منشآت جازان",
                "fa-solid fa-water", "🏙️", "info", Color.Cyan,
                [
                    DM("m_housing_readiness",  100, 78, "جاهزية السكن والأصول",
                       "إجمالي الوحدات: 910 | مشغولة: 788 | شاغرة: 61 | تحت الصيانة: 36 | جاهزة للتسكين: 5"),
                    DM("m_allocation_balance",  100, 75, "الإشغال وقوائم الانتظار",
                       "أفراد 286، ضباط صف 174، ضباط 122 | ضغط الانتظار مرتفع في الأفراد 58"),
                    DM("m_requests_sla",        100, 70, "الطلبات وSLA",
                       "تسكين 55، إمهال 31، إخلاء 26 | الإمهال 6.0 يوم، الإخلاء 5.1، التسكين 4.0"),
                    DM("m_finance_utilities",   100, 79, "الماليات والاستهلاك",
                       "الشهر الماضي 248,000 ر.س | الكهرباء 81% | الماء 72%"),
                    DM("m_maintenance_quality", 100, 81, "الصيانة والجودة",
                       "143 من 189 عمل | جاهزية الأسطول: 79% | إحالات جودة 12")
                ]),

            BuildDepartment("dep_05", 5,
                "إدارة مدينة الملك خالد العسكرية للتشغيل والصيانة",
                "مدينة الملك خالد",
                "fa-solid fa-shield-halved", "🏙️", "success", Color.Purple,
                [
                    DM("m_housing_readiness",  100, 86, "جاهزية السكن والأصول",
                       "إجمالي الوحدات: 1,186 | مشغولة: 1,068 | شاغرة: 58 | تحت الصيانة: 27 | جاهزة للتسكين: 9"),
                    DM("m_allocation_balance",  100, 78, "الإشغال وقوائم الانتظار",
                       "ضغط الانتظار في الأفراد وضباط الصف | الأفراد انتظار/ساكنين: 52/311"),
                    DM("m_requests_sla",        100, 73, "الطلبات وSLA",
                       "تسكين 59، إمهال 30، إخلاء 24 | الإمهال 5.6 يوم، الإخلاء 4.7، التسكين 3.7"),
                    DM("m_finance_utilities",   100, 80, "الماليات والاستهلاك",
                       "الشهر الماضي 301,000 ر.س | الكهرباء 79% | الماء 66%"),
                    DM("m_maintenance_quality", 100, 90, "الصيانة والجودة",
                       "177 من 197 عمل | جاهزية الأسطول: 89% | مستوى الجودة والسلامة قوي")
                ]),

            BuildDepartment("dep_06", 6,
                "إدارة التشغيل والصيانة للمنشآت العسكرية بالقصيم",
                "منشآت القصيم",
                "fa-solid fa-solar-panel", "🏙️", "info", Color.Orange,
                [
                    DM("m_housing_readiness",  100, 81, "جاهزية السكن والأصول",
                       "إجمالي الوحدات: 874 | مشغولة: 756 | شاغرة: 51 | تحت الصيانة: 34 | جاهزة للتسكين: 4"),
                    DM("m_allocation_balance",  100, 76, "الإشغال وقوائم الانتظار",
                       "الطلب الأعلى في الأفراد يليهم ضباط الصف | ضغط الانتظار فوق المخزون الجاهز"),
                    DM("m_requests_sla",        100, 71, "الطلبات وSLA",
                       "تسكين 47، إمهال 25، إخلاء 19 | الإمهال 5.8 يوم، الإخلاء 4.9، التسكين 3.9"),
                    DM("m_finance_utilities",   100, 81, "الماليات والاستهلاك",
                       "الشهر الماضي 214,000 ر.س | الكهرباء 73% | الماء 59%"),
                    DM("m_maintenance_quality", 100, 84, "الصيانة والجودة",
                       "129 من 154 عمل | جاهزية الأسطول: 81% | فرصة تحسين في برامج الوقائية")
                ]),

            BuildDepartment("dep_07", 7,
                "إدارة التشغيل وصيانة المنشآت العسكرية بالطائف",
                "منشآت الطائف",
                "fa-solid fa-mountain-city", "🏙️", "info", Color.Slate,
                [
                    DM("m_housing_readiness",  100, 83, "جاهزية السكن والأصول",
                       "إجمالي الوحدات: 932 | مشغولة: 817 | شاغرة: 53 | تحت الصيانة: 30 | جاهزة للتسكين: 6"),
                    DM("m_allocation_balance",  100, 79, "الإشغال وقوائم الانتظار",
                       "الأفراد وضباط الصف المجموعتان الرئيسيتان في الضغط"),
                    DM("m_requests_sla",        100, 72, "الطلبات وSLA",
                       "تسكين 49، إمهال 27، إخلاء 21 | الإمهال 5.5 يوم، الإخلاء 4.6، التسكين 3.6"),
                    DM("m_finance_utilities",   100, 80, "الماليات والاستهلاك",
                       "الشهر الماضي 226,000 ر.س | الكهرباء 75% | الماء 62%"),
                    DM("m_maintenance_quality", 100, 87, "الصيانة والجودة",
                       "141 من 162 عمل | جاهزية الأسطول: 85% | مستوى الجودة جيد")
                ])
        ];

        // ═══════════════════════════════════════════════════════
        //  Helpers
        // ═══════════════════════════════════════════════════════
        private static HousingCommandCenterDepartment BuildDepartment(
            string key, int sortOrder, string name, string shortName,
            string icon, string emoji, string tone, string color,
            List<HousingCommandCenterDepartmentMetric> items)
        {
            var overall = items.Any()
                ? items.Average(x => x.Target > 0
                    ? Math.Round((x.Actual ?? 0m) / x.Target.Value * 100m, 1) : 0m)
                : 0m;

            return new HousingCommandCenterDepartment
            {
                Key = key,
                SortOrder = sortOrder,
                Name = name,
                ShortName = shortName,
                Icon = icon,
                Emoji = emoji,
                Tone = tone,
                Color = color,
                Href = $"/HousingCommandCenterDashboard/Department?id={key}",
                OverallCompletionPercent = Math.Round(overall, 1),
                Metrics = items
            };
        }

        private static HousingCommandCenterDepartmentMetric DM(
            string metricKey, decimal target, decimal actual,
            string noteTitle, string detail) =>
            new HousingCommandCenterDepartmentMetric
            {
                MetricKey = metricKey,
                Target = target,
                Actual = actual,
                CompletionPercent = null,
                DisplayText = null,
                Note = $"{noteTitle} | {detail}"
            };

        private static HousingCommandCenterSummaryRow BuildSummaryRow(
            List<HousingCommandCenterMetric> metrics,
            List<HousingCommandCenterDepartment> departments)
        {
            var summary = new HousingCommandCenterSummaryRow { Label = "إجمالي جميع الإدارات" };

            foreach (var metric in metrics.OrderBy(x => x.SortOrder))
            {
                var related = departments.SelectMany(d => d.Metrics).Where(m => m.MetricKey == metric.Key).ToList();
                var target = related.Sum(x => x.Target ?? 0m);
                var actual = related.Sum(x => x.Actual ?? 0m);
                var remaining = Math.Max(target - actual, 0m);

                summary.Metrics.Add(new HousingCommandCenterDepartmentMetric
                {
                    MetricKey = metric.Key,
                    Target = target,
                    Actual = actual,
                    CompletionPercent = null,
                    DisplayText = null,
                    Tone = metric.Tone,
                    Color = metric.Color,
                    Note = $"إجمالي المستهدف: {target.ToString("0", CultureInfo.InvariantCulture)} | إجمالي المنجز: {actual.ToString("0", CultureInfo.InvariantCulture)} | المتبقي: {remaining.ToString("0", CultureInfo.InvariantCulture)}"
                });
            }
            return summary;
        }






        private static DepHousingDetail? BuildHousingDetailFromDatabase(
    DataTable? occupancyTable,
    string idaraID)
        {
            if (occupancyTable == null ||
                occupancyTable.Rows.Count == 0 ||
                string.IsNullOrWhiteSpace(idaraID))
            {
                return null;
            }

            var row =
                occupancyTable
                    .AsEnumerable()
                    .FirstOrDefault(r =>
                        Convert.ToString(
                            r["idaraID"],
                            CultureInfo.InvariantCulture)
                        == idaraID);

            if (row == null)
                return null;

            int totalUnits =
                row["TotalHousingUnits"] == DBNull.Value
                    ? 0
                    : Convert.ToInt32(
                        row["TotalHousingUnits"],
                        CultureInfo.InvariantCulture);

            int occupied =
                row["OccupiedHousingUnits"] == DBNull.Value
                    ? 0
                    : Convert.ToInt32(
                        row["OccupiedHousingUnits"],
                        CultureInfo.InvariantCulture);

            int vacant =
                row["UnoccupiedHousingUnits"] == DBNull.Value
                    ? 0
                    : Convert.ToInt32(
                        row["UnoccupiedHousingUnits"],
                        CultureInfo.InvariantCulture);

            return new DepHousingDetail
            {
                TotalUnits = totalUnits,
                Occupied = occupied,
                Vacant = vacant,

                AreaDistribution = new(),
                RoomDistribution = new()
            };
        }




        private static List<DepOccupancyLocationDetail>
    BuildOccupancyLocationsFromDatabase(
        DataTable? occupancyLocationTable,
        string idaraID)
        {
            var result = new List<DepOccupancyLocationDetail>();

            if (occupancyLocationTable == null ||
                occupancyLocationTable.Rows.Count == 0 ||
                string.IsNullOrWhiteSpace(idaraID))
            {
                return result;
            }

            foreach (DataRow row in occupancyLocationTable.Rows)
            {
                var rowIdaraID =
                    Convert.ToString(
                        row["idaraID"],
                        CultureInfo.InvariantCulture);

                if (rowIdaraID != idaraID)
                    continue;

                result.Add(
                    new DepOccupancyLocationDetail
                    {
                        MilitaryLocationID =
                            row["militaryLocationID_FK"] == DBNull.Value
                                ? 0
                                : Convert.ToInt32(
                                    row["militaryLocationID_FK"],
                                    CultureInfo.InvariantCulture),

                        MilitaryLocationName =
                            row["militaryLocationName_A"] == DBNull.Value
                                ? "غير محدد"
                                : row["militaryLocationName_A"]
                                    ?.ToString()
                                    ?.Trim()
                                    ?? "غير محدد",

                        TotalHousingUnits =
                            row["TotalHousingUnits"] == DBNull.Value
                                ? 0
                                : Convert.ToInt32(
                                    row["TotalHousingUnits"],
                                    CultureInfo.InvariantCulture),

                        OccupiedHousingUnits =
                            row["OccupiedHousingUnits"] == DBNull.Value
                                ? 0
                                : Convert.ToInt32(
                                    row["OccupiedHousingUnits"],
                                    CultureInfo.InvariantCulture),

                        UnoccupiedHousingUnits =
                            row["UnoccupiedHousingUnits"] == DBNull.Value
                                ? 0
                                : Convert.ToInt32(
                                    row["UnoccupiedHousingUnits"],
                                    CultureInfo.InvariantCulture),

                        OccupancyPercent =
                            row["OccupancyPercent"] == DBNull.Value
                                ? 0m
                                : Convert.ToDecimal(
                                    row["OccupancyPercent"],
                                    CultureInfo.InvariantCulture)
                    });
            }

            return result
                .OrderBy(x => x.MilitaryLocationName)
                .ToList();
        }



        private static DepHousingReadinessDetail?
    BuildHousingReadinessFromDatabase(
        DataTable? readinessTable,
        string idaraID)
        {
            if (readinessTable == null ||
                readinessTable.Rows.Count == 0 ||
                string.IsNullOrWhiteSpace(idaraID))
            {
                return null;
            }

            var rows = readinessTable
                .AsEnumerable()
                .Where(r =>
                    Convert.ToString(
                        r["idaraID"],
                        CultureInfo.InvariantCulture) == idaraID)
                .ToList();

            if (rows.Count == 0)
                return null;

            var totalHousingUnits =
                rows[0]["TotalHousingUnits"] == DBNull.Value
                    ? 0
                    : Convert.ToInt32(
                        rows[0]["TotalHousingUnits"],
                        CultureInfo.InvariantCulture);

            var groups = rows
                .GroupBy(r => new
                {
                    Key =
                        r["ReadinessGroupKey"] == DBNull.Value
                            ? ""
                            : r["ReadinessGroupKey"]
                                ?.ToString()
                                ?.Trim() ?? "",

                    Name =
                        r["ReadinessGroupName"] == DBNull.Value
                            ? ""
                            : r["ReadinessGroupName"]
                                ?.ToString()
                                ?.Trim() ?? "",

                    Order =
                        r["ReadinessGroupOrder"] == DBNull.Value
                            ? 99
                            : Convert.ToInt32(
                                r["ReadinessGroupOrder"],
                                CultureInfo.InvariantCulture)
                })
                .Select(g =>
                {
                    var actions = g
                        .Select(r =>
                            new DepHousingReadinessAction
                            {
                                ActionTypeID =
                                    r["buildingActionTypeID_FK"] == DBNull.Value
                                        ? null
                                        : Convert.ToInt32(
                                            r["buildingActionTypeID_FK"],
                                            CultureInfo.InvariantCulture),

                                ActionTypeName =
                                    r["ActionTypeName"] == DBNull.Value
                                        ? "لا يوجد إجراء نشط"
                                        : r["ActionTypeName"]
                                            ?.ToString()
                                            ?.Trim()
                                            ?? "لا يوجد إجراء نشط",

                                BuildingStatus =
                                    r["BuildingStatus"] == DBNull.Value
                                        ? ""
                                        : r["BuildingStatus"]
                                            ?.ToString()
                                            ?.Trim() ?? "",

                                BuildingActionRoot =
                                    r["buildingActionRoot"] == DBNull.Value
                                        ? null
                                        : Convert.ToInt32(
                                            r["buildingActionRoot"],
                                            CultureInfo.InvariantCulture),

                                HousingUnitsCount =
                                    r["HousingUnitsCount"] == DBNull.Value
                                        ? 0
                                        : Convert.ToInt32(
                                            r["HousingUnitsCount"],
                                            CultureInfo.InvariantCulture)
                            })
                        .OrderByDescending(x => x.HousingUnitsCount)
                        .ThenBy(x => x.ActionTypeName)
                        .ToList();

                    var groupCount =
                        actions.Sum(x => x.HousingUnitsCount);

                    var percent =
                        totalHousingUnits > 0
                            ? Math.Round(
                                groupCount * 100m /
                                totalHousingUnits,
                                1)
                            : 0m;

                    return new DepHousingReadinessGroup
                    {
                        Key = g.Key.Key,
                        Name = g.Key.Name,
                        Order = g.Key.Order,
                        HousingUnitsCount = groupCount,
                        Percent = percent,
                        Actions = actions
                    };
                })
                .OrderBy(x => x.Order)
                .ToList();

            return new DepHousingReadinessDetail
            {
                TotalHousingUnits = totalHousingUnits,
                Groups = groups
            };
        }




        private static DepHousingProceduresDetail?
    BuildHousingProceduresFromDatabase(
        DataTable? summaryTable,
        DataTable? stagesTable,
        DataTable? oldestTable,
        DataTable? performanceTable,
        string idaraID)
        {
            if (summaryTable == null ||
                summaryTable.Rows.Count == 0 ||
                string.IsNullOrWhiteSpace(idaraID))
            {
                return null;
            }

            //----------------------------------------------------------
            // Summary - dt7
            //----------------------------------------------------------
            var summaryRow =
                summaryTable
                    .AsEnumerable()
                    .FirstOrDefault(r =>
                        Convert.ToString(
                            r["idaraID"],
                            CultureInfo.InvariantCulture)
                        == idaraID);

            if (summaryRow == null)
                return null;

            var result =
                new DepHousingProceduresDetail
                {
                    TotalCurrentProcedures =
                        DbInt(
                            summaryRow,
                            "TotalCurrentProcedures")
                        ?? 0,

                    AllocationCurrent =
                        DbInt(
                            summaryRow,
                            "AllocationCurrent")
                        ?? 0,

                    ExtendCurrent =
                        DbInt(
                            summaryRow,
                            "ExtendCurrent")
                        ?? 0,

                    ExitCurrent =
                        DbInt(
                            summaryRow,
                            "ExitCurrent")
                        ?? 0
                };


            //----------------------------------------------------------
            // Stages - dt8
            //----------------------------------------------------------
            if (stagesTable != null)
            {
                foreach (DataRow row in stagesTable.Rows)
                {
                    var rowIdaraID =
                        DbString(
                            row,
                            "idaraID");

                    if (rowIdaraID != idaraID)
                        continue;

                    result.Stages.Add(
                        new DepHousingProcedureStage
                        {
                            ProcedureGroupKey =
                                DbString(
                                    row,
                                    "ProcedureGroupKey"),

                            ProcedureGroupName =
                                DbString(
                                    row,
                                    "ProcedureGroupName"),

                            ActionTypeID =
                                DbInt(
                                    row,
                                    "ActionTypeID")
                                ?? 0,

                            ActionTypeName =
                                DbString(
                                    row,
                                    "ActionTypeName"),

                            CurrentCases =
                                DbInt(
                                    row,
                                    "CurrentCases")
                                ?? 0,

                            OldestCurrentStatusDate =
                                DbDate(
                                    row,
                                    "OldestCurrentStatusDate"),

                            OldestCurrentStatusDays =
                                DbInt(
                                    row,
                                    "OldestCurrentStatusDays")
                        });
                }
            }


            //----------------------------------------------------------
            // Oldest current procedures - dt9
            //----------------------------------------------------------
            if (oldestTable != null)
            {
                foreach (DataRow row in oldestTable.Rows)
                {
                    var rowIdaraID =
                        DbString(
                            row,
                            "idaraID");

                    if (rowIdaraID != idaraID)
                        continue;

                    result.OldestCurrent.Add(
                        new DepHousingProcedureRow
                        {
                            RowNo =
                                DbInt(
                                    row,
                                    "RowNo")
                                ?? 0,

                            ProcedureGroupKey =
                                DbString(
                                    row,
                                    "ProcedureGroupKey"),

                            ProcedureGroupName =
                                DbString(
                                    row,
                                    "ProcedureGroupName"),

                            BuildingDetailsID =
                                DbLong(
                                    row,
                                    "buildingDetailsID")
                                ?? 0,

                            BuildingDetailsNo =
                                DbString(
                                    row,
                                    "buildingDetailsNo"),

                            GeneralNo =
                                DbLong(
                                    row,
                                    "generalNo_FK"),

                            BuildingActionID =
                                DbLong(
                                    row,
                                    "buildingActionID")
                                ?? 0,

                            BuildingActionParentID =
                                DbLong(
                                    row,
                                    "buildingActionParentID"),

                            ActionTypeID =
                                DbInt(
                                    row,
                                    "ActionTypeID")
                                ?? 0,

                            ActionTypeName =
                                DbString(
                                    row,
                                    "ActionTypeName"),

                            CurrentStatusSince =
                                DbDate(
                                    row,
                                    "CurrentStatusSince"),

                            CurrentStatusDateSource =
                                DbString(
                                    row,
                                    "CurrentStatusDateSource"),

                            DaysInCurrentStatus =
                                DbInt(
                                    row,
                                    "DaysInCurrentStatus"),

                            IsMoveDataGenerated =
                                (
                                    DbInt(
                                        row,
                                        "IsMoveDataGenerated")
                                    ?? 0
                                ) == 1
                        });
                }
            }



            //----------------------------------------------------------
            // Workflow performance - dt10
            //----------------------------------------------------------
            if (performanceTable != null)
            {
                foreach (DataRow row in performanceTable.Rows)
                {
                    var rowIdaraID =
                        DbString(
                            row,
                            "idaraID");

                    if (rowIdaraID != idaraID)
                        continue;

                    result.Performance.Add(
                        new DepHousingWorkflowPerformance
                        {
                            WorkflowKey =
                                DbString(
                                    row,
                                    "WorkflowKey"),

                            WorkflowName =
                                DbString(
                                    row,
                                    "WorkflowName"),

                            CompletedCount =
                                DbInt(
                                    row,
                                    "CompletedCount")
                                ?? 0,

                            AverageDays =
                                DbDecimal(
                                    row,
                                    "AverageDays"),

                            MedianDays =
                                DbDecimal(
                                    row,
                                    "MedianDays"),

                            MinimumDays =
                                DbDecimal(
                                    row,
                                    "MinimumDays"),

                            MaximumDays =
                                DbDecimal(
                                    row,
                                    "MaximumDays"),

                            LastCompletedDate =
                                DbDate(
                                    row,
                                    "LastCompletedDate")
                        });
                }
            }


            //----------------------------------------------------------
            // Stable ordering
            //----------------------------------------------------------
            result.Stages =
                result.Stages
                    .OrderBy(x =>
                        x.ProcedureGroupKey switch
                        {
                            "ALLOCATION" => 1,
                            "EXTEND" => 2,
                            "EXIT" => 3,
                            _ => 9
                        })
                    .ThenByDescending(
                        x => x.CurrentCases)
                    .ThenBy(
                        x => x.ActionTypeID)
                    .ToList();


            result.OldestCurrent =
                result.OldestCurrent
                    .OrderBy(
                        x => x.RowNo)
                    .ToList();


            result.Performance =
    result.Performance
        .OrderBy(x =>
            x.WorkflowKey switch
            {
                "ALLOCATION" => 1,
                "EXTEND" => 2,
                "EXIT" => 3,
                _ => 9
            })
        .ToList();


            return result;
        }


        private static DepFinanceDetail?
 BuildFinanceDetailFromDatabase(
     DataTable? financialTable,
     DataTable? financialClaimsByTypeTable,
     string idaraID)
        {
            if (financialTable == null ||
                financialTable.Rows.Count == 0 ||
                string.IsNullOrWhiteSpace(idaraID))
            {
                return null;
            }


            //----------------------------------------------------------
            // بيانات الكفاءة المالية الإجمالية للإدارة
            //----------------------------------------------------------
            var row =
                financialTable
                    .AsEnumerable()
                    .FirstOrDefault(r =>
                        Convert.ToString(
                            r["idaraID"],
                            CultureInfo.InvariantCulture)
                        == idaraID);


            if (row == null)
                return null;


            //----------------------------------------------------------
            // التحليل المالي حسب نوع الرسوم
            //----------------------------------------------------------
            var claimsByType =
                new List<DepFinanceClaimType>();


            if (financialClaimsByTypeTable != null)
            {
                foreach (
                    DataRow claimRow
                    in financialClaimsByTypeTable.Rows)
                {
                    var rowIdaraID =
                        Convert.ToString(
                            claimRow["idaraID"],
                            CultureInfo.InvariantCulture);


                    if (rowIdaraID != idaraID)
                        continue;


                    var billChargeTypeName =
                        claimRow["BillChargeTypeName"] == DBNull.Value
                            ? "غير محدد"
                            : Convert.ToString(
                                claimRow["BillChargeTypeName"],
                                CultureInfo.InvariantCulture);


                    if (string.IsNullOrWhiteSpace(
                            billChargeTypeName))
                    {
                        billChargeTypeName =
                            "غير محدد";
                    }


                    claimsByType.Add(
                        new DepFinanceClaimType
                        {
                            BillChargeTypeID =
                                claimRow["BillChargeTypeID"] ==
                                DBNull.Value
                                    ? (int?)null
                                    : Convert.ToInt32(
                                        claimRow[
                                            "BillChargeTypeID"
                                        ],
                                        CultureInfo
                                            .InvariantCulture),

                            BillChargeTypeName =
                                billChargeTypeName,

                            FinancialBeneficiariesCount =
                                claimRow[
                                    "FinancialBeneficiariesCount"
                                ] == DBNull.Value
                                    ? 0L
                                    : Convert.ToInt64(
                                        claimRow[
                                            "FinancialBeneficiariesCount"
                                        ],
                                        CultureInfo
                                            .InvariantCulture),

                            BillsCount =
                                claimRow["BillsCount"] ==
                                DBNull.Value
                                    ? 0L
                                    : Convert.ToInt64(
                                        claimRow[
                                            "BillsCount"
                                        ],
                                        CultureInfo
                                            .InvariantCulture),

                            BeneficiariesCount =
                                claimRow[
                                    "BeneficiariesCount"
                                ] == DBNull.Value
                                    ? 0L
                                    : Convert.ToInt64(
                                        claimRow[
                                            "BeneficiariesCount"
                                        ],
                                        CultureInfo
                                            .InvariantCulture),

                            TotalClaims =
                                claimRow["TotalClaims"] ==
                                DBNull.Value
                                    ? 0m
                                    : Convert.ToDecimal(
                                        claimRow[
                                            "TotalClaims"
                                        ],
                                        CultureInfo
                                            .InvariantCulture),

                            TotalPayments =
                                claimRow["TotalPayments"] ==
                                DBNull.Value
                                    ? 0m
                                    : Convert.ToDecimal(
                                        claimRow[
                                            "TotalPayments"
                                        ],
                                        CultureInfo
                                            .InvariantCulture),

                            DeficitByType =
                                claimRow["DeficitByType"] ==
                                DBNull.Value
                                    ? 0m
                                    : Convert.ToDecimal(
                                        claimRow[
                                            "DeficitByType"
                                        ],
                                        CultureInfo
                                            .InvariantCulture),

                            SurplusByType =
                                claimRow["SurplusByType"] ==
                                DBNull.Value
                                    ? 0m
                                    : Convert.ToDecimal(
                                        claimRow[
                                            "SurplusByType"
                                        ],
                                        CultureInfo
                                            .InvariantCulture),

                            NetByType =
                                claimRow["NetByType"] ==
                                DBNull.Value
                                    ? 0m
                                    : Convert.ToDecimal(
                                        claimRow[
                                            "NetByType"
                                        ],
                                        CultureInfo
                                            .InvariantCulture),

                            ClaimsPercent =
                                claimRow["ClaimsPercent"] ==
                                DBNull.Value
                                    ? 0m
                                    : Convert.ToDecimal(
                                        claimRow[
                                            "ClaimsPercent"
                                        ],
                                        CultureInfo
                                            .InvariantCulture)
                        });
                }
            }


            //----------------------------------------------------------
            // ViewModel النهائي
            //----------------------------------------------------------
            return new DepFinanceDetail
            {
                FinancialBeneficiariesCount =
                    DbInt(
                        row,
                        "FinancialBeneficiariesCount")
                    ?? 0,

                BalancedBeneficiariesCount =
                    DbInt(
                        row,
                        "BalancedBeneficiariesCount")
                    ?? 0,

                DeficitBeneficiariesCount =
                    DbInt(
                        row,
                        "DeficitBeneficiariesCount")
                    ?? 0,

                SurplusBeneficiariesCount =
                    DbInt(
                        row,
                        "SurplusBeneficiariesCount")
                    ?? 0,


                TotalClaims =
                    DbDecimal(
                        row,
                        "TotalClaims")
                    ?? 0m,

                TotalPayments =
                    DbDecimal(
                        row,
                        "TotalPayments")
                    ?? 0m,

                AmountToCollect =
                    DbDecimal(
                        row,
                        "AmountToCollect")
                    ?? 0m,

                AmountToRefund =
                    DbDecimal(
                        row,
                        "AmountToRefund")
                    ?? 0m,

                TotalFinancialGap =
                    DbDecimal(
                        row,
                        "TotalFinancialGap")
                    ?? 0m,

                NetFinancialPosition =
                    DbDecimal(
                        row,
                        "NetFinancialPosition")
                    ?? 0m,


                BalancedBeneficiariesPercent =
                    DbDecimal(
                        row,
                        "BalancedBeneficiariesPercent"),

                FinancialEfficiencyPercent =
                    DbDecimal(
                        row,
                        "FinancialEfficiencyPercent"),


                ClaimsByType =
                    claimsByType
                        .OrderByDescending(
                            x => x.TotalClaims)
                        .ToList()
            };
        }


        private static List<DepBuildingDetailRow>
            BuildBuildingDetailsRows(
                DataTable? table)
        {
            var result =
                new List<DepBuildingDetailRow>();

            if (table == null ||
                table.Rows.Count == 0)
            {
                return result;
            }

            foreach (DataRow row in table.Rows)
            {
                result.Add(
                    new DepBuildingDetailRow
                    {
                        BuildingDetailsID =
                            DbLong(row, "buildingDetailsID") ?? 0,

                        BuildingDetailsNo =
                            DbString(row, "buildingDetailsNo"),

                        MilitaryLocationName =
                            DbString(
                                row,
                                "militaryLocationName_A"),

                        BuildingTypeName =
                            DbString(
                                row,
                                "buildingTypeName_A"),

                        BuildingUtilityTypeName =
                            DbString(
                                row,
                                "buildingUtilityTypeName_A"),

                        BuildingClassName =
                            DbString(
                                row,
                                "buildingClassName_A"),

                        BuildingDetailsRooms =
                            DbInt(
                                row,
                                "buildingDetailsRooms"),

                        BuildingLevelsCount =
                            DbInt(
                                row,
                                "buildingLevelsCount"),

                        BuildingDetailsArea =
                            DbDecimal(
                                row,
                                "buildingDetailsArea"),

                        ReadinessGroupKey =
                            DbString(
                                row,
                                "ReadinessGroupKey"),

                        ReadinessGroupName =
                            DbString(
                                row,
                                "ReadinessGroupName"),

                        BuildingActionID =
                            DbLong(
                                row,
                                "buildingActionID"),

                        BuildingActionTypeID =
                            DbInt(
                                row,
                                "buildingActionTypeID_FK"),

                        CurrentActionName =
                            DbString(
                                row,
                                "CurrentActionName"),

                        CurrentBuildingStatus =
                            DbString(
                                row,
                                "CurrentBuildingStatus"),

                        CurrentStatusSince =
                            DbDate(
                                row,
                                "CurrentStatusSince"),

                        DaysInCurrentStatus =
                            DbInt(
                                row,
                                "DaysInCurrentStatus"),

                        CurrentActionDate =
                            DbDate(
                                row,
                                "CurrentActionDate"),

                        DecisionDate =
                            DbDate(
                                row,
                                "DecisionDate"),

                        ActionEntryDate =
                            DbDate(
                                row,
                                "ActionEntryDate"),

                        CurrentStatusDateSource =
                            DbString(
                                row,
                                "CurrentStatusDateSource"),

                        GeneralNo =
                            DbString(
                                row,
                                "generalNo_FK"),

                        ResidentRankName =
                            DbString(
                                row,
                                "ResidentRankName"),

                        ResidentFullName =
                            DbString(
                                row,
                                "ResidentFullName"),

                        ResidentMilitaryUnit =
                            DbString(
                                row,
                                "ResidentMilitaryUnit"),

                        OccupiedSince =
                            DbDate(
                                row,
                                "OccupiedSince"),

                        DaysOccupied =
                            DbInt(
                                row,
                                "DaysOccupied"),

                        VacantSince =
                            DbDate(
                                row,
                                "VacantSince"),

                        LastExitActionDate =
                            DbDate(
                                row,
                                "LastExitActionDate"),

                        DaysVacant =
                            DbInt(
                                row,
                                "DaysVacant"),

                        LastResidentGeneralNo =
                            DbString(
                                row,
                                "LastResidentGeneralNo"),

                        LastResidentRankName =
                            DbString(
                                row,
                                "LastResidentRankName"),

                        LastResidentFullName =
                            DbString(
                                row,
                                "LastResidentFullName"),

                        LastResidentMilitaryUnit =
                            DbString(
                                row,
                                "LastResidentMilitaryUnit")
                    });
            }

            return result;
        }


        private static List<DepProcedureDetailRow>
    BuildProcedureDetailsRows(
        DataTable? table)
        {
            var result =
                new List<DepProcedureDetailRow>();

            if (table == null ||
                table.Rows.Count == 0)
            {
                return result;
            }


            foreach (DataRow row in table.Rows)
            {
                result.Add(
                    new DepProcedureDetailRow
                    {
                        RowNo =
                            DbInt(
                                row,
                                "RowNo")
                            ?? 0,


                        //--------------------------------------------------
                        // Procedure
                        //--------------------------------------------------

                        ProcedureGroupKey =
                            DbString(
                                row,
                                "ProcedureGroupKey"),

                        ProcedureGroupName =
                            DbString(
                                row,
                                "ProcedureGroupName"),


                        //--------------------------------------------------
                        // Beneficiary
                        //--------------------------------------------------

                        ResidentInfoID =
                            DbLong(
                                row,
                                "residentInfoID_FK"),

                        GeneralNo =
                            DbString(
                                row,
                                "generalNo_FK"),

                        ResidentRankName =
                            DbString(
                                row,
                                "ResidentRankName"),

                        ResidentFullName =
                            DbString(
                                row,
                                "ResidentFullName"),

                        ResidentMilitaryUnit =
                            DbString(
                                row,
                                "ResidentMilitaryUnit"),


                        //--------------------------------------------------
                        // Building
                        //--------------------------------------------------

                        BuildingDetailsID =
                            DbLong(
                                row,
                                "buildingDetailsID")
                            ?? 0,

                        BuildingDetailsNo =
                            DbString(
                                row,
                                "buildingDetailsNo"),


                        //--------------------------------------------------
                        // Procedure Start
                        //--------------------------------------------------

                        StartActionID =
                            DbLong(
                                row,
                                "StartActionID"),

                        StartActionTypeID =
                            DbInt(
                                row,
                                "StartActionTypeID"),

                        StartActionTypeName =
                            DbString(
                                row,
                                "StartActionTypeName"),

                        ProcedureStartDate =
                            DbDate(
                                row,
                                "ProcedureStartDate"),

                        ProcedureStartSource =
                            DbString(
                                row,
                                "ProcedureStartSource"),

                        ProcedureElapsedSeconds =
                            DbLong(
                                row,
                                "ProcedureElapsedSeconds"),

                        ProcedureElapsedDays =
                            DbDecimal(
                                row,
                                "ProcedureElapsedDays"),


                        //--------------------------------------------------
                        // Current Action
                        //--------------------------------------------------

                        CurrentActionID =
                            DbLong(
                                row,
                                "CurrentActionID")
                            ?? 0,

                        CurrentActionParentID =
                            DbLong(
                                row,
                                "CurrentActionParentID"),

                        CurrentActionTypeID =
                            DbInt(
                                row,
                                "CurrentActionTypeID")
                            ?? 0,

                        CurrentActionTypeName =
                            DbString(
                                row,
                                "CurrentActionTypeName"),

                        CurrentActionSourceType =
                            DbString(
                                row,
                                "CurrentActionSourceType"),

                        IsMoveDataGenerated =
                            (
                                DbInt(
                                    row,
                                    "IsMoveDataGenerated")
                                ?? 0
                            ) == 1,


                        //--------------------------------------------------
                        // Current Status Dates
                        //--------------------------------------------------

                        CurrentEntryDate =
                            DbDate(
                                row,
                                "CurrentEntryDate"),

                        CurrentActionDate =
                            DbDate(
                                row,
                                "CurrentActionDate"),

                        CurrentStatusSince =
                            DbDate(
                                row,
                                "CurrentStatusSince"),

                        CurrentStatusDateSource =
                            DbString(
                                row,
                                "CurrentStatusDateSource"),

                        CurrentStatusElapsedSeconds =
                            DbLong(
                                row,
                                "CurrentStatusElapsedSeconds"),

                        CurrentStatusElapsedDays =
                            DbDecimal(
                                row,
                                "CurrentStatusElapsedDays"),


                        //--------------------------------------------------
                        // Business fields
                        //--------------------------------------------------

                        DecisionNo =
                            DbString(
                                row,
                                "buildingActionDecisionNo"),

                        DecisionDate =
                            DbDate(
                                row,
                                "buildingActionDecisionDate"),

                        FromDate =
                            DbDate(
                                row,
                                "buildingActionFromDate"),

                        ToDate =
                            DbDate(
                                row,
                                "buildingActionToDate"),

                        Note =
                            DbString(
                                row,
                                "buildingActionNote"),


                        //--------------------------------------------------
                        // Counters
                        //--------------------------------------------------

                        FilteredTotalCount =
                            DbInt(
                                row,
                                "FilteredTotalCount")
                            ?? 0,

                        ProcedureGroupCount =
                            DbInt(
                                row,
                                "ProcedureGroupCount")
                            ?? 0
                    });
            }


            return result;
        }


        private static List<DepFinancialDetailRow>
    BuildFinancialDetailsRows(
        DataTable? table,
        int pageNumber,
        int pageSize)
        {
            var result =
                new List<DepFinancialDetailRow>();

            if (table == null ||
                table.Rows.Count == 0)
            {
                return result;
            }


            long rowNo =
                (
                    (long)Math.Max(
                        pageNumber - 1,
                        0)
                    * pageSize
                ) + 1;


            foreach (DataRow row in table.Rows)
            {
                result.Add(
                    new DepFinancialDetailRow
                    {
                        RowNo =
                            rowNo++,

                        ResidentInfoID =
                            DbLong(
                                row,
                                "residentInfoID")
                            ?? 0,


                        //--------------------------------------------------
                        // Beneficiary
                        //--------------------------------------------------

                        GeneralNo =
                            DbString(
                                row,
                                "GeneralNo"),

                        RankName =
                            DbString(
                                row,
                                "RankName"),

                        FullName =
                            DbString(
                                row,
                                "FullName"),

                        MilitaryUnitName =
                            DbString(
                                row,
                                "MilitaryUnitName"),


                        //--------------------------------------------------
                        // Financial
                        //--------------------------------------------------

                        TotalClaims =
                            DbDecimal(
                                row,
                                "TotalClaims")
                            ?? 0m,

                        TotalPayments =
                            DbDecimal(
                                row,
                                "TotalPayments")
                            ?? 0m,

                        DeficitAmount =
                            DbDecimal(
                                row,
                                "DeficitAmount")
                            ?? 0m,

                        SurplusAmount =
                            DbDecimal(
                                row,
                                "SurplusAmount")
                            ?? 0m,

                        ClaimsCount =
                            DbLong(
                                row,
                                "ClaimsCount")
                            ??
                            DbLong(
                                row,
                                "BillsCount")
                            ?? 0,

                        PaymentsCount =
                            DbLong(
                                row,
                                "PaymentsCount")
                            ?? 0,

                        LastClaimDate =
                            DbDate(
                                row,
                                "LastClaimDate"),

                        LastPaymentDate =
                            DbDate(
                                row,
                                "LastPaymentDate"),

                        LastFinancialActivityDate =
                            DbDate(
                                row,
                                "LastFinancialActivityDate"),


                        //--------------------------------------------------
                        // Current housing status
                        //--------------------------------------------------

                        LastActionID =
                            DbLong(
                                row,
                                "LastActionID"),

                        LastActionTypeID =
                            DbInt(
                                row,
                                "LastActionTypeID"),

                        HousingStatus =
                            DbString(
                                row,
                                "HousingStatus"),

                        LastActionBuildingID =
                            DbLong(
                                row,
                                "LastActionBuildingID"),

                        LastActionBuildingNo =
                            DbString(
                                row,
                                "LastActionBuildingNo"),

                        LastActionDate =
                            DbDate(
                                row,
                                "LastActionDate")
                    });
            }


            return result;
        }


        private static List<DepFinancialChargeTypeOption>
            BuildFinancialChargeTypes(
                DataTable? table)
        {
            var result =
                new List<DepFinancialChargeTypeOption>();

            if (table == null ||
                table.Rows.Count == 0)
            {
                return result;
            }


            foreach (DataRow row in table.Rows)
            {
                var id =
                    DbInt(
                        row,
                        "BillChargeTypeID");

                if (!id.HasValue)
                    continue;


                result.Add(
                    new DepFinancialChargeTypeOption
                    {
                        BillChargeTypeID =
                            id.Value,

                        BillChargeTypeName =
                            DbString(
                                row,
                                "BillChargeTypeName_A")
                    });
            }


            return result;
        }




        private static List<DepResidentFinancialTypeSummary>
    BuildResidentFinancialTypeSummary(
        DataTable? table)
        {
            var result =
                new List<DepResidentFinancialTypeSummary>();

            if (table == null ||
                table.Rows.Count == 0)
            {
                return result;
            }


            foreach (DataRow row in table.Rows)
            {
                result.Add(
                    new DepResidentFinancialTypeSummary
                    {
                        BillChargeTypeID =
                            DbLong(
                                row,
                                "BillChargeTypeID"),

                        BillChargeTypeName =
                            DbString(
                                row,
                                "BillChargeTypeName"),

                        ClaimsCount =
                            DbLong(
                                row,
                                "ClaimsCount")
                            ?? 0,

                        PaymentsCount =
                            DbLong(
                                row,
                                "PaymentsCount")
                            ?? 0,

                        TotalClaims =
                            DbDecimal(
                                row,
                                "TotalClaims")
                            ?? 0m,

                        TotalPayments =
                            DbDecimal(
                                row,
                                "TotalPayments")
                            ?? 0m,

                        Difference =
                            DbDecimal(
                                row,
                                "Difference")
                            ?? 0m,

                        BalanceAmountByType =
                            DbDecimal(
                                row,
                                "BalanceAmountByType")
                            ?? 0m,

                        StatusByType =
                            DbString(
                                row,
                                "StatusByType")
                    });
            }


            return result;
        }


        private static List<DepResidentFinancialClaimRow>
            BuildResidentFinancialClaims(
                DataTable? table)
        {
            var result =
                new List<DepResidentFinancialClaimRow>();

            if (table == null ||
                table.Rows.Count == 0)
            {
                return result;
            }


            foreach (DataRow row in table.Rows)
            {
                result.Add(
                    new DepResidentFinancialClaimRow
                    {
                        BillsID =
                            DbLong(
                                row,
                                "BillsID")
                            ?? 0,

                        BillNumber =
                            DbString(
                                row,
                                "BillNumber"),

                        BillChargeTypeID =
                            DbLong(
                                row,
                                "BillChargeTypeID"),

                        BillChargeTypeName =
                            DbString(
                                row,
                                "BillChargeTypeName"),

                        Amount =
                            DbDecimal(
                                row,
                                "Amount")
                            ?? 0m,

                        PeriodMonth =
                            DbInt(
                                row,
                                "PeriodMonth"),

                        PeriodYear =
                            DbInt(
                                row,
                                "PeriodYear"),

                        BillsFromDate =
                            DbDate(
                                row,
                                "BillsFromDate"),

                        BillsToDate =
                            DbDate(
                                row,
                                "BillsToDate"),

                        BuildingDetailsID =
                            DbLong(
                                row,
                                "BuildingDetailsID"),

                        BuildingDetailsNo =
                            DbString(
                                row,
                                "BuildingDetailsNo"),

                        PenaltyReason =
                            DbString(
                                row,
                                "PenaltyReason"),

                        ClaimEntryDate =
                            DbDate(
                                row,
                                "ClaimEntryDate")
                    });
            }


            return result;
        }


        private static List<DepResidentFinancialPaymentRow>
            BuildResidentFinancialPayments(
                DataTable? table)
        {
            var result =
                new List<DepResidentFinancialPaymentRow>();

            if (table == null ||
                table.Rows.Count == 0)
            {
                return result;
            }


            foreach (DataRow row in table.Rows)
            {
                result.Add(
                    new DepResidentFinancialPaymentRow
                    {
                        PaymentID =
                            DbLong(
                                row,
                                "paymentID")
                            ?? 0,

                        BillChargeTypeID =
                            DbLong(
                                row,
                                "BillChargeTypeID"),

                        BillChargeTypeName =
                            DbString(
                                row,
                                "BillChargeTypeName"),

                        Amount =
                            DbDecimal(
                                row,
                                "Amount")
                            ?? 0m,

                        PaymentDate =
                            DbDate(
                                row,
                                "PaymentDate"),

                        PaymentNo =
                            DbString(
                                row,
                                "PaymentNo"),

                        DeductName =
                            DbString(
                                row,
                                "DeductName"),

                        PaymentDescription =
                            DbString(
                                row,
                                "PaymentDescription"),

                        BuildingDetailsID =
                            DbLong(
                                row,
                                "BuildingDetailsID"),

                        BuildingDetailsNo =
                            DbString(
                                row,
                                "BuildingDetailsNo"),

                        PaymentEntryDate =
                            DbDate(
                                row,
                                "PaymentEntryDate")
                    });
            }


            return result;
        }

        private static string GetFinancialDetailsTitle(
            string mode)
        {
            return mode switch
            {
                "CLAIMS" =>
                    "تفاصيل المطالبات المالية",

                "PAYMENTS" =>
                    "تفاصيل السدادات المالية",

                "DEFICIT" =>
                    "المستفيدون ذوو العجز المالي",

                "SURPLUS" =>
                    "المستفيدون ذوو الفائض المالي",

                "BALANCED" =>
                    "المستفيدون المتوازنون ماليًا",

                _ =>
                    "التفاصيل المالية"
            };
        }




        private static string GetProcedureDetailsTitle(
    string workflow)
        {
            return workflow switch
            {
                "ALL" =>
                    "جميع إجراءات الإسكان الجارية",

                "ALLOCATION" =>
                    "إجراءات التخصيص الجارية",

                "EXTEND" =>
                    "إجراءات الإمهال الجارية",

                "EXIT" =>
                    "إجراءات الإخلاء الجارية",

                _ =>
                    "تفاصيل إجراءات الإسكان"
            };
        }






        private static string GetBuildingDetailsTitle(
            string section,
            string status)
        {
            return (section, status) switch
            {
                ("occupancy", "OCCUPIED") =>
                    "الوحدات السكنية المشغولة",

                ("occupancy", "VACANT") =>
                    "الوحدات السكنية الشاغرة",

                ("readiness", "OCCUPIED") =>
                    "المساكن المسكونة حاليًا",

                ("readiness", "READY") =>
                    "المساكن الجاهزة للتسكين",

                ("readiness", "ALLOCATION") =>
                    "المساكن تحت إجراءات التخصيص",

                ("readiness", "MAINTENANCE") =>
                    "المساكن ضمن دورة الصيانة",

                ("readiness", "QUALITY") =>
                    "المساكن ضمن دورة الجودة",

                ("readiness", "GENERAL_SERVICES") =>
                    "المساكن تحت اجراءات النظافه",

                ("readiness", "HOUSING_DEPARTMENT") =>
                    "المساكن تحت إجراءات قسم الإسكان",

                ("readiness", "EXECUTION") =>
                    "المساكن ضمن دورة قسم التنفيذ",

                ("readiness", "VACANT_PENDING") =>
                    "المساكن الخالية بانتظار اتخاذ إجراء",

                ("readiness", "NO_ACTIVE_ACTION") =>
                    "المساكن بدون إجراء نشط",

                ("readiness", "OTHER") =>
                    "حالات السكن الأخرى",

                _ =>
                    "تفاصيل الوحدات السكنية"
            };
        }


        private static string DbString(
            DataRow row,
            string columnName)
        {
            if (!row.Table.Columns.Contains(columnName) ||
                row[columnName] == DBNull.Value)
            {
                return string.Empty;
            }

            return Convert.ToString(
                       row[columnName],
                       CultureInfo.InvariantCulture)
                   ?.Trim()
                   ?? string.Empty;
        }


        private static int? DbInt(
            DataRow row,
            string columnName)
        {
            if (!row.Table.Columns.Contains(columnName) ||
                row[columnName] == DBNull.Value)
            {
                return null;
            }

            return Convert.ToInt32(
                row[columnName],
                CultureInfo.InvariantCulture);
        }


        private static long? DbLong(
            DataRow row,
            string columnName)
        {
            if (!row.Table.Columns.Contains(columnName) ||
                row[columnName] == DBNull.Value)
            {
                return null;
            }

            return Convert.ToInt64(
                row[columnName],
                CultureInfo.InvariantCulture);
        }


        private static decimal? DbDecimal(
            DataRow row,
            string columnName)
        {
            if (!row.Table.Columns.Contains(columnName) ||
                row[columnName] == DBNull.Value)
            {
                return null;
            }

            return Convert.ToDecimal(
                row[columnName],
                CultureInfo.InvariantCulture);
        }


        private static DateTime? DbDate(
            DataRow row,
            string columnName)
        {
            if (!row.Table.Columns.Contains(columnName) ||
                row[columnName] == DBNull.Value)
            {
                return null;
            }

            return Convert.ToDateTime(
                row[columnName],
                CultureInfo.InvariantCulture);
        }


        // ═══════════════════════════════════════════════════════
        //  Detail Builders
        // ═══════════════════════════════════════════════════════
        private static DepHousingDetail BuildHousingDetail(string depId) => depId switch
        {
            "dep_01" => new DepHousingDetail
            {
                TotalUnits = 1482,
                Occupied = 1355,
                Vacant = 67,
                UnderMaintenance = 28,
                ReferredQuality = 14,
                ReferredServices = 10,
                ReadyToAllocate = 8,
                AreaDistribution = new()
                {
                    new() { Label = "أقل من 120م²",  Value = 164, Color = Color.Navy      },
                    new() { Label = "120-180م²",      Value = 492, Color = Color.SteelBlue },
                    new() { Label = "181-250م²",      Value = 418, Color = Color.Emerald   },
                    new() { Label = "251-350م²",      Value = 267, Color = Color.Violet    },
                    new() { Label = "أكثر من 350م²",  Value = 141, Color = Color.Red       },
                },
                RoomDistribution = new()
                {
                    new() { Label = "غرفة واحدة", Value = 42,  Color = Color.Navy      },
                    new() { Label = "غرفتان",      Value = 154, Color = Color.SteelBlue },
                    new() { Label = "3 غرف",       Value = 386, Color = Color.Emerald   },
                    new() { Label = "4 غرف",       Value = 471, Color = Color.Violet    },
                    new() { Label = "5 غرف",       Value = 294, Color = Color.Cyan      },
                    new() { Label = "6+ غرف",      Value = 135, Color = Color.Red       },
                },
                FacilityTypes = new()
                {
                    new() { Label = "منازل عائلية",  Value = 1248, Color = Color.Navy      },
                    new() { Label = "وحدات عسكرية", Value = 214,  Color = Color.SteelBlue },
                    new() { Label = "وحدات عزاب",   Value = 81,   Color = Color.Emerald   },
                    new() { Label = "حدائق",         Value = 26,   Color = Color.Cyan      },
                    new() { Label = "مبانٍ خدمية",  Value = 17,   Color = Color.Slate     },
                }
            },
            _ => new DepHousingDetail
            {
                TotalUnits = 900,
                Occupied = 800,
                Vacant = 60,
                UnderMaintenance = 25,
                ReferredQuality = 10,
                ReferredServices = 5,
                ReadyToAllocate = 5,
                AreaDistribution = new()
                {
                    new() { Label = "أقل من 120م²",  Value = 120, Color = Color.Navy      },
                    new() { Label = "120-250م²",      Value = 500, Color = Color.SteelBlue },
                    new() { Label = "أكثر من 250م²",  Value = 280, Color = Color.Emerald   },
                },
                RoomDistribution = new()
                {
                    new() { Label = "1-2 غرف", Value = 150, Color = Color.Navy      },
                    new() { Label = "3-4 غرف", Value = 500, Color = Color.SteelBlue },
                    new() { Label = "5+ غرف",  Value = 250, Color = Color.Emerald   },
                },
                FacilityTypes = new()
                {
                    new() { Label = "منازل عائلية",  Value = 700, Color = Color.Navy      },
                    new() { Label = "وحدات عسكرية", Value = 150, Color = Color.SteelBlue },
                    new() { Label = "مرافق أخرى",   Value = 50,  Color = Color.Cyan      },
                }
            }
        };

        private static DepAllocationDetail BuildAllocationDetail(string depId) => depId switch
        {
            "dep_01" => new DepAllocationDetail
            {
                Categories = new()
                {
                    new() { Label = "القادة",      Residents = 8,    Waiting = 0,    Color = Color.Navy      },
                    new() { Label = "كبار الضباط", Residents = 92,   Waiting = 12,   Color = Color.SteelBlue },
                    new() { Label = "ضباط",         Residents = 214,  Waiting = 612,  Color = Color.Emerald   },
                    new() { Label = "ضباط صف",      Residents = 1204, Waiting = 7410, Color = Color.Red       },
                    new() { Label = "جنود",         Residents = 276,  Waiting = 2108, Color = Color.Amber     },
                    new() { Label = "مدنيون",       Residents = 165,  Waiting = 315,  Color = Color.Violet    },
                    new() { Label = "متعاقدون",     Residents = 38,   Waiting = 14,   Color = Color.Cyan      },
                },
                Districts = new()
                {
                    new() { Label = "القادسية",  Value = 224, Color = Color.Navy      },
                    new() { Label = "النخيل",    Value = 205, Color = Color.SteelBlue },
                    new() { Label = "الربوة",    Value = 198, Color = Color.Emerald   },
                    new() { Label = "اليرموك",  Value = 190, Color = Color.Violet    },
                    new() { Label = "الفيصلية", Value = 183, Color = Color.Cyan      },
                    new() { Label = "الورود",    Value = 176, Color = Color.Green     },
                    new() { Label = "الصفا",     Value = 162, Color = Color.Red       },
                    new() { Label = "الأندلس",  Value = 144, Color = Color.Slate     },
                }
            },
            _ => new DepAllocationDetail
            {
                Categories = new()
                {
                    new() { Label = "ضباط",     Residents = 150, Waiting = 25, Color = Color.SteelBlue },
                    new() { Label = "ضباط صف", Residents = 200, Waiting = 40, Color = Color.Amber     },
                    new() { Label = "أفراد",    Residents = 300, Waiting = 55, Color = Color.Red       },
                    new() { Label = "مدنيون",   Residents = 100, Waiting = 20, Color = Color.Violet    },
                },
                Districts = new()
                {
                    new() { Label = "الحي الأول",  Value = 180, Color = Color.Navy      },
                    new() { Label = "الحي الثاني", Value = 160, Color = Color.SteelBlue },
                    new() { Label = "الحي الثالث", Value = 140, Color = Color.Emerald   },
                    new() { Label = "الحي الرابع", Value = 120, Color = Color.Violet    },
                }
            }
        };

        private static DepRequestsDetail BuildRequestsDetail(string depId) => depId switch
        {
            "dep_01" => new DepRequestsDetail
            {
                OpenRequests = new()
                {
                    new() { Label = "تسكين",     Value = 84, Color = Color.Navy      },
                    new() { Label = "إمهال",      Value = 42, Color = Color.Amber     },
                    new() { Label = "إخلاء",      Value = 31, Color = Color.Red       },
                    new() { Label = "صيانة",      Value = 36, Color = Color.SteelBlue },
                    new() { Label = "نقل داخلي", Value = 12, Color = Color.Violet    },
                },
                SlaComparison = new()
                {
                    new() { Label = "الإمهال",  Actual = 1.6m, Target = 3.0m, Color = Color.Amber     },
                    new() { Label = "الإخلاء",  Actual = 4.9m, Target = 3.0m, Color = Color.Red       },
                    new() { Label = "التسكين",  Actual = 3.8m, Target = 2.0m, Color = Color.Navy      },
                }
            },
            _ => new DepRequestsDetail
            {
                OpenRequests = new()
                {
                    new() { Label = "تسكين", Value = 55, Color = Color.Navy  },
                    new() { Label = "إمهال",  Value = 30, Color = Color.Amber },
                    new() { Label = "إخلاء",  Value = 25, Color = Color.Red   },
                },
                SlaComparison = new()
                {
                    new() { Label = "الإمهال", Actual = 5.5m, Target = 4.0m, Color = Color.Amber },
                    new() { Label = "الإخلاء", Actual = 4.5m, Target = 3.0m, Color = Color.Red   },
                    new() { Label = "التسكين", Actual = 3.6m, Target = 2.5m, Color = Color.Navy  },
                }
            }
        };

        

        private static DepMaintenanceDetail BuildMaintenanceDetail(string depId) => depId switch
        {
            "dep_01" => new DepMaintenanceDetail
            {
                PlannedJobs = 260,
                CompletedJobs = 221,
                FleetReadiness = 86,
                QualityRefs = 14,
                ServicesRefs = 10,
                FacilityStatus = new()
                {
                    new() { Label = "السلامة", Value = 87, Color = Color.Emerald   },
                    new() { Label = "الماء",   Value = 91, Color = Color.SteelBlue },
                    new() { Label = "الغاز",   Value = 55, Color = Color.Amber     },
                }
            },
            _ => new DepMaintenanceDetail
            {
                PlannedJobs = 180,
                CompletedJobs = 150,
                FleetReadiness = 82,
                QualityRefs = 10,
                ServicesRefs = 7,
                FacilityStatus = new()
                {
                    new() { Label = "السلامة", Value = 87, Color = Color.Emerald   },
                    new() { Label = "الماء",   Value = 91, Color = Color.SteelBlue },
                    new() { Label = "الغاز",   Value = 55, Color = Color.Amber     },
                }
            }
        };






        private static void ApplyHousingOccupancySummary(
    List<HousingCommandCenterMetric> metrics,
    DataTable? occupancyTable)
        {
            var metric =
                metrics.FirstOrDefault(
                    x => x.Key == "m_housing_readiness");

            if (metric == null)
                return;

            decimal totalHousingUnits = 0;
            decimal occupiedHousingUnits = 0;

            if (occupancyTable != null)
            {
                foreach (DataRow row in occupancyTable.Rows)
                {
                    if (row["TotalHousingUnits"] != DBNull.Value)
                    {
                        totalHousingUnits +=
                            Convert.ToDecimal(
                                row["TotalHousingUnits"],
                                CultureInfo.InvariantCulture);
                    }

                    if (row["OccupiedHousingUnits"] != DBNull.Value)
                    {
                        occupiedHousingUnits +=
                            Convert.ToDecimal(
                                row["OccupiedHousingUnits"],
                                CultureInfo.InvariantCulture);
                    }
                }
            }

            var occupancyPercent =
                totalHousingUnits > 0
                    ? Math.Round(
                        occupiedHousingUnits * 100m / totalHousingUnits,
                        1)
                    : 0m;

            metric.Target = totalHousingUnits;
            metric.Actual = occupiedHousingUnits;

            metric.Hint =
                $"إجمالي الوحدات السكنية: {totalHousingUnits:0} | " +
                $"المشغولة: {occupiedHousingUnits:0} | " +
                $"نسبة الإشغال: {occupancyPercent:0.0}%";
        }


        private static void ApplyWaitingStockSummary(
    List<HousingCommandCenterMetric> metrics,
    DataTable? occupancyTable,
    DataTable? waitingTable)
        {
            var metric =
                metrics.FirstOrDefault(
                    x => x.Key == "m_allocation_balance");

            if (metric == null)
                return;

            decimal totalUnoccupied = 0;
            decimal totalWaiting = 0;

            if (occupancyTable != null)
            {
                foreach (DataRow row in occupancyTable.Rows)
                {
                    if (row["UnoccupiedHousingUnits"] != DBNull.Value)
                    {
                        totalUnoccupied +=
                            Convert.ToDecimal(
                                row["UnoccupiedHousingUnits"],
                                CultureInfo.InvariantCulture);
                    }
                }
            }

            if (waitingTable != null)
            {
                foreach (DataRow row in waitingTable.Rows)
                {
                    if (row["CurrentWaitingCount"] != DBNull.Value)
                    {
                        totalWaiting +=
                            Convert.ToDecimal(
                                row["CurrentWaitingCount"],
                                CultureInfo.InvariantCulture);
                    }
                }
            }

            decimal coveragePercent;

            if (totalWaiting <= 0)
            {
                coveragePercent = 100m;
            }
            else
            {
                coveragePercent =
                    Math.Round(
                        Math.Min(
                            totalUnoccupied * 100m /
                            totalWaiting,
                            100m),
                        1);
            }

            var availableAfterCoverage =
                Math.Max(totalUnoccupied - totalWaiting, 0m);

            var waitingDeficit =
                Math.Max(totalWaiting - totalUnoccupied, 0m);

            metric.Actual = totalWaiting;
            metric.Target = totalUnoccupied;
            metric.CompletionPercent = coveragePercent;

            metric.Hint =
                $"المنتظرون: {totalWaiting:0} | " +
                $"الوحدات غير المشغولة: {totalUnoccupied:0} | " +
                $"المتاح بعد التغطية: {availableAfterCoverage:0} | " +
                $"العجز العددي: {waitingDeficit:0} | " +
                $"نسبة التغطية العددية: {coveragePercent:0.0}%";
        }



        private static void ApplyAllocationEfficiencySummary(
    List<HousingCommandCenterMetric> metrics,
    DataTable? occupancyTable,
    DataTable? waitingTable)
        {
            var metric =
                metrics.FirstOrDefault(
                    x => x.Key == "m_allocation_balance");

            if (metric == null)
                return;

            decimal totalWaiting = 0;
            decimal totalUnoccupiedHousingUnits = 0;

            //----------------------------------------------------------
            // إجمالي المنازل الشاغرة
            //----------------------------------------------------------
            if (occupancyTable != null)
            {
                foreach (DataRow row in occupancyTable.Rows)
                {
                    if (row["UnoccupiedHousingUnits"] != DBNull.Value)
                    {
                        totalUnoccupiedHousingUnits +=
                            Convert.ToDecimal(
                                row["UnoccupiedHousingUnits"],
                                CultureInfo.InvariantCulture);
                    }
                }
            }

            //----------------------------------------------------------
            // إجمالي المنتظرين
            //----------------------------------------------------------
            if (waitingTable != null)
            {
                foreach (DataRow row in waitingTable.Rows)
                {
                    if (row["CurrentWaitingCount"] != DBNull.Value)
                    {
                        totalWaiting +=
                            Convert.ToDecimal(
                                row["CurrentWaitingCount"],
                                CultureInfo.InvariantCulture);
                    }
                }
            }

            //----------------------------------------------------------
            // كفاءة التخصيص على مستوى جميع الإدارات
            //----------------------------------------------------------
            decimal allocationEfficiencyPercent;

            if (totalWaiting <= 0)
            {
                allocationEfficiencyPercent = 100m;
            }
            else
            {
                var conflictingCount =
                    Math.Min(
                        totalWaiting,
                        totalUnoccupiedHousingUnits);

                allocationEfficiencyPercent =
                    Math.Round(
                        100m -
                        (
                            conflictingCount * 100m /
                            totalWaiting
                        ),
                        1);
            }

            //----------------------------------------------------------
            // المنتظرون بعد تغطية المنازل الشاغرة
            //----------------------------------------------------------
            var waitingAfterCoverage =
                Math.Max(
                    totalWaiting - totalUnoccupiedHousingUnits,
                    0m);

            //----------------------------------------------------------
            // تحديث الكارد الرئيسي
            //----------------------------------------------------------
            metric.Actual = totalWaiting;
            metric.Target = totalUnoccupiedHousingUnits;
            metric.CompletionPercent = allocationEfficiencyPercent;

            metric.Hint =
                $"إجمالي المنتظرين: {totalWaiting:0} | " +
                $"إجمالي المنازل الشاغرة: {totalUnoccupiedHousingUnits:0} | " +
                $"المنتظرون بعد تغطية المنازل الشاغرة: {waitingAfterCoverage:0} | " +
                $"كفاءة التخصيص: {allocationEfficiencyPercent:0.0}%";
        }


        private static void ApplyHousingProceduresSummary(
    List<HousingCommandCenterMetric> metrics,
    DataTable? workflowPerformanceTable)
        {
            var metric =
                metrics.FirstOrDefault(
                    x => x.Key == "m_housing_procedures");

            if (metric == null)
                return;


            if (workflowPerformanceTable == null ||
                workflowPerformanceTable.Rows.Count == 0)
            {
                metric.Target = null;
                metric.Actual = null;
                metric.CompletionPercent = null;
                return;
            }


            var workflowScores =
                new List<decimal>();

            var notes =
                new List<string>();


            void AddWorkflow(
                string workflowKey,
                string workflowName,
                decimal targetDays)
            {
                var rows =
                    workflowPerformanceTable
                        .AsEnumerable()
                        .Where(r =>
                            string.Equals(
                                Convert.ToString(
                                    r["WorkflowKey"],
                                    CultureInfo.InvariantCulture),
                                workflowKey,
                                StringComparison.OrdinalIgnoreCase))
                        .ToList();


                decimal weightedDays = 0m;

                var totalCompleted = 0;


                foreach (var row in rows)
                {
                    var completed =
                        row["CompletedCount"] == DBNull.Value
                            ? 0
                            : Convert.ToInt32(
                                row["CompletedCount"],
                                CultureInfo.InvariantCulture);


                    if (completed <= 0 ||
                        row["AverageDays"] == DBNull.Value)
                    {
                        continue;
                    }


                    var averageDays =
                        Convert.ToDecimal(
                            row["AverageDays"],
                            CultureInfo.InvariantCulture);


                    weightedDays +=
                        averageDays *
                        completed;

                    totalCompleted +=
                        completed;
                }


                if (totalCompleted <= 0)
                    return;


                var globalAverageDays =
                    weightedDays /
                    totalCompleted;


                var efficiency =
                    CalculateWorkflowEfficiency(
                        targetDays,
                        totalCompleted,
                        globalAverageDays);


                if (!efficiency.HasValue)
                    return;


                workflowScores.Add(
                    efficiency.Value);


                notes.Add(
                    $"{workflowName}: متوسط {globalAverageDays:0.0} يوم " +
                    $"| الهدف {targetDays:0} يوم " +
                    $"| الكفاءة {efficiency.Value:0.0}% " +
                    $"| مكتمل {totalCompleted}");
            }


            AddWorkflow(
                "ALLOCATION",
                "التسكين",
                30m);

            AddWorkflow(
                "EXTEND",
                "الإمهال",
                5m);

            AddWorkflow(
                "EXIT",
                "الإخلاء",
                5m);


            if (workflowScores.Count == 0)
            {
                metric.Target = null;
                metric.Actual = null;
                metric.CompletionPercent = null;
                metric.Hint =
                    "لا توجد دورات مكتملة يمكن احتساب الكفاءة منها.";

                return;
            }


            var overallEfficiency =
                Math.Round(
                    workflowScores.Average(),
                    1);


            metric.Target = 100m;

            metric.Actual =
                overallEfficiency;

            metric.CompletionPercent =
                overallEfficiency;

            metric.Hint =
                string.Join(
                    " | ",
                    notes);
        }



        private static void ApplyFinancialSummary(
    List<HousingCommandCenterMetric> metrics,
    DataTable? financialTable)
        {
            var metric =
                metrics.FirstOrDefault(
                    x =>
                        x.Key ==
                        "m_finance_utilities");

            if (metric == null)
                return;


            decimal totalClaims = 0m;
            decimal totalPayments = 0m;

            decimal amountToCollect = 0m;
            decimal amountToRefund = 0m;

            decimal totalFinancialGap = 0m;

            int financialBeneficiariesCount = 0;
            int balancedBeneficiariesCount = 0;
            int deficitBeneficiariesCount = 0;
            int surplusBeneficiariesCount = 0;


            if (financialTable != null)
            {
                foreach (DataRow row in financialTable.Rows)
                {
                    financialBeneficiariesCount +=
                        row["FinancialBeneficiariesCount"] == DBNull.Value
                            ? 0
                            : Convert.ToInt32(
                                row["FinancialBeneficiariesCount"],
                                CultureInfo.InvariantCulture);


                    balancedBeneficiariesCount +=
                        row["BalancedBeneficiariesCount"] == DBNull.Value
                            ? 0
                            : Convert.ToInt32(
                                row["BalancedBeneficiariesCount"],
                                CultureInfo.InvariantCulture);


                    deficitBeneficiariesCount +=
                        row["DeficitBeneficiariesCount"] == DBNull.Value
                            ? 0
                            : Convert.ToInt32(
                                row["DeficitBeneficiariesCount"],
                                CultureInfo.InvariantCulture);


                    surplusBeneficiariesCount +=
                        row["SurplusBeneficiariesCount"] == DBNull.Value
                            ? 0
                            : Convert.ToInt32(
                                row["SurplusBeneficiariesCount"],
                                CultureInfo.InvariantCulture);


                    totalClaims +=
                        row["TotalClaims"] == DBNull.Value
                            ? 0m
                            : Convert.ToDecimal(
                                row["TotalClaims"],
                                CultureInfo.InvariantCulture);


                    totalPayments +=
                        row["TotalPayments"] == DBNull.Value
                            ? 0m
                            : Convert.ToDecimal(
                                row["TotalPayments"],
                                CultureInfo.InvariantCulture);


                    amountToCollect +=
                        row["AmountToCollect"] == DBNull.Value
                            ? 0m
                            : Convert.ToDecimal(
                                row["AmountToCollect"],
                                CultureInfo.InvariantCulture);


                    amountToRefund +=
                        row["AmountToRefund"] == DBNull.Value
                            ? 0m
                            : Convert.ToDecimal(
                                row["AmountToRefund"],
                                CultureInfo.InvariantCulture);


                    totalFinancialGap +=
                        row["TotalFinancialGap"] == DBNull.Value
                            ? 0m
                            : Convert.ToDecimal(
                                row["TotalFinancialGap"],
                                CultureInfo.InvariantCulture);
                }
            }


            //----------------------------------------------------------
            // الكفاءة المالية الإجمالية
            //----------------------------------------------------------

            decimal? financialEfficiencyPercent;


            if (financialBeneficiariesCount <= 0)
            {
                financialEfficiencyPercent =
                    null;
            }
            else if (totalClaims <= 0m)
            {
                financialEfficiencyPercent =
                    totalPayments > 0m
                        ? 0m
                        : null;
            }
            else if (totalFinancialGap >= totalClaims)
            {
                financialEfficiencyPercent =
                    0m;
            }
            else
            {
                financialEfficiencyPercent =
                    Math.Round(
                        100m -
                        (
                            totalFinancialGap *
                            100m /
                            totalClaims
                        ),
                        1);
            }


            //----------------------------------------------------------
            // تحديث المؤشر الرئيسي
            //----------------------------------------------------------

            metric.Target =
                totalClaims;

            metric.Actual =
                totalPayments;

            metric.CompletionPercent =
                financialEfficiencyPercent;


            if (!financialEfficiencyPercent.HasValue)
            {
                metric.Hint =
                    "لا توجد حركة مالية للمستفيدين يمكن احتساب الكفاءة منها.";

                return;
            }


            metric.Hint =
                $"المستفيدون الماليون: {financialBeneficiariesCount:N0} | " +
                $"المتوازنون: {balancedBeneficiariesCount:N0} | " +
                $"بعجز: {deficitBeneficiariesCount:N0} | " +
                $"بفائض: {surplusBeneficiariesCount:N0} | " +
                $"إجمالي المطالبات: {totalClaims:N2} | " +
                $"إجمالي السدادات: {totalPayments:N2} | " +
                $"مطلوب تحصيله: {amountToCollect:N2} | " +
                $"مطلوب إعادته: {amountToRefund:N2} | " +
                $"الكفاءة المالية: {financialEfficiencyPercent.Value:0.0}%";
        }











    }
}