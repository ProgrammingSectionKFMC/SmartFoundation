
CREATE PROCEDURE [Housing].[WaitingListSP] 
(
      @Action                       NVARCHAR(200)
    , @ActionID                     BIGINT          = NULL
    , @residentInfoID_FK            NVARCHAR(100)   = NULL
    , @residentName                 NVARCHAR(100)   = NULL
    , @NationalID                   NVARCHAR(100)   = NULL
    , @GeneralNo                    NVARCHAR(100)   = NULL
    , @buildingActionDecisionNo     NVARCHAR(1000)  = NULL
    , @buildingActionDecisionDate   NVARCHAR(1000)  = NULL
    , @WaitingClassID               NVARCHAR(1000)  = NULL
    , @WaitingClassName             NVARCHAR(1000)  = NULL
    , @WaitingOrderTypeID           NVARCHAR(1000)  = NULL
    , @WaitingOrderTypeName         NVARCHAR(1000)  = NULL
    , @Notes                        NVARCHAR(1000)  = NULL
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

            IF NULLIF(LTRIM(RTRIM(@ActionID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات سجل الانتظار - Action ID', 1;
            END

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
                ;THROW 50001, N'فئة سجل الانتظار مطلوبة', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@WaitingOrderTypeID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'ترتيب سجل الانتظار مطلوبة', 1;
            END


        ----------------------------------------------------------------
        -- MOVETOASSIGNLIST
        ----------------------------------------------------------------
        IF @Action = N'MOVETOASSIGNLIST'
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


             IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.ActionID = @ActionID and w.LastActionTypeID = 27 and w.ToIdaraID = @idaraID_FK
                  
            )
            BEGIN
                ;THROW 50001, N'تم اتخاذ اجراء للطلب مسبقا', 1;
            END



              
                DECLARE @MyOrder int;
                DECLARE @ErrMsg_  nvarchar(4000);
                
                SELECT @MyOrder = x.rn
                FROM
                (
                    SELECT
                        w.ActionID,
                        ROW_NUMBER() OVER (ORDER BY w.ActionDecisionDate ASC,w.ActionDecisionNo ASC, w.GeneralNo ASC) AS rn
                   FROM Housing.V_WaitingList w
                   INNER JOIN Housing.V_GetFullResidentDetails rd 
                       ON w.residentInfoID = rd.residentInfoID
                   WHERE w.WaitingClassID = @WaitingClassID
                     AND w.IdaraId = @idaraID_FK
                     AND  (w.LastActionTypeID is null or w.LastActionTypeID in (34,35))
                ) x
                WHERE x.ActionID = @ActionID;
                
                IF @MyOrder IS NULL
                BEGIN
                    SET @ErrMsg_ = N'لم يتم العثور على الطلب داخل قائمة الانتظار';
                    ;THROW 50001, @ErrMsg_, 1;
                END
                
                IF cast(@MyOrder as int) <> 1
                BEGIN
                    SET @ErrMsg_ =
                        N' المستفيد '+CAST(@residentName AS nvarchar(200))+N' ليس في رأس قائمة الانتظار في '
                        + CAST(@WaitingClassName AS nvarchar(20));
                    ;THROW 50001, @ErrMsg_, 1;
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
                , buildingActionParentID
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  27
                , @residentInfoID_FK
                , @GeneralNo
                , @buildingActionDecisionNo
                , @buildingActionDecisionDate
                , @WaitingClassID
                , @WaitingOrderTypeID
                , 1
                , @Notes
                , @ActionID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );
            
       

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في نقل لقائمة التخصيص', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في النقل لقائمة التخصيص - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), 27), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID_FK), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingActionDecisionNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionNo), '') + N'"'
                + N',"buildingActionDecisionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionDate), '') + N'"'
                + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"buildingActionNote": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ActionID), '') + N'"'
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
                , N'MOVETOASSIGNLIST'
                , @ActionID
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم النقل لقائمة التخصيص بنجاح' AS Message_;
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
