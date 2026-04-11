
CREATE   PROCEDURE [VIC].[HandoverType_Upsert_SP]
(
      @handoverTypeID     INT = NULL
    , @handoverTypeName_A NVARCHAR(100)
    , @handoverTypeName_E NVARCHAR(100) = NULL
    , @active             BIT = 1
    , @entryData          NVARCHAR(40) = NULL  -- unused (table has no audit columns)
    , @hostName           NVARCHAR(400) = NULL -- unused (table has no audit columns)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @NameA NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@handoverTypeName_A)), N'');
    DECLARE @NameE NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@handoverTypeName_E)), N'');

    -- ADDED (Audit)
    DECLARE
          @NewID INT = NULL
        , @Note_Audit NVARCHAR(MAX) = NULL
        , @ActionType NVARCHAR(20) = NULL;

    BEGIN TRY
        IF @NameA IS NULL
            THROW 50001, N'اسم النوع العربي مطلوب', 1;

        IF EXISTS
        (
            SELECT 1
            FROM VIC.HandoverType AS ht
            WHERE ht.handOverTypeName_A = @NameA
              AND (@handoverTypeID IS NULL OR ht.handOverTypeID <> @handoverTypeID)
        )
            THROW 50001, N'اسم النوع العربي موجود مسبقاً', 1;

        IF @tc = 0 BEGIN TRAN;

        IF @handoverTypeID IS NULL
        BEGIN
            INSERT INTO VIC.HandoverType
            (
                  handOverTypeName_A
                , handOverTypeName_E
                , active
            )
            VALUES
            (
                  @NameA
                , @NameE
                , @active
            );

            SET @NewID = CONVERT(INT, SCOPE_IDENTITY());
            IF @NewID IS NULL OR @NewID <= 0
                THROW 50002, N'فشل إضافة نوع المحضر', 1; -- CHANGED (50002)

            SET @ActionType = N'INSERT'; -- ADDED
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM VIC.HandoverType WHERE handOverTypeID = @handoverTypeID)
                THROW 50001, N'السجل غير موجود للتعديل', 1;

            UPDATE VIC.HandoverType
            SET
                  handOverTypeName_A = @NameA
                , handOverTypeName_E = @NameE
                , active             = @active
            WHERE handOverTypeID = @handoverTypeID;

            IF @@ROWCOUNT <= 0
                THROW 50002, N'لم يتم تعديل أي سجل', 1; -- CHANGED (50002)

            SET @NewID = @handoverTypeID;  -- ADDED
            SET @ActionType = N'UPDATE';   -- ADDED
        END

        -- ADDED (AuditLog)
        SET @Note_Audit = N'{'
            + N'"handOverTypeID": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
            + N',"handOverTypeName_A": "'  + ISNULL(CONVERT(NVARCHAR(MAX), @NameA), '') + N'"'
            + N',"handOverTypeName_E": "'  + ISNULL(CONVERT(NVARCHAR(MAX), @NameE), '') + N'"'
            + N',"active": "'              + ISNULL(CONVERT(NVARCHAR(MAX), @active), '') + N'"'
            + N',"entryData": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
            + N',"hostName": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
              N'[VIC].[HandoverType]'
            , @ActionType
            , ISNULL(@NewID, 0)
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0 COMMIT;

        SELECT
              CAST(1 AS BIT) AS IsSuccessful
            , CASE WHEN @handoverTypeID IS NULL THEN N'تمت الإضافة بنجاح' ELSE N'تم التعديل بنجاح' END AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END