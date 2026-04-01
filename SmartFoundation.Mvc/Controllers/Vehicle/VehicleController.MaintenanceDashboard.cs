using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartCharts;
using SmartFoundation.UI.ViewModels.SmartPage;
using System.Data;

namespace SmartFoundation.Mvc.Controllers.Vehicle
{
    public partial class VehicleController : Controller
    {
        public async Task<IActionResult> MaintenanceDashboard(string? daysAhead)
        {
            if (string.IsNullOrWhiteSpace(daysAhead))
                daysAhead = "30";

            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = "Vehicle";
            PageName = "Dashboard_MaintenanceDue";

            var spParameters = new object?[]
            {
                "Dashboard_MaintenanceDue",
                IdaraId,
                usersId,
                HostName,
                daysAhead
            };

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

            var table = ds.Tables.Count > 1 ? ds.Tables[1] : null;

            int overdueCount = 0;
            int nearCount = 0;
            int normalCount = 0;
            int openOrderCount = 0;

            if (table != null)
            {
                foreach (DataRow row in table.Rows)
                {
                    var status = row["DueStatus"]?.ToString()?.Trim();
                    var hasOpenOrder = row["HasOpenOrder"]?.ToString()?.Trim();

                    if (status == "متأخرة")
                        overdueCount++;
                    else if (status == "قريبة")
                        nearCount++;
                    else
                        normalCount++;

                    if (hasOpenOrder == "1")
                        openOrderCount++;
                }
            }

            var charts = new SmartChartsConfig
            {
                Title = "لوحة متابعة الصيانة الدورية",
                Dir = "rtl",
                Cards = new List<ChartCardConfig>
                {
                    new ChartCardConfig
                    {
                        Id = "maint_kpi_overdue",
                        Type = ChartCardType.Kpi,
                        Title = "متأخرة",
                        Tone = ChartTone.Danger,
                        ColCss = "12 md:3",
                        Dir = "rtl",
                        BigValue = overdueCount.ToString(),
                        Note = "عدد المركبات المتأخرة"
                    },
                    new ChartCardConfig
                    {
                        Id = "maint_kpi_near",
                        Type = ChartCardType.Kpi,
                        Title = "قريبة",
                        Tone = ChartTone.Warning,
                        ColCss = "12 md:3",
                        Dir = "rtl",
                        BigValue = nearCount.ToString(),
                        Note = "عدد المركبات القريبة"
                    },
                    new ChartCardConfig
                    {
                        Id = "maint_kpi_normal",
                        Type = ChartCardType.Kpi,
                        Title = "طبيعية",
                        Tone = ChartTone.Success,
                        ColCss = "12 md:3",
                        Dir = "rtl",
                        BigValue = normalCount.ToString(),
                        Note = "عدد المركبات الطبيعية"
                    },
                    new ChartCardConfig
                    {
                        Id = "maint_kpi_open",
                        Type = ChartCardType.Kpi,
                        Title = "أمر مفتوح",
                        Tone = ChartTone.Info,
                        ColCss = "12 md:3",
                        Dir = "rtl",
                        BigValue = openOrderCount.ToString(),
                        Note = "مركبات لديها أمر صيانة دوري مفتوح حالياً"
                    }
                }
            };

            var page = new SmartPageViewModel
            {
                PageTitle = "داش بورد الصيانة",
                PanelTitle = "داش بورد الصيانة",
                PanelIcon = "fa-solid fa-screwdriver-wrench",
                Charts = charts
            };

            ViewBag.Table = table;
            ViewBag.DaysAhead = daysAhead;

            return View("MaintenanceDashboard", page);
        }
    }
}