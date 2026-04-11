
CREATE   PROCEDURE [VIC].[Custody_Close_SP]
(
      @vehicleWithUsersID INT
    , @endDate            DATETIME = NULL
    , @note               NVARCHAR(2000) = NULL
    , @entryData          NVARCHAR(40)
    , @hostName           NVARCHAR(400)
    , @idaraID_FK         NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;
    DECLARE @ED DATETIME = ISNULL(@endDate, GETDATE());

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- ADDED (Audit)
    DECLARE @Note_Audit NVARCHAR(MAX) = NULL;

    BEGIN TRY
        IF @vehicleWithUsersID IS NULL OR @vehicleWithUsersID <= 0
            THROW 50001, N'vehicleWithUsersID مطلوب', 1;

        -- تحقق وجود العهدة وأنها نشطة
        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.vehicleWithUsers w
            WHERE w.vehicleWithUsersID = @vehicleWithUsersID
              AND w.endDate IS NULL
        )
            THROW 50001, N'العهدة غير موجودة أو مغلقة مسبقًا', 1;

        -- فلترة الإدارة عبر المركبة
        IF EXISTS
        (
            SELECT 1
            FROM VIC.vehicleWithUsers w
            INNER JOIN VIC.Vehicles v
                ON v.chassisNumber = w.chassisNumber_FK
            WHERE w.vehicleWithUsersID = @vehicleWithUsersID
              AND (@IdaraID_BIG IS NOT NULL AND v.IdaraID_FK <> @IdaraID_BIG)
        )
            THROW 50001, N'العهدة لا تتبع هذه الإدارة', 1;

        IF @tc = 0 BEGIN TRAN;

        UPDATE VIC.vehicleWithUsers
        SET
              endDate   = @ED
            , note      = CASE WHEN @note IS NULL THEN note ELSE @note END
            , entryDate = GETDATE()
            , entryData = @entryData
            , hostName  = @hostName
        WHERE vehicleWithUsersID = @vehicleWithUsersID
          AND endDate IS NULL;

        IF @@ROWCOUNT <= 0
            THROW 50002, N'لم يتم إغلاق العهدة', 1; -- CHANGED (50002)

        -- ADDED (AuditLog)
        SET @Note_Audit = N'{'
            + N'"vehicleWithUsersID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleWithUsersID), '') + N'"'
            + N',"endDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ED, 121), '') + N'"'
            + N',"idaraID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
            + N',"note": "' + ISNULL(CONVERT(NVARCHAR(MAX), @note), '') + N'"'
            + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
            + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
              N'[VIC].[vehicleWithUsers]'
            , N'UPDATE'
            , @vehicleWithUsersID
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0 COMMIT;

        SELECT CAST(1 AS BIT) AS IsSuccessful, N'تم إغلاق العهدة' AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END;