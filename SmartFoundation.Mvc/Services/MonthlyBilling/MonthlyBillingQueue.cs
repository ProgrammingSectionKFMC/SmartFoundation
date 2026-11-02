using Microsoft.Data.SqlClient;
using System.Data;

namespace SmartFoundation.Mvc.Services.MonthlyBilling;

// A durable, database-backed request queue. No work is started on the request thread.
public sealed class MonthlyBillingQueue(IConfiguration config)
{
    private readonly string _cs = config.GetConnectionString("Default")
        ?? throw new InvalidOperationException("Missing ConnectionStrings:Default");

    public async Task EnqueuePreviousMonthAsync(long idaraId, string? userId, string? hostName,
        CancellationToken cancellationToken)
    {
        var previousMonth = DateTime.Today.AddMonths(-1);
        await using var connection = new SqlConnection(_cs);
        await connection.OpenAsync(cancellationToken);
        await using var command = new SqlCommand(@"
SET XACT_ABORT ON;
BEGIN TRAN;
IF NOT EXISTS (SELECT 1 FROM Housing.MonthlyBillingQueue WITH (UPDLOCK,HOLDLOCK)
               WHERE IdaraID=@Idara AND PeriodYear=@Year AND PeriodMonth=@Month)
BEGIN
    INSERT Housing.MonthlyBillingQueue(IdaraID,PeriodYear,PeriodMonth,RequestedBy,RequestedHost)
    VALUES(@Idara,@Year,@Month,@User,@Host);
END;
COMMIT TRAN;", connection) { CommandTimeout = 15 };
        command.Parameters.Add("@Idara", SqlDbType.BigInt).Value = idaraId;
        command.Parameters.Add("@Year", SqlDbType.Int).Value = previousMonth.Year;
        command.Parameters.Add("@Month", SqlDbType.Int).Value = previousMonth.Month;
        command.Parameters.Add("@User", SqlDbType.NVarChar, 20).Value = (object?)userId is null ? DBNull.Value : userId[..Math.Min(userId.Length,20)];
        command.Parameters.Add("@Host", SqlDbType.NVarChar, 200).Value = (object?)hostName is null ? DBNull.Value : hostName[..Math.Min(hostName.Length,200)];
        await command.ExecuteNonQueryAsync(cancellationToken);
    }
}
