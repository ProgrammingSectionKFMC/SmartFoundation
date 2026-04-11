
/* =========================================================
   Description:
   تقرير المركبات التي لا يوجد عليها عهدة حالية (لا يوجد سجل custody نشط endDate IS NULL)،
   مع إظهار آخر تاريخ انتهاء عهدة إن وجد، وخيار حصر النتائج على المركبات النشطة فقط (isActive).
   Type: READ (REPORT)
========================================================= */

CREATE   PROCEDURE [VIC].[Report_VehiclesWithoutCustody_DL]
(
      @onlyActiveVehicles BIT = 0
    , @idaraID_FK         NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- لأن الحقل في الجدول Snapshot هو INT
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, @IdaraID_BIG);

    SELECT
          v.chassisNumber
        , v.plateLetters
        , v.plateNumbers
        , v.yearModel
        , (
            SELECT MAX(w.endDate)
            FROM VIC.vehicleWithUsers w
            WHERE w.chassisNumber_FK = v.chassisNumber
              AND (@IdaraID_INT IS NULL OR w.IdaraID_Snapshot = @IdaraID_INT)
          ) AS LastCustodyEndDate
    FROM VIC.Vehicles v
    WHERE (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
      AND NOT EXISTS
    (
        SELECT 1
        FROM VIC.vehicleWithUsers w
        WHERE w.chassisNumber_FK = v.chassisNumber
          AND w.endDate IS NULL
          AND (@IdaraID_INT IS NULL OR w.IdaraID_Snapshot = @IdaraID_INT)
    )
      AND (@onlyActiveVehicles = 0 OR v.isActive = 1);
END