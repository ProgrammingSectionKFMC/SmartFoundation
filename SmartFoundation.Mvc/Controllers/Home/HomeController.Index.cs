using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using SmartFoundation.Mvc.Models;
using SmartFoundation.UI.ViewModels.SmartPage;
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

            // Charts are currently disabled; do not load unused chart datasets on login.

            var page = new SmartPageViewModel
            {
                PageTitle = "لوحة التحكم",
                PanelIcon = "fa-solid fa-city"
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
