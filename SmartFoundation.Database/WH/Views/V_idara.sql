CREATE OR ALTER VIEW [WH].[V_idara]
AS
SELECT
    warehousePartID AS idaraPartID,
    warehousePartTypeID_FK AS idaraTypeID_FK,
    warehousePartName AS idaraPartName,
    warehousePartName_A AS idaraPartName_A,
    warehousePartParentID_FK AS idaraPartParentID_FK,
    warehousePartActive AS idaraPartActive,
    warehousePartOldName AS idaraPartOldName,
    warehousePartOldParentID_FK AS idaraPartOldParentID_FK,
    warehousePartIsChecked AS idaraPartIsChecked,
    IdaraID_FK,
    hostName AS idaraPartHostName,
    entryDate AS idaraPartEntryDate,
    entryData AS idaraPartEntryData
FROM WH.WarehousePart
WHERE warehousePartTypeID_FK = 2;
GO
