

CREATE VIEW [Housing].[V_GetGeneralListActionForResident]
AS
SELECT        ba.buildingActionID AS ActionID, ba.buildingActionTypeID_FK AS ActionTypeID, bat.buildingActionTypeName_A AS ActionTypeName, ba.generalNo_FK AS GeneralNo, bpt.buildingPaymentTypeName_A AS PaymentTypeName, 
                         ba.buildingDetailsNo AS BuildingNo, CAST(ba.buildingActionDate AS date) AS ActionDate, ba.buildingActionDecisionNo AS ActionDecisionNo, CAST(ba.buildingActionDecisionDate AS date) AS ActionDecisionDate, 
                         ba.buildingActionNote AS ActionNote, CAST(ba.buildingActionFromDate AS date) AS ActionFromDate, CAST(ba.buildingActionToDate AS date) AS ActionToDate, ba.buildingActionExtraType1 AS WaitingClassID, 
                         wc.waitingClassName_A AS WaitingClassName, ba.buildingActionExtraType2 AS WaitingOrderTypeID, wot.waitingOrderTypeName_A AS WaitingOrderTypeName, wc.waitingClassSequence, ba.buildingActionParentID, 
                         re.NationalID, ba.buildingActionActive, ba.IdaraId_FK, ba.buildingActionExtraInt1, re.residentInfoID, ba.residentInfoID_FK, u.usersID AS entryDatausersID, u.FullName AS entryDataName, ba.buildingPaymentTypeID_FK as PaymentTypeID, 
                         ba.entrydate,gf.FullName_A as ResidentFullName_A
FROM            Housing.BuildingAction AS ba INNER JOIN
                         Housing.BuildingActionType AS bat ON ba.buildingActionTypeID_FK = bat.buildingActionTypeID AND bat.buildingActionTypeActive = 1 LEFT OUTER JOIN
                         Housing.BuildingPaymentType AS bpt ON ba.buildingPaymentTypeID_FK = bpt.buildingPaymentTypeID AND bpt.buildingPaymentTypeActive = 1 LEFT OUTER JOIN
                         Housing.WaitingClass AS wc ON ba.buildingActionExtraType1 = wc.waitingClassID LEFT OUTER JOIN
                         Housing.WaitingOrderType AS wot ON ba.buildingActionExtraType2 = wot.waitingOrderTypeID AND wot.waitingOrderTypeActive = 1 INNER JOIN
                         Housing.ResidentInfo AS re ON ba.residentInfoID_FK = re.residentInfoID OUTER APPLY
                             (SELECT        LastUserID = TRY_CONVERT(int, LTRIM(RTRIM(CASE WHEN ba.entryData IS NULL OR
                                                         LTRIM(RTRIM(CONVERT(varchar(4000), ba.entryData))) = '' THEN NULL WHEN CHARINDEX(',', CONVERT(varchar(4000), ba.entryData)) > 0 THEN RIGHT(CONVERT(varchar(4000), ba.entryData), CHARINDEX(',', 
                                                         REVERSE(CONVERT(varchar(4000), ba.entryData)) + ',') - 1) ELSE CONVERT(varchar(4000), ba.entryData) END)))) X LEFT OUTER JOIN
                         dbo.V_GetListUsersInDSD AS u ON u.usersID = X.LastUserID
                         inner join Housing.V_GetFullResidentDetails gf on gf.residentInfoID =re.residentInfoID
WHERE        (1 = 1) AND (ba.generalNo_FK IS NOT NULL) AND (ba.generalNo_FK <> '') AND (ba.residentInfoID_FK IS NOT NULL) AND (ba.residentInfoID_FK <> '') AND (re.residentInfoActive = 1) AND (ba.buildingActionActive = 1);

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
      Begin ColumnWidths = 27
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
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 2640
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
', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetGeneralListActionForResident';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_GetGeneralListActionForResident';

