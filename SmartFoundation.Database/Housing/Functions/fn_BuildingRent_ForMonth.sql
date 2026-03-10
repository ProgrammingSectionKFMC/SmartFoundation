
CREATE FUNCTION [Housing].[fn_BuildingRent_ForMonth]
(
      @Year  int
    , @Month int
)
RETURNS TABLE
AS
RETURN
WITH M AS
(
    SELECT
        MonthStart = DATEFROMPARTS(@Year, @Month, 1),
        MonthEnd   = EOMONTH(DATEFROMPARTS(@Year, @Month, 1))
),
-- ✅ كل البيوت المطلوبة (حتى لو ما لها إيجار)
H AS
(
    SELECT DISTINCT
        buildingDetailsID = v.buildingDetailsID
    FROM Housing.V_Buildingwithrent v
),
-- ✅ نجيب الإيجارات فقط للبيوت الموجودة في الفيو
RentBase AS
(
    SELECT
          br.buildingDetailsID_FK AS buildingDetailsID
        , MonthlyRent = CAST(br.buildingRentAmount AS decimal(18,2))
        , StartDate   = CAST(br.buildingRentStartDate AS date)
        , EndDate     = CAST(br.buildingRentEndDate   AS date)
        , NextStart   = LEAD(CAST(br.buildingRentStartDate AS date))
                        OVER (PARTITION BY br.buildingDetailsID_FK
                              ORDER BY br.buildingRentStartDate, br.buildingRentID)
    FROM Housing.BuildingRent br
    WHERE EXISTS (SELECT 1 FROM H WHERE H.buildingDetailsID = br.buildingDetailsID_FK)
),
-- ✅ نحولها لفترات فعّالة بدون تداخل
BR AS
(
    SELECT
          rb.buildingDetailsID
        , rb.MonthlyRent
        , RentStart = rb.StartDate
        , RentEnd   =
            CASE
              WHEN rb.NextStart IS NOT NULL THEN
                   CASE
                     WHEN DATEADD(DAY, -1, rb.NextStart) < ISNULL(rb.EndDate, m.MonthEnd)
                       THEN DATEADD(DAY, -1, rb.NextStart)
                     ELSE ISNULL(rb.EndDate, m.MonthEnd)
                   END
              ELSE ISNULL(rb.EndDate, m.MonthEnd)
            END
        , m.MonthStart
        , m.MonthEnd
    FROM RentBase rb
    CROSS JOIN M m
),
Overlaps AS
(
    SELECT
          br.buildingDetailsID
        , OverlapStart = CASE WHEN br.RentStart > br.MonthStart THEN br.RentStart ELSE br.MonthStart END
        , OverlapEnd   = CASE WHEN br.RentEnd   < br.MonthEnd   THEN br.RentEnd   ELSE br.MonthEnd   END
        , br.MonthlyRent
        , br.MonthStart
        , br.MonthEnd
    FROM BR br
    WHERE br.RentStart <= br.MonthEnd
      AND br.RentEnd   >= br.MonthStart
),
DaysCalc AS
(
    SELECT
          buildingDetailsID
        , MonthStart
        , MonthEnd
        , MonthlyRent
        , Days30 =
          (
            (
                (YEAR(OverlapEnd) - YEAR(OverlapStart)) * 360
              + (MONTH(OverlapEnd) - MONTH(OverlapStart)) * 30
              + (
                    (CASE
                        WHEN OverlapEnd = EOMONTH(OverlapEnd) AND DAY(OverlapEnd) < 30 THEN 30
                        WHEN DAY(OverlapEnd) > 30 THEN 30
                        ELSE DAY(OverlapEnd)
                     END)
                    -
                    (CASE
                        WHEN OverlapStart = EOMONTH(OverlapStart) AND DAY(OverlapStart) < 30 THEN 30
                        WHEN DAY(OverlapStart) > 30 THEN 30
                        ELSE DAY(OverlapStart)
                     END)
                )
            ) + 1
          )
    FROM Overlaps
    WHERE OverlapStart <= OverlapEnd
),
Agg AS
(
    SELECT
          buildingDetailsID
        , MonthStart
        , RentForMonth  = CAST(SUM((MonthlyRent / 30.0) * Days30) AS decimal(18,2))
        , Days30InMonth = SUM(Days30)
    FROM DaysCalc
    GROUP BY buildingDetailsID, MonthStart
)
SELECT
      h.buildingDetailsID
    , [Year]  = @Year
    , [Month] = @Month
    , RentForMonth  = COALESCE(a.RentForMonth,  CAST(0.00 AS decimal(18,2)))
    , Days30InMonth = COALESCE(a.Days30InMonth, 0)
FROM H h
LEFT JOIN Agg a
    ON a.buildingDetailsID = h.buildingDetailsID;
