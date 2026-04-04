using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartCharts;
using SmartFoundation.UI.ViewModels.SmartPage;
using System.Globalization;

namespace SmartFoundation.Mvc.Controllers.HousingCommandCenter
{
    public class HousingCommandCenterDashboardController : Controller
    {
        // ═══════════════════════════════════════════════════════
        //  لوحة الألوان — زاهية · واضحة · غير متشابهة
        // ═══════════════════════════════════════════════════════
        private static class Color
        {
            // ── الخمسة الرئيسية للمعايير ── مختلفة تماماً
            public const string RoyalBlue = "#1a56db";   // أزرق ملكي زاهي
            public const string Teal = "#0694a2";   // تيل فيروزي
            public const string Amber = "#d97706";   // برتقالي عسلي
            public const string Emerald = "#057a55";   // أخضر زمردي
            public const string Violet = "#6d28d9";   // بنفسجي ملكي

            // ── ألوان الإدارات السبع ── كل واحدة مختلفة
            public const string Navy = "#1e3a8a";   // كحلي داكن
            public const string SteelBlue = "#1d4ed8";   // أزرق فولاذي
            public const string Green = "#065f46";   // أخضر داكن
            public const string Cyan = "#155e75";   // سماوي داكن
            public const string Purple = "#5b21b6";   // بنفسجي داكن
            public const string Orange = "#92400e";   // بني برتقالي
            public const string Slate = "#1e3a5f";   // رمادي أزرق

            // ── للبيانات والتفاصيل ──
            public const string Red = "#991b1b";   // أحمر داكن
            public const string Gold = "#b45309";   // ذهبي داكن
            public const string Indigo = "#3730a3";   // نيلي
        }

        public IActionResult Index()
        {
            var card = BuildCommandCenterCard();
            var vm = new SmartPageViewModel
            {
                PageTitle = "لوحة قيادة الإدارات التشغيلية والصيانة",
                Charts = new SmartChartsConfig
                {
                    ChartsId = "housingCommandCenterDashboard",
                    Dir = "rtl",
                    Cards = new List<ChartCardConfig> { card }
                }
            };
            return View(vm);
        }

        public IActionResult Department(string id)
        {
            var metrics = BuildMetrics();
            var departments = BuildDepartments();
            var department = departments.FirstOrDefault(d => d.Key == id);

            if (department == null)
                return RedirectToAction("Index");

            var vm = new DepartmentDetailViewModel
            {
                Department = department,
                Metrics = metrics,
                HousingDetail = BuildHousingDetail(id),
                AllocationDetail = BuildAllocationDetail(id),
                RequestsDetail = BuildRequestsDetail(id),
                FinanceDetail = BuildFinanceDetail(id),
                MaintenanceDetail = BuildMaintenanceDetail(id)
            };
            return View(vm);
        }

        // ───────────────────────────────────────────────────────
        private static ChartCardConfig BuildCommandCenterCard()
        {
            var metrics = BuildMetrics();
            var departments = BuildDepartments();
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

                HousingCommandCenterBoardOptions = new HousingCommandCenterBoardOptions
                {
                    TitleText = "لوحة قيادة الإدارات التشغيلية والصيانة",
                    SubtitleText = "خمسة معايير قرار رئيسية تعكس الجاهزية السكنية، كفاءة التخصيص، أداء الطلبات، الكفاءة المالية، والصيانة والجودة",
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

        // ═══════════════════════════════════════════════════════
        //  المعايير — 5 ألوان مختلفة تماماً وزاهية
        // ═══════════════════════════════════════════════════════
        private static List<HousingCommandCenterMetric> BuildMetrics() =>
        [
            new HousingCommandCenterMetric
            {
                Key        = "m_housing_readiness",
                SortOrder  = 1,
                Title      = "جاهزية المخزون السكني والأصول",
                ShortTitle = "جاهزية السكن والأصول",
                Subtitle   = "يقيس صلاحية الوحدات للتسكين الفعلي ويربط حالة المنازل بالأصول والمرافق الداعمة ومساحات الوحدات والغرف",
                Target = 100, Actual = 83, Unit = "%",
                Icon = "fa-solid fa-building-circle-check", Emoji = "🏛️",
                Tone  = "info",
                Color = Color.Gold,
                Hint  = "إذا انخفض هذا المؤشر فالمشكلة غالبًا في جاهزية الأصل نفسه أو دورة الإحالة بين الصيانة والجودة والخدمات العامة."
            },
            new HousingCommandCenterMetric
            {
                Key        = "m_allocation_balance",
                SortOrder  = 2,
                Title      = "كفاءة الإشغال والتخصيص وقوائم الانتظار",
                ShortTitle = "الإشغال والانتظار",
                Subtitle   = "يقيس توازن التوزيع بين الفئات السكنية ويكشف الفجوة بين المنتظرين والساكنين وحجم الاستفادة من الشواغر الجاهزة",
                Target = 95, Actual = 79, Unit = "%",
                Icon = "fa-solid fa-users-viewfinder", Emoji = "👥",
                Tone  = "info",
                Color = Color.Teal,        // تيل فيروزي
                Hint  = "هذا المؤشر هو الأكثر ارتباطًا بعدالة التخصيص وكفاءة الاستفادة من المخزون الجاهز."
            },
            new HousingCommandCenterMetric
            {
                Key        = "m_requests_sla",
                SortOrder  = 3,
                Title      = "أداء الطلبات ومدد الإنجاز مقابل الأهداف",
                ShortTitle = "الطلبات وSLA",
                Subtitle   = "يغطي طلبات الإمهال والإخلاء والتسكين تحت الإجراء، ويقارن المدد الفعلية بأهداف الإنجاز المعتمدة",
                Target = 95, Actual = 74, Unit = "%",
                Icon = "fa-solid fa-clipboard-check", Emoji = "📊",
                //Tone  = "warning",
                Color = Color.Emerald,
                Hint  = "أي تراجع هنا يعني ضغطًا إجرائيًا حقيقيًا يؤثر على رضى المستفيد وسرعة دوران الوحدات."
            },
            new HousingCommandCenterMetric
            {
                Key        = "m_finance_utilities",
                SortOrder  = 4,
                Title      = "الكفاءة المالية والاستهلاك والمطالبات",
                ShortTitle = "الماليات والاستهلاك",
                Subtitle   = "يجمع المستحقات الإيجارية، المطالبات المالية حسب الفئة، ومؤشرات استهلاك الكهرباء والماء في قراءة مالية تشغيلية واحدة",
                Target = 100, Actual = 81, Unit = "%",
                Icon = "fa-solid fa-coins", Emoji = "💰",
                Tone  = "success",
                Color = Color.RoyalBlue,
                Hint  = "هذا المؤشر يقيس أثر التشغيل على التكلفة وجودة الإدارة المالية للأصل والمستفيد والخدمة."
            },
            new HousingCommandCenterMetric
            {
                Key        = "m_maintenance_quality",
                SortOrder  = 5,
                Title      = "الصيانة الوقائية والجودة والخدمات والمركبات",
                ShortTitle = "الصيانة والجودة",
                Subtitle   = "يركز على فعالية الصيانة الوقائية للمباني والأسطول والمرافق، وسرعة الإحالات للجودة والخدمات العامة وإغلاقها",
                Target = 100, Actual = 86, Unit = "%",
                Icon = "fa-solid fa-tools", Emoji = "⚙️",
                Tone  = "success",
                Color = Color.Violet,      // بنفسجي ملكي
                Hint  = "الإدارة القوية هنا تكون أقل اعتمادًا على الصيانة الطارئة وأكثر قدرة على المحافظة على الجاهزية."
            }
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
                "fa-solid fa-water", "🏙️", "warning", Color.Cyan,
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

        private static DepFinanceDetail BuildFinanceDetail(string depId) => depId switch
        {
            "dep_01" => new DepFinanceDetail
            {
                RentLastMonth = 412000,
                RentLast3Months = 1189000,
                RentLast12Months = 4538000,
                Collected = 3941000,
                Uncollected = 597000,
                PaidFromSallary = 3211252,
                PaidByATM = 521589,
                PaidByCash = 208159,
                UtilityEfficiency = new()
                {
                    new() { Label = "الإيجار",  Value = 89, Color = Color.Navy      },
                    new() { Label = "الكهرباء", Value = 78, Color = Color.Amber     },
                    new() { Label = "الماء",     Value = 64, Color = Color.SteelBlue },
                    new() { Label = "الغاز",     Value = 97, Color = Color.Emerald   },
                }
            },
            _ => new DepFinanceDetail
            {
                RentLastMonth = 250000,
                RentLast3Months = 720000,
                RentLast12Months = 2800000,
                Collected = 2400000,
                Uncollected = 400000,
                PaidFromSallary = 2211252,
                PaidByATM = 165852,
                PaidByCash = 22896,
                UtilityEfficiency = new()
                {
                    new() { Label = "الإيجار",  Value = 84, Color = Color.Navy      },
                    new() { Label = "الكهرباء", Value = 78, Color = Color.Amber     },
                    new() { Label = "الماء",     Value = 64, Color = Color.SteelBlue },
                    new() { Label = "الغاز",     Value = 90, Color = Color.Emerald   },
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
    }
}