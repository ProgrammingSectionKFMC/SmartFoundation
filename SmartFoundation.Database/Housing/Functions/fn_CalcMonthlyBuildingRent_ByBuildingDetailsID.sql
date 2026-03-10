CREATE FUNCTION [Housing].[fn_CalcMonthlyBuildingRent_ByBuildingDetailsID]
(
      @buildingDetailsID INT
    , @FromDate          DATE
    , @ToDate            DATE = NULL
)
RETURNS TABLE
AS
RETURN
WITH Params AS
(
    SELECT
          buildingDetailsID = @buildingDetailsID
        , FromDate          = @FromDate
        , CalcTo            = ISNULL(@ToDate, CAST(GETDATE() AS DATE))
),
Bounds AS
(
    SELECT
          p.buildingDetailsID
        , p.FromDate
        , p.CalcTo
        , FirstMonth = DATEFROMPARTS(YEAR(p.FromDate), MONTH(p.FromDate), 1)
        , LastMonth  = DATEFROMPARTS(YEAR(p.CalcTo),  MONTH(p.CalcTo),  1)
        , MonthsCount = DATEDIFF(MONTH,
                                DATEFROMPARTS(YEAR(p.FromDate), MONTH(p.FromDate), 1),
                                DATEFROMPARTS(YEAR(p.CalcTo),  MONTH(p.CalcTo),  1)
                               )
    FROM Params p
    WHERE p.FromDate IS NOT NULL
      AND p.CalcTo >= p.FromDate
),
Nums AS
(
    SELECT TOP (2400)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
),
Months AS
(
    SELECT
          b.buildingDetailsID
        , b.FromDate
        , b.CalcTo
        , MonthStart = DATEADD(MONTH, n.n, b.FirstMonth)
        , MonthEnd   = EOMONTH(DATEADD(MONTH, n.n, b.FirstMonth))
        , YearMonth  = CONVERT(CHAR(7), DATEADD(MONTH, n.n, b.FirstMonth), 120)
    FROM Bounds b
    JOIN Nums n
      ON n.n <= b.MonthsCount
),
MonthWindow AS
(
    SELECT
          m.buildingDetailsID
        , m.YearMonth
        , m.MonthStart
        , m.MonthEnd
        , CalcFromDate = CASE WHEN m.FromDate > m.MonthStart THEN m.FromDate ELSE m.MonthStart END
        , CalcToDate   = CASE WHEN m.CalcTo   < m.MonthEnd   THEN m.CalcTo   ELSE m.MonthEnd   END
    FROM Months m
),

/* ✅ هنا التعديل: نمنع تداخل فترات الإيجار */
RentBase AS
(
    SELECT
          br.buildingDetailsID_FK AS buildingDetailsID
        , MonthlyRent = CAST(br.buildingRentAmount AS DECIMAL(18,2))
        , StartDate   = CAST(br.buildingRentStartDate AS DATE)
        , EndDateRaw  = CAST(br.buildingRentEndDate AS DATE)
        , NextStart   = LEAD(CAST(br.buildingRentStartDate AS DATE))
                       OVER (PARTITION BY br.buildingDetailsID_FK ORDER BY br.buildingRentStartDate, br.buildingRentID)
    FROM Housing.BuildingRent br
    WHERE br.buildingDetailsID_FK = @buildingDetailsID
),
RentRows AS
(
    SELECT
          rb.buildingDetailsID
        , rb.MonthlyRent
        , PeriodStart =
            CASE WHEN rb.StartDate > p.FromDate THEN rb.StartDate ELSE p.FromDate END
        , PeriodEnd =
            CASE
                -- لو فيه سجل لاحق يبدأ قبل/داخل نهاية الحالي: خل نهاية الحالي = اليوم قبل بداية اللاحق
                WHEN rb.NextStart IS NOT NULL
                     AND (rb.EndDateRaw IS NULL OR rb.NextStart <= rb.EndDateRaw)
                    THEN DATEADD(DAY, -1, rb.NextStart)

                -- وإلا استخدم EndDateRaw أو CalcTo
                ELSE ISNULL(rb.EndDateRaw, p.CalcTo)
            END
    FROM RentBase rb
    JOIN Params p
      ON p.buildingDetailsID = rb.buildingDetailsID
),

Overlaps AS
(
    SELECT
          mw.buildingDetailsID
        , mw.YearMonth
        , mw.MonthStart
        , mw.MonthEnd
        , mw.CalcFromDate
        , mw.CalcToDate
        , rr.MonthlyRent
        , OverlapStart = CASE WHEN rr.PeriodStart > mw.CalcFromDate THEN rr.PeriodStart ELSE mw.CalcFromDate END
        , OverlapEnd   = CASE WHEN rr.PeriodEnd   < mw.CalcToDate   THEN rr.PeriodEnd   ELSE mw.CalcToDate   END
    FROM MonthWindow mw
    JOIN RentRows rr
      ON rr.PeriodStart <= mw.CalcToDate
     AND rr.PeriodEnd   >= mw.CalcFromDate
),
Valid AS
(
    SELECT *
    FROM Overlaps
    WHERE OverlapStart <= OverlapEnd
),
DaysCalc AS
(
    SELECT
          buildingDetailsID
        , YearMonth
        , MonthStart
        , MonthEnd
        , CalcFromDate
        , CalcToDate
        , MonthlyRent
        , OverlapStart
        , OverlapEnd
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
    FROM Valid
)
SELECT
      buildingDetailsID
    , YearMonth
    , [Year]  = YEAR(MonthStart)
    , [Month] = MONTH(MonthStart)
    , MonthStart
    , MonthEnd
    , CalcFromDate
    , CalcToDate
    , RentForMonth  = CAST(SUM((MonthlyRent / 30.0) * Days30) AS DECIMAL(18,2))
    , Days30InMonth = SUM(Days30)
FROM DaysCalc
GROUP BY
      buildingDetailsID
    , YearMonth
    , MonthStart
    , MonthEnd
    , CalcFromDate
    , CalcToDate;
