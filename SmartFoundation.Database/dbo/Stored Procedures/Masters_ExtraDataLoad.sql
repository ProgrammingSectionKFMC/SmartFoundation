CREATE PROCEDURE [dbo].[Masters_ExtraDataLoad]
      @pageName_      NVARCHAR(400)
    , @ActionType     NVARCHAR(100)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
    , @parameter_01   NVARCHAR(4000) = NULL
    , @parameter_02   NVARCHAR(4000) = NULL
    , @parameter_03   NVARCHAR(4000) = NULL
    , @parameter_04   NVARCHAR(4000) = NULL
    , @parameter_05   NVARCHAR(4000) = NULL
    , @parameter_06   NVARCHAR(4000) = NULL
    , @parameter_07   NVARCHAR(4000) = NULL
    , @parameter_08   NVARCHAR(4000) = NULL
    , @parameter_09   NVARCHAR(4000) = NULL
    , @parameter_10   NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------------------
    --                   START TRY BLOCK
    -------------------------------------------------------------------

     -------------------------------------------------------------------
    --                   Residents
    -------------------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;


        IF @pageName_ = 'Residents'
        BEGIN
         IF @ActionType = 'ResidentActions'
            BEGIN
                Select top(1)
                     [buildingActionID]
                    ,[buildingActionUDID]
                    ,[buildingActionTypeID_FK]
                    ,[buildingStatusID_FK]
                    ,[residentInfoID_FK]
                    ,[generalNo_FK]
                    ,[buildingPaymentTypeID_FK]
                    ,[buildingDetailsID_FK]
                    ,[buildingDetailsNo]
                    ,[buildingActionFromDate]
                    ,[buildingActionToDate]
                    ,[buildingActionDate]
                    ,[buildingActionDate2]
                    ,[buildingActionDecisionNo]
                    ,[buildingActionDecisionDate]
                    ,[fromDSD_FK]
                    ,[toDSD_FK]
                    ,[buildingActionFromSourceID_FK]
                    ,[buildingActionToSourceID_FK]
                    ,[buildingActionNote]
                    ,[buildingActionExtraText1]
                    ,[buildingActionExtraText2]
                    ,[buildingActionExtraText3]
                    ,[buildingActionExtraText4]
                    ,[buildingActionExtraDate1]
                    ,[buildingActionExtraDate2]
                    ,[buildingActionExtraDate3]
                    ,[buildingActionExtraFloat1]
                    ,[buildingActionExtraFloat2]
                    ,[buildingActionExtraInt1]
                    ,[buildingActionExtraInt2]
                    ,[buildingActionExtraInt3]
                    ,[buildingActionExtraInt4]
                    ,[buildingActionExtraType1]
                    ,[buildingActionExtraType2]
                    ,[buildingActionExtraType3]
                    ,[buildingActionActive]
                    ,[buildingActionParentID]
                    ,[CustdyRecord]
                    ,[AssignPeriodID_FK]
                    ,[ExtendReasonTypeID_FK]
                    ,[IdaraId_FK]
                    ,[entryDate]
                    ,[entryData]
                    ,[hostName]
                       from
                       Housing.BuildingAction w
                       where w.residentInfoID_FK = @parameter_01 --and w.buildingActionTypeID_FK = @parameter_02

                       order by buildingActionID asc

            END





            

        END



    -------------------------------------------------------------------
    --                   Meters - unlink bill preview
    -------------------------------------------------------------------
         ELSE IF @pageName_ = 'Meters'
        BEGIN
            IF @ActionType = 'MeterLastBill'
            BEGIN
                IF EXISTS
                (
                    SELECT 1 FROM Housing.MeterRead mr
                    WHERE mr.meterID_FK = @parameter_02 AND mr.meterReadActive = 1
                )
                BEGIN
                    SELECT TOP (1)
                           mr.meterID_FK AS meterID,
                           meter.meterNo,
                           mr.meterReadValue AS CurrentRead,
                           ISNULL(period.billPeriodName_A + N' - ' + CONVERT(NVARCHAR(4), YEAR(period.billPeriodStartDate)), N' - ') AS periods_,
                           ISNULL(bill.TotalPrice, 0) AS TotalPrice
                    FROM Housing.MeterRead mr
                    LEFT JOIN Housing.Meter meter ON meter.meterID = mr.meterID_FK
                    OUTER APPLY
                    (
                        SELECT TOP (1) b.TotalPrice, b.CurrentPeriodID
                        FROM Housing.Bills b
                        WHERE b.meterID = mr.meterID_FK
                          AND b.meterReadID = mr.meterReadID
                          AND b.BillActive = 1
                        ORDER BY b.BillsID DESC
                    ) bill
                    LEFT JOIN Housing.BillPeriod period ON period.billPeriodID = bill.CurrentPeriodID
                    WHERE mr.meterID_FK = @parameter_02
                      AND mr.meterReadActive = 1
                    ORDER BY ISNULL(mr.dateOfRead, mr.entryDate) DESC, mr.meterReadID DESC;
                END
                ELSE
                BEGIN
                    SELECT TOP (1)
                           meter.meterID,
                           meter.meterNo,
                           CAST(N'لا يوجد قراءة سابقة' AS NVARCHAR(200)) AS CurrentRead,
                           N' - ' AS periods_,
                           CAST(N'لا يوجد فاتورة سابقة' AS NVARCHAR(200)) AS TotalPrice
                    FROM Housing.Meter meter
                    WHERE meter.meterID = @parameter_02;
                END
            END
            ELSE IF @ActionType = 'MeterNewBill'
            BEGIN
                SELECT
                    CASE WHEN s.LastRead >= s.CurrentRead THEN 0 ELSE 1 END AS checks,
                    s.CurrentRead,
                    s.LastRead,
                    s.ReadDiff,
                    s.PRICE,
                    s.PRICETAX,
                    s.meterServicePrice,
                    s.meterServicePriceTAX,
                    (s.meterServicePrice + s.meterServicePriceTAX) AS ServicePriceWithTAX,
                    s.TotalPrice,
                    s.meterID,
                    s.meterNo,
                    s.CurrentPeriodID
                FROM Housing.CalculteElectrictyBills_ByNewReadValue(@parameter_02, @parameter_04) s;
            END
        END

    -------------------------------------------------------------------
    --                   AllMeterRead
    -------------------------------------------------------------------

         ELSE IF @pageName_ = 'AllMeterRead'
        BEGIN
         IF @ActionType = 'MeterLastBill'
BEGIN

    IF EXISTS
    (
        SELECT 1
        FROM Housing.MeterRead mr
        WHERE mr.meterID_FK = @parameter_02
          AND mr.meterReadActive = 1
    )
    BEGIN
        SELECT TOP (1)
               mr.meterID_FK AS meterID,
               m.meterNo,
               mr.meterReadValue AS CurrentRead,
               ISNULL(bp.billPeriodName_A + N' - ' + CAST(DATEPART(YEAR, bp.billPeriodStartDate) AS NVARCHAR), N' - ') AS periods_,
               ISNULL(b.TotalPrice, 0) AS TotalPrice
        FROM Housing.MeterRead mr
        LEFT JOIN Housing.Meter m
            ON m.meterID = mr.meterID_FK
        LEFT JOIN Housing.Bills b
            ON b.meterReadID = mr.meterReadID
           AND b.BillActive = 1
           AND b.meterServiceTypeID = @parameter_01
           AND b.CurrentPeriodID <> @parameter_03
        LEFT JOIN Housing.BillPeriod bp
            ON bp.BillPeriodID = b.CurrentPeriodID
        WHERE mr.meterID_FK = @parameter_02
          AND mr.meterReadActive = 1
        ORDER BY
            ISNULL(mr.dateOfRead, mr.entryDate) DESC,
            mr.meterReadID DESC;
    END
    ELSE
    BEGIN
        SELECT TOP (1)
               md.meterID,
               md.meterNo,
               CAST(N'لا يوجد قراءة سابقة' AS NVARCHAR(200)) AS CurrentRead,
               N' - ' AS periods_,
               CAST(N'لا يوجد فاتورة سابقة' AS NVARCHAR(200)) AS TotalPrice
        FROM Housing.V_MetersDetails md
        WHERE md.meterID = @parameter_02
          AND md.meterServiceTypeID_FK = @parameter_01;
    END

END
ELSE IF @ActionType = 'MeterNewBill'
BEGIN

    SELECT 
        CASE 
            WHEN s.LastRead > s.CurrentRead THEN 0
            WHEN s.LastRead = s.CurrentRead THEN 0
            ELSE 1
        END AS checks,
        s.CurrentRead,
        s.LastRead,
        s.ReadDiff,
        s.PRICE,
        s.PRICETAX,
        s.meterServicePrice,
        s.meterServicePriceTAX,
        (s.meterServicePrice + s.meterServicePriceTAX) AS ServicePriceWithTAX,
        s.TotalPrice,
        s.meterID,
        s.meterNo,
        s.CurrentPeriodID
    FROM Housing.CalculteElectrictyBills_ByNewReadValue(@parameter_02, @parameter_04) s;

END

ELSE IF @ActionType = 'MeterEditedBill'
BEGIN

    SELECT
        CASE
            WHEN s.LastRead >= s.CurrentRead THEN 0
            ELSE 1
        END AS checks,
        s.CurrentRead,
        s.LastRead,
        s.ReadDiff,
        s.PRICE,
        s.PRICETAX,
        s.meterServicePrice,
        s.meterServicePriceTAX,
        (s.meterServicePrice + s.meterServicePriceTAX) AS ServicePriceWithTAX,
        s.TotalPrice,
        s.meterID,
        s.meterNo,
        s.CurrentPeriodID
    FROM Housing.CalculteElectrictyBills_ByNewReadValue_ForInsert
    (
          TRY_CONVERT(BIGINT, @parameter_01)
        , TRY_CONVERT(INT, @parameter_03)
        , TRY_CONVERT(BIGINT, @parameter_02)
    ) s;

END


            ELSE  IF @ActionType = 'EDITBILL'
            BEGIN


            select b.BillsID,b.meterNo,b.CurrentRead,b.LastRead,b.CurrentPeriodID,b.ReadDiff, b.TotalPrice,mst.meterServiceTypeName_A
            FROM Housing.Bills b
            inner join Housing.MeterServiceType mst on b.meterServiceTypeID = mst.meterServiceTypeID
            where b.BillsID = @parameter_01
            END


        END

        -------------------------------------------------------------------
    --                   AllMeterRead
    -------------------------------------------------------------------

         ELSE IF @pageName_ = 'MeterReadForOccubentAndExit'
        BEGIN
        IF @ActionType = 'MeterLastBill'
BEGIN

    IF EXISTS
    (
        SELECT 1
        FROM Housing.MeterRead mr
        WHERE mr.meterID_FK = @parameter_02
          AND mr.meterReadActive = 1
    )
    BEGIN
        SELECT TOP (1)
               mr.meterID_FK AS meterID,
               m.meterNo,
               mr.meterReadValue AS CurrentRead,
               ISNULL(bp.billPeriodName_A + N' - ' + CAST(DATEPART(YEAR, bp.billPeriodStartDate) AS NVARCHAR), N' - ') AS periods_,
               ISNULL(b.TotalPrice, 0) AS TotalPrice
        FROM Housing.MeterRead mr
        LEFT JOIN Housing.Meter m
            ON m.meterID = mr.meterID_FK
        LEFT JOIN Housing.Bills b
            ON b.meterReadID = mr.meterReadID
           AND b.BillActive = 1
           AND b.meterServiceTypeID = @parameter_01
        LEFT JOIN Housing.BillPeriod bp
            ON bp.BillPeriodID = b.CurrentPeriodID
        WHERE mr.meterID_FK = @parameter_02
          AND mr.meterReadActive = 1
        ORDER BY
            ISNULL(mr.dateOfRead, mr.entryDate) DESC,
            mr.meterReadID DESC;
    END
    ELSE
    BEGIN
        SELECT TOP (1)
               md.meterID,
               md.meterNo,
               CAST(N'لا يوجد قراءة سابقة' AS NVARCHAR(200)) AS CurrentRead,
               N' - ' AS periods_,
               CAST(N'لا يوجد فاتورة سابقة' AS NVARCHAR(200)) AS TotalPrice
        FROM Housing.V_MetersDetails md
        WHERE md.meterID = @parameter_02
          AND md.meterServiceTypeID_FK = @parameter_01;
    END

END
ELSE IF @ActionType = 'MeterNewBill'
BEGIN

    SELECT 
        CASE 
            WHEN s.LastRead > s.CurrentRead THEN 0
            WHEN s.LastRead = s.CurrentRead THEN 0
            ELSE 1
        END AS checks,
        s.CurrentRead,
        s.LastRead,
        s.ReadDiff,
        s.PRICE,
        s.PRICETAX,
        s.meterServicePrice,
        s.meterServicePriceTAX,
        (s.meterServicePrice + s.meterServicePriceTAX) AS ServicePriceWithTAX,
        s.TotalPrice,
        s.meterID,
        s.meterNo,
        s.CurrentPeriodID
    FROM Housing.CalculteElectrictyBills_ByNewReadValue(@parameter_02, @parameter_04) s;

END

ELSE IF @ActionType = 'MeterEditedBill'
BEGIN

    SELECT
        CASE
            WHEN s.LastRead >= s.CurrentRead THEN 0
            ELSE 1
        END AS checks,
        s.CurrentRead,
        s.LastRead,
        s.ReadDiff,
        s.PRICE,
        s.PRICETAX,
        s.meterServicePrice,
        s.meterServicePriceTAX,
        (s.meterServicePrice + s.meterServicePriceTAX) AS ServicePriceWithTAX,
        s.TotalPrice,
        s.meterID,
        s.meterNo,
        s.CurrentPeriodID
    FROM Housing.CalculteElectrictyBills_ByNewReadValue_ForInsert
    (
          TRY_CONVERT(BIGINT, @parameter_01)
        , TRY_CONVERT(INT, @parameter_03)
        , TRY_CONVERT(BIGINT, @parameter_02)
    ) s;

END

            ELSE  IF @ActionType = 'EDITBILL'
            BEGIN


            select b.BillsID,b.meterNo,b.CurrentRead,b.LastRead,b.CurrentPeriodID,b.ReadDiff, b.TotalPrice,mst.meterServiceTypeName_A
            FROM Housing.Bills b
            inner join Housing.MeterServiceType mst on b.meterServiceTypeID = mst.meterServiceTypeID
            where b.BillsID = @parameter_01
            END


        END




         -------------------------------------------------------------------
    --                  ImportExcelForBuildingPayment
    -------------------------------------------------------------------


         ELSE IF @pageName_ = 'ImportExcelForBuildingPayment'
        BEGIN
         IF @ActionType = 'GetBuildingPaymentByDeductList'
            BEGIN

                   SELECT [paymentID]
                        ,[PaymentUID]
                        ,[buildingPaymentTypeID_FK]
                        ,[generalNo_FK]
                        ,[IDNumber]
                        ,[residentInfoID_FK]
                        ,[rankNameA]
                        ,[unitID]
                        ,[userName]
                        ,[buildingDetailsID_FK]
                        ,[amount]
                        ,[deductListID_FK]
                        ,[buildingPayementActive]
                        ,[BillChargeTypeID_FK]
                        ,[IdaraId_FK]
                        ,[entryDate]
                        ,[entryData]
                        ,[hostName]
                    FROM [DATACORE].[Housing].[BuildingPayment] bb
                    where bb.buildingPayementActive = 1 and bb.deductListID_FK = @parameter_01

                
            END
                ELSE  IF @ActionType = 'MeterNewBill'
            BEGIN


            SELECT s.CurrentRead,s.LastRead,s.ReadDiff,s.PRICE,s.PRICETAX,s.meterServicePrice,s.meterServicePriceTAX,(s.meterServicePrice+s.meterServicePriceTAX) ServicePriceWithTAX,s.TotalPrice,s.meterID,s.meterNo,s.CurrentPeriodID
            FROM Housing.CalculteElectrictyBills_ByNewReadValue(@parameter_02, @parameter_04) s;

            END


            ELSE  IF @ActionType = 'EDITBILL'
            BEGIN


            select b.BillsID,b.meterNo,b.CurrentRead,b.LastRead,b.CurrentPeriodID,b.ReadDiff, b.TotalPrice
            FROM Housing.Bills b
            where b.BillsID = @parameter_01
            END


        END




     -------------------------------------------------------------------
    --                  FinancialAuditForExtendAndEvictions
    -------------------------------------------------------------------


         ELSE IF @pageName_ = 'FinancialAuditForUser'
BEGIN

    ------------------------------------------------------------
    -- GENERAL BALANCE - PAYMENT DETAILS
    -- استعراض حركات الرصيد العام للمستفيد حسب نوع الخدمة
    ------------------------------------------------------------

    IF @ActionType = N'GetGeneralBalancePaymentsByResident'
BEGIN
    DECLARE @ResidentID BIGINT =
        TRY_CONVERT(BIGINT, @parameter_01);

    DECLARE @ServiceID INT =
        TRY_CONVERT(INT, @parameter_02);

    DECLARE @FirstOccupancy DATE;
    DECLARE @OldRefunds DECIMAL(38,2) = 0;

    IF @ResidentID IS NULL OR @ServiceID IS NULL
       OR @ResidentID <= 0 OR @ServiceID <= 0
        THROW 50001, N'بيانات الرصيد العام غير صحيحة', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.V_GetFullResidentDetails r
        WHERE r.residentInfoID = @ResidentID
          AND r.IdaraID = @idaraID
    )
        THROW 50001, N'المستفيد خارج نطاق الإدارة', 1;

    SELECT @FirstOccupancy =
        MIN(CONVERT(DATE, a.buildingActionDate))
    FROM Housing.BuildingAction a
    WHERE a.residentInfoID_FK = @ResidentID
      AND a.buildingActionTypeID_FK = 2
      AND a.buildingActionActive = 1
      AND a.buildingActionDate IS NOT NULL;

    -- الإعادات التاريخية السالبة: تُخصم مرة واحدة.
    SELECT @OldRefunds =
        ISNULL(SUM(-CONVERT(DECIMAL(38,2), p.amount)), 0)
    FROM Housing.BuildingPayment p
    INNER JOIN Housing.DeductList d
        ON d.deductListID = p.deductListID_FK
    WHERE p.residentInfoID_FK = @ResidentID
      AND p.BillChargeTypeID_FK = @ServiceID
      AND p.IdaraId_FK = @idaraID
      AND p.buildingPaymentLinkStatusID_FK = 2
      AND p.buildingPayementActive = 1
      AND d.deductActive = 1
      AND p.amount < 0
AND p.UnallocatedRefundID_FK IS NULL
AND (
    p.buildingPaymentTypeID_FK IS NULL
    OR p.buildingPaymentTypeID_FK <> 7
);

    ;WITH HijriMonths AS
    (
        SELECT
            g.yearH,
            g.monthH,
            MIN(CONVERT(DATE, g.gregorianDate)) AS StartDate,
            MAX(CONVERT(DATE, g.gregorianDate)) AS EndDate
        FROM dbo._GregorianHijriDate g
        WHERE g.yearH BETWEEN 1400 AND 1499
        GROUP BY g.yearH, g.monthH
        HAVING COUNT(*) BETWEEN 29 AND 30
           AND COUNT(DISTINCT g.dayH) = COUNT(*)
           AND MIN(g.dayH) = 1
           AND MAX(g.dayH) = COUNT(*)
           AND COUNT(DISTINCT CONVERT(DATE, g.gregorianDate)) = COUNT(*)
           AND DATEDIFF(
                DAY,
                MIN(CONVERT(DATE, g.gregorianDate)),
                MAX(CONVERT(DATE, g.gregorianDate))
           ) + 1 = COUNT(*)
    ),
    PositivePayments AS
    (
        SELECT
            p.paymentID,
            p.residentInfoID_FK AS residentInfoID,
            p.BillChargeTypeID_FK AS BillChargeTypeID,
            d.deductName,
            bt.buildingPaymentTypeName_A,
            d.issueYear,
            d.issueMonth,
            CONVERT(NVARCHAR(10), d.paymentDate, 23) AS paymentDate,
            CONVERT(DECIMAL(38,2), p.amount) AS OriginalAmount,
            dates.ReferenceDate,
            CASE
                WHEN @FirstOccupancy IS NOT NULL
                 AND dates.PeriodEndDate >= @FirstOccupancy
                THEN 1 ELSE 0
            END AS IsEligible
        FROM Housing.BuildingPayment p
        INNER JOIN Housing.DeductList d
            ON d.deductListID = p.deductListID_FK
        LEFT JOIN Housing.BuildingPaymentType bt
            ON bt.buildingPaymentTypeID =
               p.buildingPaymentTypeID_FK
        LEFT JOIN HijriMonths h
            ON h.yearH = d.issueYear
           AND h.monthH = d.issueMonth
        CROSS APPLY
        (
            SELECT
                CASE
                    WHEN d.issueYear BETWEEN 1400 AND 1499
                        THEN h.StartDate
                    WHEN d.issueYear BETWEEN 1900 AND 9999
                     AND d.issueMonth BETWEEN 1 AND 12
                        THEN TRY_CONVERT(DATE, CONCAT(
                            d.issueYear, N'-',
                            RIGHT(N'0' + CONVERT(
                                NVARCHAR(2), d.issueMonth), 2),
                            N'-01'))
                    ELSE CONVERT(DATE, d.paymentDate)
                END AS ReferenceDate,
                CASE
                    WHEN d.issueYear BETWEEN 1400 AND 1499
                        THEN h.EndDate
                    WHEN d.issueYear BETWEEN 1900 AND 9999
                     AND d.issueMonth BETWEEN 1 AND 12
                        THEN EOMONTH(TRY_CONVERT(DATE, CONCAT(
                            d.issueYear, N'-',
                            RIGHT(N'0' + CONVERT(
                                NVARCHAR(2), d.issueMonth), 2),
                            N'-01')))
                    ELSE CONVERT(DATE, d.paymentDate)
                END AS PeriodEndDate
        ) dates
        WHERE p.residentInfoID_FK = @ResidentID
          AND p.BillChargeTypeID_FK = @ServiceID
          AND p.IdaraId_FK = @idaraID
          AND p.buildingPaymentLinkStatusID_FK = 2
          AND p.buildingPayementActive = 1
          AND d.deductActive = 1
          AND p.amount > 0
          AND NULLIF(LTRIM(RTRIM(
              p.buildingDetailsID_FK)), N'') IS NULL
    ),
    OrderedPayments AS
    (
        SELECT
            p.paymentID,
            p.OriginalAmount,
            SUM(p.OriginalAmount) OVER
            (
                ORDER BY p.ReferenceDate, p.paymentID
                ROWS UNBOUNDED PRECEDING
            ) AS RunningGross
        FROM PositivePayments p
        WHERE p.IsEligible = 1
    ),
    LegacyAllocation AS
    (
        SELECT
            o.paymentID,
            CASE
                WHEN @OldRefunds <=
                     o.RunningGross - o.OriginalAmount
                    THEN CONVERT(DECIMAL(38,2), 0)
                WHEN @OldRefunds >= o.RunningGross
                    THEN o.OriginalAmount
                ELSE @OldRefunds -
                     (o.RunningGross - o.OriginalAmount)
            END AS LegacyUsed
        FROM OrderedPayments o
    ),
    NewRefundAllocation AS
(
    SELECT
        rd.PaymentID_FK,
        SUM(
            CONVERT(DECIMAL(38,2), rd.AllocatedAmount)
        ) AS NewRefundUsed
    FROM Housing.UnallocatedPaymentRefundDetail rd
    INNER JOIN Housing.UnallocatedPaymentRefund r
        ON r.RefundID = rd.RefundID_FK
    WHERE r.ResidentInfoID_FK = @ResidentID
      AND r.BillChargeTypeID_FK = @ServiceID
      AND r.IdaraId_FK = @idaraID
      AND r.RefundStatus = 1
    GROUP BY rd.PaymentID_FK
),

-- المبالغ المحولة فعليًا من السداد العام إلى المباني
BuildingAllocation AS
(
    SELECT
        a.SourcePaymentID_FK,
        SUM(
            CONVERT(DECIMAL(38,2), a.AllocatedAmount)
        ) AS BuildingAllocated
    FROM Housing.GeneralBalanceBuildingAllocation a
    WHERE a.ResidentInfoID_FK = @ResidentID
      AND a.BillChargeTypeID_FK = @ServiceID
      AND a.IdaraID_FK = @idaraID
      AND a.AllocationStatus = 1
    GROUP BY a.SourcePaymentID_FK
),

FinalBalance AS
(
    SELECT
        p.*,

        ISNULL(l.LegacyUsed, 0) AS LegacyUsed,

        ISNULL(n.NewRefundUsed, 0) AS NewRefundUsed,

        ISNULL(b.BuildingAllocated, 0) AS BuildingAllocated,

        CASE
            WHEN p.IsEligible = 0
                THEN CONVERT(DECIMAL(38,2), 0)
            ELSE
                p.OriginalAmount
                - ISNULL(l.LegacyUsed, 0)
                - ISNULL(n.NewRefundUsed, 0)
                - ISNULL(b.BuildingAllocated, 0)
        END AS AvailableAmount

    FROM PositivePayments p

    LEFT JOIN LegacyAllocation l
        ON l.paymentID = p.paymentID

    LEFT JOIN NewRefundAllocation n
        ON n.PaymentID_FK = p.paymentID

    LEFT JOIN BuildingAllocation b
        ON b.SourcePaymentID_FK = p.paymentID
)

SELECT
    paymentID,
    residentInfoID,
    BillChargeTypeID,
    deductName,
    buildingPaymentTypeName_A,
    issueYear,
    issueMonth,
    paymentDate,

    OriginalAmount,
    LegacyUsed,
    NewRefundUsed,

    -- العمود الجديد
    BuildingAllocated,

    AvailableAmount,
    IsEligible,

    CASE
        WHEN IsEligible = 0
            THEN N'غير مؤهل للمعالجة'

        WHEN AvailableAmount < 0
            THEN N'تعارض مالي - يتطلب المراجعة'

        WHEN AvailableAmount = 0
            THEN N'تمت المعالجة'

        WHEN AvailableAmount < OriginalAmount
            THEN N'معالج جزئيًا'

        ELSE N'بانتظار المعالجة'

    END AS ProcessingStatus

FROM FinalBalance
ORDER BY paymentID DESC;
END

    ELSE IF @ActionType = 'GetBillsTotalPriceForResident'
    BEGIN

                   
        SELECT 
        r.BillsID,
        r.BillNumber,
        r.TotalPrice,
        r.residentInfoID_FK AS residentInfoID,
        r.BillChargeTypeID_FK AS BillChargeTypeID,
        bct.BillChargeTypeName_A, r.buildingDetailsID,
        b.buildingDetailsNo,
        r.idaraID_FK AS idaraID,
        vgrd.FullName_A
        FROM   Housing.Bills AS r 
        INNER JOIN Housing.BillChargeType AS bct ON r.BillChargeTypeID_FK = bct.BillChargeTypeID
        LEFT JOIN  Housing.V_GetGeneralListForBuilding b on r.buildingDetailsID = b.buildingDetailsID
        LEFT JOIN Housing.V_GetFullResidentDetails AS vgrd ON r.residentInfoID_FK = vgrd.residentInfoID


        WHERE (r.BillActive = 1) 
        and (r.residentInfoID_FK = @parameter_01) 
        and (r.BillChargeTypeID_FK = @parameter_02) 
        and (r.buildingDetailsID = @parameter_03 or r.buildingDetailsID is null) 
        and (r.idaraID_FK = @idaraID)

                
            END
                ELSE  IF @ActionType = 'GetBillsPaidByResident'
            BEGIN


            SELECT 
            bp.amount ,
            bp.residentInfoID_FK AS residentInfoID,
            bp.BillChargeTypeID_FK AS BillChargeTypeID,
            t.BillChargeTypeName_A,
            bp.buildingDetailsID_FK AS buildingDetailsID,
            bd.buildingDetailsNo,
            vgrd.FullName_A,
            d.deductName,
            bt.buildingPaymentTypeName_A
            FROM   Housing.BuildingPayment AS bp INNER JOIN
                         Housing.DeductList AS d ON bp.deductListID_FK = d.deductListID INNER JOIN
                         Housing.BillChargeType AS t ON bp.BillChargeTypeID_FK = t.BillChargeTypeID INNER JOIN
                         Housing.BuildingDetails AS bd ON bp.buildingDetailsID_FK = bd.buildingDetailsID LEFT JOIN
                         Housing.V_GetFullResidentDetails AS vgrd ON bp.residentInfoID_FK = vgrd.residentInfoID LEFT JOIN
                         Housing.BuildingPaymentType bt on bp.buildingPaymentTypeID_FK = bt.buildingPaymentTypeID
                        
            WHERE 
            (d.deductActive = 1) 
            AND (bp.buildingPayementActive = 1) 
            AND(bp.residentInfoID_FK = @parameter_01) 
            AND (bp.BillChargeTypeID_FK = @parameter_02) 
            AND (bp.IdaraId_FK = @idaraID) 
            AND (bp.buildingDetailsID_FK = @parameter_03 or bp.buildingDetailsID_FK is null)


            END


            ELSE  IF @ActionType = 'EDITBILL'
            BEGIN


            select b.BillsID,b.meterNo,b.CurrentRead,b.LastRead,b.CurrentPeriodID,b.ReadDiff, b.TotalPrice
            FROM Housing.Bills b
            where b.BillsID = @parameter_01
            END


            ELSE IF @ActionType = N'GetGeneralBalanceLinkBuildingsByResident'
BEGIN
    DECLARE @LinkResidentID BIGINT =
        TRY_CONVERT(BIGINT, @parameter_01);

    IF @LinkResidentID IS NULL OR @LinkResidentID <= 0
        THROW 50001, N'رقم المستفيد غير صحيح', 1;

    -- حماية نطاق الإدارة
    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.V_GetFullResidentDetails r
        WHERE r.residentInfoID = @LinkResidentID
          AND r.IdaraID = @idaraID
    )
        THROW 50001, N'المستفيد خارج نطاق الإدارة', 1;

    -- المباني النشطة ذات الإشغال الموثق للمستفيد
    SELECT
        b.buildingDetailsID,
        b.buildingDetailsNo
    FROM Housing.BuildingDetails b
    WHERE b.IdaraId_FK = @idaraID
      AND b.buildingDetailsActive = 1
      AND EXISTS
      (
          SELECT 1
          FROM Housing.BuildingAction a
          WHERE a.residentInfoID_FK = @LinkResidentID
            AND a.IdaraId_FK = @idaraID
            AND a.buildingDetailsID_FK = b.buildingDetailsID
            AND a.buildingActionTypeID_FK = 2
            AND a.buildingActionActive = 1
            AND a.buildingActionDate IS NOT NULL
      )
    ORDER BY
        b.buildingDetailsNo,
        b.buildingDetailsID;
END

            -- SQL SERVER / DATACORE / READ-ONLY BRANCH
-- ADD ONLY this ELSE IF branch inside the FIRST/active
-- @pageName_ = N'FinancialAuditForUser' block in dbo.Masters_ExtraDataLoad.
-- Insert it AFTER the END of GetGeneralBalancePaymentsByResident
-- and BEFORE the next ELSE IF @ActionType = 'GetBillsTotalPriceForResident'.
-- Do not execute this fragment standalone; place it into the current live
-- procedure ALTER definition and publish it as a whole.

ELSE IF @ActionType = N'GetGeneralRefundsByPayment'
BEGIN
    DECLARE @SelectedRefundPaymentID BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@parameter_01)), N''));
    DECLARE @SelectedRefundResidentID BIGINT = NULL;
    DECLARE @SelectedRefundServiceID BIGINT = NULL;

    IF @SelectedRefundPaymentID IS NULL OR @SelectedRefundPaymentID <= 0
        THROW 50001, N'رقم السداد المحدد غير صحيح', 1;

    -- The trusted @idaraID must come from the existing gateway/session.
    -- Verify the selected original credit and department before returning rows.
    SELECT
          @SelectedRefundResidentID = p.residentInfoID_FK
        , @SelectedRefundServiceID  = p.BillChargeTypeID_FK
    FROM Housing.BuildingPayment AS p
    INNER JOIN Housing.DeductList AS dd
        ON dd.deductListID = p.deductListID_FK
    WHERE p.paymentID = @SelectedRefundPaymentID
      AND p.IdaraId_FK = @idaraID
      AND p.buildingPayementActive = 1
      AND dd.deductActive = 1
      AND p.buildingPaymentLinkStatusID_FK = 2
      AND p.amount > 0
      AND NULLIF(LTRIM(RTRIM(p.buildingDetailsID_FK)), N'') IS NULL;

    IF @SelectedRefundResidentID IS NULL
       OR @SelectedRefundServiceID IS NULL
       OR NOT EXISTS
       (
           SELECT 1
           FROM Housing.V_GetFullResidentDetails AS resident
           WHERE resident.residentInfoID = @SelectedRefundResidentID
             AND resident.IdaraID = @idaraID
       )
        THROW 50001, N'السداد غير موجود ضمن نطاق الإدارة المصرح بها', 1;

    -- One accordion item per RefundID, NOT per allocation row.
    -- A refund can span multiple original payments. The displayed primary
    -- amount is its allocation to the SELECTED payment; total is separate.
    SELECT
          r.RefundID
        , CONCAT(N'إعادة رقم ', CONVERT(NVARCHAR(30), r.RefundID)) AS AccordionTitle
        , CONVERT(NVARCHAR(10), r.RefundDate, 23) AS RefundDateText
        , CONCAT(CONVERT(NVARCHAR(40),
              CONVERT(DECIMAL(18,2), allocations.AllocatedAmount)), N' ر.س') AS AllocatedAmountText
        , CONCAT(CONVERT(NVARCHAR(40),
              CONVERT(DECIMAL(18,2), r.RefundAmount)), N' ر.س') AS RefundAmountText
        , CASE r.RefundStatus
              WHEN 1 THEN N'مؤكدة'
              WHEN 2 THEN N'ملغاة'
              ELSE N'حالة غير معروفة'
          END AS RefundStatusText
        , CASE r.RefundStatus
              WHEN 1 THEN N'success'
              WHEN 2 THEN N'danger'
              ELSE N'warning'
          END AS RefundStatusTone
        , r.RefundReference
        , r.RefundDetails
        , CONVERT(NVARCHAR(30), @SelectedRefundPaymentID) AS SelectedPaymentID
        , COALESCE(CONVERT(NVARCHAR(30), ledger.paymentID), N'لا يوجد') AS LedgerPaymentIDText
        , CASE
              WHEN r.RefundStatus = 1
               AND ledger.paymentID IS NOT NULL
               AND ledger.amount = -r.RefundAmount
               AND ledger.buildingPayementActive = 1
               AND ledger.buildingPaymentTypeID_FK = 4
               AND ledger.buildingPaymentLinkStatusID_FK = 2
               AND ledger.buildingDetailsID_FK IS NULL
               AND ledger.residentInfoID_FK = r.ResidentInfoID_FK
               AND ledger.BillChargeTypeID_FK = r.BillChargeTypeID_FK
               AND ledger.IdaraId_FK = r.IdaraId_FK
               AND docs.deductActive = 1
                   THEN N'متطابقة'
              WHEN r.RefundStatus = 2
               AND (ledger.paymentID IS NULL OR
                    ledger.buildingPayementActive = 0 OR
                    docs.deductActive = 0)
                   THEN N'ملغاة محاسبيًا'
              ELSE N'تحتاج مراجعة'
          END AS LedgerStatusText
        , COALESCE(NULLIF(r.CancellationReason, N''), N'—') AS CancellationReasonText
    FROM Housing.UnallocatedPaymentRefund AS r
    INNER JOIN
    (
        SELECT
              rd.RefundID_FK
            , SUM(CONVERT(DECIMAL(38,2), rd.AllocatedAmount)) AS AllocatedAmount
        FROM Housing.UnallocatedPaymentRefundDetail AS rd
        WHERE rd.PaymentID_FK = @SelectedRefundPaymentID
        GROUP BY rd.RefundID_FK
    ) AS allocations
        ON allocations.RefundID_FK = r.RefundID
    LEFT JOIN Housing.BuildingPayment AS ledger
        ON ledger.UnallocatedRefundID_FK = r.RefundID
    LEFT JOIN Housing.DeductList AS docs
        ON docs.deductListID = ledger.deductListID_FK
    WHERE r.ResidentInfoID_FK = @SelectedRefundResidentID
      AND r.BillChargeTypeID_FK = @SelectedRefundServiceID
      AND r.IdaraId_FK = @idaraID
      AND r.RefundStatus IN (1, 2)
      

      -- إضافة عمليات ربط الرصيد بالمباني إلى نفس السجل
UNION ALL

SELECT
    -a.AllocationID AS RefundID,

    CONCAT(
        N'ربط رقم ',
        a.AllocationID,
        N' بالمبنى ',
        b.buildingDetailsNo
    ) AS AccordionTitle,

    CONVERT(NVARCHAR(10), a.EntryDate, 23)
        AS RefundDateText,

    CONCAT(
        CONVERT(NVARCHAR(40),
            CONVERT(DECIMAL(18,2), a.AllocatedAmount)),
        N' ر.س'
    ) AS AllocatedAmountText,

    CONCAT(
        CONVERT(NVARCHAR(40),
            CONVERT(DECIMAL(18,2), a.AllocatedAmount)),
        N' ر.س'
    ) AS RefundAmountText,

    CASE a.AllocationStatus
        WHEN 1 THEN N'مرتبطة بمبنى'
        WHEN 2 THEN N'ملغاة'
        ELSE N'تحتاج مراجعة'
    END AS RefundStatusText,

    CASE a.AllocationStatus
        WHEN 1 THEN N'info'
        WHEN 2 THEN N'danger'
        ELSE N'warning'
    END AS RefundStatusTone,

    a.AllocationReference AS RefundReference,

    a.AllocationDetails AS RefundDetails,

    CONVERT(NVARCHAR(30), a.SourcePaymentID_FK)
        AS SelectedPaymentID,

    CONCAT(
        N'خصم: ',
        COALESCE(CONVERT(NVARCHAR(30), debit.paymentID), N'غير موجود'),
        N' / إضافة: ',
        COALESCE(CONVERT(NVARCHAR(30), credit.paymentID), N'غير موجود')
    ) AS LedgerPaymentIDText,

    CASE
        WHEN a.AllocationStatus = 1
         AND debit.amount = -a.AllocatedAmount
         AND credit.amount = a.AllocatedAmount
         AND debit.buildingPaymentTypeID_FK = 7
         AND credit.buildingPaymentTypeID_FK = 7
         AND debit.buildingPaymentLinkStatusID_FK = 2
         AND credit.buildingPaymentLinkStatusID_FK = 1
         AND debit.buildingPayementActive = 1
         AND credit.buildingPayementActive = 1
         AND debit.deductListID_FK = a.DeductListID_FK
         AND credit.deductListID_FK = a.DeductListID_FK
         AND doc.deductActive = 1
         AND TRY_CONVERT(BIGINT, credit.buildingDetailsID_FK)
             = a.TargetBuildingID_FK
        THEN N'متطابقة'

        ELSE N'تحتاج مراجعة'
    END AS LedgerStatusText,

    N'—' AS CancellationReasonText

FROM Housing.GeneralBalanceBuildingAllocation a

INNER JOIN Housing.BuildingDetails b
    ON b.buildingDetailsID = a.TargetBuildingID_FK
   AND b.IdaraId_FK = @idaraID

LEFT JOIN Housing.BuildingPayment debit
    ON debit.paymentID = a.SourceMovementPaymentID_FK

LEFT JOIN Housing.BuildingPayment credit
    ON credit.paymentID = a.TargetMovementPaymentID_FK

LEFT JOIN Housing.DeductList doc
    ON doc.deductListID = a.DeductListID_FK

WHERE a.SourcePaymentID_FK = @SelectedRefundPaymentID
  AND a.ResidentInfoID_FK = @SelectedRefundResidentID
  AND a.BillChargeTypeID_FK = @SelectedRefundServiceID
  AND a.IdaraID_FK = @idaraID
  AND a.AllocationStatus IN (1, 2)

ORDER BY RefundDateText DESC, RefundID DESC;
   -- ORDER BY r.RefundDate DESC, r.RefundID DESC;
END

        END


    -------------------------------------------------------------------
    --                  FinancialAuditForExtendAndEvictions
    -------------------------------------------------------------------


         ELSE IF @pageName_ = 'FinancialAuditForExtendAndEvictions'
        BEGIN
         IF @ActionType = 'GetBillsTotalPriceForResident'
            BEGIN

                   
        SELECT 
        r.BillsID,
        r.BillNumber,
        r.TotalPrice,
        r.residentInfoID_FK AS residentInfoID,
        r.BillChargeTypeID_FK AS BillChargeTypeID,
        bct.BillChargeTypeName_A, r.buildingDetailsID,
        b.buildingDetailsNo,
        r.idaraID_FK AS idaraID,
        vgrd.FullName_A
        FROM   Housing.Bills AS r 
        INNER JOIN Housing.BillChargeType AS bct ON r.BillChargeTypeID_FK = bct.BillChargeTypeID
        LEFT JOIN  Housing.V_GetGeneralListForBuilding b on r.buildingDetailsID = b.buildingDetailsID
        LEFT JOIN Housing.V_GetFullResidentDetails AS vgrd ON r.residentInfoID_FK = vgrd.residentInfoID


        WHERE (r.BillActive = 1) 
        and (r.residentInfoID_FK = @parameter_01) 
        and (r.BillChargeTypeID_FK = @parameter_02) 
        and (r.buildingDetailsID = @parameter_03 or r.buildingDetailsID is null) 
        and (r.idaraID_FK = @idaraID)

                
            END
                ELSE  IF @ActionType = 'GetBillsPaidByResident'
            BEGIN


            SELECT 
            bp.amount ,
            bp.residentInfoID_FK AS residentInfoID,
            bp.BillChargeTypeID_FK AS BillChargeTypeID,
            t.BillChargeTypeName_A,
            bp.buildingDetailsID_FK AS buildingDetailsID,
            bd.buildingDetailsNo,
            vgrd.FullName_A,
            d.deductName,
            bt.buildingPaymentTypeName_A
            
            FROM   Housing.BuildingPayment AS bp INNER JOIN
                         Housing.DeductList AS d ON bp.deductListID_FK = d.deductListID INNER JOIN
                         Housing.BillChargeType AS t ON bp.BillChargeTypeID_FK = t.BillChargeTypeID INNER JOIN
                         Housing.BuildingDetails AS bd ON bp.buildingDetailsID_FK = bd.buildingDetailsID LEFT JOIN
                         Housing.V_GetFullResidentDetails AS vgrd ON bp.residentInfoID_FK = vgrd.residentInfoID LEFT JOIN
                          Housing.BuildingPaymentType bt on bp.buildingPaymentTypeID_FK = bt.buildingPaymentTypeID

            WHERE 
            (d.deductActive = 1) 
            AND (bp.buildingPayementActive = 1) 
            AND(bp.residentInfoID_FK = @parameter_01) 
            AND (bp.BillChargeTypeID_FK = @parameter_02) 
            AND (bp.IdaraId_FK = @idaraID) 
            AND (bp.buildingDetailsID_FK = @parameter_03 or bp.buildingDetailsID_FK is null)


            END


            ELSE  IF @ActionType = 'EDITBILL'
            BEGIN


            select b.BillsID,b.meterNo,b.CurrentRead,b.LastRead,b.CurrentPeriodID,b.ReadDiff, b.TotalPrice
            FROM Housing.Bills b
            where b.BillsID = @parameter_01
            END


        END


          -------------------------------------------------------------------
    --                  FinancialAuditForExtendAndEvictions
    -------------------------------------------------------------------


         ELSE IF @pageName_ = 'WaitingListByResident'
        BEGIN
         IF @ActionType = 'GetWaitingListActions'
            BEGIN

               select b.buildingActionTypeResidentAlias
              ,convert(nvarchar(10),c.entryDate,23)+' '+convert(nvarchar(10),c.entryDate,8) as entryDate
              ,u.FullName
              from [Housing].[fn_BuildingAction_ChainToRoot](@parameter_01) c
              inner join Housing.BuildingActionType b on c.buildingActionTypeID_FK = b.buildingActionTypeID
              inner join dbo.V_GetFullSystemUsersDetails u on right(c.entryData,charindex(',', reverse(c.entryData) + ',') - 1) = u.usersID    
              order by c.entryDate asc
       
            END


            


        END

    -------------------------------------------------------------------
    --                  DeductListReport
    -------------------------------------------------------------------


        ELSE IF @pageName_ = N'DeductListReport'
BEGIN
    IF @ActionType = N'GetDeductListReportDetails'
    BEGIN
        SELECT
              detailRow.DeductListReportDetailsID
            , detailRow.BillNumber
            , detailRow.ResidentFullName_A
            , detailRow.GeneralNo_FK
            , detailRow.MilitaryUnitName_A
            , detailRow.BuildingDetailsNo
            , detailRow.BillsFromDate
            , detailRow.BillsToDate
            , CASE
                WHEN reportRow.BillingType = N'RENT'
                    THEN N'إيجار'
                WHEN calculation.CalculationMethod = N'SPACE_ESTIMATED'
                    THEN N'احتساب بالفراغات'
                WHEN calculation.CalculationMethod = N'METER_READING'
                     OR
                     (
                         calculation.BillCalculationID IS NULL
                         AND bill.meterID IS NOT NULL
                     )
                    THEN N'قراءة عداد'
                WHEN calculation.CalculationMethod = N'METER_FIXED'
                    THEN N'عداد ثابت'
                WHEN calculation.CalculationMethod = N'SERVICE_FIXED_FALLBACK'
                    THEN N'مبلغ ثابت احتياطي'
                ELSE N'غير محدد'
              END AS CalculationMethodName_A
            , detailRow.TotalAmount
        FROM Housing.DeductListReportDetails detailRow
        INNER JOIN Housing.DeductListReport reportRow
            ON reportRow.DeductListReportID =
               detailRow.DeductListReportID_FK
        LEFT JOIN Housing.Bills bill
            ON bill.BillsID = detailRow.BillsID_FK
        LEFT JOIN Housing.BillCalculation calculation
            ON calculation.BillsID_FK = bill.BillsID
        WHERE reportRow.DeductListReportID =
              TRY_CONVERT(BIGINT, @parameter_01)
          AND reportRow.IdaraID_FK = @idaraID
        ORDER BY ISNULL(detailRow.MilitaryUnitName_A,N''), detailRow.GeneralNo_FK, detailRow.DeductListReportDetailsID;
    END

    ELSE IF @ActionType = N'GetDeductListReportPrint'
    BEGIN
        /* الجدول الأول: رأس المسير */
        SELECT
              reportRow.DeductListReportID
            , reportRow.ReportNo
            , reportRow.PeriodYear
            , reportRow.PeriodMonth
            , reportRow.BillingType
            , reportRow.CalculationMethod
            , serviceType.meterServiceTypeName_A
            , reportRow.InvoiceCount
            , reportRow.AmountBeforeTax
            , reportRow.TaxAmount
            , reportRow.TotalAmount
            , idara.idaraLongName_A
        FROM Housing.DeductListReport reportRow
        INNER JOIN dbo.Idara idara
            ON idara.idaraID = reportRow.IdaraID_FK
        LEFT JOIN Housing.MeterServiceType serviceType
            ON serviceType.meterServiceTypeID =
               reportRow.MeterServiceTypeID_FK
        WHERE reportRow.DeductListReportID =
              TRY_CONVERT(BIGINT, @parameter_01)
          AND reportRow.IdaraID_FK = @idaraID;

        /* الجدول الثاني: تفاصيل المسير */
        SELECT
              detailRow.DeductListReportDetailsID
            , detailRow.BillNumber
            , detailRow.ResidentFullName_A
            , detailRow.GeneralNo_FK
            , detailRow.MilitaryUnitName_A
            , detailRow.BuildingDetailsNo
            , detailRow.BillsFromDate
            , detailRow.BillsToDate
            , detailRow.AmountBeforeTax
            , detailRow.TaxAmount
            , detailRow.TotalAmount
        FROM Housing.DeductListReportDetails detailRow
        INNER JOIN Housing.DeductListReport reportRow
            ON reportRow.DeductListReportID =
               detailRow.DeductListReportID_FK
        WHERE reportRow.DeductListReportID =
              TRY_CONVERT(BIGINT, @parameter_01)
          AND reportRow.IdaraID_FK = @idaraID
        ORDER BY ISNULL(detailRow.MilitaryUnitName_A,N''), detailRow.GeneralNo_FK, detailRow.DeductListReportDetailsID;
    END
END





    -------------------------------------------------------------------
    --                  HousingUnallocatedPaymentsReview
    -------------------------------------------------------------------



ELSE IF @pageName_ = N'HousingUnallocatedPaymentsReview'
BEGIN
    IF @ActionType = N'GetUnallocatedPaymentsByResident'
    BEGIN
        SELECT
              bp.paymentID
            , bp.residentInfoID_FK AS residentInfoID
            , bp.BillChargeTypeID_FK AS BillChargeTypeID
            , d.deductName
            , bt.buildingPaymentTypeName_A
            , d.issueYear
            , d.issueMonth
            , CONVERT(NVARCHAR(10), d.paymentDate, 23) AS paymentDate
            , bp.amount
            , CASE WHEN bp.amount < 0 THEN N'استرداد سابق'
                   ELSE N'سداد عام' END AS PaymentMovementText
        FROM Housing.BuildingPayment bp
        INNER JOIN Housing.DeductList d
            ON d.deductListID = bp.deductListID_FK
        LEFT JOIN Housing.BuildingPaymentType bt
            ON bt.buildingPaymentTypeID = bp.buildingPaymentTypeID_FK
        WHERE bp.residentInfoID_FK = TRY_CONVERT(BIGINT, @parameter_01)
          AND bp.BillChargeTypeID_FK = TRY_CONVERT(BIGINT, @parameter_02)
          AND bp.IdaraId_FK = @idaraID
          AND bp.buildingPaymentLinkStatusID_FK = 2
          AND bp.buildingPayementActive = 1
          AND d.deductActive = 1
        ORDER BY bp.paymentID DESC;
    END

        ELSE IF @ActionType = N'GetUnallocatedRefundsByResident'
    BEGIN

        

        SELECT
              r.RefundID
            , r.ResidentInfoID_FK AS residentInfoID
            , r.BillChargeTypeID_FK AS BillChargeTypeID
            , r.RefundAmount
            , CONVERT(NVARCHAR(10), r.RefundDate, 23)
                AS RefundDate
            , r.RefundReference
            , r.RefundDetails
            , r.RefundStatus
            , CASE
                WHEN r.RefundStatus = 1 THEN N'مؤكد'
                WHEN r.RefundStatus = 2 THEN N'ملغى'
                ELSE N'غير معروف'
              END AS RefundStatusText
            , CONVERT(NVARCHAR(19), r.EntryDate, 120)
                AS EntryDate
            , ISNULL(a.AllocationCount, 0)
                AS AllocationCount
            , ISNULL(a.TotalAllocated, 0)
                AS TotalAllocated
            , ISNULL(a.AllocationDetails, N'')
                AS AllocationDetails

        FROM Housing.UnallocatedPaymentRefund r

        OUTER APPLY
        (
            SELECT
                  COUNT(*) AS AllocationCount
                , SUM(d.AllocatedAmount) AS TotalAllocated
                , STRING_AGG
                  (
                      CONVERT
                      (
                          NVARCHAR(MAX),
                          CONCAT
                          (
                              N'الحركة ',
                              d.PaymentID_FK,
                              N' : ',
                              d.AllocatedAmount
                          )
                      ),
                      N'، '
                  ) AS AllocationDetails
            FROM Housing.UnallocatedPaymentRefundDetail d
            WHERE d.RefundID_FK = r.RefundID
        ) a

        WHERE r.ResidentInfoID_FK =
              TRY_CONVERT(BIGINT, @parameter_01)

          AND r.BillChargeTypeID_FK =
              TRY_CONVERT(BIGINT, @parameter_02)

          AND r.IdaraId_FK = @idaraID

        ORDER BY
            r.RefundDate DESC,
            r.RefundID DESC;

    END
END



    -------------------------------------------------------------------
    --                     PAGE NOT FOUND
    --            DO NOT TOUCH DOWN THIS LINE PLEASE
    -------------------------------------------------------------------
        ELSE
        BEGIN
            SELECT 0 AS IsSuccessful, N'الصفحة المرسلة مقيدة. PageName' AS Message_;
        END

        COMMIT TRANSACTION;
    END TRY

    -------------------------------------------------------------------
    --                     CATCH BLOCK
    -------------------------------------------------------------------
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg NVARCHAR(4000), @ErrSeverity INT, @ErrState INT, @IdentityCatchError INT;

        SELECT 
              @ErrMsg      = ERROR_MESSAGE(),
              @ErrSeverity = ERROR_SEVERITY(),
              @ErrState    = ERROR_STATE();

        INSERT INTO DATACORE.dbo.ErrorLog
        (
              ERROR_MESSAGE_
            , ERROR_SEVERITY_
            , ERROR_STATE_
            , SP_NAME
            , entryData
            , hostName
        )
        VALUES
        (
              @ErrMsg
            , @ErrSeverity
            , @ErrState
            , N'[dbo].[Masters_DataLoad]'
            , @entrydata
            , @hostname
        );

        SET @IdentityCatchError = SCOPE_IDENTITY();

        SELECT 
              0 AS IsSuccessful,
              N'حصل خطأ غير معروف رمز الخطأ : ' + CAST(@IdentityCatchError AS NVARCHAR(200)) AS Message_;
    END CATCH
END