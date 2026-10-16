CREATE PROCEDURE [MoveData].[usp_MigrateMeters]
    @IdaraId bigint,
    @RollbackAfterTest bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    /* Normalize migration administration: preserve a valid supplied value, otherwise use Idara 1. */
    IF NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID = 1)
        THROW 57990, N'Default migration Idara 1 does not exist.', 1;
    IF @IdaraId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID = @IdaraId)
        SET @IdaraId = 1;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Idara] WHERE [idaraID] = @IdaraId)
        THROW 53000, N'The supplied IdaraId does not exist in DATACORE.dbo.Idara.', 1;
    IF @IdaraId NOT BETWEEN 0 AND 2147483647
        THROW 53001, N'IdaraId cannot fit in legacy int Idara columns.', 1;
    IF EXISTS (SELECT 1 FROM [KFMC].[Housing].[Meter] WHERE NULLIF(LTRIM(RTRIM([meterNo])), N'') IS NULL)
        THROW 53002, N'KFMC contains a meter without meterNo.', 1;
    IF EXISTS
    (
        SELECT 1
        FROM [KFMC].[Housing].[MeterForBuilding] sourceLink
        LEFT JOIN [Housing].[BuildingDetails] targetBuilding
          ON targetBuilding.[buildingDetailsID] = CONVERT(bigint, sourceLink.[buildingDetailsID_FK])
        WHERE sourceLink.[buildingDetailsID_FK] IS NOT NULL
          AND targetBuilding.[buildingDetailsID] IS NULL
    )
        THROW 53003, N'Run MoveData.usp_MigrateBuildings before migrating meters.', 1;

    DECLARE @MeterTypesInserted bigint = 0, @ServicePricesInserted bigint = 0, @PeriodsInserted bigint = 0,
            @MetersInserted bigint = 0, @MeterBuildingsInserted bigint = 0,
            @ReadsInserted bigint = 0,
            @ResidentReadsCorrected bigint = 0,
            @BuildingReadsCorrected bigint = 0;
    DECLARE @TypeIdentity bit = 0, @PriceIdentity bit = 0, @PeriodIdentity bit = 0, @MeterIdentity bit = 0,
            @MeterBuildingIdentity bit = 0, @ReadIdentity bit = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET IDENTITY_INSERT [Housing].[MeterType] ON;
        SET @TypeIdentity = 1;
        INSERT INTO [Housing].[MeterType]
        (
            [meterTypeID], [meterServiceTypeID_FK], [MeterCalculateTypeID_FK],
            [meterTypeName_A], [meterTypeName_E], [meterTypeDescription],
            [meterTypeConversionFactor], [meterMaxRead], [meterTypeStartDate],
            [meterTypeEndDate], [meterTypeActive], [UpdatedBy], [UpdatedDate],
            [CanceledBy], [CanceledDate], [CanceledNote], [IdaraId_FK],
            [entryDate], [entryData], [hostName]
        )
        SELECT
            s.[meterTypeID], s.[meterServiceTypeID_FK], 1,
            s.[meterTypeName_A], s.[meterTypeName_E], s.[meterTypeDescription],
            s.[meterTypeConversionFactor], s.[meterMaxRead], s.[meterTypeStartDate],
            s.[meterTypeEndDate], s.[meterTypeActive], NULL, NULL, NULL, NULL, NULL,
            @IdaraId, s.[entryDate], [MoveData].[fn_MapEntryData](s.[entryData]), [MoveData].[fn_MapHostName](s.[hostName], s.[entryData])
        FROM [KFMC].[Housing].[MeterType] s
        WHERE NOT EXISTS (SELECT 1 FROM [Housing].[MeterType] t WHERE t.[meterTypeID] = s.[meterTypeID]);
        SET @MeterTypesInserted = @@ROWCOUNT;
        SET IDENTITY_INSERT [Housing].[MeterType] OFF;
        SET @TypeIdentity = 0;

        SET IDENTITY_INSERT [Housing].[MeterServicePrice] ON;
        SET @PriceIdentity = 1;
        INSERT INTO [Housing].[MeterServicePrice]
        (
            [meterServicePriceID], [meterTypeID_FK], [meterServicePriceStartDate],
            [meterServicePriceEndDate], [meterServicePrice], [meterServicePriceActive],
            [entryDate], [entryData], [hostName]
        )
        SELECT
            s.[meterServicePriceID], s.[meterTypeID_FK], s.[meterServicePriceStartDate],
            s.[meterServicePriceEndDate], s.[meterServicePrice], s.[meterServicePriceActive],
            s.[entryDate], [MoveData].[fn_MapEntryData](s.[entryData]), [MoveData].[fn_MapHostName](s.[hostName], s.[entryData])
        FROM [KFMC].[Housing].[MeterServicePrice] s
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [Housing].[MeterServicePrice] t
            WHERE t.[meterServicePriceID] = s.[meterServicePriceID]
        );
        SET @ServicePricesInserted = @@ROWCOUNT;
        SET IDENTITY_INSERT [Housing].[MeterServicePrice] OFF;
        SET @PriceIdentity = 0;

        SET IDENTITY_INSERT [Housing].[BillPeriod] ON;
        SET @PeriodIdentity = 1;
        INSERT INTO [Housing].[BillPeriod]
        (
            [billPeriodID], [billPeriodTypeID_FK], [billPeriodName_A], [billPeriodName_E],
            [billPeriodStartDate], [billPeriodEndDate], [billPeriodActive], [ClosedBy],
            [IdaraId_FK], [entryDate], [entryData], [hostName]
        )
        SELECT
            s.[billPeriodID], s.[billPeriodTypeID_FK], s.[billPeriodName_A], s.[billPeriodName_E],
            s.[billPeriodStartDate], s.[billPeriodEndDate], s.[billPeriodActive], s.[ClosedBy],
            @IdaraId, s.[entryDate], [MoveData].[fn_MapEntryData](s.[entryData]), [MoveData].[fn_MapHostName](s.[hostName], s.[entryData])
        FROM [KFMC].[Housing].[BillPeriod] s
        WHERE NOT EXISTS (SELECT 1 FROM [Housing].[BillPeriod] t WHERE t.[billPeriodID] = s.[billPeriodID]);
        SET @PeriodsInserted = @@ROWCOUNT;
        SET IDENTITY_INSERT [Housing].[BillPeriod] OFF;
        SET @PeriodIdentity = 0;

        SET IDENTITY_INSERT [Housing].[Meter] ON;
        SET @MeterIdentity = 1;
        INSERT INTO [Housing].[Meter]
        (
            [meterID], [meterTypeID_FK], [meterNo], [meterName_A], [meterName_E],
            [meterDescription], [meterStartDate], [meterEndDate], [meterActive],
            [CanceledBy], [CanceledDate], [CanceledNote], [IdaraId_FK],
            [entryDate], [entryData], [hostName]
        )
        SELECT
            CONVERT(bigint, s.[meterID]), s.[meterTypeID_FK], s.[meterNo], s.[meterName_A], s.[meterName_E],
            s.[meterDescription], s.[meterStartDate], s.[meterEndDate], s.[meterActive],
            NULL, NULL, NULL, @IdaraId, s.[entryDate], [MoveData].[fn_MapEntryData](s.[entryData]), [MoveData].[fn_MapHostName](s.[hostName], s.[entryData])
        FROM [KFMC].[Housing].[Meter] s
        WHERE NOT EXISTS (SELECT 1 FROM [Housing].[Meter] t WHERE t.[meterID] = CONVERT(bigint, s.[meterID]));
        SET @MetersInserted = @@ROWCOUNT;
        SET IDENTITY_INSERT [Housing].[Meter] OFF;
        SET @MeterIdentity = 0;

        SET IDENTITY_INSERT [Housing].[MeterForBuilding] ON;
        SET @MeterBuildingIdentity = 1;
        INSERT INTO [Housing].[MeterForBuilding]
        (
            [meterForBuildingID], [meterID_FK], [buildingDetailsID_FK],
            [meterForBuildingStartDate], [meterForBuildingEndDate], [meterForBuildingActive],
            [meterForBuildingDescription], [CanceledBy], [CanceledDate], [CanceledNote],
            [IdaraID_FK], [entryDate], [entryData], [hostName]
        )
        SELECT
            s.[meterForBuildingID], CONVERT(bigint, s.[meterID_FK]),
            CONVERT(bigint, s.[buildingDetailsID_FK]), s.[meterForBuildingStartDate],
            s.[meterForBuildingEndDate], s.[meterForBuildingActive], NULL, NULL, NULL, NULL,
            CONVERT(int, @IdaraId), s.[entryDate], [MoveData].[fn_MapEntryData](s.[entryData]), [MoveData].[fn_MapHostName](s.[hostName], s.[entryData])
        FROM [KFMC].[Housing].[MeterForBuilding] s
        WHERE NOT EXISTS
        (SELECT 1 FROM [Housing].[MeterForBuilding] t WHERE t.[meterForBuildingID] = s.[meterForBuildingID]);
        SET @MeterBuildingsInserted = @@ROWCOUNT;
        SET IDENTITY_INSERT [Housing].[MeterForBuilding] OFF;
        SET @MeterBuildingIdentity = 0;

        SET IDENTITY_INSERT [Housing].[MeterRead] ON;
        SET @ReadIdentity = 1;
        INSERT INTO [Housing].[MeterRead]
        (
            [meterReadID], [meterReadTypeID_FK], [meterID_FK], [billPeriodID_FK],
            [residentInfoID_FK], [generalNo_FK], [buildingDetailsID], [buildingDetailsNo],
            [dateOfRead], [meterReadValue], [buildingActionID_FK], [meterReadActive],
            [CanceledBy], [IdaraID_FK], [entryDate], [entryData], [hostName]
        )
        SELECT
            s.[meterReadID], s.[meterReadTypeID_FK], CONVERT(bigint, s.[meterID_FK]),
            
            s.[billPeriodID_FK],
migratedResident.[residentInfoID],
correction.[CorrectedGeneralNo],
CONVERT(bigint, building.[buildingDetailsID]),
            correction.[CorrectedBuildingNo], s.[dateOfRead], 
            CONVERT(bigint, s.[meterReadValue]),
NULL,
s.[meterReadActive],
s.[CanceledBy],
CONVERT(int, @IdaraId),
            s.[entryDate], [MoveData].[fn_MapEntryData](s.[entryData]), [MoveData].[fn_MapHostName](s.[hostName], s.[entryData])
        FROM [KFMC].[Housing].[MeterRead] s
        CROSS APPLY
        (
            SELECT
                CONVERT(bigint,
                    CASE
                        WHEN s.[generalNo_FK] = 202964 THEN 60013013
                        WHEN s.[generalNo_FK] = 404529
                         AND LTRIM(RTRIM(s.[buildingDetailsNo])) = N'1265' THEN 10038776
                        WHEN s.[generalNo_FK] = 306499
                         AND LTRIM(RTRIM(s.[buildingDetailsNo])) = N'B06-5-2' THEN 10036016
                        ELSE s.[generalNo_FK]
                    END) AS [CorrectedGeneralNo],
                CONVERT(nvarchar(400),
                    CASE
                        WHEN LTRIM(RTRIM(s.[buildingDetailsNo])) = N'C7-2-1' THEN N'C07-2-1'
                        ELSE s.[buildingDetailsNo]
                    END) AS [CorrectedBuildingNo]
        ) correction
        LEFT JOIN [KFMC].[Housing].[ResidentInfo] sourceOriginal
    ON sourceOriginal.[generalNo] = s.[generalNo_FK]

OUTER APPLY
(
    SELECT
        CASE
            WHEN sourceOriginal.[residentInfoID] IS NOT NULL
             AND NOT EXISTS
             (
                 SELECT 1
                 FROM [KFMC].[Housing].[ResidentDetails] d
                 WHERE d.[generalNo_FK] =
                       sourceOriginal.[generalNo]
             )
            THEN CONVERT(bit, 1)
            ELSE CONVERT(bit, 0)
        END AS ExcludedOriginalResident
) ownership

LEFT JOIN [KFMC].[Housing].[ResidentInfo] resident
    ON resident.[generalNo] = correction.[CorrectedGeneralNo]

LEFT JOIN [Housing].[ResidentInfo] migratedResident
    ON migratedResident.[residentInfoID] =
       CONVERT(bigint, resident.[residentInfoID])
   AND EXISTS
   (
       SELECT 1
       FROM [KFMC].[Housing].[ResidentDetails] eligible
       WHERE eligible.[generalNo_FK] =
             resident.[generalNo]
   )
        LEFT JOIN [KFMC].[Housing].[BuildingDetails] building
          ON LTRIM(RTRIM(building.[buildingDetailsNo])) = LTRIM(RTRIM(correction.[CorrectedBuildingNo]))
        
WHERE ownership.ExcludedOriginalResident = 0
  AND NOT EXISTS
  (
      SELECT 1
      FROM [Housing].[MeterRead] t
      WHERE t.[meterReadID] = s.[meterReadID]
  );

        SET @ReadsInserted = @@ROWCOUNT;

        SELECT @ResidentReadsCorrected=COUNT_BIG(*)
        FROM [KFMC].[Housing].[MeterRead] sourceRead
        JOIN [Housing].[MeterRead] targetRead ON targetRead.[meterReadID]=sourceRead.[meterReadID]
        WHERE
             (sourceRead.[generalNo_FK]=202964 AND targetRead.[generalNo_FK]=60013013 AND targetRead.[residentInfoID_FK] IS NOT NULL)
          OR (sourceRead.[generalNo_FK]=404529 AND LTRIM(RTRIM(sourceRead.[buildingDetailsNo]))=N'1265'
              AND targetRead.[generalNo_FK]=10038776 AND targetRead.[residentInfoID_FK] IS NOT NULL)
          OR (sourceRead.[generalNo_FK]=306499 AND LTRIM(RTRIM(sourceRead.[buildingDetailsNo]))=N'B06-5-2'
              AND targetRead.[generalNo_FK]=10036016 AND targetRead.[residentInfoID_FK] IS NOT NULL);

        SELECT @BuildingReadsCorrected=COUNT_BIG(*)
        FROM [KFMC].[Housing].[MeterRead] sourceRead
        JOIN [Housing].[MeterRead] targetRead ON targetRead.[meterReadID]=sourceRead.[meterReadID]
        WHERE LTRIM(RTRIM(sourceRead.[buildingDetailsNo]))=N'C7-2-1'
          AND LTRIM(RTRIM(targetRead.[buildingDetailsNo]))=N'C07-2-1'
          AND targetRead.[buildingDetailsID] IS NOT NULL;
        SET IDENTITY_INSERT [Housing].[MeterRead] OFF;
        SET @ReadIdentity = 0;

        SELECT @RollbackAfterTest [RollbackAfterTest], @MeterTypesInserted [MeterTypesInserted],
               @ServicePricesInserted [MeterServicePricesInserted],
               @PeriodsInserted [BillPeriodsInserted], @MetersInserted [MetersInserted],
               @MeterBuildingsInserted [MeterBuildingsInserted], @ReadsInserted [MeterReadsInserted],
               @ResidentReadsCorrected [ResidentMeterReadsCorrected],
               @BuildingReadsCorrected [BuildingMeterReadsCorrected],
               (SELECT COUNT_BIG(*) FROM [Housing].[MeterRead] WHERE [residentInfoID_FK] IS NULL AND [generalNo_FK] IS NOT NULL) [ReadsWithUnmatchedResident],
               (SELECT COUNT_BIG(*) FROM [Housing].[MeterRead] WHERE [buildingDetailsID] IS NULL AND NULLIF(LTRIM(RTRIM([buildingDetailsNo])), N'') IS NOT NULL) [ReadsWithUnmatchedBuilding];

        IF @RollbackAfterTest = 1 ROLLBACK TRANSACTION; ELSE COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @ReadIdentity = 1 SET IDENTITY_INSERT [Housing].[MeterRead] OFF;
        IF @MeterBuildingIdentity = 1 SET IDENTITY_INSERT [Housing].[MeterForBuilding] OFF;
        IF @MeterIdentity = 1 SET IDENTITY_INSERT [Housing].[Meter] OFF;
        IF @PeriodIdentity = 1 SET IDENTITY_INSERT [Housing].[BillPeriod] OFF;
        IF @PriceIdentity = 1 SET IDENTITY_INSERT [Housing].[MeterServicePrice] OFF;
        IF @TypeIdentity = 1 SET IDENTITY_INSERT [Housing].[MeterType] OFF;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;