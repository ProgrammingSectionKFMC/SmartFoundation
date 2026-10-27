
CREATE PROCEDURE [Housing].[FinancialAuditForUserSP] 
(
      @Action                               NVARCHAR(200)
    , @ActionID                             BIGINT          = NULL
    , @residentInfoID                       NVARCHAR(100)   = NULL
    , @buildingDetailsID                    NVARCHAR(1000)  = NULL
    , @LastActionID                         NVARCHAR(1000)  = NULL
    , @LastActionTypeID                     NVARCHAR(1000)  = NULL
    , @Notes                                NVARCHAR(1000)  = NULL
    , @ExitDate                             NVARCHAR(1000)  = NULL
    , @LastActionExtendReasonTypeID         NVARCHAR(1000)  = NULL
    , @PaymentType                          NVARCHAR(1000)  = NULL
    , @PaymentNo                            NVARCHAR(1000)  = NULL
    , @PaymentDate                          NVARCHAR(1000)  = NULL
    , @Amount                               NVARCHAR(1000)  = NULL
    , @FullRemining                         NVARCHAR(1000)  = NULL
    , @BillChargeTypeID_FK                  NVARCHAR(1000)  = NULL
    , @ToBillChargeTypeID_FK                NVARCHAR(1000)  = NULL
    , @description                          NVARCHAR(4000)  = NULL
    , @idaraID_FK                           NVARCHAR(10)    = NULL
    , @entryData                            NVARCHAR(20)    = NULL
    , @hostName                             NVARCHAR(200)   = NULL
    , @GeneralPaymentID BIGINT = NULL
    , @GeneralRequestKey NVARCHAR(100) = NULL
)

AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE 
          @NewID BIGINT = NULL,
          @NewID1 BIGINT = NULL,
          @NewID2 BIGINT = NULL
        , @Note  NVARCHAR(MAX) = NULL;

    -- تحويلات رقمية آمنة
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(@idaraID_FK, ''));
    DECLARE @DeductType_INT INT = (select t.deductTypeID_FK from Housing.BuildingPaymentType t where t.buildingPaymentTypeID = @PaymentType);


    DECLARE @Amount_Decimal DECIMAL(18,2);

    SET @Amount_Decimal = TRY_CONVERT(DECIMAL(18,2), @Amount);
    
    IF @Amount_Decimal IS NULL
    BEGIN
        ;THROW 50001, N'قيمة المبلغ غير صحيحة', 1;
    END


    
   
    

    DECLARE @buildingDetailsNo nvarchar(200)
            , @NationalID                           NVARCHAR(100)   
            , @GeneralNo                            NVARCHAR(100)   
            , @WaitingClassID                       NVARCHAR(1000)  
            , @WaitingClassName                     NVARCHAR(1000)  
            , @WaitingOrderTypeID                   NVARCHAR(1000)  
            , @WaitingOrderTypeName                 NVARCHAR(1000)  
            , @waitingClassSequence                 NVARCHAR(1000)  
            , @WaitingListOrder                     NVARCHAR(1000)  
            , @FullName_A                           NVARCHAR(1000)  
            , @AssignPeriodID                       NVARCHAR(1000)  
            , @ExtendStartDate                      NVARCHAR(1000)
            , @ExtendEndDate                        NVARCHAR(1000)
            , @ExtendLetterNo                       NVARCHAR(1000)
            , @ExtendLetterDate                     NVARCHAR(1000)
            , @unitID                               NVARCHAR(1000)
            , @FullName                             NVARCHAR(1000)
            
            
    select 
    --@NationalID               = w.NationalID,
    --@GeneralNo                = w.GeneralNo,
    @WaitingClassID           = w.WaitingClassID,
    @WaitingClassName         = w.WaitingClassName,
    @WaitingOrderTypeID       = w.WaitingOrderTypeID,
    @WaitingOrderTypeName     = w.WaitingClassName,
    @waitingClassSequence     = w.waitingClassSequence,
    @FullName_A               = w.fullname,
    @AssignPeriodID           = w.AssignPeriodID,
    @ExtendStartDate          = w.buildingActionFromDate,
    @ExtendEndDate            = w.buildingActionToDate,
    @ExtendLetterNo           = w.ActionDecisionNo,
    @ExtendLetterDate         = w.ActionDecisionDate,
    @buildingDetailsNo         = w.buildingDetailsNo

    from Housing.V_WaitingList w
    where 
    w.LastActionID = @LastActionID
    and 
    w.ActionID = @ActionID
    and 
    w.residentInfoID = @residentInfoID
    and 
    w.buildingDetailsID = @buildingDetailsID
    and 
    w.LastActionTypeID = @LastActionTypeID
    and 
    w.IdaraId = @idaraID_FK



              
    select 
    @NationalID               = w.NationalID,
    @GeneralNo                = w.generalNo_FK,
    @unitiD                   = w.militaryUnitID_FK,
    @FullName                 = w.FullName_A
    FROM Housing.V_GetFullResidentDetails w
    where w.residentInfoID = @residentInfoID

   
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

   


        -- IF @Action IN(N'NewExtend',N'EditExtend',N'SendExtendToFinance')
        --BEGIN
         
           


        --END

        

     

      
       
        

         ----------------------------------------------------------------
        -- PAYMENTANDREFUNDFOREXTENDANDEXIT
        ----------------------------------------------------------------
         IF @Action = N'PAYMENTANDREFUNDFORUSER'
        BEGIN
            -- No ActionID or WaitingList state is required for general financial auditing.
            -- The gateway dbo.Masters_CRUD is responsible for ActionType permissions.
            DECLARE @AuditResidentID BIGINT = TRY_CONVERT(BIGINT, @residentInfoID);
            DECLARE @AuditBuildingID BIGINT = TRY_CONVERT(BIGINT, @buildingDetailsID);
            DECLARE @AuditServiceID BIGINT = TRY_CONVERT(BIGINT, @BillChargeTypeID_FK);
            DECLARE @AuditPaymentTypeID INT = TRY_CONVERT(INT, @PaymentType);
            DECLARE @AuditDirection INT = NULL;
            DECLARE @AuditLinkStatus INT = NULL;
            DECLARE @AuditDate DATE = TRY_CONVERT(DATE, @PaymentDate);
            DECLARE @AuditFirstOccupancy DATE = NULL;
            DECLARE @AuditSourceBalance DECIMAL(38,2) = 0;
            DECLARE @AuditPriorSeparateRefunds DECIMAL(38,2) = 0;
            DECLARE @AuditAvailable DECIMAL(38,2) = 0;
            DECLARE @AuditPreciseAmount DECIMAL(38,18) = TRY_CONVERT(DECIMAL(38,18), @Amount);
            DECLARE @AuditLockResult INT;
            DECLARE @AuditLockResource NVARCHAR(255);

            IF @IdaraID_INT IS NULL OR @IdaraID_INT <= 0
                THROW 50001, N'الإدارة غير صحيحة', 1;

            IF @AuditResidentID IS NULL OR @AuditResidentID <= 0
                THROW 50001, N'رقم المستفيد غير صحيح', 1;

            IF @AuditServiceID IS NULL OR @AuditServiceID <= 0
                THROW 50001, N'نوع الخدمة غير صحيح', 1;

            IF NOT EXISTS
            (
                SELECT 1
                FROM Housing.BillChargeType c
                WHERE c.BillChargeTypeID = @AuditServiceID
                  AND c.BillChargeTypeActive = 1
            )
                THROW 50001, N'نوع الخدمة غير مفعل', 1;

            IF @Amount_Decimal <= 0
               OR @Amount_Decimal >= 100000000
               OR @AuditPreciseAmount IS NULL
               OR @AuditPreciseAmount <> CONVERT(DECIMAL(38,18), @Amount_Decimal)
                THROW 50001, N'مبلغ العملية غير صحيح أو يتجاوز الحد المسموح أو يحتوي أكثر من منزلتين عشريتين', 1;

            IF NULLIF(LTRIM(RTRIM(@PaymentNo)), N'') IS NULL
               OR LEN(LTRIM(RTRIM(@PaymentNo))) > 50
                THROW 50001, N'رقم مستند العملية مطلوب وبحد أقصى 50 حرفًا', 1;

            IF @AuditDate IS NULL OR @AuditDate > CONVERT(DATE, GETDATE())
                THROW 50001, N'تاريخ العملية غير صحيح أو في المستقبل', 1;

            IF NULLIF(LTRIM(RTRIM(@description)), N'') IS NULL
               OR LEN(@description) > 1500
                THROW 50001, N'ملاحظات العملية مطلوبة وبحد أقصى 1500 حرف', 1;

            SELECT @AuditDirection = t.buildingPaymentDestainationID_FK
            FROM Housing.BuildingPaymentType t
            WHERE t.buildingPaymentTypeID = @AuditPaymentTypeID
              AND t.buildingPaymentTypeActive = 1
              AND t.deductTypeID_FK IS NOT NULL;

            -- Type 6 is a two-sided settlement, not a standalone cash payment.
            -- Type 3 is rent exemption, not a cash receipt.
            IF @AuditDirection IS NULL OR NOT
            (
                (@AuditDirection = 1 AND @AuditPaymentTypeID IN (1,2,5))
                OR (@AuditDirection = 2 AND @AuditPaymentTypeID = 4)
            )
                THROW 50001, N'نوع العملية غير مسموح به للسداد أو إعادة المبالغ', 1;

            IF NULLIF(LTRIM(RTRIM(@buildingDetailsID)), N'') IS NULL
               OR LTRIM(RTRIM(@buildingDetailsID)) = N'-1'
                SET @AuditBuildingID = NULL;
            ELSE IF @AuditBuildingID IS NULL OR @AuditBuildingID <= 0
                THROW 50001, N'معرف المبنى غير صحيح', 1;

            -- An unallocated/general row uses NULL, never the UI sentinel -1.
            SET @AuditLinkStatus = CASE WHEN @AuditBuildingID IS NULL THEN 2 ELSE 1 END;
            SET @buildingDetailsID = CASE WHEN @AuditBuildingID IS NULL THEN NULL
                                          ELSE CONVERT(NVARCHAR(1000), @AuditBuildingID) END;

            -- Resolve the beneficiary within the authenticated department, not via WaitingList.
            IF NOT EXISTS
            (
                SELECT 1
                FROM Housing.V_GetFullResidentDetails f
                WHERE f.residentInfoID = @AuditResidentID
                  AND f.IdaraID = @IdaraID_INT
            )
                THROW 50001, N'المستفيد غير موجود ضمن الإدارة المصرح بها', 1;

            -- Override the old unscoped beneficiary lookup earlier in this procedure.
            SET @NationalID = NULL;
            SET @GeneralNo = NULL;
            SET @unitiD = NULL;
            SET @FullName = NULL;
            SELECT TOP (1)
                @NationalID = f.NationalID,
                @GeneralNo = f.generalNo_FK,
                @unitiD = f.militaryUnitID_FK,
                @FullName = f.FullName_A
            FROM Housing.V_GetFullResidentDetails f
            WHERE f.residentInfoID = @AuditResidentID
              AND f.IdaraID = @IdaraID_INT
            ORDER BY f.residentDetailsID DESC;

            SELECT @AuditFirstOccupancy = MIN(CONVERT(DATE, a.buildingActionDate))
            FROM Housing.BuildingAction a
            WHERE a.residentInfoID_FK = @AuditResidentID
              AND a.IdaraId_FK = @IdaraID_INT
              AND a.buildingActionTypeID_FK = 2
              AND a.buildingActionActive = 1
              AND a.buildingActionDate IS NOT NULL
              AND a.buildingDetailsID_FK IS NOT NULL;

            IF @AuditFirstOccupancy IS NULL
                THROW 50001, N'لا يوجد أول إشغال موثق يتيح اعتماد هذه الحركة المالية', 1;

            IF @AuditDirection = 2 AND @AuditDate < @AuditFirstOccupancy
                THROW 50001, N'تاريخ إعادة المبلغ يسبق أول إشغال موثق', 1;

            IF @AuditDirection = 1 AND EOMONTH(@AuditDate) < @AuditFirstOccupancy
                THROW 50001, N'فترة السداد تسبق أول إشغال موثق بالكامل', 1;

            IF @AuditBuildingID IS NOT NULL
            BEGIN
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM Housing.BuildingDetails b
                    WHERE b.buildingDetailsID = @AuditBuildingID
                      AND b.IdaraId_FK = @IdaraID_INT
                )
                    THROW 50001, N'المبنى لا يتبع الإدارة المصرح بها', 1;

                IF NOT EXISTS
                (
                    SELECT 1
                    FROM Housing.BuildingAction a
                    WHERE a.residentInfoID_FK = @AuditResidentID
                      AND a.IdaraId_FK = @IdaraID_INT
                      AND a.buildingDetailsID_FK = @AuditBuildingID
                      AND a.buildingActionTypeID_FK = 2
                      AND a.buildingActionActive = 1
                      AND a.buildingActionDate IS NOT NULL
                )
                    THROW 50001, N'لا يوجد إشغال موثق لهذا المستفيد في المبنى المحدد', 1;
            END

            -- Serialize operations per resident, department, service and building.
            -- Future transfer/settlement code must use the SAME lock key.
            SET @AuditLockResource = CONCAT(N'HFA|', @IdaraID_INT, N'|', @AuditResidentID,
                                            N'|', @AuditServiceID, N'|',
                                            COALESCE(CONVERT(NVARCHAR(30), @AuditBuildingID), N'GENERAL'));
            EXEC @AuditLockResult = sys.sp_getapplock
                  @Resource = @AuditLockResource,
                  @LockMode = N'Exclusive',
                  @LockOwner = N'Transaction',
                  @LockTimeout = 10000;

            IF @AuditLockResult < 0
                THROW 50001, N'تعذر حجز الرصيد حاليًا، يرجى إعادة المحاولة', 1;

            -- Stop immediate repeat submissions of the same receipt/refund reference.
            IF EXISTS
            (
                SELECT 1
                FROM Housing.BuildingPayment p
                INNER JOIN Housing.DeductList d ON d.deductListID = p.deductListID_FK
                WHERE p.residentInfoID_FK = @AuditResidentID
                  AND p.IdaraId_FK = @IdaraID_INT
                  AND p.BillChargeTypeID_FK = @AuditServiceID
                  AND p.buildingPaymentTypeID_FK = @AuditPaymentTypeID
                  AND p.buildingPayementActive = 1
                  AND d.deductActive = 1
                  AND LTRIM(RTRIM(d.paymentNo)) = LTRIM(RTRIM(@PaymentNo))
                  AND
                  (
                      (@AuditBuildingID IS NULL AND
                          (p.buildingPaymentLinkStatusID_FK = 2
                           OR NULLIF(LTRIM(RTRIM(p.buildingDetailsID_FK)), N'') IS NULL))
                      OR
                      (@AuditBuildingID IS NOT NULL AND
                          TRY_CONVERT(BIGINT, p.buildingDetailsID_FK) = @AuditBuildingID)
                  )
            )
                THROW 50001, N'تم تسجيل رقم المستند مسبقًا لهذه العملية والخدمة والمبنى', 1;

            IF @AuditDirection = 2
            BEGIN
                -- Signed Remaining = claims - payments. A refund needs a true surplus.
                SELECT @AuditSourceBalance = COALESCE(SUM(CONVERT(DECIMAL(38,2), v.Remaining)), 0)
                FROM Housing.V_SumBillsTotalPriceAndTotalPaidForResident v
                WHERE v.residentInfoID = @AuditResidentID
                  AND v.idaraID = @IdaraID_INT
                  AND v.BillChargeTypeID = @AuditServiceID
                  AND
                  (
                      (@AuditBuildingID IS NULL AND v.buildingDetailsID IS NULL)
                      OR (v.buildingDetailsID = @AuditBuildingID)
                  );

                -- Confirmed legacy refunds are not part of the signed-payment view.
                IF @AuditBuildingID IS NULL
                BEGIN
                    SELECT @AuditPriorSeparateRefunds = COALESCE(SUM(CONVERT(DECIMAL(38,2), r.RefundAmount)), 0)
                    FROM Housing.UnallocatedPaymentRefund r
                    WHERE r.ResidentInfoID_FK = @AuditResidentID
                      AND r.IdaraId_FK = @IdaraID_INT
                      AND r.BillChargeTypeID_FK = @AuditServiceID
                      AND r.RefundStatus = 1;
                END

                SET @AuditAvailable = -@AuditSourceBalance - @AuditPriorSeparateRefunds;
                IF @AuditAvailable <= 0 OR CONVERT(DECIMAL(38,2), @Amount_Decimal) > @AuditAvailable
                    THROW 50001, N'مبلغ الإعادة أكبر من الفائض المؤهل المتبقي للخدمة والمبنى المحددين', 1;
            END

            ------------------------------------------------------------
-- Prevent overpayment against an existing building debt.
-- Must run AFTER acquiring the HFA application lock.
------------------------------------------------------------
IF @AuditDirection = 1 AND @AuditBuildingID IS NOT NULL
BEGIN
    DECLARE @AuditCurrentDebt DECIMAL(38,2) = 0;

    SELECT @AuditCurrentDebt =
        COALESCE(SUM(CONVERT(DECIMAL(38,2), v.Remaining)), 0)
    FROM Housing.V_SumBillsTotalPriceAndTotalPaidForResident v
    WHERE v.residentInfoID = @AuditResidentID
      AND v.idaraID = @IdaraID_INT
      AND v.BillChargeTypeID = @AuditServiceID
      AND v.buildingDetailsID = @AuditBuildingID;

    IF @AuditCurrentDebt <= 0
       OR CONVERT(DECIMAL(38,2), @Amount_Decimal) > @AuditCurrentDebt
    BEGIN
        DECLARE @AuditDebtMessage NVARCHAR(2048) =
            CONCAT(
                N'تعذر تسجيل السداد. المديونية المتبقية حاليًا لهذه الخدمة والمبنى: ',
                CONVERT(NVARCHAR(50),
                    CASE WHEN @AuditCurrentDebt > 0
                         THEN @AuditCurrentDebt
                         ELSE CONVERT(DECIMAL(38,2), 0)
                    END),
                N' ريال. يرجى تحديث بيانات التدقيق.'
            );

        THROW 50001, @AuditDebtMessage, 1;
    END;
END;


            DECLARE @InsertedAmount DECIMAL(18,2) =
                CASE WHEN @AuditDirection = 1 THEN @Amount_Decimal ELSE -@Amount_Decimal END;



         IF @AuditDirection = 1
         BEGIN
          INSERT INTO Housing.DeductList
            (
                  [deductTypeID_FK]
                 ,[DeductListStatusID_FK]
                 ,[deductName]
                 ,[amountTypeID_FK]
                 ,[paymentTypeID_FK]
                 ,[issueMonth]
                 ,[issueYear]
                 ,[paymentNo]
                 ,[paymentDate]
                 ,[description]
                 ,[deductActive]
                 ,[BillChargeTypeID_FK]
                 ,[IdaraId_FK]
                 ,[entryDate]
                 ,[entryData]
                 ,[hostName]
            )
            VALUES
            (
                 @DeductType_INT,
                 2,
                 N'سداد عن طريق صندوق الإدارة',
                 1,
                 @PaymentType,
                 MONTH(GETDATE()),
                 YEAR(GETDATE()),
                 @PaymentNo,
                 @PaymentDate,
                 @description,
                 1,
                 @BillChargeTypeID_FK,
                 @IdaraID_INT,
                 GETDATE(),
                 @entryData,
                 @hostName

            )


            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في دفع المطالبات', 1; -- برمجي/غير متوقع
            END

               set @NewID = SCOPE_IDENTITY();

             SET @Note = N'{'
                + N'"deductListID": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"deductTypeID_FK": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @DeductType_INT), '') + N'"'
                + N',"deductName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), N'سداد عن طريق صندوق الإدارة'), '') + N'"'
                + N',"amountTypeID_FK": "'  + ISNULL(CONVERT(NVARCHAR(MAX), 1), '') + N'"'
                + N',"paymentTypeID_FK": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @PaymentType), '') + N'"'
                + N',"issueMonth": "'      + ISNULL(CONVERT(NVARCHAR(MAX),  MONTH(GETDATE())), '') + N'"'
                + N',"issueYear": "'           + ISNULL(CONVERT(NVARCHAR(MAX), YEAR(GETDATE())), '') + N'"'
                + N',"paymentNo": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @PaymentNo), '') + N'"'
                + N',"paymentDate": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @PaymentDate), '') + N'"'
                + N',"description": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @description), '') + N'"'
                + N',"deductActive": "'           + ISNULL(CONVERT(NVARCHAR(MAX), 1), '') + N'"'
                + N',"BillChargeTypeID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @BillChargeTypeID_FK), '') + N'"'
                + N',"IdaraId_FK": "'                      + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                       + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                        + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[DeductList]'
                , @Action
                , @NewID
                , @entryData
                , @Note
            );


            END
            ELSE
            BEGIN

                 INSERT INTO Housing.DeductList
            (
                  [deductTypeID_FK]
                 ,[DeductListStatusID_FK]
                 ,[deductName]
                 ,[amountTypeID_FK]
                 ,[paymentTypeID_FK]
                 ,[issueMonth]
                 ,[issueYear]
                 ,[paymentNo]
                 ,[paymentDate]
                 ,[description]
                 ,[deductActive]
                 ,[BillChargeTypeID_FK]
                 ,[IdaraId_FK]
                 ,[entryDate]
                 ,[entryData]
                 ,[hostName]
            )
            VALUES
            (
                 @DeductType_INT,
                 2,
                 N'معالجة واعادة مبالغ زائدة',
                 1,
                 @PaymentType,
                 MONTH(GETDATE()),
                 YEAR(GETDATE()),
                 @PaymentNo,
                 @PaymentDate,
                 @description,
                 1,
                 @BillChargeTypeID_FK,
                 @IdaraID_INT,
                 GETDATE(),
                 @entryData,
                 @hostName

            )


            IF @@ROWCOUNT = 0
            BEGIN
                 ;THROW 50002, N'حصل خطأ في اعادة المبالغ',  1; -- برمجي/غير متوقع
            END

            set @NewID = SCOPE_IDENTITY();

             SET @Note = N'{'
                + N'"deductListID": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"deductTypeID_FK": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @DeductType_INT), '') + N'"'
                + N',"deductName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), N'معالجة واعادة مبالغ زائدة'), '') + N'"'
                + N',"amountTypeID_FK": "'  + ISNULL(CONVERT(NVARCHAR(MAX), 1), '') + N'"'
                + N',"paymentTypeID_FK": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @PaymentType), '') + N'"'
                + N',"issueMonth": "'      + ISNULL(CONVERT(NVARCHAR(MAX),  MONTH(GETDATE())), '') + N'"'
                + N',"issueYear": "'           + ISNULL(CONVERT(NVARCHAR(MAX), YEAR(GETDATE())), '') + N'"'
                + N',"paymentNo": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @PaymentNo), '') + N'"'
                + N',"paymentDate": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @PaymentDate), '') + N'"'
                + N',"description": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @description), '') + N'"'
                + N',"deductActive": "'           + ISNULL(CONVERT(NVARCHAR(MAX), 1), '') + N'"'
                + N',"BillChargeTypeID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @BillChargeTypeID_FK), '') + N'"'
                + N',"IdaraId_FK": "'                      + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                       + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                        + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[DeductList]'
                , @Action
                , @NewID
                , @entryData
                , @Note
            );

            END


               INSERT INTO [Housing].[BuildingPayment]
            (
                  [buildingPaymentTypeID_FK]
                 ,[generalNo_FK]
                 ,[IDNumber]
                 ,[residentInfoID_FK]
                 ,[unitID]
                 ,[userName]
                 ,[buildingDetailsID_FK]
                 ,[amount]
                 ,[deductListID_FK]
                 ,[buildingPayementActive]
                 ,[BillChargeTypeID_FK]
                 ,[IdaraId_FK]
                 ,[entryDate]
                 ,[entryData]
                 ,[hostName]
                 ,[buildingPaymentLinkStatusID_FK]
                 ,[paymentLinkNote]
            )
            VALUES
            (
                 @PaymentType,
                 @GeneralNo,
                 @NationalID,
                 @residentInfoID,
                 @unitID,
                 @FullName,
                 @buildingDetailsID,
                 @InsertedAmount,
                 @NewID,
                 1,
                 @BillChargeTypeID_FK,
                 @IdaraID_INT,
                 GETDATE(),
                 @entryData,
                 @hostName,
                 @AuditLinkStatus,
                 CASE WHEN @AuditLinkStatus = 2
                      THEN N'حركة رصيد عام غير مرتبطة بمبنى - التدقيق المالي العام'
                      ELSE N'حركة مرتبطة بمبنى تم إشغاله - التدقيق المالي العام' END
            )


            IF @@ROWCOUNT = 0
            BEGIN
                 ;THROW 50002, N'حصل خطأ في عملية الدفع او الاعادة - BuildingPayment',  1; -- برمجي/غير متوقع
            END

            set @NewID1 = SCOPE_IDENTITY();

             SET @Note = N'{'
                + N'"paymentID": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @NewID1), '') + N'"'
                + N',"buildingPaymentTypeID_FK": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @PaymentType), '') + N'"'
                + N',"generalNo_FK": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"IDNumber": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @NationalID), '') + N'"'
                + N',"residentInfoID_FK": "'  + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), '') + N'"'
                + N',"unitID": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @unitID), '') + N'"'
                + N',"userName": "'      + ISNULL(CONVERT(NVARCHAR(MAX),  @FullName), '') + N'"'
                + N',"buildingDetailsID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"amount": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @InsertedAmount), '') + N'"'
                + N',"deductListID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingPayementActive": "'           + ISNULL(CONVERT(NVARCHAR(MAX), 1), '') + N'"'
                + N',"BillChargeTypeID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @BillChargeTypeID_FK), '') + N'"'
                + N',"IdaraId_FK": "'                      + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                       + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                        + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingPayment]'
                , @Action
                , @NewID1
                , @entryData
                , @Note
            );



           

            SELECT 1 AS IsSuccessful, N'تم تنفيذ العملية بنجاح' AS Message_;
            RETURN;
        END



      
        ----------------------------------------------------------------
 -- FINANCIALSETTLEMENTFORUSER
 -- Transfer a real surplus to an outstanding debt WITHIN THE SAME BUILDING.
 -- Does not use WaitingList/ActionID or general/unallocated balances.
 -- Must be invoked via dbo.Masters_CRUD (permissions + outer COMMIT).
 ----------------------------------------------------------------
 ELSE IF @Action = N'FINANCIALSETTLEMENTFORUSER'
 BEGIN
     DECLARE @SetResidentID BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@residentInfoID)), N''));
     DECLARE @SetBuildingID BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@buildingDetailsID)), N''));
     DECLARE @SetFromServiceID INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@BillChargeTypeID_FK)), N''));
     DECLARE @SetToServiceID INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@ToBillChargeTypeID_FK)), N''));
     DECLARE @SetTypeID INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@PaymentType)), N''));
     DECLARE @SetPreciseAmount DECIMAL(38,18) = TRY_CONVERT(DECIMAL(38,18), NULLIF(LTRIM(RTRIM(@Amount)), N''));
     DECLARE @SetFromRemaining DECIMAL(38,2) = 0;
     DECLARE @SetToRemaining DECIMAL(38,2) = 0;
     DECLARE @SetReference NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@PaymentNo)), N'');
     DECLARE @SetDescription NVARCHAR(1500) = NULLIF(LTRIM(RTRIM(@description)), N'');
     DECLARE @SetDeductName NVARCHAR(2000);
     DECLARE @SetLockResult INT;
     DECLARE @SetLockKey NVARCHAR(255);
     DECLARE @SetFirstLockService INT;
     DECLARE @SetSecondLockService INT;
     DECLARE @SetPaymentID BIGINT;
     DECLARE @SetOperationDate DATE = CONVERT(DATE, GETDATE());

     IF @IdaraID_INT IS NULL OR @IdaraID_INT <= 0
         THROW 50001, N'الإدارة غير صحيحة', 1;

     IF @SetResidentID IS NULL OR @SetResidentID <= 0
         THROW 50001, N'المستفيد غير صحيح', 1;

     -- A NULL/-1 building means general balance and is NOT eligible here.
     IF @SetBuildingID IS NULL OR @SetBuildingID <= 0
         THROW 50001, N'التسوية المالية هنا مخصصة لمبنى محدد وليست للرصيد العام', 1;

     IF @SetFromServiceID IS NULL OR @SetToServiceID IS NULL
        OR @SetFromServiceID <= 0 OR @SetToServiceID <= 0
        OR @SetFromServiceID = @SetToServiceID
         THROW 50001, N'يجب تحديد خدمتين مختلفتين وصحيحتين للتسوية', 1;

     IF @SetTypeID IS NULL OR @SetTypeID <> 6
        OR NOT EXISTS
           (
               SELECT 1
               FROM Housing.BuildingPaymentType t
               WHERE t.buildingPaymentTypeID = 6
                 AND t.buildingPaymentTypeActive = 1
                 AND t.buildingPaymentDestainationID_FK = 1
                 AND t.deductTypeID_FK = 6
           )
         THROW 50001, N'نوع التسوية المالية غير مفعل أو غير صحيح', 1;

     IF @Amount_Decimal IS NULL OR @Amount_Decimal <= 0
        OR @Amount_Decimal >= 100000000
        OR @SetPreciseAmount IS NULL
        OR @SetPreciseAmount <> CONVERT(DECIMAL(38,18), @Amount_Decimal)
         THROW 50001, N'مبلغ التسوية غير صحيح أو يحتوي أكثر من منزلتين عشريتين', 1;

     IF @SetDescription IS NULL
         THROW 50001, N'ملاحظات التسوية مطلوبة', 1;

     IF LEN(@description) > 1500
         THROW 50001, N'ملاحظات التسوية تتجاوز 1500 حرف', 1;

     -- The request key is supplied by p13 through Masters_CRUD.
     -- Its reuse must not produce a second settlement.
     IF @SetReference IS NULL OR LEN(LTRIM(RTRIM(@PaymentNo))) > 50
         THROW 50001, N'معرف عملية التسوية مطلوب وبحد أقصى 50 حرفًا', 1;

     IF NOT EXISTS
     (
         SELECT 1
         FROM Housing.V_GetFullResidentDetails f
         WHERE f.residentInfoID = @SetResidentID
           AND f.IdaraID = @IdaraID_INT
     )
         THROW 50001, N'المستفيد لا يتبع الإدارة المصرح بها', 1;

     IF NOT EXISTS
     (
         SELECT 1
         FROM Housing.BuildingDetails b
         WHERE b.buildingDetailsID = @SetBuildingID
           AND b.IdaraId_FK = @IdaraID_INT
     )
         THROW 50001, N'المبنى لا يتبع الإدارة المصرح بها', 1;

     IF NOT EXISTS
     (
         SELECT 1
         FROM Housing.BuildingAction a
         WHERE a.residentInfoID_FK = @SetResidentID
           AND a.IdaraId_FK = @IdaraID_INT
           AND a.buildingDetailsID_FK = @SetBuildingID
           AND a.buildingActionTypeID_FK = 2
           AND a.buildingActionActive = 1
           AND a.buildingActionDate IS NOT NULL
           AND CONVERT(DATE, a.buildingActionDate) <= @SetOperationDate
     )
         THROW 50001, N'لا يوجد إشغال فعلي موثق للمستفيد في المبنى', 1;

     IF (SELECT COUNT(*)
         FROM Housing.BillChargeType c
         WHERE c.BillChargeTypeID IN (@SetFromServiceID, @SetToServiceID)
           AND c.BillChargeTypeActive = 1) <> 2
         THROW 50001, N'إحدى خدمتي التسوية غير مفعلة أو غير صحيحة', 1;

     -- Serialize both service balances. Acquire in a deterministic order
     -- to avoid deadlocks between reciprocal settlements.
     SET @SetFirstLockService = CASE WHEN @SetFromServiceID < @SetToServiceID
                                     THEN @SetFromServiceID ELSE @SetToServiceID END;
     SET @SetSecondLockService = CASE WHEN @SetFromServiceID < @SetToServiceID
                                      THEN @SetToServiceID ELSE @SetFromServiceID END;

     SET @SetLockKey = CONCAT(N'HFA|', @IdaraID_INT, N'|', @SetResidentID,
                              N'|', @SetFirstLockService, N'|', @SetBuildingID);
     EXEC @SetLockResult = sys.sp_getapplock
           @Resource = @SetLockKey, @LockMode = N'Exclusive',
           @LockOwner = N'Transaction', @LockTimeout = 10000;
     IF @SetLockResult < 0
         THROW 50001, N'تعذر حجز الرصيد للتسوية حاليًا، أعد المحاولة', 1;

     SET @SetLockKey = CONCAT(N'HFA|', @IdaraID_INT, N'|', @SetResidentID,
                              N'|', @SetSecondLockService, N'|', @SetBuildingID);
     EXEC @SetLockResult = sys.sp_getapplock
           @Resource = @SetLockKey, @LockMode = N'Exclusive',
           @LockOwner = N'Transaction', @LockTimeout = 10000;
     IF @SetLockResult < 0
         THROW 50001, N'تعذر حجز الرصيد للتسوية حاليًا، أعد المحاولة', 1;

     IF EXISTS
     (
         SELECT 1 FROM Housing.DeductList d WITH (UPDLOCK, HOLDLOCK)
         WHERE d.IdaraId_FK = @IdaraID_INT
           AND d.paymentTypeID_FK = 6
           AND d.paymentNo = @SetReference
     )
         THROW 50001, N'تم تنفيذ طلب التسوية بهذا المعرف مسبقًا', 1;

     -- Remaining = claims - payments; NEGATIVE is surplus.
     SELECT @SetFromRemaining = COALESCE(SUM(CONVERT(DECIMAL(38,2), v.Remaining)), 0)
     FROM Housing.V_SumBillsTotalPriceAndTotalPaidForResident v
     WHERE v.residentInfoID = @SetResidentID
       AND v.idaraID = @IdaraID_INT
       AND v.buildingDetailsID = @SetBuildingID
       AND v.BillChargeTypeID = @SetFromServiceID;

     SELECT @SetToRemaining = COALESCE(SUM(CONVERT(DECIMAL(38,2), v.Remaining)), 0)
     FROM Housing.V_SumBillsTotalPriceAndTotalPaidForResident v
     WHERE v.residentInfoID = @SetResidentID
       AND v.idaraID = @IdaraID_INT
       AND v.buildingDetailsID = @SetBuildingID
       AND v.BillChargeTypeID = @SetToServiceID;

     IF @SetFromRemaining >= 0 OR @Amount_Decimal > -@SetFromRemaining
         THROW 50001, N'مبلغ التسوية أكبر من فائض الخدمة المحددة داخل المبنى', 1;

     IF @SetToRemaining <= 0 OR @Amount_Decimal > @SetToRemaining
         THROW 50001, N'مبلغ التسوية أكبر من مديونية الخدمة المستهدفة داخل المبنى', 1;

     -- Load the same resident/admin identity values used by the payment branch.
     SELECT TOP (1)
         @NationalID = f.NationalID,
         @GeneralNo = f.generalNo_FK,
         @unitID = f.militaryUnitID_FK,
         @FullName = f.FullName_A
     FROM Housing.V_GetFullResidentDetails f
     WHERE f.residentInfoID = @SetResidentID
       AND f.IdaraID = @IdaraID_INT
     ORDER BY f.residentDetailsID DESC;

     declare @FromService_ nvarchar(1000),@ToService_ nvarchar(1000)

     DECLARE @SetFromServiceName NVARCHAR(1000);
DECLARE @SetToServiceName NVARCHAR(1000);

SELECT
    @SetFromServiceName =
        MAX(CASE
            WHEN BillChargeTypeID = @SetFromServiceID
            THEN BillChargeTypeName_A
        END),
    @SetToServiceName =
        MAX(CASE
            WHEN BillChargeTypeID = @SetToServiceID
            THEN BillChargeTypeName_A
        END)
FROM Housing.BillChargeType
WHERE BillChargeTypeID IN
(
    @SetFromServiceID,
    @SetToServiceID
);

IF NULLIF(LTRIM(RTRIM(@SetFromServiceName)), N'') IS NULL
   OR NULLIF(LTRIM(RTRIM(@SetToServiceName)), N'') IS NULL
BEGIN
    THROW 50001, N'تعذر تحديد أسماء خدمات التسوية المالية.', 1;
END;

SET @SetDeductName = CONCAT(
    N'تسوية مالية من ',
    @SetFromServiceName,
    N' الى ',
    @SetToServiceName
);

     INSERT INTO Housing.DeductList
     (
         deductTypeID_FK, DeductListStatusID_FK, deductName,
         amountTypeID_FK, paymentTypeID_FK, issueMonth, issueYear,
         paymentNo, paymentDate, description, deductActive,
         BillChargeTypeID_FK, ToBillChargeTypeID_FK, IdaraId_FK,
         entryDate, entryData, hostName
     )
     VALUES
     (
         6, 2, @SetDeductName,
         1, 6, MONTH(@SetOperationDate), YEAR(@SetOperationDate),
         @SetReference, @SetOperationDate, @SetDescription, 1,
         @SetFromServiceID, @SetToServiceID, @IdaraID_INT,
         GETDATE(), @entryData, @hostName
     );
     SET @NewID = CONVERT(BIGINT, SCOPE_IDENTITY());

     INSERT INTO dbo.AuditLog(TableName, ActionType, RecordID, PerformedBy, Notes)
     VALUES
     (
         N'[Housing].[DeductList]', @Action, @NewID, @entryData,
         CONCAT(N'SettlementRef=', @SetReference,
                N';Resident=', @SetResidentID,
                N';Building=', @SetBuildingID,
                N';FromService=', @SetFromServiceID,
                N';ToService=', @SetToServiceID,
                N';Amount=', CONVERT(NVARCHAR(50), @Amount_Decimal))
     );

     -- Pair of journal movements: -amount from surplus and +amount to debt.
     -- Same DeductList, resident, admin, building, settlement type, link status 1.
     INSERT INTO Housing.BuildingPayment
     (
         buildingPaymentTypeID_FK, generalNo_FK, IDNumber,
         residentInfoID_FK, unitID, userName, buildingDetailsID_FK,
         amount, deductListID_FK, buildingPayementActive,
         BillChargeTypeID_FK, IdaraId_FK,
         entryDate, entryData, hostName,
         buildingPaymentLinkStatusID_FK, paymentLinkNote
     )
     VALUES
     (
         6, @GeneralNo, @NationalID,
         @SetResidentID, @unitID, @FullName, CONVERT(NVARCHAR(30), @SetBuildingID),
         -@Amount_Decimal, @NewID, 1,
         @SetFromServiceID, @IdaraID_INT,
         GETDATE(), @entryData, @hostName,
         1, N'تسوية داخل المبنى: خصم من فائض الخدمة'
     );
     SET @SetPaymentID = CONVERT(BIGINT, SCOPE_IDENTITY());

     INSERT INTO dbo.AuditLog(TableName, ActionType, RecordID, PerformedBy, Notes)
     VALUES
     (
         N'[Housing].[BuildingPayment]', @Action, @SetPaymentID, @entryData,
         CONCAT(N'SettlementRef=', @SetReference, N';DeductListID=', @NewID,
                N';Role=SOURCE;Amount=', CONVERT(NVARCHAR(50), -@Amount_Decimal))
     );

     INSERT INTO Housing.BuildingPayment
     (
         buildingPaymentTypeID_FK, generalNo_FK, IDNumber,
         residentInfoID_FK, unitID, userName, buildingDetailsID_FK,
         amount, deductListID_FK, buildingPayementActive,
         BillChargeTypeID_FK, IdaraId_FK,
         entryDate, entryData, hostName,
         buildingPaymentLinkStatusID_FK, paymentLinkNote
     )
     VALUES
     (
         6, @GeneralNo, @NationalID,
         @SetResidentID, @unitID, @FullName, CONVERT(NVARCHAR(30), @SetBuildingID),
         @Amount_Decimal, @NewID, 1,
         @SetToServiceID, @IdaraID_INT,
         GETDATE(), @entryData, @hostName,
         1, N'تسوية داخل المبنى: إضافة لسداد مديونية الخدمة'
     );
     SET @SetPaymentID = CONVERT(BIGINT, SCOPE_IDENTITY());

     INSERT INTO dbo.AuditLog(TableName, ActionType, RecordID, PerformedBy, Notes)
     VALUES
     (
         N'[Housing].[BuildingPayment]', @Action, @SetPaymentID, @entryData,
         CONCAT(N'SettlementRef=', @SetReference, N';DeductListID=', @NewID,
                N';Role=TARGET;Amount=', CONVERT(NVARCHAR(50), @Amount_Decimal))
     );

     SELECT 1 AS IsSuccessful, N'تم تنفيذ التسوية المالية بنجاح' AS Message_;
     RETURN;
 END



 
 ELSE IF @Action = N'INSERTGENERALBALANCEREFUND'
BEGIN
    DECLARE @GBResidentID BIGINT =
        TRY_CONVERT(BIGINT, @residentInfoID);

    DECLARE @GBServiceID INT =
        TRY_CONVERT(INT, @BillChargeTypeID_FK);

    DECLARE @GBRefundDate DATE =
        TRY_CONVERT(DATE, @PaymentDate);

    DECLARE @GBReference NVARCHAR(200) =
        NULLIF(LTRIM(RTRIM(@PaymentNo)), N'');

    DECLARE @GBRequestKey UNIQUEIDENTIFIER =
        TRY_CONVERT(UNIQUEIDENTIFIER, @GeneralRequestKey);

    DECLARE @GBPreciseAmount DECIMAL(38,18) =
        TRY_CONVERT(DECIMAL(38,18), @Amount);

    DECLARE @GBFirstOccupancy DATE;
    DECLARE @GBPositive DECIMAL(38,2) = 0;
    DECLARE @GBOldRefunds DECIMAL(38,2) = 0;
    DECLARE @GBNewRefunds DECIMAL(38,2) = 0;
    DECLARE @GBAllocated DECIMAL(38,2) = 0;
    DECLARE @GBBuildingAllocated DECIMAL(38,2) = 0;
    DECLARE @GBRefundID BIGINT;
    DECLARE @GBDeductID INT;
    DECLARE @GBLedgerID BIGINT;
    DECLARE @GBLockResult INT;
    DECLARE @GBLockResource NVARCHAR(255);

    IF @GBResidentID IS NULL OR @GBResidentID <= 0
       OR @GBServiceID IS NULL OR @GBServiceID <= 0
       OR @GeneralPaymentID IS NULL OR @GeneralPaymentID <= 0
       OR @IdaraID_INT IS NULL OR @IdaraID_INT <= 0
        THROW 50001, N'بيانات السداد أو المستفيد غير صحيحة', 1;

    IF @Amount_Decimal IS NULL OR @GBPreciseAmount IS NULL
    THROW 50001, N'قيمة مبلغ الإعادة غير صحيحة', 1;

IF @GBPreciseAmount <= 0
    THROW 50001, N'يجب إدخال مبلغ إعادة أكبر من صفر', 1;

IF @GBPreciseAmount <> CONVERT(DECIMAL(38,18), @Amount_Decimal)
    THROW 50001, N'يجب إدخال المبلغ بالريال والهللة دون أجزاء أصغر من هللة', 1;

    IF @GBRefundDate IS NULL
       OR @GBRefundDate > CONVERT(DATE, GETDATE())
        THROW 50001, N'تاريخ الإعادة غير صحيح', 1;

    IF @GBReference IS NULL
       OR LEN(LTRIM(RTRIM(@PaymentNo))) > 200
       OR NULLIF(LTRIM(RTRIM(@description)), N'') IS NULL
       OR @GBRequestKey IS NULL
        THROW 50001, N'بيانات مستند الإعادة غير مكتملة', 1;

    -- DeductList.paymentNo = NVARCHAR(50), BuildingPayment.amount = DECIMAL(10,2),
    -- DeductList.description = NVARCHAR(1500). Do not silently truncate.
    IF LEN(@GBReference) > 50
        THROW 50001, N'رقم مستند الإعادة يتجاوز 50 حرفًا ولا يمكن ترحيله ماليًا', 1;

    IF LEN(@description) > 1500
        THROW 50001, N'تفاصيل الإعادة تتجاوز 1500 حرف ولا يمكن ترحيلها ماليًا', 1;

    IF @Amount_Decimal > 99999999.99
        THROW 50001, N'مبلغ الإعادة يتجاوز سعة سجل الحركة المالية', 1;

    IF NULLIF(LTRIM(RTRIM(@entryData)), N'') IS NULL
        THROW 50001, N'بيانات المستخدم غير مكتملة', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.V_GetFullResidentDetails r
        WHERE r.residentInfoID = @GBResidentID
          AND r.IdaraID = @IdaraID_INT
    )
        THROW 50001, N'المستفيد خارج نطاق الإدارة', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.billPaymentType t
        WHERE t.billPaymentTypeID = 4
          AND t.billPaymentDestainationID_FK = 2
          AND t.billPaymentTypeActive = 1
    )
        THROW 50001, N'نوع إعادة المبالغ غير متاح', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.BuildingPaymentType t
        WHERE t.buildingPaymentTypeID = 4
          AND t.buildingPaymentDestainationID_FK = 2
          AND t.deductTypeID_FK = 4
          AND t.buildingPaymentTypeActive = 1
    )
        THROW 50001, N'نوع حركة الإعادة المحاسبية غير متاح', 1;

    -- نفس القفل المحاسبي المستخدم في النظام السابق.
    SET @GBLockResource =
        N'HUPR|' + CONVERT(NVARCHAR(20), @IdaraID_INT)
        + N'|' + CONVERT(NVARCHAR(30), @GBResidentID)
        + N'|' + CONVERT(NVARCHAR(20), @GBServiceID);

    EXEC @GBLockResult = sys.sp_getapplock
        @Resource = @GBLockResource,
        @LockMode = N'Exclusive',
        @LockOwner = N'Transaction',
        @LockTimeout = 10000;

    IF @GBLockResult < 0
        THROW 50001, N'تعذر حجز الرصيد المالي', 1;

    IF EXISTS
    (
        SELECT 1
        FROM Housing.UnallocatedPaymentRefund
        WHERE RequestKey = @GBRequestKey
    )
        THROW 50001, N'تم تسجيل طلب الإعادة مسبقًا', 1;

    IF EXISTS
    (
        SELECT 1
        FROM Housing.UnallocatedPaymentRefund
        WHERE ResidentInfoID_FK = @GBResidentID
          AND BillChargeTypeID_FK = @GBServiceID
          AND IdaraId_FK = @IdaraID_INT
          AND RefundStatus = 1
          AND RefundReferenceNormalized =
              UPPER(LTRIM(RTRIM(@GBReference)))
    )
        THROW 50001, N'رقم مستند الإعادة مستخدم مسبقًا', 1;

    IF EXISTS
    (
        SELECT 1
        FROM Housing.BuildingPayment p
        INNER JOIN Housing.DeductList d
            ON d.deductListID = p.deductListID_FK
        WHERE p.residentInfoID_FK = @GBResidentID
          AND p.BillChargeTypeID_FK = @GBServiceID
          AND p.IdaraId_FK = @IdaraID_INT
          AND p.buildingPaymentLinkStatusID_FK = 2
          AND p.buildingPayementActive = 1
          AND d.deductActive = 1
          AND p.amount < 0
          AND UPPER(LTRIM(RTRIM(d.paymentNo))) =
              UPPER(LTRIM(RTRIM(@GBReference)))
    )
        THROW 50001, N'رقم المستند موجود في الإعادات التاريخية', 1;

    SELECT @GBFirstOccupancy =
        MIN(CONVERT(DATE, buildingActionDate))
    FROM Housing.BuildingAction
    WHERE residentInfoID_FK = @GBResidentID
      AND buildingActionTypeID_FK = 2
      AND buildingActionActive = 1
      AND buildingActionDate IS NOT NULL;

    IF @GBFirstOccupancy IS NULL
        THROW 50001, N'لا يوجد إشغال موثق للمستفيد', 1;

    IF @GBRefundDate < @GBFirstOccupancy
        THROW 50001, N'تاريخ الإعادة يسبق أول إشغال', 1;

    -- الفترات الهجرية المكتملة والموثوقة.
    SELECT
        g.yearH,
        g.monthH,
        MIN(CONVERT(DATE, g.gregorianDate)) AS PeriodStart,
        MAX(CONVERT(DATE, g.gregorianDate)) AS PeriodEnd
    INTO #GBHijriMonths
    FROM dbo._GregorianHijriDate g
    WHERE g.yearH BETWEEN 1400 AND 1499
    GROUP BY g.yearH, g.monthH
    HAVING COUNT(*) BETWEEN 29 AND 30
       AND COUNT(DISTINCT g.dayH) = COUNT(*)
       AND MIN(g.dayH) = 1
       AND MAX(g.dayH) = COUNT(*)
       AND COUNT(DISTINCT CONVERT(DATE, g.gregorianDate)) = COUNT(*)
       AND DATEDIFF(
           DAY,
           MIN(CONVERT(DATE, g.gregorianDate)),
           MAX(CONVERT(DATE, g.gregorianDate))
       ) + 1 = COUNT(*);

    -- الحركات العامة المؤهلة فقط.
    SELECT
        p.paymentID,
        CONVERT(DECIMAL(38,2), p.amount) AS Amount,
        dates.ReferenceDate
    INTO #GBMovements
    FROM Housing.BuildingPayment p WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN Housing.DeductList d
        ON d.deductListID = p.deductListID_FK
    LEFT JOIN #GBHijriMonths h
        ON h.yearH = d.issueYear
       AND h.monthH = d.issueMonth
    CROSS APPLY
    (
        SELECT
            CASE
                WHEN d.issueYear BETWEEN 1400 AND 1499
                    THEN h.PeriodStart
                WHEN d.issueYear BETWEEN 1900 AND 9999
                 AND d.issueMonth BETWEEN 1 AND 12
                    THEN TRY_CONVERT(DATE, CONCAT(
                        d.issueYear, N'-',
                        RIGHT(N'0' + CONVERT(
                            NVARCHAR(2), d.issueMonth), 2),
                        N'-01'))
                ELSE TRY_CONVERT(DATE, d.paymentDate)
            END AS ReferenceDate,
            CASE
                WHEN d.issueYear BETWEEN 1400 AND 1499
                    THEN h.PeriodEnd
                WHEN d.issueYear BETWEEN 1900 AND 9999
                 AND d.issueMonth BETWEEN 1 AND 12
                    THEN EOMONTH(TRY_CONVERT(DATE, CONCAT(
                        d.issueYear, N'-',
                        RIGHT(N'0' + CONVERT(
                            NVARCHAR(2), d.issueMonth), 2),
                        N'-01')))
                ELSE TRY_CONVERT(DATE, d.paymentDate)
            END AS PeriodEnd
    ) dates
    WHERE p.residentInfoID_FK = @GBResidentID
      AND p.BillChargeTypeID_FK = @GBServiceID
      AND p.IdaraId_FK = @IdaraID_INT
      AND p.buildingPaymentLinkStatusID_FK = 2
      AND p.buildingPayementActive = 1
      AND d.deductActive = 1
      -- Exclude new refund ledger movements: already counted in @GBNewRefunds.
      AND p.UnallocatedRefundID_FK IS NULL
      AND (
          p.buildingPaymentTypeID_FK IS NULL
          OR p.buildingPaymentTypeID_FK <> 7
      )
      AND NULLIF(LTRIM(RTRIM(
          p.buildingDetailsID_FK)), N'') IS NULL
      AND dates.PeriodEnd >= @GBFirstOccupancy;

    SELECT
        @GBPositive = ISNULL(SUM(
            CASE WHEN Amount > 0 THEN Amount ELSE 0 END), 0),
        @GBOldRefunds = ISNULL(SUM(
            CASE WHEN Amount < 0 THEN -Amount ELSE 0 END), 0)
    FROM #GBMovements;

    SELECT @GBNewRefunds =
        ISNULL(SUM(CONVERT(DECIMAL(38,2), RefundAmount)), 0)
    FROM Housing.UnallocatedPaymentRefund WITH (UPDLOCK, HOLDLOCK)
    WHERE ResidentInfoID_FK = @GBResidentID
      AND BillChargeTypeID_FK = @GBServiceID
      AND IdaraId_FK = @IdaraID_INT
      AND RefundStatus = 1;

    SELECT @GBAllocated =
        ISNULL(SUM(CONVERT(DECIMAL(38,2), rd.AllocatedAmount)), 0)
    FROM Housing.UnallocatedPaymentRefundDetail rd
    INNER JOIN Housing.UnallocatedPaymentRefund r
        ON r.RefundID = rd.RefundID_FK
    WHERE r.ResidentInfoID_FK = @GBResidentID
      AND r.BillChargeTypeID_FK = @GBServiceID
      AND r.IdaraId_FK = @IdaraID_INT
      AND r.RefundStatus = 1;

    IF @GBAllocated <> @GBNewRefunds
    THROW 50001, N'تعارض بين الاستردادات وتفاصيلها', 1;

    -- التخصيصات المؤكدة للمباني
    SELECT
        @GBBuildingAllocated =
            ISNULL(
                SUM(CONVERT(DECIMAL(38,2), a.AllocatedAmount)),
                0
            )
    FROM Housing.GeneralBalanceBuildingAllocation a
        WITH (UPDLOCK, HOLDLOCK)
    WHERE a.ResidentInfoID_FK = @GBResidentID
      AND a.BillChargeTypeID_FK = @GBServiceID
      AND a.IdaraID_FK = @IdaraID_INT
      AND a.AllocationStatus = 1;
    
    -- الإجمالي المتاح بعد الإعادات والربط بالمباني
    IF @GBPositive
       - @GBOldRefunds
       - @GBNewRefunds
       - @GBBuildingAllocated < @Amount_Decimal
        THROW 50001, N'الرصيد العام المؤهل غير كافٍ', 1;

    -- توزيع الإعادات التاريخية FIFO،
    -- ثم خصم الإعادات الجديدة المرتبطة بالسداد نفسه.
    ;WITH OrderedPayments AS
    (
        SELECT
            paymentID,
            Amount,
            ReferenceDate,
            SUM(Amount) OVER
            (
                ORDER BY ReferenceDate, paymentID
                ROWS UNBOUNDED PRECEDING
            ) AS RunningGross
        FROM #GBMovements
        WHERE Amount > 0
    ),
    LegacyAllocation AS
    (
        SELECT
            o.paymentID,
            o.Amount,
            CASE
                WHEN @GBOldRefunds <= o.RunningGross - o.Amount
                    THEN CONVERT(DECIMAL(38,2), 0)
                WHEN @GBOldRefunds >= o.RunningGross
                    THEN o.Amount
                ELSE @GBOldRefunds - (o.RunningGross - o.Amount)
            END AS LegacyUsed
        FROM OrderedPayments o
    ),
    ExistingAllocations AS
    (
        SELECT
            rd.PaymentID_FK,
            SUM(CONVERT(DECIMAL(38,2),
                rd.AllocatedAmount)) AS UsedAmount
        FROM Housing.UnallocatedPaymentRefundDetail rd
        INNER JOIN Housing.UnallocatedPaymentRefund r
            ON r.RefundID = rd.RefundID_FK
        WHERE r.ResidentInfoID_FK = @GBResidentID
          AND r.BillChargeTypeID_FK = @GBServiceID
          AND r.IdaraId_FK = @IdaraID_INT
          AND r.RefundStatus = 1
        GROUP BY rd.PaymentID_FK
    )
    ,
ExistingBuildingAllocations AS
(
    SELECT
        a.SourcePaymentID_FK,
        SUM(CONVERT(
            DECIMAL(38,2),
            a.AllocatedAmount
        )) AS UsedAmount
    FROM Housing.GeneralBalanceBuildingAllocation a
    WHERE a.ResidentInfoID_FK = @GBResidentID
      AND a.BillChargeTypeID_FK = @GBServiceID
      AND a.IdaraID_FK = @IdaraID_INT
      AND a.AllocationStatus = 1
    GROUP BY a.SourcePaymentID_FK
)
    SELECT
    l.paymentID,

    l.Amount
      - l.LegacyUsed
      - ISNULL(a.UsedAmount, 0)
      - ISNULL(b.UsedAmount, 0) AS FreeAmount

INTO #GBSlots

FROM LegacyAllocation l

LEFT JOIN ExistingAllocations a
    ON a.PaymentID_FK = l.paymentID

LEFT JOIN ExistingBuildingAllocations b
    ON b.SourcePaymentID_FK = l.paymentID;

    IF EXISTS
    (
        SELECT 1
        FROM #GBSlots
        WHERE FreeAmount < 0
    )
        THROW 50001, N'تعارض في تخصيص المبالغ السابقة', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM #GBSlots
        WHERE paymentID = @GeneralPaymentID
          AND FreeAmount >= @Amount_Decimal
    )
        THROW 50001, N'المبلغ المطلوب يتجاوز المتاح للسداد المحدد', 1;

    INSERT INTO Housing.UnallocatedPaymentRefund
    (
        ResidentInfoID_FK,
        BillChargeTypeID_FK,
        IdaraId_FK,
        BillPaymentTypeID_FK,
        RefundAmount,
        RefundDate,
        RefundReference,
        RefundDetails,
        RequestKey,
        RefundStatus,
        EntryDate,
        EntryData,
        HostName
    )
    VALUES
    (
        @GBResidentID,
        @GBServiceID,
        @IdaraID_INT,
        4,
        @Amount_Decimal,
        @GBRefundDate,
        @GBReference,
        @description,
        @GBRequestKey,
        1,
        SYSDATETIME(),
        @entryData,
        @hostName
    );

    SET @GBRefundID = SCOPE_IDENTITY();

    IF @GBRefundID IS NULL OR @GBRefundID <= 0
        THROW 50002, N'تعذر إنشاء سجل الإعادة', 1;

    INSERT INTO Housing.UnallocatedPaymentRefundDetail
    (
        RefundID_FK,
        PaymentID_FK,
        AllocatedAmount
    )
    VALUES
    (
        @GBRefundID,
        @GeneralPaymentID,
        @Amount_Decimal
    );

    IF @@ROWCOUNT <> 1
        THROW 50002, N'تعذر حفظ ربط الإعادة بالسداد', 1;

    -- One financial document and one signed accounting movement per RefundID.
    -- This must stay in the existing Masters_CRUD-owned transaction.
    INSERT INTO Housing.DeductList
    (
        deductTypeID_FK,
        DeductListStatusID_FK,
        deductName,
        amountTypeID_FK,
        paymentTypeID_FK,
        issueMonth,
        issueYear,
        paymentNo,
        paymentDate,
        description,
        deductActive,
        BillChargeTypeID_FK,
        IdaraId_FK,
        entryDate,
        entryData,
        hostName
    )
    VALUES
    (
        4,
        2,
        N'إعادة مبلغ من الرصيد العام',
        1,
        4,
        MONTH(@GBRefundDate),
        YEAR(@GBRefundDate),
        @GBReference,
        @GBRefundDate,
        @description,
        1,
        @GBServiceID,
        @IdaraID_INT,
        GETDATE(),
        @entryData,
        @hostName
    );

    IF @@ROWCOUNT <> 1
        THROW 50002, N'تعذر إنشاء مستند الإعادة المالي', 1;

    SET @GBDeductID = CONVERT(INT, SCOPE_IDENTITY());

    IF @GBDeductID IS NULL OR @GBDeductID <= 0
        THROW 50002, N'تعذر تحديد مستند الإعادة المالي', 1;

    -- Copy beneficiary metadata from the proven eligible source payment.
    -- No building is assigned: this is a status-2 general-balance refund.
    INSERT INTO Housing.BuildingPayment
    (
        buildingPaymentTypeID_FK,
        generalNo_FK,
        IDNumber,
        residentInfoID_FK,
        rankNameA,
        unitID,
        userName,
        buildingDetailsID_FK,
        amount,
        deductListID_FK,
        buildingPayementActive,
        BillChargeTypeID_FK,
        IdaraId_FK,
        entryDate,
        entryData,
        hostName,
        buildingPaymentLinkStatusID_FK,
        paymentLinkNote,
        UnallocatedRefundID_FK
    )
    SELECT
        4,
        p.generalNo_FK,
        p.IDNumber,
        @GBResidentID,
        p.rankNameA,
        p.unitID,
        p.userName,
        NULL,
        CONVERT(DECIMAL(10,2), -@Amount_Decimal),
        @GBDeductID,
        1,
        @GBServiceID,
        @IdaraID_INT,
        GETDATE(),
        @entryData,
        @hostName,
        2,
        CONCAT(N'إعادة رصيد عام؛ RefundID=', @GBRefundID,
               N'؛ OriginalPaymentID=', @GeneralPaymentID),
        @GBRefundID
    FROM Housing.BuildingPayment p
    WHERE p.paymentID = @GeneralPaymentID
      AND p.residentInfoID_FK = @GBResidentID
      AND p.BillChargeTypeID_FK = @GBServiceID
      AND p.IdaraId_FK = @IdaraID_INT
      AND p.buildingPaymentLinkStatusID_FK = 2
      AND p.buildingPayementActive = 1
      AND p.amount > 0
      AND NULLIF(LTRIM(RTRIM(p.buildingDetailsID_FK)), N'') IS NULL;

    IF @@ROWCOUNT <> 1
        THROW 50002, N'تعذر إنشاء الحركة المالية المرتبطة بالسداد', 1;

    SET @GBLedgerID = CONVERT(BIGINT, SCOPE_IDENTITY());

    IF @GBLedgerID IS NULL OR @GBLedgerID <= 0
        THROW 50002, N'تعذر تحديد رقم الحركة المالية', 1;

    -- Proven links; unique filtered index prevents duplicate refund movements.
    -- On cancellation, BOTH ledger row and DeductList row must be deactivated
    -- atomically with RefundStatus=2 (separate procedure change).

    INSERT INTO dbo.AuditLog
    (
        TableName,
        ActionType,
        RecordID,
        PerformedBy,
        Notes
    )
    VALUES
    (
        N'[Housing].[UnallocatedPaymentRefund],[Housing].[UnallocatedPaymentRefundDetail],'
        + N'[Housing].[DeductList],[Housing].[BuildingPayment]',
        @Action,
        @GBRefundID,
        @entryData,
        CONCAT(
            N'ResidentID=', @GBResidentID,
            N'; SourcePaymentID=', @GeneralPaymentID,
            N'; ServiceID=', @GBServiceID,
            N'; Amount=', @Amount_Decimal,
            N'; DeductListID=', @GBDeductID,
            N'; LedgerPaymentID=', @GBLedgerID
        )
    );

    IF @tc = 0
        COMMIT TRANSACTION;

    SELECT
        1 AS IsSuccessful,
        N'تم تسجيل إعادة المبلغ وربطها بالسداد بنجاح' AS Message_;

    RETURN;
END


ELSE IF @Action = N'CANCELGENERALBALANCEREFUND'
BEGIN
    DECLARE @CRID BIGINT = @ActionID;
    DECLARE @CReason NVARCHAR(MAX) =
        NULLIF(LTRIM(RTRIM(@description)), N'');

    DECLARE @CResident BIGINT;
    DECLARE @CService INT;
    DECLARE @CStatus TINYINT;
    DECLARE @CAmount DECIMAL(18,2);
    DECLARE @CAllocated DECIMAL(38,2);

    DECLARE @CLedgerID BIGINT;
    DECLARE @CLedgerAmount DECIMAL(10,2);
    DECLARE @CDeductID INT;
    DECLARE @CLedgerActive BIT;
    DECLARE @CDeductActive BIT;
    DECLARE @CLedgerType INT;
    DECLARE @CLinkStatus INT;
    DECLARE @CBuilding NVARCHAR(200);
    DECLARE @CDeductType INT;
    DECLARE @CPaymentType INT;

    DECLARE @CLock INT;
    DECLARE @CLockKey NVARCHAR(255);

    IF @CRID IS NULL OR @CRID <= 0
        THROW 50001, N'رقم الإعادة غير صحيح', 1;

    IF @IdaraID_INT IS NULL OR @IdaraID_INT <= 0
        THROW 50001, N'الإدارة غير صحيحة', 1;

    IF @CReason IS NULL OR LEN(@CReason) > 1000
        THROW 50001, N'سبب الإلغاء مطلوب وبحد أقصى 1000 حرف', 1;

    IF NULLIF(LTRIM(RTRIM(@entryData)), N'') IS NULL
        THROW 50001, N'بيانات المستخدم غير مكتملة', 1;

    SELECT
        @CResident = r.ResidentInfoID_FK,
        @CService = r.BillChargeTypeID_FK
    FROM Housing.UnallocatedPaymentRefund r
    WHERE r.RefundID = @CRID
      AND r.IdaraId_FK = @IdaraID_INT;

    IF @CResident IS NULL OR @CService IS NULL
        THROW 50001, N'الإعادة خارج نطاق الإدارة', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.V_GetFullResidentDetails r
        WHERE r.residentInfoID = @CResident
          AND r.IdaraID = @IdaraID_INT
    )
        THROW 50001, N'المستفيد خارج نطاق الإدارة', 1;

    -- نفس قفل تسجيل الإعادة
    SET @CLockKey =
        CONCAT(N'HUPR|', @IdaraID_INT,
               N'|', @CResident,
               N'|', @CService);

    EXEC @CLock = sys.sp_getapplock
        @Resource = @CLockKey,
        @LockMode = N'Exclusive',
        @LockOwner = N'Transaction',
        @LockTimeout = 10000;

    IF @CLock < 0
        THROW 50001, N'تعذر حجز السجل حاليًا', 1;

    SELECT
        @CStatus = r.RefundStatus,
        @CAmount = r.RefundAmount
    FROM Housing.UnallocatedPaymentRefund r
        WITH (UPDLOCK, HOLDLOCK)
    WHERE r.RefundID = @CRID
      AND r.ResidentInfoID_FK = @CResident
      AND r.BillChargeTypeID_FK = @CService
      AND r.IdaraId_FK = @IdaraID_INT;

    IF @CStatus IS NULL
        THROW 50001, N'سجل الإعادة غير موجود', 1;

    IF @CStatus <> 1
        THROW 50001, N'العملية ملغاة أو غير قابلة للإلغاء', 1;

    SELECT @CAllocated =
        ISNULL(SUM(CONVERT(DECIMAL(38,2), d.AllocatedAmount)), 0)
    FROM Housing.UnallocatedPaymentRefundDetail d
    WHERE d.RefundID_FK = @CRID;

    IF @CAllocated <> @CAmount
        THROW 50001, N'تفاصيل الإعادة غير متطابقة', 1;

    SELECT
        @CLedgerID = p.paymentID,
        @CLedgerAmount = p.amount,
        @CDeductID = p.deductListID_FK,
        @CLedgerActive = p.buildingPayementActive,
        @CDeductActive = d.deductActive,
        @CLedgerType = p.buildingPaymentTypeID_FK,
        @CLinkStatus = p.buildingPaymentLinkStatusID_FK,
        @CBuilding = p.buildingDetailsID_FK,
        @CDeductType = d.deductTypeID_FK,
        @CPaymentType = d.paymentTypeID_FK
    FROM Housing.BuildingPayment p
        WITH (UPDLOCK, HOLDLOCK)
    LEFT JOIN Housing.DeductList d
        ON d.deductListID = p.deductListID_FK
    WHERE p.UnallocatedRefundID_FK = @CRID
      AND p.residentInfoID_FK = @CResident
      AND p.BillChargeTypeID_FK = @CService
      AND p.IdaraId_FK = @IdaraID_INT;

    IF @CLedgerID IS NULL
       OR @CDeductID IS NULL
       OR @CLedgerAmount IS NULL
       OR @CLedgerAmount <> -@CAmount
       OR ISNULL(@CLedgerActive, 0) <> 1
       OR ISNULL(@CDeductActive, 0) <> 1
       OR ISNULL(@CLedgerType, 0) <> 4
       OR ISNULL(@CLinkStatus, 0) <> 2
       OR @CBuilding IS NOT NULL
       OR ISNULL(@CDeductType, 0) <> 4
       OR ISNULL(@CPaymentType, 0) <> 4
        THROW 50001, N'الحركة المالية غير متطابقة؛ لا يمكن إلغاؤها', 1;

    -- لا نعطل مستندًا مرتبطًا بحركات مالية أخرى
    IF EXISTS
    (
        SELECT 1
        FROM Housing.BuildingPayment p
        WHERE p.deductListID_FK = @CDeductID
          AND p.paymentID <> @CLedgerID
    )
        THROW 50001, N'المستند مرتبط بحركات مالية أخرى', 1;

    UPDATE Housing.BuildingPayment
    SET buildingPayementActive = 0
    WHERE paymentID = @CLedgerID
      AND UnallocatedRefundID_FK = @CRID
      AND buildingPayementActive = 1;

    IF @@ROWCOUNT <> 1
        THROW 50001, N'تعذر تعطيل الحركة المالية', 1;

    UPDATE Housing.DeductList
    SET deductActive = 0
    WHERE deductListID = @CDeductID
      AND deductActive = 1;

    IF @@ROWCOUNT <> 1
        THROW 50001, N'تعذر تعطيل مستند الإعادة', 1;

    UPDATE Housing.UnallocatedPaymentRefund
    SET RefundStatus = 2,
        CancellationReason = @CReason,
        CancellationDate = SYSDATETIME(),
        CancellationEntryData = @entryData
    WHERE RefundID = @CRID
      AND RefundStatus = 1
      AND IdaraId_FK = @IdaraID_INT;

    IF @@ROWCOUNT <> 1
        THROW 50001, N'تعذر إلغاء سجل الإعادة', 1;

    INSERT INTO dbo.AuditLog
    (
        TableName, ActionType, RecordID,
        PerformedBy, Notes
    )
    VALUES
    (
        N'[Housing].[UnallocatedPaymentRefund],'
        + N'[Housing].[BuildingPayment],[Housing].[DeductList]',
        @Action,
        @CRID,
        @entryData,
        CONCAT(
            N'RefundID=', @CRID,
            N'; LedgerPaymentID=', @CLedgerID,
            N'; DeductListID=', @CDeductID,
            N'; Amount=', @CAmount,
            N'; Reason=', @CReason
        )
    );

    IF @tc = 0
        COMMIT TRANSACTION;

    SELECT
        1 AS IsSuccessful,
        N'تم إلغاء الإعادة وأثرها المالي بنجاح' AS Message_;

    RETURN;
END

      -- أضف هذا الفرع داخل TRY في Housing.FinancialAuditForUserSP
-- بعد END الخاص بفرع CANCELGENERALBALANCEREFUND وقبل ELSE الأخير للعملية غير المعروفة.
-- يتطلب تحديث احتساب الرصيد في INSERTGENERALBALANCEREFUND وMasters_ExtraDataLoad
-- وإضافة مسار الصلاحية في Masters_CRUD قبل تفعيل نوع الحركة 7.

ELSE IF @Action = N'LINKGENERALBALANCETOBUILDING'
BEGIN
    DECLARE @LBResidentID BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@residentInfoID)), N''));
    DECLARE @LBServiceID INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@BillChargeTypeID_FK)), N''));
    DECLARE @LBSourceID BIGINT = @GeneralPaymentID;
    DECLARE @LBTargetID BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@buildingDetailsID)), N''));
    DECLARE @LBRequestKey UNIQUEIDENTIFIER = TRY_CONVERT(UNIQUEIDENTIFIER, @GeneralRequestKey);
    DECLARE @LBDate DATE = TRY_CONVERT(DATE, @PaymentDate);
    DECLARE @LBReference NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@PaymentNo)), N'');
    DECLARE @LBDetails NVARCHAR(4000) = NULLIF(LTRIM(RTRIM(@description)), N'');
    DECLARE @LBPreciseAmount DECIMAL(38,18) = TRY_CONVERT(DECIMAL(38,18), @Amount);
    DECLARE @LBFirstOccupancy DATE;
    DECLARE @LBPositive DECIMAL(38,2) = 0;
    DECLARE @LBOldRefunds DECIMAL(38,2) = 0;
    DECLARE @LBNewRefunds DECIMAL(38,2) = 0;
    DECLARE @LBRefundDetails DECIMAL(38,2) = 0;
    DECLARE @LBTransfers DECIMAL(38,2) = 0;
    DECLARE @LBSourceFree DECIMAL(38,2);
    DECLARE @LBLockName NVARCHAR(255);
    DECLARE @LBLockResult INT;
    DECLARE @LBDeductID INT;
    DECLARE @LBSourceMovementID BIGINT;
    DECLARE @LBTargetMovementID BIGINT;
    DECLARE @LBAllocationID BIGINT;
    DECLARE @LBGeneralNo BIGINT;
    DECLARE @LBIDNumber NVARCHAR(10);
    DECLARE @LBRankName NVARCHAR(50);
    DECLARE @LBUnitID NVARCHAR(50);
    DECLARE @LBUserName NVARCHAR(500);

    IF @LBResidentID IS NULL OR @LBResidentID <= 0
       OR @LBServiceID IS NULL OR @LBServiceID <= 0
       OR @LBSourceID IS NULL OR @LBSourceID <= 0
       OR @LBTargetID IS NULL OR @LBTargetID <= 0
       OR @IdaraID_INT IS NULL OR @IdaraID_INT <= 0
        THROW 50001, N'بيانات المستفيد أو السداد أو المبنى غير صحيحة', 1;

    IF @Amount_Decimal IS NULL OR @LBPreciseAmount IS NULL
       OR @LBPreciseAmount <= 0
       OR @LBPreciseAmount <> CONVERT(DECIMAL(38,18), @Amount_Decimal)
        THROW 50001, N'أدخل مبلغ تحويل موجبًا بالريال والهللة فقط', 1;

    -- Housing.BuildingPayment.amount = DECIMAL(10,2).
    IF @Amount_Decimal > 99999999.99
        THROW 50001, N'مبلغ التحويل يتجاوز سعة الحركة المحاسبية', 1;

    IF @LBDate IS NULL OR @LBDate > CONVERT(DATE, GETDATE())
        THROW 50001, N'تاريخ التحويل غير صحيح', 1;

    IF @LBReference IS NULL OR LEN(@LBReference) > 50
       OR @LBDetails IS NULL OR LEN(@LBDetails) > 1000
       OR @LBRequestKey IS NULL
       OR NULLIF(LTRIM(RTRIM(@entryData)), N'') IS NULL
        THROW 50001, N'مرجع التحويل أو تفاصيله أو بيانات الطلب غير مكتملة', 1;

    IF NOT EXISTS (
        SELECT 1 FROM Housing.V_GetFullResidentDetails r
        WHERE r.residentInfoID = @LBResidentID
          AND r.IdaraID = @IdaraID_INT
    )
        THROW 50001, N'المستفيد خارج نطاق الإدارة', 1;

    IF NOT EXISTS (
        SELECT 1 FROM Housing.BuildingDetails b WITH (UPDLOCK, HOLDLOCK)
        WHERE b.buildingDetailsID = @LBTargetID
          AND b.IdaraId_FK = @IdaraID_INT
          AND b.buildingDetailsActive = 1
    )
        THROW 50001, N'المبنى غير نشط أو خارج نطاق الإدارة', 1;

    -- يجب أن تكون هناك علاقة إشغال حقيقية موثقة بالمبنى المقصود.
    IF NOT EXISTS (
        SELECT 1 FROM Housing.BuildingAction a
        WHERE a.residentInfoID_FK = @LBResidentID
          AND a.buildingDetailsID_FK = @LBTargetID
          AND a.IdaraId_FK = @IdaraID_INT
          AND a.buildingActionTypeID_FK = 2
          AND a.buildingActionActive = 1
          AND a.buildingActionDate IS NOT NULL
    )
        THROW 50001, N'لا يوجد إشغال موثق يربط المستفيد بالمبنى', 1;

    -- النوع 7 مستحدث ومخصص للتحويل الداخلي فقط.
    IF NOT EXISTS (
        SELECT 1
        FROM Housing.BuildingPaymentType pt
        JOIN Housing.DeductType dt ON dt.deductTypeID = pt.deductTypeID_FK
        JOIN Housing.BuildingPaymentDestaination dest
          ON dest.buildingPaymentDestainationID = pt.buildingPaymentDestainationID_FK
        WHERE pt.buildingPaymentTypeID = 7
          AND pt.deductTypeID_FK = 7
          AND pt.buildingPaymentDestainationID_FK = 3
          AND pt.buildingPaymentTypeActive = 1
          AND dt.deductTypeActive = 1
          AND dest.buildingPaymentDestainationActive = 1
    )
        THROW 50001, N'نوع التحويل الداخلي غير مفعّل بعد', 1;

    SET @LBLockName = CONCAT(N'HUPR|', @IdaraID_INT, N'|', @LBResidentID, N'|', @LBServiceID);
    EXEC @LBLockResult = sys.sp_getapplock
        @Resource = @LBLockName,
        @LockMode = N'Exclusive',
        @LockOwner = N'Transaction',
        @LockTimeout = 10000;

    IF @LBLockResult < 0
        THROW 50001, N'تعذر حجز الرصيد العام حاليًا', 1;

    IF EXISTS (
        SELECT 1 FROM Housing.GeneralBalanceBuildingAllocation a WITH (UPDLOCK, HOLDLOCK)
        WHERE a.RequestKey = @LBRequestKey
    )
        THROW 50001, N'تم تسجيل طلب الربط مسبقًا', 1;

    IF EXISTS (
        SELECT 1 FROM Housing.GeneralBalanceBuildingAllocation a WITH (UPDLOCK, HOLDLOCK)
        WHERE a.ResidentInfoID_FK = @LBResidentID
          AND a.IdaraID_FK = @IdaraID_INT
          AND a.BillChargeTypeID_FK = @LBServiceID
          AND a.AllocationStatus = 1
          AND UPPER(LTRIM(RTRIM(a.AllocationReference))) = UPPER(@LBReference)
    )
        THROW 50001, N'مرجع التحويل مستخدم مسبقًا لهذا المستفيد والخدمة', 1;

    SELECT
        @LBGeneralNo = p.generalNo_FK,
        @LBIDNumber = p.IDNumber,
        @LBRankName = p.rankNameA,
        @LBUnitID = p.unitID,
        @LBUserName = p.userName
    FROM Housing.BuildingPayment p WITH (UPDLOCK, HOLDLOCK)
    JOIN Housing.DeductList d WITH (HOLDLOCK)
      ON d.deductListID = p.deductListID_FK
    WHERE p.paymentID = @LBSourceID
      AND p.residentInfoID_FK = @LBResidentID
      AND p.BillChargeTypeID_FK = @LBServiceID
      AND p.IdaraId_FK = @IdaraID_INT
      AND p.buildingPaymentLinkStatusID_FK = 2
      AND NULLIF(LTRIM(RTRIM(p.buildingDetailsID_FK)), N'') IS NULL
      AND p.buildingPayementActive = 1
      AND d.deductActive = 1
      AND p.UnallocatedRefundID_FK IS NULL
      AND p.buildingPaymentTypeID_FK <> 7
      AND p.amount > 0;

    IF @@ROWCOUNT <> 1
        THROW 50001, N'السداد الأصلي غير متاح للربط', 1;

    SELECT @LBFirstOccupancy = MIN(CONVERT(DATE, a.buildingActionDate))
    FROM Housing.BuildingAction a
    WHERE a.residentInfoID_FK = @LBResidentID
      AND a.IdaraId_FK = @IdaraID_INT
      AND a.buildingActionTypeID_FK = 2
      AND a.buildingActionActive = 1
      AND a.buildingActionDate IS NOT NULL;

    IF @LBFirstOccupancy IS NULL OR @LBDate < @LBFirstOccupancy
        THROW 50001, N'تاريخ التحويل غير مؤهل مقارنة بأول إشغال', 1;

    -- اتساق التخصيصات السابقة: لا يجوز اعتماد رصيد إذا تعطلت إحدى الحركتين.
    IF EXISTS (
        SELECT 1
        FROM Housing.GeneralBalanceBuildingAllocation a WITH (UPDLOCK, HOLDLOCK)
        LEFT JOIN Housing.BuildingPayment debit WITH (HOLDLOCK)
          ON debit.paymentID = a.SourceMovementPaymentID_FK
        LEFT JOIN Housing.BuildingPayment credit WITH (HOLDLOCK)
          ON credit.paymentID = a.TargetMovementPaymentID_FK
        LEFT JOIN Housing.DeductList doc WITH (HOLDLOCK)
          ON doc.deductListID = a.DeductListID_FK
        WHERE a.ResidentInfoID_FK = @LBResidentID
          AND a.BillChargeTypeID_FK = @LBServiceID
          AND a.IdaraID_FK = @IdaraID_INT
          AND a.AllocationStatus = 1
          AND (
                 ISNULL(debit.buildingPayementActive, 0) <> 1
              OR ISNULL(credit.buildingPayementActive, 0) <> 1
              OR ISNULL(doc.deductActive, 0) <> 1
              OR debit.amount <> -a.AllocatedAmount
              OR credit.amount <> a.AllocatedAmount
              OR debit.buildingPaymentTypeID_FK <> 7
              OR credit.buildingPaymentTypeID_FK <> 7
              OR debit.buildingPaymentLinkStatusID_FK <> 2
              OR credit.buildingPaymentLinkStatusID_FK <> 1
              OR debit.buildingDetailsID_FK IS NOT NULL
              OR TRY_CONVERT(BIGINT, credit.buildingDetailsID_FK) <> a.TargetBuildingID_FK
              OR debit.deductListID_FK <> a.DeductListID_FK
              OR credit.deductListID_FK <> a.DeductListID_FK
              OR debit.residentInfoID_FK <> a.ResidentInfoID_FK
              OR credit.residentInfoID_FK <> a.ResidentInfoID_FK
              OR debit.BillChargeTypeID_FK <> a.BillChargeTypeID_FK
              OR credit.BillChargeTypeID_FK <> a.BillChargeTypeID_FK
              OR debit.IdaraId_FK <> a.IdaraID_FK
              OR credit.IdaraId_FK <> a.IdaraID_FK
              OR doc.deductTypeID_FK <> 7
              OR doc.paymentTypeID_FK <> 7
              OR debit.paymentID IS NULL OR credit.paymentID IS NULL
          )
    )
        THROW 50001, N'تعارض في قيود تحويل سابقة؛ يلزم التدقيق', 1;

    -- تكرار سياسة الأهلية المحاسبية المستخدمة حاليًا في فرع الإعادة.
    SELECT
        g.yearH, g.monthH,
        MIN(CONVERT(DATE, g.gregorianDate)) AS PeriodStart,
        MAX(CONVERT(DATE, g.gregorianDate)) AS PeriodEnd
    INTO #LBHijriMonths
    FROM dbo._GregorianHijriDate g
    WHERE g.yearH BETWEEN 1400 AND 1499
    GROUP BY g.yearH, g.monthH
    HAVING COUNT(*) BETWEEN 29 AND 30
       AND COUNT(DISTINCT g.dayH) = COUNT(*)
       AND MIN(g.dayH) = 1
       AND MAX(g.dayH) = COUNT(*)
       AND COUNT(DISTINCT CONVERT(DATE, g.gregorianDate)) = COUNT(*)
       AND DATEDIFF(DAY, MIN(CONVERT(DATE, g.gregorianDate)),
                       MAX(CONVERT(DATE, g.gregorianDate))) + 1 = COUNT(*);

    SELECT
        p.paymentID,
        CONVERT(DECIMAL(38,2), p.amount) AS Amount,
        dates.ReferenceDate
    INTO #LBMovements
    FROM Housing.BuildingPayment p WITH (UPDLOCK, HOLDLOCK)
    JOIN Housing.DeductList d
      ON d.deductListID = p.deductListID_FK
    LEFT JOIN #LBHijriMonths h
      ON h.yearH = d.issueYear AND h.monthH = d.issueMonth
    CROSS APPLY (
        SELECT
            CASE
                WHEN d.issueYear BETWEEN 1400 AND 1499 THEN h.PeriodStart
                WHEN d.issueYear BETWEEN 1900 AND 9999 AND d.issueMonth BETWEEN 1 AND 12
                    THEN TRY_CONVERT(DATE, CONCAT(d.issueYear, N'-',
                        RIGHT(N'0' + CONVERT(NVARCHAR(2), d.issueMonth), 2), N'-01'))
                ELSE NULL -- لا نعتمد paymentDate كبديل عن فترة تاريخية غير موثوقة
            END AS ReferenceDate,
            CASE
                WHEN d.issueYear BETWEEN 1400 AND 1499 THEN h.PeriodEnd
                WHEN d.issueYear BETWEEN 1900 AND 9999 AND d.issueMonth BETWEEN 1 AND 12
                    THEN EOMONTH(TRY_CONVERT(DATE, CONCAT(d.issueYear, N'-',
                        RIGHT(N'0' + CONVERT(NVARCHAR(2), d.issueMonth), 2), N'-01')))
                ELSE NULL -- نفس معيار الأهلية في View المالي
            END AS PeriodEnd
    ) dates
    WHERE p.residentInfoID_FK = @LBResidentID
      AND p.BillChargeTypeID_FK = @LBServiceID
      AND p.IdaraId_FK = @IdaraID_INT
      AND p.buildingPaymentLinkStatusID_FK = 2
      AND p.buildingPayementActive = 1
      AND d.deductActive = 1
      AND p.UnallocatedRefundID_FK IS NULL
      AND p.buildingPaymentTypeID_FK <> 7
      AND NULLIF(LTRIM(RTRIM(p.buildingDetailsID_FK)), N'') IS NULL
      AND dates.PeriodEnd >= @LBFirstOccupancy;

    SELECT
        @LBPositive = ISNULL(SUM(CASE WHEN Amount > 0 THEN Amount ELSE 0 END), 0),
        @LBOldRefunds = ISNULL(SUM(CASE WHEN Amount < 0 THEN -Amount ELSE 0 END), 0)
    FROM #LBMovements;

    SELECT @LBNewRefunds = ISNULL(SUM(CONVERT(DECIMAL(38,2), r.RefundAmount)), 0)
    FROM Housing.UnallocatedPaymentRefund r WITH (UPDLOCK, HOLDLOCK)
    WHERE r.ResidentInfoID_FK = @LBResidentID
      AND r.BillChargeTypeID_FK = @LBServiceID
      AND r.IdaraId_FK = @IdaraID_INT
      AND r.RefundStatus = 1;

    SELECT @LBRefundDetails = ISNULL(SUM(CONVERT(DECIMAL(38,2), rd.AllocatedAmount)), 0)
    FROM Housing.UnallocatedPaymentRefundDetail rd WITH (UPDLOCK, HOLDLOCK)
    JOIN Housing.UnallocatedPaymentRefund r ON r.RefundID = rd.RefundID_FK
    WHERE r.ResidentInfoID_FK = @LBResidentID
      AND r.BillChargeTypeID_FK = @LBServiceID
      AND r.IdaraId_FK = @IdaraID_INT
      AND r.RefundStatus = 1;

    IF @LBRefundDetails <> @LBNewRefunds
        THROW 50001, N'تفاصيل الإعادات المؤكدة غير متطابقة', 1;

    SELECT @LBTransfers = ISNULL(SUM(CONVERT(DECIMAL(38,2), a.AllocatedAmount)), 0)
    FROM Housing.GeneralBalanceBuildingAllocation a WITH (UPDLOCK, HOLDLOCK)
    WHERE a.ResidentInfoID_FK = @LBResidentID
      AND a.BillChargeTypeID_FK = @LBServiceID
      AND a.IdaraID_FK = @IdaraID_INT
      AND a.AllocationStatus = 1;

    IF @LBPositive - @LBOldRefunds - @LBNewRefunds - @LBTransfers < @Amount_Decimal
        THROW 50001, N'الرصيد العام المؤهل غير كافٍ لعملية الربط', 1;

    ;WITH OrderedPayments AS (
        SELECT paymentID, Amount, ReferenceDate,
               SUM(Amount) OVER (ORDER BY ReferenceDate, paymentID ROWS UNBOUNDED PRECEDING) AS RunningGross
        FROM #LBMovements WHERE Amount > 0
    ),
    LegacyAllocation AS (
        SELECT paymentID, Amount,
               CASE
                   WHEN @LBOldRefunds <= RunningGross - Amount THEN CONVERT(DECIMAL(38,2),0)
                   WHEN @LBOldRefunds >= RunningGross THEN Amount
                   ELSE @LBOldRefunds - (RunningGross - Amount)
               END AS LegacyUsed
        FROM OrderedPayments
    ),
    NewRefundAllocation AS (
        SELECT rd.PaymentID_FK,
               SUM(CONVERT(DECIMAL(38,2), rd.AllocatedAmount)) AS UsedAmount
        FROM Housing.UnallocatedPaymentRefundDetail rd
        JOIN Housing.UnallocatedPaymentRefund r ON r.RefundID = rd.RefundID_FK
        WHERE r.ResidentInfoID_FK = @LBResidentID
          AND r.BillChargeTypeID_FK = @LBServiceID
          AND r.IdaraId_FK = @IdaraID_INT
          AND r.RefundStatus = 1
        GROUP BY rd.PaymentID_FK
    ),
    BuildingAllocation AS (
        SELECT a.SourcePaymentID_FK,
               SUM(CONVERT(DECIMAL(38,2), a.AllocatedAmount)) AS UsedAmount
        FROM Housing.GeneralBalanceBuildingAllocation a
        WHERE a.ResidentInfoID_FK = @LBResidentID
          AND a.BillChargeTypeID_FK = @LBServiceID
          AND a.IdaraID_FK = @IdaraID_INT
          AND a.AllocationStatus = 1
        GROUP BY a.SourcePaymentID_FK
    )
    SELECT l.paymentID,
           l.Amount - l.LegacyUsed
           - ISNULL(r.UsedAmount,0) - ISNULL(b.UsedAmount,0) AS FreeAmount
    INTO #LBSlots
    FROM LegacyAllocation l
    LEFT JOIN NewRefundAllocation r ON r.PaymentID_FK = l.paymentID
    LEFT JOIN BuildingAllocation b ON b.SourcePaymentID_FK = l.paymentID;

    IF EXISTS (SELECT 1 FROM #LBSlots WHERE FreeAmount < 0)
        THROW 50001, N'تعارض مالي: سداد مستخدم بأكثر من رصيده', 1;

    SELECT @LBSourceFree = s.FreeAmount FROM #LBSlots s WHERE s.paymentID = @LBSourceID;
    IF @LBSourceFree IS NULL OR @LBSourceFree < @Amount_Decimal
        THROW 50001, N'المبلغ المطلوب يتجاوز المتاح للسداد المختار', 1;

    -- مستند مالي واحد وحركتا نقل متقابلتان؛ إجمالي التحويل النقدي = صفر.
    INSERT INTO Housing.DeductList
    (
        deductTypeID_FK, DeductListStatusID_FK, deductName,
        amountTypeID_FK, paymentTypeID_FK,
        issueMonth, issueYear, paymentNo, paymentDate, description,
        deductActive, BillChargeTypeID_FK, IdaraId_FK,
        entryDate, entryData, hostName
    )
    VALUES
    (
        7, 2, N'تحويل رصيد عام إلى مبنى',
        1, 7,
        MONTH(@LBDate), YEAR(@LBDate), @LBReference, @LBDate, @LBDetails,
        1, @LBServiceID, @IdaraID_INT,
        GETDATE(), @entryData, @hostName
    );
    IF @@ROWCOUNT <> 1 THROW 50002, N'تعذر إنشاء مستند التحويل', 1;
    SET @LBDeductID = CONVERT(INT, SCOPE_IDENTITY());

    INSERT INTO Housing.BuildingPayment
    (
        buildingPaymentTypeID_FK, generalNo_FK, IDNumber, residentInfoID_FK,
        rankNameA, unitID, userName, buildingDetailsID_FK, amount,
        deductListID_FK, buildingPayementActive, BillChargeTypeID_FK,
        IdaraId_FK, entryDate, entryData, hostName,
        buildingPaymentLinkStatusID_FK, paymentLinkNote
    )
    VALUES
    (
        7, @LBGeneralNo, @LBIDNumber, @LBResidentID,
        @LBRankName, @LBUnitID, @LBUserName, NULL,
        CONVERT(DECIMAL(10,2), -@Amount_Decimal),
        @LBDeductID, 1, @LBServiceID,
        @IdaraID_INT, GETDATE(), @entryData, @hostName,
        2, CONCAT(N'تحويل إلى مبنى؛ OriginalPaymentID=', @LBSourceID)
    );
    IF @@ROWCOUNT <> 1 THROW 50002, N'تعذر إنشاء حركة خصم الرصيد العام', 1;
    SET @LBSourceMovementID = CONVERT(BIGINT, SCOPE_IDENTITY());

    INSERT INTO Housing.BuildingPayment
    (
        buildingPaymentTypeID_FK, generalNo_FK, IDNumber, residentInfoID_FK,
        rankNameA, unitID, userName, buildingDetailsID_FK, amount,
        deductListID_FK, buildingPayementActive, BillChargeTypeID_FK,
        IdaraId_FK, entryDate, entryData, hostName,
        buildingPaymentLinkStatusID_FK, paymentLinkNote
    )
    VALUES
    (
        7, @LBGeneralNo, @LBIDNumber, @LBResidentID,
        @LBRankName, @LBUnitID, @LBUserName, CONVERT(NVARCHAR(30), @LBTargetID),
        CONVERT(DECIMAL(10,2), @Amount_Decimal),
        @LBDeductID, 1, @LBServiceID,
        @IdaraID_INT, GETDATE(), @entryData, @hostName,
        1, CONCAT(N'تحويل من رصيد عام؛ OriginalPaymentID=', @LBSourceID)
    );
    IF @@ROWCOUNT <> 1 THROW 50002, N'تعذر إنشاء حركة إضافة رصيد المبنى', 1;
    SET @LBTargetMovementID = CONVERT(BIGINT, SCOPE_IDENTITY());

    INSERT INTO Housing.GeneralBalanceBuildingAllocation
    (
        SourcePaymentID_FK, TargetBuildingID_FK,
        ResidentInfoID_FK, BillChargeTypeID_FK, IdaraID_FK,
        AllocatedAmount, AllocationReference, AllocationDetails, RequestKey,
        AllocationStatus,
        SourceMovementPaymentID_FK, TargetMovementPaymentID_FK, DeductListID_FK,
        EntryDate, EntryData, HostName
    )
    VALUES
    (
        @LBSourceID, @LBTargetID,
        @LBResidentID, @LBServiceID, @IdaraID_INT,
        @Amount_Decimal, @LBReference, @LBDetails, @LBRequestKey,
        1,
        @LBSourceMovementID, @LBTargetMovementID, @LBDeductID,
        SYSDATETIME(), @entryData, @hostName
    );
    IF @@ROWCOUNT <> 1 THROW 50002, N'تعذر حفظ تخصيص الرصيد للمبنى', 1;
    SET @LBAllocationID = CONVERT(BIGINT, SCOPE_IDENTITY());

    INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
    VALUES
    (
        N'[Housing].[GeneralBalanceBuildingAllocation],[Housing].[BuildingPayment],[Housing].[DeductList]',
        @Action, @LBAllocationID, @entryData,
        CONCAT(N'SourcePaymentID=', @LBSourceID,
               N'; TargetBuildingID=', @LBTargetID,
               N'; Amount=', @Amount_Decimal,
               N'; DeductListID=', @LBDeductID,
               N'; SourceMovementID=', @LBSourceMovementID,
               N'; TargetMovementID=', @LBTargetMovementID)
    );

    IF @tc = 0 COMMIT TRANSACTION;
    SELECT 1 AS IsSuccessful, N'تم ربط الرصيد العام بالمبنى بنجاح' AS Message_;
    RETURN;
END
    
        ELSE IF @Action = N'CANCELGENERALBALANCEBUILDINGALLOCATION'
BEGIN

    -- إلغاء الربط معطل مؤقتًا بقرار إداري.
    -- لإعادة تفعيله مستقبلًا، احذف سطر THROW التالي فقط.
    ;THROW 50001,
        N'لا يمكن التراجع عن ربط الرصيد بالمبنى حاليًا',
        1;
    DECLARE @CBAID BIGINT;
    DECLARE @CBAResident BIGINT;
    DECLARE @CBAService INT;
    DECLARE @CBABuilding BIGINT;
    DECLARE @CBASource BIGINT;
    DECLARE @CBADebit BIGINT;
    DECLARE @CBACredit BIGINT;
    DECLARE @CBADeduct INT;
    DECLARE @CBAAmount DECIMAL(18,2);
    DECLARE @CBAEntryDate DATETIME2(3);
    DECLARE @CBAStatus TINYINT;
    DECLARE @CBAReason NVARCHAR(1000);
    DECLARE @CBALock NVARCHAR(255);
    DECLARE @CBALockResult INT;

    -- البطاقات المخصصة للتحويل تستخدم RefundID سالبًا
    -- لمنع الخلط بينها وبين أرقام الإعادات النقدية.
    IF @GeneralPaymentID IS NULL OR @GeneralPaymentID >= 0
        THROW 50001, N'معرف عملية الربط غير صحيح', 1;

    SET @CBAID = -@GeneralPaymentID;
    SET @CBAReason = NULLIF(LTRIM(RTRIM(@description)), N'');

    IF @CBAReason IS NULL OR LEN(@CBAReason) > 1000
        THROW 50001, N'سبب إلغاء الربط مطلوب وبحد أقصى 1000 حرف', 1;

    IF @IdaraID_INT IS NULL OR @IdaraID_INT <= 0
        THROW 50001, N'الإدارة غير صحيحة', 1;

    IF NULLIF(LTRIM(RTRIM(@entryData)), N'') IS NULL
        THROW 50001, N'بيانات المستخدم غير مكتملة', 1;

    -- قراءة مفتاح القفل دون حجز قفل صف قبل Application Lock.
    SELECT
        @CBAResident = a.ResidentInfoID_FK,
        @CBAService = a.BillChargeTypeID_FK
    FROM Housing.GeneralBalanceBuildingAllocation a
    WHERE a.AllocationID = @CBAID
      AND a.IdaraID_FK = @IdaraID_INT;

    IF @CBAResident IS NULL OR @CBAService IS NULL
        THROW 50001, N'عملية الربط غير موجودة ضمن الإدارة', 1;

    SET @CBALock = CONCAT(
        N'HUPR|', @IdaraID_INT,
        N'|', @CBAResident,
        N'|', @CBAService
    );

    EXEC @CBALockResult = sys.sp_getapplock
        @Resource = @CBALock,
        @LockMode = N'Exclusive',
        @LockOwner = N'Transaction',
        @LockTimeout = 10000;

    IF @CBALockResult < 0
        THROW 50001, N'تعذر حجز الرصيد حاليًا', 1;

    SELECT
        @CBAStatus = a.AllocationStatus,
        @CBABuilding = a.TargetBuildingID_FK,
        @CBASource = a.SourcePaymentID_FK,
        @CBADebit = a.SourceMovementPaymentID_FK,
        @CBACredit = a.TargetMovementPaymentID_FK,
        @CBADeduct = a.DeductListID_FK,
        @CBAAmount = a.AllocatedAmount,
        @CBAEntryDate = a.EntryDate
    FROM Housing.GeneralBalanceBuildingAllocation a
        WITH (UPDLOCK, HOLDLOCK)
    WHERE a.AllocationID = @CBAID
      AND a.IdaraID_FK = @IdaraID_INT
      AND a.ResidentInfoID_FK = @CBAResident
      AND a.BillChargeTypeID_FK = @CBAService;

    IF @CBAStatus = 2
        THROW 50001, N'سبق إلغاء عملية الربط', 1;

    IF @CBAStatus IS NULL OR @CBAStatus <> 1
        THROW 50001, N'حالة الربط لا تسمح بالإلغاء', 1;

    -- إثبات تطابق الحركتين والمستند والمصدر الأصلي.
    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.GeneralBalanceBuildingAllocation a
        JOIN Housing.BuildingPayment original
          ON original.paymentID = a.SourcePaymentID_FK
        JOIN Housing.DeductList originalDoc
          ON originalDoc.deductListID = original.deductListID_FK
        JOIN Housing.BuildingPayment debit
          ON debit.paymentID = a.SourceMovementPaymentID_FK
        JOIN Housing.BuildingPayment credit
          ON credit.paymentID = a.TargetMovementPaymentID_FK
        JOIN Housing.DeductList doc
          ON doc.deductListID = a.DeductListID_FK
        WHERE a.AllocationID = @CBAID
          AND a.AllocationStatus = 1
          AND original.buildingPayementActive = 1
          AND originalDoc.deductActive = 1
          AND original.amount > 0
          AND original.buildingPaymentLinkStatusID_FK = 2
          AND original.residentInfoID_FK = @CBAResident
          AND original.IdaraId_FK = @IdaraID_INT
          AND original.BillChargeTypeID_FK = @CBAService
          AND debit.amount = -@CBAAmount
          AND credit.amount = @CBAAmount
          AND debit.buildingPayementActive = 1
          AND credit.buildingPayementActive = 1
          AND debit.buildingPaymentTypeID_FK = 7
          AND credit.buildingPaymentTypeID_FK = 7
          AND debit.buildingPaymentLinkStatusID_FK = 2
          AND credit.buildingPaymentLinkStatusID_FK = 1
          AND NULLIF(LTRIM(RTRIM(debit.buildingDetailsID_FK)), N'') IS NULL
          AND TRY_CONVERT(BIGINT, credit.buildingDetailsID_FK)
                = @CBABuilding
          AND debit.residentInfoID_FK = @CBAResident
          AND credit.residentInfoID_FK = @CBAResident
          AND debit.IdaraId_FK = @IdaraID_INT
          AND credit.IdaraId_FK = @IdaraID_INT
          AND debit.BillChargeTypeID_FK = @CBAService
          AND credit.BillChargeTypeID_FK = @CBAService
          AND debit.deductListID_FK = @CBADeduct
          AND credit.deductListID_FK = @CBADeduct
          AND doc.deductActive = 1
          AND doc.deductTypeID_FK = 7
          AND doc.paymentTypeID_FK = 7
    )
        THROW 50001, N'قيود الربط المالي غير متطابقة', 1;

    IF (
        SELECT COUNT_BIG(*)
        FROM Housing.BuildingPayment
        WHERE deductListID_FK = @CBADeduct
    ) <> 2
        THROW 50001, N'مستند التحويل مرتبط بحركات إضافية', 1;

    -- منع الإلغاء عند وجود ارتباط مالي لاحق مباشر.
    IF EXISTS
    (
        SELECT 1
        FROM Housing.UnallocatedPaymentRefundDetail rd
        JOIN Housing.UnallocatedPaymentRefund r
          ON r.RefundID = rd.RefundID_FK
        WHERE rd.PaymentID_FK IN (@CBADebit, @CBACredit)
          AND r.RefundStatus = 1
    )
        THROW 50001, N'توجد إعادة مالية تعتمد على حركة التحويل', 1;

    IF EXISTS
    (
        SELECT 1
        FROM Housing.GeneralBalanceBuildingAllocation other
        WHERE other.SourcePaymentID_FK IN (@CBADebit, @CBACredit)
          AND other.AllocationStatus = 1
    )
        THROW 50001, N'توجد عملية ربط لاحقة تعتمد على التحويل', 1;

    -- احتياطًا: لا نلغي تلقائيًا تحويلًا أعقبته حركات
    -- مالية أو مطالبات جديدة على المبنى والخدمة.
    -- منع الإلغاء عند وجود حركات لاحقة غير مستقلة.
-- نستثني فقط التحويلات الداخلية الأخرى المثبتة محاسبيًا.

IF EXISTS
(
    SELECT 1
    FROM Housing.BuildingPayment p
    WHERE p.residentInfoID_FK = @CBAResident
      AND p.IdaraId_FK = @IdaraID_INT
      AND p.BillChargeTypeID_FK = @CBAService
      AND TRY_CONVERT(BIGINT, p.buildingDetailsID_FK) = @CBABuilding
      AND p.buildingPayementActive = 1
      AND p.paymentID NOT IN (@CBADebit, @CBACredit)
      AND p.entryDate > @CBAEntryDate

      -- لا نعتبر التحويلات الداخلية الأخرى مانعًا
      -- إلا بعد التحقق من استقلالها وتطابقها.
      AND NOT EXISTS
      (
          SELECT 1
          FROM Housing.GeneralBalanceBuildingAllocation other
          INNER JOIN Housing.BuildingPayment otherDebit
              ON otherDebit.paymentID =
                 other.SourceMovementPaymentID_FK
          INNER JOIN Housing.DeductList otherDoc
              ON otherDoc.deductListID = other.DeductListID_FK
          WHERE other.TargetMovementPaymentID_FK = p.paymentID
            AND other.AllocationID <> @CBAID
            AND other.AllocationStatus = 1
            AND other.ResidentInfoID_FK = @CBAResident
            AND other.IdaraID_FK = @IdaraID_INT
            AND other.BillChargeTypeID_FK = @CBAService
            AND other.TargetBuildingID_FK = @CBABuilding

            AND p.buildingPaymentTypeID_FK = 7
            AND p.buildingPaymentLinkStatusID_FK = 1
            AND p.amount = other.AllocatedAmount
            AND p.deductListID_FK = other.DeductListID_FK

            AND otherDebit.amount = -other.AllocatedAmount
            AND otherDebit.buildingPaymentTypeID_FK = 7
            AND otherDebit.buildingPaymentLinkStatusID_FK = 2
            AND otherDebit.buildingPayementActive = 1
            AND otherDebit.deductListID_FK = other.DeductListID_FK

            AND otherDoc.deductActive = 1
      )
)
    THROW 50001,
        N'توجد حركات مالية لاحقة للمبنى؛ يلزم التدقيق قبل الإلغاء',
        1;

    IF EXISTS
    (
        SELECT 1
        FROM Housing.Bills b
        WHERE b.residentInfoID_FK = @CBAResident
          AND b.idaraID_FK = @IdaraID_INT
          AND b.BillChargeTypeID_FK = @CBAService
          AND b.buildingDetailsID = @CBABuilding
          AND b.BillActive = 1
          AND b.entryDate > @CBAEntryDate
    )
        THROW 50001, N'توجد مطالبات لاحقة قد تعتمد على الرصيد المحول', 1;

    IF EXISTS
    (
        SELECT 1
        FROM Housing.BuildingAction ba
        WHERE ba.residentInfoID_FK = @CBAResident
          AND ba.IdaraId_FK = @IdaraID_INT
          AND ba.buildingDetailsID_FK = @CBABuilding
          AND ba.buildingActionActive = 1
          AND ba.buildingActionTypeID_FK IN (3, 57, 58)
          AND ba.entryDate > @CBAEntryDate
    )
        THROW 50001, N'توجد إجراءات تدقيق أو إخلاء لاحقة تمنع الإلغاء التلقائي', 1;

    -- تعطيل الحركتين دون حذفهما.
    UPDATE Housing.BuildingPayment
    SET buildingPayementActive = 0
    WHERE paymentID IN (@CBADebit, @CBACredit)
      AND buildingPayementActive = 1;

    IF @@ROWCOUNT <> 2
        THROW 50001, N'تعذر تعطيل حركتي التحويل', 1;

    UPDATE Housing.DeductList
    SET deductActive = 0
    WHERE deductListID = @CBADeduct
      AND deductActive = 1;

    IF @@ROWCOUNT <> 1
        THROW 50001, N'تعذر تعطيل مستند التحويل', 1;

    UPDATE Housing.GeneralBalanceBuildingAllocation
    SET
        AllocationStatus = 2,
        CancellationReason = @CBAReason,
        CancellationDate = SYSDATETIME(),
        CancellationEntryData = @entryData
    WHERE AllocationID = @CBAID
      AND AllocationStatus = 1;

    IF @@ROWCOUNT <> 1
        THROW 50001, N'تعذر إلغاء الربط', 1;

    INSERT INTO dbo.AuditLog
    (
        TableName, ActionType, RecordID, PerformedBy, Notes
    )
    VALUES
    (
        N'[Housing].[GeneralBalanceBuildingAllocation]',
        @Action,
        @CBAID,
        @entryData,
        CONCAT(
            N'AllocationID=', @CBAID,
            N'; SourcePaymentID=', @CBASource,
            N'; TargetBuildingID=', @CBABuilding,
            N'; Amount=', @CBAAmount,
            N'; Reason=', @CBAReason
        )
    );

    IF @tc = 0
        COMMIT TRANSACTION;

    SELECT
        1 AS IsSuccessful,
        N'تم إلغاء ربط الرصيد بالمبنى بنجاح' AS Message_;

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