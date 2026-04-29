using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartCharts;
using SmartFoundation.UI.ViewModels.SmartPage;

namespace SmartFoundation.Mvc.Controllers
{
    public class PopulationDensityController : Controller
    {
        public IActionResult Index()
        {
            var neighborhoods = BuildNeighborhoodData();

            var card = new ChartCardConfig
            {
                Type = ChartCardType.PopulationDensity,
                Id = "population_density_main",
                Title = "الكثافة السكانية في الأحياء السكنية",
                Subtitle = "لوحة تنفيذية للكثافة والتوزيع السكاني",
                ColCss = "12",
                Dir = "rtl",
                ShowHeader = false,
                Variant = ChartCardVariant.Soft,
                ExtraCss = "pdm-dashboard-card",
                PopulationDensityBoardOptions = new PopulationDensityBoardOptions
                {
                    TitleText = "الكثافة السكانية في الأحياء السكنية",
                    SubtitleText = "عرض تحليلي للتوزيع السكاني والمساكن حسب الحي",
                    ShowHeader = true,
                    ShowFooter = true,
                    TopPopulationCount = 18,
                    TopHousingCount = 18,
                    TopDensityCount = 10,
                    TotalPopulationOverride = 10197,
                    TotalMaleOverride = 4894,
                    TotalFemaleOverride = 5303
                },
                PopulationDensityNeighborhoods = neighborhoods
            };

            var vm = new SmartPageViewModel
            {
                PageTitle = "الكثافة السكانية في الأحياء السكنية",
                Charts = new SmartChartsConfig
                {
                    ChartsId = "populationDensityDashboard",
                    Dir = "rtl",
                    Cards = new List<ChartCardConfig> { card }
                }
            };

            return View(vm);
        }

        private static List<PopulationDensityNeighborhood> BuildNeighborhoodData()
        {
            var baseData = new (string Name, int Population, int HousingUnits)[]
            {
                ("إسكان الضباط العزاب القديم", 33, 8),
                ("السكن الجديد للضباط", 594, 135),
                ("السكن الجديد ضباط الصف", 2996, 682),
                ("السكن الجديد قادة", 20, 4),
                ("السكن الجديد كبار الضباط", 41, 9),
                ("حي أحد", 790, 181),
                ("حي القادسية أ", 148, 33),
                ("حي القادسية ب", 442, 100),
                ("حي الوديعة", 165, 39),
                ("حي الوديعة أ", 23, 5),
                ("حي اليرموك", 429, 98),
                ("حي بدر", 971, 222),
                ("حي بدر فئة ب", 40, 8),
                ("حي بدر مساكن طيران القوات البرية 2", 182, 38),
                ("حي حطين", 736, 168),
                ("حي  حطين ال 500", 276, 62),
                ("سكن الإدارة رقم 3", 192, 43),
                ("طريق القوات البرية  الثانية", 91, 22)
            };

            var maleRatios = new[]
            {
                0.56m, 0.57m, 0.58m, 0.55m, 0.59m,
                0.57m, 0.56m, 0.58m, 0.55m, 0.54m,
                0.57m, 0.58m, 0.56m, 0.59m, 0.57m,
                0.56m, 0.58m, 0.55m
            };

            var data = new List<PopulationDensityNeighborhood>(baseData.Length);

            for (var i = 0; i < baseData.Length; i++)
            {
                var male = (int)Math.Round(baseData[i].Population * maleRatios[i], MidpointRounding.AwayFromZero);
                male = Math.Clamp(male, 0, baseData[i].Population);
                var female = baseData[i].Population - male;

                data.Add(new PopulationDensityNeighborhood
                {
                    Name = baseData[i].Name,
                    Population = baseData[i].Population,
                    HousingUnits = baseData[i].HousingUnits,
                    MalePopulation = male,
                    FemalePopulation = female
                });
            }

            return data;
        }
    }
}
