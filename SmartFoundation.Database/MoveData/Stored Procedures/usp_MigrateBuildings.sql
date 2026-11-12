CREATE PROCEDURE [MoveData].[usp_MigrateBuildings]
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

    DECLARE @LocationsInserted bigint = 0;
    DECLARE @BuildingsInserted bigint = 0;
    DECLARE @RentsInserted bigint = 0;
    DECLARE @LocationIdentityOn bit = 0;
    DECLARE @BuildingIdentityOn bit = 0;
    DECLARE @RentIdentityOn bit = 0;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Idara] WHERE [idaraID] = @IdaraId)
        THROW 52000, N'The supplied IdaraId does not exist in DATACORE.dbo.Idara.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM [KFMC].[Housing].[BuildingDetails]
        WHERE NULLIF(LTRIM(RTRIM([buildingDetailsNo])), N'') IS NULL
    )
        THROW 52001, N'KFMC contains a building without buildingDetailsNo.', 1;

    IF EXISTS
    (
        SELECT [buildingDetailsNo]
        FROM [KFMC].[Housing].[BuildingDetails]
        GROUP BY [buildingDetailsNo]
        HAVING COUNT(*) > 1
    )
        THROW 52002, N'KFMC contains duplicate buildingDetailsNo values.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM [KFMC].[Housing].[BuildingDetails] AS sourceBuilding
        JOIN [Housing].[BuildingDetails] AS targetBuilding
          ON targetBuilding.[buildingDetailsID] = CONVERT(bigint, sourceBuilding.[buildingDetailsID])
        WHERE targetBuilding.[buildingDetailsNo] <> sourceBuilding.[buildingDetailsNo]
    )
        THROW 52003, N'A BuildingDetails ID already belongs to a different building.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM [KFMC].[Housing].[BuildingRent] AS sourceRent
        JOIN [Housing].[BuildingRent] AS targetRent
          ON targetRent.[buildingRentID] = sourceRent.[buildingRentID]
        WHERE ISNULL(targetRent.[buildingDetailsID_FK], -1)
           <> ISNULL(CONVERT(bigint, sourceRent.[buildingDetailsID_FK]), -1)
    )
        THROW 52004, N'A BuildingRent ID already belongs to a different building.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* Add only old locations that do not already exist in DATACORE. */
        SET IDENTITY_INSERT [Housing].[MilitaryLocation] ON;
        SET @LocationIdentityOn = 1;

        INSERT INTO [Housing].[MilitaryLocation]
        (
            [militaryLocationID], [militaryLocationCode],
            [militaryAreaCityID_FK], [militaryLocationName_A],
            [militaryLocationName_E], [militaryLocationCoordinates],
            [militaryLocationDescription], [militaryLocationActive],
            [IdaraId_FK], [entryDate], [entryData], [hostName]
        )
        SELECT
            sourceLocation.[militaryLocationID],
            sourceLocation.[militaryLocationCode],
            sourceLocation.[militaryAreaCityID_FK],
            sourceLocation.[militaryLocationName_A],
            sourceLocation.[militaryLocationName_E],
            sourceLocation.[militaryLocationCoordinates],
            sourceLocation.[militaryLocationDescription],
            sourceLocation.[militaryLocationActive],
            @IdaraId,
            sourceLocation.[entryDate],
            [MoveData].[fn_MapEntryData](sourceLocation.[entryData]),
            [MoveData].[fn_MapHostName](sourceLocation.[hostName], sourceLocation.[entryData])
        FROM [KFMC].[Housing].[MilitaryLocation] AS sourceLocation
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [Housing].[MilitaryLocation] AS targetLocation
            WHERE targetLocation.[militaryLocationID] = sourceLocation.[militaryLocationID]
        );

        SET @LocationsInserted = @@ROWCOUNT;
        SET IDENTITY_INSERT [Housing].[MilitaryLocation] OFF;
        SET @LocationIdentityOn = 0;

        /* All old lookup IDs referenced by buildings must now exist. */
        IF EXISTS
        (
            SELECT 1
            FROM [KFMC].[Housing].[BuildingDetails] AS sourceBuilding
            LEFT JOIN [Housing].[BuildingClass] AS buildingClass
              ON buildingClass.[buildingClassID] = sourceBuilding.[buildingClassID_FK]
            LEFT JOIN [Housing].[BuildingType] AS buildingType
              ON buildingType.[buildingTypeID] = sourceBuilding.[buildingTypeID_FK]
            LEFT JOIN [Housing].[BuildingUtilityType] AS utilityType
              ON utilityType.[buildingUtilityTypeID] = sourceBuilding.[buildingUtilityTypeID_FK]
            LEFT JOIN [Housing].[MilitaryLocation] AS location
              ON location.[militaryLocationID] = sourceBuilding.[militaryLocationID_FK]
            WHERE (sourceBuilding.[buildingClassID_FK] IS NOT NULL AND buildingClass.[buildingClassID] IS NULL)
               OR (sourceBuilding.[buildingTypeID_FK] IS NOT NULL AND buildingType.[buildingTypeID] IS NULL)
               OR (sourceBuilding.[buildingUtilityTypeID_FK] IS NOT NULL AND utilityType.[buildingUtilityTypeID] IS NULL)
               OR (sourceBuilding.[militaryLocationID_FK] IS NOT NULL AND location.[militaryLocationID] IS NULL)
        )
            THROW 52005, N'A building references a lookup value that does not exist in DATACORE.', 1;

        SET IDENTITY_INSERT [Housing].[BuildingDetails] ON;
        SET @BuildingIdentityOn = 1;

        INSERT INTO [Housing].[BuildingDetails]
        (
            [buildingDetailsID], [buildingDetailsNo], [buildingDetailsRooms],
            [buildingLevelsCount], [buildingDetailsArea], [buildingDetailsCoordinates],
            [buildingTypeID_FK], [buildingUtilityTypeID_FK], [militaryLocationID_FK],
            [buildingClassID_FK], [buildingDetailsTel_1], [buildingDetailsTel_2],
            [buildingDetailsRemark], [buildingDetailsStartDate], [buildingDetailsEndDate],
            [buildingDetailsActive], [IdaraId_FK], [entryDate], [entryData], [hostName]
        )
        SELECT
            CONVERT(bigint, sourceBuilding.[buildingDetailsID]),
            sourceBuilding.[buildingDetailsNo], sourceBuilding.[buildingDetailsRooms],
            sourceBuilding.[buildingLevelsCount], sourceBuilding.[buildingDetailsArea],
            sourceBuilding.[buildingDetailsCoordinates],
            CONVERT(bigint, sourceBuilding.[buildingTypeID_FK]),
            CONVERT(bigint, sourceBuilding.[buildingUtilityTypeID_FK]),
            sourceBuilding.[militaryLocationID_FK],
            CONVERT(bigint, sourceBuilding.[buildingClassID_FK]),
            sourceBuilding.[buildingDetailsTel_1], sourceBuilding.[buildingDetailsTel_2],
            sourceBuilding.[buildingDetailsRemark], sourceBuilding.[buildingDetailsStartDate],
            sourceBuilding.[buildingDetailsEndDate], sourceBuilding.[buildingDetailsActive],
            @IdaraId, sourceBuilding.[entryDate],
            [MoveData].[fn_MapEntryData](sourceBuilding.[entryData]),
            [MoveData].[fn_MapHostName](sourceBuilding.[hostName], sourceBuilding.[entryData])
        FROM [KFMC].[Housing].[BuildingDetails] AS sourceBuilding
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [Housing].[BuildingDetails] AS targetBuilding
            WHERE targetBuilding.[buildingDetailsID] = CONVERT(bigint, sourceBuilding.[buildingDetailsID])
        );

        SET @BuildingsInserted = @@ROWCOUNT;
        SET IDENTITY_INSERT [Housing].[BuildingDetails] OFF;
        SET @BuildingIdentityOn = 0;

        SET IDENTITY_INSERT [Housing].[BuildingRent] ON;
        SET @RentIdentityOn = 1;

        INSERT INTO [Housing].[BuildingRent]
        (
            [buildingRentID], [buildingRentTypeID_FK], [buildingDetailsID_FK],
            [buildingRentAmount], [buildingRentStartDate], [buildingRentEndDate],
            [buildingRentDescription], [buildingRentActive],
            [entryDate], [entryData], [hostName]
        )
        SELECT
            sourceRent.[buildingRentID], sourceRent.[buildingRentTypeID_FK],
            CONVERT(bigint, sourceRent.[buildingDetailsID_FK]), sourceRent.[buildingRentAmount],
            sourceRent.[buildingRentStartDate], sourceRent.[buildingRentEndDate],
            sourceRent.[buildingRentDescription], sourceRent.[buildingRentActive],
            sourceRent.[entryDate],
            [MoveData].[fn_MapEntryData](sourceRent.[entryData]),
            [MoveData].[fn_MapHostName](sourceRent.[hostName], sourceRent.[entryData])
        FROM [KFMC].[Housing].[BuildingRent] AS sourceRent
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [Housing].[BuildingRent] AS targetRent
            WHERE targetRent.[buildingRentID] = sourceRent.[buildingRentID]
        );

        SET @RentsInserted = @@ROWCOUNT;
        SET IDENTITY_INSERT [Housing].[BuildingRent] OFF;
        SET @RentIdentityOn = 0;

        SELECT
            @RollbackAfterTest AS [RollbackAfterTest],
            @LocationsInserted AS [MilitaryLocationsInserted],
            @BuildingsInserted AS [BuildingsInserted],
            @RentsInserted AS [BuildingRentsInserted],
            (SELECT COUNT_BIG(*) FROM [Housing].[BuildingDetails]) AS [TargetBuildingsTotal],
            (SELECT COUNT_BIG(*) FROM [Housing].[BuildingRent]) AS [TargetRentsTotal];

        IF @RollbackAfterTest = 1
            ROLLBACK TRANSACTION;
        ELSE
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @RentIdentityOn = 1 SET IDENTITY_INSERT [Housing].[BuildingRent] OFF;
        IF @BuildingIdentityOn = 1 SET IDENTITY_INSERT [Housing].[BuildingDetails] OFF;
        IF @LocationIdentityOn = 1 SET IDENTITY_INSERT [Housing].[MilitaryLocation] OFF;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO

