
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [dbo].[CountFridaysBetweenTwoDates]
(
    @StartDate DATE,
    @EndDate DATE
)
RETURNS INT
AS
BEGIN
    DECLARE @NumberOfFridays INT;

    -- Count the number of Fridays between the two dates
    SELECT @NumberOfFridays = (select count(*) from dbo._GregorianHijriDate gh
	where 1=1
	and CAST(gh.gregorianDate AS DATE) between @StartDate and @EndDate
	and DATEPART(DW,CAST(gh.gregorianDate AS DATE)) =6); -- 6 indicates Friday (assuming the first day of the week is Sunday)

    RETURN @NumberOfFridays;
END;
