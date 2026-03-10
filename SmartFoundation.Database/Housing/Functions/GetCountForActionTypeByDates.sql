
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Housing].[GetCountForActionTypeByDates]
(
	-- Add the parameters for the function here
	@buildingActionTypeID int,
	@fromDate datetime = NULL ,
	@toDate datetime = NULL
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- Add the T-SQL statements to compute the return value here
	IF(@fromDate IS NULL AND @toDate IS NULL)
	BEGIN
		IF (@buildingActionTypeID = 1)
		BEGIN
			SET @Result = ( SELECT COUNT(*) 
			FROM Housing.BuildingAction 
			WHERE buildingActionTypeID_FK = 1 
			AND generalNo_FK NOT IN (
			SELECT generalNo_FK 
			FROM Housing.BuildingAction 
			WHERE buildingActionTypeID_FK = 2
			))
		END
		ELSE
		BEGIN
			SET @Result = (SELECT COUNT(*)
			FROM Housing.BuildingAction ba
			WHERE ba.buildingActionTypeID_FK = @buildingActionTypeID)
		END
	END
	ELSE IF(@fromDate IS NOT NULL AND @toDate IS NULL)
	BEGIN
		SET @Result = (SELECT COUNT(*)
		FROM Housing.BuildingAction ba
		WHERE ba.buildingActionTypeID_FK = @buildingActionTypeID
		AND CAST(ba.buildingActionDate as DATE)>= CAST( @fromDate AS DATE))
	END
	ELSE IF(@fromDate IS NULL AND @toDate IS NOT NULL)
	BEGIN
		SET @Result = (SELECT COUNT(*)
		FROM Housing.BuildingAction ba
		WHERE ba.buildingActionTypeID_FK = @buildingActionTypeID
		AND CAST(ba.buildingActionDate as DATE)<= CAST( @toDate AS DATE))
	END
	ELSE
	BEGIN
		SET @Result = (SELECT COUNT(*)
		FROM Housing.BuildingAction ba
		WHERE ba.buildingActionTypeID_FK = @buildingActionTypeID
		AND CAST(ba.buildingActionDate as DATE)BETWEEN (CAST( @fromDate AS DATE)) AND CAST(@toDate AS DATE))
	END
	-- Return the result of the function
	RETURN @Result

END
