CREATE OR ALTER VIEW [WH].[V_shelf]
AS
SELECT
    warehousePartID AS shelfID,
    warehousePartTypeID_FK AS shelfTypeID_FK,
    warehousePartName AS shelfName,
    warehousePartParentID_FK AS shelfParentID_FK,
    warehousePartActive AS shelfActive,
    warehousePartOldName AS shelfOldName,
    warehousePartIsChecked AS shelfIsChecked,
    hostName AS shelfHostName,
    entryDate AS shelfEntryDate,
    entryData AS shelfEntryData,
    warehousePartName_A AS shelfName_A,
    warehousePartOldParentID_FK AS shelfOldParentID,
    IdaraID_FK
FROM WH.WarehousePart
WHERE warehousePartTypeID_FK = 6;
GO
