
CREATE   PROCEDURE [Maintenance].[MaintenanceSubRequestDL]
      @pageName_ NVARCHAR(400)
    , @idaraID INT
    , @entryData NVARCHAR(20) = NULL
    , @hostName NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
          list.[RequestID]
        , list.[TransactionID_FK]
        , list.[RequestNo]
        , list.[RequestDate]
        , list.[ParentRequestID]
        , list.[RootRequestID]
        , list.[RequestLevel]
        , list.[BuildingID]
        , list.[ResidentID]
        , list.[MaintenanceCategoryID]
        , list.[MaintenanceCategoryFullPath_A]
        , list.[CurrentDSDID]
        , list.[StatusID]
        , list.[StatusName_A]
        , list.[StatusCode]
        , list.[PriorityID]
        , list.[PriorityName_A]
        , list.[PriorityCode]
        , list.[LastActionDate]
        , list.[LastActionTypeName_A]
        , list.[LastActionNote]
    FROM [Maintenance].[V_BuildingMaintenanceRequestList] AS list
    WHERE list.[IdaraId] = @idaraID
      AND list.[IsActive] = 1
      AND list.[IsSubRequest] = 1
    ORDER BY list.[RequestDate] DESC, list.[RequestID] DESC;

    SELECT
          list.[RequestID]
        , list.[RequestNo]
        , list.[RequestDate]
        , list.[BuildingID]
        , list.[ResidentID]
        , list.[MaintenanceCategoryFullPath_A]
        , list.[StatusName_A]
        , list.[StatusCode]
        , list.[PriorityName_A]
        , list.[CurrentDSDID]
    FROM [Maintenance].[V_BuildingMaintenanceRequestList] AS list
    WHERE list.[IdaraId] = @idaraID
      AND list.[IsActive] = 1
      AND list.[IsSubRequest] = 0
      AND ISNULL(list.[StatusCode], N'') NOT IN (N'CLOSED', N'CANCELLED', N'COMPLETED')
    ORDER BY list.[RequestDate] DESC, list.[RequestID] DESC;

    SELECT
          tree.[MaintenanceCategoryID]
        , tree.[FullPath_A]
        , routing.[ResponsibleDSDID]
    FROM [Maintenance].[V_MaintenanceCategoryTree] AS tree
    INNER JOIN [Maintenance].[MaintenanceCategoryRouting] AS routing
        ON routing.[IdaraId_FK] = tree.[IdaraId]
       AND routing.[MaintenanceCategoryID] = tree.[MaintenanceCategoryID]
       AND routing.[IsActive] = 1
       AND routing.[IsDefault] = 1
    WHERE tree.[IdaraId] = @idaraID
      AND tree.[IsActive] = 1
      AND tree.[HasChildren] = 0
    ORDER BY tree.[FullPath_A], tree.[MaintenanceCategoryID];

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

    SELECT
          [PriorityID]
        , [PriorityName_A]
        , [PriorityCode]
    FROM [Maintenance].[MaintenancePriority]
    WHERE [IsActive] = 1
      AND ([IdaraId_FK] IS NULL OR [IdaraId_FK] = @idaraID)
    ORDER BY [DisplayOrder], [PriorityID];

    SELECT
          [StatusID]
        , [StatusName_A]
        , [StatusCode]
    FROM [Maintenance].[MaintenanceRequestStatus]
    WHERE [IsActive] = 1
      AND ([IdaraId_FK] IS NULL OR [IdaraId_FK] = @idaraID)
    ORDER BY [DisplayOrder], [StatusID];
END;

GO

