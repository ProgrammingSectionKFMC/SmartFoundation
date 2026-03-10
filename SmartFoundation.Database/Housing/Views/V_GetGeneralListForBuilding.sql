





CREATE VIEW [Housing].[V_GetGeneralListForBuilding]
AS


SELECT 
       bd.[buildingDetailsID]
      ,bd.[buildingDetailsNo]
      ,bd.[buildingDetailsRooms]
      ,bd.[buildingLevelsCount]
      ,bd.[buildingDetailsArea]
      ,bd.[buildingDetailsCoordinates]
      ,bd.[buildingTypeID_FK]
      ,bt.[buildingTypeName_A]
      ,bd.[buildingUtilityTypeID_FK]
      ,bu.[buildingUtilityTypeName_A]
      ,bd.[militaryLocationID_FK]
      ,m.[militaryLocationName_A]
      ,mac.militaryAreaCityName_A
      ,ma.militaryAreaName_A
      ,bd.[buildingClassID_FK]
      ,bc.[buildingClassName_A]
      ,bd.[buildingDetailsTel_1]
      ,bd.[buildingDetailsTel_2]
      ,bd.[buildingDetailsRemark]
      ,bd.[buildingDetailsStartDate]
      ,bd.[buildingDetailsEndDate]
      ,bd.[buildingDetailsActive]
      ,bu.[buildingUtilityIsRent]
      ,bd.[IdaraId_FK] AS BuildingIdaraID
      ,i.idaraLongName_A as BuildingIdaraName
      ,bt.[IdaraId_FK] as BuildingTypeIdaraID
      ,bu.[IdaraId_FK] as BuildingUtilityTypeIdaraID
      ,m.[IdaraId_FK] as MilitaryLocationIdaraID
      ,bc.[IdaraId_FK] as BuildingClassIdaraID
      ,lb.buildingActionID  as LastActionID
      ,lb.buildingActionTypeID_FK as LastActionTypeID
      ,bat.buildingActionTypeName_A  as LastActionTypeName
FROM  Housing.BuildingDetails bd
INNER JOIN Housing.BuildingType bt 
    ON bd.buildingTypeID_FK = bt.buildingTypeID
INNER JOIN Housing.BuildingUtilityType bu 
    ON bd.buildingUtilityTypeID_FK = bu.buildingUtilityTypeID
INNER JOIN Housing.MilitaryLocation m 
    ON bd.militaryLocationID_FK = m.militaryLocationID
INNER JOIN Housing.MilitaryAreaCity mac 
    ON m.militaryAreaCityID_FK = mac.militaryAreaCityID
INNER JOIN Housing.MilitaryArea ma 
    ON mac.militaryAreaID_FK = ma.militaryAreaID
INNER JOIN Housing.BuildingClass bc 
    ON bd.buildingClassID_FK = bc.buildingClassID
OUTER APPLY (
    SELECT TOP (1) ba.buildingActionID, ba.buildingActionTypeID_FK
    FROM Housing.BuildingAction ba
    WHERE ba.buildingDetailsID_FK = bd.buildingDetailsID
    ORDER BY ba.buildingActionID DESC
) lb
left JOIN Housing.BuildingActionType bat   -- ✅ بدل INNER JOIN
    ON bat.buildingActionTypeID = lb.buildingActionTypeID_FK
INNER JOIN dbo.Idara i 
    ON i.IdaraId = bd.IdaraId_FK
WHERE bd.[buildingDetailsActive] = 1
  AND bt.[buildingTypeActive] = 1
  AND bu.[buildingUtilityTypeActive] = 1
  AND m.[militaryLocationActive] = 1
  AND bc.[buildingClassActive] = 1
  AND mac.militaryAreaCityActive = 1
  AND ma.militaryAreaIsActive = 1
  AND bd.buildingDetailsStartDate IS NOT NULL
  AND bu.buildingUtilityTypeStartDate IS NOT NULL
  AND (bd.buildingDetailsEndDate IS NULL OR bd.buildingDetailsEndDate > GETDATE())
  AND (bu.buildingUtilityTypeEndDate IS NULL OR bu.buildingUtilityTypeEndDate > GETDATE());



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
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 32
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
', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetGeneralListForBuilding';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetGeneralListForBuilding';

