
CREATE   PROCEDURE [Maintenance].[BuildingMaintenanceRequestDL]
      @pageName_ NVARCHAR(200) = NULL
    , @idaraID NVARCHAR(10) = NULL
    , @entryData NVARCHAR(20) = NULL
    , @hostName NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------------------
    --                    BuildingMaintenanceRequest
    ----------------------------------------------------------------

    DECLARE @IdaraID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID)), N''));

    SELECT
          list.RequestID
        , list.TransactionID_FK
        , list.RequestNo
        , r.FullName_A
        , b.buildingDetailsNo
        , list.IdaraId
        , list.RequestDate
        , list.BuildingID
        , list.UnitID
        , list.ResidentID
        , list.MaintenanceCategoryID
        , list.MaintenanceCategoryName_A
        , list.MaintenanceCategoryFullPath_A
        , list.CurrentDSDID
        , list.OriginalDSDID
        , list.StatusID
        , list.StatusName_A
        , list.StatusCode
        , list.PriorityID
        , list.PriorityName_A
        , list.PriorityCode
        , list.ParentRequestID
        , list.RootRequestID
        , list.RequestLevel
        , list.IsSubRequest
        , list.HasDispute
        , list.EscalationLevel
        , list.IsLockedByDecision
        , list.SubRequestsCount
        , list.OpenSubRequestsCount
        , list.LastActionDate
        , list.LastActionTypeName_A
        , list.LastActionNote
        , list.ClosedDate
        , list.IsActive
        , request.Description_A
        
    FROM Maintenance.V_BuildingMaintenanceRequestList AS list
    INNER JOIN Maintenance.BuildingMaintenanceRequest AS request
        ON request.RequestID = list.RequestID
        left join Housing.V_GetFullResidentDetails r on r.residentInfoID = request.ResidentID
        left join Housing.V_GetGeneralListForBuilding b on request.BuildingID = b.buildingDetailsID
        
    WHERE list.IdaraId = @IdaraID_BIGINT
      AND list.IsActive = 1
    ORDER BY list.RequestDate DESC, list.RequestID DESC;

    SELECT
          d.residentInfoID
        , d.NationalID
        , d.generalNo_FK
        , d.FullName_A
        , d.rankNameA
        , d.militaryUnitName_A
        , d.residentcontactDetails
        , d.IdaraID
        , CONCAT(ISNULL(d.NationalID, N''), N' - ', ISNULL(CONVERT(NVARCHAR(50), d.generalNo_FK), N''), N' - ', ISNULL(d.FullName_A, N'')) AS ResidentDisplayName
    FROM Housing.V_GetFullResidentDetails d
    inner join Housing.V_WaitingList w on d.residentInfoID = w.residentInfoID and w.buildingActionRoot = 2
    WHERE d.IdaraID = @IdaraID_BIGINT
    ORDER BY FullName_A;

    SELECT
          residentInfoID
        , buildingDetailsID
        , buildingDetailsNo
        , OccupentDate
        , ExitDate
        , IdaraId
        , CONCAT(ISNULL(buildingDetailsNo, N''), N' - ', N'مبنى رقم ', ISNULL(buildingDetailsNo, N'')) AS BuildingDisplayName
    FROM Housing.V_Occupant
    WHERE IdaraId = @IdaraID_BIGINT
      AND ExitDate IS NULL
    ORDER BY buildingDetailsNo;

    SELECT
          tree.MaintenanceCategoryID
        , tree.FullPath_A
        , tree.CategoryName_A
        , routing.ResponsibleDSDID
        , routing.MaintenanceCategoryRoutingID
    FROM Maintenance.V_MaintenanceCategoryTree AS tree
    INNER JOIN Maintenance.MaintenanceCategoryRouting AS routing
        ON routing.MaintenanceCategoryID = tree.MaintenanceCategoryID
       AND routing.IdaraId_FK = tree.IdaraId
       AND routing.IsActive = 1
       AND routing.IsDefault = 1
       AND routing.ResponsibleDSDID IS NOT NULL
    WHERE tree.IdaraId = @IdaraID_BIGINT
      AND tree.IsActive = 1
    ORDER BY tree.DisplayOrder, tree.FullPath_A;

    SELECT
          PriorityID
        , PriorityName_A
        , PriorityCode
        , DisplayOrder
        , IsActive
        , IdaraId_FK
    FROM Maintenance.MaintenancePriority
    WHERE IsActive = 1
      AND (IdaraId_FK IS NULL OR IdaraId_FK = @IdaraID_BIGINT)
    ORDER BY DisplayOrder, PriorityID;

    SELECT
          StatusID
        , StatusName_A
        , StatusCode
        , DisplayOrder
        , IsClosed
        , IsActive
        , IdaraId_FK
    FROM Maintenance.MaintenanceRequestStatus
    WHERE IsActive = 1
      AND (IdaraId_FK IS NULL OR IdaraId_FK = @IdaraID_BIGINT)
    ORDER BY DisplayOrder, StatusID;
END

GO

