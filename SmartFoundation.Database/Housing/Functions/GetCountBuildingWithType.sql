
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GetCountBuildingWithType] 
(
	-- Add the parameters for the function here
	@buildingTypeID INT
)
RETURNS nvarchar(200)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result nvarchar(100)

	-- Add the T-SQL statements to compute the return value here
	DECLARE @buildingType nvarchar(100)
	 SET @Result = 
					(SELECT count(*) 'Building Type'
							FROM Housing.BuildingDetails bd
							INNER JOIN Housing.BuildingType bt ON bd.buildingTypeID_FK = bt.buildingTypeID
							WHERE bt.buildingTypeActive = 1 AND bt.buildingTypeID = @buildingTypeID

					)
	SET @buildingType = (SELECT TOP(1) buildingTypeName_A FROM Housing.BuildingType WHERE buildingTypeID = @buildingTypeID)
	--SET @Result = @buildingType +'    '+ @Result

	-- Return the result of the function
	RETURN @Result 

END
