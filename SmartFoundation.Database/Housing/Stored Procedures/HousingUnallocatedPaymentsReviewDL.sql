
/*
    REVIEW V4 — HIJRI MONTH PERIODS / OCCUPANCY OVERLAP.
    Review only: DO NOT DEPLOY until read-only reconciliation and live QA are approved.
    Preserves the existing five result sets (dt1..dt5), names and order.
*/
CREATE   PROCEDURE [Housing].[HousingUnallocatedPaymentsReviewDL]
      @pageName_        NVARCHAR(400)
    , @idaraID          INT
    , @entrydata        BIGINT
    , @hostname         NVARCHAR(400)
    , @residentInfoID   BIGINT = NULL
    , @BillChargeTypeID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- Page context / permission: unchanged
    --------------------------------------------------
    IF @pageName_ <> N'HousingUnallocatedPaymentsReview'
       OR @idaraID IS NULL
       OR @entrydata IS NULL
    BEGIN
        ;THROW 50001, N'سياق الصفحة غير صحيح', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ft_UserPagePermissions(@entrydata, @pageName_)
    )
    BEGIN
        ;THROW 50001, N'ليس لديك صلاحية استعراض الأرصدة العامة', 1;
    END;

    --------------------------------------------------
    -- Verified Hijri calendar months. Never fall back
    -- to staff-entered paymentDate for a Hijri month.
    --------------------------------------------------
    SELECT
          g.yearH
        , g.monthH
        , MIN(CONVERT(DATE, g.gregorianDate)) AS PeriodStartDate
        , MAX(CONVERT(DATE, g.gregorianDate)) AS PeriodEndDate
    INTO #HijriMonths
    FROM dbo._GregorianHijriDate g
    WHERE g.yearH BETWEEN 1400 AND 1499
    GROUP BY g.yearH, g.monthH
    HAVING COUNT(*) BETWEEN 29 AND 30
       AND COUNT(DISTINCT g.dayH) = COUNT(*)
       AND MIN(g.dayH) = 1
       AND MAX(g.dayH) = COUNT(*)
       AND COUNT(DISTINCT CONVERT(DATE, g.gregorianDate)) = COUNT(*)
       AND DATEDIFF
           (
               DAY,
               MIN(CONVERT(DATE, g.gregorianDate)),
               MAX(CONVERT(DATE, g.gregorianDate))
           ) + 1 = COUNT(*);

    CREATE UNIQUE CLUSTERED INDEX IX_HUPR_HijriMonths
        ON #HijriMonths (yearH, monthH);

    --------------------------------------------------
    -- First documented occupancy, unchanged
    --------------------------------------------------
    ;WITH FirstOccupancy AS
    (
        SELECT
              a.residentInfoID_FK
            , MIN(CONVERT(DATE, a.buildingActionDate)) AS FirstOccupancyDate
        FROM Housing.BuildingAction a
        WHERE a.buildingActionTypeID_FK = 2
          AND a.buildingActionActive = 1
          AND a.buildingActionDate IS NOT NULL
        GROUP BY a.residentInfoID_FK
    )
    SELECT
          p.paymentID
        , p.residentInfoID_FK AS ResidentInfoID
        , p.BillChargeTypeID_FK AS BillChargeTypeID
        , p.IdaraId_FK AS IdaraID
        , CONVERT(DECIMAL(18,2), p.amount) AS Amount
        , p.buildingDetailsID_FK
        , p.buildingPaymentTypeID_FK
        , d.deductListID
        , d.deductName
        , d.issueYear
        , d.issueMonth
        , d.paymentDate
        , bt.buildingPaymentTypeName_A AS PaymentTypeName
        , f.FirstOccupancyDate
        , dates.PaymentReferenceDate
        , CASE
              WHEN p.amount <= 0 THEN 0
              WHEN f.FirstOccupancyDate IS NULL THEN 0
              WHEN NULLIF(LTRIM(RTRIM(p.buildingDetailsID_FK)), N'') IS NOT NULL THEN 0
              WHEN dates.PaymentPeriodEndDate IS NULL THEN 0
              -- Period fully after OR overlapping first documented occupancy.
              WHEN dates.PaymentPeriodEndDate >= f.FirstOccupancyDate THEN 1
              ELSE 0
          END AS IsEligiblePositive
    INTO #Payments
    FROM Housing.BuildingPayment p
    INNER JOIN Housing.DeductList d
        ON d.deductListID = p.deductListID_FK
    LEFT JOIN Housing.BuildingPaymentType bt
        ON bt.buildingPaymentTypeID = p.buildingPaymentTypeID_FK
    LEFT JOIN FirstOccupancy f
        ON f.residentInfoID_FK = p.residentInfoID_FK
    LEFT JOIN #HijriMonths h
        ON h.yearH = d.issueYear AND h.monthH = d.issueMonth
    CROSS APPLY
    (
        SELECT
              CASE
                  WHEN d.issueYear BETWEEN 1400 AND 1499
                      THEN h.PeriodStartDate
                  WHEN d.issueYear BETWEEN 1900 AND 9999
                   AND d.issueMonth BETWEEN 1 AND 12
                      THEN TRY_CONVERT(DATE, CONCAT(d.issueYear, N'-',
                           RIGHT(N'0' + CONVERT(NVARCHAR(2), d.issueMonth), 2), N'-01'))
                  ELSE d.paymentDate
              END AS PaymentReferenceDate
            , CASE
                  WHEN d.issueYear BETWEEN 1400 AND 1499
                      THEN h.PeriodEndDate
                  WHEN d.issueYear BETWEEN 1900 AND 9999
                   AND d.issueMonth BETWEEN 1 AND 12
                      THEN EOMONTH(TRY_CONVERT(DATE, CONCAT(d.issueYear, N'-',
                           RIGHT(N'0' + CONVERT(NVARCHAR(2), d.issueMonth), 2), N'-01')))
                  ELSE d.paymentDate
              END AS PaymentPeriodEndDate
    ) dates
    WHERE p.buildingPaymentLinkStatusID_FK = 2
      AND p.buildingPayementActive = 1
      AND d.deductActive = 1
      AND p.residentInfoID_FK IS NOT NULL
      AND p.IdaraId_FK = @idaraID
      AND p.amount IS NOT NULL;

    --------------------------------------------------
    -- Balance aggregation: original layout/logic
    --------------------------------------------------
    SELECT
          p.ResidentInfoID
        , p.BillChargeTypeID
        , MAX(p.FirstOccupancyDate) AS FirstOccupancyDate
        , COUNT_BIG(*) AS PaymentCount
        , SUM(CASE WHEN p.Amount > 0 THEN p.Amount ELSE 0 END) AS TotalPositivePayments
        , SUM(CASE WHEN p.Amount < 0 THEN -p.Amount ELSE 0 END) AS TotalOldRefunds
        , SUM(CASE WHEN p.IsEligiblePositive = 1 THEN p.Amount ELSE 0 END) AS EligiblePositivePayments
        , SUM(CASE WHEN p.Amount > 0 AND p.IsEligiblePositive = 0
                   THEN p.Amount ELSE 0 END) AS PaymentsRequiringReview
        , SUM(p.Amount) AS RawGeneralBalance
    INTO #Balances
    FROM #Payments p
    GROUP BY p.ResidentInfoID, p.BillChargeTypeID;

    --------------------------------------------------
    -- dt1: beneficiaries & general balances
    --------------------------------------------------
    ;WITH NewRefunds AS
    (
        SELECT
              r.ResidentInfoID_FK
            , r.BillChargeTypeID_FK
            , SUM(CASE WHEN r.RefundStatus = 1
                       THEN r.RefundAmount ELSE 0 END) AS TotalNewRefunds
        FROM Housing.UnallocatedPaymentRefund r
        WHERE r.IdaraId_FK = @idaraID
        GROUP BY r.ResidentInfoID_FK, r.BillChargeTypeID_FK
    )
    SELECT
          ROW_NUMBER() OVER
              (ORDER BY b.ResidentInfoID, b.BillChargeTypeID) AS order_
        , b.ResidentInfoID AS residentInfoID
        , fr.NationalID
        , fr.generalNo_FK
        , fr.FullName_A
        , b.BillChargeTypeID
        , ct.BillChargeTypeName_A
        , b.FirstOccupancyDate
        , b.PaymentCount
        , b.TotalPositivePayments
        , b.TotalOldRefunds
        , b.EligiblePositivePayments
        , b.PaymentsRequiringReview
        , b.RawGeneralBalance
        , ISNULL(n.TotalNewRefunds, 0) AS TotalNewRefunds
        , CASE
              WHEN b.EligiblePositivePayments - b.TotalOldRefunds
                   - ISNULL(n.TotalNewRefunds, 0) > 0
              THEN b.EligiblePositivePayments - b.TotalOldRefunds
                   - ISNULL(n.TotalNewRefunds, 0)
              ELSE CONVERT(DECIMAL(18,2), 0)
          END AS RemainingForReview
    FROM #Balances b
    INNER JOIN Housing.BillChargeType ct
        ON ct.BillChargeTypeID = b.BillChargeTypeID
    LEFT JOIN NewRefunds n
        ON n.ResidentInfoID_FK = b.ResidentInfoID
       AND n.BillChargeTypeID_FK = b.BillChargeTypeID
    OUTER APPLY
    (
        SELECT TOP (1)
              x.NationalID
            , x.generalNo_FK
            , x.FullName_A
        FROM Housing.V_GetFullResidentDetails x
        WHERE x.residentInfoID = b.ResidentInfoID
        ORDER BY x.residentDetailsID DESC
    ) fr
    ORDER BY RawGeneralBalance desc;
    --b.ResidentInfoID, b.BillChargeTypeID;

    --------------------------------------------------
    -- dt2: positive payments for selected beneficiary
    --------------------------------------------------
    SELECT
          p.paymentID
        , p.ResidentInfoID AS residentInfoID
        , p.BillChargeTypeID
        , p.Amount
        , p.deductName
        , p.PaymentTypeName
        , p.issueYear
        , p.issueMonth
        , p.paymentDate
        , p.PaymentReferenceDate
        , p.FirstOccupancyDate
        , p.buildingDetailsID_FK
        , p.IsEligiblePositive
    FROM #Payments p
    WHERE @residentInfoID IS NOT NULL
      AND @BillChargeTypeID IS NOT NULL
      AND p.ResidentInfoID = @residentInfoID
      AND p.BillChargeTypeID = @BillChargeTypeID
      AND p.Amount > 0
    ORDER BY p.paymentDate, p.paymentID;

    --------------------------------------------------
    -- dt3: legacy negative refund movements
    --------------------------------------------------
    SELECT
          p.paymentID
        , p.ResidentInfoID AS residentInfoID
        , p.BillChargeTypeID
        , p.Amount AS SignedAmount
        , -p.Amount AS RefundAmount
        , p.deductName
        , p.PaymentTypeName
        , p.issueYear
        , p.issueMonth
        , p.paymentDate
    FROM #Payments p
    WHERE @residentInfoID IS NOT NULL
      AND @BillChargeTypeID IS NOT NULL
      AND p.ResidentInfoID = @residentInfoID
      AND p.BillChargeTypeID = @BillChargeTypeID
      AND p.Amount < 0
    ORDER BY p.paymentDate, p.paymentID;

    --------------------------------------------------
    -- dt4: refunds registered in the new page
    --------------------------------------------------
    SELECT
          r.RefundID
        , r.ResidentInfoID_FK AS residentInfoID
        , r.BillChargeTypeID_FK AS BillChargeTypeID
        , r.RefundAmount
        , r.RefundDate
        , r.RefundReference
        , r.RefundDetails
        , r.RefundStatus
        , r.EntryDate
        , r.EntryData
        , r.HostName
    FROM Housing.UnallocatedPaymentRefund r
    WHERE @residentInfoID IS NOT NULL
      AND @BillChargeTypeID IS NOT NULL
      AND r.ResidentInfoID_FK = @residentInfoID
      AND r.BillChargeTypeID_FK = @BillChargeTypeID
      AND r.IdaraId_FK = @idaraID
    ORDER BY r.RefundDate DESC, r.RefundID DESC;

    --------------------------------------------------
    -- dt5: accepted refund payment method
    --------------------------------------------------
    SELECT
          t.billPaymentTypeID
        , t.billPaymentTypeName_A
        , t.billPaymentDestainationID_FK
    FROM Housing.billPaymentType t
    WHERE t.billPaymentTypeID = 4
      AND t.billPaymentDestainationID_FK = 2
      AND t.billPaymentTypeActive = 1;
END;