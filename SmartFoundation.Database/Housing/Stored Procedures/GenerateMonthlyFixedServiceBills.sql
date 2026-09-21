CREATE PROCEDURE [Housing].[GenerateMonthlyFixedServiceBills]
(
      @Month INT
    , @Year INT
    , @EntryData NVARCHAR(20)
    , @HostName NVARCHAR(200)
    , @IdaraID BIGINT
    , @MeterServiceTypeID INT = NULL
    , @CalculationMethod NVARCHAR(30) = NULL
    , @ReturnResult BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Month NOT BETWEEN 1 AND 12 OR @Year NOT BETWEEN 1900 AND 9999 OR @IdaraID IS NULL
    BEGIN
        ;THROW 50001, N'بيانات شهر رصد الخدمات الثابتة غير صحيحة', 1;
    END;

    DECLARE @MonthStart DATE = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @MonthEnd DATE = EOMONTH(@MonthStart);

    IF @MonthEnd >= EOMONTH(GETDATE())
    BEGIN
        ;THROW 50001, N'لا يمكن رصد الخدمات الثابتة قبل اكتمال شهر الفوترة', 1;
    END;

    DECLARE @PeriodServiceTypeID INT, @MonthlyBillPeriodID INT;
    DECLARE periodServiceCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT serviceLink.MeterServiceTypeID_FK
    FROM Housing.MeterServiceTypeLinkedWithIdara serviceLink
    JOIN Housing.MeterServiceType serviceType
      ON serviceType.meterServiceTypeID = serviceLink.MeterServiceTypeID_FK
     AND serviceType.meterServiceTypeActive = 1
    WHERE (serviceLink.Idara_FK = @IdaraID OR serviceLink.Idara_FK IS NULL)
      AND (serviceLink.MeterServiceTypeLinkedWithIdaraActive = 1
           OR serviceLink.MeterServiceTypeLinkedWithIdaraEndDate IS NOT NULL)
      AND (serviceLink.MeterServiceTypeLinkedWithIdaraStartDate IS NULL
           OR CONVERT(date, serviceLink.MeterServiceTypeLinkedWithIdaraStartDate) <= @MonthEnd)
      AND (serviceLink.MeterServiceTypeLinkedWithIdaraEndDate IS NULL
           OR CONVERT(date, serviceLink.MeterServiceTypeLinkedWithIdaraEndDate) >= @MonthStart)
      AND (@MeterServiceTypeID IS NULL
           OR serviceLink.MeterServiceTypeID_FK = @MeterServiceTypeID);

    DECLARE @ResidentInfoID BIGINT, @GeneralNo BIGINT, @BuildingDetailsID BIGINT,
            @OccupentDate DATE, @ExitDate DATE, @ChargeFromDate DATE, @ChargeToDate DATE,
            @EstimatedServiceTypeID INT, @EstimatedFromDate DATE, @EstimatedToDate DATE;

    DECLARE @EstimatedSegments TABLE
    (
          MeterServiceTypeID INT NOT NULL
        , SegmentFromDate DATE NOT NULL
        , SegmentToDate DATE NOT NULL
        , PRIMARY KEY (MeterServiceTypeID, SegmentFromDate, SegmentToDate)
    );

    DECLARE residentCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT occupant.residentInfoID, occupant.GeneralNo, occupant.buildingDetailsID,
                    CAST(occupant.OccupentDate AS date), CAST(occupant.ExitDate AS date)
    FROM Housing.V_Occupant occupant
    WHERE occupant.IdaraId = @IdaraID
      AND CAST(occupant.OccupentDate AS date) <= @MonthEnd
      AND (occupant.ExitDate IS NULL OR CAST(occupant.ExitDate AS date) >= @MonthStart)
      AND
      (
          @MeterServiceTypeID IS NULL
          OR @CalculationMethod = N'METER_FIXED'
          OR EXISTS
          (
              SELECT 1
              FROM Housing.BuildingDetailsMeterServices buildingService
              WHERE buildingService.BuildingDetailsID_FK = occupant.buildingDetailsID
                AND buildingService.IdaraId_FK = @IdaraID
                AND buildingService.MeterServicesTypeID_FK = @MeterServiceTypeID
                AND (buildingService.BuildingDetailsMeterServicesActive = 1
                     OR buildingService.BuildingDetailsMeterServicesEndDate IS NOT NULL)
                AND (buildingService.BuildingDetailsMeterServicesStartDate IS NULL
                     OR CAST(buildingService.BuildingDetailsMeterServicesStartDate AS date) <= @MonthEnd)
                AND (buildingService.BuildingDetailsMeterServicesEndDate IS NULL
                     OR CAST(buildingService.BuildingDetailsMeterServicesEndDate AS date) >= @MonthStart)
          )
      )
      AND
      (
          @CalculationMethod IS NULL
          OR (@CalculationMethod = N'METER_FIXED' AND EXISTS
          (
              SELECT 1
              FROM Housing.MeterForBuilding meterLink
              JOIN Housing.Meter meter ON meter.meterID = meterLink.meterID_FK
              JOIN Housing.MeterType meterType ON meterType.meterTypeID = meter.meterTypeID_FK
              WHERE meterLink.buildingDetailsID_FK = occupant.buildingDetailsID
                AND meterLink.IdaraID_FK = @IdaraID
                AND meterType.meterServiceTypeID_FK = @MeterServiceTypeID
                AND meterType.MeterCalculateTypeID_FK = 2
          ))
          OR @CalculationMethod = N'SERVICE_FIXED'
      );

    BEGIN TRY
        BEGIN TRANSACTION;

        OPEN periodServiceCursor;
        FETCH NEXT FROM periodServiceCursor INTO @PeriodServiceTypeID;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @MonthlyBillPeriodID = NULL;

            EXEC Housing.GetOrCreateMonthlyBillPeriod
                  @IdaraID = @IdaraID
                , @MeterServiceTypeID = @PeriodServiceTypeID
                , @Year = @Year
                , @Month = @Month
                , @EntryData = @EntryData
                , @HostName = @HostName
                , @BillPeriodID = @MonthlyBillPeriodID OUTPUT;

            FETCH NEXT FROM periodServiceCursor INTO @PeriodServiceTypeID;
        END;

        CLOSE periodServiceCursor;
        DEALLOCATE periodServiceCursor;

        OPEN residentCursor;
        FETCH NEXT FROM residentCursor INTO @ResidentInfoID, @GeneralNo, @BuildingDetailsID, @OccupentDate, @ExitDate;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @ChargeFromDate = CASE WHEN @OccupentDate > @MonthStart THEN @OccupentDate ELSE @MonthStart END;
            SET @ChargeToDate = CASE WHEN @ExitDate IS NOT NULL AND @ExitDate < @MonthEnd THEN @ExitDate ELSE @MonthEnd END;

            IF @CalculationMethod = N'SERVICE_FIXED'
            BEGIN
                DELETE FROM @EstimatedSegments;

                /*
                   تقسيم فترة السكن إلى شرائح غير مغطاة بعداد مفوتر.
                   يتيح ذلك احتساب جزء الشهر من القراءة، ثم احتساب بقية
                   الشهر من الفراغات ابتداءً من اليوم التالي لانتهاء الربط.
                   كما يتم فصل الشرائح عند تغير السياسة الفعالة.
                */
                ;WITH CalendarDays AS
                (
                    SELECT @ChargeFromDate AS BillDay
                    UNION ALL
                    SELECT DATEADD(DAY, 1, BillDay)
                    FROM CalendarDays
                    WHERE BillDay < @ChargeToDate
                ),
                EligibleDays AS
                (
                    SELECT DISTINCT
                          serviceType.meterServiceTypeID
                        , dayRow.BillDay
                        , policyRow.EstimatedBillingPolicyID
                    FROM CalendarDays dayRow
                    JOIN Housing.MeterServiceType serviceType
                      ON serviceType.meterServiceTypeActive = 1
                     AND (@MeterServiceTypeID IS NULL OR serviceType.meterServiceTypeID = @MeterServiceTypeID)
                    JOIN Housing.MeterServiceTypeLinkedWithIdara serviceLink
                      ON serviceLink.MeterServiceTypeID_FK = serviceType.meterServiceTypeID
                     AND (serviceLink.Idara_FK = @IdaraID OR serviceLink.Idara_FK IS NULL)
                     AND (serviceLink.MeterServiceTypeLinkedWithIdaraActive = 1
                          OR serviceLink.MeterServiceTypeLinkedWithIdaraEndDate IS NOT NULL)
                     AND (serviceLink.MeterServiceTypeLinkedWithIdaraStartDate IS NULL
                          OR CONVERT(date, serviceLink.MeterServiceTypeLinkedWithIdaraStartDate) <= dayRow.BillDay)
                     AND (serviceLink.MeterServiceTypeLinkedWithIdaraEndDate IS NULL
                          OR CONVERT(date, serviceLink.MeterServiceTypeLinkedWithIdaraEndDate) >= dayRow.BillDay)
                    JOIN Housing.BuildingDetailsMeterServices buildingService
                      ON buildingService.BuildingDetailsID_FK = @BuildingDetailsID
                     AND buildingService.IdaraId_FK = @IdaraID
                     AND buildingService.MeterServicesTypeID_FK = serviceType.meterServiceTypeID
                     AND (buildingService.BuildingDetailsMeterServicesActive = 1
                          OR buildingService.BuildingDetailsMeterServicesEndDate IS NOT NULL)
                     AND (buildingService.BuildingDetailsMeterServicesStartDate IS NULL
                          OR CONVERT(date, buildingService.BuildingDetailsMeterServicesStartDate) <= dayRow.BillDay)
                     AND (buildingService.BuildingDetailsMeterServicesEndDate IS NULL
                          OR CONVERT(date, buildingService.BuildingDetailsMeterServicesEndDate) >= dayRow.BillDay)
                    CROSS APPLY
                    (
                        SELECT TOP (1) policy.EstimatedBillingPolicyID
                        FROM Housing.EstimatedBillingPolicy policy
                        WHERE policy.EstimatedBillingPolicyActive = 1
                          AND (policy.IdaraID_FK = @IdaraID OR policy.IdaraID_FK IS NULL)
                          AND policy.EffectiveFrom <= dayRow.BillDay
                          AND (policy.EffectiveTo IS NULL OR policy.EffectiveTo >= dayRow.BillDay)
                        ORDER BY CASE WHEN policy.IdaraID_FK = @IdaraID THEN 0 ELSE 1 END,
                                 policy.EffectiveFrom DESC, policy.EstimatedBillingPolicyID DESC
                    ) policyRow
                    WHERE NOT EXISTS
                    (
                        SELECT 1
                        FROM Housing.MeterForBuilding meterLink
                        JOIN Housing.Meter meter ON meter.meterID = meterLink.meterID_FK
                        JOIN Housing.MeterType meterType ON meterType.meterTypeID = meter.meterTypeID_FK
                        WHERE meterLink.buildingDetailsID_FK = @BuildingDetailsID
                          AND meterLink.IdaraID_FK = @IdaraID
                          AND meterType.meterServiceTypeID_FK = serviceType.meterServiceTypeID
                          AND meterType.MeterCalculateTypeID_FK = 1
                          AND (meterLink.meterForBuildingStartDate IS NULL
                               OR CONVERT(date, meterLink.meterForBuildingStartDate) <= dayRow.BillDay)
                          AND (meterLink.meterForBuildingEndDate IS NULL
                               OR CONVERT(date, meterLink.meterForBuildingEndDate) >= dayRow.BillDay)
                          AND (meter.meterStartDate IS NULL OR CONVERT(date, meter.meterStartDate) <= dayRow.BillDay)
                          AND (meter.meterEndDate IS NULL OR CONVERT(date, meter.meterEndDate) >= dayRow.BillDay)
                    )
                ),
                NumberedDays AS
                (
                    SELECT
                          eligible.meterServiceTypeID
                        , eligible.BillDay
                        , eligible.EstimatedBillingPolicyID
                        , DATEADD(DAY, -ROW_NUMBER() OVER
                          (
                              PARTITION BY eligible.meterServiceTypeID, eligible.EstimatedBillingPolicyID
                              ORDER BY eligible.BillDay
                          ), eligible.BillDay) AS IslandKey
                    FROM EligibleDays eligible
                )
                INSERT @EstimatedSegments (MeterServiceTypeID, SegmentFromDate, SegmentToDate)
                SELECT meterServiceTypeID, MIN(BillDay), MAX(BillDay)
                FROM NumberedDays
                GROUP BY meterServiceTypeID, EstimatedBillingPolicyID, IslandKey
                OPTION (MAXRECURSION 32767);

                DECLARE estimatedSegmentCursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT MeterServiceTypeID, SegmentFromDate, SegmentToDate
                FROM @EstimatedSegments
                ORDER BY MeterServiceTypeID, SegmentFromDate;

                OPEN estimatedSegmentCursor;
                FETCH NEXT FROM estimatedSegmentCursor
                INTO @EstimatedServiceTypeID, @EstimatedFromDate, @EstimatedToDate;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    EXEC Housing.GenerateEstimatedServiceBillForResidentPeriod
                          @ResidentInfoID = @ResidentInfoID, @GeneralNo = @GeneralNo
                        , @BuildingDetailsID = @BuildingDetailsID
                        , @FromDate = @EstimatedFromDate, @ToDate = @EstimatedToDate
                        , @IdaraID = @IdaraID, @EntryData = @EntryData, @HostName = @HostName
                        , @MeterServiceTypeID = @EstimatedServiceTypeID;

                    FETCH NEXT FROM estimatedSegmentCursor
                    INTO @EstimatedServiceTypeID, @EstimatedFromDate, @EstimatedToDate;
                END;

                CLOSE estimatedSegmentCursor;
                DEALLOCATE estimatedSegmentCursor;
            END;

            EXEC Housing.GenerateFixedServiceBillsForResidentPeriod
                  @ResidentInfoID = @ResidentInfoID, @GeneralNo = @GeneralNo
                , @BuildingDetailsID = @BuildingDetailsID
                , @FromDate = @ChargeFromDate
                , @ToDate = @ChargeToDate
                , @IdaraID = @IdaraID, @EntryData = @EntryData, @HostName = @HostName
                , @MeterServiceTypeID = @MeterServiceTypeID
                , @CalculationMethod = @CalculationMethod;

            FETCH NEXT FROM residentCursor INTO @ResidentInfoID, @GeneralNo, @BuildingDetailsID, @OccupentDate, @ExitDate;
        END;

        CLOSE residentCursor;
        DEALLOCATE residentCursor;
        COMMIT TRANSACTION;

        IF @ReturnResult=1
            SELECT 1 AS IsSuccessful, N'تم رصد فواتير الخدمات الثابتة الناقصة بنجاح' AS Message_;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'periodServiceCursor') >= 0 CLOSE periodServiceCursor;
        IF CURSOR_STATUS('local', 'periodServiceCursor') >= -1 DEALLOCATE periodServiceCursor;
        IF CURSOR_STATUS('local', 'estimatedSegmentCursor') >= 0 CLOSE estimatedSegmentCursor;
        IF CURSOR_STATUS('local', 'estimatedSegmentCursor') >= -1 DEALLOCATE estimatedSegmentCursor;
        IF CURSOR_STATUS('local', 'residentCursor') >= 0 CLOSE residentCursor;
        IF CURSOR_STATUS('local', 'residentCursor') >= -1 DEALLOCATE residentCursor;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
