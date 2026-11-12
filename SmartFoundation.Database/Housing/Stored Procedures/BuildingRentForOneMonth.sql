
CREATE   PROCEDURE [Housing].[BuildingRentForOneMonth]
    @Month int,
    @Year int,
    @entrydata Nvarchar(20),
    @hostname Nvarchar(200),
    @idaraID int 
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MonthStart date, @MonthEnd date;

    SET @MonthStart = DATEFROMPARTS(@Year, @Month, 1);
    SET @MonthEnd   = EOMONTH(@MonthStart);

    SELECT 
          o.residentInfoID
        , o.buildingDetailsID
        , 1 AS buildingRentTypeID_FK

        , CAST(w.RentForMonth AS DECIMAL(18,2)) AS rentBillsAmount

        , w.CalcFromDate AS rentBillsFromDate
        , w.CalcToDate   AS rentBillsToDate
        , 1 AS rentBillsActive
        , @idaraID AS idaraID_FK
        , @entrydata AS entrydata
        , @hostname  AS hostname


    FROM Housing.V_Occupant o

    CROSS APPLY Housing.fn_CalcBuildingRent_ForOneMonth
    (
          o.buildingDetailsID
        , CAST(o.OccupentDate AS date)
        , @Year
        , @Month
        , CAST(o.ExitDate AS date)
    ) w

   OUTER APPLY
(
    SELECT
          ExemptDays30 = SUM(x.ExemptDays30)
        , ExemptionAmount =
            CAST(
                (w.RentForMonth / NULLIF(w.Days30InMonth, 0)) 
                * SUM(x.ExemptDays30)
            AS DECIMAL(18,2))
    FROM
    (
        SELECT
            ExemptDays30 =
            (
                (
                    (YEAR(ExemptEnd) - YEAR(ExemptStart)) * 360
                  + (MONTH(ExemptEnd) - MONTH(ExemptStart)) * 30
                  + (
                        (CASE
                            WHEN ExemptEnd = EOMONTH(ExemptEnd) AND DAY(ExemptEnd) < 30 THEN 30
                            WHEN DAY(ExemptEnd) > 30 THEN 30
                            ELSE DAY(ExemptEnd)
                         END)
                        -
                        (CASE
                            WHEN ExemptStart = EOMONTH(ExemptStart) AND DAY(ExemptStart) < 30 THEN 30
                            WHEN DAY(ExemptStart) > 30 THEN 30
                            ELSE DAY(ExemptStart)
                         END)
                    )
                ) + 1
            )
        FROM
        (
            SELECT
                  ExemptStart =
                    CASE
                        WHEN CAST(ex.residentRentExemptionStartDate AS date) < w.CalcFromDate
                            THEN w.CalcFromDate
                        ELSE CAST(ex.residentRentExemptionStartDate AS date)
                    END
                , ExemptEnd =
                    CASE
                        WHEN ex.residentRentExemptionEndDate IS NULL
                             OR CAST(ex.residentRentExemptionEndDate AS date) > w.CalcToDate
                            THEN w.CalcToDate
                        ELSE CAST(ex.residentRentExemptionEndDate AS date)
                    END
            FROM Housing.ResidentRentExemption ex
            WHERE ex.residentInfoID_FK = o.residentInfoID
              AND ex.buildingDetailsID_FK = o.buildingDetailsID
              AND ISNULL(ex.residentRentExemptionActive, 0) = 1
              AND CAST(ex.residentRentExemptionStartDate AS date) <= w.CalcToDate
              AND (
                     ex.residentRentExemptionEndDate IS NULL
                     OR CAST(ex.residentRentExemptionEndDate AS date) >= w.CalcFromDate
                  )
        ) d
        WHERE ExemptStart <= ExemptEnd
    ) x
) exm

    WHERE CAST(o.OccupentDate AS date) <= @MonthEnd
      AND (o.ExitDate IS NULL OR CAST(o.ExitDate AS date) >= @MonthStart)
      AND o.IdaraId = @idaraID

    ORDER BY o.buildingDetailsID ASC;

END

GO

