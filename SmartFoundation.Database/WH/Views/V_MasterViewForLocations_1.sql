CREATE   VIEW [WH].[V_MasterViewForLocations]
AS
SELECT
    n.warehousePartID AS locationID,
    n.warehousePartTypeID_FK AS locationTypeID_FK,
    nt.warehousePartTypeName_A AS locationTypeName_A,
    nt.warehousePartTypeName_E AS locationTypeName_E,
    n.warehousePartName AS locationName,
    n.warehousePartName_A AS locationName_A,
    n.warehousePartParentID_FK AS locationParentID_FK,
    p1.warehousePartTypeID_FK AS parentTypeID_FK,
    p1t.warehousePartTypeName_A AS parentTypeName_A,
    p1t.warehousePartTypeName_E AS parentTypeName_E,
    p1.warehousePartName AS parentName,
    p1.warehousePartName_A AS parentName_A,
    n.warehousePartActive AS locationActive,
    n.warehousePartOldName AS locationOldName,
    n.warehousePartOldParentID_FK AS locationOldParentID_FK,
    n.warehousePartIsChecked AS locationIsChecked,
    n.hostName AS locationHostName,
    n.entryDate AS locationEntryDate,
    n.entryData AS locationEntryData,
    n.IdaraID_FK AS locationIdaraID,

    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 1 THEN n.warehousePartID END, CASE WHEN p1.warehousePartTypeID_FK = 1 THEN p1.warehousePartID END, CASE WHEN p2.warehousePartTypeID_FK = 1 THEN p2.warehousePartID END, CASE WHEN p3.warehousePartTypeID_FK = 1 THEN p3.warehousePartID END, CASE WHEN p4.warehousePartTypeID_FK = 1 THEN p4.warehousePartID END, CASE WHEN p5.warehousePartTypeID_FK = 1 THEN p5.warehousePartID END, CASE WHEN p6.warehousePartTypeID_FK = 1 THEN p6.warehousePartID END, CASE WHEN p7.warehousePartTypeID_FK = 1 THEN p7.warehousePartID END) AS organizationID,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 1 THEN n.warehousePartName END, CASE WHEN p1.warehousePartTypeID_FK = 1 THEN p1.warehousePartName END, CASE WHEN p2.warehousePartTypeID_FK = 1 THEN p2.warehousePartName END, CASE WHEN p3.warehousePartTypeID_FK = 1 THEN p3.warehousePartName END, CASE WHEN p4.warehousePartTypeID_FK = 1 THEN p4.warehousePartName END, CASE WHEN p5.warehousePartTypeID_FK = 1 THEN p5.warehousePartName END, CASE WHEN p6.warehousePartTypeID_FK = 1 THEN p6.warehousePartName END, CASE WHEN p7.warehousePartTypeID_FK = 1 THEN p7.warehousePartName END) AS organizationName,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 1 THEN n.warehousePartName_A END, CASE WHEN p1.warehousePartTypeID_FK = 1 THEN p1.warehousePartName_A END, CASE WHEN p2.warehousePartTypeID_FK = 1 THEN p2.warehousePartName_A END, CASE WHEN p3.warehousePartTypeID_FK = 1 THEN p3.warehousePartName_A END, CASE WHEN p4.warehousePartTypeID_FK = 1 THEN p4.warehousePartName_A END, CASE WHEN p5.warehousePartTypeID_FK = 1 THEN p5.warehousePartName_A END, CASE WHEN p6.warehousePartTypeID_FK = 1 THEN p6.warehousePartName_A END, CASE WHEN p7.warehousePartTypeID_FK = 1 THEN p7.warehousePartName_A END) AS organizationName_A,

    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 2 THEN n.warehousePartID END, CASE WHEN p1.warehousePartTypeID_FK = 2 THEN p1.warehousePartID END, CASE WHEN p2.warehousePartTypeID_FK = 2 THEN p2.warehousePartID END, CASE WHEN p3.warehousePartTypeID_FK = 2 THEN p3.warehousePartID END, CASE WHEN p4.warehousePartTypeID_FK = 2 THEN p4.warehousePartID END, CASE WHEN p5.warehousePartTypeID_FK = 2 THEN p5.warehousePartID END, CASE WHEN p6.warehousePartTypeID_FK = 2 THEN p6.warehousePartID END, CASE WHEN p7.warehousePartTypeID_FK = 2 THEN p7.warehousePartID END) AS idaraPartID,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 2 THEN n.warehousePartName END, CASE WHEN p1.warehousePartTypeID_FK = 2 THEN p1.warehousePartName END, CASE WHEN p2.warehousePartTypeID_FK = 2 THEN p2.warehousePartName END, CASE WHEN p3.warehousePartTypeID_FK = 2 THEN p3.warehousePartName END, CASE WHEN p4.warehousePartTypeID_FK = 2 THEN p4.warehousePartName END, CASE WHEN p5.warehousePartTypeID_FK = 2 THEN p5.warehousePartName END, CASE WHEN p6.warehousePartTypeID_FK = 2 THEN p6.warehousePartName END, CASE WHEN p7.warehousePartTypeID_FK = 2 THEN p7.warehousePartName END) AS idaraPartName,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 2 THEN n.warehousePartName_A END, CASE WHEN p1.warehousePartTypeID_FK = 2 THEN p1.warehousePartName_A END, CASE WHEN p2.warehousePartTypeID_FK = 2 THEN p2.warehousePartName_A END, CASE WHEN p3.warehousePartTypeID_FK = 2 THEN p3.warehousePartName_A END, CASE WHEN p4.warehousePartTypeID_FK = 2 THEN p4.warehousePartName_A END, CASE WHEN p5.warehousePartTypeID_FK = 2 THEN p5.warehousePartName_A END, CASE WHEN p6.warehousePartTypeID_FK = 2 THEN p6.warehousePartName_A END, CASE WHEN p7.warehousePartTypeID_FK = 2 THEN p7.warehousePartName_A END) AS idaraPartName_A,

    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 3 THEN n.warehousePartID END, CASE WHEN p1.warehousePartTypeID_FK = 3 THEN p1.warehousePartID END, CASE WHEN p2.warehousePartTypeID_FK = 3 THEN p2.warehousePartID END, CASE WHEN p3.warehousePartTypeID_FK = 3 THEN p3.warehousePartID END, CASE WHEN p4.warehousePartTypeID_FK = 3 THEN p4.warehousePartID END, CASE WHEN p5.warehousePartTypeID_FK = 3 THEN p5.warehousePartID END, CASE WHEN p6.warehousePartTypeID_FK = 3 THEN p6.warehousePartID END, CASE WHEN p7.warehousePartTypeID_FK = 3 THEN p7.warehousePartID END) AS warehouseZoneID,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 3 THEN n.warehousePartName END, CASE WHEN p1.warehousePartTypeID_FK = 3 THEN p1.warehousePartName END, CASE WHEN p2.warehousePartTypeID_FK = 3 THEN p2.warehousePartName END, CASE WHEN p3.warehousePartTypeID_FK = 3 THEN p3.warehousePartName END, CASE WHEN p4.warehousePartTypeID_FK = 3 THEN p4.warehousePartName END, CASE WHEN p5.warehousePartTypeID_FK = 3 THEN p5.warehousePartName END, CASE WHEN p6.warehousePartTypeID_FK = 3 THEN p6.warehousePartName END, CASE WHEN p7.warehousePartTypeID_FK = 3 THEN p7.warehousePartName END) AS warehouseZoneName,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 3 THEN n.warehousePartName_A END, CASE WHEN p1.warehousePartTypeID_FK = 3 THEN p1.warehousePartName_A END, CASE WHEN p2.warehousePartTypeID_FK = 3 THEN p2.warehousePartName_A END, CASE WHEN p3.warehousePartTypeID_FK = 3 THEN p3.warehousePartName_A END, CASE WHEN p4.warehousePartTypeID_FK = 3 THEN p4.warehousePartName_A END, CASE WHEN p5.warehousePartTypeID_FK = 3 THEN p5.warehousePartName_A END, CASE WHEN p6.warehousePartTypeID_FK = 3 THEN p6.warehousePartName_A END, CASE WHEN p7.warehousePartTypeID_FK = 3 THEN p7.warehousePartName_A END) AS warehouseZoneName_A,

    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 4 THEN n.warehousePartID END, CASE WHEN p1.warehousePartTypeID_FK = 4 THEN p1.warehousePartID END, CASE WHEN p2.warehousePartTypeID_FK = 4 THEN p2.warehousePartID END, CASE WHEN p3.warehousePartTypeID_FK = 4 THEN p3.warehousePartID END, CASE WHEN p4.warehousePartTypeID_FK = 4 THEN p4.warehousePartID END, CASE WHEN p5.warehousePartTypeID_FK = 4 THEN p5.warehousePartID END, CASE WHEN p6.warehousePartTypeID_FK = 4 THEN p6.warehousePartID END, CASE WHEN p7.warehousePartTypeID_FK = 4 THEN p7.warehousePartID END) AS warehouseID,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 4 THEN n.warehousePartName END, CASE WHEN p1.warehousePartTypeID_FK = 4 THEN p1.warehousePartName END, CASE WHEN p2.warehousePartTypeID_FK = 4 THEN p2.warehousePartName END, CASE WHEN p3.warehousePartTypeID_FK = 4 THEN p3.warehousePartName END, CASE WHEN p4.warehousePartTypeID_FK = 4 THEN p4.warehousePartName END, CASE WHEN p5.warehousePartTypeID_FK = 4 THEN p5.warehousePartName END, CASE WHEN p6.warehousePartTypeID_FK = 4 THEN p6.warehousePartName END, CASE WHEN p7.warehousePartTypeID_FK = 4 THEN p7.warehousePartName END) AS warehouseName,

    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 5 THEN n.warehousePartID END, CASE WHEN p1.warehousePartTypeID_FK = 5 THEN p1.warehousePartID END, CASE WHEN p2.warehousePartTypeID_FK = 5 THEN p2.warehousePartID END, CASE WHEN p3.warehousePartTypeID_FK = 5 THEN p3.warehousePartID END, CASE WHEN p4.warehousePartTypeID_FK = 5 THEN p4.warehousePartID END, CASE WHEN p5.warehousePartTypeID_FK = 5 THEN p5.warehousePartID END, CASE WHEN p6.warehousePartTypeID_FK = 5 THEN p6.warehousePartID END, CASE WHEN p7.warehousePartTypeID_FK = 5 THEN p7.warehousePartID END) AS buildingID,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 5 THEN n.warehousePartName END, CASE WHEN p1.warehousePartTypeID_FK = 5 THEN p1.warehousePartName END, CASE WHEN p2.warehousePartTypeID_FK = 5 THEN p2.warehousePartName END, CASE WHEN p3.warehousePartTypeID_FK = 5 THEN p3.warehousePartName END, CASE WHEN p4.warehousePartTypeID_FK = 5 THEN p4.warehousePartName END, CASE WHEN p5.warehousePartTypeID_FK = 5 THEN p5.warehousePartName END, CASE WHEN p6.warehousePartTypeID_FK = 5 THEN p6.warehousePartName END, CASE WHEN p7.warehousePartTypeID_FK = 5 THEN p7.warehousePartName END) AS buildingName,

    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 6 THEN n.warehousePartID END, CASE WHEN p1.warehousePartTypeID_FK = 6 THEN p1.warehousePartID END, CASE WHEN p2.warehousePartTypeID_FK = 6 THEN p2.warehousePartID END, CASE WHEN p3.warehousePartTypeID_FK = 6 THEN p3.warehousePartID END, CASE WHEN p4.warehousePartTypeID_FK = 6 THEN p4.warehousePartID END, CASE WHEN p5.warehousePartTypeID_FK = 6 THEN p5.warehousePartID END, CASE WHEN p6.warehousePartTypeID_FK = 6 THEN p6.warehousePartID END, CASE WHEN p7.warehousePartTypeID_FK = 6 THEN p7.warehousePartID END) AS shelfID,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 6 THEN n.warehousePartName END, CASE WHEN p1.warehousePartTypeID_FK = 6 THEN p1.warehousePartName END, CASE WHEN p2.warehousePartTypeID_FK = 6 THEN p2.warehousePartName END, CASE WHEN p3.warehousePartTypeID_FK = 6 THEN p3.warehousePartName END, CASE WHEN p4.warehousePartTypeID_FK = 6 THEN p4.warehousePartName END, CASE WHEN p5.warehousePartTypeID_FK = 6 THEN p5.warehousePartName END, CASE WHEN p6.warehousePartTypeID_FK = 6 THEN p6.warehousePartName END, CASE WHEN p7.warehousePartTypeID_FK = 6 THEN p7.warehousePartName END) AS shelfName,

    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 7 THEN n.warehousePartID END, CASE WHEN p1.warehousePartTypeID_FK = 7 THEN p1.warehousePartID END, CASE WHEN p2.warehousePartTypeID_FK = 7 THEN p2.warehousePartID END, CASE WHEN p3.warehousePartTypeID_FK = 7 THEN p3.warehousePartID END, CASE WHEN p4.warehousePartTypeID_FK = 7 THEN p4.warehousePartID END, CASE WHEN p5.warehousePartTypeID_FK = 7 THEN p5.warehousePartID END, CASE WHEN p6.warehousePartTypeID_FK = 7 THEN p6.warehousePartID END, CASE WHEN p7.warehousePartTypeID_FK = 7 THEN p7.warehousePartID END) AS columnID,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 7 THEN n.warehousePartName END, CASE WHEN p1.warehousePartTypeID_FK = 7 THEN p1.warehousePartName END, CASE WHEN p2.warehousePartTypeID_FK = 7 THEN p2.warehousePartName END, CASE WHEN p3.warehousePartTypeID_FK = 7 THEN p3.warehousePartName END, CASE WHEN p4.warehousePartTypeID_FK = 7 THEN p4.warehousePartName END, CASE WHEN p5.warehousePartTypeID_FK = 7 THEN p5.warehousePartName END, CASE WHEN p6.warehousePartTypeID_FK = 7 THEN p6.warehousePartName END, CASE WHEN p7.warehousePartTypeID_FK = 7 THEN p7.warehousePartName END) AS columnName,

    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 8 THEN n.warehousePartID END, CASE WHEN p1.warehousePartTypeID_FK = 8 THEN p1.warehousePartID END, CASE WHEN p2.warehousePartTypeID_FK = 8 THEN p2.warehousePartID END, CASE WHEN p3.warehousePartTypeID_FK = 8 THEN p3.warehousePartID END, CASE WHEN p4.warehousePartTypeID_FK = 8 THEN p4.warehousePartID END, CASE WHEN p5.warehousePartTypeID_FK = 8 THEN p5.warehousePartID END, CASE WHEN p6.warehousePartTypeID_FK = 8 THEN p6.warehousePartID END, CASE WHEN p7.warehousePartTypeID_FK = 8 THEN p7.warehousePartID END) AS rowID,
    COALESCE(CASE WHEN n.warehousePartTypeID_FK = 8 THEN n.warehousePartName END, CASE WHEN p1.warehousePartTypeID_FK = 8 THEN p1.warehousePartName END, CASE WHEN p2.warehousePartTypeID_FK = 8 THEN p2.warehousePartName END, CASE WHEN p3.warehousePartTypeID_FK = 8 THEN p3.warehousePartName END, CASE WHEN p4.warehousePartTypeID_FK = 8 THEN p4.warehousePartName END, CASE WHEN p5.warehousePartTypeID_FK = 8 THEN p5.warehousePartName END, CASE WHEN p6.warehousePartTypeID_FK = 8 THEN p6.warehousePartName END, CASE WHEN p7.warehousePartTypeID_FK = 8 THEN p7.warehousePartName END) AS rowName
FROM WH.WarehousePart n
LEFT JOIN WH.WarehousePartType nt
    ON nt.warehousePartTypeID = n.warehousePartTypeID_FK
LEFT JOIN WH.WarehousePart p1
    ON p1.warehousePartID = n.warehousePartParentID_FK
LEFT JOIN WH.WarehousePartType p1t
    ON p1t.warehousePartTypeID = p1.warehousePartTypeID_FK
LEFT JOIN WH.WarehousePart p2
    ON p2.warehousePartID = p1.warehousePartParentID_FK
LEFT JOIN WH.WarehousePart p3
    ON p3.warehousePartID = p2.warehousePartParentID_FK
LEFT JOIN WH.WarehousePart p4
    ON p4.warehousePartID = p3.warehousePartParentID_FK
LEFT JOIN WH.WarehousePart p5
    ON p5.warehousePartID = p4.warehousePartParentID_FK
LEFT JOIN WH.WarehousePart p6
    ON p6.warehousePartID = p5.warehousePartParentID_FK
LEFT JOIN WH.WarehousePart p7
    ON p7.warehousePartID = p6.warehousePartParentID_FK;
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

