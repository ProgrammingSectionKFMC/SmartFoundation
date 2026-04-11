






CREATE VIEW [Housing].[V_WaitingList]
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
    WHERE b.buildingActionTypeID_FK in(1,7)
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
    la.entryData AS LastActionEntryData,
    la.ExtendReasonTypeID_FK as LastActionExtendReasonTypeID,
    rd.IdaraId_FK ResidentIdaraID
    
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
WHERE b.buildingActionTypeID_FK in(1,7)
  AND b.buildingActionActive = 1;

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
         Begin Table = "g"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 256
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "w"
            Begin Extent = 
               Top = 6
               Left = 294
               Bottom = 85
               Right = 464
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 18
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
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 2145
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
', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_WaitingList';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_WaitingList';

