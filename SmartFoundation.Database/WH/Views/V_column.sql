CREATE OR ALTER VIEW [WH].[V_column]
AS
SELECT
    warehousePartID AS columnID,
    warehousePartTypeID_FK AS columnTypeID_FK,
    warehousePartName AS columnName,
    warehousePartParentID_FK AS columnParentID_FK,
    warehousePartActive AS columnActive,
    warehousePartOldName AS columnOldName,
    warehousePartIsChecked AS columnIsChecked,
    hostName AS columnHostName,
    entryDate AS columnEntryDate,
    entryData AS columnEntryData,
    warehousePartName_A AS columnName_A,
    warehousePartOldParentID_FK AS columnOldParentID,
    IdaraID_FK
FROM WH.WarehousePart
WHERE warehousePartTypeID_FK = 7;
GO
