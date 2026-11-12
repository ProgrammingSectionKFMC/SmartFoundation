
CREATE   VIEW [Maintenance].[V_BuildingMaintenanceRequestDetails]
AS
SELECT
    request.[RequestID],
    request.[IdaraId_FK] AS [IdaraId],
    request.[RequestNo],
    request.[TransactionID_FK],
    request.[ParentRequestID],
    request.[RootRequestID],
    request.[RequestLevel],
    request.[IsSubRequest],
    request.[IsBlockingParent],
    request.[BuildingID],
    request.[UnitID],
    request.[ResidentID],
    request.[MaintenanceCategoryID],
    request.[CurrentDSDID],
    request.[OriginalDSDID],
    request.[StatusID],
    request.[PriorityID],
    request.[Description_A],
    request.[HasDispute],
    request.[DisputeStatusID],
    request.[EscalationLevel],
    request.[IsLockedByDecision],
    request.[RequestDate],
    request.[ClosedDate],
    request.[entryUser],
    request.[entryDate],
    request.[entryData],
    request.[hostName],
    request.[updateUser],
    request.[updateDate],
    request.[IsActive],
    category.[CategoryName_A] AS [MaintenanceCategoryName_A],
    categoryTree.[FullPath_A] AS [MaintenanceCategoryFullPath_A],
    status.[StatusName_A],
    status.[StatusCode],
    priority.[PriorityName_A],
    priority.[PriorityCode],
    parentRequest.[RequestNo] AS [ParentRequestNo],
    rootRequest.[RequestNo] AS [RootRequestNo]
FROM [Maintenance].[BuildingMaintenanceRequest] AS request
LEFT JOIN [Maintenance].[MaintenanceCategory] AS category
    ON category.[MaintenanceCategoryID] = request.[MaintenanceCategoryID]
LEFT JOIN [Maintenance].[V_MaintenanceCategoryTree] AS categoryTree
    ON categoryTree.[IdaraId] = request.[IdaraId_FK]
    AND categoryTree.[MaintenanceCategoryID] = request.[MaintenanceCategoryID]
LEFT JOIN [Maintenance].[MaintenanceRequestStatus] AS status
    ON status.[StatusID] = request.[StatusID]
LEFT JOIN [Maintenance].[MaintenancePriority] AS priority
    ON priority.[PriorityID] = request.[PriorityID]
LEFT JOIN [Maintenance].[BuildingMaintenanceRequest] AS parentRequest
    ON parentRequest.[RequestID] = request.[ParentRequestID]
LEFT JOIN [Maintenance].[BuildingMaintenanceRequest] AS rootRequest
    ON rootRequest.[RequestID] = request.[RootRequestID];

GO

