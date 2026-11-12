
CREATE   VIEW [Maintenance].[V_BuildingMaintenanceRequestList]
AS
SELECT
    request.[RequestID],
    request.[TransactionID_FK],
    request.[RequestNo],
    request.[IdaraId_FK] AS [IdaraId],
    request.[RequestDate],
    request.[BuildingID],
    request.[UnitID],
    request.[ResidentID],
    request.[MaintenanceCategoryID],
    category.[CategoryName_A] AS [MaintenanceCategoryName_A],
    categoryTree.[FullPath_A] AS [MaintenanceCategoryFullPath_A],
    request.[CurrentDSDID],
    request.[OriginalDSDID],
    request.[StatusID],
    status.[StatusName_A],
    status.[StatusCode],
    request.[PriorityID],
    priority.[PriorityName_A],
    priority.[PriorityCode],
    request.[ParentRequestID],
    request.[RootRequestID],
    request.[RequestLevel],
    request.[IsSubRequest],
    request.[HasDispute],
    request.[EscalationLevel],
    request.[IsLockedByDecision],
    ISNULL(subRequests.[SubRequestsCount], 0) AS [SubRequestsCount],
    ISNULL(subRequests.[OpenSubRequestsCount], 0) AS [OpenSubRequestsCount],
    lastAction.[ActionDate] AS [LastActionDate],
    lastAction.[ActionTypeName_A] AS [LastActionTypeName_A],
    lastAction.[ActionNote] AS [LastActionNote],
    request.[ClosedDate],
    request.[IsActive]
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
OUTER APPLY
(
    SELECT
        COUNT(1) AS [SubRequestsCount],
        SUM(CASE WHEN ISNULL(childStatus.[IsClosed], 0) = 0 THEN 1 ELSE 0 END) AS [OpenSubRequestsCount]
    FROM [Maintenance].[BuildingMaintenanceRequest] AS child
    LEFT JOIN [Maintenance].[MaintenanceRequestStatus] AS childStatus
        ON childStatus.[StatusID] = child.[StatusID]
    WHERE child.[ParentRequestID] = request.[RequestID]
      AND child.[IsActive] = 1
) AS subRequests
OUTER APPLY
(
    SELECT TOP (1)
        action.[ActionDate],
        actionType.[ActionTypeName_A],
        action.[ActionNote]
    FROM [Maintenance].[BuildingMaintenanceRequestAction] AS action
    LEFT JOIN [Maintenance].[MaintenanceActionType] AS actionType
        ON actionType.[ActionTypeID] = action.[ActionTypeID]
    WHERE action.[RequestID] = request.[RequestID]
      AND action.[IsActive] = 1
    ORDER BY action.[ActionDate] DESC, action.[ActionID] DESC
) AS lastAction;

GO

