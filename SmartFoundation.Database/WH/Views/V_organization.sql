CREATE OR ALTER VIEW [WH].[V_organization]
AS
SELECT
    warehousePartID AS organizationID,
    warehousePartTypeID_FK AS organizationTypeID_FK,
    warehousePartName AS organizationName,
    warehousePartName_A AS organizationName_A,
    warehousePartParentID_FK AS organizationParentID_FK,
    warehousePartActive AS organizationActive,
    warehousePartOldName AS organizationOldName,
    warehousePartOldParentID_FK AS organizationOldParentID_FK,
    warehousePartIsChecked AS organizationIsChecked,
    IdaraID_FK,
    hostName AS organizationHostName,
    entryDate AS organizationEntryDate,
    entryData AS organizationEntryData
FROM WH.WarehousePart
WHERE warehousePartTypeID_FK = 1;
GO
