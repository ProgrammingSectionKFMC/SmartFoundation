CREATE VIEW Housing.V_GetGeneralListForResident
AS
SELECT        ri.residentInfoID, rd.generalNo_FK, ri.NationalID, ISNULL(RTRIM(LTRIM(rd.firstName_A)), '') + ' ' + ISNULL(RTRIM(LTRIM(rd.secondName_A)), '') + ' ' + ISNULL(RTRIM(LTRIM(rd.thirdName_A)), '') 
                         + ' ' + ISNULL(RTRIM(LTRIM(rd.lastName_A)), '') AS FullNameA, ISNULL(RTRIM(LTRIM(rd.firstName_E)), '') + ' ' + ISNULL(RTRIM(LTRIM(rd.secondName_E)), '') + ' ' + ISNULL(RTRIM(LTRIM(rd.thirdName_E)), '') 
                         + ' ' + ISNULL(RTRIM(LTRIM(rd.lastName_E)), '') AS FullNameE, rd.rankID_FK AS RankID, r.rankNameA AS RankName, rd.militaryUnitID_FK AS MilitaryUnitID, mu.militaryUnitCode, mu.militaryUnitName_A AS militaryUnitName, 
                         rd.martialStatusID_FK AS MartialStatusID, ms.maritalStatusName_A AS MaritalStatus, rd.dependinceCounter AS Dependince, rd.nationalityID_FK AS NationalityID, n.nationalityName_A AS NationalityName, 
                         rd.genderID_FK AS GenderID, g.genderName_A AS GenderName, ci.residentcontactDetails AS mobile
FROM            Housing.ResidentInfo AS ri INNER JOIN
                         Housing.ResidentDetails AS rd ON ri.residentInfoID = rd.residentInfoID_FK AND rd.residentDetailsActive = 1 INNER JOIN
                         dbo.Rank AS r ON rd.rankID_FK = r.rankID AND r.rankActive = 1 INNER JOIN
                         dbo.Gender AS g ON rd.genderID_FK = g.genderID INNER JOIN
                         dbo.Nationality AS n ON rd.nationalityID_FK = n.nationalityID AND n.nationalityActive = 1 INNER JOIN
                         dbo.MaritalStatus AS ms ON rd.martialStatusID_FK = ms.maritalStatusID AND ms.maritalStatusActive = 1 INNER JOIN
                         dbo.MilitaryUnit AS mu ON rd.militaryUnitID_FK = mu.militaryUnitID LEFT OUTER JOIN
                         Housing.ResidentContactInfo AS ci ON ri.residentInfoID = ci.residentInfoID_FK AND ci.residentcontanctTypeID_FK = 1 AND ci.residentcontactInfoActive = 1
WHERE        (1 = 1) AND (ri.residentInfoActive = 1)

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
         Begin Table = "ri"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 223
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "rd"
            Begin Extent = 
               Top = 6
               Left = 261
               Bottom = 136
               Right = 460
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "r"
            Begin Extent = 
               Top = 6
               Left = 498
               Bottom = 136
               Right = 668
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "g"
            Begin Extent = 
               Top = 6
               Left = 706
               Bottom = 136
               Right = 892
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "n"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 268
               Right = 243
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ms"
            Begin Extent = 
               Top = 138
               Left = 281
               Bottom = 268
               Right = 499
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "mu"
            Begin Extent = 
               Top = 138
               Left = 537
               Bottom = 268
               Right = 748
            End
            DisplayFlags = 280
            TopColumn = 0
         End', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetGeneralListForResident';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'
         Begin Table = "ci"
            Begin Extent = 
               Top = 138
               Left = 786
               Bottom = 268
               Right = 1026
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
', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetGeneralListForResident';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetGeneralListForResident';

