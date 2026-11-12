
CREATE   PROCEDURE [Maintenance].[MaintenanceDisputeDL]
      @pageName_ NVARCHAR(400)
    , @idaraID INT
    , @entryData NVARCHAR(20) = NULL
    , @hostName NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
          dispute.[DisputeID]
        , dispute.[RequestID]
        , list.[RequestNo]
        , list.[RequestDate]
        , list.[MaintenanceCategoryFullPath_A]
        , list.[StatusName_A]
        , list.[StatusCode]
        , dispute.[RaisedByDSDID]
        , dispute.[AgainstDSDID]
        , dispute.[RaisedByUserID]
        , dispute.[Reason]
        , dispute.[ArbitrationDSDID]
        , dispute.[DecisionByUserID]
        , dispute.[DecisionNote]
        , dispute.[IsBindingDecision]
        , dispute.[DecisionDate]
        , dispute.[DisputeStatusID]
        , dispute.[IsActive]
    FROM [Maintenance].[BuildingMaintenanceRequestDispute] AS dispute
    INNER JOIN [Maintenance].[V_BuildingMaintenanceRequestList] AS list
        ON list.[RequestID] = dispute.[RequestID]
    WHERE list.[IdaraId] = @idaraID
      AND dispute.[IsActive] = 1
      AND dispute.[DecisionDate] IS NULL
    ORDER BY dispute.[entryDate] DESC, dispute.[DisputeID] DESC;

    SELECT
          list.[RequestID]
        , list.[RequestNo]
        , list.[RequestDate]
        , list.[MaintenanceCategoryFullPath_A]
        , list.[CurrentDSDID]
        , list.[StatusName_A]
        , list.[StatusCode]
    FROM [Maintenance].[V_BuildingMaintenanceRequestList] AS list
    WHERE list.[IdaraId] = @idaraID
      AND list.[IsActive] = 1
      AND ISNULL(list.[StatusCode], N'') NOT IN (N'CLOSED', N'CANCELLED')
    ORDER BY list.[RequestDate] DESC, list.[RequestID] DESC;

    SELECT
          dsd.[DSDID]
        , COALESCE
          (
              NULLIF(LTRIM(RTRIM(CONCAT(dept.[deptName_A], N' ', sec.[secName_A], N' ', div.[divName_A]))), N''),
              N'جهة رقم ' + CONVERT(NVARCHAR(30), dsd.[DSDID])
          ) AS [DSDName_A]
    FROM [dbo].[DeptSecDiv] AS dsd
    LEFT JOIN [dbo].[Department] AS dept
        ON dept.[deptID] = dsd.[deptID_FK]
    LEFT JOIN [dbo].[Section] AS sec
        ON sec.[secID] = dsd.[secID_FK]
    LEFT JOIN [dbo].[Divison] AS div
        ON div.[divID] = dsd.[divID_FK]
    WHERE dsd.[idaraID_FK] = @idaraID
    ORDER BY [DSDName_A], dsd.[DSDID];

    SELECT TOP (100)
          timeline.[ActionID]
        , timeline.[RequestID]
        , list.[RequestNo]
        , timeline.[ActionDate]
        , timeline.[ActionTypeName_A]
        , timeline.[ActionTypeCode]
        , timeline.[ReasonName_A]
        , timeline.[ActionNote]
    FROM [Maintenance].[V_BuildingMaintenanceRequestTimeline] AS timeline
    INNER JOIN [Maintenance].[V_BuildingMaintenanceRequestList] AS list
        ON list.[RequestID] = timeline.[RequestID]
    WHERE list.[IdaraId] = @idaraID
    ORDER BY timeline.[ActionDate] DESC, timeline.[ActionID] DESC;
END;

GO

