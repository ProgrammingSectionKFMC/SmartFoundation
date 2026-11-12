using Microsoft.AspNetCore.Mvc;
using SmartFoundation.MVC.Reports;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartPrint;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.IO;

namespace SmartFoundation.Mvc.Controllers.Vehicle
{
    public partial class VehicleController : Controller
    {
        // ═══════════════════════════════════════════════════════════════
        //  صفحة إدارة العهد — Vehicle/Custody
        //  ─────────────────────────────────────────────────────────────
        //  التبويب الأول: العهود النشطة  (عرض + إنشاء + إغلاق + طباعة)
        //  التبويب الثاني: سجل العهد    (عرض + بحث + طباعة)
        //
        //  المسار: Controller → Gateway (Masters_DataLoad)
        //          → VIC.CustodyDL (@ActionType)
        //          → ViewModel → SmartRenderer → VehicleList.cshtml
        // ═══════════════════════════════════════════════════════════════

        [Route("Vehicle/Custody")]
        public async Task<IActionResult> Custody(
              string? chassisNumber = null
            , string? generalNo = null
            , string? fromDate = null
            , string? toDate = null
            , int pageNumber = 1
            , int pageSize = 50
            , int? pdf = null
        )
        {
            // ── 1) التحقق من السيشن والصلاحيات ──────────────────────

            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = "Vehicle";
            PageName = "Custody";

            var csrfToken = Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "";

            // ── دوال مساعدة محلية ───────────────────────────────────

            // يحوّل DataRow إلى Dictionary مع استبدال DBNull بـ null
            static Dictionary<string, object?> ToRowDict(DataRow r, DataTable t)
            {
                var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                foreach (DataColumn c in t.Columns)
                    dict[c.ColumnName] = r[c] == DBNull.Value ? null : r[c];
                return dict;
            }

            // يطبّق fallback: Snapshot أولاً فإن كان فارغًا يستخدم Current
            static void ApplySnapshotFallbacks(Dictionary<string, object?> dict, bool includeRank)
            {
                static string? Pick(Dictionary<string, object?> d, string snap, string cur)
                {
                    var s = d.TryGetValue(snap, out var sv) ? sv?.ToString() : null;
                    var c = d.TryGetValue(cur,  out var cv) ? cv?.ToString() : null;
                    return !string.IsNullOrWhiteSpace(s) ? s : !string.IsNullOrWhiteSpace(c) ? c : "";
                }

                dict["UserFullName_Snapshot"] = Pick(dict, "UserFullName_Snapshot", "UserFullName_A_Current");
                dict["GeneralNo_Snapshot"]    = Pick(dict, "GeneralNo_Snapshot",    "GeneralNo_Current");

                if (includeRank)
                    dict["RankName_Snapshot"] = Pick(dict, "RankName_Snapshot", "RankName_Current");
            }

            // يستخرج قوائم منسدلة من DataSet (Tables[1] أو Tables[0])
            static List<OptionItem> ExtractDdlOptions(DataSet? ds)
            {
                var opts = new List<OptionItem>();
                DataTable? t = (ds?.Tables?.Count ?? 0) > 1 ? ds!.Tables[1]
                    : (ds?.Tables?.Count ?? 0) > 0 ? ds!.Tables[0] : null;
                if (t == null) return opts;
                foreach (DataRow r in t.Rows)
                {
                    var val = t.Columns.Contains("Value") ? r["Value"]?.ToString() : null;
                    var txt = t.Columns.Contains("Text") ? r["Text"]?.ToString() : null;
                    if (val != null && txt != null)
                        opts.Add(new OptionItem { Value = val, Text = txt });
                }
                return opts;
            }

            // يبني الحقول المخفية المشتركة بين كل النماذج
            List<FieldConfig> BuildHiddenFields(string actionType) => new()
            {
                new FieldConfig { Name = "pageName_",                     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",                    Type = "hidden", Value = actionType },
                new FieldConfig { Name = "idaraID",                       Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata",                     Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname",                      Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectAction",                Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController",            Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken",    Type = "hidden", Value = csrfToken },
            };

            // ── 2) تحميل البيانات المتوازي ───────────────────────────
            // 6 طلبات تُطلق دفعة واحدة ثم ننتظر أطولها فقط

            var custodyTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[] { PageName, IdaraId, usersId, HostName });

            var vehicleTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[] { "Vehicle_Search", IdaraId, usersId, HostName, "%", null, null, 2000, IdaraId });

            var rankTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[] { "VehicleUser_DDL", IdaraId, usersId, HostName, "DDL_RANK" });

            var nationalityTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[] { "VehicleUser_DDL", IdaraId, usersId, HostName, "DDL_NATIONALITY" });

            var genderTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[] { "VehicleUser_DDL", IdaraId, usersId, HostName, "DDL_GENDER" });

            var historyTask = _mastersServies.GetDataLoadDataSetAsync(
                new object?[]
                {
                    "Custody_HistoryList", IdaraId, usersId, HostName,
                    string.IsNullOrWhiteSpace(chassisNumber) ? null : chassisNumber,
                    string.IsNullOrWhiteSpace(fromDate) ? null : fromDate,
                    string.IsNullOrWhiteSpace(toDate) ? null : toDate,
                    null, null,
                    pageNumber, pageSize, IdaraId
                });

            await Task.WhenAll(custodyTask, vehicleTask, rankTask, nationalityTask, genderTask, historyTask);

            // ── 3) استخراج القوائم المنسدلة ─────────────────────────

            // قائمة المركبات (Select2) — من Vehicle_Search
            // النص يبدأ برقم الجيش (الأبرز) ثم رقم الهيكل، والقيمة = chassisNumber
            var vehicleOptions = new List<OptionItem>();
            DataSet vehicleDs = vehicleTask.Result;
            DataTable? vehicleTable = (vehicleDs?.Tables?.Count ?? 0) > 1
                ? vehicleDs!.Tables[1]
                : (vehicleDs?.Tables?.Count ?? 0) > 0 ? vehicleDs!.Tables[0] : null;

            if (vehicleTable != null)
            {
                foreach (DataRow r in vehicleTable.Rows)
                {
                    var chassis = vehicleTable.Columns.Contains("chassisNumber")
                        ? r["chassisNumber"]?.ToString() : null;
                    if (string.IsNullOrWhiteSpace(chassis)) continue;

                    var army = vehicleTable.Columns.Contains("armyNumber")
                        ? r["armyNumber"]?.ToString()?.Trim() : "";
                    var pL = vehicleTable.Columns.Contains("plateLetters") ? r["plateLetters"]?.ToString()?.Trim() : "";
                    var pN = vehicleTable.Columns.Contains("plateNumbers") ? r["plateNumbers"]?.ToString()?.Trim() : "";
                    var plate = $"{pL} {pN}".Trim();

                    string text;
                    if (!string.IsNullOrWhiteSpace(army))
                        text = $"{army} — {chassis}";
                    else if (!string.IsNullOrWhiteSpace(plate))
                        text = $"{chassis} — {plate}";
                    else
                        text = chassis;

                    vehicleOptions.Add(new OptionItem { Value = chassis, Text = text });
                }
            }

            // قوائم الرتبة / الجنسية / الجنس — من VehicleUser_DDL
            var rankOptions        = ExtractDdlOptions(rankTask.Result);
            var nationalityOptions = ExtractDdlOptions(nationalityTask.Result);
            var genderOptions      = ExtractDdlOptions(genderTask.Result);

            // ── 4) تجهيز بيانات التبويب الأول (العهود النشطة) ─────────

            DataSet ds = custodyTask.Result;
            SplitDataSet(ds);

            bool canAccess        = false;
            bool canSelect        = false;
            bool canInsertCustody = false;
            bool canCloseCustody  = false;

            var custodyColumns = new List<TableColumn>();
            var custodyRows    = new List<Dictionary<string, object?>>();

            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable != null && permissionTable.Rows.Count > 0)
                {
                    // استخراج الصلاحيات
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var p = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                        if (p == "ACCESS")        canAccess = true;
                        if (p == "SELECT")        canSelect = true;
                        if (p == "INSERTCUSTODY") canInsertCustody = true;
                        if (p == "CLOSECUSTODY")  canCloseCustody = true;
                    }

                    if (!canAccess && !canSelect)
                    {
                        TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                        return RedirectToAction("Index", "Home");
                    }

                    var custodyData = dt1;

                    // كشف رسائل الخطأ من الـ SP (IsSuccessful بدون vehicleWithUsersID)
                    if (custodyData != null
                        && custodyData.Columns.Contains("IsSuccessful")
                        && !custodyData.Columns.Contains("vehicleWithUsersID"))
                    {
                        string sqlError = "استجابة غير متوقعة من قاعدة البيانات";
                        if (custodyData.Rows.Count > 0)
                        {
                            var msgCol = custodyData.Columns.Contains("Message_")
                                ? "Message_"
                                : custodyData.Columns.Contains("Message") ? "Message" : null;
                            if (msgCol != null && custodyData.Rows[0][msgCol] != null && custodyData.Rows[0][msgCol] != DBNull.Value)
                                sqlError = custodyData.Rows[0][msgCol]?.ToString() ?? sqlError;
                        }
                        TempData["DataSetError"] = sqlError;
                        custodyData = null;
                    }

                    // تعريف الأعمدة
                    custodyColumns = new List<TableColumn>
                    {
                        new TableColumn { Field = "vehicleWithUsersID",    Label = "رقم العهدة",    Sortable = true, Visible = false },
                        new TableColumn { Field = "armyNumber",            Label = "الرقم العسكري", Sortable = true },
                        new TableColumn { Field = "chassisNumber_FK",      Label = "رقم الهيكل",    Sortable = true },
                        new TableColumn { Field = "plateLetters",          Label = "حروف اللوحة",   Sortable = true },
                        new TableColumn { Field = "plateNumbers",          Label = "أرقام اللوحة",  Sortable = true },
                        new TableColumn { Field = "UserFullName_Snapshot", Label = "اسم المستخدم",  Sortable = true },
                        new TableColumn { Field = "GeneralNo_Snapshot",    Label = "الرقم العام",   Sortable = true },
                        new TableColumn { Field = "RankName_Snapshot",     Label = "الرتبة",        Sortable = true },
                        new TableColumn { Field = "startDateText",         Label = "تاريخ البداية", Sortable = true },
                        new TableColumn { Field = "note",                  Label = "ملاحظات",       Sortable = true },
                    };

                    // بناء الصفوف
                    if (custodyData != null && custodyData.Columns.Count > 0)
                    {
                        foreach (DataRow r in custodyData.Rows)
                        {
                            var dict = ToRowDict(r, custodyData);
                            ApplySnapshotFallbacks(dict, includeRank: true);
                            dict["startDateText"] = NormalizeDateForInput(dict.TryGetValue("startDate", out var sd) ? sd : null);
                            dict["p01"] = dict.TryGetValue("vehicleWithUsersID", out var id) ? id : null;
                            custodyRows.Add(dict);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                TempData["DataSetError"] = ex.Message;
            }

            // ── 5) تجهيز بيانات التبويب الثاني (السجل) ───────────────

            DataSet dsHistory = historyTask.Result;
            var historyData = (dsHistory?.Tables?.Count ?? 0) > 1 ? dsHistory!.Tables[1] : null;

            var historyColumns = new List<TableColumn>
            {
                new TableColumn { Field = "vehicleWithUsersID",    Label = "رقم العهدة",    Sortable = true, Visible = false },
                new TableColumn { Field = "armyNumber",            Label = "الرقم العسكري", Sortable = true },
                new TableColumn { Field = "chassisNumber_FK",      Label = "رقم الهيكل",    Sortable = true },
                new TableColumn { Field = "plateLetters",          Label = "حروف اللوحة",   Sortable = true },
                new TableColumn { Field = "plateNumbers",          Label = "أرقام اللوحة",  Sortable = true },
                new TableColumn { Field = "UserFullName_Snapshot", Label = "اسم المستخدم",  Sortable = true },
                new TableColumn { Field = "GeneralNo_Snapshot",    Label = "الرقم العام",   Sortable = true },
                new TableColumn { Field = "startDateText",         Label = "تاريخ البداية", Sortable = true },
                new TableColumn { Field = "endDateText",           Label = "تاريخ النهاية", Sortable = true },
                new TableColumn { Field = "CustodyStatusText",     Label = "الحالة", Sortable = true, Type = "badge",
                    Badge = new TableBadgeConfig
                    {
                        Map = new Dictionary<string, string>
                        {
                            ["نشطة"]  = "pill pill-green",
                            ["مغلقة"] = "pill pill-gray",
                        }
                    }
                },
                new TableColumn { Field = "note",                  Label = "ملاحظات",       Sortable = true },
            };

            var historyRows = new List<Dictionary<string, object?>>();

            if (historyData != null && historyData.Columns.Count > 0)
            {
                foreach (DataRow r in historyData.Rows)
                {
                    var dict = ToRowDict(r, historyData);
                    ApplySnapshotFallbacks(dict, includeRank: false);
                    dict["startDateText"] = NormalizeDateForInput(dict.TryGetValue("startDate", out var sd) ? sd : null);
                    dict["endDateText"]   = NormalizeDateForInput(dict.TryGetValue("endDate",   out var ed) ? ed : null);
                    historyRows.Add(dict);
                }
            }

            // الرقم العام كان ظاهرًا في واجهة الفلترة القديمة دون ربطه بعقد SQL.
            // نحافظ عليه كفلتر عرض فقط، دون تغيير Stored Procedures أو منطق الحفظ.
            if (!string.IsNullOrWhiteSpace(generalNo))
            {
                var normalizedGeneralNo = generalNo.Trim();

                static bool MatchesGeneralNo(
                    Dictionary<string, object?> row,
                    string expected)
                {
                    return row.TryGetValue("GeneralNo_Snapshot", out var value)
                        && string.Equals(
                            value?.ToString()?.Trim(),
                            expected,
                            StringComparison.OrdinalIgnoreCase);
                }

                custodyRows = custodyRows
                    .Where(row => MatchesGeneralNo(row, normalizedGeneralNo))
                    .ToList();

                historyRows = historyRows
                    .Where(row => MatchesGeneralNo(row, normalizedGeneralNo))
                    .ToList();
            }

            // ── 6) وضع الطباعة (PDF) ─────────────────────────────────
            // sfPrintWithBusy يفتح نفس الرابط مع ?pdf=1 أو ?pdf=2
            // الـ Controller يُولّد PDF عبر QuestPdfReportRenderer

            if (pdf.HasValue)
            {
                var rows = pdf == 2 ? historyRows : custodyRows;
                var title = pdf == 2 ? "سجل العهد" : "العهود النشطة";

                if (rows.Count == 0)
                    return Content("لا توجد بيانات للطباعة.");

                var printTable = new DataTable();
                printTable.Columns.Add("armyNumber",            typeof(string));
                printTable.Columns.Add("chassisNumber_FK",      typeof(string));
                printTable.Columns.Add("plateLetters",          typeof(string));
                printTable.Columns.Add("plateNumbers",          typeof(string));
                printTable.Columns.Add("UserFullName_Snapshot", typeof(string));
                printTable.Columns.Add("GeneralNo_Snapshot",    typeof(string));
                printTable.Columns.Add("RankName_Snapshot",     typeof(string));
                printTable.Columns.Add("startDateText",         typeof(string));

                if (pdf == 2)
                    printTable.Columns.Add("endDateText", typeof(string));

                printTable.Columns.Add("CustodyStatusText", typeof(string));
                printTable.Columns.Add("note",              typeof(string));

                foreach (var row in rows)
                {
                    var vals = new List<object?>
                    {
                        row.GetValueOrDefault("armyNumber")?.ToString(),
                        row.GetValueOrDefault("chassisNumber_FK")?.ToString(),
                        row.GetValueOrDefault("plateLetters")?.ToString(),
                        row.GetValueOrDefault("plateNumbers")?.ToString(),
                        row.GetValueOrDefault("UserFullName_Snapshot")?.ToString(),
                        row.GetValueOrDefault("GeneralNo_Snapshot")?.ToString(),
                        row.GetValueOrDefault("RankName_Snapshot")?.ToString(),
                        row.GetValueOrDefault("startDateText")?.ToString(),
                    };

                    if (pdf == 2)
                        vals.Add(row.GetValueOrDefault("endDateText")?.ToString());

                    vals.Add(row.GetValueOrDefault("CustodyStatusText")?.ToString());
                    vals.Add(row.GetValueOrDefault("note")?.ToString());

                    printTable.Rows.Add(vals.ToArray()!);
                }

                var reportColumns = new List<ReportColumn>
                {
                    new("armyNumber",            "الرقم العسكري", Align:"center", Weight:2, FontSize:9),
                    new("chassisNumber_FK",      "رقم الهيكل",    Align:"center", Weight:2, FontSize:9),
                    new("plateLetters",          "حروف اللوحة",   Align:"center", Weight:2, FontSize:9),
                    new("plateNumbers",          "أرقام اللوحة",  Align:"center", Weight:2, FontSize:9),
                    new("UserFullName_Snapshot", "اسم المستخدم",  Align:"center", Weight:3, FontSize:9),
                    new("GeneralNo_Snapshot",    "الرقم العام",   Align:"center", Weight:2, FontSize:9),
                    new("RankName_Snapshot",     "الرتبة",        Align:"center", Weight:2, FontSize:9),
                    new("startDateText",         "تاريخ البداية", Align:"center", Weight:2, FontSize:9),
                };

                if (pdf == 2)
                    reportColumns.Add(new("endDateText", "تاريخ النهاية", Align:"center", Weight:2, FontSize:9));

                reportColumns.AddRange(new List<ReportColumn>
                {
                    new("CustodyStatusText", "الحالة",   Align:"center", Weight:2, FontSize:9),
                    new("note",              "ملاحظات",  Align:"center", Weight:3, FontSize:9),
                });

                var logo = Path.Combine(_env.WebRootPath, "img", "ppng.png");
                var header = new Dictionary<string, string>
                {
                    ["no"]      = usersId ?? "",
                    ["date"]    = DateTime.Now.ToString("yyyy/MM/dd"),
                    ["attach"]  = "—",
                    ["subject"] = title,
                    ["right1"]  = "المملكة العربية السعودية",
                    ["right2"]  = "وزارة الدفاع",
                    ["right3"]  = "القوات البرية الملكية السعودية",
                    ["midCaption"] = ""
                };

                var report = DataTableReportBuilder.FromDataTable(
                    reportId:   "Custody",
                    title:      title,
                    table:      printTable,
                    columns:    reportColumns,
                    headerFields: header,
                    footerFields: new Dictionary<string, string>
                    {
                        ["تمت الطباعة بواسطة"]   = FullName ?? "",
                        ["ملاحظة"]               = "هذا التقرير للاستخدام الرسمي",
                        ["عدد السجلات"]          = rows.Count.ToString(),
                        ["تاريخ ووقت الطباعة"]   = DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss")
                    },
                    orientation:  ReportOrientation.Landscape,
                    headerType:   ReportHeaderType.LetterOfficial,
                    logoPath:     logo,
                    headerRepeat: ReportHeaderRepeat.FirstPageOnly
                );

                var pdfBytes = QuestPdfReportRenderer.Render(report);
                Response.Headers["Content-Disposition"] = $"inline; filename=Custody.pdf";
                return File(pdfBytes, "application/pdf");
            }

            // ── 7) تجهيز النماذج ─────────────────────────────────────

            // نموذج إنشاء عهدة (15 بارامتر → Gateway INSERTCUSTODY)
            var addCustodyFields = BuildHiddenFields("INSERTCUSTODY");
            addCustodyFields.AddRange(new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Type = "hidden", Value = "" },
                new FieldConfig { Name = "p03", Type = "hidden", Value = "" },

                // بيانات المستخدم
                new FieldConfig { SectionTitle = "بيانات المستخدم", Name = "p06", Label = "الرقم العام", Type = "number", ColCss = "6", Required = true, Icon = "fa-solid fa-user-tag", Autocomplete = "off" },
                new FieldConfig { Name = "p07", Label = "رقم الهوية", Type = "nationalid", ColCss = "6", Icon = "fa-solid fa-address-card" },
                new FieldConfig { Name = "p08", Label = "رقم الجوال", Type = "tel", ColCss = "4", Icon = "fa-solid fa-phone", HelpText = "مثال: 05XXXXXXXX" },
                new FieldConfig { Name = "p09", Label = "الرتبة",    Type = "select", ColCss = "4", Options = rankOptions,       Select2 = true },
                new FieldConfig { Name = "p10", Label = "الجنسية",   Type = "select", ColCss = "4", Options = nationalityOptions, Select2 = true },
                new FieldConfig { Name = "p11", Label = "الجنس",     Type = "select", ColCss = "4", Options = genderOptions,     Select2 = true },
                new FieldConfig { Name = "p12", Label = "الاسم الأول",  Type = "text", ColCss = "4", Required = true, Placeholder = "حقل عربي فقط", TextMode = "arabic", MaxLength = 50, Icon = "fa-solid fa-user" },
                new FieldConfig { Name = "p13", Label = "اسم الأب",    Type = "text", ColCss = "4", Required = true, Placeholder = "حقل عربي فقط", TextMode = "arabic", MaxLength = 50 },
                new FieldConfig { Name = "p14", Label = "اسم الجد",    Type = "text", ColCss = "4", Placeholder = "حقل عربي فقط", TextMode = "arabic", MaxLength = 50 },
                new FieldConfig { Name = "p15", Label = "الاسم الأخير", Type = "text", ColCss = "4", Required = true, Placeholder = "حقل عربي فقط", TextMode = "arabic", MaxLength = 50 },

                // بيانات العهدة
                new FieldConfig { SectionTitle = "بيانات العهدة", Name = "p02", Label = "المركبة", Type = "select", ColCss = "12", Required = true, Select2 = true, Placeholder = "ابحث برقم الجيش أو رقم الهيكل", Options = vehicleOptions },
                new FieldConfig { Name = "p04", Label = "تاريخ البداية", Type = "date", ColCss = "6", Icon = "fa-solid fa-calendar", DefaultToday = true },
                new FieldConfig { Name = "p05", Label = "ملاحظات",       Type = "textarea", ColCss = "12", MaxLength = 2000 },
            });

            // نموذج إغلاق عهدة (3 بارامترات → Gateway CLOSECUSTODY)
            var closeCustodyFields = BuildHiddenFields("CLOSECUSTODY");
            closeCustodyFields.AddRange(new List<FieldConfig>
            {
                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig { Name = "p02", Label = "تاريخ الإغلاق", Type = "date",     ColCss = "6",  Required = true, Icon = "fa-solid fa-calendar", DefaultToday = true },
                new FieldConfig { Name = "p03", Label = "ملاحظات",       Type = "textarea", ColCss = "12", MaxLength = 2000 },
            });

            // ── 8) تجهيز الأزرار والإجراءات ─────────────────────────

            // إجراءات مخصصة للتبويب الأول (إغلاق عهدة)
            var custodyCustomActions = new List<TableAction>();

            if (canCloseCustody)
            {
                custodyCustomActions.Add(new TableAction
                {
                    Label            = "إغلاق عهدة",
                    Icon             = "fa-solid fa-lock",
                    Color            = "warning",
                    RequireSelection = true,
                    MinSelection     = 1,
                    MaxSelection     = 1,
                    OpenModal        = true,
                    ModalTitle       = "<i class='fa-solid fa-lock text-amber-600 text-xl mr-2'></i> إغلاق عهدة",
                    OpenForm = new FormConfig
                    {
                        FormId    = "CloseCustodyForm",
                        Title     = "إغلاق عهدة",
                        Method    = "post",
                        ActionUrl = "/crud/update",
                        Fields    = closeCustodyFields,
                        Buttons = new List<FormButtonConfig>
                        {
                            new FormButtonConfig { Text = "إغلاق", Type = "submit", Color = "warning" },
                            new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                        }
                    }
                });
            }

            // ── 9) تجميع نموذج الصفحة (SmartPageViewModel) ───────────

            var filterForm = new FormConfig
            {
                FormId = "custodyFilterForm",
                Title = "",
                LabelText = "فلترة بيانات العهد",
                Method = "GET",
                ActionUrl = "/Vehicle/Custody",
                ShowPanel = false,
                ShowSubmit = false,
                ShowReset = false,
                Fields = new List<FieldConfig>
                {
                    new()
                    {
                        Name = "chassisNumber",
                        Label = "رقم الهيكل",
                        Type = "text",
                        ColCss = "3",
                        Value = chassisNumber ?? "",
                        Placeholder = "ابحث برقم الهيكل",
                        Icon = "fa-solid fa-car"
                    },
                    new()
                    {
                        Name = "generalNo",
                        Label = "الرقم العام",
                        Type = "text",
                        ColCss = "3",
                        Value = generalNo ?? "",
                        Placeholder = "ابحث بالرقم العام",
                        Icon = "fa-solid fa-id-badge"
                    },
                    new()
                    {
                        Name = "fromDate",
                        Label = "من تاريخ",
                        Type = "date",
                        ColCss = "3",
                        Value = fromDate ?? "",
                        Icon = "fa-solid fa-calendar-days"
                    },
                    new()
                    {
                        Name = "toDate",
                        Label = "إلى تاريخ",
                        Type = "date",
                        ColCss = "3",
                        Value = toDate ?? "",
                        Icon = "fa-solid fa-calendar-check"
                    }
                },
                Buttons = new List<FormButtonConfig>
                {
                    new()
                    {
                        Text = "بحث",
                        Type = "button",
                        Color = "info",
                        Icon = "fa-solid fa-magnifying-glass",
                        OnClickJs = @"
                            const form = document.getElementById('custodyFilterForm');
                            const query = new URLSearchParams();
                            ['chassisNumber', 'generalNo', 'fromDate', 'toDate'].forEach(name => {
                                const value = form?.querySelector(`[name='${name}']`)?.value?.trim();
                                if (value) query.set(name, value);
                            });
                            window.location.href = '/Vehicle/Custody' + (query.toString() ? '?' + query.toString() : '');
                        "
                    },
                    new()
                    {
                        Text = "إعادة تعيين",
                        Type = "button",
                        Color = "secondary",
                        Icon = "fa-solid fa-rotate-right",
                        OnClickJs = "window.location.href = '/Vehicle/Custody';"
                    }
                }
            };

            // التبويب الأول: العهود النشطة
            var dsModelCustody = new SmartTableDsModel
            {
                PageTitle  = "إدارة العهد",
                PanelTitle = "العهود النشطة",
                Columns    = custodyColumns,
                Rows       = custodyRows,
                RowIdField = "vehicleWithUsersID",
                PageSize   = 10,
                PageSizes  = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = custodyColumns.Where(c => c.Visible).Select(c => c.Field).Take(6).ToList(),

                Searchable           = true,
                AllowExport          = true,
                ShowRowBorders       = true,
                EnablePagination     = true,
                ShowPageSizeSelector = true,
                ShowToolbar          = true,
                EnableCellCopy       = true,
                ShowFilter           = true,
                FilterRow            = true,
                FilterDebounce       = 250,
                ShowColumnVisibility = true,

                RenderMode       = SmartTableRenderMode.Tab,
                RenderAsTab      = true,
                TabGroupKey      = "custody-page",
                TabKey           = "active-custody",
                TabLabel         = "العهود النشطة",
                TabIcon          = "fa-solid fa-key",
                TabDefaultActive = true,
                ShowTabCount     = true,
                TabOrder         = 1,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh     = false,
                    ShowColumns     = true,
                    ShowExportCsv   = false,
                    ShowExportExcel = true,
                    ShowExportPdf   = false,
                    ShowPrint1      = true,
                    ShowBulkDelete  = false,
                    ShowAdd         = canInsertCustody,
                    ShowEdit        = false,
                    ShowDelete      = false,
                    CustomActions   = custodyCustomActions,

                    // زر الطباعة (PDF)
                    Print1 = new TableAction
                    {
                        Label            = "طباعة",
                        Icon             = "fa fa-print",
                        Color            = "info",
                        RequireSelection = false,
                        OnClickJs        = "sfPrintWithBusy(table, { pdf: 1, busy: { title: 'طباعة بيانات العهد النشطة' } });"
                    },

                    // زر الإضافة (يظهر فقط لمن يملك INSERTCUSTODY)
                    Add = canInsertCustody ? new TableAction
                    {
                        Label            = "إنشاء عهدة",
                        Icon             = "fa fa-plus-circle",
                        Color            = "success",
                        OpenModal        = true,
                        RequireSelection = false,
                        ModalTitle       = "<i class='fa-solid fa-key text-emerald-600 text-xl mr-2'></i> إنشاء عهدة جديدة",
                        OpenForm = new FormConfig
                        {
                            FormId    = "InsertCustodyForm",
                            Title     = "بيانات عهدة جديدة",
                            Method    = "post",
                            ActionUrl = "/crud/insert",
                            Fields    = addCustodyFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    } : null,
                },
            };

            // التبويب الثاني: سجل العهد
            var dsModelHistory = new SmartTableDsModel
            {
                PageTitle  = "إدارة العهد",
                PanelTitle = "سجل العهد",
                Columns    = historyColumns,
                Rows       = historyRows,
                RowIdField = "vehicleWithUsersID",
                PageSize   = 10,
                PageSizes  = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = historyColumns.Where(c => c.Visible).Select(c => c.Field).Take(5).ToList(),

                Searchable           = true,
                AllowExport          = true,
                ShowRowBorders       = true,
                EnablePagination     = true,
                ShowPageSizeSelector = true,
                ShowToolbar          = true,
                EnableCellCopy       = true,
                ShowFilter           = true,
                FilterRow            = true,
                FilterDebounce       = 250,
                ShowColumnVisibility = true,

                RenderMode       = SmartTableRenderMode.Tab,
                RenderAsTab      = true,
                TabGroupKey      = "custody-page",
                TabKey           = "custody-history",
                TabLabel         = "السجل",
                TabIcon          = "fa-solid fa-clock-rotate-left",
                TabDefaultActive = false,
                TabOrder         = 2,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh     = false,
                    ShowColumns     = true,
                    ShowExportCsv   = false,
                    ShowExportExcel = true,
                    ShowExportPdf   = false,
                    ShowPrint1      = true,
                    ShowBulkDelete  = false,
                    ShowAdd         = false,
                    ShowEdit        = false,
                    ShowDelete      = false,
                    CustomActions   = new List<TableAction>(),

                    // زر الطباعة (PDF)
                    Print1 = new TableAction
                    {
                        Label            = "طباعة",
                        Icon             = "fa fa-print",
                        Color            = "info",
                        RequireSelection = false,
                        OnClickJs        = "sfPrintWithBusy(table, { pdf: 2, busy: { title: 'طباعة سجل العهد' } });"
                    },
                },
            };

            // ── 10) إرجاع الصفحة ───────────────────────────────────

            var page = new SmartPageViewModel
            {
                PageTitle  = dsModelCustody.PageTitle,
                PanelTitle = dsModelCustody.PanelTitle,
                PanelIcon  = "fa-solid fa-key",
                Form       = filterForm,
                TableDS    = dsModelCustody,
                TableDS1   = dsModelHistory,
            };

            return View("Page/Custody", page);
        }
    }
}
