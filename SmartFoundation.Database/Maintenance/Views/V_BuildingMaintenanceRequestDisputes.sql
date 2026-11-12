
CREATE   VIEW [Maintenance].[V_BuildingMaintenanceRequestDisputes]
AS
SELECT
    dispute.[DisputeID],
    dispute.[RequestID],
    dispute.[RaisedByDSDID],
    dispute.[AgainstDSDID],
    dispute.[RaisedByUserID],
    dispute.[Reason],
    dispute.[ArbitrationDSDID],
    dispute.[DecisionByUserID],
    dispute.[DecisionNote],
    dispute.[IsBindingDecision],
    dispute.[DecisionDate],
    dispute.[DisputeStatusID],
    dispute.[IsActive]
FROM [Maintenance].[BuildingMaintenanceRequestDispute] AS dispute;

GO

