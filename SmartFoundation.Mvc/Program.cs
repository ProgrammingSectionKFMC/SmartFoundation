using SmartFoundation.Mvc.Services.MonthlyBilling;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using QuestPDF.Drawing;
using QuestPDF.Infrastructure;
using SmartFoundation.Application.Extensions;
using SmartFoundation.Application.Services;
using SmartFoundation.DataEngine.Core.Interfaces;
using SmartFoundation.DataEngine.Core.Services;
using SmartFoundation.DataEngine.Core.Utilities;
using SmartFoundation.Mvc.Controllers;
using SmartFoundation.Mvc.Middleware;
using SmartFoundation.Mvc.Services.Chart;
using SmartFoundation.Mvc.Services.DataLoad;
using SmartFoundation.Mvc.Services.Exports.Pdf;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);
QuestPDF.Settings.License = LicenseType.Community;

var fontPath = Path.Combine(builder.Environment.WebRootPath, "fonts", "Tajawal-Regular.ttf");
using (var fs = File.OpenRead(fontPath))
{
    FontManager.RegisterFont(fs);
}

builder.Services.AddControllersWithViews()
    .AddMvcOptions(options =>
    {
        options.Filters.Add(new Microsoft.AspNetCore.Mvc.AutoValidateAntiforgeryTokenAttribute());
    })
    .AddJsonOptions(o =>
    {
        o.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    });

builder.Services.AddRazorPages();

builder.Services.AddDistributedMemoryCache();
builder.Services.AddMemoryCache();

builder.Services.AddScoped<
    SmartFoundation.Mvc.Services.DashboardMetricsCacheService>();

builder.Services.AddSession(o =>
{
    o.IdleTimeout = TimeSpan.FromMinutes(5);
    o.Cookie.HttpOnly = true;
    o.Cookie.IsEssential = true;
    o.Cookie.SecurePolicy = CookieSecurePolicy.Always;
});

builder.Services
    .AddAuthentication(options =>
    {
        options.DefaultAuthenticateScheme = CookieAuthenticationDefaults.AuthenticationScheme;
        options.DefaultChallengeScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    })
    .AddCookie(options =>
    {
        options.LoginPath = "/Login";
        options.AccessDeniedPath = "/Login/AccessDenied";
        options.Cookie.Name = ".SmartFoundation.Auth";
        options.Cookie.HttpOnly = true;
        options.Cookie.SecurePolicy = builder.Environment.IsDevelopment()
            ? CookieSecurePolicy.SameAsRequest
            : CookieSecurePolicy.Always;
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.ExpireTimeSpan = TimeSpan.FromMinutes(5);
        options.SlidingExpiration = true;
        options.Events.OnRedirectToLogin = context =>
        {
            if (IsProgrammaticRequest(context.Request))
            {
                context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                return Task.CompletedTask;
            }

            context.Response.Redirect(context.RedirectUri);
            return Task.CompletedTask;
        };
        options.Events.OnRedirectToAccessDenied = context =>
        {
            if (IsProgrammaticRequest(context.Request))
            {
                context.Response.StatusCode = StatusCodes.Status403Forbidden;
                return Task.CompletedTask;
            }

            context.Response.Redirect(context.RedirectUri);
            return Task.CompletedTask;
        };

        options.Events.OnCheckSlidingExpiration = context =>
        {
            if (context.Request.Path.StartsWithSegments(
                "/HousingCommandCenterDashboard",
                StringComparison.OrdinalIgnoreCase))
            {
                context.ShouldRenew = false;
            }

            return Task.CompletedTask;
        };
    });


builder.Services.AddAuthentication()
    .AddCookie("DashboardDisplay", options =>
    {
        options.Cookie.Name = ".SmartFoundation.DashboardDisplay";
        options.Cookie.Path = "/HousingCommandCenterDashboard";
        options.Cookie.HttpOnly = true;
        options.Cookie.IsEssential = true;
        options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
        options.Cookie.SameSite = SameSiteMode.Strict;

        // Separate display credential from the three-minute background activity lease.
        options.ExpireTimeSpan = TimeSpan.FromDays(30);
        options.SlidingExpiration = true;

        options.Events.OnCheckSlidingExpiration = context =>
        {
            context.ShouldRenew = false; // Renew only after successful live authorization.
            return Task.CompletedTask;
        };

        options.Events.OnValidatePrincipal = async context =>
        {
            var services = context.HttpContext.RequestServices;

            var store = services.GetRequiredService<
                SmartFoundation.Mvc.Services.DashboardDisplaySessionStore>();

            var token = context.Principal?
                .FindFirst("DashboardDisplayToken")?.Value;

            if (!store.TryGet(token, out var displayContext) ||
                displayContext == null ||
                !displayContext.TryGetValue("usersID", out var userIdText) ||
                !long.TryParse(userIdText, out var userId) ||
                userId <= 0 ||
                context.Principal?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value != userIdText ||
                !displayContext.TryGetValue("IdaraID", out var idaraIdText) ||
                !int.TryParse(idaraIdText, out var idaraId) ||
                idaraId <= 0)
            {
                context.RejectPrincipal();
                return;
            }

            // Check the current database permission on every dashboard request.
            try
            {
                var masters = services.GetRequiredService<
                    SmartFoundation.Application.Services.MastersServies>();

                var parameters = new Dictionary<string, object?>
                {
                    ["pageName_"] = "HousingCommandCenterDashboard",
                    ["idaraID"] = idaraId,
                    ["entrydata"] = userId,
                    ["hostname"] = displayContext.TryGetValue("HostName", out var host)
                        ? host ?? ""
                        : "",
                    ["parameter_20"] = "DASHBOARD_SCOPE_ONLY"
                };

                var ds = await masters.GetDataLoadDataSetAsync(parameters);

                if (ds.Tables.Count == 0 ||
                    !ds.Tables[0].Columns.Contains("permissionTypeName_E"))
                    throw new InvalidOperationException("Dashboard permission data unavailable.");

                bool permitted =
                    ds.Tables.Count > 0 &&
                    ds.Tables[0].Columns.Contains("permissionTypeName_E") &&
                    ds.Tables[0].Rows.Cast<System.Data.DataRow>().Any(row =>
                        string.Equals(
                            row["permissionTypeName_E"]?.ToString()?.Trim(),
                            "VIEWDASHBOARD",
                            StringComparison.OrdinalIgnoreCase));

                if (!permitted)
                {
                    store.Revoke(token);
                    context.HttpContext.Items["DashboardDisplayFailure"] = 403;
                    context.RejectPrincipal();
                    return;
                }

                // Resolve current scope using only signed identity and server-held context.
                if (ds.Tables.Count < 2 ||
                    !ds.Tables[1].Columns.Contains("idaraID") ||
                    !ds.Tables[1].Columns.Contains("TrustedIdaraID"))
                    throw new InvalidOperationException("Dashboard scope unavailable.");

                var scope = ds.Tables[1];
                var target = context.Request.Query["id"].ToString();
                if (string.IsNullOrEmpty(target))
                    target = context.Request.RouteValues["id"]?.ToString();
                bool scopeAllowed = scope.Rows.Count > 0 &&
                    scope.Rows.Cast<System.Data.DataRow>().All(row =>
                        long.TryParse(row["TrustedIdaraID"]?.ToString(), out var trusted) && trusted == idaraId) &&
                    (string.IsNullOrEmpty(target) || scope.Rows.Cast<System.Data.DataRow>().Any(row =>
                        long.TryParse(row["idaraID"]?.ToString(), out var allowed) &&
                        long.TryParse(target, out var requested) && allowed == requested));

                if (!scopeAllowed)
                {
                    context.HttpContext.Items["DashboardDisplayFailure"] = 403;
                    context.ShouldRenew = false;
                    store.Revoke(token);
                    context.RejectPrincipal();
                    return;
                }

                // Recheck revocation after SQL awaits, before issuing any renewed credential.
                if (!store.TryGet(token, out _))
                {
                    context.RejectPrincipal();
                    return;
                }
                context.ShouldRenew = context.Properties.IssuedUtc is DateTimeOffset issued &&
                    DateTimeOffset.UtcNow - issued > TimeSpan.FromDays(1);
            }
            catch (Exception)
            {
                // Fail closed for new data without treating SQL outages as revocation.
                context.HttpContext.Items["DashboardDisplayFailure"] = 503;
                context.ShouldRenew = false;
                context.RejectPrincipal();
            }
        };

        options.Events.OnRedirectToLogin = context =>
        {
            context.Response.StatusCode = context.HttpContext.Items["DashboardDisplayFailure"] is int status
                ? status : StatusCodes.Status401Unauthorized;
            context.Response.Headers["Cache-Control"] = "no-store";
            context.Response.Headers["X-Dashboard-Status"] = context.Response.StatusCode == 503
                ? "temporarily-unavailable" : "reauthentication-required";
            return Task.CompletedTask;
        };

        options.Events.OnRedirectToAccessDenied = context =>
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            return Task.CompletedTask;
        };
    });


builder.Services.AddAuthorization(options =>
{
    options.FallbackPolicy = new AuthorizationPolicyBuilder(
            CookieAuthenticationDefaults.AuthenticationScheme)
        .RequireAuthenticatedUser()
        .Build();
});

builder.Services.AddResponseCompression();
builder.Services.AddAntiforgery(o =>
{
    o.HeaderName = "RequestVerificationToken";
    o.Cookie.HttpOnly = true;
    o.Cookie.SecurePolicy = CookieSecurePolicy.Always;
});
builder.Services.AddHsts(o =>
{
    o.IncludeSubDomains = true;
    o.MaxAge = TimeSpan.FromDays(365);
});

builder.Services.AddSingleton<ConnectionFactory>();

// Independent TV dashboard display sessions
builder.Services.AddSingleton<
    SmartFoundation.Mvc.Services.DashboardDisplaySessionStore>(); 
builder.Services.AddSingleton<MonthlyBillingQueue>();
builder.Services.AddHostedService<MonthlyBillingWorker>();
builder.Services.AddHostedService<SmartFoundation.Mvc.Services.DashboardMetricsRefreshWorker>();
builder.Services.AddScoped<ISmartComponentService, SmartComponentService>();
builder.Services.AddScoped<CrudController>();
builder.Services.AddScoped<RequestScopedDataLoadService>();
builder.Services.AddScoped<IPdfExportService, QuestPdfExportService>();
builder.Services.AddApplicationServices();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<Chart>();

var app = builder.Build();



app.UseResponseCompression();
app.UseHsts();
app.UseHttpsRedirection();
app.UseCookiePolicy(new CookiePolicyOptions
{
    Secure = CookieSecurePolicy.Always
});

app.Use(async (context, next) =>
{
    context.Response.OnStarting(() =>
    {
        var headers = context.Response.Headers;
        var path = context.Request.Path;
        var host = context.Request.Host.Host;
        var isLoginSurface =
            path == "/" ||
            path.Equals("/Login", StringComparison.OrdinalIgnoreCase) ||
            path.Equals("/Login/Index", StringComparison.OrdinalIgnoreCase) ||
            path.Equals("/Login/CheckLogin", StringComparison.OrdinalIgnoreCase);
        var isLocalDevelopmentHost =
            app.Environment.IsDevelopment() &&
            (string.Equals(host, "localhost", StringComparison.OrdinalIgnoreCase) ||
             string.Equals(host, "127.0.0.1", StringComparison.OrdinalIgnoreCase) ||
             string.Equals(host, "::1", StringComparison.OrdinalIgnoreCase));

        var devConnectSrc = isLocalDevelopmentHost
            ? "connect-src 'self' http://localhost:* ws://localhost:* wss://localhost:*;"
            : "connect-src 'self';";

        var contentSecurityPolicy = isLoginSurface
            ? "default-src 'self'; " +
              "base-uri 'self'; " +
              "object-src 'none'; " +
              "frame-ancestors 'self'; " +
              "form-action 'self'; " +
              "img-src 'self' data: blob:; " +
              "font-src 'self' data:; " +
              "style-src 'self'; " +
              "script-src 'self'; " +
              devConnectSrc + " " +
              "frame-src 'self'; " +
              "worker-src 'none';"
            : "default-src 'self'; " +
              "base-uri 'self'; " +
              "object-src 'none'; " +
              "frame-ancestors 'self'; " +
              "form-action 'self'; " +
              "img-src 'self' data: blob: https:; " +
              "font-src 'self' data: https:; " +
              "style-src 'self' 'unsafe-inline' https:; " +
              "script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; " +
              devConnectSrc + " " +
              "frame-src 'self' https:;";

        headers["X-Frame-Options"] = "SAMEORIGIN";
        headers["X-Content-Type-Options"] = "nosniff";
        headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains";
        headers["Content-Security-Policy"] = contentSecurityPolicy;

        headers["Cross-Origin-Opener-Policy"] = "same-origin";
        headers["Cross-Origin-Embedder-Policy"] = "require-corp";
        headers["Cross-Origin-Resource-Policy"] = "same-origin";
        headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";

        return Task.CompletedTask;
    });

    await next();
});

app.UseStaticFiles();
app.UseRouting();
app.UseSession();
app.UseMiddleware<GlobalExceptionMiddleware>();
app.UseAuthentication();
app.UseAuthorization();
app.UseMiddleware<SessionGuardMiddleware>();
app.UseMiddleware<ForcePasswordChangeMiddleware>();
app.MapRazorPages();
app.MapControllers();
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Login}/{action=Index}/{id?}");

app.Run();

static bool IsProgrammaticRequest(HttpRequest request)
{
    return request.Path.StartsWithSegments("/api", StringComparison.OrdinalIgnoreCase) ||
           request.Path.StartsWithSegments("/crud", StringComparison.OrdinalIgnoreCase) ||
           string.Equals(request.Headers["X-Requested-With"], "XMLHttpRequest", StringComparison.OrdinalIgnoreCase) ||
           request.Headers.Accept.Any(value =>
               value?.Contains("application/json", StringComparison.OrdinalIgnoreCase) == true);
}
