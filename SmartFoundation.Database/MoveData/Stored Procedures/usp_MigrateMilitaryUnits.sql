
CREATE   PROCEDURE [MoveData].[usp_MigrateMilitaryUnits]
    @RollbackAfterTest bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Inserted bigint = 0;
    DECLARE @IdentityInsertOn bit = 0;

    /* Do not silently overwrite a target unit that reused an old ID for another code. */
    IF EXISTS
    (
        SELECT 1
        FROM KFMC.dbo.MilitaryUnit sourceUnit
        JOIN dbo.MilitaryUnit targetUnit
          ON targetUnit.militaryUnitID = sourceUnit.militaryUnitID
        WHERE ISNULL(LTRIM(RTRIM(targetUnit.militaryUnitCode)), N'') <>
              ISNULL(LTRIM(RTRIM(sourceUnit.militaryUnitCode)), N'')
    )
        THROW 53500, N'A military-unit ID exists in DATACORE with a different code.', 1;

    /* ResidentDetails keeps the old ID, so the same code cannot be stored under another ID. */
    IF EXISTS
    (
        SELECT 1
        FROM KFMC.dbo.MilitaryUnit sourceUnit
        JOIN dbo.MilitaryUnit targetUnit
          ON LTRIM(RTRIM(targetUnit.militaryUnitCode)) =
             LTRIM(RTRIM(sourceUnit.militaryUnitCode))
         AND targetUnit.militaryUnitID <> sourceUnit.militaryUnitID
        WHERE NULLIF(LTRIM(RTRIM(sourceUnit.militaryUnitCode)), N'') IS NOT NULL
    )
        THROW 53501, N'A military-unit code exists in DATACORE under a different ID.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET IDENTITY_INSERT dbo.MilitaryUnit ON;
        SET @IdentityInsertOn = 1;

        INSERT INTO dbo.MilitaryUnit
        (
            militaryUnitID,
            militaryUnitCode,
            militaryUnitName_A,
            militaryUnitName_E,
            militaryUnitShortName,
            militaryUnitAreaID_FK,
            entryDate,
            entryData,
            hostName
        )
        SELECT
            sourceUnit.militaryUnitID,
            sourceUnit.militaryUnitCode,
            sourceUnit.militaryUnitName_A,
            sourceUnit.militaryUnitName_E,
            sourceUnit.militaryUnitShortName,
            sourceUnit.militaryUnitAreaID_FK,
            sourceUnit.entryDate,
            [MoveData].[fn_MapEntryData](sourceUnit.entryData),
            [MoveData].[fn_MapHostName](sourceUnit.hostName, sourceUnit.entryData)
        FROM KFMC.dbo.MilitaryUnit sourceUnit
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.MilitaryUnit targetUnit
            WHERE targetUnit.militaryUnitID = sourceUnit.militaryUnitID
        );

        SET @Inserted = @@ROWCOUNT;

        SET IDENTITY_INSERT dbo.MilitaryUnit OFF;
        SET @IdentityInsertOn = 0;

        SELECT
            @RollbackAfterTest RollbackAfterTest,
            @Inserted MilitaryUnitsInserted,
            (SELECT COUNT_BIG(*) FROM dbo.MilitaryUnit) TargetMilitaryUnitsTotal,
            (SELECT COUNT_BIG(*)
             FROM KFMC.dbo.MilitaryUnit sourceUnit
             LEFT JOIN dbo.MilitaryUnit targetUnit
               ON targetUnit.militaryUnitID = sourceUnit.militaryUnitID
             WHERE targetUnit.militaryUnitID IS NULL) MissingMilitaryUnits;

        IF @RollbackAfterTest = 1 ROLLBACK TRANSACTION;
        ELSE COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @IdentityInsertOn = 1 SET IDENTITY_INSERT dbo.MilitaryUnit OFF;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO

