CREATE PROCEDURE [Housing].[GenerateFixedServiceBillsForResidentPeriod]
(
      @ResidentInfoID BIGINT
    , @GeneralNo BIGINT
    , @BuildingDetailsID BIGINT
    , @FromDate DATE
    , @ToDate DATE
    , @IdaraID BIGINT
    , @EntryData NVARCHAR(20)
    , @HostName NVARCHAR(200)
    , @MeterServiceTypeID INT = NULL
    , @CalculationMethod NVARCHAR(30) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ResidentInfoID IS NULL OR @BuildingDetailsID IS NULL OR @IdaraID IS NULL
       OR @FromDate IS NULL OR @ToDate IS NULL OR @FromDate > @ToDate
        RETURN;

    DECLARE @TransactionCount INT = @@TRANCOUNT;

    BEGIN TRY
        IF @TransactionCount = 0 BEGIN TRANSACTION;

        DECLARE @ApplicationLockResult INT;
        DECLARE @ApplicationLockResource NVARCHAR(255) =
            CONCAT(N'FIXED_SERVICE_BILLS:', @IdaraID, N':', @ResidentInfoID, N':', @BuildingDetailsID);
        EXEC @ApplicationLockResult = sys.sp_getapplock
              @Resource = @ApplicationLockResource
            , @LockMode = N'Exclusive'
            , @LockOwner = N'Transaction'
            , @LockTimeout = 15000;

        IF @ApplicationLockResult < 0
        BEGIN
            ;THROW 50001, N'تعذر حجز عملية رصد الخدمات الثابتة، يرجى المحاولة مرة أخرى', 1;
        END;

        CREATE TABLE #ExistingFixedBills
        (
              BillChargeTypeID_FK INT NOT NULL
            , meterServiceTypeID INT NOT NULL
            , meterID BIGINT NULL
            , BillFromDate DATE NOT NULL
            , BillToDate DATE NOT NULL
        );

        INSERT INTO #ExistingFixedBills
        (
              BillChargeTypeID_FK, meterServiceTypeID, meterID, BillFromDate, BillToDate
        )
        SELECT
              existingBill.BillChargeTypeID_FK
            , existingBill.meterServiceTypeID
            , existingBill.meterID
            , billDate.BillFromDate
            , billDate.BillToDate
        FROM Housing.Bills existingBill
        CROSS APPLY
        (
            SELECT
                  COALESCE
                  (
                      CAST(existingBill.BillsFromDate AS date),
                      CASE WHEN existingBill.PeriodYear BETWEEN 1753 AND 9999
                             AND existingBill.PeriodMonth BETWEEN 1 AND 12
                           THEN DATEFROMPARTS(existingBill.PeriodYear, existingBill.PeriodMonth, 1) END
                  ) AS BillFromDate
                , COALESCE
                  (
                      CAST(existingBill.BillsToDate AS date),
                      CASE WHEN existingBill.PeriodYear BETWEEN 1753 AND 9999
                             AND existingBill.PeriodMonth BETWEEN 1 AND 12
                           THEN EOMONTH(DATEFROMPARTS(existingBill.PeriodYear, existingBill.PeriodMonth, 1)) END
                  ) AS BillToDate
        ) billDate
        WHERE existingBill.residentInfoID_FK = @ResidentInfoID
          AND existingBill.buildingDetailsID = @BuildingDetailsID
          AND existingBill.idaraID_FK = @IdaraID
          AND existingBill.BillActive = 1
          AND existingBill.meterServiceTypeID IS NOT NULL
          AND existingBill.BillChargeTypeID_FK IS NOT NULL
          AND billDate.BillFromDate <= @ToDate
          AND billDate.BillToDate >= @FromDate;

        CREATE INDEX IX_ExistingFixedBills_Lookup
            ON #ExistingFixedBills
               (BillChargeTypeID_FK, meterServiceTypeID, meterID, BillFromDate, BillToDate);

        DECLARE @InsertedBills TABLE
        (
              BillsID BIGINT NOT NULL
            , meterID INT NULL
            , BillsFromDate DATE NOT NULL
            , BillsToDate DATE NOT NULL
            , TaxRatePercent DECIMAL(18,6) NOT NULL
            , AmountBeforeTax DECIMAL(18,2) NOT NULL
            , TaxAmount DECIMAL(18,2) NOT NULL
            , TotalAmount DECIMAL(18,2) NOT NULL
        );

        ;WITH CalendarDays AS
        (
            SELECT @FromDate AS BillDay
            UNION ALL
            SELECT DATEADD(DAY, 1, BillDay)
            FROM CalendarDays
            WHERE BillDay < @ToDate
        ),
        EligibleServiceDays AS
        (
            SELECT
                  dayRow.BillDay
                , building.buildingDetailsID
                , building.buildingDetailsNo
                , building.buildingUtilityTypeID_FK
                , serviceType.meterServiceTypeID
                , chargeType.BillChargeTypeID
            FROM CalendarDays dayRow
            JOIN Housing.BuildingDetails building
              ON building.buildingDetailsID = @BuildingDetailsID
             AND building.IdaraId_FK = @IdaraID
             AND (building.buildingDetailsStartDate IS NULL OR CAST(building.buildingDetailsStartDate AS date) <= dayRow.BillDay)
             AND (building.buildingDetailsEndDate IS NULL OR CAST(building.buildingDetailsEndDate AS date) >= dayRow.BillDay)
            JOIN Housing.MeterServiceType serviceType
              ON serviceType.meterServiceTypeActive = 1
             AND (@MeterServiceTypeID IS NULL OR serviceType.meterServiceTypeID = @MeterServiceTypeID)
            JOIN Housing.MeterServiceTypeLinkedWithIdara serviceLink
              ON serviceLink.MeterServiceTypeID_FK = serviceType.meterServiceTypeID
             AND serviceLink.Idara_FK = @IdaraID
             AND (serviceLink.MeterServiceTypeLinkedWithIdaraActive = 1 OR serviceLink.MeterServiceTypeLinkedWithIdaraEndDate IS NOT NULL)
             AND (serviceLink.MeterServiceTypeLinkedWithIdaraStartDate IS NULL OR CAST(serviceLink.MeterServiceTypeLinkedWithIdaraStartDate AS date) <= dayRow.BillDay)
             AND (serviceLink.MeterServiceTypeLinkedWithIdaraEndDate IS NULL OR CAST(serviceLink.MeterServiceTypeLinkedWithIdaraEndDate AS date) >= dayRow.BillDay)
            JOIN Housing.BillChargeType chargeType
              ON chargeType.MeterServiceTypeID_FK = serviceType.meterServiceTypeID
             AND chargeType.BillChargeTypeActive = 1
        ),
        ServiceWithoutMeterDays AS
        (
            SELECT
                  serviceDay.*
                , CAST(NULL AS BIGINT) AS meterID
                , CAST(NULL AS INT) AS meterTypeID
                , CAST(NULL AS NVARCHAR(100)) AS meterNo
                , CAST(NULL AS NVARCHAR(200)) AS meterName_A
                , fixedAmount.FixedAmount
                , N'SERVICE' AS SourceKind
            FROM EligibleServiceDays serviceDay
            CROSS APPLY
            (
                SELECT TOP (1) amountRow.FixedAmount
                FROM Housing.MeterServiceTypeFixedAmount amountRow
                WHERE amountRow.MeterServiceTypeID_FK = serviceDay.meterServiceTypeID
                  AND (amountRow.idaraID_FK = @IdaraID OR amountRow.idaraID_FK IS NULL)
                  AND (amountRow.MeterServiceTypeFixedAmountActive = 1 OR amountRow.MeterServiceTypeFixedAmountEndDate IS NOT NULL)
                  AND ISNULL(amountRow.FixedAmount, 0) > 0
                  AND (amountRow.MeterServiceTypeFixedAmountStartDate IS NULL OR CAST(amountRow.MeterServiceTypeFixedAmountStartDate AS date) <= serviceDay.BillDay)
                  AND (amountRow.MeterServiceTypeFixedAmountEndDate IS NULL OR CAST(amountRow.MeterServiceTypeFixedAmountEndDate AS date) >= serviceDay.BillDay)
                ORDER BY
                      CASE WHEN amountRow.idaraID_FK = @IdaraID THEN 0 ELSE 1 END
                    , amountRow.MeterServiceTypeFixedAmountStartDate DESC
                    , amountRow.MeterServiceTypeFixedAmountID DESC
            ) fixedAmount
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM Housing.MeterForBuilding meterLink
                JOIN Housing.Meter meter ON meter.meterID = meterLink.meterID_FK
                JOIN Housing.MeterType meterType ON meterType.meterTypeID = meter.meterTypeID_FK
                WHERE meterLink.buildingDetailsID_FK = serviceDay.buildingDetailsID
                  AND meterLink.IdaraID_FK = @IdaraID
                  AND meterType.meterServiceTypeID_FK = serviceDay.meterServiceTypeID
                  AND meterType.MeterCalculateTypeID_FK IN (1, 2)
                  AND (meterLink.meterForBuildingStartDate IS NULL OR CAST(meterLink.meterForBuildingStartDate AS date) <= serviceDay.BillDay)
                  AND (meterLink.meterForBuildingEndDate IS NULL OR CAST(meterLink.meterForBuildingEndDate AS date) >= serviceDay.BillDay)
                  AND (meter.meterStartDate IS NULL OR CAST(meter.meterStartDate AS date) <= serviceDay.BillDay)
                  AND (meter.meterEndDate IS NULL OR CAST(meter.meterEndDate AS date) >= serviceDay.BillDay)
                  AND (meterType.meterTypeStartDate IS NULL OR CAST(meterType.meterTypeStartDate AS date) <= serviceDay.BillDay)
                  AND (meterType.meterTypeEndDate IS NULL OR CAST(meterType.meterTypeEndDate AS date) >= serviceDay.BillDay)
            )
              AND EXISTS
              (
                  SELECT 1
                  FROM Housing.BuildingDetailsMeterServices buildingService
                  WHERE buildingService.BuildingDetailsID_FK = serviceDay.buildingDetailsID
                    AND buildingService.IdaraId_FK = @IdaraID
                    AND buildingService.MeterServicesTypeID_FK = serviceDay.meterServiceTypeID
                    AND (buildingService.BuildingDetailsMeterServicesActive = 1
                         OR buildingService.BuildingDetailsMeterServicesEndDate IS NOT NULL)
                    AND (buildingService.BuildingDetailsMeterServicesStartDate IS NULL
                         OR CAST(buildingService.BuildingDetailsMeterServicesStartDate AS date) <= serviceDay.BillDay)
                    AND (buildingService.BuildingDetailsMeterServicesEndDate IS NULL
                         OR CAST(buildingService.BuildingDetailsMeterServicesEndDate AS date) >= serviceDay.BillDay)
              )
              AND (@CalculationMethod IS NULL OR @CalculationMethod = N'SERVICE_FIXED')
        ),
        FixedMeterDays AS
        (
            SELECT
                  serviceDay.*
                , meter.meterID
                , meterType.meterTypeID
                , meter.meterNo
                , meter.meterName_A
                , fixedAmount.FixedAmount
                , N'METER' AS SourceKind
            FROM EligibleServiceDays serviceDay
            JOIN Housing.MeterForBuilding meterLink
              ON meterLink.buildingDetailsID_FK = serviceDay.buildingDetailsID
             AND meterLink.IdaraID_FK = @IdaraID
             AND (meterLink.meterForBuildingStartDate IS NULL OR CAST(meterLink.meterForBuildingStartDate AS date) <= serviceDay.BillDay)
             AND (meterLink.meterForBuildingEndDate IS NULL OR CAST(meterLink.meterForBuildingEndDate AS date) >= serviceDay.BillDay)
            JOIN Housing.Meter meter
              ON meter.meterID = meterLink.meterID_FK
             AND (meter.meterStartDate IS NULL OR CAST(meter.meterStartDate AS date) <= serviceDay.BillDay)
             AND (meter.meterEndDate IS NULL OR CAST(meter.meterEndDate AS date) >= serviceDay.BillDay)
            JOIN Housing.MeterType meterType
              ON meterType.meterTypeID = meter.meterTypeID_FK
             AND meterType.meterServiceTypeID_FK = serviceDay.meterServiceTypeID
             AND meterType.MeterCalculateTypeID_FK = 2
             AND meterType.IdaraId_FK = @IdaraID
             AND (meterType.meterTypeStartDate IS NULL OR CAST(meterType.meterTypeStartDate AS date) <= serviceDay.BillDay)
             AND (meterType.meterTypeEndDate IS NULL OR CAST(meterType.meterTypeEndDate AS date) >= serviceDay.BillDay)
            CROSS APPLY
            (
                SELECT TOP (1) amountRow.FixedAmount
                FROM Housing.MeterTypeFixedAmount amountRow
                WHERE amountRow.MeterTypeID_FK = meterType.meterTypeID
                  AND amountRow.idaraID_FK = @IdaraID
                  AND (amountRow.MeterTypeFixedAmountActive = 1 OR amountRow.MeterTypeFixedAmountEndDate IS NOT NULL)
                  AND ISNULL(amountRow.FixedAmount, 0) > 0
                  AND (amountRow.MeterTypeFixedAmountStartDate IS NULL OR CAST(amountRow.MeterTypeFixedAmountStartDate AS date) <= serviceDay.BillDay)
                  AND (amountRow.MeterTypeFixedAmountEndDate IS NULL OR CAST(amountRow.MeterTypeFixedAmountEndDate AS date) >= serviceDay.BillDay)
                ORDER BY amountRow.MeterTypeFixedAmountStartDate DESC, amountRow.MeterTypeFixedAmountID DESC
            ) fixedAmount
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM Housing.MeterForBuilding readLink
                JOIN Housing.Meter readMeter ON readMeter.meterID = readLink.meterID_FK
                JOIN Housing.MeterType readType ON readType.meterTypeID = readMeter.meterTypeID_FK
                WHERE readLink.buildingDetailsID_FK = serviceDay.buildingDetailsID
                  AND readLink.IdaraID_FK = @IdaraID
                  AND readType.meterServiceTypeID_FK = serviceDay.meterServiceTypeID
                  AND readType.MeterCalculateTypeID_FK = 1
                  AND (readLink.meterForBuildingStartDate IS NULL OR CAST(readLink.meterForBuildingStartDate AS date) <= serviceDay.BillDay)
                  AND (readLink.meterForBuildingEndDate IS NULL OR CAST(readLink.meterForBuildingEndDate AS date) >= serviceDay.BillDay)
                  AND (readMeter.meterStartDate IS NULL OR CAST(readMeter.meterStartDate AS date) <= serviceDay.BillDay)
                  AND (readMeter.meterEndDate IS NULL OR CAST(readMeter.meterEndDate AS date) >= serviceDay.BillDay)
            )
              AND (@CalculationMethod IS NULL OR @CalculationMethod = N'METER_FIXED')
        ),
        SourceDays AS
        (
            SELECT * FROM ServiceWithoutMeterDays
            UNION ALL
            SELECT * FROM FixedMeterDays
        ),
        MissingDays AS
        (
            SELECT sourceDay.*, ISNULL(taxRate.taxRate, 0) AS TaxRate
            FROM SourceDays sourceDay
            OUTER APPLY
            (
                SELECT TOP (1) tax.taxRate
                FROM dbo.Tax tax
                WHERE sourceDay.BillDay >= CAST(tax.taxStartDate AS date)
                  AND (tax.taxEndDate IS NULL OR sourceDay.BillDay <= CAST(tax.taxEndDate AS date))
                ORDER BY tax.taxStartDate DESC
            ) taxRate
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM #ExistingFixedBills existingBill
                WHERE 1 = 1
                  AND existingBill.meterServiceTypeID = sourceDay.meterServiceTypeID
                  AND existingBill.BillChargeTypeID_FK = sourceDay.BillChargeTypeID
                  AND ((sourceDay.SourceKind = N'SERVICE' AND existingBill.meterID IS NULL)
                       OR (sourceDay.SourceKind = N'METER' AND existingBill.meterID = sourceDay.meterID))
                  AND existingBill.BillFromDate <= sourceDay.BillDay
                  AND existingBill.BillToDate >= sourceDay.BillDay
            )
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM Housing.Bills estimatedBill
                  JOIN Housing.BillCalculation calculation
                    ON calculation.BillsID_FK = estimatedBill.BillsID
                   AND calculation.CalculationMethod = N'SPACE_ESTIMATED'
                  WHERE estimatedBill.residentInfoID_FK = @ResidentInfoID
                    AND estimatedBill.buildingDetailsID = @BuildingDetailsID
                    AND estimatedBill.idaraID_FK = @IdaraID
                    AND estimatedBill.meterServiceTypeID = sourceDay.meterServiceTypeID
                    AND estimatedBill.BillActive = 1
                    AND CONVERT(date, estimatedBill.BillsFromDate) <= sourceDay.BillDay
                    AND CONVERT(date, estimatedBill.BillsToDate) >= sourceDay.BillDay
              )
        ),
        NumberedDays AS
        (
            SELECT missingDay.*,
                   DATEADD(DAY, -ROW_NUMBER() OVER
                   (
                       PARTITION BY YEAR(BillDay), MONTH(BillDay), SourceKind, meterServiceTypeID,
                                    ISNULL(meterID, -1), FixedAmount, TaxRate
                       ORDER BY BillDay
                   ), BillDay) AS IslandKey
            FROM MissingDays missingDay
        ),
        BillSegments AS
        (
            SELECT
                  MIN(BillDay) AS BillFromDate
                , MAX(BillDay) AS BillToDate
                , buildingDetailsID, MAX(buildingDetailsNo) AS buildingDetailsNo
                , MAX(buildingUtilityTypeID_FK) AS buildingUtilityTypeID_FK
                , meterServiceTypeID, BillChargeTypeID, meterID, meterTypeID
                , MAX(meterNo) AS meterNo, MAX(meterName_A) AS meterName_A
                , FixedAmount, TaxRate, SourceKind
            FROM NumberedDays
            GROUP BY YEAR(BillDay), MONTH(BillDay), SourceKind, meterServiceTypeID,
                     BillChargeTypeID, meterID, meterTypeID, FixedAmount, TaxRate, IslandKey, buildingDetailsID
        )
        INSERT INTO Housing.Bills
        (
              BillsUID, BillChargeTypeID_FK, BillTypeID_FK, CurrentPeriodID
            , PeriodMonth, PeriodYear, CurrentPeriodTax
            , meterNo, meterID, meterName_A, buildingDetailsNo, buildingUtilityTypeID, buildingDetailsID
            , meterTypeID, meterServiceTypeID, residentInfoID_FK, generalNo_FK
            , CurrentRead, LastRead, ReadDiff, PRICE, PRICETAX, meterServicePrice, meterServicePriceTAX, TotalPrice
            , BillsFromDate, BillsToDate, BillActive, idaraID_FK, entryDate, entryData, hostName
        )
        OUTPUT inserted.BillsID, inserted.meterID, inserted.BillsFromDate, inserted.BillsToDate,
               inserted.CurrentPeriodTax, inserted.PRICE, inserted.PRICETAX, inserted.TotalPrice
        INTO @InsertedBills
        SELECT
              NEWID(), segment.BillChargeTypeID, 2, periodRow.billPeriodID
            , MONTH(segment.BillFromDate), YEAR(segment.BillFromDate), segment.TaxRate
            , segment.meterNo, segment.meterID, segment.meterName_A, segment.buildingDetailsNo
            , segment.buildingUtilityTypeID_FK, segment.buildingDetailsID, segment.meterTypeID
            , segment.meterServiceTypeID, @ResidentInfoID, @GeneralNo
            , 0, 0, 0, amount.ChargeAmount
            , CAST(amount.ChargeAmount * segment.TaxRate / 100.0 AS decimal(18,2)), 0, 0
            , CAST(amount.ChargeAmount * (1 + segment.TaxRate / 100.0) AS decimal(18,2))
            , segment.BillFromDate, segment.BillToDate, 1, @IdaraID, GETDATE(), @EntryData, @HostName
        FROM BillSegments segment
        CROSS APPLY
        (
            SELECT CAST(segment.FixedAmount *
            (
                ((YEAR(segment.BillToDate) - YEAR(segment.BillFromDate)) * 360
                 + (MONTH(segment.BillToDate) - MONTH(segment.BillFromDate)) * 30
                 + (CASE WHEN segment.BillToDate = EOMONTH(segment.BillToDate) AND DAY(segment.BillToDate) < 30 THEN 30 WHEN DAY(segment.BillToDate) > 30 THEN 30 ELSE DAY(segment.BillToDate) END)
                 - (CASE WHEN segment.BillFromDate = EOMONTH(segment.BillFromDate) AND DAY(segment.BillFromDate) < 30 THEN 30 WHEN DAY(segment.BillFromDate) > 30 THEN 30 ELSE DAY(segment.BillFromDate) END)) + 1
            ) / 30.00 AS decimal(18,2)) AS ChargeAmount
        ) amount
        OUTER APPLY
        (
            SELECT TOP (1) period.billPeriodID
            FROM Housing.BillPeriodType periodType
            JOIN Housing.BillPeriod period ON period.billPeriodTypeID_FK = periodType.billPeriodTypeID
                                         AND period.IdaraId_FK = @IdaraID
            WHERE periodType.meterServiceTypeID_FK = segment.meterServiceTypeID
              AND period.billPeriodStartDate <= segment.BillToDate
              AND period.billPeriodEndDate >= segment.BillFromDate
            ORDER BY period.billPeriodID DESC
        ) periodRow
        OPTION (MAXRECURSION 32767);

        INSERT Housing.BillCalculation
        (
              BillsID_FK, CalculationMethod, EstimatedBillingPolicyID_FK, BillingDays
            , TaxApplicable, TaxInclusive, TaxID_FK, TaxRate
            , AmountBeforeTax, TaxAmount, TotalAmount, CalculationReason
            , entryData, hostName
        )
        SELECT
              insertedBill.BillsID
            , CASE WHEN insertedBill.meterID IS NULL THEN N'SERVICE_FIXED_FALLBACK' ELSE N'METER_FIXED' END
            , NULL
            , ((YEAR(insertedBill.BillsToDate) - YEAR(insertedBill.BillsFromDate)) * 360
               + (MONTH(insertedBill.BillsToDate) - MONTH(insertedBill.BillsFromDate)) * 30
               + (CASE
                      WHEN insertedBill.BillsToDate = EOMONTH(insertedBill.BillsToDate) AND DAY(insertedBill.BillsToDate) < 30 THEN 30
                      WHEN DAY(insertedBill.BillsToDate) > 30 THEN 30
                      ELSE DAY(insertedBill.BillsToDate)
                  END)
               - (CASE
                      WHEN insertedBill.BillsFromDate = EOMONTH(insertedBill.BillsFromDate) AND DAY(insertedBill.BillsFromDate) < 30 THEN 30
                      WHEN DAY(insertedBill.BillsFromDate) > 30 THEN 30
                      ELSE DAY(insertedBill.BillsFromDate)
                  END)
               + 1)
            , 1, 0, taxRow.taxID, insertedBill.TaxRatePercent / 100.0
            , insertedBill.AmountBeforeTax, insertedBill.TaxAmount, insertedBill.TotalAmount
            , CASE WHEN insertedBill.meterID IS NULL
                   THEN N'تم الرجوع إلى المبلغ الثابت للخدمة لعدم وجود فراغات مطابقة لسياسة الحسبة'
                   ELSE N'تم الاحتساب بالمبلغ الثابت للعداد'
              END
            , @EntryData, @HostName
        FROM @InsertedBills insertedBill
        OUTER APPLY
        (
            SELECT TOP (1) tax.taxID
            FROM dbo.Tax tax
            WHERE tax.taxActive = 1
              AND CONVERT(date, tax.taxStartDate) <= insertedBill.BillsToDate
              AND (tax.taxEndDate IS NULL OR CONVERT(date, tax.taxEndDate) >= insertedBill.BillsFromDate)
            ORDER BY tax.taxStartDate DESC, tax.taxID DESC
        ) taxRow;

        IF @TransactionCount = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @TransactionCount = 0 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
