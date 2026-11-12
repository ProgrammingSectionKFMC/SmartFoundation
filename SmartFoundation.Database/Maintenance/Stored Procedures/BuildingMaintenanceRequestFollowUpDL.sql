
CREATE   PROCEDURE [Maintenance].[BuildingMaintenanceRequestFollowUpDL]
      @pageName_ NVARCHAR(200) = NULL
    , @idaraID NVARCHAR(10) = NULL
    , @entryData NVARCHAR(20) = NULL
    , @hostName NVARCHAR(200) = NULL
    , @RequestID NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------------------
    --                    BuildingMaintenanceRequestFollowUp
    ----------------------------------------------------------------

    DECLARE @IdaraID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID)), N''));
    DECLARE @RequestID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@RequestID)), N''));

    SELECT
          details.RequestID
        , details.RequestNo
        , details.IdaraId
        , details.RequestDate
        , details.BuildingID
        , details.ResidentID
        , details.MaintenanceCategoryID
        , details.MaintenanceCategoryName_A
        , details.MaintenanceCategoryFullPath_A
        , details.StatusID
        , details.StatusName_A
        , details.StatusCode
        , details.PriorityID
        , details.PriorityName_A
        , details.PriorityCode
        , details.CurrentDSDID
        , details.OriginalDSDID
        , details.Description_A
        , lastAction.LastActionDate
        , lastAction.LastActionTypeName_A
        , lastAction.LastActionTypeCode
        , lastAction.LastActionNote
        , CASE
            WHEN details.StatusCode = N'COMPLETED' OR lastAction.LastActionTypeCode = N'INSPECTION_REPORT'
                THEN 1
            ELSE 0
          END AS CanCloseMaintenanceRequest
        , details.ClosedDate
        , details.IsActive
    FROM Maintenance.V_BuildingMaintenanceRequestDetails AS details
    OUTER APPLY
    (
        SELECT TOP 1
              timeline.ActionDate AS LastActionDate
            , timeline.ActionTypeName_A AS LastActionTypeName_A
            , timeline.ActionTypeCode AS LastActionTypeCode
            , timeline.ActionNote AS LastActionNote
        FROM Maintenance.V_BuildingMaintenanceRequestTimeline AS timeline
        WHERE timeline.RequestID = details.RequestID
        ORDER BY timeline.ActionDate DESC, timeline.ActionID DESC
    ) AS lastAction
    WHERE details.IdaraId = @IdaraID_BIGINT
      AND details.IsActive = 1
      AND (@RequestID_BIGINT IS NULL OR details.RequestID = @RequestID_BIGINT)
      AND (@RequestID_BIGINT IS NOT NULL OR ISNULL(details.StatusCode, N'') NOT IN (N'CLOSED', N'CANCELLED'))
    ORDER BY details.RequestDate DESC, details.RequestID DESC;

    SELECT
          timeline.ActionID
        , timeline.RequestID
        , timeline.ActionDate
        , timeline.ActionTypeID
        , timeline.ActionTypeName_A
        , timeline.ActionTypeCode
        , timeline.ReasonID
        , timeline.ReasonName_A
        , timeline.FromDSDID
        , timeline.ToDSDID
        , timeline.FromUserID
        , timeline.ToUserID
        , timeline.OldStatusID
        , timeline.OldStatusName_A
        , timeline.NewStatusID
        , timeline.NewStatusName_A
        , timeline.ActionNote
        , timeline.entryUser
        , timeline.entryDate
    FROM Maintenance.V_BuildingMaintenanceRequestTimeline AS timeline
    INNER JOIN Maintenance.BuildingMaintenanceRequest AS request
        ON request.RequestID = timeline.RequestID
       AND request.IdaraId_FK = @IdaraID_BIGINT
    WHERE (@RequestID_BIGINT IS NULL OR timeline.RequestID = @RequestID_BIGINT)
    ORDER BY timeline.ActionDate DESC, timeline.ActionID DESC;

    SELECT
          assignments.AssignmentID
        , assignments.RequestID
        , assignments.AssignedToUserID
        , assignments.AssignedByUserID
        , assignments.AssignedDSDID
        , assignments.AssignedDate
        , assignments.InspectionDate
        , assignments.CompletionDate
        , assignments.AssignmentStatusID
        , assignments.NeedsApproval
        , assignments.NeedsSubRequest
        , assignments.TransactionID_FK
        , assignments.ReportText
        , assignments.IsActive
        , CONVERT(NVARCHAR(50), assignments.AssignmentID) + N' - ' + ISNULL(users.FullName, N'') AS AssignmentDisplayName
    FROM Maintenance.V_BuildingMaintenanceRequestAssignments AS assignments
    INNER JOIN Maintenance.BuildingMaintenanceRequest AS request
        ON request.RequestID = assignments.RequestID
       AND request.IdaraId_FK = @IdaraID_BIGINT
    LEFT JOIN dbo.V_GetFullSystemUsersDetails AS users
        ON users.usersID = assignments.AssignedToUserID
    WHERE assignments.IsActive = 1
      AND (@RequestID_BIGINT IS NULL OR assignments.RequestID = @RequestID_BIGINT)
    ORDER BY assignments.AssignedDate DESC, assignments.AssignmentID DESC;

    SELECT
          ReasonID
        , ReasonName_A
        , ReasonCode
        , IsActive
        , IdaraId_FK
    FROM Maintenance.MaintenanceActionReason
    WHERE IsActive = 1
      AND (IdaraId_FK IS NULL OR IdaraId_FK = @IdaraID_BIGINT)
    ORDER BY ReasonID;

    SELECT
          usersID
        , nationalID
        , GeneralNo
        , FullName
        , userActive
        , IdaraID
        , CONCAT(ISNULL(CONVERT(NVARCHAR(50), GeneralNo), N''), N' - ', ISNULL(FullName, N'')) AS UserDisplayName
    FROM dbo.V_GetFullSystemUsersDetails
    WHERE userActive = 1
      AND (IdaraID IS NULL OR IdaraID = @IdaraID_BIGINT)
    ORDER BY FullName;
END

GO

