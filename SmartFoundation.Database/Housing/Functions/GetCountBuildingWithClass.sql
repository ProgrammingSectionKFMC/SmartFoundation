
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GetCountBuildingWithClass]
(
	-- Add the parameters for the function here
	@buildingClassID INT
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- Add the T-SQL statements to compute the return value here
	 SET @Result = 
					(
						SELECT count (*) 'Building Class'
						from Housing.BuildingDetails bd
						inner join Housing.BuildingClass bc on bd.buildingClassID_FK=bc.buildingClassID
						WHERE bc.buildingClassActive = 1 AND bc.buildingClassID = @buildingClassID

					)

	-- Return the result of the function
	RETURN @Result

END
