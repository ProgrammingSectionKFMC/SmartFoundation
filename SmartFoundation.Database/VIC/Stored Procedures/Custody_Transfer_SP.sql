
CREATE   PROCEDURE [VIC].[Custody_Transfer_SP]
(
      @chassisNumber   NVARCHAR(100)
    , @toUserID_FK      BIGINT
    , @transferDate     DATETIME = NULL
    , @note             NVARCHAR(2000) = NULL
    , @entryData        NVARCHAR(40)
    , @hostName         NVARCHAR(400)
    , @idaraID_FK       NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @CH NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
    DECLARE @TD DATETIME = ISNULL(@transferDate, GETDATE());

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- ADDED (Audit)
    DECLARE
          @Note_Audit NVARCHAR(MAX) = NULL
        , @NewID_Audit INT = NULL;

    BEGIN TRY
        IF @CH IS NULL
            THROW 50001, N'chassisNumber مطلوب', 1;

        IF @toUserID_FK IS NULL OR @toUserID_FK <= 0
            THROW 50001, N'toUserID_FK مطلوب', 1;

        -- تحقق المركبة + فلتر الإدارة
        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.Vehicles v
            WHERE v.chassisNumber = @CH
              AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
        )
            THROW 50001, N'المركبة غير موجودة أو لا تتبع الإدارة', 1;

        -- منع إذا خارج الخدمة أو إتلاف نهائي
        IF EXISTS
        (
            SELECT 1
            FROM VIC.Vehicles v
            WHERE v.chassisNumber = @CH
              AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
              AND v.vehicleStatusID_FK IN (261, 262)
        )
            THROW 50001, N'لا يمكن نقل العهدة: المركبة خارج الخدمة أو مُتلفة نهائيًا', 1;

        -- لازم فيه عهدة نشطة ليتم نقلها
        DECLARE @CurrentID INT;

        SELECT TOP (1) @CurrentID = w.vehicleWithUsersID
        FROM VIC.vehicleWithUsers w
        WHERE w.chassisNumber_FK = @CH
          AND w.endDate IS NULL
        ORDER BY w.startDate DESC, w.vehicleWithUsersID DESC;

        IF @CurrentID IS NULL
            THROW 50001, N'لا توجد عهدة نشطة لنقلها', 1;

        IF @tc = 0 BEGIN TRAN;

        -- 1) إغلاق العهدة الحالية
        UPDATE VIC.vehicleWithUsers
        SET
              endDate   = @TD
            , note      = CASE WHEN @note IS NULL THEN note ELSE @note END
            , entryDate = GETDATE()
            , entryData = @entryData
            , hostName  = @hostName
        WHERE vehicleWithUsersID = @CurrentID
          AND endDate IS NULL;

        IF @@ROWCOUNT <= 0
            THROW 50002, N'فشل إغلاق العهدة الحالية', 1; -- CHANGED (50002)

        -- 2) فتح عهدة جديدة
        INSERT INTO VIC.vehicleWithUsers
        (
              userID_FK
            , startDate
            , endDate
            , note
            , entryDate
            , entryData
            , hostName
            , chassisNumber_FK

            -- Snapshot (جزئي)
            , OrgSnapshotDate
            , IdaraID_Snapshot
        )
        VALUES
        (
              @toUserID_FK
            , @TD
            , NULL
            , @note
            , GETDATE()
            , @entryData
            , @hostName
            , @CH
            , GETDATE()
            , TRY_CONVERT(INT, @IdaraID_BIG)
        );

        SET @NewID_Audit = CONVERT(INT, SCOPE_IDENTITY());
        IF @NewID_Audit IS NULL OR @NewID_Audit <= 0
            THROW 50002, N'فشل إنشاء العهدة الجديدة', 1; -- CHANGED (50002)

        -- ADDED (AuditLog)
        SET @Note_Audit = N'{'
            + N'"chassisNumber": "' + ISNULL(CONVERT(NVARCHAR(MAX), @CH), '') + N'"'
            + N',"transferDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @TD, 121), '') + N'"'
            + N',"toUserID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @toUserID_FK), '') + N'"'
            + N',"idaraID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
            + N',"ClosedVehicleWithUsersID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @CurrentID), '') + N'"'
            + N',"NewVehicleWithUsersID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID_Audit), '') + N'"'
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
            , N'TRANSFER'
            , ISNULL(@NewID_Audit, 0)
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0 COMMIT;

        SELECT
              CAST(1 AS BIT) AS IsSuccessful
            , N'تم نقل العهدة' AS Message_
            , @CurrentID AS ClosedVehicleWithUsersID
            , @NewID_Audit AS NewVehicleWithUsersID;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END;