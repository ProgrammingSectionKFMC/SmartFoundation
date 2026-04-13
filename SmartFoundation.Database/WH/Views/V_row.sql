CREATE OR ALTER VIEW [WH].[V_row]
AS
SELECT
    warehousePartID AS rowID,
    warehousePartTypeID_FK AS rowTypeID_FK,
    warehousePartName AS rowName,
    warehousePartName_A AS rowName_A,
    warehousePartParentID_FK AS rowParentID_FK,
    warehousePartActive AS rowActive,
    warehousePartOldName AS rowOldName,
    warehousePartIsChecked AS rowIsChecked,
    hostName AS rowHostName,
    entryDate AS rowEntryDate,
    entryData AS rowEntryData,
    IdaraID_FK
FROM WH.WarehousePart
WHERE warehousePartTypeID_FK = 8;
GO
