
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GetCountForHousingWithPrivteConditions]
(
	-- Add the parameters for the function here
	@buildingActionTypeID int,
	@bug int
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- Add the T-SQL statements to compute the return value here
	


	-- عدد الساكنين بدون امر سكن
		IF (@buildingActionTypeID = 2 AND @bug = 1)
		BEGIN
			SET @Result = ( SELECT COUNT(*) N'عدد الساكنين بدون امر سكن'
			FROM Housing.BuildingAction b
			WHERE b.buildingActionTypeID_FK = 2 
			AND (b.buildingActionDecisionDate IS NULL OR b.buildingActionDecisionNo IS NULL))
		END


		-- عدد الساكنين مع امر سكن
		ELSE IF (@buildingActionTypeID = 2 AND @bug = 2)
		BEGIN
			SET @Result = ( SELECT COUNT(*) N'عدد الساكنين مع امر سكن'
			FROM Housing.BuildingAction b
			WHERE b.buildingActionTypeID_FK = 2 
			AND (b.buildingActionDecisionDate IS NOT NULL AND b.buildingActionDecisionNo IS NOT NULL))
		END



		ELSE
		BEGIN
			SET @Result = (SELECT COUNT(*)
			FROM Housing.BuildingAction ba
			WHERE ba.buildingActionTypeID_FK = @buildingActionTypeID)
		END
	
	
	-- Return the result of the function
	RETURN @Result

END
