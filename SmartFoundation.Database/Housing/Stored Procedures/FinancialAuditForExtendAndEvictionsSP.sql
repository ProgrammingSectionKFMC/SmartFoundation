
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
            
    select 
    @NationalID               = w.NationalID,
    @GeneralNo                = w.GeneralNo,
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
