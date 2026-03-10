CREATE FUNCTION [dbo].[GetRank]
(
	-- Add the parameters for the function here
	@userID int
)
RETURNS NVARCHAR (100)
AS
BEGIN
	DECLARE @result NVARCHAR (100)

	SET @result = (	SELECT d.distributorName_A AS [rank]
					FROM dbo.UserDistributor ud 
						INNER JOIN dbo.Distributor  d ON ud.distributorID_FK = d.distributorID 
					WHERE 1=1
						AND (d.distributorType_FK = 3) 
						AND (ud.UDActive = 1)
						AND (ud.UDStartDate IS NOT NULL)
						AND (ud.UDEndDate IS NULL)
						AND (ud.userID_FK=@userID))

	-- Return the result of the function
	RETURN @result

END