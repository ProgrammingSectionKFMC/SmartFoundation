-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[BuildingRentForOneMonth]
	-- Add the parameters for the stored procedure here
	@Month int,
	@Year int,
	@entrydata Nvarchar(20),
	@hostname Nvarchar(200)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

DECLARE @MonthStart date, @MonthEnd date;

SET @MonthStart = DATEFROMPARTS(@Year, @Month, 1);
SET @MonthEnd   = EOMONTH(@MonthStart);

SELECT 
      o.residentInfoID
    , o.buildingDetailsID
    , 1 AS buildingRentTypeID_FK
    , w.RentForMonth AS rentBillsAmount
    , w.CalcFromDate AS rentBillsFromDate
    , w.CalcToDate   AS rentBillsToDate
    , 1 AS rentBillsActive
    , 1 AS idaraID_FK
    , @entrydata AS entrydata
    , @hostname  AS hostname
FROM Housing.V_Occupant o
CROSS APPLY Housing.fn_CalcBuildingRent_ForOneMonth
(
      o.buildingDetailsID
    , CAST(o.OccupentDate AS date)  -- FromDate
    , @Year
    , @Month
    , NULL                           -- ToDate (VacateDate لو عندك)
) w
WHERE CAST(o.OccupentDate AS date) <= @MonthEnd
ORDER BY o.buildingDetailsID ASC;




END
