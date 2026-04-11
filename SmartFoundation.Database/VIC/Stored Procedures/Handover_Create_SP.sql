
CREATE   PROCEDURE [VIC].[Handover_Create_SP]
(
      @requestID      INT
    , @handoverTypeID INT
    , @handoverDate   DATETIME = NULL
    , @note           NVARCHAR(1000) = NULL
    , @idaraID_FK     NVARCHAR(10) = NULL
    , @entryData      NVARCHAR(40)
    , @hostName       NVARCHAR(400)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- ADDED (Audit)
    DECLARE
          @NewID INT = NULL
        , @Note_Audit NVARCHAR(MAX) = NULL;

    BEGIN TRY
        IF @requestID IS NULL OR @requestID <= 0
            THROW 50001, N'requestID مطلوب', 1;

        IF @handoverTypeID IS NULL OR @handoverTypeID <= 0
            THROW 50001, N'handoverTypeID مطلوب', 1;

        -- وجود الطلب (ومطابقة الإدارة إذا تم تمريرها)
        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.VehicleTransferRequest AS r
            WHERE r.RequestID = @requestID
              AND (@IdaraID_BIG IS NULL OR r.IdaraID_FK = @IdaraID_BIG)
        )
            THROW 50001, N'طلب النقل غير موجود أو لا يتبع نفس الإدارة', 1;

        IF @tc = 0 BEGIN TRAN;

        INSERT INTO VIC.VehicleHandover
        (
              RequestID_FK
            , handOverTypeID_FK
            , handoverDate
            , note
            , IdaraID_FK
            , entryDate
            , entryData
            , hostName
        )
        VALUES
        (
              @requestID
            , @handoverTypeID
            , ISNULL(@handoverDate, GETDATE())
            , @note
            , @IdaraID_BIG
            , GETDATE()
            , @entryData
            , @hostName
        );

        SET @NewID = CONVERT(INT, SCOPE_IDENTITY());
        IF @NewID IS NULL OR @NewID <= 0
            THROW 50002, N'فشل إنشاء المحضر', 1; -- CHANGED (50002)

        -- ADDED (AuditLog)
        SET @Note_Audit = N'{'
            + N'"VehicleHandoverID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
            + N',"requestID": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @requestID), '') + N'"'
            + N',"handoverTypeID": "'   + ISNULL(CONVERT(NVARCHAR(MAX), @handoverTypeID), '') + N'"'
            + N',"handoverDate": "'     + ISNULL(CONVERT(NVARCHAR(MAX), ISNULL(@handoverDate, GETDATE()), 121), '') + N'"'
            + N',"note": "'             + ISNULL(CONVERT(NVARCHAR(MAX), @note), '') + N'"'
            + N',"idaraID_FK": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
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
              N'[VIC].[VehicleHandover]'
            , N'INSERT'
            , ISNULL(@NewID, 0)
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0 COMMIT;

        SELECT
              CAST(1 AS BIT) AS IsSuccessful
            , N'تم إنشاء المحضر بنجاح' AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END