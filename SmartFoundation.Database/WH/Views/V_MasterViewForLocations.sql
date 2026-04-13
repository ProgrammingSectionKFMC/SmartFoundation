CREATE OR ALTER VIEW [WH].[V_MasterViewForLocations]
AS
SELECT
    n.warehousePartID AS locationID,
    n.warehousePartTypeID_FK AS locationTypeID_FK,
    nt.warehousePartTypeName_A AS locationTypeName_A,
    nt.warehousePartTypeName_E AS locationTypeName_E,
    n.warehousePartName AS locationName,
    n.warehousePartName_A AS locationName_A,
    n.warehousePartParentID_FK AS locationParentID_FK,
    p1.warehousePartTypeID_FK AS parentTypeID_FK,
    p1t.warehousePartTypeName_A AS parentTypeName_A,
    p1t.warehousePartTypeName_E AS parentTypeName_E,
    p1.warehousePartName AS parentName,
    p1.warehousePartName_A AS parentName_A,
    n.warehousePartActive AS locationActive,
    n.warehousePartOldName AS locationOldName,
    n.warehousePartOldParentID_FK AS locationOldParentID_FK,
    n.warehousePartIsChecked AS locationIsChecked,
    n.hostName AS locationHostName,
    n.entryDate AS locationEntryDate,
    n.entryData AS locationEntryData,
    n.IdaraID_FK AS locationIdaraID,

    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 1 THEN n.warehousePartID END, CASE WHEN p1.warehousePartTypeID_FK = 1 THEN p1.warehousePartID END, CASE WHEN p2.warehousePartTypeID_FK = 1 THEN p2.warehousePartID END, CASE WHEN p3.warehousePartTypeID_FK = 1 THEN p3.warehousePartID END, CASE WHEN p4.warehousePartTypeID_FK = 1 THEN p4.warehousePartID END, CASE WHEN p5.warehousePartTypeID_FK = 1 THEN p5.warehousePartID END, CASE WHEN p6.warehousePartTypeID_FK = 1 THEN p6.warehousePartID END, CASE WHEN p7.warehousePartTypeID_FK = 1 THEN p7.warehousePartID END) AS organizationID,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 1 THEN n.warehousePartName END, CASE WHEN p1.warehousePartTypeID_FK = 1 THEN p1.warehousePartName END, CASE WHEN p2.warehousePartTypeID_FK = 1 THEN p2.warehousePartName END, CASE WHEN p3.warehousePartTypeID_FK = 1 THEN p3.warehousePartName END, CASE WHEN p4.warehousePartTypeID_FK = 1 THEN p4.warehousePartName END, CASE WHEN p5.warehousePartTypeID_FK = 1 THEN p5.warehousePartName END, CASE WHEN p6.warehousePartTypeID_FK = 1 THEN p6.warehousePartName END, CASE WHEN p7.warehousePartTypeID_FK = 1 THEN p7.warehousePartName END) AS organizationName,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 1 THEN n.warehousePartName_A END, CASE WHEN p1.warehousePartTypeID_FK = 1 THEN p1.warehousePartName_A END, CASE WHEN p2.warehousePartTypeID_FK = 1 THEN p2.warehousePartName_A END, CASE WHEN p3.warehousePartTypeID_FK = 1 THEN p3.warehousePartName_A END, CASE WHEN p4.warehousePartTypeID_FK = 1 THEN p4.warehousePartName_A END, CASE WHEN p5.warehousePartTypeID_FK = 1 THEN p5.warehousePartName_A END, CASE WHEN p6.warehousePartTypeID_FK = 1 THEN p6.warehousePartName_A END, CASE WHEN p7.warehousePartTypeID_FK = 1 THEN p7.warehousePartName_A END) AS organizationName_A,

    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 2 THEN n.warehousePartID END, CASE WHEN p1.warehousePartTypeID_FK = 2 THEN p1.warehousePartID END, CASE WHEN p2.warehousePartTypeID_FK = 2 THEN p2.warehousePartID END, CASE WHEN p3.warehousePartTypeID_FK = 2 THEN p3.warehousePartID END, CASE WHEN p4.warehousePartTypeID_FK = 2 THEN p4.warehousePartID END, CASE WHEN p5.warehousePartTypeID_FK = 2 THEN p5.warehousePartID END, CASE WHEN p6.warehousePartTypeID_FK = 2 THEN p6.warehousePartID END, CASE WHEN p7.warehousePartTypeID_FK = 2 THEN p7.warehousePartID END) AS idaraPartID,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 2 THEN n.warehousePartName END, CASE WHEN p1.warehousePartTypeID_FK = 2 THEN p1.warehousePartName END, CASE WHEN p2.warehousePartTypeID_FK = 2 THEN p2.warehousePartName END, CASE WHEN p3.warehousePartTypeID_FK = 2 THEN p3.warehousePartName END, CASE WHEN p4.warehousePartTypeID_FK = 2 THEN p4.warehousePartName END, CASE WHEN p5.warehousePartTypeID_FK = 2 THEN p5.warehousePartName END, CASE WHEN p6.warehousePartTypeID_FK = 2 THEN p6.warehousePartName END, CASE WHEN p7.warehousePartTypeID_FK = 2 THEN p7.warehousePartName END) AS idaraPartName,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 2 THEN n.warehousePartName_A END, CASE WHEN p1.warehousePartTypeID_FK = 2 THEN p1.warehousePartName_A END, CASE WHEN p2.warehousePartTypeID_FK = 2 THEN p2.warehousePartName_A END, CASE WHEN p3.warehousePartTypeID_FK = 2 THEN p3.warehousePartName_A END, CASE WHEN p4.warehousePartTypeID_FK = 2 THEN p4.warehousePartName_A END, CASE WHEN p5.warehousePartTypeID_FK = 2 THEN p5.warehousePartName_A END, CASE WHEN p6.warehousePartTypeID_FK = 2 THEN p6.warehousePartName_A END, CASE WHEN p7.warehousePartTypeID_FK = 2 THEN p7.warehousePartName_A END) AS idaraPartName_A,

    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 3 THEN n.warehousePartID END, CASE WHEN p1.warehousePartTypeID_FK = 3 THEN p1.warehousePartID END, CASE WHEN p2.warehousePartTypeID_FK = 3 THEN p2.warehousePartID END, CASE WHEN p3.warehousePartTypeID_FK = 3 THEN p3.warehousePartID END, CASE WHEN p4.warehousePartTypeID_FK = 3 THEN p4.warehousePartID END, CASE WHEN p5.warehousePartTypeID_FK = 3 THEN p5.warehousePartID END, CASE WHEN p6.warehousePartTypeID_FK = 3 THEN p6.warehousePartID END, CASE WHEN p7.warehousePartTypeID_FK = 3 THEN p7.warehousePartID END) AS warehouseZoneID,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 3 THEN n.warehousePartName END, CASE WHEN p1.warehousePartTypeID_FK = 3 THEN p1.warehousePartName END, CASE WHEN p2.warehousePartTypeID_FK = 3 THEN p2.warehousePartName END, CASE WHEN p3.warehousePartTypeID_FK = 3 THEN p3.warehousePartName END, CASE WHEN p4.warehousePartTypeID_FK = 3 THEN p4.warehousePartName END, CASE WHEN p5.warehousePartTypeID_FK = 3 THEN p5.warehousePartName END, CASE WHEN p6.warehousePartTypeID_FK = 3 THEN p6.warehousePartName END, CASE WHEN p7.warehousePartTypeID_FK = 3 THEN p7.warehousePartName END) AS warehouseZoneName,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 3 THEN n.warehousePartName_A END, CASE WHEN p1.warehousePartTypeID_FK = 3 THEN p1.warehousePartName_A END, CASE WHEN p2.warehousePartTypeID_FK = 3 THEN p2.warehousePartName_A END, CASE WHEN p3.warehousePartTypeID_FK = 3 THEN p3.warehousePartName_A END, CASE WHEN p4.warehousePartTypeID_FK = 3 THEN p4.warehousePartName_A END, CASE WHEN p5.warehousePartTypeID_FK = 3 THEN p5.warehousePartName_A END, CASE WHEN p6.warehousePartTypeID_FK = 3 THEN p6.warehousePartName_A END, CASE WHEN p7.warehousePartTypeID_FK = 3 THEN p7.warehousePartName_A END) AS warehouseZoneName_A,

    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 4 THEN n.warehousePartID END, CASE WHEN p1.warehousePartTypeID_FK = 4 THEN p1.warehousePartID END, CASE WHEN p2.warehousePartTypeID_FK = 4 THEN p2.warehousePartID END, CASE WHEN p3.warehousePartTypeID_FK = 4 THEN p3.warehousePartID END, CASE WHEN p4.warehousePartTypeID_FK = 4 THEN p4.warehousePartID END, CASE WHEN p5.warehousePartTypeID_FK = 4 THEN p5.warehousePartID END, CASE WHEN p6.warehousePartTypeID_FK = 4 THEN p6.warehousePartID END, CASE WHEN p7.warehousePartTypeID_FK = 4 THEN p7.warehousePartID END) AS warehouseID,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 4 THEN n.warehousePartName END, CASE WHEN p1.warehousePartTypeID_FK = 4 THEN p1.warehousePartName END, CASE WHEN p2.warehousePartTypeID_FK = 4 THEN p2.warehousePartName END, CASE WHEN p3.warehousePartTypeID_FK = 4 THEN p3.warehousePartName END, CASE WHEN p4.warehousePartTypeID_FK = 4 THEN p4.warehousePartName END, CASE WHEN p5.warehousePartTypeID_FK = 4 THEN p5.warehousePartName END, CASE WHEN p6.warehousePartTypeID_FK = 4 THEN p6.warehousePartName END, CASE WHEN p7.warehousePartTypeID_FK = 4 THEN p7.warehousePartName END) AS warehouseName,

    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 5 THEN n.warehousePartID END, CASE WHEN p1.warehousePartTypeID_FK = 5 THEN p1.warehousePartID END, CASE WHEN p2.warehousePartTypeID_FK = 5 THEN p2.warehousePartID END, CASE WHEN p3.warehousePartTypeID_FK = 5 THEN p3.warehousePartID END, CASE WHEN p4.warehousePartTypeID_FK = 5 THEN p4.warehousePartID END, CASE WHEN p5.warehousePartTypeID_FK = 5 THEN p5.warehousePartID END, CASE WHEN p6.warehousePartTypeID_FK = 5 THEN p6.warehousePartID END, CASE WHEN p7.warehousePartTypeID_FK = 5 THEN p7.warehousePartID END) AS buildingID,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 5 THEN n.warehousePartName END, CASE WHEN p1.warehousePartTypeID_FK = 5 THEN p1.warehousePartName END, CASE WHEN p2.warehousePartTypeID_FK = 5 THEN p2.warehousePartName END, CASE WHEN p3.warehousePartTypeID_FK = 5 THEN p3.warehousePartName END, CASE WHEN p4.warehousePartTypeID_FK = 5 THEN p4.warehousePartName END, CASE WHEN p5.warehousePartTypeID_FK = 5 THEN p5.warehousePartName END, CASE WHEN p6.warehousePartTypeID_FK = 5 THEN p6.warehousePartName END, CASE WHEN p7.warehousePartTypeID_FK = 5 THEN p7.warehousePartName END) AS buildingName,

    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 6 THEN n.warehousePartID END, CASE WHEN p1.warehousePartTypeID_FK = 6 THEN p1.warehousePartID END, CASE WHEN p2.warehousePartTypeID_FK = 6 THEN p2.warehousePartID END, CASE WHEN p3.warehousePartTypeID_FK = 6 THEN p3.warehousePartID END, CASE WHEN p4.warehousePartTypeID_FK = 6 THEN p4.warehousePartID END, CASE WHEN p5.warehousePartTypeID_FK = 6 THEN p5.warehousePartID END, CASE WHEN p6.warehousePartTypeID_FK = 6 THEN p6.warehousePartID END, CASE WHEN p7.warehousePartTypeID_FK = 6 THEN p7.warehousePartID END) AS shelfID,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 6 THEN n.warehousePartName END, CASE WHEN p1.warehousePartTypeID_FK = 6 THEN p1.warehousePartName END, CASE WHEN p2.warehousePartTypeID_FK = 6 THEN p2.warehousePartName END, CASE WHEN p3.warehousePartTypeID_FK = 6 THEN p3.warehousePartName END, CASE WHEN p4.warehousePartTypeID_FK = 6 THEN p4.warehousePartName END, CASE WHEN p5.warehousePartTypeID_FK = 6 THEN p5.warehousePartName END, CASE WHEN p6.warehousePartTypeID_FK = 6 THEN p6.warehousePartName END, CASE WHEN p7.warehousePartTypeID_FK = 6 THEN p7.warehousePartName END) AS shelfName,

    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 7 THEN n.warehousePartID END, CASE WHEN p1.warehousePartTypeID_FK = 7 THEN p1.warehousePartID END, CASE WHEN p2.warehousePartTypeID_FK = 7 THEN p2.warehousePartID END, CASE WHEN p3.warehousePartTypeID_FK = 7 THEN p3.warehousePartID END, CASE WHEN p4.warehousePartTypeID_FK = 7 THEN p4.warehousePartID END, CASE WHEN p5.warehousePartTypeID_FK = 7 THEN p5.warehousePartID END, CASE WHEN p6.warehousePartTypeID_FK = 7 THEN p6.warehousePartID END, CASE WHEN p7.warehousePartTypeID_FK = 7 THEN p7.warehousePartID END) AS columnID,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 7 THEN n.warehousePartName END, CASE WHEN p1.warehousePartTypeID_FK = 7 THEN p1.warehousePartName END, CASE WHEN p2.warehousePartTypeID_FK = 7 THEN p2.warehousePartName END, CASE WHEN p3.warehousePartTypeID_FK = 7 THEN p3.warehousePartName END, CASE WHEN p4.warehousePartTypeID_FK = 7 THEN p4.warehousePartName END, CASE WHEN p5.warehousePartTypeID_FK = 7 THEN p5.warehousePartName END, CASE WHEN p6.warehousePartTypeID_FK = 7 THEN p6.warehousePartName END, CASE WHEN p7.warehousePartTypeID_FK = 7 THEN p7.warehousePartName END) AS columnName,

    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 8 THEN n.warehousePartID END, CASE WHEN p1.warehousePartTypeID_FK = 8 THEN p1.warehousePartID END, CASE WHEN p2.warehousePartTypeID_FK = 8 THEN p2.warehousePartID END, CASE WHEN p3.warehousePartTypeID_FK = 8 THEN p3.warehousePartID END, CASE WHEN p4.warehousePartTypeID_FK = 8 THEN p4.warehousePartID END, CASE WHEN p5.warehousePartTypeID_FK = 8 THEN p5.warehousePartID END, CASE WHEN p6.warehousePartTypeID_FK = 8 THEN p6.warehousePartID END, CASE WHEN p7.warehousePartTypeID_FK = 8 THEN p7.warehousePartID END) AS rowID,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 8 THEN n.warehousePartName END, CASE WHEN p1.warehousePartTypeID_FK = 8 THEN p1.warehousePartName END, CASE WHEN p2.warehousePartTypeID_FK = 8 THEN p2.warehousePartName END, CASE WHEN p3.warehousePartTypeID_FK = 8 THEN p3.warehousePartName END, CASE WHEN p4.warehousePartTypeID_FK = 8 THEN p4.warehousePartName END, CASE WHEN p5.warehousePartTypeID_FK = 8 THEN p5.warehousePartName END, CASE WHEN p6.warehousePartTypeID_FK = 8 THEN p6.warehousePartName END, CASE WHEN p7.warehousePartTypeID_FK = 8 THEN p7.warehousePartName END) AS rowName
FROM WH.WarehousePart n
LEFT JOIN WH.WarehousePartType nt
    ON nt.warehousePartTypeID = n.warehousePartTypeID_FK
LEFT JOIN WH.WarehousePart p1
    ON p1.warehousePartID = n.warehousePartParentID_FK
LEFT JOIN WH.WarehousePartType p1t
    ON p1t.warehousePartTypeID = p1.warehousePartTypeID_FK
LEFT JOIN WH.WarehousePart p2
    ON p2.warehousePartID = p1.warehousePartParentID_FK
LEFT JOIN WH.WarehousePart p3
    ON p3.warehousePartID = p2.warehousePartParentID_FK
LEFT JOIN WH.WarehousePart p4
    ON p4.warehousePartID = p3.warehousePartParentID_FK
LEFT JOIN WH.WarehousePart p5
    ON p5.warehousePartID = p4.warehousePartParentID_FK
LEFT JOIN WH.WarehousePart p6
    ON p6.warehousePartID = p5.warehousePartParentID_FK
LEFT JOIN WH.WarehousePart p7
    ON p7.warehousePartID = p6.warehousePartParentID_FK;
GO
