
/* =========================================================
   Description:
   إضافة/تعديل نوع وثيقة مركبة في جدول VIC.VehiclesDocumentType.
   - يتحقق من الاسم العربي وعدم تكراره.
   - يدعم Insert عند عدم تمرير vehicleDocumentTypeID
   - ويدعم Update عند تمريره
   Type: WRITE (UPSERT)
========================================================= */

CREATE PROCEDURE [VIC].[VehicleDocumentType_Upsert_SP]
(
      @vehicleDocumentTypeID INT = NULL
    , @NameA                 NVARCHAR(100)
    , @NameE                 NVARCHAR(100) = NULL
    , @Active                BIT = 1

    -- ADDED: for AuditLog (same pattern as other lookups in your codebase)
    , @entryData             NVARCHAR(40)  = NULL
    , @hostName              NVARCHAR(400) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @FinalID INT = NULL;

    DECLARE @NameA_Trim NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@NameA)), N'');
    DECLARE @NameE_Trim NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@NameE)), N'');

    -- AuditLog
    DECLARE @Note_Audit NVARCHAR(MAX) = NULL;

    BEGIN TRY
        IF @NameA_Trim IS NULL
            THROW 50001, N'اسم النوع العربي مطلوب', 1;

        IF EXISTS
        (
            SELECT 1
            FROM VIC.VehiclesDocumentType AS dt
            WHERE dt.vehicleDocumentTypeName_A = @NameA_Trim
              AND (@vehicleDocumentTypeID IS NULL OR dt.vehicleDocumentTypeID <> @vehicleDocumentTypeID)
        )
            THROW 50001, N'اسم النوع العربي موجود مسبقاً', 1;

        IF @tc = 0 BEGIN TRAN;

        IF @vehicleDocumentTypeID IS NULL
        BEGIN
            INSERT INTO VIC.VehiclesDocumentType
            (
                  vehicleDocumentTypeName_A
                , vehicleDocumentTypeName_E
                , vehicleDocumentTypeActive
            )
            VALUES
            (
                  @NameA_Trim
                , @NameE_Trim
                , @Active
            );

            SET @FinalID = CONVERT(INT, SCOPE_IDENTITY());

            IF @FinalID IS NULL OR @FinalID <= 0
                THROW 50002, N'فشل إضافة نوع الوثيقة', 1; -- CHANGED (50002)

            -- AuditLog (INSERT)
            SET @Note_Audit = N'{'
                + N'"vehicleDocumentTypeID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @FinalID), '') + N'"'
                + N',"NameA":"' + ISNULL(@NameA_Trim, '') + N'"'
                + N',"NameE":"' + ISNULL(@NameE_Trim, '') + N'"'
                + N',"Active":"' + ISNULL(CONVERT(NVARCHAR(10), @Active), '') + N'"'
                + N',"entryData":"' + ISNULL(@entryData, '') + N'"'
                + N',"hostName":"' + ISNULL(@hostName, '') + N'"'
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
                  N'[VIC].[VehiclesDocumentType]'
                , N'INSERT'
                , ISNULL(@FinalID, 0)
                , @entryData
                , @Note_Audit
            );
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM VIC.VehiclesDocumentType AS dt WHERE dt.vehicleDocumentTypeID = @vehicleDocumentTypeID)
                THROW 50001, N'السجل غير موجود للتعديل', 1;

            UPDATE VIC.VehiclesDocumentType
            SET
                  vehicleDocumentTypeName_A = @NameA_Trim
                , vehicleDocumentTypeName_E = @NameE_Trim
                , vehicleDocumentTypeActive = @Active
            WHERE vehicleDocumentTypeID = @vehicleDocumentTypeID;

            IF @@ROWCOUNT <= 0
                THROW 50002, N'لم يتم تعديل أي سجل', 1; -- CHANGED (50002)

            SET @FinalID = @vehicleDocumentTypeID;

            -- AuditLog (UPDATE)
            SET @Note_Audit = N'{'
                + N'"vehicleDocumentTypeID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @FinalID), '') + N'"'
                + N',"NameA":"' + ISNULL(@NameA_Trim, '') + N'"'
                + N',"NameE":"' + ISNULL(@NameE_Trim, '') + N'"'
                + N',"Active":"' + ISNULL(CONVERT(NVARCHAR(10), @Active), '') + N'"'
                + N',"entryData":"' + ISNULL(@entryData, '') + N'"'
                + N',"hostName":"' + ISNULL(@hostName, '') + N'"'
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
                  N'[VIC].[VehiclesDocumentType]'
                , N'UPDATE'
                , ISNULL(@FinalID, 0)
                , @entryData
                , @Note_Audit
            );
        END

        IF @tc = 0 COMMIT;

        SELECT
              CAST(1 AS BIT) AS IsSuccessful
            , CASE WHEN @vehicleDocumentTypeID IS NULL THEN N'تمت الإضافة بنجاح' ELSE N'تم التعديل بنجاح' END AS Message_
            , @FinalID AS vehicleDocumentTypeID;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END