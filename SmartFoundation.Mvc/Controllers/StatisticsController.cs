using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartCharts;
using System.Collections.Generic;

namespace SmartFoundation.Mvc.Controllers
{
    public class StatisticsController : Controller
    {
        public IActionResult Index()
        {
            var vm = new SmartPageViewModel
            {
                PageTitle = "المدن الصحية",
                Charts = new SmartChartsConfig
                {
                    Cards = new List<ChartCardConfig>
                    {
                        new ChartCardConfig
                        {
                            Type = ChartCardType.HealthKpiAnnual,
                            Title = "مؤشر أداء المدن الصحية",
                            Subtitle = "خطة مستهدفات الفعاليات والمشاركات الإجتماعية للمدن الصحية (2026 - 2028)",
                            Icon = "fa-solid fa-heart-pulse",
                            Tone = ChartTone.Info,
                            ColCss = "12 md:12",
                            Dir = "rtl",
                            ShowHeader = false,
                            Variant = ChartCardVariant.Soft,
                            ExtraCss = "border border-slate-400/45 bg-slate-50/80 rounded-lg shadow-[0_1px_1px_rgba(15,23,42,0.02)]",
                            HealthKpiAnimate = true,

                            HealthKpiIndicators = new List<HealthKpiIndicator>
                            {
                                // =========================================================
                                // KPI 1) الوصول إلى المشاركين في البرنامج الصحي (1000 مشارك)
                                // =========================================================
                                new HealthKpiIndicator
                                {
                                    Key = "kpi1",
                                    Title = "الوصول إلى المشاركين في البرنامج الصحي",
                                    Subtitle = "خطة 2026–2028",
                                    Unit = "مشارك",
                                    Emoji = "🧠",
                                    Icon = "fa-solid fa-person-walking",
                                    Tone = "info",
                                    PlanGoal = 1000,
                                    Hint = "مستهدف البرنامج حتى نهاية 2028.",
                                    Years = new List<HealthKpiIndicatorYear>
                                    {
                                        new HealthKpiIndicatorYear{
                                            Key="y2026", Year=2026,
                                            Title="فعاليات توعوية حول نمط الحياة الصحي",
                                            Subtitle="الوصول إلى 600 مشترك",
                                            Target=600, Actual=400,
                                            Badge="مستهدف 2026", Tone="info", Emoji="🧠",
                                            Icon="fa-solid fa-person-walking"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2027", Year=2027,
                                            Title="التوسع في برنامج حياة صحية",
                                            Subtitle="الوصول إلى 800 مشترك",
                                            Target=800, Actual=0,
                                            Badge="مستهدف 2027", Tone="warning", Emoji="📈",
                                            Icon="fa-solid fa-up-right-and-down-left-from-center"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2028", Year=2028,
                                            Title="مبادرات مجتمعية وتحسين الاستدامة",
                                            Subtitle="الوصول إلى 1000 مشترك (اكتمال المستهدف النهائي)",
                                            Target=1000, Actual=0,
                                            Badge="مستهدف 2028", Tone="info", Emoji="🤝",
                                            Icon="fa-solid fa-people-group"
                                        }
                                    }
                                },

                                // =========================================================
                                // KPI 2) استخدام الدراجات (10% من سكان المدينة)
                                // =========================================================
                                new HealthKpiIndicator
                                {
                                    Key="kpi2",
                                    Title="استخدام الدراجات من قبل 10% من سكان المدينة",
                                    Subtitle="هدف نهائي: 10% (تراكمي)",
                                    Unit="%",
                                    Emoji="🚲",
                                    Icon="fa-solid fa-bicycle",
                                    Tone="success",
                                    PlanGoal=10,
                                    Years=new List<HealthKpiIndicatorYear>{
                                        new HealthKpiIndicatorYear{
                                            Key="y2026", Year=2026,
                                            Title="حملات وتحفيز مجتمعي",
                                            Subtitle="رفع الاستخدام للوصول إلى 4% بنهاية 2026",
                                            Target=4, Actual=3,
                                            Badge="مستهدف 2026", Tone="success", Emoji="🚲", Icon="fa-solid fa-bicycle"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2027", Year=2027,
                                            Title="توسعة المسارات وبرامج الشراكات",
                                            Subtitle="رفع الاستخدام للوصول إلى 7% بنهاية 2027",
                                            Target=7, Actual=0,
                                            Badge="مستهدف 2027", Tone="success", Emoji="🚲", Icon="fa-solid fa-bicycle"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2028", Year=2028,
                                            Title="تكامل المبادرات وتحسين الوصول",
                                            Subtitle="رفع الاستخدام للوصول إلى 10% بنهاية 2028",
                                            Target=10, Actual=0,
                                            Badge="مستهدف 2028", Tone="success", Emoji="🚲", Icon="fa-solid fa-bicycle"
                                        },
                                    }
                                },

                                // =========================================================
                                // KPI 3) خفض نسبة المدخنين إلى 15% (تفصيل سنوي: 8% + 4% + 3% = 15%)
                                // ✅ هنا نعاملها كـ "تقدم نحو خفض" وليس "نسبة متبقية"
                                // - PlanGoal = 15 (إجمالي الخفض)
                                // - Targets السنوية = 8 / 4 / 3
                                // - Actuals: ضع المنجز الحقيقي لكل سنة (مبدئياً 2026=8 مثال، والباقي 0)
                                // =========================================================
                                new HealthKpiIndicator
                                {
                                    Key="kpi3",
                                    Title="خفض نسبة المدخنين",
                                    Subtitle="هدف نهائي: خفض 15% (8% + 4% + 3%)",
                                    Unit="%",
                                    Emoji="🚭",
                                    Icon="fa-solid fa-ban-smoking",
                                    Tone="danger",
                                    PlanGoal=15,
                                    Hint="المستهدف سنوياً: 2026 خفض 8%، 2027 خفض 4%، 2028 خفض 3% (الإجمالي 15%).",
                                    Years=new List<HealthKpiIndicatorYear>{
                                        new HealthKpiIndicatorYear{
                                            Key="y2026", Year=2026,
                                            Title="برامج توعوية وإقلاع",
                                            Subtitle="خفض 8% بنهاية 2026",
                                            Target=8, Actual=5,
                                            Badge="مستهدف 2026", Tone="danger", Emoji="🚭", Icon="fa-solid fa-ban-smoking"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2027", Year=2027,
                                            Title="توسع العيادات والبرامج المدرسية",
                                            Subtitle="خفض 4% بنهاية 2027",
                                            Target=4, Actual=0,
                                            Badge="مستهدف 2027", Tone="danger", Emoji="🚭", Icon="fa-solid fa-ban-smoking"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2028", Year=2028,
                                            Title="حزم تدخل مستدامة ومتابعة",
                                            Subtitle="خفض 3% بنهاية 2028",
                                            Target=3, Actual=0,
                                            Badge="مستهدف 2028", Tone="danger", Emoji="🚭", Icon="fa-solid fa-ban-smoking"
                                        },
                                    }
                                },

                                // =========================================================
                                // KPI 4) فلاتر وتحسين جودة المياه (70% من المنازل)
                                // =========================================================
                                new HealthKpiIndicator
                                {
                                    Key="kpi4",
                                    Title="تحسين جودة المياه في المنازل",
                                    Subtitle="هدف نهائي: 70%",
                                    Unit="%",
                                    Emoji="💧",
                                    Icon="fa-solid fa-water",
                                    Tone="info",
                                    PlanGoal=70,
                                    Years=new List<HealthKpiIndicatorYear>{
                                        new HealthKpiIndicatorYear{
                                            Key="y2026", Year=2026,
                                            Title="مرحلة أولى: حصر وتركيب",
                                            Subtitle="رفع التغطية إلى 25% بنهاية 2026",
                                            Target=25, Actual=22,
                                            Badge="مستهدف 2026", Tone="info", Emoji="💧", Icon="fa-solid fa-water"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2027", Year=2027,
                                            Title="مرحلة ثانية: توسعة التغطية",
                                            Subtitle="رفع التغطية إلى 50% بنهاية 2027",
                                            Target=50, Actual=0,
                                            Badge="مستهدف 2027", Tone="info", Emoji="💧", Icon="fa-solid fa-water"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2028", Year=2028,
                                            Title="مرحلة ثالثة: اكتمال التحسين",
                                            Subtitle="رفع التغطية إلى 70% بنهاية 2028",
                                            Target=70, Actual=0,
                                            Badge="مستهدف 2028", Tone="info", Emoji="💧", Icon="fa-solid fa-water"
                                        },
                                    }
                                },

                                // =========================================================
                                // KPI 5) تدريب 500 + تفعيل النادي النسائي
                                // =========================================================
                                new HealthKpiIndicator
                                {
                                    Key="kpi5",
                                    Title="التغذية واللياقة وتفعيل النادي النسائي",
                                    Subtitle="هدف نهائي: 500 مستفيد (تراكمي)",
                                    Unit="مستفيد",
                                    Emoji="🏋️",
                                    Icon="fa-solid fa-dumbbell",
                                    Tone="warning",
                                    PlanGoal=500,
                                    Years=new List<HealthKpiIndicatorYear>{
                                        new HealthKpiIndicatorYear{
                                            Key="y2026", Year=2026,
                                            Title="إطلاق التدريب + تفعيل النادي النسائي",
                                            Subtitle="الوصول إلى 200 مستفيد بنهاية 2026",
                                            Target=200, Actual=120,
                                            Badge="مستهدف 2026", Tone="warning", Emoji="🏋️", Icon="fa-solid fa-dumbbell"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2027", Year=2027,
                                            Title="توسعة الدورات والشراكات",
                                            Subtitle="الوصول إلى 350 مستفيد بنهاية 2027",
                                            Target=350, Actual=0,
                                            Badge="مستهدف 2027", Tone="warning", Emoji="🏋️", Icon="fa-solid fa-dumbbell"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2028", Year=2028,
                                            Title="استدامة البرامج وقياس الأثر",
                                            Subtitle="الوصول إلى 500 مستفيد بنهاية 2028",
                                            Target=500, Actual=0,
                                            Badge="مستهدف 2028", Tone="warning", Emoji="🏋️", Icon="fa-solid fa-dumbbell"
                                        },
                                    }
                                },

                                // =========================================================
                                // KPI 6) زراعة 5000 شتلة + نقطتي إعادة التدوير
                                // =========================================================
                                new HealthKpiIndicator
                                {
                                    Key="kpi6",
                                    Title="زراعة 5000 شتلة + إعادة التدوير",
                                    Subtitle="هدف نهائي: 5000 شتلة تشغيل نقطتي تدوير",
                                    Unit="شتلة",
                                    Emoji="🌱",
                                    Icon="fa-solid fa-seedling",
                                    Tone="success",
                                    PlanGoal=5000,
                                    Years=new List<HealthKpiIndicatorYear>{
                                        new HealthKpiIndicatorYear{
                                            Key="y2026", Year=2026,
                                            Title="زراعة + تشغيل نقاط التدوير (مرحلة أولى)",
                                            Subtitle="الوصول إلى 1500 شتلة بنهاية 2026 + تفعيل النقطتين",
                                            Target=1500, Actual=900,
                                            Badge="مستهدف 2026", Tone="success", Emoji="🌱", Icon="fa-solid fa-seedling"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2027", Year=2027,
                                            Title="مرحلة ثانية: توسعة المشاركة المجتمعية",
                                            Subtitle="الوصول إلى 3500 شتلة بنهاية 2027 + تشغيل مستدام",
                                            Target=3500, Actual=0,
                                            Badge="مستهدف 2027", Tone="success", Emoji="🌱", Icon="fa-solid fa-seedling"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2028", Year=2028,
                                            Title="مرحلة ثالثة: اكتمال المستهدف",
                                            Subtitle="الوصول إلى 5000 شتلة بنهاية 2028 + تحسين جودة التدوير",
                                            Target=5000, Actual=0,
                                            Badge="مستهدف 2028", Tone="success", Emoji="🌱", Icon="fa-solid fa-seedling"
                                        },
                                    }
                                },

                                // =========================================================
                                // KPI 7) تقليل الحيوانات الضالة بنسبة 70% (2026–2028)
                                // التوزيع: 2026 منجز 25% — 2027 مستهدف 25% — 2028 مستهدف 20%
                                // =========================================================
                                new HealthKpiIndicator
                                {
                                    Key = "kpi7",
                                    Title = "تقليل الحيوانات الضالة",
                                    Subtitle = "هدف نهائي: خفض 70% (تراكمي) خلال 2026–2028",
                                    Unit = "%",
                                    Emoji = "🐾",
                                    Icon = "fa-solid fa-paw",
                                    Tone = "danger",
                                    PlanGoal = 70,
                                    Years = new List<HealthKpiIndicatorYear>
                                    {
                                        new HealthKpiIndicatorYear
                                        {
                                            Key = "y2026",
                                            Year = 2026,
                                            Title = "حصر ومعالجة واستجابة (مرحلة أولى)",
                                            Subtitle = "خفض تراكمي 25% بنهاية 2026",
                                            Target = 25,
                                            Actual = 20,
                                            Badge = "مستهدف 2026",
                                            Tone = "danger",
                                            Emoji = "🐾",
                                            Icon = "fa-solid fa-paw"
                                        },
                                        new HealthKpiIndicatorYear
                                        {
                                            Key = "y2027",
                                            Year = 2027,
                                            Title = "حملات التعقيم والتبني (مرحلة ثانية)",
                                            Subtitle = "إضافة 25% (تراكمي 50%) بنهاية 2027",
                                            Target = 25,
                                            Actual = 0,
                                            Badge = "مستهدف 2027",
                                            Tone = "danger",
                                            Emoji = "🐾",
                                            Icon = "fa-solid fa-paw"
                                        },
                                        new HealthKpiIndicatorYear
                                        {
                                            Key = "y2028",
                                            Year = 2028,
                                            Title = "استدامة التدخل والمتابعة (مرحلة ثالثة)",
                                            Subtitle = "إضافة 20% (تراكمي 70%) بنهاية 2028",
                                            Target = 20,
                                            Actual = 0,
                                            Badge = "مستهدف 2028",
                                            Tone = "danger",
                                            Emoji = "🐾",
                                            Icon = "fa-solid fa-paw"
                                        },
                                    }
                                },
                            }
                        }
                    }
                }
            };

            return View(vm);
        }
    }
}
