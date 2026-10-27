using System.Collections.Concurrent;
using System.Data;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using SmartFoundation.Application.Services;

namespace SmartFoundation.Mvc.Services.DataLoad;

/// <summary>
/// Opt-in reuse of Masters_DataLoad results within the owning DI request scope.
/// Callers must supply trusted context and all SQL parameters, including pageName_.
/// Do not reuse a loaded key after a write in the same request.
/// </summary>
public sealed class RequestScopedDataLoadService
{
    private readonly MastersServies mastersServies;
    private readonly IHttpContextAccessor httpContextAccessor;
    private readonly ConcurrentDictionary<string, Lazy<Task<DataSet>>> loads = new();

    /// <summary>Creates a loader owned by the current request scope.</summary>
    public RequestScopedDataLoadService(
        MastersServies mastersServies, IHttpContextAccessor httpContextAccessor)
    {
        this.mastersServies = mastersServies;
        this.httpContextAccessor = httpContextAccessor;
    }

    /// <summary>
    /// Loads an exact SQL parameter set once and returns a private copy per caller.
    /// Missing keys, null, DBNull, CLR types and text values remain distinct.
    /// Unsupported mutable parameter types are rejected rather than ambiguously keyed.
    /// </summary>
    public async Task<DataSet> GetDataLoadDataSetAsync(Dictionary<string, object?> parameters)
    {
        ArgumentNullException.ThrowIfNull(parameters);
        var context = httpContextAccessor.HttpContext
            ?? throw new InvalidOperationException("An active HTTP request is required.");
        var cancellationToken = context.RequestAborted;
        cancellationToken.ThrowIfCancellationRequested();

        var snapshot = new Dictionary<string, object?>(StringComparer.Ordinal);
        foreach (var parameter in parameters)
            snapshot.Add(parameter.Key, Snapshot(parameter.Value));

        // This instance only executes Masters_DataLoad against its injected service.
        // JSON structure avoids separator collisions; values are never logged.
        var key = JsonSerializer.Serialize(snapshot.OrderBy(p => p.Key, StringComparer.Ordinal)
            .Select(p => new
            {
                Name = p.Key,
                Type = p.Value?.GetType().AssemblyQualifiedName,
                Value = p.Value == DBNull.Value ? null : p.Value
            }));

        var load = loads.GetOrAdd(key, _ => new Lazy<Task<DataSet>>(
            async () =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                var data = await mastersServies.GetDataLoadDataSetAsync(snapshot);
                cancellationToken.ThrowIfCancellationRequested();
                return data.Copy();
            }, LazyThreadSafetyMode.ExecutionAndPublication));

        try
        {
            var data = await load.Value;
            cancellationToken.ThrowIfCancellationRequested();
            return data.Copy();
        }
        catch
        {
            // Remove this attempt only: an older waiter must not evict a retry.
            ((ICollection<KeyValuePair<string, Lazy<Task<DataSet>>>>)loads)
                .Remove(new(key, load));
            throw;
        }
    }

    private static object? Snapshot(object? value) => value switch
    {
        null => null,
        DBNull => DBNull.Value,
        byte[] bytes => bytes.ToArray(),
        JsonElement json => json.Clone(),
        string or bool or char or byte or sbyte or short or ushort or int or uint
            or long or ulong or decimal or float or double or Guid or DateTime
            or DateTimeOffset or TimeSpan or DateOnly or TimeOnly => value,
        _ => throw new ArgumentException("Unsupported SQL parameter type.")
    };
}
