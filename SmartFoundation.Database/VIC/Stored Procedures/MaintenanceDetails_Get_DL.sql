
/* =========================================================
   Description:
   جلب بند صيانة واحد من VIC.MaintenanceDetails حسب MaintDetailesID
   مع التحقق من وجوده ومطابقة الإدارة عبر أمر الصيانة المرتبط.
   Type: READ (GET)
========================================================= */

CREATE   PROCEDURE [VIC].[MaintenanceDetails_Get_DL]
(
      @maintDetailesID INT
    , @idaraID_FK      NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @maintDetailesID IS NULL OR @maintDetailesID <= 0
        THROW 50001, N'maintDetailesID مطلوب', 1;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- تحقق وجود السجل + مطابقة الإدارة
    IF NOT EXISTS
    (
        SELECT 1
        FROM VIC.MaintenanceDetails d
        INNER JOIN VIC.VehicleMaintenance m
            ON m.MaintOrdID = d.MaintOrdID_FK
        WHERE d.MaintDetailesID = @maintDetailesID
          AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)
    )
        THROW 50001, N'البند غير موجود أو لا يطابق الإدارة', 1;

    SELECT
          d.MaintDetailesID
        , d.MaintOrdID_FK
        , d.typesID_FK
        , d.SupportID_FK
        , d.CheckStatus_FK
        , d.ActionState
        , d.CorrectiveAction
        , d.FSN
        , d.MaintLevel
        , d.CurrentDate
        , d.Notes
        , d.entryDate
        , d.entryData
        , d.hostName
    FROM VIC.MaintenanceDetails d
    INNER JOIN VIC.VehicleMaintenance m
        ON m.MaintOrdID = d.MaintOrdID_FK
    WHERE d.MaintDetailesID = @maintDetailesID
      AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG);
END