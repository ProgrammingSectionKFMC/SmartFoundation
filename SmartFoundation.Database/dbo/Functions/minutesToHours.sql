CREATE FUNCTION [dbo].[minutesToHours]
(
 	@minutes INT , @type NVARCHAR(100) =NULL
)
RETURNS NVARCHAR(100) 
AS
BEGIN
	 RETURN  CASE WHEN @minutes < 60 THEN CONVERT(NVARCHAR,@minutes) + ' ' +N'د' 
		ELSE 
			CASE WHEN @type IS NULL THEN CONVERT(NVARCHAR,CONVERT(DECIMAL(10,1),@minutes/60.0)) + ' ' +N'س' 
			WHEN @type = 'hh mm' THEN CONVERT(NVARCHAR, @minutes/60 ) +N'س' + CASE WHEN @minutes%60 = 0 THEN '' ELSE N' ' + CONVERT(NVARCHAR, @minutes%60 )+ N'د' END 
			ELSE NULL 
			END 
		END 
END
