CREATE PROCEDURE [Housing].[GenerateEstimatedServiceBillForResidentPeriod]
(
      @ResidentInfoID BIGINT
    , @GeneralNo BIGINT
    , @BuildingDetailsID BIGINT
    , @FromDate DATE
    , @ToDate DATE
    , @IdaraID BIGINT
    , @EntryData NVARCHAR(20)
    , @HostName NVARCHAR(200)
    , @MeterServiceTypeID INT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ResidentInfoID IS NULL OR @BuildingDetailsID IS NULL OR @IdaraID IS NULL
       OR @MeterServiceTypeID IS NULL OR @FromDate IS NULL OR @ToDate IS NULL OR @FromDate > @ToDate
        RETURN;

    /* A previously issued bill, including a metered-reading bill, has first priority. */
    IF EXISTS
    (
        SELECT 1
        FROM Housing.Bills bill
        WHERE bill.residentInfoID_FK = @ResidentInfoID
          AND bill.buildingDetailsID = @BuildingDetailsID
          AND bill.idaraID_FK = @IdaraID
          AND bill.meterServiceTypeID = @MeterServiceTypeID
          AND bill.BillActive = 1
          AND CONVERT(date, bill.BillsFromDate) <= @ToDate
          AND CONVERT(date, bill.BillsToDate) >= @FromDate
    ) RETURN;

    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.BuildingDetailsMeterServices service
        WHERE service.BuildingDetailsID_FK = @BuildingDetailsID
          AND service.IdaraId_FK = @IdaraID
          AND service.MeterServicesTypeID_FK = @MeterServiceTypeID
          AND (service.BuildingDetailsMeterServicesActive = 1 OR service.BuildingDetailsMeterServicesEndDate IS NOT NULL)
          AND (service.BuildingDetailsMeterServicesStartDate IS NULL OR CONVERT(date, service.BuildingDetailsMeterServicesStartDate) <= @ToDate)
          AND (service.BuildingDetailsMeterServicesEndDate IS NULL OR CONVERT(date, service.BuildingDetailsMeterServicesEndDate) >= @FromDate)
    ) RETURN;

    /* A building linked to a billed meter must always be billed from readings. */
    IF EXISTS
    (
        SELECT 1
        FROM Housing.MeterForBuilding meterLink
        JOIN Housing.Meter meter
          ON meter.meterID = meterLink.meterID_FK
        JOIN Housing.MeterType meterType
          ON meterType.meterTypeID = meter.meterTypeID_FK
        WHERE meterLink.buildingDetailsID_FK = @BuildingDetailsID
          AND meterLink.IdaraID_FK = @IdaraID
          AND meterType.meterServiceTypeID_FK = @MeterServiceTypeID
          AND meterType.MeterCalculateTypeID_FK = 1
          AND (meterLink.meterForBuildingStartDate IS NULL OR CONVERT(date, meterLink.meterForBuildingStartDate) <= @ToDate)
          AND (meterLink.meterForBuildingEndDate IS NULL OR CONVERT(date, meterLink.meterForBuildingEndDate) >= @FromDate)
          AND (meter.meterStartDate IS NULL OR CONVERT(date, meter.meterStartDate) <= @ToDate)
          AND (meter.meterEndDate IS NULL OR CONVERT(date, meter.meterEndDate) >= @FromDate)
    ) RETURN;

    DECLARE @PolicyID BIGINT, @TaxApplicable BIT, @TaxInclusive BIT;
    SELECT TOP (1)
          @PolicyID = policy.EstimatedBillingPolicyID
        , @TaxApplicable = policy.TaxApplicable
        , @TaxInclusive = policy.TaxInclusive
    FROM Housing.EstimatedBillingPolicy policy
    WHERE policy.EstimatedBillingPolicyActive = 1
      AND (policy.IdaraID_FK = @IdaraID OR policy.IdaraID_FK IS NULL)
      AND policy.EffectiveFrom <= @ToDate
      AND (policy.EffectiveTo IS NULL OR policy.EffectiveTo >= @FromDate)
    ORDER BY CASE WHEN policy.IdaraID_FK = @IdaraID THEN 0 ELSE 1 END,
             policy.EffectiveFrom DESC, policy.EstimatedBillingPolicyID DESC;

    IF @PolicyID IS NULL RETURN;

    DECLARE @BillingDays INT =
    (
          (YEAR(@ToDate) - YEAR(@FromDate)) * 360
        + (MONTH(@ToDate) - MONTH(@FromDate)) * 30
        + CASE
              WHEN @ToDate = EOMONTH(@ToDate) AND DAY(@ToDate) < 30 THEN 30
              WHEN DAY(@ToDate) > 30 THEN 30
              ELSE DAY(@ToDate)
          END
        - CASE
              WHEN @FromDate = EOMONTH(@FromDate) AND DAY(@FromDate) < 30 THEN 30
              WHEN DAY(@FromDate) > 30 THEN 30
              ELSE DAY(@FromDate)
          END
        + 1
    );

    DECLARE @TaxID INT = NULL, @TaxRatePercent DECIMAL(18,6) = 0, @TaxRate DECIMAL(9,6) = 0;
    IF @TaxApplicable = 1
    BEGIN
        SELECT TOP (1) @TaxID = tax.taxID, @TaxRatePercent = ISNULL(tax.taxRate, 0)
        FROM dbo.Tax tax
        WHERE tax.taxActive = 1
          AND CONVERT(date, tax.taxStartDate) <= @ToDate
          AND (tax.taxEndDate IS NULL OR CONVERT(date, tax.taxEndDate) >= @FromDate)
        ORDER BY tax.taxStartDate DESC, tax.taxID DESC;

        SET @TaxRate = @TaxRatePercent / 100.0;
    END;

    CREATE TABLE #Details
    (
          BuildingSpaceTypeID INT NOT NULL
        , SpaceTypeCode NVARCHAR(50) NULL
        , SpaceTypeName_A NVARCHAR(100) NULL
        , SpaceCount INT NOT NULL
        , AverageDailyConsumption DECIMAL(18,6) NOT NULL
        , UsageFactor DECIMAL(18,6) NOT NULL
        , UnitPrice DECIMAL(18,6) NOT NULL
        , UnitCode NVARCHAR(30) NOT NULL
        , RawAmount DECIMAL(18,6) NOT NULL
        , AmountBeforeTax DECIMAL(18,2) NOT NULL
        , TaxAmount DECIMAL(18,2) NOT NULL
        , TotalAmount DECIMAL(18,2) NOT NULL
    );

    ;WITH SpaceCounts AS
    (
        SELECT space.BuildingSpaceTypeID_FK, COUNT(*) SpaceCount
        FROM Housing.BuildingSpace space
        WHERE space.BuildingDetailsID_FK = @BuildingDetailsID
          AND space.BuildingSpaceActive = 1
          AND (space.BuildingSpaceStartDate IS NULL OR space.BuildingSpaceStartDate <= @ToDate)
          AND (space.BuildingSpaceEndDate IS NULL OR space.BuildingSpaceEndDate >= @FromDate)
        GROUP BY space.BuildingSpaceTypeID_FK
    )
    INSERT #Details
    SELECT
          spaceType.BuildingSpaceTypeID
        , spaceType.BuildingSpaceTypeCode
        , spaceType.BuildingSpaceTypeName_A
        , spaces.SpaceCount
        , policyDetail.AverageDailyConsumption
        , policyDetail.UsageFactor
        , policyDetail.UnitPrice
        , policyDetail.UnitCode
        , amount.RawAmount
        , calculated.AmountBeforeTax
        , calculated.TaxAmount
        , calculated.TotalAmount
    FROM SpaceCounts spaces
    JOIN Housing.BuildingSpaceType spaceType
      ON spaceType.BuildingSpaceTypeID = spaces.BuildingSpaceTypeID_FK
     AND spaceType.BuildingSpaceTypeActive = 1
    JOIN Housing.EstimatedBillingPolicyDetails policyDetail
      ON policyDetail.EstimatedBillingPolicyID_FK = @PolicyID
     AND policyDetail.MeterServiceTypeID_FK = @MeterServiceTypeID
     AND policyDetail.BuildingSpaceTypeID_FK = spaces.BuildingSpaceTypeID_FK
     AND policyDetail.EstimatedBillingPolicyDetailsActive = 1
    CROSS APPLY
    (
        SELECT CAST(spaces.SpaceCount * policyDetail.AverageDailyConsumption * policyDetail.UsageFactor * policyDetail.UnitPrice * @BillingDays AS DECIMAL(18,6)) RawAmount
    ) amount
    CROSS APPLY
    (
        SELECT
              CAST(CASE WHEN @TaxApplicable = 1 AND @TaxInclusive = 1 THEN amount.RawAmount / (1 + @TaxRate) ELSE amount.RawAmount END AS DECIMAL(18,2)) AmountBeforeTax
            , CAST(CASE WHEN @TaxApplicable = 0 THEN 0 WHEN @TaxInclusive = 1 THEN amount.RawAmount - (amount.RawAmount / (1 + @TaxRate)) ELSE amount.RawAmount * @TaxRate END AS DECIMAL(18,2)) TaxAmount
            , CAST(CASE WHEN @TaxApplicable = 1 AND @TaxInclusive = 0 THEN amount.RawAmount * (1 + @TaxRate) ELSE amount.RawAmount END AS DECIMAL(18,2)) TotalAmount
    ) calculated
    ;

    IF NOT EXISTS (SELECT 1 FROM #Details) RETURN;

    DECLARE @AmountBeforeTax DECIMAL(18,2), @TaxAmount DECIMAL(18,2), @TotalAmount DECIMAL(18,2);
    SELECT @AmountBeforeTax = SUM(AmountBeforeTax), @TaxAmount = SUM(TaxAmount), @TotalAmount = SUM(TotalAmount) FROM #Details;

    DECLARE @tc INT = @@TRANCOUNT, @BillID BIGINT, @CalculationID BIGINT;
    BEGIN TRY
        IF @tc = 0 BEGIN TRANSACTION;

        DECLARE @LockResult INT, @LockResource NVARCHAR(255);
        SET @LockResource = CONCAT(N'Housing.EstimatedBill:', @IdaraID, N':', @ResidentInfoID, N':', @BuildingDetailsID, N':', @MeterServiceTypeID, N':', CONVERT(char(8), @FromDate, 112), N':', CONVERT(char(8), @ToDate, 112));
        EXEC @LockResult = sys.sp_getapplock
              @Resource = @LockResource
            , @LockMode = N'Exclusive'
            , @LockOwner = N'Transaction'
            , @LockTimeout = 10000;

        IF @LockResult < 0
            THROW 50001, N'تعذر حجز عملية إصدار الفاتورة التقديرية. يرجى إعادة المحاولة.', 1;

        /* Repeat the priority check while holding the lock to prevent concurrent duplicates. */
        IF EXISTS
        (
            SELECT 1
            FROM Housing.Bills bill
            WHERE bill.residentInfoID_FK = @ResidentInfoID
              AND bill.buildingDetailsID = @BuildingDetailsID
              AND bill.idaraID_FK = @IdaraID
              AND bill.meterServiceTypeID = @MeterServiceTypeID
              AND bill.BillActive = 1
              AND CONVERT(date, bill.BillsFromDate) <= @ToDate
              AND CONVERT(date, bill.BillsToDate) >= @FromDate
        )
        BEGIN
            IF @tc = 0 COMMIT TRANSACTION;
            RETURN;
        END;

        DECLARE @BillChargeTypeID INT, @PeriodID INT, @BuildingNo NVARCHAR(200), @UtilityTypeID INT;
        SELECT @BuildingNo = buildingDetailsNo, @UtilityTypeID = buildingUtilityTypeID_FK
        FROM Housing.BuildingDetails WHERE buildingDetailsID = @BuildingDetailsID AND IdaraId_FK = @IdaraID;
        SELECT TOP (1) @BillChargeTypeID = BillChargeTypeID FROM Housing.BillChargeType
        WHERE MeterServiceTypeID_FK = @MeterServiceTypeID AND BillChargeTypeActive = 1 ORDER BY BillChargeTypeID;
        SELECT TOP (1) @PeriodID = period.billPeriodID
        FROM Housing.BillPeriodType periodType
        JOIN Housing.BillPeriod period ON period.billPeriodTypeID_FK = periodType.billPeriodTypeID AND period.IdaraId_FK = @IdaraID
        WHERE periodType.meterServiceTypeID_FK = @MeterServiceTypeID
          AND period.billPeriodStartDate <= @ToDate AND period.billPeriodEndDate >= @FromDate
        ORDER BY period.billPeriodID DESC;

        INSERT Housing.Bills
        (BillsUID,BillChargeTypeID_FK,BillTypeID_FK,CurrentPeriodID,PeriodMonth,PeriodYear,CurrentPeriodTax,
         buildingDetailsNo,buildingUtilityTypeID,buildingDetailsID,meterServiceTypeID,residentInfoID_FK,generalNo_FK,
         CurrentRead,LastRead,ReadDiff,PRICE,PRICETAX,meterServicePrice,meterServicePriceTAX,TotalPrice,
         BillsFromDate,BillsToDate,BillActive,idaraID_FK,entryData,hostName)
        VALUES
        (NEWID(),@BillChargeTypeID,2,@PeriodID,MONTH(@FromDate),YEAR(@FromDate),@TaxRatePercent,
         @BuildingNo,@UtilityTypeID,@BuildingDetailsID,@MeterServiceTypeID,@ResidentInfoID,@GeneralNo,
         0,0,0,@AmountBeforeTax,@TaxAmount,0,0,@TotalAmount,
         @FromDate,@ToDate,1,@IdaraID,@EntryData,@HostName);
        SET @BillID = SCOPE_IDENTITY();

        INSERT Housing.BillCalculation
        (BillsID_FK,CalculationMethod,EstimatedBillingPolicyID_FK,BillingDays,TaxApplicable,TaxInclusive,TaxID_FK,TaxRate,
         AmountBeforeTax,TaxAmount,TotalAmount,CalculationReason,entryData,hostName)
        VALUES
        (@BillID,N'SPACE_ESTIMATED',@PolicyID,@BillingDays,@TaxApplicable,@TaxInclusive,@TaxID,@TaxRate,
         @AmountBeforeTax,@TaxAmount,@TotalAmount,N'تم الاحتساب تقديرياً بناءً على الفراغات النشطة في المبنى',@EntryData,@HostName);
        SET @CalculationID = SCOPE_IDENTITY();

        INSERT Housing.BillCalculationDetails
        (BillCalculationID_FK,BuildingSpaceTypeID_FK,SpaceTypeCode,SpaceTypeName_A,SpaceCount,
         AverageDailyConsumption,UsageFactor,UnitPrice,UnitCode,BillingDays,AmountBeforeTax,TaxAmount,TotalAmount,entryData,hostName)
        SELECT @CalculationID,BuildingSpaceTypeID,SpaceTypeCode,SpaceTypeName_A,SpaceCount,
               AverageDailyConsumption,UsageFactor,UnitPrice,UnitCode,@BillingDays,AmountBeforeTax,TaxAmount,TotalAmount,@EntryData,@HostName
        FROM #Details;

        IF @tc = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
