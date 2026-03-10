

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GetLastActionForResident]
(
	-- Add the parameters for the function here
	@generalNo_FK INT
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- Add the T-SQL statements to compute the return value here
	 SET @Result = 
					(
						SELECT TOP (1) ba.buildingActionTypeID_FK 
						from  Housing.BuildingAction ba
						WHERE  ba.generalNo_FK = @generalNo_FK
						ORDER BY ba.buildingActionID desc

					)

	-- Return the result of the function
	RETURN @Result

END
