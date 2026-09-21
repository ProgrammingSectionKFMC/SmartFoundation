using Microsoft.Data.SqlClient;
using System.Data;

namespace SmartFoundation.Mvc.Middleware;

public sealed class GlobalExceptionMiddleware
{
    private static readonly HashSet<int> ConnectionErrorNumbers =
    [
        -2, 2, 20, 53, 64, 233, 258, 4060, 18456,
        10053, 10054, 10060, 11001
    ];

    private readonly RequestDelegate _next;
    private readonly IConfiguration _configuration;
    private readonly ILogger<GlobalExceptionMiddleware> _logger;

    public GlobalExceptionMiddleware(
        RequestDelegate next,
        IConfiguration configuration,
        ILogger<GlobalExceptionMiddleware> logger)
    {
        _next = next;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception exception)
        {
            if (context.Response.HasStarted)
                throw;

            int? errorLogId = null;
            var dataSourceUnavailable = IsDatabaseConnectionFailure(exception);

            if (!dataSourceUnavailable)
            {
                try
                {
                    errorLogId = await SaveErrorAsync(context, exception);
                }
                catch (Exception loggingException)
                {
                    dataSourceUnavailable = IsDatabaseConnectionFailure(loggingException);
                    _logger.LogError(loggingException, "Failed to save exception in dbo.ErrorLog");
                }
            }

            _logger.LogError(
                exception,
                "Unhandled request exception. ErrorLogID={ErrorLogID}, Path={Path}",
                errorLogId,
                context.Request.Path.Value);

            context.Response.Clear();
            context.Response.Redirect(dataSourceUnavailable
                ? "/Home/Error?dataSourceUnavailable=true"
                : errorLogId.HasValue
                    ? $"/Home/Error?errorId={errorLogId.Value}"
                    : "/Home/Error");
        }
    }

    private async Task<int> SaveErrorAsync(HttpContext context, Exception exception)
    {
        var connectionString = _configuration.GetConnectionString("Default");
        if (string.IsNullOrWhiteSpace(connectionString))
            throw new InvalidOperationException("Default connection string is not configured.");

        var rootException = GetRootException(exception);
        var sqlException = rootException as SqlException;
        var userId = context.Session.GetString("usersID");
        var requestPath = $"{context.Request.Method} {context.Request.Path}";
        var sourceName = string.IsNullOrWhiteSpace(rootException.Source)
            ? requestPath
            : $"{rootException.Source} | {requestPath}";

        await using var connection = new SqlConnection(connectionString);
        await using var command = new SqlCommand("dbo.ErrorLog_Insert", connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 15
        };

        command.Parameters.Add("@ErrorMessage", SqlDbType.NVarChar, 4000).Value = Limit(rootException.Message, 4000);
        command.Parameters.Add("@ErrorSeverity", SqlDbType.NVarChar, 4000).Value =
            sqlException is null ? DBNull.Value : sqlException.Class.ToString();
        command.Parameters.Add("@ErrorState", SqlDbType.NVarChar, 4000).Value =
            sqlException is null ? DBNull.Value : sqlException.State.ToString();
        command.Parameters.Add("@SourceName", SqlDbType.NVarChar, 4000).Value = Limit(sourceName, 4000);
        command.Parameters.Add("@EntryData", SqlDbType.NVarChar, 20).Value = DbValue(userId);
        command.Parameters.Add("@HostName", SqlDbType.NVarChar, 200).Value = Limit(Environment.MachineName, 200);
        command.Parameters.Add("@StackTrace", SqlDbType.NVarChar, -1).Value = DbValue(exception.ToString());
        command.Parameters.Add("@InnerException", SqlDbType.NVarChar, -1).Value = DbValue(exception.InnerException?.ToString());
        command.Parameters.Add("@RequestPath", SqlDbType.NVarChar, 1000).Value = Limit(context.Request.Path.Value, 1000);
        command.Parameters.Add("@HttpMethod", SqlDbType.NVarChar, 20).Value = Limit(context.Request.Method, 20);

        await connection.OpenAsync(CancellationToken.None);
        var result = await command.ExecuteScalarAsync(CancellationToken.None);
        return Convert.ToInt32(result);
    }

    private static bool IsDatabaseConnectionFailure(Exception exception)
    {
        for (Exception? current = exception; current is not null; current = current.InnerException)
        {
            if (current is SqlException sqlException &&
                sqlException.Errors.Cast<SqlError>().Any(error => ConnectionErrorNumbers.Contains(error.Number)))
                return true;
        }

        return false;
    }

    private static Exception GetRootException(Exception exception)
    {
        var current = exception;
        while (current.InnerException is not null)
            current = current.InnerException;

        return current;
    }

    private static object DbValue(string? value) =>
        string.IsNullOrWhiteSpace(value) ? DBNull.Value : value;

    private static string Limit(string? value, int maximumLength)
    {
        var text = value ?? string.Empty;
        return text.Length <= maximumLength ? text : text[..maximumLength];
    }
}
