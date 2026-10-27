CREATE   PROCEDURE [MoveData].[usp_MigrateAll]
    @IdaraId bigint,
    /* مهم عند التشغيل الفعلي: تاريخ نهاية الترحيل وبداية اعتماد النظام الجديد. */
    @CutoverDate date,
    @WaterMonthlyAmount decimal(18,2) = 8.25,
    @RollbackAfterTest bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MigrationRunID uniqueidentifier = NEWID(),
            @CurrentStepNumber int = NULL,
            @CurrentProcedure sysname = NULL,
            @StepStartedAt datetime2(3) = NULL;
    DECLARE @ExecutionTiming TABLE
    (
        StepNumber int NOT NULL, ProcedureName sysname NOT NULL,
        StartedAt datetime2(3) NOT NULL, CompletedAt datetime2(3) NOT NULL,
        DurationMilliseconds bigint NOT NULL, ExecutionStatus varchar(20) NOT NULL,
        ErrorNumber int NULL, ErrorMessage nvarchar(4000) NULL
    );

    IF NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID=@IdaraId)
        THROW 57000, N'The supplied IdaraId does not exist.', 1;
    IF @CutoverDate IS NULL
        THROW 57001, N'CutoverDate is required.', 1;


        
-- ==========================================
-- Preflight: Duplicate active waiting roots
-- ==========================================

SELECT
    a.generalNo_FK AS GeneralNo,
    a.buildingActionExtraType1 AS WaitingClassID,
    COUNT_BIG(*) AS ActiveRequests,
    STRING_AGG(
        CONVERT(NVARCHAR(MAX), a.buildingActionID),
        N', '
    ) AS ActionIDs
INTO #WaitingRootDuplicates
FROM KFMC.Housing.BuildingAction a
WHERE a.buildingActionTypeID_FK IN (1, 7, 25)
  AND a.buildingActionActive = 1
  AND a.generalNo_FK IS NOT NULL
  AND a.generalNo_FK NOT IN (0, 1)
  AND a.buildingActionExtraType1 IS NOT NULL
GROUP BY
    a.generalNo_FK,
    a.buildingActionExtraType1
HAVING COUNT_BIG(*) > 1;

IF EXISTS
(
    SELECT 1
    FROM #WaitingRootDuplicates
)
BEGIN
    SELECT
        GeneralNo,
        WaitingClassID,
        ActiveRequests,
        ActionIDs
    FROM #WaitingRootDuplicates
    ORDER BY GeneralNo, WaitingClassID;

    DECLARE @DuplicateGroups BIGINT;
    DECLARE @FirstGeneralNo NVARCHAR(50);
    DECLARE @WaitingError NVARCHAR(2048);

    SELECT @DuplicateGroups = COUNT_BIG(*)
    FROM #WaitingRootDuplicates;

    SELECT TOP (1)
        @FirstGeneralNo = CONVERT(
            NVARCHAR(50), GeneralNo
        )
    FROM #WaitingRootDuplicates
    ORDER BY GeneralNo;

    SET @WaitingError = CONCAT(
        N'فشل فحص الترحيل: يوجد ',
        @DuplicateGroups,
        N' مجموعات طلبات انتظار نشطة مكررة في KFMC. ',
        N'أول رقم عام مخالف: ',
        @FirstGeneralNo,
        N'. يجب تصحيح جميع المخالفات قبل النقل.'
    );

    THROW 57120, @WaitingError, 1;
END;


    BEGIN TRY
        BEGIN TRANSACTION;

        SET @CurrentStepNumber=1; SET @CurrentProcedure=N'MoveData.usp_MigrateMilitaryUnits'; SET @StepStartedAt=SYSDATETIME();
        EXEC MoveData.usp_MigrateMilitaryUnits
             @RollbackAfterTest=0;
        INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);

        SET @CurrentStepNumber=2; SET @CurrentProcedure=N'MoveData.usp_MigrateResidents'; SET @StepStartedAt=SYSDATETIME();
        EXEC MoveData.usp_MigrateResidents
             @IdaraId=@IdaraId, @RollbackAfterTest=0;
        INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);

        SET @CurrentStepNumber=3; SET @CurrentProcedure=N'MoveData.usp_MigrateResidentContacts'; SET @StepStartedAt=SYSDATETIME();
        EXEC MoveData.usp_MigrateResidentContacts
             @RollbackAfterTest=0;
        INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);

        SET @CurrentStepNumber=4; SET @CurrentProcedure=N'MoveData.usp_MigrateBuildings'; SET @StepStartedAt=SYSDATETIME();
        EXEC MoveData.usp_MigrateBuildings
             @IdaraId=@IdaraId, @RollbackAfterTest=0;
        INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);

        SET @CurrentStepNumber=5; SET @CurrentProcedure=N'MoveData.usp_MigrateMeters'; SET @StepStartedAt=SYSDATETIME();
        EXEC MoveData.usp_MigrateMeters
             @IdaraId=@IdaraId, @RollbackAfterTest=0;
        INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);

        /* Step 6: Migrate WaitingClass */
SET @CurrentStepNumber=6;
SET @CurrentProcedure=N'MoveData.usp_MigrateWaitingClass';
SET @StepStartedAt=SYSDATETIME();

EXEC MoveData.usp_MigrateWaitingClass
     @IdaraId=@IdaraId,
     @RollbackAfterTest=0;

INSERT @ExecutionTiming
VALUES(
    @CurrentStepNumber,
    @CurrentProcedure,
    @StepStartedAt,
    SYSDATETIME(),
    DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),
    'Succeeded',
    NULL,
    NULL
);

/* Step 7: Migrate BuildingActions */
SET @CurrentStepNumber=7;
SET @CurrentProcedure=N'MoveData.usp_MigrateBuildingActions';
SET @StepStartedAt=SYSDATETIME();

EXEC MoveData.usp_MigrateBuildingActions
     @IdaraId=@IdaraId,
     @RollbackAfterTest=0;

INSERT @ExecutionTiming
VALUES(
    @CurrentStepNumber,
    @CurrentProcedure,
    @StepStartedAt,
    SYSDATETIME(),
    DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),
    'Succeeded',
    NULL,
    NULL
);

        SET @CurrentStepNumber=8; SET @CurrentProcedure=N'MoveData.usp_MigrateLegacyAssignments'; SET @StepStartedAt=SYSDATETIME();
        EXEC MoveData.usp_MigrateLegacyAssignments
             @IdaraId=@IdaraId, @RollbackAfterTest=0;
        INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);

        SET @CurrentStepNumber=9; SET @CurrentProcedure=N'MoveData.usp_MigrateExtendInsurance'; SET @StepStartedAt=SYSDATETIME();
        EXEC MoveData.usp_MigrateExtendInsurance
             @IdaraId=@IdaraId, @RollbackAfterTest=0;
        INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);

        /* Electricity is inserted first to preserve old BillsID values. */
        SET @CurrentStepNumber=10; SET @CurrentProcedure=N'MoveData.usp_MigrateElectricBillsAndPayments'; SET @StepStartedAt=SYSDATETIME();
        EXEC MoveData.usp_MigrateElectricBillsAndPayments
             @IdaraId=@IdaraId, @RollbackAfterTest=0;
        INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);

        /* Rent and water receive new BillsID values after electricity. */
        SET @CurrentStepNumber=11; SET @CurrentProcedure=N'MoveData.usp_MigrateHistoricalRentAndWaterBills'; SET @StepStartedAt=SYSDATETIME();
        EXEC MoveData.usp_MigrateHistoricalRentAndWaterBills
             @IdaraId=@IdaraId,
             @CutoverDate=@CutoverDate,
             @WaterMonthlyAmount=@WaterMonthlyAmount,
             @RollbackAfterTest=0;
        INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);

        /* Restore the house-to-service configuration and service identity on
           historical fixed-service bills.  It uses only services already
           configured with an active idara link and fixed tariff. */
        SET @CurrentStepNumber=12; SET @CurrentProcedure=N'MoveData.usp_MigrateBuildingFixedServices'; SET @StepStartedAt=SYSDATETIME();
        EXEC MoveData.usp_MigrateBuildingFixedServices
             @IdaraId=@IdaraId, @RollbackAfterTest=0;
        INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);

        /* ربط سدادات الإيجار بالمبنى من فترة السكن بعد إنشاء فواتير الإيجار. */
        /* Deferred: run Housing.usp_ClassifyAndLinkBuildingPayments after migration validation. */

        SET @CurrentStepNumber=13; SET @CurrentProcedure=N'MoveData.usp_MigrateOccupantCustodyActions'; SET @StepStartedAt=SYSDATETIME();
        EXEC MoveData.usp_MigrateOccupantCustodyActions
             @RollbackAfterTest=0;
        INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);

        SET @CurrentStepNumber=14; SET @CurrentProcedure=N'MoveData.usp_MigratePenaltyBillsAndPayments'; SET @StepStartedAt=SYSDATETIME();
        EXEC MoveData.usp_MigratePenaltyBillsAndPayments
             @IdaraId=@IdaraId, @RollbackAfterTest=0;
        INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);


        /* Step 15: Register unfinished legacy exit cycles */

SET @CurrentStepNumber = 15;
SET @CurrentProcedure =
    N'MoveData.usp_RegisterLegacyOpenExitCycles';
SET @StepStartedAt = SYSDATETIME();

EXEC MoveData.usp_RegisterLegacyOpenExitCycles
     @IdaraId = @IdaraId,
     @RollbackAfterTest = 0;

INSERT @ExecutionTiming
VALUES
(
    @CurrentStepNumber,
    @CurrentProcedure,
    @StepStartedAt,
    SYSDATETIME(),
    DATEDIFF_BIG(MILLISECOND, @StepStartedAt, SYSDATETIME()),
    'Succeeded',
    NULL,
    NULL
);

        SELECT
            @RollbackAfterTest [RollbackAfterTest],
            @CutoverDate [CutoverDate],
            (SELECT COUNT_BIG(*) FROM dbo.MilitaryUnit) [MilitaryUnits],
            (SELECT COUNT_BIG(*) FROM Housing.ResidentInfo) [Residents],
            (SELECT COUNT_BIG(*) FROM Housing.ResidentContactInfo) [ResidentContacts],
            (SELECT COUNT_BIG(*) FROM Housing.BuildingDetails) [Buildings],
            (SELECT COUNT_BIG(*) FROM Housing.Meter) [Meters],
            (SELECT COUNT_BIG(*) FROM Housing.MeterRead) [MeterReads],
            (SELECT COUNT_BIG(*) FROM Housing.BuildingAction) [BuildingActions],
            (SELECT COUNT_BIG(*) FROM Housing.AssignPeriod
             WHERE AssignPeriodDescrption LIKE N'Legacy allocation migration - WaitingClass %') [AssignPeriods],
            (SELECT COUNT_BIG(*) FROM Housing.ExtendInsurance) [ExtendInsurance],
            (SELECT COUNT_BIG(*) FROM Housing.OccupantCustodyAction) [OccupantCustodyActions],
            (SELECT COUNT_BIG(*) FROM Housing.Bills WHERE BillChargeTypeID_FK=1) [RentBills],
            (SELECT COUNT_BIG(*) FROM Housing.Bills WHERE BillChargeTypeID_FK=2) [ElectricBills],
            (SELECT COUNT_BIG(*) FROM Housing.Bills WHERE BillChargeTypeID_FK=3) [WaterBills],
            (SELECT COUNT_BIG(*) FROM Housing.Bills WHERE BillChargeTypeID_FK=5) [PenaltyBills],
            (SELECT COUNT_BIG(*) FROM Housing.BuildingPayment WHERE BillChargeTypeID_FK=1) [RentPayments],
            (SELECT COUNT_BIG(*) FROM Housing.BuildingPayment WHERE BillChargeTypeID_FK=2) [ElectricPayments],
            (SELECT COUNT_BIG(*) FROM Housing.BuildingPayment WHERE BillChargeTypeID_FK=5) [PenaltyPayments];

        SELECT
            chargeType.BillChargeTypeID,
            chargeType.BillChargeTypeName_A,
            ISNULL(bills.TotalBills,0) [TotalBills],
            ISNULL(payments.TotalPayments,0) [TotalPayments],
            ISNULL(bills.TotalBills,0)-ISNULL(payments.TotalPayments,0) [Remaining]
        FROM Housing.BillChargeType chargeType
        LEFT JOIN
        (
            SELECT BillChargeTypeID_FK,SUM(TotalPrice) TotalBills
            FROM Housing.Bills WHERE BillActive=1 GROUP BY BillChargeTypeID_FK
        ) bills ON bills.BillChargeTypeID_FK=chargeType.BillChargeTypeID
        LEFT JOIN
        (
            SELECT paymentRow.BillChargeTypeID_FK,SUM(paymentRow.amount) TotalPayments
            FROM Housing.BuildingPayment paymentRow
            JOIN Housing.DeductList deductRow
              ON deductRow.deductListID=paymentRow.deductListID_FK
            WHERE paymentRow.buildingPayementActive=1
              AND deductRow.deductActive=1
              AND paymentRow.buildingPaymentLinkStatusID_FK=1
            GROUP BY paymentRow.BillChargeTypeID_FK
        ) payments ON payments.BillChargeTypeID_FK=chargeType.BillChargeTypeID
        WHERE chargeType.BillChargeTypeID IN (1,2,3,5)
        ORDER BY chargeType.BillChargeTypeID;

        SELECT linkStatus.buildingPaymentLinkStatusID,
               linkStatus.buildingPaymentLinkStatusName_A,
               COUNT_BIG(paymentRow.paymentID) PaymentCount,
               ISNULL(SUM(paymentRow.amount),0) PaymentTotal
        FROM Housing.BuildingPaymentLinkStatus linkStatus
        LEFT JOIN Housing.BuildingPayment paymentRow
          ON paymentRow.buildingPaymentLinkStatusID_FK=linkStatus.buildingPaymentLinkStatusID
         AND paymentRow.buildingPayementActive=1
        GROUP BY linkStatus.buildingPaymentLinkStatusID,
                 linkStatus.buildingPaymentLinkStatusName_A
        ORDER BY linkStatus.buildingPaymentLinkStatusID;

        /* تفصيل التصنيف المالي حسب نوع المطالبة؛ مهم لمراجعة الحالات 2 و3 و4. */
        SELECT
            paymentRow.BillChargeTypeID_FK,
            chargeType.BillChargeTypeName_A,
            paymentRow.buildingPaymentLinkStatusID_FK,
            linkStatus.buildingPaymentLinkStatusName_A,
            COUNT_BIG(*) PaymentCount,
            SUM(paymentRow.amount) PaymentTotal
        FROM Housing.BuildingPayment paymentRow
        LEFT JOIN Housing.BillChargeType chargeType
          ON chargeType.BillChargeTypeID=paymentRow.BillChargeTypeID_FK
        LEFT JOIN Housing.BuildingPaymentLinkStatus linkStatus
          ON linkStatus.buildingPaymentLinkStatusID=paymentRow.buildingPaymentLinkStatusID_FK
        WHERE paymentRow.buildingPayementActive=1
        GROUP BY paymentRow.BillChargeTypeID_FK,
                 chargeType.BillChargeTypeName_A,
                 paymentRow.buildingPaymentLinkStatusID_FK,
                 linkStatus.buildingPaymentLinkStatusName_A
        ORDER BY paymentRow.BillChargeTypeID_FK,
                 paymentRow.buildingPaymentLinkStatusID_FK;

        /* يفسر الفرق بين إجمالي كهرباء المصدر والإجمالي المالي النشط. */
        SELECT
            BillActive,
            COUNT_BIG(*) ElectricBillCount,
            SUM(TotalPrice) ElectricBillTotal
        FROM Housing.Bills
        WHERE BillChargeTypeID_FK=2
        GROUP BY BillActive
        ORDER BY BillActive DESC;

        IF @RollbackAfterTest=1 ROLLBACK TRANSACTION; ELSE COMMIT TRANSACTION;

        INSERT MoveData.MigrationExecutionLog
        (MigrationRunID,StepNumber,ProcedureName,StartedAt,CompletedAt,DurationMilliseconds,ExecutionStatus,ErrorNumber,ErrorMessage,IdaraId,CutoverDate,RollbackAfterTest)
        SELECT @MigrationRunID,StepNumber,ProcedureName,StartedAt,CompletedAt,DurationMilliseconds,ExecutionStatus,ErrorNumber,ErrorMessage,@IdaraId,@CutoverDate,@RollbackAfterTest
        FROM @ExecutionTiming;

        SELECT StepNumber,ProcedureName,StartedAt,CompletedAt,DurationMilliseconds,
               CONVERT(decimal(18,2),DurationMilliseconds/1000.0) DurationSeconds,
               ExecutionStatus,ErrorNumber,ErrorMessage
        FROM @ExecutionTiming ORDER BY StepNumber;
    END TRY
BEGIN CATCH
        DECLARE @ErrorNumber int=ERROR_NUMBER(), @ErrorMessage nvarchar(4000)=ERROR_MESSAGE();
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        IF @CurrentProcedure IS NOT NULL
           AND NOT EXISTS(SELECT 1 FROM @ExecutionTiming WHERE StepNumber=@CurrentStepNumber)
            INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Failed',@ErrorNumber,@ErrorMessage);
        INSERT MoveData.MigrationExecutionLog
        (MigrationRunID,StepNumber,ProcedureName,StartedAt,CompletedAt,DurationMilliseconds,ExecutionStatus,ErrorNumber,ErrorMessage,IdaraId,CutoverDate,RollbackAfterTest)
        SELECT @MigrationRunID,StepNumber,ProcedureName,StartedAt,CompletedAt,DurationMilliseconds,ExecutionStatus,ErrorNumber,ErrorMessage,@IdaraId,@CutoverDate,@RollbackAfterTest
        FROM @ExecutionTiming;
        THROW;
    END CATCH;
END;