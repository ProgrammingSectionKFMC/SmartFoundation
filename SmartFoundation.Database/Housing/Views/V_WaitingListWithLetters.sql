
CREATE   VIEW [Housing].[V_WaitingListWithLetters]
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
    WHERE b.buildingActionTypeID_FK IN (1,7)
      AND b.buildingActionActive = 1
      AND x.buildingActionActive = 1

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
    WHERE x.buildingActionActive = 1
),
-- ✅ بدل NOT EXISTS: نجيب أقصى مستوى لكل Root (أخف)
lastlvl AS
(
    SELECT
        RootActionID,
        MaxLvl = MAX(Lvl)
    FROM d
    GROUP BY RootActionID
),
-- ✅ نختار آخر أكشن داخل آخر مستوى (نفس منطقك السابق)
leaf AS
(
    SELECT
        d.RootActionID,
        d.buildingActionID,
        d.buildingActionTypeID_FK,
        d.IdaraId_FK,
        d.Lvl,
        rn = ROW_NUMBER() OVER
        (
            PARTITION BY d.RootActionID
            ORDER BY d.buildingActionID DESC
        )
    FROM d
    INNER JOIN lastlvl ll
        ON ll.RootActionID = d.RootActionID
       AND ll.MaxLvl = d.Lvl
)
SELECT
    b.buildingActionID AS ActionID,
    b.buildingActionTypeID_FK AS ActionTypeID,

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

    la.buildingDetailsID_FK AS buildingDetailsID,
    la.buildingDetailsNo,

    l.buildingActionTypeID_FK AS LastActionTypeID,
    l.buildingActionID AS LastActionID,
    l.IdaraId_FK AS LastActionIdaraID,
    it.idaraLongName_A AS LastActionIdaraName,

    bt.buildingActionTypeName_A AS LastActionTypeName,
    la.AssignPeriodID_FK AS AssignPeriodID,
    la.buildingActionParentID AS LastActionbuildingActionParentID,

    la.buildingActionNote AS LastActionNote,
    la.entryDate AS LastActionEntryDate,
    la.entryData AS LastActionEntryData,

    rd.IdaraId_FK AS ResidentIdaraID
FROM Housing.BuildingAction b
LEFT JOIN leaf l
    ON l.RootActionID = b.buildingActionID
   AND l.rn = 1
LEFT JOIN Housing.BuildingAction la
    ON la.buildingActionID = l.buildingActionID
LEFT JOIN Housing.BuildingActionType bt
    ON bt.buildingActionTypeID = l.buildingActionTypeID_FK
LEFT JOIN Housing.ResidentInfo ri
    ON ri.residentInfoID = b.residentInfoID_FK

-- ✅ اختر آخر ResidentDetails Active فقط (بدون تكرار)
OUTER APPLY
(
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
WHERE b.buildingActionTypeID_FK IN (1,7)
  AND b.buildingActionActive = 1;
