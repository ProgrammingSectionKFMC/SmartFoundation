CREATE PROCEDURE [Housing].[GetOrCreateMonthlyBillPeriod]
(
      @IdaraID BIGINT
    , @MeterServiceTypeID INT
    , @Year INT
    , @Month INT
    , @EntryData NVARCHAR(20)
    , @HostName NVARCHAR(200)
    , @BillPeriodID INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @IdaraID IS NULL OR @MeterServiceTypeID IS NULL
       OR @Year NOT BETWEEN 1900 AND 9999 OR @Month NOT BETWEEN 1 AND 12
        THROW 50001, N'بيانات فترة الفوترة الشهرية غير صحيحة', 1;

    DECLARE @PeriodStartDate DATE = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @PeriodEndDate DATE = EOMONTH(@PeriodStartDate);
    DECLARE @BillPeriodTypeID INT, @ServiceName NVARCHAR(100);
    DECLARE @TransactionCount INT = @@TRANCOUNT;
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(255) = CONCAT
    (
        N'BILL_PERIOD:', @IdaraID, N':', @MeterServiceTypeID, N':', @Year, N':', @Month
    );

    BEGIN TRY
        IF @TransactionCount = 0 BEGIN TRANSACTION;

        EXEC @LockResult = sys.sp_getapplock
              @Resource = @LockResource
            , @LockMode = N'Exclusive'
            , @LockOwner = N'Transaction'
            , @LockTimeout = 10000;

        IF @LockResult < 0
            THROW 50001, N'تعذر حجز عملية إنشاء فترة الفوترة الشهرية، يرجى إعادة المحاولة', 1;

        SELECT TOP (1)
            @BillPeriodID = period.billPeriodID
        FROM Housing.BillPeriod period WITH (UPDLOCK, HOLDLOCK)
        JOIN Housing.BillPeriodType periodType
          ON periodType.billPeriodTypeID = period.billPeriodTypeID_FK
        WHERE period.IdaraId_FK = @IdaraID
          AND periodType.meterServiceTypeID_FK = @MeterServiceTypeID
          AND CONVERT(date, period.billPeriodStartDate) = @PeriodStartDate
          AND CONVERT(date, period.billPeriodEndDate) = @PeriodEndDate
        ORDER BY period.billPeriodID DESC;

        IF @BillPeriodID IS NOT NULL
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM Housing.BillPeriod
                WHERE billPeriodID = @BillPeriodID
                  AND ISNULL(billPeriodActive, 0) = 0
            )
                THROW 50001, N'فترة الفوترة المطلوبة مغلقة ولا يمكن إضافة فواتير جديدة إليها', 1;

            IF @TransactionCount = 0 COMMIT TRANSACTION;
            RETURN;
        END;

        SELECT TOP (1)
              @BillPeriodTypeID = periodType.billPeriodTypeID
            , @ServiceName = serviceType.meterServiceTypeName_A
        FROM Housing.BillPeriodType periodType
        JOIN Housing.MeterServiceType serviceType
          ON serviceType.meterServiceTypeID = periodType.meterServiceTypeID_FK
        WHERE periodType.meterServiceTypeID_FK = @MeterServiceTypeID
          AND periodType.billPeriodTypeActive = 1
          AND serviceType.meterServiceTypeActive = 1
        ORDER BY periodType.billPeriodTypeID;

        IF @BillPeriodTypeID IS NULL
            THROW 50001, N'لا يوجد نوع فترة فعال للخدمة المحددة', 1;

        INSERT Housing.BillPeriod
        (
              billPeriodTypeID_FK, billPeriodName_A, billPeriodName_E
            , billPeriodStartDate, billPeriodEndDate, billPeriodActive, ClosedBy
            , IdaraId_FK, entryDate, entryData, hostName
        )
        VALUES
        (
              @BillPeriodTypeID
            , CONCAT(N'فترة ', @ServiceName, N' ', FORMAT(@PeriodStartDate, N'MM/yyyy'))
            , CONCAT(N'Billing period ', FORMAT(@PeriodStartDate, N'MM/yyyy'))
            , @PeriodStartDate, @PeriodEndDate, 1, NULL
            , @IdaraID, GETDATE(), @EntryData, @HostName
        );

        SET @BillPeriodID = CONVERT(INT, SCOPE_IDENTITY());

        INSERT dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
        VALUES
        (
              N'[Housing].[BillPeriod]'
            , N'AUTO_CREATE_MONTHLY_BILL_PERIOD'
            , @BillPeriodID
            , @EntryData
            , CONCAT
              (
                  N'{"IdaraID":"', @IdaraID,
                  N'","MeterServiceTypeID":"', @MeterServiceTypeID,
                  N'","PeriodStartDate":"', CONVERT(nvarchar(10), @PeriodStartDate, 23),
                  N'","PeriodEndDate":"', CONVERT(nvarchar(10), @PeriodEndDate, 23), N'"}'
              )
        );

        IF @TransactionCount = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @TransactionCount = 0 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
