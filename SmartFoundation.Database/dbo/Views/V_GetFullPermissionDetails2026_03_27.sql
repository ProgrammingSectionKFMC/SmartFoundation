
CREATE VIEW [dbo].[V_GetFullPermissionDetails2026_03_27]
AS
SELECT        pr.permissionID, dd.distributorID,m.menuID, p.permissionTypeID, dd.distributorName_A, p.permissionTypeName_A,m.menuName_A, pr.DistributorPermissionTypeID_FK, CASE WHEN pr.UsersID_FK IS NOT NULL 
                         THEN ud.FullName WHEN pr.RoleID_FK IS NOT NULL THEN r.roleName_A WHEN pr.DSDID_FK IS NOT NULL THEN CASE WHEN dsd.DivisonName IS NOT NULL THEN ISNULL(dsd.IdaraName, '') 
                         + '-' + ISNULL(dsd.DepartmentName, '') + '-' + ISNULL(dsd.SectionName, '') + '-' + ISNULL(dsd.DivisonName, '') WHEN dsd.SectionName IS NOT NULL THEN ISNULL(dsd.IdaraName, '') + '-' + ISNULL(dsd.DepartmentName, '') 
                         + '-' + ISNULL(dsd.SectionName, '') WHEN dsd.DepartmentName IS NOT NULL THEN ISNULL(dsd.IdaraName, '') + '-' + ISNULL(dsd.DepartmentName, '') ELSE ISNULL(dsd.IdaraName, '') END WHEN pr.IdaraID_FK IS NOT NULL 
                         THEN da.idaraLongName_A WHEN pr.distributorID_FK IS NOT NULL THEN ds.distributorName_A ELSE NULL END AS PermissionHolderName, CASE WHEN pr.UsersID_FK IS NOT NULL 
                         THEN ud.usersID WHEN pr.RoleID_FK IS NOT NULL THEN r.roleID WHEN pr.DSDID_FK IS NOT NULL THEN DSDID WHEN pr.IdaraID_FK IS NOT NULL THEN da.idaraID WHEN pr.distributorID_FK IS NOT NULL 
                         THEN ds.distributorID ELSE NULL END AS PermissionHolderID, CASE WHEN pr.UsersID_FK IS NOT NULL THEN N'User' WHEN pr.RoleID_FK IS NOT NULL THEN N'Role' WHEN pr.DSDID_FK IS NOT NULL 
                         THEN N'DSD' WHEN pr.IdaraID_FK IS NOT NULL THEN N'Idara' WHEN pr.distributorID_FK IS NOT NULL THEN N'Distributor' ELSE N'Unknown' END AS PermissionHolderType, CASE WHEN pr.UsersID_FK IS NOT NULL 
                         THEN N'1' WHEN pr.RoleID_FK IS NOT NULL THEN N'3' WHEN pr.DSDID_FK IS NOT NULL THEN N'5' WHEN pr.IdaraID_FK IS NOT NULL THEN N'4' WHEN pr.distributorID_FK IS NOT NULL 
                         THEN N'2' ELSE N'0' END AS PermissionHolderTypeID, pr.UsersID_FK, ud.FullName AS UserFullName, pr.RoleID_FK, r.roleName_A AS RoleName, pr.distributorID_FK, ds.distributorName_A AS DistributorName, 
                         pr.DSDID_FK, CASE WHEN pr.DSDID_FK IS NOT NULL THEN CASE WHEN dsd.DivisonName IS NOT NULL THEN isnull(dsd.IdaraName, '') + '-' + isnull(dsd.DepartmentName, '') + '-' + isnull(dsd.SectionName, '') 
                         + '-' + isnull(dsd.DivisonName, '') WHEN dsd.DivisonName IS NULL AND dsd.SectionName IS NOT NULL THEN isnull(dsd.IdaraName, '') + '-' + isnull(dsd.DepartmentName, '') + '-' + isnull(dsd.SectionName, '') 
                         WHEN dsd.DivisonName IS NULL AND dsd.SectionName IS NULL AND dsd.DepartmentName IS NOT NULL THEN isnull(dsd.IdaraName, '') + '-' + isnull(dsd.DepartmentName, '') WHEN dsd.DivisonName IS NULL AND 
                         dsd.SectionName IS NULL AND dsd.DepartmentName IS NULL AND dsd.IdaraName IS NOT NULL THEN isnull(dsd.IdaraName, '') END ELSE NULL END AS DSDName, pr.IdaraID_FK, da.idaraLongName_A AS IdaraName, 
                         pr.permissionStartDate, pr.permissionEndDate, pr.permissionNote, pr.InIdaraID, pr.entryData, pr.entryDate, pr.hostName, pr.permissionActive, d.distributorPermissionTypeActive, dd.distributorActive, p.permissionTypeActive, 
                         ud.userActive
FROM            dbo.DistributorPermissionType AS d INNER JOIN
                         dbo.PermissionType AS p ON d.permissionTypeID_FK = p.permissionTypeID INNER JOIN
                         dbo.Distributor AS dd ON d.DistributorID_FK = dd.distributorID INNER JOIN
                         dbo.Permission AS pr ON pr.DistributorPermissionTypeID_FK = d.distributorPermissionTypeID LEFT OUTER JOIN
                         dbo.V_GetFullSystemUsersDetails AS ud ON pr.UsersID_FK = ud.usersID LEFT OUTER JOIN
                         dbo.Role AS r ON pr.RoleID_FK = r.roleID LEFT OUTER JOIN
                         dbo.Distributor AS ds ON pr.distributorID_FK = ds.distributorID LEFT OUTER JOIN
                         dbo.V_GetFullStructureForDSD AS dsd ON pr.DSDID_FK = dsd.DSDID LEFT OUTER JOIN
                         dbo.Idara AS da ON pr.IdaraID_FK = da.idaraID LEft JOIN
                         dbo.MenuDistributor md on d.DistributorID_FK = md.distributorID_FK LEft Join
                         dbo.Menu m on md.menuID_FK = m.menuID
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'V_GetFullPermissionDetails2026_03_27';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'
         Begin Table = "dsd"
            Begin Extent = 
               Top = 138
               Left = 569
               Bottom = 268
               Right = 758
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "da"
            Begin Extent = 
               Top = 138
               Left = 796
               Bottom = 268
               Right = 984
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'V_GetFullPermissionDetails2026_03_27';


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
         Begin Table = "d"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 314
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "p"
            Begin Extent = 
               Top = 6
               Left = 352
               Bottom = 136
               Right = 570
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "dd"
            Begin Extent = 
               Top = 6
               Left = 608
               Bottom = 136
               Right = 812
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "pr"
            Begin Extent = 
               Top = 6
               Left = 850
               Bottom = 136
               Right = 1108
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ud"
            Begin Extent = 
               Top = 6
               Left = 1146
               Bottom = 136
               Right = 1333
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "r"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 268
               Right = 289
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ds"
            Begin Extent = 
               Top = 138
               Left = 327
               Bottom = 268
               Right = 531
            End
            DisplayFlags = 280
            TopColumn = 0
         End', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'V_GetFullPermissionDetails2026_03_27';

