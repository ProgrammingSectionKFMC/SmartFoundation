
CREATE   VIEW Housing.V_GetGeneralListActionForBuilding
AS
SELECT
    b.buildingDetailsID,
    b.buildingDetailsNo,

    a.buildingActionID,
    a.buildingActionUDID,
    a.buildingActionParentID,

    a.buildingActionTypeID_FK AS ActionTypeID,
    t.buildingActionTypeName_A AS ActionTypeName,
    t.buildingActionTypeBuildingAlias AS ActionTypeBuildingAlias,

    a.residentInfoID_FK AS ResidentID,
    a.generalNo_FK AS GeneralNo,

    a.buildingStatusID_FK AS BuildingStatusID,

    a.buildingActionDate AS ActionDate,
    a.entryDate AS EntryDate,
    a.OccupentDate,
    a.ExitDate,

    a.buildingActionActive AS ActionActive,
    a.buildingActionNote AS ActionNote,

    a.AssignPeriodID_FK AS AssignPeriodID,
    a.IdaraId_FK AS IdaraID,

    a.entryData,
    a.hostName

FROM Housing.BuildingDetails b

INNER JOIN Housing.BuildingAction a
    ON a.buildingDetailsID_FK = b.buildingDetailsID

LEFT JOIN Housing.BuildingActionType t
    ON t.buildingActionTypeID = a.buildingActionTypeID_FK;

GO

