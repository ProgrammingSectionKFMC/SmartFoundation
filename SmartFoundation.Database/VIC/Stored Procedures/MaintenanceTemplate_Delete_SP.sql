
/* =========================================================
   Description:
   حذف بند واحد من قالب الصيانة في جدول VIC.MaintenanceTemplate.
   Type: WRITE (DELETE)
========================================================= */

CREATE   PROCEDURE [VIC].[MaintenanceTemplate_Delete_SP]
(
      @TemplateID INT
    , @entryData  NVARCHAR(40) = NULL
    , @hostName   NVARCHAR(400) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @Note_Audit NVARCHAR(MAX) = NULL;

    BEGIN TRY
        IF @tc = 0
            BEGIN TRAN;

        IF @TemplateID IS NULL OR @TemplateID <= 0
            THROW 50001, N'TemplateID غير صحيح', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.MaintenanceTemplate mt
            WHERE mt.TemplateID = @TemplateID
        )
            THROW 50001, N'بند القالب غير موجود', 1;

        DELETE FROM VIC.MaintenanceTemplate
        WHERE TemplateID = @TemplateID;

        IF @@ROWCOUNT <= 0
            THROW 50002, N'لم يتم حذف أي سجل', 1;

        SET @Note_Audit = N'{'
            + N'"TemplateID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @TemplateID), '') + N'"'
            + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
            + N',"hostName": "'  + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
            , N'DELETE'
            , @TemplateID
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0
            COMMIT;

        SELECT 1 AS IsSuccessful, N'تم حذف بند القالب' AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END