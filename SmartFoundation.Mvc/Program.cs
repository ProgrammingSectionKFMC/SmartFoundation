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
builder.Services.AddSession(o =>
{
    o.IdleTimeout = TimeSpan.FromMinutes(10);
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
        options.ExpireTimeSpan = TimeSpan.FromMinutes(10);
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
builder.Services.AddScoped<ISmartComponentService, SmartComponentService>();
builder.Services.AddScoped<CrudController>();
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
