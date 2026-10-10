CREATE FUNCTION [Housing].[fn_BuildingOccupancyPeriods]
(
    @BuildingDetailsID BIGINT,
    @IdaraID BIGINT
)
RETURNS TABLE
AS
RETURN
(
    -- Follow each occupancy's own history; a different occupancy date starts
    -- another period. Restored occupancy rows after cancellation keep the date.
    WITH OccupancyChain AS
    (
        SELECT
              ba.buildingActionID AS OccupancyActionID
            , ba.residentInfoID_FK
            , CONVERT(DATE, COALESCE(ba.OccupentDate, ba.buildingActionDate, ba.entryDate)) AS OccupentDate
            , ba.buildingActionID
            , ba.buildingActionTypeID_FK
            , CONVERT(DATE, ba.ExitDate) AS ActionExitDate
            , CAST(CONCAT('|', ba.buildingActionID, '|') AS VARCHAR(MAX)) AS ActionPath
        FROM Housing.BuildingAction ba
        WHERE ba.buildingDetailsID_FK = @BuildingDetailsID
          AND ba.IdaraId_FK = @IdaraID
          AND ba.buildingActionTypeID_FK = 2
          AND ba.buildingActionActive = 1

        UNION ALL

        SELECT
              parent.OccupancyActionID
            , parent.residentInfoID_FK
            , parent.OccupentDate
            , child.buildingActionID
            , child.buildingActionTypeID_FK
            , CONVERT(DATE, CASE WHEN child.buildingActionTypeID_FK IN (3,54,56)
                                THEN COALESCE(child.ExitDate, child.buildingActionDate)
                                ELSE child.ExitDate END)
            , CAST(CONCAT(parent.ActionPath, child.buildingActionID, '|') AS VARCHAR(MAX))
        FROM OccupancyChain parent
        INNER JOIN Housing.BuildingAction child
            ON child.buildingActionParentID = parent.buildingActionID
           AND child.residentInfoID_FK = parent.residentInfoID_FK
           AND child.buildingDetailsID_FK = @BuildingDetailsID
           AND child.IdaraId_FK = @IdaraID
           AND child.buildingActionActive = 1
        WHERE CHARINDEX(CONCAT('|', child.buildingActionID, '|'), parent.ActionPath) = 0
          AND (child.buildingActionTypeID_FK <> 2
               OR CONVERT(DATE, COALESCE(child.OccupentDate, child.buildingActionDate, child.entryDate)) = parent.OccupentDate)
    ),
    ExitEvents AS
    (
        SELECT *, ROW_NUMBER() OVER
        (
            PARTITION BY OccupancyActionID
            -- Explicit creation/edit/cancellation/finalization is authoritative.
            -- Migrated histories may only have a financial/meter stage (57-60).
            -- Those carried dates must not overwrite a later physical-date edit.
            ORDER BY CASE WHEN buildingActionTypeID_FK IN (3,54,55,56) THEN 0 ELSE 1 END,
                     buildingActionID DESC
        ) AS EventOrder
        FROM OccupancyChain
        WHERE buildingActionTypeID_FK IN (3,54,55,56,57,58,59,60)
    )
    SELECT
          occupancy.OccupancyActionID
        , occupancy.residentInfoID_FK
        , occupancy.OccupentDate
        , CASE WHEN exitEvent.buildingActionTypeID_FK <> 55 THEN exitEvent.ActionExitDate END AS ExitDate
        , exitEvent.buildingActionID AS ExitActionID
        , exitEvent.buildingActionTypeID_FK AS ExitActionTypeID
    FROM OccupancyChain occupancy
    LEFT JOIN ExitEvents exitEvent
        ON exitEvent.OccupancyActionID = occupancy.OccupancyActionID
       AND exitEvent.EventOrder = 1
    WHERE occupancy.buildingActionID = occupancy.OccupancyActionID
);
