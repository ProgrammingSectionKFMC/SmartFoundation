
CREATE VIEW [Housing].[V_MetersDetails]
AS
SELECT m.meterID, m.meterTypeID_FK, m.meterNo, m.meterName_A, m.meterName_E, m.meterDescription, m.meterStartDate, m.meterEndDate, m.meterActive, m.CanceledBy, m.CanceledDate, m.CanceledNote, m.IdaraId_FK AS MeterIDaraID, mt.meterServiceTypeID_FK, 
             mt.meterTypeName_A, mt.meterTypeName_E, mt.meterTypeDescription, mt.meterTypeConversionFactor, mt.meterMaxRead, mt.meterTypeStartDate, mt.meterTypeEndDate, mt.meterTypeActive, mt.CanceledBy AS MeterTypeCanceledBy, 
             mt.CanceledDate AS MeterTypeCanceledDate, mt.CanceledNote AS MeterTypeCanceledNote, mt.IdaraId_FK AS MeterTypeIDaraID, mst.meterServiceTypeName_A, mst.meterServiceTypeName_E, mst.meterServiceTypeDescription, mst.meterServiceTypeStartDate, 
             mst.meterServiceTypeEndDate, mst.meterServiceTypeActive, mst.BillChargeTypeID_FK, msp.meterServicePriceID, msp.meterServicePriceStartDate, msp.meterServicePriceEndDate, msp.meterServicePrice, msp.meterServicePriceActive, mtw.MeterServiceTypeLinkedWithIdaraID, 
             mtw.Idara_FK AS MeterServiceTypeLinkedWithIdaraID_FK, mtw.MeterServiceTypeLinkedWithIdaraStartDate, mtw.MeterServiceTypeLinkedWithIdaraEndDate, mtw.MeterServiceTypeLinkedWithIdaraActive
FROM   Housing.Meter AS m INNER JOIN
             Housing.MeterType AS mt ON m.meterTypeID_FK = mt.meterTypeID INNER JOIN
             Housing.MeterServiceType AS mst ON mt.meterServiceTypeID_FK = mst.meterServiceTypeID INNER JOIN
             Housing.MeterServicePrice AS msp ON mt.meterTypeID = msp.meterTypeID_FK INNER JOIN
             Housing.MeterServiceTypeLinkedWithIdara AS mtw ON mst.meterServiceTypeID = mtw.MeterServiceTypeID_FK

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
         Configuration = "(H (1[50] 4[25] 3) )"
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
         Configuration = "(H (1[61] 4) )"
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
         Configuration = "(V (4) )"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 9
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "m"
            Begin Extent = 
               Top = 9
               Left = 57
               Bottom = 591
               Right = 297
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "mt"
            Begin Extent = 
               Top = 9
               Left = 354
               Bottom = 588
               Right = 680
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "mst"
            Begin Extent = 
               Top = 9
               Left = 737
               Bottom = 585
               Right = 1070
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "msp"
            Begin Extent = 
               Top = 9
               Left = 1127
               Bottom = 398
               Right = 1443
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "mtw"
            Begin Extent = 
               Top = 246
               Left = 867
               Bottom = 628
               Right = 1312
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
      PaneHidden = 
   End
   Begin DataPane = 
      PaneHidden = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 10
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
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         C', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_MetersDetails';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'olumn = 2600
         Alias = 3140
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
', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_MetersDetails';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_MetersDetails';

