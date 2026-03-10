
CREATE FUNCTION [Housing].[GetCountBuildingForActionTypeWithClassID]
(
    @buildingActionTypeID INT,
	@buildingClassID INT 
)
RETURNS INT
AS
BEGIN
	DECLARE @Result INT
	SET @Result = (
					SELECT COUNT(*) FROM (
					SELECT bd.buildingDetailsNo, MAX(ba.buildingActionID) BuildingActionID, ba.buildingActionTypeID_FK
					FROM Housing.BuildingDetails bd
					LEFT JOIN Housing.BuildingAction ba ON bd.buildingDetailsNo = ba.buildingDetailsNo
					INNER JOIN Housing.BuildingClass bc ON bd.buildingClassID_FK = bc.buildingClassID
					WHERE bc.buildingClassID = @buildingClassID
					GROUP BY bd.buildingDetailsNo, ba.buildingActionTypeID_FK, bc.buildingClassID) iii
					WHERE iii.buildingActionTypeID_FK = @buildingActionTypeID
					)
    RETURN @Result

END
