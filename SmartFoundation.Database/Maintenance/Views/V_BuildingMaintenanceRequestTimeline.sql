
CREATE   VIEW [Maintenance].[V_BuildingMaintenanceRequestTimeline]
AS
SELECT
    action.[ActionID],
    action.[RequestID],
    action.[ActionDate],
    action.[ActionTypeID],
    actionType.[ActionTypeName_A],
    actionType.[ActionTypeCode],
    action.[ReasonID],
    reason.[ReasonName_A],
    reason.[ReasonCode],
    action.[FromDSDID],
    action.[ToDSDID],
    action.[FromUserID],
    action.[ToUserID],
    action.[OldStatusID],
    oldStatus.[StatusName_A] AS [OldStatusName_A],
    oldStatus.[StatusCode] AS [OldStatusCode],
    action.[NewStatusID],
    newStatus.[StatusName_A] AS [NewStatusName_A],
    newStatus.[StatusCode] AS [NewStatusCode],
    action.[ActionNote],
    action.[entryUser],
    action.[entryDate]
FROM [Maintenance].[BuildingMaintenanceRequestAction] AS action
LEFT JOIN [Maintenance].[MaintenanceActionType] AS actionType
    ON actionType.[ActionTypeID] = action.[ActionTypeID]
LEFT JOIN [Maintenance].[MaintenanceActionReason] AS reason
    ON reason.[ReasonID] = action.[ReasonID]
LEFT JOIN [Maintenance].[MaintenanceRequestStatus] AS oldStatus
    ON oldStatus.[StatusID] = action.[OldStatusID]
LEFT JOIN [Maintenance].[MaintenanceRequestStatus] AS newStatus
    ON newStatus.[StatusID] = action.[NewStatusID];

GO

