using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using SmartFoundation.Application.Services;
using SmartFoundation.Mvc.Models;
using SmartFoundation.Mvc.Services.Chart;
using SmartFoundation.UI.ViewModels.SmartCharts;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;

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

            // احتفظنا بمشغل Home كخيار رجوع فقط. التشغيل الطبيعي أصبح من SQL Agent.
            if (_configuration.GetValue<bool>("MonthlyBilling:RunFromHome"))
            {
                await GenerateMonthlyRentBillsAsync();
            }

            ControllerName = nameof(Home);
            PageName = "Home";

            var spParameters = new object?[] { "Home", IdaraId, usersId, HostName, usersId };

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            SplitDataSet(ds);

            // ✅ قراءة أسماء الـ Charts من ChartTable
            //var chartMethodNames = new List<string>();

            //if (ChartTable != null && ChartTable.Rows.Count > 0)
            //{
            //    _logger.LogInformation("ChartTable has {Count} rows", ChartTable.Rows.Count);
                
            //    // طباعة أسماء الأعمدة للتأكد
            //    var columns = string.Join(", ", ChartTable.Columns.Cast<DataColumn>().Select(c => c.ColumnName));
            //    _logger.LogInformation("ChartTable Columns: {Columns}", columns);

            //    foreach (DataRow row in ChartTable.Rows)
            //    {
            //        var chartName = row["ChartListName_E"]?.ToString()?.Trim();
                    
            //        if (!string.IsNullOrWhiteSpace(chartName))
            //        {
            //            chartMethodNames.Add(chartName);
            //            _logger.LogInformation("✅ Added chart method: {ChartName}", chartName);
            //        }
            //    }
            //}
            //else
            //{
            //    _logger.LogWarning("⚠️ ChartTable is null or empty");
            //}

            //_logger.LogInformation("📊 Total charts from DB: {Count}", chartMethodNames.Count);

            //// ✅ الحصول على الـ Charts
            //SmartChartsConfig? charts = null;

            //if (chartMethodNames.Any())
            //{
            //    var chartCards = _chartService.GetChartsByMethodNames(chartMethodNames);
                
            //    if (chartCards.Any())
            //    {
            //        charts = new SmartChartsConfig
            //        {
            //            Title = "لوحة مؤشرات النظام الموحد",
            //            Dir = "rtl",
            //            Cards = chartCards
            //        };
                    
            //        _logger.LogInformation("✅ Created SmartChartsConfig with {Count} charts for user {UserId}", chartCards.Count, usersId);
            //    }
            //    else
            //    {
            //        _logger.LogWarning("⚠️ GetChartsByMethodNames returned empty list");
            //    }
            //}
            //else
            //{
            //    _logger.LogInformation("ℹ️ No charts configured for user {UserId}", usersId);
            //}

            var page = new SmartPageViewModel
            {
                PageTitle = "لوحة التحكم",
                PanelIcon = "fa-solid fa-city"//,
                //Charts = charts
            };

            return View("Index", page);
        }

        public IActionResult Privacy()
        {
            return View();
        }

        [Microsoft.AspNetCore.Authorization.AllowAnonymous]
        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error(int? errorId, bool dataSourceUnavailable = false)
        {
            return View(new ErrorViewModel
            {
                ErrorLogID = errorId,
                DataSourceUnavailable = dataSourceUnavailable
            });
        }


        private async Task GenerateMonthlyRentBillsAsync()
        {
            try
            {
                DateTime previousMonth = DateTime.Now.AddMonths(-1);

                int month = previousMonth.Month;
                int year = previousMonth.Year;

                await using var conn = new SqlConnection(
                    _configuration.GetConnectionString("Default"));

                await using var cmd = new SqlCommand("[Housing].[GenerateMonthlyRentBills]", conn);

                cmd.CommandType = CommandType.StoredProcedure;
                cmd.CommandTimeout = 60;

                cmd.Parameters.Add("@Month", SqlDbType.Int).Value = month;
                cmd.Parameters.Add("@Year", SqlDbType.Int).Value = year;
                cmd.Parameters.Add("@entrydata", SqlDbType.NVarChar, 20).Value = usersId ?? "";
                cmd.Parameters.Add("@hostname", SqlDbType.NVarChar, 200).Value = HostName ?? "";
                cmd.Parameters.Add("@idaraID", SqlDbType.Int).Value = Convert.ToInt32(IdaraId);


                await conn.OpenAsync();
                await cmd.ExecuteNonQueryAsync();

                await using var fixedServicesCmd = new SqlCommand(
                    "[Housing].[GenerateMonthlyFixedServiceBills]", conn);

                fixedServicesCmd.CommandType = CommandType.StoredProcedure;
                fixedServicesCmd.CommandTimeout = 120;
                fixedServicesCmd.Parameters.Add("@Month", SqlDbType.Int).Value = month;
                fixedServicesCmd.Parameters.Add("@Year", SqlDbType.Int).Value = year;
                fixedServicesCmd.Parameters.Add("@EntryData", SqlDbType.NVarChar, 20).Value = usersId ?? "";
                fixedServicesCmd.Parameters.Add("@HostName", SqlDbType.NVarChar, 200).Value = HostName ?? "";
                fixedServicesCmd.Parameters.Add("@IdaraID", SqlDbType.BigInt).Value = Convert.ToInt64(IdaraId);

                await fixedServicesCmd.ExecuteNonQueryAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex,
                    "Generate previous month rent/fixed-service bills failed. UserId={UserId}, IdaraId={IdaraId}",
                    usersId,
                    IdaraId);
            }
        }
    }
}
