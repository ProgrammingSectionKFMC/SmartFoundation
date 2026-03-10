





CREATE VIEW [Housing].[V_GetGeneralListForBuildingWithRent]
AS


SELECT 
       bd.[buildingDetailsID]
      ,bd.[buildingDetailsNo]
      ,br.buildingRentAmount
      ,br.buildingRentTypeName_A
      ,br.buildingRentTypeID
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
      ,bt.[IdaraId_FK] as BuildingTypeIdaraID
      ,bu.[IdaraId_FK] as BuildingUtilityTypeIdaraID
      ,m.[IdaraId_FK] as MilitaryLocationIdaraID
      ,bc.[IdaraId_FK] as BuildingClassIdaraID
      ,lb.buildingActionID  as LastActionID
      ,lb.buildingActionTypeID_FK as LastActionTypeID
      ,bat.buildingActionTypeName_A  as LastActionTypeName
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
    SELECT TOP (1) r.buildingDetailsID_FK,r.buildingRentAmount,rt.buildingRentTypeName_A,rt.buildingRentTypeID
    FROM Housing.BuildingRent r
        left join Housing.BuildingRentType rt on r.buildingRentTypeID_FK = rt.buildingRentTypeID
    WHERE r.buildingDetailsID_FK = bd.buildingDetailsID
    and r.buildingRentActive = 1
    and (r.buildingRentEndDate is null or Cast(r.buildingRentEndDate as date) > Cast(GETDATE() as date))
    and rt.buildingRentTypeActive = 1
    ORDER BY r.buildingRentID DESC
) br
OUTER APPLY (
    SELECT TOP (1) ba.buildingActionID,ba.buildingActionTypeID_FK
    FROM Housing.BuildingAction ba
    WHERE ba.buildingDetailsID_FK = bd.buildingDetailsID
    ORDER BY ba.buildingActionID DESC
) lb
Inner JOIN Housing.BuildingActionType bat on lb.buildingActionTypeID_FK = bat.buildingActionTypeID
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


