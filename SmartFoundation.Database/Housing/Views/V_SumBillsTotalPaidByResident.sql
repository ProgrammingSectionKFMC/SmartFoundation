
CREATE   VIEW Housing.V_SumBillsTotalPaidByResident
AS
WITH FirstOccupancy AS
(
    SELECT
        a.residentInfoID_FK,
        a.IdaraId_FK,
        MIN(CONVERT(DATE, a.buildingActionDate))
            AS FirstOccupancyDate
    FROM Housing.BuildingAction a
    WHERE a.buildingActionTypeID_FK = 2
      AND a.buildingActionActive = 1
      AND a.buildingActionDate IS NOT NULL
      AND a.residentInfoID_FK IS NOT NULL
      AND a.IdaraId_FK IS NOT NULL
    GROUP BY
        a.residentInfoID_FK,
        a.IdaraId_FK
),
HijriMonths AS
(
    SELECT
        yearH,
        monthH,
        MAX(CONVERT(DATE, gregorianDate)) AS MonthEnd
    FROM dbo._GregorianHijriDate
    GROUP BY yearH, monthH
),
PaymentPeriods AS
(
    SELECT
        p.residentInfoID_FK AS residentInfoID,
        p.BillChargeTypeID_FK AS BillChargeTypeID,
        ct.BillChargeTypeName_A,

        CASE
            WHEN p.buildingPaymentLinkStatusID_FK = 1
            THEN TRY_CONVERT(
                BIGINT, p.buildingDetailsID_FK)
            ELSE CAST(NULL AS BIGINT)
        END AS buildingDetailsID,

        p.IdaraId_FK AS idaraID,
        p.buildingPaymentLinkStatusID_FK AS LinkStatus,
        p.amount,
        o.FirstOccupancyDate,

        CASE
            WHEN d.issueYear BETWEEN 1300 AND 1599
                THEN h.MonthEnd

            WHEN d.issueYear BETWEEN 1900 AND 9999
             AND d.issueMonth BETWEEN 1 AND 12
                THEN EOMONTH(DATEFROMPARTS(
                    d.issueYear,
                    d.issueMonth,
                    1
                ))

            ELSE NULL
        END AS PeriodEnd

    FROM Housing.BuildingPayment p

    INNER JOIN Housing.DeductList d
        ON d.deductListID = p.deductListID_FK

    INNER JOIN Housing.BillChargeType ct
        ON ct.BillChargeTypeID = p.BillChargeTypeID_FK

    INNER JOIN FirstOccupancy o
        ON o.residentInfoID_FK = p.residentInfoID_FK
       AND o.IdaraId_FK = p.IdaraId_FK

    LEFT JOIN HijriMonths h
        ON h.yearH = d.issueYear
       AND h.monthH = d.issueMonth

    WHERE p.buildingPayementActive = 1
      AND d.deductActive = 1
      AND p.residentInfoID_FK IS NOT NULL
      AND p.IdaraId_FK IS NOT NULL
      AND p.buildingPaymentLinkStatusID_FK IN (1,2)
),
EligiblePayments AS
(
    SELECT *
    FROM PaymentPeriods
    WHERE PeriodEnd IS NOT NULL
      AND PeriodEnd >= FirstOccupancyDate
      AND
      (
          LinkStatus = 2
          OR
          (
              LinkStatus = 1
              AND buildingDetailsID > 0
          )
      )
)
SELECT
    SUM(amount) AS SumTotalPaidBills,
    residentInfoID,
    BillChargeTypeID,
    BillChargeTypeName_A,
    buildingDetailsID,
    idaraID

FROM EligiblePayments
GROUP BY
    residentInfoID,
    BillChargeTypeID,
    BillChargeTypeName_A,
    buildingDetailsID,
    idaraID;

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
         Configuration = "(H (4[50] 3) )"
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
      ActivePaneConfig = 6
   End
   Begin DiagramPane = 
      PaneHidden = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "bp"
            Begin Extent = 
               Top = 9
               Left = 57
               Bottom = 206
               Right = 393
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "d"
            Begin Extent = 
               Top = 9
               Left = 450
               Bottom = 206
               Right = 746
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t"
            Begin Extent = 
               Top = 9
               Left = 803
               Bottom = 206
               Right = 1106
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
      Begin ColumnWidths = 12
         Column = 2520
         Alias = 2260
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
', @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_SumBillsTotalPaidByResident';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'Housing', @level1type = N'VIEW', @level1name = N'V_SumBillsTotalPaidByResident';

