namespace SmartFoundation.Mvc.Middleware;

public sealed class ForcePasswordChangeMiddleware
{
    private const string ChangePasswordPage = "/Login/ChangePasswordRequired";
    private readonly RequestDelegate _next;

    public ForcePasswordChangeMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var userId = context.Session.GetString("usersID");
        var changedPassword = context.Session.GetString("ChangedPassword");

        if (string.IsNullOrWhiteSpace(userId) || changedPassword != "0")
        {
            await _next(context);
            return;
        }

        var path = context.Request.Path;
        if (IsAllowedPath(path))
        {
            await _next(context);
            return;
        }

        if (path.StartsWithSegments("/crud", StringComparison.OrdinalIgnoreCase) ||
            path.StartsWithSegments("/api", StringComparison.OrdinalIgnoreCase))
        {
            context.Response.StatusCode = StatusCodes.Status423Locked;
            await context.Response.WriteAsJsonAsync(new
            {
                success = false,
                message = "يجب تغيير كلمة المرور قبل استخدام النظام."
            });
            return;
        }

        context.Response.Redirect(ChangePasswordPage);
    }

    private static bool IsAllowedPath(PathString path)
    {
        return path.Equals(ChangePasswordPage, StringComparison.OrdinalIgnoreCase) ||
               path.Equals("/Login/ChangePassword", StringComparison.OrdinalIgnoreCase) ||
               path.Equals("/Login/Logout", StringComparison.OrdinalIgnoreCase) ||
               path.Equals("/Home/Error", StringComparison.OrdinalIgnoreCase);
    }
}
