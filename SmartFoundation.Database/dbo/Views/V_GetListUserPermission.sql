CREATE VIEW dbo.V_GetListUserPermission
AS
SELECT        p.UsersID_FK AS userID, m.menuName_A, m.menuName_E, pt.permissionTypeName_A, pt.permissionTypeName_E, m.menuID, md.menuDistributorID, d.distributorID, dpt.distributorPermissionTypeID, p.permissionID, 
                         p.DistributorPermissionTypeID_FK, pt.permissionTypeID, p.permissionStartDate, p.permissionEndDate, p.permissionActive, p.entryDate, p.entryData, p.hostName, dpt.distributorPermissionTypeStartDate, 
                         dpt.distributorPermissionTypeEndDate, dpt.distributorPermissionTypeActive, p.permissionNote, p.RoleID_FK, p.distributorID_FK, p.DSDID_FK, p.IdaraID_FK, DE.deptName_A, SE.secName_A, DI.divName_A, DI.divID, SE.secID, 
                         DE.deptID
FROM            dbo.Menu AS m INNER JOIN
                         dbo.MenuDistributor AS md ON md.menuID_FK = m.menuID INNER JOIN
                         dbo.Distributor AS d ON md.distributorID_FK = d.distributorID INNER JOIN
                         dbo.DistributorPermissionType AS dpt ON d.distributorID = dpt.DistributorID_FK INNER JOIN
                         dbo.Permission AS p ON dpt.distributorPermissionTypeID = p.DistributorPermissionTypeID_FK INNER JOIN
                         dbo.PermissionType AS pt ON pt.permissionTypeID = dpt.permissionTypeID_FK LEFT OUTER JOIN
                         dbo.DeptSecDiv AS DSD ON DSD.DSDID = p.DSDID_FK LEFT OUTER JOIN
                         dbo.Department AS DE ON DSD.deptID_FK = DE.deptID LEFT OUTER JOIN
                         dbo.Section AS SE ON DSD.secID_FK = SE.secID LEFT OUTER JOIN
                         dbo.Divison AS DI ON DSD.divID_FK = DI.divID
WHERE        (m.menuActive = 1) AND (md.menuDistributorActive = 1) AND (d.distributorActive = 1) AND (dpt.distributorPermissionTypeActive = 1) AND (p.permissionActive = 1) AND (pt.permissionTypeActive = 1) AND 
                         (dpt.distributorPermissionTypeStartDate IS NOT NULL) AND (CAST(dpt.distributorPermissionTypeStartDate AS date) <= CAST(GETDATE() AS date)) AND (p.permissionStartDate IS NOT NULL) AND 
                         (CAST(p.permissionEndDate AS date) >= CAST(GETDATE() AS date)) AND (dpt.distributorPermissionTypeEndDate IS NULL) OR
                         (m.menuActive = 1) AND (md.menuDistributorActive = 1) AND (d.distributorActive = 1) AND (dpt.distributorPermissionTypeActive = 1) AND (p.permissionActive = 1) AND (pt.permissionTypeActive = 1) AND 
                         (dpt.distributorPermissionTypeStartDate IS NOT NULL) AND (CAST(dpt.distributorPermissionTypeStartDate AS date) <= CAST(GETDATE() AS date)) AND (p.permissionStartDate IS NOT NULL) AND 
                         (CAST(p.permissionEndDate AS date) >= CAST(GETDATE() AS date)) AND (CAST(dpt.distributorPermissionTypeEndDate AS date) >= CAST(GETDATE() AS date)) OR
                         (m.menuActive = 1) AND (md.menuDistributorActive = 1) AND (d.distributorActive = 1) AND (dpt.distributorPermissionTypeActive = 1) AND (p.permissionActive = 1) AND (pt.permissionTypeActive = 1) AND 
                         (dpt.distributorPermissionTypeStartDate IS NOT NULL) AND (CAST(dpt.distributorPermissionTypeStartDate AS date) <= CAST(GETDATE() AS date)) AND (p.permissionStartDate IS NOT NULL) AND 
                         (dpt.distributorPermissionTypeEndDate IS NULL) AND (p.permissionEndDate IS NULL) OR
                         (m.menuActive = 1) AND (md.menuDistributorActive = 1) AND (d.distributorActive = 1) AND (dpt.distributorPermissionTypeActive = 1) AND (p.permissionActive = 1) AND (pt.permissionTypeActive = 1) AND 
                         (dpt.distributorPermissionTypeStartDate IS NOT NULL) AND (CAST(dpt.distributorPermissionTypeStartDate AS date) <= CAST(GETDATE() AS date)) AND (p.permissionStartDate IS NOT NULL) AND 
                         (CAST(dpt.distributorPermissionTypeEndDate AS date) >= CAST(GETDATE() AS date)) AND (p.permissionEndDate IS NULL)

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
         Begin Table = "m"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 221
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "md"
            Begin Extent = 
               Top = 6
               Left = 259
               Bottom = 136
               Right = 468
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "d"
            Begin Extent = 
               Top = 6
               Left = 506
               Bottom = 136
               Right = 710
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "dpt"
            Begin Extent = 
               Top = 6
               Left = 748
               Bottom = 136
               Right = 1024
            End
            DisplayFlags = 280
            TopColumn = 3
         End
         Begin Table = "p"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 268
               Right = 296
            End
            DisplayFlags = 280
            TopColumn = 3
         End
         Begin Table = "pt"
            Begin Extent = 
               Top = 6
               Left = 1062
               Bottom = 136
               Right = 1280
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DSD"
            Begin Extent = 
               Top = 138
               Left = 334
               Bottom = 268
               Right = 520
            End
            DisplayFlags = 280
            TopColumn = 0
         E', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'V_GetListUserPermission';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'nd
         Begin Table = "DE"
            Begin Extent = 
               Top = 138
               Left = 558
               Bottom = 268
               Right = 735
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "SE"
            Begin Extent = 
               Top = 138
               Left = 773
               Bottom = 268
               Right = 943
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DI"
            Begin Extent = 
               Top = 138
               Left = 981
               Bottom = 268
               Right = 1151
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
      Begin ColumnWidths = 54
         Width = 284
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1665
         Width = 1500
         Width = 2430
         Width = 1875
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1980
         Width = 1725
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
      Begin ColumnWidths = 12
         Column = 3015
         Alias = 2520
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
         Or = 1350
      End
   End
End
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'V_GetListUserPermission';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'V_GetListUserPermission';

