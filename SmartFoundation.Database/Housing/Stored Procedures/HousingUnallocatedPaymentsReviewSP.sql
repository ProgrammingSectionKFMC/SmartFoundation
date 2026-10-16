
/*
    REVIEW V5 — SOFT CANCELLATION / CONFIRMED-ONLY REFERENCE UNIQUENESS.
    Retain the V4 INSERT accounting and allocation policy unchanged.
    CANCEL must be routed through Masters_CRUD with separate permission.
    Execute ONLY through dbo.Masters_CRUD, which owns COMMIT.
    Same transaction pattern as HousingExtendSP and MetersSP.
*/
CREATE   PROCEDURE [Housing].[HousingUnallocatedPaymentsReviewSP]
(
      @Action                 NVARCHAR(200)  = NULL
    , @residentInfoID         NVARCHAR(100)  = NULL
    , @BillChargeTypeID       NVARCHAR(100)  = NULL
    , @RefundAmount           NVARCHAR(100)  = NULL
    , @RefundDate             NVARCHAR(100)  = NULL
    , @RefundReference        NVARCHAR(4000) = NULL
    , @RefundDetails          NVARCHAR(MAX)  = NULL
    , @BillPaymentTypeID      NVARCHAR(100)  = NULL
    , @RequestKey             NVARCHAR(100)  = NULL
    , @idaraID_FK             NVARCHAR(10)   = NULL
    , @entryData              NVARCHAR(20)   = NULL
    , @hostName               NVARCHAR(200)  = NULL
    , @RefundID               NVARCHAR(100)  = NULL
    , @CancellationReason     NVARCHAR(MAX)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;
    DECLARE @NewID BIGINT = NULL, @Note NVARCHAR(MAX) = NULL;
    DECLARE @ResidentID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@residentInfoID)), N''));
    DECLARE @ChargeType_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@BillChargeTypeID)), N''));
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));
    DECLARE @Amount_DECIMAL DECIMAL(18,2) = TRY_CONVERT(DECIMAL(18,2), NULLIF(LTRIM(RTRIM(@RefundAmount)), N''));
    DECLARE @Amount_PRECISE DECIMAL(38,18) = TRY_CONVERT(DECIMAL(38,18), NULLIF(LTRIM(RTRIM(@RefundAmount)), N''));
    DECLARE @RefundDate_DATE DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@RefundDate)), N''));
    DECLARE @TypeID_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@BillPaymentTypeID)), N''));
    DECLARE @RequestKey_UID UNIQUEIDENTIFIER = TRY_CONVERT(UNIQUEIDENTIFIER, NULLIF(LTRIM(RTRIM(@RequestKey)), N''));
    DECLARE @FirstOccupancyDate DATE = NULL;
    DECLARE @EligiblePositive DECIMAL(38,2) = 0;
    DECLARE @OldRefunds DECIMAL(38,2) = 0;
    DECLARE @NewRefunds DECIMAL(38,2) = 0;
    DECLARE @ExistingDetailTotal DECIMAL(38,2) = 0;
    DECLARE @Available DECIMAL(38,2) = 0;
    DECLARE @DetailTotal DECIMAL(38,2) = 0;
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(255);
    DECLARE @CancelRefundID BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@RefundID)), N''));
    DECLARE @CancelReason NVARCHAR(MAX) = NULLIF(LTRIM(RTRIM(@CancellationReason)), N'');
    DECLARE @CancelResidentID BIGINT;
    DECLARE @CancelChargeTypeID INT;
    DECLARE @CancelStatus TINYINT;
    DECLARE @CancelAmount DECIMAL(18,2);
    DECLARE @CancelAllocated DECIMAL(38,2);

    BEGIN TRY
        -- Transaction-safe (same pattern as HousingExtendSP/MetersSP).
        IF @tc = 0
            BEGIN TRAN;

        ----------------------------------------------------------------
        -- Business validations => THROW 50001
        ----------------------------------------------------------------
        IF NULLIF(LTRIM(RTRIM(@Action)), N'') IS NULL
        BEGIN
            THROW 50001, N'العملية مطلوبة', 1;
        END

        ----------------------------------------------------------------
        -- INSERTUNALLOCATEDPAYMENTREFUND
        ----------------------------------------------------------------
        IF @Action = N'INSERTUNALLOCATEDPAYMENTREFUND'
        BEGIN
            IF @ResidentID_BIGINT IS NULL OR @ResidentID_BIGINT <= 0
            BEGIN
                THROW 50001, N'رقم المستفيد غير صحيح', 1;
            END

            IF @ChargeType_INT IS NULL OR @ChargeType_INT <= 0
            BEGIN
                THROW 50001, N'نوع الخدمة غير صحيح', 1;
            END

            IF @IdaraID_INT IS NULL OR @IdaraID_INT <= 0
            BEGIN
                THROW 50001, N'الإدارة غير صحيحة', 1;
            END

            IF @Amount_DECIMAL IS NULL OR @Amount_DECIMAL <= 0
            BEGIN
                THROW 50001, N'يجب إدخال مبلغ إعادة أكبر من صفر', 1;
            END

            IF @Amount_PRECISE IS NULL OR @Amount_PRECISE <> @Amount_DECIMAL
            BEGIN
                THROW 50001, N'مبلغ الإعادة يجب أن يحتوي على هللتين كحد أقصى', 1;
            END

            IF @RefundDate_DATE IS NULL OR @RefundDate_DATE > CONVERT(DATE, GETDATE())
            BEGIN
                THROW 50001, N'تاريخ إعادة المبلغ غير صحيح أو في المستقبل', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@RefundReference)), N'') IS NULL
               OR LEN(LTRIM(RTRIM(@RefundReference))) > 200
            BEGIN
                THROW 50001, N'رقم مستند الإعادة مطلوب وبحد أقصى 200 حرف', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@RefundDetails)), N'') IS NULL
            BEGIN
                THROW 50001, N'تفاصيل إعادة المبلغ مطلوبة', 1;
            END

            IF @RequestKey_UID IS NULL
            BEGIN
                THROW 50001, N'معرّف عملية الحفظ غير صحيح', 1;
            END

            IF @TypeID_INT <> 4 OR @TypeID_INT IS NULL
            BEGIN
                THROW 50001, N'نوع العملية المسموح به هو إعادة مبالغ زائدة فقط', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM Housing.billPaymentType t
                WHERE t.billPaymentTypeID = 4
                  AND t.billPaymentDestainationID_FK = 2
                  AND t.billPaymentTypeActive = 1
            )
            BEGIN
                THROW 50001, N'نوع إعادة المبالغ غير مفعل', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1 FROM Housing.ResidentInfo r
                INNER JOIN Housing.V_GetFullResidentDetails f
                    ON f.residentInfoID = r.residentInfoID
                WHERE r.residentInfoID = @ResidentID_BIGINT
                  AND f.IdaraID = @IdaraID_INT
            )
            BEGIN
                THROW 50001, N'المستفيد غير موجود ضمن الإدارة المصرح بها', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1 FROM Housing.BillChargeType c
                WHERE c.BillChargeTypeID = @ChargeType_INT
                  AND c.BillChargeTypeActive = 1
            )
            BEGIN
                THROW 50001, N'نوع الخدمة غير فعال', 1;
            END

            -- Serialize this beneficiary+charge+department's refund records.
            SET @LockResource = N'HUPR|' + CONVERT(NVARCHAR(20), @IdaraID_INT)
                + N'|' + CONVERT(NVARCHAR(30), @ResidentID_BIGINT)
                + N'|' + CONVERT(NVARCHAR(20), @ChargeType_INT);
            EXEC @LockResult = sys.sp_getapplock
                  @Resource = @LockResource
                , @LockMode = N'Exclusive'
                , @LockOwner = N'Transaction'
                , @LockTimeout = 10000;

            IF @LockResult < 0
            BEGIN
                THROW 50001, N'تعذر حجز الرصيد حاليًا، حاول مجددًا', 1;
            END

            IF EXISTS
            (
                SELECT 1 FROM Housing.UnallocatedPaymentRefund r WITH (UPDLOCK, HOLDLOCK)
                WHERE r.RequestKey = @RequestKey_UID
            )
            BEGIN
                THROW 50001, N'تم تسجيل طلب الاسترداد مسبقًا', 1;
            END

            IF EXISTS
            (
                SELECT 1 FROM Housing.UnallocatedPaymentRefund r WITH (UPDLOCK, HOLDLOCK)
                WHERE r.ResidentInfoID_FK = @ResidentID_BIGINT
                  AND r.IdaraId_FK = @IdaraID_INT
                  AND r.BillChargeTypeID_FK = @ChargeType_INT
                  AND r.RefundReferenceNormalized = UPPER(LTRIM(RTRIM(@RefundReference)))
                  AND r.RefundStatus = 1  -- cancelled references may be reused
            )
            BEGIN
                THROW 50001, N'مرجع إعادة المبلغ مسجل مسبقًا لهذا المستفيد والخدمة', 1;
            END

            -- Also reject an exact reference already used for a negative legacy refund.
            -- Missing/changed historical references still require human reconciliation.
            IF EXISTS
            (
                SELECT 1
                FROM Housing.BuildingPayment p WITH (UPDLOCK, HOLDLOCK)
                INNER JOIN Housing.DeductList d ON d.deductListID = p.deductListID_FK
                WHERE p.residentInfoID_FK = @ResidentID_BIGINT
                  AND p.IdaraId_FK = @IdaraID_INT
                  AND p.BillChargeTypeID_FK = @ChargeType_INT
                  AND p.buildingPaymentLinkStatusID_FK = 2
                  AND p.buildingPayementActive = 1
                  AND d.deductActive = 1
                  AND p.amount < 0
                  AND UPPER(LTRIM(RTRIM(d.paymentNo))) = UPPER(LTRIM(RTRIM(@RefundReference)))
            )
            BEGIN
                THROW 50001, N'مرجع الإعادة موجود في الاستردادات السالبة القديمة', 1;
            END

            -- A documented first occupancy is mandatory for eligible status-2 credit.
            SELECT @FirstOccupancyDate = MIN(CONVERT(DATE, a.buildingActionDate))
            FROM Housing.BuildingAction a
            WHERE a.residentInfoID_FK = @ResidentID_BIGINT
              AND a.buildingActionTypeID_FK = 2
              AND a.buildingActionActive = 1
              AND a.buildingActionDate IS NOT NULL;

            IF @FirstOccupancyDate IS NULL
            BEGIN
                THROW 50001, N'لا يوجد إشغال أول معروف للمستفيد، ولا يمكن اعتماد الرصيد', 1;
            END

            IF @RefundDate_DATE < @FirstOccupancyDate
            BEGIN
                THROW 50001, N'تاريخ الاسترداد يسبق أول إشغال معروف للمستفيد', 1;
            END

            -- Monthly Hijri mapping; accept only structurally complete months.
            -- gregorianDate is the approved mapping (NOT SQLServerGregorianDate).
            -- An incomplete Hijri period must NOT fall back to staff-entered paymentDate.
            SELECT
                  g.yearH
                , g.monthH
                , MIN(CONVERT(DATE, g.gregorianDate)) AS PeriodStartDate
                , MAX(CONVERT(DATE, g.gregorianDate)) AS PeriodEndDate
            INTO #HijriMonths
            FROM dbo._GregorianHijriDate g
            WHERE g.yearH BETWEEN 1400 AND 1499
            GROUP BY g.yearH, g.monthH
            HAVING COUNT(*) BETWEEN 29 AND 30
               AND COUNT(DISTINCT g.dayH) = COUNT(*)
               AND MIN(g.dayH) = 1
               AND MAX(g.dayH) = COUNT(*)
               AND COUNT(DISTINCT CONVERT(DATE, g.gregorianDate)) = COUNT(*)
               AND DATEDIFF
                   (
                       DAY,
                       MIN(CONVERT(DATE, g.gregorianDate)),
                       MAX(CONVERT(DATE, g.gregorianDate))
                   ) + 1 = COUNT(*);

            CREATE UNIQUE CLUSTERED INDEX IX_HUPR_HijriMonths
                ON #HijriMonths (yearH, monthH);

            -- A monthly payment is eligible if its period END overlaps
            -- or follows the beneficiary's first documented occupancy.
            -- No assumption that paymentDate describes its original Hijri period.
            SELECT
                  p.paymentID AS PaymentID
                , CONVERT(DECIMAL(18,2), p.amount) AS PaymentAmount
                , dates.PaymentReferenceDate AS PaymentReferenceDate
            INTO #EligiblePayments
            FROM Housing.BuildingPayment p WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN Housing.DeductList d ON d.deductListID = p.deductListID_FK
            LEFT JOIN #HijriMonths h
                ON h.yearH = d.issueYear
               AND h.monthH = d.issueMonth
            CROSS APPLY
            (
                SELECT
                    CASE
                        WHEN d.issueYear BETWEEN 1400 AND 1499
                            THEN h.PeriodStartDate
                        WHEN d.issueYear BETWEEN 1900 AND 9999
                         AND d.issueMonth BETWEEN 1 AND 12
                            THEN TRY_CONVERT(DATE, CONCAT(d.issueYear, N'-',
                                 RIGHT(N'0' + CONVERT(NVARCHAR(2), d.issueMonth), 2), N'-01'))
                        ELSE d.paymentDate
                    END AS PaymentReferenceDate,
                    CASE
                        WHEN d.issueYear BETWEEN 1400 AND 1499
                            THEN h.PeriodEndDate
                        WHEN d.issueYear BETWEEN 1900 AND 9999
                         AND d.issueMonth BETWEEN 1 AND 12
                            THEN EOMONTH(TRY_CONVERT(DATE, CONCAT(d.issueYear, N'-',
                                 RIGHT(N'0' + CONVERT(NVARCHAR(2), d.issueMonth), 2), N'-01')))
                        ELSE d.paymentDate
                    END AS PaymentPeriodEndDate
            ) dates
            WHERE p.residentInfoID_FK = @ResidentID_BIGINT
              AND p.IdaraId_FK = @IdaraID_INT
              AND p.BillChargeTypeID_FK = @ChargeType_INT
              AND p.buildingPaymentLinkStatusID_FK = 2
              AND p.buildingPayementActive = 1
              AND d.deductActive = 1
              AND p.amount > 0
              AND NULLIF(LTRIM(RTRIM(p.buildingDetailsID_FK)), N'') IS NULL
              AND dates.PaymentPeriodEndDate >= @FirstOccupancyDate;

            SELECT @EligiblePositive = ISNULL(SUM(CONVERT(DECIMAL(38,2), PaymentAmount)), 0)
            FROM #EligiblePayments;

            SELECT @OldRefunds = ISNULL(SUM(-CONVERT(DECIMAL(38,2), p.amount)), 0)
            FROM Housing.BuildingPayment p WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN Housing.DeductList d ON d.deductListID = p.deductListID_FK
            WHERE p.residentInfoID_FK = @ResidentID_BIGINT
              AND p.IdaraId_FK = @IdaraID_INT
              AND p.BillChargeTypeID_FK = @ChargeType_INT
              AND p.buildingPaymentLinkStatusID_FK = 2
              AND p.buildingPayementActive = 1
              AND d.deductActive = 1
              AND p.amount < 0;

            SELECT @NewRefunds = ISNULL(SUM(CONVERT(DECIMAL(38,2), r.RefundAmount)), 0)
            FROM Housing.UnallocatedPaymentRefund r WITH (UPDLOCK, HOLDLOCK)
            WHERE r.ResidentInfoID_FK = @ResidentID_BIGINT
              AND r.IdaraId_FK = @IdaraID_INT
              AND r.BillChargeTypeID_FK = @ChargeType_INT
              AND r.RefundStatus = 1;

            SELECT @ExistingDetailTotal = ISNULL(SUM(CONVERT(DECIMAL(38,2), rd.AllocatedAmount)), 0)
            FROM Housing.UnallocatedPaymentRefundDetail rd WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN Housing.UnallocatedPaymentRefund r ON r.RefundID = rd.RefundID_FK
            WHERE r.ResidentInfoID_FK = @ResidentID_BIGINT
              AND r.IdaraId_FK = @IdaraID_INT
              AND r.BillChargeTypeID_FK = @ChargeType_INT
              AND r.RefundStatus = 1;

            IF @NewRefunds <> @ExistingDetailTotal
            BEGIN
                THROW 50001, N'تفاصيل الاستردادات السابقة غير متطابقة، راجع السجلات', 1;
            END

            SET @Available = @EligiblePositive - @OldRefunds - @NewRefunds;

            IF @Available < @Amount_DECIMAL
            BEGIN
                THROW 50001, N'المبلغ المطلوب أكبر من الرصيد العام المتبقي المؤهل', 1;
            END

            -- Accounting policy: check AGGREGATE eligible remaining balance only.
            -- Do not gate refunds by PaymentReferenceDate <= RefundDate.
            -- RefundDate itself is still validated above (not future / not before occupancy).

            -- FIFO: reserve earlier eligible credits for the historical negative
            -- refunds, then subtract allocations from confirmed new refunds.
            ;WITH Ordered AS
            (
                SELECT e.PaymentID, e.PaymentAmount, e.PaymentReferenceDate,
                    SUM(CONVERT(DECIMAL(38,2), e.PaymentAmount)) OVER
                    (ORDER BY e.PaymentReferenceDate, e.PaymentID ROWS UNBOUNDED PRECEDING)
                    AS RunningGross
                FROM #EligiblePayments e
            ), OldReserved AS
            (
                SELECT o.*,
                    CASE
                        WHEN @OldRefunds <= o.RunningGross - o.PaymentAmount THEN CONVERT(DECIMAL(38,2), 0)
                        WHEN @OldRefunds >= o.RunningGross THEN CONVERT(DECIMAL(38,2), o.PaymentAmount)
                        ELSE @OldRefunds - (o.RunningGross - o.PaymentAmount)
                    END AS LegacyUsed
                FROM Ordered o
            ), PreviouslyAllocated AS
            (
                SELECT d.PaymentID_FK,
                    SUM(CONVERT(DECIMAL(38,2), d.AllocatedAmount)) AS Allocated
                FROM Housing.UnallocatedPaymentRefundDetail d
                INNER JOIN Housing.UnallocatedPaymentRefund r ON r.RefundID = d.RefundID_FK
                WHERE r.ResidentInfoID_FK = @ResidentID_BIGINT
                  AND r.IdaraId_FK = @IdaraID_INT
                  AND r.BillChargeTypeID_FK = @ChargeType_INT
                  AND r.RefundStatus = 1
                GROUP BY d.PaymentID_FK
            )
            SELECT o.PaymentID, o.PaymentReferenceDate,
                CONVERT(DECIMAL(38,2), o.PaymentAmount - o.LegacyUsed - ISNULL(x.Allocated, 0)) AS FreeAmount
            INTO #PaymentSlots
            FROM OldReserved o
            LEFT JOIN PreviouslyAllocated x ON x.PaymentID_FK = o.PaymentID;

            IF EXISTS (SELECT 1 FROM #PaymentSlots WHERE FreeAmount < 0)
            BEGIN
                THROW 50001, N'تعارض في تخصيص الاستردادات السابقة، يجب مراجعة الرصيد', 1;
            END

            IF @Amount_DECIMAL > ISNULL((SELECT SUM(FreeAmount) FROM #PaymentSlots), 0)
            BEGIN
                THROW 50001, N'الرصيد المتاح على السدادات الأصلية غير كافٍ', 1;
            END

            INSERT INTO Housing.UnallocatedPaymentRefund
            (
                  ResidentInfoID_FK, BillChargeTypeID_FK, IdaraId_FK
                , BillPaymentTypeID_FK, RefundAmount, RefundDate, RefundReference
                , RefundDetails, RequestKey, RefundStatus, EntryDate, EntryData, HostName
            )
            VALUES
            (
                  @ResidentID_BIGINT, @ChargeType_INT, @IdaraID_INT
                , @TypeID_INT, @Amount_DECIMAL, @RefundDate_DATE, LTRIM(RTRIM(@RefundReference))
                , @RefundDetails, @RequestKey_UID, 1, GETDATE(), @entryData, @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                THROW 50002, N'حصل خطأ في تسجيل عملية الاسترداد', 1;
            END

            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                THROW 50002, N'حصل خطأ في تسجيل رقم الاسترداد', 1;
            END

            ;WITH Running AS
            (
                SELECT s.PaymentID, s.FreeAmount,
                    SUM(s.FreeAmount) OVER
                    (ORDER BY s.PaymentReferenceDate, s.PaymentID ROWS UNBOUNDED PRECEDING)
                    AS RunningFree
                FROM #PaymentSlots s
                WHERE s.FreeAmount > 0
            ), Allocation AS
            (
                SELECT r.PaymentID,
                    CASE
                        WHEN @Amount_DECIMAL >= r.RunningFree THEN r.FreeAmount
                        WHEN @Amount_DECIMAL <= r.RunningFree - r.FreeAmount THEN CONVERT(DECIMAL(38,2),0)
                        ELSE @Amount_DECIMAL - (r.RunningFree - r.FreeAmount)
                    END AS AllocatedAmount
                FROM Running r
            )
            INSERT INTO Housing.UnallocatedPaymentRefundDetail
            (
                RefundID_FK, PaymentID_FK, AllocatedAmount
            )
            SELECT @NewID, a.PaymentID, CONVERT(DECIMAL(18,2), a.AllocatedAmount)
            FROM Allocation a WHERE a.AllocatedAmount > 0;

            SELECT @DetailTotal = ISNULL(SUM(CONVERT(DECIMAL(38,2), d.AllocatedAmount)), 0)
            FROM Housing.UnallocatedPaymentRefundDetail d
            WHERE d.RefundID_FK = @NewID;

            IF @DetailTotal <> @Amount_DECIMAL
            BEGIN
                THROW 50002, N'إجمالي تفاصيل الاسترداد لا يساوي المبلغ المسجل', 1;
            END

            SET @Note = N'{' + N'"RefundID":"' + CONVERT(NVARCHAR(30), @NewID)
                + N'","ResidentInfoID":"' + CONVERT(NVARCHAR(30), @ResidentID_BIGINT)
                + N'","ChargeTypeID":"' + CONVERT(NVARCHAR(20), @ChargeType_INT)
                + N'","IdaraID":"' + CONVERT(NVARCHAR(20), @IdaraID_INT)
                + N'","RefundAmount":"' + CONVERT(NVARCHAR(50), @Amount_DECIMAL)
                + N'","BillPaymentTypeID":"4"}';

            INSERT INTO dbo.AuditLog
            (
                TableName, ActionType, RecordID, PerformedBy, Notes
            )
            VALUES
            (
                  N'[Housing].[UnallocatedPaymentRefund],[Housing].[UnallocatedPaymentRefundDetail]'
                , @Action, @NewID, @entryData, @Note
            );

            SELECT 1 AS IsSuccessful, N'تم تسجيل المبلغ المعاد للمستفيد بنجاح' AS Message_;
            RETURN;
        END
        ELSE IF @Action = N'CANCELUNALLOCATEDPAYMENTREFUND'
        BEGIN
            -- The caller (dbo.Masters_CRUD) must authorize this ActionType.
            IF @CancelRefundID IS NULL OR @CancelRefundID <= 0
                THROW 50001, N'رقم الاسترداد غير صحيح', 1;

            IF @IdaraID_INT IS NULL OR @IdaraID_INT <= 0
                THROW 50001, N'الإدارة غير صحيحة', 1;

            IF @CancelReason IS NULL OR LEN(@CancelReason) > 1000
                THROW 50001, N'سبب الإلغاء مطلوب وبحد أقصى 1000 حرف', 1;

            IF NULLIF(LTRIM(RTRIM(@entryData)), N'') IS NULL
                THROW 50001, N'بيانات المستخدم غير مكتملة', 1;

            -- Read the group keys without acquiring a row lock first.
            -- Lock ordering must match INSERT: application lock, then row lock.
            SELECT @CancelResidentID = r.ResidentInfoID_FK,
                   @CancelChargeTypeID = r.BillChargeTypeID_FK
            FROM Housing.UnallocatedPaymentRefund r
            WHERE r.RefundID = @CancelRefundID
              AND r.IdaraId_FK = @IdaraID_INT;

            IF @CancelResidentID IS NULL OR @CancelChargeTypeID IS NULL
                THROW 50001, N'سجل الاسترداد غير موجود ضمن الإدارة المصرح بها', 1;

            SET @LockResource = N'HUPR|' + CONVERT(NVARCHAR(20), @IdaraID_INT)
                + N'|' + CONVERT(NVARCHAR(30), @CancelResidentID)
                + N'|' + CONVERT(NVARCHAR(20), @CancelChargeTypeID);

            EXEC @LockResult = sys.sp_getapplock
                  @Resource = @LockResource
                , @LockMode = N'Exclusive'
                , @LockOwner = N'Transaction'
                , @LockTimeout = 10000;

            IF @LockResult < 0
                THROW 50001, N'تعذر حجز الرصيد حاليًا، حاول مجددًا', 1;

            -- Verify again after acquiring the same lock used by INSERT.
            SELECT @CancelStatus = r.RefundStatus,
                   @CancelAmount = r.RefundAmount
            FROM Housing.UnallocatedPaymentRefund r WITH (UPDLOCK, HOLDLOCK)
            WHERE r.RefundID = @CancelRefundID
              AND r.IdaraId_FK = @IdaraID_INT
              AND r.ResidentInfoID_FK = @CancelResidentID
              AND r.BillChargeTypeID_FK = @CancelChargeTypeID;

            IF @CancelStatus IS NULL
                THROW 50001, N'سجل الاسترداد غير موجود', 1;

            IF @CancelStatus = 2
                THROW 50001, N'سبق إلغاء تسجيل هذا الاسترداد', 1;

            IF @CancelStatus <> 1
                THROW 50001, N'حالة الاسترداد لا تسمح بالإلغاء', 1;

            SELECT @CancelAllocated = ISNULL(SUM(CONVERT(DECIMAL(38,2), d.AllocatedAmount)), 0)
            FROM Housing.UnallocatedPaymentRefundDetail d
            WHERE d.RefundID_FK = @CancelRefundID;

            IF @CancelAllocated <> @CancelAmount
                THROW 50001, N'تفاصيل الاسترداد غير متطابقة؛ يجب مراجعتها قبل الإلغاء', 1;

            UPDATE Housing.UnallocatedPaymentRefund
            SET RefundStatus = 2,
                CancellationReason = @CancelReason,
                CancellationDate = SYSDATETIME(),
                CancellationEntryData = @entryData
            WHERE RefundID = @CancelRefundID
              AND IdaraId_FK = @IdaraID_INT
              AND ResidentInfoID_FK = @CancelResidentID
              AND BillChargeTypeID_FK = @CancelChargeTypeID
              AND RefundStatus = 1;

            IF @@ROWCOUNT <> 1
                THROW 50001, N'تعذر إلغاء التسجيل؛ يرجى تحديث البيانات', 1;

            SELECT @Note =
            (
                SELECT @CancelRefundID AS RefundID,
                       @CancelResidentID AS ResidentInfoID,
                       @CancelChargeTypeID AS ChargeTypeID,
                       @IdaraID_INT AS IdaraID,
                       @CancelAmount AS RefundAmount,
                       CONVERT(INT, 1) AS PreviousStatus,
                       CONVERT(INT, 2) AS NewStatus,
                       @CancelReason AS CancellationReason
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );

            INSERT INTO dbo.AuditLog
            (
                TableName, ActionType, RecordID, PerformedBy, Notes
            )
            VALUES
            (
                N'[Housing].[UnallocatedPaymentRefund]',
                @Action, @CancelRefundID, @entryData, @Note
            );

            SELECT 1 AS IsSuccessful, N'تم إلغاء تسجيل الاسترداد بنجاح' AS Message_;
            RETURN;
        END
        ELSE
        BEGIN
            THROW 50001, N'العملية غير مسجلة', 1;
        END
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END;