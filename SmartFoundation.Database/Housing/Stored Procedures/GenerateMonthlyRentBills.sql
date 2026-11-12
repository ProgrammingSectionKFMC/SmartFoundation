CREATE PROCEDURE [Housing].[GenerateMonthlyRentBills]
    @Month int,
    @Year int,
    @entrydata nvarchar(20),
    @hostname nvarchar(200),
    @idaraID int,
    @ReturnResult bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @InsertedCount int = 0;
    DECLARE @ExpectedCount int = 0;
    DECLARE @BillingMonthStart date = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @BillingMonthEnd date = EOMONTH(DATEFROMPARTS(@Year, @Month, 1));

    DECLARE @Bills TABLE
    (
        residentInfoID bigint,
        buildingDetailsID bigint,
        buildingRentTypeID_FK bigint,
        rentBillsAmount decimal(18,2),
        rentBillsFromDate date,
        rentBillsToDate date,
        rentBillsActive bit,
        idaraID_FK bigint,
        entrydata nvarchar(20),
        hostname nvarchar(200)
    );

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO @Bills
        EXEC [Housing].[BuildingRentForOneMonth]
             @Month = @Month,
             @Year = @Year,
             @entrydata = @entrydata,
             @hostname = @hostname,
             @idaraID = @idaraID;

        SELECT @ExpectedCount = COUNT(*)
        FROM @Bills;

        INSERT INTO Housing.Bills
        (
              BillsUID
            , BillChargeTypeID_FK
            , BillTypeID_FK
            , PeriodMonth
            , PeriodYear
            , buildingDetailsID
            , residentInfoID_FK
            , PRICE
            , PRICETAX
            , TotalPrice
            , buildingRentTypeID_FK
            , BillsFromDate
            , BillsToDate
            , BillActive
            , idaraID_FK
            , entryDate
            , entryData
            , hostName
        )
        SELECT
              NEWID()
            , 1
            , 2
            , @Month
            , @Year
            , b.buildingDetailsID
            , b.residentInfoID
            , b.rentBillsAmount
            , 0
            , b.rentBillsAmount
            , b.buildingRentTypeID_FK
            , b.rentBillsFromDate
            , b.rentBillsToDate
            , 1
            , @idaraID
            , GETDATE()
            , @entrydata
            , @hostname
        FROM @Bills b
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM Housing.Bills x WITH (UPDLOCK, HOLDLOCK)
            WHERE x.BillChargeTypeID_FK = 1
              AND x.idaraID_FK = @idaraID
              AND x.residentInfoID_FK = b.residentInfoID
              AND x.buildingDetailsID = b.buildingDetailsID
              AND x.BillActive = 1
              AND CAST(x.BillsFromDate AS date) <= b.rentBillsToDate
              AND CAST(x.BillsToDate AS date) >= b.rentBillsFromDate
        );

        SET @InsertedCount = @@ROWCOUNT;

        DECLARE @ResidentRentExemptionID BIGINT;
        DECLARE exemptionCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT exemption.residentRentExemptionID
        FROM Housing.ResidentRentExemption exemption
        WHERE exemption.residentRentExemptionActive = 1
          AND exemption.idaraID_FK = @idaraID
          AND CAST(exemption.residentRentExemptionStartDate AS date) <= @BillingMonthEnd
          AND
          (
              exemption.residentRentExemptionEndDate IS NULL
              OR CAST(exemption.residentRentExemptionEndDate AS date) >= @BillingMonthStart
          );

        OPEN exemptionCursor;
        FETCH NEXT FROM exemptionCursor INTO @ResidentRentExemptionID;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC Housing.SyncRentExemptionPayments
                  @Action = N'GENERATE'
                , @ResidentRentExemptionID = @ResidentRentExemptionID
                , @ThroughDate = @BillingMonthEnd
                , @SourceType = N'MONTHLY'
                , @EntryData = @entrydata
                , @HostName = @hostname;

            FETCH NEXT FROM exemptionCursor INTO @ResidentRentExemptionID;
        END;

        CLOSE exemptionCursor;
        DEALLOCATE exemptionCursor;

        COMMIT TRAN;

        IF @ReturnResult=1 SELECT
              1 AS IsSuccessful
            , CASE 
                WHEN @ExpectedCount = 0 
                    THEN N'لا توجد فواتير إيجار مستحقة لهذا الشهر'
                WHEN @InsertedCount = 0 
                    THEN N'فواتير الإيجار مرصودة مسبقاً لجميع المستحقين'
                ELSE N'تم رصد فواتير الإيجار الناقصة بنجاح'
              END AS Message_
            , @ExpectedCount AS ExpectedCount
            , @InsertedCount AS InsertedCount;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        IF @ReturnResult=1 SELECT
              0 AS IsSuccessful
            , ERROR_MESSAGE() AS Message_
            , @ExpectedCount AS ExpectedCount
            , @InsertedCount AS InsertedCount;
        ELSE
            THROW;
    END CATCH
END

GO

