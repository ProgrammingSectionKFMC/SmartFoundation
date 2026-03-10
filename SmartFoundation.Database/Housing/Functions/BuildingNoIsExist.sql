-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION Housing.BuildingNoIsExist 
(
	-- Add the parameters for the function here
	@buildingNo nvarchar(20)
)
RETURNS bit
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result bit

	-- Add the T-SQL statements to compute the return value here
IF((SELECT COUNT(*) FROM Housing.BuildingDetails WHERE buildingDetailsNo = @buildingNo AND buildingDetailsActive = 1) > 0)				
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
