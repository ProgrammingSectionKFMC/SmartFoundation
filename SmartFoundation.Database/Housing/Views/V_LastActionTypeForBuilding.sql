
CREATE VIEW [Housing].[V_LastActionTypeForBuilding]
AS
SELECT
    x.buildingActionID,
    x.buildingDetailsID_FK AS buildingDetailsID,
    x.buildingActionTypeID_FK AS LastActionTypeID
FROM
(
    SELECT
        b.buildingActionID,
        b.buildingDetailsID_FK,
        b.buildingActionTypeID_FK,
        ROW_NUMBER() OVER
        (
            PARTITION BY b.buildingDetailsID_FK
            ORDER BY b.buildingActionID DESC
        ) AS rn
    FROM Housing.BuildingAction b
    WHERE b.buildingActionActive = 1 and b.buildingDetailsID_FK is not null and b.buildingActionActive = 1
) x
WHERE x.rn = 1