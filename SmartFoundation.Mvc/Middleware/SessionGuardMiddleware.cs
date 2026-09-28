using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using SmartFoundation.Application.Services;
using SmartFoundation.Application.Services.Models;
using System.Security.Claims;

namespace SmartFoundation.Mvc.Middleware
{
    public sealed class SessionGuardMiddleware
    {
        private static readonly PathString[] StaticPrefixes = new[]
        {
            new PathString("/css"),
            new PathString("/js"),
            new PathString("/lib"),
            new PathString("/images"),
            new PathString("/favicon.ico")
        };

        private static readonly string[] RequiredKeys = new[]
        {
            "usersID", "fullName", "IdaraID", "nationalID"
        };

        private readonly RequestDelegate _next;

        public SessionGuardMiddleware(RequestDelegate next) => _next = next;

        public async Task InvokeAsync(
            HttpContext context,
            AuthenticationAuditService authenticationAuditService)
        {
            var path = context.Request.Path;

            // Skip static files quickly
            foreach (var p in StaticPrefixes)
            {
                if (path.StartsWithSegments(p, StringComparison.OrdinalIgnoreCase))
                {
                    await _next(context);
                    return;
                }
            }

            // Respect endpoints marked with [AllowAnonymous]
            var endpoint = context.GetEndpoint();
            if (endpoint?.Metadata.GetMetadata<IAllowAnonymous>() is not null)
            {
                await _next(context);
                return;
            }

            // Cookie authentication is the primary mechanism. This middleware only
            // validates that its server-side application context is still consistent.
            if (context.User.Identity?.IsAuthenticated != true)
            {
                await _next(context);
                return;
            }

            // Require session keys
            bool missing = false;
            foreach (var key in RequiredKeys)
            {
                var value = context.Session.GetString(key);
                if (string.IsNullOrWhiteSpace(value))
                    missing = true;
            }

            var claimUserId = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
            var sessionUserId = context.Session.GetString("usersID");
            var identityMismatch = string.IsNullOrWhiteSpace(claimUserId) ||
                                   !string.Equals(claimUserId, sessionUserId, StringComparison.Ordinal);

            if (missing || identityMismatch)
            {
                var nationalId = context.Session.GetString("nationalID");
                var hostName = context.Session.GetString("HostName");
                long? parsedUsersId = long.TryParse(claimUserId ?? sessionUserId, out var id) ? id : null;

                await authenticationAuditService.TryWriteAsync(
                    new AuthenticationAuditEntry
                    {
                        EventType = AuthenticationAuditEventTypes.SessionExpired,
                        UsersId = parsedUsersId,
                        LoginIdentifier = nationalId,
                        IsSuccessful = true,
                        FailureReasonCode = identityMismatch
                            ? "IDENTITY_MISMATCH"
                            : "MISSING_SESSION_CONTEXT",
                        IpAddress = context.Connection.RemoteIpAddress?.ToString(),
                        HostName = hostName,
                        UserAgent = context.Request.Headers.UserAgent.ToString(),
                        SessionId = context.Session.Id,
                        TraceId = context.TraceIdentifier,
                        RequestPath = context.Request.Path.Value
                    });

                await context.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
                context.Session.Clear();

                var isAjax = string.Equals(context.Request.Headers["X-Requested-With"], "XMLHttpRequest", StringComparison.OrdinalIgnoreCase);
                var acceptsJson = context.Request.Headers["Accept"].ToString().Contains("application/json", StringComparison.OrdinalIgnoreCase);
                var isApiOrCrud = path.StartsWithSegments("/api", StringComparison.OrdinalIgnoreCase) ||
                                  path.StartsWithSegments("/crud", StringComparison.OrdinalIgnoreCase);

                if (isApiOrCrud || isAjax || acceptsJson)
                {
                    context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                    return;
                }

                context.Response.Redirect("/Login/Index?logout=1");
                return;
            }

            await _next(context);
        }
    }
}
