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
                    ShowHeader = true,
                    ShowSummaryRow = true,
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
                Actual = 84,
                CompletionPercent = 84,
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
                Target = 100,
                Actual = 79,
                CompletionPercent = 79,
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
                Target = 100,
                Actual = 74,
                CompletionPercent = 74,
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
                CompletionPercent = 81,
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
                CompletionPercent = 86,
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
                icon: "fa-solid fa-city",
                emoji: "🏙️",
                tone: "success",
                color: Color.Teal,
                hint: "أكبر نطاق تشغيلي على مستوى اللوحة، ويُستخدم كمرجع مقارنة لبقية الإدارات في السكن والطلبات والصيانة والماليات.",
                items:
                [
                    DM(
                        "m_housing_readiness", 100, 89,
                        "جاهزية السكن والأصول",
                        "Housing stock totals: 1,482 units | Occupied: 1,355 | Vacant: 67 | Under maintenance: 28 | Referred to quality: 14 | Referred to public services: 10 | Ready for allocation: 8 | Areas: <120 sqm = 164, 120-180 = 492, 181-250 = 418, 251-350 = 267, >350 = 141 | Rooms: 1 room = 42, 2 rooms = 154, 3 rooms = 386, 4 rooms = 471, 5 rooms = 294, 6+ = 135 | Major facilities: family houses 1,248, military units 214, bachelor units 81, parks 26, service buildings 17."
                    ),
                    DM(
                        "m_allocation_balance", 100, 85,
                        "الإشغال وقوائم الانتظار",
                        "Housing categories: senior officers 92, officers 214, NCOs 276, soldiers 418, civilians 165, contractors 38, users 43, retirees 9, visitors/experts 3, unclassified 1 | Waiting vs residents: senior officers 12/86, officers 38/201, NCOs 54/261, soldiers 71/395, civilians 29/151, contractors 14/38 | District distribution: Qadisiyah 224, Nakheel 205, Rabwah 198, Yarmouk 190, Faisaliyah 183, Wurood 176, Safa 162, Andalus 144."
                    ),
                    DM(
                        "m_requests_sla", 100, 79,
                        "الطلبات وSLA",
                        "Open requests: allocation 84, grace 42, eviction 31, maintenance 36, internal transfer 12 | Avg. completion: grace 5.7 days vs target 4.0, eviction 4.9 vs 3.0, allocation 3.8 vs 2.5 | Main executive pressure remains in allocation and grace tracks."
                    ),
                    DM(
                        "m_finance_utilities", 100, 84,
                        "الماليات والاستهلاك",
                        "Outstanding rent: last month SAR 412,000 | last 3 months SAR 1,189,000 | last 12 months SAR 4,538,000 | Collected SAR 3,941,000 | Uncollected SAR 597,000 | Claims concentration highest in soldiers, NCOs, then officers | Utility efficiency: electricity 78%, water 64%."
                    ),
                    DM(
                        "m_maintenance_quality", 100, 88,
                        "الصيانة والجودة",
                        "Preventive maintenance completed: 221 out of 260 planned jobs | Fleet and vehicles readiness: 86% | Referrals: quality 14, public services 10 | Utility condition: safety 87%, gas 91%, internet 55% | Main recommendation: accelerate preventive closure of repetitive-failure sites."
                    )
                ]),

            BuildDepartment(
                key: "dep_02",
                sortOrder: 2,
                name: "إدارة مدينة الملك عبدالعزيز العسكرية للتشغيل والصيانة",
                icon: "fa-solid fa-fort-awesome",
                emoji: "🏰",
                tone: "success",
                color: Color.Blue,
                hint: "إدارة كبيرة مستقرة نسبيًا، لكنها ما زالت تتحمل ضغطًا واضحًا في الإحالات والزمن التنفيذي لبعض المسارات.",
                items:
                [
                    DM(
                        "m_housing_readiness", 100, 87,
                        "جاهزية السكن والأصول",
                        "Housing stock totals: 1,320 units | Occupied: 1,188 | Vacant: 74 | Under maintenance: 31 | Referred to quality: 11 | Referred to public services: 9 | Ready for allocation: 7 | Core assets include 1,090 houses, 176 military units, 22 parks, 31 parking zones, and 13 service buildings."
                    ),
                    DM(
                        "m_allocation_balance", 100, 82,
                        "الإشغال وقوائم الانتظار",
                        "Key categories: soldiers 362, NCOs 244, officers 186, civilians 141, senior officers 78 | Waiting list: soldiers 63, NCOs 47, officers 29, civilians 21, senior officers 8 | Main gap appears in aligning ready vacancies with soldiers demand."
                    ),
                    DM(
                        "m_requests_sla", 100, 76,
                        "الطلبات وSLA",
                        "Open requests: allocation 71, grace 36, eviction 28 | Avg. completion: grace 5.2 days vs target 4.0, eviction 4.5 vs 3.0, allocation 3.5 vs 2.5 | Operationally acceptable but still below executive target."
                    ),
                    DM(
                        "m_finance_utilities", 100, 83,
                        "الماليات والاستهلاك",
                        "Outstanding rent: last month SAR 376,000 | last 3 months SAR 1,041,000 | last 12 months SAR 3,986,000 | Collection efficiency 87% | Electricity 76% | Water 67% | Claims remain concentrated in soldiers and NCO categories."
                    ),
                    DM(
                        "m_maintenance_quality", 100, 86,
                        "الصيانة والجودة",
                        "Preventive maintenance completed: 198 of 236 jobs | Fleet readiness: 84% | Referrals: quality 11, public services 9 | Most visible improvement opportunity lies in roads, lighting, and external infrastructure preventive cycles."
                    )
                ]),

            BuildDepartment(
                key: "dep_03",
                sortOrder: 3,
                name: "إدارة التشغيل والصيانة للمنشآت العسكرية بالرياض",
                icon: "fa-solid fa-building",
                emoji: "🏢",
                tone: "success",
                color: Color.Green,
                hint: "إدارة متوازنة في أغلب المؤشرات، وأداؤها مناسب كنموذج تشغيلي مستقر مع فرص محددة في تقليل زمن الإنجاز.",
                items:
                [
                    DM(
                        "m_housing_readiness", 100, 88,
                        "جاهزية السكن والأصول",
                        "Housing stock totals: 1,268 units | Occupied: 1,142 | Vacant: 63 | Under maintenance: 29 | Referred to quality: 10 | Referred to public services: 7 | Ready for allocation: 8 | District spread is balanced, with only a limited portion of units still outside service."
                    ),
                    DM(
                        "m_allocation_balance", 100, 83,
                        "الإشغال وقوائم الانتظار",
                        "Top categories: soldiers 341, NCOs 228, officers 179, civilians 133 | Waiting list: soldiers 49, NCOs 35, officers 22 | Better opportunity exists to absorb waiting pressure through faster reuse of ready vacancies."
                    ),
                    DM(
                        "m_requests_sla", 100, 77,
                        "الطلبات وSLA",
                        "Open requests: allocation 62, grace 28, eviction 22 | Avg. completion: grace 5.1 days, eviction 4.2, allocation 3.4 | Better than several peers, but still behind approved targets."
                    ),
                    DM(
                        "m_finance_utilities", 100, 85,
                        "الماليات والاستهلاك",
                        "Outstanding rent: last month SAR 335,000 | last 3 months SAR 946,000 | last 12 months SAR 3,401,000 | Collection efficiency remains healthy | Electricity 74% | Water 61% | Main financial opportunity is reducing water burden and high-category receivable aging."
                    ),
                    DM(
                        "m_maintenance_quality", 100, 89,
                        "الصيانة والجودة",
                        "Preventive maintenance completed: 186 of 209 jobs | Fleet readiness: 88% | Quality and safety levels remain high | Lower referral volume indicates stronger operational stability."
                    )
                ]),

            BuildDepartment(
                key: "dep_04",
                sortOrder: 4,
                name: "إدارة التشغيل والصيانة للمنشآت العسكرية بجازان",
                icon: "fa-solid fa-water",
                emoji: "🌊",
                tone: "warning",
                color: Color.Sky,
                hint: "بيئة التشغيل الساحلية تجعل هذه الإدارة أكثر تعرضًا لتآكل الأصول وارتفاع أعطال الشبكات، لذلك تظهر الحساسية بوضوح في SLA والوقائية.",
                items:
                [
                    DM(
                        "m_housing_readiness", 100, 78,
                        "جاهزية السكن والأصول",
                        "Housing stock totals: 910 units | Occupied: 788 | Vacant: 61 | Under maintenance: 36 | Referred to quality: 12 | Referred to public services: 8 | Ready for allocation: 5 | Coastal conditions place heavier stress on networks and building shells."
                    ),
                    DM(
                        "m_allocation_balance", 100, 75,
                        "الإشغال وقوائم الانتظار",
                        "Main categories: soldiers 286, NCOs 174, officers 122, civilians 96 | Waiting pressure remains high in soldiers 58 and civilians 19 | Ready stock remains below the pace of demand."
                    ),
                    DM(
                        "m_requests_sla", 100, 70,
                        "الطلبات وSLA",
                        "Open requests: allocation 55, grace 31, eviction 26 | Avg. completion: grace 6.0 days, eviction 5.1, allocation 4.0 | This is one of the departments requiring direct executive follow-up on SLA."
                    ),
                    DM(
                        "m_finance_utilities", 100, 79,
                        "الماليات والاستهلاك",
                        "Outstanding rent: last month SAR 248,000 | last 3 months SAR 721,000 | last 12 months SAR 2,614,000 | Electricity 81% | Water 72% | Lower collection efficiency is linked with higher emergency operating cost."
                    ),
                    DM(
                        "m_maintenance_quality", 100, 81,
                        "الصيانة والجودة",
                        "Preventive maintenance completed: 143 of 189 jobs | Fleet readiness: 79% | Referrals: quality 12, public services 8 | Biggest gap remains preventive cycles for water systems, HVAC, and high-humidity sites."
                    )
                ]),

            BuildDepartment(
                key: "dep_05",
                sortOrder: 5,
                name: "إدارة مدينة الملك خالد العسكرية للتشغيل والصيانة",
                icon: "fa-solid fa-shield-halved",
                emoji: "🛡️",
                tone: "success",
                color: Color.Violet,
                hint: "إدارة قوية في الاستقرار التشغيلي والوقائي، لكن ما زال عندها مجال لتحسين توازن الانتظار والملف المالي.",
                items:
                [
                    DM(
                        "m_housing_readiness", 100, 86,
                        "جاهزية السكن والأصول",
                        "Housing stock totals: 1,186 units | Occupied: 1,068 | Vacant: 58 | Under maintenance: 27 | Referred to quality: 13 | Referred to public services: 11 | Ready for allocation: 9 | Service assets are healthy, but some units remain pending final public services clearance."
                    ),
                    DM(
                        "m_allocation_balance", 100, 78,
                        "الإشغال وقوائم الانتظار",
                        "Waiting pressure is notable in soldiers and NCOs despite available vacancies progressing through turnover cycle | Soldiers waiting/residents: 52/311."
                    ),
                    DM(
                        "m_requests_sla", 100, 73,
                        "الطلبات وSLA",
                        "Open requests: allocation 59, grace 30, eviction 24 | Avg. completion: grace 5.6 days, eviction 4.7, allocation 3.7 | Better coordination between allocation, maintenance, and services would raise this track."
                    ),
                    DM(
                        "m_finance_utilities", 100, 80,
                        "الماليات والاستهلاك",
                        "Outstanding rent: last month SAR 301,000 | last 3 months SAR 884,000 | last 12 months SAR 3,119,000 | Electricity 79% | Water 66% | Financial claims remain concentrated in soldiers and NCO groups."
                    ),
                    DM(
                        "m_maintenance_quality", 100, 90,
                        "الصيانة والجودة",
                        "Preventive maintenance completed: 177 of 197 jobs | Fleet readiness: 89% | Quality and safety posture is strong | Quality referrals exist but close in shorter cycles than peer average."
                    )
                ]),

            BuildDepartment(
                key: "dep_06",
                sortOrder: 6,
                name: "إدارة التشغيل والصيانة للمنشآت العسكرية بالقصيم",
                icon: "fa-solid fa-solar-panel",
                emoji: "🏜️",
                tone: "info",
                color: Color.Amber,
                hint: "إدارة متوسطة الأداء، ويظهر فيها أثر تأخر الجاهزية على التخصيص والطلبات أكثر من أثر الماليات.",
                items:
                [
                    DM(
                        "m_housing_readiness", 100, 81,
                        "جاهزية السكن والأصول",
                        "Housing stock totals: 874 units | Occupied: 756 | Vacant: 51 | Under maintenance: 34 | Referred to quality: 9 | Referred to public services: 7 | Ready for allocation: 4 | A visible bottleneck remains in converting maintained units into ready stock."
                    ),
                    DM(
                        "m_allocation_balance", 100, 76,
                        "الإشغال وقوائم الانتظار",
                        "Highest demand remains in soldiers followed by NCOs | Waiting pressure is still above ready vacant stock | Allocation efficiency depends on faster readiness turnover."
                    ),
                    DM(
                        "m_requests_sla", 100, 71,
                        "الطلبات وSLA",
                        "Open requests: allocation 47, grace 25, eviction 19 | Avg. completion: grace 5.8 days, eviction 4.9, allocation 3.9 | Peripheral sites continue to affect closure times."
                    ),
                    DM(
                        "m_finance_utilities", 100, 81,
                        "الماليات والاستهلاك",
                        "Outstanding rent: last month SAR 214,000 | last 3 months SAR 612,000 | last 12 months SAR 2,284,000 | Electricity 73% | Water 59% | Financial profile is stable but not yet strong."
                    ),
                    DM(
                        "m_maintenance_quality", 100, 84,
                        "الصيانة والجودة",
                        "Preventive maintenance completed: 129 of 154 jobs | Fleet readiness: 81% | Clear improvement opportunity exists in vehicle preventive programs and quality closure discipline."
                    )
                ]),

            BuildDepartment(
                key: "dep_07",
                sortOrder: 7,
                name: "إدارة التشغيل وصيانة المنشآت العسكرية بالطائف",
                icon: "fa-solid fa-mountain-city",
                emoji: "⛰️",
                tone: "info",
                color: Color.Purple,
                hint: "إدارة ذات أساس جيد في الجودة والاستقرار العام، لكنها تحتاج تحسينًا أدق في المسار المالي وبعض مدد الإمهال.",
                items:
                [
                    DM(
                        "m_housing_readiness", 100, 83,
                        "جاهزية السكن والأصول",
                        "Housing stock totals: 932 units | Occupied: 817 | Vacant: 53 | Under maintenance: 30 | Referred to quality: 12 | Referred to public services: 6 | Ready for allocation: 6 | Asset mix remains balanced, though some units still require partial renewal."
                    ),
                    DM(
                        "m_allocation_balance", 100, 79,
                        "الإشغال وقوائم الانتظار",
                        "Soldiers and NCOs remain the main pressure groups | Waiting/resident gap is smaller than Jazan and Qassim, yet still influential on allocation speed."
                    ),
                    DM(
                        "m_requests_sla", 100, 72,
                        "الطلبات وSLA",
                        "Open requests: allocation 49, grace 27, eviction 21 | Avg. completion: grace 5.5 days, eviction 4.6, allocation 3.6 | Grace requests need tighter follow-up."
                    ),
                    DM(
                        "m_finance_utilities", 100, 80,
                        "الماليات والاستهلاك",
                        "Outstanding rent: last month SAR 226,000 | last 3 months SAR 664,000 | last 12 months SAR 2,473,000 | Electricity 75% | Water 62% | Claims are distributed more evenly between officers and soldiers than in peer departments."
                    ),
                    DM(
                        "m_maintenance_quality", 100, 87,
                        "الصيانة والجودة",
                        "Preventive maintenance completed: 141 of 162 jobs | Fleet readiness: 85% | Quality level remains comparatively good, but some public services referrals still slow unit return to service."
                    )
                ])
        ];

        private static HousingCommandCenterDepartment BuildDepartment(
            string key,
            int sortOrder,
            string name,
            string icon,
            string emoji,
            string tone,
            string color,
            string hint,
            List<HousingCommandCenterDepartmentMetric> items)
        {
            var overall = items.Any() ? items.Average(x => x.CompletionPercent ?? 0m) : 0m;

            return new HousingCommandCenterDepartment
            {
                Key = key,
                SortOrder = sortOrder,
                Name = name,
                Icon = icon,
                Emoji = emoji,
                Tone = tone,
                Color = color,
                Hint = hint,
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
                CompletionPercent = percent,
                DisplayText = percent.ToString("0.0", CultureInfo.InvariantCulture) + "%",
                Note = $"{noteTitle} | Target {target.ToString("0", CultureInfo.InvariantCulture)} | Actual {actual.ToString("0", CultureInfo.InvariantCulture)} | Remaining {remaining.ToString("0", CultureInfo.InvariantCulture)}. {detail}"
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
                    CompletionPercent = percent,
                    DisplayText = percent.ToString("0.0", CultureInfo.InvariantCulture) + "%",
                    Tone = metric.Tone,
                    Color = metric.Color,
                    Note = $"Total target {target.ToString("0", CultureInfo.InvariantCulture)} | Total actual {actual.ToString("0", CultureInfo.InvariantCulture)} | Remaining {remaining.ToString("0", CultureInfo.InvariantCulture)}"
                });
            }

            return summary;
        }
    }
}