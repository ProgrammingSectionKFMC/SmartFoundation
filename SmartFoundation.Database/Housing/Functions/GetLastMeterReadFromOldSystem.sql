-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GetLastMeterReadFromOldSystem] 
(
	-- Add the parameters for the function here
	  @buildingUtilityTypeID int,
	 --,@meterServiceTypeID int
	 --,@meterSlideSequence int
	  @meterNo nvarchar(20)
)
RETURNS int
AS
BEGIN
	-- Declare the return variable here
	DECLARE @ResultVar int
		IF(@buildingUtilityTypeID IN(2))
		BEGIN
			Set @ResultVar = ( 
		SELECT TOP (1) convert (int,bc.creading)
		FROM [electricbill].[dbo].[billcompanies] bc
		WHERE meterno = @meterNo
		order by bno desc
		)
		END
	-- Add the T-SQL statements to compute the return value here
		ELSE
		BEGIN
		Set @ResultVar = ( 
		SELECT TOP (1) convert (int,b.creading)
		FROM [electricbill].[dbo].[billdets] b
		WHERE meterno = @meterNo
		order by bno desc
		)
		END
	-- Return the result of the function
	RETURN @ResultVar

END
