
-- STAGING ONLY: Creates V5, leaves production V_GetGeneralListForBuilding unchanged.
-- Direct base-table seeks for ResidentTree, FinalRanked and correlated NOT EXISTS.
-- Same schema and selection rules as V3; performance/parity must be measured on SQL Server.
CREATE   VIEW [Housing].[V_GetGeneralListForBuilding] AS WITH EligibleBuildings AS (  SELECT bd.buildingDetailsID,bd.buildingDetailsNo,bd.buildingDetailsRooms,         bd.buildingLevelsCount,bd.buildingDetailsArea,bd.buildingDetailsCoordinates,         bd.buildingTypeID_FK,bt.buildingTypeName_A,         bd.buildingUtilityTypeID_FK,bu.buildingUtilityTypeName_A,         bd.militaryLocationID_FK,m.militaryLocationName_A,         mac.militaryAreaCityName_A,ma.militaryAreaName_A,         bd.buildingClassID_FK,bc.buildingClassName_A,         bd.buildingDetailsTel_1,bd.buildingDetailsTel_2,bd.buildingDetailsRemark,         bd.buildingDetailsStartDate,bd.buildingDetailsEndDate,bd.buildingDetailsActive,         bu.buildingUtilityIsRent,bd.IdaraId_FK AS BuildingIdaraID,         i.idaraLongName_A AS BuildingIdaraName,         bt.IdaraId_FK AS BuildingTypeIdaraID,         bu.IdaraId_FK AS BuildingUtilityTypeIdaraID,         m.IdaraId_FK AS MilitaryLocationIdaraID,         bc.IdaraId_FK AS BuildingClassIdaraID  FROM Housing.BuildingDetails bd  JOIN Housing.BuildingType bt ON bt.buildingTypeID=bd.buildingTypeID_FK  JOIN Housing.BuildingUtilityType bu ON bu.buildingUtilityTypeID=bd.buildingUtilityTypeID_FK  JOIN Housing.MilitaryLocation m ON m.militaryLocationID=bd.militaryLocationID_FK  JOIN Housing.MilitaryAreaCity mac ON mac.militaryAreaCityID=m.militaryAreaCityID_FK  JOIN Housing.MilitaryArea ma ON ma.militaryAreaID=mac.militaryAreaID_FK  JOIN Housing.BuildingClass bc ON bc.buildingClassID=bd.buildingClassID_FK  JOIN dbo.Idara i ON i.IdaraId=bd.IdaraId_FK  WHERE bd.buildingDetailsActive=1 AND bt.buildingTypeActive=1    AND bu.buildingUtilityTypeActive=1 AND m.militaryLocationActive=1    AND bc.buildingClassActive=1 AND mac.militaryAreaCityActive=1    AND ma.militaryAreaIsActive=1    AND bd.buildingDetailsStartDate IS NOT NULL    AND bu.buildingUtilityTypeStartDate IS NOT NULL    AND (bd.buildingDetailsEndDate IS NULL OR bd.buildingDetailsEndDate>GETDATE())    AND (bu.buildingUtilityTypeEndDate IS NULL OR bu.buildingUtilityTypeEndDate>GETDATE()) ),
Actions AS (  SELECT a.buildingActionID AS ActionID,a.buildingActionTypeID_FK AS ActionType,         a.buildingActionParentID AS ParentID,a.buildingDetailsID_FK AS BuildingID,         a.IdaraId_FK AS IdaraID,a.residentInfoID_FK AS ResidentID,a.entryDate AS EntryDate  FROM Housing.BuildingAction a  JOIN EligibleBuildings b ON b.buildingDetailsID=a.buildingDetailsID_FK   AND b.BuildingIdaraID=a.IdaraId_FK  WHERE a.buildingActionActive=1 ),
HousingRanked AS (  SELECT a.*,  ROW_NUMBER() OVER(PARTITION BY BuildingID,IdaraID                    ORDER BY EntryDate DESC,ActionID DESC) AS rn  FROM Actions a WHERE ActionType=2 AND ResidentID IS NOT NULL ),
Housing2 AS (  SELECT BuildingID,IdaraID,ActionID AS H2ID,ResidentID,EntryDate AS H2Entry  FROM HousingRanked WHERE rn=1 ),
ResidentTree AS (  SELECT h.BuildingID,h.IdaraID,h.ResidentID,h.H2ID,         h.H2ID AS ActionID,CAST(0 AS int) AS Depth  FROM Housing2 h  UNION ALL  SELECT t.BuildingID,t.IdaraID,t.ResidentID,t.H2ID,         c.buildingActionID,t.Depth+1  FROM ResidentTree t  JOIN Housing.BuildingAction c ON c.buildingActionParentID=t.ActionID      AND c.buildingDetailsID_FK=t.BuildingID AND c.IdaraId_FK=t.IdaraID      AND c.residentInfoID_FK=t.ResidentID AND c.buildingActionActive=1  WHERE t.Depth<32 AND c.buildingActionID<>t.ActionID ),
FinalRanked AS (  SELECT t.BuildingID,t.IdaraID,t.H2ID,t.ActionID,t.Depth,         a.buildingActionTypeID_FK,a.entryDate,         ROW_NUMBER() OVER(PARTITION BY t.BuildingID,t.IdaraID           ORDER BY t.Depth DESC,              CASE a.buildingActionTypeID_FK WHEN 3 THEN 0 WHEN 58 THEN 1 WHEN 57 THEN 2                   WHEN 24 THEN 3 ELSE 4 END,              a.entryDate DESC,a.buildingActionID DESC) AS rn,         MAX(CASE WHEN t.Depth=32 THEN 1 ELSE 0 END)           OVER(PARTITION BY t.BuildingID,t.IdaraID) AS HitDepthLimit  FROM ResidentTree t JOIN Housing.BuildingAction a ON a.buildingActionID=t.ActionID AND a.buildingActionActive=1 ),
HousingFinal AS (  SELECT BuildingID,IdaraID,H2ID,ActionID AS HFinalID,         buildingActionTypeID_FK AS HFinalType,
entryDate AS HFinalEntry,HitDepthLimit  FROM FinalRanked WHERE rn=1 ),
OpRanked AS (  SELECT a.*,  ROW_NUMBER() OVER(PARTITION BY BuildingID,IdaraID             ORDER BY EntryDate DESC,ActionID DESC) AS rn  FROM Actions a WHERE a.ResidentID IS NULL    AND a.ActionType IN (4,5,9,10,11,12,13,14,15,17,29,62) ),
LastOp AS (  SELECT BuildingID,IdaraID,ActionID AS OpID,ActionType AS OpType,         EntryDate AS OpEntry FROM OpRanked WHERE rn=1 ),
GraceRanked AS (  SELECT a.*,  ROW_NUMBER() OVER(PARTITION BY BuildingID,IdaraID          ORDER BY EntryDate DESC,ActionID DESC) AS rn  FROM Actions a WHERE ActionType=24 AND ResidentID IS NOT NULL ),
LastGrace AS (  SELECT BuildingID,IdaraID,ActionID AS Action24ID,         ResidentID AS Resident24ID,EntryDate AS Entry24  FROM GraceRanked WHERE rn=1 ),
Decision AS (  SELECT b.buildingDetailsID AS BuildingID,b.BuildingIdaraID AS IdaraID,         CASE           WHEN f.HitDepthLimit=1 THEN NULL           WHEN p.Action24ID IS NOT NULL            AND (f.HFinalID IS NULL OR p.Entry24>f.HFinalEntry)            AND (o.OpID IS NULL OR o.OpEntry<p.Entry24)            AND NOT EXISTS            (              SELECT 1 FROM Housing.BuildingAction ex              WHERE ex.buildingDetailsID_FK=p.BuildingID AND ex.IdaraId_FK=p.IdaraID                AND ex.residentInfoID_FK=p.Resident24ID AND ex.buildingActionActive=1 AND ex.buildingActionTypeID_FK IN (3,57,58)                AND ex.entryDate>p.Entry24            ) THEN p.Action24ID           WHEN f.HFinalID IS NOT NULL AND o.OpID IS NOT NULL            AND o.OpEntry=f.HFinalEntry THEN NULL           WHEN f.HFinalID IS NOT NULL AND o.OpID IS NOT NULL            AND f.HFinalType IN (2,24,54,59,60)            AND o.OpEntry>h.H2Entry THEN NULL           WHEN f.HFinalID IS NOT NULL AND o.OpID IS NOT NULL            AND f.HFinalType IN (3,57,58)            AND o.OpEntry>h.H2Entry AND o.OpEntry<f.HFinalEntry THEN NULL           WHEN f.HFinalID IS NOT NULL AND f.HFinalType IN (3,57,58)            AND o.OpID IS NOT NULL AND o.OpEntry>=h.H2Entry THEN o.OpID           WHEN f.HFinalID IS NOT NULL AND f.HFinalType IN (2,24,54,59,60)            AND (o.OpID IS NULL OR o.OpEntry<h.H2Entry) THEN f.HFinalID           WHEN f.HFinalID IS NULL AND o.OpID IS NOT NULL THEN o.OpID           WHEN f.HFinalID IS NOT NULL AND f.HFinalType IN (3,57,58)            AND (o.OpID IS NULL OR o.OpEntry<h.H2Entry) THEN f.HFinalID           ELSE NULL         END AS EffectiveActionID,         CASE WHEN f.HitDepthLimit=1 THEN 'REVIEW_DEPTH'           WHEN p.Action24ID IS NOT NULL            AND (f.HFinalID IS NULL OR p.Entry24>f.HFinalEntry)            AND (o.OpID IS NULL OR o.OpEntry<p.Entry24)            AND NOT EXISTS            (SELECT 1 FROM Housing.BuildingAction ex WHERE ex.buildingDetailsID_FK=p.BuildingID              AND ex.IdaraId_FK=p.IdaraID AND ex.residentInfoID_FK=p.Resident24ID AND ex.buildingActionActive=1              AND ex.buildingActionTypeID_FK IN (3,57,58) AND ex.entryDate>p.Entry24)           THEN 'GRACE_24'           WHEN f.HFinalID IS NOT NULL AND o.OpID IS NOT NULL            AND o.OpEntry=f.HFinalEntry THEN 'REVIEW_TIE'           WHEN f.HFinalID IS NOT NULL AND o.OpID IS NOT NULL            AND f.HFinalType IN (2,24,54,59,60) AND o.OpEntry>h.H2Entry            THEN 'REVIEW_OCCUPANCY_OPERATION'           WHEN f.HFinalID IS NOT NULL AND o.OpID IS NOT NULL            AND f.HFinalType IN (3,57,58) AND o.OpEntry>h.H2Entry            AND o.OpEntry<f.HFinalEntry THEN 'REVIEW_EXIT_OPERATION'           WHEN f.HFinalID IS NOT NULL AND f.HFinalType IN (3,57,58)            AND o.OpID IS NOT NULL AND o.OpEntry>=h.H2Entry THEN 'OPERATION_AFTER_EXIT'           WHEN f.HFinalID IS NOT NULL AND f.HFinalType IN (2,24,54,59,60)            AND (o.OpID IS NULL OR o.OpEntry<h.H2Entry) THEN 'OCCUPIED'           WHEN f.HFinalID IS NULL AND o.OpID IS NOT NULL THEN 'OPERATION'           WHEN f.HFinalID IS NOT NULL AND f.HFinalType IN (3,57,58)            AND (o.OpID IS NULL OR o.OpEntry<h.H2Entry) THEN 'EXIT'           WHEN NOT EXISTS(SELECT 1 FROM Housing.BuildingAction aa WHERE aa.buildingDetailsID_FK=b.buildingDetailsID AND aa.IdaraId_FK=b.BuildingIdaraID AND aa.buildingActionActive=1) THEN 'NO_ACTION'           ELSE 'REVIEW_UNRESOLVED' END AS DecisionClass  FROM EligibleBuildings b  LEFT JOIN Housing2 h ON h.BuildingID=b.buildingDetailsID AND h.IdaraID=b.BuildingIdaraID  LEFT JOIN HousingFinal f ON f.BuildingID=b.buildingDetailsID AND f.IdaraID=b.BuildingIdaraID  LEFT JOIN LastOp o ON o.BuildingID=b.buildingDetailsID AND o.IdaraID=b.BuildingIdaraID  LEFT JOIN LastGrace p ON p.BuildingID=b.buildingDetailsID AND p.IdaraID=b.BuildingIdaraID ) SELECT b.buildingDetailsID,b.buildingDetailsNo,b.buildingDetailsRooms,b.buildingLevelsCount,        b.buildingDetailsArea,b.buildingDetailsCoordinates,b.buildingTypeID_FK,        b.buildingTypeName_A,b.buildingUtilityTypeID_FK,b.buildingUtilityTypeName_A,        b.militaryLocationID_FK,b.militaryLocationName_A,b.militaryAreaCityName_A,        b.militaryAreaName_A,b.buildingClassID_FK,b.buildingClassName_A,        b.buildingDetailsTel_1,b.buildingDetailsTel_2,b.buildingDetailsRemark,        b.buildingDetailsStartDate,b.buildingDetailsEndDate,b.buildingDetailsActive,        b.buildingUtilityIsRent,b.BuildingIdaraID,b.BuildingIdaraName,b.BuildingTypeIdaraID,        b.BuildingUtilityTypeIdaraID,b.MilitaryLocationIdaraID,b.BuildingClassIdaraID,        ea.buildingActionID AS LastActionID,        ea.buildingActionTypeID_FK AS LastActionTypeID,        bat.buildingActionTypeName_A AS LastActionTypeName,        bat.buildingActionTypeBuildingAlias AS LastActionTypeBuildingAlias,        ea.entryDate AS LastActionEntryDate,        ea.buildingActionNote AS LastActionNote FROM EligibleBuildings b JOIN Decision d ON d.BuildingID=b.buildingDetailsID AND d.IdaraID=b.BuildingIdaraID /* Fallback is self-contained: never reference the production view (no circular dependency).    The 3/58 guard and the scoped 47->2 adjustment are identical to the    existing production definition. Fallback is needed ONLY for unresolved    candidate decisions. A real house with no action still returns NULL. */ OUTER APPLY (     SELECT TOP (1) a.buildingActionID,a.buildingActionTypeID_FK,            a.residentInfoID_FK,a.entryDate     FROM Housing.BuildingAction a     WHERE d.EffectiveActionID IS NULL       AND a.buildingDetailsID_FK=b.buildingDetailsID       AND a.buildingActionActive=1       AND NOT       (         a.buildingActionTypeID_FK IN (3,58)         AND EXISTS         (             SELECT 1             FROM Housing.fn_BuildingAction_ChainToRoot(a.buildingActionID) ancestor             JOIN Housing.BuildingAction s57               ON s57.buildingActionID=ancestor.buildingActionID              AND s57.buildingActionTypeID_FK=57              AND s57.buildingActionActive=1              AND s57.buildingDetailsID_FK=b.buildingDetailsID              AND s57.IdaraId_FK=b.BuildingIdaraID             JOIN Housing.BuildingAction opRoot               ON opRoot.buildingDetailsID_FK=b.buildingDetailsID              AND opRoot.IdaraId_FK=b.BuildingIdaraID              AND opRoot.buildingActionActive=1              AND opRoot.buildingActionParentID IS NULL              AND opRoot.residentInfoID_FK IS NULL              AND opRoot.buildingActionTypeID_FK IN (4,5,62)              AND opRoot.buildingActionID>s57.buildingActionID              AND opRoot.buildingActionID<a.buildingActionID         )       )     ORDER BY a.buildingActionID DESC ) fbRaw OUTER APPLY (     SELECT TOP (1) a.buildingActionID,a.residentInfoID_FK     FROM Housing.BuildingAction a     WHERE d.EffectiveActionID IS NULL       AND fbRaw.buildingActionTypeID_FK=47       AND a.buildingActionParentID=fbRaw.buildingActionID       AND a.buildingActionTypeID_FK=2 AND a.buildingActionActive=1       AND a.buildingDetailsID_FK=b.buildingDetailsID       AND a.IdaraId_FK=b.BuildingIdaraID       AND a.residentInfoID_FK=fbRaw.residentInfoID_FK     ORDER BY a.buildingActionID DESC ) fbHousing2 OUTER APPLY (     SELECT TOP (1) a.buildingActionID,a.buildingActionTypeID_FK,a.entryDate     FROM Housing.BuildingAction a     WHERE d.EffectiveActionID IS NULL       AND fbHousing2.buildingActionID IS NOT NULL       AND a.buildingActionParentID=fbHousing2.buildingActionID       AND a.buildingActionTypeID_FK IN (3,24,57)       AND a.buildingActionActive=1       AND a.buildingDetailsID_FK=b.buildingDetailsID       AND a.IdaraId_FK=b.BuildingIdaraID       AND a.residentInfoID_FK=fbHousing2.residentInfoID_FK     ORDER BY CASE a.buildingActionTypeID_FK WHEN 3 THEN 1 WHEN 57 THEN 2 WHEN 24 THEN 3 ELSE 4 END,              a.buildingActionID DESC ) fbExit OUTER APPLY (     SELECT TOP (1) r.buildingActionID     FROM Housing.BuildingAction r     WHERE d.EffectiveActionID IS NULL       AND fbExit.buildingActionTypeID_FK IN (3,57)       AND r.buildingDetailsID_FK=b.buildingDetailsID       AND r.IdaraId_FK=b.BuildingIdaraID AND r.buildingActionActive=1       AND r.buildingActionParentID IS NULL AND r.residentInfoID_FK IS NULL       AND r.buildingActionTypeID_FK IN (4,5,62)       AND r.entryDate>fbExit.entryDate       AND NOT EXISTS       (           SELECT 1 FROM Housing.BuildingAction child           WHERE child.buildingActionParentID=r.buildingActionID             AND child.buildingActionActive=1             AND child.buildingDetailsID_FK=b.buildingDetailsID             AND child.IdaraId_FK=b.BuildingIdaraID       )     ORDER BY r.entryDate DESC,r.buildingActionID DESC ) fbOp LEFT JOIN Housing.BuildingAction ea ON ea.buildingActionID=COALESCE     (d.EffectiveActionID,fbOp.buildingActionID,fbExit.buildingActionID,      fbHousing2.buildingActionID,fbRaw.buildingActionID) LEFT JOIN Housing.BuildingActionType bat ON bat.buildingActionTypeID=ea.buildingActionTypeID_FK;

GO

EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 32
         Width = 284
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetGeneralListForBuilding';


GO

EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane11', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 32
         Width = 284
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetGeneralListForBuilding';


GO

EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetGeneralListForBuilding';


GO

EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount1', @value = 1, @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetGeneralListForBuilding';


GO

