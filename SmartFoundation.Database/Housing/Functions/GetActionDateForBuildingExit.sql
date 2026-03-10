-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GetActionDateForBuildingExit]
(
	-- Add the parameters for the function here
	@generalNo INT,
	@buildingDetailsNo NVARCHAR(20)
)
RETURNS DATE
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result DATE

	-- Add the T-SQL statements to compute the return value here
	 SET @Result = 
					(	
						SELECT cast(ba.buildingActionDate as date) buildingActionDate
						FROM  Housing.BuildingAction  ba
						WHERE   1=1
								AND(ba.buildingActionTypeID_FK=4)
								AND (ba.generalNo_FK = @generalNo)
								AND (ba.buildingDetailsNo=@buildingDetailsNo)

					)

	-- Return the result of the function
	RETURN  coalesce (@Result,CAST(GETDATE() AS date))

END
