using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Application.Services;
using SmartFoundation.Mvc.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using System.Data;
using Microsoft.Extensions.Logging;

namespace SmartFoundation.Mvc.ViewComponents
{
    public class MenuItemsViewComponent : ViewComponent
    {
        private readonly MastersServies _mastersServies;
        private readonly ILogger<MenuItemsViewComponent> _logger;

        public MenuItemsViewComponent(
            MastersServies mastersServies,
            ILogger<MenuItemsViewComponent> logger)
        {
            _mastersServies = mastersServies;
            _logger = logger;
        }

        public async Task<IViewComponentResult> InvokeAsync()
        {
            var usersID = HttpContext.Session.GetString("usersID") ?? "";

            await RefreshDashboardPermissionAsync(usersID);

            var parameters = new Dictionary<string, object?>
            {
                { "UsersID", usersID }
            };

            var jsonResult = await _mastersServies.GetUserMenuTree(parameters); // use public wrapper
            var response = JsonSerializer.Deserialize<JsonElement>(jsonResult);

            var menuItems = response.GetProperty("success").GetBoolean()
                ? response.GetProperty("data").EnumerateArray().Select(MapToMenuItem)
                    .Where(x => !IsHiddenMenuItem(x)).ToList()
                : new List<MenuItem>();

            //var menuTree = BuildMenuHierarchy(menuItems);
            //return View("~/Views/Shared/_SidebarNavbar.cshtml", menuTree);
            var menuTree = BuildMenuHierarchy(menuItems);
            HttpContext.Session.SetString("MENU_TREE", JsonSerializer.Serialize(menuTree));
            return View("~/Views/Shared/_SidebarNavbar.cshtml", menuTree);

        }

        /// <summary>
        /// Ticket menu rows that must stay active in dbo.Menu because TicketList/TicketAdmin
        /// read their permissions and gateway routing through these page names, but which
        /// have no page of their own and must not appear in the sidebar.
        /// </summary>
        private static readonly HashSet<string> HiddenTicketMenuLinks =
            new(StringComparer.OrdinalIgnoreCase) { "TicketDetails", "ServiceCatalogueList" };

        private static bool IsHiddenMenuItem(MenuItem item) =>
            string.Equals(item.ProgramLink?.Trim(), "Ticket", StringComparison.OrdinalIgnoreCase)
            && HiddenTicketMenuLinks.Contains(item.MenuLink ?? "");

        private async Task RefreshDashboardPermissionAsync(string usersID)
        {
            var session = HttpContext.Session;

            long now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();

            long.TryParse(
                session.GetString("CanViewDashboardCheckedUnix"),
                out long lastCheck);

            // Refresh at most once every 30 seconds per session.
            if (lastCheck > 0 &&
                now >= lastCheck &&
                now - lastCheck < 30)
            {
                return;
            }

            bool canViewDashboard = false;

            try
            {
                if (int.TryParse(usersID, out int userId) &&
                    int.TryParse(
                        session.GetString("IdaraID"),
                        out int idaraId))
                {
                    var parameters = new Dictionary<string, object?>
                    {
                        ["pageName_"] = "HousingCommandCenterDashboard",
                        ["idaraID"] = idaraId,
                        ["entrydata"] = userId,
                        ["hostname"] = session.GetString("HostName") ?? "",
                        ["parameter_20"] = "HEADER_PERMISSION_ONLY"
                    };

                    DataSet ds =
                        await _mastersServies.GetDataLoadDataSetAsync(parameters);

                    if (ds.Tables.Count > 0)
                    {
                        DataTable permissions = ds.Tables[0];

                        if (permissions.Columns.Contains("permissionTypeName_E"))
                        {
                            canViewDashboard =
                                permissions.Rows.Cast<DataRow>().Any(row =>
                                    string.Equals(
                                        row["permissionTypeName_E"]?.ToString()?.Trim(),
                                        "VIEWDASHBOARD",
                                        StringComparison.OrdinalIgnoreCase));
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(
                    ex,
                    "Failed to refresh dashboard header permission.");
            }

            // Fail closed if the permission could not be verified.
            session.SetString(
                "CanViewDashboard",
                canViewDashboard ? "1" : "0");

            session.SetString(
                "CanViewDashboardCheckedUnix",
                now.ToString());
        }

        private static List<MenuItem> BuildMenuHierarchy(IEnumerable<MenuItem> items)
        {
            var list = items.OrderBy(x => x.MPSerial ?? int.MaxValue).ToList();
            var byId = list.ToDictionary(x => x.MPID);

            foreach (var item in list)
            {
                var parentId = item.Parents ?? item.ParentMenuID_FK;
                // Skip invalid/self-parent or missing parent
                if (parentId is int pid && pid != item.MPID && byId.TryGetValue(pid, out var parent))
                {
                    // Avoid duplicate adds
                    if (!parent.Children.Any(c => c.MPID == item.MPID))
                        parent.Children.Add(item);
                }
            }

            return list
                .Where(x => (x.Parents ?? x.ParentMenuID_FK) == null || (x.Levels ?? 0) == 1)
                .OrderBy(x => x.MPSerial ?? int.MaxValue)
                .ToList();
        }

        private static MenuItem MapToMenuItem(JsonElement element)
        {
            return new MenuItem
            {
                MPID = GetInt(element, "MPID"),
                MenuName_A = GetString(element, "menuName_A") ?? GetString(element, "MenuName_A"),
                MPSerial = GetInt(element, "MPSerial"),
                MPLink = NormalizeController(GetString(element, "MPLink")),   // ../Employee -> Employee
                ParentMenuID_FK = GetNullableInt(element, "parentMenuID_FK"),
                ProgramID = GetInt(element, "programID"),
                Parents = GetNullableInt(element, "parents"),
                Levels = GetInt(element, "Levels"),
                MPIcon = GetString(element, "MPIcon"),

                MenuNameForView = GetString(element, "MenuNameForView"),
                LevelNo = GetInt(element, "LevelNo"),

                // ✅ مهم جداً: نقرأ menuLink من الـ SP ونحوّلها لاسم أكشن
                //  /BuildingClass.aspx  ->  BuildingClass
                MenuLink = NormalizeAction(GetString(element, "menuLink")),

                PathName_A = GetString(element, "PathName_A"),
                PathName_E = GetString(element, "PathName_E"),

                ProgramName_A = GetString(element, "programName_A"),
                ProgramName_E = GetString(element, "programName_E"),
                ProgramIcon = GetString(element, "programIcon"),
                ProgramLink = GetString(element, "programLink"),
                ProgramSerial = GetInt(element, "programSerial"),

                MenuID = GetInt(element, "menuID"),
                SortKey = GetString(element, "SortKey"),
                HasPermissionForUser = GetInt(element, "HasPermissionForUser"),
                IndentedMenuName = GetString(element, "IndentedMenuName")
            };

            static string NormalizeController(string? controllerRaw)
            {
                if (string.IsNullOrWhiteSpace(controllerRaw)) return "";
                var c = controllerRaw.Replace("\\", "/");
                var last = c.Split('/', StringSplitOptions.RemoveEmptyEntries).LastOrDefault() ?? c;
                return last.Trim(); // ../Employee -> Employee
            }

            static string NormalizeAction(string? actionRaw)
            {
                if (string.IsNullOrWhiteSpace(actionRaw))
                    return "";                // نخليه فاضي إذا ما فيه أكشن

                var a = actionRaw.Trim();

                // لو كانت من نوع /BuildingClass.aspx
                if (a.StartsWith("/", StringComparison.Ordinal))
                    a = a[1..];              // نشيل الـ /

                if (a.EndsWith(".aspx", StringComparison.OrdinalIgnoreCase))
                    a = a[..^5];             // نشيل .aspx

                return a.Trim();             // مثال: "BuildingClass"
            }
        }


        private static string GetString(JsonElement element, string key, string fallback = "")
        {
            if (TryGetProperty(element, key, out var prop))
            {
                if (prop.ValueKind == JsonValueKind.String)
                    return prop.GetString() ?? fallback;
                if (prop.ValueKind != JsonValueKind.Null)
                    return prop.ToString();
            }
            return fallback;
        }

        private static int GetInt(JsonElement element, string key, int fallback = 0)
        {
            if (TryGetProperty(element, key, out var prop))
            {
                if (prop.ValueKind == JsonValueKind.Number)
                    return prop.GetInt32();
                if (prop.ValueKind == JsonValueKind.String && int.TryParse(prop.GetString(), out var parsed))
                    return parsed;
            }
            return fallback;
        }

        private static int? GetNullableInt(JsonElement element, string key)
        {
            if (TryGetProperty(element, key, out var prop))
            {
                if (prop.ValueKind == JsonValueKind.Number)
                    return prop.GetInt32();
                if (prop.ValueKind == JsonValueKind.String && int.TryParse(prop.GetString(), out var parsed))
                    return parsed;
            }
            return null;
        }

        private static bool TryGetProperty(JsonElement element, string key, out JsonElement property)
        {
            // Try exact match first
            if (element.TryGetProperty(key, out property))
                return true;

            // Try case-insensitive match
            foreach (var prop in element.EnumerateObject())
            {
                if (string.Equals(prop.Name, key, StringComparison.OrdinalIgnoreCase))
                {
                    property = prop.Value;
                    return true;
                }
            }

            property = default;
            return false;
        }
    }
}
