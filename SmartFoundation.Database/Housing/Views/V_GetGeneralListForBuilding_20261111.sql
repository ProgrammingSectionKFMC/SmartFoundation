

/*
  Housing.V_GetGeneralListForBuilding
  Scoped correction for proven migrated 47 -> 2 reversed-ID chains.
  Preserves ALL existing output columns, joins, eligibility filters, and
  existing 3/58 suppression logic for other cases.

  Tested diagnostic baseline (2026-11-10):
    435 apparent 47 buildings -> 392 type 2, 13 type 24, 10 type 4, 20 type 5.

  IMPORTANT:
    - No special building IDs, resident IDs, or Idara filter.
    - The operating root is chosen only after a demonstrated 3/57 exit
      and only if it has no active direct children.
    - This is a focused repair, NOT a proved universal redesign of every
      independent operational and resident cycle.
    - Execute only after reviewing and approving the change.
*/
CREATE VIEW [Housing].[V_GetGeneralListForBuilding_20261111]
AS
SELECT
     bd.[buildingDetailsID]
    ,bd.[buildingDetailsNo]
    ,bd.[buildingDetailsRooms]
    ,bd.[buildingLevelsCount]
    ,bd.[buildingDetailsArea]
    ,bd.[buildingDetailsCoordinates]
    ,bd.[buildingTypeID_FK]
    ,bt.[buildingTypeName_A]
    ,bd.[buildingUtilityTypeID_FK]
    ,bu.[buildingUtilityTypeName_A]
    ,bd.[militaryLocationID_FK]
    ,m.[militaryLocationName_A]
    ,mac.militaryAreaCityName_A
    ,ma.militaryAreaName_A
    ,bd.[buildingClassID_FK]
    ,bc.[buildingClassName_A]
    ,bd.[buildingDetailsTel_1]
    ,bd.[buildingDetailsTel_2]
    ,bd.[buildingDetailsRemark]
    ,bd.[buildingDetailsStartDate]
    ,bd.[buildingDetailsEndDate]
    ,bd.[buildingDetailsActive]
    ,bu.[buildingUtilityIsRent]
    ,bd.[IdaraId_FK] AS BuildingIdaraID
    ,i.idaraLongName_A AS BuildingIdaraName
    ,bt.[IdaraId_FK] AS BuildingTypeIdaraID
    ,bu.[IdaraId_FK] AS BuildingUtilityTypeIdaraID
    ,m.[IdaraId_FK] AS MilitaryLocationIdaraID
    ,bc.[IdaraId_FK] AS BuildingClassIdaraID
    ,effectiveAction.buildingActionID AS LastActionID
    ,effectiveAction.buildingActionTypeID_FK AS LastActionTypeID
    ,bat.buildingActionTypeName_A AS LastActionTypeName
    ,bat.buildingActionTypeBuildingAlias AS LastActionTypeBuildingAlias
    ,effectiveAction.entryDate AS LastActionEntryDate
    ,effectiveAction.buildingActionNote AS LastActionNote
FROM Housing.BuildingDetails bd
INNER JOIN Housing.BuildingType bt
    ON bd.buildingTypeID_FK = bt.buildingTypeID
INNER JOIN Housing.BuildingUtilityType bu
    ON bd.buildingUtilityTypeID_FK = bu.buildingUtilityTypeID
INNER JOIN Housing.MilitaryLocation m
    ON bd.militaryLocationID_FK = m.militaryLocationID
INNER JOIN Housing.MilitaryAreaCity mac
    ON m.militaryAreaCityID_FK = mac.militaryAreaCityID
INNER JOIN Housing.MilitaryArea ma
    ON mac.militaryAreaID_FK = ma.militaryAreaID
INNER JOIN Housing.BuildingClass bc
    ON bd.buildingClassID_FK = bc.buildingClassID

/* Preserve the original choice of a raw latest action and its 3/58 guard. */
OUTER APPLY
(
    SELECT TOP (1)
         ba.buildingActionID
        ,ba.buildingActionTypeID_FK
        ,ba.residentInfoID_FK
        ,ba.entryDate
        ,ba.buildingActionNote
    FROM Housing.BuildingAction ba
    WHERE ba.buildingDetailsID_FK = bd.buildingDetailsID
      AND ba.buildingActionActive = 1
      AND NOT
      (
          ba.buildingActionTypeID_FK IN (3, 58)
          AND EXISTS
          (
              SELECT 1
              FROM Housing.fn_BuildingAction_ChainToRoot(ba.buildingActionID) ancestor
              JOIN Housing.BuildingAction stage57
                ON stage57.buildingActionID = ancestor.buildingActionID
               AND stage57.buildingActionTypeID_FK = 57
               AND stage57.buildingActionActive = 1
               AND stage57.buildingDetailsID_FK = bd.buildingDetailsID
               AND stage57.IdaraId_FK = bd.IdaraId_FK
              JOIN Housing.BuildingAction operatingRoot
                ON operatingRoot.buildingDetailsID_FK = bd.buildingDetailsID
               AND operatingRoot.IdaraId_FK = bd.IdaraId_FK
               AND operatingRoot.buildingActionActive = 1
               AND operatingRoot.buildingActionParentID IS NULL
               AND operatingRoot.residentInfoID_FK IS NULL
               AND operatingRoot.buildingActionTypeID_FK IN (4, 5, 62)
               AND operatingRoot.buildingActionID > stage57.buildingActionID
               AND operatingRoot.buildingActionID < ba.buildingActionID
          )
      )
    ORDER BY ba.buildingActionID DESC
) rawAction

/* Only a displayed active 47 enters the documented 47->2 correction. */
OUTER APPLY
(
    SELECT TOP (1) h.buildingActionID, h.residentInfoID_FK
    FROM Housing.BuildingAction h
    WHERE rawAction.buildingActionTypeID_FK = 47
      AND h.buildingActionParentID = rawAction.buildingActionID
      AND h.buildingActionTypeID_FK = 2
      AND h.buildingActionActive = 1
      AND h.buildingDetailsID_FK = bd.buildingDetailsID
      AND h.IdaraId_FK = bd.IdaraId_FK
      AND h.residentInfoID_FK = rawAction.residentInfoID_FK
    ORDER BY h.buildingActionID DESC
) housing2

/* Prefer completed exit (3) over a parallel grace-stage (24).
   A 57 without a completed 3 is an exit in progress. */
OUTER APPLY
(
    SELECT TOP (1)
         x.buildingActionID
        ,x.buildingActionTypeID_FK
        ,x.entryDate
    FROM Housing.BuildingAction x
    WHERE housing2.buildingActionID IS NOT NULL
      AND x.buildingActionParentID = housing2.buildingActionID
      AND x.buildingActionTypeID_FK IN (3, 24, 57)
      AND x.buildingActionActive = 1
      AND x.buildingDetailsID_FK = bd.buildingDetailsID
      AND x.IdaraId_FK = bd.IdaraId_FK
      AND x.residentInfoID_FK = housing2.residentInfoID_FK
    ORDER BY CASE x.buildingActionTypeID_FK
                WHEN 3 THEN 1
                WHEN 57 THEN 2
                WHEN 24 THEN 3
                ELSE 4
             END,
             x.buildingActionID DESC
) residentExit

/* The independent post-exit operating cycle supersedes the old resident.
   A root with children requires general chain logic and is not asserted
   to be a leaf by this narrow, validated correction. */
OUTER APPLY
(
    SELECT TOP (1) r.buildingActionID
    FROM Housing.BuildingAction r
    WHERE residentExit.buildingActionTypeID_FK IN (3, 57)
      AND r.buildingDetailsID_FK = bd.buildingDetailsID
      AND r.IdaraId_FK = bd.IdaraId_FK
      AND r.buildingActionActive = 1
      AND r.buildingActionParentID IS NULL
      AND r.residentInfoID_FK IS NULL
      AND r.buildingActionTypeID_FK IN (4, 5, 62)
      AND r.entryDate > residentExit.entryDate
      AND NOT EXISTS
      (
          SELECT 1
          FROM Housing.BuildingAction opChild
          WHERE opChild.buildingActionParentID = r.buildingActionID
            AND opChild.buildingActionActive = 1
            AND opChild.buildingDetailsID_FK = bd.buildingDetailsID
            AND opChild.IdaraId_FK = bd.IdaraId_FK
      )
    ORDER BY r.entryDate DESC, r.buildingActionID DESC
) independentLeaf

/* Hydrate ALL metadata from the effective action, never mix 47 metadata
   with the 2/24/4/5 status. If no proven correction exists, rawAction wins. */
LEFT JOIN Housing.BuildingAction effectiveAction
    ON effectiveAction.buildingActionID = COALESCE
       (
           independentLeaf.buildingActionID,
           residentExit.buildingActionID,
           housing2.buildingActionID,
           rawAction.buildingActionID
       )
LEFT JOIN Housing.BuildingActionType bat
    ON bat.buildingActionTypeID = effectiveAction.buildingActionTypeID_FK
INNER JOIN dbo.Idara i
    ON i.IdaraId = bd.IdaraId_FK
WHERE bd.[buildingDetailsActive] = 1
  AND bt.[buildingTypeActive] = 1
  AND bu.[buildingUtilityTypeActive] = 1
  AND m.[militaryLocationActive] = 1
  AND bc.[buildingClassActive] = 1
  AND mac.militaryAreaCityActive = 1
  AND ma.militaryAreaIsActive = 1
  AND bd.buildingDetailsStartDate IS NOT NULL
  AND bu.buildingUtilityTypeStartDate IS NOT NULL
  AND (bd.buildingDetailsEndDate IS NULL OR bd.buildingDetailsEndDate > GETDATE())
  AND (bu.buildingUtilityTypeEndDate IS NULL OR bu.buildingUtilityTypeEndDate > GETDATE());

GO

