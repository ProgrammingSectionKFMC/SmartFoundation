CREATE VIEW dbo.View_getDSDForUsers
AS
SELECT        ud.distributorID_FK, ud.userID_FK, asd.DSDName_A, d.DSDID_FK
FROM            dbo.UserDistributor AS ud INNER JOIN
                         dbo.Distributor AS d ON d.distributorID = ud.distributorID_FK INNER JOIN
                             (SELECT        dt.distributorID, dt.DSDID_FK, de.deptID, NULL AS secID, NULL AS divID, N'قسم' + ' ' + de.deptName_A AS DSDName_A
                                FROM            dbo.Distributor AS dt LEFT OUTER JOIN
                                                         dbo.DeptSecDiv AS dsd ON dsd.DSDID = dt.DSDID_FK LEFT OUTER JOIN
                                                         dbo.Department AS de ON dsd.deptID_FK = de.deptID
                                WHERE        (1 = 1) AND (dt.distributorType_FK = 1) AND (de.deptActive = 1) AND (de.deptEndDate IS NULL) AND (de.idaraID_FK = 1) AND (dsd.secID_FK IS NULL) AND (dsd.divID_FK IS NULL)
                                UNION
                                SELECT        dt.distributorID, dt.DSDID_FK, de.deptID, se.secID, NULL AS divID, N'قسم' + ' ' + de.deptName_A + ' ' + N'فرع' + ' ' + se.secName_A AS DSDName_A
                                FROM            dbo.Distributor AS dt LEFT OUTER JOIN
                                                         dbo.DeptSecDiv AS dsd ON dsd.DSDID = dt.DSDID_FK LEFT OUTER JOIN
                                                         dbo.Department AS de ON dsd.deptID_FK = de.deptID LEFT OUTER JOIN
                                                         dbo.Section AS se ON se.secID = dsd.secID_FK
                                WHERE        (1 = 1) AND (dt.distributorType_FK = 1) AND (de.deptActive = 1) AND (de.deptEndDate IS NULL) AND (de.idaraID_FK = 1) AND (se.secActive = 1) AND (se.secEndDate IS NULL) AND (dsd.divID_FK IS NULL)
                                UNION
                                SELECT        dt.distributorID, dt.DSDID_FK, de.deptID, se.secID, NULL AS divID, N'قسم' + ' ' + de.deptName_A + ' ' + N'فرع' + ' ' + se.secName_A + ' ' + N'شعبة' + dv.divName_A AS DSDName_A
                                FROM            dbo.Distributor AS dt LEFT OUTER JOIN
                                                         dbo.DeptSecDiv AS dsd ON dsd.DSDID = dt.DSDID_FK LEFT OUTER JOIN
                                                         dbo.Department AS de ON dsd.deptID_FK = de.deptID LEFT OUTER JOIN
                                                         dbo.Section AS se ON se.secID = dsd.secID_FK LEFT OUTER JOIN
                                                         dbo.Divison AS dv ON dv.divID = dsd.divID_FK
                                WHERE        (1 = 1) AND (dt.distributorType_FK = 1) AND (de.deptActive = 1) AND (de.deptEndDate IS NULL) AND (de.idaraID_FK = 1) AND (se.secActive = 1) AND (se.secEndDate IS NULL) AND (dv.divActive = 1) AND 
                                                         (dv.divEndDate IS NULL)) AS asd ON asd.distributorID = ud.distributorID_FK
WHERE        EXISTS
                             (SELECT        dt.distributorID
                                FROM            dbo.Distributor AS dt LEFT OUTER JOIN
                                                         dbo.DeptSecDiv AS dsd ON dsd.DSDID = dt.DSDID_FK LEFT OUTER JOIN
                                                         dbo.Department AS de ON dsd.deptID_FK = de.deptID
                                WHERE        (1 = 1) AND (dt.distributorType_FK = 1) AND (de.deptActive = 1) AND (de.deptEndDate IS NULL) AND (de.idaraID_FK = 1) AND (dsd.secID_FK IS NULL) AND (dsd.divID_FK IS NULL)
                                UNION
                                SELECT        dt.distributorID
                                FROM            dbo.Distributor AS dt LEFT OUTER JOIN
                                                         dbo.DeptSecDiv AS dsd ON dsd.DSDID = dt.DSDID_FK LEFT OUTER JOIN
                                                         dbo.Department AS de ON dsd.deptID_FK = de.deptID LEFT OUTER JOIN
                                                         dbo.Section AS se ON se.secID = dsd.secID_FK
                                WHERE        (1 = 1) AND (dt.distributorType_FK = 1) AND (de.deptActive = 1) AND (de.deptEndDate IS NULL) AND (de.idaraID_FK = 1) AND (se.secActive = 1) AND (se.secEndDate IS NULL) AND (dsd.divID_FK IS NULL)
                                UNION
                                SELECT        dt.distributorID
                                FROM            dbo.Distributor AS dt LEFT OUTER JOIN
                                                         dbo.DeptSecDiv AS dsd ON dsd.DSDID = dt.DSDID_FK LEFT OUTER JOIN
                                                         dbo.Department AS de ON dsd.deptID_FK = de.deptID LEFT OUTER JOIN
                                                         dbo.Section AS se ON se.secID = dsd.secID_FK LEFT OUTER JOIN
                                                         dbo.Divison AS dv ON dv.divID = dsd.divID_FK
                                WHERE        (1 = 1) AND (dt.distributorType_FK = 1) AND (de.deptActive = 1) AND (de.deptEndDate IS NULL) AND (de.idaraID_FK = 1) AND (se.secActive = 1) AND (se.secEndDate IS NULL) AND (dv.divActive = 1) AND 
                                                         (dv.divEndDate IS NULL)) AND (d.distributorType_FK = 1) AND (ud.UDEndDate IS NULL) AND (ud.UDActive = 1)

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
         Begin Table = "ud"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 211
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "d"
            Begin Extent = 
               Top = 6
               Left = 249
               Bottom = 136
               Right = 453
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "asd"
            Begin Extent = 
               Top = 6
               Left = 491
               Bottom = 136
               Right = 661
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'View_getDSDForUsers';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'View_getDSDForUsers';

