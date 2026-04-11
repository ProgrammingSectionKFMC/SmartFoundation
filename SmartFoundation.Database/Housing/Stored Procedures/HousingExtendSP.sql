
CREATE PROCEDURE [Housing].[HousingExtendSP] 
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
    , @buildingDetailsNo                    NVARCHAR(1000)  = NULL
    , @AssignPeriodID                       NVARCHAR(1000)  = NULL
    , @LastActionID                         NVARCHAR(1000)  = NULL
    , @LastActionTypeID                     NVARCHAR(1000)  = NULL
    , @Notes                                NVARCHAR(1000)  = NULL
    , @BuildingActionTypeCases              NVARCHAR(1000)  = NULL
    , @ExtendLetterNo                       NVARCHAR(1000)  = NULL
    , @ExtendLetterDate                     NVARCHAR(1000)  = NULL
    , @ExtendStartDate                      NVARCHAR(1000)  = NULL
    , @ExtendEndDate                        NVARCHAR(1000)  = NULL
    , @ExtendTypeID                         NVARCHAR(1000)  = NULL
    , @InsuranceAmount                      NVARCHAR(1000)  = NULL
    , @Remaining                            NVARCHAR(1000)  = NULL
    , @InsuranceAmountWithRemaining         NVARCHAR(1000)  = NULL
    , @ExtendInsuranceNo                    NVARCHAR(1000)  = NULL
    , @ExtendInsuranceDate                  NVARCHAR(1000)  = NULL
    , @ExtendInsuranceType                  NVARCHAR(1000)  = NULL
    , @ExtendInsuranceNote                  NVARCHAR(1000)  = NULL
    , @ExtendInsuranceTypeID                NVARCHAR(1000)  = NULL
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
        , @Note  NVARCHAR(MAX) = NULL
        , @NewID1 BIGINT = NULL
        , @Note1  NVARCHAR(MAX) = NULL;

    -- تحويلات رقمية آمنة
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(@idaraID_FK, ''));

    --DECLARE @buildingDetailsNo nvarchar(200) 
    --set @buildingDetailsNo = (select b.buildingDetailsNo from Housing.V_GetGeneralListForBuilding b where b.buildingDetailsID = @buildingDetailsID);

   
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

   


         IF @Action IN(N'HOUSINGEXTEND',N'EditExtend',N'SendExtendToFinance',N'ApproveExtend')
        BEGIN
         
            IF NULLIF(LTRIM(RTRIM(@ExtendStartDate)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يجب كتابة تاريخ بداية الامهال', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@ExtendEndDate)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يجب كتابة تاريخ نهاية الامهال', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@ExtendLetterNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يجب كتابة رقم وثيقة الموافقة على الامهال', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@ExtendLetterDate)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يجب كتابة تاريخ وثيقة الموافقة على الامهال', 1;
            END

             IF cast(@ExtendStartDate as date) >= cast(@ExtendEndDate as date)
            BEGIN
                ;THROW 50001, N'يجب ان يكون تاريخ نهاية الامهال اكبر من تاريخ بداية الامهال', 1;
            END

        END

        

     

        ----------------------------------------------------------------
        -- HOUSINGEXTEND
        ----------------------------------------------------------------
        IF @Action = N'HOUSINGEXTEND'
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
            ) Not in (2)
            BEGIN
                ;THROW 50001, N'المستفيد غير مؤهل للامهال او تم امهاله مسبقا', 1;
            END



            Declare @buildingActionTypeID_FK INT

            select 
            @buildingActionTypeID_FK =
            case 
            when w.LastActionTypeID = 2  then 48
            when w.LastActionTypeID = 48  then 49 
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
                , @ExtendTypeID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في انشاء طلب الامهال', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في انشاء طلب الامهال - Identity', 1; -- برمجي
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
                , N'HOUSINGEXTEND'
                , @ActionID
                , @entryData
                , @Note
            );
            

            SELECT 1 AS IsSuccessful, N'تم انشاء طلب الامهال بنجاح' AS Message_;
            RETURN;
        END


      
        ----------------------------------------------------------------
        -- EDITHOUSINGEXTEND
        ----------------------------------------------------------------
        ELSE IF @Action = N'EDITHOUSINGEXTEND'
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
            ) Not in (48)
            BEGIN
                ;THROW 50001, N'لايمكن تعديل الطلب', 1;
            END




            


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
                  50
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
                , @ExtendTypeID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل طلب الامهال', 1; -- برمجي
            END



             SET @NewID = SCOPE_IDENTITY();


            
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
                  48
                , @residentInfoID
                , @GeneralNo
                , @ExtendLetterNo
                , @ExtendLetterDate
                , @buildingDetailsID
                , @buildingDetailsNo
                , 1
                , @Notes
                , @NewID
                , @ExtendStartDate
                , @ExtendEndDate
                , @ExtendTypeID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل طلب الامهال', 1; -- برمجي
            END


            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل طلب الامهال - Identity', 1; -- برمجي
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
                , N'EDITHOUSINGEXTEND'
                , @ActionID
                , @entryData
                , @Note
            );
            

            SELECT 1 AS IsSuccessful, N'تم تعديل طلب الامهال بنجاح' AS Message_;
            RETURN;
        END

        
        ----------------------------------------------------------------
        -- CANCELHOUSINGEXTEND
        ----------------------------------------------------------------
        ELSE IF @Action = N'CANCELHOUSINGEXTEND'
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
            ) Not in (48)
            BEGIN
                ;THROW 50001, N'لايمكن الغاء الطلب', 1;
            END




            


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
                  50
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
                , @ExtendTypeID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في الغاء طلب الامهال', 1; -- برمجي
            END



             SET @NewID = SCOPE_IDENTITY();


            
                INSERT INTO  Housing.BuildingAction
            (
                 buildingActionTypeID_FK, buildingStatusID_FK, residentInfoID_FK, generalNo_FK, buildingPaymentTypeID_FK, buildingDetailsID_FK, buildingDetailsNo, buildingActionFromDate, 
               buildingActionToDate, buildingActionDate, buildingActionDate2, buildingActionDecisionNo, buildingActionDecisionDate, fromDSD_FK, toDSD_FK, buildingActionFromSourceID_FK, buildingActionToSourceID_FK, 
               buildingActionNote, buildingActionExtraText1, buildingActionExtraText2, buildingActionExtraText3, buildingActionExtraText4, buildingActionExtraDate1, buildingActionExtraDate2, buildingActionExtraDate3, 
               buildingActionExtraFloat1, buildingActionExtraFloat2, buildingActionExtraInt1, buildingActionExtraInt2, buildingActionExtraInt3, buildingActionExtraInt4, buildingActionExtraType1, buildingActionExtraType2, 
               buildingActionExtraType3, buildingActionActive, buildingActionParentID, CustdyRecord, AssignPeriodID_FK, IdaraId_FK, entryData, hostName

            )
            
            

            SELECT Top(1)
                 buildingActionTypeID_FK, buildingStatusID_FK, residentInfoID_FK, generalNo_FK, buildingPaymentTypeID_FK, buildingDetailsID_FK, buildingDetailsNo, buildingActionFromDate, 
               buildingActionToDate, buildingActionDate, buildingActionDate2, buildingActionDecisionNo, buildingActionDecisionDate, fromDSD_FK, toDSD_FK, buildingActionFromSourceID_FK, buildingActionToSourceID_FK, 
               buildingActionNote, buildingActionExtraText1, buildingActionExtraText2, buildingActionExtraText3, buildingActionExtraText4, buildingActionExtraDate1, buildingActionExtraDate2, buildingActionExtraDate3, 
               buildingActionExtraFloat1, buildingActionExtraFloat2, buildingActionExtraInt1, buildingActionExtraInt2, buildingActionExtraInt3, buildingActionExtraInt4, buildingActionExtraType1, buildingActionExtraType2, 
               buildingActionExtraType3, buildingActionActive, @NewID, CustdyRecord, AssignPeriodID_FK, @idaraID_FK, @entryData, @hostName
            FROM Housing.fn_BuildingAction_ChainToRoot(@NewID) r
            WHERE R.residentInfoID_FK = @residentInfoID and r.buildingActionTypeID_FK = 2
            ORDER BY buildingActionID;
                 


            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في الغاء طلب الامهال', 1; -- برمجي
            END


            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في الغاء طلب الامهال - Identity', 1; -- برمجي
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
                , N'CANCELHOUSINGEXTEND'
                , @ActionID
                , @entryData
                , @Note
            );
            

            SELECT 1 AS IsSuccessful, N'تم الغاء طلب الامهال بنجاح' AS Message_;
            RETURN;
        END

             
             

        ----------------------------------------------------------------
        -- SENDHOUSINGEXTENDTOFINANCE
        ----------------------------------------------------------------
        IF @Action = N'SENDHOUSINGEXTENDTOFINANCE'
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
            ) Not in (48)
            BEGIN
                ;THROW 50001, N'تم ارسال الطلب للتدقيق المالي مسبقا', 1;
            END




            


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
                  51
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
                , @ExtendTypeID
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
                , N'SENDHOUSINGEXTENDTOFINANCE'
                , @ActionID
                , @entryData
                , @Note
            );
            

            SELECT 1 AS IsSuccessful, N'تم ارسال طلب الامهال للتدقيق المالي بنجاح' AS Message_;
            RETURN;
        END


        
        ----------------------------------------------------------------
        -- ApproveExtend
        ----------------------------------------------------------------
        ELSE IF @Action = N'ApproveExtend'
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
            ) Not in (52,61)
            BEGIN
                ;THROW 50001, N'لايمكن اعتماد الطلب', 1;
            END


            if exists 
            (select 1 
            from Housing.V_WaitingList w
            inner join Housing.ExtendReasonType r on w.LastActionExtendReasonTypeID = r.ExtendReasonTypeID
            where w.ActionID = @ActionID 
            and r.InsuranceRequired = 1 and w.LastActionTypeID <> 61
            )
            BEGIN
                ;THROW 50001, N'تنفيذ التأمين الاحترازي مطلوب', 1;
            END

            


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
                  24
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
                , @ExtendTypeID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اعتماد الامهال', 1; -- برمجي
            END



             SET @NewID = SCOPE_IDENTITY();


            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اعتماد الامهال - Identity', 1; -- برمجي
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
                , N'ApproveExtend'
                , @ActionID
                , @entryData
                , @Note
            );
            

            SELECT 1 AS IsSuccessful, N'تم اعتماد طلب الامهال بنجاح' AS Message_;
            RETURN;
        END


         ----------------------------------------------------------------
        -- EXTENDINSURANCE
        ----------------------------------------------------------------
        ELSE IF @Action = N'EXTENDINSURANCE'
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
            ) Not in (52)
            BEGIN
                ;THROW 50001, N'لايمكن اعتماد الطلب لعدم انتهاء مرحلة التدقيق المالي', 1;
            END


            if exists 
            (select 1 
            from Housing.V_WaitingList w
            inner join Housing.ExtendReasonType r on w.LastActionExtendReasonTypeID = r.ExtendReasonTypeID
            where w.ActionID = @ActionID 
            and r.InsuranceRequired = 1 and w.LastActionTypeID = 61
            )
            BEGIN
                ;THROW 50001, N'تم تنفيذ التأمين الاحترازي مسبقا', 1;
            END

            if exists 
            (select 1 
            from Housing.V_WaitingList w
            inner join Housing.ExtendReasonType r on w.LastActionExtendReasonTypeID = r.ExtendReasonTypeID
            where w.ActionID = @ActionID 
            and r.InsuranceRequired = 0
            )
            BEGIN
                ;THROW 50001, N'تنفيذ التأمين الاحترازي غير مطلوب', 1;
            END



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
                  61
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
                , @ExtendTypeID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تنفيذ التامين الاحترازي', 1; -- برمجي
            END



             SET @NewID = SCOPE_IDENTITY();


            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تنفيذ التامين الاحترازي - Identity', 1; -- برمجي
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
                , N'ApproveExtend'
                , @NewID
                , @entryData
                , @Note
            );


               INSERT INTO  Housing.ExtendInsurance
            (
                  [buildingActionID_FK]
                 ,[residentInfoID_FK]
                 ,[buildingDetailsID_FK]
                 ,[buildingDetailsNo]
                 ,[InsuranceAmount]
                 ,[Remaining]
                 ,[InsuranceAmountWithRemaining]
                 ,[ExtendInsuranceNo]
                 ,[ExtendInsuranceDate]
                 ,[ExtendInsuranceType]
                 ,[ExtendInsuranceNote]
                 ,[ExtendInsuranceActive]
                 ,[IdaraId_FK]
                 ,[entryDate]
                 ,[entryData]
                 ,[hostName]
            )
            
             VALUES
            (
                  @NewID
                , @residentInfoID
                , @buildingDetailsID
                , @buildingDetailsNo
                , @InsuranceAmount
                , @Remaining
                , @InsuranceAmountWithRemaining
                , @ExtendInsuranceNo
                , @ExtendInsuranceDate
                , @ExtendInsuranceType
                , @ExtendInsuranceNote
                , 1
                , @IdaraID_INT
                , GETDATE()
                , @entryData
                , @hostName
            );


            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تنفيذ التامين الاحترازي', 1; -- برمجي
            END



             SET @NewID1 = SCOPE_IDENTITY();


            SET @NewID1 = SCOPE_IDENTITY();
            IF @NewID1 IS NULL OR @NewID1 <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تنفيذ التامين الاحترازي - Identity', 1; -- برمجي
            END

     
            SET @Note1 = N'{'
                + N'"ExtendInsuranceID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID1), '') + N'"'
                + N',"buildingActionID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"InsuranceAmount": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @InsuranceAmount), '') + N'"'
                + N',"Remaining": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Remaining), '') + N'"'
                + N',"InsuranceAmountWithRemaining": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @InsuranceAmountWithRemaining), '') + N'"'
                + N',"ExtendInsuranceNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendInsuranceNo), '') + N'"'
                + N',"ExtendInsuranceDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendInsuranceDate), '') + N'"'
                + N',"ExtendInsuranceType": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendInsuranceType), '') + N'"'
                + N',"ExtendInsuranceActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"ExtendInsuranceNote": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendInsuranceNote), '') + N'"'
                + N',"IdaraId_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), '') + N'"'
                + N',"entryDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
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
                  N'[Housing].[ExtendInsurance]'
                , N'EXTENDINSURANCE'
                , @NewID1
                , @entryData
                , @Note1
            );


            

            SELECT 1 AS IsSuccessful, N'تم اعتماد طلب الامهال بنجاح' AS Message_;
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