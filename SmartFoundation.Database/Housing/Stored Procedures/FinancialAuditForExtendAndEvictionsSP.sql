
CREATE PROCEDURE [Housing].[FinancialAuditForExtendAndEvictionsSP] 
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

            IF 
            (
               @buildingActionTypeID_FK = 9999 
            )
            BEGIN
                ;THROW 50001, N'حصل خطأ ما building Action Type', 1;
            END

          

            IF(@buildingActionTypeID_FK = 52)
            begin


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
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
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
                , @LastActionExtendReasonTypeID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            
            IF @@ROWCOUNT = 0
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
                , N'ASSIGNHOUSE'
                , @ActionID
                , @entryData
                , @Note
            );
            

            SELECT 1 AS IsSuccessful, N'تم اعتماد التدقيق المالي للامهال بنجاح' AS Message_;
            RETURN;

            END



            ELSE IF(@buildingActionTypeID_FK = 58)
            begin


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
                , ExtendReasonTypeID_FK
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
                , @LastActionExtendReasonTypeID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            
            IF @@ROWCOUNT = 0
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
                , N'ASSIGNHOUSE'
                , @ActionID
                , @entryData
                , @Note
            );
            

            SELECT 1 AS IsSuccessful, N'تم اعتماد التدقيق المالي للاخلاء بنجاح' AS Message_;
            RETURN;

            END
            ELSE
        BEGIN

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


              DECLARE @FullRemining_Decimal DECIMAL(18,2);

    SET @FullRemining_Decimal = TRY_CONVERT(DECIMAL(18,2), @FullRemining);
    
    IF @FullRemining_Decimal IS NULL
    BEGIN
        ;THROW 50001, N'قيمة المبلغ غير صحيحة', 1;
    END

               IF @Amount_Decimal > @FullRemining_Decimal
             BEGIN
             declare @msg nvarchar(1000)
             set @msg = N'المبلغ المدخل اكبر من المبلغ المتوفر في هذه الخدمه : ' + CONVERT(NVARCHAR(100), @FullRemining_Decimal)
                 ;THROW 50001, @msg, 1;
             END

               IF @Amount_Decimal = 0.00
             BEGIN
              declare @msg3 nvarchar(1000)
             set @msg3 = N'يجب ان يكون المبلغ اكبر من صفر ';
                 ;THROW 50001, @msg3, 1;
             END


         
            Declare @AvailableAmountForToChargeType decimal(18,2);
            set @AvailableAmountForToChargeType = 
            (select TRY_CONVERT(DECIMAL(18,2),s.Remaining) 
               FROM Housing.BillChargeType bt
               LEFT JOIN Housing.V_SumBillsTotalPriceAndTotalPaidForResident s
                      ON s.BillChargeTypeID = bt.BillChargeTypeID
                     AND s.residentInfoID = @residentInfoID
                     AND (s.buildingDetailsID = @buildingDetailsID OR s.buildingDetailsID IS NULL)
               LEFT JOIN Housing.V_GetGeneralListForBuilding b
                      ON s.buildingDetailsID = b.buildingDetailsID
                      where bt.BillChargeTypeID = @ToBillChargeTypeID_FK
             )

                  IF @Amount_Decimal > @AvailableAmountForToChargeType
             BEGIN
             declare @msg1 nvarchar(1000)
             set @msg1 = N'المبلغ المدخل اكبر من المبلغ المطلوب في الخدمه المعالجة والمبلغ المطلوب لسدادها هو : ' + CONVERT(NVARCHAR(100), @AvailableAmountForToChargeType)
                 ;THROW 50001, @msg1, 1;
             END

                 


              IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) Not in (51,57)
            BEGIN
                ;THROW 50001, N'تم انهاء اجراءات الامهال / الاخلاء مسبقا', 1;
            END

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