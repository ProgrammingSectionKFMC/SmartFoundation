
/* =========================================================
   Description:
   داشبورد الصيانة الدورية:
   - يعرض المركبات المستحقة أو القريبة للصيانة
   - مع حالة وجود أمر صيانة مفتوح
   Type: READ (LIST)
========================================================= */

CREATE PROCEDURE [VIC].[Dashboard_MaintenanceDue_DL]
(
      @daysAhead   INT = 7
    , @idaraID_FK  NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE @Now DATE = CAST(GETDATE() AS DATE);

    SELECT
          p.PlanID
        , p.chassisNumber_FK AS chassisNumber
        , v.plateLetters
        , v.plateNumbers
        , p.periodMonths
        , p.nextDueDate

        -- كم باقي يوم
        , DATEDIFF(DAY, @Now, CAST(p.nextDueDate AS DATE)) AS DaysToDue

        -- الحالة
        , CASE 
            WHEN CAST(p.nextDueDate AS DATE) < @Now THEN N'متأخرة'
            WHEN CAST(p.nextDueDate AS DATE) <= DATEADD(DAY, @daysAhead, @Now) THEN N'قريبة'
            ELSE N'طبيعية'
          END AS DueStatus

        -- هل فيه أمر مفتوح
        , CASE 
            WHEN EXISTS
            (
                SELECT 1
                FROM VIC.VehicleMaintenance m
                WHERE m.chassisNumber_FK = p.chassisNumber_FK
                  AND m.MaintOrdTypeID_FK = 265
                  AND m.MaintOrdActive = 1
            )
            THEN 1 ELSE 0
          END AS HasOpenOrder

    FROM VIC.VehicleMaintenancePlan p
    INNER JOIN VIC.Vehicles v
        ON v.chassisNumber = p.chassisNumber_FK

    WHERE p.planActive = 1
      AND (@IdaraID_BIG IS NULL OR p.IdaraID_FK = @IdaraID_BIG)
      AND CAST(p.nextDueDate AS DATE) <= DATEADD(DAY, @daysAhead, @Now)

    ORDER BY
          p.nextDueDate ASC;
END