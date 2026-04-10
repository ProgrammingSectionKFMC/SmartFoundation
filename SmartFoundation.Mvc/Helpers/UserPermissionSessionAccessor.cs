using Microsoft.AspNetCore.Http;
using SmartFoundation.Mvc.Services.AiAssistant.Security;

namespace SmartFoundation.Mvc.Helpers;

public static class UserPermissionSessionAccessor
{
    private static IHttpContextAccessor? _accessor;

    public static void Configure(IHttpContextAccessor accessor)
    {
        _accessor = accessor;
    }

    public static UserPermissionMap? GetCurrent()
    {
        var ctx = _accessor?.HttpContext;
        if (ctx == null) return null;

        return UserPermissionSessionHelper.Get(ctx);
    }
}