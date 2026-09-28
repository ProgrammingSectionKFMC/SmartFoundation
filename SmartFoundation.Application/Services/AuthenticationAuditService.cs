using Microsoft.Extensions.Logging;
using SmartFoundation.Application.Mapping;
using SmartFoundation.Application.Services.Models;
using SmartFoundation.DataEngine.Core.Interfaces;
using SmartFoundation.DataEngine.Core.Models;

namespace SmartFoundation.Application.Services;

/// <summary>
/// Writes authentication events without allowing an audit failure to interrupt
/// the authentication operation itself.
/// </summary>
public sealed class AuthenticationAuditService : BaseService
{
    public AuthenticationAuditService(
        ISmartComponentService dataEngine,
        ILogger<AuthenticationAuditService> logger)
        : base(dataEngine, logger)
    {
    }

    public async Task<AuthenticationLoginGuardResult> CheckLoginGuardAsync(
        string? loginIdentifier,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var request = new SmartRequest
            {
                Operation = "sp",
                SpName = ProcedureMapper.GetProcedureName("auth", "loginGuard"),
                Params = new Dictionary<string, object?>
                {
                    ["LoginIdentifier"] = Limit(loginIdentifier, 20)
                }
            };

            var response = await _dataEngine.ExecuteAsync(request, cancellationToken);
            var row = response.Data.FirstOrDefault();
            if (!response.Success || row is null)
            {
                _logger.LogWarning("Authentication login guard returned no usable result.");
                return new AuthenticationLoginGuardResult { IsAvailable = false };
            }

            return new AuthenticationLoginGuardResult
            {
                IsAvailable = ReadBoolean(row, "IsAvailable"),
                IsAllowed = ReadBoolean(row, "IsAllowed"),
                UsersId = ReadNullableInt64(row, "UsersID"),
                BlockReasonCode = ReadString(row, "BlockReasonCode"),
                Message = ReadString(row, "Message_"),
                LockedUntil = ReadNullableDateTime(row, "LockedUntil"),
                RetryAfterSeconds = ReadInt32(row, "RetryAfterSeconds")
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Authentication login guard check failed.");
            return new AuthenticationLoginGuardResult { IsAvailable = false };
        }
    }

    /// <summary>
    /// Attempts to persist an authentication audit event.
    /// </summary>
    public async Task<bool> TryWriteAsync(
        AuthenticationAuditEntry entry,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(entry);

        try
        {
            var parameters = new Dictionary<string, object?>
            {
                ["EventType"] = Limit(entry.EventType, 50),
                ["IsSuccessful"] = entry.IsSuccessful
            };

            AddIfPresent(parameters, "UsersID_FK", entry.UsersId);
            AddIfPresent(parameters, "LoginIdentifier", Limit(entry.LoginIdentifier, 20));
            AddIfPresent(parameters, "FailureReasonCode", Limit(entry.FailureReasonCode, 50));
            AddIfPresent(parameters, "FailureMessage", Limit(entry.FailureMessage, 500));
            AddIfPresent(parameters, "IPAddress", Limit(entry.IpAddress, 45));
            AddIfPresent(parameters, "HostName", Limit(entry.HostName, 255));
            AddIfPresent(parameters, "UserAgent", Limit(entry.UserAgent, 1000));
            AddIfPresent(parameters, "SessionID", Limit(entry.SessionId, 200));
            AddIfPresent(parameters, "TraceID", Limit(entry.TraceId, 100));
            AddIfPresent(parameters, "RequestPath", Limit(entry.RequestPath, 500));

            var request = new SmartRequest
            {
                Operation = "sp",
                SpName = ProcedureMapper.GetProcedureName("auth", "audit"),
                Params = parameters
            };

            var response = await _dataEngine.ExecuteAsync(request, cancellationToken);
            if (!response.Success)
            {
                _logger.LogWarning(
                    "Authentication audit write failed for event {EventType}: {Message}",
                    entry.EventType,
                    response.Message ?? response.Error);
            }

            return response.Success;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Authentication audit write failed for event {EventType}", entry.EventType);
            return false;
        }
    }

    private static string? Limit(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
            return null;

        var normalized = value.Trim();
        return normalized.Length <= maxLength ? normalized : normalized[..maxLength];
    }

    private static void AddIfPresent(
        IDictionary<string, object?> parameters,
        string name,
        object? value)
    {
        if (value is not null)
            parameters[name] = value;
    }

    private static object? ReadValue(
        IReadOnlyDictionary<string, object?> row,
        string name)
    {
        var key = row.Keys.FirstOrDefault(key =>
            key.Equals(name, StringComparison.OrdinalIgnoreCase));
        return key is null || row[key] is DBNull ? null : row[key];
    }

    private static bool ReadBoolean(IReadOnlyDictionary<string, object?> row, string name)
    {
        var value = ReadValue(row, name);
        return value is not null && Convert.ToBoolean(value);
    }

    private static long? ReadNullableInt64(IReadOnlyDictionary<string, object?> row, string name)
    {
        var value = ReadValue(row, name);
        return value is null ? null : Convert.ToInt64(value);
    }

    private static int ReadInt32(IReadOnlyDictionary<string, object?> row, string name)
    {
        var value = ReadValue(row, name);
        return value is null ? 0 : Convert.ToInt32(value);
    }

    private static DateTime? ReadNullableDateTime(IReadOnlyDictionary<string, object?> row, string name)
    {
        var value = ReadValue(row, name);
        return value is null ? null : Convert.ToDateTime(value);
    }

    private static string? ReadString(IReadOnlyDictionary<string, object?> row, string name)
        => ReadValue(row, name)?.ToString();
}
