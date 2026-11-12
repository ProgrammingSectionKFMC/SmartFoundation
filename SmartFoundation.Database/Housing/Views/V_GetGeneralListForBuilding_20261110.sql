


CREATE VIEW [Housing].[V_GetGeneralListForBuilding_20261110]
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
      ,i.idaraLongName_A as BuildingIdaraName
      ,bt.[IdaraId_FK] as BuildingTypeIdaraID
      ,bu.[IdaraId_FK] as BuildingUtilityTypeIdaraID
      ,m.[IdaraId_FK] as MilitaryLocationIdaraID
      ,bc.[IdaraId_FK] as BuildingClassIdaraID
      ,lb.buildingActionID  as LastActionID
      ,lb.buildingActionTypeID_FK as LastActionTypeID
      ,bat.buildingActionTypeName_A  as LastActionTypeName
      ,bat.buildingActionTypeBuildingAlias as LastActionTypeBuildingAlias
      ,lb.LastActionEntryDate
      ,lb.LastActionNote
FROM  Housing.BuildingDetails bd
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
OUTER APPLY (
    SELECT TOP (1)
        ba.buildingActionID,
        ba.buildingActionTypeID_FK,
        ba.entryDate as LastActionEntryDate,
        ba.buildingActionNote as LastActionNote
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
) lb
left JOIN Housing.BuildingActionType bat   -- ✅ بدل INNER JOIN
    ON bat.buildingActionTypeID = lb.buildingActionTypeID_FK
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