CREATE PROCEDURE [Housing].[GenerateExitServiceBillsForRequest]
(
      @Action NVARCHAR(20)
    , @ResidentInfoID BIGINT
    , @GeneralNo BIGINT
    , @BuildingDetailsID BIGINT
    , @ExitDate DATE
    , @IdaraID BIGINT
    , @EntryData NVARCHAR(20)
    , @HostName NVARCHAR(200)
    , @OccupentDate DATE = NULL
    , @ExitRequestActionID BIGINT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    -- EXIT_SERVICE_GENERATE_V1: PREVIEW unchanged; only registered cycle fixed/estimate GENERATE enabled.
    -- Reading meters are excluded. REGENERATE and CANCEL deliberately remain disabled.
    IF @Action IS NULL OR @Action NOT IN (N'PREVIEW',N'GENERATE',N'CANCEL',N'REGENERATE')
        THROW 50001, N'المسموح حاليًا معاينة الخدمة أو إصدارها للدورة الجديدة؛ التعديل والإلغاء غير مفعلين.', 1;
    IF @Action IN (N'GENERATE',N'CANCEL',N'REGENERATE')
    BEGIN
        IF @ExitRequestActionID IS NULL OR @OccupentDate IS NULL OR @GeneralNo IS NULL
            THROW 50001, N'رقم دورة الإخلاء وتاريخ الإشغال والرقم العام مطلوبة لإصدار الفاتورة.', 1;
    END;
    IF @ExitDate IS NULL OR @BuildingDetailsID IS NULL
       OR @ResidentInfoID IS NULL OR @IdaraID IS NULL
       OR @ExitDate < CONVERT(DATE, '19000101',112)
        THROW 50001, N'بيانات معاينة خدمات الإخلاء غير صحيحة.', 1;
    IF @OccupentDate IS NOT NULL AND @OccupentDate > @ExitDate
        THROW 50001, N'تاريخ الإشغال لا يمكن أن يلي تاريخ الإخلاء.', 1;
    IF NOT EXISTS (SELECT 1 FROM Housing.BuildingDetails bd
                   WHERE bd.buildingDetailsID=@BuildingDetailsID
                     AND bd.IdaraId_FK=@IdaraID)
        THROW 50001, N'المبنى غير مرتبط بالإدارة المطلوبة.', 1;
    -- EXIT_SERVICE_CANCEL_V1_BEGIN
    -- CANCEL is for registered new cycles only; only this module's estimated/fixed bills.
    -- Legacy/reading-meter invoices are never updated here.
    IF @Action = N'CANCEL'
    BEGIN
        SET XACT_ABORT ON;
        DECLARE @CancelStartingTran INT = @@TRANCOUNT;
        BEGIN TRY
            IF @CancelStartingTran = 0 BEGIN TRANSACTION;

            DECLARE @CancelLockResource NVARCHAR(255) =
                CONCAT(N'ExitServiceCycle:', @IdaraID, N':', @ResidentInfoID, N':', @BuildingDetailsID);
            DECLARE @CancelLockResult INT;
            EXEC @CancelLockResult = sys.sp_getapplock
                 @Resource = @CancelLockResource,
                 @LockMode = N'Exclusive',
                 @LockOwner = N'Transaction',
                 @LockTimeout = 15000;
            IF @CancelLockResult < 0
                THROW 50001, N'تعذر حجز عملية إلغاء خدمات الإخلاء.', 1;

            IF @EntryData IS NULL OR LTRIM(RTRIM(@EntryData)) = N''
                THROW 50001, N'هوية منفذ إلغاء فواتير الخدمات مطلوبة.', 1;

            IF NOT EXISTS
            (
                SELECT 1
                FROM Housing.ExitFinancialProcessingCycle c WITH (UPDLOCK,HOLDLOCK)
                JOIN Housing.BuildingAction a WITH (UPDLOCK,HOLDLOCK)
                  ON a.buildingActionID = c.ExitRequestActionID_FK
                WHERE c.ExitRequestActionID_FK = @ExitRequestActionID
                  AND c.ProcessingVersion = 1
                  AND a.buildingActionTypeID_FK = 54
                  AND a.buildingActionActive = 1
                  AND a.residentInfoID_FK = @ResidentInfoID
                  AND a.generalNo_FK = @GeneralNo
                  AND a.buildingDetailsID_FK = @BuildingDetailsID
                  AND a.IdaraId_FK = @IdaraID
                  AND CONVERT(date,a.OccupentDate) = @OccupentDate
                  AND CONVERT(date,a.ExitDate) = @ExitDate
            )
                THROW 50001, N'دورة إخلاء الخدمات غير مسجلة أو بياناتها غير مطابقة.', 1;

            IF NOT EXISTS
            (
                SELECT 1 FROM Housing.V_WaitingList w
                WHERE w.residentInfoID = @ResidentInfoID
                  AND w.buildingDetailsID = @BuildingDetailsID
                  AND w.IdaraId = @IdaraID
                  AND CONVERT(date,w.ExitDate) = @ExitDate
                  AND w.LastActionTypeID IN (54,59,60,57,58)
            )
                THROW 50001, N'لا يمكن إلغاء خدمات دورة إخلاء معتمدة نهائيًا أو غير مطابقة.', 1;

            DECLARE @CancelBillIDs TABLE (BillsID BIGINT NOT NULL PRIMARY KEY);
            INSERT INTO @CancelBillIDs (BillsID)
            SELECT b.BillsID
            FROM Housing.Bills b WITH (UPDLOCK,HOLDLOCK)
            JOIN Housing.BillCalculation calc
              ON calc.BillsID_FK = b.BillsID
             AND calc.CalculationMethod IN
                (N'SPACE_ESTIMATED',N'METER_FIXED',N'FIXED_METER',N'SERVICE_FIXED_FALLBACK')
            WHERE b.ExitRequestActionID_FK = @ExitRequestActionID
              AND b.BillTypeID_FK = 3
              AND b.BillChargeTypeID_FK IN (2,3,4)
              AND b.BillActive = 1
              AND b.residentInfoID_FK = @ResidentInfoID
              AND b.generalNo_FK = @GeneralNo
              AND b.buildingDetailsID = @BuildingDetailsID
              AND b.idaraID_FK = @IdaraID;

            -- Fail closed even for inactive historical payment links.
            -- No per-invoice payment map: payments survive canceled claims in the ledger.
IF EXISTS
            (
                SELECT 1 FROM @CancelBillIDs target
                JOIN Housing.ResidentRentExemptionPayment linkRow WITH (UPDLOCK,HOLDLOCK)
                  ON linkRow.billsID_FK = target.BillsID
            )
                THROW 50001, N'فاتورة الخدمة مرتبطة بسداد إعفاء؛ لا يمكن إلغاؤها تلقائيًا.', 1;

            IF EXISTS
            (
                SELECT 1 FROM @CancelBillIDs target
                JOIN Housing.Bills child WITH (UPDLOCK,HOLDLOCK)
                  ON child.ParentBillsID_FK = target.BillsID
            )
                THROW 50001, N'فاتورة الخدمة لها فواتير فرعية؛ لا يمكن إلغاؤها تلقائيًا.', 1;

            DECLARE @ExpectedCancelCount INT = (SELECT COUNT(*) FROM @CancelBillIDs);
            IF @ExpectedCancelCount > 0
            BEGIN
                UPDATE b
                   SET BillActive = 0,
                       CanceledBy = @EntryData,
                       CanceledDate = GETDATE()
                FROM Housing.Bills b
                JOIN @CancelBillIDs target ON target.BillsID = b.BillsID
                WHERE b.BillActive = 1;

                IF @@ROWCOUNT <> @ExpectedCancelCount
                    THROW 50001, N'فشل الإلغاء الذري لفواتير خدمات الإخلاء.', 1;

                INSERT INTO dbo.AuditLog
                   (TableName,ActionType,RecordID,PerformedBy,Notes)
                SELECT N'[Housing].[Bills]',N'CANCELEXITSERVICEBILL',
                       target.BillsID,@EntryData,
                       CONCAT(N'ExitRequestActionID=',CONVERT(NVARCHAR(30),@ExitRequestActionID))
                FROM @CancelBillIDs target;
            END;

            IF @CancelStartingTran = 0 COMMIT TRANSACTION;
            RETURN;
        END TRY
        BEGIN CATCH
            IF @CancelStartingTran = 0 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
            THROW;
        END CATCH;
    END;
    -- EXIT_SERVICE_CANCEL_V1_END

    -- EXIT_SERVICE_REGENERATE_V1_BEGIN
    -- REGENERATE = CANCEL + GENERATE as a single atomic operation.
    -- No reading-meter invoices are created or modified by this action.
    IF @Action = N'REGENERATE'
    BEGIN
        SET XACT_ABORT ON;
        DECLARE @RegenInitialTranCount INT = @@TRANCOUNT;
        BEGIN TRY
            IF @RegenInitialTranCount = 0 BEGIN TRANSACTION;

            DECLARE @RegenAppLockResource NVARCHAR(255) =
                CONCAT(N'ExitServiceCycle:',@IdaraID,N':',@ResidentInfoID,N':',@BuildingDetailsID);
            DECLARE @RegenAppLockResult INT;
            EXEC @RegenAppLockResult = sys.sp_getapplock
                 @Resource=@RegenAppLockResource,
                 @LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=15000;
            IF @RegenAppLockResult < 0
                THROW 50001,N'تعذر حجز دورة إعادة إصدار خدمات الإخلاء.',1;

            IF @EntryData IS NULL OR NULLIF(LTRIM(RTRIM(@EntryData)),N'') IS NULL
                THROW 50001,N'هوية منفذ إعادة إصدار الخدمات مطلوبة.',1;

            IF NOT EXISTS
            (
                SELECT 1 FROM Housing.ExitFinancialProcessingCycle c WITH (UPDLOCK,HOLDLOCK)
                JOIN Housing.BuildingAction a WITH (UPDLOCK,HOLDLOCK)
                  ON a.buildingActionID=c.ExitRequestActionID_FK
                WHERE c.ExitRequestActionID_FK=@ExitRequestActionID
                  AND c.ProcessingVersion=1
                  AND a.buildingActionTypeID_FK=54 AND a.buildingActionActive=1
                  AND a.residentInfoID_FK=@ResidentInfoID
                  AND a.generalNo_FK=@GeneralNo
                  AND a.buildingDetailsID_FK=@BuildingDetailsID
                  AND a.IdaraId_FK=@IdaraID
                  AND CONVERT(date,a.OccupentDate)=@OccupentDate
                  AND CONVERT(date,a.ExitDate)=@ExitDate
            )
                THROW 50001,N'دورة إخلاء الخدمات غير مسجلة أو بياناتها غير مطابقة.',1;

            IF NOT EXISTS
            (
                SELECT 1 FROM Housing.V_WaitingList w
                WHERE w.residentInfoID=@ResidentInfoID
                  AND w.buildingDetailsID=@BuildingDetailsID
                  AND w.IdaraId=@IdaraID
                  AND CONVERT(date,w.ExitDate)=@ExitDate
                  AND w.LastActionTypeID IN (54,59,60)
            )
                THROW 50001,N'لا يمكن إعادة إصدار خدمات الإخلاء بعد إحالتها للتدقيق المالي.',1;

            IF NOT EXISTS
            (
                SELECT 1 FROM Housing.Bills b WITH (UPDLOCK,HOLDLOCK)
                JOIN Housing.BillCalculation calc ON calc.BillsID_FK=b.BillsID
                  AND calc.CalculationMethod IN
                     (N'SPACE_ESTIMATED',N'METER_FIXED',N'FIXED_METER',N'SERVICE_FIXED_FALLBACK')
                WHERE b.ExitRequestActionID_FK=@ExitRequestActionID
                  AND b.BillTypeID_FK=3
                  AND b.BillChargeTypeID_FK IN (2,3,4)
                  AND b.BillActive=1
                  AND b.residentInfoID_FK=@ResidentInfoID
                  AND b.generalNo_FK=@GeneralNo
                  AND b.buildingDetailsID=@BuildingDetailsID
                  AND b.idaraID_FK=@IdaraID
            )
                THROW 50001,N'لا توجد فواتير خدمات إخلاء نشطة لإعادة إصدارها.',1;

            -- Both inner actions share this transaction and application lock.
            -- If GENERATE fails, the CANCEL is rolled back with it.
            EXEC Housing.GenerateExitServiceBillsForRequest
                 @Action=N'CANCEL',
                 @ResidentInfoID=@ResidentInfoID,@GeneralNo=@GeneralNo,
                 @BuildingDetailsID=@BuildingDetailsID,@ExitDate=@ExitDate,
                 @IdaraID=@IdaraID,@EntryData=@EntryData,@HostName=@HostName,
                 @OccupentDate=@OccupentDate,@ExitRequestActionID=@ExitRequestActionID;

            EXEC Housing.GenerateExitServiceBillsForRequest
                 @Action=N'GENERATE',
                 @ResidentInfoID=@ResidentInfoID,@GeneralNo=@GeneralNo,
                 @BuildingDetailsID=@BuildingDetailsID,@ExitDate=@ExitDate,
                 @IdaraID=@IdaraID,@EntryData=@EntryData,@HostName=@HostName,
                 @OccupentDate=@OccupentDate,@ExitRequestActionID=@ExitRequestActionID;

            IF @RegenInitialTranCount=0 COMMIT TRANSACTION;
            RETURN;
        END TRY
        BEGIN CATCH
            IF @RegenInitialTranCount=0 AND XACT_STATE()<>0
                ROLLBACK TRANSACTION;
            THROW;
        END CATCH;
    END;
    -- EXIT_SERVICE_REGENERATE_V1_END

    -- PREVIEW does not generate bills and deliberately requires no enrolled cycle.
    -- It is NOT an authorization to perform a financial operation.
    DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@ExitDate),MONTH(@ExitDate),1);
    IF @OccupentDate IS NOT NULL AND @OccupentDate > @MonthStart SET @MonthStart = @OccupentDate;

    IF @ExitDate IS NULL OR @BuildingDetailsID IS NULL OR @ResidentInfoID IS NULL OR @IdaraID IS NULL
        THROW 50001, N'بيانات الفحص ناقصة', 1;

    IF OBJECT_ID('tempdb..#ExitServiceDayPreview') IS NOT NULL DROP TABLE #ExitServiceDayPreview;

    ;WITH Days AS
    (
        SELECT @MonthStart AS BillDay
        UNION ALL
        SELECT DATEADD(DAY,1,BillDay) FROM Days WHERE BillDay < @ExitDate
    )
    SELECT
          d.BillDay
        , st.meterServiceTypeID AS ServiceID
        , st.meterServiceTypeName_A AS ServiceName
        , CONVERT(INT,CASE WHEN dept.HasLink=1 THEN 1 ELSE 0 END) AS LinkedToIdara
        , CONVERT(INT,CASE WHEN service.HasLink=1 THEN 1 ELSE 0 END) AS LinkedToBuilding
        , ISNULL(reading.CountMeters,0) AS ReadingMeters
        , ISNULL(fixed.CountMeters,0) AS FixedMeters
        , selectedPolicy.EstimatedBillingPolicyID AS SelectedPolicyID
        , ISNULL(spaces.MatchedSpaces,0) AS EligibleSpaces
        , ISNULL(fallback.CountRates,0) AS FixedFallbackRates
        , ISNULL(existingBill.CountBills,0) AS ExistingActiveBillsForDay
        , CONVERT(VARCHAR(25),CASE
            WHEN dept.HasLink IS NULL THEN 'NOT_LINKED_TO_IDARA'
            WHEN reading.CountMeters > 0 THEN 'READING_METER'
            WHEN fixed.CountMeters > 0 THEN 'FIXED_METER'
            WHEN service.HasLink IS NULL THEN 'NOT_LINKED_TO_BUILDING'
            WHEN spaces.MatchedSpaces > 0 THEN 'SPACE_ESTIMATED'
            WHEN fallback.CountRates > 0 THEN 'SERVICE_FIXED_FALLBACK'
            ELSE 'NO_ELIGIBLE_RATE' END) AS ProposedMethod
    INTO #ExitServiceDayPreview
    FROM Days d
    CROSS JOIN Housing.MeterServiceType st
    OUTER APPLY
    (
        SELECT TOP (1) 1 AS HasLink
        FROM Housing.MeterServiceTypeLinkedWithIdara il
        WHERE il.MeterServiceTypeID_FK=st.meterServiceTypeID
          AND (il.Idara_FK=@IdaraID OR il.Idara_FK IS NULL)
          AND (il.MeterServiceTypeLinkedWithIdaraActive=1 OR il.MeterServiceTypeLinkedWithIdaraEndDate IS NOT NULL)
          AND (il.MeterServiceTypeLinkedWithIdaraStartDate IS NULL OR CONVERT(date,il.MeterServiceTypeLinkedWithIdaraStartDate)<=d.BillDay)
          AND (il.MeterServiceTypeLinkedWithIdaraEndDate IS NULL OR CONVERT(date,il.MeterServiceTypeLinkedWithIdaraEndDate)>=d.BillDay)
    ) dept
    OUTER APPLY
    (
        SELECT TOP(1) 1 AS HasLink
        FROM Housing.BuildingDetailsMeterServices s
        WHERE s.BuildingDetailsID_FK=@BuildingDetailsID
          AND s.IdaraId_FK=@IdaraID
          AND s.MeterServicesTypeID_FK=st.meterServiceTypeID
          AND (s.BuildingDetailsMeterServicesActive=1 OR s.BuildingDetailsMeterServicesEndDate IS NOT NULL)
          AND (s.BuildingDetailsMeterServicesStartDate IS NULL OR CONVERT(date,s.BuildingDetailsMeterServicesStartDate)<=d.BillDay)
          AND (s.BuildingDetailsMeterServicesEndDate IS NULL OR CONVERT(date,s.BuildingDetailsMeterServicesEndDate)>=d.BillDay)
    ) service
    OUTER APPLY
    (
        SELECT COUNT(*) AS CountMeters
        FROM Housing.MeterForBuilding link
        JOIN Housing.Meter m ON m.meterID=link.meterID_FK
        JOIN Housing.MeterType mt ON mt.meterTypeID=m.meterTypeID_FK
        WHERE link.buildingDetailsID_FK=@BuildingDetailsID
          AND link.IdaraID_FK=@IdaraID
          AND link.meterForBuildingActive=1 AND m.meterActive=1 AND mt.meterTypeActive=1
          AND mt.IdaraId_FK=@IdaraID
          AND mt.meterServiceTypeID_FK=st.meterServiceTypeID
          AND mt.MeterCalculateTypeID_FK=1
          AND (link.meterForBuildingStartDate IS NULL OR CONVERT(date,link.meterForBuildingStartDate)<=d.BillDay)
          AND (link.meterForBuildingEndDate IS NULL OR CONVERT(date,link.meterForBuildingEndDate)>=d.BillDay)
          AND (m.meterStartDate IS NULL OR CONVERT(date,m.meterStartDate)<=d.BillDay)
          AND (m.meterEndDate IS NULL OR CONVERT(date,m.meterEndDate)>=d.BillDay)
    ) reading
    OUTER APPLY
    (
        SELECT COUNT(*) AS CountMeters
        FROM Housing.MeterForBuilding link
        JOIN Housing.Meter m ON m.meterID=link.meterID_FK
        JOIN Housing.MeterType mt ON mt.meterTypeID=m.meterTypeID_FK
        WHERE link.buildingDetailsID_FK=@BuildingDetailsID
          AND link.IdaraID_FK=@IdaraID
          AND link.meterForBuildingActive=1 AND m.meterActive=1 AND mt.meterTypeActive=1
          AND mt.IdaraId_FK=@IdaraID
          AND mt.meterServiceTypeID_FK=st.meterServiceTypeID
          AND mt.MeterCalculateTypeID_FK=2
          AND (link.meterForBuildingStartDate IS NULL OR CONVERT(date,link.meterForBuildingStartDate)<=d.BillDay)
          AND (link.meterForBuildingEndDate IS NULL OR CONVERT(date,link.meterForBuildingEndDate)>=d.BillDay)
          AND (m.meterStartDate IS NULL OR CONVERT(date,m.meterStartDate)<=d.BillDay)
          AND (m.meterEndDate IS NULL OR CONVERT(date,m.meterEndDate)>=d.BillDay)
    ) fixed
    OUTER APPLY
    (
        SELECT TOP(1) p.EstimatedBillingPolicyID
        FROM Housing.EstimatedBillingPolicy p
        WHERE p.EstimatedBillingPolicyActive=1
          AND (p.IdaraID_FK=@IdaraID OR p.IdaraID_FK IS NULL)
          AND p.EffectiveFrom<=d.BillDay
          AND (p.EffectiveTo IS NULL OR p.EffectiveTo>=d.BillDay)
        ORDER BY CASE WHEN p.IdaraID_FK=@IdaraID THEN 0 ELSE 1 END,
                 p.EffectiveFrom DESC,p.EstimatedBillingPolicyID DESC
    ) selectedPolicy
    OUTER APPLY
    (
        /* An eligible space overlapping ANY part of this period qualifies as an input.
           The future billing engine must preserve the user's whole-period rule. */
        SELECT COUNT(*) AS MatchedSpaces
        FROM Housing.BuildingSpace sp
        JOIN Housing.EstimatedBillingPolicyDetails policyRule
          ON policyRule.BuildingSpaceTypeID_FK=sp.BuildingSpaceTypeID_FK
         AND policyRule.MeterServiceTypeID_FK=st.meterServiceTypeID
         AND policyRule.EstimatedBillingPolicyID_FK=selectedPolicy.EstimatedBillingPolicyID
         AND policyRule.EstimatedBillingPolicyDetailsActive=1
        WHERE sp.BuildingDetailsID_FK=@BuildingDetailsID AND sp.BuildingSpaceActive=1
          AND (sp.BuildingSpaceStartDate IS NULL OR CONVERT(date,sp.BuildingSpaceStartDate)<=@ExitDate)
          AND (sp.BuildingSpaceEndDate IS NULL OR CONVERT(date,sp.BuildingSpaceEndDate)>=@MonthStart)
    ) spaces
    OUTER APPLY
    (
        SELECT COUNT(*) AS CountRates
        FROM Housing.MeterServiceTypeFixedAmount amount
        WHERE amount.MeterServiceTypeID_FK=st.meterServiceTypeID
          AND (amount.idaraID_FK=@IdaraID OR amount.idaraID_FK IS NULL)
          AND amount.FixedAmount>0
          AND (amount.MeterServiceTypeFixedAmountActive=1 OR amount.MeterServiceTypeFixedAmountEndDate IS NOT NULL)
          AND (amount.MeterServiceTypeFixedAmountStartDate IS NULL OR CONVERT(date,amount.MeterServiceTypeFixedAmountStartDate)<=d.BillDay)
          AND (amount.MeterServiceTypeFixedAmountEndDate IS NULL OR CONVERT(date,amount.MeterServiceTypeFixedAmountEndDate)>=d.BillDay)
    ) fallback
    OUTER APPLY
    (
        SELECT COUNT(*) AS CountBills
        FROM Housing.Bills b
        LEFT JOIN Housing.BillChargeType chargeType
          ON chargeType.BillChargeTypeID=b.BillChargeTypeID_FK
        WHERE b.residentInfoID_FK=@ResidentInfoID
          AND b.buildingDetailsID=@BuildingDetailsID
          AND b.idaraID_FK=@IdaraID
          AND (b.meterServiceTypeID=st.meterServiceTypeID
               OR (b.meterServiceTypeID IS NULL AND chargeType.MeterServiceTypeID_FK=st.meterServiceTypeID))
          AND b.BillActive=1
          AND b.BillChargeTypeID_FK IN (2,3,4)
          AND COALESCE(CONVERT(date,b.BillsFromDate),
                CASE WHEN b.PeriodYear BETWEEN 1753 AND 9999 AND b.PeriodMonth BETWEEN 1 AND 12
                THEN DATEFROMPARTS(b.PeriodYear,b.PeriodMonth,1) END) <=d.BillDay
          AND COALESCE(CONVERT(date,b.BillsToDate),
                CASE WHEN b.PeriodYear BETWEEN 1753 AND 9999 AND b.PeriodMonth BETWEEN 1 AND 12
                THEN EOMONTH(DATEFROMPARTS(b.PeriodYear,b.PeriodMonth,1)) END) >=d.BillDay
    ) existingBill
    WHERE st.meterServiceTypeActive=1
      AND (st.meterServiceTypeStartDate IS NULL OR CONVERT(date,st.meterServiceTypeStartDate)<=d.BillDay)
      AND (st.meterServiceTypeEndDate IS NULL OR CONVERT(date,st.meterServiceTypeEndDate)>=d.BillDay)
    OPTION (MAXRECURSION 40);

    IF @Action = N'PREVIEW'
    BEGIN
    -- Result 1: per-service method and date spans (NO prices or invoice changes).
    ;WITH Numbered AS
    (
        SELECT *, DATEDIFF(DAY,CONVERT(date,'20000101',112),BillDay)
            - ROW_NUMBER() OVER(PARTITION BY ServiceID,ProposedMethod,ISNULL(SelectedPolicyID,-1),
                                          CASE WHEN ExistingActiveBillsForDay>0 THEN 1 ELSE 0 END
                                ORDER BY BillDay) AS IslandKey
        FROM #ExitServiceDayPreview
    )
    SELECT ServiceID,MAX(ServiceName) AS ServiceName,
           MIN(BillDay) AS SegmentStart,MAX(BillDay) AS SegmentEnd,
           ProposedMethod,SelectedPolicyID,
           MAX(ReadingMeters) AS MaxReadingMeters,
           MAX(FixedMeters) AS MaxFixedMeters,
           MAX(EligibleSpaces) AS MaxEligibleSpaces,
           MAX(FixedFallbackRates) AS MaxFallbackRates,
           MAX(ExistingActiveBillsForDay) AS MaxExistingBillsPerDay,
           COUNT(*) AS DaysInSegment
    FROM Numbered
    GROUP BY ServiceID,ProposedMethod,SelectedPolicyID,
             CASE WHEN ExistingActiveBillsForDay>0 THEN 1 ELSE 0 END,IslandKey
    ORDER BY ServiceID,SegmentStart;

    -- Result 2: Any unexpected changes in method/policy within the same exit month.
    SELECT ServiceID,MAX(ServiceName) AS ServiceName,
           COUNT(DISTINCT ProposedMethod) AS DistinctMethods,
           COUNT(DISTINCT ISNULL(SelectedPolicyID,-1)) AS DistinctPolicyIDs,
           SUM(CASE WHEN ExistingActiveBillsForDay>0 THEN 1 ELSE 0 END) AS DaysWithExistingBill,
           SUM(CASE WHEN ProposedMethod IN ('NO_ELIGIBLE_RATE','NOT_LINKED_TO_BUILDING')
                    AND LinkedToIdara=1 THEN 1 ELSE 0 END) AS DaysWithMissingBuildingRate
    FROM #ExitServiceDayPreview
    GROUP BY ServiceID
    ORDER BY ServiceID;

    -- Result 3: Existing service bills overlapping the proposed month, if any.
    SELECT b.BillsID,b.BillTypeID_FK,b.BillChargeTypeID_FK,b.meterServiceTypeID,
           b.BillsFromDate,b.BillsToDate,b.PeriodYear,b.PeriodMonth,
           b.ExitRequestActionID_FK,b.TotalPrice,b.BillActive
    FROM Housing.Bills b
    WHERE b.residentInfoID_FK=@ResidentInfoID
      AND b.buildingDetailsID=@BuildingDetailsID
      AND b.idaraID_FK=@IdaraID
      AND b.BillActive=1 AND b.BillChargeTypeID_FK IN (2,3,4)
      AND COALESCE(CONVERT(date,b.BillsFromDate),
            CASE WHEN b.PeriodYear BETWEEN 1753 AND 9999 AND b.PeriodMonth BETWEEN 1 AND 12
            THEN DATEFROMPARTS(b.PeriodYear,b.PeriodMonth,1) END)<=@ExitDate
      AND COALESCE(CONVERT(date,b.BillsToDate),
            CASE WHEN b.PeriodYear BETWEEN 1753 AND 9999 AND b.PeriodMonth BETWEEN 1 AND 12
            THEN EOMONTH(DATEFROMPARTS(b.PeriodYear,b.PeriodMonth,1)) END)>=@MonthStart
    ORDER BY b.BillsToDate DESC,b.BillsID DESC;

    DROP TABLE #ExitServiceDayPreview;
    RETURN;
    END;

    -- EXIT_SERVICE_GENERATE_V1: never produces a reading-meter invoice.
    -- REGENERATE/CANCEL remain disabled until paid-bill and refund safeguards are implemented.
    IF @Action = N'GENERATE'
    BEGIN
        DECLARE @PriorTranCount INT = @@TRANCOUNT;
        BEGIN TRY
            IF @PriorTranCount = 0 BEGIN TRANSACTION;

            DECLARE @AppLockResult INT;
            DECLARE @AppLockResource NVARCHAR(255) =
                CONCAT(N'ExitServiceCycle:',@IdaraID,N':',@ResidentInfoID,N':',@BuildingDetailsID);
            EXEC @AppLockResult = sys.sp_getapplock
                 @Resource = @AppLockResource
               , @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 15000;
            IF @AppLockResult < 0
                THROW 50001, N'تعذر حجز معالجة خدمات الإخلاء؛ أعد المحاولة.', 1;

            IF NOT EXISTS
            (
                SELECT 1
                FROM Housing.ExitFinancialProcessingCycle c WITH (UPDLOCK, HOLDLOCK)
                JOIN Housing.BuildingAction a WITH (UPDLOCK, HOLDLOCK)
                  ON a.buildingActionID = c.ExitRequestActionID_FK
                WHERE c.ExitRequestActionID_FK = @ExitRequestActionID
                  AND c.ProcessingVersion = 1
                  AND a.buildingActionTypeID_FK = 54 AND a.buildingActionActive = 1
                  AND a.residentInfoID_FK = @ResidentInfoID
                  AND a.buildingDetailsID_FK = @BuildingDetailsID
                  AND a.IdaraId_FK = @IdaraID
                  AND a.generalNo_FK = @GeneralNo
                  AND CONVERT(date,a.ExitDate) = @ExitDate
                  AND CONVERT(date,a.OccupentDate) = @OccupentDate
            )
                THROW 50001, N'دورة الإخلاء الجديدة غير مسجلة أو بياناتها لا تطابق طلب الإخلاء.', 1;

            -- Only before submission for financial audit. Do not write after 57/58/3.
            IF NOT EXISTS
            (
                SELECT 1 FROM Housing.V_WaitingList w
                WHERE w.residentInfoID = @ResidentInfoID
                  AND w.buildingDetailsID = @BuildingDetailsID
                  AND w.IdaraId = @IdaraID
                  AND CONVERT(date,w.ExitDate) = @ExitDate
                  AND w.LastActionTypeID IN (54,59,60)
            )
                THROW 50001, N'لا يسمح بإصدار فواتير الخدمات بعد إحالة الإخلاء للتدقيق المالي.', 1;

            -- EXIT_SERVICE_OWN_OUTPUT_GUARD_V2: reading-meter bills do not
             -- block eligible non-meter exit services. Unknown active output
             -- must be examined by the separate overlap/eligibility checks.
             IF EXISTS (
                 SELECT 1
                 FROM Housing.Bills b WITH (UPDLOCK, HOLDLOCK)
                 INNER JOIN Housing.BillCalculation calc
                     ON calc.BillsID_FK = b.BillsID
                    AND calc.CalculationMethod IN
                        (N'SPACE_ESTIMATED', N'METER_FIXED', N'SERVICE_FIXED_FALLBACK')
                 WHERE b.ExitRequestActionID_FK = @ExitRequestActionID
                   AND b.BillTypeID_FK = 3
                   AND b.BillChargeTypeID_FK IN (2,3,4)
                   AND b.BillActive = 1
                   AND b.residentInfoID_FK = @ResidentInfoID
                   AND b.generalNo_FK = @GeneralNo
                   AND b.buildingDetailsID = @BuildingDetailsID
                   AND b.idaraID_FK = @IdaraID
             )
                 THROW 50001, N'تم إصدار خدمات الإخلاء لهذه الدورة مسبقًا؛ يمنع إصدارها مرتين.', 1;
 
             -- Fail closed on unclassified active cycle service bills. Only a
             -- proven reading-meter invoice or known exit-service output is accepted.
             IF EXISTS (
                 SELECT 1
                 FROM Housing.Bills b WITH (UPDLOCK, HOLDLOCK)
                 WHERE b.ExitRequestActionID_FK = @ExitRequestActionID
                   AND b.BillChargeTypeID_FK IN (2,3,4)
                   AND b.BillActive = 1
                   AND NOT EXISTS (
                       SELECT 1
                       FROM Housing.Meter meter
                       INNER JOIN Housing.MeterType meterType
                           ON meterType.meterTypeID = meter.meterTypeID_FK
                       WHERE meter.meterID = b.meterID
                         AND meterType.MeterCalculateTypeID_FK = 1
                         AND meterType.meterServiceTypeID_FK = b.meterServiceTypeID
                   )
                   AND NOT EXISTS (
                       SELECT 1
                       FROM Housing.BillCalculation knownCalc
                       WHERE knownCalc.BillsID_FK = b.BillsID
                         AND knownCalc.CalculationMethod IN
                             (N'SPACE_ESTIMATED', N'METER_FIXED', N'SERVICE_FIXED_FALLBACK')
                   )
             )
                 THROW 50001, N'توجد فاتورة خدمة لدورة الإخلاء غير مصنفة كقراءة عداد أو خدمة إخلاء؛ يلزم مراجعتها.', 1;

            DECLARE @DaysInWindow INT = DATEDIFF(DAY,@MonthStart,@ExitDate)+1;
            DECLARE @BillingDays INT =
                  (YEAR(@ExitDate) - YEAR(@MonthStart)) * 360
                + (MONTH(@ExitDate) - MONTH(@MonthStart)) * 30
                + CASE WHEN @ExitDate = EOMONTH(@ExitDate) AND DAY(@ExitDate)<30 THEN 30
                       WHEN DAY(@ExitDate)>30 THEN 30 ELSE DAY(@ExitDate) END
                - CASE WHEN @MonthStart = EOMONTH(@MonthStart) AND DAY(@MonthStart)<30 THEN 30
                       WHEN DAY(@MonthStart)>30 THEN 30 ELSE DAY(@MonthStart) END + 1;
            IF @BillingDays NOT BETWEEN 1 AND 30
                THROW 50001, N'مدة احتساب خدمات الإخلاء غير صحيحة.', 1;

            -- Any active reading meter in the period excludes that entire service from THIS engine.
            -- Reading meter invoices remain owned by MeterReadForOccubentAndExitSP.
            CREATE TABLE #ServiceSummary
            (
                ServiceID INT NOT NULL PRIMARY KEY,
                Method VARCHAR(25) NOT NULL,
                PolicyID BIGINT NULL,
                ReadingDays INT NOT NULL,
                EligibleDays INT NOT NULL,
                DistinctMethods INT NOT NULL,
                DistinctPolicies INT NOT NULL
            );
            INSERT INTO #ServiceSummary
            SELECT ServiceID,MAX(ProposedMethod),MAX(SelectedPolicyID),
                   SUM(CASE WHEN ReadingMeters>0 THEN 1 ELSE 0 END),
                   SUM(CASE WHEN ProposedMethod IN
                         ('FIXED_METER','SPACE_ESTIMATED','SERVICE_FIXED_FALLBACK')
                         THEN 1 ELSE 0 END),
                   COUNT(DISTINCT ProposedMethod),
                   COUNT(DISTINCT ISNULL(SelectedPolicyID,-1))
            FROM #ExitServiceDayPreview GROUP BY ServiceID;

            IF EXISTS
            (
                SELECT 1 FROM #ServiceSummary s
                WHERE s.ReadingDays = 0 AND s.EligibleDays > 0
                  AND (s.EligibleDays <> @DaysInWindow OR s.DistinctMethods <> 1
                       OR (s.Method = 'SPACE_ESTIMATED' AND s.DistinctPolicies <> 1))
            )
                THROW 50001, N'تغيرت طريقة فوترة الخدمة خلال فترة الإخلاء؛ يلزم تقسيم الفترة قبل إصدار الفاتورة.', 1;

            IF EXISTS
            (
                SELECT 1 FROM #ExitServiceDayPreview
                WHERE LinkedToIdara=1 AND LinkedToBuilding=1
                  AND ReadingMeters=0 AND ProposedMethod='NO_ELIGIBLE_RATE'
            )
                THROW 50001, N'توجد خدمة مفعلة للمبنى دون تعرفة مؤهلة؛ لا يجوز إصدار حساب ناقص.', 1;

            -- No reading-meters: a previously issued overlapping active invoice for this
            -- resident/building/service blocks the new bill; old paid invoices are immutable.
            IF EXISTS
            (
                SELECT 1 FROM #ServiceSummary s
                JOIN Housing.Bills b WITH (UPDLOCK,HOLDLOCK)
                  ON b.residentInfoID_FK=@ResidentInfoID AND b.buildingDetailsID=@BuildingDetailsID
                 AND b.idaraID_FK=@IdaraID AND b.BillActive=1
                LEFT JOIN Housing.BillChargeType ct ON ct.BillChargeTypeID=b.BillChargeTypeID_FK
                WHERE s.ReadingDays=0 AND s.EligibleDays>0
                  AND (b.meterServiceTypeID=s.ServiceID
                       OR (b.meterServiceTypeID IS NULL AND ct.MeterServiceTypeID_FK=s.ServiceID))
                  AND b.BillChargeTypeID_FK IN (2,3,4)
                  AND (
                    (COALESCE(CONVERT(date,b.BillsFromDate),
                       CASE WHEN b.PeriodYear BETWEEN 1900 AND 9999 AND b.PeriodMonth BETWEEN 1 AND 12
                            THEN DATEFROMPARTS(b.PeriodYear,b.PeriodMonth,1) END) <= @ExitDate
                     AND
                     COALESCE(CONVERT(date,b.BillsToDate),
                       CASE WHEN b.PeriodYear BETWEEN 1900 AND 9999 AND b.PeriodMonth BETWEEN 1 AND 12
                            THEN EOMONTH(DATEFROMPARTS(b.PeriodYear,b.PeriodMonth,1)) END) >= @MonthStart)
                    OR (b.BillsFromDate IS NULL AND b.BillsToDate IS NULL
                        AND (b.PeriodYear IS NULL OR b.PeriodMonth NOT BETWEEN 1 AND 12))
                  )
            )
                THROW 50001, N'توجد فاتورة خدمة نشطة متداخلة مع فترة الإخلاء؛ يمنع إصدار فاتورة مكررة.', 1;

            DECLARE @TaxID INT=NULL, @TaxRatePercent DECIMAL(18,6)=NULL;
            SELECT TOP (1) @TaxID=t.taxID, @TaxRatePercent=t.taxRate
            FROM dbo.Tax t
            WHERE t.taxActive=1 AND CONVERT(date,t.taxStartDate)<=@ExitDate
              AND (t.taxEndDate IS NULL OR CONVERT(date,t.taxEndDate)>=@ExitDate)
            ORDER BY t.taxStartDate DESC,t.taxID DESC;

            CREATE TABLE #BillTargets
            (
                TargetID INT IDENTITY(1,1) PRIMARY KEY,
                ServiceID INT NOT NULL,
                Method VARCHAR(25) NOT NULL,
                ChargeTypeID INT NOT NULL,
                PolicyID BIGINT NULL,
                MeterID BIGINT NULL,
                MeterTypeID INT NULL,
                MeterNo NVARCHAR(100) NULL,
                MeterName NVARCHAR(200) NULL,
                FixedAmount DECIMAL(18,2) NULL,
                TaxApplicable BIT NOT NULL,
                TaxInclusive BIT NOT NULL
            );

            DECLARE @ServiceID INT, @Method VARCHAR(25), @PolicyID BIGINT;
            DECLARE ServiceCursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT ServiceID,Method,PolicyID
                FROM #ServiceSummary
                WHERE ReadingDays=0 AND EligibleDays=@DaysInWindow
                  AND Method IN ('FIXED_METER','SPACE_ESTIMATED','SERVICE_FIXED_FALLBACK')
                ORDER BY ServiceID;
            OPEN ServiceCursor;
            FETCH NEXT FROM ServiceCursor INTO @ServiceID,@Method,@PolicyID;
            WHILE @@FETCH_STATUS=0
            BEGIN
                DECLARE @ChargeTypeID INT=NULL;
                SELECT TOP(1) @ChargeTypeID=ct.BillChargeTypeID
                FROM Housing.BillChargeType ct
                WHERE ct.MeterServiceTypeID_FK=@ServiceID AND ct.BillChargeTypeActive=1
                  AND ct.BillChargeTypeID IN (2,3,4)
                ORDER BY ct.BillChargeTypeID;
                IF @ChargeTypeID IS NULL
                    THROW 50001, N'لا يوجد نوع رسم نشط مطابق للخدمة.', 1;

                IF @Method='SPACE_ESTIMATED'
                BEGIN
                    INSERT INTO #BillTargets
                    (ServiceID,Method,ChargeTypeID,PolicyID,TaxApplicable,TaxInclusive)
                    SELECT @ServiceID,@Method,@ChargeTypeID,p.EstimatedBillingPolicyID,
                           p.TaxApplicable,p.TaxInclusive
                    FROM Housing.EstimatedBillingPolicy p
                    WHERE p.EstimatedBillingPolicyID=@PolicyID
                      AND p.EstimatedBillingPolicyActive=1;
                    IF @@ROWCOUNT<>1
                        THROW 50001, N'سياسة تقدير الخدمات المختارة غير متاحة.', 1;
                END;
                ELSE IF @Method='SERVICE_FIXED_FALLBACK'
                BEGIN
                    INSERT INTO #BillTargets
                    (ServiceID,Method,ChargeTypeID,FixedAmount,TaxApplicable,TaxInclusive)
                    SELECT TOP(1) @ServiceID,@Method,@ChargeTypeID,amount.FixedAmount,1,0
                    FROM Housing.MeterServiceTypeFixedAmount amount
                    WHERE amount.MeterServiceTypeID_FK=@ServiceID
                      AND (amount.idaraID_FK=@IdaraID OR amount.idaraID_FK IS NULL)
                      AND amount.FixedAmount>0
                      AND (amount.MeterServiceTypeFixedAmountActive=1
                           OR amount.MeterServiceTypeFixedAmountEndDate IS NOT NULL)
                      AND (amount.MeterServiceTypeFixedAmountStartDate IS NULL
                           OR CONVERT(date,amount.MeterServiceTypeFixedAmountStartDate)<=@MonthStart)
                      AND (amount.MeterServiceTypeFixedAmountEndDate IS NULL
                           OR CONVERT(date,amount.MeterServiceTypeFixedAmountEndDate)>=@ExitDate)
                    ORDER BY CASE WHEN amount.idaraID_FK=@IdaraID THEN 0 ELSE 1 END,
                             amount.MeterServiceTypeFixedAmountStartDate DESC,
                             amount.MeterServiceTypeFixedAmountID DESC;
                    IF @@ROWCOUNT<>1
                        THROW 50001, N'لا توجد تعرفة ثابتة سارية طوال فترة الإخلاء.', 1;
                END;
                ELSE IF @Method='FIXED_METER'
                BEGIN
                    INSERT INTO #BillTargets
                    (ServiceID,Method,ChargeTypeID,MeterID,MeterTypeID,MeterNo,MeterName,
                     FixedAmount,TaxApplicable,TaxInclusive)
                    SELECT DISTINCT @ServiceID,@Method,@ChargeTypeID,m.meterID,mt.meterTypeID,
                           m.meterNo,m.meterName_A,rate.FixedAmount,1,0
                    FROM Housing.MeterForBuilding link
                    JOIN Housing.Meter m ON m.meterID=link.meterID_FK
                    JOIN Housing.MeterType mt ON mt.meterTypeID=m.meterTypeID_FK
                    CROSS APPLY
                    (
                        SELECT TOP(1) fr.FixedAmount
                        FROM Housing.MeterTypeFixedAmount fr
                        WHERE fr.MeterTypeID_FK=mt.meterTypeID
                          AND (fr.idaraID_FK=@IdaraID OR fr.idaraID_FK IS NULL)
                          AND fr.FixedAmount>0
                          AND (fr.MeterTypeFixedAmountActive=1
                               OR fr.MeterTypeFixedAmountEndDate IS NOT NULL)
                          AND (fr.MeterTypeFixedAmountStartDate IS NULL
                               OR CONVERT(date,fr.MeterTypeFixedAmountStartDate)<=@MonthStart)
                          AND (fr.MeterTypeFixedAmountEndDate IS NULL
                               OR CONVERT(date,fr.MeterTypeFixedAmountEndDate)>=@ExitDate)
                        ORDER BY CASE WHEN fr.idaraID_FK=@IdaraID THEN 0 ELSE 1 END,
                                 fr.MeterTypeFixedAmountStartDate DESC,fr.MeterTypeFixedAmountID DESC
                    ) rate
                    WHERE link.buildingDetailsID_FK=@BuildingDetailsID
                      AND link.IdaraID_FK=@IdaraID AND link.meterForBuildingActive=1
                      AND m.meterActive=1 AND mt.meterTypeActive=1
                      AND mt.meterServiceTypeID_FK=@ServiceID AND mt.MeterCalculateTypeID_FK=2
                      AND mt.IdaraId_FK=@IdaraID
                      AND (link.meterForBuildingStartDate IS NULL
                           OR CONVERT(date,link.meterForBuildingStartDate)<=@MonthStart)
                      AND (link.meterForBuildingEndDate IS NULL
                           OR CONVERT(date,link.meterForBuildingEndDate)>=@ExitDate)
                      AND (m.meterStartDate IS NULL
                           OR CONVERT(date,m.meterStartDate)<=@MonthStart)
                      AND (m.meterEndDate IS NULL
                           OR CONVERT(date,m.meterEndDate)>=@ExitDate);
                    IF @@ROWCOUNT=0
                        THROW 50001, N'تعرفة العداد الثابت غير متاحة طوال فترة الإخلاء.', 1;
                END;
                FETCH NEXT FROM ServiceCursor INTO @ServiceID,@Method,@PolicyID;
            END;
            CLOSE ServiceCursor;
            DEALLOCATE ServiceCursor;

            -- Ensure fixed-meter coverage stays stable throughout the period.
            -- Do not silently drop a meter attached for only part of the month.
            IF EXISTS
            (
                SELECT 1
                FROM #ServiceSummary summary_
                CROSS APPLY
                (
                    SELECT MIN(d.FixedMeters) AS MinMeters, MAX(d.FixedMeters) AS MaxMeters
                    FROM #ExitServiceDayPreview d WHERE d.ServiceID=summary_.ServiceID
                ) dayCount
                OUTER APPLY
                (
                    SELECT COUNT(*) AS TargetMeters FROM #BillTargets t
                    WHERE t.ServiceID=summary_.ServiceID AND t.Method='FIXED_METER'
                ) targets
                WHERE summary_.ReadingDays=0 AND summary_.Method='FIXED_METER'
                  AND (dayCount.MinMeters<>dayCount.MaxMeters
                       OR ISNULL(targets.TargetMeters,0)<>dayCount.MaxMeters)
            )
                THROW 50001, N'تغيرت عدادات الخدمة الثابتة خلال فترة الإخلاء؛ يلزم معالجة الفترات أولاً.', 1;

            -- Reject midperiod fixed-rate overrides. A full-window older rate
            -- must not override a newer department-specific rate during part of the month.
            IF EXISTS
            (
                SELECT 1
                FROM #BillTargets target_
                JOIN #ExitServiceDayPreview day_ ON day_.ServiceID=target_.ServiceID
                OUTER APPLY
                (
                    SELECT TOP(1) amount.FixedAmount
                    FROM Housing.MeterServiceTypeFixedAmount amount
                    WHERE amount.MeterServiceTypeID_FK=target_.ServiceID
                      AND (amount.idaraID_FK=@IdaraID OR amount.idaraID_FK IS NULL)
                      AND amount.FixedAmount>0
                      AND (amount.MeterServiceTypeFixedAmountActive=1
                           OR amount.MeterServiceTypeFixedAmountEndDate IS NOT NULL)
                      AND (amount.MeterServiceTypeFixedAmountStartDate IS NULL
                           OR CONVERT(date,amount.MeterServiceTypeFixedAmountStartDate)<=day_.BillDay)
                      AND (amount.MeterServiceTypeFixedAmountEndDate IS NULL
                           OR CONVERT(date,amount.MeterServiceTypeFixedAmountEndDate)>=day_.BillDay)
                    ORDER BY CASE WHEN amount.idaraID_FK=@IdaraID THEN 0 ELSE 1 END,
                             amount.MeterServiceTypeFixedAmountStartDate DESC,
                             amount.MeterServiceTypeFixedAmountID DESC
                ) dailyRate
                WHERE target_.Method='SERVICE_FIXED_FALLBACK'
                  AND (dailyRate.FixedAmount IS NULL
                       OR dailyRate.FixedAmount<>target_.FixedAmount)
            )
                THROW 50001, N'تغير مبلغ الخدمة الثابت خلال فترة الإخلاء؛ يلزم تقسيم الفترة.', 1;

            IF EXISTS
            (
                SELECT 1
                FROM #BillTargets target_
                JOIN #ExitServiceDayPreview day_ ON day_.ServiceID=target_.ServiceID
                OUTER APPLY
                (
                    SELECT TOP(1) amount.FixedAmount
                    FROM Housing.MeterTypeFixedAmount amount
                    WHERE amount.MeterTypeID_FK=target_.MeterTypeID
                      AND (amount.idaraID_FK=@IdaraID OR amount.idaraID_FK IS NULL)
                      AND amount.FixedAmount>0
                      AND (amount.MeterTypeFixedAmountActive=1
                           OR amount.MeterTypeFixedAmountEndDate IS NOT NULL)
                      AND (amount.MeterTypeFixedAmountStartDate IS NULL
                           OR CONVERT(date,amount.MeterTypeFixedAmountStartDate)<=day_.BillDay)
                      AND (amount.MeterTypeFixedAmountEndDate IS NULL
                           OR CONVERT(date,amount.MeterTypeFixedAmountEndDate)>=day_.BillDay)
                    ORDER BY CASE WHEN amount.idaraID_FK=@IdaraID THEN 0 ELSE 1 END,
                             amount.MeterTypeFixedAmountStartDate DESC,
                             amount.MeterTypeFixedAmountID DESC
                ) dailyRate
                WHERE target_.Method='FIXED_METER'
                  AND (dailyRate.FixedAmount IS NULL
                       OR dailyRate.FixedAmount<>target_.FixedAmount)
            )
                THROW 50001, N'تغير مبلغ العداد الثابت خلال فترة الإخلاء؛ يلزم تقسيم الفترة.', 1;

            IF @TaxRatePercent IS NULL
               AND EXISTS (SELECT 1 FROM #BillTargets WHERE TaxApplicable=1)
                THROW 50001, N'تعذر تحديد ضريبة الخدمات السارية في تاريخ الإخلاء.', 1;

            DECLARE @BillID BIGINT, @TargetID INT=0, @TotalTargets INT;
            SELECT @TotalTargets=COUNT(*) FROM #BillTargets;
            DECLARE @BuildingNo NVARCHAR(200), @UtilityTypeID INT;
            SELECT @BuildingNo=bd.buildingDetailsNo,@UtilityTypeID=bd.buildingUtilityTypeID_FK
            FROM Housing.BuildingDetails bd
            WHERE bd.buildingDetailsID=@BuildingDetailsID AND bd.IdaraId_FK=@IdaraID;

            WHILE @TargetID < @TotalTargets
            BEGIN
                SET @TargetID=@TargetID+1;
                DECLARE @TargetService INT,@TargetCharge INT,@TargetMethod VARCHAR(25),
                        @TargetPolicy BIGINT,@TargetMeter BIGINT,@TargetMeterType INT,
                        @TargetMeterNo NVARCHAR(100),@TargetMeterName NVARCHAR(200),
                        @TargetFixed DECIMAL(18,2),@TaxApp BIT,@TaxIncl BIT;
                SELECT @TargetService=ServiceID,@TargetCharge=ChargeTypeID,
                       @TargetMethod=Method,@TargetPolicy=PolicyID,
                       @TargetMeter=MeterID,@TargetMeterType=MeterTypeID,
                       @TargetMeterNo=MeterNo,@TargetMeterName=MeterName,
                       @TargetFixed=FixedAmount,@TaxApp=TaxApplicable,@TaxIncl=TaxInclusive
                FROM #BillTargets WHERE TargetID=@TargetID;

                DECLARE @BeforeTax DECIMAL(18,2)=0,@AmountTax DECIMAL(18,2)=0,
                        @AmountTotal DECIMAL(18,2)=0;
                IF @TargetMethod='SPACE_ESTIMATED'
                BEGIN
                    CREATE TABLE #SpaceAmounts
                    (
                        BuildingSpaceTypeID INT NOT NULL,
                        SpaceCode NVARCHAR(50) NULL,SpaceName NVARCHAR(100) NULL,
                        SpaceCount INT NOT NULL,AverageConsumption DECIMAL(18,6) NOT NULL,
                        UsageFactor DECIMAL(18,6) NOT NULL,UnitPrice DECIMAL(18,6) NOT NULL,
                        UnitCode NVARCHAR(30) NOT NULL,
                        BeforeTax DECIMAL(18,2) NOT NULL,Tax DECIMAL(18,2) NOT NULL,
                        Total DECIMAL(18,2) NOT NULL
                    );
                    ;WITH SpaceCounts AS
                    (
                        SELECT sp.BuildingSpaceTypeID_FK,COUNT(*) AS SpaceCount
                        FROM Housing.BuildingSpace sp
                        WHERE sp.BuildingDetailsID_FK=@BuildingDetailsID AND sp.BuildingSpaceActive=1
                          AND (sp.BuildingSpaceStartDate IS NULL OR sp.BuildingSpaceStartDate<=@ExitDate)
                          AND (sp.BuildingSpaceEndDate IS NULL OR sp.BuildingSpaceEndDate>=@MonthStart)
                        GROUP BY sp.BuildingSpaceTypeID_FK
                    )
                    INSERT #SpaceAmounts
                    SELECT typ.BuildingSpaceTypeID,typ.BuildingSpaceTypeCode,
                           typ.BuildingSpaceTypeName_A,c.SpaceCount,rule_.AverageDailyConsumption,
                           rule_.UsageFactor,rule_.UnitPrice,rule_.UnitCode,
                           CAST(CASE WHEN @TaxApp=1 AND @TaxIncl=1
                                     THEN raw_.RawAmount/(1+ISNULL(@TaxRatePercent,0)/100.0)
                                     ELSE raw_.RawAmount END AS DECIMAL(18,2)),
                           CAST(CASE WHEN @TaxApp=0 THEN 0
                                     WHEN @TaxIncl=1 THEN raw_.RawAmount-
                                          raw_.RawAmount/(1+ISNULL(@TaxRatePercent,0)/100.0)
                                     ELSE raw_.RawAmount*(@TaxRatePercent/100.0) END AS DECIMAL(18,2)),
                           CAST(CASE WHEN @TaxApp=1 AND @TaxIncl=0
                                     THEN raw_.RawAmount*(1+@TaxRatePercent/100.0)
                                     ELSE raw_.RawAmount END AS DECIMAL(18,2))
                    FROM SpaceCounts c
                    JOIN Housing.BuildingSpaceType typ ON typ.BuildingSpaceTypeID=c.BuildingSpaceTypeID_FK
                      AND typ.BuildingSpaceTypeActive=1
                    JOIN Housing.EstimatedBillingPolicyDetails rule_
                      ON rule_.EstimatedBillingPolicyID_FK=@TargetPolicy
                     AND rule_.MeterServiceTypeID_FK=@TargetService
                     AND rule_.BuildingSpaceTypeID_FK=c.BuildingSpaceTypeID_FK
                     AND rule_.EstimatedBillingPolicyDetailsActive=1
                    CROSS APPLY
                    (
                        SELECT CAST(c.SpaceCount*rule_.AverageDailyConsumption*
                          rule_.UsageFactor*rule_.UnitPrice*@BillingDays AS DECIMAL(18,6)) AS RawAmount
                    ) raw_;
                    IF NOT EXISTS(SELECT 1 FROM #SpaceAmounts)
                        THROW 50001, N'لا توجد فراغات مؤهلة لفاتورة الإخلاء التقديرية.', 1;
                    SELECT @BeforeTax=SUM(BeforeTax),@AmountTax=SUM(Tax),
                           @AmountTotal=SUM(Total) FROM #SpaceAmounts;
                END
                ELSE
                BEGIN
                    SET @BeforeTax=CAST(@TargetFixed*@BillingDays/30.0 AS DECIMAL(18,2));
                    SET @AmountTax=CASE WHEN @TaxApp=1
                         THEN CAST(@BeforeTax*@TaxRatePercent/100.0 AS DECIMAL(18,2))
                         ELSE 0 END;
                    SET @AmountTotal=@BeforeTax+@AmountTax;
                END;
                IF @AmountTotal<=0 OR @AmountTotal IS NULL
                    THROW 50001, N'المبلغ المحتسب لفاتورة الإخلاء غير صالح.', 1;

                DECLARE @PeriodID INT=NULL;
                SELECT TOP(1) @PeriodID=period.billPeriodID
                FROM Housing.BillPeriodType periodType
                JOIN Housing.BillPeriod period ON period.billPeriodTypeID_FK=periodType.billPeriodTypeID
                                           AND period.IdaraId_FK=@IdaraID
                WHERE periodType.meterServiceTypeID_FK=@TargetService
                  AND period.billPeriodStartDate<=@ExitDate
                  AND period.billPeriodEndDate>=@MonthStart
                ORDER BY period.billPeriodID DESC;

                INSERT INTO Housing.Bills
                (BillsUID,BillChargeTypeID_FK,BillTypeID_FK,CurrentPeriodID,
                 PeriodMonth,PeriodYear,CurrentPeriodTax,meterNo,meterID,meterName_A,
                 buildingDetailsNo,buildingUtilityTypeID,buildingDetailsID,meterTypeID,meterServiceTypeID,
                 residentInfoID_FK,generalNo_FK,CurrentRead,LastRead,ReadDiff,
                 PRICE,PRICETAX,meterServicePrice,meterServicePriceTAX,TotalPrice,
                 BillsFromDate,BillsToDate,BillActive,idaraID_FK,entryData,hostName,
                 ExitRequestActionID_FK)
                VALUES
                (NEWID(),@TargetCharge,3,@PeriodID,MONTH(@ExitDate),YEAR(@ExitDate),
                 ISNULL(@TaxRatePercent,0),@TargetMeterNo,@TargetMeter,@TargetMeterName,
                 @BuildingNo,@UtilityTypeID,@BuildingDetailsID,@TargetMeterType,@TargetService,
                 @ResidentInfoID,@GeneralNo,0,0,0,
                 @BeforeTax,@AmountTax,0,0,@AmountTotal,
                 @MonthStart,@ExitDate,1,@IdaraID,@EntryData,@HostName,@ExitRequestActionID);
                SET @BillID=SCOPE_IDENTITY();

                INSERT INTO Housing.BillCalculation
                (BillsID_FK,CalculationMethod,EstimatedBillingPolicyID_FK,BillingDays,
                 TaxApplicable,TaxInclusive,TaxID_FK,TaxRate,
                 AmountBeforeTax,TaxAmount,TotalAmount,CalculationReason,entryData,hostName)
                VALUES
                (@BillID,CONVERT(NVARCHAR(40),@TargetMethod),@TargetPolicy,@BillingDays,
                 @TaxApp,@TaxIncl,CASE WHEN @TaxApp=1 THEN @TaxID ELSE NULL END,
                 CASE WHEN @TaxApp=1 THEN @TaxRatePercent/100.0 ELSE 0 END,
                 @BeforeTax,@AmountTax,@AmountTotal,
                 N'فاتورة خدمة الإخلاء المرتبطة بدورة الإخلاء',@EntryData,@HostName);

                IF @TargetMethod='SPACE_ESTIMATED'
                BEGIN
                    DECLARE @CalculationID BIGINT=SCOPE_IDENTITY();
                    INSERT INTO Housing.BillCalculationDetails
                    (BillCalculationID_FK,BuildingSpaceTypeID_FK,SpaceTypeCode,SpaceTypeName_A,
                     SpaceCount,AverageDailyConsumption,UsageFactor,UnitPrice,UnitCode,BillingDays,
                     AmountBeforeTax,TaxAmount,TotalAmount,entryData,hostName)
                    SELECT @CalculationID,BuildingSpaceTypeID,SpaceCode,SpaceName,
                           SpaceCount,AverageConsumption,UsageFactor,UnitPrice,UnitCode,@BillingDays,
                           BeforeTax,Tax,Total,@EntryData,@HostName FROM #SpaceAmounts;
                    DROP TABLE #SpaceAmounts;
                END;
            END;
            IF @PriorTranCount=0 COMMIT TRANSACTION;
            DROP TABLE #ExitServiceDayPreview;
            RETURN;
        END TRY
        BEGIN CATCH
            IF CURSOR_STATUS('local','ServiceCursor')>=-1
            BEGIN
                IF CURSOR_STATUS('local','ServiceCursor')>=0 CLOSE ServiceCursor;
                DEALLOCATE ServiceCursor;
            END;
            IF @PriorTranCount=0 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
            THROW;
        END CATCH;
    END;
END;