
CREATE   PROCEDURE [Maintenance].[MaintenanceApprovalDL]
      @pageName_ NVARCHAR(400)
    , @idaraID INT
    , @entryData NVARCHAR(20) = NULL
    , @hostName NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
          list.[RequestID]
        , list.[RequestNo]
        , list.[RequestDate]
        , list.[BuildingID]
        , list.[ResidentID]
        , list.[MaintenanceCategoryID]
        , list.[MaintenanceCategoryFullPath_A]
        , list.[PriorityName_A]
        , list.[StatusName_A]
        , list.[CurrentDSDID]
        , list.[LastActionDate]
        , list.[LastActionTypeName_A]
        , list.[LastActionNote]
    FROM [Maintenance].[V_BuildingMaintenanceRequestList] AS list
    WHERE list.[IdaraId] = @idaraID
      AND list.[IsActive] = 1
      AND list.[StatusCode] = N'WAITING_APPROVAL'
    ORDER BY list.[RequestDate] DESC, list.[RequestID] DESC;
END;

GO

