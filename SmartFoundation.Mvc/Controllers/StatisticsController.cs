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
                                // (توزيع تراكمي: 600 / +200 / +200)
                                // =========================================================
                                new HealthKpiIndicator
                                {
                                    Key = "kpi1",
                                    Title = "الوصول إلى المشاركين في البرنامج الصحي",
                                    Subtitle = "خطة 2026–2028 (تراكمي)",
                                    Unit = "مشارك",
                                    Emoji = "🧠",
                                    Icon = "fa-solid fa-person-walking",
                                    Tone = "info",
                                    PlanGoal = 1000,
                                    Hint = "مستهدف تراكمي حتى نهاية 2028.",
                                    Years = new List<HealthKpiIndicatorYear>
                                    {
                                        new HealthKpiIndicatorYear{
                                            Key="y2026", Year=2026,
                                            Title="فعاليات توعوية حول نمط الحياة الصحي",
                                            Subtitle="الوصول إلى 600 مشارك (مرحلة أولى)",
                                            Target=600, Actual=600,
                                            Badge="مستهدف 2026", Tone="info", Emoji="🧠",
                                            Icon="fa-solid fa-person-walking"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2027", Year=2027,
                                            Title="التوسع في برنامج حياة صحية",
                                            Subtitle="إضافة 200 مشارك (إجمالي 800)",
                                            Target=200, Actual=0,
                                            Badge="مستهدف 2027", Tone="warning", Emoji="📈",
                                            Icon="fa-solid fa-up-right-and-down-left-from-center"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2028", Year=2028,
                                            Title="مبادرات مجتمعية وتحسين الاستدامة",
                                            Subtitle="إضافة 200 مشارك (اكتمال 1000)",
                                            Target=200, Actual=0,
                                            Badge="مستهدف 2028", Tone="info", Emoji="🤝",
                                            Icon="fa-solid fa-people-group"
                                        }
                                    }
                                },


                                // =========================================================
                                // KPI 2) استخدام الدراجات (10% من سكان المدينة)
                                // (توزيع سنوي: 4% / 3% / 3% = 10%)
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
                                            Subtitle="رفع الاستخدام +4% افتتاح مسار دراجات بطول 3 كم بنهاية 2026",
                                            Target=4, Actual=3,
                                            Badge="مستهدف 2026", Tone="success", Emoji="🚲", Icon="fa-solid fa-bicycle"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2027", Year=2027,
                                            Title="توسعة المسارات وبرامج الشراكات",
                                            Subtitle="رفع الاستخدام +3% بنهاية 2027",
                                            Target=3, Actual=0,
                                            Badge="مستهدف 2027", Tone="success", Emoji="🚲", Icon="fa-solid fa-bicycle"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2028", Year=2028,
                                            Title="تكامل المبادرات وتحسين الوصول",
                                            Subtitle="رفع الاستخدام +3% بنهاية 2028 (اكتمال 10%)",
                                            Target=3, Actual=0,
                                            Badge="مستهدف 2028", Tone="success", Emoji="🚲", Icon="fa-solid fa-bicycle"
                                        },
                                    }
                                },


                                // =========================================================
                                // KPI 3) خفض نسبة المدخنين (إجمالي خفض 15% خلال 3 سنوات)
                                // (توزيع سنوي: 6% / 6% / 4% = 15%)
                                // =========================================================
                                new HealthKpiIndicator
                                {
                                    Key="kpi3",
                                    Title="خفض نسبة المدخنين",
                                    Subtitle="هدف نهائي: خفض 15% (6% + 6% + 4%)",
                                    Unit="%",
                                    Emoji="🚭",
                                    Icon="fa-solid fa-ban-smoking",
                                    Tone="danger",
                                    PlanGoal=15,
                                    Hint="المستهدف سنوياً: 2026 خفض 6%، 2027 خفض 6%، 2028 خفض 4% (الإجمالي 15%).",
                                    Years=new List<HealthKpiIndicatorYear>{
                                        new HealthKpiIndicatorYear{
                                            Key="y2026", Year=2026,
                                            Title="تفعيل عيادات الإقلاع والدعم الفردي",
                                            Subtitle="برامج إقلاع ودعم فردي (أثر توعوي 18%) وخفض 6% بنهاية 2026",
                                            Target=6, Actual=5,
                                            Badge="مستهدف 2026", Tone="danger", Emoji="🚭", Icon="fa-solid fa-ban-smoking"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2027", Year=2027,
                                            Title="حملات موسعة وبرامج تعليمية",
                                            Subtitle="حملات إقلاع موسعة (أثر توعوي 16%) وخفض 6% بنهاية 2027",
                                            Target=6, Actual=0,
                                            Badge="مستهدف 2027", Tone="danger", Emoji="🚭", Icon="fa-solid fa-ban-smoking"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2028", Year=2028,
                                            Title="التقييم النهائي والاستدامة",
                                            Subtitle="تقييم نهائي وانخفاض إجمالي بنسبة 15% (اكتمال الهدف)",
                                            Target=4, Actual=0,
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
                                    Subtitle="هدف نهائي: تزويد 70% من المنازل بفلاتر المياه",
                                    Unit="%",
                                    Emoji="💧",
                                    Icon="fa-solid fa-water",
                                    Tone="info",
                                    PlanGoal=70,
                                    Years=new List<HealthKpiIndicatorYear>{
                                        new HealthKpiIndicatorYear{
                                            Key="y2026", Year=2026,
                                            Title="إطلاق المبادرة والعروض",
                                            Subtitle="عروض على فلاتر المياه وتركيب الفلاتر في 20% من المنازل",
                                            Target=25, Actual=22,
                                            Badge="مستهدف 2026", Tone="info", Emoji="💧", Icon="fa-solid fa-water"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2027", Year=2027,
                                            Title="التوسع في التركيب",
                                            Subtitle="توسعة تركيب فلاتر المياه لتغطية 50% من المنازل",
                                            Target=50, Actual=0,
                                            Badge="مستهدف 2027", Tone="info", Emoji="💧", Icon="fa-solid fa-water"
                                        },
                                        new HealthKpiIndicatorYear{
                                            Key="y2028", Year=2028,
                                            Title="الاكتمال والاستدامة",
                                            Subtitle="تزويد 70% من المنازل بفلاتر المياه وتحسين مستدام للجودة",
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
                                            Title="إطلاق التدريب وتفعيل النادي",
                                            Subtitle="الوصول إلى 200 مستفيد مع إشراك النساء والأطفال",
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
                                            Title="الاستدامة وقياس الأثر",
                                            Subtitle="الوصول إلى 500 مستفيد مع استدامة الأنشطة",
                                            Target=500, Actual=0,
                                            Badge="مستهدف 2028", Tone="warning", Emoji="🏋️", Icon="fa-solid fa-dumbbell"
                                        },
                                    }
                                },

                                // =========================================================
                                // KPI 6) زراعة 5000 شتلة + نقطتي إعادة التدوير
                                // (توزيع المستهدف: 2000 / 2000 / 1000)
                                // =========================================================
                                new HealthKpiIndicator
                                {
                                    Key = "kpi6",
                                    Title = "زراعة 5000 شتلة + إعادة التدوير",
                                    Subtitle = "هدف نهائي: 5000 شتلة + تشغيل نقطتي تدوير",
                                    Unit = "شتلة",
                                    Emoji = "🌱",
                                    Icon = "fa-solid fa-seedling",
                                    Tone = "success",
                                    PlanGoal = 5000,
                                    Years = new List<HealthKpiIndicatorYear>
                                    {
                                        new HealthKpiIndicatorYear
                                        {
                                            Key = "y2026", Year = 2026,
                                            Title = "إطلاق المبادرة والتجهيز",
                                            Subtitle = "زراعة 2000 شتلة + تجهيز نقطة تدوير وتطبيق إغلاق الحاويات بالأحياء الحساسة وتسريع جمع النفايات",
                                            Target = 2000, Actual = 900,
                                            Badge = "مستهدف 2026", Tone = "success", Emoji = "🌱", Icon = "fa-solid fa-seedling"
                                        },
                                        new HealthKpiIndicatorYear
                                        {
                                            Key = "y2027", Year = 2027,
                                            Title = "التوسع المجتمعي",
                                            Subtitle = "زراعة 2000 شتلة إضافية + تشغيل مستدام لإعادة التدوير",
                                            Target = 2000, Actual = 0,
                                            Badge = "مستهدف 2027", Tone = "success", Emoji = "🌱", Icon = "fa-solid fa-seedling"
                                        },
                                        new HealthKpiIndicatorYear
                                        {
                                            Key = "y2028", Year = 2028,
                                            Title = "الاستكمال والاستدامة",
                                            Subtitle = "زراعة 1000 شتلة + تدوير مفعل وتحسين جودة التدوير",
                                            Target = 1000, Actual = 0,
                                            Badge = "مستهدف 2028", Tone = "success", Emoji = "🌱", Icon = "fa-solid fa-seedling"
                                        },
                                    }
                                },



                                // =========================================================
                                // KPI 7) تقليل الحيوانات الضالة بنسبة 70% (2026–2028)
                                // التوزيع: 2026 (25%) — 2027 (25%) — 2028 (20%)
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
                                            Title = "بدء برنامج الحد من التكاثر",
                                            Subtitle = "تفعيل لجنة مكافحة الحيوانات السائبة والتنسيق مع المركز الوطني لحماية الحياة الفطرية",
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
                                            Title = "تعزيز إجراءات السيطرة",
                                            Subtitle = "إغلاق 80% من الحاويات واستمرار عمليات السيطرة على الكلاب الضالة",
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
                                            Title = "الاستدامة والتقييم النهائي",
                                            Subtitle = "إغلاق 100% من الحاويات وتقييم شامل مع المركز الوطني لحماية الحياة الفطرية (تحقيق خفض 70%)",
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
