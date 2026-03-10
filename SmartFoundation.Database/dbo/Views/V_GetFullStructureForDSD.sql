CREATE VIEW dbo.V_GetFullStructureForDSD
AS
SELECT        dsd.DSDID, o.OrganizationID, o.OrganizationName, I.IdaraID, I.IdaraName, d.DepartmentID, d.DepartmentName, s.SectionID, s.SectionName, v.DivisonID, v.DivisonName, CASE WHEN (v.DivisonID IS NULL) AND 
                         (s.SectionID IS NULL) AND (d .DepartmentID IS NULL) AND (i.IdaraID IS NULL) AND (o.OrganizationID IS NOT NULL) THEN 1 WHEN (v.DivisonID IS NULL) AND (s.SectionID IS NULL) AND (d .DepartmentID IS NULL) AND 
                         (i.IdaraID IS NOT NULL) AND (o.OrganizationID IS NOT NULL) THEN 2 WHEN (v.DivisonID IS NULL) AND (s.SectionID IS NULL) AND (d .DepartmentID IS NOT NULL) AND (i.IdaraID IS NOT NULL) AND 
                         (o.OrganizationID IS NOT NULL) THEN 3 WHEN (v.DivisonID IS NULL) AND (s.SectionID IS NOT NULL) AND (d .DepartmentID IS NOT NULL) AND (i.IdaraID IS NOT NULL) AND (o.OrganizationID IS NOT NULL) 
                         THEN 4 WHEN (v.DivisonID IS NOT NULL) AND (s.SectionID IS NOT NULL) AND (d .DepartmentID IS NOT NULL) AND (i.IdaraID IS NOT NULL) AND (o.OrganizationID IS NOT NULL) THEN 5 END AS DSDLevel
FROM            dbo.DeptSecDiv AS dsd LEFT OUTER JOIN
                         dbo.V_GetListOrganization AS o ON dsd.OrganizationID_FK = o.OrganizationID LEFT OUTER JOIN
                         dbo.V_GetListIdara AS I ON dsd.idaraID_FK = I.IdaraID LEFT OUTER JOIN
                         dbo.V_GetListDepartment AS d ON dsd.deptID_FK = d.DepartmentID LEFT OUTER JOIN
                         dbo.V_GetListSection AS s ON dsd.secID_FK = s.SectionID LEFT OUTER JOIN
                         dbo.V_GetListDivison AS v ON dsd.divID_FK = v.DivisonID
WHERE        (1 = 1) AND (d.deptActive = 1) AND (d.deptStartDate IS NOT NULL) AND (CAST(d.deptStartDate AS date) <= CAST(GETDATE() AS date)) AND (CAST(d.deptEndDate AS date) > CAST(GETDATE() AS date)) OR
                         (1 = 1) AND (d.deptActive = 1) AND (d.deptStartDate IS NOT NULL) AND (CAST(d.deptStartDate AS date) <= CAST(GETDATE() AS date)) AND (d.deptEndDate IS NULL) OR
                         (s.secActive = 1) AND (s.secStartDate IS NOT NULL) AND (CAST(s.secStartDate AS date) <= CAST(GETDATE() AS date)) AND (CAST(s.secEndDate AS date) > CAST(GETDATE() AS date)) OR
                         (s.secActive = 1) AND (s.secStartDate IS NOT NULL) AND (CAST(s.secStartDate AS date) <= CAST(GETDATE() AS date)) AND (s.secEndDate IS NULL) OR
                         (v.divActive = 1) AND (v.divStartDate IS NOT NULL) AND (CAST(v.divStartDate AS date) <= CAST(GETDATE() AS date)) AND (CAST(v.divEndDate AS date) > CAST(GETDATE() AS date)) OR
                         (v.divActive = 1) AND (v.divStartDate IS NOT NULL) AND (CAST(v.divStartDate AS date) <= CAST(GETDATE() AS date)) AND (v.divEndDate IS NULL) OR
                         (dsd.idaraID_FK IS NOT NULL) AND (dsd.deptID_FK IS NULL) AND (dsd.secID_FK IS NULL) AND (dsd.divID_FK IS NULL) OR
                         (dsd.idaraID_FK IS NULL) AND (dsd.deptID_FK IS NULL) AND (dsd.secID_FK IS NULL) AND (dsd.divID_FK IS NULL) AND (dsd.OrganizationID_FK IS NOT NULL)

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
         Begin Table = "dsd"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 208
            End
            DisplayFlags = 280
            TopColumn = 3
         End
         Begin Table = "d"
            Begin Extent = 
               Top = 6
               Left = 246
               Bottom = 136
               Right = 430
            End
            DisplayFlags = 280
            TopColumn = 2
         End
         Begin Table = "s"
            Begin Extent = 
               Top = 6
               Left = 468
               Bottom = 136
               Right = 638
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "v"
            Begin Extent = 
               Top = 6
               Left = 676
               Bottom = 136
               Right = 846
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "o"
            Begin Extent = 
               Top = 6
               Left = 884
               Bottom = 136
               Right = 1101
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "I"
            Begin Extent = 
               Top = 6
               Left = 1139
               Bottom = 136
               Right = 1323
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
      Begin ColumnWidths = 14
         Width = 284
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 15', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'V_GetFullStructureForDSD';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'00
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
      Begin ColumnWidths = 16
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
         Or = 1350
         Or = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'V_GetFullStructureForDSD';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'V_GetFullStructureForDSD';

