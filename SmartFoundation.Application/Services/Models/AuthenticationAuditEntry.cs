namespace SmartFoundation.Application.Services.Models;

/// <summary>
/// Represents a security audit event related to authentication.
/// Passwords, authentication cookies, hashes, and salts must never be assigned
/// to any property of this model.
/// </summary>
public sealed class AuthenticationAuditEntry
{
    public string EventType { get; init; } = string.Empty;
    public long? UsersId { get; init; }
    public string? LoginIdentifier { get; init; }
    public bool IsSuccessful { get; init; }
    public string? FailureReasonCode { get; init; }
    public string? FailureMessage { get; init; }
    public string? IpAddress { get; init; }
    public string? HostName { get; init; }
    public string? UserAgent { get; init; }
    public string? SessionId { get; init; }
    public string? TraceId { get; init; }
    public string? RequestPath { get; init; }
}

public static class AuthenticationAuditEventTypes
{
    public const string LoginSuccess = "LOGIN_SUCCESS";
    public const string LoginFailed = "LOGIN_FAILED";
    public const string Logout = "LOGOUT";
    public const string SessionExpired = "SESSION_EXPIRED";
    public const string PasswordChanged = "PASSWORD_CHANGED";
    public const string PasswordChangeFailed = "PASSWORD_CHANGE_FAILED";
    public const string AccountReactivated = "ACCOUNT_REACTIVATED";
}

