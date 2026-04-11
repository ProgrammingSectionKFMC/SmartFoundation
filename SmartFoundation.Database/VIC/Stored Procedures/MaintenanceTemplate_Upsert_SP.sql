
/* =========================================================
   Description:
   إضافة/تعديل بند داخل قالب الصيانة في جدول VIC.MaintenanceTemplate.
   Type: WRITE (UPSERT)
========================================================= */

CREATE   PROCEDURE [VIC].[MaintenanceTemplate_Upsert_SP]
(
      @TemplateID         INT = NULL
    , @MaintOrdTypeID_FK  INT
    , @typesID_FK         INT
    , @TemplateOrder      INT = 1
    , @active             BIT = 1
    , @entryData          NVARCHAR(40) = NULL
    , @hostName           NVARCHAR(400) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE
          @ActionType NVARCHAR(20) = NULL
        , @Note_Audit NVARCHAR(MAX) = NULL
        , @NewID INT = NULL;

    BEGIN TRY
        IF @tc = 0
            BEGIN TRAN;

        IF @MaintOrdTypeID_FK IS NULL OR @MaintOrdTypeID_FK <= 0
            THROW 50001, N'MaintOrdTypeID_FK مطلوب', 1;

        IF @typesID_FK IS NULL OR @typesID_FK <= 0
            THROW 50001, N'typesID_FK مطلوب', 1;

        IF @TemplateOrder IS NULL OR @TemplateOrder <= 0
            THROW 50001, N'TemplateOrder مطلوب ويجب أن يكون أكبر من صفر', 1;

        -- تحقق من نوع أمر الصيانة (من Parent 264)
        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.TypesRoot t
            WHERE t.typesID = @MaintOrdTypeID_FK
              AND t.typesRoot_ParentID = 264
              AND ISNULL(t.typesActive, 0) = 1
        )
            THROW 50001, N'نوع أمر الصيانة غير صحيح', 1;

        -- تحقق من البند
        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.TypesRoot t
            WHERE t.typesID = @typesID_FK
              AND ISNULL(t.typesActive, 0) = 1
        )
            THROW 50001, N'بند القالب غير صحيح', 1;

        IF @TemplateID IS NULL
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM VIC.MaintenanceTemplate mt
                WHERE mt.MaintOrdTypeID_FK = @MaintOrdTypeID_FK
                  AND mt.typesID_FK = @typesID_FK
                  AND mt.templateActive = 1
            )
                THROW 50001, N'هذا البند موجود مسبقًا في القالب', 1;

            INSERT INTO VIC.MaintenanceTemplate
            (
                  MaintOrdTypeID_FK
                , typesID_FK
                , TemplateOrder
                , templateActive
                , entryDate
                , entryData
                , hostName
            )
            VALUES
            (
                  @MaintOrdTypeID_FK
                , @typesID_FK
                , @TemplateOrder
                , @active
                , GETDATE()
                , @entryData
                , @hostName
            );

            SET @TemplateID = CONVERT(INT, SCOPE_IDENTITY());

            IF @TemplateID IS NULL OR @TemplateID <= 0
                THROW 50002, N'فشل إضافة بند القالب', 1;

            SET @ActionType = N'INSERT';
        END
        ELSE
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM VIC.MaintenanceTemplate mt
                WHERE mt.TemplateID = @TemplateID
            )
                THROW 50001, N'TemplateID غير موجود للتعديل', 1;

            UPDATE VIC.MaintenanceTemplate
            SET
                  MaintOrdTypeID_FK = @MaintOrdTypeID_FK
                , typesID_FK        = @typesID_FK
                , TemplateOrder     = @TemplateOrder
                , templateActive    = @active
                , entryDate         = GETDATE()
                , entryData         = @entryData
                , hostName          = @hostName
            WHERE TemplateID = @TemplateID;

            IF @@ROWCOUNT <= 0
                THROW 50002, N'لم يتم تعديل أي سجل', 1;

            SET @ActionType = N'UPDATE';
        END

        SET @NewID = @TemplateID;
        SET @Note_Audit = N'{'
            + N'"TemplateID": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @TemplateID), '') + N'"'
            + N',"MaintOrdTypeID_FK": "'+ ISNULL(CONVERT(NVARCHAR(MAX), @MaintOrdTypeID_FK), '') + N'"'
            + N',"typesID_FK": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @typesID_FK), '') + N'"'
            + N',"TemplateOrder": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @TemplateOrder), '') + N'"'
            + N',"active": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @active), '') + N'"'
            + N',"entryData": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
            + N',"hostName": "'         + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
            + N'}';

        INSERT INTO DATACORE.dbo.AuditLog
        (
              TableName
            , ActionType
            , RecordID
            , PerformedBy
            , Notes
        )
        VALUES
        (
              N'[VIC].[MaintenanceTemplate]'
            , @ActionType
            , ISNULL(@NewID, 0)
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0
            COMMIT;

        SELECT 1 AS IsSuccessful, N'تم حفظ بند القالب بنجاح' AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END