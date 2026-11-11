using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Application.Services;
using SmartFoundation.Mvc.Models;
using System.Data;
using Microsoft.Extensions.Caching.Memory;

namespace SmartFoundation.Mvc.Controllers.HousingCommandCenter
{
    public partial class HousingCommandCenterDashboardController : Controller
    {
        private readonly MastersServies _mastersServies;
        private readonly CrudController _CrudController;
        private readonly IWebHostEnvironment _env;

        private readonly SmartFoundation.Mvc.Services.DashboardDisplaySessionStore _displaySessionStore;

        private readonly IMemoryCache _memoryCache;
        private readonly SmartFoundation.Mvc.Services.DashboardMetricsCacheService _dashboardMetricsCacheService;

        protected string? ControllerName;
        protected string? PageName;

        protected string? usersId;
        protected string? FullName;
        protected string? OrganizationId;
        protected string? OrganizationName;
        protected string? IdaraId;
        protected string? IdaraName;
        protected string? DepartmentId;
        protected string? DepartmentName;
        protected string? SectionId;
        protected string? SectionName;
        protected string? DivisionId;
        protected string? DivisionName;
        protected string? PhotoBase64;
        protected string? ThameName;
        protected string? DeptCode;
        protected string? NationalId;
        protected string? IdNumber;
        protected string? UserActive;
        protected string? HostName;
        protected string? LastActivityUtc;
        protected string? OrganaiztionLogo;
        protected string? IdaraLogo;

        protected DataTable? permissionTable;

        
        protected DataTable? dt1;
        protected DataTable? dt2;
        protected DataTable? dt3;
        protected DataTable? dt4;
        protected DataTable? dt5;
        protected DataTable? dt6;
        protected DataTable? dt7;
        protected DataTable? dt8;
        protected DataTable? dt9;
        protected DataTable? dt10;
        protected DataTable? dt11;
        protected DataTable? dt12;
        protected DataTable? dt13;

        protected DataTable? dtExtra1;
        protected DataTable? dtExtra2;
        protected DataTable? dtExtra3;
        protected DataTable? dtExtra4;
        protected DataTable? dtExtra5;
        protected DataTable? dtExtra6;
        protected DataTable? dtExtra7;
        protected DataTable? dtExtra8;
        protected DataTable? dtExtra9;

        public HousingCommandCenterDashboardController(
    MastersServies mastersServies,
    CrudController crudController,
    IWebHostEnvironment env,
    SmartFoundation.Mvc.Services.DashboardDisplaySessionStore displaySessionStore,
    IMemoryCache memoryCache,
    SmartFoundation.Mvc.Services.DashboardMetricsCacheService dashboardMetricsCacheService)
        {
            _mastersServies = mastersServies;
            _CrudController = crudController;
            _env = env;
            _displaySessionStore = displaySessionStore;
            _memoryCache = memoryCache;
            _dashboardMetricsCacheService = dashboardMetricsCacheService;
        }

        protected bool InitPageContext(out IActionResult? redirectResult)
        {
            redirectResult = null;


            if (HttpContext.User.Identities.Any(identity =>
                identity.IsAuthenticated &&
                identity.AuthenticationType == "DashboardDisplay"))
            {
                var token = HttpContext.User
                    .FindFirst("DashboardDisplayToken")?.Value;

                if (!_displaySessionStore.TryGet(
                    token, out var displayContext) ||
                    displayContext == null)
                {
                    redirectResult = Unauthorized();
                    return false;
                }

                ApplyPageContext(key =>
                    displayContext.TryGetValue(key, out var value)
                        ? value
                        : null);

                return true;
            }


            if (string.IsNullOrWhiteSpace(
                HttpContext.Session.GetString("usersID")))
            {
                redirectResult = RedirectToAction(
                    "Index",
                    "Login",
                    new { logout = 1 });

                return false;
            }

            ApplyPageContext(
    key => HttpContext.Session.GetString(key));

            return true;
        }

        private void ApplyPageContext(Func<string, string?> read)
        {
            usersId = read("usersID");
            FullName = read("fullName");
            OrganizationId = read("OrganizationID");
            OrganizationName = read("OrganizationName");
            IdaraId = read("IdaraID");
            IdaraName = read("IdaraName");
            DepartmentId = read("DepartmentID");
            DepartmentName = read("DepartmentName");
            SectionId = read("SectionID");
            SectionName = read("SectionName");
            DivisionId = read("DivisonID");
            DivisionName = read("DivisonName");
            PhotoBase64 = read("photoBase64");
            ThameName = read("ThameName");
            DeptCode = read("DeptCode");
            NationalId = read("nationalID");
            IdNumber = read("IDNumber") ?? NationalId;
            UserActive = read("useractive");
            HostName = read("HostName");
            LastActivityUtc = read("LastActivityUtc");
            OrganaiztionLogo = read("OrganaiztionLogo");
            IdaraLogo = read("IdaraLogo");
        }

        protected void SplitDataSet(DataSet ds)
        {
            permissionTable = (ds?.Tables?.Count ?? 0) > 0 ? ds.Tables[0] : null;

            dt1 = (ds?.Tables?.Count ?? 0) > 1 ? ds.Tables[1] : null;
            dt2 = (ds?.Tables?.Count ?? 0) > 2 ? ds.Tables[2] : null;
            dt3 = (ds?.Tables?.Count ?? 0) > 3 ? ds.Tables[3] : null;
            dt4 = (ds?.Tables?.Count ?? 0) > 4 ? ds.Tables[4] : null;
            dt5 = (ds?.Tables?.Count ?? 0) > 5 ? ds.Tables[5] : null;
            dt6 = (ds?.Tables?.Count ?? 0) > 6 ? ds.Tables[6] : null;

            dt7 = (ds?.Tables?.Count ?? 0) > 7 ? ds.Tables[7] : null;
            dt8 = (ds?.Tables?.Count ?? 0) > 8 ? ds.Tables[8] : null;
            dt9 = (ds?.Tables?.Count ?? 0) > 9 ? ds.Tables[9] : null;

            dt10 = (ds?.Tables?.Count ?? 0) > 10 ? ds.Tables[10] : null;
            dt11 = (ds?.Tables?.Count ?? 0) > 11 ? ds.Tables[11] : null;
            dt12 = (ds?.Tables?.Count ?? 0) > 12 ? ds.Tables[12] : null;
            dt13 = (ds?.Tables?.Count ?? 0) > 13 ? ds.Tables[13] : null;
        }

        protected void SplitExtraDataSet(DataSet dsExtra)
        {
            permissionTable = (dsExtra?.Tables?.Count ?? 0) > 0 ? dsExtra.Tables[0] : null;
            dtExtra1 = (dsExtra?.Tables?.Count ?? 0) > 1 ? dsExtra.Tables[1] : null;
            dtExtra2 = (dsExtra?.Tables?.Count ?? 0) > 2 ? dsExtra.Tables[2] : null;
            dtExtra3 = (dsExtra?.Tables?.Count ?? 0) > 3 ? dsExtra.Tables[3] : null;
            dtExtra4 = (dsExtra?.Tables?.Count ?? 0) > 4 ? dsExtra.Tables[4] : null;
            dtExtra5 = (dsExtra?.Tables?.Count ?? 0) > 5 ? dsExtra.Tables[5] : null;
            dtExtra6 = (dsExtra?.Tables?.Count ?? 0) > 6 ? dsExtra.Tables[6] : null;
            dtExtra7 = (dsExtra?.Tables?.Count ?? 0) > 7 ? dsExtra.Tables[7] : null;
            dtExtra8 = (dsExtra?.Tables?.Count ?? 0) > 8 ? dsExtra.Tables[8] : null;
            dtExtra9 = (dsExtra?.Tables?.Count ?? 0) > 9 ? dsExtra.Tables[9] : null;
        }
    }
}