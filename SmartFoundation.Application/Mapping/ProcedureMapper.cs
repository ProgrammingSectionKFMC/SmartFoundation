using System;
using System.Collections.Generic;

namespace SmartFoundation.Application.Mapping;

/// <summary>
/// Centralized mapping of business operations to stored procedure names.
/// This eliminates hard-coded SP names throughout the application.
/// </summary>
public static class ProcedureMapper
{
    private static readonly Dictionary<string, string> _mappings = new()
    {
        // Employee operations
        { "employee:list", "dbo.sp_SmartFormDemo" },
        { "employee:insert", "dbo.sp_SmartFormDemo" },
        { "employee:update", "dbo.sp_SmartFormDemo" },
        { "employee:delete", "dbo.sp_SmartFormDemo" },
        { "employee:getById", "dbo.sp_SmartFormDemo" },

        { "MastersDataLoad:getData", "dbo.Masters_DataLoad" },
        { "MastersCrud:crud", "dbo.Masters_CRUD" },
        
        // Menu operations
        { "menu:listAll", "dbo.sp_GetAllMenuItems" },
        { "menu:tree", "dbo.GetUserMenuTree" },
        { "menu:sami", "dbo.GetUserMenuTree" },

        // Notification operations
        { "Notification:count", "dbo.Notifications_CRUD" },
        { "Notification:body", "dbo.Notifications_CRUD" },
        { "Notification:markClicked", "dbo.Notifications_CRUD" },
        { "Notification:markRead", "dbo.Notifications_CRUD" },  
        { "Notification:markAllRead", "dbo.Notifications_CRUD" },
        { "Notification:markAllClicked", "dbo.Notifications_CRUD" },
        
        // Dashboard operations
        { "dashboard:summary", "dbo.sp_GetDashboardSummary" },
        
        // Demo operations
        { "demo:getData", "dbo.sp_GetDemoData" },
        { "demo:saveForm", "dbo.sp_SaveDemoForm" },

        // Authentication operations
        { "auth:sessions_", "dbo.GetSessionInfoForMVC" },

        // ✅ AI Chat operations (استخدام Masters_CRUD)
        { "aichat:saveHistory", "dbo.Masters_CRUD" },  // ✅ نرجع لـ Masters_CRUD
        { "aichat:saveFeedback", "dbo.Masters_CRUD" },
        { "aichat:getHistory", "dbo.Masters_DataLoad" },
        { "aichat:getStatistics", "dbo.Masters_DataLoad" }
    };

    /// <summary>
    /// Gets the stored procedure name for a given module and operation.
    /// </summary>
    /// <param name="module">The module name (e.g., "employee", "menu")</param>
    /// <param name="operation">The operation name (e.g., "list", "insert")</param>
    /// <returns>The stored procedure name</returns>
    /// <exception cref="InvalidOperationException">Thrown when mapping not found</exception>
    public static string GetProcedureName(string module, string operation)
    {
        var key = $"{module}:{operation}";

        if (_mappings.TryGetValue(key, out var spName))
            return spName;

        throw new InvalidOperationException(
            $"No stored procedure mapping found for '{key}'. " +
            $"Available mappings: {string.Join(", ", _mappings.Keys)}");
    }

    /// <summary>
    /// Gets all available mappings (for debugging/documentation purposes)
    /// </summary>
    public static IReadOnlyDictionary<string, string> GetAllMappings()
        => _mappings;
}
