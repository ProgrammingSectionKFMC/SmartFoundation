
CREATE   PROCEDURE [VIC].[Custody_Create_SP]
(
      @chassisNumber   NVARCHAR(100)
    , @userID_FK        BIGINT
    , @startDate        DATETIME = NULL
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
    DECLARE @SD DATETIME = ISNULL(@startDate, GETDATE());

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, @IdaraID_BIG);

    -- ADDED (Audit)
    DECLARE
          @Note_Audit NVARCHAR(MAX) = NULL
        , @NewID_Audit INT = NULL;

    BEGIN TRY
        IF @CH IS NULL
            THROW 50001, N'chassisNumber مطلوب', 1;

        IF @userID_FK IS NULL OR @userID_FK <= 0
            THROW 50001, N'userID_FK مطلوب', 1;

        IF @IdaraID_BIG IS NULL
            THROW 50001, N'idaraID_FK مطلوب', 1;

        IF @IdaraID_INT IS NULL
            THROW 50001, N'idaraID_FK غير صحيح (لا يمكن تحويله إلى INT لسsnapshot)', 1;

        -- تحقق وجود المركبة ضمن نفس الإدارة
        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.Vehicles v
            WHERE v.chassisNumber = @CH
              AND v.IdaraID_FK = @IdaraID_BIG
        )
            THROW 50001, N'المركبة غير موجودة أو لا تتبع الإدارة', 1;

        -- منع إذا خارج الخدمة أو إتلاف نهائي
        IF EXISTS
        (
            SELECT 1
            FROM VIC.Vehicles v
            WHERE v.chassisNumber = @CH
              AND v.IdaraID_FK = @IdaraID_BIG
              AND v.vehicleStatusID_FK IN (261, 262)
        )
            THROW 50001, N'لا يمكن إنشاء عهدة: المركبة خارج الخدمة أو مُتلفة نهائيًا', 1;

        -- منع ازدواج العهدة داخل نفس الإدارة (Snapshot)
        IF EXISTS
        (
            SELECT 1
            FROM VIC.vehicleWithUsers w
            WHERE w.chassisNumber_FK = @CH
              AND w.endDate IS NULL
              AND ISNULL(w.IdaraID_Snapshot, -1) = @IdaraID_INT
        )
            THROW 50001, N'يوجد عهدة نشطة على المركبة بالفعل داخل نفس الإدارة', 1;

        IF @tc = 0 BEGIN TRAN;

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
            , OrgSnapshotDate
            , IdaraID_Snapshot
        )
        VALUES
        (
              @userID_FK
            , @SD
            , NULL
            , @note
            , GETDATE()
            , @entryData
            , @hostName
            , @CH
            , GETDATE()
            , @IdaraID_INT
        );

        SET @NewID_Audit = CONVERT(INT, SCOPE_IDENTITY());
        IF @NewID_Audit IS NULL OR @NewID_Audit <= 0
            THROW 50002, N'فشل إنشاء العهدة', 1; -- CHANGED (50002)

        -- ADDED (AuditLog)
        SET @Note_Audit = N'{'
            + N'"vehicleWithUsersID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID_Audit), '') + N'"'
            + N',"chassisNumber": "' + ISNULL(CONVERT(NVARCHAR(MAX), @CH), '') + N'"'
            + N',"userID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @userID_FK), '') + N'"'
            + N',"startDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @SD, 121), '') + N'"'
            + N',"idaraID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
            + N',"IdaraID_Snapshot": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), '') + N'"'
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
            , N'INSERT'
            , ISNULL(@NewID_Audit, 0)
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0 COMMIT;

        SELECT CAST(1 AS BIT) AS IsSuccessful, N'تم إنشاء العهدة' AS Message_, @NewID_Audit AS vehicleWithUsersID;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END;