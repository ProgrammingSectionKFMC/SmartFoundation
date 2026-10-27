CREATE  PROCEDURE [Housing].[HousingExitSP] 
(
      @Action                               NVARCHAR(200)
    , @ActionID                             BIGINT          = NULL
    , @residentInfoID                       NVARCHAR(100)   = NULL
    , @NationalID                           NVARCHAR(100)   = NULL
    , @GeneralNo                            NVARCHAR(100)   = NULL
    , @WaitingClassID                       NVARCHAR(1000)  = NULL
    , @WaitingClassName                     NVARCHAR(1000)  = NULL
    , @WaitingOrderTypeID                   NVARCHAR(1000)  = NULL
    , @WaitingOrderTypeName                 NVARCHAR(1000)  = NULL
    , @waitingClassSequence                 NVARCHAR(1000)  = NULL
    , @WaitingListOrder                     NVARCHAR(1000)  = NULL
    , @FullName_A                           NVARCHAR(1000)  = NULL
    , @buildingDetailsID                    NVARCHAR(1000)  = NULL
    , @AssignPeriodID                       NVARCHAR(1000)  = NULL
    , @LastActionID                         NVARCHAR(1000)  = NULL
    , @LastActionTypeID                     NVARCHAR(1000)  = NULL
    , @Notes                                NVARCHAR(1000)  = NULL
    , @ExitDate                             NVARCHAR(1000)  = NULL
    , @PenaltyPrice                         NVARCHAR(1000)  = NULL
    , @PenaltyReason                        NVARCHAR(4000)  = NULL
    , @BillsID                              NVARCHAR(4000)  = NULL
    , @OccupentDate                         NVARCHAR(4000)  = NULL
    , @FinalExitDate                        NVARCHAR(4000)  = NULL
    , @idaraID_FK                           NVARCHAR(10)    = NULL
    , @entryData                            NVARCHAR(20)    = NULL
    , @hostName                             NVARCHAR(200)   = NULL
)

AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE 
          @NewID BIGINT = NULL
        , @Note  NVARCHAR(MAX) = NULL;

    -- تحويلات رقمية آمنة
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(@idaraID_FK, ''));

    DECLARE @ResidentInfoID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(@residentInfoID, ''));
    DECLARE @GeneralNo_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(@GeneralNo, ''));
    DECLARE @BuildingDetailsID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(@buildingDetailsID, ''));
    DECLARE @OccupentDate_DATE DATE = TRY_CONVERT(DATE, NULLIF(@OccupentDate, ''));
    -- p22 (@ExitDate) is editable only while creating/editing the exit request.
    -- In later workflow actions p22 contains LastActionDate, while p44
    -- (@FinalExitDate) carries the actual exit date saved on the request.
    DECLARE @ExitDate_DATE DATE =
        CASE
            WHEN @Action = N'HOUSINGEXIT'
    THEN CONVERT(DATE, GETDATE())

            WHEN @Action = N'EDITHOUSINGEXIT'
    THEN TRY_CONVERT(DATE, NULLIF(@ExitDate, ''))
            ELSE COALESCE
            (
                TRY_CONVERT(DATE, NULLIF(@FinalExitDate, '')),
                TRY_CONVERT(DATE, NULLIF(@ExitDate, ''))
            )
        END;

    -- Preserve the existing procedure contract for branches that insert
    -- @ExitDate directly into BuildingAction.
    SET @ExitDate = CONVERT(NVARCHAR(10), @ExitDate_DATE, 23);

    DECLARE @buildingDetailsNo nvarchar(200) 
    set @buildingDetailsNo = (select b.buildingDetailsNo from Housing.V_GetGeneralListForBuilding b where b.buildingDetailsID = @buildingDetailsID);

DECLARE @Clean NVARCHAR(100) =
    LTRIM(RTRIM(NULLIF(@PenaltyPrice, '')));

-- إزالة المسافات
SET @Clean = REPLACE(@Clean, ' ', '');

IF @Clean IS NOT NULL
BEGIN
    DECLARE @LastComma INT = LEN(@Clean) - CHARINDEX(',', REVERSE(@Clean)) + 1;
    DECLARE @LastDot   INT = LEN(@Clean) - CHARINDEX('.', REVERSE(@Clean)) + 1;

    IF CHARINDEX(',', @Clean) > 0 AND CHARINDEX('.', @Clean) > 0
    BEGIN
        -- إذا النقطة هي الأخيرة → تنسيق أمريكي
        IF @LastDot > @LastComma
        BEGIN
            -- إزالة فواصل الآلاف
            SET @Clean = REPLACE(@Clean, ',', '');
        END
        ELSE
        BEGIN
            -- تنسيق أوروبي
            SET @Clean = REPLACE(@Clean, '.', '');
            SET @Clean = REPLACE(@Clean, ',', '.');
        END
    END
    ELSE
    BEGIN
        -- حالة وجود فاصلة واحدة فقط (آلاف)
        SET @Clean = REPLACE(@Clean, ',', '');
    END
END

DECLARE @PenaltyPriceDecimal DECIMAL(18,2) =
    TRY_CONVERT(DECIMAL(18,2), @Clean);


    BEGIN TRY
        -- Transaction-safe
        IF @tc = 0
            BEGIN TRAN;

        ----------------------------------------------------------------
        -- Business validations => THROW 50001
        ----------------------------------------------------------------
        IF NULLIF(LTRIM(RTRIM(@Action)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'العملية مطلوبة', 1;
        END

        -- Keep physical vacancy independent from the resident's financial workflow.
        -- All exit writes use the same transaction lock as final occupancy.
        IF @Action IN (N'HOUSINGEXIT', N'EDITHOUSINGEXIT', N'CANCELHOUSINGEXIT',
                       N'SENDHOUSINGEXITTOFINANCE', N'APPROVEHOUSINGEXIT', N'HOUSINGEXITPENALTYRECORD')
        BEGIN
            DECLARE @OccupancyLockResult INT;
            DECLARE @OccupancyLockResource NVARCHAR(255) = CONCAT(
                N'Housing.Occupancy:', @IdaraID_INT, N':', @BuildingDetailsID_BIGINT);
            EXEC @OccupancyLockResult = sys.sp_getapplock
                  @Resource = @OccupancyLockResource
                , @LockMode = 'Exclusive'
                , @LockOwner = 'Transaction'
                , @LockTimeout = 10000;
            IF @OccupancyLockResult < 0
                THROW 50001, N'تجري معالجة أخرى للمنزل؛ يرجى إعادة المحاولة.', 1;

            -- Reject stale or mismatched form context before changing dates or bills.
            IF NOT EXISTS
            (
                SELECT 1 FROM Housing.BuildingAction currentAction
                WHERE currentAction.buildingActionID = TRY_CONVERT(BIGINT, @LastActionID)
                  AND currentAction.residentInfoID_FK = @ResidentInfoID_BIGINT
                  AND currentAction.buildingDetailsID_FK = @BuildingDetailsID_BIGINT
                  AND currentAction.IdaraId_FK = @IdaraID_INT
                  AND currentAction.buildingActionActive = 1
                  AND NOT EXISTS
                  (
                      SELECT 1 FROM Housing.BuildingAction child
                      WHERE child.buildingActionParentID = currentAction.buildingActionID
                        AND child.buildingActionActive = 1
                  )
            )
                THROW 50001, N'تغيرت حالة طلب الإخلاء؛ يرجى تحديث الصفحة وإعادة المحاولة.', 1;

            DECLARE @ExitOccupancyActionID BIGINT;
            DECLARE @StoredOccupentDate DATE;
            DECLARE @StoredExitDate DATE;
            DECLARE @NextOccupentDate DATE;
            DECLARE @ExitOverlapMessage NVARCHAR(1000);

            SELECT TOP (1)
                  @ExitOccupancyActionID = history.buildingActionID
                , @StoredOccupentDate = CONVERT(DATE, COALESCE(history.OccupentDate, history.buildingActionDate, history.entryDate))
            FROM Housing.fn_BuildingAction_ChainToRoot(TRY_CONVERT(BIGINT, @LastActionID)) history
            WHERE history.buildingActionTypeID_FK = 2
              AND history.buildingActionActive = 1
              AND history.residentInfoID_FK = @ResidentInfoID_BIGINT
              AND history.buildingDetailsID_FK = @BuildingDetailsID_BIGINT
              AND history.IdaraId_FK = @IdaraID_INT
            ORDER BY history.Lvl DESC
            OPTION (MAXRECURSION 32767);

            IF @ExitOccupancyActionID IS NULL OR @StoredOccupentDate IS NULL
                THROW 50001, N'تعذر تحديد فترة التسكين المرتبطة بطلب الإخلاء.', 1;

            SELECT @StoredExitDate = period.ExitDate
            FROM Housing.fn_BuildingOccupancyPeriods(@BuildingDetailsID_BIGINT, @IdaraID_INT) period
            WHERE period.OccupancyActionID = @ExitOccupancyActionID
            OPTION (MAXRECURSION 32767);

            -- Financial stages carry the saved physical date; hidden posted dates
            -- must not silently change it after another resident has moved in.
            IF @Action NOT IN (N'HOUSINGEXIT', N'EDITHOUSINGEXIT')
                SET @ExitDate_DATE = @StoredExitDate;
            SET @ExitDate = CONVERT(NVARCHAR(10), @ExitDate_DATE, 23);
            SET @OccupentDate_DATE = @StoredOccupentDate;
            SET @OccupentDate = CONVERT(NVARCHAR(10), @StoredOccupentDate, 23);


            ------------------------------------------------------------
-- HOUSING_EXIT_DATE_15D_V1
-- Server-side exit date protection
------------------------------------------------------------
IF @Action IN (N'HOUSINGEXIT', N'EDITHOUSINGEXIT')
BEGIN
    DECLARE @TodayForExit DATE = CONVERT(DATE, GETDATE());

    -- التحقق من صحة التاريخ
    IF @ExitDate_DATE IS NULL
        THROW 50001,
            N'يجب إدخال تاريخ إخلاء صحيح.',
            1;

    -- منع التاريخ المستقبلي
    IF @ExitDate_DATE > @TodayForExit
        THROW 50001,
            N'لا يمكن تسجيل أو تعديل الإخلاء بتاريخ مستقبلي.',
            1;

    --------------------------------------------------------
    -- إنشاء إخلاء جديد
    --------------------------------------------------------
    
    -- EXIT_DELIVERY_CURRENT_MONTH_15D_V1
    -- Applicable to BOTH HOUSINGEXIT and EDITHOUSINGEXIT.
    -- Never allow backdating past today's last 15 days or past current-month start.
    IF @ExitDate_DATE < DATEADD(DAY, -15, @TodayForExit)
        THROW 50001, N'لا يمكن إنشاء أو تعديل الإخلاء بتاريخ أقدم من 15 يوماً من تاريخ اليوم.', 1;

    IF @ExitDate_DATE < DATEFROMPARTS(YEAR(@TodayForExit), MONTH(@TodayForExit), 1)
        THROW 50001, N'لا يمكن إنشاء أو تعديل الإخلاء في شهر ميلادي سابق؛ المسموح الشهر الحالي فقط.', 1;
    -- END EXIT_DELIVERY_CURRENT_MONTH_15D_V1

    IF @Action = N'HOUSINGEXIT'
    BEGIN
        IF @ExitDate_DATE < DATEADD(DAY, -15, @TodayForExit)
            THROW 50001,
                N'لا يمكن تسجيل إخلاء بتاريخ أقدم من 15 يوماً.',
                1;
    END;

    --------------------------------------------------------
    -- تعديل إخلاء قائم
    --------------------------------------------------------
    IF @Action = N'EDITHOUSINGEXIT'
    BEGIN
        DECLARE @OriginalExitEntryDate DATE = NULL;
        DECLARE @OriginalExitCount INT = 0;

        -- تاريخ إنشاء الإخلاء الأصلي من السلسلة الموثوقة
        SELECT
            @OriginalExitCount = COUNT(*),
            @OriginalExitEntryDate =
                MIN(CONVERT(DATE, history.entryDate))
        FROM Housing.fn_BuildingAction_ChainToRoot
             (TRY_CONVERT(BIGINT, @LastActionID)) history
        WHERE history.buildingActionTypeID_FK = 54
          AND history.buildingActionActive = 1
          AND history.residentInfoID_FK = @ResidentInfoID_BIGINT
          AND history.buildingDetailsID_FK = @BuildingDetailsID_BIGINT
          AND history.IdaraId_FK = @IdaraID_INT
        OPTION (MAXRECURSION 32767);

        IF @OriginalExitCount <> 1
           OR @OriginalExitEntryDate IS NULL
            THROW 50001,
                N'تعذر تحديد تاريخ تسجيل طلب الإخلاء الأصلي.',
                1;



        IF @OriginalExitEntryDate > @TodayForExit
         THROW 50001,
        N'تاريخ تسجيل طلب الإخلاء الأصلي غير صحيح.',
        1;

        -- لا تمدد التعديلات المتكررة المهلة
        IF @TodayForExit >
           DATEADD(DAY, 15, @OriginalExitEntryDate)
            THROW 50001,
                N'انتهت مهلة تعديل طلب الإخلاء البالغة 15 يوماً من تاريخ تسجيله.',
                1;

        -- أقدم تاريخ مسموح مرتبط بالتسجيل الأصلي
        IF @ExitDate_DATE <
           DATEADD(DAY, -15, @OriginalExitEntryDate)
            THROW 50001,
                N'لا يمكن تعديل تاريخ الإخلاء إلى تاريخ أقدم من 15 يوماً قبل تسجيل الطلب الأصلي.',
                1;
    END;
END;
------------------------------------------------------------
-- END HOUSING_EXIT_DATE_15D_V1
------------------------------------------------------------

            SELECT TOP (1)
                  @NextOccupentDate = CONVERT(DATE, COALESCE(nextOccupancy.OccupentDate, nextOccupancy.buildingActionDate, nextOccupancy.entryDate))
            FROM Housing.BuildingAction nextOccupancy
            WHERE nextOccupancy.buildingDetailsID_FK = @BuildingDetailsID_BIGINT
              AND nextOccupancy.IdaraId_FK = @IdaraID_INT
              AND nextOccupancy.buildingActionTypeID_FK = 2
              AND nextOccupancy.buildingActionActive = 1
              AND CONVERT(DATE, COALESCE(nextOccupancy.OccupentDate, nextOccupancy.buildingActionDate, nextOccupancy.entryDate)) >= @StoredOccupentDate
              AND (nextOccupancy.residentInfoID_FK <> @ResidentInfoID_BIGINT
                   OR CONVERT(DATE, COALESCE(nextOccupancy.OccupentDate, nextOccupancy.buildingActionDate, nextOccupancy.entryDate)) > @StoredOccupentDate)
            ORDER BY CONVERT(DATE, COALESCE(nextOccupancy.OccupentDate, nextOccupancy.buildingActionDate, nextOccupancy.entryDate)),
                     nextOccupancy.buildingActionID;

            IF @Action = N'CANCELHOUSINGEXIT' AND @NextOccupentDate IS NOT NULL
            BEGIN
                SET @ExitOverlapMessage = CONCAT(N'لا يمكن إلغاء الإخلاء؛ تم تسكين مستفيد آخر بالمنزل بتاريخ ',
                    CONVERT(NVARCHAR(10), @NextOccupentDate, 23), N'.');
                THROW 50001, @ExitOverlapMessage, 1;
            END;

            IF @Action <> N'CANCELHOUSINGEXIT'
            BEGIN
                IF @ExitDate_DATE IS NULL OR @ExitDate_DATE < @StoredOccupentDate
                    THROW 50001, N'تاريخ الإخلاء غير صحيح أو يسبق تاريخ التسكين.', 1;
                IF @NextOccupentDate IS NOT NULL AND @ExitDate_DATE >= @NextOccupentDate
                BEGIN
                    SET @ExitOverlapMessage = CONCAT(N'لا يمكن حفظ تاريخ الإخلاء؛ يجب أن يكون قبل تاريخ تسكين المستفيد التالي ',
                        CONVERT(NVARCHAR(10), @NextOccupentDate, 23), N'، لأن المنزل يتاح من اليوم التالي للإخلاء.');
                    THROW 50001, @ExitOverlapMessage, 1;
                END;
            END;
        END;

   


         
        
        -- EXIT_DELIVERY_ANY_BUILDING_BILL_MONTH_GUARD_V1_BEGIN
        -- Block on ANY current-month bill of the building, active or inactive,
        -- including rent, services and penalties. Historical imported bills
        -- must not be counted solely because their entryDate was in this month.
        IF @Action IN (N'HOUSINGEXIT', N'EDITHOUSINGEXIT')
        BEGIN
            DECLARE @ExitMonthStartForBillGuard DATE =
                DATEFROMPARTS(YEAR(@ExitDate_DATE), MONTH(@ExitDate_DATE), 1);
            DECLARE @NextExitMonthForBillGuard DATE =
                DATEADD(MONTH, 1, @ExitMonthStartForBillGuard);

            IF @BuildingDetailsID_BIGINT IS NULL OR @IdaraID_INT IS NULL
                THROW 50001, N'تعذر التحقق من فواتير المبنى بسبب بيانات غير مكتملة.', 1;

            IF EXISTS
            (
                SELECT 1
                FROM Housing.Bills b WITH (UPDLOCK, HOLDLOCK)
                WHERE b.buildingDetailsID = @BuildingDetailsID_BIGINT
                  AND b.idaraID_FK = @IdaraID_INT
                  AND NOT
                  (
                    b.BillActive=0
                    AND EXISTS
                    (
                      SELECT 1 FROM Housing.BuildingAction old54
                      WHERE old54.buildingActionTypeID_FK=54
                        AND old54.buildingActionActive=1
                        AND old54.buildingDetailsID_FK=@BuildingDetailsID_BIGINT
                        AND old54.IdaraId_FK=@IdaraID_INT
                        AND EXISTS
                        (
                          SELECT 1 FROM Housing.BuildingAction cancel55
                          WHERE cancel55.buildingActionTypeID_FK=55
                            AND cancel55.buildingActionActive=1
                            AND cancel55.residentInfoID_FK=old54.residentInfoID_FK
                            AND cancel55.buildingDetailsID_FK=old54.buildingDetailsID_FK
                            AND cancel55.IdaraId_FK=old54.IdaraId_FK
                            AND EXISTS
                            (
                              SELECT 1 FROM Housing.fn_BuildingAction_ChainToRoot(cancel55.buildingActionID) anc
                              WHERE anc.buildingActionID=old54.buildingActionID
                            )
                        )
                        AND
                        (
                          (b.ExitRequestActionID_FK=old54.buildingActionID
                           AND b.CanceledDate IS NOT NULL)
                          OR
                          EXISTS
                          (
                            SELECT 1 FROM Housing.MeterRead oldRead
                            JOIN Housing.BuildingAction action59
                              ON action59.buildingActionID=oldRead.buildingActionID_FK
                            WHERE b.meterReadID=oldRead.meterReadID
                              AND b.BillTypeID_FK=3
                              AND b.BillChargeTypeID_FK IN (2,3,4)
                              AND oldRead.meterReadTypeID_FK=3
                              AND oldRead.meterReadActive=0
                              AND action59.buildingActionTypeID_FK=59
                              AND action59.buildingActionActive=1
                              AND action59.residentInfoID_FK=old54.residentInfoID_FK
                              AND action59.buildingDetailsID_FK=old54.buildingDetailsID_FK
                              AND action59.IdaraId_FK=old54.IdaraId_FK
                              AND EXISTS
                              (
                                SELECT 1 FROM Housing.fn_BuildingAction_ChainToRoot(action59.buildingActionID) anc
                                WHERE anc.buildingActionID=old54.buildingActionID
                              )
                          )
                        )
                    )
                  )

                  AND
                  (
                      (b.PeriodYear = YEAR(@ExitMonthStartForBillGuard)
                       AND b.PeriodMonth = MONTH(@ExitMonthStartForBillGuard))
                      OR
                      (b.BillsFromDate < @NextExitMonthForBillGuard
                       AND b.BillsToDate >= @ExitMonthStartForBillGuard)
                      OR
                      (
                          -- EXIT_DELIVERY_ENTRYDATE_FALLBACK_V2
                          -- Never treat migration entryDate as a billing period
                          -- when period month/year or dates identify an older period.
                          (COALESCE(b.PeriodYear,0) NOT BETWEEN 1900 AND 9999
                           OR COALESCE(b.PeriodMonth,0) NOT BETWEEN 1 AND 12)
                          AND (b.BillsFromDate IS NULL OR b.BillsToDate IS NULL)
                          AND b.entryDate >= @ExitMonthStartForBillGuard
                          AND b.entryDate < @NextExitMonthForBillGuard
                      )
                  )
            )
                THROW 50001,
                    N'لا يمكن إنشاء أو تعديل الإخلاء بعد إصدار أي فاتورة تخص المبنى في الشهر الحالي؛ يلزم مراجعة الفوترة.', 1;
        END;
        -- EXIT_DELIVERY_ANY_BUILDING_BILL_MONTH_GUARD_V1_END

        -- EXIT_LAST_BILL_END_GUARD_V1_BEGIN
        -- Only exit creation/edit: prevent a physical exit date earlier than the end
        -- of an independent active rent/service bill from THIS occupancy.
        -- Monthly (BillType 2) bills are always independent of the exit request.
        -- On new exit, existing BillType 3 service/rent bills also protect the date.
        -- On editing, BillType 3 bills are excluded because legacy exit bills are
        -- NOT reliably linked to their specific action-54 request yet.
        -- Charges of type 5 are penalties, not dated occupancy/service periods.
        IF @Action IN (N'HOUSINGEXIT', N'EDITHOUSINGEXIT')
        BEGIN
            DECLARE @LastIndependentBilledThrough DATE = NULL;
            DECLARE @BillEndGuardMessage NVARCHAR(1000);

            IF @ResidentInfoID_BIGINT IS NULL
               OR @BuildingDetailsID_BIGINT IS NULL
               OR @IdaraID_INT IS NULL
               OR @StoredOccupentDate IS NULL
               OR @ExitDate_DATE IS NULL
                THROW 50001, N'بيانات فترة الإشغال اللازمة لفحص آخر فاتورة غير مكتملة.', 1;

            -- Fail closed: an active qualifying bill whose end date cannot be
            -- determined must be reviewed before creating/editing an exit.
            IF EXISTS
            (
                SELECT 1
                FROM Housing.Bills b WITH (UPDLOCK, HOLDLOCK)
                WHERE b.residentInfoID_FK = @ResidentInfoID_BIGINT
                  AND b.buildingDetailsID = @BuildingDetailsID_BIGINT
                  AND b.idaraID_FK = @IdaraID_INT
                  AND b.BillActive = 1
                  AND b.BillChargeTypeID_FK IN (1, 2, 3, 4)
                  AND (b.BillTypeID_FK = 2
                       OR (@Action = N'HOUSINGEXIT' AND b.BillTypeID_FK = 3))
                  AND b.BillsToDate IS NULL
                  AND (b.PeriodYear IS NULL OR b.PeriodYear NOT BETWEEN 1900 AND 9999
                       OR b.PeriodMonth IS NULL OR b.PeriodMonth NOT BETWEEN 1 AND 12)
            )
                THROW 50001, N'توجد فاتورة نشطة غير محددة النهاية؛ يجب مراجعتها قبل الإخلاء.', 1;

            SELECT @LastIndependentBilledThrough = MAX(bEnd.BilledThrough)
            FROM Housing.Bills b WITH (UPDLOCK, HOLDLOCK)
            CROSS APPLY
            (
                VALUES
                (
                    COALESCE
                    (
                        CONVERT(DATE, b.BillsToDate),
                        CASE WHEN b.PeriodYear BETWEEN 1900 AND 9999
                                   AND b.PeriodMonth BETWEEN 1 AND 12
                             THEN EOMONTH(DATEFROMPARTS(b.PeriodYear, b.PeriodMonth, 1))
                        END
                    )
                )
            ) AS bEnd(BilledThrough)
            WHERE b.residentInfoID_FK = @ResidentInfoID_BIGINT
              AND b.buildingDetailsID = @BuildingDetailsID_BIGINT
              AND b.idaraID_FK = @IdaraID_INT
              AND b.BillActive = 1
              AND b.BillChargeTypeID_FK IN (1, 2, 3, 4)
              AND (b.BillTypeID_FK = 2
                   OR (@Action = N'HOUSINGEXIT' AND b.BillTypeID_FK = 3))
              AND bEnd.BilledThrough >= @StoredOccupentDate;

            IF @LastIndependentBilledThrough IS NOT NULL
               AND @ExitDate_DATE < @LastIndependentBilledThrough
            BEGIN
                SET @BillEndGuardMessage = CONCAT
                (
                    N'لا يمكن تحديد الإخلاء بتاريخ يسبق نهاية آخر فاتورة سكن أو خدمات، وهي ',
                    CONVERT(NVARCHAR(10), @LastIndependentBilledThrough, 23),
                    N'.'
                );
                THROW 50001, @BillEndGuardMessage, 1;
            END;
        END;
        -- EXIT_LAST_BILL_END_GUARD_V1_END

        ----------------------------------------------------------------
        -- EXIT_BILL_ISSUED_LOCK_V2_BEGIN
        -- Check current registered exit-54 cycle, never rely on browser state.
        -- No BillActive predicate: issuing then deactivating still counts.
        -- Unlinked legacy bills dated since this request are conservatively
        -- treated as possibly belonging to this exit, to fail closed.
        ----------------------------------------------------------------
        IF @Action = N'EDITHOUSINGEXIT'
        BEGIN
            DECLARE @ExitLockRoot54 BIGINT = NULL;
            DECLARE @ExitLockRootCreatedAt DATETIME2(7) = NULL;

            SELECT TOP (1)
                   @ExitLockRoot54 = a.buildingActionID,
                   @ExitLockRootCreatedAt = CONVERT(DATETIME2(7),a.entryDate)
            FROM Housing.fn_BuildingAction_ChainToRoot
                 (TRY_CONVERT(BIGINT,@LastActionID)) a
            INNER JOIN Housing.ExitFinancialProcessingCycle cycle
              ON cycle.ExitRequestActionID_FK=a.buildingActionID
             AND cycle.ProcessingVersion=1
            WHERE a.buildingActionTypeID_FK=54
              AND a.buildingActionActive=1
              AND a.residentInfoID_FK=@ResidentInfoID_BIGINT
              AND a.generalNo_FK=@GeneralNo_BIGINT
              AND a.buildingDetailsID_FK=@BuildingDetailsID_BIGINT
              AND a.IdaraId_FK=@IdaraID_INT
            ORDER BY a.Lvl DESC;

            IF @ExitLockRoot54 IS NULL OR @ExitLockRootCreatedAt IS NULL
                THROW 50001,N'تعذر تحديد دورة الإخلاء الموثوقة للتحقق من فواتيرها.',1;

            IF EXISTS
            (
                SELECT 1 FROM Housing.Bills b WITH (UPDLOCK,HOLDLOCK)
                WHERE b.residentInfoID_FK=@ResidentInfoID_BIGINT
                  AND b.buildingDetailsID=@BuildingDetailsID_BIGINT
                  AND b.idaraID_FK=@IdaraID_INT
                  AND
                  (
                       -- Explicit link is authoritative regardless of bill type.
                       b.ExitRequestActionID_FK=@ExitLockRoot54
                       OR
                       (
                           b.ExitRequestActionID_FK IS NULL
                           AND (b.BillTypeID_FK=3 OR b.BillChargeTypeID_FK=5)
                           AND b.entryDate>=@ExitLockRootCreatedAt
                       )
                  )
            )
                THROW 50001,N'لا يمكن تعديل أو إلغاء طلب الإخلاء بعد إصدار فاتورة إخلاء أو غرامة مرتبطة به، حتى لو ألغيت الفاتورة.',1;

            -- Do not silently retain real exit readings when changing dates.
            -- CANCEL follows this same fail-closed rule if any active read exists
            -- without an invoice: its reversal needs independent verification.
            IF EXISTS
            (
                SELECT 1 FROM Housing.MeterRead mr WITH (UPDLOCK,HOLDLOCK)
                WHERE mr.residentInfoID_FK=@ResidentInfoID_BIGINT
                  AND mr.buildingDetailsID=@BuildingDetailsID_BIGINT
                  AND mr.IdaraID_FK=@IdaraID_INT
                  AND mr.meterReadTypeID_FK=3
                  AND mr.meterReadActive=1
                  AND mr.buildingActionID_FK IN
                  (
                      SELECT a.buildingActionID
                      FROM Housing.fn_BuildingAction_ChainToRoot
                           (TRY_CONVERT(BIGINT,@LastActionID)) a
                      WHERE a.buildingActionTypeID_FK=59
                        AND a.entryDate>=@ExitLockRootCreatedAt
                  )
            )
                THROW 50001,N'توجد قراءة إخلاء مسجلة؛ لا يمكن تعديل الطلب أو إلغاؤه قبل تسوية القراءة.',1;
        END;
        -- EXIT_BILL_ISSUED_LOCK_V2_END


IF @Action IN(N'HOUSINGEXIT',N'EditExtend',N'SendExtendToFinance',N'ApproveExtend')
        BEGIN
         
            IF NULLIF(LTRIM(RTRIM(@ExitDate)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يجب كتابة تاريخ الاخلاء', 1;
            END

        END

        

     

        ----------------------------------------------------------------
        -- HOUSINGEXIT
        ----------------------------------------------------------------
        IF @Action = N'HOUSINGEXIT'
        BEGIN
       


            IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END


            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.ActionID = @ActionID
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END


              IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) Not in (2,24)
            BEGIN
                ;THROW 50001, N'المستفيد غير مؤهل للاخلاء او تم اخلائه مسبقا', 1;
            END



            Declare @buildingActionTypeID_FK INT

            select 
            @buildingActionTypeID_FK =
            case 
            when w.LastActionTypeID = 2  then 54
            when w.LastActionTypeID = 24  then 54
            else 
            9999
            END
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID
            and w.ActionID = @ActionID

            IF 
            (
               @buildingActionTypeID_FK = 9999 
            )
            BEGIN
                ;THROW 50001, N'حصل خطأ ما building Action Type', 1;
            END

          

            


              INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingDetailsID_FK
                , buildingDetailsNo
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , buildingActionDate
                , OccupentDate
                , ExitDate
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  @buildingActionTypeID_FK
                , @residentInfoID
                , @GeneralNo
                , @buildingDetailsID
                , @buildingDetailsNo
                , 1
                , @Notes
                , @LastActionID
                , @ExitDate  
                , @OccupentDate
                , @ExitDate 
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في انشاء طلب الاخلاء', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في انشاء طلب الاخلاء - Identity', 1; -- برمجي
            END


            /* تسجيل دورة الإخلاء المالية الجديدة */

            IF @buildingActionTypeID_FK <> 54
                THROW 50001,
                      N'نوع طلب الإخلاء غير صحيح لتسجيل الدورة المالية',
                      1;
            
            INSERT INTO Housing.ExitFinancialProcessingCycle
            (
                  ExitRequestActionID_FK
                , ProcessingVersion
                , CreatedAt
                , entryData
                , hostName
            )
            VALUES
            (
                  @NewID
                , 1
                , SYSDATETIME()
                , @entryData
                , @hostName
            );
            
            IF @@ROWCOUNT <> 1
                THROW 50002,
                      N'تعذر تسجيل الدورة المالية لطلب الإخلاء',
                      1;


            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionTypeID_FK), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingDetailsID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"buildingDetailsNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), '') + N'"'
                + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"buildingActionNote": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @LastActionID), '') + N'"'
                + N',"buildingActionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExitDate), '') + N'"'
                + N',"entryData": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Housing].[BuildingAction]'
                , N'HOUSINGEXIT'
                , @ActionID
                , @entryData
                , @Note
            );
            

            IF @tc = 0 COMMIT TRANSACTION;
            

            SELECT 1 AS IsSuccessful, N'تم انشاء طلب الاخلاء بنجاح' AS Message_;
            RETURN;
        END


      
        ----------------------------------------------------------------
        -- EDITHOUSINGEXIT
        ----------------------------------------------------------------
        ELSE IF @Action = N'EDITHOUSINGEXIT'
        BEGIN
       


            IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END


            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.ActionID = @ActionID
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END


              IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) NOT IN (54,59,60) /* EXIT_LOCK_ON_ISSUED_BILL_EDIT_V2 */
            BEGIN
                ;THROW 50001, N'لا يمكن تعديل تاريخ الإخلاء بعد إرساله للعدادات أو انتقاله إلى مرحلة لاحقة.', 1;
            END

            -- EXIT_EDIT_MONTH_GUARD_V1: only edit the date within the same calendar month.
            DECLARE @OriginalEditExitDate DATE = NULL;

            SELECT @OriginalEditExitDate = CAST(a.ExitDate AS DATE)
            FROM Housing.BuildingAction a WITH (UPDLOCK, HOLDLOCK)
            WHERE a.buildingActionID = TRY_CONVERT(BIGINT, @LastActionID)
              AND a.residentInfoID_FK = @ResidentInfoID_BIGINT
              AND a.buildingDetailsID_FK = @BuildingDetailsID_BIGINT
              AND a.IdaraId_FK = @IdaraID_INT
              AND a.buildingActionActive = 1;

            IF @OriginalEditExitDate IS NULL OR @ExitDate_DATE IS NULL
                THROW 50001, N'تعذر التحقق من تاريخ الإخلاء الحالي أو التاريخ الجديد.', 1;

            IF EOMONTH(@OriginalEditExitDate) <> EOMONTH(@ExitDate_DATE)
                THROW 50001, N'لا يمكن تعديل تاريخ الإخلاء إلى شهر آخر؛ ألغِ طلب الإخلاء وأنشئ طلبًا جديدًا.', 1;





            


              INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingDetailsID_FK
                , buildingDetailsNo
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , buildingActionDate
                , OccupentDate
                , ExitDate
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  56
                , @residentInfoID
                , @GeneralNo
                , @buildingDetailsID
                , @buildingDetailsNo
                , 1
                , @Notes
                , @LastActionID
                , @ExitDate
                , @OccupentDate
                , @ExitDate 
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل طلب الاخلاء', 1; -- برمجي
            END



             SET @NewID = SCOPE_IDENTITY();


            
              INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingDetailsID_FK
                , buildingDetailsNo
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , buildingActionDate
                , OccupentDate
                , ExitDate
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  @LastActionTypeID
                , @residentInfoID
                , @GeneralNo
                , @buildingDetailsID
                , @buildingDetailsNo
                , 1
                , @Notes
                , @NewID
                , @ExitDate  
                , @OccupentDate
                , @ExitDate
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل طلب الاخلاء', 1; -- برمجي
            END


            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل طلب الاخلاء - Identity', 1; -- برمجي
            END

            EXEC [Housing].[GenerateExitRentBills]
      @Action            = N'REGENERATE'
    , @ResidentInfoID    = @ResidentInfoID_BIGINT
    , @GeneralNo         = @GeneralNo_BIGINT
    , @BuildingDetailsID = @BuildingDetailsID_BIGINT
    , @OccupentDate      = @OccupentDate_DATE
    , @ExitDate          = @ExitDate_DATE
    , @IdaraID           = @IdaraID_INT
    , @EntryData         = @entryData
    , @HostName          = @hostName;


            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionTypeID_FK), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingDetailsID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"buildingDetailsNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), '') + N'"'
                + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"buildingActionNote": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @LastActionID), '') + N'"'
                + N',"buildingActionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExitDate), '') + N'"'
                + N',"entryData": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Housing].[BuildingAction]'
                , N'EDITHOUSINGEXIT'
                , @ActionID
                , @entryData
                , @Note
            );
            

            IF @tc = 0 COMMIT TRANSACTION;
            

            SELECT 1 AS IsSuccessful, N'تم تعديل طلب الاخلاء بنجاح' AS Message_;
            RETURN;
        END

        
        ----------------------------------------------------------------
        -- CANCELHOUSINGEXIT
        ----------------------------------------------------------------
        ELSE IF @Action = N'CANCELHOUSINGEXIT'
        BEGIN
       


            IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END


            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.ActionID = @ActionID
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END


              IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) NOT IN (54,59,60) /* EXIT_LOCK_ON_ISSUED_BILL_CANCEL_V2 */
            BEGIN
                ;THROW 50001, N'لا يمكن إلغاء طلب الإخلاء بعد إرساله للتدقيق المالي أو اعتماده.', 1;
            END

            /*
  SmartFoundation / Housing.HousingExitSP / CANCELHOUSINGEXIT
  FRAGMENT ONLY: replace the entire existing cancellation financial block:
  from EXEC [Housing].[GenerateExitRentBills] @Action=N'CANCEL'
  THROUGH the 3 broad UPDATE statements on Bills and MeterRead.
  Keep the subsequent INSERT INTO Housing.BuildingAction (55) unchanged.
  Financial guards now execute BEFORE rent cancellation.
  Parent HousingExitSP transaction must enclose this entire fragment.
  Not a standalone script. Requires review and rollback QA before deployment.
  Retain existing CANCELHOUSINGEXIT permission, workflow insertions and audit.
*/

-- Identify the most recent active exit request (54) in the exact current action chain.
DECLARE @Cancel_CurrentExit54ID BIGINT = NULL;
SELECT TOP (1) @Cancel_CurrentExit54ID = a.buildingActionID
FROM Housing.fn_BuildingAction_ChainToRoot(TRY_CONVERT(BIGINT, @LastActionID)) a
INNER JOIN Housing.ExitFinancialProcessingCycle c
    ON c.ExitRequestActionID_FK = a.buildingActionID
   AND c.ProcessingVersion = 1
WHERE a.buildingActionTypeID_FK = 54
  AND a.buildingActionActive = 1
  AND a.residentInfoID_FK = @ResidentInfoID_BIGINT
  AND a.generalNo_FK = @GeneralNo_BIGINT
  AND a.buildingDetailsID_FK = @BuildingDetailsID_BIGINT
  AND a.IdaraId_FK = @IdaraID_INT
ORDER BY a.Lvl DESC;

IF @Cancel_CurrentExit54ID IS NULL
    THROW 50001, N'تعذر تحديد دورة طلب الإخلاء الحالية لإلغائها بأمان.', 1;

-- Current-cycle meter readings: stage-59 action must descend from this request-54
-- and be an ancestor of the current last action.
DECLARE @Cancel_CurrentReadIDs TABLE (meterReadID BIGINT NOT NULL PRIMARY KEY);

INSERT INTO @Cancel_CurrentReadIDs(meterReadID)
SELECT DISTINCT mr.meterReadID
FROM Housing.fn_BuildingAction_ChainToRoot(TRY_CONVERT(BIGINT,@LastActionID)) a
INNER JOIN Housing.MeterRead mr WITH (UPDLOCK,HOLDLOCK)
 ON mr.buildingActionID_FK=a.buildingActionID
WHERE a.buildingActionTypeID_FK=59
  AND a.buildingActionActive=1
  AND a.residentInfoID_FK=@ResidentInfoID_BIGINT
  AND a.buildingDetailsID_FK=@BuildingDetailsID_BIGINT
  AND a.IdaraId_FK=@IdaraID_INT
  AND mr.meterReadTypeID_FK=3 AND mr.meterReadActive=1
  AND mr.residentInfoID_FK=@ResidentInfoID_BIGINT
  AND mr.buildingDetailsID=@BuildingDetailsID_BIGINT
  AND mr.IdaraID_FK=@IdaraID_INT
  AND EXISTS
  (
    SELECT 1 FROM Housing.fn_BuildingAction_ChainToRoot(a.buildingActionID) ancestor
    WHERE ancestor.buildingActionID=@Cancel_CurrentExit54ID
  );

DECLARE @Cancel_CurrentBillIDs TABLE (BillsID BIGINT NOT NULL PRIMARY KEY);
INSERT INTO @Cancel_CurrentBillIDs(BillsID)
SELECT DISTINCT b.BillsID
FROM Housing.Bills b WITH (UPDLOCK, HOLDLOCK)
INNER JOIN @Cancel_CurrentReadIDs mr ON mr.meterReadID = b.meterReadID
WHERE b.BillActive = 1
  AND b.BillTypeID_FK = 3
  AND b.BillChargeTypeID_FK IN (2,3,4)
  AND b.residentInfoID_FK = @ResidentInfoID_BIGINT
  AND b.buildingDetailsID = @BuildingDetailsID_BIGINT
  AND b.idaraID_FK = @IdaraID_INT;

-- Fail closed if a current-cycle read is referenced by a bill outside the precise set.
IF EXISTS
(
    SELECT 1
    FROM Housing.Bills b WITH (UPDLOCK, HOLDLOCK)
    JOIN @Cancel_CurrentReadIDs r ON r.meterReadID = b.meterReadID
    WHERE b.BillActive = 1
      AND NOT EXISTS (SELECT 1 FROM @Cancel_CurrentBillIDs t WHERE t.BillsID=b.BillsID)
)
    THROW 50001, N'توجد فاتورة قراءة لا يمكن ربطها بأمان بدورة الإخلاء.', 1;

-- Only *explicitly linked* exit penalties may be canceled automatically.
-- Unlinked penalties require separate historical reconciliation, never broad UPDATE.
IF EXISTS
(
    SELECT 1 FROM Housing.Bills b WITH (UPDLOCK, HOLDLOCK)
    WHERE b.BillActive = 1
      AND b.BillChargeTypeID_FK = 5
      AND b.residentInfoID_FK = @ResidentInfoID_BIGINT
      AND b.buildingDetailsID = @BuildingDetailsID_BIGINT
      AND b.idaraID_FK = @IdaraID_INT
      AND b.ExitRequestActionID_FK IS NULL
)
    THROW 50001, N'توجد غرامة غير مرتبطة بدورة الإخلاء؛ يلزم تدقيق ارتباطها قبل الإلغاء.', 1;

INSERT INTO @Cancel_CurrentBillIDs(BillsID)
SELECT b.BillsID
FROM Housing.Bills b WITH (UPDLOCK, HOLDLOCK)
WHERE b.BillActive = 1
  AND b.BillChargeTypeID_FK = 5
  AND b.ExitRequestActionID_FK = @Cancel_CurrentExit54ID
  AND b.residentInfoID_FK = @ResidentInfoID_BIGINT
  AND b.buildingDetailsID = @BuildingDetailsID_BIGINT
  AND b.idaraID_FK = @IdaraID_INT
  AND NOT EXISTS (SELECT 1 FROM @Cancel_CurrentBillIDs t WHERE t.BillsID=b.BillsID);

-- Never silently deactivate paid, allocated, exempted or split bills.
-- Obsolete bill-to-payment mapping intentionally excluded. Ledger payments are preserved.
IF EXISTS
(
    SELECT 1 FROM @Cancel_CurrentBillIDs t
    JOIN Housing.ResidentRentExemptionPayment e WITH (UPDLOCK, HOLDLOCK)
      ON e.billsID_FK = t.BillsID
)
    THROW 50001, N'توجد فاتورة إخلاء مرتبطة بإعفاء مالي؛ يلزم تدقيق مالي.', 1;

IF EXISTS
(
    SELECT 1 FROM @Cancel_CurrentBillIDs t
    JOIN Housing.Bills child WITH (UPDLOCK, HOLDLOCK)
      ON child.ParentBillsID_FK = t.BillsID
)
    THROW 50001, N'توجد فاتورة إخلاء لها فواتير فرعية؛ يلزم تدقيق مالي.', 1;

-- Existing rent engine cancels all active exit-rent bills for this occupancy.
-- Guard foreign cycle links and ANY historical financial link first.
IF EXISTS
(
    SELECT 1 FROM Housing.Bills b WITH (UPDLOCK, HOLDLOCK)
    WHERE b.BillActive = 1
      AND b.BillChargeTypeID_FK = 1
      AND b.BillTypeID_FK = 3
      AND b.residentInfoID_FK = @ResidentInfoID_BIGINT
      AND b.buildingDetailsID = @BuildingDetailsID_BIGINT
      AND b.idaraID_FK = @IdaraID_INT
      AND b.BillsToDate >= @OccupentDate_DATE
      AND
      (
          (b.ExitRequestActionID_FK IS NULL OR
           b.ExitRequestActionID_FK <> @Cancel_CurrentExit54ID)
          OR EXISTS (SELECT 1 FROM Housing.ResidentRentExemptionPayment e WITH (UPDLOCK,HOLDLOCK)
                     WHERE e.billsID_FK = b.BillsID)
          OR EXISTS (SELECT 1 FROM Housing.Bills child WITH (UPDLOCK,HOLDLOCK)
                     WHERE child.ParentBillsID_FK = b.BillsID)
      )
)
    THROW 50001, N'توجد فاتورة إيجار إخلاء مرتبطة ماليًا أو بدورة أخرى؛ يلزم تدقيق قبل الإلغاء.', 1;

-- Invoke the existing source-of-truth service cancel engine for estimated/fixed bills.
EXEC Housing.GenerateExitServiceBillsForRequest
      @Action = N'CANCEL'
    , @ResidentInfoID = @ResidentInfoID_BIGINT
    , @GeneralNo = @GeneralNo_BIGINT
    , @BuildingDetailsID = @BuildingDetailsID_BIGINT
    , @ExitDate = @ExitDate_DATE
    , @IdaraID = @IdaraID_INT
    , @EntryData = @entryData
    , @HostName = @hostName
    , @OccupentDate = @OccupentDate_DATE
    , @ExitRequestActionID = @Cancel_CurrentExit54ID;

DECLARE @Cancel_ExpectedBillCount INT = (SELECT COUNT(*) FROM @Cancel_CurrentBillIDs);

UPDATE b
SET b.BillActive = 0,
    b.CanceledBy = @entryData,
    b.CanceledDate = SYSDATETIME()
FROM Housing.Bills b
JOIN @Cancel_CurrentBillIDs t ON t.BillsID = b.BillsID
WHERE b.BillActive = 1;

IF @@ROWCOUNT <> @Cancel_ExpectedBillCount
    THROW 50001, N'تعذر إلغاء فواتير قراءة الإخلاء والجزاءات بصورة جذرية.', 1;

DECLARE @Cancel_ExpectedReadCount INT = (SELECT COUNT(*) FROM @Cancel_CurrentReadIDs);

UPDATE mr
SET mr.meterReadActive = 0
FROM Housing.MeterRead mr
JOIN @Cancel_CurrentReadIDs r ON r.meterReadID = mr.meterReadID
WHERE mr.meterReadActive = 1;

IF @@ROWCOUNT <> @Cancel_ExpectedReadCount
    THROW 50001, N'تعذر إلغاء قراءات الإخلاء بصورة جذرية.', 1;

-- Strong post-condition: no current-cycle active exit service bill may remain.
IF EXISTS
(
    SELECT 1 FROM Housing.Bills b WITH (UPDLOCK, HOLDLOCK)
    WHERE b.ExitRequestActionID_FK = @Cancel_CurrentExit54ID
      AND b.BillActive = 1 AND b.BillTypeID_FK = 3
      AND b.BillChargeTypeID_FK IN (2,3,4,5)
)
    THROW 50001, N'لم تكتمل إزالة فواتير خدمات دورة الإخلاء.', 1;


-- CANCEL_V2_METER_POSTCONDITION: independent of invoice ExitRequestActionID_FK.
IF EXISTS
(
 SELECT 1 FROM Housing.fn_BuildingAction_ChainToRoot(TRY_CONVERT(BIGINT,@LastActionID)) a
 JOIN Housing.MeterRead mr WITH (UPDLOCK,HOLDLOCK)
   ON mr.buildingActionID_FK=a.buildingActionID
 WHERE a.buildingActionTypeID_FK=59 AND a.buildingActionActive=1
   AND a.residentInfoID_FK=@ResidentInfoID_BIGINT
   AND a.buildingDetailsID_FK=@BuildingDetailsID_BIGINT
   AND a.IdaraId_FK=@IdaraID_INT
   AND mr.residentInfoID_FK=@ResidentInfoID_BIGINT
   AND mr.buildingDetailsID=@BuildingDetailsID_BIGINT
   AND mr.IdaraID_FK=@IdaraID_INT
   AND mr.meterReadTypeID_FK=3
   AND EXISTS (SELECT 1 FROM Housing.fn_BuildingAction_ChainToRoot(a.buildingActionID) ancestor
               WHERE ancestor.buildingActionID=@Cancel_CurrentExit54ID)
   AND
   (
      mr.meterReadActive=1
      OR EXISTS (SELECT 1 FROM Housing.Bills b WITH (UPDLOCK,HOLDLOCK)
                 WHERE b.meterReadID=mr.meterReadID AND b.BillActive=1)
   )
)
 THROW 50001,N'تعذر إلغاء كافة قراءات الإخلاء وفواتيرها؛ لم يتم إلغاء الطلب.',1;

-- Preserve the existing rent cancellation and restoration behavior, but only
-- after all financial preconditions above have passed.
EXEC [Housing].[GenerateExitRentBills]
      @Action = N'CANCEL'
    , @ResidentInfoID = @ResidentInfoID_BIGINT
    , @GeneralNo = @GeneralNo_BIGINT
    , @BuildingDetailsID = @BuildingDetailsID_BIGINT
    , @OccupentDate = @OccupentDate_DATE
    , @ExitDate = @ExitDate_DATE
    , @IdaraID = @IdaraID_INT
    , @EntryData = @entryData
    , @HostName = @hostName;



              INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingDetailsID_FK
                , buildingDetailsNo
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , buildingActionDate
                , OccupentDate
                , ExitDate
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  55
                , @residentInfoID
                , @GeneralNo
                , @buildingDetailsID
                , @buildingDetailsNo
                , 1
                , @Notes
                , @LastActionID
                , @ExitDate  
                , @OccupentDate
                , @ExitDate
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في الغاء طلب الاخلاء', 1; -- برمجي
            END



             SET @NewID = SCOPE_IDENTITY();


            
                INSERT INTO  Housing.BuildingAction
            (
                 buildingActionTypeID_FK, buildingStatusID_FK, residentInfoID_FK, generalNo_FK, buildingPaymentTypeID_FK, buildingDetailsID_FK, buildingDetailsNo, buildingActionFromDate, 
               buildingActionToDate, buildingActionDate, buildingActionDate2, buildingActionDecisionNo, buildingActionDecisionDate, fromDSD_FK, toDSD_FK, buildingActionFromSourceID_FK, buildingActionToSourceID_FK, 
               buildingActionNote, buildingActionExtraText1, buildingActionExtraText2, buildingActionExtraText3, buildingActionExtraText4, buildingActionExtraDate1, buildingActionExtraDate2, buildingActionExtraDate3, 
               buildingActionExtraFloat1, buildingActionExtraFloat2, buildingActionExtraInt1, buildingActionExtraInt2, buildingActionExtraInt3, buildingActionExtraInt4, buildingActionExtraType1, buildingActionExtraType2, 
               buildingActionExtraType3, buildingActionActive, buildingActionParentID, CustdyRecord, AssignPeriodID_FK,OccupentDate,ExitDate, IdaraId_FK, entryData, hostName

            )
            
            

            SELECT Top(1)
                 buildingActionTypeID_FK, buildingStatusID_FK, residentInfoID_FK, generalNo_FK, buildingPaymentTypeID_FK, buildingDetailsID_FK, buildingDetailsNo, buildingActionFromDate, 
               buildingActionToDate, buildingActionDate, buildingActionDate2, buildingActionDecisionNo, buildingActionDecisionDate, fromDSD_FK, toDSD_FK, buildingActionFromSourceID_FK, buildingActionToSourceID_FK, 
               buildingActionNote, buildingActionExtraText1, buildingActionExtraText2, buildingActionExtraText3, buildingActionExtraText4, buildingActionExtraDate1, buildingActionExtraDate2, buildingActionExtraDate3, 
               buildingActionExtraFloat1, buildingActionExtraFloat2, buildingActionExtraInt1, buildingActionExtraInt2, buildingActionExtraInt3, buildingActionExtraInt4, buildingActionExtraType1, buildingActionExtraType2, 
               buildingActionExtraType3, buildingActionActive, @NewID, CustdyRecord, AssignPeriodID_FK,@OccupentDate,null, @idaraID_FK, @entryData, @hostName
            FROM Housing.fn_BuildingAction_ChainToRoot(@NewID) r
            WHERE R.residentInfoID_FK = @residentInfoID and r.buildingActionTypeID_FK in(2,24)
            ORDER BY buildingActionID desc;
                 


            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في الغاء طلب الاخلاء', 1; -- برمجي
            END


            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في الغاء طلب الاخلاء - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionTypeID_FK), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingDetailsID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"buildingDetailsNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), '') + N'"'
                + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"buildingActionNote": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @LastActionID), '') + N'"'
                + N',"buildingActionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExitDate), '') + N'"'
                + N',"entryData": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Housing].[BuildingAction]'
                , N'CANCELHOUSINGEXIT'
                , @ActionID
                , @entryData
                , @Note
            );
            

            IF @tc = 0 COMMIT TRANSACTION;
            

            SELECT 1 AS IsSuccessful, N'تم الغاء طلب الاخلاء بنجاح' AS Message_;
            RETURN;
        END

             
             

        ----------------------------------------------------------------
        -- SENDHOUSINGEXITTOFINANCE
        ----------------------------------------------------------------
        IF @Action = N'SENDHOUSINGEXITTOFINANCE'
        BEGIN
       


            IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END


            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.ActionID = @ActionID
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END


              IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) Not in (60)
            BEGIN
                ;THROW 50001, N'تم ارسال الطلب للتدقيق المالي مسبقا', 1;
            END




            -- EXIT_57_V1_GATE_REVIEW: ORIGINAL 54 > 59(optional) > 60.
            -- All checks and financial writes share the HousingExitSP transaction/occupancy lock.
            DECLARE @G57_S60 BIGINT=TRY_CONVERT(BIGINT,@LastActionID);
            DECLARE @G57_S59 BIGINT=NULL,@G57_Exit54 BIGINT=NULL;
            DECLARE @G57_Resident BIGINT=NULL,@G57_General BIGINT=NULL,
                    @G57_Home BIGINT=NULL,@G57_Idara INT=NULL;
            DECLARE @G57_Entry DATE=NULL,@G57_Physical DATE=NULL,
                    @G57_Version INT=NULL;

            SELECT @G57_Exit54=exit54.buildingActionID,
                   @G57_S59=CASE WHEN prev.buildingActionTypeID_FK=59
                               THEN prev.buildingActionID END,
                   @G57_Resident=exit54.residentInfoID_FK,
                   @G57_General=exit54.generalNo_FK,
                   @G57_Home=exit54.buildingDetailsID_FK,
                   @G57_Idara=exit54.IdaraId_FK,
                   @G57_Entry=TRY_CONVERT(DATE,exit54.OccupentDate),
                   @G57_Physical=TRY_CONVERT(DATE,exit54.ExitDate)
            FROM Housing.V_WaitingList w
            JOIN Housing.BuildingAction current60 WITH (UPDLOCK,HOLDLOCK)
              ON current60.buildingActionID=TRY_CONVERT(BIGINT,w.LastActionID)
             AND current60.buildingActionTypeID_FK=60 AND current60.buildingActionActive=1
            JOIN Housing.BuildingAction prev WITH (UPDLOCK,HOLDLOCK)
              ON prev.buildingActionID=current60.buildingActionParentID
             AND prev.buildingActionTypeID_FK IN (54,59) AND prev.buildingActionActive=1
            JOIN Housing.BuildingAction exit54 WITH (UPDLOCK,HOLDLOCK)
              ON exit54.buildingActionID=CASE WHEN prev.buildingActionTypeID_FK=59
                 THEN prev.buildingActionParentID ELSE prev.buildingActionID END
             AND exit54.buildingActionTypeID_FK=54 AND exit54.buildingActionActive=1
            WHERE w.ActionID=@ActionID AND w.LastActionTypeID=60
              AND current60.buildingActionID=@G57_S60
              AND w.residentInfoID=exit54.residentInfoID_FK
              AND w.GeneralNo=exit54.generalNo_FK
              AND w.buildingDetailsID=exit54.buildingDetailsID_FK
              AND w.IdaraId=exit54.IdaraId_FK
              AND current60.residentInfoID_FK=exit54.residentInfoID_FK
              AND prev.residentInfoID_FK=exit54.residentInfoID_FK
              AND current60.generalNo_FK=exit54.generalNo_FK
              AND prev.generalNo_FK=exit54.generalNo_FK
              AND current60.buildingDetailsID_FK=exit54.buildingDetailsID_FK
              AND prev.buildingDetailsID_FK=exit54.buildingDetailsID_FK
              AND current60.IdaraId_FK=exit54.IdaraId_FK
              AND prev.IdaraId_FK=exit54.IdaraId_FK;

            IF @G57_Exit54 IS NULL OR @G57_Entry IS NULL OR @G57_Physical IS NULL
               OR @G57_Entry>@G57_Physical
               OR @G57_Resident IS NULL OR @G57_General IS NULL
               OR @G57_Home IS NULL OR @G57_Idara IS NULL
               OR @G57_Resident<>@ResidentInfoID_BIGINT
               OR @G57_General<>@GeneralNo_BIGINT
               OR @G57_Home<>@BuildingDetailsID_BIGINT
               OR @G57_Idara<>@IdaraID_INT
               OR @G57_Physical<>@ExitDate_DATE
               OR @G57_Entry<>@OccupentDate_DATE
               OR EXISTS (SELECT 1 FROM Housing.BuildingAction x WITH (UPDLOCK,HOLDLOCK)
                          WHERE x.buildingActionParentID=@G57_S60 AND x.buildingActionActive=1)
                THROW 50001,N'تعذر إثبات دورة الإخلاء 54 الحالية وتطابق بياناتها قبل الإرسال المالي.',1;

            SELECT @G57_Version=cyc.ProcessingVersion
            FROM Housing.ExitFinancialProcessingCycle cyc WITH (UPDLOCK,HOLDLOCK)
            WHERE cyc.ExitRequestActionID_FK=@G57_Exit54;

            IF @G57_Version=1
            BEGIN
                IF NULLIF(LTRIM(RTRIM(@entryData)),N'') IS NULL
                    THROW 50001,N'هوية منفذ الإحالة المالية مطلوبة.',1;
                -- Preserve existing exemption payment history. Never cap an exemption
                -- if historical active credits already extend beyond physical 54.
                IF EXISTS
                (
                    SELECT 1 FROM Housing.ResidentRentExemptionPayment p WITH (UPDLOCK,HOLDLOCK)
                    JOIN Housing.ResidentRentExemption e
                      ON e.residentRentExemptionID=p.residentRentExemptionID_FK
                    WHERE e.residentInfoID_FK=@G57_Resident
                      AND e.buildingDetailsID_FK=@G57_Home AND e.idaraID_FK=@G57_Idara
                      AND p.paymentActive=1
                      AND (TRY_CONVERT(DATE,p.exemptionFromDate)>@G57_Physical
                           OR TRY_CONVERT(DATE,p.exemptionToDate)>@G57_Physical
                           OR p.exemptionFromDate IS NULL OR p.exemptionToDate IS NULL)
                ) THROW 50001,N'يوجد سداد إعفاء مؤهل يتجاوز الاستلام الفعلي أو بلا فترة موثوقة.',1;

                EXEC Housing.ManageExitRentExemptionClosure
                  @Action=N'APPLY', @ExitRequestActionID=@G57_Exit54,
                  @ResidentInfoID=@G57_Resident,@BuildingDetailsID=@G57_Home,
                  @IdaraID=@G57_Idara,@ExitDate=@G57_Physical,
                  @EntryData=@entryData,@HostName=@hostName,@ReturnResult=0;

                -- Historical service completion over every completed pre-exit month.
                EXEC Housing.GenerateHistoricalServiceBillsForExitRequest
                  @Action=N'GENERATE', @ExitRequestActionID=@G57_Exit54,
                  @EntryData=@entryData, @HostName=@hostName, @ReturnResult=0;

                EXEC Housing.GenerateExitRentBillsForRequest
                  @Action=N'GENERATE',@ResidentInfoID=@G57_Resident,@GeneralNo=@G57_General,
                  @BuildingDetailsID=@G57_Home,@OccupentDate=@G57_Entry,
                  @ExitDate=@G57_Physical,@ExitRequestActionID=@G57_Exit54,
                  @IdaraID=@G57_Idara,@EntryData=@entryData,@HostName=@hostName;

                
                -- Financial-ledger safe: fill missing active credits only.
                DECLARE @G57_BackfillID BIGINT;
                DECLARE G57_Backfill CURSOR LOCAL FAST_FORWARD FOR
                    SELECT e.residentRentExemptionID
                    FROM Housing.ResidentRentExemption e WITH (UPDLOCK,HOLDLOCK)
                    WHERE e.residentInfoID_FK=@G57_Resident
                      AND e.buildingDetailsID_FK=@G57_Home
                      AND e.idaraID_FK=@G57_Idara
                      AND e.residentRentExemptionActive=1
                      AND e.residentRentExemptionStartDate IS NOT NULL
                      AND CONVERT(DATE,e.residentRentExemptionStartDate)<=@G57_Physical
                      AND (e.residentRentExemptionEndDate IS NULL
                           OR CONVERT(DATE,e.residentRentExemptionEndDate)>=@G57_Entry);
                OPEN G57_Backfill;
                FETCH NEXT FROM G57_Backfill INTO @G57_BackfillID;
                WHILE @@FETCH_STATUS=0
                BEGIN
                    EXEC Housing.SyncRentExemptionPayments
                      @Action=N'GENERATE',@ResidentRentExemptionID=@G57_BackfillID,
                      @ThroughDate=@G57_Physical,@SourceType=N'EXIT_GAP_BACKFILL',
                      @EntryData=@entryData,@HostName=@hostName,@TargetBillsID=NULL;
                    FETCH NEXT FROM G57_Backfill INTO @G57_BackfillID;
                END;
                CLOSE G57_Backfill;
                DEALLOCATE G57_Backfill;

                -- Reject an eligible active rent invoice without required active credit.
                IF EXISTS
                (
                    SELECT 1 FROM Housing.Bills b WITH (UPDLOCK,HOLDLOCK)
                    JOIN Housing.ResidentRentExemption e
                      ON e.residentInfoID_FK=b.residentInfoID_FK
                     AND e.buildingDetailsID_FK=b.buildingDetailsID
                     AND e.idaraID_FK=b.idaraID_FK
                     AND e.residentRentExemptionActive=1
                     AND CONVERT(DATE,e.residentRentExemptionStartDate)<=CONVERT(DATE,b.BillsToDate)
                     AND (e.residentRentExemptionEndDate IS NULL
                          OR CONVERT(DATE,e.residentRentExemptionEndDate)>=CONVERT(DATE,b.BillsFromDate))
                    WHERE b.BillActive=1 AND b.BillChargeTypeID_FK=1
                      AND b.residentInfoID_FK=@G57_Resident
                      AND b.buildingDetailsID=@G57_Home AND b.idaraID_FK=@G57_Idara
                      AND CONVERT(DATE,b.BillsFromDate)<=@G57_Physical
                      AND CONVERT(DATE,b.BillsToDate)>=@G57_Entry
                      AND NOT EXISTS
                      (SELECT 1 FROM Housing.ResidentRentExemptionPayment p
                       WHERE p.residentRentExemptionID_FK=e.residentRentExemptionID
                         AND p.billsID_FK=b.BillsID AND p.paymentActive=1)
                ) THROW 50001,N'فاتورة إيجار مؤهلة لا تملك سداد الإعفاء المستحق.',1;

                EXEC Housing.GenerateExitServiceBillsForRequest
                  @Action=N'GENERATE',@ResidentInfoID=@G57_Resident,@GeneralNo=@G57_General,
                  @BuildingDetailsID=@G57_Home,@OccupentDate=@G57_Entry,
                  @ExitDate=@G57_Physical,@ExitRequestActionID=@G57_Exit54,
                  @IdaraID=@G57_Idara,@EntryData=@entryData,@HostName=@hostName;

                -- INDEPENDENT RENT COVERAGE: Every calendar day has exactly one active bill.
                DECLARE @G57_RentGaps BIGINT=0;
                ;WITH Days AS
                (
                    SELECT @G57_Entry AS BillDay
                    UNION ALL SELECT DATEADD(DAY,1,BillDay)
                    FROM Days WHERE BillDay<@G57_Physical
                ), Counts AS
                (
                    SELECT d.BillDay,(SELECT COUNT_BIG(*) FROM Housing.Bills b WITH (UPDLOCK,HOLDLOCK)
                      WHERE b.residentInfoID_FK=@G57_Resident
                        AND b.buildingDetailsID=@G57_Home AND b.idaraID_FK=@G57_Idara
                        AND b.BillActive=1 AND b.BillChargeTypeID_FK=1
                        AND b.BillTypeID_FK IN (2,3)
                        AND CONVERT(DATE,b.BillsFromDate)<=d.BillDay
                        AND CONVERT(DATE,b.BillsToDate)>=d.BillDay) AS N
                    FROM Days d
                )
                SELECT @G57_RentGaps=COUNT_BIG(*) FROM Counts WHERE N<>1
                OPTION(MAXRECURSION 32767);
                IF @G57_RentGaps>0
                    THROW 50001,N'فواتير إيجار الإشغال غير مكتملة أو بها تداخل؛ لا يمكن إرسال الإخلاء.',1;

                -- New-cycle rent invoices must have a trustworthy exit-day bound.
                IF NOT EXISTS
                (
                    SELECT 1 FROM Housing.Bills b WITH (UPDLOCK,HOLDLOCK)
                    WHERE b.ExitRequestActionID_FK=@G57_Exit54
                      AND b.residentInfoID_FK=@G57_Resident
                      AND b.buildingDetailsID=@G57_Home AND b.idaraID_FK=@G57_Idara
                      AND b.BillActive=1 AND b.BillTypeID_FK=3
                      AND b.BillChargeTypeID_FK=1
                      AND CONVERT(DATE,b.BillsToDate)=@G57_Physical
                ) THROW 50001,N'فاتورة إيجار الإخلاء غير مكتملة حتى يوم الاستلام.',1;

                -- Ensure all capped exemptions end no later than physical 54.
                IF EXISTS
                (
                    SELECT 1 FROM Housing.ResidentRentExemption e WITH (UPDLOCK,HOLDLOCK)
                    WHERE e.residentInfoID_FK=@G57_Resident
                      AND e.buildingDetailsID_FK=@G57_Home AND e.idaraID_FK=@G57_Idara
                      AND e.residentRentExemptionActive=1
                      AND CONVERT(DATE,e.residentRentExemptionStartDate)<=@G57_Physical
                      AND (e.residentRentExemptionEndDate IS NULL
                           OR CONVERT(DATE,e.residentRentExemptionEndDate)>@G57_Physical)
                ) THROW 50001,N'تعذر إنهاء جميع الإعفاءات المؤهلة بتاريخ الاستلام الفعلي.',1;

                -- Exit-month exempt rent must have a generated credit when eligible.
                IF EXISTS
                (
                    SELECT 1 FROM Housing.Bills b WITH (UPDLOCK,HOLDLOCK)
                    JOIN Housing.ResidentRentExemption e
                      ON e.residentInfoID_FK=b.residentInfoID_FK
                     AND e.buildingDetailsID_FK=b.buildingDetailsID
                     AND e.idaraID_FK=b.idaraID_FK
                     AND e.residentRentExemptionActive=1
                     AND CONVERT(DATE,e.residentRentExemptionStartDate)<=CONVERT(DATE,b.BillsToDate)
                     AND (e.residentRentExemptionEndDate IS NULL OR
                          CONVERT(DATE,e.residentRentExemptionEndDate)>=CONVERT(DATE,b.BillsFromDate))
                    WHERE b.ExitRequestActionID_FK=@G57_Exit54
                      AND b.BillActive=1 AND b.BillChargeTypeID_FK=1 AND b.BillTypeID_FK=3
                      AND NOT EXISTS
                      (SELECT 1 FROM Housing.ResidentRentExemptionPayment p
                       WHERE p.residentRentExemptionID_FK=e.residentRentExemptionID
                         AND p.billsID_FK=b.BillsID AND p.paymentActive=1)
                ) THROW 50001,N'فاتورة إيجار الإخلاء لا تتضمن سداد الإعفاء المستحق.',1;

                -- Reading-meter bills: exact meter and current stage59/54 date,
                -- exactly one active exit read and exactly one active linked invoice.
                IF EXISTS
                (
                    SELECT 1
                    FROM Housing.MeterForBuilding link
                    JOIN Housing.Meter m ON m.meterID=link.meterID_FK
                    JOIN Housing.MeterType mt ON mt.meterTypeID=m.meterTypeID_FK
                    OUTER APPLY
                    (
                        SELECT COUNT_BIG(DISTINCT r.meterReadID) AS Reads,
                          COUNT_BIG(DISTINCT CASE WHEN b.BillsID IS NOT NULL THEN b.BillsID END) AS Bills
                        FROM Housing.MeterRead r
                        LEFT JOIN Housing.Bills b
                          ON b.meterReadID=r.meterReadID AND b.meterID=m.meterID
                         AND b.BillActive=1 AND b.BillTypeID_FK=3
                         AND b.residentInfoID_FK=@G57_Resident
                         AND b.generalNo_FK=@G57_General
                         AND b.buildingDetailsID=@G57_Home AND b.idaraID_FK=@G57_Idara
                         AND b.PeriodYear=YEAR(@G57_Physical)
                         AND b.PeriodMonth=MONTH(@G57_Physical)
                        WHERE r.meterID_FK=m.meterID AND r.meterReadActive=1
                          AND r.meterReadTypeID_FK=3 AND r.buildingActionID_FK=@G57_S59
                          AND CONVERT(DATE,r.dateOfRead)=@G57_Physical
                    ) match_
                    WHERE link.buildingDetailsID_FK=@G57_Home
                      AND link.IdaraID_FK=@G57_Idara
                      AND link.meterForBuildingActive=1 AND m.meterActive=1 AND mt.meterTypeActive=1
                      AND mt.IdaraId_FK=@G57_Idara AND mt.MeterCalculateTypeID_FK=1
                      AND (link.meterForBuildingStartDate IS NULL OR CONVERT(DATE,link.meterForBuildingStartDate)<=@G57_Physical)
                      AND (link.meterForBuildingEndDate IS NULL OR CONVERT(DATE,link.meterForBuildingEndDate)>=@G57_Physical)
                      AND (m.meterStartDate IS NULL OR CONVERT(DATE,m.meterStartDate)<=@G57_Physical)
                      AND (m.meterEndDate IS NULL OR CONVERT(DATE,m.meterEndDate)>=@G57_Physical)
                      AND (match_.Reads<>1 OR match_.Bills<>1 OR @G57_S59 IS NULL)
                ) THROW 50001,N'القراءة النهائية أو فاتورتها غير مكتملة لأحد العدادات الفعلية.',1;

                -- Services: independently reject any configured, non-reading service
                -- that did not produce a correctly stamped cycle bill for the exit month.
                DECLARE @G57_MonthStart DATE=DATEFROMPARTS(YEAR(@G57_Physical),MONTH(@G57_Physical),1);
                IF @G57_Entry>@G57_MonthStart SET @G57_MonthStart=@G57_Entry;
                IF EXISTS
                (
                    SELECT 1 FROM Housing.MeterServiceType st
                    WHERE st.meterServiceTypeActive=1
                      AND (st.meterServiceTypeStartDate IS NULL OR CONVERT(DATE,st.meterServiceTypeStartDate)<=@G57_Physical)
                      AND (st.meterServiceTypeEndDate IS NULL OR CONVERT(DATE,st.meterServiceTypeEndDate)>=@G57_Physical)
                      AND EXISTS
                      (SELECT 1 FROM Housing.MeterServiceTypeLinkedWithIdara il
                       WHERE il.MeterServiceTypeID_FK=st.meterServiceTypeID
                         AND (il.Idara_FK=@G57_Idara OR il.Idara_FK IS NULL)
                         AND (il.MeterServiceTypeLinkedWithIdaraActive=1 OR il.MeterServiceTypeLinkedWithIdaraEndDate IS NOT NULL)
                         AND (il.MeterServiceTypeLinkedWithIdaraStartDate IS NULL OR CONVERT(DATE,il.MeterServiceTypeLinkedWithIdaraStartDate)<=@G57_MonthStart)
                         AND (il.MeterServiceTypeLinkedWithIdaraEndDate IS NULL OR CONVERT(DATE,il.MeterServiceTypeLinkedWithIdaraEndDate)>=@G57_Physical))
                      AND NOT EXISTS
                      (SELECT 1 FROM Housing.MeterForBuilding lm
                       JOIN Housing.Meter mm ON mm.meterID=lm.meterID_FK
                       JOIN Housing.MeterType tm ON tm.meterTypeID=mm.meterTypeID_FK
                       WHERE lm.buildingDetailsID_FK=@G57_Home AND lm.IdaraID_FK=@G57_Idara
                         AND lm.meterForBuildingActive=1 AND mm.meterActive=1 AND tm.meterTypeActive=1
                         AND tm.meterServiceTypeID_FK=st.meterServiceTypeID AND tm.MeterCalculateTypeID_FK=1
                         AND tm.IdaraId_FK=@G57_Idara
                         AND (lm.meterForBuildingStartDate IS NULL OR CONVERT(DATE,lm.meterForBuildingStartDate)<=@G57_Physical)
                         AND (lm.meterForBuildingEndDate IS NULL OR CONVERT(DATE,lm.meterForBuildingEndDate)>=@G57_Physical))
                      AND
                      (
                       EXISTS
                       (SELECT 1 FROM Housing.MeterForBuilding lm
                        JOIN Housing.Meter mm ON mm.meterID=lm.meterID_FK
                        JOIN Housing.MeterType tm ON tm.meterTypeID=mm.meterTypeID_FK
                        WHERE lm.buildingDetailsID_FK=@G57_Home AND lm.IdaraID_FK=@G57_Idara
                          AND lm.meterForBuildingActive=1 AND mm.meterActive=1 AND tm.meterTypeActive=1
                          AND tm.meterServiceTypeID_FK=st.meterServiceTypeID AND tm.MeterCalculateTypeID_FK=2
                          AND tm.IdaraId_FK=@G57_Idara
                          AND (lm.meterForBuildingStartDate IS NULL OR CONVERT(DATE,lm.meterForBuildingStartDate)<=@G57_Physical)
                          AND (lm.meterForBuildingEndDate IS NULL OR CONVERT(DATE,lm.meterForBuildingEndDate)>=@G57_Physical))
                       OR EXISTS (SELECT 1 FROM Housing.BuildingDetailsMeterServices bms
                          WHERE bms.BuildingDetailsID_FK=@G57_Home
                            AND bms.IdaraId_FK=@G57_Idara
                            AND bms.MeterServicesTypeID_FK=st.meterServiceTypeID
                            AND (bms.BuildingDetailsMeterServicesActive=1 OR bms.BuildingDetailsMeterServicesEndDate IS NOT NULL)
                            AND (bms.BuildingDetailsMeterServicesStartDate IS NULL OR CONVERT(DATE,bms.BuildingDetailsMeterServicesStartDate)<=@G57_MonthStart)
                            AND (bms.BuildingDetailsMeterServicesEndDate IS NULL OR CONVERT(DATE,bms.BuildingDetailsMeterServicesEndDate)>=@G57_Physical))
                      )
                      AND NOT EXISTS
                      (SELECT 1 FROM Housing.Bills b WITH (UPDLOCK,HOLDLOCK)
                       JOIN Housing.BillCalculation c ON c.BillsID_FK=b.BillsID
                       WHERE b.ExitRequestActionID_FK=@G57_Exit54
                         AND b.residentInfoID_FK=@G57_Resident
                         AND b.generalNo_FK=@G57_General
                         AND b.buildingDetailsID=@G57_Home AND b.idaraID_FK=@G57_Idara
                         AND b.BillActive=1 AND b.BillTypeID_FK=3
                         AND b.meterServiceTypeID=st.meterServiceTypeID
                         AND CONVERT(DATE,b.BillsFromDate)<=@G57_MonthStart
                         AND CONVERT(DATE,b.BillsToDate)>=@G57_Physical
                         AND c.CalculationMethod IN
    (N'SPACE_ESTIMATED', N'FIXED_METER', N'SERVICE_FIXED_FALLBACK'))
)
THROW 50001,
    N'فاتورة خدمة مستحقة غير مكتملة لفترة الإخلاء أو لا تطابق نوع الخدمة.', 1;
                -- This gate proves exit-month service presence, but not historical
                -- service coverage for EVERY prior tenancy month. That is a separate
                -- pre-release blocker and must be verified before deploying this draft.
            END
            ELSE
            BEGIN
                -- Legacy path unchanged (not enrolled in ProcessingVersion=1).
                EXEC Housing.GenerateFixedServiceBillsForResidentPeriod
                      @ResidentInfoID=@ResidentInfoID_BIGINT,@GeneralNo=@GeneralNo_BIGINT,
                      @BuildingDetailsID=@BuildingDetailsID_BIGINT,
                      @FromDate=@OccupentDate_DATE,@ToDate=@ExitDate_DATE,
                      @IdaraID=@IdaraID_INT,@EntryData=@entryData,@HostName=@hostName;
            END;

              INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingDetailsID_FK
                , buildingDetailsNo
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , buildingActionDate
                , OccupentDate
                , ExitDate
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  57
                , @residentInfoID
                , @GeneralNo
                , @buildingDetailsID
                , @buildingDetailsNo
                , 1
                , @Notes
                , @LastActionID
                , @ExitDate  
                , @OccupentDate
                , @ExitDate
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في ارسال الطلب للتدقيق المالي', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في ارسال الطلب للتدقيق المالي - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionTypeID_FK), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingDetailsID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"buildingDetailsNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), '') + N'"'
                + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"buildingActionNote": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @LastActionID), '') + N'"'
                + N',"buildingActionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExitDate), '') + N'"'
                + N',"entryData": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Housing].[BuildingAction]'
                , N'SENDHOUSINGEXITTOFINANCE'
                , @ActionID
                , @entryData
                , @Note
            );
            

            IF @tc = 0 COMMIT TRANSACTION;
            

            SELECT 1 AS IsSuccessful, N'تم ارسال طلب الاخلاء للتدقيق المالي بنجاح' AS Message_;
            RETURN;
        END


        
         ----------------------------------------------------------------
        -- HOUSINGEXIT
        ----------------------------------------------------------------
        IF @Action = N'APPROVEHOUSINGEXIT'
        BEGIN
       


            IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END


            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.ActionID = @ActionID
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            
              IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) Not in (58)
            BEGIN
                ;THROW 50001, N'المستفيد غير مؤهل للاخلاء لعدم انتهاء التدقيق المالي', 1;
            END



            
          


            
            -- EXIT_3_V1_LEDGER_SAFE: preserve stage 57 accounting for registered cycles.
            DECLARE @G3_Exit54 BIGINT = NULL;
            SELECT TOP (1) @G3_Exit54=a.buildingActionID
            FROM Housing.fn_BuildingAction_ChainToRoot(TRY_CONVERT(BIGINT,@LastActionID)) a
            WHERE a.buildingActionTypeID_FK=54 AND a.buildingActionActive=1
              AND a.residentInfoID_FK=@ResidentInfoID_BIGINT
              AND a.buildingDetailsID_FK=@BuildingDetailsID_BIGINT
              AND a.IdaraId_FK=@IdaraID_INT
              AND CONVERT(DATE,a.ExitDate)=@ExitDate_DATE
            ORDER BY a.Lvl ASC;

            DECLARE @G3_Version INT=NULL;
            SELECT @G3_Version=cyc.ProcessingVersion
            FROM Housing.ExitFinancialProcessingCycle cyc WITH (UPDLOCK,HOLDLOCK)
            WHERE cyc.ExitRequestActionID_FK=@G3_Exit54;

            -- V1 cannot fail open to legacy processing due to incorrect 54 context.
            IF @G3_Version IS NULL AND EXISTS
            (
                SELECT 1
                FROM Housing.fn_BuildingAction_ChainToRoot(TRY_CONVERT(BIGINT,@LastActionID)) a
                JOIN Housing.ExitFinancialProcessingCycle cyc
                  ON cyc.ExitRequestActionID_FK=a.buildingActionID
                WHERE cyc.ProcessingVersion=1
            ) THROW 50001,N'تعذر التحقق من دورة الإخلاء المسجلة؛ لا يمكن اعتمادها.',1;

            IF @G3_Version=1
            BEGIN
                -- Stage 57 must be present in this exact action chain, prior to 58.
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM Housing.fn_BuildingAction_ChainToRoot(TRY_CONVERT(BIGINT,@LastActionID)) a
                    WHERE a.buildingActionTypeID_FK=57 AND a.buildingActionActive=1
                      AND a.residentInfoID_FK=@ResidentInfoID_BIGINT
                      AND a.buildingDetailsID_FK=@BuildingDetailsID_BIGINT
                      AND a.IdaraId_FK=@IdaraID_INT
                ) THROW 50001,N'لم تثبت مرحلة إرسال الإخلاء للتدقيق المالي في الدورة الحالية.',1;

                -- Stage 57 must have capped all overlapping active rent exemptions
                -- at the original physical handover date from action 54.
                IF EXISTS
                (
                    SELECT 1
                    FROM Housing.ResidentRentExemption e WITH (UPDLOCK,HOLDLOCK)
                    WHERE e.residentInfoID_FK=@ResidentInfoID_BIGINT
                      AND e.buildingDetailsID_FK=@BuildingDetailsID_BIGINT
                      AND e.idaraID_FK=@IdaraID_INT
                      AND e.residentRentExemptionActive=1
                      AND CONVERT(DATE,e.residentRentExemptionStartDate)<=@ExitDate_DATE
                      AND (e.residentRentExemptionEndDate IS NULL
                           OR CONVERT(DATE,e.residentRentExemptionEndDate)>@ExitDate_DATE)
                ) THROW 50001,N'لم تُغلق إعفاءات الإيجار المستحقة على تاريخ الاستلام الفعلي.',1;
            END;

            INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingDetailsID_FK
                , buildingDetailsNo
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , buildingActionDate
                , OccupentDate
                , ExitDate
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  3
                , @residentInfoID
                , @GeneralNo
                , @buildingDetailsID
                , @buildingDetailsNo
                , 1
                , @Notes
                , @LastActionID
                , @ExitDate  
                , @OccupentDate
                , @ExitDate
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اعتماد طلب الاخلاء', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اعتماد طلب الاخلاء - Identity', 1; -- برمجي
            END

            -- قد يختلف تاريخ الإخلاء النهائي عن التاريخ الذي رُصدت به الفاتورة عند إنشاء/تعديل الطلب.
            -- إلغاء فاتورة الإخلاء السابقة وإعادة إنشائها بالتاريخ النهائي قبل رصد سداد الإعفاء.
            IF ISNULL(@G3_Version,0)<>1
            BEGIN -- Legacy only: never recalculate V1 rent or exemption payments at 3.
            EXEC Housing.GenerateExitRentBills
                  @Action = N'REGENERATE'
                , @ResidentInfoID = @ResidentInfoID_BIGINT
                , @GeneralNo = @GeneralNo_BIGINT
                , @BuildingDetailsID = @BuildingDetailsID_BIGINT
                , @OccupentDate = @OccupentDate_DATE
                , @ExitDate = @ExitDate_DATE
                , @IdaraID = @IdaraID_INT
                , @EntryData = @entryData
                , @HostName = @hostName;

            /* استكمال أي رسوم خدمات ثابتة ناقصة حتى تاريخ الإخلاء النهائي
               باستخدام المحرك نفسه المستخدم في الرصد الشهري والتسكين المتأخر. */
            EXEC Housing.GenerateFixedServiceBillsForResidentPeriod
                  @ResidentInfoID = @ResidentInfoID_BIGINT
                , @GeneralNo = @GeneralNo_BIGINT
                , @BuildingDetailsID = @BuildingDetailsID_BIGINT
                , @FromDate = @OccupentDate_DATE
                , @ToDate = @ExitDate_DATE
                , @IdaraID = @IdaraID_INT
                , @EntryData = @entryData
                , @HostName = @hostName;

            DECLARE @FinalizedExemptions TABLE
            (
                residentRentExemptionID BIGINT PRIMARY KEY
            );

            UPDATE exemption
               SET exemption.residentRentExemptionEndDate = @ExitDate_DATE
            OUTPUT inserted.residentRentExemptionID
              INTO @FinalizedExemptions (residentRentExemptionID)
            FROM Housing.ResidentRentExemption exemption
            WHERE exemption.residentInfoID_FK = @ResidentInfoID_BIGINT
              AND exemption.residentRentExemptionActive = 1
              AND exemption.buildingDetailsID_FK = @BuildingDetailsID_BIGINT
              AND
              (
                  exemption.residentRentExemptionEndDate IS NULL
                  OR CAST(exemption.residentRentExemptionEndDate AS date) > @ExitDate_DATE
              );

            DECLARE @FinalizedExemptionID BIGINT;
            DECLARE finalizedExemptionCursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT residentRentExemptionID
            FROM @FinalizedExemptions;

            OPEN finalizedExemptionCursor;
            FETCH NEXT FROM finalizedExemptionCursor INTO @FinalizedExemptionID;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                EXEC Housing.SyncRentExemptionPayments
                      @Action = N'CANCEL'
                    , @ResidentRentExemptionID = @FinalizedExemptionID
                    , @SourceType = N'FINAL_EXIT_RECALC'
                    , @EntryData = @entryData
                    , @HostName = @hostName;

                EXEC Housing.SyncRentExemptionPayments
                      @Action = N'GENERATE'
                    , @ResidentRentExemptionID = @FinalizedExemptionID
                    , @ThroughDate = @ExitDate_DATE
                    , @SourceType = N'FINAL_EXIT'
                    , @EntryData = @entryData
                    , @HostName = @hostName;

                FETCH NEXT FROM finalizedExemptionCursor INTO @FinalizedExemptionID;
            END;

            CLOSE finalizedExemptionCursor;
            DEALLOCATE finalizedExemptionCursor;
            END; -- EXIT_3_V1_LEDGER_SAFE_LEGACY_END

        -- التحقق المالي النهائي بعد إعادة احتساب الإيجار والخدمات والإعفاءات

IF @ResidentInfoID_BIGINT IS NULL
   OR @BuildingDetailsID_BIGINT IS NULL
   OR @IdaraID_INT IS NULL
BEGIN
    ;THROW 50001,
        N'بيانات التدقيق المالي لاعتماد الإخلاء غير مكتملة.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM Housing.V_SumBillsTotalPriceAndTotalPaidForResident e
    WHERE e.residentInfoID = @ResidentInfoID_BIGINT
      AND
      (
          e.buildingDetailsID = @BuildingDetailsID_BIGINT
          OR e.buildingDetailsID IS NULL
      )
)
BEGIN
    ;THROW 50001,
        N'تعذر التحقق من الرصيد المالي النهائي؛ لا يمكن اعتماد الإخلاء.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM Housing.V_SumBillsTotalPriceAndTotalPaidForResident e
    WHERE e.residentInfoID = @ResidentInfoID_BIGINT
      AND
      (
          e.buildingDetailsID = @BuildingDetailsID_BIGINT
          OR e.buildingDetailsID IS NULL
      )
    GROUP BY
        e.BillChargeTypeID,
        e.buildingDetailsID
    HAVING
        SUM(CONVERT(DECIMAL(38,2), e.Remaining)) <> 0
        OR COUNT_BIG(e.Remaining) <> COUNT_BIG(*)
)
BEGIN
    ;THROW 50001,
        N'لا يمكن اعتماد الإخلاء؛ توجد أرصدة خدمات غير مصفاة أو تسويات مالية غير مكتملة.', 1;
END;

            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionTypeID_FK), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingDetailsID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"buildingDetailsNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), '') + N'"'
                + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"buildingActionNote": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @LastActionID), '') + N'"'
                + N',"buildingActionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExitDate), '') + N'"'
                + N',"entryData": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Housing].[BuildingAction]'
                , N'HOUSINGEXIT'
                , @ActionID
                , @entryData
                , @Note
            );
            

            IF @tc = 0 COMMIT TRANSACTION;
            

            SELECT 1 AS IsSuccessful, N'تم اعتماد طلب الاخلاء بنجاح' AS Message_;
            RETURN;
        END





          ----------------------------------------------------------------
        -- HOUSINGEXITPENALTYRECORD
        ----------------------------------------------------------------
        ELSE IF @Action = N'HOUSINGEXITPENALTYRECORD'
        BEGIN
       


            IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END


            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.ActionID = @ActionID
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END


              IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) Not in (54,59,60)
            BEGIN
                ;THROW 50001, N'لايمكن اضافة / تعديل غرامات للطلب', 1;
            END
            -- Penalty must reference the registered exit-54 cycle of this exact action chain.
            DECLARE @Penalty_CurrentExit54ID BIGINT = NULL;

            SELECT TOP (1) @Penalty_CurrentExit54ID = a.buildingActionID
            FROM Housing.fn_BuildingAction_ChainToRoot(TRY_CONVERT(BIGINT, @LastActionID)) AS a
            INNER JOIN Housing.ExitFinancialProcessingCycle AS c
                ON c.ExitRequestActionID_FK = a.buildingActionID
               AND c.ProcessingVersion = 1
            WHERE a.buildingActionTypeID_FK = 54
              AND a.buildingActionActive = 1
              AND a.residentInfoID_FK = @ResidentInfoID_BIGINT
              AND a.generalNo_FK = @GeneralNo_BIGINT
              AND a.buildingDetailsID_FK = @BuildingDetailsID_BIGINT
              AND a.IdaraId_FK = @IdaraID_INT
            ORDER BY a.Lvl DESC;

            IF @Penalty_CurrentExit54ID IS NULL
                THROW 50001, N'تعذر تحديد دورة الإخلاء المرتبطة بالغرامة.', 1;

            -------------------------------------------------------------

            ------------------------------------------------------------
-- إصدار فواتير العدادات الثابتة عند خروج الساكن
-- ثم تحديد الإجراء التالي: 59 أو 60
------------------------------------------------------------

DECLARE @buildingActionTypeID_FKForMeterRead INT;

DECLARE @ExitDateForBill             DATE;
DECLARE @OccupentDateForBill         DATE;
DECLARE @BillPeriodStartDateForExit  DATE;
DECLARE @BillPeriodMonthDateForExit  DATE;
DECLARE @BillPeriodEndDateForExit    DATE;
DECLARE @ChargeStartDateForExit      DATE;
DECLARE @ChargeEndDateForExit        DATE;

DECLARE @BillMonthForExit            INT;
DECLARE @BillYearForExit             INT;
DECLARE @ChargeDaysForExit           INT;

DECLARE @TaxRateForExit              DECIMAL(18,2) = 0;
DECLARE @PreviousBillPeriodID        BIGINT = NULL;
DECLARE @FixedBillsInserted          INT = 0;

DECLARE @billPeriodID                 BIGINT
SET @billPeriodID = (select top(1) b.billPeriodID from Housing.BillPeriod b where b.IdaraId_FK = 1 and b.billPeriodTypeID_FK =(select t.billPeriodTypeID from Housing.BillPeriodType t where t.meterServiceTypeID_FK = 1) order by b.billPeriodID desc)

------------------------------------------------------------
-- تحويل تاريخ الخروج
------------------------------------------------------------
SET @ExitDateForBill =
    TRY_CONVERT
    (
        DATE,
        NULLIF(LTRIM(RTRIM(@ExitDate)), N'')
    );

IF @ExitDateForBill IS NULL
BEGIN
    ;THROW 50001, N'تاريخ الخروج غير صحيح', 1;
END;

------------------------------------------------------------
-- التحقق من رقم المبنى والساكن
------------------------------------------------------------
IF TRY_CONVERT(BIGINT, @buildingDetailsID) IS NULL
BEGIN
    ;THROW 50001, N'رقم المبنى غير صحيح', 1;
END;

IF TRY_CONVERT(BIGINT, @residentInfoID) IS NULL
BEGIN
    ;THROW 50001, N'رقم الساكن غير صحيح', 1;
END;

------------------------------------------------------------
-- جلب فترة الفاتورة
------------------------------------------------------------
SELECT TOP (1)
      @BillPeriodStartDateForExit =
          CAST(p.billPeriodStartDate AS DATE)

    , @BillMonthForExit =
          MONTH(p.billPeriodStartDate)

    , @BillYearForExit =
          YEAR(p.billPeriodStartDate)

    , @BillPeriodMonthDateForExit =
          DATEFROMPARTS
          (
              YEAR(p.billPeriodStartDate),
              MONTH(p.billPeriodStartDate),
              1
          )

FROM Housing.BillPeriod p

WHERE p.billPeriodID = @billPeriodID
  --AND p.billPeriodActive = 1
  AND p.IdaraId_FK = @IdaraID_INT
  order by p.billPeriodID desc
  ;

IF @BillPeriodStartDateForExit IS NULL
BEGIN
    ;THROW 50001, N'فترة الفاتورة غير موجودة أو غير نشطة', 1;
END;

SET @BillPeriodEndDateForExit =
    EOMONTH(@BillPeriodMonthDateForExit);

------------------------------------------------------------
-- جلب تاريخ بداية سكن الساكن
-- يبقى buildingActionRoot = 2 كما هو
------------------------------------------------------------
SELECT TOP (1)
    @OccupentDateForBill =
        CAST(vw.OccupentDate AS DATE)

FROM Housing.V_WaitingList vw

WHERE vw.residentInfoID =
          TRY_CONVERT(BIGINT, @residentInfoID)

  AND vw.buildingDetailsID =
          TRY_CONVERT(BIGINT, @buildingDetailsID)

  AND vw.buildingActionRoot = 2
  AND vw.OccupentDate IS NOT NULL

ORDER BY
      vw.OccupentDate DESC
    , vw.ActionID DESC;

IF @OccupentDateForBill IS NULL
BEGIN
    ;THROW 50001, N'لم يتم العثور على تاريخ سكن المستفيد', 1;
END;

------------------------------------------------------------
-- تحديد بداية الاحتساب
--
-- الأصل: بداية شهر الفاتورة
-- إذا بدأ السكن أثناء الشهر: يبدأ الحساب من تاريخ السكن
------------------------------------------------------------
SET @ChargeStartDateForExit =
    CASE
        WHEN @OccupentDateForBill >
             @BillPeriodMonthDateForExit
         AND @OccupentDateForBill <=
             @BillPeriodEndDateForExit
        THEN @OccupentDateForBill

        ELSE @BillPeriodMonthDateForExit
    END;

------------------------------------------------------------
-- تحديد نهاية الاحتساب
--
-- إذا كان الخروج داخل الشهر: حتى تاريخ الخروج
-- إذا كان بعد نهاية الشهر: حتى نهاية الشهر
------------------------------------------------------------
SET @ChargeEndDateForExit =
    CASE
        WHEN @ExitDateForBill <
             @BillPeriodEndDateForExit
        THEN @ExitDateForBill

        ELSE @BillPeriodEndDateForExit
    END;

------------------------------------------------------------
-- التحقق من أن الساكن كان موجودًا خلال فترة الفاتورة
------------------------------------------------------------
IF @ChargeEndDateForExit < @ChargeStartDateForExit
BEGIN
    ;THROW 50001,
        N'تاريخ خروج الساكن لا يقع ضمن فترة الفاتورة المحددة',
        1;
END;

------------------------------------------------------------
-- حساب عدد الأيام شامل يوم الخروج
------------------------------------------------------------
SET @ChargeDaysForExit =
    DATEDIFF
    (
        DAY,
        @ChargeStartDateForExit,
        @ChargeEndDateForExit
    ) + 1;

------------------------------------------------------------
-- نظام الحساب يعتمد الشهر 30 يومًا
------------------------------------------------------------
IF @ChargeDaysForExit > 30
BEGIN
    SET @ChargeDaysForExit = 30;
END;

IF @ChargeDaysForExit < 1
BEGIN
    SET @ChargeDaysForExit = 1;
END;

------------------------------------------------------------
-- جلب نسبة الضريبة السارية بتاريخ الخروج
------------------------------------------------------------
SELECT TOP (1)
    @TaxRateForExit =
        ISNULL(tx.taxRate, 0)

FROM dbo.Tax tx

WHERE @ExitDateForBill >=
          CAST(tx.taxStartDate AS DATE)

  AND
  (
      tx.taxEndDate IS NULL

      OR @ExitDateForBill <=
         CAST(tx.taxEndDate AS DATE)
  )

ORDER BY tx.taxStartDate DESC;

SET @TaxRateForExit =
    ISNULL(@TaxRateForExit, 0);

------------------------------------------------------------
-- جلب فترة الفاتورة السابقة
------------------------------------------------------------
SELECT TOP (1)
    @PreviousBillPeriodID =
        p.billPeriodID

FROM Housing.BillPeriod p

WHERE p.IdaraId_FK = @IdaraID_INT
  AND p.billPeriodID < @billPeriodID

ORDER BY p.billPeriodID DESC;

------------------------------------------------------------
-- إصدار فاتورة مستقلة لكل عداد ثابت
------------------------------------------------------------
;WITH FixedMeters AS
(
    SELECT
          mfb.meterForBuildingID
        , mfb.buildingDetailsID_FK

        , m.meterID
        , m.meterTypeID_FK

        , mt.meterServiceTypeID_FK

        , mst.BillChargeTypeID_FK

        , b.buildingDetailsNo
        , b.buildingUtilityTypeID_FK
        , b.buildingDetailsID

        , fixedAmount.FixedAmount

    FROM Housing.MeterForBuilding mfb

    INNER JOIN Housing.Meter m
        ON m.meterID = mfb.meterID_FK
       AND m.meterActive = 1

    INNER JOIN Housing.MeterType mt
        ON mt.meterTypeID = m.meterTypeID_FK
       AND mt.meterTypeActive = 1
       AND mt.IdaraId_FK = @IdaraID_INT

       -- النوع الثابت
       AND mt.MeterCalculateTypeID_FK = 2

    INNER JOIN Housing.MeterServiceType mst
        ON mst.meterServiceTypeID =
               mt.meterServiceTypeID_FK

       AND mst.meterServiceTypeActive = 1

    INNER JOIN Housing.V_GetGeneralListForBuilding b
        ON b.buildingDetailsID =
               mfb.buildingDetailsID_FK

       AND b.BuildingIdaraID = @IdaraID_INT

    --------------------------------------------------------
    -- جلب آخر مبلغ ثابت نشط لنوع العداد
    --------------------------------------------------------
    CROSS APPLY
    (
        SELECT TOP (1)
            CAST(mc.FixedAmount AS DECIMAL(18,2))
                AS FixedAmount

        FROM Housing.MeterTypeFixedAmount mc

        WHERE mc.MeterTypeID_FK = mt.meterTypeID
          AND mc.IdaraID_FK = @IdaraID_INT
          AND (mc.MeterTypeFixedAmountActive = 1 OR mc.MeterTypeFixedAmountEndDate IS NOT NULL)
          AND ISNULL(mc.FixedAmount, 0) > 0
          AND (mc.MeterTypeFixedAmountStartDate IS NULL OR CAST(mc.MeterTypeFixedAmountStartDate AS date) <= @ChargeEndDateForExit)
          AND (mc.MeterTypeFixedAmountEndDate IS NULL OR CAST(mc.MeterTypeFixedAmountEndDate AS date) >= @ChargeStartDateForExit)

        ORDER BY
            mc.MeterTypeFixedAmountID DESC
    ) fixedAmount

    WHERE mfb.buildingDetailsID_FK =
              TRY_CONVERT(BIGINT, @buildingDetailsID)

      AND mfb.IdaraID_FK = @IdaraID_INT
      AND mfb.meterForBuildingActive = 1

      ------------------------------------------------------
      -- التأكد من ارتباط الخدمة بالإدارة
      ------------------------------------------------------
      AND EXISTS
      (
          SELECT 1

          FROM Housing.MeterServiceTypeLinkedWithIdara msl

          WHERE msl.MeterServiceTypeID_FK =
                    mt.meterServiceTypeID_FK

            AND msl.Idara_FK = @IdaraID_INT

            AND
                msl.MeterServiceTypeLinkedWithIdaraActive = 1
      )
)

INSERT INTO Housing.Bills
(
      BillChargeTypeID_FK
    , BillTypeID_FK
    , CurrentPeriodID
    , PerviosPeriodID
    , PeriodMonth
    , PeriodYear
    , CurrentPeriodTax

    , buildingDetailsNo
    , buildingUtilityTypeID
    , buildingDetailsID

    , meterID
    , meterReadID

    , residentInfoID_FK
    , generalNo_FK
    , meterServiceTypeID

    , CurrentRead
    , LastRead
    , ReadDiff

    , PRICE
    , PRICETAX

    , meterServicePrice
    , meterServicePriceTAX

    , TotalPrice

    , BillActive
    , idaraID_FK
    , entryDate
    , entryData
    , hostName
)

SELECT
      fm.BillChargeTypeID_FK

    -- فاتورة مبلغ ثابت
    , 2

    , @billPeriodID
    , @PreviousBillPeriodID
    , @BillMonthForExit
    , @BillYearForExit
    , @TaxRateForExit

    , fm.buildingDetailsNo
    , fm.buildingUtilityTypeID_FK
    , fm.buildingDetailsID

    --------------------------------------------------------
    -- مهم: تسجيل رقم كل عداد حتى تكون لكل عداد فاتورة
    --------------------------------------------------------
    , fm.meterID

    , NULL

    , TRY_CONVERT(BIGINT, @residentInfoID)
    , TRY_CONVERT(BIGINT, @GeneralNo)
    , fm.meterServiceTypeID_FK

    , 0
    , 0
    , 0

    --------------------------------------------------------
    -- قيمة الفاتورة من بداية الشهر حتى الخروج
    --------------------------------------------------------
    , calculatedAmount.CalculatedFixedAmount

    --------------------------------------------------------
    -- ضريبة المبلغ
    --------------------------------------------------------
    , CAST
      (
          calculatedAmount.CalculatedFixedAmount
          *
          (
              @TaxRateForExit / 100.0
          )
          AS DECIMAL(18,2)
      )

    , 0
    , 0

    --------------------------------------------------------
    -- إجمالي الفاتورة شامل الضريبة
    --------------------------------------------------------
    , CAST
      (
          calculatedAmount.CalculatedFixedAmount
          +
          (
              calculatedAmount.CalculatedFixedAmount
              *
              (
                  @TaxRateForExit / 100.0
              )
          )
          AS DECIMAL(18,2)
      )

    , 1
    , @IdaraID_INT
    , GETDATE()
    , @entryData
    , @hostName

FROM FixedMeters fm

CROSS APPLY
(
    SELECT
        CAST
        (
            (fm.FixedAmount / 30.00)
            * @ChargeDaysForExit
            AS DECIMAL(18,2)
        ) AS CalculatedFixedAmount
) calculatedAmount

------------------------------------------------------------
-- منع تكرار الفاتورة لكل عداد
------------------------------------------------------------
WHERE NOT EXISTS
(
    SELECT 1

    FROM Housing.Bills oldb

    WHERE oldb.CurrentPeriodID = @billPeriodID

      AND oldb.buildingDetailsID =
              fm.buildingDetailsID

      AND oldb.meterID =
              fm.meterID

      AND oldb.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)

      AND oldb.meterServiceTypeID =
              fm.meterServiceTypeID_FK

      AND oldb.idaraID_FK =
              @IdaraID_INT

      AND oldb.BillTypeID_FK = 2
      AND oldb.BillActive = 1
);

SET @FixedBillsInserted = @@ROWCOUNT;

------------------------------------------------------------
-- فحص وجود عداد مفوتر واحد أو أكثر
------------------------------------------------------------
IF EXISTS
(
    SELECT 1

    FROM Housing.MeterForBuilding mfb

    INNER JOIN Housing.Meter m
        ON m.meterID = mfb.meterID_FK
       AND m.meterActive = 1

    INNER JOIN Housing.MeterType mt
        ON mt.meterTypeID = m.meterTypeID_FK
       AND mt.meterTypeActive = 1
       AND mt.IdaraId_FK = @IdaraID_INT

       -- النوع المفوتر
       AND mt.MeterCalculateTypeID_FK = 1

    WHERE mfb.buildingDetailsID_FK =
              TRY_CONVERT(BIGINT, @buildingDetailsID)

      AND mfb.IdaraID_FK = @IdaraID_INT
      AND mfb.meterForBuildingActive = 1
)
BEGIN
    --------------------------------------------------------
    -- يوجد عداد مفوتر واحد على الأقل
    -- الفواتير الثابتة صدرت أعلاه
    -- ثم ينتقل لقراءة العدادات المفوترة
    --------------------------------------------------------
    SET @buildingActionTypeID_FKForMeterRead = 59;
END
ELSE
BEGIN
    --------------------------------------------------------
    -- لا يوجد عداد مفوتر
    --
    -- إما أن جميع العدادات ثابتة وتم إصدار فواتيرها
    -- أو لا يوجد أي عداد مرتبط بالمبنى
    --------------------------------------------------------
    SET @buildingActionTypeID_FKForMeterRead = 60;
END;



            ------------------------------------------------------------


            --Declare @buildingActionTypeID_FKForMeterRead int

            --IF exists (select 1 
            --from Housing.MeterForBuilding m 
            --where m.buildingDetailsID_FK = @buildingDetailsID 
            --and m.IdaraID_FK = @idaraID_FK 
            --and m.meterForBuildingActive = 1)
            --begin

            --set @buildingActionTypeID_FKForMeterRead = 59

            --end
            --else
            --begin

            --set @buildingActionTypeID_FKForMeterRead = 60

            --end




            IF NULLIF(LTRIM(RTRIM(@BillsID)), N'') IS NULL
            BEGIN


              INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingDetailsID_FK
                , buildingDetailsNo
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , buildingActionDate
                , OccupentDate
                , ExitDate
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  @buildingActionTypeID_FKForMeterRead
                , @residentInfoID
                , @GeneralNo
                , @buildingDetailsID
                , @buildingDetailsNo
                , 1
                , @Notes
                , @LastActionID
                , @ExitDate
                , @OccupentDate
                , @ExitDate
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة غرامات لطلب الاخلاء', 1; -- برمجي
            END



             SET @NewID = SCOPE_IDENTITY();


            
             
             INSERT INTO [DATACORE].[Housing].[Bills]
            (
                  [residentInfoID_FK]
                 ,[buildingDetailsID]
                 ,[BillChargeTypeID_FK]
                 ,[ExitRequestActionID_FK]
                 ,[PeriodMonth]
                 ,[PeriodYear]
                 ,[PenaltyReason]
                 ,[PRICE]
                 ,[PRICETAX]
                 ,[TotalPrice]
  
                 ,[BillActive]
                 ,[idaraID_FK]
                 ,[entryData]
                 ,[hostName]
            )
            
             VALUES
            (
                  
                   
            @residentInfoID,
            @buildingDetailsID,
            5,
            @Penalty_CurrentExit54ID,
            DATEPART(MONTH,GETDATE()),
            DATEPART(YEAR,GETDATE()),
            @PenaltyReason,
            @PenaltyPriceDecimal,
            0.00,
            @PenaltyPriceDecimal,
            
            
            1,
            @idaraID_FK,
            @entryData,
            @hostName

            );


            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة غرامات لطلب الاخلاء', 1; -- برمجي
            END


            SET @NewID = SCOPE_IDENTITY();

               IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة غرامات لطلب الاخلاء - Identity', 1; -- برمجي
            END




            END
            ELSE
            Begin

            DECLARE @Penalty_EditBillID BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@BillsID)), N''));

            IF @Penalty_EditBillID IS NULL OR NOT EXISTS
            (
                SELECT 1
                FROM Housing.Bills AS b WITH (UPDLOCK, HOLDLOCK)
                WHERE b.BillsID = @Penalty_EditBillID
                  AND b.BillChargeTypeID_FK = 5
                  AND b.BillActive = 1
                  AND b.residentInfoID_FK = @ResidentInfoID_BIGINT
                  AND b.buildingDetailsID = @BuildingDetailsID_BIGINT
                  AND b.idaraID_FK = @IdaraID_INT
                  AND b.ExitRequestActionID_FK = @Penalty_CurrentExit54ID
            )
                THROW 50001, N'الغرامة غير نشطة أو لا تتبع دورة الإخلاء الحالية.', 1;

            -- Do not edit a financially posted, exempted or split penalty.
            IF EXISTS (SELECT 1 FROM Housing.BillsDeductListDetails d WITH (UPDLOCK, HOLDLOCK)
                       WHERE d.billsID_FK = @Penalty_EditBillID)
               OR EXISTS (SELECT 1 FROM Housing.ResidentRentExemptionPayment e WITH (UPDLOCK, HOLDLOCK)
                          WHERE e.billsID_FK = @Penalty_EditBillID)
               OR EXISTS (SELECT 1 FROM Housing.Bills child WITH (UPDLOCK, HOLDLOCK)
                          WHERE child.ParentBillsID_FK = @Penalty_EditBillID)
                THROW 50001, N'الغرامة مرتبطة بسداد أو إعفاء أو فاتورة فرعية؛ يلزم التدقيق المالي قبل تعديلها.', 1;

            UPDATE b
               SET b.BillActive = 0,
                   b.CanceledBy = @entryData,
                   b.CanceledDate = SYSDATETIME()
            FROM Housing.Bills AS b
            WHERE b.BillsID = @Penalty_EditBillID
              AND b.BillActive = 1
              AND b.residentInfoID_FK = @ResidentInfoID_BIGINT
              AND b.buildingDetailsID = @BuildingDetailsID_BIGINT
              AND b.idaraID_FK = @IdaraID_INT
              AND b.ExitRequestActionID_FK = @Penalty_CurrentExit54ID;

            IF @@ROWCOUNT <> 1
                THROW 50001, N'تعذر تعديل الغرامة بصورة آمنة.', 1;


              INSERT INTO [DATACORE].[Housing].[Bills]
            (
                  [residentInfoID_FK]
                 ,[buildingDetailsID]
                 ,[BillChargeTypeID_FK]
                 ,[ExitRequestActionID_FK]
                 ,[PeriodMonth]
                 ,[PeriodYear]
                 ,[PenaltyReason]
                 ,[PRICE]
                 ,[PRICETAX]
                 ,[TotalPrice]
  
                 ,[BillActive]
                 ,[idaraID_FK]
                 ,[entryData]
                 ,[hostName]
            )
            
             VALUES
            (
                  
                   
            @residentInfoID,
            @buildingDetailsID,
            5,
            @Penalty_CurrentExit54ID,
            DATEPART(MONTH,GETDATE()),
            DATEPART(YEAR,GETDATE()),
            @PenaltyReason,
            @PenaltyPriceDecimal,
            0.00,
            @PenaltyPriceDecimal,
            
            
            1,
            @idaraID_FK,
            @entryData,
            @hostName

            );

             IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل غرامات لطلب الاخلاء', 1; -- برمجي
            END

            END


         
            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionTypeID_FK), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingDetailsID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"buildingDetailsNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), '') + N'"'
                + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"buildingActionNote": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @LastActionID), '') + N'"'
                + N',"buildingActionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExitDate), '') + N'"'
                + N',"entryData": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Housing].[BuildingAction]'
                , N'EDITHOUSINGEXIT'
                , @ActionID
                , @entryData
                , @Note
            );
            

            IF @tc = 0 COMMIT TRANSACTION;
            

            SELECT 1 AS IsSuccessful, N'تم اضافة / تعديل غرامات لطلب الاخلاء بنجاح' AS Message_;
            RETURN;
        END


        ----------------------------------------------------------------
        -- Unknown Action
        ----------------------------------------------------------------
        ELSE
        BEGIN
            ;THROW 50001, N'العملية غير مسجلة', 1;
        END

    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;

        ;THROW;
    END CATCH
END