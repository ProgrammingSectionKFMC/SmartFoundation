
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GetCountAllResident]
(
	-- Add the parameters for the function here
	
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- Add the T-SQL statements to compute the return value here
	 SET @Result = 
					(
						SELECT count(*) N'AllResident' FROM Housing.ResidentDetails rd
    INNER JOIN Housing.ResidentInfo ri 
	ON rd.residentInfoID_FK = ri.residentInfoID
	WHERE rd.residentDetailsActive =1

					)

	-- Return the result of the function
	RETURN @Result

END
