CREATE VIEW dbo.V_GetListUsersInDSD
AS
SELECT DISTINCT 
                         u.usersID, u.nationalID, ue.GeneralNo, Concat_Ws(' ', ue.firstName_A, ue.secondName_A, ue.thirdName_A, ue.lastName_A) AS FullName, ds.distributorName_A AS distributorName, ud.distributorID_FK AS DistributorID, 
                         ut.userTypeName_A AS UserTypeName, ds.DSDID_FK AS DSDID, ue.userTypeID_FK AS userTypeID
FROM            dbo.Users AS u INNER JOIN
                         dbo.UsersDetails AS ue ON u.usersID = ue.usersID_FK INNER JOIN
                         dbo.UserDistributor AS ud ON ud.userID_FK = u.usersID INNER JOIN
                         dbo.Distributor AS ds ON ud.distributorID_FK = ds.distributorID INNER JOIN
                         dbo.UserType AS ut ON ut.userTypeID = ue.userTypeID_FK
WHERE        (1 = 1) AND (ud.UDActive = 1) AND (ud.UDStartDate IS NOT NULL) AND (ud.UDEndDate IS NULL) AND (ds.distributorActive = 1) AND (ds.distributorType_FK = 1) AND (ds.DSDID_FK IS NOT NULL) AND (ds.roleID_FK IS NULL) AND 
                         (ut.userTypeActive = 1) AND (u.usersActive = 1) AND (ue.userActive = 1) AND (ud.UDStartDate IS NOT NULL) AND (CAST(ud.UDStartDate AS date) <= CAST(GETDATE() AS date)) AND (ud.UDEndDate IS NULL) OR
                         (1 = 1) AND (ud.UDActive = 1) AND (ud.UDStartDate IS NOT NULL) AND (ud.UDEndDate IS NULL) AND (ds.distributorActive = 1) AND (ds.distributorType_FK = 1) AND (ds.DSDID_FK IS NOT NULL) AND (ds.roleID_FK IS NULL) AND 
                         (ut.userTypeActive = 1) AND (u.usersActive = 1) AND (ue.userActive = 1) AND (ud.UDStartDate IS NOT NULL) AND (CAST(ud.UDStartDate AS date) <= CAST(GETDATE() AS date)) AND (CAST(ud.UDEndDate AS date) > CAST(GETDATE()
                          AS date))

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
         Begin Table = "u"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 236
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ue"
            Begin Extent = 
               Top = 6
               Left = 968
               Bottom = 136
               Right = 1215
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ud"
            Begin Extent = 
               Top = 6
               Left = 280
               Bottom = 136
               Right = 453
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ds"
            Begin Extent = 
               Top = 6
               Left = 491
               Bottom = 136
               Right = 695
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ut"
            Begin Extent = 
               Top = 6
               Left = 733
               Bottom = 136
               Right = 930
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
         Output', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'V_GetListUsersInDSD';


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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'V_GetListUsersInDSD';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'V_GetListUsersInDSD';

