SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @EffectiveFrom DATE = CONVERT(date, '20260729', 112);
DECLARE @EntryData NVARCHAR(20) = N'SYSTEM';
DECLARE @HostName NVARCHAR(200) = HOST_NAME();

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @SpaceTypes TABLE
    (
        BuildingSpaceTypeCode NVARCHAR(50) NOT NULL,
        BuildingSpaceTypeName_A NVARCHAR(100) NOT NULL,
        BuildingSpaceTypeName_E NVARCHAR(100) NOT NULL
    );

    INSERT INTO @SpaceTypes
    (
        BuildingSpaceTypeCode,
        BuildingSpaceTypeName_A,
        BuildingSpaceTypeName_E
    )
    VALUES
        (N'BEDROOM',      N'غرفة نوم',    N'Bedroom'),
        (N'HALL',         N'صالة',         N'Hall'),
        (N'MAJLIS',       N'مجلس',         N'Majlis'),
        (N'ANNEX',        N'ملحق',         N'Annex'),
        (N'KITCHEN',      N'مطبخ',         N'Kitchen'),
        (N'BATHROOM',     N'دورة مياه',    N'Bathroom'),
        (N'LAUNDRY_ROOM', N'غرفة غسيل',   N'Laundry room');

    INSERT INTO Housing.BuildingSpaceType
    (
        BuildingSpaceTypeCode,
        BuildingSpaceTypeName_A,
        BuildingSpaceTypeName_E,
        BuildingSpaceTypeStartDate,
        BuildingSpaceTypeActive,
        entryData,
        hostName
    )
    SELECT
        sourceRow.BuildingSpaceTypeCode,
        sourceRow.BuildingSpaceTypeName_A,
        sourceRow.BuildingSpaceTypeName_E,
        @EffectiveFrom,
        1,
        @EntryData,
        @HostName
    FROM @SpaceTypes sourceRow
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM Housing.BuildingSpaceType existingRow
        WHERE existingRow.BuildingSpaceTypeCode = sourceRow.BuildingSpaceTypeCode
    );

    DECLARE @PolicyID BIGINT;

    SELECT TOP (1)
        @PolicyID = policyRow.EstimatedBillingPolicyID
    FROM Housing.EstimatedBillingPolicy policyRow
    WHERE policyRow.IdaraID_FK IS NULL
      AND policyRow.EffectiveFrom = @EffectiveFrom
      AND policyRow.CanceledDate IS NULL
    ORDER BY policyRow.EstimatedBillingPolicyID DESC;

    IF @PolicyID IS NULL
    BEGIN
        INSERT INTO Housing.EstimatedBillingPolicy
        (
            EstimatedBillingPolicyName_A,
            EstimatedBillingPolicyName_E,
            IdaraID_FK,
            EffectiveFrom,
            EffectiveTo,
            TaxApplicable,
            TaxInclusive,
            EstimatedBillingPolicyActive,
            EstimatedBillingPolicyDescription,
            entryData,
            hostName
        )
        VALUES
        (
            N'السياسة الافتراضية للحسبة التقديرية',
            N'Default estimated billing policy',
            NULL,
            @EffectiveFrom,
            NULL,
            1,
            1,
            1,
            N'سياسة عامة لجميع الإدارات ما لم توجد سياسة نشطة خاصة بالإدارة.',
            @EntryData,
            @HostName
        );

        SET @PolicyID = SCOPE_IDENTITY();
    END;

    DECLARE @ElectricityServiceID INT =
    (
        SELECT TOP (1) meterServiceTypeID
        FROM Housing.MeterServiceType
        WHERE meterServiceTypeID = 1
          AND meterServiceTypeActive = 1
    );

    DECLARE @WaterServiceID INT =
    (
        SELECT TOP (1) meterServiceTypeID
        FROM Housing.MeterServiceType
        WHERE meterServiceTypeID = 2
          AND meterServiceTypeActive = 1
    );

    IF @ElectricityServiceID IS NULL
        THROW 50001, N'خدمة الكهرباء النشطة غير موجودة.', 1;

    IF @WaterServiceID IS NULL
        THROW 50001, N'خدمة المياه النشطة غير موجودة.', 1;

    DECLARE @Rules TABLE
    (
        MeterServiceTypeID_FK INT NOT NULL,
        BuildingSpaceTypeCode NVARCHAR(50) NOT NULL,
        AverageDailyConsumption DECIMAL(18, 6) NOT NULL,
        UsageFactor DECIMAL(18, 6) NOT NULL,
        UnitPrice DECIMAL(18, 6) NOT NULL,
        UnitCode NVARCHAR(30) NOT NULL
    );

    INSERT INTO @Rules
    (
        MeterServiceTypeID_FK,
        BuildingSpaceTypeCode,
        AverageDailyConsumption,
        UsageFactor,
        UnitPrice,
        UnitCode
    )
    VALUES
        (@ElectricityServiceID, N'BEDROOM',      8.00, 0.75, 0.18, N'KWH'),
        (@ElectricityServiceID, N'HALL',         5.00, 0.75, 0.18, N'KWH'),
        (@ElectricityServiceID, N'MAJLIS',       5.00, 0.75, 0.18, N'KWH'),
        (@ElectricityServiceID, N'ANNEX',        5.00, 0.75, 0.18, N'KWH'),
        (@ElectricityServiceID, N'KITCHEN',      3.00, 0.40, 0.18, N'KWH'),
        (@ElectricityServiceID, N'BATHROOM',     1.00, 0.40, 0.18, N'KWH'),
        (@ElectricityServiceID, N'LAUNDRY_ROOM', 1.00, 0.40, 0.18, N'KWH'),
        (@WaterServiceID,       N'KITCHEN',      1.50, 1.00, 0.10, N'M3'),
        (@WaterServiceID,       N'BATHROOM',     1.50, 1.00, 0.18, N'M3'),
        (@WaterServiceID,       N'LAUNDRY_ROOM', 1.50, 1.00, 0.18, N'M3');

    INSERT INTO Housing.EstimatedBillingPolicyDetails
    (
        EstimatedBillingPolicyID_FK,
        MeterServiceTypeID_FK,
        BuildingSpaceTypeID_FK,
        AverageDailyConsumption,
        UsageFactor,
        UnitPrice,
        UnitCode,
        EstimatedBillingPolicyDetailsActive,
        entryData,
        hostName
    )
    SELECT
        @PolicyID,
        ruleRow.MeterServiceTypeID_FK,
        spaceType.BuildingSpaceTypeID,
        ruleRow.AverageDailyConsumption,
        ruleRow.UsageFactor,
        ruleRow.UnitPrice,
        ruleRow.UnitCode,
        1,
        @EntryData,
        @HostName
    FROM @Rules ruleRow
    INNER JOIN Housing.BuildingSpaceType spaceType
        ON spaceType.BuildingSpaceTypeCode = ruleRow.BuildingSpaceTypeCode
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM Housing.EstimatedBillingPolicyDetails existingRule
        WHERE existingRule.EstimatedBillingPolicyID_FK = @PolicyID
          AND existingRule.MeterServiceTypeID_FK = ruleRow.MeterServiceTypeID_FK
          AND existingRule.BuildingSpaceTypeID_FK = spaceType.BuildingSpaceTypeID
    );

    COMMIT TRANSACTION;

    SELECT @PolicyID AS EstimatedBillingPolicyID;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
