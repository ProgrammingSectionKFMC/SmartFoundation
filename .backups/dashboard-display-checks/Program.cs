using SmartFoundation.Mvc.Services;
using System.Reflection;
using System.Collections;
var store = new DashboardDisplaySessionStore();
var context = new Dictionary<string, string?> { ["usersID"] = "7", ["IdaraID"] = "3" };
void Check(bool condition, string name) { if (!condition) throw new Exception(name); Console.WriteLine("PASS " + name); }
object Session(string token) {
    var sessions = (IEnumerable)typeof(DashboardDisplaySessionStore).GetField("_sessions", BindingFlags.NonPublic | BindingFlags.Instance)!.GetValue(store)!;
    return sessions.Cast<object>().Select(x => (Key: x.GetType().GetProperty("Key")!.GetValue(x), Value: x.GetType().GetProperty("Value")!.GetValue(x))).Single(x => (string)x.Key! == token).Value!;
}
void Expire(string token, string field) { var value = Session(token); value.GetType().GetField(field)!.SetValue(value, DateTime.UtcNow.AddDays(-2).Ticks); }
var token = store.Create(context);
context["usersID"] = "99";
Check(store.TryGet(token, out var saved) && saved!["usersID"] == "7", "trusted context snapshot");
Expire(token, "ExpiresUtcTicks");
Check(store.GetActiveMetricsContexts().Count == 0, "sleep suspends background work");
Check(store.TryGet(token, out _) && store.Renew(token), "two-day inactive lease can resume with retained grant");
Check(store.GetActiveMetricsContexts().Count == 1, "resumed lease activates background work");
store.Revoke(token);
Check(!store.TryGet(token, out _) && !store.Renew(token), "explicit revocation cannot revive");
context["usersID"] = "7";
var first = store.Create(context); var second = store.Create(context);
Check(store.RevokeAllForUser(7) == 2 && !store.Renew(first) && !store.Renew(second), "logout revokes all credentials");
var expired = store.Create(context); Expire(expired, "GrantExpiresUtcTicks");
Check(!store.TryGet(expired, out _) && !store.Renew(expired), "expired grant cannot revive");
Check(!new DashboardDisplaySessionStore().TryGet(store.Create(context), out _), "MVC restart fails closed");
