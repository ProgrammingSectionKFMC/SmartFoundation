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
using Microsoft.Extensions.Logging;
using System.Security.Claims;

namespace SmartFoundation.Mvc.Controllers.Login
{
    public class LoginController : Controller
    {
        private readonly MastersServies _mastersServies;
        private readonly AuthenticationAuditService _authenticationAuditService;
        private readonly ILogger<LoginController> _logger;


        public LoginController(
            MastersServies mastersServies,
            AuthenticationAuditService authenticationAuditService,
            ILogger<LoginController> logger)
        {
            _mastersServies = mastersServies;
            _authenticationAuditService = authenticationAuditService;
            _logger = logger;
        }

        private static readonly Dictionary<string, string> _dnsCache = new(StringComparer.OrdinalIgnoreCase);

        private RedirectToActionResult RedirectToLogin(string messageType, string message, string? nationalId = null)
        {
            TempData["LoginMessageType"] = messageType;
            TempData["LoginMessage"] = message;

            if (!string.IsNullOrWhiteSpace(nationalId))
                TempData["LoginLastUser"] = nationalId;

            return RedirectToAction(nameof(Index));
        }

        private static string ResolveClientHostName(HttpContext ctx)
        {
            IPAddress? remoteIp = ctx.Connection.RemoteIpAddress;
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

        private Task WriteAuthenticationAuditAsync(
            string eventType,
            bool isSuccessful,
            string? loginIdentifier = null,
            string? usersId = null,
            string? failureReasonCode = null,
            string? failureMessage = null)
        {
            long? parsedUsersId = long.TryParse(usersId, out var id) ? id : null;
            var remoteIp = HttpContext.Connection.RemoteIpAddress;
            if (remoteIp?.IsIPv4MappedToIPv6 == true)
                remoteIp = remoteIp.MapToIPv4();

            var hostName = HttpContext.Session.GetString("HostName");
            if (string.IsNullOrWhiteSpace(hostName))
                hostName = ResolveClientHostName(HttpContext);

            return _authenticationAuditService.TryWriteAsync(
                new AuthenticationAuditEntry
                {
                    EventType = eventType,
                    UsersId = parsedUsersId,
                    LoginIdentifier = loginIdentifier,
                    IsSuccessful = isSuccessful,
                    FailureReasonCode = failureReasonCode,
                    FailureMessage = failureMessage,
                    IpAddress = remoteIp?.ToString(),
                    HostName = hostName,
                    UserAgent = Request.Headers.UserAgent.ToString(),
                    SessionId = HttpContext.Session.Id,
                    TraceId = HttpContext.TraceIdentifier,
                    RequestPath = Request.Path.Value
                });
        }

        private static string ResolveLoginFailureReason(string? message)
        {
            if (string.IsNullOrWhiteSpace(message))
                return "AUTHENTICATION_REJECTED";

            if (message.Contains("غير صحيحة", StringComparison.OrdinalIgnoreCase))
                return "INVALID_CREDENTIALS";
            if (message.Contains("منتهية", StringComparison.OrdinalIgnoreCase))
                return "PASSWORD_EXPIRED";
            if (message.Contains("اعادة ضبط", StringComparison.OrdinalIgnoreCase) ||
                message.Contains("إعادة ضبط", StringComparison.OrdinalIgnoreCase))
                return "PASSWORD_RESET_REQUIRED";

            return "NO_ACTIVE_PROFILE";
        }

        [HttpGet]
        [AllowAnonymous]
        [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
        public IActionResult Index()
        {
            var lastUser = TempData["LoginLastUser"]?.ToString() ?? string.Empty;
            ViewBag.LastUser = lastUser;

            var messageType = TempData["LoginMessageType"]?.ToString() ?? string.Empty;
            var message = TempData["LoginMessage"]?.ToString() ?? string.Empty;

            HttpContext.Session.Clear();
            if (Request.Query.ContainsKey("logout"))
            {
                var logoutValue = Request.Query["logout"].ToString();

                if (logoutValue == "1")
                {
                    ViewBag.LoginMessageType = "error";
                    ViewBag.LoginMessage = "تم تسجيل خروجك من النظام لعدم وجود نشاط";
                }
                else if (logoutValue == "2")
                {
                    ViewBag.LoginMessageType = "success";
                    ViewBag.LoginMessage = "تم تسجيل خروجك بنجاح";
                }
                else
                {
                    ViewBag.LoginMessageType = "error";
                    ViewBag.LoginMessage = "تم تسجيل الخروج";
                }
            }
            else if (!string.IsNullOrWhiteSpace(messageType) && !string.IsNullOrWhiteSpace(message))
            {
                ViewBag.LoginMessageType = messageType;
                ViewBag.LoginMessage = message;
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

            //if (DateTime.Now > new DateTime(2027, 1, 1))
            //{
            //    return RedirectToLogin("error", "حصل خطأ ما الرجاء التواصل مع فريق عمل المنصة الموحدة", NationalID);
            //}

            if (string.IsNullOrWhiteSpace(NationalID) || string.IsNullOrWhiteSpace(password))
            {
                await WriteAuthenticationAuditAsync(
                    AuthenticationAuditEventTypes.LoginFailed,
                    false,
                    NationalID,
                    failureReasonCode: "MISSING_FIELDS",
                    failureMessage: "لم تكتمل حقول تسجيل الدخول المطلوبة.");
                return RedirectToLogin("error", "الرجاء اكمال الحقول المطلوبة", NationalID);
            }

            NationalID = NationalID.Trim();

            var loginGuard = await _authenticationAuditService.CheckLoginGuardAsync(NationalID, ct);
            if (!loginGuard.IsAvailable)
            {
                return RedirectToLogin(
                    "error",
                    "تعذر التحقق من سياسة محاولات الدخول. يرجى المحاولة مرة أخرى.",
                    NationalID);
            }

            if (!loginGuard.IsAllowed)
            {
                await WriteAuthenticationAuditAsync(
                    AuthenticationAuditEventTypes.LoginFailed,
                    false,
                    NationalID,
                    loginGuard.UsersId?.ToString(),
                    loginGuard.BlockReasonCode ?? "LOGIN_BLOCKED",
                    loginGuard.Message);

                return RedirectToLogin(
                    "error",
                    loginGuard.Message ?? "تعذر تسجيل الدخول مؤقتًا.",
                    NationalID);
            }

            DataSet ds;

            var spParameters = new object?[] { NationalID, password, Request.Host.Value };
            try
            {
                ds = await _mastersServies.GetLoginsDataSetAsync(spParameters);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Login data source call failed");
                await WriteAuthenticationAuditAsync(
                    AuthenticationAuditEventTypes.LoginFailed,
                    false,
                    NationalID,
                    failureReasonCode: "DATA_SOURCE_ERROR",
                    failureMessage: "تعذر استدعاء مصدر بيانات تسجيل الدخول.");
                return RedirectToLogin("error", "حدث خطأ أثناء الاتصال بالخادم. يرجى المحاولة مرة أخرى.", NationalID);
            }

            AuthInfo auth;
            try
            {
                auth = _mastersServies.ExtractAuth(ds);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to process login result");
                await WriteAuthenticationAuditAsync(
                    AuthenticationAuditEventTypes.LoginFailed,
                    false,
                    NationalID,
                    failureReasonCode: "RESULT_PROCESSING_ERROR",
                    failureMessage: "تعذرت معالجة نتيجة تسجيل الدخول.");
                return RedirectToLogin("error", "حدث خطأ أثناء معالجة بيانات الدخول. يرجى المحاولة مرة أخرى.", NationalID);
            }



            // ✅ Check 1: usersId validation
            if (string.IsNullOrWhiteSpace(auth.usersId))
            {
                var message = !string.IsNullOrWhiteSpace(auth.Message_) ? auth.Message_ : "لايوجد ملف نشط لهذا المستخدم";
                await WriteAuthenticationAuditAsync(
                    AuthenticationAuditEventTypes.LoginFailed,
                    false,
                    NationalID,
                    failureReasonCode: ResolveLoginFailureReason(message),
                    failureMessage: message);
                // Use SQL message if available, otherwise fallback
                return RedirectToLogin(
                    "error",
                    message,
                    NationalID);
            }


            // ✅ Check 2: usersActive validation
            if (auth.usersActive == 0)
            {
                var message = !string.IsNullOrWhiteSpace(auth.Message_) ? auth.Message_ : "لايوجد حساب نشط لهذا المستخدم";
                await WriteAuthenticationAuditAsync(
                    AuthenticationAuditEventTypes.LoginFailed,
                    false,
                    NationalID,
                    auth.usersId,
                    "ACCOUNT_INACTIVE",
                    message);
                // ✅ FIXED: Use message from SQL instead of hard-coded
                return RedirectToLogin(
                    "error",
                    message,
                    NationalID);
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
            HttpContext.Session.SetString("GeneralNo", auth.GeneralNo ?? "");
            HttpContext.Session.SetString("HostName", clientHostName ?? "");
            HttpContext.Session.SetString("LastActivityUtc", DateTime.UtcNow.ToString("O"));
            HttpContext.Session.SetString("AdminTypeID", auth.AdminTypeID ?? "");
            HttpContext.Session.SetString("AdminTypeName", auth.AdminTypeName ?? "");
            HttpContext.Session.SetString("ChangedPassword", auth.ChangedPassword?.ToString() ?? "0");
            HttpContext.Session.SetString("OrganaiztionLogo", auth.OrganaiztionLogo ?? "");  // ✅ FIXED: Changed from auth.Photo to auth.photoBase64
            HttpContext.Session.SetString("IdaraLogo", auth.IdaraLogo ?? "");  // ✅ FIXED: Changed from auth.Photo to auth.photoBase64

            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, auth.usersId!),
                new(ClaimTypes.Name, auth.fullName ?? string.Empty)
            };
            var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
            var principal = new ClaimsPrincipal(identity);

            await HttpContext.SignInAsync(
                CookieAuthenticationDefaults.AuthenticationScheme,
                principal,
                new AuthenticationProperties
                {
                    IsPersistent = false,
                    AllowRefresh = true,
                    ExpiresUtc = DateTimeOffset.UtcNow.AddMinutes(5)
                });

            await WriteAuthenticationAuditAsync(
                AuthenticationAuditEventTypes.LoginSuccess,
                true,
                auth.nationalID ?? NationalID,
                auth.usersId);



            //}
            //catch (Exception ex)
            //{
            //    TempData["LastUser"] = NationalID;
            //    return RedirectToAction(nameof(Index));
            //}

            switch (auth.usersActive)
            {
                case 1:
                    TempData["Success"] = auth.Message_ ?? "تم تسجيل الدخول بنجاح.";
                    break;
                case 2:
                    TempData["Warning"] = auth.Message_ ?? "تم تسجيل الدخول مع تحذير.";
                    break;
                case 3:
                    TempData["Info"] = auth.Message_ ?? "معلومة: تم الدخول.";
                    break;
                default:
                    TempData["Success"] = auth.Message_ ?? "تم تسجيل الدخول.";
                    break;
            }


            return RedirectToAction("Index", "Home");
        }

        [HttpPost]
        public async Task<IActionResult> Logout()
        {
            var userId = HttpContext.Session.GetString("usersID") ??
                         User.FindFirstValue(ClaimTypes.NameIdentifier);
            var nationalId = HttpContext.Session.GetString("nationalID");

            await WriteAuthenticationAuditAsync(
                AuthenticationAuditEventTypes.Logout,
                true,
                nationalId,
                userId);

            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            HttpContext.Session.Clear();

            return RedirectToAction("Index", "Login", new { logout = 2 });
        }

        [HttpGet]
        public IActionResult ChangePasswordRequired()
        {
            var userId = HttpContext.Session.GetString("usersID");
            if (string.IsNullOrWhiteSpace(userId))
                return RedirectToAction(nameof(Index));

            if (HttpContext.Session.GetString("ChangedPassword") != "0")
                return RedirectToAction("Index", "Home");

            return View();
        }

        [HttpPost]
        public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
        {
            try
            {
                var userId = HttpContext.Session.GetString("usersID");
                
                if (string.IsNullOrWhiteSpace(userId))
                {
                    await WriteAuthenticationAuditAsync(
                        AuthenticationAuditEventTypes.PasswordChangeFailed,
                        false,
                        failureReasonCode: "SESSION_EXPIRED",
                        failureMessage: "جلسة العمل منتهية.");
                    return Json(new { success = false, message = "جلسة العمل منتهية. الرجاء تسجيل الدخول مرة أخرى" });
                }
                
                if (string.IsNullOrWhiteSpace(request.OldPassword) || string.IsNullOrWhiteSpace(request.NewPassword))
                {
                    await WriteAuthenticationAuditAsync(
                        AuthenticationAuditEventTypes.PasswordChangeFailed,
                        false,
                        HttpContext.Session.GetString("nationalID"),
                        userId,
                        "MISSING_FIELDS",
                        "لم تكتمل حقول تغيير كلمة المرور المطلوبة.");
                    return Json(new { success = false, message = "الرجاء إدخال كلمة المرور الحالية والجديدة" });
                }
                
                if (request.NewPassword.Length < 12 ||
                    !request.NewPassword.Any(character => character is >= 'A' and <= 'Z') ||
                    !request.NewPassword.Any(character => character is >= 'a' and <= 'z') ||
                    !request.NewPassword.Any(char.IsDigit))
                {
                    await WriteAuthenticationAuditAsync(
                        AuthenticationAuditEventTypes.PasswordChangeFailed,
                        false,
                        HttpContext.Session.GetString("nationalID"),
                        userId,
                        "PASSWORD_POLICY_FAILED",
                        "كلمة المرور الجديدة لا تحقق سياسة كلمات المرور.");
                    return Json(new { success = false, message = "كلمة المرور يجب أن لا تقل عن 12 خانة، وأن تتضمن حرفًا إنجليزيًا كبيرًا وحرفًا إنجليزيًا صغيرًا ورقمًا." });
                }
                
                var spParameters = new object?[] 
                { 
                    userId,
                    request.OldPassword.Trim(),
                    request.NewPassword.Trim()
                };
                
                DataSet ds;
                try
                {
                    ds = await _mastersServies.GetChangePasswordDataSetAsync(spParameters);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error calling GetChangePasswordDataSetAsync");
                    await WriteAuthenticationAuditAsync(
                        AuthenticationAuditEventTypes.PasswordChangeFailed,
                        false,
                        HttpContext.Session.GetString("nationalID"),
                        userId,
                        "DATA_SOURCE_ERROR",
                        "تعذر استدعاء مصدر بيانات تغيير كلمة المرور.");
                    return Json(new { success = false, message = "خطأ في الاتصال بالخادم" });
                }
                
                if (ds?.Tables?.Count > 0 && ds.Tables[0].Rows.Count > 0)
                {
                    var row = ds.Tables[0].Rows[0];
                    
                    var success = false;
                    var message = "فشل تغيير كلمة المرور";
                    
                    if (ds.Tables[0].Columns.Contains("IsSuccessful") && row["IsSuccessful"] != DBNull.Value)
                    {
                        success = Convert.ToBoolean(row["IsSuccessful"]);
                    }
                    
                    if (ds.Tables[0].Columns.Contains("Message_") && row["Message_"] != DBNull.Value)
                    {
                        message = row["Message_"].ToString() ?? message;
                    }
                    
                    if (success)
                    {
                        await WriteAuthenticationAuditAsync(
                            AuthenticationAuditEventTypes.PasswordChanged,
                            true,
                            HttpContext.Session.GetString("nationalID"),
                            userId);
                        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
                        HttpContext.Session.Clear();
                        _logger.LogInformation("Password changed successfully for user {UserId}; session cleared", userId);
                    }
                    else
                    {
                        await WriteAuthenticationAuditAsync(
                            AuthenticationAuditEventTypes.PasswordChangeFailed,
                            false,
                            HttpContext.Session.GetString("nationalID"),
                            userId,
                            "CHANGE_REJECTED",
                            message);
                    }
                    
                    return Json(new
                    {
                        success,
                        message,
                        redirectUrl = success ? Url.Action(nameof(Index), "Login", new { logout = 2 }) : null
                    });
                }
                
                await WriteAuthenticationAuditAsync(
                    AuthenticationAuditEventTypes.PasswordChangeFailed,
                    false,
                    HttpContext.Session.GetString("nationalID"),
                    userId,
                    "NO_RESULT",
                    "لم يتم إرجاع نتيجة من قاعدة البيانات.");
                return Json(new { success = false, message = "لم يتم إرجاع نتيجة من قاعدة البيانات" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error in ChangePassword");
                await WriteAuthenticationAuditAsync(
                    AuthenticationAuditEventTypes.PasswordChangeFailed,
                    false,
                    HttpContext.Session.GetString("nationalID"),
                    HttpContext.Session.GetString("usersID"),
                    "UNEXPECTED_ERROR",
                    "حدث خطأ غير متوقع أثناء تغيير كلمة المرور.");
                return Json(new { success = false, message = "حدث خطأ غير متوقع" });
            }
        }

        // Request model - Keep this at the bottom of the file
        public class ChangePasswordRequest
        {
            public string OldPassword { get; set; } = "";
            public string NewPassword { get; set; } = "";
        }
    }
}
