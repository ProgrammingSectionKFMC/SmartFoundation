using CommunityToolkit.HighPerformance;
using Microsoft.AspNetCore.DataProtection.KeyManagement;
using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartCharts;
using SmartFoundation.UI.ViewModels.SmartPage;
using System.Globalization;
//test
namespace SmartFoundation.Mvc.Controllers.HousingCommandCenter
{
    public class HousingCommandCenterDashboardController : Controller
    {
        private static class Color
        {
            public const string Teal = "#0f766e";
            public const string Green = "#16a34a";
            public const string Blue = "#2563eb";
            public const string Sky = "#0ea5e9";
            public const string Violet = "#7c3aed";
            public const string Purple = "#9333ea";
            public const string Amber = "#d97706";
            public const string Red = "#dc2626";
            public const string Slate = "#64748b";
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
                    //Title = "لوحة قيادة الإدارات التشغيلية والصيانة",
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
                Subtitle = "قراءة تنفيذية نهائية لملف السكن، التخصيص، الطلبات، الماليات، والاستهلاك والصيانة الوقائية",
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

        private static List<HousingCommandCenterMetric> BuildMetrics() =>
        [
            new HousingCommandCenterMetric
            {
                Key = "m_housing_readiness",
                SortOrder = 1,
                Title = "جاهزية المخزون السكني والأصول",
                ShortTitle = "جاهزية السكن والأصول",
                Subtitle = "يقيس صلاحية الوحدات للتسكين الفعلي ويربط حالة المنازل بالأصول والمرافق الداعمة ومساحات الوحدات والغرف",
                Target = 100,
                Actual = 83,
                //CompletionPercent = 84,
                Unit = "%",
                Icon = "fa-solid fa-house-circle-check",
                Emoji = "🏘️",
                Tone = "success",
                Color = Color.Teal,
                Hint = "إذا انخفض هذا المؤشر فالمشكلة غالبًا ليست في الطلب فقط، بل في جاهزية الأصل نفسه أو في دورة الإحالة بين الصيانة والجودة والخدمات العامة."
            },
            new HousingCommandCenterMetric
            {
                Key = "m_allocation_balance",
                SortOrder = 2,
                Title = "كفاءة الإشغال والتخصيص وقوائم الانتظار",
                ShortTitle = "الإشغال والانتظار",
                Subtitle = "يقيس توازن التوزيع بين الفئات السكنية ويكشف الفجوة بين المنتظرين والساكنين وحجم الاستفادة من الشواغر الجاهزة",
                Target = 95,
                Actual = 79,
                //CompletionPercent = 79,
                Unit = "%",
                Icon = "fa-solid fa-people-roof",
                Emoji = "📋",
                Tone = "info",
                Color = Color.Blue,
                Hint = "هذا المؤشر هو الأكثر ارتباطًا بعدالة التخصيص وكفاءة الاستفادة من المخزون الجاهز، ويكشف اختناقات الفئات أو المدن مباشرة."
            },
            new HousingCommandCenterMetric
            {
                Key = "m_requests_sla",
                SortOrder = 3,
                Title = "أداء الطلبات ومدد الإنجاز مقابل الأهداف",
                ShortTitle = "الطلبات وSLA",
                Subtitle = "يغطي طلبات الإمهال والإخلاء والتسكين تحت الإجراء، ويقارن المدد الفعلية بأهداف الإنجاز المعتمدة",
                Target = 95,
                Actual = 74,
                //CompletionPercent = 74,
                Unit = "%",
                Icon = "fa-solid fa-stopwatch-20",
                Emoji = "⏱️",
                Tone = "warning",
                Color = Color.Amber,
                Hint = "أي تراجع هنا يعني ضغطًا إجرائيًا حقيقيًا يؤثر على رضى المستفيد وسرعة دوران الوحدات، ويستلزم تدخلًا تشغيليًا مباشرًا."
            },
            new HousingCommandCenterMetric
            {
                Key = "m_finance_utilities",
                SortOrder = 4,
                Title = "الكفاءة المالية والاستهلاك والمطالبات",
                ShortTitle = "الماليات والاستهلاك",
                Subtitle = "يجمع المستحقات الإيجارية، المطالبات المالية حسب الفئة، ومؤشرات استهلاك الكهرباء والماء في قراءة مالية تشغيلية واحدة",
                Target = 100,
                Actual = 81,
                //CompletionPercent = 81,
                Unit = "%",
                Icon = "fa-solid fa-money-bill-wave",
                Emoji = "💰",
                Tone = "success",
                Color = Color.Green,
                Hint = "هذا المؤشر لا يقيس التحصيل فقط، بل يقيس أيضًا أثر التشغيل على التكلفة وجودة الإدارة المالية للأصل والمستفيد والخدمة."
            },
            new HousingCommandCenterMetric
            {
                Key = "m_maintenance_quality",
                SortOrder = 5,
                Title = "الصيانة الوقائية والجودة والخدمات والمركبات",
                ShortTitle = "الصيانة والجودة",
                Subtitle = "يركز على فعالية الصيانة الوقائية للمباني والأسطول والمرافق، وسرعة الإحالات للجودة والخدمات العامة وإغلاقها",
                Target = 100,
                Actual = 86,
                //CompletionPercent = 86,
                Unit = "%",
                Icon = "fa-solid fa-screwdriver-wrench",
                Emoji = "🛠️",
                Tone = "success",
                Color = Color.Violet,
                Hint = "الإدارة القوية في هذا المؤشر تكون أقل اعتمادًا على الصيانة الطارئة وأكثر قدرة على المحافظة على الجاهزية واستقرار التشغيل."
            }
        ];

        private static List<HousingCommandCenterDepartment> BuildDepartments() =>
[
    BuildDepartment(
        key: "dep_01",
        sortOrder: 1,
        name: "إدارة مدينة الملك فيصل العسكرية للتشغيل والصيانة",
            shortName: "مدينة الملك فيصل",

        icon: "fa-solid fa-city",
        emoji: "🏙️",
        tone: "success",
        color: Color.Teal,
        //hint: "أكبر نطاق تشغيلي على مستوى اللوحة، ويُستخدم كمرجع مقارنة لبقية الإدارات.",
        items:
        [
            DM(
                "m_housing_readiness", 100, 90,
                "جاهزية السكن والأصول",
                "إجمالي الوحدات: 1,482 | مشغولة: 1,355 | شاغرة: 67 | تحت الصيانة: 28 | إحالة جودة: 14 | إحالة خدمات عامة: 10 | جاهزة للتسكين: 8 | المساحات: أقل من 120م²: 164، من 120-180: 492، من 181-250: 418، من 251-350: 267، أكثر من 350: 141 | الغرف: غرفة واحدة: 42، غرفتان: 154، 3 غرف: 386، 4 غرف: 471، 5 غرف: 294، 6 فأكثر: 135 | المرافق: منازل عائلية: 1,248، وحدات عسكرية: 214، وحدات عزاب: 81، حدائق: 26، مبانٍ خدمية: 17"
            ),
            DM(
                "m_allocation_balance", 100, 88,
                "الإشغال وقوائم الانتظار",
                "الفئات السكنية: ضباط كبار: 92، ضباط: 214، ضباط صف: 276، أفراد: 418، مدنيون: 165، متعاقدون: 38، مستخدمون: 43، متقاعدون: 9، زوار وخبراء: 3، غير مصنف: 1 | الانتظار مقابل الساكنين: ضباط كبار 12/86، ضباط 38/201، ضباط صف 54/261، أفراد 71/395، مدنيون 29/151، متعاقدون 14/38 | التوزيع الحي: القادسية: 224، النخيل: 205، الربوة: 198، اليرموك: 190، الفيصلية: 183، الورود: 176، الصفا: 162، الأندلس: 144"
            ),
            DM(
                "m_requests_sla", 100, 90,
                "الطلبات وSLA",
                "الطلبات المفتوحة: تسكين: 84، إمهال: 42، إخلاء: 31، صيانة: 36، نقل داخلي: 12 | متوسط الإنجاز: الإمهال 5.7 يوم مقابل هدف 4.0، الإخلاء 4.9 مقابل 3.0، التسكين 3.8 مقابل 2.5 | الضغط التنفيذي الأبرز في مسار التسكين والإمهال"
            ),
            DM(
                "m_finance_utilities", 100, 95,
                "الماليات والاستهلاك",
                "الإيجارات المستحقة: الشهر الماضي 412,000 ر.س | آخر 3 أشهر 1,189,000 ر.س | آخر 12 شهراً 4,538,000 ر.س | المحصّل: 3,941,000 ر.س | غير المحصّل: 597,000 ر.س | تركّز المطالبات: الأفراد ثم ضباط الصف ثم الضباط | كفاءة الاستهلاك: الكهرباء 78%، الماء 64%"
            ),
            DM(
                "m_maintenance_quality", 100, 88,
                "الصيانة والجودة",
                "الصيانة الوقائية المنجزة: 221 من 260 عمل مخطط | جاهزية الأسطول والمركبات: 86% | الإحالات: جودة 14، خدمات عامة 10 | حالة المرافق: السلامة 87%، الغاز 91%، الإنترنت 55% | التوصية: تسريع إغلاق المواقع ذات الأعطال المتكررة"
            )
        ]),

    BuildDepartment(
        key: "dep_02",
        sortOrder: 2,
        name: "إدارة مدينة الملك عبدالعزيز العسكرية للتشغيل والصيانة",
            shortName: "مدينة الملك عبدالعزيز",

        icon: "fa-solid fa-fort-awesome",
        emoji: "🏙️",
        tone: "success",
        color: Color.Blue,
       // hint: "إدارة كبيرة مستقرة نسبيًا، لكنها ما زالت تتحمل ضغطًا واضحًا في الإحالات والزمن التنفيذي.",
        items:
        [
            DM(
                "m_housing_readiness", 100, 87,
                "جاهزية السكن والأصول",
                "إجمالي الوحدات: 1,320 | مشغولة: 1,188 | شاغرة: 74 | تحت الصيانة: 31 | إحالة جودة: 11 | إحالة خدمات عامة: 9 | جاهزة للتسكين: 7 | الأصول الرئيسية: منازل 1,090، وحدات عسكرية 176، حدائق 22، مواقف 31، مبانٍ خدمية 13"
            ),
            DM(
                "m_allocation_balance", 100, 82,
                "الإشغال وقوائم الانتظار",
                "الفئات الرئيسية: أفراد 362، ضباط صف 244، ضباط 186، مدنيون 141، ضباط كبار 78 | قوائم الانتظار: أفراد 63، ضباط صف 47، ضباط 29، مدنيون 21، ضباط كبار 8 | الفجوة الرئيسية في مواءمة الشواغر الجاهزة مع طلب الأفراد"
            ),
            DM(
                "m_requests_sla", 100, 76,
                "الطلبات وSLA",
                "الطلبات المفتوحة: تسكين 71، إمهال 36، إخلاء 28 | متوسط الإنجاز: الإمهال 5.2 يوم مقابل هدف 4.0، الإخلاء 4.5 مقابل 3.0، التسكين 3.5 مقابل 2.5 | الأداء مقبول تشغيلياً لكن دون الهدف التنفيذي"
            ),
            DM(
                "m_finance_utilities", 100, 83,
                "الماليات والاستهلاك",
                "الإيجارات المستحقة: الشهر الماضي 376,000 ر.س | آخر 3 أشهر 1,041,000 ر.س | آخر 12 شهراً 3,986,000 ر.س | كفاءة التحصيل 87% | الكهرباء 76% | الماء 67% | المطالبات مركّزة في فئة الأفراد وضباط الصف"
            ),
            DM(
                "m_maintenance_quality", 100, 86,
                "الصيانة والجودة",
                "الصيانة الوقائية المنجزة: 198 من 236 عمل | جاهزية الأسطول: 84% | الإحالات: جودة 11، خدمات عامة 9 | فرصة التحسين الأبرز في دورات الصيانة الوقائية للطرق والإنارة والبنية التحتية الخارجية"
            )
        ]),

    BuildDepartment(
        key: "dep_03",
        sortOrder: 3,
        name: "إدارة التشغيل والصيانة للمنشآت العسكرية بالرياض",
            shortName: "منشآت الرياض",

        icon: "fa-solid fa-building",
        emoji: "🏙️",
        tone: "success",
        color: Color.Green,
       // hint: "إدارة متوازنة في أغلب المؤشرات، وأداؤها مناسب كنموذج تشغيلي مستقر مع فرص محددة في تقليل زمن الإنجاز.",
        items:
        [
            DM(
                "m_housing_readiness", 100, 88,
                "جاهزية السكن والأصول",
                "إجمالي الوحدات: 1,268 | مشغولة: 1,142 | شاغرة: 63 | تحت الصيانة: 29 | إحالة جودة: 10 | إحالة خدمات عامة: 7 | جاهزة للتسكين: 8 | التوزيع الحي متوازن مع نسبة محدودة من الوحدات خارج الخدمة"
            ),
            DM(
                "m_allocation_balance", 100, 83,
                "الإشغال وقوائم الانتظار",
                "الفئات الرئيسية: أفراد 341، ضباط صف 228، ضباط 179، مدنيون 133 | قوائم الانتظار: أفراد 49، ضباط صف 35، ضباط 22 | الفرصة في تسريع إعادة استخدام الشواغر الجاهزة لامتصاص الضغط"
            ),
            DM(
                "m_requests_sla", 100, 77,
                "الطلبات وSLA",
                "الطلبات المفتوحة: تسكين 62، إمهال 28، إخلاء 22 | متوسط الإنجاز: الإمهال 5.1 يوم، الإخلاء 4.2، التسكين 3.4 | أفضل من عدة إدارات مقارنة لكن لا يزال دون الأهداف المعتمدة"
            ),
            DM(
                "m_finance_utilities", 100, 85,
                "الماليات والاستهلاك",
                "الإيجارات المستحقة: الشهر الماضي 335,000 ر.س | آخر 3 أشهر 946,000 ر.س | آخر 12 شهراً 3,401,000 ر.س | كفاءة التحصيل جيدة | الكهرباء 74% | الماء 61% | فرصة تقليل عبء الماء وتقادم المستحقات في الفئات العليا"
            ),
            DM(
                "m_maintenance_quality", 100, 89,
                "الصيانة والجودة",
                "الصيانة الوقائية المنجزة: 186 من 209 أعمال | جاهزية الأسطول: 88% | مستوى الجودة والسلامة مرتفع | انخفاض حجم الإحالات يعكس استقراراً تشغيلياً أقوى"
            )
        ]),

    BuildDepartment(
        key: "dep_04",
        sortOrder: 4,
        name: "إدارة التشغيل والصيانة للمنشآت العسكرية بجازان",
            shortName: "منشآت جازان",

        icon: "fa-solid fa-water",
        emoji: "🏙️",
        tone: "warning",
        color: Color.Sky,
        //hint: "البيئة الساحلية تزيد من تآكل الأصول وأعطال الشبكات، وتظهر الحساسية بوضوح في SLA والصيانة الوقائية.",
        items:
        [
            DM(
                "m_housing_readiness", 100, 78,
                "جاهزية السكن والأصول",
                "إجمالي الوحدات: 910 | مشغولة: 788 | شاغرة: 61 | تحت الصيانة: 36 | إحالة جودة: 12 | إحالة خدمات عامة: 8 | جاهزة للتسكين: 5 | الظروف الساحلية تضع ضغطاً أكبر على الشبكات وأغلفة المباني"
            ),
            DM(
                "m_allocation_balance", 100, 75,
                "الإشغال وقوائم الانتظار",
                "الفئات الرئيسية: أفراد 286، ضباط صف 174، ضباط 122، مدنيون 96 | ضغط الانتظار مرتفع في الأفراد 58 والمدنيين 19 | المخزون الجاهز لا يواكب وتيرة الطلب"
            ),
            DM(
                "m_requests_sla", 100, 70,
                "الطلبات وSLA",
                "الطلبات المفتوحة: تسكين 55، إمهال 31، إخلاء 26 | متوسط الإنجاز: الإمهال 6.0 يوم، الإخلاء 5.1، التسكين 4.0 | من الإدارات التي تستوجب متابعة تنفيذية مباشرة على SLA"
            ),
            DM(
                "m_finance_utilities", 100, 79,
                "الماليات والاستهلاك",
                "الإيجارات المستحقة: الشهر الماضي 248,000 ر.س | آخر 3 أشهر 721,000 ر.س | آخر 12 شهراً 2,614,000 ر.س | الكهرباء 81% | الماء 72% | انخفاض كفاءة التحصيل مرتبط بارتفاع تكلفة التشغيل الطارئ"
            ),
            DM(
                "m_maintenance_quality", 100, 81,
                "الصيانة والجودة",
                "الصيانة الوقائية المنجزة: 143 من 189 عمل | جاهزية الأسطول: 79% | الإحالات: جودة 12، خدمات عامة 8 | الفجوة الأكبر في دورات الوقائية لأنظمة المياه والتكييف والمواقع عالية الرطوبة"
            )
        ]),

    BuildDepartment(
        key: "dep_05",
        sortOrder: 5,
        name: "إدارة مدينة الملك خالد العسكرية للتشغيل والصيانة",
            shortName: "مدينة الملك خالد",

        icon: "fa-solid fa-shield-halved",
        emoji: "🏙️",
        tone: "success",
        color: Color.Violet,
        //hint: "إدارة قوية في الاستقرار التشغيلي والوقائي، لكن ما زال عندها مجال لتحسين توازن الانتظار والملف المالي.",
        items:
        [
            DM(
                "m_housing_readiness", 100, 86,
                "جاهزية السكن والأصول",
                "إجمالي الوحدات: 1,186 | مشغولة: 1,068 | شاغرة: 58 | تحت الصيانة: 27 | إحالة جودة: 13 | إحالة خدمات عامة: 11 | جاهزة للتسكين: 9 | الأصول الخدمية جيدة لكن بعض الوحدات معلّقة على اعتماد الخدمات العامة النهائي"
            ),
            DM(
                "m_allocation_balance", 100, 78,
                "الإشغال وقوائم الانتظار",
                "ضغط الانتظار واضح في الأفراد وضباط الصف رغم توفر شواغر في دورة التسليم | الأفراد انتظار/ساكنين: 52/311"
            ),
            DM(
                "m_requests_sla", 100, 73,
                "الطلبات وSLA",
                "الطلبات المفتوحة: تسكين 59، إمهال 30، إخلاء 24 | متوسط الإنجاز: الإمهال 5.6 يوم، الإخلاء 4.7، التسكين 3.7 | تحسين التنسيق بين التسكين والصيانة والخدمات سيرفع هذا المسار"
            ),
            DM(
                "m_finance_utilities", 100, 80,
                "الماليات والاستهلاك",
                "الإيجارات المستحقة: الشهر الماضي 301,000 ر.س | آخر 3 أشهر 884,000 ر.س | آخر 12 شهراً 3,119,000 ر.س | الكهرباء 79% | الماء 66% | المطالبات المالية مركّزة في فئتي الأفراد وضباط الصف"
            ),
            DM(
                "m_maintenance_quality", 100, 90,
                "الصيانة والجودة",
                "الصيانة الوقائية المنجزة: 177 من 197 عمل | جاهزية الأسطول: 89% | مستوى الجودة والسلامة قوي | إحالات الجودة تُغلق بدورات أقصر من متوسط الإدارات المماثلة"
            )
        ]),

    BuildDepartment(
        key: "dep_06",
        sortOrder: 6,
        name: "إدارة التشغيل والصيانة للمنشآت العسكرية بالقصيم",
            shortName: "منشآت القصيم",

        icon: "fa-solid fa-solar-panel",
        emoji: "🏙️",
        tone: "info",
        color: Color.Amber,
       // hint: "إدارة متوسطة الأداء، ويظهر فيها أثر تأخر الجاهزية على التخصيص والطلبات أكثر من أثر الماليات.",
        items:
        [
            DM(
                "m_housing_readiness", 100, 81,
                "جاهزية السكن والأصول",
                "إجمالي الوحدات: 874 | مشغولة: 756 | شاغرة: 51 | تحت الصيانة: 34 | إحالة جودة: 9 | إحالة خدمات عامة: 7 | جاهزة للتسكين: 4 | عنق الزجاجة الواضح في تحويل الوحدات المصانة إلى مخزون جاهز"
            ),
            DM(
                "m_allocation_balance", 100, 76,
                "الإشغال وقوائم الانتظار",
                "الطلب الأعلى في الأفراد يليهم ضباط الصف | ضغط الانتظار لا يزال فوق المخزون الشاغر الجاهز | كفاءة التخصيص مرتبطة بتسريع دورة الجاهزية"
            ),
            DM(
                "m_requests_sla", 100, 71,
                "الطلبات وSLA",
                "الطلبات المفتوحة: تسكين 47، إمهال 25، إخلاء 19 | متوسط الإنجاز: الإمهال 5.8 يوم، الإخلاء 4.9، التسكين 3.9 | المواقع الطرفية تستمر في التأثير على أوقات الإغلاق"
            ),
            DM(
                "m_finance_utilities", 100, 81,
                "الماليات والاستهلاك",
                "الإيجارات المستحقة: الشهر الماضي 214,000 ر.س | آخر 3 أشهر 612,000 ر.س | آخر 12 شهراً 2,284,000 ر.س | الكهرباء 73% | الماء 59% | الملف المالي مستقر لكن لم يصل للقوة المطلوبة"
            ),
            DM(
                "m_maintenance_quality", 100, 84,
                "الصيانة والجودة",
                "الصيانة الوقائية المنجزة: 129 من 154 عمل | جاهزية الأسطول: 81% | فرصة تحسين واضحة في برامج الوقائية للمركبات وانضباط إغلاق إحالات الجودة"
            )
        ]),

    BuildDepartment(
        key: "dep_07",
        sortOrder: 7,
        name: "إدارة التشغيل وصيانة المنشآت العسكرية بالطائف",
            shortName: "منشآت الطائف",

        icon: "fa-solid fa-mountain-city",
        emoji: "🏙️",
        tone: "info",
        color: Color.Purple,
        //hint: "إدارة ذات أساس جيد في الجودة والاستقرار العام، لكنها تحتاج تحسينًا في المسار المالي وبعض مدد الإمهال.",
        items:
        [
            DM(
                "m_housing_readiness", 100, 83,
                "جاهزية السكن والأصول",
                "إجمالي الوحدات: 932 | مشغولة: 817 | شاغرة: 53 | تحت الصيانة: 30 | إحالة جودة: 12 | إحالة خدمات عامة: 6 | جاهزة للتسكين: 6 | مزيج الأصول متوازن مع بعض الوحدات التي تحتاج تجديداً جزئياً"
            ),
            DM(
                "m_allocation_balance", 100, 79,
                "الإشغال وقوائم الانتظار",
                "الأفراد وضباط الصف المجموعتان الرئيسيتان في الضغط | فجوة الانتظار/الساكنين أصغر من جازان والقصيم لكنها مؤثرة على سرعة التخصيص"
            ),
            DM(
                "m_requests_sla", 100, 72,
                "الطلبات وSLA",
                "الطلبات المفتوحة: تسكين 49، إمهال 27، إخلاء 21 | متوسط الإنجاز: الإمهال 5.5 يوم، الإخلاء 4.6، التسكين 3.6 | طلبات الإمهال تحتاج متابعة أكثر إحكاماً"
            ),
            DM(
                "m_finance_utilities", 100, 80,
                "الماليات والاستهلاك",
                "الإيجارات المستحقة: الشهر الماضي 226,000 ر.س | آخر 3 أشهر 664,000 ر.س | آخر 12 شهراً 2,473,000 ر.س | الكهرباء 75% | الماء 62% | المطالبات موزعة بشكل أكثر توازناً بين الضباط والأفراد مقارنة بالإدارات الأخرى"
            ),
            DM(
                "m_maintenance_quality", 100, 87,
                "الصيانة والجودة",
                "الصيانة الوقائية المنجزة: 141 من 162 عمل | جاهزية الأسطول: 85% | مستوى الجودة جيد نسبياً لكن بعض إحالات الخدمات العامة لا تزال تبطئ عودة الوحدات للخدمة"
            )
        ])
];

        private static HousingCommandCenterDepartment BuildDepartment(
            string key,
            int sortOrder,
            string name,
            string shortName,
            string icon,
            string emoji,
            string tone,
            string color,
            List<HousingCommandCenterDepartmentMetric> items)
        {
            var overall = items.Any()
              ? items.Average(x =>
                x.Target > 0
                  ? Math.Round((x.Actual ?? 0m) / x.Target.Value * 100m, 1)
                 : 0m)
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
            string metricKey,
            decimal target,
            decimal actual,
            string noteTitle,
            string detail)
        {
            var remaining = Math.Max(target - actual, 0m);
            var percent = target <= 0 ? 0m : Math.Round((actual / target) * 100m, 1);

            
            return new HousingCommandCenterDepartmentMetric
            {
                MetricKey = metricKey,
                Target = target,
                Actual = actual,
                CompletionPercent = null,    //  الجافاسكريبت يحسبها
                DisplayText = null,          //  الجافاسكريبت يعرضها
                Note = $"{noteTitle} | {detail}"
            };
        }

        private static HousingCommandCenterSummaryRow BuildSummaryRow(
            List<HousingCommandCenterMetric> metrics,
            List<HousingCommandCenterDepartment> departments)
        {
            var summary = new HousingCommandCenterSummaryRow
            {
                Label = "إجمالي جميع الإدارات"
            };

            foreach (var metric in metrics.OrderBy(x => x.SortOrder))
            {
                var related = departments
                    .SelectMany(d => d.Metrics)
                    .Where(m => m.MetricKey == metric.Key)
                    .ToList();

                var target = related.Sum(x => x.Target ?? 0m);
                var actual = related.Sum(x => x.Actual ?? 0m);
                var remaining = Math.Max(target - actual, 0m);
                var percent = target <= 0 ? 0m : Math.Round((actual / target) * 100m, 1);

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
            new() { Label = "أقل من 120م²", Value = 164, Color = "#0f766e" },
            new() { Label = "120-180م²",    Value = 492, Color = "#2563eb" },
            new() { Label = "181-250م²",    Value = 418, Color = "#d97706" },
            new() { Label = "251-350م²",    Value = 267, Color = "#7c3aed" },
            new() { Label = "أكثر من 350م²",Value = 141, Color = "#dc2626" },
        },
            RoomDistribution = new()
        {
            new() { Label = "غرفة واحدة", Value = 42,  Color = "#0f766e" },
            new() { Label = "غرفتان",      Value = 154, Color = "#2563eb" },
            new() { Label = "3 غرف",       Value = 386, Color = "#d97706" },
            new() { Label = "4 غرف",       Value = 471, Color = "#7c3aed" },
            new() { Label = "5 غرف",       Value = 294, Color = "#0891b2" },
            new() { Label = "6+ غرف",      Value = 135, Color = "#dc2626" },
        },
            FacilityTypes = new()
        {
            new() { Label = "منازل عائلية",  Value = 1248, Color = "#0f766e" },
            new() { Label = "وحدات عسكرية", Value = 214,  Color = "#2563eb" },
            new() { Label = "وحدات عزاب",   Value = 81,   Color = "#d97706" },
            new() { Label = "حدائق",         Value = 26,   Color = "#16a34a" },
            new() { Label = "مبانٍ خدمية",  Value = 17,   Color = "#64748b" },
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
            new() { Label = "أقل من 120م²", Value = 120, Color = "#0f766e" },
            new() { Label = "120-250م²",    Value = 500, Color = "#2563eb" },
            new() { Label = "أكثر من 250م²",Value = 280, Color = "#d97706" },
        },
            RoomDistribution = new()
        {
            new() { Label = "1-2 غرف", Value = 150, Color = "#0f766e" },
            new() { Label = "3-4 غرف", Value = 500, Color = "#2563eb" },
            new() { Label = "5+ غرف",  Value = 250, Color = "#d97706" },
        },
            FacilityTypes = new()
        {
            new() { Label = "منازل عائلية",  Value = 700, Color = "#0f766e" },
            new() { Label = "وحدات عسكرية", Value = 150, Color = "#2563eb" },
            new() { Label = "مرافق أخرى",   Value = 50,  Color = "#d97706" },
        }
        }
    };

        private static DepAllocationDetail BuildAllocationDetail(string depId) => depId switch
        {
            "dep_01" => new DepAllocationDetail
            {
                Categories = new()
        {
            new() { Label = "القادة",  Residents = 8,  Waiting = 0, Color = "#0f766e" },
            new() { Label = "كيار الضباط",  Residents = 92,  Waiting = 12, Color = "#0f766e" },
            new() { Label = "ضباط",        Residents = 214, Waiting = 612, Color = "#2563eb" },
            new() { Label = "ضباط صف",       Residents = 1204, Waiting = 7410, Color = "#dc2626" },
            new() { Label = "جنود",    Residents = 276, Waiting = 2108, Color = "#d97706" },
            new() { Label = "مدنيون",      Residents = 165, Waiting = 315, Color = "#7c3aed" },
            new() { Label = "متعاقدون",    Residents = 38,  Waiting = 14, Color = "#0891b2" },
        },
                Districts = new()
        {
            new() { Label = "القادسية", Value = 224, Color = "#0f766e" },
            new() { Label = "النخيل",   Value = 205, Color = "#2563eb" },
            new() { Label = "الربوة",   Value = 198, Color = "#d97706" },
            new() { Label = "اليرموك", Value = 190, Color = "#7c3aed" },
            new() { Label = "الفيصلية",Value = 183, Color = "#0891b2" },
            new() { Label = "الورود",   Value = 176, Color = "#16a34a" },
            new() { Label = "الصفا",    Value = 162, Color = "#dc2626" },
            new() { Label = "الأندلس", Value = 144, Color = "#64748b" },
        }
            },
            _ => new DepAllocationDetail
            {
                Categories = new()
        {
            new() { Label = "ضباط",     Residents = 150, Waiting = 25, Color = "#2563eb" },
            new() { Label = "ضباط صف", Residents = 200, Waiting = 40, Color = "#d97706" },
            new() { Label = "أفراد",    Residents = 300, Waiting = 55, Color = "#dc2626" },
            new() { Label = "مدنيون",   Residents = 100, Waiting = 20, Color = "#7c3aed" },
        },
                Districts = new()
        {
            new() { Label = "الحي الأول",  Value = 180, Color = "#0f766e" },
            new() { Label = "الحي الثاني", Value = 160, Color = "#2563eb" },
            new() { Label = "الحي الثالث", Value = 140, Color = "#d97706" },
            new() { Label = "الحي الرابع", Value = 120, Color = "#7c3aed" },
        }
            }
        };

        private static DepRequestsDetail BuildRequestsDetail(string depId) => depId switch
        {
            "dep_01" => new DepRequestsDetail
            {
                OpenRequests = new()
        {
            new() { Label = "تسكين",      Value = 84, Color = "#0f766e" },
            new() { Label = "إمهال",       Value = 42, Color = "#d97706" },
            new() { Label = "إخلاء",       Value = 31, Color = "#dc2626" },
            new() { Label = "صيانة",       Value = 36, Color = "#2563eb" },
            new() { Label = "نقل داخلي",  Value = 12, Color = "#7c3aed" },
        },
                SlaComparison = new()
        {
            new() { Label = "الإمهال",  Actual = 1.6m, Target = 3.0m, Color = "#d97706" },
            new() { Label = "الإخلاء",  Actual = 4.9m, Target = 3.0m, Color = "#dc2626" },
            new() { Label = "التسكين",  Actual = 3.8m, Target = 2.0m, Color = "#0f766e" },
        }
            },
            _ => new DepRequestsDetail
            {
                OpenRequests = new()
        {
            new() { Label = "تسكين", Value = 55, Color = "#0f766e" },
            new() { Label = "إمهال",  Value = 30, Color = "#d97706" },
            new() { Label = "إخلاء",  Value = 25, Color = "#dc2626" },
        },
                SlaComparison = new()
        {
            new() { Label = "الإمهال", Actual = 5.5m, Target = 4.0m, Color = "#d97706" },
            new() { Label = "الإخلاء", Actual = 4.5m, Target = 3.0m, Color = "#dc2626" },
            new() { Label = "التسكين", Actual = 3.6m, Target = 2.5m, Color = "#0f766e" },
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
            new() { Label = "الايجار",      Value = 89, Color = "#0f766e" },
            new() { Label = "الكهرباء",      Value = 78, Color = "#d97706" },
            new() { Label = "الماء",          Value = 64, Color = "#2563eb" },
            new() { Label = "الغاز",          Value = 97, Color = "#7c3aed" },
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
                PaidByATM =  165852,
                PaidByCash = 22896,

                UtilityEfficiency = new()
        {
              new() { Label = "الايجار",      Value = 84, Color = "#0f766e" },
            new() { Label = "الكهرباء",      Value = 78, Color = "#d97706" },
            new() { Label = "الماء",          Value = 64, Color = "#2563eb" },
            new() { Label = "الغاز",          Value = 90, Color = "#7c3aed" },
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
            new() { Label = "السلامة",  Value = 87, Color = "#16a34a" },
            new() { Label = "الماء",    Value = 91, Color = "#0f766e" },
            new() { Label = "الغاز", Value = 55, Color = "#d97706" },
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
            new() { Label = "السلامة",  Value = 87, Color = "#16a34a" },
            new() { Label = "الماء",    Value = 91, Color = "#0f766e" },
            new() { Label = "الغاز", Value = 55, Color = "#d97706" },
        }
            },

        };
    } }