CREATE OR ALTER VIEW [WH].[V_warehouseZone]
AS
SELECT
    warehousePartID AS warehouseZoneID,
    warehousePartTypeID_FK AS warehouseZoneTypeID_FK,
    warehousePartName AS warehouseZoneName,
    warehousePartName_A AS warehouseZoneName_A,
    warehousePartParentID_FK AS warehouseZoneParentID_FK,
    warehousePartActive AS warehouseZoneActive,
    warehousePartOldName AS warehouseZoneOldName,
    warehousePartOldParentID_FK AS warehouseZoneOldParentID_FK,
    warehousePartIsChecked AS warehouseZoneIsChecked,
    IdaraID_FK,
    hostName AS warehouseZoneHostName,
    entryDate AS warehouseZoneEntryDate,
    entryData AS warehouseZoneEntryData
FROM WH.WarehousePart
WHERE warehousePartTypeID_FK = 3;
GO
