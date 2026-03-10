
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GetRentForBuilding]
(
	-- Add the parameters for the function here
	@buildingDetailsID INT
)
RETURNS decimal(10,2)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result decimal(10,2)

	-- Add the T-SQL statements to compute the return value here
	 SET @Result = 
					(
						SELECT TOP(1) buildingRentAmount
						FROM  Housing.BuildingRent
						WHERE buildingRentActive = 1 AND buildingDetailsID_FK = @buildingDetailsID
						ORDER BY buildingRentID desc


					)

	-- Return the result of the function
	RETURN  coalesce (@Result,0)

END
