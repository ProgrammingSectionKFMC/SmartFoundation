using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartCharts;

namespace SmartFoundation.Mvc.Controllers
{
    public class DashboardController : Controller
    {
        public IActionResult Index()
        {
            var charts = new SmartChartsConfig
            {
                Title = "لوحة مؤشرات الإسكان والمباني والصيانة والساكنين ( شاشة تجريبية قيد التطوير لعرض المكونات )",
                Dir = "rtl",
                Cards = new List<ChartCardConfig>
                {


                    // ================== 9) StatsGrid ==================
                    new ChartCardConfig
                    {
                        Type = ChartCardType.StatsGrid,
                        Title = "إحصائيات وأرقام تنفيذية",
                        Subtitle = "ملخص قرار سريع: إشغال / شواغر / صيانة / تكاليف",
                        Icon = "fa-solid fa-chart-simple",
                        Tone = ChartTone.Info,
                        ColCss = "6 md:6",
                        Dir = "rtl",

                        StatsGridAnimate = true,
                        StatsGridGroups = new List<StatsGridGroup>
                        {
                            new StatsGridGroup
                            {
                                Title = "الوحدات المشغولة",
                                Subtitle = "الحالة الحالية",
                                Badge = "اليوم",
                                Items = new List<StatsGridItem>
                                {
                                    new StatsGridItem
                                    {
                                        Label = "عدد الوحدات المشغولة",
                                        Value = "8,580",
                                        Unit = "وحدة",
                                        Icon = "fa-solid fa-house-circle-check",
                                        Hint = "إجمالي الوحدات المستفيدة حالياً",
                                        Delta = "+1.9%",
                                        DeltaPositive = true,
                                        Href = "/Housing/Occupancy?status=occupied"
                                    },
                                    new StatsGridItem
                                    {
                                        Label = "نسبة الإشغال",
                                        Value = "91.6",
                                        Unit = "%",
                                        Icon = "fa-solid fa-percent",
                                        Hint = "إشغال = مشغولة ÷ إجمالي الوحدات",
                                        Delta = "+0.8%",
                                        DeltaPositive = true,
                                        Href = "/Housing/Occupancy"
                                    }
                                }
                            },
                            new StatsGridGroup
                            {
                                Title = "الشواغر والصيانة",
                                Subtitle = "نقاط قرار سريعة",
                                Badge = "هذا الشهر",
                                Items = new List<StatsGridItem>
                                {
                                    new StatsGridItem
                                    {
                                        Label = "وحدات شاغرة قابلة للتأجير",
                                        Value = "410",
                                        Unit = "وحدة",
                                        Icon = "fa-solid fa-house-circle-xmark",
                                        Hint = "متاحة للترشيح/التخصيص",
                                        Delta = "-6.2%",
                                        DeltaPositive = false,
                                        Href = "/Housing/Vacancy?type=available"
                                    },
                                    new StatsGridItem
                                    {
                                        Label = "وحدات تحت الصيانة",
                                        Value = "190",
                                        Unit = "وحدة",
                                        Icon = "fa-solid fa-screwdriver-wrench",
                                        Hint = "تحتاج تسريع الإغلاق لتقليل الفاقد",
                                        Delta = "+3.1%",
                                        DeltaPositive = false,
                                        Href = "/Maintenance?status=in_progress"
                                    }
                                }
                            }
                        }
                    },

                     

                    // ================== 2) لوحة تشغيل: مؤشرات متعددة (Radial Rings) ==================
                    new ChartCardConfig
                    {
                        Type = ChartCardType.RadialRings,
                        Title = "مؤشرات التشغيل",
                        Subtitle = "إشغال • جاهزية • SLA • شواغر",
                        Icon = "fa-solid fa-circle-nodes",
                        Tone = ChartTone.Info,
                        ColCss = "6 md:6",
                        Dir = "rtl",

                        RadialRingSize = 280,
                        RadialRingThickness = 10,
                        RadialRingGap = 8,
                        RadialRingShowLegend = true,
                        RadialRingValueFormat = "0",

                        RadialRings = new List<RadialRingItem>
                        {
                            new RadialRingItem { Key="occupancy", Label="الإشغال",         Value=92,  Max=100, ValueText="92%",  Href="/Residents/Occupancy" },
                            new RadialRingItem { Key="readiness", Label="جاهزية الوحدات",  Value=86,  Max=100, ValueText="86%",  Href="/Housing/Readiness" },
                            new RadialRingItem { Key="sla",       Label="صيانة ضمن SLA",   Value=78,  Max=100, ValueText="78%",  Href="/Maintenance/Sla" },
                            new RadialRingItem { Key="vacancy",   Label="الشواغر الجاهزة", Value=410, Max=800, ValueText="410",  Href="/Housing/Vacant" },
                        }
                    },


                    

                    // ================== Pie3D: توزيع الوحدات حسب فئة المستفيد ==================
                            new ChartCardConfig
                            {
                                Type = ChartCardType.Pie3D,
                                Title = "توزيع الوحدات حسب فئة المستفيد",
                                Subtitle = "3D Pie يوضح مزج الفئات + قابل للنقر للتفاصيل",
                                Icon = "fa-solid fa-pizza-slice",
                                Tone = ChartTone.Info,
                                ColCss = "6 md:6",
                                Dir = "rtl",

                                Pie3DSize = 300,
                                Pie3DHeight = 20,
                                Pie3DInnerHole = 0,               // خليها 0 عشان Pie فعلي
                                Pie3DShowLegend = true,
                                Pie3DShowCenterTotal = true,
                                Pie3DValueFormat = "0",
                                Pie3DExplodeOnHover = true,

                                Pie3DSlices = new List<Pie3DSlice>
                                {
                                    new Pie3DSlice { Key="leaders",  Label="منازل كبار القادة",   Value=120,  Href="/Housing?segment=leaders",  Hint="سكن تنفيذي مخصص" },
                                    new Pie3DSlice { Key="officers", Label="سكن الضباط",         Value=480,  Href="/Housing?segment=officers", Hint="وحدات للضباط" },
                                    new Pie3DSlice { Key="ncos",     Label="سكن ضباط الصف",      Value=760,  Href="/Housing?segment=ncos",     Hint="NCO Housing" },
                                    new Pie3DSlice { Key="enlisted", Label="سكن الأفراد",        Value=1320, Href="/Housing?segment=enlisted", Hint="Enlisted Housing" },
                                    new Pie3DSlice { Key="singles",  Label="سكن العزاب",         Value=610,  Href="/Housing?segment=singles",  Hint="Singles Quarters" },
                                    new Pie3DSlice { Key="families", Label="وحدات العوائل", /*Color="#504E92",*/     Value=2240, Href="/Housing?segment=families", Hint="Family Units" },
                                    new Pie3DSlice { Key="guest",    Label="الضيافة/المؤقت",     Value=95,   Href="/Housing?segment=guest",    Hint="Temporary / Guest" },
                                    new Pie3DSlice { Key="vip_hold", Label="محجوزة/حجز VIP",     Value=210,  Href="/Housing?segment=vip_hold", Hint="Reserved / Hold" },
                                }
                            },

                            // ================== 4) ColumnPro: الوحدات حسب الحي ==================
                                    new ChartCardConfig
                                    {
                                        Type = ChartCardType.ColumnPro,
                                        Title = "الوحدات حسب الحي",
                                        Subtitle = "مقارنة عدد الوحدات بين الأحياء",
                                        Icon = "fa-solid fa-city",
                                        Tone = ChartTone.Info,
                                        ColCss = "6 md:6",
                                        Dir = "rtl",

                                        ColumnProLabels = new List<string>
                                        {
                                            "النرجس","الياسمين","الملقا","العارض","القيروان","حطين","الندى","الواحة"
                                        },
                                        ColumnProSeries = new List<ChartSeries>
                                        {
                                            new ChartSeries
                                            {
                                                Name = "الوحدات",
                                                Data = new List<decimal> { 1240, 980, 760, 540, 410, 390, 360, 200 }
                                            }
                                        },

                                        ColumnProShowValues = true,
                                        ColumnProValueFormat = "0",
                                        ColumnProMinBarWidth = 56,

                                        //مهم: لازم عدد الروابط يساوي عدد ColumnProLabels
                                        ColumnProHrefs = new List<string>
                                        {
                                            "/Housing?district=nargis",
                                            "/Housing?district=yasmin",
                                            "/Housing?district=malqa",
                                            "/Housing?district=aredh",
                                            "/Housing?district=qirawan",
                                            "/Housing?district=hittin",
                                            "/Housing?district=nada",
                                            "/Housing?district=wahah"
                                        }
                                    },


                    // ================== 9) OpsBoard ==================

                               new ChartCardConfig
                                {
                                    Type = ChartCardType.OpsBoard,
                                    Title = "لوحة التشغيل اليومية",
                                    Subtitle = "تشغيل الصيانة + الساكنين + المباني + الإسكان (آخر 24 ساعة)",
                                    Icon = "fa-solid fa-layer-group",
                                    Tone = ChartTone.Info,
                                    ColCss = "12 md:6",
                                    Dir = "rtl",

                                    OpsBoardAnimate = true,
                                    OpsBoardCompact = false,
                                    OpsBoardColumns = 2,

                                    OpsBoardSections = new List<OpsBoardSection>
                                    {
                                        new OpsBoardSection
                                        {
                                            Title = "الصيانة",
                                            Subtitle = "البلاغات والالتزام والقطع",
                                            Icon = "fa-solid fa-screwdriver-wrench",
                                            Badge = "آخر 24 ساعة",
                                            Href = "/Maintenance",

                                            Kpis = new List<OpsBoardKpi>
                                            {
                                                new OpsBoardKpi{
                                                    Label="بلاغات جديدة",
                                                    Value="148",
                                                    Unit="بلاغ",
                                                    Icon="fa-solid fa-circle-plus",
                                                    Hint="تم إنشاؤها خلال آخر 24 ساعة",
                                                    Delta="+12.4%",
                                                    DeltaPositive=false,
                                                    Progress=62,
                                                    Href="/Maintenance?range=24h&status=new"
                                                },
                                                new OpsBoardKpi{
                                                    Label="إغلاق ضمن SLA",
                                                    Value="81",
                                                    Unit="%",
                                                    Icon="fa-solid fa-stopwatch",
                                                    Hint="نسبة إغلاق البلاغات ضمن SLA",
                                                    Delta="+1.6%",
                                                    DeltaPositive=true,
                                                    Progress=81,
                                                    Href="/Maintenance/Sla"
                                                },
                                                new OpsBoardKpi{
                                                    Label="معلّق بسبب قطع",
                                                    Value="23",
                                                    Unit="بلاغ",
                                                    Icon="fa-solid fa-box-open",
                                                    Hint="بانتظار قطع/توريد",
                                                    Delta="-3",
                                                    DeltaPositive=true,
                                                    Progress=35,
                                                    Href="/Maintenance?status=waiting"
                                                },
                                                new OpsBoardKpi{
                                                    Label="الأعمال الحرجة المفتوحة",
                                                    Value="7",
                                                    Unit="بلاغ",
                                                    Icon="fa-solid fa-triangle-exclamation",
                                                    Hint="تحتاج تدخل سريع",
                                                    Delta="+2",
                                                    DeltaPositive=false,
                                                    Progress=70,
                                                    Href="/Maintenance?priority=critical&status=open"
                                                },
                                            },

                                            Events = new List<OpsBoardEvent>
                                            {
                                                new OpsBoardEvent{
                                                    Title="تسريب مياه - مبنى 12 / شقة 304",
                                                    Subtitle="إسناد لفريق السباكة • رقم البلاغ: MNT-10421",
                                                    Icon="fa-solid fa-droplet",
                                                    Time="منذ 18 دقيقة",
                                                    Status="قيد التنفيذ",
                                                    StatusTone="info",
                                                    Priority="عالية",
                                                    PriorityTone="warning",
                                                    Href="/Maintenance/Details?id=MNT-10421"
                                                },
                                                new OpsBoardEvent{
                                                    Title="عطل كهربائي - غرفة مضخات",
                                                    Subtitle="تصعيد للمقاول • رقم البلاغ: MNT-10407",
                                                    Icon="fa-solid fa-bolt",
                                                    Time="منذ ساعتين",
                                                    Status="معلّق",
                                                    StatusTone="warning",
                                                    Priority="حرجة",
                                                    PriorityTone="danger",
                                                    Href="/Maintenance/Details?id=MNT-10407"
                                                },
                                                new OpsBoardEvent{
                                                    Title="إغلاق بلاغ - تكييف (وحدة 88)",
                                                    Subtitle="تم الإغلاق والتحقق",
                                                    Icon="fa-solid fa-circle-check",
                                                    Time="اليوم 09:20",
                                                    Status="مغلق",
                                                    StatusTone="success",
                                                    Priority="عادية",
                                                    PriorityTone="neutral",
                                                    Href="/Maintenance/Details?id=MNT-10388"
                                                }
                                            }
                                        },

                                        new OpsBoardSection
                                        {
                                            Title = "الساكنين والخدمات",
                                            Subtitle = "حركة الطلبات والتوثيق",
                                            Icon = "fa-solid fa-users",
                                            Badge = "اليوم",
                                            Href = "/Residents",

                                            Kpis = new List<OpsBoardKpi>
                                            {
                                                new OpsBoardKpi{
                                                    Label="طلبات نقل/تبديل",
                                                    Value="19",
                                                    Unit="طلب",
                                                    Icon="fa-solid fa-right-left",
                                                    Hint="طلبات تحويل وحدات",
                                                    Delta="+4",
                                                    DeltaPositive=false,
                                                    Progress=48,
                                                    Href="/Residents/Transfers?range=today"
                                                },
                                                new OpsBoardKpi{
                                                    Label="بلاغات الساكنين المفتوحة",
                                                    Value="62",
                                                    Unit="بلاغ",
                                                    Icon="fa-solid fa-headset",
                                                    Hint="طلبات خدمة قيد المعالجة",
                                                    Delta="-5",
                                                    DeltaPositive=true,
                                                    Progress=71,
                                                    Href="/Residents/Requests?status=open"
                                                },
                                                new OpsBoardKpi{
                                                    Label="تحديث بيانات الهوية",
                                                    Value="33",
                                                    Unit="سجل",
                                                    Icon="fa-solid fa-id-card",
                                                    Hint="تحديث/توثيق اليوم",
                                                    Delta="+9.0%",
                                                    DeltaPositive=true,
                                                    Progress=66,
                                                    Href="/Residents/Verification?range=today"
                                                },
                                                new OpsBoardKpi{
                                                    Label="مستفيدون جدد",
                                                    Value="11",
                                                    Unit="شخص",
                                                    Icon="fa-solid fa-user-plus",
                                                    Hint="تسجيلات جديدة",
                                                    Delta="+2",
                                                    DeltaPositive=true,
                                                    Progress=55,
                                                    Href="/Residents/New?range=today"
                                                },
                                            },

                                            Events = new List<OpsBoardEvent>
                                            {
                                                new OpsBoardEvent{
                                                    Title="طلب نقل - من حي الياسمين إلى النرجس",
                                                    Subtitle="بانتظار اعتماد الإسكان • رقم: TR-2209",
                                                    Icon="fa-solid fa-route",
                                                    Time="منذ 35 دقيقة",
                                                    Status="بانتظار اعتماد",
                                                    StatusTone="warning",
                                                    Priority="عادية",
                                                    PriorityTone="neutral",
                                                    Href="/Residents/Transfers/Details?id=TR-2209"
                                                },
                                                new OpsBoardEvent{
                                                    Title="طلب خدمة - تحديث عقد",
                                                    Subtitle="تمت المراجعة الأولية",
                                                    Icon="fa-solid fa-file-signature",
                                                    Time="اليوم 10:05",
                                                    Status="قيد المراجعة",
                                                    StatusTone="info",
                                                    Priority="متوسطة",
                                                    PriorityTone="info",
                                                    Href="/Residents/Requests/Details?id=RQ-8801"
                                                }
                                            }
                                        }
                                    }
                                },


                               // ================== 9) ExecWatch ==================

                               new ChartCardConfig
                                        {
                                            Type = ChartCardType.ExecWatch,
                                            Title = "لوحة مراقبة المدراء",
                                            Subtitle = "مراقبة الورش + سير الأعمال + إنذارات رقابية",
                                            Icon = "fa-solid fa-shield-halved",
                                            Tone = ChartTone.Info,
                                            ColCss = "6 md:12",
                                            Dir = "rtl",

                                            ExecWatchAnimate = true,

                                            ExecWatchKpis = new List<ExecWatchKpi>
                                            {
                                                new ExecWatchKpi{
                                                    Label="طلبات مفتوحة",
                                                    Value="1,240",
                                                    Unit="طلب",
                                                    Icon="fa-solid fa-folder-open",
                                                    Hint="إجمالي الطلبات قيد المعالجة",
                                                    Delta="+3.2%",
                                                    DeltaPositive=false,
                                                    Tone="warning",
                                                    Href="/Requests?status=open"
                                                },
                                                new ExecWatchKpi{
                                                    Label="معدل إنجاز اليوم",
                                                    Value="86",
                                                    Unit="%",
                                                    Icon="fa-solid fa-gauge-high",
                                                    Hint="مقارنة بالخطة اليومية",
                                                    Delta="+1.1%",
                                                    DeltaPositive=true,
                                                    Tone="success",
                                                    Href="/Management/DailyPerformance"
                                                },
                                                new ExecWatchKpi{
                                                    Label="متوسط زمن الإغلاق",
                                                    Value="18.4",
                                                    Unit="ساعة",
                                                    Icon="fa-solid fa-clock",
                                                    Hint="متوسط آخر 7 أيام",
                                                    Delta="-0.9",
                                                    DeltaPositive=true,
                                                    Tone="info",
                                                    Href="/Management/CycleTime"
                                                },
                                                new ExecWatchKpi{
                                                    Label="التكلفة التشغيلية",
                                                    Value="2.4M",
                                                    Unit="ر.س",
                                                    Icon="fa-solid fa-sack-dollar",
                                                    Hint="مصروفات صيانة وتشغيل",
                                                    Delta="+6.0%",
                                                    DeltaPositive=false,
                                                    Tone="danger",
                                                    Href="/Finance/Opex"
                                                },
                                            },

                                            ExecWatchStages = new List<ExecWatchStage>
                                            {
                                                new ExecWatchStage{ Label="استقبال الطلب",   Count=420, Percent=34, AvgHours=2.1m,  Overdue=12, Tone="info",    Href="/Requests?stage=intake" },
                                                new ExecWatchStage{ Label="فرز وتوجيه",      Count=310, Percent=25, AvgHours=3.7m,  Overdue=19, Tone="warning", Href="/Requests?stage=triage" },
                                                new ExecWatchStage{ Label="قيد التنفيذ",     Count=260, Percent=21, AvgHours=11.4m, Overdue=27, Tone="warning", Href="/Requests?stage=in_progress" },
                                                new ExecWatchStage{ Label="بانتظار قطع",     Count=95,  Percent=8,  AvgHours=22.6m, Overdue=31, Tone="danger",  Href="/Requests?stage=waiting_parts" },
                                                new ExecWatchStage{ Label="إغلاق وتحقق",     Count=155, Percent=12, AvgHours=4.2m,  Overdue=6,  Tone="success", Href="/Requests?stage=qa_close" },
                                            },

                                            ExecWatchWorkshops = new List<ExecWatchWorkshop>
                                            {
                                                new ExecWatchWorkshop{
                                                    Name="ورشة الكهرباء",
                                                    Icon="fa-solid fa-bolt",
                                                    Capacity=18, Load=78, Productivity=84, Backlog=46, Delayed=9,
                                                    Tone="warning",
                                                    Href="/Workshops/Electrical"
                                                },


                                                new ExecWatchWorkshop{
                                                    Name="ورشة السباكة",
                                                    Icon="fa-solid fa-faucet-drip",
                                                    Capacity=14, Load=64, Productivity=88, Backlog=31, Delayed=4,
                                                    Tone="info",
                                                    Href="/Workshops/Plumbing"
                                                },
                                                new ExecWatchWorkshop{
                                                    Name="ورشة التكييف",
                                                    Icon="fa-solid fa-fan",
                                                    Capacity=16, Load=86, Productivity=72, Backlog=58, Delayed=15,
                                                    Tone="danger",
                                                    Href="/Workshops/HVAC"
                                                },
                                                new ExecWatchWorkshop{
                                                    Name="ورشة النجارة",
                                                    Icon="fa-solid fa-hammer",
                                                    Capacity=10, Load=52, Productivity=90, Backlog=19, Delayed=2,
                                                    Tone="success",
                                                    Href="/Workshops/Carpentry"
                                                },
                                            },

                                            ExecWatchRisks = new List<ExecWatchRisk>
                                            {
                                                new ExecWatchRisk{
                                                    Title="تجاوز SLA في بلاغات التكييف",
                                                    Desc="15 بلاغًا تجاوزت الحد خلال 48 ساعة",
                                                    Tone="danger",
                                                    Time="آخر 6 ساعات",
                                                    Href="/Maintenance/Sla?category=hvac"
                                                },
                                                new ExecWatchRisk{
                                                    Title="تراكم أعمال ورشة الكهرباء",
                                                    Desc="Backlog أعلى من المتوسط الأسبوعي",
                                                    Tone="warning",
                                                    Time="اليوم",
                                                    Href="/Workshops/Electrical?view=backlog"
                                                },
                                                new ExecWatchRisk{
                                                    Title="نقص مخزون قطع (صمامات)",
                                                    Desc="قد يسبب تعليق بلاغات السباكة",
                                                    Tone="info",
                                                    Time="هذا الأسبوع",
                                                    Href="/Inventory?item=valves"
                                                },
                                            },

                                            ExecWatchSlaLabel = "التزام SLA (كافة الطلبات)",
                                            ExecWatchSlaValue = "83",
                                            ExecWatchSlaUnit = "%",
                                            ExecWatchSlaHint = "نسبة الإغلاق ضمن SLA خلال 7 أيام",
                                            ExecWatchSlaTone = "warning",
                                            ExecWatchSlaHref = "/Maintenance/Sla"
                                        },

                    
                    // ================== 1) الإسكان: توزيع أنواع الوحدات ==================
                    new ChartCardConfig
                    {
                        Type = ChartCardType.Donut,
                        Title = "توزيع أنواع الوحدات",
                        Subtitle = "حسب نوع العقار",
                        Icon = "fa-solid fa-chart-pie",
                        Tone = ChartTone.Info,
                        ColCss = "6 md:6",
                        Dir = "rtl",

                        DonutMode = "donut",
                        DonutThickness = 0.30m,
                        DonutShowLegend = true,
                        DonutShowCenterText = true,
                        DonutValueFormat = "0",

                        Slices = new List<DonutSlice>
                        {
                            new DonutSlice { Label = "شقق سكنية", Value = 4200 },
                            new DonutSlice { Label = "فلل",       Value = 1800 },
                            new DonutSlice { Label = "أراضي",     Value = 950  },
                            new DonutSlice { Label = "تجاري",     Value = 400  },
                            new DonutSlice { Label = "وقف",     Value = 120  },
                        }
                    },

                    

                    // ================== 3) Gauge ==================
                    new ChartCardConfig
                    {
                        Type = ChartCardType.Gauge,
                        Title = "التزام الإسكان بزمن معالجة الطلبات",
                        Subtitle = "طلبات الإسكان خلال 48 ساعة",
                        Icon = "fa-solid fa-file-signature",
                        Tone = ChartTone.Info,
                        ColCss = "6 md:3",
                        Dir = "rtl",

                        GaugeLabel = "طلبات ضمن 48 ساعة",
                        GaugeMin = 0,
                        GaugeMax = 100,
                        GaugeValue = 87,
                        GaugeUnit = "%",

                        GaugeWarnFrom = 80,
                        GaugeGoodFrom = 92,
                        GaugeValueText = "87%",
                        GaugeShowThresholds = true
                    },

                    

                    // ================== 5) StatusStack ==================
                    new ChartCardConfig
                    {
                        Type = ChartCardType.StatusStack,
                        Title = "توزيع حالة الوحدات",
                        Subtitle = "شاغرة / مشغولة / صيانة / موقوفة",
                        Icon = "fa-solid fa-house-signal",
                        Tone = ChartTone.Info,
                        ColCss = "6 md:6",
                        Dir = "rtl",

                        StatusStackValueFormat = "0",
                        StatusStackShowLegend = true,

                        StatusStackItems = new List<StatusStackItem>
                        {
                            new StatusStackItem { Key="occupied",    Label="مشغولة",      Value=8450, Href="/Housing?status=occupied" },
                            new StatusStackItem { Key="vacant",      Label="شاغرة جاهزة", Value=2150, Href="/Housing?status=vacant" },
                            new StatusStackItem { Key="maintenance", Label="تحت صيانة",   Value=980,  Href="/Housing?status=maintenance" },
                            new StatusStackItem { Key="blocked",     Label="موقوفة",      Value=420,  Href="/Housing?status=blocked" },
                        }
                    },

                    // ================== 6) Bullet ==================
                    new ChartCardConfig
                    {
                        Type = ChartCardType.Bullet,
                        Title = "الأداء مقابل الأهداف",
                        Subtitle = "ملخص مؤشرات التشغيل الرئيسية",
                        Icon = "fa-solid fa-bullseye",
                        Tone = ChartTone.Info,
                        ColCss = "4 md:6",
                        Dir = "rtl",

                        BulletValueFormat = "0",
                        BulletShowLegend = false,

                        Bullets = new List<BulletItem>
                        {
                            new BulletItem { Key="sla_close",   Label="إغلاق البلاغات ضمن SLA", Actual=78, Target=90, Max=100, OkFrom=70, GoodFrom=90, Unit="%", Href="/Maintenance/Sla" },
                            new BulletItem { Key="occupancy",   Label="نسبة الإشغال",           Actual=92, Target=95, Max=100, OkFrom=85, GoodFrom=95, Unit="%", Href="/Residents/Occupancy" },
                            new BulletItem { Key="readiness",   Label="جاهزية الوحدات",         Actual=86, Target=90, Max=100, OkFrom=80, GoodFrom=90, Unit="%", Href="/Housing/Readiness" },
                            new BulletItem { Key="inspections", Label="إنجاز فحوصات المباني",   Actual=64, Target=80, Max=100, OkFrom=60, GoodFrom=80, Unit="%", Href="/Buildings/Inspections" },
                        }
                    },

                    // ================== 7) Funnel ==================
                    new ChartCardConfig
                    {
                        Type = ChartCardType.Funnel,
                        Title = "سير بلاغات الصيانة",
                        Subtitle = "مراحل معالجة البلاغات",
                        Icon = "fa-solid fa-screwdriver-wrench",
                        Tone = ChartTone.Info,
                        ColCss = "6 md:6",
                        Dir = "rtl",

                        FunnelValueFormat = "0",
                        FunnelShowPercent = true,
                        FunnelShowDelta = true,
                        FunnelClickable = true,

                        FunnelStages = new List<FunnelStage>
                        {
                            new FunnelStage { Key="new",         Label="جديد",         Value=420, Href="/Maintenance?status=new" },
                            new FunnelStage { Key="assigned",    Label="تم الإسناد",   Value=310, Href="/Maintenance?status=assigned" },
                            new FunnelStage { Key="in_progress", Label="قيد التنفيذ",  Value=260, Href="/Maintenance?status=in_progress" },
                            new FunnelStage { Key="waiting",     Label="بانتظار قطع",  Value=95,  Href="/Maintenance?status=waiting" },
                            new FunnelStage { Key="closed",      Label="مغلق",         Value=180, Href="/Maintenance?status=closed" },
                        }
                    },

                    // ================== 8) Waterfall ==================
                    new ChartCardConfig
                    {
                        Type = ChartCardType.Waterfall,
                        Title = "جسر تغيّر الإشغال الشهري",
                        Subtitle = "تفصيل الزيادة/النقصان المؤثر على إشغال الوحدات (بداية ⇢ نهاية الشهر)",
                        Icon = "fa-solid fa-bridge-water",
                        Tone = ChartTone.Info,
                        ColCss = "6 md:6",
                        Dir = "rtl",

                        WaterfallValueFormat = "0",
                        WaterfallHeight = 320,
                        WaterfallMinBarWidth = 92,
                        WaterfallShowValues = true,

                        WaterfallSteps = new List<WaterfallStep>
                        {
                            new WaterfallStep { Key="start", Label="إشغال بداية الشهر", IsTotal=true, Value=8120, Href="/Housing/Occupancy?point=start" },

                            new WaterfallStep { Key="new_allocations",       Label="تخصيص وحدات جديدة",  Value=+640, Href="/Housing/Allocations?period=month" },
                            new WaterfallStep { Key="contract_renewals",     Label="تجديد عقود",         Value=+310, Href="/Housing/Renewals?period=month" },
                            new WaterfallStep { Key="back_from_maintenance", Label="عودة وحدات من الصيانة", Value=+220, Href="/Maintenance/Completed?period=month" },

                            new WaterfallStep { Key="vacated_units",        Label="إخلاءات",              Value=-520, Href="/Housing/Vacations?period=month" },
                            new WaterfallStep { Key="sent_to_maintenance",  Label="تحويل وحدات للصيانة",  Value=-190, Href="/Maintenance/Inbound?period=month" },

                            new WaterfallStep { Key="end", Label="إشغال نهاية الشهر", IsTotal=true, Value=8580, Href="/Housing/Occupancy?point=end" },
                        }
                    },

                    

                    // ================== 10) Occupancy Matrix ==================
                    new ChartCardConfig
                    {
                        Type = ChartCardType.Occupancy,
                        Title = "حالة الوحدات السكنية",
                        Subtitle = "مأهولة • شاغرة • صيانة • محجوزة • غير صالحة",
                        Icon = "fa-solid fa-building-circle-check",
                        Tone = ChartTone.Info,
                        ColCss = "6 md:6",
                        Dir = "rtl",

                        OccupancyShowPercent = true,
                        OccupancyStatuses = new List<OccupancyStatus>
                        {
                            new OccupancyStatus { Key="occupied",    Label="مأهولة",      Units=8120, Color="#22c55e", Href="/Housing?status=occupied" },
                            new OccupancyStatus { Key="vacant",      Label="شاغرة",       Units=1240, Color="#0ea5e9", Href="/Housing?status=vacant" },
                            new OccupancyStatus { Key="maintenance", Label="تحت الصيانة", Units=430,  Color="#f59e0b", Href="/Housing?status=maintenance" },
                            new OccupancyStatus { Key="reserved",    Label="محجوزة",      Units=210,  Color="#8b5cf6", Href="/Housing?status=reserved" },
                            new OccupancyStatus { Key="inactive",    Label="غير صالحة",   Units=95,   Color="#ef4444", Href="/Housing?status=inactive" },
                        }
                    },

                    // ================== 11) Line ==================
                    new ChartCardConfig
                    {
                        Type = ChartCardType.Line,
                        Title = "اتجاه طلبات الإسكان",
                        Subtitle = "آخر 12 شهر",
                        Icon = "fa-solid fa-chart-line",
                        Tone = ChartTone.Info,
                        ColCss = "6 md:6",
                        Dir = "rtl",

                        XLabels = new List<string>
                        {
                            "يناير","فبراير","مارس","أبريل","مايو","يونيو",
                            "يوليو","أغسطس","سبتمبر","أكتوبر","نوفمبر","ديسمبر"
                        },
                        LineSeries = new List<ChartSeries>
                        {
                            new ChartSeries
                            {
                                Name = "طلبات الإسكان",
                                Data = new List<decimal> { 120, 135, 128, 142, 160, 170, 168, 180, 175, 190, 205, 220 }
                            }
                        },
                        LineFillArea = true,
                        LineShowGrid = true,
                        LineShowDots = true,
                        LineValueFormat = "0",
                        LineMaxXTicks = 6
                    },

                     //================== 12) KPI ==================
                    //new ChartCardConfig
                    //{
                    //    Type = ChartCardType.Kpi,
                    //    Title = "إجمالي الساكنين",
                    //    Subtitle = "النشطون حالياً",
                    //    Icon = "fa-solid fa-users",
                    //    BigValue = "21K",
                    //    Note = "عدد الساكنين المسجلين بالنظام",
                    //    SecondaryLabel = "التغير الشهري",
                    //    SecondaryValue = "↑ 3.4%",
                    //    SecondaryIsPositive = true,
                    //    Tone = ChartTone.Success,
                    //    ColCss = "6 md:3",
                    //    Dir = "rtl"
                    //},

                    // ================== 13) BarHorizontal ==================
                    //new ChartCardConfig
                    //{
                    //    Type = ChartCardType.BarHorizontal,
                    //    Title = "توزيع الوحدات حسب غرف النوم",
                    //    Subtitle = "ملخص سريع لطرازات الوحدات",
                    //    Icon = "fa-solid fa-bed",
                    //    Tone = ChartTone.Warning,
                    //    ColCss = "6 md:6",
                    //    Dir = "rtl",

                    //    Labels = new List<string> { "غرفة واحدة","غرفتان","٣ غرف","٤ غرف","٥ غرف","٦ غرف فأكثر" },
                    //    Series = new List<ChartSeries>
                    //    {
                    //        new ChartSeries { Name = "عدد الوحدات", Data = new List<decimal> { 274, 2760, 9824, 6882, 1601, 272 } }
                    //    },
                    //    ShowValues = true,
                    //    ValueFormat = "0",
                    //    LabelMaxChars = 22
                    //}
                }
            };

            var page = new SmartPageViewModel
            {
                PageTitle = "لوحة التحكم",
                PanelIcon = "fa-solid fa-city",
                Charts = charts
            };

            return View("Index", page);
        }
    }
}
