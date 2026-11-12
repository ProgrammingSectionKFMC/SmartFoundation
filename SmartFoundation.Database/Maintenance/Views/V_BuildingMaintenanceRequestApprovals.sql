
CREATE   VIEW [Maintenance].[V_BuildingMaintenanceRequestApprovals]
AS
SELECT
    approval.[ApprovalID],
    approval.[RequestID],
    approval.[RequestedByUserID],
    approval.[RequestedDate],
    approval.[ApprovalLevel],
    approval.[ApprovalDSDID],
    approval.[ApprovalUserID],
    approval.[ApprovalStatusID],
    approval.[Reason],
    approval.[EstimatedCost],
    approval.[DecisionNote],
    approval.[DecisionDate],
    approval.[IsActive]
FROM [Maintenance].[BuildingMaintenanceRequestApproval] AS approval;

GO

