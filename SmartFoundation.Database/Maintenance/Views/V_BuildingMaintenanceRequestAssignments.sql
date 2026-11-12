
CREATE   VIEW [Maintenance].[V_BuildingMaintenanceRequestAssignments]
AS
SELECT
    assignment.[AssignmentID],
    assignment.[RequestID],
    assignment.[AssignedToUserID],
    assignment.[AssignedByUserID],
    assignment.[AssignedDSDID],
    assignment.[AssignedDate],
    assignment.[InspectionDate],
    assignment.[CompletionDate],
    assignment.[AssignmentStatusID],
    assignment.[NeedsApproval],
    assignment.[NeedsSubRequest],
    request.[TransactionID_FK],
    assignment.[ReportText],
    assignment.[IsActive]
FROM [Maintenance].[BuildingMaintenanceRequestAssignment] AS assignment
INNER JOIN [Maintenance].[BuildingMaintenanceRequest] AS request
    ON request.[RequestID] = assignment.[RequestID];

GO

