CREATE  PROCEDURE [Housing].[GenerateExitRentBillsForRequest]
(
      @Action             NVARCHAR(20)
    , @ResidentInfoID     BIGINT
    , @GeneralNo          BIGINT
    , @BuildingDetailsID  BIGINT
    , @OccupentDate       DATE
    , @ExitDate           DATE
    , @ExitRequestActionID BIGINT
    , @IdaraID            BIGINT
    , @EntryData          NVARCHAR(20)
    , @HostName           NVARCHAR(200)

)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TransactionCount INT = @@TRANCOUNT;
    DECLARE @ReplacedPeriodicBills TABLE
    (
          BillsID BIGINT PRIMARY KEY
        , BillsFromDate DATE NOT NULL
        , BillsToDate DATE NOT NULL
    );
    DECLARE @CanceledExitMonths TABLE
    (
          PeriodYear INT NOT NULL
        , PeriodMonth INT NOT NULL
        , PRIMARY KEY (PeriodYear, PeriodMonth)
    );

    BEGIN TRY
        IF @TransactionCount = 0
            BEGIN TRANSACTION;

        -- EXIT_STEP03_CYCLE_GUARDS_V1
        -- This procedure is deliberately NOT wired to HousingExitSP.
        -- The legacy and monthly billing procedures are unchanged.
        IF @ResidentInfoID IS NULL OR @GeneralNo IS NULL OR @BuildingDetailsID IS NULL
           OR @IdaraID IS NULL OR @OccupentDate IS NULL OR @ExitDate IS NULL
           OR @ExitRequestActionID IS NULL OR @ExitDate < @OccupentDate
            THROW 50001, N'بيانات دورة الإخلاء وتواريخها غير مكتملة أو غير صحيحة.', 1;

        DECLARE @LockResource NVARCHAR(255) = CONCAT(
            N'Housing.Occupancy:', @IdaraID, N':', @BuildingDetailsID);
        DECLARE @LockResult INT;
        EXEC @LockResult = sys.sp_getapplock
              @Resource = @LockResource
            , @LockMode = N'Exclusive'
            , @LockOwner = N'Transaction'
            , @LockTimeout = 15000;
        IF @LockResult < 0
            THROW 50001, N'تعذر حجز المنزل لإجراء فوترة الإخلاء.', 1;


        -- EXIT_STEP05_REGISTRATION_GUARD_V1
        -- Fail closed: only exit cycles explicitly enrolled in version 1
        -- may use the new rent engine. No legacy cycle is enrolled automatically.
        IF NOT EXISTS
        (
            SELECT 1
            FROM Housing.ExitFinancialProcessingCycle AS cycle WITH (UPDLOCK, HOLDLOCK)
            WHERE cycle.ExitRequestActionID_FK = @ExitRequestActionID
              AND cycle.ProcessingVersion = 1
        )
            THROW 50001, N'دورة الإخلاء غير مفعلة للمحرك المالي الجديد.', 1;

        DECLARE @OriginalRequestExitDate DATE;
        SELECT @OriginalRequestExitDate = CONVERT(DATE,a.ExitDate)
        FROM Housing.BuildingAction a WITH (UPDLOCK, HOLDLOCK)
        WHERE a.buildingActionID = @ExitRequestActionID
          AND a.buildingActionTypeID_FK = 54
          AND a.buildingActionActive = 1
          AND a.residentInfoID_FK = @ResidentInfoID
          AND a.generalNo_FK = @GeneralNo
          AND a.buildingDetailsID_FK = @BuildingDetailsID
          AND a.IdaraId_FK = @IdaraID
          AND CONVERT(DATE,a.OccupentDate) = @OccupentDate;

        IF @OriginalRequestExitDate IS NULL
            THROW 50001, N'تعذر التحقق من طلب الإخلاء الأصلي 54.', 1;
        IF @Action = N'GENERATE' AND @ExitDate <> @OriginalRequestExitDate
            THROW 50001, N'تاريخ توليد الإخلاء لا يطابق تاريخ الطلب المسجل.', 1;
        IF @Action = N'REGENERATE' AND EOMONTH(@ExitDate) <> EOMONTH(@OriginalRequestExitDate)
            THROW 50001, N'تغيير شهر الإخلاء يتطلب إلغاء الطلب وإنشاء طلب جديد.', 1;

        -- An independent active monthly bill may never be shortened implicitly.
        IF @Action IN (N'GENERATE',N'REGENERATE') AND EXISTS
        (
            SELECT 1 FROM Housing.Bills b WITH (UPDLOCK, HOLDLOCK)
            WHERE b.residentInfoID_FK=@ResidentInfoID
              AND b.buildingDetailsID=@BuildingDetailsID
              AND b.idaraID_FK=@IdaraID
              AND b.BillActive=1
              AND b.BillTypeID_FK=2
              AND b.BillChargeTypeID_FK IN (1,2,3,4)
              AND COALESCE(CONVERT(DATE,b.BillsToDate),
                  CASE WHEN b.PeriodYear BETWEEN 1900 AND 9999
                            AND b.PeriodMonth BETWEEN 1 AND 12
                       THEN EOMONTH(DATEFROMPARTS(b.PeriodYear,b.PeriodMonth,1)) END) > @ExitDate
              AND COALESCE(CONVERT(DATE,b.BillsToDate),
                  CASE WHEN b.PeriodYear BETWEEN 1900 AND 9999
                            AND b.PeriodMonth BETWEEN 1 AND 12
                       THEN EOMONTH(DATEFROMPARTS(b.PeriodYear,b.PeriodMonth,1)) END) >= @OccupentDate
        )
            THROW 50001, N'تاريخ الإخلاء يسبق نهاية فاتورة شهرية قائمة.', 1;

        -- A legacy / other exit bill cannot be mistaken for a bill of this cycle.
        IF @Action IN (N'GENERATE',N'REGENERATE') AND EXISTS
        (
            SELECT 1 FROM Housing.Bills b WITH (UPDLOCK,HOLDLOCK)
            WHERE b.residentInfoID_FK=@ResidentInfoID
              AND b.buildingDetailsID=@BuildingDetailsID
              AND b.idaraID_FK=@IdaraID
              AND b.BillActive=1
              AND b.BillTypeID_FK=3
              AND b.BillChargeTypeID_FK=1
              AND (b.ExitRequestActionID_FK IS NULL
                   OR b.ExitRequestActionID_FK <> @ExitRequestActionID)
              AND CONVERT(DATE,b.BillsFromDate) <= @ExitDate
              AND CONVERT(DATE,b.BillsToDate) >= @OccupentDate
        )
            THROW 50001, N'توجد فاتورة إيجار إخلاء تاريخية أو لدورة أخرى؛ يجب مراجعتها.', 1;

        -- Never invalidate a rent bill that already has an exemption payment link,
        -- even if that link was logically canceled; reconciliation is a later step.
        IF @Action IN (N'REGENERATE',N'CANCEL') AND EXISTS
        (
            SELECT 1
            FROM Housing.Bills b WITH (UPDLOCK,HOLDLOCK)
            INNER JOIN Housing.ResidentRentExemptionPayment linkRow
              ON linkRow.billsID_FK=b.BillsID
            WHERE b.residentInfoID_FK=@ResidentInfoID
              AND b.buildingDetailsID=@BuildingDetailsID
              AND b.idaraID_FK=@IdaraID
              AND b.BillActive=1
              AND b.BillChargeTypeID_FK=1
              AND b.BillTypeID_FK=3
              AND b.ExitRequestActionID_FK=@ExitRequestActionID
        )
            THROW 50001, N'فاتورة الإخلاء مرتبطة بسجل سداد إعفاء؛ يلزم تسوية الإعفاء أولًا.', 1;
        -- EXIT_STEP03_CYCLE_GUARDS_V1_END

            IF @ExitRequestActionID IS NULL
   OR NOT EXISTS
   (
       SELECT 1
       FROM Housing.BuildingAction a
       WHERE a.buildingActionID = @ExitRequestActionID
         AND a.buildingActionTypeID_FK = 54
         AND a.buildingActionActive = 1
         AND a.residentInfoID_FK = @ResidentInfoID
         AND a.buildingDetailsID_FK = @BuildingDetailsID
         AND a.IdaraId_FK = @IdaraID
         AND CAST(a.OccupentDate AS DATE) = @OccupentDate
   )
BEGIN
    ;THROW 50001,
        N'تعذر التحقق من طلب الإخلاء الأصلي المرتبط بالفواتير',
        1;
END;

        IF ISNULL(@Action, N'') NOT IN (N'GENERATE', N'REGENERATE', N'CANCEL')
        BEGIN
            ;THROW 50001, N'عملية فواتير إيجار الإخلاء غير صحيحة', 1;
        END;

        IF @ResidentInfoID IS NULL
           OR @BuildingDetailsID IS NULL
           OR @IdaraID IS NULL
           OR @OccupentDate IS NULL
        BEGIN
            ;THROW 50001, N'بيانات المستفيد والمنزل وتاريخ السكن والإدارة مطلوبة', 1;
        END;

        IF @Action IN (N'REGENERATE', N'CANCEL')
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM Housing.Bills b
                INNER JOIN Housing.BillsDeductListDetails d
                    ON d.billsID_FK = b.BillsID
                WHERE b.residentInfoID_FK = @ResidentInfoID
                  AND b.buildingDetailsID = @BuildingDetailsID
                  AND b.BillChargeTypeID_FK = 1
                  AND b.BillTypeID_FK = 3
                  AND b.BillActive = 1
                  AND b.idaraID_FK = @IdaraID
                  AND CAST(b.BillsToDate AS date) >= @OccupentDate
                  AND b.ExitRequestActionID_FK = @ExitRequestActionID
                  AND (d.billActive = 1 OR d.billPaid = 1)
            )
            BEGIN
                ;THROW 50001, N'لا يمكن تعديل أو إلغاء الإخلاء لوجود فاتورة إيجار إخلاء دخلت في التحصيل', 1;
            END;

            IF @Action = N'CANCEL'
            BEGIN
                INSERT INTO @CanceledExitMonths (PeriodYear, PeriodMonth)
                SELECT DISTINCT b.PeriodYear, b.PeriodMonth
                FROM Housing.Bills b
                WHERE b.residentInfoID_FK = @ResidentInfoID
                  AND b.buildingDetailsID = @BuildingDetailsID
                  AND b.idaraID_FK = @IdaraID
                  AND b.BillChargeTypeID_FK = 1
                  AND b.BillTypeID_FK = 3
                  AND b.BillActive = 1
                  AND b.ParentBillsID_FK IS NULL
                  AND b.ExitRequestActionID_FK = @ExitRequestActionID
                  AND CAST(b.BillsToDate AS date) >= @OccupentDate
                  AND b.PeriodMonth BETWEEN 1 AND 12
                  AND b.PeriodYear BETWEEN 1900 AND 9999
                  AND EOMONTH(DATEFROMPARTS(b.PeriodYear, b.PeriodMonth, 1))
                      <= EOMONTH(DATEADD(MONTH, -1, GETDATE()));
            END;

            DECLARE @OriginalPeriodicBills TABLE (BillsID BIGINT PRIMARY KEY);

            INSERT INTO @OriginalPeriodicBills (BillsID)
            SELECT DISTINCT b.ParentBillsID_FK
            FROM Housing.Bills b
            WHERE b.residentInfoID_FK = @ResidentInfoID
              AND b.buildingDetailsID = @BuildingDetailsID
              AND b.BillChargeTypeID_FK = 1
              AND b.BillTypeID_FK = 3
              AND b.BillActive = 1
              AND b.idaraID_FK = @IdaraID
              AND CAST(b.BillsToDate AS date) >= @OccupentDate
              AND b.ParentBillsID_FK IS NOT NULL
              AND b.ExitRequestActionID_FK = @ExitRequestActionID;

            UPDATE Housing.Bills
               SET BillActive = 0,
                   CanceledBy = CONCAT(N'EXIT_', @Action),
                   entryData = @EntryData,
                   hostName = @HostName
            WHERE residentInfoID_FK = @ResidentInfoID
              AND buildingDetailsID = @BuildingDetailsID
              AND BillChargeTypeID_FK = 1
              AND BillTypeID_FK = 3
              AND BillActive = 1
              AND idaraID_FK = @IdaraID
              AND CAST(BillsToDate AS date) >= @OccupentDate
              AND ExitRequestActionID_FK = @ExitRequestActionID;

            UPDATE originalBill
               SET originalBill.BillActive = 1,
                   originalBill.CanceledBy = NULL,
                   originalBill.entryData = @EntryData,
                   originalBill.hostName = @HostName
            FROM Housing.Bills originalBill
            INNER JOIN @OriginalPeriodicBills parent
                ON parent.BillsID = originalBill.BillsID
            WHERE originalBill.BillChargeTypeID_FK = 1
              AND originalBill.BillTypeID_FK = 2
              AND originalBill.BillActive = 0
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM Housing.BillsDeductListDetails d
                  WHERE d.billsID_FK = originalBill.BillsID
                    AND (d.billActive = 1 OR d.billPaid = 1)
              );

            IF @Action = N'CANCEL'
            BEGIN
                DECLARE @RestoreYear INT;
                DECLARE @RestoreMonth INT;

                WHILE EXISTS (SELECT 1 FROM @CanceledExitMonths)
                BEGIN
                    SELECT TOP (1)
                          @RestoreYear = PeriodYear
                        , @RestoreMonth = PeriodMonth
                    FROM @CanceledExitMonths
                    ORDER BY PeriodYear, PeriodMonth;

                    EXEC Housing.GenerateMonthlyRentBillForResident
                          @ResidentInfoID = @ResidentInfoID
                        , @GeneralNo = @GeneralNo
                        , @BuildingDetailsID = @BuildingDetailsID
                        , @OccupentDate = @OccupentDate
                        , @Month = @RestoreMonth
                        , @Year = @RestoreYear
                        , @IdaraID = @IdaraID
                        , @EntryData = @EntryData
                        , @HostName = @HostName;

                    DELETE FROM @CanceledExitMonths
                    WHERE PeriodYear = @RestoreYear
                      AND PeriodMonth = @RestoreMonth;
                END;
            END;
        END;

        IF @Action IN (N'GENERATE', N'REGENERATE')
        BEGIN
            DECLARE @BillingFromDate DATE;
            DECLARE @LastBilledToDate DATE;

            IF @OccupentDate IS NULL OR @ExitDate IS NULL
                THROW 50001, N'تاريخ السكن وتاريخ الإخلاء مطلوبان لرصد إيجار الإخلاء', 1;

            IF @ExitDate < @OccupentDate
                THROW 50001, N'تاريخ الإخلاء يجب ألا يسبق تاريخ السكن', 1;

            IF EXISTS
            (
                SELECT 1
                FROM Housing.Bills b
                INNER JOIN Housing.BillsDeductListDetails d
                    ON d.billsID_FK = b.BillsID
                WHERE b.residentInfoID_FK = @ResidentInfoID
                  AND b.buildingDetailsID = @BuildingDetailsID
                  AND b.idaraID_FK = @IdaraID
                  AND b.BillChargeTypeID_FK = 1
                  AND b.BillTypeID_FK = 2
                  AND b.BillActive = 1
                  AND CAST(b.BillsFromDate AS date) <= @ExitDate
                  AND CAST(b.BillsToDate AS date) > @ExitDate
                  AND (d.billActive = 1 OR d.billPaid = 1)
            )
            BEGIN
                ;THROW 50001, N'لا يمكن احتساب إيجار الإخلاء لوجود فاتورة دورية متجاوزة لتاريخ الإخلاء ودخلت في التحصيل', 1;
            END;

            IF EXISTS
            (
                SELECT 1
                FROM Housing.Bills b WITH (UPDLOCK,HOLDLOCK)
                INNER JOIN Housing.ResidentRentExemptionPayment ep
                  ON ep.billsID_FK=b.BillsID
                WHERE b.residentInfoID_FK=@ResidentInfoID
                  AND b.buildingDetailsID=@BuildingDetailsID
                  AND b.idaraID_FK=@IdaraID
                  AND b.BillChargeTypeID_FK=1
                  AND b.BillTypeID_FK=2
                  AND b.BillActive=1
                  AND CONVERT(DATE,b.BillsFromDate)<=@ExitDate
                  AND CONVERT(DATE,b.BillsToDate)>@ExitDate
            )
                THROW 50001, N'لا يمكن استبدال فاتورة دورية ترتبط بسداد إعفاء دون تسوية.', 1;

            INSERT INTO @ReplacedPeriodicBills (BillsID, BillsFromDate, BillsToDate)
            SELECT
                  b.BillsID
                , CAST(b.BillsFromDate AS date)
                , CAST(b.BillsToDate AS date)
            FROM Housing.Bills b WITH (UPDLOCK, HOLDLOCK)
            WHERE b.residentInfoID_FK = @ResidentInfoID
              AND b.buildingDetailsID = @BuildingDetailsID
              AND b.idaraID_FK = @IdaraID
              AND b.BillChargeTypeID_FK = 1
              AND b.BillTypeID_FK = 2
              AND b.BillActive = 1
              AND CAST(b.BillsFromDate AS date) <= @ExitDate
              AND CAST(b.BillsToDate AS date) > @ExitDate;

            UPDATE periodicBill
               SET periodicBill.BillActive = 0,
                   periodicBill.CanceledBy = N'REPLACED_BY_EXIT_BILL',
                   periodicBill.entryData = @EntryData,
                   periodicBill.hostName = @HostName
            FROM Housing.Bills periodicBill
            INNER JOIN @ReplacedPeriodicBills replaced
                ON replaced.BillsID = periodicBill.BillsID;



                /* استكمال الإيجارات الشهرية السابقة لشهر الإخلاء */

DECLARE @ExitMonthStartForMonthly DATE;
DECLARE @MonthToGenerate DATE;
DECLARE @MonthNumberToGenerate INT;
DECLARE @YearNumberToGenerate INT;

SET @ExitMonthStartForMonthly =
    DATEFROMPARTS(YEAR(@ExitDate), MONTH(@ExitDate), 1);

SET @MonthToGenerate =
    DATEFROMPARTS(YEAR(@OccupentDate), MONTH(@OccupentDate), 1);

WHILE @MonthToGenerate < @ExitMonthStartForMonthly
BEGIN

    SET @MonthNumberToGenerate = MONTH(@MonthToGenerate);
    SET @YearNumberToGenerate = YEAR(@MonthToGenerate);

    EXEC Housing.GenerateMonthlyRentBillForResident
          @ResidentInfoID    = @ResidentInfoID
        , @GeneralNo         = @GeneralNo
        , @BuildingDetailsID = @BuildingDetailsID
        , @OccupentDate      = @OccupentDate
        , @Month             = @MonthNumberToGenerate
        , @Year              = @YearNumberToGenerate
        , @IdaraID           = @IdaraID
        , @EntryData         = @EntryData
        , @HostName          = @HostName;

    SET @MonthToGenerate =
        DATEADD(MONTH, 1, @MonthToGenerate);

END;


            SELECT @LastBilledToDate = MAX(CAST(b.BillsToDate AS date))
            FROM Housing.Bills b
            WHERE b.residentInfoID_FK = @ResidentInfoID
              AND b.buildingDetailsID = @BuildingDetailsID
              AND b.idaraID_FK = @IdaraID
              AND b.BillChargeTypeID_FK = 1
              AND b.BillActive = 1
              AND b.BillsToDate IS NOT NULL
              AND CAST(b.BillsToDate AS date) >= DATEADD(DAY, -1, @OccupentDate);

            /* فاتورة الإخلاء تخص شهر الإخلاء فقط */
DECLARE @ExitRentMonthStart DATE =
    DATEFROMPARTS(YEAR(@ExitDate), MONTH(@ExitDate), 1);

SET @BillingFromDate =
    CASE
        WHEN @OccupentDate > @ExitRentMonthStart
            THEN @OccupentDate
        ELSE @ExitRentMonthStart
    END;

/* عدم إعادة إصدار فترة سبق رصدها */
IF @LastBilledToDate IS NOT NULL
   AND @LastBilledToDate >= @BillingFromDate
BEGIN
    SET @BillingFromDate =
        DATEADD(DAY, 1, @LastBilledToDate);
END;

/* قد تكون الفاتورة موجودة، لكن سداد إعفائها لم يُنشأ */
IF @BillingFromDate <= @ExitDate
BEGIN

/* شهر الإخلاء فقط */
;WITH Months AS
(
    SELECT @ExitRentMonthStart AS MonthStart
),
            CalculatedRent AS
            (
                SELECT
                      w.[Year]
                    , w.[Month]
                    , w.CalcFromDate
                    , w.CalcToDate
                    , RentAmount = CAST(w.RentForMonth AS DECIMAL(18,2))
                FROM Months m
                CROSS APPLY Housing.fn_CalcBuildingRent_ForOneMonth
                (
                      @BuildingDetailsID
                    , @BillingFromDate
                    , YEAR(m.MonthStart)
                    , MONTH(m.MonthStart)
                    , @ExitDate
                ) w
                OUTER APPLY
                (
                    SELECT
                        ExemptionAmount =
                            CAST
                            (
                                (w.RentForMonth / NULLIF(w.Days30InMonth, 0))
                                * SUM(x.ExemptDays30)
                                AS DECIMAL(18,2)
                            )
                    FROM
                    (
                        SELECT
                            ExemptDays30 =
                            (
                                (YEAR(d.ExemptEnd) - YEAR(d.ExemptStart)) * 360
                              + (MONTH(d.ExemptEnd) - MONTH(d.ExemptStart)) * 30
                              + (
                                    CASE
                                        WHEN d.ExemptEnd = EOMONTH(d.ExemptEnd) AND DAY(d.ExemptEnd) < 30 THEN 30
                                        WHEN DAY(d.ExemptEnd) > 30 THEN 30
                                        ELSE DAY(d.ExemptEnd)
                                    END
                                    -
                                    CASE
                                        WHEN d.ExemptStart = EOMONTH(d.ExemptStart) AND DAY(d.ExemptStart) < 30 THEN 30
                                        WHEN DAY(d.ExemptStart) > 30 THEN 30
                                        ELSE DAY(d.ExemptStart)
                                    END
                                )
                              + 1
                            )
                        FROM
                        (
                            SELECT
                                  ExemptStart =
                                      CASE
                                          WHEN CAST(ex.residentRentExemptionStartDate AS date) < w.CalcFromDate
                                              THEN w.CalcFromDate
                                          ELSE CAST(ex.residentRentExemptionStartDate AS date)
                                      END
                                , ExemptEnd =
                                      CASE
                                          WHEN ex.residentRentExemptionEndDate IS NULL
                                               OR CAST(ex.residentRentExemptionEndDate AS date) > w.CalcToDate
                                              THEN w.CalcToDate
                                          ELSE CAST(ex.residentRentExemptionEndDate AS date)
                                      END
                            FROM Housing.ResidentRentExemption ex
                            WHERE ex.residentInfoID_FK = @ResidentInfoID
                              AND ex.buildingDetailsID_FK = @BuildingDetailsID
                              AND ISNULL(ex.residentRentExemptionActive, 0) = 1
                              AND CAST(ex.residentRentExemptionStartDate AS date) <= w.CalcToDate
                              AND
                                  (
                                      ex.residentRentExemptionEndDate IS NULL
                                      OR CAST(ex.residentRentExemptionEndDate AS date) >= w.CalcFromDate
                                  )
                        ) d
                        WHERE d.ExemptStart <= d.ExemptEnd
                    ) x
                ) exm
            )
            INSERT INTO Housing.Bills
            (
                  BillsUID
                , BillChargeTypeID_FK
                , BillTypeID_FK
                , ParentBillsID_FK
                , ExitRequestActionID_FK
                , PeriodMonth
                , PeriodYear
                , buildingDetailsID
                , residentInfoID_FK
                , generalNo_FK
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
                , 3
                , parentBill.BillsID
                , @ExitRequestActionID
                , r.[Month]
                , r.[Year]
                , @BuildingDetailsID
                , @ResidentInfoID
                , @GeneralNo
                , r.RentAmount
                , 0
                , r.RentAmount
                , 1
                , r.CalcFromDate
                , r.CalcToDate
                , 1
                , @IdaraID
                , GETDATE()
                , @EntryData
                , @HostName
            FROM CalculatedRent r
            OUTER APPLY
            (
                SELECT TOP (1) replaced.BillsID
                FROM @ReplacedPeriodicBills replaced
                WHERE replaced.BillsFromDate <= r.CalcToDate
                  AND replaced.BillsToDate >= r.CalcFromDate
                ORDER BY replaced.BillsID DESC
            ) parentBill
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM Housing.Bills existingBill WITH (UPDLOCK, HOLDLOCK)
                WHERE existingBill.residentInfoID_FK = @ResidentInfoID
                  AND existingBill.buildingDetailsID = @BuildingDetailsID
                  AND existingBill.BillChargeTypeID_FK = 1
                  AND existingBill.BillActive = 1
                  AND CAST(existingBill.BillsFromDate AS date) <= r.CalcToDate
                  AND CAST(existingBill.BillsToDate AS date) >= r.CalcFromDate
            )
            OPTION (MAXRECURSION 1200);

            END; -- نهاية إنشاء فاتورة الإخلاء عند وجود فترة غير مفوترة

            /* مزامنة الإعفاءات لفواتير هذه الدورة فقط */
DECLARE @TargetExitBillID BIGINT;
DECLARE @TargetExitExemptionID BIGINT;

DECLARE ExitExemptionCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT
    b.BillsID,
    e.residentRentExemptionID
FROM Housing.Bills b
INNER JOIN Housing.ResidentRentExemption e
    ON e.residentInfoID_FK = b.residentInfoID_FK
   AND e.buildingDetailsID_FK = b.buildingDetailsID
   AND e.idaraID_FK = b.idaraID_FK
WHERE b.ExitRequestActionID_FK = @ExitRequestActionID
  AND b.residentInfoID_FK = @ResidentInfoID
  AND b.buildingDetailsID = @BuildingDetailsID
  AND b.idaraID_FK = @IdaraID
  AND b.BillChargeTypeID_FK = 1
  AND b.BillTypeID_FK = 3
  AND b.BillActive = 1
  AND e.residentRentExemptionActive = 1
  AND CAST(e.residentRentExemptionStartDate AS DATE)
      <= CAST(b.BillsToDate AS DATE)
  AND
  (
      e.residentRentExemptionEndDate IS NULL
      OR CAST(e.residentRentExemptionEndDate AS DATE)
          >= CAST(b.BillsFromDate AS DATE)
  )
ORDER BY b.BillsID, e.residentRentExemptionID;

OPEN ExitExemptionCursor;

FETCH NEXT FROM ExitExemptionCursor
INTO @TargetExitBillID, @TargetExitExemptionID;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC Housing.SyncRentExemptionPayments
          @Action = N'GENERATE'
        , @ResidentRentExemptionID = @TargetExitExemptionID
        , @ThroughDate = @ExitDate
        , @SourceType = N'EXIT_RENT'
        , @EntryData = @EntryData
        , @HostName = @HostName
        , @TargetBillsID = @TargetExitBillID;

    FETCH NEXT FROM ExitExemptionCursor
    INTO @TargetExitBillID, @TargetExitExemptionID;
END;

CLOSE ExitExemptionCursor;
DEALLOCATE ExitExemptionCursor;

        END;

        IF @TransactionCount = 0
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @TransactionCount = 0 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;