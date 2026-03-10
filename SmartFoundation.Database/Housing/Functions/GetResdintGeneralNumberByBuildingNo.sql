
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GetResdintGeneralNumberByBuildingNo]
(
	-- Add the parameters for the function here
	@buildingDetailsNo NVARCHAR(20)
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- Add the T-SQL statements to compute the return value here
	 SET @Result = 
					(
						SELECT TOP (1) ba.generalNo_FK 
						from  Housing.BuildingAction ba
						
						WHERE  ba.buildingDetailsNo = @buildingDetailsNo AND ba.buildingActionTypeID_FK = 2
						ORDER BY ba.buildingActionID desc

					)

	-- Return the result of the function
	RETURN @Result

END
