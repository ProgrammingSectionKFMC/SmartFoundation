using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using SmartFoundation.Application.Services;
using System.Data;
using System.Linq;
using System.Net;
using System.Net.Sockets;

namespace SmartFoundation.Mvc.Controllers.IncomeSystem
{
    // ✅ هذا هو الـ Base الحقيقي: نفس الكنترولر (partial) ويحتوي كل الاعتماديات المشتركة
    public partial class IncomeSystemController : Controller
    {
        // ===== Services (Shared) =====
        protected readonly MastersServies _mastersServies;
        protected readonly CrudController _CrudController;
        protected readonly IWebHostEnvironment _env;
        protected readonly ILogger<IncomeSystemController> _logger;

        // ✅ مضافة لدعم UploadExcel داخل نفس الكنترولر
        protected readonly IAntiforgery _antiforgery;
        protected readonly IConfiguration _cfg;

        // ===== Common Context =====
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

        // ===== DataSet Split =====
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
        protected DataTable? dt14;
        protected DataTable? dt15;

        // ✅ Constructor واحد فقط يخدم كل ملفات الـ partial
        public IncomeSystemController(
            MastersServies mastersServies,
            CrudController crudController,
            IWebHostEnvironment env,
            ILogger<IncomeSystemController> logger,
            IAntiforgery antiforgery,
            IConfiguration cfg)
        {
            _mastersServies = mastersServies;
            _CrudController = crudController;
            _env = env;
            _logger = logger;

            _antiforgery = antiforgery;
            _cfg = cfg;
        }

        public IActionResult Index()
        {
            return View();
        }

        /// <summary>
        /// يقرأ بيانات السيشن ويعبّي المتغيّرات المشتركة
        /// يرجع false لو ما فيه user ويضبط redirect
        /// </summary>
        protected bool InitPageContext(out IActionResult? redirectResult)
        {
            redirectResult = null;

            if (string.IsNullOrWhiteSpace(HttpContext.Session.GetString("usersID")))
            {
                redirectResult = RedirectToAction("Index", "Login", new { logout = 1 });
                return false;
            }

            usersId = HttpContext.Session.GetString("usersID");
            FullName = HttpContext.Session.GetString("fullName");
            OrganizationId = HttpContext.Session.GetString("OrganizationID");
            OrganizationName = HttpContext.Session.GetString("OrganizationName");
            IdaraId = HttpContext.Session.GetString("IdaraID");
            IdaraName = HttpContext.Session.GetString("IdaraName");
            DepartmentId = HttpContext.Session.GetString("DepartmentID");
            DepartmentName = HttpContext.Session.GetString("DepartmentName");
            SectionId = HttpContext.Session.GetString("SectionID");
            SectionName = HttpContext.Session.GetString("SectionName");
            DivisionId = HttpContext.Session.GetString("DivisonID");
            DivisionName = HttpContext.Session.GetString("DivisonName");
            PhotoBase64 = HttpContext.Session.GetString("photoBase64");
            ThameName = HttpContext.Session.GetString("ThameName");
            DeptCode = HttpContext.Session.GetString("DeptCode");
            NationalId = HttpContext.Session.GetString("nationalID");
            IdNumber = HttpContext.Session.GetString("IDNumber") ?? NationalId;
            UserActive = HttpContext.Session.GetString("useractive");
            HostName = HttpContext.Session.GetString("HostName");
            LastActivityUtc = HttpContext.Session.GetString("LastActivityUtc");

            // (اختياري) fallback لاسم الجهاز لو ما موجود بالسيشن
            if (string.IsNullOrWhiteSpace(HostName))
            {
                try { HostName = Dns.GetHostName(); } catch { /* ignore */ }
            }

            return true;
        }

        /// <summary>
        /// تقسيم الـ DataSet إلى جداول dt1..dt9 + جدول الصلاحيات
        /// </summary>
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
            dt14 = (ds?.Tables?.Count ?? 0) > 14 ? ds.Tables[14] : null;
            dt15 = (ds?.Tables?.Count ?? 0) > 15 ? ds.Tables[15] : null;
        }

        /// <summary>
        /// (اختياري) يساعدك تجيب IP داخلي للجهاز
        /// </summary>
        protected string? GetLocalIp()
        {
            try
            {
                var host = Dns.GetHostEntry(Dns.GetHostName());
                var ip = host.AddressList.FirstOrDefault(a => a.AddressFamily == AddressFamily.InterNetwork);
                return ip?.ToString();
            }
            catch
            {
                return null;
            }
        }
    }
}