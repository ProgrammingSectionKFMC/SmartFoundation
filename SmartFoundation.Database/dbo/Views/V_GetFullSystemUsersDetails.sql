CREATE VIEW dbo.V_GetFullSystemUsersDetails
AS
SELECT
    u.usersID,
    u.nationalID,
    ud.GeneralNo,
    LTRIM(RTRIM(
        ISNULL(ud.firstName_A, N'') + N' ' +
        ISNULL(ud.secondName_A, N'') + N' ' +
        ISNULL(ud.thirdName_A, N'') + N' ' +
        ISNULL(ud.forthName_A, N'') + N' ' +
        ISNULL(ud.lastName_A,  N'')
    )) AS FullName,
    ud.userTypeID_FK,
    uty.userTypeName_A,
    ua.UsersAuthTypeName_A,
    ua.UsersAuthTypeID,
    ud.userActive,
    ud.userNote,
    ud.IdaraID,
    id.idaraLongName_A,
    ud.entryDate,
    ud.entryData,
    LTRIM(RTRIM(
        ISNULL(eud.firstName_A, N'') + N' ' +
        ISNULL(eud.secondName_A, N'') + N' ' +
        ISNULL(eud.thirdName_A, N'') + N' ' +
        ISNULL(eud.forthName_A, N'') + N' ' +
        ISNULL(eud.lastName_A,  N'')
    )) AS EntryFullName
FROM dbo.Users AS u
OUTER APPLY
(
    SELECT TOP (1) ud1.*
    FROM dbo.UsersDetails ud1
    WHERE ud1.usersID_FK = u.usersID
    ORDER BY ud1.entryDate DESC, ud1.usersDetailsID DESC
) AS ud
LEFT JOIN dbo.UsersAuthType ua
    ON ud.usersAuthTypeID_FK = ua.UsersAuthTypeID
LEFT JOIN dbo.UserType uty
    ON ud.userTypeID_FK = uty.userTypeID
LEFT JOIN dbo.Users eu
    ON ud.entryData = eu.usersID
OUTER APPLY
(
    -- نجيب آخر سجل تفاصيل لمنفّذ الإجراء (حتى لو المنفّذ غير نشط)
    SELECT TOP (1) eud1.*
    FROM dbo.UsersDetails eud1
    WHERE eud1.usersID_FK = eu.usersID
    ORDER BY eud1.entryDate DESC, eud1.usersDetailsID DESC
) AS eud
LEFT JOIN dbo.Idara id
    ON ud.IdaraID = id.idaraID
--WHERE
    --u.usersActive = 1;  -- المستخدم نفسه فقط (اختياري حسب رغبتك)

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
         Begin Table = "ud"
            Begin Extent = 
               Top = 6
               Left = 274
               Bottom = 136
               Right = 521
            End
            DisplayFlags = 280
            TopColumn = 27
         End
         Begin Table = "eu"
            Begin Extent = 
               Top = 6
               Left = 559
               Bottom = 136
               Right = 757
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "eud"
            Begin Extent = 
               Top = 6
               Left = 795
               Bottom = 136
               Right = 1042
            End
            DisplayFlags = 280
            TopColumn = 2
         End
         Begin Table = "id"
            Begin Extent = 
               Top = 6
               Left = 1080
               Bottom = 136
               Right = 1268
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
      Begin ColumnWidths = 11
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
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'V_GetFullSystemUsersDetails';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'Alias = 900
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'V_GetFullSystemUsersDetails';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'V_GetFullSystemUsersDetails';

