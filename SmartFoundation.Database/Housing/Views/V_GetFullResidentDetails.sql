

CREATE VIEW [Housing].[V_GetFullResidentDetails]
AS
SELECT
    rd.residentDetailsID              AS residentDetailsID,
    ri.residentInfoID                 AS residentInfoID,
    ri.NationalID                     AS NationalID,

    ISNULL(rd.generalNo_FK, '')       AS generalNo_FK,
    ISNULL(rd.firstName_A, '')        AS firstName_A,
    ISNULL(rd.secondName_A, '')       AS secondName_A,
    ISNULL(rd.thirdName_A, '')        AS thirdName_A,
    ISNULL(rd.lastName_A, '')         AS lastName_A,

    ISNULL(rd.firstName_E, '')        AS firstName_E,
    ISNULL(rd.secondName_E, '')       AS secondName_E,
    ISNULL(rd.thirdName_E, '')        AS thirdName_E,
    ISNULL(rd.lastName_E, '')         AS lastName_E,

    LTRIM(RTRIM(CONCAT_WS(N' ',
        rd.firstName_A, rd.secondName_A, rd.thirdName_A, rd.lastName_A
    )))                               AS FullName_A,

    LTRIM(RTRIM(CONCAT_WS(N' ',
        rd.firstName_E, rd.secondName_E, rd.thirdName_E, rd.lastName_E
    )))                               AS FullName_E,

    rd.rankID_FK                      AS rankID_FK,
    r.rankNameA                       AS rankNameA,

    rd.militaryUnitID_FK              AS militaryUnitID_FK,
    m.militaryUnitName_A              AS militaryUnitName_A,

    rd.martialStatusID_FK             AS martialStatusID_FK,
    ms.maritalStatusName_A            AS maritalStatusName_A,

    rd.dependinceCounter              AS dependinceCounter,

    rd.nationalityID_FK               AS nationalityID_FK,
    n.nationalityName_A               AS nationalityName_A,

    rd.genderID_FK                    AS genderID_FK,
    g.genderName_A                    AS genderName_A,

    CONVERT(nvarchar(10), rd.birthdate, 23) AS birthdate,

    ISNULL(rc.residentcontactDetails,'')    AS residentcontactDetails,
    ct.residentcontactTypeName_A            AS MobileTypeName_A,

    ISNULL(rd.note,'')                AS note,
    rd.IdaraId_FK                     AS IdaraID,
    i.idaraLongName_A                 AS IdaraName
FROM Housing.ResidentInfo ri
INNER JOIN Housing.ResidentDetails rd
    ON rd.residentInfoID_FK = ri.residentInfoID
   AND rd.residentDetailsActive = 1

LEFT JOIN (
    SELECT residentInfoID_FK, MAX(residentcontactInfoID) AS MaxMobileID
    FROM Housing.ResidentContactInfo
    WHERE residentcontactInfoActive = 1
      AND residentcontanctTypeID_FK = 1
    GROUP BY residentInfoID_FK
) mx
    ON mx.residentInfoID_FK = ri.residentInfoID

LEFT JOIN Housing.ResidentContactInfo rc
    ON rc.residentcontactInfoID = mx.MaxMobileID
LEFT JOIN Housing.ResidentContactType ct
    ON rc.residentcontanctTypeID_FK = ct.residentcontanctTypeID

INNER JOIN dbo.Rank r
    ON rd.rankID_FK = r.rankID
INNER JOIN dbo.MilitaryUnit m
    ON rd.militaryUnitID_FK = m.militaryUnitID
INNER JOIN dbo.MaritalStatus ms
    ON rd.martialStatusID_FK = ms.maritalStatusID
INNER JOIN dbo.Nationality n
    ON rd.nationalityID_FK = n.nationalityID
INNER JOIN dbo.Gender g
    ON rd.genderID_FK = g.genderID
INNER JOIN dbo.Idara i
    ON rd.IdaraId_FK = i.idaraID
WHERE ri.residentInfoActive = 1;

GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[65] 4[3] 2[13] 3) )"
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
               Left = 316
               Bottom = 136
               Right = 501
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "maxdet"
            Begin Extent = 
               Top = 6
               Left = 539
               Bottom = 102
               Right = 720
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "rd"
            Begin Extent = 
               Top = 6
               Left = 758
               Bottom = 136
               Right = 972
            End
            DisplayFlags = 280
            TopColumn = 22
         End
         Begin Table = "MAXMobile"
            Begin Extent = 
               Top = 6
               Left = 1010
               Bottom = 102
               Right = 1213
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "rc"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 337
               Right = 278
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ct"
            Begin Extent = 
               Top = 6
               Left = 1251
               Bottom = 119
               Right = 1493
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "r"
            Begin Extent = 
               Top = 102
               Left = 539
               Bottom = 232
               Right = 709
            End
            DisplayFlags = 280
            TopColumn = 0', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetFullResidentDetails';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'
         End
         Begin Table = "m"
            Begin Extent = 
               Top = 102
               Left = 1010
               Bottom = 232
               Right = 1221
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ms"
            Begin Extent = 
               Top = 120
               Left = 1259
               Bottom = 250
               Right = 1477
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "n"
            Begin Extent = 
               Top = 138
               Left = 316
               Bottom = 268
               Right = 521
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "g"
            Begin Extent = 
               Top = 138
               Left = 747
               Bottom = 268
               Right = 933
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Idara"
            Begin Extent = 
               Top = 272
               Left = 533
               Bottom = 402
               Right = 721
            End
            DisplayFlags = 280
            TopColumn = 1
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 31
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
', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetFullResidentDetails';




GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetFullResidentDetails';

