
CREATE PROCEDURE [Housing].[OtherWaitingListManagmentSP] 
(
      @Action                   NVARCHAR(200)
    , @waitingClassID           BIGINT          = NULL
    , @waitingClassName_A       NVARCHAR(100)   = NULL
    , @waitingClassName_E       NVARCHAR(100)   = NULL
    , @waitingClassDescription  NVARCHAR(1000)  = NULL
    , @UpdatedWhy               NVARCHAR(1000)  = NULL
    , @CancelWhy                NVARCHAR(1000)  = NULL
    , @idaraID_FK               NVARCHAR(10)    = NULL
    , @entryData                NVARCHAR(20)    = NULL
    , @hostName                 NVARCHAR(200)   = NULL
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
    DECLARE @waitingClassSequenceold INT = (Select top(1) c.waitingClassSequence FROM  Housing.WaitingClass c WHERE (c.idara_FK = @IdaraID_INT OR @IdaraID_INT IS NULL) order by c.waitingClassID desc);
    DECLARE @waitingClassSequenceNew INT = @waitingClassSequenceold + 1;

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
        ----------------------------------------------------------------
        -- INSERT
        ----------------------------------------------------------------
        IF @Action = N'INSERTOTHERWAITINGLIST'
        BEGIN
            IF NULLIF(LTRIM(RTRIM(@waitingClassName_A)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'اسم سجل الانتظار (عربي) مطلوب', 1;
            END

            IF EXISTS
            (
                SELECT 1
                FROM  Housing.WaitingClass c
                WHERE c.waitingClassName_A = @waitingClassName_A
                  AND c.waitingClassActive = 1
                  AND (c.idara_FK = @IdaraID_INT OR @IdaraID_INT IS NULL)
            )
            BEGIN
                ;THROW 50001, N'البيانات مدخلة مسبقا', 1;
            END
            INSERT INTO  Housing.WaitingClass
            (
                  waitingClassName_A
                , waitingClassName_E
                , waitingClassDescription
                , waitingClassSequence
                , waitingClassActive
                , idara_FK
                , entryData
                , hostName
            )
            VALUES
            (
                  @waitingClassName_A
                , @waitingClassName_E
                , @waitingClassDescription
                , @waitingClassSequenceNew
                , 1
                , @IdaraID_INT
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة سجل الانتظار الجانبي', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في سجل الانتظار الجانبي - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingClassID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"waitingClassName_A": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @waitingClassName_A), '') + N'"'
                + N',"waitingClassName_E": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @waitingClassName_E), '') + N'"'
                + N',"waitingClassDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @waitingClassDescription), '') + N'"'
                + N',"waitingClassSequence": "' + ISNULL(CONVERT(NVARCHAR(MAX), @waitingClassSequenceNew), '') + N'"'
                + N',"waitingClassActive": "1"'
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
                  N'[Housing].[waitingClass]'
                , N'INSERTOTHERWAITINGLIST'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم اضافة سجل الانتظار الجانبي بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- UPDATE
        ----------------------------------------------------------------
        ELSE IF @Action = N'UPDATEOTHERWAITINGLIST'
        BEGIN
            IF @waitingClassID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.WaitingClass
                WHERE waitingClassID = @waitingClassID
                  AND waitingClassActive = 1
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود او غير نشط', 1;
            END
            UPDATE  Housing.WaitingClass
            SET
                  waitingClassName_A      = ISNULL(@waitingClassName_A, waitingClassName_A)
                , waitingClassName_E      = ISNULL(@waitingClassName_E, waitingClassName_E)
                , waitingClassDescription = ISNULL(@waitingClassDescription, waitingClassDescription)
                , idara_FK               = ISNULL(@IdaraID_INT, idara_FK)
                , UpdatedBy = ISNULL(ISNULL(UpdatedBy,'')+N','+@entryData+' '+TRY_CONVERT(nvarchar(50),Getdate(),23) +' '+TRY_CONVERT(nvarchar(50),Getdate(),8), UpdatedBy)
                , UpdatedWhy  = ISNULL(ISNULL(UpdatedWhy,'')+N','+@UpdatedWhy, UpdatedWhy)
            WHERE waitingClassID = @waitingClassID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1; -- برمجي/غير متوقع
            END

            SET @Note = N'{'
                + N'"waitingClassID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @waitingClassID), '') + N'"'
                + N',"waitingClassName_A": "'      + ISNULL(CONVERT(NVARCHAR(MAX),  @waitingClassName_A), '') + N'"'
                + N',"waitingClassName_E": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @waitingClassName_E), '') + N'"'
                + N',"waitingClassDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @waitingClassDescription), '') + N'"'
                + N',"IdaraId_FK": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"UpdatedBy": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"UpdatedWhy": "'                 + ISNULL(CONVERT(NVARCHAR(MAX), @UpdatedWhy), '') + N'"'
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
                  N'[Housing].[WaitingClass]'
                , N'UPDATEOTHERWAITINGLIST'
                , @waitingClassID
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم تحديث سجل الانتظار الجانبي بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- DELETE (Soft Delete)
        ----------------------------------------------------------------
        ELSE IF @Action = N'DELETEOTHERWAITINGLIST'
        BEGIN
            IF @waitingClassID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للحذف', 1;
            END

             IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.WaitingClass
                WHERE waitingClassID = @waitingClassID
                  AND waitingClassActive = 1
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END
            
            Declare @waitlistcount bigint, @waitlistMsg nvarchar(500)
            set @waitlistcount = (select count(*) from Housing.V_WaitingList w where w.WaitingClassID = @waitingClassID)
            set @waitlistMsg =N' لايمكن حذف فئة سجل الانتظار الجانبي لوجود عدد '+CAST(@waitlistcount as nvarchar(10))+N' سجلات انتظار مرتبطة به '
            IF (@waitlistcount) > 0
            BEGIN
                ;THROW 50001, @waitlistMsg, 1;
            END

           

            UPDATE  Housing.WaitingClass
            SET
                  waitingClassActive = 0
                , CancelBy = ISNULL(ISNULL(CancelBy,'')+N','+@entryData+' '+TRY_CONVERT(nvarchar(50),Getdate(),23)+' '+TRY_CONVERT(nvarchar(50),Getdate(),8), CancelBy)
                , CancelWhy  = ISNULL(ISNULL(CancelWhy,'')+N','+@CancelWhy, CancelWhy)
            WHERE waitingClassID = @waitingClassID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم حذف أي سجل', 1; -- برمجي/غير متوقع
            END
            SET @Note = N'{'
                + N'"waitingClassID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @waitingClassID), '') + N'"'
                + N',"CancelBy": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"CancelWhy": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @CancelWhy), '') + N'"'
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
                  N'[Housing].[WaitingClass]'
                , N'DELETEOTHERWAITINGLIST'
                , @waitingClassID
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم حذف سجل الانتظار الجانبي بنجاح' AS Message_;
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

GO

