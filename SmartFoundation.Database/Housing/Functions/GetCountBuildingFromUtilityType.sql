
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GetCountBuildingFromUtilityType] 
(
	-- Add the parameters for the function here
	@buildingUtilityTypeID INT
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- Add the T-SQL statements to compute the return value here
	 SET @Result = 
					(SELECT count(*) 'Utility Type'
						FROM Housing.BuildingDetails bd
						INNER JOIN Housing.BuildingUtilityType but ON bd.buildingUtilityTypeID_FK = but.buildingUtilityTypeID
						WHERE but.buildingUtilityTypeActive = 1 AND but.buildingUtilityTypeID = @buildingUtilityTypeID

					)

	-- Return the result of the function
	RETURN @Result

END
