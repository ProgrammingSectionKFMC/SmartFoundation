using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Application.Services;
using SmartFoundation.Application.Services.Models; // ✅ ADD THIS LINE
using System.Data;
using System.Net;
using System.Threading;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;

namespace SmartFoundation.Mvc.Controllers.Login
{
    public class LoginController : Controller
    {
        private readonly MastersServies _mastersServies;


        public LoginController(MastersServies mastersServies)
        {
            _mastersServies = mastersServies;
        }

        private static readonly Dictionary<string, string> _dnsCache = new(StringComparer.OrdinalIgnoreCase);

        private static string ResolveClientHostName(HttpContext ctx)
        {
            string? forwardedFor = ctx.Request.Headers["X-Forwarded-For"].FirstOrDefault();
            IPAddress? remoteIp = null;
            if (!string.IsNullOrWhiteSpace(forwardedFor))
            {
                var firstIp = forwardedFor.Split(',').First().Trim();
                if (IPAddress.TryParse(firstIp, out var parsed))
                    remoteIp = parsed;
            }

            remoteIp ??= ctx.Connection.RemoteIpAddress;
            if (remoteIp == null)
                return "unknown";

            if (remoteIp.IsIPv4MappedToIPv6) remoteIp = remoteIp.MapToIPv4();

            if (IPAddress.IsLoopback(remoteIp))
                return remoteIp.ToString();

            var ipString = remoteIp.ToString();
            if (_dnsCache.TryGetValue(ipString, out var cached))
                return cached;

            var hostValue = ipString;
            try
            {
                var entry = Dns.GetHostEntry(remoteIp);
                if (!string.IsNullOrWhiteSpace(entry.HostName))
                    hostValue = entry.HostName.TrimEnd('.');
            }
            catch
            {
            }

            _dnsCache[ipString] = hostValue;
            return hostValue;
        }

        [HttpGet]
        [AllowAnonymous]
        [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
        public async Task<IActionResult> Index()
        {
            
            HttpContext.Session.Clear();
            if (Request.Query.ContainsKey("logout"))
            {
                var logoutValue = Request.Query["logout"].ToString();

                if (logoutValue == "1")
                {
                    TempData["Error"] = "تم تسجيل خروجك من النظام لعدم وجود نشاط";
                }
                else if (logoutValue == "2")
                {
                    TempData["Success"] = "تم تسجيل خروجك بنجاح";
                }
                else
                {
                    TempData["Error"] = "تم تسجيل الخروج";
                }
            }

            // Extra anti-cache headers (defense-in-depth)
            Response.Headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0";
            Response.Headers["Pragma"] = "no-cache";
            Response.Headers["Expires"] = "0";

            return View();
        }

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> CheckLogin(string NationalID, string password, CancellationToken ct)
        {


            if (string.IsNullOrWhiteSpace(NationalID) || string.IsNullOrWhiteSpace(password))
            {
                TempData["Error"] = "الرجاء اكمال الحقول المطلوبة";
                TempData["LastUser"] = NationalID;
                return RedirectToAction(nameof(Index));
            }

            DataSet ds;

            var spParameters = new object?[] { NationalID.Trim(), password, Request.Host.Value };
            try
            {
                ds = await _mastersServies.GetLoginsDataSetAsync(spParameters);
            }
            catch (Exception ex)
            {
                TempData["Error"] = "خطأ في الاتصال بالخادم." + ex.Message;
                TempData["LastUser"] = NationalID;
                return RedirectToAction(nameof(Index));
            }

            var auth = _mastersServies.ExtractAuth(ds);


            try
            {
                auth = _mastersServies.ExtractAuth(ds);
            }
            catch (Exception ex)
            {
                TempData["Error"] = "خطأ في معالجة بيانات الدخول: " + ex.Message;
                TempData["LastUser"] = NationalID;
                return RedirectToAction(nameof(Index));
            }



            // ✅ Check 1: usersId validation
            if (string.IsNullOrWhiteSpace(auth.usersId))
            {
                TempData["Error"] = "لايوجد ملف نشط لهذا المستخدم";
                TempData["LastUser"] = NationalID;
                return RedirectToAction(nameof(Index));
            }


            // ✅ Check 2: usersActive validation
            if (auth.usersActive == 0)
            {
                TempData["Error"] = "لايوجد حساب نشط لهذا المستخدم";
                TempData["LastUser"] = NationalID;
                return RedirectToAction(nameof(Index));
            }

            //// ✅ Set session data with null-safe approach
            //try
            //{
            string clientHostName = ResolveClientHostName(HttpContext);

            // Use ?? "" to prevent null reference exceptions
            HttpContext.Session.SetString("usersID", auth.usersId ?? "");
            HttpContext.Session.SetString("fullName", auth.fullName ?? "");
            HttpContext.Session.SetString("OrganizationID", auth.OrganizationID ?? "");
            HttpContext.Session.SetString("OrganizationName", auth.OrganizationName ?? "");
            HttpContext.Session.SetString("IdaraID", auth.IdaraID ?? "");
            HttpContext.Session.SetString("IdaraName", auth.IdaraName ?? "");
            HttpContext.Session.SetString("DepartmentID", auth.DepartmentID ?? "");
            HttpContext.Session.SetString("DepartmentName", auth.DepartmentName ?? "");
            HttpContext.Session.SetString("SectionID", auth.SectionID ?? "");
            HttpContext.Session.SetString("SectionName", auth.SectionName ?? "");
            HttpContext.Session.SetString("DivisonID", auth.DivisonID ?? "");
            HttpContext.Session.SetString("DivisonName", auth.DivisonName ?? "");
            HttpContext.Session.SetString("photoBase64", auth.photoBase64 ?? "");  // ✅ FIXED: Changed from auth.Photo to auth.photoBase64
            HttpContext.Session.SetString("ThameName", auth.ThameName ?? "");
            HttpContext.Session.SetString("DeptCode", auth.DeptCode ?? "");
            HttpContext.Session.SetString("nationalID", auth.nationalID ?? "");
            HttpContext.Session.SetString("usersActive", auth.usersActive.ToString());
            HttpContext.Session.SetString("GeneralNo", auth.GeneralNo);
            HttpContext.Session.SetString("HostName", clientHostName ?? "");
            HttpContext.Session.SetString("LastActivityUtc", DateTime.UtcNow.ToString("O"));


            //}
            //catch (Exception ex)
            //{
            //    TempData["Error"] = "خطأ في حفظ بيانات الجلسة: " + ex.Message;
            //    TempData["LastUser"] = NationalID;
            //    return RedirectToAction(nameof(Index));
            //}

            //// Set success message based on useractive
            //switch (auth.useractive)
            //{
            //    case 1: TempData["Success"] = auth.Message_ ?? "تم تسجيل الدخول بنجاح."; break;
            //    case 2: TempData["Warning"] = auth.Message_ ?? "تم تسجيل الدخول مع تحذير."; break;
            //    case 3: TempData["Info"] = auth.Message_ ?? "معلومة: تم الدخول."; break;
            //    default: TempData["Success"] = auth.Message_ ?? "تم تسجيل الدخول."; break;
            //}


            return RedirectToAction("Index", "Home");
        }

        [HttpGet]
        public IActionResult Logout()
        {
            // حذف جميع السيشنات
            HttpContext.Session.Clear();

            // حذف الكوكيز إذا كنت تستخدم Cookie Authentication (اختياري)
            // await HttpContext.SignOutAsync();

            return RedirectToAction("Index", "Login", new { logout = 2 });
        }

    }
}
