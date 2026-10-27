
CREATE PROCEDURE [Housing].[FinancialAuditForExtendAndEvictionsSP] 
(
      @Action                               NVARCHAR(200)
    , @ActionID                             BIGINT          = NULL
    , @residentInfoID                       NVARCHAR(100)   = NULL
    , @buildingDetailsID                    NVARCHAR(1000)  = NULL
    , @LastActionID                         NVARCHAR(1000)  = NULL
    , @LastActionTypeID                     NVARCHAR(1000)  = NULL
    , @Notes                                NVARCHAR(1000)  = NULL
    , @LastActionExtendReasonTypeID         NVARCHAR(1000)  = NULL
    , @PaymentType                          NVARCHAR(1000)  = NULL
    , @PaymentNo                            NVARCHAR(1000)  = NULL
    , @PaymentDate                          NVARCHAR(1000)  = NULL
    , @Amount                               NVARCHAR(1000)  = NULL
    , @FullRemining                         NVARCHAR(1000)  = NULL
    , @BillChargeTypeID_FK                  NVARCHAR(1000)  = NULL
    , @ToBillChargeTypeID_FK                NVARCHAR(1000)  = NULL
    , @description                          NVARCHAR(4000)  = NULL
    , @OccupentDate                         NVARCHAR(4000)  = NULL
    , @ExitDate                             NVARCHAR(1000)  = NULL
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
          @NewID BIGINT = NULL,
          @NewID1 BIGINT = NULL,
          @NewID2 BIGINT = NULL
        , @Note  NVARCHAR(MAX) = NULL
        , @Note1  NVARCHAR(MAX) = NULL;

    -- تحويلات رقمية آمنة
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(@idaraID_FK, ''));
    DECLARE @DeductType_INT INT = (select top (1) t.deductTypeID_FK from Housing.BuildingPaymentType t where t.buildingPaymentTypeID = @PaymentType order by t.buildingPaymentTypeID desc);


    DECLARE @Amount_Decimal DECIMAL(18,2);
    IF @Action = N'FINANCIALAUDITFOREXTENDANDEVICTIONS'
    begin
    SET @Amount_Decimal = TRY_CONVERT(DECIMAL(18,2), 0);
    end
    else
    begin
    SET @Amount_Decimal = TRY_CONVERT(DECIMAL(18,2), @Amount);
    
    IF @Amount_Decimal IS NULL
    BEGIN
        ;THROW 50001, N'قيمة المبلغ غير صحيحة', 1;
    END
    end

    
   
    

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

        -- Validate the exact current request, department and latest workflow stage.
        IF @Action IN (N'FINANCIALAUDITFOREXTENDANDEVICTIONS',
                       N'PAYMENTANDREFUNDFOREXTENDANDEXIT', N'FINANCIALSETTLEMENT')
           AND NOT EXISTS
           (
               SELECT 1
               FROM Housing.V_WaitingList w
               WHERE w.ActionID = @ActionID
                 AND w.LastActionID = TRY_CONVERT(BIGINT, @LastActionID)
                 AND w.residentInfoID = TRY_CONVERT(BIGINT, @residentInfoID)
                 AND w.buildingDetailsID = TRY_CONVERT(BIGINT, @buildingDetailsID)
                 AND w.IdaraId = @IdaraID_INT
                 AND w.LastActionTypeID IN (51, 57)
           )
           THROW 50001, N'تغير طلب التدقيق أو لا يتطابق مع المستفيد والمنزل والإدارة؛ حدّث الصفحة.', 1;

   


        -- IF @Action IN(N'NewExtend',N'EditExtend',N'SendExtendToFinance')
        --BEGIN
         
           


        --END

        

     

        ----------------------------------------------------------------
        -- FINANCIALAUDITFOREXTENDANDEVICTIONS
        ----------------------------------------------------------------
        IF @Action = N'FINANCIALAUDITFOREXTENDANDEVICTIONS'
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

             IF NULLIF(LTRIM(RTRIM(@residentInfoID)), N'') IS NULL
             BEGIN
                 ;THROW 50001, N'رقم الساكن مطلوب', 1;
             END


              IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) Not in (51,57)
            BEGIN
                ;THROW 50001, N'تم انهاء اجراءات الامهال / الاخلاء مسبقا', 1;
            END



            Declare @buildingActionTypeID_FK INT

            select 
            @buildingActionTypeID_FK =
            case 
            when w.LastActionTypeID = 51  then 52
            when w.LastActionTypeID = 57  then 58
            else 
            9999
            END
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID 
            and w.ActionID = @ActionID
            and w.buildingDetailsID = @buildingDetailsID

            IF 
            (
               @buildingActionTypeID_FK = 9999 
            )
            BEGIN
                ;THROW 50001, N'حصل خطأ ما building Action Type', 1;
            END

          

            IF(@buildingActionTypeID_FK = 52)
BEGIN

    ------------------------------------------------------------
    -- منع اعتماد التدقيق المالي للإمهال عند وجود رصيد عام فائض
    -- المرحلة 51 -> 52 فقط
    ------------------------------------------------------------

    DECLARE @ExtendAuditResidentID BIGINT =
        TRY_CONVERT(BIGINT, @residentInfoID);

    IF @ExtendAuditResidentID IS NULL
       OR @IdaraID_INT IS NULL
    BEGIN
        ;THROW 50001,
            N'بيانات المستفيد أو الإدارة غير صحيحة.',
            1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM Housing.V_SumBillsTotalPriceAndTotalPaidForResident e
        WHERE e.residentInfoID = @ExtendAuditResidentID
          AND e.buildingDetailsID IS NULL
        GROUP BY e.BillChargeTypeID
        HAVING
            SUM(CONVERT(DECIMAL(38,2), e.Remaining)) < 0
            OR COUNT_BIG(e.Remaining) <> COUNT_BIG(*)
    )
    BEGIN
        ;THROW 50001,
            N'لا يمكن اعتماد التدقيق المالي للإمهال لوجود رصيد عام فائض غير مرتبط بمبنى. يرجى معالجته من صفحة التدقيق المالي العام أولاً.',
            1;
    END;

   


              INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                , buildingDetailsID_FK
                , buildingDetailsNo
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , buildingActionFromDate
                , buildingActionToDate
                , ExtendReasonTypeID_FK
                , OccupentDate
                --, ExitDate
                , IdaraId_FK
                , entryData
                , hostName
            )
            select
              @buildingActionTypeID_FK
                , @residentInfoID
                , @GeneralNo
                , @ExtendLetterNo
                , @ExtendLetterDate
                , @buildingDetailsID
                , @buildingDetailsNo
                , 1
                , @Notes
                , @LastActionID
                , @ExtendStartDate
                , @ExtendEndDate
                , w.LastActionExtendReasonTypeID
                , cast(@OccupentDate as date)
                --, @ExitDate
                , @IdaraID_INT
                , @entryData
                , @hostName
              from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID 
            and w.buildingDetailsID = @buildingDetailsID
            and w.ActionID = @ActionID
            and w.LastActionID = TRY_CONVERT(BIGINT,@LastActionID)
            and w.LastActionTypeID = 51
            and w.IdaraId = @IdaraID_INT
            
            -- VALUES
            --(
            --      @buildingActionTypeID_FK
            --    , @residentInfoID
            --    , @GeneralNo
            --    , @ExtendLetterNo
            --    , @ExtendLetterDate
            --    , @buildingDetailsID
            --    , @buildingDetailsNo
            --    , 1
            --    , @Notes
            --    , @LastActionID
            --    , @ExtendStartDate
            --    , @ExtendEndDate
            --    , @LastActionExtendReasonTypeID
            --    , @IdaraID_INT
            --    , @entryData
            --    , @hostName
            --);


            
            IF @@ROWCOUNT <> 1
            BEGIN
                ;THROW 50002, N'حصل خطأ في اعتماد التدقيق المالي للامهال ', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اعتماد التدقيق المالي للامهال - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionTypeID_FK), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingActionDecisionNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendLetterNo), '') + N'"'
                + N',"buildingActionDecisionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendLetterDate), '') + N'"'
                + N',"buildingDetailsID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"buildingDetailsNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), '') + N'"'
                + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"buildingActionNote": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @LastActionID), '') + N'"'
                + N',"buildingActionFromDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendStartDate), '') + N'"'
                + N',"buildingActionToDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendEndDate), '') + N'"'
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
                , N'FINANCIALAUDITFOREXTENDANDEVICTIONS'
                , @ActionID
                , @entryData
                , @Note
            );
            

            IF @tc = 0 COMMIT TRANSACTION;
            

            SELECT 1 AS IsSuccessful, N'تم اعتماد التدقيق المالي للامهال بنجاح' AS Message_;
            RETURN;

            END



            ELSE IF(@buildingActionTypeID_FK = 58)
            begin



            
-- التحقق المالي قبل اعتماد الإخلاء فقط (57 -> 58)
DECLARE @AuditResidentID BIGINT = TRY_CONVERT(BIGINT, @residentInfoID);
DECLARE @AuditBuildingID BIGINT = TRY_CONVERT(BIGINT, @buildingDetailsID);

IF @AuditResidentID IS NULL OR @AuditBuildingID IS NULL OR @IdaraID_INT IS NULL
    THROW 50001, N'بيانات المستفيد أو المبنى أو الإدارة غير صحيحة.', 1;

-- General credit/debt is processed only on FinancialAuditForUser.
IF EXISTS
(
    SELECT 1
    FROM Housing.V_SumBillsTotalPriceAndTotalPaidForResident e
    WHERE e.residentInfoID = @AuditResidentID
      AND e.buildingDetailsID IS NULL
    GROUP BY e.BillChargeTypeID
    HAVING SUM(CONVERT(DECIMAL(38,2),e.Remaining)) <> 0
        OR COUNT_BIG(e.Remaining) <> COUNT_BIG(*)
)
    THROW 50001, N'يوجد رصيد عام غير معالج للمستفيد؛ يرجى معالجته أولاً من صفحة التدقيق المالي العام.', 1;

-- Missing accounting data is not evidence of a zero balance.
IF NOT EXISTS
(
    SELECT 1
    FROM Housing.V_SumBillsTotalPriceAndTotalPaidForResident e
    WHERE e.residentInfoID = @AuditResidentID
      AND e.buildingDetailsID = @AuditBuildingID
)
    THROW 50001, N'تعذر التحقق من الرصيد المالي للمنزل.', 1;

-- Every service for the selected home must be settled independently.
IF EXISTS
(
    SELECT 1
    FROM Housing.V_SumBillsTotalPriceAndTotalPaidForResident e
    WHERE e.residentInfoID = @AuditResidentID
      AND e.buildingDetailsID = @AuditBuildingID
    GROUP BY e.BillChargeTypeID
    HAVING SUM(CONVERT(DECIMAL(38,2),e.Remaining)) <> 0
        OR COUNT_BIG(e.Remaining) <> COUNT_BIG(*)
)
    THROW 50001, N'لا يمكن اعتماد الإخلاء حتى تصفية جميع أرصدة خدمات المنزل وإتمام التسويات المالية.', 1;

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
                , buildingActionDecisionDate
                , buildingActionDecisionNo
                , ExtendReasonTypeID_FK
                , OccupentDate
                , ExitDate
                , IdaraId_FK
                , entryData
                , hostName
            )
            SELECT
                  @buildingActionTypeID_FK
                , @residentInfoID
                , @GeneralNo
                , @buildingDetailsID
                , @buildingDetailsNo
                , 1
                , @Notes
                , @LastActionID
                , GETDATE() 
                , null
                , null
                , @LastActionExtendReasonTypeID
                , @OccupentDate
                , @ExitDate
                , @IdaraID_INT
                , @entryData
                , @hostName

            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID 
            and w.buildingDetailsID = @buildingDetailsID
            and w.ActionID = @ActionID
            and w.LastActionID = TRY_CONVERT(BIGINT,@LastActionID)
            and w.LastActionTypeID = 57
            and w.IdaraId = @IdaraID_INT
            -- VALUES
            --(
            --      @buildingActionTypeID_FK
            --    , @residentInfoID
            --    , @GeneralNo
            --    , @buildingDetailsID
            --    , @buildingDetailsNo
            --    , 1
            --    , @Notes
            --    , @LastActionID
            --    , @ExitDate
            --    , @LastActionExtendReasonTypeID
            --    , @IdaraID_INT
            --    , @entryData
            --    , @hostName
            --);


            
            IF @@ROWCOUNT <> 1
            BEGIN
                ;THROW 50002, N'حصل خطأ في اعتماد التدقيق المالي للاخلاء ', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اعتماد التدقيق المالي للاخلاء - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionTypeID_FK), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingActionDecisionNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendLetterNo), '') + N'"'
                + N',"buildingActionDecisionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendLetterDate), '') + N'"'
                + N',"buildingDetailsID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"buildingDetailsNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), '') + N'"'
                + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"buildingActionNote": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @LastActionID), '') + N'"'
                + N',"buildingActionFromDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendStartDate), '') + N'"'
                + N',"buildingActionToDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendEndDate), '') + N'"'
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
                , N'FINANCIALAUDITFOREXTENDANDEVICTIONS'
                , @ActionID
                , @entryData
                , @Note
            );
            

            IF @tc = 0 COMMIT TRANSACTION;
            

            SELECT 1 AS IsSuccessful, N'تم اعتماد التدقيق المالي للاخلاء بنجاح' AS Message_;
            RETURN;

            END
            ELSE
        BEGIN

        IF @tc = 0 COMMIT TRANSACTION;

        SELECT 0 AS IsSuccessful, N'حصل خطأ ما - Not Exit Or Extend' AS Message_;
            RETURN;

        END

        END
       
        

         ----------------------------------------------------------------
        -- PAYMENTANDREFUNDFOREXTENDANDEXIT
        ----------------------------------------------------------------
        ELSE IF @Action = N'PAYMENTANDREFUNDFOREXTENDANDEXIT'
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


              IF NULLIF(LTRIM(RTRIM(@residentInfoID)), N'') IS NULL
             BEGIN
                 ;THROW 50001, N'رقم الساكن مطلوب', 1;
             END



              IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) Not in (51,57)
            BEGIN
                ;THROW 50001, N'تم انهاء اجراءات الامهال / الاخلاء مسبقا', 1;
            END

            Declare @InsertedAmount decimal(18,2)
             IF (select b.buildingPaymentDestainationID_FK from [DATACORE].[Housing].[BuildingPaymentType] b where b.buildingPaymentTypeID = @PaymentType) = 1
         BEGIN
                set @InsertedAmount = @Amount_Decimal
         END
         ELSE
         BEGIN
                set @InsertedAmount = @Amount_Decimal * -1
         END


          
           -- All payment/refund balances are limited to the selected home.
          -- All payment/refund balances are limited to the selected home.
IF @Amount_Decimal IS NULL OR @Amount_Decimal <= 0
    THROW 50001, N'يجب إدخال مبلغ أكبر من صفر.', 1;

------------------------------------------------------------
-- Shared financial concurrency lock.
-- Same resource format as FinancialAuditForUserSP.
-- Must be acquired BEFORE recalculating the balance.
------------------------------------------------------------
DECLARE @HFAResidentID BIGINT =
    TRY_CONVERT(BIGINT, @residentInfoID);

DECLARE @HFABuildingID BIGINT =
    TRY_CONVERT(BIGINT, @buildingDetailsID);

DECLARE @HFAServiceID BIGINT =
    TRY_CONVERT(BIGINT, @BillChargeTypeID_FK);

DECLARE @HFALockResult INT;
DECLARE @HFALockResource NVARCHAR(255);

IF @IdaraID_INT IS NULL OR @IdaraID_INT <= 0
   OR @HFAResidentID IS NULL OR @HFAResidentID <= 0
   OR @HFABuildingID IS NULL OR @HFABuildingID <= 0
   OR @HFAServiceID IS NULL OR @HFAServiceID <= 0
BEGIN
    THROW 50001, N'بيانات المستفيد أو المبنى أو نوع الخدمة غير صحيحة.', 1;
END;

SET @HFALockResource =
    CONCAT(
        N'HFA|',
        @IdaraID_INT, N'|',
        @HFAResidentID, N'|',
        @HFAServiceID, N'|',
        CONVERT(NVARCHAR(30), @HFABuildingID)
    );

EXEC @HFALockResult = sys.sp_getapplock
    @Resource = @HFALockResource,
    @LockMode = N'Exclusive',
    @LockOwner = N'Transaction',
    @LockTimeout = 10000;

IF @HFALockResult < 0
BEGIN
    THROW 50001,
        N'تعذر حجز الرصيد المالي حاليًا، يرجى إعادة المحاولة.',
        1;
END;

------------------------------------------------------------
-- Recalculate the balance only AFTER acquiring the lock.
------------------------------------------------------------
DECLARE @AvailableAmountForToChargeTypeForPayment DECIMAL(38,2) = NULL,
        @FinalAvailableAmountForToChargeTypeForPayment DECIMAL(38,2) = NULL;

           SELECT @AvailableAmountForToChargeTypeForPayment =
                  SUM(CONVERT(DECIMAL(38,2),s.Remaining))
           FROM Housing.V_SumBillsTotalPriceAndTotalPaidForResident s
           WHERE s.residentInfoID = TRY_CONVERT(BIGINT,@residentInfoID)
             AND s.buildingDetailsID = TRY_CONVERT(BIGINT,@buildingDetailsID)
             AND s.BillChargeTypeID = TRY_CONVERT(INT,@BillChargeTypeID_FK);

         IF (select b.buildingPaymentDestainationID_FK from [DATACORE].[Housing].[BuildingPaymentType] b where b.buildingPaymentTypeID = @PaymentType) = 1
         BEGIN
           
           set @FinalAvailableAmountForToChargeTypeForPayment = @AvailableAmountForToChargeTypeForPayment
                 
         END
        else
        BEGIN
           
           set @FinalAvailableAmountForToChargeTypeForPayment = @AvailableAmountForToChargeTypeForPayment * -1
                 
         END


         IF @FinalAvailableAmountForToChargeTypeForPayment IS NULL
            OR @FinalAvailableAmountForToChargeTypeForPayment <= 0
            OR @Amount_Decimal > @FinalAvailableAmountForToChargeTypeForPayment
             THROW 50001, N'المبلغ يتجاوز الرصيد المتاح لهذا النوع من الخدمة في المنزل المحدد.', 1;

         IF (select b.buildingPaymentDestainationID_FK from [DATACORE].[Housing].[BuildingPaymentType] b where b.buildingPaymentTypeID = @PaymentType) = 1
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
                 @hostName

            )


            IF @@ROWCOUNT = 0
            BEGIN
                 ;THROW 50002, N'حصل خطأ في عملية الدفع او الاعادة - BuildingPayment',  1; -- برمجي/غير متوقع
            END

            set @NewID1 = SCOPE_IDENTITY();

             SET @Note1 = N'{'
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
                , @Note1
            );



           

            IF @tc = 0 COMMIT TRANSACTION;



           

            SELECT 1 AS IsSuccessful, N'تم تنفيذ العملية بنجاح' AS Message_;
            RETURN;
        END



      
        ----------------------------------------------------------------
        -- FINANCIALSETTLEMENT
        ----------------------------------------------------------------
        ELSE IF @Action = N'FINANCIALSETTLEMENT'
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


              IF NULLIF(LTRIM(RTRIM(@residentInfoID)), N'') IS NULL
             BEGIN
                 ;THROW 50001, N'رقم الساكن مطلوب', 1;
             END

             
              IF @BillChargeTypeID_FK = @ToBillChargeTypeID_FK
             BEGIN
                 ;THROW 50001, N'لايمكن سحب رصيد من الخدمة لنفسها', 1;
             END


            -- Recalculate both service balances on the server for this home only;
            -- @FullRemining is user-supplied and must not authorize a transfer.
            IF @Amount_Decimal IS NULL OR @Amount_Decimal <= 0
    THROW 50001, N'مبلغ التسوية يجب أن يكون أكبر من صفر.', 1;

------------------------------------------------------------
-- Shared HFA locks for financial settlement.
-- Lock BOTH services before recalculating balances.
------------------------------------------------------------
DECLARE @ExitSetResidentID BIGINT =
    TRY_CONVERT(BIGINT, @residentInfoID);

DECLARE @ExitSetBuildingID BIGINT =
    TRY_CONVERT(BIGINT, @buildingDetailsID);

DECLARE @ExitSetFromServiceID INT =
    TRY_CONVERT(INT, @BillChargeTypeID_FK);

DECLARE @ExitSetToServiceID INT =
    TRY_CONVERT(INT, @ToBillChargeTypeID_FK);

DECLARE @ExitSetFirstServiceID INT;
DECLARE @ExitSetSecondServiceID INT;
DECLARE @ExitSetLockKey NVARCHAR(255);
DECLARE @ExitSetLockResult INT;

IF @IdaraID_INT IS NULL OR @IdaraID_INT <= 0
   OR @ExitSetResidentID IS NULL OR @ExitSetResidentID <= 0
   OR @ExitSetBuildingID IS NULL OR @ExitSetBuildingID <= 0
   OR @ExitSetFromServiceID IS NULL OR @ExitSetFromServiceID <= 0
   OR @ExitSetToServiceID IS NULL OR @ExitSetToServiceID <= 0
   OR @ExitSetFromServiceID = @ExitSetToServiceID
BEGIN
    THROW 50001,
        N'بيانات المستفيد أو المبنى أو خدمات التسوية غير صحيحة.',
        1;
END;

-- Deterministic lock ordering prevents reciprocal
-- settlements from acquiring the two locks in reverse order.

SET @ExitSetFirstServiceID =
    CASE
        WHEN @ExitSetFromServiceID < @ExitSetToServiceID
        THEN @ExitSetFromServiceID
        ELSE @ExitSetToServiceID
    END;

SET @ExitSetSecondServiceID =
    CASE
        WHEN @ExitSetFromServiceID < @ExitSetToServiceID
        THEN @ExitSetToServiceID
        ELSE @ExitSetFromServiceID
    END;

-- Lock the first service.
SET @ExitSetLockKey = CONCAT(
    N'HFA|',
    @IdaraID_INT, N'|',
    @ExitSetResidentID, N'|',
    @ExitSetFirstServiceID, N'|',
    @ExitSetBuildingID
);

EXEC @ExitSetLockResult = sys.sp_getapplock
    @Resource = @ExitSetLockKey,
    @LockMode = N'Exclusive',
    @LockOwner = N'Transaction',
    @LockTimeout = 10000;

IF @ExitSetLockResult < 0
    THROW 50001,
        N'تعذر حجز الرصيد للتسوية حاليًا، يرجى إعادة المحاولة.',
        1;

-- Lock the second service.
SET @ExitSetLockKey = CONCAT(
    N'HFA|',
    @IdaraID_INT, N'|',
    @ExitSetResidentID, N'|',
    @ExitSetSecondServiceID, N'|',
    @ExitSetBuildingID
);

EXEC @ExitSetLockResult = sys.sp_getapplock
    @Resource = @ExitSetLockKey,
    @LockMode = N'Exclusive',
    @LockOwner = N'Transaction',
    @LockTimeout = 10000;

IF @ExitSetLockResult < 0
    THROW 50001,
        N'تعذر حجز الرصيد للتسوية حاليًا، يرجى إعادة المحاولة.',
        1;


        ------------------------------------------------------------
-- Settlement idempotency validation
-- Must execute AFTER acquiring both HFA locks
-- and BEFORE calculating balances or inserting movements.
------------------------------------------------------------
DECLARE @ExitSetReference NVARCHAR(50) =
    NULLIF(LTRIM(RTRIM(@PaymentNo)), N'');

IF @ExitSetReference IS NULL
   OR LEN(LTRIM(RTRIM(@PaymentNo))) > 50
BEGIN
    THROW 50001,
        N'معرف عملية التسوية مطلوب وبحد أقصى 50 حرفًا.',
        1;
END;

-- Only the approved financial settlement payment type.
IF ISNULL(TRY_CONVERT(INT, @PaymentType), 0) <> 6
   OR NOT EXISTS
   (
       SELECT 1
       FROM Housing.BuildingPaymentType t
       WHERE t.buildingPaymentTypeID = 6
         AND t.buildingPaymentTypeActive = 1
         AND t.buildingPaymentDestainationID_FK = 1
         AND t.deductTypeID_FK = 6
   )
BEGIN
    THROW 50001,
        N'نوع عملية التسوية المالية غير صحيح أو غير مفعل.',
        1;
END;

-- Reject replaying an already registered settlement request.
IF EXISTS
(
    SELECT 1
    FROM Housing.DeductList d WITH (UPDLOCK, HOLDLOCK)
    WHERE d.IdaraId_FK = @IdaraID_INT
      AND d.paymentTypeID_FK = 6
      AND d.paymentNo = @ExitSetReference
)
BEGIN
    THROW 50001,
        N'تم تنفيذ طلب التسوية بهذا المعرف مسبقًا.',
        1;
END;

------------------------------------------------------------
-- Existing balance calculations MUST run after both locks.
------------------------------------------------------------
DECLARE @SourceRemaining DECIMAL(38,2) = NULL,
        @TargetRemaining DECIMAL(38,2) = NULL;

            SELECT @SourceRemaining = SUM(CONVERT(DECIMAL(38,2),s.Remaining))
            FROM Housing.V_SumBillsTotalPriceAndTotalPaidForResident s
            WHERE s.residentInfoID = TRY_CONVERT(BIGINT,@residentInfoID)
              AND s.buildingDetailsID = TRY_CONVERT(BIGINT,@buildingDetailsID)
              AND s.BillChargeTypeID = TRY_CONVERT(INT,@BillChargeTypeID_FK);

            SELECT @TargetRemaining = SUM(CONVERT(DECIMAL(38,2),s.Remaining))
            FROM Housing.V_SumBillsTotalPriceAndTotalPaidForResident s
            WHERE s.residentInfoID = TRY_CONVERT(BIGINT,@residentInfoID)
              AND s.buildingDetailsID = TRY_CONVERT(BIGINT,@buildingDetailsID)
              AND s.BillChargeTypeID = TRY_CONVERT(INT,@ToBillChargeTypeID_FK);

            IF @SourceRemaining IS NULL OR @SourceRemaining >= 0
                THROW 50001, N'لا يوجد فائض مؤهل للتسوية في الخدمة المصدر لهذا المنزل.', 1;

            IF @TargetRemaining IS NULL OR @TargetRemaining <= 0
                THROW 50001, N'لا توجد مديونية مؤهلة للتسوية في الخدمة المستهدفة لهذا المنزل.', 1;

            IF @Amount_Decimal > -@SourceRemaining OR @Amount_Decimal > @TargetRemaining
                THROW 50001, N'مبلغ التسوية يتجاوز فائض المصدر أو مديونية الوجهة لهذا المنزل.', 1;

            IF NOT EXISTS
            (
               SELECT 1 FROM Housing.V_WaitingList w
               WHERE w.ActionID=@ActionID AND w.LastActionID=TRY_CONVERT(BIGINT,@LastActionID)
                 AND w.residentInfoID=TRY_CONVERT(BIGINT,@residentInfoID)
                 AND w.buildingDetailsID=TRY_CONVERT(BIGINT,@buildingDetailsID)
                 AND w.IdaraId=@IdaraID_INT AND w.LastActionTypeID IN (51,57)
            ) THROW 50001, N'حالة طلب التدقيق تغيرت؛ حدّث الصفحة.', 1;

            Declare @AmountForFromChargeType decimal(18,2),@AmountForToChargeType decimal(18,2)
            
                set @AmountForFromChargeType = @Amount_Decimal * -1

                set @AmountForToChargeType = @Amount_Decimal
         
 


         Declare @FromChargeTypeName nvarchar(1000) ,@ToChargeTypeName nvarchar(1000),@msgChargeType nvarchar(2000) 
         
         set @ToChargeTypeName = (select v.BillChargeTypeName_A from Housing.BillChargeType v where v.BillChargeTypeID = @ToBillChargeTypeID_FK)
         set @FromChargeTypeName = (select v.BillChargeTypeName_A from Housing.BillChargeType v where v.BillChargeTypeID = @BillChargeTypeID_FK)
         set @msgChargeType = N'تسوية مالية من ' + ISNULL(@FromChargeTypeName,'') + N' الى ' + ISNULL(@ToChargeTypeName,'')


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
                 ,[ToBillChargeTypeID_FK]
                 ,[IdaraId_FK]
                 ,[entryDate]
                 ,[entryData]
                 ,[hostName]
            )
            VALUES
            (
                 @DeductType_INT,
                 2,
                 @msgChargeType,
                 1,
                 @PaymentType,
                 MONTH(GETDATE()),
                 YEAR(GETDATE()),
                 @ExitSetReference,
                 GETDATE(),
                 @description,
                 1,
                 @BillChargeTypeID_FK,
                 @ToBillChargeTypeID_FK,
                 @IdaraID_INT,
                 GETDATE(),
                 @entryData,
                 @hostName

            )


            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في التسوية المالية - deductList', 1; -- برمجي/غير متوقع
            END

           set @NewID = SCOPE_IDENTITY();







             SET @Note = N'{'
                + N'"deductListID": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"deductTypeID_FK": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @DeductType_INT), '') + N'"'
                + N',"deductName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @msgChargeType), '') + N'"'
                + N',"amountTypeID_FK": "'  + ISNULL(CONVERT(NVARCHAR(MAX), 1), '') + N'"'
                + N',"paymentTypeID_FK": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @PaymentType), '') + N'"'
                + N',"issueMonth": "'      + ISNULL(CONVERT(NVARCHAR(MAX),  MONTH(GETDATE())), '') + N'"'
                + N',"issueYear": "'           + ISNULL(CONVERT(NVARCHAR(MAX), YEAR(GETDATE())), '') + N'"'
                + N',"paymentDate": "'           + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
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
                 @AmountForFromChargeType,
                 @NewID,
                 1,
                 @BillChargeTypeID_FK,
                 @IdaraID_INT,
                 GETDATE(),
                 @entryData,
                 @hostName

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
                 @AmountForToChargeType,
                 @NewID,
                 1,
                 @ToBillChargeTypeID_FK,
                 @IdaraID_INT,
                 GETDATE(),
                 @entryData,
                 @hostName

            )


            IF @@ROWCOUNT = 0
            BEGIN
                 ;THROW 50002, N'حصل خطأ في عملية الدفع او الاعادة - BuildingPayment',  1; -- برمجي/غير متوقع
            END

            set @NewID2 = SCOPE_IDENTITY();

             SET @Note = N'{'
                + N'"paymentID": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @NewID2), '') + N'"'
                + N',"buildingPaymentTypeID_FK": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @PaymentType), '') + N'"'
                + N',"generalNo_FK": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"IDNumber": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @NationalID), '') + N'"'
                + N',"residentInfoID_FK": "'  + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), '') + N'"'
                + N',"unitID": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @unitID), '') + N'"'
                + N',"userName": "'      + ISNULL(CONVERT(NVARCHAR(MAX),  @FullName), '') + N'"'
                + N',"buildingDetailsID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"amount": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @AmountForToChargeType), '') + N'"'
                + N',"deductListID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingPayementActive": "'           + ISNULL(CONVERT(NVARCHAR(MAX), 1), '') + N'"'
                + N',"BillChargeTypeID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @ToBillChargeTypeID_FK), '') + N'"'
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
                , @NewID2
                , @entryData
                , @Note
            );


           

            IF @tc = 0 COMMIT TRANSACTION;


           

            SELECT 1 AS IsSuccessful, N'تم تنفيذ التسوية المالية بنجاح' AS Message_;
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