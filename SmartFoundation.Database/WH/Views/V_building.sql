CREATE OR ALTER VIEW [WH].[V_building]
AS
SELECT
    warehousePartID AS buildingID,
    warehousePartTypeID_FK AS buildingTypeID_FK,
    warehousePartName AS buildingName,
    warehousePartParentID_FK AS buildingParentID_FK,
    warehousePartActive AS buildingActive,
    warehousePartIsChecked AS buildingIsChecked,
    hostName AS buildingHostName,
    entryDate AS buildingEntryDate,
    entryData AS buildingEntryData,
    warehousePartName_A AS buildingPartName_A,
    warehousePartOldName AS buildingOldName,
    warehousePartOldParentID_FK AS buildingOldParentID_FK,
    IdaraID_FK
FROM WH.WarehousePart
WHERE warehousePartTypeID_FK = 5;
GO
