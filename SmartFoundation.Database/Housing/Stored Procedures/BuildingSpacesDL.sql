CREATE PROCEDURE [Housing].[BuildingSpacesDL]
    @pageName_ NVARCHAR(400),
    @idaraID INT,
    @entrydata INT,
    @hostname NVARCHAR(400),
    @buildingUtilityTypeID_FK INT,
    @BuildingDetailsID_FK BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    -- بيانات المباني
    SELECT DISTINCT
         bd.buildingDetailsID
        ,bd.buildingDetailsNo
        ,but.buildingUtilityTypeID
        ,bd.buildingDetailsStartDate
    FROM [DATACORE].[Housing].[BuildingDetails] bd
    INNER JOIN [DATACORE].[Housing].[BuildingType] bt ON bd.buildingTypeID_FK = bt.buildingTypeID
    INNER JOIN [DATACORE].[Housing].[BuildingUtilityType] but ON bd.buildingUtilityTypeID_FK = but.buildingUtilityTypeID
    INNER JOIN [DATACORE].[Housing].[MilitaryLocation] m ON bd.militaryLocationID_FK = m.militaryLocationID
    INNER JOIN [DATACORE].[Housing].[BuildingClass] bc ON bd.buildingClassID_FK = bc.buildingClassID
    LEFT JOIN [DATACORE].[Housing].[BuildingRent] br ON bd.buildingDetailsID = br.buildingDetailsID_FK AND br.buildingRentActive = 1 AND br.buildingRentStartDate <= GETDATE() AND (br.buildingRentEndDate >= GETDATE() OR br.buildingRentEndDate IS NULL)
    LEFT JOIN [DATACORE].[Housing].[BuildingRentType] brt ON br.buildingRentTypeID_FK = brt.buildingRentTypeID AND brt.buildingRentTypeActive = 1
    LEFT JOIN [DATACORE].[Housing].[V_LastActionForBuilding] lb ON bd.buildingDetailsID = lb.buildingDetailsID
    LEFT JOIN [DATACORE].[Housing].[BuildingAction] ba ON lb.buildingActionID = ba.buildingActionID AND ba.buildingActionActive = 1
    LEFT JOIN [DATACORE].[Housing].[BuildingActionType] bat ON ba.buildingActionTypeID_FK = bat.buildingActionTypeID AND bat.buildingActionTypeActive = 1
    WHERE bd.buildingDetailsActive = 1
      AND m.militaryLocationActive = 1
      AND bt.buildingTypeActive = 1
      AND but.buildingUtilityTypeActive = 1
      AND bc.buildingClassActive = 1
      AND bd.IdaraId_FK = @idaraID
    ORDER BY bd.buildingDetailsID DESC;

    -- أنواع المرافق
    SELECT
         bu.buildingUtilityTypeID
        ,bu.buildingUtilityTypeName_A
        ,bu.buildingUtilityIsRent
    FROM [DATACORE].[Housing].[BuildingUtilityType] bu
    WHERE bu.buildingUtilityTypeActive = 1
      AND (bu.IdaraId_FK = @idaraID OR bu.IdaraId_FK IS NULL);

    -- فراغات المبنى المختار
    SELECT
         bs.BuildingSpaceID
        ,bs.BuildingDetailsID_FK
        ,d.buildingDetailsNo
        ,bs.BuildingSpaceTypeID_FK
        ,bst.BuildingSpaceTypeCode
        ,bst.BuildingSpaceTypeName_A
        ,bs.BuildingSpaceSequence
        ,bs.BuildingSpaceName
        ,bs.BuildingSpaceLength
        ,bs.BuildingSpaceWidth
        ,bs.BuildingSpaceArea
        ,CONVERT(NVARCHAR(10), bs.BuildingSpaceStartDate, 23) AS BuildingSpaceStartDate
        ,CONVERT(NVARCHAR(10), bs.BuildingSpaceEndDate, 23) AS BuildingSpaceEndDate
        ,bs.BuildingSpaceActive
        ,bs.BuildingSpaceRemark
        ,bs.CanceledBy
        ,bs.CanceledDate
        ,bs.entryDate
        ,bs.entryData
        ,bs.hostName
    FROM [Housing].[BuildingSpace] bs
    INNER JOIN [Housing].[BuildingSpaceType] bst ON bst.BuildingSpaceTypeID = bs.BuildingSpaceTypeID_FK
    LEFT JOIN [Housing].[BuildingDetails] d ON d.buildingDetailsID = bs.BuildingDetailsID_FK
    WHERE bs.BuildingDetailsID_FK = @BuildingDetailsID_FK
      AND bs.BuildingSpaceActive = 1
    ORDER BY bs.BuildingSpaceID DESC;

    -- أنواع الفراغات
    SELECT
         bst.BuildingSpaceTypeID
        ,bst.BuildingSpaceTypeName_A
    FROM [Housing].[BuildingSpaceType] bst
    WHERE bst.BuildingSpaceTypeActive = 1
    ORDER BY bst.BuildingSpaceTypeName_A;
END
