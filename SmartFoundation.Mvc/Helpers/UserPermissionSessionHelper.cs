using System.Text.Json;
using SmartFoundation.Mvc.Services.AiAssistant.Security;

namespace SmartFoundation.Mvc.Helpers;

public static class UserPermissionSessionHelper
{
    private const string SessionKey = "Ai.UserPermissionMap";

    /// <summary>
    /// Save permissions from DataTable (dt2) into Session.
    /// </summary>
    public static void SaveFromDataTable(HttpContext httpContext, System.Data.DataTable? dt)
    {
        if (httpContext == null)
            return;

        if (dt == null || dt.Rows.Count == 0)
        {
            httpContext.Session.Remove(SessionKey);
            return;
        }

        var rows = new List<UserPermissionRow>();

        foreach (System.Data.DataRow row in dt.Rows)
        {
            rows.Add(new UserPermissionRow
            {
                UserId = TryToLong(row["userID"]),
                MenuNameEnglish = row["menuName_E"]?.ToString()?.Trim() ?? "",
                MenuNameArabic = row["menuName_A"]?.ToString()?.Trim() ?? "",
                PermissionNameEnglish = row["permissionTypeName_E"]?.ToString()?.Trim() ?? "",
                PermissionNameArabic = row["permissionTypeName_A"]?.ToString()?.Trim() ?? ""
            });
        }

        var map = UserPermissionMap.Build(rows);

        var json = JsonSerializer.Serialize(map);
        httpContext.Session.SetString(SessionKey, json);
    }

    /// <summary>
    /// Get permissions map from Session.
    /// </summary>
    public static UserPermissionMap? Get(HttpContext httpContext)
    {
        if (httpContext == null)
            return null;

        var json = httpContext.Session.GetString(SessionKey);

        if (string.IsNullOrWhiteSpace(json))
            return null;

        return JsonSerializer.Deserialize<UserPermissionMap>(json);
    }

    /// <summary>
    /// Check if user has access to page (any permission).
    /// </summary>
    public static bool HasPageAccess(HttpContext httpContext, string internalPageName)
    {
        var map = Get(httpContext);
        return map?.HasAccess(internalPageName) == true;
    }

    /// <summary>
    /// Check specific permission on page.
    /// </summary>
    public static bool HasPermission(HttpContext httpContext, string internalPageName, string permissionName)
    {
        var map = Get(httpContext);
        return map?.HasPermission(internalPageName, permissionName) == true;
    }

    /// <summary>
    /// Remove permissions from session (logout).
    /// </summary>
    public static void Clear(HttpContext httpContext)
    {
        if (httpContext == null)
            return;

        httpContext.Session.Remove(SessionKey);
    }

    private static long TryToLong(object? value)
    {
        if (value == null || value == DBNull.Value)
            return 0;

        return long.TryParse(value.ToString(), out var result) ? result : 0;
    }
}