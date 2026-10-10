
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
            WHEN @Action IN (N'HOUSINGEXIT', N'EDITHOUSINGEXIT')
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


            EXEC Housing.GenerateExitRentBills
                  @Action = N'GENERATE'
                , @ResidentInfoID = @ResidentInfoID_BIGINT
                , @GeneralNo = @GeneralNo_BIGINT
                , @BuildingDetailsID = @BuildingDetailsID_BIGINT
                , @OccupentDate = @OccupentDate_DATE
                , @ExitDate = @ExitDate_DATE
                , @IdaraID = @IdaraID_INT
                , @EntryData = @entryData
                , @HostName = @hostName;


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

            EXEC [Housing].[GenerateExitRentBills]
      @Action            = N'CANCEL'
    , @ResidentInfoID    = @ResidentInfoID_BIGINT
    , @GeneralNo         = @GeneralNo_BIGINT
    , @BuildingDetailsID = @BuildingDetailsID_BIGINT
    , @OccupentDate      = @OccupentDate_DATE
    , @ExitDate          = @ExitDate_DATE
    , @IdaraID           = @IdaraID_INT
    , @EntryData         = @entryData
    , @HostName          = @hostName;

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
