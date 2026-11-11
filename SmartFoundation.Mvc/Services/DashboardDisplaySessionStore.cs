
using System.Collections.Concurrent;
using System.Collections.ObjectModel;
using System.Security.Cryptography;

namespace SmartFoundation.Mvc.Services;

public sealed class DashboardDisplaySessionStore
{
    private static readonly TimeSpan HeartbeatTimeout =
        TimeSpan.FromMinutes(3);

    private sealed class DisplaySession
    {
        public required IReadOnlyDictionary<string, string?> Context { get; init; }
        public long ExpiresUtcTicks;
        public long GrantExpiresUtcTicks;
    }

    private readonly ConcurrentDictionary<string, DisplaySession> _sessions =
        new(StringComparer.Ordinal);

    public string Create(IReadOnlyDictionary<string, string?> context)
    {
        if (!context.TryGetValue("usersID", out var userId) ||
            !long.TryParse(userId, out var parsedUserId) ||
            parsedUserId <= 0 ||
            !context.TryGetValue("IdaraID", out var idaraId) ||
            !long.TryParse(idaraId, out var parsedIdaraId) ||
            parsedIdaraId <= 0)
        {
            throw new InvalidOperationException(
                "Dashboard display context is incomplete.");
        }

        var snapshot = new ReadOnlyDictionary<string, string?>(
            new Dictionary<string, string?>(context, StringComparer.Ordinal));

        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));

        _sessions[token] = new DisplaySession
        {
            Context = snapshot,
            GrantExpiresUtcTicks = DateTime.UtcNow.AddDays(30).Ticks,
            ExpiresUtcTicks = DateTime.UtcNow.Add(HeartbeatTimeout).Ticks
        };

        return token;
    }

    /// <summary>
    /// Reads an independent display credential, including after its activity lease lapses.
    /// Callers must validate the signed identity and current database authorization before use.
    /// </summary>
    public bool TryGet(
        string? token,
        out IReadOnlyDictionary<string, string?>? context)
    {
        context = null;

        if (string.IsNullOrWhiteSpace(token) ||
            !_sessions.TryGetValue(token, out var session))
        {
            return false;
        }

        if (DateTime.UtcNow.Ticks >=
            Interlocked.Read(ref session.GrantExpiresUtcTicks))
        {
            _sessions.TryRemove(token, out _);
            return false;
        }

        context = session.Context;
        return true;
    }

    /// <summary>Renews only an existing credential after successful live authorization.</summary>
    public bool Renew(string? token)
    {
        if (!TryGet(token, out _) || token == null)
            return false;

        if (!_sessions.TryGetValue(token, out var session))
            return false;

        Interlocked.Exchange(ref session.GrantExpiresUtcTicks, DateTime.UtcNow.AddDays(30).Ticks);
        Interlocked.Exchange(
            ref session.ExpiresUtcTicks,
            DateTime.UtcNow.Add(HeartbeatTimeout).Ticks);

        return true;
    }

    public int RevokeAllForUser(long userId)
    {
        if (userId <= 0)
            return 0;

        int revoked = 0;

        foreach (var item in _sessions)
        {
            if (!item.Value.Context.TryGetValue("usersID", out var storedId) ||
                !long.TryParse(storedId, out var parsedId) ||
                parsedId != userId)
            {
                continue;
            }

            if (_sessions.TryRemove(item.Key, out _))
                revoked++;
        }

        return revoked;
    }

    public void Revoke(string? token)
    {
        if (!string.IsNullOrWhiteSpace(token))
            _sessions.TryRemove(token, out _);
    }



    public IReadOnlyList<DashboardMetricsContext> GetActiveMetricsContexts()
    {
        var nowTicks = DateTime.UtcNow.Ticks;

        var result = new Dictionary<string, DashboardMetricsContext>(
            StringComparer.Ordinal);

        foreach (var item in _sessions)
        {
            var session = item.Value;

            if (nowTicks >= Interlocked.Read(
                    ref session.ExpiresUtcTicks))
            {
                // The short activity lease only controls background work.
                // Keep the independent credential across sleep; never recreate revoked tokens.
                if (nowTicks >= Interlocked.Read(ref session.GrantExpiresUtcTicks))
                    _sessions.TryRemove(new KeyValuePair<string, DisplaySession>(item.Key, session));

                continue;
            }

            var context = session.Context;

            if (!context.TryGetValue("usersID", out var userId) ||
                !long.TryParse(userId, out var parsedUserId) ||
                parsedUserId <= 0 ||
                !context.TryGetValue("IdaraID", out var idaraId) ||
                !long.TryParse(idaraId, out var parsedIdaraId) ||
                parsedIdaraId <= 0)
            {
                continue;
            }

            context.TryGetValue("HostName", out var hostName);

            var metricsContext = new DashboardMetricsContext(
                "HousingCommandCenterDashboard",
                parsedIdaraId.ToString(
                    System.Globalization.CultureInfo.InvariantCulture),
                parsedUserId.ToString(
                    System.Globalization.CultureInfo.InvariantCulture),
                hostName ?? string.Empty
            );

            // Deduplicate identical SQL request contexts.
            string key = string.Join(
                ":",
                metricsContext.PageName,
                metricsContext.IdaraId,
                metricsContext.UserId,
                metricsContext.HostName);

            result.TryAdd(key, metricsContext);
        }

        return result.Values.ToArray();
    }

}
