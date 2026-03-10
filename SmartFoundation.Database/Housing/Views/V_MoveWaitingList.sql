


CREATE VIEW [Housing].[V_MoveWaitingList]
AS
SELECT        TOP (100) PERCENT b.buildingActionID AS ActionID, ri.NationalID NationalID, rd.generalNo_FK AS GeneralNo, b.buildingActionDecisionNo AS ActionDecisionNo, b.buildingActionDecisionDate AS ActionDecisionDate, 
                         b.buildingActionDate AS ActionDate, ri.residentInfoID residentInfoID, ri.FullName_A AS fullname, b.buildingActionNote AS ActionNote, b.IdaraId_FK AS IdaraId, i.idaraLongName_A AS ActionIdaraName, i.entryData AS MainActionEntryData, 
                         i.entryDate AS MainActionEntryDate, b.buildingActionExtraInt1 AS ToIdaraID, toidara.idaraLongName_A AS Toidaraname, x.buildingActionID AS LastActionID, x.buildingActionTypeID_FK AS LastActionTypeID, 
                         x.IdaraId_FK AS LastActionIdaraID, it.idaraLongName_A AS LastActionIdaraName, bt1.buildingActionTypeName_A AS LastActionTypeName, x.buildingActionNote AS LastActionNote, x.entryDate AS LastActionEntryDate, 
                         x.entryData AS LastActionEntryData, CASE WHEN x.buildingActionTypeID_FK IS NULL 
                         THEN N'تحت الاجراء' WHEN x.buildingActionTypeID_FK = 33 THEN N'مقبول' WHEN x.buildingActionTypeID_FK = 34 THEN N'مرفوض' WHEN x.buildingActionTypeID_FK = 35 THEN N'ملغى' END AS ActionStatus,
                             (SELECT        COUNT(*) AS Expr1
                               FROM            Housing.V_WaitingList AS w
                               WHERE        (residentInfoID = b.residentInfoID_FK) AND (WaitingClassID IN (1, 2, 3, 4, 11))) AS WaitingListCount
FROM            Housing.BuildingAction AS b LEFT OUTER JOIN
                         Housing.BuildingAction AS x ON x.buildingActionParentID = b.buildingActionID LEFT OUTER JOIN
                         Housing.BuildingActionType AS bt ON b.buildingActionTypeID_FK = bt.buildingActionTypeID LEFT OUTER JOIN
                         Housing.BuildingActionType AS bt1 ON x.buildingActionTypeID_FK = bt1.buildingActionTypeID LEFT OUTER JOIN
                         Housing.V_GetFullResidentDetails AS ri ON ri.residentInfoID = b.residentInfoID_FK LEFT OUTER JOIN
                         Housing.ResidentDetails AS rd ON ri.residentInfoID = rd.residentInfoID_FK and rd.residentDetailsActive = 1 LEFT OUTER JOIN
                         dbo.Idara AS i ON b.IdaraId_FK = i.idaraID LEFT OUTER JOIN
                         dbo.Idara AS it ON x.IdaraId_FK = it.idaraID LEFT OUTER JOIN
                         dbo.Idara AS toidara ON b.buildingActionExtraInt1 = toidara.idaraID
WHERE        (b.buildingActionTypeID_FK = 32) AND (b.buildingActionActive = 1)

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
         Begin Table = "b"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 299
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "x"
            Begin Extent = 
               Top = 6
               Left = 337
               Bottom = 136
               Right = 598
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "bt"
            Begin Extent = 
               Top = 6
               Left = 636
               Bottom = 136
               Right = 890
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "bt1"
            Begin Extent = 
               Top = 6
               Left = 928
               Bottom = 136
               Right = 1182
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ri"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 268
               Right = 280
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "rd"
            Begin Extent = 
               Top = 6
               Left = 1220
               Bottom = 136
               Right = 1434
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "i"
            Begin Extent = 
               Top = 138
               Left = 318
               Bottom = 268
               Right = 506
            End
            DisplayFlags = 280
            TopColumn = 0
         En', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_MoveWaitingList';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'd
         Begin Table = "it"
            Begin Extent = 
               Top = 138
               Left = 544
               Bottom = 268
               Right = 732
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "toidara"
            Begin Extent = 
               Top = 138
               Left = 770
               Bottom = 268
               Right = 958
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
      Begin ColumnWidths = 25
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
', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_MoveWaitingList';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_MoveWaitingList';

