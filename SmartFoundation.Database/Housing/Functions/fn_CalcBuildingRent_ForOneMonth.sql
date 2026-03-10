CREATE   FUNCTION [Housing].[fn_CalcBuildingRent_ForOneMonth]
(
      @buildingDetailsID INT
    , @FromDate          DATE              -- مثل OccupentDate
    , @Year              INT
    , @Month             INT
    , @ToDate            DATE = NULL       -- اختياري (مثلاً VacateDate)؛ إذا NULL يحسب لنهاية الشهر
)
RETURNS TABLE
AS
RETURN
WITH M AS
(
    SELECT
          MonthStart = DATEFROMPARTS(@Year, @Month, 1)
        , MonthEnd   = EOMONTH(DATEFROMPARTS(@Year, @Month, 1))
),
Params AS
(
    SELECT
          buildingDetailsID = @buildingDetailsID
        , FromDate          = @FromDate
        , MonthStart        = m.MonthStart
        , MonthEnd          = m.MonthEnd
        , CalcTo            = CASE
                                WHEN @ToDate IS NULL THEN m.MonthEnd
                                WHEN @ToDate > m.MonthEnd THEN m.MonthEnd
                                ELSE @ToDate
                              END
        , CalcFromDate      = CASE
                                WHEN @FromDate > m.MonthStart THEN @FromDate
                                ELSE m.MonthStart
                              END
    FROM M m
    WHERE @FromDate IS NOT NULL
),
/* ✅ نفس منطق الفنكشن الأخيرة: منع تداخل فترات الإيجار */
RentBase AS
(
    SELECT
          br.buildingDetailsID_FK AS buildingDetailsID
        , MonthlyRent = CAST(br.buildingRentAmount AS DECIMAL(18,2))
        , StartDate   = CAST(br.buildingRentStartDate AS DATE)
        , EndDateRaw  = CAST(br.buildingRentEndDate AS DATE)
        , NextStart   = LEAD(CAST(br.buildingRentStartDate AS DATE))
                       OVER (PARTITION BY br.buildingDetailsID_FK
                             ORDER BY br.buildingRentStartDate, br.buildingRentID)
    FROM Housing.BuildingRent br
    WHERE br.buildingDetailsID_FK = @buildingDetailsID
),
RentRows AS
(
    SELECT
          rb.buildingDetailsID
        , rb.MonthlyRent
        , PeriodStart =
            CASE WHEN rb.StartDate > p.CalcFromDate THEN rb.StartDate ELSE p.CalcFromDate END
        , PeriodEnd =
            CASE
                WHEN rb.NextStart IS NOT NULL
                     AND (rb.EndDateRaw IS NULL OR rb.NextStart <= rb.EndDateRaw)
                    THEN DATEADD(DAY, -1, rb.NextStart)
                ELSE ISNULL(rb.EndDateRaw, p.CalcTo)
            END
        , p.CalcTo
        , p.CalcFromDate
        , p.MonthStart
        , p.MonthEnd
    FROM RentBase rb
    JOIN Params p
      ON p.buildingDetailsID = rb.buildingDetailsID
),
RentRowsFixed AS
(
    SELECT
          buildingDetailsID
        , MonthlyRent
        , PeriodStart
        , PeriodEnd = CASE WHEN PeriodEnd > CalcTo THEN CalcTo ELSE PeriodEnd END
        , CalcFromDate
        , CalcTo
        , MonthStart
        , MonthEnd
    FROM RentRows
    WHERE PeriodStart IS NOT NULL
      AND PeriodEnd   IS NOT NULL
      AND PeriodEnd >= PeriodStart   -- ✅ حماية من أي فترة سالبة
),
Overlaps AS
(
    SELECT
          r.buildingDetailsID
        , r.MonthStart
        , r.MonthEnd
        , r.CalcFromDate
        , CalcToDate = r.CalcTo
        , r.MonthlyRent
        , OverlapStart = CASE WHEN r.PeriodStart > r.CalcFromDate THEN r.PeriodStart ELSE r.CalcFromDate END
        , OverlapEnd   = CASE WHEN r.PeriodEnd   < r.CalcTo       THEN r.PeriodEnd   ELSE r.CalcTo       END
    FROM RentRowsFixed r
    WHERE r.PeriodStart <= r.CalcTo
      AND r.PeriodEnd   >= r.CalcFromDate
),
DaysCalc AS
(
    SELECT
          buildingDetailsID
        , MonthStart
        , MonthEnd
        , CalcFromDate
        , CalcToDate
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
)
SELECT
      buildingDetailsID
    , YearMonth   = CONVERT(CHAR(7), MonthStart, 120)
    , [Year]      = YEAR(MonthStart)
    , [Month]     = MONTH(MonthStart)
    , MonthStart
    , MonthEnd
    , CalcFromDate
    , CalcToDate
    , RentForMonth  = CAST(SUM((MonthlyRent / 30.0) * Days30) AS DECIMAL(18,2))
    , Days30InMonth = SUM(Days30)
FROM DaysCalc
GROUP BY
      buildingDetailsID
    , MonthStart
    , MonthEnd
    , CalcFromDate
    , CalcToDate;
