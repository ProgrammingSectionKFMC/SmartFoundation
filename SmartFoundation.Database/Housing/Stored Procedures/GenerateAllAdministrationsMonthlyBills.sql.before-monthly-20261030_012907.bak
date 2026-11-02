CREATE PROCEDURE [Housing].[GenerateAllAdministrationsMonthlyBills]
(
      @Month INT = NULL
    , @Year INT = NULL
    , @EntryData NVARCHAR(20)
    , @HostName NVARCHAR(200)
    , @RetryFailed BIT = 1
    , @OnlyRunID BIGINT = NULL
    , @ReturnSummary BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE @TargetDate DATE = DATEADD(MONTH, -1, CONVERT(date, GETDATE()));
    SET @Month = ISNULL(@Month, MONTH(@TargetDate));
    SET @Year = ISNULL(@Year, YEAR(@TargetDate));
    IF @Month NOT BETWEEN 1 AND 12 OR EOMONTH(DATEFROMPARTS(@Year,@Month,1)) >= EOMONTH(GETDATE())
        THROW 50001, N'يجب أن تكون فترة الرصد شهراً مكتملاً سابقاً', 1;

    DECLARE @Scopes TABLE
    (
        ScopeID INT IDENTITY PRIMARY KEY, IdaraID BIGINT, BillingType NVARCHAR(20),
        ServiceID INT, CalculationMethod NVARCHAR(30)
    );
    INSERT @Scopes (IdaraID,BillingType,ServiceID,CalculationMethod)
    SELECT DISTINCT source.IdaraID, N'RENT', 0, N'RENT'
    FROM
    (
        SELECT CONVERT(bigint,IdaraId) IdaraID FROM Housing.V_Occupant WHERE IdaraId IS NOT NULL
        UNION SELECT CONVERT(bigint,Idara_FK) FROM Housing.MeterServiceTypeLinkedWithIdara WHERE Idara_FK IS NOT NULL
    ) source;

    INSERT @Scopes (IdaraID,BillingType,ServiceID,CalculationMethod)
    SELECT DISTINCT administration.IdaraID,N'SERVICE',link.MeterServiceTypeID_FK,method.MethodName
    FROM
    (
        SELECT DISTINCT CONVERT(bigint, occupant.IdaraId) AS IdaraID
        FROM Housing.V_Occupant occupant
        WHERE occupant.IdaraId IS NOT NULL
    ) administration
    JOIN Housing.MeterServiceTypeLinkedWithIdara link
      ON link.Idara_FK = administration.IdaraID
      OR link.Idara_FK IS NULL
    JOIN Housing.MeterServiceType serviceType ON serviceType.meterServiceTypeID=link.MeterServiceTypeID_FK
    CROSS JOIN (VALUES(N'SERVICE_FIXED'),(N'METER_FIXED')) method(MethodName)
    WHERE serviceType.meterServiceTypeActive=1
      AND (link.MeterServiceTypeLinkedWithIdaraActive=1 OR link.MeterServiceTypeLinkedWithIdaraEndDate IS NOT NULL)
      AND (link.MeterServiceTypeLinkedWithIdaraStartDate IS NULL OR CONVERT(date,link.MeterServiceTypeLinkedWithIdaraStartDate)<=EOMONTH(DATEFROMPARTS(@Year,@Month,1)))
      AND (link.MeterServiceTypeLinkedWithIdaraEndDate IS NULL OR CONVERT(date,link.MeterServiceTypeLinkedWithIdaraEndDate)>=DATEFROMPARTS(@Year,@Month,1));

    IF @OnlyRunID IS NOT NULL
    BEGIN
        DELETE scopeRow
        FROM @Scopes scopeRow
        WHERE NOT EXISTS
        (
            SELECT 1 FROM Housing.MonthlyBillingRun runRow
            WHERE runRow.MonthlyBillingRunID=@OnlyRunID
              AND runRow.IdaraID_FK=scopeRow.IdaraID AND runRow.PeriodYear=@Year AND runRow.PeriodMonth=@Month
              AND runRow.BillingType=scopeRow.BillingType AND runRow.MeterServiceTypeID_FK=scopeRow.ServiceID
              AND runRow.CalculationMethod=scopeRow.CalculationMethod
        );
    END;

    DECLARE @ScopeID INT=1,@MaxScopeID INT=(SELECT MAX(ScopeID) FROM @Scopes),@IdaraID BIGINT,
            @BillingType NVARCHAR(20),@ServiceID INT,@Method NVARCHAR(30),@RunID BIGINT,
            @BeforeBillID BIGINT,@LockResult INT,@LockResource NVARCHAR(255),@Expected INT=0,@Inserted INT=0,@Existing INT=0,@Skipped INT=0;
    DECLARE @ExpectedRent TABLE
    (
        residentInfoID BIGINT, buildingDetailsID BIGINT, buildingRentTypeID_FK BIGINT,
        rentBillsAmount DECIMAL(18,2), rentBillsFromDate DATE, rentBillsToDate DATE,
        rentBillsActive BIT, idaraID_FK BIGINT, entrydata NVARCHAR(20), hostname NVARCHAR(200)
    );

    WHILE @ScopeID<=ISNULL(@MaxScopeID,0)
    BEGIN
        SELECT @IdaraID=IdaraID,@BillingType=BillingType,@ServiceID=ServiceID,@Method=CalculationMethod
        FROM @Scopes WHERE ScopeID=@ScopeID;
        SET @RunID=NULL; SET @Expected=0; SET @Inserted=0; SET @Existing=0; SET @Skipped=0;
        SET @LockResource=CONCAT(N'MONTHLY_BILLING:',@IdaraID,N':',@Year,N':',@Month,N':',@BillingType,N':',@ServiceID,N':',@Method);
        EXEC @LockResult=sys.sp_getapplock @Resource=@LockResource,@LockMode=N'Exclusive',@LockOwner=N'Session',@LockTimeout=0;
        IF @LockResult>=0
        BEGIN
            BEGIN TRY
                SELECT @RunID=MonthlyBillingRunID
                FROM Housing.MonthlyBillingRun WITH(UPDLOCK,HOLDLOCK)
                WHERE IdaraID_FK=@IdaraID AND PeriodYear=@Year AND PeriodMonth=@Month
                  AND BillingType=@BillingType AND MeterServiceTypeID_FK=@ServiceID AND CalculationMethod=@Method;
                IF @RunID IS NULL
                BEGIN
                    INSERT Housing.MonthlyBillingRun
                    (IdaraID_FK,PeriodYear,PeriodMonth,BillingType,MeterServiceTypeID_FK,CalculationMethod,RunStatus,entryData,hostName)
                    VALUES(@IdaraID,@Year,@Month,@BillingType,@ServiceID,@Method,N'PENDING',@EntryData,@HostName);
                    SET @RunID=SCOPE_IDENTITY();
                END;

                IF NOT EXISTS(SELECT 1 FROM Housing.MonthlyBillingRun WHERE MonthlyBillingRunID=@RunID AND RunStatus=N'COMPLETED')
                   AND (@RetryFailed=1 OR NOT EXISTS(SELECT 1 FROM Housing.MonthlyBillingRun WHERE MonthlyBillingRunID=@RunID AND RunStatus=N'FAILED'))
                BEGIN
                    UPDATE Housing.MonthlyBillingRun
                    SET RunStatus=N'RUNNING',StartedAt=COALESCE(StartedAt,SYSDATETIME()),LastHeartbeatAt=SYSDATETIME(),
                        FinishedAt=NULL,AttemptCount=AttemptCount+1,LastError=NULL,entryData=@EntryData,hostName=@HostName
                    WHERE MonthlyBillingRunID=@RunID;
                    SET @BeforeBillID=ISNULL((SELECT MAX(BillsID) FROM Housing.Bills),0);
                    DELETE FROM Housing.MonthlyBillingRunDetails WHERE MonthlyBillingRunID_FK=@RunID;

                    /*
                       Rent bills created earlier by an exit workflow can legitimately
                       belong to the same month, but they are not candidates of the
                       current monthly run. Build the candidate set first so EXISTING
                       and ProposedCount describe only this run's scope.
                    */
                    IF @BillingType=N'RENT'
                    BEGIN
                        DELETE FROM @ExpectedRent;
                        INSERT @ExpectedRent
                        EXEC Housing.BuildingRentForOneMonth @Month,@Year,@EntryData,@HostName,@IdaraID;
                        SET @Expected=(SELECT COUNT(*) FROM @ExpectedRent);
                    END;

                    INSERT Housing.MonthlyBillingRunDetails
                    (MonthlyBillingRunID_FK,BillsID_FK,ResidentInfoID_FK,GeneralNo_FK,BuildingDetailsID_FK,MeterID_FK,
                     FromDate,ToDate,ResultStatus,ReasonCode,ReasonMessage,AmountBeforeTax,TaxAmount,TotalAmount)
                    SELECT @RunID,b.BillsID,b.residentInfoID_FK,b.generalNo_FK,b.buildingDetailsID,b.meterID,
                           CONVERT(date,b.BillsFromDate),CONVERT(date,b.BillsToDate),N'EXISTING',N'ALREADY_BILLED',N'الفاتورة موجودة قبل هذا التشغيل',
                           ISNULL(b.PRICE,0),ISNULL(b.PRICETAX,0),ISNULL(b.TotalPrice,0)
                    FROM Housing.Bills b
                    LEFT JOIN Housing.MeterType mt ON mt.meterTypeID=b.meterTypeID
                    WHERE b.BillActive=1 AND b.idaraID_FK=@IdaraID AND b.PeriodYear=@Year AND b.PeriodMonth=@Month
                      AND ((@BillingType=N'RENT' AND b.BillChargeTypeID_FK=1
                            AND EXISTS
                            (
                                SELECT 1
                                FROM @ExpectedRent expectedRent
                                WHERE expectedRent.residentInfoID=b.residentInfoID_FK
                                  AND expectedRent.buildingDetailsID=b.buildingDetailsID
                                  AND CONVERT(date,b.BillsFromDate)<=expectedRent.rentBillsToDate
                                  AND CONVERT(date,b.BillsToDate)>=expectedRent.rentBillsFromDate
                            ))
                        OR (@BillingType=N'SERVICE' AND b.meterServiceTypeID=@ServiceID
                            AND ((@Method=N'SERVICE_FIXED' AND b.meterID IS NULL)
                              OR (@Method=N'METER_FIXED' AND mt.MeterCalculateTypeID_FK=2))));
                    SET @Existing=@@ROWCOUNT;
                    IF @BillingType=N'RENT'
                    BEGIN
                        INSERT Housing.MonthlyBillingRunDetails
                        (MonthlyBillingRunID_FK,ResidentInfoID_FK,GeneralNo_FK,BuildingDetailsID_FK,
                         FromDate,ToDate,ResultStatus,ReasonCode,ReasonMessage)
                        SELECT @RunID,o.residentInfoID,o.GeneralNo,o.buildingDetailsID,
                               NULL,NULL,N'SKIPPED',N'MISSING_OCCUPANCY_DATE',N'تاريخ بداية السكن غير موجود'
                        FROM Housing.V_Occupant o
                        WHERE o.IdaraId=@IdaraID AND o.OccupentDate IS NULL;

                        INSERT Housing.MonthlyBillingRunDetails
                        (MonthlyBillingRunID_FK,ResidentInfoID_FK,GeneralNo_FK,BuildingDetailsID_FK,
                         FromDate,ToDate,ResultStatus,ReasonCode,ReasonMessage)
                        SELECT @RunID,o.residentInfoID,o.GeneralNo,o.buildingDetailsID,
                               CASE WHEN CONVERT(date,o.OccupentDate)>DATEFROMPARTS(@Year,@Month,1)
                                    THEN CONVERT(date,o.OccupentDate) ELSE DATEFROMPARTS(@Year,@Month,1) END,
                               CASE WHEN o.ExitDate IS NOT NULL AND CONVERT(date,o.ExitDate)<EOMONTH(DATEFROMPARTS(@Year,@Month,1))
                                    THEN CONVERT(date,o.ExitDate) ELSE EOMONTH(DATEFROMPARTS(@Year,@Month,1)) END,
                               N'SKIPPED',
                               CASE WHEN NOT EXISTS(SELECT 1 FROM Housing.BuildingRent br WHERE br.buildingDetailsID_FK=o.buildingDetailsID)
                                    THEN N'MISSING_RENT_PRICE' ELSE N'NO_ACTIVE_RENT_PRICE' END,
                               CASE WHEN NOT EXISTS(SELECT 1 FROM Housing.BuildingRent br WHERE br.buildingDetailsID_FK=o.buildingDetailsID)
                                    THEN N'لا يوجد سعر إيجار معرف للمنزل' ELSE N'لا يوجد سعر إيجار سارٍ خلال شهر الرصد' END
                        FROM Housing.V_Occupant o
                        WHERE o.IdaraId=@IdaraID
                          AND CONVERT(date,o.OccupentDate)<=EOMONTH(DATEFROMPARTS(@Year,@Month,1))
                          AND (o.ExitDate IS NULL OR CONVERT(date,o.ExitDate)>=DATEFROMPARTS(@Year,@Month,1))
                          AND NOT EXISTS
                          (SELECT 1 FROM Housing.fn_CalcBuildingRent_ForOneMonth
                           (o.buildingDetailsID,CONVERT(date,o.OccupentDate),@Year,@Month,CONVERT(date,o.ExitDate)));

                        SET @Skipped=(SELECT COUNT(*) FROM Housing.MonthlyBillingRunDetails
                                      WHERE MonthlyBillingRunID_FK=@RunID AND ResultStatus=N'SKIPPED');
                        EXEC Housing.GenerateMonthlyRentBills @Month,@Year,@EntryData,@HostName,@IdaraID,@ReturnResult=0;
                    END
                    ELSE
                    BEGIN
                        EXEC Housing.GenerateMonthlyFixedServiceBills
                            @Month=@Month,@Year=@Year,@EntryData=@EntryData,@HostName=@HostName,@IdaraID=@IdaraID,
                            @MeterServiceTypeID=@ServiceID,@CalculationMethod=@Method,@ReturnResult=0;
                    END;

                    INSERT Housing.MonthlyBillingRunDetails
                    (MonthlyBillingRunID_FK,BillsID_FK,ResidentInfoID_FK,GeneralNo_FK,BuildingDetailsID_FK,MeterID_FK,
                     FromDate,ToDate,ResultStatus,ReasonCode,ReasonMessage,AmountBeforeTax,TaxAmount,TotalAmount)
                    SELECT @RunID,b.BillsID,b.residentInfoID_FK,b.generalNo_FK,b.buildingDetailsID,b.meterID,
                           CONVERT(date,b.BillsFromDate),CONVERT(date,b.BillsToDate),N'BILLED',N'CREATED',N'تم إنشاء الفاتورة في هذا التشغيل',
                           ISNULL(b.PRICE,0),ISNULL(b.PRICETAX,0),ISNULL(b.TotalPrice,0)
                    FROM Housing.Bills b
                    LEFT JOIN Housing.MeterType mt ON mt.meterTypeID=b.meterTypeID
                    WHERE b.BillsID>@BeforeBillID AND b.idaraID_FK=@IdaraID
                      AND ((@BillingType=N'RENT' AND b.BillChargeTypeID_FK=1)
                        OR (@BillingType=N'SERVICE' AND b.meterServiceTypeID=@ServiceID
                            AND ((@Method=N'SERVICE_FIXED' AND b.meterID IS NULL)
                              OR (@Method=N'METER_FIXED' AND mt.MeterCalculateTypeID_FK=2))));

                    SET @Inserted=@@ROWCOUNT;
                    IF @BillingType=N'SERVICE' SET @Expected=@Existing+@Inserted;
                    UPDATE runRow
                    SET RunStatus=N'COMPLETED',ProposedCount=@Expected,CreatedCount=@Inserted,
                        ExistingCount=@Existing,SkippedCount=@Skipped,
                        AmountBeforeTax=totals.AmountBeforeTax,TaxAmount=totals.TaxAmount,TotalAmount=totals.TotalAmount,
                        LastHeartbeatAt=SYSDATETIME(),FinishedAt=SYSDATETIME()
                    FROM Housing.MonthlyBillingRun runRow
                    CROSS APPLY(SELECT ISNULL(SUM(AmountBeforeTax),0) AmountBeforeTax,ISNULL(SUM(TaxAmount),0) TaxAmount,
                                      ISNULL(SUM(TotalAmount),0) TotalAmount
                                FROM Housing.MonthlyBillingRunDetails d WHERE d.MonthlyBillingRunID_FK=@RunID) totals
                    WHERE runRow.MonthlyBillingRunID=@RunID;
                END;
            END TRY
            BEGIN CATCH
                IF @RunID IS NOT NULL
                BEGIN
                    UPDATE Housing.MonthlyBillingRun SET RunStatus=N'FAILED',FailedCount=FailedCount+1,
                           LastHeartbeatAt=SYSDATETIME(),FinishedAt=SYSDATETIME(),LastError=ERROR_MESSAGE()
                    WHERE MonthlyBillingRunID=@RunID;
                    INSERT Housing.MonthlyBillingRunDetails(MonthlyBillingRunID_FK,ResultStatus,ReasonCode,ReasonMessage)
                    VALUES(@RunID,N'FAILED',CONCAT(N'SQL_',ERROR_NUMBER()),ERROR_MESSAGE());
                END;
            END CATCH;
            EXEC sys.sp_releaseapplock @Resource=@LockResource,@LockOwner=N'Session';
        END;
        SET @ScopeID+=1;
    END;

    IF @ReturnSummary=1
        SELECT runRow.*,idara.idaraLongName_A,serviceType.meterServiceTypeName_A
        FROM Housing.MonthlyBillingRun runRow
        LEFT JOIN dbo.Idara idara ON idara.idaraID=runRow.IdaraID_FK
        LEFT JOIN Housing.MeterServiceType serviceType ON serviceType.meterServiceTypeID=runRow.MeterServiceTypeID_FK
        WHERE runRow.PeriodYear=@Year AND runRow.PeriodMonth=@Month
          AND (@OnlyRunID IS NULL OR runRow.MonthlyBillingRunID=@OnlyRunID)
        ORDER BY runRow.IdaraID_FK,runRow.BillingType,runRow.MeterServiceTypeID_FK,runRow.CalculationMethod;
    ELSE
        SELECT 1 IsSuccessful,N'تمت إعادة تشغيل نطاق الرصد بنجاح' Message_;
END;
