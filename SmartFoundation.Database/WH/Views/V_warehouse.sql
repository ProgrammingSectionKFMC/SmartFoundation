CREATE OR ALTER VIEW [WH].[V_warehouse]
AS
SELECT
    warehousePartID AS warehouseID,
    warehousePartTypeID_FK AS warehouseTypeID_FK,
    warehousePartName AS warehouseName,
    warehousePartParentID_FK AS warehouseParentID_FK,
    warehousePartActive AS warehouseActive,
    warehousePartOldName AS warehouseOldName,
    warehousePartIsChecked AS warehouseIsChecked,
    hostName AS warehouseHostName,
    entryDate AS warehouseEntryDate,
    entryData AS warehouseEntryData,
    warehousePartName_A,
    warehousePartOldParentID_FK,
    IdaraID_FK
FROM WH.WarehousePart
WHERE warehousePartTypeID_FK = 4;
GO
