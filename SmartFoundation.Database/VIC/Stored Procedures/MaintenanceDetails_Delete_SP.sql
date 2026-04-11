
/* =========================================================
   Description:
   حذف بند صيانة واحد من VIC.MaintenanceDetails بعد التحقق من وجوده
   ومن أن أمر الصيانة المرتبط غير مقفل (MaintOrdActive = 1).
   Type: WRITE (DELETE)
========================================================= */

CREATE   PROCEDURE [VIC].[MaintenanceDetails_Delete_SP]
(
      @maintDetailesID INT
    , @idaraID_FK      NVARCHAR(10) = NULL
    , @entryData       NVARCHAR(40) = NULL   -- ADDED (Audit)
    , @hostName        NVARCHAR(400) = NULL  -- ADDED (Audit)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @maintDetailesID IS NULL OR @maintDetailesID <= 0
        THROW 50001, N'maintDetailesID غير صحيح', 1;

    DECLARE @tc INT = @@TRANCOUNT;

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- ADDED (Audit)
    DECLARE @Note_Audit NVARCHAR(MAX) = NULL;

    BEGIN TRY
        IF @tc = 0
            BEGIN TRAN;

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.MaintenanceDetails AS d
            WHERE d.MaintDetailesID = @maintDetailesID
        )
            THROW 50001, N'البند غير موجود', 1;

        -- مطابقة الإدارة (إن تم تمريرها) عبر أمر الصيانة المرتبط (VehicleMaintenance)
        IF @IdaraID_BIG IS NOT NULL
           AND NOT EXISTS
        (
            SELECT 1
            FROM VIC.MaintenanceDetails AS d
            INNER JOIN VIC.VehicleMaintenance AS m
                ON m.MaintOrdID = d.MaintOrdID_FK
            WHERE d.MaintDetailesID = @maintDetailesID
              AND m.IdaraID_FK = @IdaraID_BIG
        )
            THROW 50001, N'لا يمكن حذف البند: الإدارة غير مطابقة', 1;

        IF EXISTS
        (
            SELECT 1
            FROM VIC.MaintenanceDetails AS d
            INNER JOIN VIC.VehicleMaintenance AS m
                ON m.MaintOrdID = d.MaintOrdID_FK
            WHERE d.MaintDetailesID = @maintDetailesID
              AND m.MaintOrdActive = 0
        )
            THROW 50001, N'الأمر مقفل لا يمكن حذف البنود', 1;

        DELETE FROM VIC.MaintenanceDetails
        WHERE MaintDetailesID = @maintDetailesID;

        IF @@ROWCOUNT <= 0
            THROW 50002, N'لم يتم حذف أي سجل', 1; -- CHANGED (50002)

        -- ADDED (AuditLog)
        SET @Note_Audit = N'{'
            + N'"maintDetailesID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @maintDetailesID), '') + N'"'
            + N',"idaraID_FK": "'     + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
            + N',"entryData": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
            + N',"hostName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
              N'[VIC].[MaintenanceDetails]'
            , N'DELETE'
            , @maintDetailesID
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0
            COMMIT;

        SELECT 1 AS IsSuccessful, N'تم حذف البند' AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END