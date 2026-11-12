-- STAGING ONLY: creates V2 separately, never modifies production or V1.
-- Accepted outcome 45 continues the housing handover chain. Rejections 39/41 are excluded.
-- For a confirmation sibling of allocation, require same parent and same house/resident.
-- First verify exact definition matches production baseline and compare all output rows.
CREATE   VIEW [Housing].[V_GetGeneralListForBuilding_Candidate_Operational_V2] AS WITH EligibleBuildings AS (  SELECT bd.buildingDetailsID,bd.buildingDetailsNo,bd.buildingDetailsRooms,         bd.buildingLevelsCount,bd.buildingDetailsArea,bd.buildingDetailsCoordinates,         bd.buildingTypeID_FK,bt.buildingTypeName_A,         bd.buildingUtilityTypeID_FK,bu.buildingUtilityTypeName_A,         bd.militaryLocationID_FK,m.militaryLocationName_A,         mac.militaryAreaCityName_A,ma.militaryAreaName_A,         bd.buildingClassID_FK,bc.buildingClassName_A,         bd.buildingDetailsTel_1,bd.buildingDetailsTel_2,bd.buildingDetailsRemark,         bd.buildingDetailsStartDate,bd.buildingDetailsEndDate,bd.buildingDetailsActive,         bu.buildingUtilityIsRent,bd.IdaraId_FK AS BuildingIdaraID,         i.idaraLongName_A AS BuildingIdaraName,         bt.IdaraId_FK AS BuildingTypeIdaraID,         bu.IdaraId_FK AS BuildingUtilityTypeIdaraID,         m.IdaraId_FK AS MilitaryLocationIdaraID,         bc.IdaraId_FK AS BuildingClassIdaraID  FROM Housing.BuildingDetails bd  JOIN Housing.BuildingType bt ON bt.buildingTypeID=bd.buildingTypeID_FK  JOIN Housing.BuildingUtilityType bu ON bu.buildingUtilityTypeID=bd.buildingUtilityTypeID_FK  JOIN Housing.MilitaryLocation m ON m.militaryLocationID=bd.militaryLocationID_FK  JOIN Housing.MilitaryAreaCity mac ON mac.militaryAreaCityID=m.militaryAreaCityID_FK  JOIN Housing.MilitaryArea ma ON ma.militaryAreaID=mac.militaryAreaID_FK  JOIN Housing.BuildingClass bc ON bc.buildingClassID=bd.buildingClassID_FK  JOIN dbo.Idara i ON i.IdaraId=bd.IdaraId_FK  WHERE bd.buildingDetailsActive=1 AND bt.buildingTypeActive=1    AND bu.buildingUtilityTypeActive=1 AND m.militaryLocationActive=1    AND bc.buildingClassActive=1 AND mac.militaryAreaCityActive=1    AND ma.militaryAreaIsActive=1    AND bd.buildingDetailsStartDate IS NOT NULL    AND bu.buildingUtilityTypeStartDate IS NOT NULL    AND (bd.buildingDetailsEndDate IS NULL OR bd.buildingDetailsEndDate>GETDATE())    AND (bu.buildingUtilityTypeEndDate IS NULL OR bu.buildingUtilityTypeEndDate>GETDATE()) ),
Actions AS (  SELECT a.buildingActionID AS ActionID,a.buildingActionTypeID_FK AS ActionType,         a.buildingActionParentID AS ParentID,a.buildingDetailsID_FK AS BuildingID,         a.IdaraId_FK AS IdaraID,a.residentInfoID_FK AS ResidentID,a.entryDate AS EntryDate  FROM Housing.BuildingAction a  JOIN EligibleBuildings b ON b.buildingDetailsID=a.buildingDetailsID_FK   AND b.BuildingIdaraID=a.IdaraId_FK  WHERE a.buildingActionActive=1 ),
HousingRanked AS (  SELECT a.*,  ROW_NUMBER() OVER(PARTITION BY BuildingID,IdaraID                    ORDER BY EntryDate DESC,ActionID DESC) AS rn  FROM Actions a WHERE ActionType=2 AND ResidentID IS NOT NULL ),
Housing2 AS (  SELECT BuildingID,IdaraID,ActionID AS H2ID,ResidentID,EntryDate AS H2Entry  FROM HousingRanked WHERE rn=1 ),
ResidentTree AS (  SELECT h.BuildingID,h.IdaraID,h.ResidentID,h.H2ID,         h.H2ID AS ActionID,CAST(0 AS int) AS Depth  FROM Housing2 h  UNION ALL  SELECT t.BuildingID,t.IdaraID,t.ResidentID,t.H2ID,         c.buildingActionID,t.Depth+1  FROM ResidentTree t  JOIN Housing.BuildingAction c ON c.buildingActionParentID=t.ActionID      AND c.buildingDetailsID_FK=t.BuildingID AND c.IdaraId_FK=t.IdaraID      AND c.residentInfoID_FK=t.ResidentID AND c.buildingActionActive=1  WHERE t.Depth<32 AND c.buildingActionID<>t.ActionID ),
FinalRanked AS (  SELECT t.BuildingID,t.IdaraID,t.H2ID,t.ActionID,t.Depth,         a.buildingActionTypeID_FK,a.entryDate,         ROW_NUMBER() OVER(PARTITION BY t.BuildingID,t.IdaraID           ORDER BY t.Depth DESC,              CASE a.buildingActionTypeID_FK WHEN 3 THEN 0 WHEN 58 THEN 1 WHEN 57 THEN 2                   WHEN 24 THEN 3 ELSE 4 END,              a.entryDate DESC,a.buildingActionID DESC) AS rn,         MAX(CASE WHEN t.Depth=32 THEN 1 ELSE 0 END)           OVER(PARTITION BY t.BuildingID,t.IdaraID) AS HitDepthLimit  FROM ResidentTree t JOIN Housing.BuildingAction a ON a.buildingActionID=t.ActionID AND a.buildingActionActive=1 ),
HousingFinal AS (  SELECT BuildingID,IdaraID,H2ID,ActionID AS HFinalID,         buildingActionTypeID_FK AS HFinalType,
entryDate AS HFinalEntry,HitDepthLimit  FROM FinalRanked WHERE rn=1 ),
OpRanked AS (  SELECT a.*,  ROW_NUMBER() OVER(PARTITION BY BuildingID,IdaraID             ORDER BY EntryDate DESC,ActionID DESC) AS rn  FROM Actions a WHERE a.ResidentID IS NULL    AND a.ActionType IN (4,5,9,10,11,12,13,14,15,16,17,29,30,31,62) ),
LastOp AS (  SELECT BuildingID,IdaraID,ActionID AS OpID,ActionType AS OpType,         EntryDate AS OpEntry FROM OpRanked WHERE rn=1 ),
GraceRanked AS (  SELECT a.*,  ROW_NUMBER() OVER(PARTITION BY BuildingID,IdaraID          ORDER BY EntryDate DESC,ActionID DESC) AS rn  FROM Actions a WHERE ActionType=24 AND ResidentID IS NOT NULL ),
LastGrace AS (  SELECT BuildingID,IdaraID,ActionID AS Action24ID,         ResidentID AS Resident24ID,EntryDate AS Entry24  FROM GraceRanked WHERE rn=1 ),
/* Current resident-linked allocation from OPERATIONAL periods only.
   Follow the true child chain. A rejection, swap or cancellation removes
   the old building from the current allocation candidate. */
OperationalFlow AS
(
 SELECT m.AssignPeriodMemberID AS MemberID,
        al.AssignPeriodAllocationID AS AllocationID,
        a.buildingActionID AS ActionID,
        a.buildingActionTypeID_FK AS ActionType,
        a.buildingDetailsID_FK AS BuildingID,
        a.IdaraId_FK AS IdaraID,
        a.residentInfoID_FK AS ResidentID,
        a.entryDate AS EntryDate,
        CAST(0 AS int) AS Depth
 FROM Housing.AssignPeriodMember m
 JOIN Housing.AssignPeriodAllocation al
   ON al.AssignPeriodMemberID_FK=m.AssignPeriodMemberID
 JOIN Housing.BuildingAction allocation
   ON allocation.buildingActionID=al.AllocationActionID_FK
  AND allocation.buildingActionActive=1
  AND allocation.buildingActionTypeID_FK IN (38,40)
  AND allocation.residentInfoID_FK=m.ResidentInfoID_FK
 LEFT JOIN Housing.BuildingAction confirmation
   ON confirmation.buildingActionID=al.ConfirmationActionID_FK
  AND confirmation.buildingActionActive=1
  AND confirmation.buildingActionTypeID_FK IN (38,40)
  AND confirmation.residentInfoID_FK=allocation.residentInfoID_FK
  AND confirmation.buildingDetailsID_FK=allocation.buildingDetailsID_FK
  AND confirmation.IdaraId_FK=allocation.IdaraId_FK
 JOIN Housing.BuildingAction a
   ON a.buildingActionID=CASE
        WHEN al.OutcomeActionID_FK IS NULL
          THEN al.AllocationActionID_FK
        ELSE al.OutcomeActionID_FK END
  AND a.buildingActionActive=1
  AND a.residentInfoID_FK=allocation.residentInfoID_FK
  AND a.buildingDetailsID_FK=allocation.buildingDetailsID_FK
  AND a.IdaraId_FK=allocation.IdaraId_FK
 WHERE m.DataOrigin=N'OPERATIONAL'
   AND
   (
      (al.OutcomeActionID_FK IS NULL
       AND a.buildingActionTypeID_FK IN (38,40))
      OR
      (al.OutcomeActionID_FK IS NOT NULL
       AND a.buildingActionTypeID_FK=45
       AND
       (
          a.buildingActionParentID=allocation.buildingActionID
          OR
          (
             confirmation.buildingActionID IS NOT NULL
             AND a.buildingActionParentID=confirmation.buildingActionID
             AND
             (
                confirmation.buildingActionParentID=allocation.buildingActionID
                OR confirmation.buildingActionParentID=allocation.buildingActionParentID
             )
          )
       )
      )
   )
 UNION ALL
 SELECT t.MemberID,t.AllocationID,
        c.buildingActionID,c.buildingActionTypeID_FK,
        c.buildingDetailsID_FK,c.IdaraId_FK,c.residentInfoID_FK,
        c.entryDate,t.Depth+1
 FROM OperationalFlow t
 JOIN Housing.BuildingAction c
   ON c.buildingActionParentID=t.ActionID
  AND c.buildingActionActive=1
  AND c.IdaraId_FK=t.IdaraID
  AND c.residentInfoID_FK=t.ResidentID
 WHERE t.Depth<32
   AND c.buildingActionID<>t.ActionID
),
OperationalLeafRanked AS
(
 SELECT t.*,
        ROW_NUMBER() OVER
        (PARTITION BY t.BuildingID,t.IdaraID
         ORDER BY t.EntryDate DESC,t.ActionID DESC) AS rn
 FROM OperationalFlow t
 JOIN EligibleBuildings b
   ON b.buildingDetailsID=t.BuildingID
  AND b.BuildingIdaraID=t.IdaraID
 WHERE t.ActionType IN (38,40,45,46,47)
   AND t.Depth<32
   AND NOT EXISTS
   (
      SELECT 1 FROM Housing.BuildingAction child
      WHERE child.buildingActionParentID=t.ActionID
        AND child.buildingActionActive=1
        AND child.IdaraId_FK=t.IdaraID
        AND child.residentInfoID_FK=t.ResidentID
   )
),
CurrentOperationalAllocation AS
(
 SELECT BuildingID,IdaraID,ActionID AS CurrentAllocationActionID
 FROM OperationalLeafRanked WHERE rn=1
),
Decision AS (  SELECT b.buildingDetailsID AS BuildingID,b.BuildingIdaraID AS IdaraID,         CASE           WHEN f.HitDepthLimit=1 THEN NULL           WHEN p.Action24ID IS NOT NULL            AND (f.HFinalID IS NULL OR p.Entry24>f.HFinalEntry)            AND (o.OpID IS NULL OR o.OpEntry<p.Entry24)            AND NOT EXISTS            (              SELECT 1 FROM Housing.BuildingAction ex              WHERE ex.buildingDetailsID_FK=p.BuildingID AND ex.IdaraId_FK=p.IdaraID                AND ex.residentInfoID_FK=p.Resident24ID AND ex.buildingActionActive=1 AND ex.buildingActionTypeID_FK IN (3,57,58)                AND ex.entryDate>p.Entry24            ) THEN p.Action24ID           WHEN f.HFinalID IS NOT NULL AND o.OpID IS NOT NULL            AND o.OpEntry=f.HFinalEntry THEN NULL           WHEN f.HFinalID IS NOT NULL AND o.OpID IS NOT NULL            AND f.HFinalType IN (2,24,54,59,60)            AND o.OpEntry>h.H2Entry THEN NULL           WHEN f.HFinalID IS NOT NULL AND o.OpID IS NOT NULL            AND f.HFinalType IN (3,57,58)            AND o.OpEntry>h.H2Entry AND o.OpEntry<f.HFinalEntry THEN NULL           WHEN f.HFinalID IS NOT NULL AND f.HFinalType IN (3,57,58)            AND o.OpID IS NOT NULL AND o.OpEntry>=h.H2Entry THEN o.OpID           WHEN f.HFinalID IS NOT NULL AND f.HFinalType IN (2,24,54,59,60)            AND (o.OpID IS NULL OR o.OpEntry<h.H2Entry) THEN f.HFinalID           WHEN f.HFinalID IS NULL AND o.OpID IS NOT NULL THEN o.OpID           WHEN f.HFinalID IS NOT NULL AND f.HFinalType IN (3,57,58)            AND (o.OpID IS NULL OR o.OpEntry<h.H2Entry) THEN f.HFinalID           ELSE NULL         END AS EffectiveActionID,         CASE WHEN f.HitDepthLimit=1 THEN 'REVIEW_DEPTH'           WHEN p.Action24ID IS NOT NULL            AND (f.HFinalID IS NULL OR p.Entry24>f.HFinalEntry)            AND (o.OpID IS NULL OR o.OpEntry<p.Entry24)            AND NOT EXISTS            (SELECT 1 FROM Housing.BuildingAction ex WHERE ex.buildingDetailsID_FK=p.BuildingID              AND ex.IdaraId_FK=p.IdaraID AND ex.residentInfoID_FK=p.Resident24ID AND ex.buildingActionActive=1              AND ex.buildingActionTypeID_FK IN (3,57,58) AND ex.entryDate>p.Entry24)           THEN 'GRACE_24'           WHEN f.HFinalID IS NOT NULL AND o.OpID IS NOT NULL            AND o.OpEntry=f.HFinalEntry THEN 'REVIEW_TIE'           WHEN f.HFinalID IS NOT NULL AND o.OpID IS NOT NULL            AND f.HFinalType IN (2,24,54,59,60) AND o.OpEntry>h.H2Entry            THEN 'REVIEW_OCCUPANCY_OPERATION'           WHEN f.HFinalID IS NOT NULL AND o.OpID IS NOT NULL            AND f.HFinalType IN (3,57,58) AND o.OpEntry>h.H2Entry            AND o.OpEntry<f.HFinalEntry THEN 'REVIEW_EXIT_OPERATION'           WHEN f.HFinalID IS NOT NULL AND f.HFinalType IN (3,57,58)            AND o.OpID IS NOT NULL AND o.OpEntry>=h.H2Entry THEN 'OPERATION_AFTER_EXIT'           WHEN f.HFinalID IS NOT NULL AND f.HFinalType IN (2,24,54,59,60)            AND (o.OpID IS NULL OR o.OpEntry<h.H2Entry) THEN 'OCCUPIED'           WHEN f.HFinalID IS NULL AND o.OpID IS NOT NULL THEN 'OPERATION'           WHEN f.HFinalID IS NOT NULL AND f.HFinalType IN (3,57,58)            AND (o.OpID IS NULL OR o.OpEntry<h.H2Entry) THEN 'EXIT'           WHEN NOT EXISTS(SELECT 1 FROM Housing.BuildingAction aa WHERE aa.buildingDetailsID_FK=b.buildingDetailsID AND aa.IdaraId_FK=b.BuildingIdaraID AND aa.buildingActionActive=1) THEN 'NO_ACTION'           ELSE 'REVIEW_UNRESOLVED' END AS DecisionClass  FROM EligibleBuildings b  LEFT JOIN Housing2 h ON h.BuildingID=b.buildingDetailsID AND h.IdaraID=b.BuildingIdaraID  LEFT JOIN HousingFinal f ON f.BuildingID=b.buildingDetailsID AND f.IdaraID=b.BuildingIdaraID  LEFT JOIN LastOp o ON o.BuildingID=b.buildingDetailsID AND o.IdaraID=b.BuildingIdaraID  LEFT JOIN LastGrace p ON p.BuildingID=b.buildingDetailsID AND p.IdaraID=b.BuildingIdaraID ) SELECT b.buildingDetailsID,b.buildingDetailsNo,b.buildingDetailsRooms,b.buildingLevelsCount,        b.buildingDetailsArea,b.buildingDetailsCoordinates,b.buildingTypeID_FK,        b.buildingTypeName_A,b.buildingUtilityTypeID_FK,b.buildingUtilityTypeName_A,        b.militaryLocationID_FK,b.militaryLocationName_A,b.militaryAreaCityName_A,        b.militaryAreaName_A,b.buildingClassID_FK,b.buildingClassName_A,        b.buildingDetailsTel_1,b.buildingDetailsTel_2,b.buildingDetailsRemark,        b.buildingDetailsStartDate,b.buildingDetailsEndDate,b.buildingDetailsActive,        b.buildingUtilityIsRent,b.BuildingIdaraID,b.BuildingIdaraName,b.BuildingTypeIdaraID,        b.BuildingUtilityTypeIdaraID,b.MilitaryLocationIdaraID,b.BuildingClassIdaraID,        ea.buildingActionID AS LastActionID,        ea.buildingActionTypeID_FK AS LastActionTypeID,        bat.buildingActionTypeName_A AS LastActionTypeName,        bat.buildingActionTypeBuildingAlias AS LastActionTypeBuildingAlias,        ea.entryDate AS LastActionEntryDate,        ea.buildingActionNote AS LastActionNote FROM EligibleBuildings b JOIN Decision d ON d.BuildingID=b.buildingDetailsID AND d.IdaraID=b.BuildingIdaraID /* Fallback is self-contained: never reference the production view (no circular dependency).    The 3/58 guard and the scoped 47->2 adjustment are identical to the    existing production definition. Fallback is needed ONLY for unresolved    candidate decisions. A real house with no action still returns NULL. */ OUTER APPLY (     SELECT TOP (1) a.buildingActionID,a.buildingActionTypeID_FK,            a.residentInfoID_FK,a.entryDate     FROM Housing.BuildingAction a     WHERE d.EffectiveActionID IS NULL       AND a.buildingDetailsID_FK=b.buildingDetailsID       AND a.buildingActionActive=1       AND NOT       (         a.buildingActionTypeID_FK IN (3,58)         AND EXISTS         (             SELECT 1             FROM Housing.fn_BuildingAction_ChainToRoot(a.buildingActionID) ancestor             JOIN Housing.BuildingAction s57               ON s57.buildingActionID=ancestor.buildingActionID              AND s57.buildingActionTypeID_FK=57              AND s57.buildingActionActive=1              AND s57.buildingDetailsID_FK=b.buildingDetailsID              AND s57.IdaraId_FK=b.BuildingIdaraID             JOIN Housing.BuildingAction opRoot               ON opRoot.buildingDetailsID_FK=b.buildingDetailsID              AND opRoot.IdaraId_FK=b.BuildingIdaraID              AND opRoot.buildingActionActive=1              AND opRoot.buildingActionParentID IS NULL              AND opRoot.residentInfoID_FK IS NULL              AND opRoot.buildingActionTypeID_FK IN (4,5,62)              AND opRoot.buildingActionID>s57.buildingActionID              AND opRoot.buildingActionID<a.buildingActionID         )       )     ORDER BY a.buildingActionID DESC ) fbRaw OUTER APPLY (     SELECT TOP (1) a.buildingActionID,a.residentInfoID_FK     FROM Housing.BuildingAction a     WHERE d.EffectiveActionID IS NULL       AND fbRaw.buildingActionTypeID_FK=47       AND a.buildingActionParentID=fbRaw.buildingActionID       AND a.buildingActionTypeID_FK=2 AND a.buildingActionActive=1       AND a.buildingDetailsID_FK=b.buildingDetailsID       AND a.IdaraId_FK=b.BuildingIdaraID       AND a.residentInfoID_FK=fbRaw.residentInfoID_FK     ORDER BY a.buildingActionID DESC ) fbHousing2 OUTER APPLY (     SELECT TOP (1) a.buildingActionID,a.buildingActionTypeID_FK,a.entryDate     FROM Housing.BuildingAction a     WHERE d.EffectiveActionID IS NULL       AND fbHousing2.buildingActionID IS NOT NULL       AND a.buildingActionParentID=fbHousing2.buildingActionID       AND a.buildingActionTypeID_FK IN (3,24,57)       AND a.buildingActionActive=1       AND a.buildingDetailsID_FK=b.buildingDetailsID       AND a.IdaraId_FK=b.BuildingIdaraID       AND a.residentInfoID_FK=fbHousing2.residentInfoID_FK     ORDER BY CASE a.buildingActionTypeID_FK WHEN 3 THEN 1 WHEN 57 THEN 2 WHEN 24 THEN 3 ELSE 4 END,              a.buildingActionID DESC ) fbExit OUTER APPLY (     SELECT TOP (1) r.buildingActionID     FROM Housing.BuildingAction r     WHERE d.EffectiveActionID IS NULL       AND fbExit.buildingActionTypeID_FK IN (3,57)       AND r.buildingDetailsID_FK=b.buildingDetailsID       AND r.IdaraId_FK=b.BuildingIdaraID AND r.buildingActionActive=1       AND r.buildingActionParentID IS NULL AND r.residentInfoID_FK IS NULL       AND r.buildingActionTypeID_FK IN (4,5,62)       AND r.entryDate>fbExit.entryDate       AND NOT EXISTS       (           SELECT 1 FROM Housing.BuildingAction child           WHERE child.buildingActionParentID=r.buildingActionID             AND child.buildingActionActive=1             AND child.buildingDetailsID_FK=b.buildingDetailsID             AND child.IdaraId_FK=b.BuildingIdaraID       )     ORDER BY r.entryDate DESC,r.buildingActionID DESC ) fbOp LEFT JOIN CurrentOperationalAllocation coa
   ON coa.BuildingID=b.buildingDetailsID
  AND coa.IdaraID=b.BuildingIdaraID
LEFT JOIN Housing.BuildingAction ea ON ea.buildingActionID=COALESCE
     (coa.CurrentAllocationActionID,d.EffectiveActionID,fbOp.buildingActionID,
      fbExit.buildingActionID,fbHousing2.buildingActionID,fbRaw.buildingActionID) LEFT JOIN Housing.BuildingActionType bat ON bat.buildingActionTypeID=ea.buildingActionTypeID_FK;