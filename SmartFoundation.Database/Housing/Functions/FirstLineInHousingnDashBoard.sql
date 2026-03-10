
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[FirstLineInHousingnDashBoard] 
(
	-- Add the parameters for the function here
	@TypeOfTotal INT
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- Add the T-SQL statements to compute the return value here
	 SET @Result = 
					(

					SELECT COUNT(*) N'عدد المستفيدين المسجلة' 

			        FROM [Housing].[ResidentInfo] ri

					)

	-- Return the result of the function
	RETURN @Result

END

