
CREATE VIEW [WH].[V_MasterViewForLocations]
AS
SELECT        w.warehouseID, w.warehouseTypeID_FK, w.warehouseName, w.warehouseParentID_FK, w.warehouseActive, w.warehouseOldName, w.warehouseIsChecked, w.warehouseHostName, w.warehouseEntryDate,w.IdaraID_FK as warehouseIdaraID,
                         w.warehouseEntryData, b.buildingID, b.buildingTypeID_FK, b.buildingName, b.buildingParentID_FK, b.buildingActive, b.buildingOldName, b.buildingIsChecked, b.buildingHostName, b.buildingEntryDate, b.buildingEntryData, b.IdaraID_FK as buildingIdaraID,
                         s.shelfID, s.shelfTypeID_FK, s.shelfName, s.shelfParentID_FK, s.shelfActive, s.shelfOldName, s.shelfIsChecked, s.shelfHostName, s.shelfEntryDate, s.shelfEntryData,s.IdaraID_FK  as shelfIdaraID, c.columnID, c.columnTypeID_FK, c.columnName, 
                         c.columnParentID_FK, c.columnActive, c.columnOldName, c.columnIsChecked, c.columnHostName, c.columnEntryDate, c.columnEntryData,c.IdaraID_FK as columnIdaraID, r.rowID, r.rowTypeID_FK, r.rowName, r.rowParentID_FK, r.rowActive, r.rowOldName, 
                         r.rowIsChecked, r.rowHostName, r.rowEntryDate, r.rowEntryData,r.IdaraID_FK rowIdaraID
FROM            WH.V_warehouse AS w LEFT OUTER JOIN
                         WH.V_building AS b ON w.warehouseID = b.buildingParentID_FK LEFT OUTER JOIN
                         WH.V_row AS r RIGHT OUTER JOIN
                         WH.V_column AS c ON r.rowParentID_FK = c.columnID RIGHT OUTER JOIN
                         WH.V_shelf AS s ON c.columnParentID_FK = s.shelfID ON b.buildingID = s.shelfParentID_FK
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'WH', @level1type = N'VIEW', @level1name = N'V_MasterViewForLocations';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N' = 720
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
', @level0type = N'SCHEMA', @level0name = N'WH', @level1type = N'VIEW', @level1name = N'V_MasterViewForLocations';


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
         Begin Table = "w"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 234
               Right = 247
            End
            DisplayFlags = 280
            TopColumn = 6
         End
         Begin Table = "s"
            Begin Extent = 
               Top = 13
               Left = 505
               Bottom = 238
               Right = 682
            End
            DisplayFlags = 280
            TopColumn = 6
         End
         Begin Table = "r"
            Begin Extent = 
               Top = 11
               Left = 944
               Bottom = 264
               Right = 1116
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "b"
            Begin Extent = 
               Top = 10
               Left = 272
               Bottom = 258
               Right = 468
            End
            DisplayFlags = 280
            TopColumn = 6
         End
         Begin Table = "c"
            Begin Extent = 
               Top = 12
               Left = 723
               Bottom = 256
               Right = 916
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
      Begin ColumnWidths = 9
         Width = 284
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
         Output', @level0type = N'SCHEMA', @level0name = N'WH', @level1type = N'VIEW', @level1name = N'V_MasterViewForLocations';

