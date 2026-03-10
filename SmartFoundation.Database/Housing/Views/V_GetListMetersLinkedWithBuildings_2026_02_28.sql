CREATE VIEW Housing.[V_GetListMetersLinkedWithBuildings_2026_02_28]
AS
SELECT        m.meterID, m.meterTypeID_FK, m.meterNo, m.meterName_A, m.meterName_E, m.meterDescription, mt.meterServiceTypeID_FK, mb.meterID_FK, mb.buildingDetailsID_FK, bd.buildingDetailsNo, bd.buildingUtilityTypeID_FK, 
                         msp.meterServicePrice, msp.meterServicePriceStartDate, msp.meterServicePriceEndDate, mt.meterTypeConversionFactor
FROM            Housing.MeterForBuilding AS mb INNER JOIN
                         Housing.BuildingDetails AS bd ON mb.buildingDetailsID_FK = bd.buildingDetailsID INNER JOIN
                         Housing.Meter AS m ON mb.meterID_FK = m.meterID INNER JOIN
                         Housing.MeterType AS mt ON m.meterTypeID_FK = mt.meterTypeID INNER JOIN
                         Housing.MeterServiceType AS mst ON mt.meterServiceTypeID_FK = mst.meterServiceTypeID INNER JOIN
                         Housing.BuildingUtilityType AS but ON bd.buildingUtilityTypeID_FK = but.buildingUtilityTypeID INNER JOIN
                         Housing.MeterServicePrice AS msp ON mt.meterTypeID = msp.meterTypeID_FK
WHERE        (1 = 1) AND (mb.meterForBuildingActive = 1) AND (mb.meterForBuildingStartDate IS NOT NULL) AND (mb.meterForBuildingEndDate IS NULL) AND (bd.buildingDetailsActive = 1) AND (bd.buildingDetailsStartDate IS NOT NULL) AND
                          (bd.buildingDetailsEndDate IS NULL) AND (m.meterActive = 1) AND (m.meterStartDate IS NOT NULL) AND (m.meterEndDate IS NULL) AND (mt.meterTypeActive = 1) AND (mt.meterTypeStartDate IS NOT NULL) AND 
                         (mt.meterTypeEndDate IS NULL) AND (mt.meterServiceTypeID_FK = 1) AND (but.buildingUtilityTypeActive = 1) AND (but.buildingUtilityTypeStartDate IS NOT NULL) AND (but.buildingUtilityTypeEndDate IS NULL) AND 
                         (mst.meterServiceTypeActive = 1) AND (mst.meterServiceTypeStartDate IS NOT NULL) AND (mst.meterServiceTypeEndDate IS NULL) AND (msp.meterServicePriceActive = 1) AND (msp.meterServicePriceStartDate IS NOT NULL)

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
         Begin Table = "mb"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 267
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "bd"
            Begin Extent = 
               Top = 6
               Left = 305
               Bottom = 136
               Right = 537
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "m"
            Begin Extent = 
               Top = 6
               Left = 575
               Bottom = 136
               Right = 755
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "mt"
            Begin Extent = 
               Top = 6
               Left = 793
               Bottom = 136
               Right = 1032
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "mst"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 268
               Right = 281
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "but"
            Begin Extent = 
               Top = 138
               Left = 319
               Bottom = 268
               Right = 569
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "msp"
            Begin Extent = 
               Top = 138
               Left = 607
               Bottom = 268
               Right = 838
            End
            DisplayFlags = 280
            TopColumn = 0
       ', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetListMetersLinkedWithBuildings_2026_02_28';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'  End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 10
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
', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetListMetersLinkedWithBuildings_2026_02_28';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetListMetersLinkedWithBuildings_2026_02_28';

