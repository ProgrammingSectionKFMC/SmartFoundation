using Microsoft.Data.SqlClient;
using System.Data;

namespace SmartFoundation.Mvc.Services.MonthlyBilling;

public sealed class MonthlyBillingWorker(IConfiguration config, ILogger<MonthlyBillingWorker> logger)
    : BackgroundService
{
    private readonly string _cs = config.GetConnectionString("Default")
        ?? throw new InvalidOperationException("Missing ConnectionStrings:Default");

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Both enqueue and processing are feature-gated. Keep disabled until SQL is deployed.
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (config.GetValue<bool>("MonthlyBilling:BackgroundWorkerEnabled"))
                {
                    var item = await ClaimAsync(stoppingToken);
                    if (item is not null) await ProcessAsync(item.Value, stoppingToken);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex) { logger.LogError(ex, "Monthly billing background loop failed"); }
            try { await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken); }
            catch (OperationCanceledException) { break; }
        }
    }

    private async Task<(long Id,long Idara,int Year,int Month,string User,string Host)?> ClaimAsync(CancellationToken ct)
    {
        await using var cn = new SqlConnection(_cs);
        await cn.OpenAsync(ct);
        await using var cmd = new SqlCommand(@"
;WITH q AS
(
 SELECT TOP(1) * FROM Housing.MonthlyBillingQueue WITH (UPDLOCK, READPAST, ROWLOCK)
 WHERE Status=N'PENDING'
    OR (Status=N'RUNNING' AND (HeartbeatAt IS NULL OR HeartbeatAt < DATEADD(MINUTE,-5,SYSUTCDATETIME())))
 ORDER BY QueueID
)
UPDATE q SET Status=N'RUNNING', StartedAt=SYSUTCDATETIME(), HeartbeatAt=SYSUTCDATETIME(),
             FinishedAt=NULL, AttemptCount=AttemptCount+1, LastError=NULL
OUTPUT inserted.QueueID, inserted.IdaraID, inserted.PeriodYear, inserted.PeriodMonth,
       inserted.RequestedBy, inserted.RequestedHost;", cn) { CommandTimeout=20 };
        await using var rd = await cmd.ExecuteReaderAsync(ct);
        if (!await rd.ReadAsync(ct)) return null;
        return (rd.GetInt64(0),rd.GetInt64(1),rd.GetInt32(2),rd.GetInt32(3),
                rd.IsDBNull(4)?"BILLING_WORKER":rd.GetString(4),
                rd.IsDBNull(5)?"BILLING_WORKER":rd.GetString(5));
    }

    private async Task ProcessAsync((long Id,long Idara,int Year,int Month,string User,string Host) item,
                                    CancellationToken stoppingToken)
    {
        // Worker owns only one claim at a time; heartbeat runs independently during long SQL execution.
        using var hbCts = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);
        var heartbeat = HeartbeatLoopAsync(item.Id,hbCts.Token);
        var completed = false;
        string? error = null;
        try
        {
            await using var cn = new SqlConnection(_cs);
            await cn.OpenAsync(stoppingToken);
            await using var cmd = new SqlCommand("Housing.GenerateAllAdministrationsMonthlyBills",cn)
            {
                CommandType=CommandType.StoredProcedure, CommandTimeout=0
            };
            cmd.Parameters.Add("@OnlyIdaraID",SqlDbType.BigInt).Value=item.Idara;
            cmd.Parameters.Add("@Month",SqlDbType.Int).Value=item.Month;
            cmd.Parameters.Add("@Year",SqlDbType.Int).Value=item.Year;
            cmd.Parameters.Add("@EntryData",SqlDbType.NVarChar,20).Value=item.User[..Math.Min(20,item.User.Length)];
            cmd.Parameters.Add("@HostName",SqlDbType.NVarChar,200).Value=item.Host[..Math.Min(200,item.Host.Length)];
            cmd.Parameters.Add("@RetryFailed",SqlDbType.Bit).Value=false;
            cmd.Parameters.Add("@ReturnSummary",SqlDbType.Bit).Value=false;
            await cmd.ExecuteNonQueryAsync(stoppingToken);
            // Procedure reports failures through MonthlyBillingRun without necessarily throwing.
            await using var verify = new SqlCommand(@"
SELECT COUNT_BIG(*) FROM Housing.MonthlyBillingRun
WHERE IdaraID_FK=@Idara AND PeriodYear=@Year AND PeriodMonth=@Month
  AND RunStatus<>N'COMPLETED';",cn);
            verify.Parameters.Add("@Idara",SqlDbType.BigInt).Value=item.Idara;
            verify.Parameters.Add("@Year",SqlDbType.Int).Value=item.Year;
            verify.Parameters.Add("@Month",SqlDbType.Int).Value=item.Month;
            var failures = Convert.ToInt64(await verify.ExecuteScalarAsync(stoppingToken));
            if (failures>0) throw new InvalidOperationException($"MonthlyBillingRun has {failures} incomplete scopes.");
            completed=true;
        }
        catch (OperationCanceledException) when(stoppingToken.IsCancellationRequested)
        {
            error="Application stopping; retry on next startup";
        }
        catch (Exception ex) { error=ex.Message; logger.LogError(ex,"Monthly billing failed for queue {QueueID}",item.Id); }
        finally
        {
            await hbCts.CancelAsync();
            try { await heartbeat; } catch(OperationCanceledException) { }
            try { await FinishAsync(item.Id,completed,error); }
            catch(Exception ex) { logger.LogError(ex,"Unable to save billing queue outcome {QueueID}",item.Id); }
        }
    }

    private async Task HeartbeatLoopAsync(long id,CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            try { await Task.Delay(TimeSpan.FromSeconds(20),ct); }
            catch(OperationCanceledException) { return; }
            try
            {
                await using var cn=new SqlConnection(_cs); await cn.OpenAsync(ct);
                await using var cmd=new SqlCommand(@"UPDATE Housing.MonthlyBillingQueue
 SET HeartbeatAt=SYSUTCDATETIME() WHERE QueueID=@Id AND Status=N'RUNNING';",cn);
                cmd.Parameters.Add("@Id",SqlDbType.BigInt).Value=id;
                await cmd.ExecuteNonQueryAsync(ct);
            }
            catch(OperationCanceledException) when(ct.IsCancellationRequested) { return; }
            catch(Exception ex) { logger.LogWarning(ex,"Billing heartbeat failed {QueueID}",id); }
        }
    }

    private async Task FinishAsync(long id,bool success,string? error)
    {
        await using var cn=new SqlConnection(_cs);await cn.OpenAsync();
        await using var cmd=new SqlCommand(@"UPDATE Housing.MonthlyBillingQueue
SET Status=CASE WHEN @Success=1 THEN N'COMPLETED' ELSE N'FAILED' END,
    FinishedAt=SYSUTCDATETIME(), HeartbeatAt=SYSUTCDATETIME(), LastError=@Error
WHERE QueueID=@Id AND Status=N'RUNNING';",cn);
        cmd.Parameters.Add("@Id",SqlDbType.BigInt).Value=id;
        cmd.Parameters.Add("@Success",SqlDbType.Bit).Value=success;
        cmd.Parameters.Add("@Error",SqlDbType.NVarChar,2000).Value=error is null?DBNull.Value:error[..Math.Min(2000,error.Length)];
        await cmd.ExecuteNonQueryAsync();
    }
}
