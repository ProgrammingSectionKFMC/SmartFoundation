
CREATE PROCEDURE [Housing].[WaitingListByResidentSP] 
(
      @Action                       NVARCHAR(200)
    , @ActionID                     BIGINT          = NULL
    , @residentInfoID_FK            NVARCHAR(100)   = NULL
    , @NationalID                   NVARCHAR(100)   = NULL
    , @GeneralNo                    NVARCHAR(100)   = NULL
    , @buildingActionDecisionNo     NVARCHAR(1000)  = NULL
    , @buildingActionDecisionDate   NVARCHAR(1000)  = NULL
    , @WaitingClassID               NVARCHAR(1000)  = NULL
    , @WaitingOrderTypeID           NVARCHAR(1000)  = NULL
    , @ActionTypeID                 NVARCHAR(1000)  = NULL
    , @Notes                        NVARCHAR(1000)  = NULL
    , @NewIdaraForMoveWaitingList   NVARCHAR(1000)  = NULL
    , @idaraID_FK                   NVARCHAR(10)    = NULL
    , @entryData                    NVARCHAR(20)    = NULL
    , @hostName                     NVARCHAR(200)   = NULL
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

        IF @Action IN(N'INSERTWAITINGLIST',N'UPDATEWAITINGLIST')
        BEGIN
       
            IF NULLIF(LTRIM(RTRIM(@residentInfoID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات المستفيد - resident ID', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@GeneralNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات المستفيد - GN', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@NationalID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات المستفيد - @NationalID', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@buildingActionDecisionNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'رقم القرار مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@buildingActionDecisionDate)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ القرار مطلوب', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@WaitingClassID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'فئة قائمة الانتظار مطلوبة', 1;
            END


             IF NULLIF(LTRIM(RTRIM(@WaitingOrderTypeID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع فئة الانتظار مطلوبة', 1;
            END
        END


        IF @Action IN(N'INSERTOCCUBENTLETTER',N'UPDATEOCCUBENTLETTER')
        BEGIN
       
            IF NULLIF(LTRIM(RTRIM(@residentInfoID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات المستفيد - resident ID', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@GeneralNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات المستفيد - GN', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@NationalID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات المستفيد - @NationalID', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@buildingActionDecisionNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'رقم القرار مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@buildingActionDecisionDate)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ القرار مطلوب', 1;
            END

            -- IF NULLIF(LTRIM(RTRIM(@WaitingClassID)), N'') IS NULL
            --BEGIN
            --    ;THROW 50001, N'فئة قائمة الانتظار مطلوبة', 1;
            --END


            -- IF NULLIF(LTRIM(RTRIM(@WaitingOrderTypeID)), N'') IS NULL
            --BEGIN
            --    ;THROW 50001, N'نوع فئة الانتظار مطلوبة', 1;
            --END
        END



         IF @Action IN(N'MOVEWAITINGLIST',N'DELETERESIDENTALLWAITINGLIST')
        BEGIN
            --IF NULLIF(LTRIM(RTRIM(@ActionID)), N'') IS NULL
            --BEGIN
            --    ;THROW 50001, N'يوجد خطأ بجلب بيانات سجل الانتظار - Action ID', 1;
            --END

            IF NULLIF(LTRIM(RTRIM(@residentInfoID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات المستفيد - resident ID', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@GeneralNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات المستفيد - GN', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@NationalID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات المستفيد - @NationalID', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@buildingActionDecisionNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'رقم القرار مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@buildingActionDecisionDate)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ القرار مطلوب', 1;
            END

            -- IF NULLIF(LTRIM(RTRIM(@WaitingClassID)), N'') IS NULL
            --BEGIN
            --    ;THROW 50001, N'فئة قائمة الانتظار مطلوبة', 1;
            --END


            -- IF NULLIF(LTRIM(RTRIM(@WaitingOrderTypeID)), N'') IS NULL
            --BEGIN
            --    ;THROW 50001, N'نوع فئة الانتظار مطلوبة', 1;
            --END
        END

        ----------------------------------------------------------------
        -- INSERTWAITINGLIST
        ----------------------------------------------------------------
        IF @Action = N'INSERTWAITINGLIST'
        BEGIN


          IF
              (
            (
                SELECT top(1) W.LastActionTypeID
                FROM  Housing.V_MoveWaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  and w.IdaraId = @idaraID_FK
                  order by w.ActionID desc
            ) is null
            or
            (
                SELECT top(1) W.LastActionTypeID
                FROM  Housing.V_MoveWaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  and w.IdaraId = @idaraID_FK
                  order by w.ActionID desc
            ) = 33
            )
            BEGIN
                ;THROW 50001, N'لايمكن ادراج سجل انتظار جديد للمستفيد لوجود طلب نقل له الى ادارة اخرى', 1;
            END

        

            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.WaitingClassID = @WaitingClassID
            )
            BEGIN
                ;THROW 50001, N'يوجد سجل انتظار مدرج للمستفيد بالنظام بنفس الفئة', 1;
            END

        
        
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in(19)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب التقاعد', 1;
            END


            
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in (53)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب الفصل', 1;
            END


             IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.V_GetFullResidentDetails w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.IdaraID = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'ملف المستفيد ليس في ادارتك حاليا', 1;
            END


            INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                , buildingActionExtraType1
                , buildingActionExtraType2
                , buildingActionActive
                , buildingActionNote
                , IdaraId_FK
                , entryData
                , hostName
            )
            VALUES
            (
                  1
                , @residentInfoID_FK
                , @GeneralNo
                , @buildingActionDecisionNo
                , @buildingActionDecisionDate
                , @WaitingClassID
                , @WaitingOrderTypeID
                , 1
                , @Notes
                , @IdaraID_INT
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "1"'
                + N',"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID_FK), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingActionDecisionNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionNo), '') + N'"'
                + N',"buildingActionDecisionDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionDate), '') + N'"'
                + N',"buildingActionExtraType1": "' + ISNULL(CONVERT(NVARCHAR(MAX), @WaitingClassID), '') + N'"'
                + N',"buildingActionExtraType2": "' + ISNULL(CONVERT(NVARCHAR(MAX), @WaitingOrderTypeID), '') + N'"'
                + N',"buildingActionActive": "1"'
                + N',"buildingActionNote": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"IdaraId_FK": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                 + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                , N'INSERTWAITINGLIST'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم اضافة البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- UPDATEWAITINGLIST
        ----------------------------------------------------------------
        ELSE IF @Action = N'UPDATEWAITINGLIST'
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
            (
                SELECT top(1) W.LastActionTypeID
                FROM  Housing.V_MoveWaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  and w.IdaraId = @idaraID_FK
                  order by w.ActionID desc
            ) is null
            or
            (
                SELECT top(1) W.LastActionTypeID
                FROM  Housing.V_MoveWaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  and w.IdaraId = @idaraID_FK
                  order by w.ActionID desc
            ) = 33
            )
            BEGIN
                ;THROW 50001, N'لايمكن تعديل سجل انتظار جديد للمستفيد لوجود طلب نقل له الى ادارة اخرى', 1;
            END

            
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in(19)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب التقاعد', 1;
            END


            
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in (53)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب الفصل', 1;
            END


             IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.V_GetFullResidentDetails w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.IdaraID = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'ملف المستفيد ليس في ادارتك حاليا', 1;
            END


            UPDATE  Housing.BuildingAction
            SET

                  buildingActionDecisionNo      = ISNULL(@buildingActionDecisionNo, buildingActionDecisionNo)
                , buildingActionDecisionDate    = ISNULL(@buildingActionDecisionDate, buildingActionDecisionDate)
                --, buildingActionExtraType1      = ISNULL(@WaitingClassID, buildingActionExtraType1)
                , buildingActionExtraType2      = ISNULL(@WaitingOrderTypeID, buildingActionExtraType2)
                , buildingActionNote            = ISNULL(@Notes, buildingActionNote)
                , IdaraId_FK                    = ISNULL(@IdaraID_INT, IdaraId_FK)
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)

                
            WHERE buildingActionID = @ActionID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1; -- برمجي/غير متوقع
            END

             SET @Note = N'{'
                + N'"buildingActionID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @ActionID), '') + N'"'
                + N',"buildingActionTypeID_FK": "1"'
                + N',"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID_FK), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingActionDecisionNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionNo), '') + N'"'
                + N',"buildingActionDecisionDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionDate), '') + N'"'
                + N',"buildingActionExtraType1": "' + ISNULL(CONVERT(NVARCHAR(MAX), @WaitingClassID), '') + N'"'
                + N',"buildingActionExtraType2": "' + ISNULL(CONVERT(NVARCHAR(MAX), @WaitingOrderTypeID), '') + N'"'
                + N',"buildingActionActive": "1"'
                + N',"buildingActionNote": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"IdaraId_FK": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                 + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                , N'UPDATEWAITINGLIST'
                , @ActionID
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم تحديث البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- DELETEWAITINGLIST (Soft Delete)
        ----------------------------------------------------------------
        ELSE IF @Action = N'DELETEWAITINGLIST'
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
            (
                SELECT top(1) W.LastActionTypeID
                FROM  Housing.V_MoveWaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  and w.IdaraId = @idaraID_FK
                  order by w.ActionID desc
            ) is null
            or
            (
                SELECT top(1) W.LastActionTypeID
                FROM  Housing.V_MoveWaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  and w.IdaraId = @idaraID_FK
                  order by w.ActionID desc
            ) = 33
            )
            BEGIN
                ;THROW 50001, N'لايمكن الغاء سجل انتظار جديد للمستفيد لوجود طلب نقل له الى ادارة اخرى', 1;
            END


            
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in(19)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب التقاعد', 1;
            END


            
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in (53)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب الفصل', 1;
            END


              IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.V_GetFullResidentDetails w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.IdaraID = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'ملف المستفيد ليس في ادارتك حاليا', 1;
            END



            UPDATE  Housing.BuildingAction
            SET
                  buildingActionActive = 0
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE buildingActionID = @ActionID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم حذف أي سجل', 1; -- برمجي/غير متوقع
            END
            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ActionID), '') + N'"'
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
                  N'[Housing].[BuildingClass]'
                , N'DELETEWAITINGLIST'
                , @ActionID
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم حذف البيانات بنجاح' AS Message_;
            RETURN;
        END


        ----------------------------------------------------------------
        -- INSERTOCCUBENTLETTER
        ----------------------------------------------------------------
        ELSE IF @Action = N'INSERTOCCUBENTLETTER'
        BEGIN

            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.IdaraId = @IdaraID_INT
                  AND w.ActionTypeID = 7
            )
            BEGIN
                ;THROW 50001, N'يوجد خطاب تسكين للمستفيد بالنظام بنفس الادارة', 1;
            END


              IF
              (
            (
                SELECT top(1) W.LastActionTypeID
                FROM  Housing.V_MoveWaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  and w.IdaraId = @idaraID_FK
                  order by w.ActionID desc
            ) is null
            or
            (
                SELECT top(1) W.LastActionTypeID
                FROM  Housing.V_MoveWaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  and w.IdaraId = @idaraID_FK
                  order by w.ActionID desc
            ) = 33
            )
            BEGIN
                ;THROW 50001, N'لايمكن ادراج خطاب تسكين جديد للمستفيد لوجود طلب نقل له الى ادارة اخرى', 1;
            END

        
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in(19)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب التقاعد', 1;
            END


            
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in (53)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب الفصل', 1;
            END


              IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.V_GetFullResidentDetails w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.IdaraID = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'ملف المستفيد ليس في ادارتك حاليا', 1;
            END


            INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                --, buildingActionExtraType1
                --, buildingActionExtraType2
                , buildingActionActive
                , buildingActionNote
                , IdaraId_FK
                , entryData
                , hostName
            )
            VALUES
            (
                  7
                , @residentInfoID_FK
                , @GeneralNo
                , @buildingActionDecisionNo
                , @buildingActionDecisionDate
                --, @WaitingClassID
                --, @WaitingOrderTypeID
                , 1
                , @Notes
                , @IdaraID_INT
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "7"'
                + N',"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID_FK), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingActionDecisionNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionNo), '') + N'"'
                + N',"buildingActionDecisionDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionDate), '') + N'"'
                --+ N',"buildingActionExtraType1": "' + ISNULL(CONVERT(NVARCHAR(MAX), @WaitingClassID), '') + N'"'
                --+ N',"buildingActionExtraType2": "' + ISNULL(CONVERT(NVARCHAR(MAX), @WaitingOrderTypeID), '') + N'"'
                + N',"buildingActionActive": "1"'
                + N',"buildingActionNote": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"IdaraId_FK": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                 + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                , N'INSERTOCCUBENTLETTER'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم اضافة البيانات بنجاح' AS Message_;
            RETURN;
        END

          ----------------------------------------------------------------
        -- UPDATEOCCUBENTLETTER
        ----------------------------------------------------------------
        ELSE IF @Action = N'UPDATEOCCUBENTLETTER'
        BEGIN
       
            IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.V_WaitingListByLetter w
                WHERE w.ActionID = @ActionID
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

              IF
              (
            (
                SELECT top(1) W.LastActionTypeID
                FROM  Housing.V_MoveWaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  and w.IdaraId = @idaraID_FK
                  order by w.ActionID desc
            ) is null
            or
            (
                SELECT top(1) W.LastActionTypeID
                FROM  Housing.V_MoveWaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  and w.IdaraId = @idaraID_FK
                  order by w.ActionID desc
            ) = 33
            )
            BEGIN
                ;THROW 50001, N'لايمكن ادراج خطاب تسكين جديد للمستفيد لوجود طلب نقل له الى ادارة اخرى', 1;
            END


            
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in(19)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب التقاعد', 1;
            END


            
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in (53)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب الفصل', 1;
            END


               IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.V_GetFullResidentDetails w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.IdaraID = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'ملف المستفيد ليس في ادارتك حاليا', 1;
            END



            UPDATE  Housing.BuildingAction
            SET

                  buildingActionDecisionNo      = ISNULL(@buildingActionDecisionNo, buildingActionDecisionNo)
                , buildingActionDecisionDate    = ISNULL(@buildingActionDecisionDate, buildingActionDecisionDate)
                --, buildingActionExtraType1      = ISNULL(@WaitingClassID, buildingActionExtraType1)
                --, buildingActionExtraType2      = ISNULL(@WaitingOrderTypeID, buildingActionExtraType2)
                , buildingActionNote            = ISNULL(@Notes, buildingActionNote)
                , IdaraId_FK                    = ISNULL(@IdaraID_INT, IdaraId_FK)
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)

                
            WHERE buildingActionID = @ActionID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1; -- برمجي/غير متوقع
            END

             SET @Note = N'{'
                + N'"buildingActionID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @ActionID), '') + N'"'
                + N',"buildingActionTypeID_FK": "7"'
                + N',"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID_FK), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingActionDecisionNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionNo), '') + N'"'
                + N',"buildingActionDecisionDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionDate), '') + N'"'
                --+ N',"buildingActionExtraType1": "' + ISNULL(CONVERT(NVARCHAR(MAX), @WaitingClassID), '') + N'"'
                --+ N',"buildingActionExtraType2": "' + ISNULL(CONVERT(NVARCHAR(MAX), @WaitingOrderTypeID), '') + N'"'
                + N',"buildingActionActive": "1"'
                + N',"buildingActionNote": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"IdaraId_FK": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                 + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                , N'UPDATEOCCUBENTLETTER'
                , @ActionID
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم تحديث البيانات بنجاح' AS Message_;
            RETURN;
        END




        ----------------------------------------------------------------
        -- DELETEOCCUBENTLETTER (Soft Delete)
        ----------------------------------------------------------------
        ELSE IF @Action = N'DELETEOCCUBENTLETTER'
        BEGIN

        
             IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.V_WaitingListByLetter w
                WHERE w.ActionID = @ActionID
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

              IF
  (
(
    SELECT top(1) W.LastActionTypeID
    FROM  Housing.V_MoveWaitingList w
    WHERE w.residentInfoID = @residentInfoID_FK
      and w.IdaraId = @idaraID_FK
      order by w.ActionID desc
) is null
or
(
    SELECT top(1) W.LastActionTypeID
    FROM  Housing.V_MoveWaitingList w
    WHERE w.residentInfoID = @residentInfoID_FK
      and w.IdaraId = @idaraID_FK
      order by w.ActionID desc
) = 33
)
BEGIN
    ;THROW 50001, N'لايمكن ادراج خطاب تسكين جديد للمستفيد لوجود طلب نقل له الى ادارة اخرى', 1;
END



            
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in(19)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب التقاعد', 1;
            END


            
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in (53)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب الفصل', 1;
            END


            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.V_GetFullResidentDetails w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.IdaraID = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'ملف المستفيد ليس في ادارتك حاليا', 1;
            END


            UPDATE  Housing.BuildingAction
            SET
                  buildingActionActive = 0
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE buildingActionID = @ActionID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم حذف أي سجل', 1; -- برمجي/غير متوقع
            END
            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ActionID), '') + N'"'
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
                  N'[Housing].[BuildingClass]'
                , N'DELETEOCCUBENTLETTER'
                , @ActionID
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم حذف البيانات بنجاح' AS Message_;
            RETURN;
        END

          ----------------------------------------------------------------
        -- MOVEWAITINGLIST
        ----------------------------------------------------------------
        ELSE IF @Action = N'MOVEWAITINGLIST'
        BEGIN

            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_MoveWaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK and w.LastActionID is null
                  
            )
            BEGIN
                ;THROW 50001, N'يوجد طلبات نقل سجلات انتظار تحت الاجراء بالنظام للمستفيد', 1;
            END

             IF NOT EXISTS
            (
                SELECT 1
                from Housing.V_WaitingList w
                where w.residentInfoID = @residentInfoID_FK
                and w.WaitingClassID in (1,2,3,4,11) and w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'لايوجد سجلات انتظار بالنظام للمستفيد يمكن نقلها', 1;
            END


             IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID = 32
            )
            BEGIN
                ;THROW 50001, N'يوجد طلبات نقل سجلات انتظار تحت الاجراء بالنظام للمستفيد', 1;
            END


            
             IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in(2,24,27,32,33,38,39,40,41,43,45,46,47,48,49,50,51,52)
            )
            BEGIN
                ;THROW 50001, N'يوجد سجلات انتظار تحت الاجراء بالنظام للمستفيد', 1;
            END

             IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.V_GetFullResidentDetails w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.IdaraID = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'ملف المستفيد ليس في ادارتك حاليا', 1;
            END

            
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in(19)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب التقاعد', 1;
            END


            
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in (53)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب الفصل', 1;
            END


             IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.V_GetFullResidentDetails w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.IdaraID = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'ملف المستفيد ليس في ادارتك حاليا', 1;
            END

        

            INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                , buildingActionActive
                , buildingActionNote
                , buildingActionExtraInt1
                
                , IdaraId_FK
                , entryData
                , hostName
            )

              VALUES
            (
                  32
                , @residentInfoID_FK
                , @GeneralNo
                , @buildingActionDecisionNo
                , @buildingActionDecisionDate
                , 1
                , @Notes
                , @NewIdaraForMoveWaitingList
                , @IdaraID_INT
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "34"'
                + N',"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID_FK), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingActionDecisionNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionNo), '') + N'"'
                + N',"buildingActionDecisionDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionDate), '') + N'"'
                --+ N',"buildingActionExtraType1": "' + ISNULL(CONVERT(NVARCHAR(MAX), @WaitingClassID), '') + N'"'
                --+ N',"buildingActionExtraType2": "' + ISNULL(CONVERT(NVARCHAR(MAX), @WaitingOrderTypeID), '') + N'"'
                + N',"buildingActionActive": "1"'
                + N',"buildingActionNote": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionExtraInt1": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewIdaraForMoveWaitingList), '') + N'"'
                + N',"buildingActionParentID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ActionID), '') + N'"'
                + N',"IdaraId_FK": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                 + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                , N'MOVEWAITINGLIST'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم اضافة البيانات بنجاح' AS Message_;
            RETURN;
        END



        ----------------------------------------------------------------
        -- DELETEMOVEWAITINGLIST (Soft Delete)
        ----------------------------------------------------------------
        ELSE IF @Action = N'DELETEMOVEWAITINGLIST'
        BEGIN

        
            IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.V_MoveWaitingList w
                WHERE w.ActionID = @ActionID
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END


             IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.V_MoveWaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK and w.LastActionID is null and w.IdaraId = @idaraID_FK
                  
            )
            BEGIN
                ;THROW 50001, N'تم اتخاذ اجراء للطلب لايمكن الغائه', 1;
            END


            
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in(19)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب التقاعد', 1;
            END


            
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in (53)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب الفصل', 1;
            END


              IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.V_GetFullResidentDetails w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.IdaraID = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'ملف المستفيد ليس في ادارتك حاليا', 1;
            END



            -- IF EXISTS
            --(
            --    SELECT 1
            --    FROM  Housing.V_MoveWaitingList w
            --    WHERE  w.ActionID = @ActionID and w.ActionStatus <> N'تحت الإجراء'
            --)
            --BEGIN
            --    ;THROW 50001, N'تم اتخاذ اجراء لهذا الطلب لايمكن الغائه', 1;
            --END


             INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                , buildingActionActive
                , buildingActionNote
                , buildingActionExtraInt1
                , buildingActionParentID
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  35
                , @residentInfoID_FK
                , @GeneralNo
                , @buildingActionDecisionNo
                , @buildingActionDecisionDate
                , 1
                , @Notes
                , @NewIdaraForMoveWaitingList
                , @ActionID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );
            
            --select 
            --35,
            --w.residentInfoID,
            --w.GeneralNo,
            --w.ActionDecisionNo,
            --w.ActionDecisionDate,
            --w.WaitingClassID,
            --w.WaitingOrderTypeID,
            --1,
            --@Notes,
            --@NewIdaraForMoveWaitingList,
            --w.ActionID,
            --w.IdaraId,
            --@entryData,
            --@hostName
            
            --from Housing.V_WaitingList w
            --where w.residentInfoID = @residentInfoID_FK
            --and w.LastActionTypeID = 32
            
            --VALUES
            --(
            --      35
            --    , @residentInfoID_FK
            --    , @GeneralNo
            --    , @buildingActionDecisionNo
            --    , @buildingActionDecisionDate
            --    , @WaitingClassID
            --    , @WaitingOrderTypeID
            --    , 1
            --    , @Notes
            --    , @NewIdaraForMoveWaitingList
            --    , @ActionID
            --    , @IdaraID_INT
            --    , @entryData
            --    , @hostName
            --);

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في الغاء البيانات', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في الغاء البيانات - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ActionID), '') + N'"'
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
                , N'DELETEOCCUBENTLETTER'
                , @ActionID
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم حذف البيانات بنجاح' AS Message_;
            RETURN;
        END







             ----------------------------------------------------------------
        -- DELETERESIDENTALLWAITINGLIST
        ----------------------------------------------------------------
        ELSE IF @Action = N'DELETERESIDENTALLWAITINGLIST'
        BEGIN

            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_MoveWaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK and w.LastActionID is null
                  
            )
            BEGIN
                ;THROW 50001, N'يوجد طلبات نقل سجلات انتظار تحت الاجراء بالنظام للمستفيد', 1;
            END


             IF NOT EXISTS
            (
                SELECT 1
                from Housing.V_WaitingList w
                where w.residentInfoID = @residentInfoID_FK
                and w.WaitingClassID in (1,2,3,4,11) and w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'لايوجد سجلات انتظار بالنظام للمستفيد يمكن نقلها', 1;
            END


             IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in(2,24,27,32,33,38,39,40,41,43,45,46,47,48,49,50,51,52)
            )
            BEGIN
                ;THROW 50001, N'يوجد سجلات انتظار تحت الاجراء بالنظام للمستفيد', 1;
            END

            
             IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingListByLetter w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in(2,24,27,32,33,38,39,40,41,43,45,46,47,48,49,50,51,52)
            )
            BEGIN
                ;THROW 50001, N'يوجد خطابات تسكين تحت الاجراء بالنظام للمستفيد', 1;
            END


            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in(19)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب التقاعد', 1;
            END


            
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.LastActionTypeID in (53)
                  AND w.IdaraId = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'تم الغاء جميع سجلات الانتظار للمستفيد مسبقا بسبب الفصل', 1;
            END


             IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.V_GetFullResidentDetails w
                WHERE w.residentInfoID = @residentInfoID_FK
                  AND w.IdaraID = @idaraID_FK
            )
            BEGIN
                ;THROW 50001, N'ملف المستفيد ليس في ادارتك حاليا', 1;
            END

            
        

            INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , buildingActionExtraType1
                , buildingActionExtraType2
                , IdaraId_FK
                , entryData
                , hostName
            )

            SELECT 
            @ActionTypeID,
            @residentInfoID_FK,
            w.GeneralNo,
            @buildingActionDecisionNo,
            @buildingActionDecisionDate,
            1,
            @Notes,
            isnull(w.LastActionID,w.ActionID),
            w.WaitingClassID,
            w.WaitingOrderTypeID,
            @idaraID_FK,
            @entryData,
            @hostName

            FROM Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID_FK

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في حذف سجلات الانتظار للمستفيد', 1; -- برمجي
            END

            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في حذف سجلات الانتظار للمستفيد - Identity', 1; -- برمجي
            END



            INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , buildingActionExtraType1
                , buildingActionExtraType2
                , IdaraId_FK
                , entryData
                , hostName
            )

            SELECT 
            @ActionTypeID,
            @residentInfoID_FK,
            w.GeneralNo,
            @buildingActionDecisionNo,
            @buildingActionDecisionDate,
            1,
            @Notes,
            isnull(w.LastActionID,w.ActionID),
            w.WaitingClassID,
            w.WaitingOrderTypeID,
            @idaraID_FK,
            @entryData,
            @hostName

            FROM Housing.V_WaitingListByLetter w
            where w.residentInfoID = @residentInfoID_FK

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في حذف خطابات التسكين للمستفيد', 1; -- برمجي
            END

            




            SET @Note = N'{'
                + N'"buildingActionID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "34"'
                + N',"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID_FK), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingActionDecisionNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionNo), '') + N'"'
                + N',"buildingActionDecisionDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionDate), '') + N'"'
                --+ N',"buildingActionExtraType1": "' + ISNULL(CONVERT(NVARCHAR(MAX), @WaitingClassID), '') + N'"'
                --+ N',"buildingActionExtraType2": "' + ISNULL(CONVERT(NVARCHAR(MAX), @WaitingOrderTypeID), '') + N'"'
                + N',"buildingActionActive": "1"'
                + N',"buildingActionNote": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionExtraInt1": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewIdaraForMoveWaitingList), '') + N'"'
                + N',"buildingActionParentID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ActionID), '') + N'"'
                + N',"IdaraId_FK": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                 + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                , N'DELETERESIDENTALLWAITINGLIST'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم حذف سجلات الانتظار للمستفيد بنجاح' AS Message_;
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