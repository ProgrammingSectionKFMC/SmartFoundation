

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GetBuildingNoByResidentGeneralNo]
(
	-- Add the parameters for the function here
	@generalNo_FK INT
)
RETURNS NVARCHAR(20)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result nvarchar(20)

	-- Add the T-SQL statements to compute the return value here
	 SET @Result = 
					(
						SELECT TOP (1) ba.buildingDetailsNo 
						from Housing.BuildingAction ba
						WHERE  ba.generalNo_FK = @generalNo_FK
						ORDER BY ba.buildingActionID desc

					)

	-- Return the result of the function
	RETURN @Result

END
