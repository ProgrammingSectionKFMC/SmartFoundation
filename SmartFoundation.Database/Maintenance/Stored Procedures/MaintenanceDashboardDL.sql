
CREATE   PROCEDURE [Maintenance].[MaintenanceDashboardDL]
      @pageName_ NVARCHAR(400)
    , @idaraID INT
    , @entryData NVARCHAR(20) = NULL
    , @hostName NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [StatusID], [StatusName_A], [StatusCode], COUNT(1) AS [RequestsCount]
    FROM [Maintenance].[V_BuildingMaintenanceRequestList]
    WHERE [IdaraId] = @idaraID
      AND [IsActive] = 1
    GROUP BY [StatusID], [StatusName_A], [StatusCode]
    ORDER BY [StatusName_A];

    SELECT COUNT(1) AS [OpenRequestsCount]
    FROM [Maintenance].[V_BuildingMaintenanceRequestList]
    WHERE [IdaraId] = @idaraID
      AND [IsActive] = 1
      AND ISNULL([StatusCode], N'') NOT IN (N'CLOSED', N'CANCELLED', N'COMPLETED');

    SELECT COUNT(1) AS [ClosedRequestsCount]
    FROM [Maintenance].[V_BuildingMaintenanceRequestList]
    WHERE [IdaraId] = @idaraID
      AND [IsActive] = 1
      AND ISNULL([StatusCode], N'') IN (N'CLOSED', N'COMPLETED');

    SELECT COUNT(1) AS [LateRequestsCount]
    FROM [Maintenance].[V_BuildingMaintenanceRequestSLAStatus]
    WHERE [IdaraId] = @idaraID
      AND [IsAnyLate] = 1;

    SELECT [MaintenanceCategoryID], [MaintenanceCategoryFullPath_A], COUNT(1) AS [RequestsCount]
    FROM [Maintenance].[V_BuildingMaintenanceRequestList]
    WHERE [IdaraId] = @idaraID
      AND [IsActive] = 1
    GROUP BY [MaintenanceCategoryID], [MaintenanceCategoryFullPath_A]
    ORDER BY [RequestsCount] DESC, [MaintenanceCategoryFullPath_A];

    SELECT [CurrentDSDID], COUNT(1) AS [RequestsCount]
    FROM [Maintenance].[V_BuildingMaintenanceRequestList]
    WHERE [IdaraId] = @idaraID
      AND [IsActive] = 1
    GROUP BY [CurrentDSDID]
    ORDER BY [RequestsCount] DESC, [CurrentDSDID];

    SELECT [PriorityID], [PriorityName_A], [PriorityCode], COUNT(1) AS [RequestsCount]
    FROM [Maintenance].[V_BuildingMaintenanceRequestList]
    WHERE [IdaraId] = @idaraID
      AND [IsActive] = 1
    GROUP BY [PriorityID], [PriorityName_A], [PriorityCode]
    ORDER BY [RequestsCount] DESC, [PriorityName_A];

    SELECT TOP (20)
          [RequestID]
        , [RequestNo]
        , [RequestDate]
        , [MaintenanceCategoryFullPath_A]
        , [StatusName_A]
        , [StatusCode]
        , [PriorityName_A]
        , [CurrentDSDID]
    FROM [Maintenance].[V_BuildingMaintenanceRequestList]
    WHERE [IdaraId] = @idaraID
      AND [IsActive] = 1
    ORDER BY [RequestDate] DESC, [RequestID] DESC;

    SELECT TOP (20) [MaintenanceCategoryID], [MaintenanceCategoryFullPath_A], COUNT(1) AS [RequestsCount]
    FROM [Maintenance].[V_BuildingMaintenanceRequestList]
    WHERE [IdaraId] = @idaraID
      AND [IsActive] = 1
    GROUP BY [MaintenanceCategoryID], [MaintenanceCategoryFullPath_A]
    ORDER BY [RequestsCount] DESC, [MaintenanceCategoryFullPath_A];

    SELECT COUNT(1) AS [OpenDisputesCount]
    FROM [Maintenance].[BuildingMaintenanceRequestDispute] AS dispute
    INNER JOIN [Maintenance].[BuildingMaintenanceRequest] AS request
        ON request.[RequestID] = dispute.[RequestID]
    WHERE request.[IdaraId_FK] = @idaraID
      AND dispute.[IsActive] = 1
      AND dispute.[DecisionDate] IS NULL;

    SELECT COUNT(1) AS [WaitingApprovalRequestsCount]
    FROM [Maintenance].[V_BuildingMaintenanceRequestList]
    WHERE [IdaraId] = @idaraID
      AND [IsActive] = 1
      AND [StatusCode] = N'WAITING_APPROVAL';

    SELECT COUNT(1) AS [OpenSubRequestsCount]
    FROM [Maintenance].[V_BuildingMaintenanceRequestList]
    WHERE [IdaraId] = @idaraID
      AND [IsActive] = 1
      AND [IsSubRequest] = 1
      AND ISNULL([StatusCode], N'') NOT IN (N'CLOSED', N'CANCELLED', N'COMPLETED');
END;

GO

