
CREATE   VIEW [Maintenance].[V_BuildingMaintenanceRequestSLAStatus]
AS
SELECT
    request.[RequestID],
    request.[RequestNo],
    request.[IdaraId_FK] AS [IdaraId],
    request.[StatusID],
    status.[StatusName_A],
    status.[StatusCode],
    request.[PriorityID],
    priority.[PriorityName_A],
    requestSla.[InspectionDueDate],
    requestSla.[ExecutionDueDate],
    requestSla.[ApprovalDueDate],
    requestSla.[IsInspectionLate],
    requestSla.[IsExecutionLate],
    requestSla.[IsApprovalLate],
    CAST(
        CASE
            WHEN requestSla.[IsInspectionLate] = 1
              OR requestSla.[IsExecutionLate] = 1
              OR requestSla.[IsApprovalLate] = 1
            THEN 1
            ELSE 0
        END AS BIT
    ) AS [IsAnyLate],
    request.[RequestDate],
    request.[ClosedDate]
FROM [Maintenance].[BuildingMaintenanceRequest] AS request
LEFT JOIN [Maintenance].[BuildingMaintenanceRequestSLA] AS requestSla
    ON requestSla.[RequestID] = request.[RequestID]
LEFT JOIN [Maintenance].[MaintenanceRequestStatus] AS status
    ON status.[StatusID] = request.[StatusID]
LEFT JOIN [Maintenance].[MaintenancePriority] AS priority
    ON priority.[PriorityID] = request.[PriorityID];

GO

