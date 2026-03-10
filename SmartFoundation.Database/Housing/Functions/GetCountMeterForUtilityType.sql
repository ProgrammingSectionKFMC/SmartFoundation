-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GetCountMeterForUtilityType]
(
	-- Add the parameters for the function here
	@buildingUtilityTypeID INT,
	@meterServiceTypeID INT
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- Add the T-SQL statements to compute the return value here
	 SET @Result = 
					(
						SELECT COUNT(*) N'عدد العدادات'
						FROM Housing.Meter AS m INNER JOIN
                         Housing.MeterType AS mt ON m.meterTypeID_FK = mt.meterTypeID INNER JOIN
                         Housing.MeterForBuilding AS mb ON m.meterID = mb.meterID_FK INNER JOIN
                         Housing.BuildingDetails AS bd ON mb.buildingDetailsID_FK = bd.buildingDetailsID
						WHERE (mt.meterServiceTypeID_FK = @meterServiceTypeID) AND (bd.buildingUtilityTypeID_FK = @buildingUtilityTypeID)
						GROUP BY bd.buildingUtilityTypeID_FK

					)

	-- Return the result of the function
	RETURN coalesce( @Result,0)

END
