namespace SmartFoundation.Application.Services.Models;

public sealed class AuthenticationLoginGuardResult
{
    public bool IsAvailable { get; init; }
    public bool IsAllowed { get; init; }
    public long? UsersId { get; init; }
    public string? BlockReasonCode { get; init; }
    public string? Message { get; init; }
    public DateTime? LockedUntil { get; init; }
    public int RetryAfterSeconds { get; init; }
}

