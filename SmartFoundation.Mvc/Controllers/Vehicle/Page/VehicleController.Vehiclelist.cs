using Microsoft.AspNetCore.Mvc;
using SmartFoundation.MVC.Reports;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartPrint;
using SmartFoundation.UI.ViewModels.SmartDrawer;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.IO;
using System.Linq;

namespace SmartFoundation.Mvc.Controllers.Vehicle
{
    public partial class VehicleController : Controller
    {
        // ═══════════════════════════════════════════════════════════════
        //  صفحة قائمة المركبات (VehicleList)
        //  تعرض 3 تبويبات: المركبات / التأمينات / الوثائق
        //  تدعم: بحث، فلترة، إضافة/تعديل، طباعة PDF، وتصدير Excel
        // ═══════════════════════════════════════════════════════════════
        public async Task<IActionResult> Vehiclelist(
              string? ownerID_FK = null
            , string? plateLetters = null
            , string? plateNumbers = null
            , string? hasCustody = null
            , int pageNumber = 1
            , int pageSize = 50
            , int? pdf = null
        )
        {
            // ── تهيئة السياق والصلاحيات ──────────────────────────────
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = "Vehicle";
            PageName = "Vehiclelist";

            var currentUrl = Request.Path + Request.QueryString;

            // ── تجهيز بارامترات الاستدعاءات المتوازية ─────────────────
            // كل استدعاء يمر عبر Gateway (Masters_DataLoad) ثم يُوجَّه للـ SP المناسب

            var vehicleParams = new object?[]
            {
                PageName, IdaraId, usersId, HostName,
                string.IsNullOrWhiteSpace(ownerID_FK) ? null : ownerID_FK,
                string.IsNullOrWhiteSpace(plateLetters) ? null : plateLetters,
                string.IsNullOrWhiteSpace(plateNumbers) ? null : plateNumbers,
                string.IsNullOrWhiteSpace(hasCustody) ? null : hasCustody,
                pageNumber, pageSize,
                IdaraId
            };

            var insuranceParams = new object?[]
            {
                "VehicleInsurance_List", IdaraId, usersId, HostName,
                null, null, null, 1, null, null,
                1, 50, null, null, IdaraId
            };

            var documentParams = new object?[]
            {
                "VehicleDocuments_List", IdaraId, usersId, HostName,
                null, 1, 50, IdaraId
            };

            // ── تحميل كل البيانات بالتوازي (17 استدعاء في وقت واحد) ───
            // يشمل: بيانات المركبات، التأمينات، الوثائق، وكل قوائم Lookup (الأنواع)
            var vehicleTask = _mastersServies.GetDataLoadDataSetAsync(vehicleParams);
            var insuranceTask = _mastersServies.GetDataLoadDataSetAsync(insuranceParams);
            var documentTask = _mastersServies.GetDataLoadDataSetAsync(documentParams);
            var ownerTask = LoadTypesRootLookup(1);
            var manufacturerTask = LoadTypesRootLookup(2);
            var modelTask = LoadTypesRootLookup(3);
            var classTask = LoadTypesRootLookup(4);
            var useTypeTask = LoadTypesRootLookup(5);
            var colorTask = LoadTypesRootLookup(6);
            var countryTask = LoadTypesRootLookup(7);
            var registrationTask = LoadTypesRootLookup(8);
            var regionTask = LoadTypesRootLookup(9);
            var fuelTask = LoadTypesRootLookup(172);
            var vehicleTypeTask = LoadTypesRootLookup(175);
            var insuranceTypeTask = LoadTypesRootLookup(203);
            var operationTypeTask = LoadTypesRootLookup(199);
            var documentTypeTask = LoadDocumentTypeLookup();

            await Task.WhenAll(
                vehicleTask, insuranceTask, documentTask,
                ownerTask, manufacturerTask, modelTask, classTask, useTypeTask,
                colorTask, countryTask, registrationTask, regionTask, fuelTask,
                vehicleTypeTask, insuranceTypeTask, operationTypeTask, documentTypeTask
            );

            // ── فصل Result Sets الخاصة ببيانات المركبات ───────────────
            DataSet ds = vehicleTask.Result;
            SplitDataSet(ds);

            // ── استخراج الصلاحيات من permissionTable ──────────────────
            bool canAccess = false;
            bool canSelect = false;
            bool canVehicleInsert = false;
            bool canVehicleUpdate = false;
            bool canVehicleGet = false;
            bool canInsuranceInsert = false;
            bool canInsuranceUpdate = false;
            bool canDocumentInsert = false;
            bool canDocumentUpdate = false;

            var vehicleColumns = new List<TableColumn>();
            var vehicleRows = new List<Dictionary<string, object?>>();
            var chassisOptions = new List<OptionItem>();
            string rowIdField = "chassisNumber";

            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable != null && permissionTable.Rows.Count > 0)
                {
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var p = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (p == "ACCESS") canAccess = true;
                        if (p == "SELECT") canSelect = true;
                        if (p == "VEHICLE_UPSERT_INSERT") canVehicleInsert = true;
                        if (p == "VEHICLE_UPSERT_UPDATE") canVehicleUpdate = true;
                        if (p == "VEHICLE_GET") canVehicleGet = true;
                        if (p == "VEHICLEINSURANCE_UPSERT_INSERT") canInsuranceInsert = true;
                        if (p == "VEHICLEINSURANCE_UPSERT_UPDATE") canInsuranceUpdate = true;
                        if (p == "VEHICLEDOCUMENT_UPSERT_INSERT") canDocumentInsert = true;
                        if (p == "VEHICLEDOCUMENT_UPSERT_UPDATE") canDocumentUpdate = true;
                    }

                    if (!canAccess && !canSelect)
                    {
                        TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                        return RedirectToAction("Index", "Home");
                    }

                    // ── تجهيز بيانات جدول المركبات ───────────────────────
                    var vehicleData = dt2 ?? dt1;

                    // بناء فلتر حالة المركبة ديناميكيًا من البيانات (نمط Housing)
                    var statusFilterOpts = new List<OptionItem>();
                    if (vehicleData != null && vehicleData.Columns.Contains("vehicleStatusName"))
                    {
                        statusFilterOpts = vehicleData.AsEnumerable()
                            .Select(r => r["vehicleStatusName"] == DBNull.Value ? "" : r["vehicleStatusName"]?.ToString()?.Trim())
                            .Where(s => !string.IsNullOrWhiteSpace(s))
                            .Distinct()
                            .OrderBy(s => s)
                            .Select(s => new OptionItem { Value = s!, Text = s! })
                            .ToList();
                    }

                    // تعريف أعمدة جدول المركبات
                    vehicleColumns = new List<TableColumn>
                    {
                        new TableColumn
                        {
                            Field = "chassisNumber",
                            Label = "رقم الهيكل",
                            Sortable = true,
                            Visible = true,
                            Type = canVehicleGet ? "link" : "text",
                            LinkTemplate = canVehicleGet
                                ? "#sf-drawer:sf-vehicle-details-drawer:/Vehicle/VehicleDetailsDrawer?chassisNumber={chassisNumberUrl}"
                                : null
                        },
                        new TableColumn { Field = "plateLetters", Label = "حروف اللوحة", Sortable = true, Visible = true },
                        new TableColumn { Field = "plateNumbers", Label = "أرقام اللوحة", Sortable = true, Visible = true },
                        new TableColumn { Field = "armyNumber", Label = "الرقم العسكري", Sortable = true, Visible = true },
                        new TableColumn { Field = "yearModel", Label = "سنة الصنع", Sortable = true, Visible = true },
                        new TableColumn { Field = "ownerName", Label = "المالك", Sortable = true, Visible = true },
                        new TableColumn { Field = "manufacturerName", Label = "الشركة المصنعة", Sortable = true, Visible = true },
                        new TableColumn { Field = "modelName", Label = "الموديل", Sortable = true, Visible = true },
                        new TableColumn { Field = "colorName", Label = "اللون", Sortable = true, Visible = true },
                        new TableColumn { Field = "vehicleStatusName", Label = "حالة المركبة", Sortable = true, Visible = true, Filter = new TableColumnFilter
                        {
                            Type = "select",
                            Placeholder = "الكل",
                            Options = statusFilterOpts
                        } },
                        new TableColumn { Field = "isActiveText", Label = "حالة السجل", Sortable = true, Visible = false },
                        new TableColumn { Field = "CurrentUserDisplay", Label = "المستخدم الحالي", Sortable = true, Visible = true },
                        new TableColumn { Field = "CustodyStartDateText", Label = "تاريخ بداية العهدة", Sortable = true, Visible = true },
                        new TableColumn { Field = "custodyStatusText", Label = "حالة العهدة", Sortable = true, Visible = true, Filter = new TableColumnFilter
                        {
                            Type = "select",
                            Placeholder = "الكل",
                            Options = new List<OptionItem>
                            {
                                new OptionItem { Value = "عهدة نشطة", Text = "عهدة نشطة" },
                                new OptionItem { Value = "بدون عهدة", Text = "بدون عهدة" },
                            }
                        } },
                    };

                    // تحويل صفوف الـ DataTable إلى قائمة Dictionary للعرض
                    // مع حساب الأعمدة النصية (fallback لو لم تأتِ من الـ SP)
                    if (vehicleData != null && vehicleData.Columns.Count > 0)
                    {
                        foreach (DataRow r in vehicleData.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in vehicleData.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;

                            var hasCustodyUser = !string.IsNullOrWhiteSpace(Get("CurrentUserID")?.ToString());

                            // أعمدة عرض محسوبة (fallback من C# إذا لم تأتِ من SP)
                            dict["isActiveText"] = Get("isActiveText")?.ToString()
                                ?? ((Get("isActive")?.ToString() == "1") ? "مفعل" : "موقوف");
                            dict["custodyStatusText"] = Get("custodyStatusText")?.ToString()
                                ?? (hasCustodyUser ? "عهدة نشطة" : "بدون عهدة");
                            dict["CustodyStartDateText"] = Get("CustodyStartDateText")?.ToString()
                                ?? NormalizeDateForInput(Get("CustodyStartDate")) ?? "لا يوجد";
                            dict["CurrentUserDisplay"] = Get("CurrentUserDisplay")?.ToString() ?? "لا يوجد مستخدم";
                            dict["chassisNumberUrl"] = Uri.EscapeDataString(Get("chassisNumber")?.ToString() ?? "");

                            // حقول مخفية (p01..p19) تُستخدم لتعبئة نموذج التعديل تلقائيًا
                            dict["p01"] = Get("chassisNumber");
                            dict["p02"] = Get("ownerID_FK");
                            dict["p03"] = Get("ManufacturerNameID_FK");
                            dict["p04"] = Get("vehicleModelID_FK");
                            dict["p05"] = Get("vehicleClassID_FK");
                            dict["p06"] = Get("TypeOfUseID_FK");
                            dict["p07"] = Get("vehicleColorID_FK");
                            dict["p08"] = Get("countryMadeID_FK");
                            dict["p09"] = Get("regstritionTypeID_FK");
                            dict["p10"] = Get("regionID_FK");
                            dict["p11"] = Get("fuelTypeID_FK");
                            dict["p12"] = Get("vehicleTypeID_FK");
                            dict["p13"] = Get("yearModel");
                            dict["p14"] = Get("capacity");
                            dict["p15"] = Get("serialNumber");
                            dict["p16"] = Get("plateLetters");
                            dict["p17"] = Get("plateNumbers");
                            dict["p18"] = Get("armyNumber");
                            dict["p19"] = Get("vehicleNote");

                            vehicleRows.Add(dict);
                        }

                        // بناء قائمة أرقام الهيكل لاستخدامها في نماذج الإضافة (Select2)
                        var chassisCol = vehicleData.Columns.Contains("chassisNumber")
                            ? "chassisNumber" : vehicleData.Columns[0].ColumnName;
                        chassisOptions = vehicleData.AsEnumerable()
                            .Select(r => r[chassisCol] == DBNull.Value ? "" : r[chassisCol]?.ToString())
                            .Where(x => !string.IsNullOrWhiteSpace(x))
                            .Distinct()
                            .OrderBy(x => x)
                            .Select(x => new OptionItem { Value = x!, Text = x! })
                            .ToList();
                    }
                }
            }
            catch (Exception ex)
            {
                TempData["DataSetError"] = ex.Message;
            }

            // ═══════════════════════════════════════════════════════════════
            //  تبويب التأمينات — قراءة الأعمدة + بناء التنبيهات
            // ═══════════════════════════════════════════════════════════════
            var insData = (insuranceTask.Result?.Tables?.Count ?? 0) > 1 ? insuranceTask.Result!.Tables[1] : null;

            var insuranceColumns = new List<TableColumn>
            {
                new TableColumn { Field = "VehicleInsuranceID", Label = "ID", Sortable = true, Visible = false },
                new TableColumn { Field = "vehicleID", Label = "VehicleID", Sortable = false, Visible = false },
                new TableColumn { Field = "chassisNumber_FK", Label = "رقم الهيكل", Sortable = true, Visible = true },
                new TableColumn { Field = "plateLetters", Label = "حروف اللوحة", Sortable = true, Visible = true },
                new TableColumn { Field = "plateNumbers", Label = "أرقام اللوحة", Sortable = true, Visible = true },
                new TableColumn { Field = "InsuranceOpertionTypeName", Label = "نوع العملية", Sortable = true, Visible = true },
                new TableColumn { Field = "InsuranceTypeName", Label = "نوع التأمين", Sortable = true, Visible = true },
                new TableColumn { Field = "Source", Label = "المصدر", Sortable = true, Visible = true },
                new TableColumn { Field = "StartInsuranceText", Label = "بداية التأمين", Sortable = true, Visible = true },
                new TableColumn { Field = "EndInsuranceText", Label = "نهاية التأمين", Sortable = true, Visible = true },
                new TableColumn { Field = "Amount", Label = "المبلغ", Sortable = true, Visible = true },
                new TableColumn { Field = "InsuranceStatusText", Label = "الحالة", Sortable = true, Visible = true },
                new TableColumn { Field = "Note", Label = "ملاحظات", Sortable = true, Visible = true },
            };

            var insuranceRows = new List<Dictionary<string, object?>>();

            if (insData != null && insData.Columns.Count > 0)
            {
                foreach (DataRow r in insData.Rows)
                {
                    var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                    foreach (DataColumn c in insData.Columns)
                    {
                        var val = r[c];
                        dict[c.ColumnName] = val == DBNull.Value ? null : val;
                    }

                    object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;

                    dict["StartInsuranceText"] = NormalizeDateForInput(Get("StartInsurance"));
                    dict["EndInsuranceText"] = NormalizeDateForInput(Get("EndInsurance"));
                    dict["InsuranceStatusText"] = Get("InsuranceStatus")?.ToString() ?? "غير محدد";

                    dict["p01"] = Get("VehicleInsuranceID");
                    dict["p02"] = Get("chassisNumber_FK");
                    dict["p03"] = Get("InsuranceOpertionType_FK");
                    dict["p04"] = Get("InsuranceTypeID_FK");
                    dict["p05"] = Get("Source");
                    dict["p06"] = NormalizeDateForInput(Get("StartInsurance"));
                    dict["p07"] = NormalizeDateForInput(Get("EndInsurance"));
                    dict["p08"] = Get("Amount");
                    dict["p09"] = Get("Note");
                    dict["p10"] = Get("active");

                    insuranceRows.Add(dict);
                }
            }

            // ── حساب تنبيهات التأمين (منتهي / يقارب الانتهاء) ──────────
            var insExpiredCount = insuranceRows.Count(r =>
                r.TryGetValue("InsuranceStatusCode", out var sc) && sc?.ToString() == "expired");
            var insExpiringCount = insuranceRows.Count(r =>
                r.TryGetValue("InsuranceStatusCode", out var sc) && sc?.ToString() == "expiring");

            var insAlertParts = new List<string>();
            if (insExpiredCount > 0)
                insAlertParts.Add($"<span class='text-red-700 font-bold'>{insExpiredCount} تأمين منتهي</span>");
            if (insExpiringCount > 0)
                insAlertParts.Add($"<span class='text-orange-600 font-bold'>{insExpiringCount} تأمين يقارب الانتهاء</span>");
            var insAlertHtml = insAlertParts.Count > 0
                ? $"<div class='flex items-center gap-4 rounded-md bg-yellow-50 border border-yellow-300 px-4 py-2 mb-2 text-sm'><i class='fa-solid fa-triangle-exclamation text-yellow-500'></i><span>{string.Join(" &bull; ", insAlertParts)}</span></div>"
                : null;

            // ═══════════════════════════════════════════════════════════════
            //  تبويب الوثائق — قراءة الأعمدة + بناء التنبيهات
            // ═══════════════════════════════════════════════════════════════
            var docData = (documentTask.Result?.Tables?.Count ?? 0) > 1 ? documentTask.Result!.Tables[1] : null;

            var documentColumns = new List<TableColumn>
            {
                new TableColumn { Field = "vehicleDocumentID", Label = "ID", Sortable = true, Visible = false },
                new TableColumn { Field = "vehicleID", Label = "VehicleID", Sortable = false, Visible = false },
                new TableColumn { Field = "chassisNumber_FK", Label = "رقم الهيكل", Sortable = true, Visible = true },
                new TableColumn { Field = "vehicleDocumentTypeName_A", Label = "نوع الوثيقة", Sortable = true, Visible = true },
                new TableColumn { Field = "vehicleDocumentNo", Label = "رقم الوثيقة", Sortable = true, Visible = true },
                new TableColumn { Field = "StartDateText", Label = "تاريخ البداية", Sortable = true, Visible = true },
                new TableColumn { Field = "EndDateText", Label = "تاريخ النهاية", Sortable = true, Visible = true },
                new TableColumn { Field = "DocumentStatusText", Label = "الحالة", Sortable = true, Visible = true },
                new TableColumn { Field = "plateLetters", Label = "حروف اللوحة", Sortable = true, Visible = true },
                new TableColumn { Field = "plateNumbers", Label = "أرقام اللوحة", Sortable = true, Visible = true },
            };

            var documentRows = new List<Dictionary<string, object?>>();

            if (docData != null && docData.Columns.Count > 0)
            {
                string? prevChassis = null;
                foreach (DataRow r in docData.Rows)
                {
                    var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                    foreach (DataColumn c in docData.Columns)
                    {
                        var val = r[c];
                        dict[c.ColumnName] = val == DBNull.Value ? null : val;
                    }

                    object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;

                    dict["StartDateText"] = NormalizeDateForInput(Get("vehicleDocumentStartDate"));
                    dict["EndDateText"] = NormalizeDateForInput(Get("vehicleDocumentEndDate"));
                    dict["DocumentStatusText"] = Get("DocumentStatus")?.ToString() ?? "غير محدد";

                    // فاصل بصري عند تغير رقم الهيكل (تجميع الوثائق حسب المركبة)
                    var currentChassis = Get("chassisNumber_FK")?.ToString();
                    dict["IsGroupStart"] = prevChassis != null && currentChassis != prevChassis ? "true" : "false";
                    prevChassis = currentChassis;

                    dict["p01"] = Get("vehicleDocumentID");
                    dict["p02"] = Get("chassisNumber_FK");
                    dict["p03"] = Get("vehicleDocumentTypeID_FK");
                    dict["p04"] = Get("vehicleDocumentNo");
                    dict["p05"] = NormalizeDateForInput(Get("vehicleDocumentStartDate"));
                    dict["p06"] = NormalizeDateForInput(Get("vehicleDocumentEndDate"));

                    documentRows.Add(dict);
                }
            }

            // ── حساب تنبيهات الوثائق (منتهية / تقارب الانتهاء) ─────────
            var docExpiredCount = documentRows.Count(r =>
                r.TryGetValue("DocumentStatusCode", out var sc) && sc?.ToString() == "expired");
            var docExpiringCount = documentRows.Count(r =>
                r.TryGetValue("DocumentStatusCode", out var sc) && sc?.ToString() == "expiring");

            var docAlertParts = new List<string>();
            if (docExpiredCount > 0)
                docAlertParts.Add($"<span class='text-red-700 font-bold'>{docExpiredCount} وثيقة منتهية</span>");
            if (docExpiringCount > 0)
                docAlertParts.Add($"<span class='text-orange-600 font-bold'>{docExpiringCount} وثيقة تقارب الانتهاء</span>");
            var docAlertHtml = docAlertParts.Count > 0
                ? $"<div class='flex items-center gap-4 rounded-md bg-yellow-50 border border-yellow-300 px-4 py-2 mb-2 text-sm'><i class='fa-solid fa-triangle-exclamation text-yellow-500'></i><span>{string.Join(" &bull; ", docAlertParts)}</span></div>"
                : null;

            // ═══════════════════════════════════════════════════════════════
            //  قوائم Lookup — فك نتائج الاستدعاءات المتوازية
            // ═══════════════════════════════════════════════════════════════
            var ownerOptions = ownerTask.Result;
            var manufacturerOptions = manufacturerTask.Result;
            var modelOptions = modelTask.Result;
            var classOptions = classTask.Result;
            var useTypeOptions = useTypeTask.Result;
            var colorOptions = colorTask.Result;
            var countryOptions = countryTask.Result;
            var registrationOptions = registrationTask.Result;
            var regionOptions = regionTask.Result;
            var fuelOptions = fuelTask.Result;
            var vehicleTypeOptions = vehicleTypeTask.Result;
            var documentTypeOptions = documentTypeTask.Result;
            var insuranceTypeOptions = insuranceTypeTask.Result;
            var operationTypeOptionsRaw = operationTypeTask.Result;
            // فلترة أنواع العمليات (ID >= 284 فقط لأنواع التأمين)
            var operationTypeOptions = operationTypeOptionsRaw.Where(o =>
            {
                if (int.TryParse(o.Value, out int id)) return id >= 284;
                return true;
            }).ToList();

            // ═══════════════════════════════════════════════════════════════
            //  تعريف نماذج الإضافة والتعديل (Forms)
            //  الحقول المخفية تشمل: pageName_, ActionType, idaraID,
            //  entrydata, hostname, redirectUrl, CSRF token
            // ═══════════════════════════════════════════════════════════════
            var vehicleInsertFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "Vehiclelist" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "VEHICLE_UPSERT_INSERT" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "" },

                new FieldConfig { Name = "p01", Label = "رقم الهيكل", Type = "text", ColCss = "4", Required = true },
                BuildTypesRootField("p02", "المالك", ownerOptions),
                BuildTypesRootField("p03", "الشركة المصنعة", manufacturerOptions),
                BuildTypesRootField("p04", "موديل المركبة", modelOptions),
                BuildTypesRootField("p05", "فئة المركبة", classOptions),
                BuildTypesRootField("p06", "نوع الاستخدام", useTypeOptions),
                BuildTypesRootField("p07", "لون المركبة", colorOptions),
                BuildTypesRootField("p08", "بلد الصنع", countryOptions),
                BuildTypesRootField("p09", "نوع التسجيل", registrationOptions),
                BuildTypesRootField("p10", "المنطقة", regionOptions),
                BuildTypesRootField("p11", "نوع الوقود", fuelOptions),
                BuildTypesRootField("p12", "نوع المركبة", vehicleTypeOptions),
                new FieldConfig { Name = "p13", Label = "سنة الصنع", Type = "number", ColCss = "4" },
                new FieldConfig { Name = "p14", Label = "السعة", Type = "number", ColCss = "4" },
                new FieldConfig { Name = "p15", Label = "الرقم التسلسلي", Type = "text", ColCss = "4" },
                new FieldConfig { Name = "p16", Label = "حروف اللوحة", Type = "text", ColCss = "4" },
                new FieldConfig { Name = "p17", Label = "أرقام اللوحة", Type = "number", ColCss = "4" },
                new FieldConfig { Name = "p18", Label = "الرقم العسكري", Type = "text", ColCss = "4" },
                new FieldConfig { Name = "p19", Label = "الملاحظات", Type = "textarea", ColCss = "12", MaxLength = 400 },
            };

            var vehicleUpdateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "Vehiclelist" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "VEHICLE_UPSERT_UPDATE" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "" },

                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "chassisNumber" },
                BuildTypesRootField("p02", "المالك", ownerOptions),
                BuildTypesRootField("p03", "الشركة المصنعة", manufacturerOptions),
                BuildTypesRootField("p04", "موديل المركبة", modelOptions),
                BuildTypesRootField("p05", "فئة المركبة", classOptions),
                BuildTypesRootField("p06", "نوع الاستخدام", useTypeOptions),
                BuildTypesRootField("p07", "لون المركبة", colorOptions),
                BuildTypesRootField("p08", "بلد الصنع", countryOptions),
                BuildTypesRootField("p09", "نوع التسجيل", registrationOptions),
                BuildTypesRootField("p10", "المنطقة", regionOptions),
                BuildTypesRootField("p11", "نوع الوقود", fuelOptions),
                BuildTypesRootField("p12", "نوع المركبة", vehicleTypeOptions),
                new FieldConfig { Name = "p13", Label = "سنة الصنع", Type = "number", ColCss = "4" },
                new FieldConfig { Name = "p14", Label = "السعة", Type = "number", ColCss = "4" },
                new FieldConfig { Name = "p15", Label = "الرقم التسلسلي", Type = "text", ColCss = "4" },
                new FieldConfig { Name = "p16", Label = "حروف اللوحة", Type = "text", ColCss = "4" },
                new FieldConfig { Name = "p17", Label = "أرقام اللوحة", Type = "number", ColCss = "4" },
                new FieldConfig { Name = "p18", Label = "الرقم العسكري", Type = "text", ColCss = "4" },
                new FieldConfig { Name = "p19", Label = "الملاحظات", Type = "textarea", ColCss = "12", MaxLength = 400 },
            };

            var insuranceUpsertFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "Vehiclelist" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "VEHICLEINSURANCE_UPSERT_INSERT" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "" },

                new FieldConfig { Name = "p01", Type = "hidden", Value = "0" },
                new FieldConfig
                {
                    Name = "p02",
                    Label = "رقم الهيكل",
                    Type = "select",
                    ColCss = "6",
                    Required = true,
                    Select2 = true,
                    Placeholder = "ابحث برقم الهيكل",
                    Options = chassisOptions
                },
                BuildTypesRootField("p03", "نوع العملية", operationTypeOptions),
                BuildTypesRootField("p04", "نوع التأمين", insuranceTypeOptions),
                new FieldConfig { Name = "p05", Label = "المصدر", Type = "text", ColCss = "6" },
                new FieldConfig { Name = "p06", Label = "بداية التأمين", Type = "date", ColCss = "6" },
                new FieldConfig { Name = "p07", Label = "نهاية التأمين", Type = "date", ColCss = "6" },
                new FieldConfig { Name = "p08", Label = "المبلغ", Type = "number", ColCss = "6" },
                new FieldConfig { Name = "p09", Label = "ملاحظات", Type = "textarea", ColCss = "12", MaxLength = 800 },
            };

            var insuranceUpdateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "Vehiclelist" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "VEHICLEINSURANCE_UPSERT_UPDATE" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "" },

                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig
                {
                    Name = "p02",
                    Label = "رقم الهيكل",
                    Type = "select",
                    ColCss = "6",
                    Required = true,
                    Select2 = true,
                    Placeholder = "ابحث برقم الهيكل",
                    Options = chassisOptions
                },
                BuildTypesRootField("p03", "نوع العملية", operationTypeOptions),
                BuildTypesRootField("p04", "نوع التأمين", insuranceTypeOptions),
                new FieldConfig { Name = "p05", Label = "المصدر", Type = "text", ColCss = "6" },
                new FieldConfig { Name = "p06", Label = "بداية التأمين", Type = "date", ColCss = "6" },
                new FieldConfig { Name = "p07", Label = "نهاية التأمين", Type = "date", ColCss = "6" },
                new FieldConfig { Name = "p08", Label = "المبلغ", Type = "number", ColCss = "6" },
                new FieldConfig { Name = "p09", Label = "ملاحظات", Type = "textarea", ColCss = "12", MaxLength = 800 },
            };

            var documentInsertFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "Vehiclelist" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "VEHICLEDOCUMENT_UPSERT_INSERT" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "" },

                new FieldConfig
                {
                    Name = "p01",
                    Label = "رقم الهيكل",
                    Type = "select",
                    ColCss = "6",
                    Required = true,
                    Select2 = true,
                    Placeholder = "ابحث برقم الهيكل",
                    Options = chassisOptions
                },
                new FieldConfig
                {
                    Name = "p02",
                    Label = "نوع الوثيقة",
                    Type = "select",
                    ColCss = "6",
                    Required = true,
                    Select2 = true,
                    Placeholder = "اختر نوع الوثيقة",
                    Options = documentTypeOptions
                },
                new FieldConfig { Name = "p03", Label = "رقم الوثيقة", Type = "text", ColCss = "6", Required = true },
                new FieldConfig { Name = "p04", Label = "تاريخ البداية", Type = "date", ColCss = "6" },
                new FieldConfig { Name = "p05", Label = "تاريخ النهاية", Type = "date", ColCss = "6" },
            };

            var documentUpdateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_", Type = "hidden", Value = "Vehiclelist" },
                new FieldConfig { Name = "ActionType", Type = "hidden", Value = "VEHICLEDOCUMENT_UPSERT_UPDATE" },
                new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraId },
                new FieldConfig { Name = "entrydata", Type = "hidden", Value = usersId },
                new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName },
                new FieldConfig { Name = "redirectUrl", Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "" },

                new FieldConfig { Name = "p01", Type = "hidden" },
                new FieldConfig
                {
                    Name = "p02",
                    Label = "رقم الهيكل",
                    Type = "select",
                    ColCss = "6",
                    Required = true,
                    Select2 = true,
                    Placeholder = "ابحث برقم الهيكل",
                    Options = chassisOptions
                },
                new FieldConfig
                {
                    Name = "p03",
                    Label = "نوع الوثيقة",
                    Type = "select",
                    ColCss = "6",
                    Required = true,
                    Select2 = true,
                    Placeholder = "اختر نوع الوثيقة",
                    Options = documentTypeOptions
                },
                new FieldConfig { Name = "p04", Label = "رقم الوثيقة", Type = "text", ColCss = "6", Required = true },
                new FieldConfig { Name = "p05", Label = "تاريخ البداية", Type = "date", ColCss = "6" },
                new FieldConfig { Name = "p06", Label = "تاريخ النهاية", Type = "date", ColCss = "6" },
            };

            // ═══════════════════════════════════════════════════════════════
            //  بناء نموذج جدول المركبات (dsModelVehicle)
            //  — تبويب افتراضي نشط، يحتوي:
            //    • الأعمدة + الصفوف
            //    • دليل الألوان (Legend) أعلى الجدول
            //    • قواعد التلوين (StyleRules) لحالة المركبة والعهدة والتأمين/الوثائق
            //    • أزرار: إضافة، تعديل، طباعة
            //    • رقم الهيكل يفتح تفاصيل المركبة داخل SmartDrawer
            // ═══════════════════════════════════════════════════════════════

            var dsModelVehicle = new SmartTableDsModel
            {
                PageTitle = "المركبات",
                PanelTitle = "المركبات",
                Columns = vehicleColumns,
                Rows = vehicleRows,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = vehicleColumns.Where(c => c.Visible).Select(c => c.Field).Take(6).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowRowBorders = true,
                EnablePagination = true,
                ShowPageSizeSelector = true,
                ShowToolbar = true,
                EnableCellCopy = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                ShowColumnVisibility = true,

                // ── إعدادات التبويب ─────────────────────────────────────
                RenderMode = SmartTableRenderMode.Tab,
                RenderAsTab = true,
                TabGroupKey = "vehicles-page",
                TabKey = "vehicles",
                TabLabel = "المركبات",
                TabIcon = "fa-solid fa-car",
                TabDefaultActive = true,
                ShowTabCount = true,
                TabOrder = 1,
                // دليل الألوان (Legend) — يُعرض أعلى الجدول بعد إصلاح عرض TabDescription
                TabDescription = "<div class='flex items-center gap-3 px-4 py-2 mb-2 text-xs'><span class='badge badge-danger'>لا يوجد تأمين ولا وثائق</span><span class='badge' style='background:#f3eefc;border-color:#c4b5fd;color:#6b21a8'>لا توجد وثائق</span><span class='badge badge-warning'>لا يوجد تأمين</span></div>",

                // ── شريط الأدوات (Toolbar) ───────────────────────────────
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = true,
                    ShowExportPdf = false,
                    ShowPrint1 = true,
                    ShowBulkDelete = false,
                    ShowAdd = canVehicleInsert,
                    ShowEdit = canVehicleUpdate,
                    ShowDelete = false,
                    CustomActions = new List<TableAction>(),
                    Drawers = canVehicleGet
                        ? new List<SmartDrawerConfig>
                        {
                            new SmartDrawerConfig
                            {
                                Id = "sf-vehicle-details-drawer",
                                Show = true,
                                Title = "تفاصيل المركبة",
                                Subtitle = "اختر رقم هيكل لعرض التفاصيل",
                                Icon = "fa-solid fa-car",
                                Side = SmartDrawerSide.Right,
                                Size = SmartDrawerSize.Large,
                                EmptyText = "اختر رقم هيكل لعرض تفاصيل المركبة"
                            }
                        }
                        : new List<SmartDrawerConfig>(),

                    // زر: إضافة مركبة جديدة (Modal)
                    Add = new TableAction
                    {
                        Label = "إضافة مركبة",
                        Icon = "fa fa-plus-circle",
                        Color = "success",
                        OpenModal = true,
                        RequireSelection = false,
                        ModalTitle = "<i class='fa-solid fa-car text-emerald-600 text-xl mr-2'></i> إضافة مركبة",
                        OpenForm = new FormConfig
                        {
                            FormId = "InsertVehicleForm",
                            Title = "بيانات مركبة جديدة",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = vehicleInsertFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },

                    // زر: تعديل مركبة محددة (Modal) — يعبأ تلقائيًا من الصف المحدد
                    Edit = new TableAction
                    {
                        Label = "تعديل مركبة",
                        Icon = "fa-solid fa-pen",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        ModalTitle = "<i class='fa-solid fa-pen-to-square text-emerald-600 text-xl mr-2'></i> تعديل مركبة",
                        OpenForm = new FormConfig
                        {
                            FormId = "UpdateVehicleForm",
                            Title = "تعديل بيانات مركبة",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Fields = vehicleUpdateFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ التعديلات", Type = "submit", Color = "info" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },

                    // زر: طباعة قائمة المركبات (PDF)
                    Print1 = new TableAction
                    {
                        Label = "طباعة",
                        Icon = "fa fa-print",
                        Color = "info",
                        RequireSelection = false,
                        OnClickJs = "sfPrintWithBusy(table, { pdf: 1, busy: { title: 'طباعة بيانات المركبات' } });"
                    },
                },

                // ── قواعد التلوين (StyleRules) ──────────────────────────
                // 1) حالة المركبة (Pills ملوّنة على مستوى الصف)
                //    260 = نشط (أخضر) / 261 = غير نشط (أصفر) / 262 = تالف (أحمر)
                // 2) حالة العهدة (Pills على مستوى الخلية)
                // 3) تلوين خلفية الصف حسب وجود وثائق/تأمين (recordStatus من SP)
                //    لا تأمين ولا وثائق → أحمر (أولوية قصوى + StopOnMatch)
                //    لا وثائق فقط → بنفسجي
                //    لا تأمين فقط → أصفر
                StyleRules = new List<TableStyleRule>
                {
                    // Pills حالة المركبة (نُطبّق على عمود vehicleStatusName)
                    new TableStyleRule
                    {
                        Target = "row", Field = "vehicleStatusID_FK", Op = "eq", Value = "260",
                        Priority = 1, PillEnabled = true, PillField = "vehicleStatusName",
                        PillTextField = "vehicleStatusName", PillCssClass = "pill pill-green", PillMode = "replace"
                    },
                    new TableStyleRule
                    {
                        Target = "row", Field = "vehicleStatusID_FK", Op = "eq", Value = "261",
                        Priority = 1, PillEnabled = true, PillField = "vehicleStatusName",
                        PillTextField = "vehicleStatusName", PillCssClass = "pill pill-yellow", PillMode = "replace"
                    },
                    new TableStyleRule
                    {
                        Target = "row", Field = "vehicleStatusID_FK", Op = "eq", Value = "262",
                        Priority = 1, PillEnabled = true, PillField = "vehicleStatusName",
                        PillTextField = "vehicleStatusName", PillCssClass = "pill pill-red", PillMode = "replace"
                    },
                    // Pills حالة العهدة (نُطبّق على خلية custodyStatusText)
                    new TableStyleRule
                    {
                        Target = "cell", Field = "custodyStatusText", Op = "eq", Value = "عهدة نشطة",
                        Priority = 2, PillEnabled = true, PillField = "custodyStatusText",
                        PillTextField = "custodyStatusText", PillCssClass = "pill pill-green", PillMode = "replace"
                    },
                    new TableStyleRule
                    {
                        Target = "cell", Field = "custodyStatusText", Op = "eq", Value = "بدون عهدة",
                        Priority = 2, PillEnabled = true, PillField = "custodyStatusText",
                        PillTextField = "custodyStatusText", PillCssClass = "pill pill-gray", PillMode = "replace"
                    },
                    // ── تلوين خلفية الصف حسب recordStatus ──────────────────
                    // القاعدة الأشد (no_both) لها StopOnMatch لمنع تداخل الألوان
                    new TableStyleRule
                    {
                        Target = "row", Field = "recordStatus", Op = "eq", Value = "no_both",
                        CssClass = "row-red", Priority = 5, StopOnMatch = true
                    },
                    new TableStyleRule
                    {
                        Target = "row", Field = "recordStatus", Op = "eq", Value = "no_docs",
                        CssClass = "row-purple", Priority = 6
                    },
                    new TableStyleRule
                    {
                        Target = "row", Field = "recordStatus", Op = "eq", Value = "no_ins",
                        CssClass = "row-yellow", Priority = 6
                    },
                }
            };

            // ═══════════════════════════════════════════════════════════════
            //  بناء نموذج جدول التأمينات (dsModelInsurance) — تبويب 2
            // ═══════════════════════════════════════════════════════════════
            var insuranceCustomActions = new List<TableAction>();

            var dsModelInsurance = new SmartTableDsModel
            {
                PageTitle = "المركبات",
                PanelTitle = "تأمينات المركبات",
                Columns = insuranceColumns,
                Rows = insuranceRows,
                RowIdField = "VehicleInsuranceID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = insuranceColumns.Where(c => c.Visible).Select(c => c.Field).Take(5).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowRowBorders = true,
                EnablePagination = true,
                ShowPageSizeSelector = true,
                ShowToolbar = true,
                EnableCellCopy = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                ShowColumnVisibility = true,

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsTab = true,
                TabGroupKey = "vehicles-page",
                TabKey = "insurance",
                TabLabel = "التأمينات",
                TabIcon = "fa-solid fa-shield-halved",
                TabDefaultActive = false,
                ShowTabCount = true,
                TabOrder = 2,
                TabDescription = insAlertHtml,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = true,
                    ShowExportPdf = false,
                    ShowPrint1 = false,
                    ShowBulkDelete = false,
                    ShowAdd = canInsuranceInsert,
                    ShowEdit = canInsuranceUpdate,
                    ShowDelete = false,
                    CustomActions = insuranceCustomActions,

                    Add = new TableAction
                    {
                        Label = "إضافة تأمين",
                        Icon = "fa fa-plus-circle",
                        Color = "success",
                        OpenModal = true,
                        RequireSelection = false,
                        ModalTitle = "<i class='fa-solid fa-shield-halved text-emerald-600 text-xl mr-2'></i> إضافة تأمين",
                        OpenForm = new FormConfig
                        {
                            FormId = "InsertInsuranceForm",
                            Title = "بيانات تأمين جديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = insuranceUpsertFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },

                    Edit = new TableAction
                    {
                        Label = "تعديل تأمين",
                        Icon = "fa-solid fa-pen",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        ModalTitle = "<i class='fa-solid fa-pen-to-square text-emerald-600 text-xl mr-2'></i> تعديل تأمين",
                        OpenForm = new FormConfig
                        {
                            FormId = "UpdateInsuranceForm",
                            Title = "تعديل بيانات التأمين",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Fields = insuranceUpdateFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ التعديلات", Type = "submit", Color = "info" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },
                },

                // Pills حالة التأمين: ساري (أخضر) / قارب الانتهاء (برتقالي) / منتهي (أحمر)
                StyleRules = new List<TableStyleRule>
                {
                    new TableStyleRule
                    {
                        Target = "row", Field = "InsuranceStatusCode", Op = "eq", Value = "active",
                        Priority = 1, PillEnabled = true, PillField = "InsuranceStatusText",
                        PillTextField = "InsuranceStatusText", PillCssClass = "pill pill-green", PillMode = "replace"
                    },
                    new TableStyleRule
                    {
                        Target = "row", Field = "InsuranceStatusCode", Op = "eq", Value = "expiring",
                        Priority = 1, PillEnabled = true, PillField = "InsuranceStatusText",
                        PillTextField = "InsuranceStatusText", PillCssClass = "pill pill-orange", PillMode = "replace"
                    },
                    new TableStyleRule
                    {
                        Target = "row", Field = "InsuranceStatusCode", Op = "eq", Value = "expired",
                        Priority = 1, PillEnabled = true, PillField = "InsuranceStatusText",
                        PillTextField = "InsuranceStatusText", PillCssClass = "pill pill-red", PillMode = "replace"
                    },
                }
            };

            // ═══════════════════════════════════════════════════════════════
            //  بناء نموذج جدول الوثائق (dsModelDocuments) — تبويب 3
            // ═══════════════════════════════════════════════════════════════
            var dsModelDocuments = new SmartTableDsModel
            {
                PageTitle = "المركبات",
                PanelTitle = "وثائق المركبات",
                Columns = documentColumns,
                Rows = documentRows,
                RowIdField = "vehicleDocumentID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = documentColumns.Where(c => c.Visible).Select(c => c.Field).Take(5).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowRowBorders = true,
                EnablePagination = true,
                ShowPageSizeSelector = true,
                ShowToolbar = true,
                EnableCellCopy = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,
                ShowColumnVisibility = true,

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsTab = true,
                TabGroupKey = "vehicles-page",
                TabKey = "documents",
                TabLabel = "الوثائق",
                TabIcon = "fa-solid fa-file-lines",
                TabDefaultActive = false,
                ShowTabCount = true,
                TabOrder = 3,
                TabDescription = docAlertHtml,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = true,
                    ShowExportPdf = false,
                    ShowPrint1 = false,
                    ShowBulkDelete = false,
                    ShowAdd = canDocumentInsert,
                    ShowEdit = canDocumentUpdate,
                    ShowDelete = false,

                    Add = new TableAction
                    {
                        Label = "إضافة وثيقة",
                        Icon = "fa fa-plus-circle",
                        Color = "success",
                        OpenModal = true,
                        RequireSelection = false,
                        ModalTitle = "<i class='fa-solid fa-file-lines text-emerald-600 text-xl mr-2'></i> إضافة وثيقة",
                        OpenForm = new FormConfig
                        {
                            FormId = "InsertDocumentForm",
                            Title = "بيانات وثيقة جديدة",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = documentInsertFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },

                    Edit = new TableAction
                    {
                        Label = "تعديل وثيقة",
                        Icon = "fa-solid fa-pen",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        ModalTitle = "<i class='fa-solid fa-pen-to-square text-emerald-600 text-xl mr-2'></i> تعديل وثيقة",
                        OpenForm = new FormConfig
                        {
                            FormId = "UpdateDocumentForm",
                            Title = "تعديل بيانات الوثيقة",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            Fields = documentUpdateFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ التعديلات", Type = "submit", Color = "info" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },
                },

                // فاصل بصري عند تغير رقم الهيكل + Pills حالة الوثيقة
                StyleRules = new List<TableStyleRule>
                {
                    // فاصل بين مجموعات الوثائق لكل مركبة
                    new TableStyleRule
                    {
                        Target = "row", Field = "IsGroupStart", Op = "eq", Value = "true",
                        Priority = 0, CssClass = "border-t-2 border-gray-300"
                    },
                    // Pills حالة الوثيقة: ساري / قارب الانتهاء / منتهي
                    new TableStyleRule
                    {
                        Target = "row", Field = "DocumentStatusCode", Op = "eq", Value = "active",
                        Priority = 1, PillEnabled = true, PillField = "DocumentStatusText",
                        PillTextField = "DocumentStatusText", PillCssClass = "pill pill-green", PillMode = "replace"
                    },
                    new TableStyleRule
                    {
                        Target = "row", Field = "DocumentStatusCode", Op = "eq", Value = "expiring",
                        Priority = 1, PillEnabled = true, PillField = "DocumentStatusText",
                        PillTextField = "DocumentStatusText", PillCssClass = "pill pill-orange", PillMode = "replace"
                    },
                    new TableStyleRule
                    {
                        Target = "row", Field = "DocumentStatusCode", Op = "eq", Value = "expired",
                        Priority = 1, PillEnabled = true, PillField = "DocumentStatusText",
                        PillTextField = "DocumentStatusText", PillCssClass = "pill pill-red", PillMode = "replace"
                    },
                }
            };

            // ═══════════════════════════════════════════════════════════════
            //  وضع الطباعة (PDF) — يُولّد تقريرًا عند تمرير pdf=1
            // ═══════════════════════════════════════════════════════════════
            if (pdf == 1)
            {
                if (vehicleRows.Count == 0)
                    return Content("لا توجد بيانات للطباعة.");

                var printTable = new DataTable();
                printTable.Columns.Add("chassisNumber", typeof(string));
                printTable.Columns.Add("plateLetters", typeof(string));
                printTable.Columns.Add("plateNumbers", typeof(string));
                printTable.Columns.Add("armyNumber", typeof(string));
                printTable.Columns.Add("yearModel", typeof(string));
                printTable.Columns.Add("ownerName", typeof(string));
                printTable.Columns.Add("manufacturerName", typeof(string));
                printTable.Columns.Add("modelName", typeof(string));
                printTable.Columns.Add("colorName", typeof(string));
                printTable.Columns.Add("VehicleStatusName", typeof(string));
                printTable.Columns.Add("custodyStatusText", typeof(string));

                foreach (var row in vehicleRows)
                {
                    printTable.Rows.Add(
                        row.GetValueOrDefault("chassisNumber")?.ToString(),
                        row.GetValueOrDefault("plateLetters")?.ToString(),
                        row.GetValueOrDefault("plateNumbers")?.ToString(),
                        row.GetValueOrDefault("armyNumber")?.ToString(),
                        row.GetValueOrDefault("yearModel")?.ToString(),
                        row.GetValueOrDefault("ownerName")?.ToString(),
                        row.GetValueOrDefault("manufacturerName")?.ToString(),
                        row.GetValueOrDefault("modelName")?.ToString(),
                        row.GetValueOrDefault("colorName")?.ToString(),
                        row.GetValueOrDefault("VehicleStatusName")?.ToString(),
                        row.GetValueOrDefault("custodyStatusText")?.ToString()
                    );
                }

                var reportColumns = new List<ReportColumn>
                {
                    new("chassisNumber", "رقم الهيكل", Align:"center", Weight:2, FontSize:9),
                    new("plateLetters", "حروف اللوحة", Align:"center", Weight:2, FontSize:9),
                    new("plateNumbers", "أرقام اللوحة", Align:"center", Weight:2, FontSize:9),
                    new("armyNumber", "الرقم العسكري", Align:"center", Weight:2, FontSize:9),
                    new("yearModel", "سنة الصنع", Align:"center", Weight:1, FontSize:9),
                    new("ownerName", "المالك", Align:"center", Weight:3, FontSize:9),
                    new("manufacturerName", "الشركة المصنعة", Align:"center", Weight:2, FontSize:9),
                    new("modelName", "الموديل", Align:"center", Weight:2, FontSize:9),
                    new("colorName", "اللون", Align:"center", Weight:2, FontSize:9),
                    new("VehicleStatusName", "حالة المركبة", Align:"center", Weight:2, FontSize:9),
                    new("custodyStatusText", "حالة العهدة", Align:"center", Weight:2, FontSize:9),
                };

                var logo = Path.Combine(_env.WebRootPath, "img", "ppng.png");
                var header = new Dictionary<string, string>
                {
                    ["no"] = usersId ?? "",
                    ["date"] = DateTime.Now.ToString("yyyy/MM/dd"),
                    ["attach"] = "—",
                    ["subject"] = "قائمة المركبات",
                    ["right1"] = "المملكة العربية السعودية",
                    ["right2"] = "وزارة الدفاع",
                    ["right3"] = "القوات البرية الملكية السعودية",
                    ["midCaption"] = ""
                };

                var report = DataTableReportBuilder.FromDataTable(
                    reportId: "VehicleList",
                    title: "قائمة المركبات",
                    table: printTable,
                    columns: reportColumns,
                    headerFields: header,
                    footerFields: new Dictionary<string, string>
                    {
                        ["تمت الطباعة بواسطة"] = FullName ?? "",
                        ["ملاحظة"] = "هذا التقرير للاستخدام الرسمي",
                        ["عدد السجلات"] = vehicleRows.Count.ToString(),
                        ["تاريخ ووقت الطباعة"] = DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss")
                    },
                    orientation: ReportOrientation.Landscape,
                    headerType: ReportHeaderType.LetterOfficial,
                    logoPath: logo,
                    headerRepeat: ReportHeaderRepeat.FirstPageOnly
                );

                var pdfBytes = QuestPdfReportRenderer.Render(report);
                Response.Headers["Content-Disposition"] = "inline; filename=VehicleList.pdf";
                return File(pdfBytes, "application/pdf");
            }

            // ═══════════════════════════════════════════════════════════════
            //  تجميع الصفحة النهائية (SmartPageViewModel)
            //  SmartRenderer يتولى رسم: Tabs + Toolbar + Tables تلقائيًا
            // ═══════════════════════════════════════════════════════════════
            var page = new SmartPageViewModel
            {
                PageTitle = dsModelVehicle.PageTitle,
                PanelTitle = dsModelVehicle.PanelTitle,
                PanelIcon = "fa-solid fa-car",
                TableDS = dsModelVehicle,
                TableDS1 = dsModelInsurance,
                TableDS2 = dsModelDocuments,
            };

            return View("Page/VehicleList", page);
        }

        // ═══════════════════════════════════════════════════════════════
        //  AJAX Endpoints — تُستدعى من JavaScript فقط (للسيlect2 والنماذج)
        // ═══════════════════════════════════════════════════════════════

        // جلب بيانات مركبة كاملة لتعبئة نموذج التعديل (يستدعيه sfRouteEditForm)
        [HttpGet]
        public async Task<IActionResult> GetVehicleFull(string? chassisNumber)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return Json(new { success = false, message = "تعذر تهيئة الصفحة" });

            if (string.IsNullOrWhiteSpace(usersId))
                return Json(new { success = false, message = "المستخدم غير معرف" });

            if (string.IsNullOrWhiteSpace(chassisNumber))
                return Json(new { success = false, message = "رقم الهيكل مطلوب" });

            try
            {
                var spParameters = new object?[]
                {
                    "Vehicle_Get", IdaraId, usersId, HostName,
                    usersId, null, 1, chassisNumber, IdaraId
                };

                DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

                DataTable? dataTable = null;
                if (ds.Tables.Count == 1)
                    dataTable = ds.Tables[0];
                else if (ds.Tables.Count > 1)
                    dataTable = ds.Tables[1] ?? ds.Tables[0];

                if (dataTable == null || dataTable.Rows.Count == 0)
                    return Json(new { success = false, message = "لم يتم العثور على بيانات المركبة" });

                var row = dataTable.Rows[0];

                object? GetValue(string name) =>
                    dataTable.Columns.Contains(name) && row[name] != DBNull.Value ? row[name] : null;

                var item = new Dictionary<string, object?>
                {
                    ["p01"] = GetValue("chassisNumber"),
                    ["p02"] = GetValue("ownerID_FK"),
                    ["p03"] = GetValue("ManufacturerNameID_FK"),
                    ["p04"] = GetValue("vehicleModelID_FK"),
                    ["p05"] = GetValue("vehicleClassID_FK"),
                    ["p06"] = GetValue("TypeOfUseID_FK"),
                    ["p07"] = GetValue("vehicleColorID_FK"),
                    ["p08"] = GetValue("countryMadeID_FK"),
                    ["p09"] = GetValue("regstritionTypeID_FK"),
                    ["p10"] = GetValue("regionID_FK"),
                    ["p11"] = GetValue("fuelTypeID_FK"),
                    ["p12"] = GetValue("vehicleTypeID_FK"),
                    ["p13"] = GetValue("yearModel"),
                    ["p14"] = GetValue("capacity"),
                    ["p15"] = GetValue("serialNumber"),
                    ["p16"] = GetValue("plateLetters"),
                    ["p17"] = GetValue("plateNumbers"),
                    ["p18"] = GetValue("armyNumber"),
                    ["p19"] = GetValue("vehicleNote")
                };

                return Json(new { success = true, item });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        // بحث برقم الهيكل (يستدعيه Select2 للبحث اللحظي)
        [HttpGet]
        public async Task<IActionResult> SearchVehicleChassis(string? q = null)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return Json(new { results = new List<object>() });

            if (string.IsNullOrWhiteSpace(usersId))
                return Json(new { results = new List<object>() });

            try
            {
                var searchValue = string.IsNullOrWhiteSpace(q) ? "1" : q.Trim();

                var spParameters = new object?[]
                {
                    "Vehicle_Search", IdaraId, usersId, HostName,
                    searchValue, null, null, 20, IdaraId
                };

                DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

                DataTable? dataTable = null;
                if (ds.Tables.Count == 1)
                    dataTable = ds.Tables[0];
                else if (ds.Tables.Count > 1)
                    dataTable = ds.Tables[1] ?? ds.Tables[0];

                var results = new List<object>();

                if (dataTable != null && dataTable.Rows.Count > 0)
                {
                    foreach (DataRow row in dataTable.Rows)
                    {
                        var chassis = dataTable.Columns.Contains("chassisNumber")
                            ? row["chassisNumber"]?.ToString() : null;

                        if (!string.IsNullOrWhiteSpace(chassis))
                            results.Add(new { id = chassis, text = chassis });
                    }
                }

                return Json(new { results });
            }
            catch
            {
                return Json(new { results = new List<object>() });
            }
        }

        // جلب قائمة TypesRoot ديناميكيًا (يستدعيه Select2 للأقسام الفرعية)
        [HttpGet]
        public async Task<IActionResult> GetTypesRootOptions(int? parentID, string? q = null)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return Json(new { success = false, items = new List<object>() });

            if (string.IsNullOrWhiteSpace(usersId))
                return Json(new { success = false, items = new List<object>() });

            if (parentID == null)
                return Json(new { success = true, items = new List<object>() });

            try
            {
                var spParameters = new object?[]
                {
                    "TypesRoot_List", IdaraId, usersId, HostName,
                    parentID, 1,
                    string.IsNullOrWhiteSpace(q) ? null : q
                };

                DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

                DataTable? dataTable = null;
                if (ds.Tables.Count == 1)
                    dataTable = ds.Tables[0];
                else if (ds.Tables.Count > 1)
                    dataTable = ds.Tables[1] ?? ds.Tables[0];

                var items = new List<object>();

                if (dataTable != null && dataTable.Rows.Count > 0)
                {
                    foreach (DataRow row in dataTable.Rows)
                    {
                        var value = dataTable.Columns.Contains("typesID")
                            ? row["typesID"]?.ToString() ?? "" : "";
                        var text = dataTable.Columns.Contains("typesName_A")
                            ? row["typesName_A"]?.ToString() ?? "" : "";

                        items.Add(new { value, text });
                    }
                }

                return Json(new { success = true, items });
            }
            catch
            {
                return Json(new { success = false, items = new List<object>() });
            }
        }

        // ═══════════════════════════════════════════════════════════════
        //  Helper Methods — تُستدعى داخليًا لتحميل قوائم Lookup
        // ═══════════════════════════════════════════════════════════════

        // تحميل قائمة من TypesRoot حسب typesRoot_ParentID (تُستدعى بالتوازي)
        private async Task<List<OptionItem>> LoadTypesRootLookup(int parentID)
        {
            var options = new List<OptionItem>();

            try
            {
                var spParameters = new object?[]
                {
                    "TypesRoot_List", IdaraId, usersId, HostName,
                    parentID, 1, null
                };

                DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

                DataTable? dataTable = null;
                if (ds.Tables.Count == 1)
                    dataTable = ds.Tables[0];
                else if (ds.Tables.Count > 1)
                    dataTable = ds.Tables[1] ?? ds.Tables[0];

                if (dataTable != null && dataTable.Rows.Count > 0)
                {
                    foreach (DataRow row in dataTable.Rows)
                    {
                        var value = dataTable.Columns.Contains("typesID")
                            ? row["typesID"]?.ToString() ?? "" : "";
                        var text = dataTable.Columns.Contains("typesName_A")
                            ? row["typesName_A"]?.ToString() ?? "" : "";

                        if (!string.IsNullOrWhiteSpace(value) && !string.IsNullOrWhiteSpace(text))
                            options.Add(new OptionItem { Value = value, Text = text });
                    }
                }
            }
            catch { }

            return options;
        }

        // تحميل قائمة أنواع الوثائق (تُستدعى بالتوازي)
        private async Task<List<OptionItem>> LoadDocumentTypeLookup()
        {
            var options = new List<OptionItem>();

            try
            {
                var spParameters = new object?[]
                {
                    "VehicleDocumentType_List", IdaraId, usersId, HostName,
                    1
                };

                DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

                DataTable? dataTable = null;
                if (ds.Tables.Count == 1)
                    dataTable = ds.Tables[0];
                else if (ds.Tables.Count > 1)
                    dataTable = ds.Tables[1] ?? ds.Tables[0];

                if (dataTable != null && dataTable.Rows.Count > 0)
                {
                    foreach (DataRow row in dataTable.Rows)
                    {
                        var value = dataTable.Columns.Contains("vehicleDocumentTypeID")
                            ? row["vehicleDocumentTypeID"]?.ToString() ?? "" : "";
                        var text = dataTable.Columns.Contains("vehicleDocumentTypeName_A")
                            ? row["vehicleDocumentTypeName_A"]?.ToString() ?? "" : "";

                        if (!string.IsNullOrWhiteSpace(value) && !string.IsNullOrWhiteSpace(text))
                            options.Add(new OptionItem { Value = value, Text = text });
                    }
                }
            }
            catch { }

            return options;
        }

        // بناء حقل Select2 من قائمة TypesRoot (يُستدعى عند بناء النماذج)
        private static FieldConfig BuildTypesRootField(string name, string label, List<OptionItem> options)
        {
            return new FieldConfig
            {
                Name = name,
                Label = label,
                Type = "select",
                ColCss = "4",
                Select2 = true,
                Placeholder = "اختر " + label,
                Options = options
            };
        }
    }
}
