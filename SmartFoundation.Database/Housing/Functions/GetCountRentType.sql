
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GetCountRentType] 
(
	-- Add the parameters for the function here
	@buildingRentTypeID INT
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- Add the T-SQL statements to compute the return value here
	 SET @Result = 
					(SELECT COUNT(*) 'Rent Type'
					FROM  Housing.BuildingDetails bd
					INNER JOIN  Housing.BuildingRent br ON bd.buildingDetailsID = br.buildingDetailsID_FK
					INNER JOIN  Housing.BuildingRentType brt ON br.buildingRentTypeID_FK = brt.buildingRentTypeID
					WHERE brt.buildingRentTypeActive = 1 AND brt.buildingRentTypeID = @buildingRentTypeID

					)

	-- Return the result of the function
	RETURN @Result

END
