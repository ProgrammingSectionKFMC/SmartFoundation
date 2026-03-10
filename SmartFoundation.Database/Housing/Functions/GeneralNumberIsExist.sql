-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GeneralNumberIsExist] 
(
	-- Add the parameters for the function here
	@generalNo_ INT
)
RETURNS bit
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result bit

	-- Add the T-SQL statements to compute the return value here
IF((SELECT COUNT(*) 
FROM Housing.ResidentInfo i INNER JOIN HOUSING.ResidentDetails d ON i.residentInfoID = d.residentInfoID_FK
WHERE d.generalNo_FK = @generalNo_) > 0)				
	BEGIN

		SET @Result = 1

	END
ELSE

	BEGIN

		SET @Result = 0

	END
	-- Return the result of the function
	RETURN @Result

END
