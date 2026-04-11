
/* =========================================================
   Description:
   جلب خطة صيانة دورية واحدة حسب PlanID
   Type: READ (GET)
========================================================= */

CREATE   PROCEDURE [VIC].[MaintenancePlan_Get_DL]
(
      @planID      INT
    , @idaraID_FK  NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @planID IS NULL OR @planID <= 0
        THROW 50001, N'planID مطلوب', 1;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    IF NOT EXISTS
    (
        SELECT 1
        FROM VIC.VehicleMaintenancePlan p
        WHERE p.PlanID = @planID
          AND (@IdaraID_BIG IS NULL OR p.IdaraID_FK = @IdaraID_BIG)
    )
        THROW 50001, N'الخطة غير موجودة أو لا تطابق الإدارة', 1;

    SELECT
          p.PlanID
        , p.chassisNumber_FK
        , p.periodMonths
        , p.nextDueDate
        , p.planActive
        , p.entryDate
        , p.entryData
        , p.hostName
    FROM VIC.VehicleMaintenancePlan p
    WHERE p.PlanID = @planID
      AND (@IdaraID_BIG IS NULL OR p.IdaraID_FK = @IdaraID_BIG);
END