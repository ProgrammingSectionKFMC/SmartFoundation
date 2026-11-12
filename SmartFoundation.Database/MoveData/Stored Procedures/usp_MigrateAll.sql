CREATE PROCEDURE [MoveData].[usp_MigrateAll]      @IdaraId bigint,      /* مهم عند التشغيل الفعلي: تاريخ نهاية الترحيل وبداية اعتماد النظام الجديد. */      @CutoverDate date,      @WaterMonthlyAmount decimal(18,2) = 8.25,      @RollbackAfterTest bit = 1  AS  BEGIN      SET NOCOUNT ON;      SET XACT_ABORT ON;        DECLARE @MigrationRunID uniqueidentifier = NEWID(),              @CurrentStepNumber int = NULL,              @CurrentProcedure sysname = NULL,              @StepStartedAt datetime2(3) = NULL;      /* Findings survive transaction rollback because they are captured in a table variable. */
      DECLARE @DuplicateGateFindings TABLE
      (
          GeneralNo bigint NULL,
          EffectiveClassID bigint NULL,
          EffectiveIdaraID bigint NULL,
          PendingCount bigint NOT NULL,
          OccupiedCount bigint NOT NULL,
          TotalActiveRoots bigint NOT NULL
      );
      DECLARE @ExecutionTiming TABLE      (          StepNumber int NOT NULL, ProcedureName sysname NOT NULL,          StartedAt datetime2(3) NOT NULL, CompletedAt datetime2(3) NOT NULL,          DurationMilliseconds bigint NOT NULL, ExecutionStatus varchar(20) NOT NULL,          ErrorNumber int NULL, ErrorMessage nvarchar(4000) NULL      );        IF NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID=@IdaraId)          THROW 57000, N'The supplied IdaraId does not exist.', 1;      IF @CutoverDate IS NULL          THROW 57001, N'CutoverDate is required.', 1;                  /* Trial 2: the old source-side COUNT(root) gate was over-broad: historical
     occupied/exited roots are still active rows in KFMC. The new check runs
     AFTER usp_MigrateBuildingActions inside this transaction; its own dynamic
     policy resolves safe same-class duplicates, and only unresolved TARGET
     active pending requests trigger 57120. */
  BEGIN TRY          BEGIN TRANSACTION;            SET @CurrentStepNumber=1; SET @CurrentProcedure=N'MoveData.usp_MigrateMilitaryUnits'; SET @StepStartedAt=SYSDATETIME();
          RAISERROR(N'[MigrateAll] START stage %d/16: %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;          EXEC MoveData.usp_MigrateMilitaryUnits               @RollbackAfterTest=0;          INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);
          RAISERROR(N'[MigrateAll] OK stage %d/16 (pending final commit): %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;            SET @CurrentStepNumber=2; SET @CurrentProcedure=N'MoveData.usp_MigrateResidents'; SET @StepStartedAt=SYSDATETIME();
          RAISERROR(N'[MigrateAll] START stage %d/16: %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;          EXEC MoveData.usp_MigrateResidents               @IdaraId=@IdaraId, @RollbackAfterTest=0;          INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);
          RAISERROR(N'[MigrateAll] OK stage %d/16 (pending final commit): %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;            SET @CurrentStepNumber=3; SET @CurrentProcedure=N'MoveData.usp_MigrateResidentContacts'; SET @StepStartedAt=SYSDATETIME();
          RAISERROR(N'[MigrateAll] START stage %d/16: %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;          EXEC MoveData.usp_MigrateResidentContacts               @RollbackAfterTest=0;          INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);
          RAISERROR(N'[MigrateAll] OK stage %d/16 (pending final commit): %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;            SET @CurrentStepNumber=4; SET @CurrentProcedure=N'MoveData.usp_MigrateBuildings'; SET @StepStartedAt=SYSDATETIME();
          RAISERROR(N'[MigrateAll] START stage %d/16: %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;          EXEC MoveData.usp_MigrateBuildings               @IdaraId=@IdaraId, @RollbackAfterTest=0;          INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);
          RAISERROR(N'[MigrateAll] OK stage %d/16 (pending final commit): %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;            SET @CurrentStepNumber=5; SET @CurrentProcedure=N'MoveData.usp_MigrateMeters'; SET @StepStartedAt=SYSDATETIME();
          RAISERROR(N'[MigrateAll] START stage %d/16: %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;          EXEC MoveData.usp_MigrateMeters               @IdaraId=@IdaraId, @RollbackAfterTest=0;          INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);
          RAISERROR(N'[MigrateAll] OK stage %d/16 (pending final commit): %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;            /* Step 6: Migrate WaitingClass */  SET @CurrentStepNumber=6;  SET @CurrentProcedure=N'MoveData.usp_MigrateWaitingClass';  SET @StepStartedAt=SYSDATETIME();
          RAISERROR(N'[MigrateAll] START stage %d/16: %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;    EXEC MoveData.usp_MigrateWaitingClass       @IdaraId=@IdaraId,       @RollbackAfterTest=0;    INSERT @ExecutionTiming  VALUES(      @CurrentStepNumber,      @CurrentProcedure,      @StepStartedAt,      SYSDATETIME(),      DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),      'Succeeded',      NULL,      NULL  );
          RAISERROR(N'[MigrateAll] OK stage %d/16 (pending final commit): %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;    /* Step 7: Migrate BuildingActions */  SET @CurrentStepNumber=7;  SET @CurrentProcedure=N'MoveData.usp_MigrateBuildingActions';  SET @StepStartedAt=SYSDATETIME();
          RAISERROR(N'[MigrateAll] START stage %d/16: %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;    EXEC MoveData.usp_MigrateBuildingActions    @IdaraId=@IdaraId,    @RollbackAfterTest=0;

  /* Trial-2 gate 57120: verify ACTUAL TARGET effective pending chains.
     Every duplicate is scoped to the same resident, class and department.
     A source root with completed occupation/exit must not be counted as
     an active waiting request, even when its original root is active. */
  ;WITH ActiveRoots AS
  (
    SELECT r.[buildingActionID] AS RootID,r.[generalNo_FK] AS GeneralNo,
           r.[buildingActionExtraType1] AS EffectiveClassID,
           COALESCE(r.[IdaraId_FK],@IdaraId) AS EffectiveIdaraID
    FROM [Housing].[BuildingAction] r
    WHERE r.[buildingActionParentID] IS NULL
      AND r.[buildingActionTypeID_FK]=1
      AND r.[buildingActionActive]=1
      AND r.[generalNo_FK] IS NOT NULL
      AND r.[generalNo_FK] NOT IN (0,1,18)
      AND r.[buildingActionExtraType1] IS NOT NULL
  ), ActionTree AS
  (
    SELECT r.RootID,r.GeneralNo,r.EffectiveClassID,r.EffectiveIdaraID,
           a.[buildingActionID] AS ActionID,
           a.[buildingActionTypeID_FK] AS ActionTypeID,
           CONVERT(int,0) AS Depth
    FROM ActiveRoots r JOIN [Housing].[BuildingAction] a
      ON a.[buildingActionID]=r.RootID
    UNION ALL
    SELECT t.RootID,t.GeneralNo,t.EffectiveClassID,t.EffectiveIdaraID,
           a.[buildingActionID],a.[buildingActionTypeID_FK],t.Depth+1
    FROM ActionTree t JOIN [Housing].[BuildingAction] a
      ON a.[buildingActionParentID]=t.ActionID
     AND a.[buildingActionActive]=1
    WHERE t.Depth<100
  ), LastRanked AS
  (
    SELECT *,ROW_NUMBER() OVER
       (PARTITION BY RootID ORDER BY Depth DESC,ActionID DESC) AS rn
    FROM ActionTree
  )
  SELECT GeneralNo,EffectiveClassID,EffectiveIdaraID,
         SUM(CASE WHEN ActionTypeID IN (1,18,26,27)
         THEN 1 ELSE 0 END) AS PendingCount,
SUM(CASE WHEN ActionTypeID IN (2,24)
         THEN 1 ELSE 0 END) AS OccupiedCount,
         COUNT_BIG(*) AS TotalActiveRoots
  INTO #Trial2PostActionRootGroups
  FROM LastRanked WHERE rn=1
  GROUP BY GeneralNo,EffectiveClassID,EffectiveIdaraID
  OPTION (MAXRECURSION 100);

  IF EXISTS
  (
    SELECT 1 FROM #Trial2PostActionRootGroups
    WHERE PendingCount>1 OR (PendingCount>0 AND OccupiedCount>0)
  )
  BEGIN
    INSERT @DuplicateGateFindings
      (GeneralNo,EffectiveClassID,EffectiveIdaraID,PendingCount,OccupiedCount,TotalActiveRoots)
    SELECT GeneralNo,EffectiveClassID,EffectiveIdaraID,
           PendingCount,OccupiedCount,TotalActiveRoots
    FROM #Trial2PostActionRootGroups
    WHERE PendingCount>1 OR (PendingCount>0 AND OccupiedCount>0);
    THROW 57120, N'Unresolved duplicated active waiting requests in the same class after BuildingAction migration; transaction rolled back.', 1;
  END;

  DROP TABLE #Trial2PostActionRootGroups;
  INSERT @ExecutionTiming  VALUES(      @CurrentStepNumber,      @CurrentProcedure,      @StepStartedAt,      SYSDATETIME(),      DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),      'Succeeded',      NULL,      NULL  );
          RAISERROR(N'[MigrateAll] OK stage %d/16 (pending final commit): %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;            SET @CurrentStepNumber=8; SET @CurrentProcedure=N'MoveData.usp_MigrateLegacyAssignments'; SET @StepStartedAt=SYSDATETIME();
          RAISERROR(N'[MigrateAll] START stage %d/16: %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;          EXEC MoveData.usp_MigrateLegacyAssignments               @IdaraId=@IdaraId, @RollbackAfterTest=0;          INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);
          RAISERROR(N'[MigrateAll] OK stage %d/16 (pending final commit): %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;            SET @CurrentStepNumber=9; SET @CurrentProcedure=N'MoveData.usp_MigrateExtendInsurance'; SET @StepStartedAt=SYSDATETIME();
          RAISERROR(N'[MigrateAll] START stage %d/16: %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;          EXEC MoveData.usp_MigrateExtendInsurance               @IdaraId=@IdaraId, @RollbackAfterTest=0;          INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);
          RAISERROR(N'[MigrateAll] OK stage %d/16 (pending final commit): %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;            /* Electricity is inserted first to preserve old BillsID values. */          SET @CurrentStepNumber=10; SET @CurrentProcedure=N'MoveData.usp_MigrateElectricBillsAndPayments'; SET @StepStartedAt=SYSDATETIME();
          RAISERROR(N'[MigrateAll] START stage %d/16: %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;          EXEC MoveData.usp_MigrateElectricBillsAndPayments               @IdaraId=@IdaraId, @RollbackAfterTest=0;          INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);
          RAISERROR(N'[MigrateAll] OK stage %d/16 (pending final commit): %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;            /* Rent and water receive new BillsID values after electricity. */          SET @CurrentStepNumber=11; SET @CurrentProcedure=N'MoveData.usp_MigrateHistoricalRentAndWaterBills'; SET @StepStartedAt=SYSDATETIME();
          RAISERROR(N'[MigrateAll] START stage %d/16: %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;          EXEC MoveData.usp_MigrateHistoricalRentAndWaterBills               @IdaraId=@IdaraId,               @CutoverDate=@CutoverDate,               @WaterMonthlyAmount=@WaterMonthlyAmount,               @RollbackAfterTest=0;          INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);
          RAISERROR(N'[MigrateAll] OK stage %d/16 (pending final commit): %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;            /* Restore the house-to-service configuration and service identity on            historical fixed-service bills.  It uses only services already            configured with an active idara link and fixed tariff. */         SET @CurrentStepNumber=12; SET @CurrentProcedure=N'MoveData.usp_MigrateBuildingFixedServices'; SET @StepStartedAt=SYSDATETIME();
          RAISERROR(N'[MigrateAll] START stage %d/16: %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;         EXEC MoveData.usp_MigrateBuildingFixedServices              @IdaraId=@IdaraId, @RollbackAfterTest=0;         INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);
          RAISERROR(N'[MigrateAll] OK stage %d/16 (pending final commit): %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;          /* ربط سدادات الإيجار بالمبنى من فترة السكن بعد إنشاء فواتير الإيجار. */         /* Deferred: run Housing.usp_ClassifyAndLinkBuildingPayments after migration validation. */          SET @CurrentStepNumber=13; SET @CurrentProcedure=N'MoveData.usp_MigrateOccupantCustodyActions'; SET @StepStartedAt=SYSDATETIME();
          RAISERROR(N'[MigrateAll] START stage %d/16: %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;         EXEC MoveData.usp_MigrateOccupantCustodyActions              @RollbackAfterTest=0;         INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);
          RAISERROR(N'[MigrateAll] OK stage %d/16 (pending final commit): %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;          SET @CurrentStepNumber=14; SET @CurrentProcedure=N'MoveData.usp_MigratePenaltyBillsAndPayments'; SET @StepStartedAt=SYSDATETIME();
          RAISERROR(N'[MigrateAll] START stage %d/16: %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;         EXEC MoveData.usp_MigratePenaltyBillsAndPayments              @IdaraId=@IdaraId, @RollbackAfterTest=0;          INSERT @ExecutionTiming VALUES(@CurrentStepNumber,@CurrentProcedure,@StepStartedAt,SYSDATETIME(),DATEDIFF_BIG(MILLISECOND,@StepStartedAt,SYSDATETIME()),'Succeeded',NULL,NULL);
          RAISERROR(N'[MigrateAll] OK stage %d/16 (pending final commit): %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;              /* Step 15: Register unfinished legacy exit cycles */    SET @CurrentStepNumber = 15;  SET @CurrentProcedure =      N'MoveData.usp_RegisterLegacyOpenExitCycles';  SET @StepStartedAt = SYSDATETIME();
          RAISERROR(N'[MigrateAll] START stage %d/16: %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;    EXEC MoveData.usp_RegisterLegacyOpenExitCycles       @IdaraId = @IdaraId,       @RollbackAfterTest = 0;    INSERT @ExecutionTiming  VALUES  (      @CurrentStepNumber,      @CurrentProcedure,      @StepStartedAt,      SYSDATETIME(),      DATEDIFF_BIG(MILLISECOND, @StepStartedAt, SYSDATETIME()),      'Succeeded',      NULL,      NULL  );
          RAISERROR(N'[MigrateAll] OK stage %d/16 (pending final commit): %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;        /* Step 16: Finalize vacant buildings after migration */  SET @CurrentStepNumber = 16;  SET @CurrentProcedure =      N'MoveData.usp_FinalizeVacantBuildingActions';  SET @StepStartedAt = SYSDATETIME();
          RAISERROR(N'[MigrateAll] START stage %d/16: %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;    EXEC MoveData.usp_FinalizeVacantBuildingActions      @IdaraId = @IdaraId,      @RollbackAfterTest = 0;    INSERT @ExecutionTiming  VALUES  (      @CurrentStepNumber,      @CurrentProcedure,      @StepStartedAt,      SYSDATETIME(),      DATEDIFF_BIG(          MILLISECOND,          @StepStartedAt,          SYSDATETIME()      ),      'Succeeded',      NULL,      NULL  );
          RAISERROR(N'[MigrateAll] OK stage %d/16 (pending final commit): %s',10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;            SELECT              @RollbackAfterTest [RollbackAfterTest],              @CutoverDate [CutoverDate],              (SELECT COUNT_BIG(*) FROM dbo.MilitaryUnit) [MilitaryUnits],              (SELECT COUNT_BIG(*) FROM Housing.ResidentInfo) [Residents],              (SELECT COUNT_BIG(*) FROM Housing.ResidentContactInfo) [ResidentContacts],              (SELECT COUNT_BIG(*) FROM Housing.BuildingDetails) [Buildings],              (SELECT COUNT_BIG(*) FROM Housing.Meter) [Meters],              (SELECT COUNT_BIG(*) FROM Housing.MeterRead) [MeterReads],              (SELECT COUNT_BIG(*) FROM Housing.BuildingAction) [BuildingActions],              (SELECT COUNT_BIG(*) FROM Housing.AssignPeriod               WHERE AssignPeriodDescrption LIKE N'Legacy allocation migration - WaitingClass %') [AssignPeriods],              (SELECT COUNT_BIG(*) FROM Housing.ExtendInsurance) [ExtendInsurance],             (SELECT COUNT_BIG(*) FROM Housing.OccupantCustodyAction) [OccupantCustodyActions],             (SELECT COUNT_BIG(*) FROM Housing.Bills WHERE BillChargeTypeID_FK=1) [RentBills],              (SELECT COUNT_BIG(*) FROM Housing.Bills WHERE BillChargeTypeID_FK=2) [ElectricBills],              (SELECT COUNT_BIG(*) FROM Housing.Bills WHERE BillChargeTypeID_FK=3) [WaterBills],              (SELECT COUNT_BIG(*) FROM Housing.Bills WHERE BillChargeTypeID_FK=5) [PenaltyBills],              (SELECT COUNT_BIG(*) FROM Housing.BuildingPayment WHERE BillChargeTypeID_FK=1) [RentPayments],              (SELECT COUNT_BIG(*) FROM Housing.BuildingPayment WHERE BillChargeTypeID_FK=2) [ElectricPayments],              (SELECT COUNT_BIG(*) FROM Housing.BuildingPayment WHERE BillChargeTypeID_FK=5) [PenaltyPayments];            SELECT              chargeType.BillChargeTypeID,              chargeType.BillChargeTypeName_A,              ISNULL(bills.TotalBills,0) [TotalBills],              ISNULL(payments.TotalPayments,0) [TotalPayments],              ISNULL(bills.TotalBills,0)-ISNULL(payments.TotalPayments,0) [Remaining]          FROM Housing.BillChargeType chargeType          LEFT JOIN          (              SELECT BillChargeTypeID_FK,SUM(TotalPrice) TotalBills              FROM Housing.Bills WHERE BillActive=1 GROUP BY BillChargeTypeID_FK          ) bills ON bills.BillChargeTypeID_FK=chargeType.BillChargeTypeID          LEFT JOIN          (              SELECT paymentRow.BillChargeTypeID_FK,SUM(paymentRow.amount) TotalPayments              FROM Housing.BuildingPayment paymentRow              JOIN Housing.DeductList deductRow                ON deductRow.deductListID=paymentRow.deductListID_FK              WHERE paymentRow.buildingPayementActive=1                AND deductRow.deductActive=1                AND paymentRow.buildingPaymentLinkStatusID_FK=1              GROUP BY paymentRow.BillChargeTypeID_FK          ) payments ON payments.BillChargeTypeID_FK=chargeType.BillChargeTypeID          WHERE chargeType.BillChargeTypeID IN (1,2,3,5)          ORDER BY chargeType.BillChargeTypeID;            SELECT linkStatus.buildingPaymentLinkStatusID,                 linkStatus.buildingPaymentLinkStatusName_A,                 COUNT_BIG(paymentRow.paymentID) PaymentCount,                 ISNULL(SUM(paymentRow.amount),0) PaymentTotal          FROM Housing.BuildingPaymentLinkStatus linkStatus          LEFT JOIN Housing.BuildingPayment paymentRow            ON paymentRow.buildingPaymentLinkStatusID_FK=linkStatus.buildingPaymentLinkStatusID           AND paymentRow.buildingPayementActive=1          GROUP BY linkStatus.buildingPaymentLinkStatusID,                   linkStatus.buildingPaymentLinkStatusName_A          ORDER BY linkStatus.buildingPaymentLinkStatusID;            /* تفصيل التصنيف المالي حسب نوع المطالبة؛ مهم لمراجعة الحالات 2 و3 و4. */          SELECT              paymentRow.BillChargeTypeID_FK,              chargeType.BillChargeTypeName_A,              paymentRow.buildingPaymentLinkStatusID_FK,              linkStatus.buildingPaymentLinkStatusName_A,              COUNT_BIG(*) PaymentCount,              SUM(paymentRow.amount) PaymentTotal          FROM Housing.BuildingPayment paymentRow          LEFT JOIN Housing.BillChargeType chargeType            ON chargeType.BillChargeTypeID=paymentRow.BillChargeTypeID_FK          LEFT JOIN Housing.BuildingPaymentLinkStatus linkStatus            ON linkStatus.buildingPaymentLinkStatusID=paymentRow.buildingPaymentLinkStatusID_FK          WHERE paymentRow.buildingPayementActive=1          GROUP BY paymentRow.BillChargeTypeID_FK,                   chargeType.BillChargeTypeName_A,                   paymentRow.buildingPaymentLinkStatusID_FK,                   linkStatus.buildingPaymentLinkStatusName_A          ORDER BY paymentRow.BillChargeTypeID_FK,                   paymentRow.buildingPaymentLinkStatusID_FK;            /* يفسر الفرق بين إجمالي كهرباء المصدر والإجمالي المالي النشط. */          SELECT              BillActive,              COUNT_BIG(*) ElectricBillCount,              SUM(TotalPrice) ElectricBillTotal          FROM Housing.Bills          WHERE BillChargeTypeID_FK=2          GROUP BY BillActive          ORDER BY BillActive DESC;            IF @RollbackAfterTest=1
            BEGIN
                ROLLBACK TRANSACTION;
                UPDATE @ExecutionTiming SET ExecutionStatus='TestRolledBack'
                WHERE ExecutionStatus='Succeeded';
                RAISERROR(N'[MigrateAll] All 16 stages executed. TEST ROLLBACK completed; no migration changes committed.',10,1) WITH NOWAIT;
            END
            ELSE
            BEGIN
                COMMIT TRANSACTION;
                RAISERROR(N'[MigrateAll] All 16 stages executed and COMMITTED.',10,1) WITH NOWAIT;
            END;            INSERT MoveData.MigrationExecutionLog          (MigrationRunID,StepNumber,ProcedureName,StartedAt,CompletedAt,DurationMilliseconds,ExecutionStatus,ErrorNumber,ErrorMessage,IdaraId,CutoverDate,RollbackAfterTest)          SELECT @MigrationRunID,StepNumber,ProcedureName,StartedAt,CompletedAt,DurationMilliseconds,ExecutionStatus,ErrorNumber,ErrorMessage,@IdaraId,@CutoverDate,@RollbackAfterTest          FROM @ExecutionTiming;            SELECT StepNumber,ProcedureName,StartedAt,CompletedAt,DurationMilliseconds,                 CONVERT(decimal(18,2),DurationMilliseconds/1000.0) DurationSeconds,                 ExecutionStatus,ErrorNumber,ErrorMessage          FROM @ExecutionTiming ORDER BY StepNumber;      END TRY
      BEGIN CATCH
          DECLARE @ErrorNumber int=ERROR_NUMBER(),
                  @ErrorMessage nvarchar(4000)=ERROR_MESSAGE(),
                  @ErrorProcedure sysname=ERROR_PROCEDURE(),
                  @ErrorLine int=ERROR_LINE();

          IF XACT_STATE()<>0 ROLLBACK TRANSACTION;

          /* A pre-rollback OK is not a committed migration. */
          UPDATE @ExecutionTiming SET ExecutionStatus='RolledBack'
          WHERE ExecutionStatus='Succeeded';

          IF @CurrentProcedure IS NOT NULL
             AND NOT EXISTS(SELECT 1 FROM @ExecutionTiming WHERE StepNumber=@CurrentStepNumber)
          BEGIN
              INSERT @ExecutionTiming
                (StepNumber,ProcedureName,StartedAt,CompletedAt,DurationMilliseconds,
                 ExecutionStatus,ErrorNumber,ErrorMessage)
              VALUES
                (@CurrentStepNumber,@CurrentProcedure,
                 COALESCE(@StepStartedAt,SYSDATETIME()),SYSDATETIME(),
                 DATEDIFF_BIG(MILLISECOND,COALESCE(@StepStartedAt,SYSDATETIME()),SYSDATETIME()),
                 'Failed',@ErrorNumber,@ErrorMessage);
          END;

          RAISERROR(N'[MigrateAll] STOPPED at stage %d/16: %s. Transaction rolled back.',
                    10,1,@CurrentStepNumber,@CurrentProcedure) WITH NOWAIT;

          /* Logging failure must not replace the original migration error. */
          BEGIN TRY
              INSERT MoveData.MigrationExecutionLog
                (MigrationRunID,StepNumber,ProcedureName,StartedAt,CompletedAt,
                 DurationMilliseconds,ExecutionStatus,ErrorNumber,ErrorMessage,
                 IdaraId,CutoverDate,RollbackAfterTest)
              SELECT @MigrationRunID,StepNumber,ProcedureName,StartedAt,CompletedAt,
                     DurationMilliseconds,ExecutionStatus,ErrorNumber,ErrorMessage,
                     @IdaraId,@CutoverDate,@RollbackAfterTest
              FROM @ExecutionTiming;
          END TRY
          BEGIN CATCH
              RAISERROR(N'[MigrateAll] WARNING: execution log write failed after rollback.',10,1) WITH NOWAIT;
          END CATCH;

          SELECT @MigrationRunID AS MigrationRunID,
                 N'FAILED_ROLLED_BACK' AS FinalStatus,
                 @CurrentStepNumber AS FailedStepNumber,
                 @CurrentProcedure AS FailedStepProcedure,
                 @ErrorNumber AS ErrorNumber,
                 @ErrorMessage AS ErrorMessage,
                 @ErrorProcedure AS ErrorProcedure,
                 @ErrorLine AS ErrorLine,
                 @@TRANCOUNT AS OpenTransactions;

          SELECT StepNumber,ProcedureName,StartedAt,CompletedAt,
                 DurationMilliseconds,
                 CONVERT(decimal(18,2),DurationMilliseconds/1000.0) AS DurationSeconds,
                 ExecutionStatus,ErrorNumber,ErrorMessage
          FROM @ExecutionTiming ORDER BY StepNumber;

          /* Full list of known business-rule violations, collected before rollback. */
          IF EXISTS (SELECT 1 FROM @DuplicateGateFindings)
          BEGIN
              SELECT GeneralNo,EffectiveClassID,EffectiveIdaraID,
                     PendingCount,OccupiedCount,TotalActiveRoots,
                     N'تكرار تسجيل انتظار غير محسوم في الفئة والإدارة نفسها' AS FailureReason
              FROM @DuplicateGateFindings
              ORDER BY GeneralNo,EffectiveClassID,EffectiveIdaraID;
          END;

          /* Critical: preserve original SQL error and stop all downstream stages. */
          THROW;
      END CATCH;
  END;

GO

