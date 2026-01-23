using System.Text.RegularExpressions;

namespace SmartFoundation.UI.ViewModels.SmartCharts
{
    public enum ChartCardType
    {
        Kpi,
        BarHorizontal,
        Donut,
        Line,
        Heatmap,
        Funnel,
        Gauge,
        Occupancy,
        ColumnPro,
        RadialRings,
        Bullet,
        Treemap,
        StatusStack,
        Waterfall,
        StatsGrid,
        Pie3D,
        OpsBoard,
        ExecWatch,
        HealthKpiRoadmap,
        HealthKpiPulse,
        HealthKpiAnnual
    }

    public enum ChartTone { Neutral, Success, Warning, Danger, Info }
    public enum ChartCardSize { Sm, Md, Lg }
    public enum ChartCardVariant { Soft, Outline, Solid }



    // =========================
    // HealthKpiAnnual - Program (7 Indicators)
    // =========================
    public class HealthKpiIndicator
    {
        public string Key { get; set; } = "";
        public string Title { get; set; } = "";
        public string Subtitle { get; set; } = "";

        public string Unit { get; set; } = "";         // "مشارك" / "%" / "منزل" ...
        public string Icon { get; set; } = "";         // fontawesome
        public string Emoji { get; set; } = "";        // 🧠 🚲 💧 ...
        public string Tone { get; set; } = "info";     // info/warning/success/danger...

        public decimal? PlanGoal { get; set; }         // الهدف النهائي للمؤشر (اختياري)
        public string Hint { get; set; } = "";
        public string Href { get; set; } = "";

        public List<HealthKpiIndicatorYear> Years { get; set; } = new();
    }

    public class HealthKpiIndicatorYear
    {
        public string Key { get; set; } = "";          // y2026 ...
        public int Year { get; set; }

        public string Title { get; set; } = "";        // وصف سنة (التوعية... التوسع...)
        public string Subtitle { get; set; } = "";

        public decimal? Target { get; set; }           // هدف السنة (اختياري)
        public decimal? Actual { get; set; }           // منجز السنة (اختياري)

        public string Badge { get; set; } = "";        // "مستهدف 2026"
        public string Tone { get; set; } = "info";
        public string Icon { get; set; } = "";
        public string Emoji { get; set; } = "";

        public string Href { get; set; } = "";
}



    public class HealthKpiMilestone
    {
        public string Key { get; set; } = Guid.NewGuid().ToString("N");
        public int Year { get; set; } = DateTime.UtcNow.Year;

        public decimal Target { get; set; } = 0m;     // الهدف (مثلاً 1000)
        public string Unit { get; set; } = "مشارك";   // "مشارك/مشترك" حسب صياغتك

        public string Title { get; set; } = "";       // عنوان السنة/المرحلة
        public string? Subtitle { get; set; }         // وصف الفعالية/المبادرة
        public string? Badge { get; set; }            // مثل: "مستهدف"
        public string? Tone { get; set; }             // neutral|info|success|warning|danger
        public string? Href { get; set; }             // Drilldown
        public string? Icon { get; set; }        // FontAwesome مثل: "fa-solid fa-heart-pulse"
        public string? Emoji { get; set; }       // اختياري سريع: "💚"
        public string? ImageUrl { get; set; }    // اختياري: مسار صورة صغيرة (مثلاً ~/images/health/awareness.svg)
        public decimal? Actual { get; set; }

    }

    public class HealthKpiSummary
    {
        public string Label { get; set; } = "الهدف";
        public decimal Goal { get; set; } = 0m;       // الهدف النهائي
        public string Unit { get; set; } = "مشارك";
        public decimal? Current { get; set; }         // اختياري: المنجز الحالي
        public string? Hint { get; set; }             // نص توضيحي
        public string ValueFormat { get; set; } = "0";
        public string? Href { get; set; }
        public string? Icon { get; set; }        // أيقونة للعنوان
        public string? AccentTone { get; set; }  // info/success/warning/danger

    }


    public class ExecWatchKpi
    {
        public string Key { get; set; } = Guid.NewGuid().ToString("N");
        public string Label { get; set; } = "";
        public string Value { get; set; } = "";
        public string? Unit { get; set; }
        public string? Icon { get; set; }
        public string? Hint { get; set; }
        public string? Delta { get; set; }
        public bool? DeltaPositive { get; set; }

        public string? Tone { get; set; } // neutral|info|success|warning|danger
        public string? Href { get; set; }
    }

    public class ExecWatchStage
    {
        public string Key { get; set; } = Guid.NewGuid().ToString("N");
        public string Label { get; set; } = "";

        public decimal Count { get; set; } = 0m;
        public decimal Percent { get; set; } = 0m;     // 0..100
        public decimal AvgHours { get; set; } = 0m;    // متوسط زمن المرحلة
        public decimal Overdue { get; set; } = 0m;     // المتأخر

        public string? Tone { get; set; } // neutral|info|success|warning|danger
        public string? Href { get; set; }
    }

    public class ExecWatchWorkshop
    {
        public string Key { get; set; } = Guid.NewGuid().ToString("N");
        public string Name { get; set; } = "";
        public string? Icon { get; set; }

        public decimal Capacity { get; set; } = 0m;      // طاقة/عدد فنيين/خطوط
        public decimal Load { get; set; } = 0m;          // 0..100
        public decimal Productivity { get; set; } = 0m;  // 0..100
        public decimal Backlog { get; set; } = 0m;       // عدد أعمال متراكمة
        public decimal Delayed { get; set; } = 0m;       // متأخر

        public string? Tone { get; set; } // neutral|info|success|warning|danger
        public string? Href { get; set; }
    }

    public class ExecWatchRisk
    {
        public string Key { get; set; } = Guid.NewGuid().ToString("N");
        public string Title { get; set; } = "";
        public string? Desc { get; set; }
        public string? Tone { get; set; } // danger|warning|info|success
        public string? Time { get; set; }
        public string? Href { get; set; }
    }


    public class OpsBoardSection
    {
        public string Key { get; set; } = Guid.NewGuid().ToString("N");
        public string Title { get; set; } = "";
        public string? Subtitle { get; set; }
        public string? Icon { get; set; }          // FontAwesome
        public string? Badge { get; set; }         // مثل "اليوم" / "آخر 24 ساعة"
        public string? Href { get; set; }          // Drilldown للقسم

        public List<OpsBoardKpi> Kpis { get; set; } = new();
        public List<OpsBoardEvent> Events { get; set; } = new();
    }

    public class OpsBoardKpi
    {
        public string Key { get; set; } = Guid.NewGuid().ToString("N");
        public string Label { get; set; } = "";
        public string Value { get; set; } = "";
        public string? Unit { get; set; }
        public string? Icon { get; set; }
        public string? Hint { get; set; }
        public string? Delta { get; set; }
        public bool? DeltaPositive { get; set; }

        public decimal? Progress { get; set; }     // 0..100 (اختياري)
        public string? Href { get; set; }          // Drilldown للـ KPI
    }

    public class OpsBoardEvent
    {
        public string Key { get; set; } = Guid.NewGuid().ToString("N");
        public string Title { get; set; } = "";
        public string? Subtitle { get; set; }
        public string? Icon { get; set; }

        public string? Time { get; set; }          // "منذ 12 دقيقة" / "اليوم 02:10"
        public string? Status { get; set; }        // "قيد التنفيذ" / "مغلق"...
        public string? StatusTone { get; set; }    // neutral|info|success|warning|danger

        public string? Priority { get; set; }      // "عالية" / "حرجة"
        public string? PriorityTone { get; set; }  // neutral|info|success|warning|danger

        public string? Href { get; set; }
    }



    public class Pie3DSlice
    {
        public string Key { get; set; } = "";
        public string Label { get; set; } = "";
        public decimal Value { get; set; } = 0m;

        public string? Color { get; set; }       // اختياري
        public string? Href { get; set; }        // اختياري drilldown
        public string? Hint { get; set; }        // اختياري (tooltip)
    }

    public class StatsGridGroup
    {
        public string Key { get; set; } = Guid.NewGuid().ToString("N");
        public string Title { get; set; } = "";
        public string? Subtitle { get; set; }
        public string? Badge { get; set; }
        public List<StatsGridItem> Items { get; set; } = new();
    }

    public class StatsGridItem
    {
        public string Key { get; set; } = Guid.NewGuid().ToString("N");
        public string Label { get; set; } = "";
        public string Value { get; set; } = "";
        public string? Unit { get; set; }
        public string? Icon { get; set; }
        public string? Hint { get; set; }
        public string? Delta { get; set; }
        public bool? DeltaPositive { get; set; }
        public string? Href { get; set; }
    }




    public class WaterfallStep
    {
        public string Key { get; set; } = "";
        public string Label { get; set; } = "";
        public decimal Value { get; set; } = 0m;   // delta (+/-) أو total إذا IsTotal
        public bool IsTotal { get; set; } = false; // خطوة إجمالي
        public string? Color { get; set; }         // اختياري
        public string? Href { get; set; }          // drilldown
    }

    public class StatusStackItem
    {
        public string Key { get; set; } = "";
        public string Label { get; set; } = "";
        public decimal Value { get; set; } = 0m;

        public string? Color { get; set; } // optional
        public string? Href { get; set; }  // drilldown
    }



    public class TreemapNode
    {
        public string Id { get; set; } = Guid.NewGuid().ToString("N");
        public string Label { get; set; } = "";
        public decimal Value { get; set; } = 0m;       // يستخدم فقط لو Leaf
        public string? Color { get; set; }             // اختياري
        public string? Href { get; set; }              // اختياري Drilldown

        public List<TreemapNode> Children { get; set; } = new();
    }

    public class BulletItem
    {
        public string Key { get; set; } = "";
        public string Label { get; set; } = "";      // اسم المؤشر
        public decimal Actual { get; set; } = 0m;    // الحالي
        public decimal Target { get; set; } = 0m;    // الهدف
        public decimal Max { get; set; } = 100m;     // الحد الأعلى للمقياس

        // نطاقات الأداء (اختياري): Poor <= okFrom < goodFrom <= Max
        public decimal OkFrom { get; set; } = 60m;
        public decimal GoodFrom { get; set; } = 85m;

        public string? Color { get; set; }           // لون الـ actual (اختياري)
        public string? Unit { get; set; }            // "%" أو "يوم" أو "ساعة"
        public string? Href { get; set; }            // Drilldown (اختياري)
    }

    public class RadialRingItem
    {
        public string Key { get; set; } = "";
        public string Label { get; set; } = "";       // مثل "جاهزية الوحدات"
        public decimal Value { get; set; } = 0m;      // القيمة الحالية
        public decimal Max { get; set; } = 100m;      // الحد الأعلى (افتراضي 100)

        public string? Color { get; set; }            // اختياري
        public string? ValueText { get; set; }        // اختياري: "92%"
        public string? Href { get; set; }             // اختياري drilldown
    }

    public class ChartSeries
    {
        public string Name { get; set; } = "Series";
        public List<decimal> Data { get; set; } = new();
    }


    public class OccupancyStatus
    {
        public string Key { get; set; } = "";     // occupied, vacant, maintenance...
        public string Label { get; set; } = "";
        public decimal Units { get; set; } = 0m;

        public string? Color { get; set; }         // لون الحالة
        public string? Href { get; set; }          // Drilldown
    }

    public class FunnelStage
    {
        public string Key { get; set; } = "";      // مثلا "new", "in_progress"
        public string Label { get; set; } = "";    // مثلا "جديد"
        public decimal Value { get; set; } = 0m;   // العدد

        // اختياري: لون ثابت
        public string? Color { get; set; }

        // اختياري: drilldown
        public string? Href { get; set; }
        public string? OnClickJs { get; set; }
    }

    public class DonutSlice
    {
        public string Label { get; set; } = "";
        public decimal Value { get; set; } = 0m;

        // اختياري: لون ثابت (مثل "#0ea5e9")، إذا تركته فارغ JS يعطي Palette تلقائي
        public string? Color { get; set; }

        // اختياري: نص يظهر بدل القيمة (مثل "45%")
        public string? DisplayValue { get; set; }
    }


    public class ChartAction
    {
        public string Id { get; set; } = Guid.NewGuid().ToString("N");
        public string Text { get; set; } = "";
        public string? Icon { get; set; }          // FontAwesome class
        public string? Href { get; set; }          // رابط
        public string? OnClickJs { get; set; }     // JS snippet
        public string? CssClass { get; set; }      // تخصيص مظهر
        public bool Show { get; set; } = true;
        public string? Title { get; set; }         // tooltip
        public bool OpenNewTab { get; set; } = false;
    }

    public class ChartCardConfig
    {
        // Identity / layout
        public string Id { get; set; } = Guid.NewGuid().ToString("N");
        public ChartCardType Type { get; set; }
        public string? ColCss { get; set; }           // نفس نظامك
        public string? ExtraCss { get; set; }
        public string Dir { get; set; } = "rtl";      // rtl/ltr

        // Shell (مشترك لكل الشارتات)
        public bool ShowHeader { get; set; } = true;
        public string Title { get; set; } = "";
        public string? Subtitle { get; set; }
        public string? Icon { get; set; }             // FontAwesome
        public ChartTone Tone { get; set; } = ChartTone.Neutral;
        public ChartCardSize Size { get; set; } = ChartCardSize.Md;
        public ChartCardVariant Variant { get; set; } = ChartCardVariant.Outline;

        // States
        public bool IsLoading { get; set; } = false;
        public bool IsEmpty { get; set; } = false;
        public string? EmptyMessage { get; set; } = "لا توجد بيانات";
        public string? ErrorMessage { get; set; }     // لو موجود => Error state

        // Footer / meta
        public bool ShowFooter { get; set; } = false;
        public string? FooterText { get; set; }       // مثل "آخر تحديث..."
        public string? LastUpdatedText { get; set; }

        // Drilldown (تضغط الكيس)
        public string? Href { get; set; }
        public string? OnClickJs { get; set; }
        public bool OpenNewTab { get; set; } = false;

        // Actions (أزرار أعلى الكيس)
        public List<ChartAction> Actions { get; set; } = new();

        // -------- KPI (example type payload) --------
        public string? BigValue { get; set; }
        public string? Note { get; set; }
        public string? SecondaryLabel { get; set; }
        public string? SecondaryValue { get; set; }
        public bool? SecondaryIsPositive { get; set; } // null = محايد

        // -------- BarHorizontal (example type payload) --------
        public List<string> Labels { get; set; } = new();
        public List<ChartSeries> Series { get; set; } = new();
        public bool ShowValues { get; set; } = true;
        public string ValueFormat { get; set; } = "0";    // "0", "0.0", "0.##"
        public int LabelMaxChars { get; set; } = 22;

        // -------- Donut/Pie --------
        public List<DonutSlice> Slices { get; set; } = new();
        public bool DonutShowLegend { get; set; } = true;
        public bool DonutShowCenterText { get; set; } = true;

        // “donut” أو “pie”
        public string DonutMode { get; set; } = "donut";

        // سماكة الحلقة (للـ donut) كنسبة 0..1 (مثال 0.28)
        public decimal DonutThickness { get; set; } = 0.28m;

        // صيغة عرض القيمة (إذا ما استخدمت DisplayValue)
        public string DonutValueFormat { get; set; } = "0";

        // -------- Line/Area --------
        public List<string> XLabels { get; set; } = new();           // محور X
        public List<ChartSeries> LineSeries { get; set; } = new();   // نفس ChartSeries لكن هنا مخصص للـ line
        public bool LineShowDots { get; set; } = true;
        public bool LineShowGrid { get; set; } = true;
        public bool LineFillArea { get; set; } = true;               // Area تحت الخط
        public string LineValueFormat { get; set; } = "0";           // "0", "0.0", "0.##"
        public int LineMaxXTicks { get; set; } = 6;                  // تقليل النصوص على X


        // -------- Funnel / Pipeline --------
        public List<FunnelStage> FunnelStages { get; set; } = new();
        public bool FunnelShowPercent { get; set; } = true;     // نسبة من الإجمالي
        public bool FunnelShowDelta { get; set; } = true;       // فرق عن المرحلة السابقة
        public string FunnelValueFormat { get; set; } = "0";
        public bool FunnelClickable { get; set; } = true;

        // -------- SLA Gauge (Radial) --------
        public decimal GaugeValue { get; set; } = 0m;          // القيمة الحالية
        public decimal GaugeMin { get; set; } = 0m;
        public decimal GaugeMax { get; set; } = 100m;

        public string? GaugeLabel { get; set; }                // مثل: "الالتزام بالـ SLA"
        public string? GaugeValueText { get; set; }            // مثل: "92%"
        public string GaugeValueFormat { get; set; } = "0";    // لو ما حطيت GaugeValueText

        public decimal GaugeGoodFrom { get; set; } = 90m;      // >= good
        public decimal GaugeWarnFrom { get; set; } = 75m;      // >= warn, أقل = danger

        public string GaugeUnit { get; set; } = "%";           // "%" أو "h" ... إلخ
        public bool GaugeShowThresholds { get; set; } = true;  // عرض حدود الألوان أسفل

        // -------- Housing Occupancy --------
        public List<OccupancyStatus> OccupancyStatuses { get; set; } = new();
        public bool OccupancyShowPercent { get; set; } = true;
        public string OccupancyValueFormat { get; set; } = "0";


        // -------- ColumnPro --------
        public List<string> ColumnProLabels { get; set; } = new();
        public List<ChartSeries> ColumnProSeries { get; set; } = new(); // أول Series فقط
        public string ColumnProValueFormat { get; set; } = "0";
        public int ColumnProMinBarWidth { get; set; } = 44;     // عرض العمود بالبيكسل
        public int ColumnProHeight { get; set; } = 260;         // ارتفاع منطقة الرسم
        public bool ColumnProShowValues { get; set; } = true;
        public List<string>? ColumnProHrefs { get; set; }       // اختياري: رابط لكل عمود


        // -------- Radial Rings --------
        public List<RadialRingItem> RadialRings { get; set; } = new();
        public int RadialRingSize { get; set; } = 260;           // قطر الرسم
        public int RadialRingThickness { get; set; } = 10;       // سماكة كل حلقة
        public int RadialRingGap { get; set; } = 8;              // مسافة بين الحلقات
        public bool RadialRingShowLegend { get; set; } = true;
        public string RadialRingValueFormat { get; set; } = "0";


        // -------- Bullet --------
        public List<BulletItem> Bullets { get; set; } = new();
        public string BulletValueFormat { get; set; } = "0";
        public bool BulletShowLegend { get; set; } = true;

        // -------- Treemap --------
        public TreemapNode? TreemapRoot { get; set; }               // جذر الشجرة
        public int TreemapHeight { get; set; } = 320;               // ارتفاع الرسم
        public int TreemapMinTile { get; set; } = 18;               // أقل حجم بلاطة لعرض النص
        public bool TreemapShowLegend { get; set; } = false;        // اختياري لاحقًا
        public string TreemapValueFormat { get; set; } = "0";


        // -------- StatusStack (NEW) --------
        public string StatusStackValueFormat { get; set; } = "0";
        public bool StatusStackShowLegend { get; set; } = true;
        public List<StatusStackItem> StatusStackItems { get; set; } = new();

        // -------- Waterfall --------
        public List<WaterfallStep> WaterfallSteps { get; set; } = new();
        public string WaterfallValueFormat { get; set; } = "0";
        public int WaterfallHeight { get; set; } = 280;
        public int WaterfallMinBarWidth { get; set; } = 72;
        public bool WaterfallShowValues { get; set; } = true;

        // -------- StatsGrid --------
        public List<StatsGridGroup> StatsGridGroups { get; set; } = new();
        public bool StatsGridAnimate { get; set; } = true;


        // -------- Pie3D --------
        public List<Pie3DSlice> Pie3DSlices { get; set; } = new();
        public int Pie3DSize { get; set; } = 280;          // قطر
        public int Pie3DHeight { get; set; } = 18;         // سماكة (Extrusion)
        public int Pie3DInnerHole { get; set; } = 0;       // 0 = Pie صافي، لو تبغى donut 3D حط 40 مثلاً
        public bool Pie3DShowLegend { get; set; } = true;
        public bool Pie3DShowCenterTotal { get; set; } = true;
        public string Pie3DValueFormat { get; set; } = "0";
        public bool Pie3DExplodeOnHover { get; set; } = true;


        // -------- OpsBoard (NEW) --------
        public List<OpsBoardSection> OpsBoardSections { get; set; } = new();
        public bool OpsBoardAnimate { get; set; } = true;
        public bool OpsBoardCompact { get; set; } = false;
        public int OpsBoardColumns { get; set; } = 2;   // 1..3

        // -------- ExecWatch (NEW) --------
        public List<ExecWatchKpi> ExecWatchKpis { get; set; } = new();
        public List<ExecWatchStage> ExecWatchStages { get; set; } = new();
        public List<ExecWatchWorkshop> ExecWatchWorkshops { get; set; } = new();
        public List<ExecWatchRisk> ExecWatchRisks { get; set; } = new();

        public bool ExecWatchAnimate { get; set; } = true;

        public string? ExecWatchSlaLabel { get; set; }
        public string? ExecWatchSlaValue { get; set; }
        public string? ExecWatchSlaUnit { get; set; }
        public string? ExecWatchSlaHint { get; set; }
        public string? ExecWatchSlaTone { get; set; }  // info/success/warning/danger
        public string? ExecWatchSlaHref { get; set; }

        // -------- Health KPI Roadmap (NEW) --------
        public HealthKpiSummary? HealthKpiSummary { get; set; }
        public List<HealthKpiMilestone> HealthKpiMilestones { get; set; } = new();
        public bool HealthKpiShowProgress { get; set; } = true;
        public bool HealthKpiAnimate { get; set; } = true;
        // داخل ChartCardConfig (نفس مكان HealthKpiSummary / HealthKpiMilestones)
        public List<HealthKpiIndicator>? HealthKpiIndicators { get; set; }




        // Grid helper
        public string GetResolvedColCss()
        {
            var raw = (ColCss ?? "").Trim();
            if (string.IsNullOrWhiteSpace(raw))
                return "col-span-12 md:col-span-6";

            var tokens = Regex.Split(raw, @"\s+")
                              .Where(t => !string.IsNullOrWhiteSpace(t))
                              .ToList();

            var outTokens = new List<string>();
            var hasBase = false;

            foreach (var t in tokens)
            {
                var mBpNum = Regex.Match(t, @"^(sm|md|lg|xl|2xl):(\d{1,2})$");
                if (mBpNum.Success)
                {
                    var bp = mBpNum.Groups[1].Value;
                    var val = Clamp(int.Parse(mBpNum.Groups[2].Value), 1, 12);
                    outTokens.Add($"{bp}:col-span-{val}");
                    continue;
                }

                var mBase = Regex.Match(t, @"^col-span-(\d{1,2})$");
                if (mBase.Success)
                {
                    var val = Clamp(int.Parse(mBase.Groups[1].Value), 1, 12);
                    outTokens.Add($"col-span-{val}");
                    hasBase = true;
                    continue;
                }

                var mBpCol = Regex.Match(t, @"^(sm|md|lg|xl|2xl):col-span-(\d{1,2})$");
                if (mBpCol.Success)
                {
                    var bp = mBpCol.Groups[1].Value;
                    var val = Clamp(int.Parse(mBpCol.Groups[2].Value), 1, 12);
                    outTokens.Add($"{bp}:col-span-{val}");
                    continue;
                }

                var mNum = Regex.Match(t, @"^0*(\d{1,2})$");
                if (mNum.Success)
                {
                    var val = Clamp(int.Parse(mNum.Groups[1].Value), 1, 12);
                    outTokens.Add("col-span-12");
                    outTokens.Add($"md:col-span-{val}");
                    hasBase = true;
                    continue;
                }

                outTokens.Add(t);
            }

            if (!hasBase)
                outTokens.Insert(0, "col-span-12");

            var result = string.Join(" ", outTokens.Distinct());
            return Regex.Replace(result, @"\s+", " ").Trim();
        }

        private static int Clamp(int v, int min, int max) => v < min ? min : (v > max ? max : v);
    }

    public class SmartChartsConfig
    {
        public string ChartsId { get; set; } = "smartCharts";
        public string? Title { get; set; }
        public string Dir { get; set; } = "rtl";

        // لو تبغى عنوان/أكشن للداش ككل
        public List<ChartAction> Actions { get; set; } = new();

        public List<ChartCardConfig> Cards { get; set; } = new();
    }
}
