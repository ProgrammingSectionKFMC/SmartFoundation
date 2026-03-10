
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GetCountBuildingForActionTypeID]
(
	-- Add the parameters for the function here
	@buildingActionTypeID INT
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- Add the T-SQL statements to compute the return value here
	 SET @Result = 
					(  SELECT COUNT(*)
                       FROM Housing.BuildingAction ba
					   WHERE 
						(	SELECT TOP (1) ba.buildingActionTypeID_FK 
							from Housing.BuildingAction baa	
							WHERE  baa.buildingDetailsNo = ba.buildingDetailsNo 
							ORDER BY baa.buildingActionID desc
						)=@buildingActionTypeID 
					)

	-- Return the result of the function
	RETURN  coalesce (@Result,0)

END
