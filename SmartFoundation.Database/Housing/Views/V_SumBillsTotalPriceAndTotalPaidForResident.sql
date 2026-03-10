
CREATE VIEW [Housing].[V_SumBillsTotalPriceAndTotalPaidForResident]
AS
SELECT COALESCE (br.residentInfoID, po.residentInfoID) AS residentInfoID, COALESCE (br.BillChargeTypeID, po.BillChargeTypeID) AS BillChargeTypeID, COALESCE (br.BillChargeTypeName_A, po.BillChargeTypeName_A) AS BillChargeTypeName_A, COALESCE (br.buildingDetailsID, 
             po.buildingDetailsID) AS buildingDetailsID, ISNULL(br.SumBillsTotalPrice, 0) AS SumBillsTotalPrice, ISNULL(po.SumTotalPaidBills, 0) AS SumTotalPaidBills, ISNULL(br.SumBillsTotalPrice, 0) - ISNULL(po.SumTotalPaidBills, 0) AS Remaining
FROM   Housing.V_SumBillsTotalPriceForResident AS br FULL OUTER JOIN
             Housing.V_SumBillsTotalPaidByResident AS po ON br.residentInfoID = po.residentInfoID AND br.BillChargeTypeID = po.BillChargeTypeID AND ISNULL(br.buildingDetailsID, - 1) = ISNULL(po.buildingDetailsID, - 1)

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
         Configuration = "(H (4[30] 2[40] 3) )"
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
      ActivePaneConfig = 3
   End
   Begin DiagramPane = 
      PaneHidden = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "br"
            Begin Extent = 
               Top = 9
               Left = 57
               Bottom = 206
               Right = 343
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "po"
            Begin Extent = 
               Top = 9
               Left = 400
               Bottom = 206
               Right = 686
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
', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_SumBillsTotalPriceAndTotalPaidForResident';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_SumBillsTotalPriceAndTotalPaidForResident';

