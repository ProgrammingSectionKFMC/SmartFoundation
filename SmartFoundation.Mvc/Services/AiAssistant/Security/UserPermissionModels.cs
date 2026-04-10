using System;
using System.Collections.Generic;
using System.Linq;

namespace SmartFoundation.Mvc.Services.AiAssistant.Security;

public sealed class UserPermissionRow
{
    public long UserId { get; init; }

    /// <summary>
    /// Internal page name from database, e.g. Residents, Assign, AllMeterRead.
    /// </summary>
    public string MenuNameEnglish { get; init; } = "";

    /// <summary>
    /// Arabic page name shown to users.
    /// </summary>
    public string MenuNameArabic { get; init; } = "";

    /// <summary>
    /// Internal permission name from database, e.g. ACCESS, INSERT, ASSIGNHOUSE.
    /// </summary>
    public string PermissionNameEnglish { get; init; } = "";

    /// <summary>
    /// Arabic permission label shown to users when needed.
    /// </summary>
    public string PermissionNameArabic { get; init; } = "";
}

public sealed class UserPagePermissionSet
{
    public long UserId { get; init; }

    /// <summary>
    /// Internal page name from database.
    /// </summary>
    public string MenuNameEnglish { get; init; } = "";

    /// <summary>
    /// Arabic page name from database.
    /// </summary>
    public string MenuNameArabic { get; init; } = "";

    /// <summary>
    /// Unique set of internal permission names for this page.
    /// </summary>
    public HashSet<string> PermissionNamesEnglish { get; init; }
        = new(StringComparer.OrdinalIgnoreCase);

    /// <summary>
    /// Unique set of Arabic permission labels for this page.
    /// </summary>
    public HashSet<string> PermissionNamesArabic { get; init; }
        = new(StringComparer.OrdinalIgnoreCase);

    public bool HasPermission(string permissionName)
    {
        if (string.IsNullOrWhiteSpace(permissionName))
            return false;

        return PermissionNamesEnglish.Contains(permissionName.Trim());
    }

    public bool HasAnyPermission(params string[] permissionNames)
    {
        if (permissionNames is null || permissionNames.Length == 0)
            return false;

        foreach (var permissionName in permissionNames)
        {
            if (HasPermission(permissionName))
                return true;
        }

        return false;
    }

    /// <summary>
    /// User has access to page if he has ANY permission on it.
    /// </summary>
    public bool HasAccess()
        => PermissionNamesEnglish.Count > 0;

    /// <summary>
    /// Read access = any permission (same as access in your system).
    /// </summary>
    public bool HasRead()
        => HasAccess();

    public IReadOnlyList<string> GetSortedPermissionNames()
        => PermissionNamesEnglish
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .ToArray();
}

public sealed class UserPermissionMap
{
    public long UserId { get; init; }


    /// <summary>
    /// Key = internal page name, value = page permission set.
    /// </summary>
    public Dictionary<string, UserPagePermissionSet> Pages { get; init; }
        = new(StringComparer.OrdinalIgnoreCase);

    public bool HasPage(string internalPageName)
    {
        if (string.IsNullOrWhiteSpace(internalPageName))
            return false;

        return Pages.ContainsKey(internalPageName.Trim());
    }

    public UserPagePermissionSet? FindPage(string? internalPageName)
    {
        if (string.IsNullOrWhiteSpace(internalPageName))
            return null;

        Pages.TryGetValue(internalPageName.Trim(), out var page);
        return page;
    }

    public bool HasPermission(string? internalPageName, string? permissionName)
    {
        var page = FindPage(internalPageName);
        if (page is null || string.IsNullOrWhiteSpace(permissionName))
            return false;

        return page.HasPermission(permissionName);
    }

    public bool HasAnyPermission(string? internalPageName, params string[] permissionNames)
    {
        var page = FindPage(internalPageName);
        if (page is null)
            return false;

        return page.HasAnyPermission(permissionNames);
    }



    public bool HasAccess(string? internalPageName)
    {
        var page = FindPage(internalPageName);
        return page?.HasAccess() == true;
    }


    public static UserPermissionMap Build(IEnumerable<UserPermissionRow>? rows)
    {

        var rowList = rows?
            .Where(x =>
                x is not null &&
                !string.IsNullOrWhiteSpace(x.MenuNameEnglish) &&
                !string.IsNullOrWhiteSpace(x.PermissionNameEnglish))
            .ToList()
            ?? new List<UserPermissionRow>();

        var userId = rowList.FirstOrDefault()?.UserId ?? 0;

        var result = new UserPermissionMap
        {
            UserId = userId
        };

        foreach (var row in rowList)
        {
            var pageKey = row.MenuNameEnglish.Trim();

            if (!result.Pages.TryGetValue(pageKey, out var pageSet))
            {
                pageSet = new UserPagePermissionSet
                {
                    UserId = row.UserId,
                    MenuNameEnglish = row.MenuNameEnglish?.Trim() ?? "",
                    MenuNameArabic = row.MenuNameArabic?.Trim() ?? ""
                };

                result.Pages[pageKey] = pageSet;
            }

            if (!string.IsNullOrWhiteSpace(row.PermissionNameEnglish))
                pageSet.PermissionNamesEnglish.Add(row.PermissionNameEnglish.Trim());

            if (!string.IsNullOrWhiteSpace(row.PermissionNameArabic))
                pageSet.PermissionNamesArabic.Add(row.PermissionNameArabic.Trim());
        }

        return result;
    }
}