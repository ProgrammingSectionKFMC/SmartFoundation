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
                        
                        // ================== HealthKpiRoadmap: برنامج حياة صحية (KPI Roadmap) ==================
                        new ChartCardConfig
                        {
                            Type = ChartCardType.HealthKpiRoadmap,
                            Title = "مؤشر أداء برنامج حياة صحية",
                            Subtitle = "خطة مستهدفات المشاركين والفعاليات (2026 - 2028)",
                            Icon = "fa-solid fa-heart-pulse",
                            Tone = ChartTone.Info,
                            ColCss = "12 md:12",
                            Dir = "rtl",
                            Variant = ChartCardVariant.Soft,
                            ExtraCss = "border border-slate-400/45 bg-slate-50/80 rounded-lg shadow-[0_1px_1px_rgba(15,23,42,0.02)]",




                            HealthKpiAnimate = true,
                            HealthKpiShowProgress = false,

                            HealthKpiSummary = new HealthKpiSummary
                            {
                                Label = "المستهدف النهائي للخطة",
                                Goal = 1000,
                                Unit = "مشارك",
                                Hint = "مستهدف البرنامج حتى نهاية 2028 عبر التوعية، التوسع، المبادرات المجتمعية، ثم الإغلاق على الهدف.",
                                ValueFormat = "0",
                                Icon = "fa-solid fa-heart-pulse",
                                AccentTone = "info",
                                Href = "#"
                            },

                            HealthKpiMilestones = new List<HealthKpiMilestone>
                            {
                                new HealthKpiMilestone{
                                    Key="y2026",
                                    Year=2026,
                                    Target=600,
                                    Unit="مشارك",
                                    Title="المرحلة الأولى: التوعية بنمط الحياة الصحي",
                                    Subtitle="فعاليات توعوية للوصول إلى 600 مشارك خلال 2026.",
                                    Badge="مستهدف 2026",
                                    Tone="info",
                                    Icon="fa-solid fa-person-walking",
                                    Emoji="🧠",
                                    Href="#"
                                    // ImageUrl="~/images/health/awareness.svg"
                                },
                                new HealthKpiMilestone{
                                    Key="y2027",
                                    Year=2027,
                                    Target=200,
                                    Unit="مشاركة إضافية",
                                    Title="التوسع: برنامج حياة صحية (2)",
                                    Subtitle="توسّع البرنامج للوصول إلى 800 مشارك خلال 2027.",
                                    Badge="مستهدف 2027",
                                    Tone="warning",
                                    Icon="fa-solid fa-up-right-and-down-left-from-center",
                                    Emoji="📈",
                                    Href="#"
                                },
                                new HealthKpiMilestone{
                                    Key="y2028_community",
                                    Year=2028,
                                    Target=200,
                                    Unit="مشاركة إضافية",
                                    Title="مبادرات مجتمعية",
                                    Subtitle="فعاليات مجتمعية للوصول إلى 200 مشاركة خلال 2028.",
                                    Badge="مستهدف 2028",
                                    Tone="info",
                                    Icon="fa-solid fa-people-group",
                                    Emoji="🤝",
                                    Href="#"
                                },
                                new HealthKpiMilestone{
                                    Key="y2028_final",
                                    Year=2028,
                                    Target=1000,
                                    Unit="مشارك",
                                    Title="الإغلاق: الوصول للمستهدف النهائي",
                                    Subtitle="الوصول إلى 1000 مشترك بنهاية 2028 كهدف نهائي للمرحلة.",
                                    Badge="الهدف النهائي",
                                    Tone="success",
                                    Icon="fa-solid fa-flag-checkered",
                                    Emoji="🏁",
                                    Href="#"
                                }
                            }
                        }

                    }
                }

            };



            return View(vm);
        }
    }
}