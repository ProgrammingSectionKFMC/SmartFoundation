





CREATE   VIEW [Housing].[V_WaitingList_20261111]
AS
WITH d AS
(
    SELECT
        b.buildingActionID AS RootActionID,
        x.buildingActionID,
        x.buildingActionParentID,
        x.buildingActionTypeID_FK,
        x.IdaraId_FK,
        1 AS Lvl
    FROM Housing.BuildingAction b
    INNER JOIN Housing.BuildingAction x
        ON x.buildingActionParentID = b.buildingActionID
        AND x.buildingActionActive = 1
        AND x.buildingActionTypeID_FK <> 18
    WHERE b.buildingActionTypeID_FK in(1,7,25)
      AND b.buildingActionActive = 1

    UNION ALL

    SELECT
        d.RootActionID,
        x.buildingActionID,
        x.buildingActionParentID,
        x.buildingActionTypeID_FK,
        x.IdaraId_FK,
        d.Lvl + 1
    FROM d
    INNER JOIN Housing.BuildingAction x
        ON x.buildingActionParentID = d.buildingActionID

        where x.buildingActionActive = 1
        AND x.buildingActionTypeID_FK <> 18
),
leaf AS
(
    SELECT
        d.RootActionID,
        d.buildingActionID,
        d.buildingActionTypeID_FK,
        d.IdaraId_FK,
        d.Lvl,
        ROW_NUMBER() OVER
        (
            PARTITION BY d.RootActionID
            ORDER BY d.Lvl DESC, d.buildingActionID DESC
        ) AS rn
    FROM d
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM Housing.BuildingAction ch
        WHERE ch.buildingActionParentID = d.buildingActionID
        AND ch.buildingActionActive = 1
        AND ch.buildingActionTypeID_FK <> 18
    )
)
SELECT
    b.buildingActionID AS ActionID,
    b.buildingActionTypeID_FK as ActionTypeID,
    ri.NationalID,
    rd.generalNo_FK AS GeneralNo,
    b.buildingActionDecisionNo AS ActionDecisionNo,
    CONVERT(nvarchar(10), b.buildingActionDecisionDate, 23) AS ActionDecisionDate,

    wc.waitingClassID AS WaitingClassID,
    wc.waitingClassName_A AS WaitingClassName,
    wo.waitingOrderTypeID AS WaitingOrderTypeID,
    wo.waitingOrderTypeName_A AS WaitingOrderTypeName,
    wc.waitingClassSequence AS waitingClassSequence,

    b.buildingActionDate AS ActionDate,
    ri.residentInfoID AS residentInfoID,

    LTRIM(RTRIM(CONCAT_WS(N' ', rd.firstName_A, rd.secondName_A, rd.thirdName_A, rd.lastName_A))) AS fullname,

    b.buildingActionNote AS ActionNote,
    b.IdaraId_FK AS IdaraId,
    i.idaraLongName_A AS ActionIdaraName,

    b.entryData AS MainActionEntryData,
    b.entryDate AS MainActionEntryDate,

    la.buildingActionExtraInt1 AS ToIdaraID,
    toidara.idaraLongName_A AS Toidaraname,

    la.buildingDetailsID_FK as buildingDetailsID,
    la.buildingDetailsNo,
    

    l.buildingActionID AS LastActionID,
    l.buildingActionTypeID_FK AS LastActionTypeID,
    bt.buildingActionTypeName_A AS LastActionTypeName,
    bt.buildingActionRoot,
    la.buildingActionDate  as LastActionDate,
    l.IdaraId_FK AS LastActionIdaraID,
    it.idaraLongName_A AS LastActionIdaraName,



    la.buildingActionDecisionNo AS LastActionDecisionNo,
    CONVERT(nvarchar(10), la.buildingActionDecisionDate, 23) AS LastActionDecisionDate,
    la.buildingActionFromDate,
    la.buildingActionToDate,

    
    la.AssignPeriodID_FK as AssignPeriodID,
    la.InAssignPeriod as InAssignPeriod,
    la.buildingActionParentID as LastActionbuildingActionParentID,

    la.buildingActionNote AS LastActionNote,
    la.entryDate AS LastActionEntryDate,
    custody.CustdyRecord AS CustdyRecord,
    la.entryData AS LastActionEntryData,
    la.ExtendReasonTypeID_FK as LastActionExtendReasonTypeID,
    rd.IdaraId_FK ResidentIdaraID,
    COALESCE(la.OccupentDate, occupancyAction.OccupentDate) AS OccupentDate,
    la.ExitDate
    
FROM Housing.BuildingAction b
LEFT JOIN leaf l
    ON l.RootActionID = b.buildingActionID
   AND l.rn = 1
LEFT JOIN Housing.BuildingAction la
    ON la.buildingActionID = l.buildingActionID
OUTER APPLY
(
    SELECT TOP (1) occupancy.OccupentDate
    FROM d occupancyNode
    JOIN Housing.BuildingAction occupancy
      ON occupancy.buildingActionID = occupancyNode.buildingActionID
    WHERE occupancyNode.RootActionID = b.buildingActionID
      AND occupancy.buildingActionTypeID_FK = 2
      AND occupancy.OccupentDate IS NOT NULL
    ORDER BY occupancy.OccupentDate DESC, occupancy.buildingActionID DESC
) occupancyAction
LEFT JOIN Housing.BuildingActionType bt
    ON bt.buildingActionTypeID = l.buildingActionTypeID_FK
INNER JOIN Housing.ResidentInfo ri
    ON ri.residentInfoID = b.residentInfoID_FK
    AND ri.residentInfoActive = 1

-- ✅ اختر آخر ResidentDetails Active فقط (بدون تكرار)
OUTER APPLY (
    SELECT TOP (1) rd1.*
    FROM Housing.ResidentDetails rd1
    WHERE rd1.residentInfoID_FK = ri.residentInfoID
      AND rd1.IdaraId_FK = b.IdaraId_FK
      AND rd1.residentDetailsActive = 1
    ORDER BY rd1.residentDetailsID DESC
) rd

LEFT JOIN Housing.WaitingClass wc
    ON b.buildingActionExtraType1 = wc.waitingClassID
LEFT JOIN Housing.WaitingOrderType wo
    ON b.buildingActionExtraType2 = wo.waitingOrderTypeID
LEFT JOIN dbo.Idara i
    ON b.IdaraId_FK = i.idaraID
LEFT JOIN dbo.Idara it
    ON l.IdaraId_FK = it.idaraID
LEFT JOIN dbo.Idara toidara
    ON la.buildingActionExtraInt1 = toidara.idaraID

    OUTER APPLY
(
    SELECT TOP (1)
        c.CustdyRecord
    FROM Housing.fn_BuildingAction_ChainToRoot(la.buildingActionID) c
    WHERE NULLIF(LTRIM(RTRIM(c.CustdyRecord)), N'') IS NOT NULL
    ORDER BY c.Lvl DESC
) custody


WHERE b.buildingActionTypeID_FK in(1,7,25)
  AND b.buildingActionActive = 1
  AND b.residentInfoID_FK is not null;