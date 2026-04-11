
CREATE PROCEDURE [Housing].[HousingExitSP] 
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
            ) Not in (54,59,60)
            BEGIN
                ;THROW 50001, N'لايمكن تعديل الطلب', 1;
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
            ) Not in (54)
            BEGIN
                ;THROW 50001, N'لايمكن الغاء الطلب', 1;
            END



            update Housing.Bills set BillActive = 0 
            where residentInfoID_FK = @residentInfoID and buildingDetailsID = @buildingDetailsID and BillChargeTypeID_FK in (5)

            update Housing.Bills set BillActive = 0 
            where residentInfoID_FK = @residentInfoID and buildingDetailsID = @buildingDetailsID and BillChargeTypeID_FK in (2,3,4) and BillTypeID_FK = 3

            update Housing.MeterRead set meterReadActive = 0
            where residentInfoID_FK = @residentInfoID and buildingDetailsID = @buildingDetailsID and meterReadTypeID_FK = 3
            


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
               buildingActionExtraType3, buildingActionActive, buildingActionParentID, CustdyRecord, AssignPeriodID_FK, IdaraId_FK, entryData, hostName

            )
            
            

            SELECT Top(1)
                 buildingActionTypeID_FK, buildingStatusID_FK, residentInfoID_FK, generalNo_FK, buildingPaymentTypeID_FK, buildingDetailsID_FK, buildingDetailsNo, buildingActionFromDate, 
               buildingActionToDate, buildingActionDate, buildingActionDate2, buildingActionDecisionNo, buildingActionDecisionDate, fromDSD_FK, toDSD_FK, buildingActionFromSourceID_FK, buildingActionToSourceID_FK, 
               buildingActionNote, buildingActionExtraText1, buildingActionExtraText2, buildingActionExtraText3, buildingActionExtraText4, buildingActionExtraDate1, buildingActionExtraDate2, buildingActionExtraDate3, 
               buildingActionExtraFloat1, buildingActionExtraFloat2, buildingActionExtraInt1, buildingActionExtraInt2, buildingActionExtraInt3, buildingActionExtraInt4, buildingActionExtraType1, buildingActionExtraType2, 
               buildingActionExtraType3, buildingActionActive, @NewID, CustdyRecord, AssignPeriodID_FK, @idaraID_FK, @entryData, @hostName
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
            

            SELECT 1 AS IsSuccessful, N'تم ارسال طلب الامهال للتدقيق المالي بنجاح' AS Message_;
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



            Declare @buildingActionTypeID_FKForMeterRead int

            IF exists (select 1 
            from Housing.MeterForBuilding m 
            where m.buildingDetailsID_FK = @buildingDetailsID 
            and m.IdaraID_FK = @idaraID_FK 
            and m.meterForBuildingActive = 1)
            begin

            set @buildingActionTypeID_FKForMeterRead = 59

            end
            else
            begin

            set @buildingActionTypeID_FKForMeterRead = 60

            end




            if(@BillsID is null)
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

            update Housing.Bills set BillActive = 0 where BillsID = @BillsID

             IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل غرامات لطلب الاخلاء', 1; -- برمجي
            END


              INSERT INTO [DATACORE].[Housing].[Bills]
            (
                  [residentInfoID_FK]
                 ,[buildingDetailsID]
                 ,[BillChargeTypeID_FK]
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