

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [dbo].[MergeDates] 
(
	-- Add the parameters for the function here
	@hijriDate nvarchar(50) = NULL,
	@greoDate Date = NULL
)
RETURNS nvarchar(100)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @MergeDate nvarchar(100)

	-- Add the T-SQL statements to compute the return value here
	IF(@hijriDate IS NULL AND @greoDate IS NOT NULL)

BEGIN

 SET @MergeDate =(SELECT CAST( CAST(g.gregorianDate AS DATE)AS nvarchar(100))+' - '+ g.hijriDateyyyymmdd_ FROM  dbo._GregorianHijriDate g WHERE g.gregorianDate = @greoDate) 

END
ELSE IF(@hijriDate IS NOT NULL AND @greoDate IS NULL)

BEGIN

 SET @MergeDate = (SELECT CAST( CAST(g.gregorianDate AS DATE)AS nvarchar(100))+' - '+ g.hijriDateyyyymmdd_ FROM  dbo._GregorianHijriDate g WHERE g.hijriDateyyyymmdd_ = @hijriDate) 

END
ELSE

BEGIN

 SET @MergeDate = N'لا يوجد تواريخ مدخلة'

END


	-- Return the result of the function
	RETURN @MergeDate 

END
