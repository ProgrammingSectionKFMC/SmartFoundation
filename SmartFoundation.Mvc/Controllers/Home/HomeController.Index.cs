using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Application.Services;
using SmartFoundation.Mvc.Models;
using SmartFoundation.Mvc.Services.Chart;
using SmartFoundation.UI.ViewModels.SmartCharts;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Diagnostics;

namespace SmartFoundation.Mvc.Controllers.Home
{
    public partial class HomeController : Controller
    {
        [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
        public async Task<IActionResult> Index()
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }

            ControllerName = nameof(Home);
            PageName = "Home";

            var spParameters = new object?[] { "Home", IdaraId, usersId, HostName, usersId };

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            SplitDataSet(ds);

            // ✅ قراءة أسماء الـ Charts من ChartTable
            var chartMethodNames = new List<string>();

            if (ChartTable != null && ChartTable.Rows.Count > 0)
            {
                _logger.LogInformation("ChartTable has {Count} rows", ChartTable.Rows.Count);
                
                // طباعة أسماء الأعمدة للتأكد
                var columns = string.Join(", ", ChartTable.Columns.Cast<DataColumn>().Select(c => c.ColumnName));
                _logger.LogInformation("ChartTable Columns: {Columns}", columns);

                foreach (DataRow row in ChartTable.Rows)
                {
                    var chartName = row["ChartListName_E"]?.ToString()?.Trim();
                    
                    if (!string.IsNullOrWhiteSpace(chartName))
                    {
                        chartMethodNames.Add(chartName);
                        _logger.LogInformation("✅ Added chart method: {ChartName}", chartName);
                    }
                }
            }
            else
            {
                _logger.LogWarning("⚠️ ChartTable is null or empty");
            }

            _logger.LogInformation("📊 Total charts from DB: {Count}", chartMethodNames.Count);

            // ✅ الحصول على الـ Charts
            SmartChartsConfig? charts = null;

            if (chartMethodNames.Any())
            {
                var chartCards = _chartService.GetChartsByMethodNames(chartMethodNames);
                
                if (chartCards.Any())
                {
                    charts = new SmartChartsConfig
                    {
                        Title = "لوحة مؤشرات الإسكان والمباني والصيانة والساكنين",
                        Dir = "rtl",
                        Cards = chartCards
                    };
                    
                    _logger.LogInformation("✅ Created SmartChartsConfig with {Count} charts for user {UserId}", chartCards.Count, usersId);
                }
                else
                {
                    _logger.LogWarning("⚠️ GetChartsByMethodNames returned empty list");
                }
            }
            else
            {
                _logger.LogInformation("ℹ️ No charts configured for user {UserId}", usersId);
            }

            var page = new SmartPageViewModel
            {
                PageTitle = "لوحة التحكم",
                PanelIcon = "fa-solid fa-city",
                Charts = charts
            };

            return View("Index", page);
        }

        public IActionResult Privacy()
        {
            return View();
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}
