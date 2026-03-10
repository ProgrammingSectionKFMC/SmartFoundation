-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [dbo].[genderID] (@generalNo int) 

RETURNS int
AS
BEGIN
	-- Declare the return variable here
	DECLARE @genderID int

	SET @genderID = (SELECT CONVERT(INT,[gender])  genderID FROM [payroll].[dbo].[personel] where fno = @generalNo)
	
	RETURN @genderID

END
