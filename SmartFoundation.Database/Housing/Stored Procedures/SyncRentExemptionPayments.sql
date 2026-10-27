CREATE PROCEDURE [Housing].[SyncRentExemptionPayments]
      @Action                    NVARCHAR(20)
    , @ResidentRentExemptionID   BIGINT
    , @ThroughDate               DATE = NULL
    , @SourceType                NVARCHAR(30) = N'MANUAL'
    , @EntryData                 NVARCHAR(20) = NULL
    , @HostName                  NVARCHAR(200) = NULL
    , @TargetBillsID BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TransactionCount INT = @@TRANCOUNT;

    BEGIN TRY
        IF @TransactionCount = 0
            BEGIN TRANSACTION;

        IF @Action NOT IN (N'GENERATE', N'CANCEL')
        BEGIN
            ;THROW 50001, N'عملية معالجة سدادات الإعفاء غير صحيحة', 1;
        END;

        IF @ResidentRentExemptionID IS NULL
        BEGIN
            ;THROW 50001, N'رقم الإعفاء مطلوب لمعالجة سدادات الإعفاء', 1;
        END;

        /* منع استخدام الإلغاء العام على فاتورة محددة */
IF @TargetBillsID IS NOT NULL
   AND @Action <> N'GENERATE'
BEGIN
    THROW 50001,
          N'لا يمكن استخدام إلغاء الإعفاء العام لفاتورة محددة.',
          1;
END;

/* معالجة إعفاء الإخلاء يجب أن تستهدف فاتورة محددة */
IF @SourceType = N'EXIT_RENT'
   AND
   (
       @Action <> N'GENERATE'
       OR @TargetBillsID IS NULL
   )
BEGIN
    THROW 50001,
          N'يجب تحديد فاتورة الإخلاء عند معالجة إعفائها.',
          1;
END;

        IF @Action = N'CANCEL'
        BEGIN
            DECLARE @CanceledPayments TABLE
            (
                  paymentID BIGINT PRIMARY KEY
                , deductListID INT NULL
            );

            INSERT INTO @CanceledPayments (paymentID, deductListID)
            SELECT paymentRow.paymentID, paymentRow.deductListID_FK
            FROM Housing.ResidentRentExemptionPayment linkRow WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN Housing.BuildingPayment paymentRow
                ON paymentRow.paymentID = linkRow.paymentID_FK
            WHERE linkRow.residentRentExemptionID_FK = @ResidentRentExemptionID
              AND linkRow.paymentActive = 1;

            UPDATE paymentRow
               SET paymentRow.buildingPayementActive = 0,
                   paymentRow.entryData = @EntryData,
                   paymentRow.hostName = @HostName,
                   paymentRow.paymentLinkNote = CONCAT(N'ملغي بسبب معالجة الإعفاء رقم ', @ResidentRentExemptionID)
            FROM Housing.BuildingPayment paymentRow
            INNER JOIN @CanceledPayments canceled
                ON canceled.paymentID = paymentRow.paymentID;

            UPDATE deductRow
               SET deductRow.deductActive = 0,
                   deductRow.DeductListStatusID_FK = 3,
                   deductRow.description = CONCAT(ISNULL(deductRow.description, N''), N' | ملغي بسبب معالجة الإعفاء رقم ', @ResidentRentExemptionID),
                   deductRow.entryData = @EntryData,
                   deductRow.hostName = @HostName
            FROM Housing.DeductList deductRow
            INNER JOIN @CanceledPayments canceled
                ON canceled.deductListID = deductRow.deductListID;

            UPDATE Housing.ResidentRentExemptionPayment
               SET paymentActive = 0,
                   canceledBy = @EntryData,
                   canceledDate = GETDATE(),
                   canceledReason = CONCAT(N'إلغاء سدادات الإعفاء - ', @SourceType)
            WHERE residentRentExemptionID_FK = @ResidentRentExemptionID
              AND paymentActive = 1;

            IF @TransactionCount = 0
                COMMIT TRANSACTION;

            RETURN;
        END;

        DECLARE
              @ResidentInfoID BIGINT
            , @GeneralNo BIGINT
            , @NationalID NVARCHAR(10)
            , @ResidentName NVARCHAR(500)
            , @BuildingDetailsID BIGINT
            , @IdaraID INT
            , @ExemptionStartDate DATE
            , @ExemptionEndDate DATE
            , @ExemptionPercentage DECIMAL(9,4)
            , @ExemptionActive BIT
            , @ExemptPaymentTypeID INT;

        SELECT
              @ResidentInfoID = exemption.residentInfoID_FK
            , @BuildingDetailsID = exemption.buildingDetailsID_FK
            , @IdaraID = exemption.idaraID_FK
            , @ExemptionStartDate = CAST(exemption.residentRentExemptionStartDate AS date)
            , @ExemptionEndDate = CAST(exemption.residentRentExemptionEndDate AS date)
            , @ExemptionPercentage = TRY_CONVERT(DECIMAL(9,4), exemptionType.ResidentRentExemptionTypePercentage)
            , @ExemptionActive = ISNULL(exemption.residentRentExemptionActive, 0)
        FROM Housing.ResidentRentExemption exemption WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN Housing.ResidentRentExemptionType exemptionType
            ON exemptionType.ResidentRentExemptionTypeID = exemption.residentRentExemptionTypeID_FK
        WHERE exemption.residentRentExemptionID = @ResidentRentExemptionID;

        IF @ResidentInfoID IS NULL OR @BuildingDetailsID IS NULL OR @IdaraID IS NULL
        BEGIN
            ;THROW 50001, N'بيانات الإعفاء غير مكتملة ولا يمكن رصد سداده', 1;
        END;

        IF @ExemptionActive = 0
        BEGIN
            ;THROW 50001, N'لا يمكن رصد سداد لإعفاء ملغي', 1;
        END;

        IF @ExemptionStartDate IS NULL
        BEGIN
            ;THROW 50001, N'تاريخ بداية الإعفاء مطلوب لرصد السداد', 1;
        END;

        IF @ExemptionPercentage IS NULL OR @ExemptionPercentage <= 0 OR @ExemptionPercentage > 100
        BEGIN
            ;THROW 50001, N'نسبة نوع الإعفاء يجب أن تكون أكبر من صفر ولا تتجاوز 100', 1;
        END;

        SELECT TOP (1)
            @ExemptPaymentTypeID = paymentType.buildingPaymentTypeID
        FROM Housing.BuildingPaymentType paymentType
        WHERE paymentType.buildingPaymentTypeActive = 1
          AND
          (
              REPLACE(REPLACE(paymentType.buildingPaymentTypeName_A, N'ى', N'ي'), N'إ', N'ا') LIKE N'%معفي%الايجار%'
              OR LOWER(ISNULL(paymentType.buildingPaymentTypeName_E, N'')) LIKE N'%exempt%rent%'
          )
        ORDER BY paymentType.buildingPaymentTypeID;

        IF @ExemptPaymentTypeID IS NULL
        BEGIN
            ;THROW 50001, N'نوع السداد معفي من الإيجار غير معرف أو غير فعال', 1;
        END;

        SELECT TOP (1)
              @GeneralNo = resident.generalNo_FK
            , @NationalID = resident.NationalID
            , @ResidentName = LTRIM(RTRIM(CONCAT_WS(N' ', resident.firstName_A, resident.secondName_A, resident.thirdName_A, resident.lastName_A)))
        FROM Housing.V_GetFullResidentDetails resident
        WHERE resident.residentInfoID = @ResidentInfoID;

        SET @ThroughDate = ISNULL(@ThroughDate, CAST(GETDATE() AS date));

        /* التحقق من الفاتورة المستهدفة */
IF @TargetBillsID IS NOT NULL
BEGIN
    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.Bills b WITH (UPDLOCK, HOLDLOCK)
        WHERE b.BillsID = @TargetBillsID
          AND b.residentInfoID_FK = @ResidentInfoID
          AND b.buildingDetailsID = @BuildingDetailsID
          AND b.idaraID_FK = @IdaraID
          AND b.BillChargeTypeID_FK = 1
          AND b.BillActive = 1
          AND
          (
              @SourceType <> N'EXIT_RENT'
              OR
              (
                  b.BillTypeID_FK = 3
                  AND b.ExitRequestActionID_FK IS NOT NULL
              )
          )
    )
    BEGIN
        THROW 50001,
              N'الفاتورة المحددة غير موجودة أو لا تتبع المستفيد ودورة الإخلاء.',
              1;
    END;
END;

        DECLARE billCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
              bill.BillsID
            , CAST(bill.BillsFromDate AS date)
            , CAST(bill.BillsToDate AS date)
            , CAST(bill.TotalPrice AS DECIMAL(18,2))
        FROM Housing.Bills bill WITH (UPDLOCK, HOLDLOCK)
        WHERE bill.residentInfoID_FK = @ResidentInfoID
          AND bill.buildingDetailsID = @BuildingDetailsID
          AND bill.idaraID_FK = @IdaraID
          AND bill.BillChargeTypeID_FK = 1
          AND bill.BillActive = 1
          AND
(
    @TargetBillsID IS NULL
    OR bill.BillsID = @TargetBillsID
)
          AND CAST(bill.BillsFromDate AS date) <= ISNULL(@ExemptionEndDate, @ThroughDate)
          AND CAST(bill.BillsToDate AS date) >= @ExemptionStartDate
          AND CAST(bill.BillsFromDate AS date) <= @ThroughDate
          AND NOT EXISTS
          (
              SELECT 1
              FROM Housing.ResidentRentExemptionPayment existing WITH (UPDLOCK, HOLDLOCK)
              WHERE existing.residentRentExemptionID_FK = @ResidentRentExemptionID
                AND existing.billsID_FK = bill.BillsID
                AND existing.paymentActive = 1
          )
        ORDER BY bill.BillsFromDate, bill.BillsID;

        DECLARE
              @BillsID BIGINT
            , @BillFromDate DATE
            , @BillToDate DATE
            , @BillAmount DECIMAL(18,2)
            , @OverlapFrom DATE
            , @OverlapTo DATE
            , @BillDays30 INT
            , @ExemptDays30 INT
            , @PaymentAmount DECIMAL(18,2)
            , @DeductListID INT
            , @PaymentID BIGINT;

        OPEN billCursor;
        FETCH NEXT FROM billCursor INTO @BillsID, @BillFromDate, @BillToDate, @BillAmount;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @OverlapFrom = CASE WHEN @ExemptionStartDate > @BillFromDate THEN @ExemptionStartDate ELSE @BillFromDate END;
            SET @OverlapTo = CASE
                                 WHEN ISNULL(@ExemptionEndDate, @ThroughDate) < @BillToDate THEN ISNULL(@ExemptionEndDate, @ThroughDate)
                                 ELSE @BillToDate
                             END;

            SET @BillDays30 =
                (YEAR(@BillToDate) - YEAR(@BillFromDate)) * 360
                + (MONTH(@BillToDate) - MONTH(@BillFromDate)) * 30
                + (CASE WHEN @BillToDate = EOMONTH(@BillToDate) OR DAY(@BillToDate) > 30 THEN 30 ELSE DAY(@BillToDate) END)
                - (CASE WHEN @BillFromDate = EOMONTH(@BillFromDate) OR DAY(@BillFromDate) > 30 THEN 30 ELSE DAY(@BillFromDate) END)
                + 1;

            SET @ExemptDays30 =
                (YEAR(@OverlapTo) - YEAR(@OverlapFrom)) * 360
                + (MONTH(@OverlapTo) - MONTH(@OverlapFrom)) * 30
                + (CASE WHEN @OverlapTo = EOMONTH(@OverlapTo) OR DAY(@OverlapTo) > 30 THEN 30 ELSE DAY(@OverlapTo) END)
                - (CASE WHEN @OverlapFrom = EOMONTH(@OverlapFrom) OR DAY(@OverlapFrom) > 30 THEN 30 ELSE DAY(@OverlapFrom) END)
                + 1;

            SET @PaymentAmount = ROUND(@BillAmount * (@ExemptionPercentage / 100.0) * @ExemptDays30 / NULLIF(@BillDays30, 0), 2);

            IF @OverlapFrom <= @OverlapTo AND @PaymentAmount > 0
            BEGIN
                INSERT INTO Housing.DeductList
                (
                      deductTypeID_FK, DeductListStatusID_FK, deductName, amountTypeID_FK
                    , paymentTypeID_FK, issueMonth, issueYear, paymentNo, paymentDate
                    , description, deductActive, BillChargeTypeID_FK, IdaraId_FK
                    , entryDate, entryData, hostName
                )
                VALUES
                (
                      NULL, 2, N'سداد إعفاء من الإيجار', 1
                    , @ExemptPaymentTypeID, MONTH(@BillFromDate), YEAR(@BillFromDate)
                    , CONCAT(N'RE-', @ResidentRentExemptionID, N'-', @BillsID), GETDATE()
                    , CONCAT(N'إعفاء رقم ', @ResidentRentExemptionID, N' للفاتورة رقم ', @BillsID)
                    , 1, 1, @IdaraID, GETDATE(), @EntryData, @HostName
                );

                SET @DeductListID = SCOPE_IDENTITY();

                INSERT INTO Housing.BuildingPayment
                (
                      buildingPaymentTypeID_FK, generalNo_FK, IDNumber, residentInfoID_FK
                    , userName, buildingDetailsID_FK, amount, deductListID_FK
                    , buildingPayementActive, BillChargeTypeID_FK, IdaraId_FK
                    , entryDate, entryData, hostName, buildingPaymentLinkStatusID_FK, paymentLinkNote
                )
                VALUES
                (
                      @ExemptPaymentTypeID, @GeneralNo, @NationalID, @ResidentInfoID
                    , @ResidentName, CONVERT(NVARCHAR(200), @BuildingDetailsID), @PaymentAmount, @DeductListID
                    , 1, 1, @IdaraID, GETDATE(), @EntryData, @HostName, 1
                    , CONCAT(N'سداد إعفاء مرتبط بالفاتورة ', @BillsID)
                );

                SET @PaymentID = SCOPE_IDENTITY();

                INSERT INTO Housing.ResidentRentExemptionPayment
                (
                      residentRentExemptionID_FK, paymentID_FK, billsID_FK
                    , exemptionFromDate, exemptionToDate, exemptionAmount
                    , sourceType, paymentActive, entryDate, entryData, hostName
                )
                VALUES
                (
                      @ResidentRentExemptionID, @PaymentID, @BillsID
                    , @OverlapFrom, @OverlapTo, @PaymentAmount
                    , @SourceType, 1, GETDATE(), @EntryData, @HostName
                );
            END;

            FETCH NEXT FROM billCursor INTO @BillsID, @BillFromDate, @BillToDate, @BillAmount;
        END;

        CLOSE billCursor;
        DEALLOCATE billCursor;

        IF @TransactionCount = 0
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'billCursor') >= 0
            CLOSE billCursor;
        IF CURSOR_STATUS('local', 'billCursor') > -3
            DEALLOCATE billCursor;

        IF @TransactionCount = 0 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;