CREATE PROCEDURE [Housing].[MonthlyBillingMonitorSP]
      @Action NVARCHAR(100), @MonthlyBillingRunID BIGINT, @IdaraID BIGINT
    , @EntryData NVARCHAR(20), @HostName NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @Action<>N'RETRYMONTHLYBILLING' THROW 50001,N'العملية غير مسجلة',1;
    DECLARE @Year INT,@Month INT,@RunIdaraID BIGINT;
    SELECT @Year=PeriodYear,@Month=PeriodMonth,@RunIdaraID=IdaraID_FK
    FROM Housing.MonthlyBillingRun WHERE MonthlyBillingRunID=@MonthlyBillingRunID;
    IF @Year IS NULL THROW 50001,N'نطاق الرصد غير موجود',1;
    IF @RunIdaraID<>@IdaraID THROW 50001,N'لا يمكن إعادة تشغيل نطاق تابع لإدارة أخرى',1;
    UPDATE Housing.MonthlyBillingRun SET RunStatus=N'PENDING',FinishedAt=NULL,LastError=NULL,entryData=@EntryData,hostName=@HostName
    WHERE MonthlyBillingRunID=@MonthlyBillingRunID;
    EXEC Housing.GenerateAllAdministrationsMonthlyBills
         @Month=@Month,@Year=@Year,@EntryData=@EntryData,@HostName=@HostName,@RetryFailed=1,
         @OnlyRunID=@MonthlyBillingRunID,@ReturnSummary=0;
END;

GO

