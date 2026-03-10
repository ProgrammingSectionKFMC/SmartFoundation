-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GetCountAllMeter]
(
	-- Add the parameters for the function here
	@meterServiceTypeID INT
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- Add the T-SQL statements to compute the return value here
	 SET @Result = 
					(
						SELECT COUNT(*) N'إجمالي عدادات'
						FROM Housing.Meter AS m 
						INNER JOIN Housing.MeterType mt ON m.meterTypeID_FK = mt.meterTypeID
						WHERE (mt.meterServiceTypeID_FK = @meterServiceTypeID)
						GROUP BY mt.meterServiceTypeID_FK 

					)

	-- Return the result of the function
	RETURN coalesce(@Result,0)

END
