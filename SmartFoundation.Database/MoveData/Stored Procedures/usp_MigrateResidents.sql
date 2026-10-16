
CREATE   PROCEDURE [MoveData].[usp_MigrateResidents]
    @IdaraId BIGINT,
    @RollbackAfterTest BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ResidentInfoInserted BIGINT = 0;
    DECLARE @ResidentDetailsInserted BIGINT = 0;
    DECLARE @IdentityInsertInfoOn BIT = 0;
    DECLARE @IdentityInsertDetailsOn BIT = 0;

    ------------------------------------------------------------
    -- 1. Validate Idara
    ------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Idara
        WHERE idaraID = 1
    )
        THROW 57990,
            N'Default migration Idara 1 does not exist.', 1;

    IF @IdaraId IS NULL
       OR NOT EXISTS
       (
           SELECT 1
           FROM dbo.Idara
           WHERE idaraID = @IdaraId
       )
        SET @IdaraId = 1;

    ------------------------------------------------------------
    -- 2. Select ONE ResidentDetails per generalNo
    --
    -- Priority:
    --   Active first
    --   Newest entryDate
    --   Highest residentDetailsID
    --
    -- If all versions are inactive:
    --   Select the newest inactive version.
    ------------------------------------------------------------

    ;WITH RankedDetails AS
    (
        SELECT
            d.*,

            ROW_NUMBER() OVER
            (
                PARTITION BY d.generalNo_FK
                ORDER BY
                    CASE
                        WHEN d.residentDetailsActive = 1 THEN 0
                        ELSE 1
                    END,
                    d.entryDate DESC,
                    d.residentDetailsID DESC
            ) AS MigrationRank

        FROM KFMC.Housing.ResidentDetails AS d
    )
    SELECT *
    INTO #SelectedResidentDetails
    FROM RankedDetails
    WHERE MigrationRank = 1;

    ------------------------------------------------------------
    -- 3. Validate selected ResidentDetails ownership
    ------------------------------------------------------------

    IF EXISTS
    (
        SELECT 1
        FROM #SelectedResidentDetails AS d

        LEFT JOIN KFMC.Housing.ResidentInfo AS r
            ON TRY_CONVERT(BIGINT, r.generalNo) =
               TRY_CONVERT(BIGINT, d.generalNo_FK)

        GROUP BY d.residentDetailsID

        HAVING COUNT_BIG(r.residentInfoID) <> 1
    )
        THROW 51001,
            N'Selected ResidentDetails cannot be mapped uniquely to ResidentInfo.',
            1;

    ------------------------------------------------------------
    -- 4. Validate military units for selected details
    ------------------------------------------------------------

    IF EXISTS
    (
        SELECT 1
        FROM #SelectedResidentDetails AS d

        LEFT JOIN dbo.MilitaryUnit AS u
            ON u.militaryUnitID =
               TRY_CONVERT(BIGINT, d.militaryUnitID_FK)

        WHERE d.militaryUnitID_FK IS NOT NULL
          AND u.militaryUnitID IS NULL
    )
        THROW 51005,
            N'Required military units are missing. Migrate military units first.',
            1;

    ------------------------------------------------------------
    -- 5. ResidentInfo ID collision protection
    --    Only eligible residents are checked.
    ------------------------------------------------------------

    IF EXISTS
    (
        SELECT 1
        FROM KFMC.Housing.ResidentInfo AS s

        JOIN #SelectedResidentDetails AS d
            ON TRY_CONVERT(BIGINT, d.generalNo_FK) =
               TRY_CONVERT(BIGINT, s.generalNo)

        JOIN Housing.ResidentInfo AS t
            ON t.residentInfoID =
               TRY_CONVERT(BIGINT, s.residentInfoID)

        WHERE t.residentInfoUID <> s.residentInfoUID
    )
        THROW 51002,
            N'A ResidentInfo ID belongs to a different resident.',
            1;

    ------------------------------------------------------------
    -- 6. ResidentDetails ID collision protection
    ------------------------------------------------------------

    IF EXISTS
    (
        SELECT 1
        FROM #SelectedResidentDetails AS d

        JOIN KFMC.Housing.ResidentInfo AS r
            ON TRY_CONVERT(BIGINT, r.generalNo) =
               TRY_CONVERT(BIGINT, d.generalNo_FK)

        JOIN Housing.ResidentDetails AS t
            ON t.residentDetailsID =
               TRY_CONVERT(BIGINT, d.residentDetailsID)

        WHERE t.residentInfoID_FK <>
              TRY_CONVERT(BIGINT, r.residentInfoID)
    )
        THROW 51003,
            N'A ResidentDetails ID belongs to a different resident.',
            1;

    ------------------------------------------------------------
    -- 7. Migrate eligible residents and selected details
    ------------------------------------------------------------

    BEGIN TRY

        BEGIN TRANSACTION;

        --------------------------------------------------------
        -- ResidentInfo
        --------------------------------------------------------

        SET IDENTITY_INSERT Housing.ResidentInfo ON;
        SET @IdentityInsertInfoOn = 1;

        INSERT INTO Housing.ResidentInfo
        (
            residentInfoID,
            residentInfoUID,
            NationalID,
            residentInfoActive,
            entryDate,
            entryData,
            hostName
        )
        SELECT
            TRY_CONVERT(BIGINT, s.residentInfoID),
            s.residentInfoUID,
            s.NationalID,
            s.residentInfoActive,
            s.entryDate,
            MoveData.fn_MapEntryData(s.entryData),
            MoveData.fn_MapHostName
            (
                s.hostName,
                s.entryData
            )

        FROM KFMC.Housing.ResidentInfo AS s

        WHERE EXISTS
        (
            SELECT 1
            FROM #SelectedResidentDetails AS d
            WHERE TRY_CONVERT(BIGINT, d.generalNo_FK) =
                  TRY_CONVERT(BIGINT, s.generalNo)
        )

        AND NOT EXISTS
        (
            SELECT 1
            FROM Housing.ResidentInfo AS t
            WHERE t.residentInfoID =
                  TRY_CONVERT(BIGINT, s.residentInfoID)
        );

        SET @ResidentInfoInserted = @@ROWCOUNT;

        SET IDENTITY_INSERT Housing.ResidentInfo OFF;
        SET @IdentityInsertInfoOn = 0;

        --------------------------------------------------------
        -- ResidentDetails
        --------------------------------------------------------

        SET IDENTITY_INSERT Housing.ResidentDetails ON;
        SET @IdentityInsertDetailsOn = 1;

        INSERT INTO Housing.ResidentDetails
        (
            residentDetailsID,
            residentInfoID_FK,
            generalNo_FK,
            rankID_FK,
            militaryUnitID_FK,
            martialStatusID_FK,
            dependinceCounter,
            nationalityID_FK,
            genderID_FK,

            firstName_A,
            secondName_A,
            thirdName_A,
            lastName_A,

            firstName_E,
            secondName_E,
            thirdName_E,
            lastName_E,

            note,
            birthdate,
            residentDetailsStartDate,
            residentDetailsEndDate,
            IdaraId_FK,
            residentDetailsActive,
            entryDate,
            entryData,
            hostName
        )
        SELECT
            TRY_CONVERT(BIGINT, d.residentDetailsID),
            TRY_CONVERT(BIGINT, r.residentInfoID),
            TRY_CONVERT(BIGINT, d.generalNo_FK),

            d.rankID_FK,
            d.militaryUnitID_FK,
            d.martialStatusID_FK,
            d.dependinceCounter,
            d.nationalityID_FK,
            d.genderID_FK,

            r.firstName_A,
            r.secondName_A,
            r.thirdName_A,
            r.lastName_A,

            r.firstName_E,
            r.secondName_E,
            r.thirdName_E,
            r.lastName_E,

            r.note,
            r.birthdate,

            d.entryDate,
            NULL,
            @IdaraId,
            d.residentDetailsActive,
            d.entryDate,

            MoveData.fn_MapEntryData(d.entryData),

            MoveData.fn_MapHostName
            (
                d.hostName,
                d.entryData
            )

        FROM #SelectedResidentDetails AS d

        JOIN KFMC.Housing.ResidentInfo AS r
            ON TRY_CONVERT(BIGINT, r.generalNo) =
               TRY_CONVERT(BIGINT, d.generalNo_FK)

        WHERE NOT EXISTS
        (
            SELECT 1
            FROM Housing.ResidentDetails AS t
            WHERE t.residentDetailsID =
                  TRY_CONVERT(BIGINT, d.residentDetailsID)
        );

        SET @ResidentDetailsInserted = @@ROWCOUNT;

        SET IDENTITY_INSERT Housing.ResidentDetails OFF;
        SET @IdentityInsertDetailsOn = 0;

        --------------------------------------------------------
        -- 8. Validate no orphan details
        --------------------------------------------------------

        IF EXISTS
        (
            SELECT 1
            FROM Housing.ResidentDetails AS d

            LEFT JOIN Housing.ResidentInfo AS r
                ON r.residentInfoID = d.residentInfoID_FK

            WHERE r.residentInfoID IS NULL
        )
            THROW 51004,
                N'Migration created orphan ResidentDetails.',
                1;

        --------------------------------------------------------
        -- 9. Results
        --------------------------------------------------------

        SELECT
            @RollbackAfterTest AS RollbackAfterTest,
            @ResidentInfoInserted AS ResidentInfoInserted,
            @ResidentDetailsInserted AS ResidentDetailsInserted,

            (
                SELECT COUNT_BIG(*)
                FROM Housing.ResidentInfo
            ) AS TargetResidentInfoTotal,

            (
                SELECT COUNT_BIG(*)
                FROM Housing.ResidentDetails
            ) AS TargetResidentDetailsTotal;

        --------------------------------------------------------
        -- 10. Commit or rollback
        --------------------------------------------------------

        IF @RollbackAfterTest = 1
            ROLLBACK TRANSACTION;
        ELSE
            COMMIT TRANSACTION;

    END TRY

    BEGIN CATCH

        IF @IdentityInsertDetailsOn = 1
            SET IDENTITY_INSERT Housing.ResidentDetails OFF;

        IF @IdentityInsertInfoOn = 1
            SET IDENTITY_INSERT Housing.ResidentInfo OFF;

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;