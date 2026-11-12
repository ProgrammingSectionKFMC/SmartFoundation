CREATE PROCEDURE [MoveData].[usp_MigrateResidents]
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

    
    /* TRIAL2_GENERIC_RESIDENT_ELIGIBILITY_20261105
       Action count is across the source resident's generalNo, NOT hardcoded IDs. */
    SELECT
        TRY_CONVERT(bigint,r.residentInfoID) AS ResidentInfoID,
        TRY_CONVERT(bigint,r.generalNo) AS GeneralNo
    INTO #EligibleMigrationResidents
    FROM [KFMC].[Housing].[ResidentInfo] r
WHERE r.residentInfoActive = 1
  AND TRY_CONVERT(bigint,r.generalNo) IS NOT NULL
  AND TRY_CONVERT(bigint,r.generalNo) NOT IN (0,1,18)
  AND EXISTS
      (
          SELECT 1
          FROM [KFMC].[Housing].[BuildingAction] a
          WHERE a.generalNo_FK = TRY_CONVERT(bigint,r.generalNo)
          GROUP BY a.generalNo_FK
          HAVING COUNT_BIG(*) > 1
             OR MAX(CASE WHEN a.buildingActionTypeID_FK <> 6 THEN 1 ELSE 0 END) = 1
      );
    /* RESIDENT_IDENTITY_GATES_NO_UID_20261107
       Source: KFMC read-only. Diagnose ALL offending rows before THROW.
       Target has no generalNo on ResidentInfo: resolve it through ResidentDetails.
       An eligible source resident without details remains eligible. */
    CREATE TABLE #ResidentMigrationConflicts
    (
        ConflictType nvarchar(90) NOT NULL,
        ConflictKey nvarchar(200) NULL,
        SourceResidentInfoID bigint NULL,
        SourceGeneralNo bigint NULL,
        SourceNationalID nvarchar(100) NULL,
        TargetResidentInfoID bigint NULL,
        TargetGeneralNo bigint NULL,
        TargetNationalID nvarchar(100) NULL,
        ExplanationArabic nvarchar(500) NOT NULL
    );

    SELECT e.ResidentInfoID, e.GeneralNo,
           NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),s.NationalID))),N'') AS NationalID
      INTO #EligibleResidentIdentity
    FROM #EligibleMigrationResidents e
    JOIN KFMC.Housing.ResidentInfo s
      ON TRY_CONVERT(bigint,s.residentInfoID)=e.ResidentInfoID;

    /* 1 - duplicate eligible source general number: output every row. */
    INSERT #ResidentMigrationConflicts
    (ConflictType,ConflictKey,SourceResidentInfoID,SourceGeneralNo,SourceNationalID,ExplanationArabic)
    SELECT N'SOURCE_DUPLICATE_GENERAL',CONVERT(nvarchar(200),s.GeneralNo),
           s.ResidentInfoID,s.GeneralNo,s.NationalID,
           N'الرقم العام مرتبط بأكثر من سجل مستفيد مؤهل في KFMC'
    FROM #EligibleResidentIdentity s
    WHERE EXISTS
      (SELECT 1 FROM #EligibleResidentIdentity g
       WHERE g.GeneralNo=s.GeneralNo
       GROUP BY g.GeneralNo HAVING COUNT_BIG(*)>1);

    /* 2 - duplicate nonblank national ID among eligible source residents. */
    INSERT #ResidentMigrationConflicts
    (ConflictType,ConflictKey,SourceResidentInfoID,SourceGeneralNo,SourceNationalID,ExplanationArabic)
    SELECT N'SOURCE_DUPLICATE_NATIONAL_ID',s.NationalID,
           s.ResidentInfoID,s.GeneralNo,s.NationalID,
           N'رقم الهوية مرتبط بأكثر من مستفيد مؤهل في KFMC'
    FROM #EligibleResidentIdentity s
    WHERE s.NationalID IS NOT NULL
      AND EXISTS
      (SELECT 1 FROM #EligibleResidentIdentity n
       WHERE n.NationalID=s.NationalID
       GROUP BY n.NationalID HAVING COUNT_BIG(*)>1);

    /* 3a - source's generalNo already assigned in target to a different ID.
       DISTINCT because target can have multiple historical details for one ID. */
    INSERT #ResidentMigrationConflicts
    (ConflictType,ConflictKey,SourceResidentInfoID,SourceGeneralNo,SourceNationalID,
     TargetResidentInfoID,TargetGeneralNo,TargetNationalID,ExplanationArabic)
    SELECT DISTINCT N'TARGET_GENERAL_ASSIGNED_TO_OTHER_ID',CONVERT(nvarchar(200),s.GeneralNo),
           s.ResidentInfoID,s.GeneralNo,s.NationalID,
           t.residentInfoID,TRY_CONVERT(bigint,d.generalNo_FK),
           NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),t.NationalID))),N''),
           N'الرقم العام للمصدر موجود في تفاصيل مستفيد آخر في DATACORE'
    FROM #EligibleResidentIdentity s
    JOIN Housing.ResidentDetails d
      ON TRY_CONVERT(bigint,d.generalNo_FK)=s.GeneralNo
    JOIN Housing.ResidentInfo t ON t.residentInfoID=d.residentInfoID_FK
    WHERE t.residentInfoID<>s.ResidentInfoID;

    /* 3b - same source/target resident ID, but historical target generalNo differs.
       This is a genuine collision on an existing detail, not a missing-detail case. */
    INSERT #ResidentMigrationConflicts
    (ConflictType,ConflictKey,SourceResidentInfoID,SourceGeneralNo,SourceNationalID,
     TargetResidentInfoID,TargetGeneralNo,TargetNationalID,ExplanationArabic)
    SELECT DISTINCT N'TARGET_ID_HAS_OTHER_GENERAL',CONVERT(nvarchar(200),s.ResidentInfoID),
           s.ResidentInfoID,s.GeneralNo,s.NationalID,
           t.residentInfoID,TRY_CONVERT(bigint,d.generalNo_FK),
           NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),t.NationalID))),N''),
           N'معرف المستفيد مطابق لكن تفاصيله في DATACORE مرتبطة برقم عام مختلف'
    FROM #EligibleResidentIdentity s
    JOIN Housing.ResidentInfo t ON t.residentInfoID=s.ResidentInfoID
    JOIN Housing.ResidentDetails d ON d.residentInfoID_FK=t.residentInfoID
    WHERE TRY_CONVERT(bigint,d.generalNo_FK) IS NULL
       OR TRY_CONVERT(bigint,d.generalNo_FK)<>s.GeneralNo;

    /* 3c - target resident identity conflict, even without target details. */
    INSERT #ResidentMigrationConflicts
    (ConflictType,ConflictKey,SourceResidentInfoID,SourceGeneralNo,SourceNationalID,
     TargetResidentInfoID,TargetNationalID,ExplanationArabic)
    SELECT N'TARGET_IDENTITY_MISMATCH',CONVERT(nvarchar(200),s.ResidentInfoID),
           s.ResidentInfoID,s.GeneralNo,s.NationalID,t.residentInfoID,
           NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),t.NationalID))),N''),
           N'معرف المستفيد موجود لكن رقم الهوية الوطنية في الهدف لا يطابق المصدر'
    FROM #EligibleResidentIdentity s
    JOIN Housing.ResidentInfo t ON t.residentInfoID=s.ResidentInfoID
    WHERE ISNULL(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),t.NationalID))),N''),N'')
          <> ISNULL(s.NationalID,N'');

    /* 3d - source national ID belongs to a different target resident ID.
       A matching source/target record with the SAME ID is normal. */
    INSERT #ResidentMigrationConflicts
    (ConflictType,ConflictKey,SourceResidentInfoID,SourceGeneralNo,SourceNationalID,
     TargetResidentInfoID,TargetNationalID,ExplanationArabic)
    SELECT DISTINCT N'TARGET_NATIONAL_ID_OTHER_ID',s.NationalID,
           s.ResidentInfoID,s.GeneralNo,s.NationalID,t.residentInfoID,
           NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),t.NationalID))),N''),
           N'رقم هوية المصدر مستخدم لمعرف مستفيد مختلف في DATACORE'
    FROM #EligibleResidentIdentity s
    JOIN Housing.ResidentInfo t
      ON NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),t.NationalID))),N'')=s.NationalID
     AND t.residentInfoID<>s.ResidentInfoID
    WHERE s.NationalID IS NOT NULL;


    IF EXISTS (SELECT 1 FROM #ResidentMigrationConflicts)
    BEGIN
        SELECT ConflictType,COUNT_BIG(*) AS ConflictRows,
               COUNT(DISTINCT SourceResidentInfoID) AS AffectedSourceResidents
        FROM #ResidentMigrationConflicts
        GROUP BY ConflictType ORDER BY ConflictType;

        SELECT ConflictType,ConflictKey,SourceResidentInfoID,SourceGeneralNo,
               SourceNationalID,TargetResidentInfoID,TargetGeneralNo,
               TargetNationalID,ExplanationArabic
        FROM #ResidentMigrationConflicts
        ORDER BY ConflictType,ConflictKey,SourceGeneralNo,
                 SourceResidentInfoID,TargetResidentInfoID;

        THROW 58212,
          N'Resident migration identity/generalNo conflict: diagnostic result sets returned; no residents inserted.',1;
    END;

    IF EXISTS (SELECT 1 FROM #EligibleMigrationResidents
               WHERE ResidentInfoID IS NULL OR GeneralNo IS NULL)
        THROW 58210,N'Eligible KFMC resident has missing identity; cannot safely migrate.',1;

    CREATE UNIQUE CLUSTERED INDEX IX_EligibleMigrationResidents_ResidentInfo
      ON #EligibleMigrationResidents(ResidentInfoID);
    CREATE UNIQUE INDEX IX_EligibleMigrationResidents_GeneralNo
      ON #EligibleMigrationResidents(GeneralNo);

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
    WHERE MigrationRank = 1
          AND EXISTS
          (
              SELECT 1 FROM #EligibleMigrationResidents e
              WHERE e.GeneralNo=TRY_CONVERT(bigint,RankedDetails.generalNo_FK)
          );

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
              SELECT 1 FROM #EligibleMigrationResidents e
              WHERE e.ResidentInfoID=TRY_CONVERT(bigint,s.residentInfoID)
          ) AND NOT EXISTS
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