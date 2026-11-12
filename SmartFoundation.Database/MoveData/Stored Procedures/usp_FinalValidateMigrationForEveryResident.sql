CREATE PROCEDURE [MoveData].[usp_FinalValidateMigrationForEveryResident]
      @IdaraId            BIGINT = 1
    , @GeneralNo          BIGINT = NULL
    , @CutoverDate        DATE = NULL
    , @WaterMonthlyAmount DECIMAL(18,2) = 8.25
    , @OnlyFailures       BIT = 1
    , @FailOnMismatch     BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    ------------------------------------------------------------
    -- IMPORTANT
    --
    -- FINAL implementation scope:
    --   Resident Population / Identity / Data
    --   Resident Contacts
    --   Actions + generated migration workflow
    --   Electricity / Rent / Water / Penalty Claims
    --   Payments + Payment Types
    --   Payment Links / Link Status
    --   Financial Reconciliation
    --   Current / Last Action Parity
    --   Final Resident status + Final Cutover Gate
    --
    -- IMPORTANT:
    --   A scoped @GeneralNo execution can PASS its scope, but it
    --   can never open IsFinalCutoverGateReady. The final gate is
    --   available only on the full-population run (@GeneralNo IS NULL).
    ------------------------------------------------------------


    ------------------------------------------------------------
    -- 0. Environment validation
    ------------------------------------------------------------

    IF DB_NAME() <> N'DATACORE'
        THROW 59900,
              N'This validation procedure must run in DATACORE.',
              1;

    IF DB_ID(N'KFMC') IS NULL
        THROW 59901,
              N'KFMC database is not available.',
              1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Idara
        WHERE idaraID = 1
    )
        THROW 59902,
              N'Default Idara 1 does not exist.',
              1;

    /*
        Keep the same Idara normalization contract
        used by MoveData.usp_MigrateResidents.
    */
    IF @IdaraId IS NULL
       OR NOT EXISTS
          (
              SELECT 1
              FROM dbo.Idara
              WHERE idaraID = @IdaraId
          )
    BEGIN
        SET @IdaraId = 1;
    END;


        ------------------------------------------------------------
    -- Final migration parameters
    ------------------------------------------------------------

    IF @CutoverDate IS NULL
    BEGIN
        SELECT TOP (1)
            @CutoverDate = l.CutoverDate
        FROM MoveData.MigrationExecutionLog l
        WHERE l.IdaraId = @IdaraId
          AND l.RollbackAfterTest = 0
          AND l.ExecutionStatus = 'Succeeded'
          AND l.CutoverDate IS NOT NULL
          AND NOT EXISTS
          (
              SELECT 1
              FROM MoveData.MigrationExecutionLog failedStep
              WHERE failedStep.MigrationRunID = l.MigrationRunID
                AND failedStep.ExecutionStatus <> 'Succeeded'
          )
        ORDER BY l.CompletedAt DESC;
    END;

    IF @CutoverDate IS NULL
        THROW 59903,
              N'لا يمكن تحديد CutoverDate المستخدم في الترحيل.',
              1;

    IF @CutoverDate > CAST(GETDATE() AS date)
        THROW 59904,
              N'CutoverDate لا يمكن أن يكون في المستقبل.',
              1;

    IF @WaterMonthlyAmount < 0
        THROW 59905,
              N'WaterMonthlyAmount لا يمكن أن يكون سالباً.',
              1;

    DECLARE @HistoricalEndDate date =
        EOMONTH(DATEADD(month, -1, @CutoverDate));

    DECLARE @RentChargeStartDate date =
        CONVERT(date, '20171001', 112);

    DECLARE @WaterChargeStartDate date =
        CONVERT(date, '20240101', 112);


    ------------------------------------------------------------
    -- 1. Central failure table
    ------------------------------------------------------------

    CREATE TABLE #ValidationIssues
    (
          FailureID        BIGINT IDENTITY(1,1) NOT NULL
        , EntityKey        NVARCHAR(100) NULL
        , GeneralNo        BIGINT NULL
        , ResidentInfoID   BIGINT NULL
        , ResidentDetailsID BIGINT NULL
        , FullName         NVARCHAR(1000) NULL

        , SectionName      NVARCHAR(100) NOT NULL
        , IssueCode        NVARCHAR(150) NOT NULL

        , SourceObject     NVARCHAR(300) NULL
        , TargetObject     NVARCHAR(300) NULL
        , ReferenceID      NVARCHAR(500) NULL
        , FieldName        NVARCHAR(200) NULL

        , ExpectedValue    NVARCHAR(MAX) NULL
        , ActualValue      NVARCHAR(MAX) NULL

        , Severity         VARCHAR(20) NOT NULL
        , Notes            NVARCHAR(2000) NULL
    );


    ------------------------------------------------------------
    -- 2. Reproduce EXACT ResidentDetails selection
    --    from current MoveData.usp_MigrateResidents
    ------------------------------------------------------------

    /* Use the exact resident eligibility policy of usp_MigrateResidents. */
SELECT
    TRY_CONVERT(BIGINT, r.residentInfoID) AS ResidentInfoID,
    TRY_CONVERT(BIGINT, r.generalNo) AS GeneralNo
INTO #EligibleMigrationResidents
FROM KFMC.Housing.ResidentInfo r
WHERE r.residentInfoActive = 1
  AND TRY_CONVERT(BIGINT, r.generalNo) IS NOT NULL
  AND TRY_CONVERT(BIGINT, r.generalNo) NOT IN (0,1,18)
  AND EXISTS
  (
      SELECT 1
      FROM KFMC.Housing.BuildingAction a
      WHERE a.generalNo_FK = TRY_CONVERT(BIGINT, r.generalNo)
      GROUP BY a.generalNo_FK
      HAVING COUNT_BIG(*) > 1
         OR MAX(
             CASE WHEN a.buildingActionTypeID_FK <> 6
                  THEN 1 ELSE 0 END
         ) = 1
  );

;WITH RankedDetails AS
(
    SELECT
        d.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY d.generalNo_FK
            ORDER BY
                CASE WHEN d.residentDetailsActive = 1
                     THEN 0 ELSE 1 END,
                d.entryDate DESC,
                d.residentDetailsID DESC
        ) AS MigrationRank
    FROM KFMC.Housing.ResidentDetails d
)
SELECT d.*
INTO #SelectedResidentDetails
FROM RankedDetails d
JOIN #EligibleMigrationResidents e
  ON e.GeneralNo = TRY_CONVERT(BIGINT, d.generalNo_FK)
WHERE d.MigrationRank = 1;



/* Eligible residents must be validated even without ResidentDetails. */
INSERT INTO #ValidationIssues
(
    EntityKey,
    GeneralNo,
    ResidentInfoID,
    SectionName,
    IssueCode,
    SourceObject,
    TargetObject,
    ReferenceID,
    FieldName,
    ExpectedValue,
    ActualValue,
    Severity,
    Notes
)
SELECT
    CONCAT(N'G:', e.GeneralNo),
    e.GeneralNo,
    e.ResidentInfoID,
    N'POPULATION',
    N'ELIGIBLE_RESIDENT_WITHOUT_DETAILS_NOT_MIGRATED',
    N'KFMC.Housing.ResidentInfo',
    N'DATACORE.Housing.ResidentInfo',
    CONVERT(NVARCHAR(100), e.ResidentInfoID),
    N'residentInfoID',
    CONVERT(NVARCHAR(100), e.ResidentInfoID),
    NULL,
    'ERROR',
    N'المستفيد مؤهل للترحيل رغم عدم وجود ResidentDetails، ولكن سجل ResidentInfo غير موجود في DATACORE.'
FROM #EligibleMigrationResidents e
WHERE NOT EXISTS
(
    SELECT 1
    FROM #SelectedResidentDetails d
    WHERE TRY_CONVERT(BIGINT, d.generalNo_FK) = e.GeneralNo
)
AND NOT EXISTS
(
    SELECT 1
    FROM Housing.ResidentInfo t
    WHERE t.residentInfoID = e.ResidentInfoID
)
AND
(
    @GeneralNo IS NULL
    OR e.GeneralNo = @GeneralNo
);
    ------------------------------------------------------------
    -- 3. Ownership validation:
    --    selected ResidentDetails must map to exactly ONE
    --    KFMC ResidentInfo.
    ------------------------------------------------------------

    SELECT
          TRY_CONVERT(BIGINT, d.generalNo_FK) AS GeneralNo
        , TRY_CONVERT(BIGINT, d.residentDetailsID) AS ResidentDetailsID
        , COUNT_BIG(r.ResidentInfoID) AS ResidentInfoMatches
    INTO #SelectedDetailsOwnership
    FROM #SelectedResidentDetails d
    LEFT JOIN #EligibleMigrationResidents r
        ON r.GeneralNo = TRY_CONVERT(BIGINT, d.generalNo_FK)
    WHERE
        @GeneralNo IS NULL
        OR TRY_CONVERT(BIGINT, d.generalNo_FK) = @GeneralNo
    GROUP BY
          TRY_CONVERT(BIGINT, d.generalNo_FK)
        , TRY_CONVERT(BIGINT, d.residentDetailsID);


    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentDetailsID
        , SectionName
        , IssueCode
        , SourceObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          CASE
              WHEN o.GeneralNo IS NOT NULL
                  THEN CONCAT(N'G:', o.GeneralNo)
              ELSE CONCAT(N'D:', o.ResidentDetailsID)
          END
        , o.GeneralNo
        , o.ResidentDetailsID
        , N'POPULATION'
        , N'SOURCE_RESIDENT_DETAILS_NOT_UNIQUELY_MAPPED'
        , N'KFMC.Housing.ResidentDetails / ResidentInfo'
        , CONVERT(NVARCHAR(100), o.ResidentDetailsID)
        , N'ResidentInfoMatches'
        , N'1'
        , CONVERT(NVARCHAR(100), o.ResidentInfoMatches)
        , 'ERROR'
        , N'The selected ResidentDetails must map to exactly one source ResidentInfo.'
    FROM #SelectedDetailsOwnership o
    WHERE o.ResidentInfoMatches <> 1;


    ------------------------------------------------------------
    -- 4. Build authoritative expected resident dataset
    ------------------------------------------------------------

    SELECT
          CONCAT
          (
              N'G:',
              CONVERT
              (
                  NVARCHAR(40),
                  eligible.GeneralNo
              )
          ) AS EntityKey

        , eligible.GeneralNo AS GeneralNo

        --------------------------------------------------------
        -- ResidentInfo source / expected
        --------------------------------------------------------
        , TRY_CONVERT(BIGINT, r.residentInfoID)
            AS SourceResidentInfoID

        , r.residentInfoUID
            AS SourceResidentInfoUID

        , r.NationalID
            AS SourceNationalID

        , r.residentInfoActive
            AS SourceResidentInfoActive

        , r.entryDate
            AS SourceResidentInfoEntryDate

        , MoveData.fn_MapEntryData(r.entryData)
            AS ExpectedResidentInfoEntryData

        , MoveData.fn_MapHostName
          (
              r.hostName,
              r.entryData
          )
            AS ExpectedResidentInfoHostName


        --------------------------------------------------------
        -- Selected ResidentDetails source / expected
        --------------------------------------------------------
        , TRY_CONVERT(BIGINT, d.residentDetailsID)
            AS SourceResidentDetailsID

        , d.rankID_FK
        , d.militaryUnitID_FK
        , d.martialStatusID_FK
        , d.dependinceCounter
        , d.nationalityID_FK
        , d.genderID_FK

        --------------------------------------------------------
        -- Names are copied from ResidentInfo
        --------------------------------------------------------
        , r.firstName_A
        , r.secondName_A
        , r.thirdName_A
        , r.lastName_A

        , r.firstName_E
        , r.secondName_E
        , r.thirdName_E
        , r.lastName_E

        , r.note
        , r.birthdate

        --------------------------------------------------------
        -- Current migration transformations
        --------------------------------------------------------
        , d.entryDate
            AS ExpectedResidentDetailsStartDate

        , CAST(NULL AS DATETIME)
            AS ExpectedResidentDetailsEndDate

        , @IdaraId
            AS ExpectedIdaraId

        , d.residentDetailsActive
            AS ExpectedResidentDetailsActive

        , d.entryDate
            AS ExpectedResidentDetailsEntryDate

        , MoveData.fn_MapEntryData(d.entryData)
            AS ExpectedResidentDetailsEntryData

        , MoveData.fn_MapHostName
          (
              d.hostName,
              d.entryData
          )
            AS ExpectedResidentDetailsHostName

        , LTRIM
          (
              RTRIM
              (
                  CONCAT_WS
                  (
                      N' ',
                      r.firstName_A,
                      r.secondName_A,
                      r.thirdName_A,
                      r.lastName_A
                  )
              )
          ) AS FullName

    INTO #ExpectedResidents

    FROM #EligibleMigrationResidents eligible

    JOIN KFMC.Housing.ResidentInfo r
        ON TRY_CONVERT(BIGINT, r.residentInfoID) = eligible.ResidentInfoID
       AND r.residentInfoActive = 1

    LEFT JOIN #SelectedResidentDetails d
        ON TRY_CONVERT(BIGINT, d.generalNo_FK) = eligible.GeneralNo

    LEFT JOIN #SelectedDetailsOwnership o
        ON o.ResidentDetailsID = TRY_CONVERT(BIGINT, d.residentDetailsID)

    WHERE (@GeneralNo IS NULL OR eligible.GeneralNo = @GeneralNo)
      AND (d.residentDetailsID IS NULL OR o.ResidentInfoMatches = 1);


    ------------------------------------------------------------
    -- 5. Requested GeneralNo does not exist in KFMC
    ------------------------------------------------------------

    IF @GeneralNo IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM KFMC.Housing.ResidentInfo r
           WHERE TRY_CONVERT(BIGINT, r.generalNo) = @GeneralNo
       )
    BEGIN
        INSERT INTO #ValidationIssues
        (
              EntityKey
            , GeneralNo
            , SectionName
            , IssueCode
            , SourceObject
            , FieldName
            , ExpectedValue
            , ActualValue
            , Severity
            , Notes
        )
        VALUES
        (
              CONCAT(N'G:', @GeneralNo)
            , @GeneralNo
            , N'POPULATION'
            , N'REQUESTED_GENERALNO_NOT_FOUND_IN_KFMC'
            , N'KFMC.Housing.ResidentInfo'
            , N'generalNo'
            , CONVERT(NVARCHAR(100), @GeneralNo)
            , NULL
            , 'ERROR'
            , N'The requested GeneralNo does not exist in the KFMC source database.'
        );
    END;


    ------------------------------------------------------------
    -- 6. Missing ResidentInfo in DATACORE
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName

        , SectionName
        , IssueCode

        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName

        , ExpectedValue
        , ActualValue

        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.SourceResidentInfoID
        , e.SourceResidentDetailsID
        , e.FullName

        , N'POPULATION'
        , N'MISSING_TARGET_RESIDENTINFO'

        , N'KFMC.Housing.ResidentInfo'
        , N'DATACORE.Housing.ResidentInfo'
        , CONVERT(NVARCHAR(100), e.SourceResidentInfoID)
        , N'residentInfoID'

        , CONVERT(NVARCHAR(100), e.SourceResidentInfoID)
        , NULL

        , 'ERROR'
        , N'An eligible source resident was not found in DATACORE by the preserved residentInfoID.'
    FROM #ExpectedResidents e
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM Housing.ResidentInfo t
        WHERE t.residentInfoID = e.SourceResidentInfoID
    );


    ------------------------------------------------------------
    -- 7. Missing selected ResidentDetails in DATACORE
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName

        , SectionName
        , IssueCode

        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName

        , ExpectedValue
        , ActualValue

        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.SourceResidentInfoID
        , e.SourceResidentDetailsID
        , e.FullName

        , N'POPULATION'
        , N'MISSING_TARGET_RESIDENTDETAILS'

        , N'KFMC.Housing.ResidentDetails'
        , N'DATACORE.Housing.ResidentDetails'
        , CONVERT(NVARCHAR(100), e.SourceResidentDetailsID)
        , N'residentDetailsID'

        , CONVERT(NVARCHAR(100), e.SourceResidentDetailsID)
        , NULL

        , 'ERROR'
        , N'The selected source ResidentDetails row was not found in DATACORE by its preserved ID.'
    FROM #ExpectedResidents e
    WHERE e.SourceResidentDetailsID IS NOT NULL
      AND NOT EXISTS
    (
        SELECT 1
        FROM Housing.ResidentDetails t
        WHERE t.residentDetailsID = e.SourceResidentDetailsID
    );


    ------------------------------------------------------------
    -- 8. Unexpected ResidentInfo in DATACORE
    --
    -- Checked globally, or limited to the requested resident.
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName

        , SectionName
        , IssueCode

        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName

        , ExpectedValue
        , ActualValue

        , Severity
        , Notes
    )
    SELECT
          CASE
              WHEN TRY_CONVERT(BIGINT, td.generalNo_FK) IS NOT NULL
                  THEN CONCAT
                       (
                           N'G:',
                           TRY_CONVERT(BIGINT, td.generalNo_FK)
                       )

              WHEN TRY_CONVERT(BIGINT, sr.generalNo) IS NOT NULL
                  THEN CONCAT
                       (
                           N'G:',
                           TRY_CONVERT(BIGINT, sr.generalNo)
                       )

              ELSE CONCAT
                   (
                       N'R:',
                       t.residentInfoID
                   )
          END

        , COALESCE
          (
              TRY_CONVERT(BIGINT, td.generalNo_FK),
              TRY_CONVERT(BIGINT, sr.generalNo)
          )

        , t.residentInfoID
        , td.residentDetailsID

        , LTRIM
          (
              RTRIM
              (
                  CONCAT_WS
                  (
                      N' ',
                      td.firstName_A,
                      td.secondName_A,
                      td.thirdName_A,
                      td.lastName_A
                  )
              )
          )

        , N'POPULATION'
        , N'UNEXPECTED_TARGET_RESIDENTINFO'

        , N'KFMC.Housing.ResidentInfo'
        , N'DATACORE.Housing.ResidentInfo'

        , CONVERT(NVARCHAR(100), t.residentInfoID)
        , N'residentInfoID'

        , NULL
        , CONVERT(NVARCHAR(100), t.residentInfoID)

        , 'ERROR'
        , N'DATACORE contains a ResidentInfo row that is not part of the eligible migrated resident population.'
    FROM Housing.ResidentInfo t

    LEFT JOIN KFMC.Housing.ResidentInfo sr
        ON TRY_CONVERT(BIGINT, sr.residentInfoID)
         = t.residentInfoID

    OUTER APPLY
    (
        SELECT TOP (1)
            rd.*
        FROM Housing.ResidentDetails rd
        WHERE rd.residentInfoID_FK = t.residentInfoID
        ORDER BY rd.residentDetailsID DESC
    ) td

    WHERE NOT EXISTS
    (
        SELECT 1
        FROM #ExpectedResidents e
        WHERE e.SourceResidentInfoID = t.residentInfoID
    )
    AND
    (
        @GeneralNo IS NULL

        OR TRY_CONVERT(BIGINT, sr.generalNo) = @GeneralNo

        OR TRY_CONVERT(BIGINT, td.generalNo_FK) = @GeneralNo
    );


    ------------------------------------------------------------
    -- 9. Unexpected ResidentDetails in DATACORE
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName

        , SectionName
        , IssueCode

        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName

        , ExpectedValue
        , ActualValue

        , Severity
        , Notes
    )
    SELECT
          CASE
              WHEN TRY_CONVERT(BIGINT, t.generalNo_FK) IS NOT NULL
                  THEN CONCAT
                       (
                           N'G:',
                           TRY_CONVERT(BIGINT, t.generalNo_FK)
                       )
              ELSE CONCAT
                   (
                       N'R:',
                       t.residentInfoID_FK
                   )
          END

        , TRY_CONVERT(BIGINT, t.generalNo_FK)
        , t.residentInfoID_FK
        , t.residentDetailsID

        , LTRIM
          (
              RTRIM
              (
                  CONCAT_WS
                  (
                      N' ',
                      t.firstName_A,
                      t.secondName_A,
                      t.thirdName_A,
                      t.lastName_A
                  )
              )
          )

        , N'POPULATION'
        , N'UNEXPECTED_TARGET_RESIDENTDETAILS'

        , N'KFMC.Housing.ResidentDetails'
        , N'DATACORE.Housing.ResidentDetails'

        , CONVERT(NVARCHAR(100), t.residentDetailsID)
        , N'residentDetailsID'

        , NULL
        , CONVERT(NVARCHAR(100), t.residentDetailsID)

        , 'ERROR'
        , N'DATACORE contains a ResidentDetails row that is not the selected source version expected by the migration policy.'
    FROM Housing.ResidentDetails t

    WHERE NOT EXISTS
    (
        SELECT 1
        FROM #ExpectedResidents e
        WHERE e.SourceResidentDetailsID = t.residentDetailsID
    )
    AND
    (
        @GeneralNo IS NULL
        OR TRY_CONVERT(BIGINT, t.generalNo_FK) = @GeneralNo
    );


    ------------------------------------------------------------
    -- 10. Compare ResidentInfo fields exactly as migrated
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName

        , SectionName
        , IssueCode

        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName

        , ExpectedValue
        , ActualValue

        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.SourceResidentInfoID
        , e.SourceResidentDetailsID
        , e.FullName

        , N'RESIDENT_DATA'
        , N'RESIDENTINFO_VALUE_MISMATCH'

        , N'KFMC.Housing.ResidentInfo'
        , N'DATACORE.Housing.ResidentInfo'

        , CONVERT(NVARCHAR(100), e.SourceResidentInfoID)
        , v.FieldName

        , v.ExpectedValue
        , v.ActualValue

        , 'ERROR'
        , N'ResidentInfo value differs from the exact value expected after migration.'
    FROM #ExpectedResidents e

    JOIN Housing.ResidentInfo t
        ON t.residentInfoID = e.SourceResidentInfoID

    CROSS APPLY
    (
        VALUES

        (
            N'residentInfoUID',
            CONVERT(NVARCHAR(MAX), e.SourceResidentInfoUID),
            CONVERT(NVARCHAR(MAX), t.residentInfoUID)
        ),

        (
            N'NationalID',
            CONVERT(NVARCHAR(MAX), e.SourceNationalID),
            CONVERT(NVARCHAR(MAX), t.NationalID)
        ),

        (
            N'residentInfoActive',
            CONVERT(NVARCHAR(MAX), e.SourceResidentInfoActive),
            CONVERT(NVARCHAR(MAX), t.residentInfoActive)
        ),

        (
            N'entryDate',
            CONVERT
            (
                NVARCHAR(MAX),
                e.SourceResidentInfoEntryDate,
                126
            ),
            CONVERT
            (
                NVARCHAR(MAX),
                t.entryDate,
                126
            )
        ),

        (
            N'entryData',
            CONVERT
            (
                NVARCHAR(MAX),
                e.ExpectedResidentInfoEntryData
            ),
            CONVERT
            (
                NVARCHAR(MAX),
                t.entryData
            )
        ),

        (
            N'hostName',
            CONVERT
            (
                NVARCHAR(MAX),
                e.ExpectedResidentInfoHostName
            ),
            CONVERT
            (
                NVARCHAR(MAX),
                t.hostName
            )
        )

    ) v
    (
          FieldName
        , ExpectedValue
        , ActualValue
    )

    WHERE
           (
               v.ExpectedValue COLLATE DATABASE_DEFAULT
               <>
               v.ActualValue COLLATE DATABASE_DEFAULT
           )

        OR (
               v.ExpectedValue IS NULL
               AND v.ActualValue IS NOT NULL
           )

        OR (
               v.ExpectedValue IS NOT NULL
               AND v.ActualValue IS NULL
           );


    ------------------------------------------------------------
    -- 11. Compare selected ResidentDetails exactly
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName

        , SectionName
        , IssueCode

        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName

        , ExpectedValue
        , ActualValue

        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.SourceResidentInfoID
        , e.SourceResidentDetailsID
        , e.FullName

        , N'RESIDENT_DATA'
        , N'RESIDENTDETAILS_VALUE_MISMATCH'

        , N'KFMC.Housing.ResidentInfo / ResidentDetails'
        , N'DATACORE.Housing.ResidentDetails'

        , CONVERT(NVARCHAR(100), e.SourceResidentDetailsID)
        , v.FieldName

        , v.ExpectedValue
        , v.ActualValue

        , 'ERROR'
        , N'ResidentDetails value differs from the exact value expected after migration.'
    FROM #ExpectedResidents e

    JOIN Housing.ResidentDetails t
        ON t.residentDetailsID = e.SourceResidentDetailsID

    CROSS APPLY
    (
        VALUES

        (
            N'residentInfoID_FK',
            CONVERT
            (
                NVARCHAR(MAX),
                e.SourceResidentInfoID
            ),
            CONVERT
            (
                NVARCHAR(MAX),
                t.residentInfoID_FK
            )
        ),

        (
            N'generalNo_FK',
            CONVERT
            (
                NVARCHAR(MAX),
                e.GeneralNo
            ),
            CONVERT
            (
                NVARCHAR(MAX),
                t.generalNo_FK
            )
        ),

        (
            N'rankID_FK',
            CONVERT(NVARCHAR(MAX), e.rankID_FK),
            CONVERT(NVARCHAR(MAX), t.rankID_FK)
        ),

        (
            N'militaryUnitID_FK',
            CONVERT(NVARCHAR(MAX), e.militaryUnitID_FK),
            CONVERT(NVARCHAR(MAX), t.militaryUnitID_FK)
        ),

        (
            N'martialStatusID_FK',
            CONVERT(NVARCHAR(MAX), e.martialStatusID_FK),
            CONVERT(NVARCHAR(MAX), t.martialStatusID_FK)
        ),

        (
            N'dependinceCounter',
            CONVERT(NVARCHAR(MAX), e.dependinceCounter),
            CONVERT(NVARCHAR(MAX), t.dependinceCounter)
        ),

        (
            N'nationalityID_FK',
            CONVERT(NVARCHAR(MAX), e.nationalityID_FK),
            CONVERT(NVARCHAR(MAX), t.nationalityID_FK)
        ),

        (
            N'genderID_FK',
            CONVERT(NVARCHAR(MAX), e.genderID_FK),
            CONVERT(NVARCHAR(MAX), t.genderID_FK)
        ),

        (
            N'firstName_A',
            CONVERT(NVARCHAR(MAX), e.firstName_A),
            CONVERT(NVARCHAR(MAX), t.firstName_A)
        ),

        (
            N'secondName_A',
            CONVERT(NVARCHAR(MAX), e.secondName_A),
            CONVERT(NVARCHAR(MAX), t.secondName_A)
        ),

        (
            N'thirdName_A',
            CONVERT(NVARCHAR(MAX), e.thirdName_A),
            CONVERT(NVARCHAR(MAX), t.thirdName_A)
        ),

        (
            N'lastName_A',
            CONVERT(NVARCHAR(MAX), e.lastName_A),
            CONVERT(NVARCHAR(MAX), t.lastName_A)
        ),

        (
            N'firstName_E',
            CONVERT(NVARCHAR(MAX), e.firstName_E),
            CONVERT(NVARCHAR(MAX), t.firstName_E)
        ),

        (
            N'secondName_E',
            CONVERT(NVARCHAR(MAX), e.secondName_E),
            CONVERT(NVARCHAR(MAX), t.secondName_E)
        ),

        (
            N'thirdName_E',
            CONVERT(NVARCHAR(MAX), e.thirdName_E),
            CONVERT(NVARCHAR(MAX), t.thirdName_E)
        ),

        (
            N'lastName_E',
            CONVERT(NVARCHAR(MAX), e.lastName_E),
            CONVERT(NVARCHAR(MAX), t.lastName_E)
        ),

        (
            N'note',
            CONVERT(NVARCHAR(MAX), e.note),
            CONVERT(NVARCHAR(MAX), t.note)
        ),

        (
            N'birthdate',
            CONVERT
            (
                NVARCHAR(MAX),
                e.birthdate,
                126
            ),
            CONVERT
            (
                NVARCHAR(MAX),
                t.birthdate,
                126
            )
        ),

        (
            N'residentDetailsStartDate',
            CONVERT
            (
                NVARCHAR(MAX),
                e.ExpectedResidentDetailsStartDate,
                126
            ),
            CONVERT
            (
                NVARCHAR(MAX),
                t.residentDetailsStartDate,
                126
            )
        ),

        (
            N'residentDetailsEndDate',
            CAST(NULL AS NVARCHAR(MAX)),
            CONVERT
            (
                NVARCHAR(MAX),
                t.residentDetailsEndDate,
                126
            )
        ),

        (
            N'IdaraId_FK',
            CONVERT
            (
                NVARCHAR(MAX),
                e.ExpectedIdaraId
            ),
            CONVERT
            (
                NVARCHAR(MAX),
                t.IdaraId_FK
            )
        ),

        (
            N'residentDetailsActive',
            CONVERT
            (
                NVARCHAR(MAX),
                e.ExpectedResidentDetailsActive
            ),
            CONVERT
            (
                NVARCHAR(MAX),
                t.residentDetailsActive
            )
        ),

        (
            N'entryDate',
            CONVERT
            (
                NVARCHAR(MAX),
                e.ExpectedResidentDetailsEntryDate,
                126
            ),
            CONVERT
            (
                NVARCHAR(MAX),
                t.entryDate,
                126
            )
        ),

        (
            N'entryData',
            CONVERT
            (
                NVARCHAR(MAX),
                e.ExpectedResidentDetailsEntryData
            ),
            CONVERT
            (
                NVARCHAR(MAX),
                t.entryData
            )
        ),

        (
            N'hostName',
            CONVERT
            (
                NVARCHAR(MAX),
                e.ExpectedResidentDetailsHostName
            ),
            CONVERT
            (
                NVARCHAR(MAX),
                t.hostName
            )
        )

    ) v
    (
          FieldName
        , ExpectedValue
        , ActualValue
    )

    WHERE
           (
               v.ExpectedValue COLLATE DATABASE_DEFAULT
               <>
               v.ActualValue COLLATE DATABASE_DEFAULT
           )

        OR (
               v.ExpectedValue IS NULL
               AND v.ActualValue IS NOT NULL
           )

        OR (
               v.ExpectedValue IS NOT NULL
               AND v.ActualValue IS NULL
           );

    ------------------------------------------------------------
    -- 12. RESIDENT CONTACTS
    --
    -- Reproduce exactly what
    -- MoveData.usp_MigrateResidentContacts expects.
    --
    -- Business identity used by migration:
    --   Resident
    --   Contact Type
    --   Contact Details
    --   Start Date
    --   End Date
    --   Active
    --
    -- Additional migrated values validated:
    --   Note = NULL
    --   entryDate
    --   mapped entryData
    --   mapped hostName
    ------------------------------------------------------------


    ------------------------------------------------------------
    -- 12.1 Expected source contacts for ELIGIBLE residents
    ------------------------------------------------------------

    ;WITH ExpectedContactBase AS
    (
        SELECT
              e.EntityKey
            , e.GeneralNo
            , e.SourceResidentInfoID AS ResidentInfoID
            , e.SourceResidentDetailsID AS ResidentDetailsID
            , e.FullName

            , sourceContact.contanctTypeID_FK
                AS ContactTypeID

            , CONVERT
              (
                  NVARCHAR(4000),
                  sourceContact.contactDetails
              ) AS ContactDetails

            , CONVERT
              (
                  DATETIME2(3),
                  sourceContact.contactInfoStartDate
              ) AS ContactStartDate

            , CONVERT
              (
                  DATETIME2(3),
                  sourceContact.contactInfoEndDate
              ) AS ContactEndDate

            , sourceContact.contactInfoActive
                AS ContactActive

            /*
                usp_MigrateResidentContacts always writes NULL here.
            */
            , CAST(NULL AS NVARCHAR(4000))
                AS ExpectedContactNote

            , CONVERT
              (
                  DATETIME2(3),
                  sourceContact.entryDate
              ) AS ExpectedEntryDate

            , CONVERT
              (
                  NVARCHAR(4000),
                  MoveData.fn_MapEntryData
                  (
                      sourceContact.entryData
                  )
              ) AS ExpectedEntryData

            , CONVERT
              (
                  NVARCHAR(4000),
                  MoveData.fn_MapHostName
                  (
                      sourceContact.hostName,
                      sourceContact.entryData
                  )
              ) AS ExpectedHostName

        FROM #ExpectedResidents e

        JOIN KFMC.dbo.contactInfo sourceContact
            ON TRY_CONVERT
               (
                   BIGINT,
                   sourceContact.userID_FK
               ) = e.GeneralNo
    ),
    ExpectedContactRanked AS
    (
        SELECT
              b.*

            /*
                Preserve duplicate source contacts.

                If KFMC contains two identical contact rows,
                DATACORE is expected to contain two corresponding
                rows after migration.
            */
            , ROW_NUMBER() OVER
              (
                  PARTITION BY
                        b.ResidentInfoID
                      , b.ContactTypeID
                      , b.ContactDetails
                      , b.ContactStartDate
                      , b.ContactEndDate
                      , b.ContactActive

                  ORDER BY
                        b.ExpectedEntryDate
                      , b.ExpectedEntryData
                      , b.ExpectedHostName
              ) AS ContactOccurrence

        FROM ExpectedContactBase b
    )
    SELECT *
    INTO #ExpectedContacts
    FROM ExpectedContactRanked;



    ------------------------------------------------------------
    -- 12.2 Actual DATACORE contacts
    --      Only for residents in expected migration population
    ------------------------------------------------------------

    ;WITH ActualContactBase AS
    (
        SELECT
              e.EntityKey
            , e.GeneralNo
            , e.SourceResidentInfoID AS ResidentInfoID
            , e.SourceResidentDetailsID AS ResidentDetailsID
            , e.FullName

            , targetContact.residentcontanctTypeID_FK
                AS ContactTypeID

            , CONVERT
              (
                  NVARCHAR(4000),
                  targetContact.residentcontactDetails
              ) AS ContactDetails

            , CONVERT
              (
                  DATETIME2(3),
                  targetContact.residentcontactInfoStartDate
              ) AS ContactStartDate

            , CONVERT
              (
                  DATETIME2(3),
                  targetContact.residentcontactInfoEndDate
              ) AS ContactEndDate

            , targetContact.residentcontactInfoActive
                AS ContactActive

            , CONVERT
              (
                  NVARCHAR(4000),
                  targetContact.residentcontactInfoNote
              ) AS ActualContactNote

            , CONVERT
              (
                  DATETIME2(3),
                  targetContact.entryDate
              ) AS ActualEntryDate

            , CONVERT
              (
                  NVARCHAR(4000),
                  targetContact.entryData
              ) AS ActualEntryData

            , CONVERT
              (
                  NVARCHAR(4000),
                  targetContact.hostName
              ) AS ActualHostName

        FROM #ExpectedResidents e

        JOIN Housing.ResidentContactInfo targetContact
            ON targetContact.residentInfoID_FK
             = e.SourceResidentInfoID
    ),
    ActualContactRanked AS
    (
        SELECT
              b.*

            , ROW_NUMBER() OVER
              (
                  PARTITION BY
                        b.ResidentInfoID
                      , b.ContactTypeID
                      , b.ContactDetails
                      , b.ContactStartDate
                      , b.ContactEndDate
                      , b.ContactActive

                  ORDER BY
                        b.ActualEntryDate
                      , b.ActualEntryData
                      , b.ActualHostName
              ) AS ContactOccurrence

        FROM ActualContactBase b
    )
    SELECT *
    INTO #ActualContacts
    FROM ActualContactRanked;



    ------------------------------------------------------------
    -- 12.3 Match contacts by the SAME business identity
    --      used by usp_MigrateResidentContacts
    ------------------------------------------------------------

    SELECT
          COALESCE(e.EntityKey, a.EntityKey)
            AS EntityKey

        , COALESCE(e.GeneralNo, a.GeneralNo)
            AS GeneralNo

        , COALESCE(e.ResidentInfoID, a.ResidentInfoID)
            AS ResidentInfoID

        , COALESCE(e.ResidentDetailsID, a.ResidentDetailsID)
            AS ResidentDetailsID

        , COALESCE(e.FullName, a.FullName)
            AS FullName

        , e.ContactTypeID
            AS ExpectedContactTypeID

        , a.ContactTypeID
            AS ActualContactTypeID

        , e.ContactDetails
            AS ExpectedContactDetails

        , a.ContactDetails
            AS ActualContactDetails

        , e.ContactStartDate
            AS ExpectedContactStartDate

        , a.ContactStartDate
            AS ActualContactStartDate

        , e.ContactEndDate
            AS ExpectedContactEndDate

        , a.ContactEndDate
            AS ActualContactEndDate

        , e.ContactActive
            AS ExpectedContactActive

        , a.ContactActive
            AS ActualContactActive

        , e.ExpectedContactNote
        , a.ActualContactNote

        , e.ExpectedEntryDate
        , a.ActualEntryDate

        , e.ExpectedEntryData
        , a.ActualEntryData

        , e.ExpectedHostName
        , a.ActualHostName

        , e.ContactOccurrence
            AS ExpectedOccurrence

        , a.ContactOccurrence
            AS ActualOccurrence

    INTO #ContactComparison

    FROM #ExpectedContacts e

    FULL OUTER JOIN #ActualContacts a
        ON a.ResidentInfoID = e.ResidentInfoID

       AND
       (
            a.ContactTypeID = e.ContactTypeID
            OR
            (
                a.ContactTypeID IS NULL
                AND e.ContactTypeID IS NULL
            )
       )

       AND
       (
            a.ContactDetails = e.ContactDetails
            OR
            (
                a.ContactDetails IS NULL
                AND e.ContactDetails IS NULL
            )
       )

       AND
       (
            a.ContactStartDate = e.ContactStartDate
            OR
            (
                a.ContactStartDate IS NULL
                AND e.ContactStartDate IS NULL
            )
       )

       AND
       (
            a.ContactEndDate = e.ContactEndDate
            OR
            (
                a.ContactEndDate IS NULL
                AND e.ContactEndDate IS NULL
            )
       )

       AND
       (
            a.ContactActive = e.ContactActive
            OR
            (
                a.ContactActive IS NULL
                AND e.ContactActive IS NULL
            )
       )

       AND a.ContactOccurrence = e.ContactOccurrence;



    ------------------------------------------------------------
    -- 12.4 Missing expected contacts
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName

        , SectionName
        , IssueCode

        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName

        , ExpectedValue
        , ActualValue

        , Severity
        , Notes
    )
    SELECT
          c.EntityKey
        , c.GeneralNo
        , c.ResidentInfoID
        , c.ResidentDetailsID
        , c.FullName

        , N'RESIDENT_CONTACTS'
        , N'MISSING_CONTACT'

        , N'KFMC.dbo.contactInfo'
        , N'DATACORE.Housing.ResidentContactInfo'

        , CONCAT
          (
              N'Resident=',
              c.ResidentInfoID,
              N';Occurrence=',
              c.ExpectedOccurrence
          )

        , N'ContactRow'

        , CONCAT
          (
              N'Type=',
              COALESCE
              (
                  CONVERT
                  (
                      NVARCHAR(100),
                      c.ExpectedContactTypeID
                  ),
                  N'<NULL>'
              ),
              N'; Details=',
              COALESCE
              (
                  c.ExpectedContactDetails,
                  N'<NULL>'
              ),
              N'; Start=',
              COALESCE
              (
                  CONVERT
                  (
                      NVARCHAR(50),
                      c.ExpectedContactStartDate,
                      126
                  ),
                  N'<NULL>'
              ),
              N'; End=',
              COALESCE
              (
                  CONVERT
                  (
                      NVARCHAR(50),
                      c.ExpectedContactEndDate,
                      126
                  ),
                  N'<NULL>'
              ),
              N'; Active=',
              COALESCE
              (
                  CONVERT
                  (
                      NVARCHAR(20),
                      c.ExpectedContactActive
                  ),
                  N'<NULL>'
              )
          )

        , NULL

        , 'ERROR'

        , N'A source resident contact expected after migration is missing from DATACORE.'

    FROM #ContactComparison c

    WHERE c.ExpectedOccurrence IS NOT NULL
      AND c.ActualOccurrence IS NULL;



    ------------------------------------------------------------
    -- 12.5 Unexpected target contacts / duplicate target rows
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName

        , SectionName
        , IssueCode

        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName

        , ExpectedValue
        , ActualValue

        , Severity
        , Notes
    )
    SELECT
          c.EntityKey
        , c.GeneralNo
        , c.ResidentInfoID
        , c.ResidentDetailsID
        , c.FullName

        , N'RESIDENT_CONTACTS'
        , N'UNEXPECTED_CONTACT_OR_DUPLICATE'

        , N'KFMC.dbo.contactInfo'
        , N'DATACORE.Housing.ResidentContactInfo'

        , CONCAT
          (
              N'Resident=',
              c.ResidentInfoID,
              N';Occurrence=',
              c.ActualOccurrence
          )

        , N'ContactRow'

        , NULL

        , CONCAT
          (
              N'Type=',
              COALESCE
              (
                  CONVERT
                  (
                      NVARCHAR(100),
                      c.ActualContactTypeID
                  ),
                  N'<NULL>'
              ),
              N'; Details=',
              COALESCE
              (
                  c.ActualContactDetails,
                  N'<NULL>'
              ),
              N'; Start=',
              COALESCE
              (
                  CONVERT
                  (
                      NVARCHAR(50),
                      c.ActualContactStartDate,
                      126
                  ),
                  N'<NULL>'
              ),
              N'; End=',
              COALESCE
              (
                  CONVERT
                  (
                      NVARCHAR(50),
                      c.ActualContactEndDate,
                      126
                  ),
                  N'<NULL>'
              ),
              N'; Active=',
              COALESCE
              (
                  CONVERT
                  (
                      NVARCHAR(20),
                      c.ActualContactActive
                  ),
                  N'<NULL>'
              )
          )

        , 'ERROR'

        , N'DATACORE contains a resident contact row that is not represented by the expected KFMC contact population, or contains an extra duplicate.'

    FROM #ContactComparison c

    WHERE c.ExpectedOccurrence IS NULL
      AND c.ActualOccurrence IS NOT NULL;



    ------------------------------------------------------------
    -- 12.6 Compare additional migrated contact values
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName

        , SectionName
        , IssueCode

        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName

        , ExpectedValue
        , ActualValue

        , Severity
        , Notes
    )
    SELECT
          c.EntityKey
        , c.GeneralNo
        , c.ResidentInfoID
        , c.ResidentDetailsID
        , c.FullName

        , N'RESIDENT_CONTACTS'
        , N'CONTACT_VALUE_MISMATCH'

        , N'KFMC.dbo.contactInfo'
        , N'DATACORE.Housing.ResidentContactInfo'

        , CONCAT
          (
              N'Resident=',
              c.ResidentInfoID,
              N';Occurrence=',
              c.ExpectedOccurrence
          )

        , v.FieldName
        , v.ExpectedValue
        , v.ActualValue

        , 'ERROR'

        , N'The contact exists, but an additional migrated field does not match the expected migration value.'

    FROM #ContactComparison c

    CROSS APPLY
    (
        VALUES

        (
            N'residentcontactInfoNote',
            CONVERT
            (
                NVARCHAR(MAX),
                c.ExpectedContactNote
            ),
            CONVERT
            (
                NVARCHAR(MAX),
                c.ActualContactNote
            )
        ),

        (
            N'entryDate',
            CONVERT
            (
                NVARCHAR(MAX),
                c.ExpectedEntryDate,
                126
            ),
            CONVERT
            (
                NVARCHAR(MAX),
                c.ActualEntryDate,
                126
            )
        ),

        (
            N'entryData',
            CONVERT
            (
                NVARCHAR(MAX),
                c.ExpectedEntryData
            ),
            CONVERT
            (
                NVARCHAR(MAX),
                c.ActualEntryData
            )
        ),

        (
            N'hostName',
            CONVERT
            (
                NVARCHAR(MAX),
                c.ExpectedHostName
            ),
            CONVERT
            (
                NVARCHAR(MAX),
                c.ActualHostName
            )
        )

    ) v
    (
          FieldName
        , ExpectedValue
        , ActualValue
    )

    WHERE c.ExpectedOccurrence IS NOT NULL
      AND c.ActualOccurrence IS NOT NULL

      AND
      (
             (
                 v.ExpectedValue COLLATE DATABASE_DEFAULT
                 <>
                 v.ActualValue COLLATE DATABASE_DEFAULT
             )

          OR (
                 v.ExpectedValue IS NULL
                 AND v.ActualValue IS NOT NULL
             )

          OR (
                 v.ExpectedValue IS NOT NULL
                 AND v.ActualValue IS NULL
             )
      );


          ------------------------------------------------------------
    -- 13. ACTIONS - SOURCE ACTIONS + GENERATED WORKFLOW
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- 13.1 Reproduce consecutive duplicate detection exactly
    --      as usp_MigrateBuildingActions
    ------------------------------------------------------------

    ;WITH OrderedSourceActions AS
    (
        SELECT
              sourceAction.*
            , LAG(sourceAction.buildingActionID) OVER
              (
                  PARTITION BY
                        sourceAction.generalNo_FK
                      , ISNULL
                        (
                            LTRIM(RTRIM(sourceAction.buildingDetailsNo)),
                            N''
                        )
                  ORDER BY sourceAction.buildingActionID
              ) AS previousEntityActionID

        FROM KFMC.Housing.BuildingAction sourceAction

        WHERE EXISTS
        (
            SELECT 1
            FROM #ExpectedResidents e
            WHERE e.GeneralNo =
                  TRY_CONVERT(BIGINT, sourceAction.generalNo_FK)
        )
    )
    SELECT
          currentAction.buildingActionID AS duplicateActionID
        , previousAction.buildingActionID AS previousActionID
    INTO #FV_DuplicateActionEdges
    FROM OrderedSourceActions currentAction

    JOIN KFMC.Housing.BuildingAction previousAction
        ON previousAction.buildingActionID =
           currentAction.previousEntityActionID

    WHERE NOT EXISTS
    (
        SELECT
              currentAction.buildingActionTypeID_FK
            , currentAction.buildingStatusID_FK
            , currentAction.generalNo_FK
            , currentAction.buildingPaymentTypeID_FK
            , currentAction.buildingDetailsNo
            , currentAction.buildingActionFromDate
            , currentAction.buildingActionToDate
            , currentAction.buildingActionDate
            , currentAction.buildingActionDate2
            , currentAction.buildingActionDecisionNo
            , currentAction.buildingActionDecisionDate
            , currentAction.fromDSD_FK
            , currentAction.toDSD_FK
            , currentAction.buildingActionFromSourceID_FK
            , currentAction.buildingActionToSourceID_FK
            , currentAction.buildingActionNote
            , currentAction.buildingActionExtraText1
            , currentAction.buildingActionExtraText2
            , currentAction.buildingActionExtraText3
            , currentAction.buildingActionExtraText4
            , currentAction.buildingActionExtraDate1
            , currentAction.buildingActionExtraDate2
            , currentAction.buildingActionExtraDate3
            , currentAction.buildingActionExtraFloat1
            , currentAction.buildingActionExtraFloat2
            , currentAction.buildingActionExtraInt1
            , currentAction.buildingActionExtraInt2
            , currentAction.buildingActionExtraInt3
            , currentAction.buildingActionExtraInt4
            , currentAction.buildingActionExtraType1
            , currentAction.buildingActionExtraType2
            , currentAction.buildingActionExtraType3
            , currentAction.buildingActionActive
            , currentAction.buildingActionParentID

        EXCEPT

        SELECT
              previousAction.buildingActionTypeID_FK
            , previousAction.buildingStatusID_FK
            , previousAction.generalNo_FK
            , previousAction.buildingPaymentTypeID_FK
            , previousAction.buildingDetailsNo
            , previousAction.buildingActionFromDate
            , previousAction.buildingActionToDate
            , previousAction.buildingActionDate
            , previousAction.buildingActionDate2
            , previousAction.buildingActionDecisionNo
            , previousAction.buildingActionDecisionDate
            , previousAction.fromDSD_FK
            , previousAction.toDSD_FK
            , previousAction.buildingActionFromSourceID_FK
            , previousAction.buildingActionToSourceID_FK
            , previousAction.buildingActionNote
            , previousAction.buildingActionExtraText1
            , previousAction.buildingActionExtraText2
            , previousAction.buildingActionExtraText3
            , previousAction.buildingActionExtraText4
            , previousAction.buildingActionExtraDate1
            , previousAction.buildingActionExtraDate2
            , previousAction.buildingActionExtraDate3
            , previousAction.buildingActionExtraFloat1
            , previousAction.buildingActionExtraFloat2
            , previousAction.buildingActionExtraInt1
            , previousAction.buildingActionExtraInt2
            , previousAction.buildingActionExtraInt3
            , previousAction.buildingActionExtraInt4
            , previousAction.buildingActionExtraType1
            , previousAction.buildingActionExtraType2
            , previousAction.buildingActionExtraType3
            , previousAction.buildingActionActive
            , previousAction.buildingActionParentID
    );


    ------------------------------------------------------------
    -- 13.2 Resolve duplicate chains A -> A -> A
    ------------------------------------------------------------

    ;WITH DuplicatePaths AS
    (
        SELECT
              edge.duplicateActionID
            , edge.previousActionID AS retainedActionID
            , 1 AS pathLevel
        FROM #FV_DuplicateActionEdges edge

        UNION ALL

        SELECT
              path.duplicateActionID
            , previousEdge.previousActionID
            , path.pathLevel + 1
        FROM DuplicatePaths path

        JOIN #FV_DuplicateActionEdges previousEdge
            ON previousEdge.duplicateActionID =
               path.retainedActionID

        WHERE path.pathLevel < 100
    ),
    RankedDuplicatePaths AS
    (
        SELECT
              duplicateActionID
            , retainedActionID
            , ROW_NUMBER() OVER
              (
                  PARTITION BY duplicateActionID
                  ORDER BY pathLevel DESC
              ) AS rn
        FROM DuplicatePaths
    )
    SELECT
          duplicateActionID
        , retainedActionID
    INTO #FV_DuplicateActionMap
    FROM RankedDuplicatePaths
    WHERE rn = 1
    OPTION (MAXRECURSION 100);


    ------------------------------------------------------------
    -- 13.3 Resolve OccupentDate for source evacuation actions
    ------------------------------------------------------------

    ;WITH ActionAncestors AS
    (
        SELECT
              exitAction.buildingActionID AS exitActionID
            , parentAction.buildingActionID AS ancestorActionID
            , parentAction.buildingActionParentID AS nextParentID
            , parentAction.buildingActionTypeID_FK AS ancestorTypeID
            , parentAction.buildingActionDate AS ancestorActionDate
            , 1 AS ancestorLevel

        FROM KFMC.Housing.BuildingAction exitAction

        LEFT JOIN KFMC.Housing.BuildingAction parentAction
            ON parentAction.buildingActionID =
               exitAction.buildingActionParentID

        WHERE exitAction.buildingActionTypeID_FK = 3

          AND EXISTS
          (
              SELECT 1
              FROM #ExpectedResidents e
              WHERE e.GeneralNo =
                    TRY_CONVERT(BIGINT, exitAction.generalNo_FK)
          )

        UNION ALL

        SELECT
              a.exitActionID
            , parentAction.buildingActionID
            , parentAction.buildingActionParentID
            , parentAction.buildingActionTypeID_FK
            , parentAction.buildingActionDate
            , a.ancestorLevel + 1

        FROM ActionAncestors a

        JOIN KFMC.Housing.BuildingAction parentAction
            ON parentAction.buildingActionID = a.nextParentID

        WHERE a.ancestorLevel < 100
    ),
    RankedOccupancy AS
    (
        SELECT
              exitActionID
            , ancestorActionDate AS OccupentDate
            , ROW_NUMBER() OVER
              (
                  PARTITION BY exitActionID
                  ORDER BY ancestorLevel
              ) AS rn

        FROM ActionAncestors

        WHERE ancestorTypeID = 2
    )
    SELECT
          exitActionID
        , OccupentDate
    INTO #FV_ExitOccupancy
    FROM RankedOccupancy
    WHERE rn = 1
    OPTION (MAXRECURSION 100);


    ------------------------------------------------------------
    -- 13.4 Expected SOURCE actions
    ------------------------------------------------------------

    SELECT
          sourceAction.buildingActionID AS SourceActionID

        , e.EntityKey
        , e.GeneralNo
        , e.SourceResidentInfoID AS ResidentInfoID
        , e.SourceResidentDetailsID AS ResidentDetailsID
        , e.FullName

        , sourceAction.buildingActionUDID

        , CASE
              WHEN sourceAction.buildingActionParentID IS NULL
               AND sourceAction.buildingActionTypeID_FK IN (7,25)
                  THEN 1
              WHEN sourceAction.buildingActionTypeID_FK = 3
               AND sourceAction.buildingActionExtraInt1 IS NULL
                  THEN 3

              WHEN sourceAction.buildingActionTypeID_FK = 3
               AND sourceAction.buildingActionExtraInt1 = 1
                  THEN 59

              WHEN sourceAction.buildingActionTypeID_FK = 3
               AND sourceAction.buildingActionExtraInt1 IN (2,3)
                  THEN 57

              WHEN sourceAction.buildingActionTypeID_FK = 3
               AND sourceAction.buildingActionExtraInt1 = 4
                  THEN 57

              WHEN sourceAction.buildingActionTypeID_FK = 3
               AND sourceAction.buildingActionExtraInt1 = 5
                  THEN 3

              ELSE sourceAction.buildingActionTypeID_FK
          END AS ExpectedActionTypeID

        , sourceAction.buildingStatusID_FK
        , sourceAction.buildingPaymentTypeID_FK

        , TRY_CONVERT
          (
              BIGINT,
              sourceBuilding.buildingDetailsID
          ) AS ExpectedBuildingDetailsID

        , sourceAction.buildingDetailsNo

        , sourceAction.buildingActionFromDate
        , sourceAction.buildingActionToDate
        , sourceAction.buildingActionDate
        , sourceAction.buildingActionDate2
        , sourceAction.buildingActionDecisionNo
        , sourceAction.buildingActionDecisionDate

        , sourceAction.fromDSD_FK
        , sourceAction.toDSD_FK

        , sourceAction.buildingActionFromSourceID_FK
        , sourceAction.buildingActionToSourceID_FK

        , sourceAction.buildingActionNote

        , sourceAction.buildingActionExtraText1
        , sourceAction.buildingActionExtraText2
        , sourceAction.buildingActionExtraText3
        , sourceAction.buildingActionExtraText4

        , sourceAction.buildingActionExtraDate1
        , sourceAction.buildingActionExtraDate2
        , sourceAction.buildingActionExtraDate3

        , sourceAction.buildingActionExtraFloat1
        , sourceAction.buildingActionExtraFloat2

        , sourceAction.buildingActionExtraInt1
        , sourceAction.buildingActionExtraInt2
        , sourceAction.buildingActionExtraInt3
        , sourceAction.buildingActionExtraInt4

        , CASE
              WHEN sourceAction.buildingActionParentID IS NULL
               AND sourceAction.buildingActionTypeID_FK = 7 THEN 17
              WHEN sourceAction.buildingActionParentID IS NULL
               AND sourceAction.buildingActionTypeID_FK = 25 THEN 18
              WHEN sourceAction.buildingActionParentID IS NULL
               AND sourceAction.buildingActionTypeID_FK = 1
               AND sourceAction.buildingActionExtraType1 = 99 THEN 5
              ELSE sourceAction.buildingActionExtraType1
          END AS buildingActionExtraType1
        , sourceAction.buildingActionExtraType2
        , sourceAction.buildingActionExtraType3

        , sourceAction.buildingActionActive

                , CAST
          (
              CASE
                  WHEN COALESCE
                       (
                           duplicateParent.retainedActionID,

sourceAction.buildingActionParentID
                       ) IS NULL
                      THEN NULL

                  ELSE CONCAT
                       (
                           N'ID:',
                           COALESCE
                           (
                               duplicateParent.retainedActionID,

sourceAction.buildingActionParentID
                           )
                       )
              END
              AS NVARCHAR(500)
          ) AS ExpectedParentToken

        , CASE
              WHEN sourceAction.buildingActionTypeID_FK = 24
               AND sourceAction.buildingActionExtraType1 = 2
                  THEN 1

              WHEN sourceAction.buildingActionTypeID_FK = 24
               AND sourceAction.buildingActionExtraType1 = 3
                  THEN 3

              WHEN sourceAction.buildingActionTypeID_FK = 24
               AND sourceAction.buildingActionExtraType1 = 4
                  THEN 2
          END AS ExpectedExtendReasonTypeID

        , CASE
              WHEN sourceAction.buildingActionTypeID_FK = 2
                  THEN sourceAction.buildingActionDate

              WHEN sourceAction.buildingActionTypeID_FK = 3
                  THEN exitOccupancy.OccupentDate
          END AS ExpectedOccupentDate

        , CASE
              WHEN sourceAction.buildingActionTypeID_FK = 3
                  THEN sourceAction.buildingActionDate
          END AS ExpectedExitDate

        , @IdaraId AS ExpectedIdaraID
        , sourceAction.entryDate AS ExpectedEntryDate

        , MoveData.fn_MapEntryData(sourceAction.entryData)
            AS ExpectedEntryData

        , MoveData.fn_MapHostName
          (
              sourceAction.hostName,
              sourceAction.entryData
          ) AS ExpectedHostName

    INTO #FV_ExpectedSourceActions

    FROM KFMC.Housing.BuildingAction sourceAction

    JOIN #ExpectedResidents e
        ON e.GeneralNo =
           TRY_CONVERT(BIGINT, sourceAction.generalNo_FK)

    LEFT JOIN KFMC.Housing.BuildingDetails sourceBuilding
        ON LTRIM(RTRIM(sourceBuilding.buildingDetailsNo))
         = LTRIM(RTRIM(sourceAction.buildingDetailsNo))

    LEFT JOIN #FV_ExitOccupancy exitOccupancy
        ON exitOccupancy.exitActionID =
           sourceAction.buildingActionID

    LEFT JOIN #FV_DuplicateActionMap duplicateParent
        ON duplicateParent.duplicateActionID =
           sourceAction.buildingActionParentID

    LEFT JOIN KFMC.Housing.BuildingAction letterAllocationParent
        ON letterAllocationParent.buildingActionID =
           sourceAction.buildingActionParentID

       AND letterAllocationParent.buildingActionTypeID_FK = 27

       AND EXISTS
       (
           SELECT 1
           FROM KFMC.Housing.BuildingAction letterRoot
           WHERE letterRoot.buildingActionID =
                 letterAllocationParent.buildingActionParentID
             AND letterRoot.buildingActionTypeID_FK = 7
       )

    WHERE NOT EXISTS
    (
        SELECT 1
        FROM #FV_DuplicateActionMap duplicateAction
        WHERE duplicateAction.duplicateActionID = sourceAction.buildingActionID
    )
    AND NOT
    (
        sourceAction.buildingActionTypeID_FK=21
        AND sourceAction.buildingActionActive=1
        AND EXISTS (SELECT 1 FROM KFMC.Housing.BuildingAction root
                    WHERE root.buildingActionID=sourceAction.buildingActionParentID
                      AND root.buildingActionParentID IS NULL
                      AND root.buildingActionTypeID_FK IN (1,7,25))
        AND NOT EXISTS (SELECT 1 FROM KFMC.Housing.BuildingAction child
                        WHERE child.buildingActionParentID=sourceAction.buildingActionID)
        AND NOT EXISTS (SELECT 1 FROM KFMC.Housing.BuildingAssign a
                        WHERE a.BuildingActionID_FK=sourceAction.buildingActionID)
    )
    AND NOT
    (
        sourceAction.buildingActionTypeID_FK=26
        AND sourceAction.buildingActionActive=1
        AND EXISTS (SELECT 1 FROM KFMC.Housing.BuildingAction parent27
                    WHERE parent27.buildingActionID=sourceAction.buildingActionParentID
                      AND parent27.buildingActionTypeID_FK=27)
        AND NOT EXISTS (SELECT 1 FROM KFMC.Housing.BuildingAction child
                        WHERE child.buildingActionParentID=sourceAction.buildingActionID)
        AND NOT EXISTS (SELECT 1 FROM KFMC.Housing.BuildingAssign a
                        WHERE a.BuildingActionID_FK=sourceAction.buildingActionID)
    )

    AND NOT
    (
        sourceAction.buildingActionTypeID_FK = 27
        AND EXISTS
        (
            SELECT 1 FROM KFMC.Housing.BuildingAction letterRoot
            WHERE letterRoot.buildingActionID = sourceAction.buildingActionParentID
              AND letterRoot.buildingActionParentID IS NULL
              AND letterRoot.buildingActionTypeID_FK IN (7,25)
        )
        AND NOT EXISTS
        (
            SELECT 1 FROM KFMC.Housing.BuildingAction child
            WHERE child.buildingActionParentID = sourceAction.buildingActionID
        )
        AND NOT EXISTS
        (
            SELECT 1 FROM KFMC.Housing.BuildingAssign allocation
            WHERE allocation.BuildingActionID_FK = sourceAction.buildingActionID
        )
    )
    -- FINAL99_LIVE_ALIGN_20261110: terminal 27 is not an eligible current allocation
    AND NOT
    (
        sourceAction.buildingActionTypeID_FK = 27
        AND sourceAction.buildingActionActive = 1
        AND NOT EXISTS
        (
            SELECT 1 FROM KFMC.Housing.BuildingAction child27
            WHERE child27.buildingActionParentID = sourceAction.buildingActionID
        )
        AND NOT EXISTS
        (
            SELECT 1 FROM KFMC.Housing.BuildingAssign assign27
            WHERE assign27.BuildingActionID_FK = sourceAction.buildingActionID
        )
        AND EXISTS
        (
            SELECT 1
            FROM KFMC.Housing.BuildingAction root27
            JOIN Housing.BuildingAction targetRoot27
              ON targetRoot27.buildingActionID = root27.buildingActionID
             AND targetRoot27.buildingActionParentID IS NULL
             AND targetRoot27.buildingActionTypeID_FK = 1
             AND targetRoot27.buildingActionUDID = root27.buildingActionUDID
            WHERE root27.buildingActionID = sourceAction.buildingActionParentID
              AND root27.buildingActionParentID IS NULL
              AND root27.buildingActionTypeID_FK = 1
              AND root27.buildingActionActive = 1
              AND
              (
                  -- Active local SIDE-class waiting roots: no allocation yet.
                  (
                    targetRoot27.buildingActionActive = 1
                    AND EXISTS
                    (
                      SELECT 1 FROM Housing.WaitingClass waitingClass27
                      WHERE waitingClass27.waitingClassID =
                            sourceAction.buildingActionExtraType1
                        AND waitingClass27.idara_FK = @IdaraId
                    )
                  )
                  OR
                  -- Historically disabled source root, verified in duplicate map.
                  (
                    targetRoot27.buildingActionActive = 0
                    -- FINAL99_MAIN_27_OCCUPIED_SIBLING_V3
                    AND
                    (
                        EXISTS
                        (
                            SELECT 1 FROM #FV_DuplicateActionMap dm27
                            WHERE dm27.duplicateActionID = root27.buildingActionID
                        )
                        OR
                        (
                            -- Retained earlier, completed housing chain under the
                            -- same resident and SAME main waiting class. This is
                            -- not an exemption for arbitrary disabled roots.
                            EXISTS
                            (
                                SELECT 1
                                FROM KFMC.Housing.BuildingAction earlierRoot
                                JOIN Housing.BuildingAction retainedRoot
                                  ON retainedRoot.buildingActionID = earlierRoot.buildingActionID
                                 AND retainedRoot.buildingActionUDID = earlierRoot.buildingActionUDID
                                 AND retainedRoot.buildingActionActive = 1
                                 AND retainedRoot.buildingActionTypeID_FK = 1
                                JOIN KFMC.Housing.BuildingAction earlierHousing
                                  ON earlierHousing.buildingActionParentID = earlierRoot.buildingActionID
                                 AND earlierHousing.buildingActionTypeID_FK = 2
                                 AND earlierHousing.buildingActionActive = 1
                                JOIN Housing.BuildingAction retainedHousing
                                  ON retainedHousing.buildingActionID = earlierHousing.buildingActionID
                                 AND retainedHousing.buildingActionUDID = earlierHousing.buildingActionUDID
                                 AND retainedHousing.buildingActionParentID = retainedRoot.buildingActionID
                                 AND retainedHousing.buildingActionTypeID_FK = 2
                                 AND retainedHousing.buildingActionActive = 1
                                WHERE earlierRoot.buildingActionParentID IS NULL
                                  AND earlierRoot.buildingActionTypeID_FK = 1
                                  AND earlierRoot.buildingActionActive = 1
                                  AND earlierRoot.buildingActionID <> root27.buildingActionID
                                  AND TRY_CONVERT(bigint, earlierRoot.generalNo_FK) =
                                      TRY_CONVERT(bigint, root27.generalNo_FK)
                                  AND earlierRoot.buildingActionExtraType1 = root27.buildingActionExtraType1
                                  AND retainedRoot.buildingActionParentID IS NULL
                            )
                            -- Prevent an excluded terminal allocation from hiding
                            -- another operational child in the target.
                            AND NOT EXISTS
                            (
                                SELECT 1
                                FROM Housing.BuildingAction remainingTargetChild
                                WHERE remainingTargetChild.buildingActionParentID = root27.buildingActionID
                            )
                        )
                    )
                    AND NOT EXISTS
                    (
                       SELECT 1 FROM Housing.BuildingAction surviving27
                       WHERE surviving27.buildingActionParentID = root27.buildingActionID
                    )
                  )
              )
        )
    )
;


    ------------------------------------------------------------
    -- 13.5 Build ValidAssignments exactly like migration
    ------------------------------------------------------------

    ;WITH OrderedAssignments AS
    (
        SELECT
              sourceAssign.*

            , LAG(sourceAssign.BuildingAssignID) OVER
              (
                  PARTITION BY
                        sourceAssign.GeneralNo
                      , sourceAssign.BuildingActionID_FK

                  ORDER BY sourceAssign.BuildingAssignID
              ) AS PreviousAssignID

        FROM KFMC.Housing.BuildingAssign sourceAssign

        WHERE EXISTS
        (
            SELECT 1
            FROM #ExpectedResidents e
            WHERE e.GeneralNo =
                  TRY_CONVERT(BIGINT, sourceAssign.GeneralNo)
        )
    )
    SELECT currentAssign.*
    INTO #FV_ValidAssign
    FROM OrderedAssignments currentAssign

    JOIN KFMC.Housing.BuildingAction ownerAction
        ON ownerAction.buildingActionID =
           currentAssign.BuildingActionID_FK

       AND CONVERT(NVARCHAR(100), ownerAction.generalNo_FK)
         = CONVERT(NVARCHAR(100), currentAssign.GeneralNo)

       AND ownerAction.generalNo_FK NOT IN (0,1,18)

    JOIN #ExpectedResidents validResident
        ON validResident.GeneralNo =
           TRY_CONVERT(BIGINT, ownerAction.generalNo_FK)

    LEFT JOIN KFMC.Housing.BuildingAssign previousAssign
        ON previousAssign.BuildingAssignID =
           currentAssign.PreviousAssignID

    WHERE previousAssign.BuildingAssignID IS NULL

       OR EXISTS
          (
              SELECT
                    currentAssign.BuildingAssignTypeID_FK
                  , currentAssign.ParentBuildingAssignID
                  , currentAssign.BuildingNo
                  , currentAssign.BuildingAssignStatusID_FK
                  , currentAssign.MeterReadValue

              EXCEPT

              SELECT
                    previousAssign.BuildingAssignTypeID_FK
                  , previousAssign.ParentBuildingAssignID
                  , previousAssign.BuildingNo
                  , previousAssign.BuildingAssignStatusID_FK
                  , previousAssign.MeterReadValue
          );


    ------------------------------------------------------------
    -- 13.6 Normal allocation roots
    ------------------------------------------------------------

    SELECT
          action27.buildingActionID AS Action27ID
        , e.GeneralNo
        , e.SourceResidentInfoID AS ResidentInfoID
        , e.SourceResidentDetailsID AS ResidentDetailsID
        , e.EntityKey
        , e.FullName

        , COALESCE
          (
              action27.buildingActionExtraType1,
              waitingRoot.buildingActionExtraType1
          ) AS WaitingClassID

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_ValidAssign noHouse

            WHERE noHouse.BuildingActionID_FK =
                  action27.buildingActionID

              AND noHouse.BuildingAssignTypeID_FK = 1

              AND UPPER
                  (
                      LTRIM
                      (
                          RTRIM
                          (
                              ISNULL(noHouse.BuildingNo,N'')
                          )
                      )
                  ) = N'NO_HOUSE'
          ) AS NoHouseCount

    INTO #FV_NormalAllocationRoots

    FROM KFMC.Housing.BuildingAction action27

    JOIN KFMC.Housing.BuildingAction waitingRoot
        ON waitingRoot.buildingActionID = action27.buildingActionParentID
       AND waitingRoot.buildingActionTypeID_FK = 1
    JOIN Housing.BuildingAction migratedRoot
      ON migratedRoot.buildingActionID=waitingRoot.buildingActionID
     AND migratedRoot.buildingActionTypeID_FK=1
     AND migratedRoot.buildingActionActive=1

    JOIN #ExpectedResidents e
        ON e.GeneralNo =
           TRY_CONVERT(BIGINT, action27.generalNo_FK)

    WHERE action27.buildingActionTypeID_FK = 27

      AND COALESCE
          (
              action27.buildingActionExtraType1,
              waitingRoot.buildingActionExtraType1
          ) IN (1,2,3,4);


    ------------------------------------------------------------
    -- 13.7 Expected generated action table
    ------------------------------------------------------------

    CREATE TABLE #FV_ExpectedGeneratedActions
    (
          Marker                 NVARCHAR(400) NOT NULL
        , EntityKey              NVARCHAR(100) NOT NULL
        , GeneralNo              BIGINT NOT NULL
        , ResidentInfoID         BIGINT NOT NULL
        , ResidentDetailsID      BIGINT NULL
        , FullName               NVARCHAR(1000) NULL

        , GenerationKind         NVARCHAR(100) NOT NULL
        , ExpectedActionTypeID   INT NOT NULL

        , ExpectedBuildingID     BIGINT NULL
        , ExpectedBuildingNo     NVARCHAR(400) NULL

        , ExpectedParentToken    NVARCHAR(500) NULL

        , ExpectedWaitingClassID INT NULL
        , ExpectedInAssignPeriod INT NULL

        , ExpectedNote           NVARCHAR(MAX) NULL
        , ExpectedExtraInt1      BIGINT NULL

        , ExpectedIdaraID        BIGINT NOT NULL
        , ExpectedEntryDate      DATETIME NULL
        , ExpectedEntryData      NVARCHAR(4000) NULL
        , ExpectedHostName       NVARCHAR(4000) NULL
    );


    ------------------------------------------------------------
    -- 13.8 NO_HOUSE twice -> generated Type 42
    ------------------------------------------------------------

    INSERT INTO #FV_ExpectedGeneratedActions
    (
          Marker
        , EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , GenerationKind
        , ExpectedActionTypeID
        , ExpectedBuildingID
        , ExpectedBuildingNo
        , ExpectedParentToken
        , ExpectedWaitingClassID
        , ExpectedInAssignPeriod
        , ExpectedNote
        , ExpectedExtraInt1
        , ExpectedIdaraID
        , ExpectedEntryDate
        , ExpectedEntryData
        , ExpectedHostName
    )
    SELECT
          CONCAT(N'MoveData:NoHouse2:', root.Action27ID)

        , root.EntityKey
        , root.GeneralNo
        , root.ResidentInfoID
        , root.ResidentDetailsID
        , root.FullName

        , N'NO_HOUSE_2'
        , 42
        , NULL
        , NULL

        , CONCAT(N'ID:', root.Action27ID)

        , root.WaitingClassID
        , 0

        , N'Eligibility cancelled after two legacy virtual allocations (No_house)'

        , NULL
        , @IdaraId

        , COALESCE
          (
              virtualOffer.RejectionEntryDate,
              virtualOffer.OfferEntryDate
          )

        , MoveData.fn_MapEntryData
          (
              COALESCE
              (
                  virtualOffer.RejectionEntryData,
                  virtualOffer.OfferEntryData
              )
          )

        , MoveData.fn_MapHostName
          (
              COALESCE
              (
                  virtualOffer.RejectionHostName,
                  virtualOffer.OfferHostName
              ),

              COALESCE
              (
                  virtualOffer.RejectionEntryData,
                  virtualOffer.OfferEntryData
              )
          )

    FROM #FV_NormalAllocationRoots root

    CROSS APPLY
    (
        SELECT TOP (1)
              virtualRow.BuildingAssignID

            , virtualRow.entryDate AS OfferEntryDate
            , virtualRow.entryData AS OfferEntryData
            , virtualRow.hostName AS OfferHostName

            , rejection.entryDate AS RejectionEntryDate
            , rejection.entryData AS RejectionEntryData
            , rejection.hostName AS RejectionHostName

        FROM #FV_ValidAssign virtualRow

        OUTER APPLY
        (
            SELECT TOP (1)
                  rejected.entryDate
                , rejected.entryData
                , rejected.hostName

            FROM #FV_ValidAssign rejected

            WHERE rejected.BuildingAssignTypeID_FK = 2
              AND rejected.ParentBuildingAssignID =
                  virtualRow.BuildingAssignID

            ORDER BY rejected.BuildingAssignID DESC
        ) rejection

        WHERE virtualRow.BuildingActionID_FK =
              root.Action27ID

          AND virtualRow.BuildingAssignTypeID_FK = 1

          AND UPPER
              (
                  LTRIM
                  (
                      RTRIM
                      (
                          ISNULL(virtualRow.BuildingNo,N'')
                      )
                  )
              ) = N'NO_HOUSE'

        ORDER BY virtualRow.BuildingAssignID DESC
    ) virtualOffer

    WHERE root.NoHouseCount >= 2;


    ------------------------------------------------------------
    -- 13.9 Real offers
    ------------------------------------------------------------

    ;WITH OfferBase AS
    (
        SELECT
              root.Action27ID
            , root.EntityKey
            , root.GeneralNo
            , root.ResidentInfoID
            , root.ResidentDetailsID
            , root.FullName
            , root.WaitingClassID

            , offer.BuildingAssignID AS OfferID

            , ROW_NUMBER() OVER
              (
                  PARTITION BY root.Action27ID
                  ORDER BY offer.BuildingAssignID
              ) AS OfferNo

            , offer.BuildingNo
            , TRY_CONVERT
              (
                  BIGINT,
                  sourceBuilding.buildingDetailsID
              ) AS BuildingID

            , offer.MeterReadValue

            , offer.entryDate AS OfferEntryDate
            , offer.entryData AS OfferEntryData
            , offer.hostName AS OfferHostName

            , rejection.BuildingAssignID AS RejectionID
            , rejection.entryDate AS RejectionEntryDate
            , rejection.entryData AS RejectionEntryData
            , rejection.hostName AS RejectionHostName

        FROM #FV_NormalAllocationRoots root

        JOIN #FV_ValidAssign offer
            ON offer.BuildingActionID_FK = root.Action27ID
           AND offer.BuildingAssignTypeID_FK = 1

        LEFT JOIN KFMC.Housing.BuildingDetails sourceBuilding
            ON LTRIM(RTRIM(sourceBuilding.buildingDetailsNo))
             = LTRIM(RTRIM(offer.BuildingNo))

        OUTER APPLY
        (
            SELECT TOP (1)
                  rejectRow.BuildingAssignID
                , rejectRow.entryDate
                , rejectRow.entryData
                , rejectRow.hostName

            FROM #FV_ValidAssign rejectRow

            WHERE rejectRow.BuildingAssignTypeID_FK = 2
              AND rejectRow.ParentBuildingAssignID =
                  offer.BuildingAssignID

            ORDER BY rejectRow.BuildingAssignID
        ) rejection

        WHERE root.NoHouseCount < 2

          AND UPPER
              (
                  LTRIM
                  (
                      RTRIM
                      (
                          ISNULL(offer.BuildingNo,N'')
                      )
                  )
              ) <> N'NO_HOUSE'
    ),
    OfferTokens AS
    (
        SELECT
              o.*

            , CASE
                  WHEN o.OfferNo = 1 THEN 38
                  ELSE 40
              END AS OfferActionType

            , CONCAT
              (
                  N'MoveData:Assign:',
                  o.OfferID,
                  N':',
                  CASE
                      WHEN o.OfferNo = 1 THEN 38
                      ELSE 40
                  END
              ) AS OfferMarker

            , CASE
                  WHEN o.RejectionID IS NOT NULL
                      THEN CONCAT
                           (
                               N'MoveData:Reject:',
                               o.RejectionID,
                               N':',
                               CASE
                                   WHEN o.OfferNo = 1 THEN 39
                                   ELSE 42
                               END
                           )

                  WHEN o.MeterReadValue IS NOT NULL
                      THEN CONCAT
                           (
                               N'MoveData:Accept:',
                               o.OfferID,
                               N':47'
                           )

                  ELSE CONCAT
                       (
                           N'MoveData:Assign:',
                           o.OfferID,
                           N':',
                           CASE
                               WHEN o.OfferNo = 1 THEN 38
                               ELSE 40
                           END
                       )
              END AS FinalToken

        FROM OfferBase o
    )
    SELECT
          o.*
        , CASE
              WHEN o.OfferNo = 1
                  THEN CONCAT(N'ID:', o.Action27ID)

              ELSE LAG
                   (
                       CONCAT(N'MARKER:', o.FinalToken)
                   ) OVER
                   (
                       PARTITION BY o.Action27ID
                       ORDER BY o.OfferID
                   )
          END AS OfferParentToken

    INTO #FV_RealOffers

    FROM OfferTokens o;


    ------------------------------------------------------------
    -- Correct parent of offers after first offer.
    --
    -- LAG above must use the PREVIOUS row FinalToken.
    ------------------------------------------------------------

    ;WITH ParentFix AS
    (
        SELECT
              OfferID
            , CASE
                  WHEN OfferNo = 1
                      THEN CONCAT(N'ID:', Action27ID)

                  ELSE CONCAT
                       (
                           N'MARKER:',
                           LAG(FinalToken) OVER
                           (
                               PARTITION BY Action27ID
                               ORDER BY OfferID
                           )
                       )
              END AS CorrectParentToken

        FROM #FV_RealOffers
    )
    UPDATE o
       SET OfferParentToken = p.CorrectParentToken
    FROM #FV_RealOffers o
    JOIN ParentFix p
      ON p.OfferID = o.OfferID;


    ------------------------------------------------------------
    -- Generated offer 38 / 40
    ------------------------------------------------------------

    INSERT INTO #FV_ExpectedGeneratedActions
    (
          Marker
        , EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , GenerationKind
        , ExpectedActionTypeID
        , ExpectedBuildingID
        , ExpectedBuildingNo
        , ExpectedParentToken
        , ExpectedWaitingClassID
        , ExpectedInAssignPeriod
        , ExpectedNote
        , ExpectedExtraInt1
        , ExpectedIdaraID
        , ExpectedEntryDate
        , ExpectedEntryData
        , ExpectedHostName
    )
    SELECT
          OfferMarker
        , EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , N'ALLOCATION_OFFER'
        , OfferActionType
        , BuildingID
        , BuildingNo
        , OfferParentToken
        , WaitingClassID
        , 0
        , NULL
        , NULL
        , @IdaraId
        , OfferEntryDate
        , MoveData.fn_MapEntryData(OfferEntryData)
        , MoveData.fn_MapHostName
          (
              OfferHostName,
              OfferEntryData
          )
    FROM #FV_RealOffers;


    ------------------------------------------------------------
    -- Generated rejection 39 / 42
    ------------------------------------------------------------

    INSERT INTO #FV_ExpectedGeneratedActions
    (
          Marker
        , EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , GenerationKind
        , ExpectedActionTypeID
        , ExpectedBuildingID
        , ExpectedBuildingNo
        , ExpectedParentToken
        , ExpectedWaitingClassID
        , ExpectedInAssignPeriod
        , ExpectedNote
        , ExpectedExtraInt1
        , ExpectedIdaraID
        , ExpectedEntryDate
        , ExpectedEntryData
        , ExpectedHostName
    )
    SELECT
          CONCAT
          (
              N'MoveData:Reject:',
              RejectionID,
              N':',
              CASE
                  WHEN OfferNo = 1 THEN 39
                  ELSE 42
              END
          )

        , EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName

        , N'ALLOCATION_REJECTION'

        , CASE
              WHEN OfferNo = 1 THEN 39
              ELSE 42
          END

        , BuildingID
        , BuildingNo

        , CONCAT(N'MARKER:', OfferMarker)

        , WaitingClassID
        , 0

        , NULL
        , NULL
        , @IdaraId

        , RejectionEntryDate

        , MoveData.fn_MapEntryData(RejectionEntryData)

        , MoveData.fn_MapHostName
          (
              RejectionHostName,
              RejectionEntryData
          )

    FROM #FV_RealOffers

    WHERE RejectionID IS NOT NULL;


    ------------------------------------------------------------
    -- Generated accepted chain 45 -> 46 -> 47
    ------------------------------------------------------------

    INSERT INTO #FV_ExpectedGeneratedActions
    (
          Marker
        , EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , GenerationKind
        , ExpectedActionTypeID
        , ExpectedBuildingID
        , ExpectedBuildingNo
        , ExpectedParentToken
        , ExpectedWaitingClassID
        , ExpectedInAssignPeriod
        , ExpectedNote
        , ExpectedExtraInt1
        , ExpectedIdaraID
        , ExpectedEntryDate
        , ExpectedEntryData
        , ExpectedHostName
    )
    SELECT
          CONCAT
          (
              N'MoveData:Accept:',
              o.OfferID,
              N':',
              stage.StageType
          )

        , o.EntityKey
        , o.GeneralNo
        , o.ResidentInfoID
        , o.ResidentDetailsID
        , o.FullName

        , N'ALLOCATION_ACCEPT_STAGE'

        , stage.StageType

        , o.BuildingID
        , o.BuildingNo

        , CASE stage.StageType
              WHEN 45
                  THEN CONCAT(N'MARKER:', o.OfferMarker)

              WHEN 46
                  THEN CONCAT
                       (
                           N'MARKER:MoveData:Accept:',
                           o.OfferID,
                           N':45'
                       )

              WHEN 47
                  THEN CONCAT
                       (
                           N'MARKER:MoveData:Accept:',
                           o.OfferID,
                           N':46'
                       )
          END

        , o.WaitingClassID
        , 0
        , NULL

        , CASE
              WHEN stage.StageType IN (46,47)
                  THEN TRY_CONVERT(BIGINT, o.MeterReadValue)
          END

        , @IdaraId
        , o.OfferEntryDate

        , MoveData.fn_MapEntryData(o.OfferEntryData)

        , MoveData.fn_MapHostName
          (
              o.OfferHostName,
              o.OfferEntryData
          )

    FROM #FV_RealOffers o

    CROSS JOIN
    (
        VALUES (45),(46),(47)
    ) stage(StageType)

    WHERE o.RejectionID IS NULL
      AND o.MeterReadValue IS NOT NULL;


    ------------------------------------------------------------
    -- 13.10 Re-parent historical Type 2 after accepted 47
    ------------------------------------------------------------

    ;WITH ReparentEvents AS
    (
        SELECT
              offer.Action27ID
            , offer.OfferID

            , housingAction.SourceActionID AS HousingActionID

            , CONCAT
              (
                  N'MARKER:MoveData:Accept:',
                  offer.OfferID,
                  N':47'
              ) AS ExpectedParentToken

        FROM #FV_RealOffers offer

        CROSS APPLY
        (
            SELECT TOP (1)
                  expectedAction.SourceActionID

            FROM #FV_ExpectedSourceActions expectedAction

            WHERE expectedAction.GeneralNo = offer.GeneralNo
              AND expectedAction.ExpectedActionTypeID = 2
              AND expectedAction.SourceActionID >
                  offer.Action27ID

              AND UPPER
                  (
                      REPLACE
                      (
                          LTRIM
                          (
                              RTRIM
                              (
                                  ISNULL
                                  (
                                      expectedAction.buildingDetailsNo,
                                      N''
                                  )
                              )
                          ),
                          N' ',
                          N''
                      )
                  )
                =
                  UPPER
                  (
                      REPLACE
                      (
                          LTRIM
                          (
                              RTRIM
                              (
                                  ISNULL(offer.BuildingNo,N'')
                              )
                          ),
                          N' ',
                          N''
                      )
                  )

            ORDER BY expectedAction.SourceActionID
        ) housingAction

        WHERE offer.RejectionID IS NULL
          AND offer.MeterReadValue IS NOT NULL
    ),
    FinalReparent AS
    (
        SELECT
              *
            , ROW_NUMBER() OVER
              (
                  PARTITION BY HousingActionID
                  ORDER BY
                        Action27ID DESC
                      , OfferID DESC
              ) AS rn

        FROM ReparentEvents
    )
    UPDATE expectedAction
       SET ExpectedParentToken =
           finalParent.ExpectedParentToken

    FROM #FV_ExpectedSourceActions expectedAction

    JOIN FinalReparent finalParent
        ON finalParent.HousingActionID =
           expectedAction.SourceActionID
       AND finalParent.rn = 1;


    ------------------------------------------------------------
    -- 13.11 Letter housing generated 45
    ------------------------------------------------------------

    ;WITH LetterCandidates AS
    (
        SELECT
              letterRoot.buildingActionID AS LetterRootID

            , e.EntityKey
            , e.GeneralNo
            , e.SourceResidentInfoID AS ResidentInfoID
            , e.SourceResidentDetailsID AS ResidentDetailsID
            , e.FullName

            , oldAction27.buildingActionID AS OldAction27ID

            , realOffer.BuildingAssignID AS OfferID
            , realOffer.BuildingNo

            , TRY_CONVERT
              (
                  BIGINT,
                  sourceBuilding.buildingDetailsID
              ) AS BuildingID

            , realOffer.entryDate AS OfferEntryDate
            , realOffer.entryData AS OfferEntryData
            , realOffer.hostName AS OfferHostName

        FROM KFMC.Housing.BuildingAction oldAction27

        JOIN KFMC.Housing.BuildingAction letterRoot
            ON letterRoot.buildingActionID =
               oldAction27.buildingActionParentID
           AND letterRoot.buildingActionTypeID_FK = 7

        JOIN #ExpectedResidents e
            ON e.GeneralNo =
               TRY_CONVERT(BIGINT, letterRoot.generalNo_FK)

        CROSS APPLY
        (
            SELECT TOP (1)
                  offer.*

            FROM #FV_ValidAssign offer

            WHERE offer.BuildingActionID_FK =
                  oldAction27.buildingActionID

              AND offer.BuildingAssignTypeID_FK = 1

              AND UPPER
                  (
                      LTRIM
                      (
                          RTRIM
                          (
                              ISNULL(offer.BuildingNo,N'')
                          )
                      )
                  ) <> N'NO_HOUSE'

              AND NOT EXISTS
                  (
                      SELECT 1
                      FROM #FV_ValidAssign rejectRow

                      WHERE rejectRow.BuildingAssignTypeID_FK = 2
                        AND rejectRow.ParentBuildingAssignID =
                            offer.BuildingAssignID
                  )

            ORDER BY offer.BuildingAssignID DESC
        ) realOffer

        LEFT JOIN KFMC.Housing.BuildingDetails sourceBuilding
            ON LTRIM(RTRIM(sourceBuilding.buildingDetailsNo))
             = LTRIM(RTRIM(realOffer.BuildingNo))

        WHERE oldAction27.buildingActionTypeID_FK = 27

          AND NOT EXISTS
          (
              SELECT 1
              FROM #FV_ExpectedSourceActions housed

              WHERE housed.GeneralNo = e.GeneralNo
                AND housed.ExpectedActionTypeID = 2
                AND housed.SourceActionID >
                    oldAction27.buildingActionID

                AND UPPER
                    (
                        REPLACE
                        (
                            LTRIM
                            (
                                RTRIM
                                (
                                    ISNULL
                                    (
                                        housed.buildingDetailsNo,
                                        N''
                                    )
                                )
                            ),
                            N' ',
                            N''
                        )
                    )
                  =
                    UPPER
                    (
                        REPLACE
                        (
                            LTRIM
                            (
                                RTRIM
                                (
                                    ISNULL(realOffer.BuildingNo,N'')
                                )
                            ),
                            N' ',
                            N''
                        )
                    )
          )
    )
    INSERT INTO #FV_ExpectedGeneratedActions
    (
          Marker
        , EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , GenerationKind
        , ExpectedActionTypeID
        , ExpectedBuildingID
        , ExpectedBuildingNo
        , ExpectedParentToken
        , ExpectedWaitingClassID
        , ExpectedInAssignPeriod
        , ExpectedNote
        , ExpectedExtraInt1
        , ExpectedIdaraID
        , ExpectedEntryDate
        , ExpectedEntryData
        , ExpectedHostName
    )
    SELECT
          CONCAT(N'MoveData:Letter45:', OfferID)
        , EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , N'LETTER_HOUSING_45'
        , 45
        , BuildingID
        , BuildingNo
        , CONCAT(N'ID:', LetterRootID)
        , NULL
        , NULL
        , NULL
        , NULL
        , @IdaraId
        , OfferEntryDate
        , MoveData.fn_MapEntryData(OfferEntryData)
        , MoveData.fn_MapHostName
          (
              OfferHostName,
              OfferEntryData
          )
    FROM LetterCandidates;


    ------------------------------------------------------------
    -- 13.12 Missing SOURCE actions
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , N'ACTIONS'
        , N'MISSING_SOURCE_ACTION'

        , N'KFMC.Housing.BuildingAction'
        , N'DATACORE.Housing.BuildingAction'

        , CONVERT(NVARCHAR(100), e.SourceActionID)

        , N'buildingActionID'

        , CONVERT(NVARCHAR(100), e.SourceActionID)
        , NULL

        , 'ERROR'

        , N'A source action expected to be preserved or transformed is missing from DATACORE.'

    FROM #FV_ExpectedSourceActions e

    WHERE NOT EXISTS
    (
        SELECT 1
        FROM Housing.BuildingAction t
        WHERE t.buildingActionID = e.SourceActionID
    );


    ------------------------------------------------------------
    -- 13.13 Source actions that should have been excluded
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.SourceResidentInfoID
        , e.SourceResidentDetailsID
        , e.FullName

        , N'ACTIONS'
        , N'UNEXPECTED_EXCLUDED_SOURCE_ACTION'

        , N'KFMC.Housing.BuildingAction'
        , N'DATACORE.Housing.BuildingAction'

        , CONVERT(NVARCHAR(100), s.buildingActionID)

        , N'buildingActionID'

        , N'<EXCLUDED>'
        , CONVERT(NVARCHAR(100), t.buildingActionID)

        , 'ERROR'

        , N'This source action should have been excluded by duplicate or letter-allocation migration logic.'

    FROM KFMC.Housing.BuildingAction s

    JOIN #ExpectedResidents e
        ON e.GeneralNo =
           TRY_CONVERT(BIGINT, s.generalNo_FK)

    JOIN Housing.BuildingAction t
        ON t.buildingActionID = s.buildingActionID

    WHERE NOT EXISTS
    (
        SELECT 1
        FROM #FV_ExpectedSourceActions x
        WHERE x.SourceActionID = s.buildingActionID
    )
    -- FINAL99_LIVE_ALIGN_20261110: preserved disabled historical duplicate root
    AND NOT
    (
        s.buildingActionParentID IS NULL
        AND s.buildingActionTypeID_FK = 1
        AND s.buildingActionActive = 1
        AND t.buildingActionParentID IS NULL
        AND t.buildingActionTypeID_FK = 1
        AND t.buildingActionActive = 0
        AND t.buildingActionUDID = s.buildingActionUDID
        AND TRY_CONVERT(bigint,t.generalNo_FK) = TRY_CONVERT(bigint,s.generalNo_FK)
        AND EXISTS
        (
            SELECT 1 FROM #FV_DuplicateActionMap dmRoot
            WHERE dmRoot.duplicateActionID = s.buildingActionID
        )
        AND NOT EXISTS
        (
            SELECT 1 FROM Housing.BuildingAction activeTargetChild
            WHERE activeTargetChild.buildingActionParentID = s.buildingActionID
        )
        AND NOT EXISTS
        (
            SELECT 1
            FROM KFMC.Housing.BuildingAction sourceChild
            WHERE sourceChild.buildingActionParentID = s.buildingActionID
              AND
              (
                 sourceChild.buildingActionTypeID_FK <> 27
                 OR EXISTS
                 (
                    SELECT 1 FROM KFMC.Housing.BuildingAction grandchild
                    WHERE grandchild.buildingActionParentID = sourceChild.buildingActionID
                 )
                 OR EXISTS
                 (
                    SELECT 1 FROM KFMC.Housing.BuildingAssign sourceAssign
                    WHERE sourceAssign.BuildingActionID_FK = sourceChild.buildingActionID
                 )
              )
        )
    )
;


    ------------------------------------------------------------
    -- 13.14 Compare SOURCE action fields
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , N'ACTIONS'
        , N'SOURCE_ACTION_VALUE_MISMATCH'

        , N'KFMC.Housing.BuildingAction'
        , N'DATACORE.Housing.BuildingAction'

        , CONVERT(NVARCHAR(100), e.SourceActionID)

        , v.FieldName
        , v.ExpectedValue
        , v.ActualValue

        , 'ERROR'

        , N'The migrated source action exists, but a migrated value differs from the expected transformation.'

    FROM #FV_ExpectedSourceActions e

    JOIN Housing.BuildingAction t
        ON t.buildingActionID = e.SourceActionID

    CROSS APPLY
    (
        VALUES

        (N'buildingActionUDID',
         CONVERT(NVARCHAR(MAX),e.buildingActionUDID),
         CONVERT(NVARCHAR(MAX),t.buildingActionUDID)),

        (N'buildingActionTypeID_FK',
         CONVERT(NVARCHAR(MAX),e.ExpectedActionTypeID),
         CONVERT(NVARCHAR(MAX),t.buildingActionTypeID_FK)),

        (N'buildingStatusID_FK',
         CONVERT(NVARCHAR(MAX),e.buildingStatusID_FK),
         CONVERT(NVARCHAR(MAX),t.buildingStatusID_FK)),

        (N'residentInfoID_FK',
         CONVERT(NVARCHAR(MAX),e.ResidentInfoID),
         CONVERT(NVARCHAR(MAX),t.residentInfoID_FK)),

        (N'generalNo_FK',
         CONVERT(NVARCHAR(MAX),e.GeneralNo),
         CONVERT(NVARCHAR(MAX),t.generalNo_FK)),

        (N'buildingPaymentTypeID_FK',
         CONVERT(NVARCHAR(MAX),e.buildingPaymentTypeID_FK),
         CONVERT(NVARCHAR(MAX),t.buildingPaymentTypeID_FK)),

        (N'buildingDetailsID_FK',
         CONVERT(NVARCHAR(MAX),e.ExpectedBuildingDetailsID),
         CONVERT(NVARCHAR(MAX),t.buildingDetailsID_FK)),

        (N'buildingDetailsNo',
         CONVERT(NVARCHAR(MAX),e.buildingDetailsNo),
         CONVERT(NVARCHAR(MAX),t.buildingDetailsNo)),

        (N'buildingActionFromDate',
         CONVERT(NVARCHAR(MAX),e.buildingActionFromDate,126),
         CONVERT(NVARCHAR(MAX),t.buildingActionFromDate,126)),

        (N'buildingActionToDate',
         CONVERT(NVARCHAR(MAX),e.buildingActionToDate,126),
         CONVERT(NVARCHAR(MAX),t.buildingActionToDate,126)),

        (N'buildingActionDate',
         CONVERT(NVARCHAR(MAX),e.buildingActionDate,126),
         CONVERT(NVARCHAR(MAX),t.buildingActionDate,126)),

        (N'buildingActionDate2',
         CONVERT(NVARCHAR(MAX),e.buildingActionDate2,126),
         CONVERT(NVARCHAR(MAX),t.buildingActionDate2,126)),

        (N'buildingActionDecisionNo',
         CONVERT(NVARCHAR(MAX),e.buildingActionDecisionNo),
         CONVERT(NVARCHAR(MAX),t.buildingActionDecisionNo)),

        (N'buildingActionDecisionDate',
         CONVERT(NVARCHAR(MAX),e.buildingActionDecisionDate,126),
         CONVERT(NVARCHAR(MAX),t.buildingActionDecisionDate,126)),

        (N'fromDSD_FK',
         CONVERT(NVARCHAR(MAX),e.fromDSD_FK),
         CONVERT(NVARCHAR(MAX),t.fromDSD_FK)),

        (N'toDSD_FK',
         CONVERT(NVARCHAR(MAX),e.toDSD_FK),
         CONVERT(NVARCHAR(MAX),t.toDSD_FK)),

        (N'buildingActionFromSourceID_FK',
         CONVERT(NVARCHAR(MAX),e.buildingActionFromSourceID_FK),
         CONVERT(NVARCHAR(MAX),t.buildingActionFromSourceID_FK)),

        (N'buildingActionToSourceID_FK',
         CONVERT(NVARCHAR(MAX),e.buildingActionToSourceID_FK),
         CONVERT(NVARCHAR(MAX),t.buildingActionToSourceID_FK)),

        (N'buildingActionNote',
         CONVERT(NVARCHAR(MAX),e.buildingActionNote),
         CONVERT(NVARCHAR(MAX),t.buildingActionNote)),

        (N'buildingActionExtraText1',
         CONVERT(NVARCHAR(MAX),e.buildingActionExtraText1),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraText1)),

        (N'buildingActionExtraText2',
         CONVERT(NVARCHAR(MAX),e.buildingActionExtraText2),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraText2)),

        (N'buildingActionExtraText3',
         CONVERT(NVARCHAR(MAX),e.buildingActionExtraText3),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraText3)),

        (N'buildingActionExtraText4',
         CONVERT(NVARCHAR(MAX),e.buildingActionExtraText4),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraText4)),

        (N'buildingActionExtraText5',
         N'LEGACY',
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraText5)),

        (N'buildingActionExtraDate1',
         CONVERT(NVARCHAR(MAX),e.buildingActionExtraDate1,126),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraDate1,126)),

        (N'buildingActionExtraDate2',
         CONVERT(NVARCHAR(MAX),e.buildingActionExtraDate2,126),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraDate2,126)),

        (N'buildingActionExtraDate3',
         CONVERT(NVARCHAR(MAX),e.buildingActionExtraDate3,126),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraDate3,126)),

        (N'buildingActionExtraFloat1',
         CONVERT(NVARCHAR(MAX),e.buildingActionExtraFloat1),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraFloat1)),

        (N'buildingActionExtraFloat2',
         CONVERT(NVARCHAR(MAX),e.buildingActionExtraFloat2),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraFloat2)),

        (N'buildingActionExtraInt1',
         CONVERT(NVARCHAR(MAX),e.buildingActionExtraInt1),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraInt1)),

        (N'buildingActionExtraInt2',
         CONVERT(NVARCHAR(MAX),e.buildingActionExtraInt2),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraInt2)),

        (N'buildingActionExtraInt3',
         CONVERT(NVARCHAR(MAX),e.buildingActionExtraInt3),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraInt3)),

        (N'buildingActionExtraInt4',
         CONVERT(NVARCHAR(MAX),e.buildingActionExtraInt4),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraInt4)),

        (N'buildingActionExtraType1',
         CONVERT(NVARCHAR(MAX),e.buildingActionExtraType1),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraType1)),

        (N'buildingActionExtraType2',
         CONVERT(NVARCHAR(MAX),e.buildingActionExtraType2),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraType2)),

        (N'buildingActionExtraType3',
         CONVERT(NVARCHAR(MAX),e.buildingActionExtraType3),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraType3)),

        (N'buildingActionActive',
          CONVERT(NVARCHAR(MAX),
             CASE WHEN e.ExpectedParentToken IS NULL
                       AND e.ExpectedActionTypeID=1
                       AND e.buildingActionActive=1
                       AND t.buildingActionActive=0
                  THEN 0 ELSE e.buildingActionActive END),
          CONVERT(NVARCHAR(MAX),t.buildingActionActive)),

        (N'CustdyRecord',
         CAST(NULL AS NVARCHAR(MAX)),
         CONVERT(NVARCHAR(MAX),t.CustdyRecord)),

        (N'AssignPeriodID_FK',
         CAST(NULL AS NVARCHAR(MAX)),
         CONVERT(NVARCHAR(MAX),t.AssignPeriodID_FK)),

        (N'InAssignPeriod',
         CAST(NULL AS NVARCHAR(MAX)),
         CONVERT(NVARCHAR(MAX),t.InAssignPeriod)),

        (N'ExtendReasonTypeID_FK',
         CONVERT(NVARCHAR(MAX),e.ExpectedExtendReasonTypeID),
         CONVERT(NVARCHAR(MAX),t.ExtendReasonTypeID_FK)),

        (N'OccupentDate',
         CONVERT(NVARCHAR(MAX),e.ExpectedOccupentDate,126),
         CONVERT(NVARCHAR(MAX),t.OccupentDate,126)),

        (N'ExitDate',
         CONVERT(NVARCHAR(MAX),e.ExpectedExitDate,126),
         CONVERT(NVARCHAR(MAX),t.ExitDate,126)),

        (N'IdaraId_FK',
         CONVERT(NVARCHAR(MAX),e.ExpectedIdaraID),
         CONVERT(NVARCHAR(MAX),t.IdaraId_FK)),

        (N'entryDate',
         CONVERT(NVARCHAR(MAX),e.ExpectedEntryDate,126),
         CONVERT(NVARCHAR(MAX),t.entryDate,126)),

        (N'entryData',
         CONVERT(NVARCHAR(MAX),e.ExpectedEntryData),
         CONVERT(NVARCHAR(MAX),t.entryData)),

        (N'hostName',
         CONVERT(NVARCHAR(MAX),e.ExpectedHostName),
         CONVERT(NVARCHAR(MAX),t.hostName))

    ) v(FieldName,ExpectedValue,ActualValue)

    WHERE
           (
               v.ExpectedValue COLLATE DATABASE_DEFAULT
               <>
               v.ActualValue COLLATE DATABASE_DEFAULT
           )

        OR (
               v.ExpectedValue IS NULL
               AND v.ActualValue IS NOT NULL
           )

        OR (
               v.ExpectedValue IS NOT NULL
               AND v.ActualValue IS NULL
           );


    ------------------------------------------------------------
    -- 13.15 Validate SOURCE action parent
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , N'ACTIONS'
        , N'WRONG_PARENT'

        , N'MoveData expected action chain'
        , N'DATACORE.Housing.BuildingAction'

        , CONVERT(NVARCHAR(100),e.SourceActionID)

        , N'buildingActionParentID'

        , e.ExpectedParentToken

        , CASE
              WHEN t.buildingActionParentID IS NULL
                  THEN NULL

              ELSE CONCAT
                   (
                       N'ID:',
                       t.buildingActionParentID
                   )
          END

        , 'ERROR'

        , N'The action parent does not match the expected migration chain.'

    FROM #FV_ExpectedSourceActions e

    JOIN Housing.BuildingAction t
        ON t.buildingActionID = e.SourceActionID

    OUTER APPLY
    (
        SELECT
            CASE
                WHEN e.ExpectedParentToken IS NULL
                    THEN NULL

                WHEN e.ExpectedParentToken LIKE N'ID:%'
                    THEN TRY_CONVERT
                         (
                             BIGINT,
                             SUBSTRING
                             (
                                 e.ExpectedParentToken,
                                 4,
                                 500
                             )
                         )

                WHEN e.ExpectedParentToken LIKE N'MARKER:%'
                    THEN
                    (
                        SELECT MIN(x.buildingActionID)
                        FROM Housing.BuildingAction x
                        WHERE x.buildingActionExtraText4 =
                              SUBSTRING
                              (
                                  e.ExpectedParentToken,
                                  8,
                                  500
                              )
                        HAVING COUNT_BIG(*) = 1
                    )
            END AS ExpectedParentID
    ) p

    WHERE
        (
            e.ExpectedParentToken IS NULL
            AND t.buildingActionParentID IS NOT NULL
        )

        OR
        (
            e.ExpectedParentToken IS NOT NULL
            AND p.ExpectedParentID IS NOT NULL
            AND ISNULL(t.buildingActionParentID,-1)
                <> p.ExpectedParentID
        );


    ------------------------------------------------------------
    -- 13.16 Missing / duplicate GENERATED actions
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , N'ACTIONS'

        , CASE
              WHEN a.MatchCount = 0
                  THEN N'MISSING_GENERATED_ACTION'
              ELSE N'DUPLICATE_GENERATED_ACTION'
          END

        , N'MoveData.usp_MigrateLegacyAssignments'
        , N'DATACORE.Housing.BuildingAction'

        , e.Marker

        , N'buildingActionExtraText4'

        , N'Exactly 1'
        , CONVERT(NVARCHAR(100),a.MatchCount)

        , 'ERROR'

        , CONCAT
          (
              N'Generated migration action: ',
              e.GenerationKind
          )

    FROM #FV_ExpectedGeneratedActions e

    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.BuildingAction t
        WHERE t.buildingActionExtraText4 = e.Marker
    ) a

    WHERE a.MatchCount <> 1;


    ------------------------------------------------------------
    -- 13.17 Compare generated action values
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , N'ACTIONS'
        , N'GENERATED_ACTION_VALUE_MISMATCH'

        , N'MoveData.usp_MigrateLegacyAssignments'
        , N'DATACORE.Housing.BuildingAction'

        , e.Marker

        , v.FieldName
        , v.ExpectedValue
        , v.ActualValue

        , 'ERROR'

        , CONCAT
          (
              N'Generated migration action differs: ',
              e.GenerationKind
          )

    FROM #FV_ExpectedGeneratedActions e

    JOIN Housing.BuildingAction t
        ON t.buildingActionExtraText4 = e.Marker

    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.BuildingAction x
        WHERE x.buildingActionExtraText4 = e.Marker
    ) actionCount

    OUTER APPLY
    (
        SELECT
              ap.WaitingClassID_FK
            , ap.IdaraId_FK AS PeriodIdaraID
            , ap.AssignPeriodDescrption
        FROM Housing.AssignPeriod ap
        WHERE ap.AssignPeriodID = t.AssignPeriodID_FK
    ) period

    CROSS APPLY
    (
        VALUES

        (N'buildingActionTypeID_FK',
         CONVERT(NVARCHAR(MAX),e.ExpectedActionTypeID),
         CONVERT(NVARCHAR(MAX),t.buildingActionTypeID_FK)),

        (N'residentInfoID_FK',
         CONVERT(NVARCHAR(MAX),e.ResidentInfoID),
         CONVERT(NVARCHAR(MAX),t.residentInfoID_FK)),

        (N'generalNo_FK',
         CONVERT(NVARCHAR(MAX),e.GeneralNo),
         CONVERT(NVARCHAR(MAX),t.generalNo_FK)),

        (N'buildingDetailsID_FK',
         CONVERT(NVARCHAR(MAX),e.ExpectedBuildingID),
         CONVERT(NVARCHAR(MAX),t.buildingDetailsID_FK)),

        (N'buildingDetailsNo',
         CONVERT(NVARCHAR(MAX),e.ExpectedBuildingNo),
         CONVERT(NVARCHAR(MAX),t.buildingDetailsNo)),

        (N'buildingActionActive',
         N'1',
         CONVERT(NVARCHAR(MAX),t.buildingActionActive)),

        (N'InAssignPeriod',
         CONVERT(NVARCHAR(MAX),e.ExpectedInAssignPeriod),
         CONVERT(NVARCHAR(MAX),t.InAssignPeriod)),

        (N'buildingActionNote',
         CONVERT(NVARCHAR(MAX),e.ExpectedNote),
         CONVERT(NVARCHAR(MAX),t.buildingActionNote)),

        (N'buildingActionExtraInt1',
         CONVERT(NVARCHAR(MAX),e.ExpectedExtraInt1),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraInt1)),

        (N'buildingActionExtraText4',
         CONVERT(NVARCHAR(MAX),e.Marker),
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraText4)),

        (N'buildingActionExtraText5',
         N'MIGRATION_GENERATED',
         CONVERT(NVARCHAR(MAX),t.buildingActionExtraText5)),

        (N'IdaraId_FK',
         CONVERT(NVARCHAR(MAX),e.ExpectedIdaraID),
         CONVERT(NVARCHAR(MAX),t.IdaraId_FK)),

        (N'entryDate',
         CONVERT(NVARCHAR(MAX),e.ExpectedEntryDate,126),
         CONVERT(NVARCHAR(MAX),t.entryDate,126)),

        (N'entryData',
         CONVERT(NVARCHAR(MAX),e.ExpectedEntryData),
         CONVERT(NVARCHAR(MAX),t.entryData)),

        (N'hostName',
         CONVERT(NVARCHAR(MAX),e.ExpectedHostName),
         CONVERT(NVARCHAR(MAX),t.hostName)),

        (N'AssignPeriod.WaitingClassID_FK',
         CONVERT(NVARCHAR(MAX),e.ExpectedWaitingClassID),
         CONVERT(NVARCHAR(MAX),period.WaitingClassID_FK)),

        (N'AssignPeriod.IdaraId_FK',
         CASE
             WHEN e.ExpectedWaitingClassID IS NULL
                 THEN NULL
             ELSE CONVERT(NVARCHAR(MAX),e.ExpectedIdaraID)
         END,
         CONVERT(NVARCHAR(MAX),period.PeriodIdaraID)),

        (N'AssignPeriod.Description',
         CASE
             WHEN e.ExpectedWaitingClassID IS NULL
                 THEN NULL
             ELSE CONCAT
                  (
                      N'Legacy allocation migration - WaitingClass ',
                      e.ExpectedWaitingClassID
                  )
         END,
         CONVERT(NVARCHAR(MAX),period.AssignPeriodDescrption))

    ) v(FieldName,ExpectedValue,ActualValue)

    WHERE actionCount.MatchCount = 1

      AND
      (
             (
                 v.ExpectedValue COLLATE DATABASE_DEFAULT
                 <>
                 v.ActualValue COLLATE DATABASE_DEFAULT
             )

          OR (
                 v.ExpectedValue IS NULL
                 AND v.ActualValue IS NOT NULL
             )

          OR (
                 v.ExpectedValue IS NOT NULL
                 AND v.ActualValue IS NULL
             )
      );


    ------------------------------------------------------------
    -- 13.18 Generated action parent-chain validation
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , N'ACTIONS'
        , N'GENERATED_ACTION_WRONG_PARENT'

        , N'MoveData.usp_MigrateLegacyAssignments'
        , N'DATACORE.Housing.BuildingAction'

        , e.Marker
        , N'buildingActionParentID'

        , e.ExpectedParentToken

        , CASE
              WHEN t.buildingActionParentID IS NULL
                  THEN NULL
              ELSE CONCAT
                   (
                       N'ID:',
                       t.buildingActionParentID
                   )
          END

        , 'ERROR'

        , N'Generated action parent chain is incorrect.'

    FROM #FV_ExpectedGeneratedActions e

    JOIN Housing.BuildingAction t
        ON t.buildingActionExtraText4 = e.Marker

    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.BuildingAction x
        WHERE x.buildingActionExtraText4 = e.Marker
    ) ownCount

    OUTER APPLY
    (
        SELECT
            CASE
                WHEN e.ExpectedParentToken IS NULL
                    THEN NULL

                WHEN e.ExpectedParentToken LIKE N'ID:%'
                    THEN TRY_CONVERT
                         (
                             BIGINT,
                             SUBSTRING
                             (
                                 e.ExpectedParentToken,
                                 4,
                                 500
                             )
                         )

                WHEN e.ExpectedParentToken LIKE N'MARKER:%'
                    THEN
                    (
                        SELECT MIN(x.buildingActionID)
                        FROM Housing.BuildingAction x
                        WHERE x.buildingActionExtraText4 =
                              SUBSTRING
                              (
                                  e.ExpectedParentToken,
                                  8,
                                  500
                              )
                        HAVING COUNT_BIG(*) = 1
                    )
            END AS ExpectedParentID
    ) parentResolved

    WHERE ownCount.MatchCount = 1

      AND
      (
          (
              e.ExpectedParentToken IS NULL
              AND t.buildingActionParentID IS NOT NULL
          )

          OR
          (
              e.ExpectedParentToken IS NOT NULL
              AND parentResolved.ExpectedParentID IS NOT NULL
              AND ISNULL(t.buildingActionParentID,-1)
                  <> parentResolved.ExpectedParentID
          )
      );


    ------------------------------------------------------------
    -- 13.19 Unexpected MoveData-generated action
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.SourceResidentInfoID
        , e.SourceResidentDetailsID
        , e.FullName

        , N'ACTIONS'
        , N'UNEXPECTED_GENERATED_ACTION'

        , N'MoveData.usp_MigrateLegacyAssignments'
        , N'DATACORE.Housing.BuildingAction'

        , t.buildingActionExtraText4

        , N'buildingActionExtraText4'

        , NULL
        , t.buildingActionExtraText4

        , 'ERROR'

        , N'DATACORE contains a MoveData-generated action that is not expected from the KFMC assignment history.'

    FROM Housing.BuildingAction t

    JOIN #ExpectedResidents e
        ON e.SourceResidentInfoID = t.residentInfoID_FK

    WHERE t.buildingActionExtraText4 LIKE N'MoveData:%'

      AND NOT EXISTS
      (
          SELECT 1
          FROM #FV_ExpectedGeneratedActions x
          WHERE x.Marker = t.buildingActionExtraText4
      )

      /*
          Do not classify a preserved source row as generated
          merely because its source ExtraText4 happened to start
          with MoveData:.
      */
      AND NOT EXISTS
      (
          SELECT 1
          FROM #FV_ExpectedSourceActions s
          WHERE s.SourceActionID = t.buildingActionID
      );




    ------------------------------------------------------------
    -- 13.20 Action provenance guard, including building-only actions.
    -- LEGACY and MIGRATION_GENERATED are reserved, immutable labels.
    -- NULL and other text values are allowed, but are not proof of
    -- native origin. Compare with KFMC and MoveData: evidence.
    ------------------------------------------------------------
    INSERT INTO #ValidationIssues
    (
          EntityKey, GeneralNo, ResidentInfoID, ResidentDetailsID, FullName
        , SectionName, IssueCode, SourceObject, TargetObject, ReferenceID
        , FieldName, ExpectedValue, ActualValue, Severity, Notes
    )
    SELECT
          COALESCE(e.EntityKey,CONCAT(N'A:',a.buildingActionID))
        , TRY_CONVERT(BIGINT,a.generalNo_FK)
        , a.residentInfoID_FK
        , e.SourceResidentDetailsID
        , e.FullName
        , N'ACTIONS'
        , origin.IssueCode
        , N'KFMC.Housing.BuildingAction / MoveData'
        , N'DATACORE.Housing.BuildingAction'
        , CONVERT(NVARCHAR(100),a.buildingActionID)
        , N'buildingActionExtraText5'
        , origin.ExpectedValue
        , COALESCE(a.buildingActionExtraText5,N'<NULL>')
        , 'ERROR'
        , N'Origin marker or legacy source identity is inconsistent; other nonreserved values are allowed.'
    FROM Housing.BuildingAction a
    LEFT JOIN KFMC.Housing.BuildingAction sourceAction
      ON sourceAction.buildingActionID=a.buildingActionID
    LEFT JOIN #ExpectedResidents e
      ON e.GeneralNo=TRY_CONVERT(BIGINT,a.generalNo_FK)
    CROSS APPLY
    (
        SELECT
            CASE
                WHEN sourceAction.buildingActionID IS NOT NULL
                 AND
                 (
                     a.buildingActionUDID IS NULL
                     OR sourceAction.buildingActionUDID IS NULL
                     OR a.buildingActionUDID<>sourceAction.buildingActionUDID
                 )
                    THEN N'ORIGIN_SOURCE_IDENTITY_MISMATCH'
                WHEN sourceAction.buildingActionID IS NOT NULL
                 AND
                 (
                     a.buildingActionExtraText5 IS NULL
                     OR a.buildingActionExtraText5<>N'LEGACY'
                 )
                    THEN N'ORIGIN_LEGACY_CLASSIFICATION_MISMATCH'
                WHEN sourceAction.buildingActionID IS NULL
                 AND a.buildingActionExtraText5=N'LEGACY'
                    THEN N'ORIGIN_FALSE_LEGACY_CLASSIFICATION'
                WHEN a.buildingActionExtraText5=N'MIGRATION_GENERATED'
                 AND
                 (
                     sourceAction.buildingActionID IS NOT NULL
                     OR a.buildingActionExtraText4 IS NULL
                     OR a.buildingActionExtraText4 NOT LIKE N'MoveData:%'
                 )
                    THEN N'ORIGIN_FALSE_GENERATED_CLASSIFICATION'
                WHEN sourceAction.buildingActionID IS NULL
                 AND a.buildingActionExtraText4 LIKE N'MoveData:%'
                 AND
                 (
                     a.buildingActionExtraText5 IS NULL
                     OR a.buildingActionExtraText5<>N'MIGRATION_GENERATED'
                 )
                    THEN N'ORIGIN_GENERATED_CLASSIFICATION_MISSING'
                ELSE NULL
            END AS IssueCode,
            CASE
                WHEN sourceAction.buildingActionID IS NOT NULL
                    THEN N'LEGACY with matching KFMC UDID'
                WHEN a.buildingActionExtraText4 LIKE N'MoveData:%'
                    THEN N'MIGRATION_GENERATED'
                ELSE N'Not a reserved migration value'
            END AS ExpectedValue
    ) origin
    WHERE origin.IssueCode IS NOT NULL
      AND
      (
          @GeneralNo IS NULL
          OR TRY_CONVERT(BIGINT,a.generalNo_FK)=@GeneralNo
      );

          ------------------------------------------------------------
    -- 14. CLAIMS
    --
    -- 14A Electricity
    -- 14B Historical Rent
    -- 14C Historical Water
    -- 14D Penalties
    ------------------------------------------------------------


    ------------------------------------------------------------
    -- 14A. ELECTRICITY CLAIMS
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- Reproduce exact October-2024 duplicate selection rule
    ------------------------------------------------------------

    ;WITH RankedElectricSource AS
    (
        SELECT
              s.*

            , CASE
                  WHEN ISNULL(s.BillActive, 1) = 1
                   AND s.PeriodYear = 2024
                   AND s.PeriodMonth = 10
                  THEN
                      ROW_NUMBER() OVER
                      (
                          PARTITION BY
                                s.generalNo_FK
                              , s.buildingDetailsNo
                              , s.PeriodYear
                              , s.PeriodMonth
                              , CAST
                                (
                                    ISNULL(s.TotalPrice, 0)
                                    AS decimal(18,2)
                                )
                              , s.meterID
                              , s.meterNo
                              , s.meterReadID

                          ORDER BY
                              CASE
                                  WHEN EXISTS
                                  (
                                      SELECT 1
                                      FROM KFMC.Housing.BillsDeductListDetails d
                                      WHERE d.billsID_FK = s.BillsID
                                        AND d.billPaid = 1
                                        AND d.paidAmount IS NOT NULL
                                  )
                                  THEN 1
                                  ELSE 0
                              END DESC,
                              s.BillsID
                      )
                  ELSE 1
              END AS migrationRowNo

        FROM KFMC.Housing.Bills s
    )
    SELECT *
    INTO #FV_ElectricSourceRanked
    FROM RankedElectricSource;


    ------------------------------------------------------------
    -- Expected electricity claims belonging to eligible residents
    ------------------------------------------------------------

    SELECT
          COALESCE(e.EntityKey, CONCAT(N'B:', CONVERT(NVARCHAR(40), s.BillsID))) AS EntityKey
        , e.GeneralNo
        , e.SourceResidentInfoID AS ResidentInfoID
        , e.SourceResidentDetailsID AS ResidentDetailsID
        , e.FullName

        , CONVERT(BIGINT, s.BillsID) AS SourceBillsID
        , s.BillsUID

        , s.BillTypeID_FK

        , s.PeriodMonth
        , s.PeriodYear

        , s.meterNo
        , s.meterID
        , s.meterName_A
        , s.meterName_E
        , s.meterDescription

        , s.buildingDetailsNo
        , s.buildingUtilityTypeID
        , s.buildingDetailsID
        , s.meterTypeID

        , COALESCE
          (
              s.meterServiceTypeID,
              charge.MeterServiceTypeID_FK
          ) AS ExpectedMeterServiceTypeID

        , TRY_CONVERT(BIGINT, s.meterReadID) AS ExpectedMeterReadID

        , s.CurrentRead
        , s.LastRead
        , s.ReadDiff

        , s.meterSlideMinValue1
        , s.meterSlideMaxValue1
        , s.SlidePriceFactor1
        , s.PriceForSlide1

        , s.meterSlideMinValue2
        , s.meterSlideMaxValue2
        , s.SlidePriceFactor2
        , s.PriceForSlide2

        , s.meterSlideMinValue3
        , s.meterSlideMaxValue3
        , s.SlidePriceFactor3
        , s.PriceForSlide3

        , s.PRICE
        , s.PRICETAX
        , s.meterServicePrice
        , s.meterServicePriceTAX
        , s.TotalPrice

        , billDate.BillFromDate AS ExpectedBillsFromDate
        , billDate.BillToDate AS ExpectedBillsToDate

        , s.BillActive

        , @IdaraId AS ExpectedIdaraID

        , s.entryDate AS ExpectedEntryDate

        , MoveData.fn_MapEntryData(s.entryData)
            AS ExpectedEntryData

        , CASE
              WHEN MoveData.fn_MapEntryData(s.entryData) IS NULL
                  THEN s.hostName

              ELSE CONCAT
                   (
                       ISNULL(s.hostName, N''),
                       N'-',
                       NULLIF
                       (
                           LTRIM
                           (
                               RTRIM
                               (
                                   CONVERT
                                   (
                                       NVARCHAR(40),
                                       s.entryData
                                   )
                               )
                           ),
                           N''
                       )
                   )
          END AS ExpectedHostName

    INTO #FV_ExpectedElectricBills

    FROM #FV_ElectricSourceRanked s

    LEFT JOIN #ExpectedResidents e
        ON e.GeneralNo = TRY_CONVERT(BIGINT, s.generalNo_FK)

    JOIN Housing.BillChargeType charge
        ON charge.BillChargeTypeID = 2

    LEFT JOIN Housing.BillPeriod validPeriod
        ON validPeriod.billPeriodID = s.CurrentPeriodID
       AND validPeriod.IdaraId_FK = @IdaraId

    LEFT JOIN Housing.BillPeriodType validPeriodType
        ON validPeriodType.billPeriodTypeID =
           validPeriod.billPeriodTypeID_FK

    LEFT JOIN Housing.MeterRead targetRead
        ON targetRead.meterReadID =
           TRY_CONVERT(BIGINT, s.meterReadID)

    LEFT JOIN Housing.BillPeriod readPeriod
        ON readPeriod.billPeriodID =
           targetRead.billPeriodID_FK
       AND readPeriod.IdaraId_FK = @IdaraId

    LEFT JOIN Housing.BillPeriodType readPeriodType
        ON readPeriodType.billPeriodTypeID =
           readPeriod.billPeriodTypeID_FK

    OUTER APPLY
    (
        SELECT

            COALESCE
            (
                CASE
                    WHEN validPeriodType.meterServiceTypeID_FK =
                         charge.MeterServiceTypeID_FK
                    THEN CAST(validPeriod.billPeriodStartDate AS date)
                END,

                CASE
                    WHEN readPeriodType.meterServiceTypeID_FK =
                         charge.MeterServiceTypeID_FK
                    THEN CAST(readPeriod.billPeriodStartDate AS date)
                END,

                CASE
                    WHEN s.PeriodYear BETWEEN 1753 AND 9999
                     AND s.PeriodMonth BETWEEN 1 AND 12
                    THEN DATEFROMPARTS
                         (
                             s.PeriodYear,
                             s.PeriodMonth,
                             1
                         )
                END
            ) AS BillFromDate,

            COALESCE
            (
                CASE
                    WHEN validPeriodType.meterServiceTypeID_FK =
                         charge.MeterServiceTypeID_FK
                    THEN CAST(validPeriod.billPeriodEndDate AS date)
                END,

                CASE
                    WHEN readPeriodType.meterServiceTypeID_FK =
                         charge.MeterServiceTypeID_FK
                    THEN CAST(readPeriod.billPeriodEndDate AS date)
                END,

                CASE
                    WHEN s.PeriodYear BETWEEN 1753 AND 9999
                     AND s.PeriodMonth BETWEEN 1 AND 12
                    THEN EOMONTH
                         (
                             DATEFROMPARTS
                             (
                                 s.PeriodYear,
                                 s.PeriodMonth,
                                 1
                             )
                         )
                END
            ) AS BillToDate

    ) billDate

    WHERE s.migrationRowNo = 1
      AND (s.generalNo_FK IS NULL OR e.SourceResidentInfoID IS NOT NULL)
      AND (@GeneralNo IS NULL OR e.GeneralNo = @GeneralNo);


    ------------------------------------------------------------
    -- Missing electricity bill
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , N'ELECTRICITY_CLAIMS'
        , N'MISSING_ELECTRIC_BILL'

        , N'KFMC.Housing.Bills'
        , N'DATACORE.Housing.Bills'

        , CONVERT(NVARCHAR(100), e.SourceBillsID)

        , N'BillsID'

        , CONVERT(NVARCHAR(100), e.SourceBillsID)
        , NULL

        , 'ERROR'

        , N'فاتورة كهرباء مختارة للترحيل غير موجودة في DATACORE.'

    FROM #FV_ExpectedElectricBills e

    WHERE NOT EXISTS
    (
        SELECT 1
        FROM Housing.Bills t
        WHERE t.BillsID = e.SourceBillsID
    );


    ------------------------------------------------------------
    -- Source electricity duplicate that should have been excluded
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.SourceResidentInfoID
        , e.SourceResidentDetailsID
        , e.FullName

        , N'ELECTRICITY_CLAIMS'
        , N'UNEXPECTED_EXCLUDED_ELECTRIC_BILL'

        , N'KFMC.Housing.Bills'
        , N'DATACORE.Housing.Bills'

        , CONVERT(NVARCHAR(100), s.BillsID)

        , N'BillsID'

        , N'<EXCLUDED>'
        , CONVERT(NVARCHAR(100), t.BillsID)

        , 'ERROR'

        , N'فاتورة كهرباء مكررة كان يجب استبعادها بقاعدة October-2024.'

    FROM #FV_ElectricSourceRanked s

    LEFT JOIN #ExpectedResidents e
        ON e.GeneralNo = TRY_CONVERT(BIGINT, s.generalNo_FK)

    JOIN Housing.Bills t
        ON t.BillsID = TRY_CONVERT(BIGINT, s.BillsID)

    WHERE s.migrationRowNo > 1
      AND (s.generalNo_FK IS NULL OR e.SourceResidentInfoID IS NOT NULL)
      AND (@GeneralNo IS NULL OR e.GeneralNo = @GeneralNo);


    ------------------------------------------------------------
    -- Electricity field-by-field comparison
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , N'ELECTRICITY_CLAIMS'
        , N'ELECTRIC_BILL_VALUE_MISMATCH'

        , N'KFMC.Housing.Bills'
        , N'DATACORE.Housing.Bills'

        , CONVERT(NVARCHAR(100), e.SourceBillsID)

        , v.FieldName
        , v.ExpectedValue
        , v.ActualValue

        , 'ERROR'

        , N'فاتورة الكهرباء موجودة ولكن إحدى قيمها لا تطابق التحويل المتوقع.'

    FROM #FV_ExpectedElectricBills e

    JOIN Housing.Bills t
        ON t.BillsID = e.SourceBillsID

    CROSS APPLY
    (
        VALUES

        (N'BillsUID',
         CONVERT(NVARCHAR(MAX), e.BillsUID),
         CONVERT(NVARCHAR(MAX), t.BillsUID)),

        (N'BillChargeTypeID_FK',
         N'2',
         CONVERT(NVARCHAR(MAX), t.BillChargeTypeID_FK)),

        (N'BillTypeID_FK',
         CONVERT(NVARCHAR(MAX), e.BillTypeID_FK),
         CONVERT(NVARCHAR(MAX), t.BillTypeID_FK)),

        (N'PeriodMonth',
         CONVERT(NVARCHAR(MAX), e.PeriodMonth),
         CONVERT(NVARCHAR(MAX), t.PeriodMonth)),

        (N'PeriodYear',
         CONVERT(NVARCHAR(MAX), e.PeriodYear),
         CONVERT(NVARCHAR(MAX), t.PeriodYear)),

        (N'meterNo',
         CONVERT(NVARCHAR(MAX), e.meterNo),
         CONVERT(NVARCHAR(MAX), t.meterNo)),

        (N'meterID',
         CONVERT(NVARCHAR(MAX), e.meterID),
         CONVERT(NVARCHAR(MAX), t.meterID)),

        (N'meterReadID',
         CONVERT(NVARCHAR(MAX), e.ExpectedMeterReadID),
         CONVERT(NVARCHAR(MAX), t.meterReadID)),

        (N'buildingDetailsNo',
         CONVERT(NVARCHAR(MAX), e.buildingDetailsNo),
         CONVERT(NVARCHAR(MAX), t.buildingDetailsNo)),

        (N'buildingDetailsID',
         CONVERT(NVARCHAR(MAX), e.buildingDetailsID),
         CONVERT(NVARCHAR(MAX), t.buildingDetailsID)),

        (N'residentInfoID_FK',
         CONVERT(NVARCHAR(MAX), e.ResidentInfoID),
         CONVERT(NVARCHAR(MAX), t.residentInfoID_FK)),

        (N'generalNo_FK',
         CONVERT(NVARCHAR(MAX), e.GeneralNo),
         CONVERT(NVARCHAR(MAX), t.generalNo_FK)),

        (N'meterServiceTypeID',
         CONVERT(NVARCHAR(MAX), e.ExpectedMeterServiceTypeID),
         CONVERT(NVARCHAR(MAX), t.meterServiceTypeID)),

        (N'CurrentRead',
         CONVERT(NVARCHAR(MAX), e.CurrentRead),
         CONVERT(NVARCHAR(MAX), t.CurrentRead)),

        (N'LastRead',
         CONVERT(NVARCHAR(MAX), e.LastRead),
         CONVERT(NVARCHAR(MAX), t.LastRead)),

        (N'ReadDiff',
         CONVERT(NVARCHAR(MAX), e.ReadDiff),
         CONVERT(NVARCHAR(MAX), t.ReadDiff)),

        (N'PRICE',
         CONVERT(NVARCHAR(MAX), e.PRICE),
         CONVERT(NVARCHAR(MAX), t.PRICE)),

        (N'PRICETAX',
         CONVERT(NVARCHAR(MAX), e.PRICETAX),
         CONVERT(NVARCHAR(MAX), t.PRICETAX)),

        (N'meterServicePrice',
         CONVERT(NVARCHAR(MAX), e.meterServicePrice),
         CONVERT(NVARCHAR(MAX), t.meterServicePrice)),

        (N'meterServicePriceTAX',
         CONVERT(NVARCHAR(MAX), e.meterServicePriceTAX),
         CONVERT(NVARCHAR(MAX), t.meterServicePriceTAX)),

        (N'TotalPrice',
         CONVERT(NVARCHAR(MAX), e.TotalPrice),
         CONVERT(NVARCHAR(MAX), t.TotalPrice)),

                (N'BillsFromDate',
         CONVERT
         (
             NVARCHAR(MAX),
             CONVERT(date, e.ExpectedBillsFromDate),
             126
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             CONVERT(date, t.BillsFromDate),
             126
         )),

        (N'BillsToDate',
         CONVERT
         (
             NVARCHAR(MAX),
             CONVERT(date, e.ExpectedBillsToDate),
             126
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             CONVERT(date, t.BillsToDate),
             126
         )),

        (N'BillActive',
         CONVERT(NVARCHAR(MAX), e.BillActive),
         CONVERT(NVARCHAR(MAX), t.BillActive)),

        (N'idaraID_FK',
         CONVERT(NVARCHAR(MAX), e.ExpectedIdaraID),
         CONVERT(NVARCHAR(MAX), t.idaraID_FK)),

        (N'entryDate',
         CONVERT(NVARCHAR(MAX), e.ExpectedEntryDate, 126),
         CONVERT(NVARCHAR(MAX), t.entryDate, 126)),

        (N'entryData',
         CONVERT(NVARCHAR(MAX), e.ExpectedEntryData),
         CONVERT(NVARCHAR(MAX), t.entryData)),

        (N'hostName',
         CONVERT(NVARCHAR(MAX), e.ExpectedHostName),
         CONVERT(NVARCHAR(MAX), t.hostName))

    ) v(FieldName, ExpectedValue, ActualValue)

    WHERE
           (
               v.ExpectedValue COLLATE DATABASE_DEFAULT
               <>
               v.ActualValue COLLATE DATABASE_DEFAULT
           )

        OR (
               v.ExpectedValue IS NULL
               AND v.ActualValue IS NOT NULL
           )

        OR (
               v.ExpectedValue IS NOT NULL
               AND v.ActualValue IS NULL
           );


------------------------------------------------------------
-- 14B + 14C
    -- HISTORICAL RENT AND WATER FOR ELIGIBLE RESIDENTS
------------------------------------------------------------
    CREATE TABLE #FV_ExpectedHistoricalResidentBills
    (
          StagingID BIGINT IDENTITY(1,1) NOT NULL

        , EntityKey NVARCHAR(100) NOT NULL
        , GeneralNo BIGINT NOT NULL
        , ResidentInfoID BIGINT NOT NULL
        , ResidentDetailsID BIGINT NULL
        , FullName NVARCHAR(1000) NULL

        , ChargeTypeID INT NOT NULL
        , BillTypeID INT NOT NULL

        , BuildingDetailsID BIGINT NOT NULL
        , BuildingDetailsNo NVARCHAR(100) NULL

        , PeriodMonth INT NOT NULL
        , PeriodYear INT NOT NULL

        , FromDate DATE NOT NULL
        , ToDate DATE NOT NULL

        , Amount DECIMAL(18,2) NOT NULL

        , SourceEntryData NVARCHAR(40) NULL
        , ExpectedRentDays30 INT NULL
        , CoveredRentDays30 INT NULL
        , RentCalculationReason NVARCHAR(250) NULL
    );


    ;WITH OccupancyBase AS
    (
        SELECT
              actionRow.buildingActionID AS SourceActionID

            , e.EntityKey
            , e.GeneralNo
            , e.SourceResidentInfoID AS ResidentInfoID
            , e.SourceResidentDetailsID AS ResidentDetailsID
            , e.FullName

            , CONVERT
              (
                  BIGINT,
                  building.buildingDetailsID
              ) AS BuildingDetailsID

            , building.buildingDetailsNo AS BuildingDetailsNo

            , CAST
              (
                  actionRow.buildingActionDate
                  AS date
              ) AS OccupancyDate

            , CAST
              (
                  exitAction.ExitDate
                  AS date
              ) AS ExitDate

            , CAST
              (
                  nextOccupancy.NextOccupancyDate
                  AS date
              ) AS NextOccupancyDate

            , CONVERT
              (
                  NVARCHAR(40),
                  actionRow.entryData
              ) AS SourceEntryData

        FROM KFMC.Housing.BuildingAction actionRow

        JOIN #ExpectedResidents e
            ON e.GeneralNo =
               TRY_CONVERT
               (
                   BIGINT,
                   actionRow.generalNo_FK
               )

        JOIN KFMC.Housing.BuildingDetails building
            ON LTRIM(RTRIM(building.buildingDetailsNo))
             = LTRIM(RTRIM(actionRow.buildingDetailsNo))

        OUTER APPLY
        (
            SELECT TOP (1)
                exitRow.buildingActionDate AS ExitDate

            FROM KFMC.Housing.BuildingAction exitRow

            WHERE exitRow.buildingActionTypeID_FK = 3
              AND exitRow.buildingActionActive = 1

              AND exitRow.generalNo_FK =
                  actionRow.generalNo_FK

              AND LTRIM(RTRIM(exitRow.buildingDetailsNo))
                = LTRIM(RTRIM(actionRow.buildingDetailsNo))

              AND exitRow.buildingActionDate >=
                  actionRow.buildingActionDate

              AND
              (
                  exitRow.buildingActionParentID =
                      actionRow.buildingActionID

                  OR exitRow.buildingActionParentID IS NULL
              )

            ORDER BY
                  CASE
                      WHEN exitRow.buildingActionParentID =
                           actionRow.buildingActionID
                          THEN 0
                      ELSE 1
                  END
                , exitRow.buildingActionDate
                , exitRow.buildingActionID
        ) exitAction

        OUTER APPLY
        (
            SELECT TOP (1)
                nextRow.buildingActionDate AS NextOccupancyDate

            FROM KFMC.Housing.BuildingAction nextRow

            WHERE nextRow.buildingActionTypeID_FK = 2
              AND nextRow.buildingActionActive = 1

              AND LTRIM(RTRIM(nextRow.buildingDetailsNo))
                = LTRIM(RTRIM(actionRow.buildingDetailsNo))

              AND nextRow.buildingActionDate >
                  actionRow.buildingActionDate

            ORDER BY
                  nextRow.buildingActionDate
                , nextRow.buildingActionID
        ) nextOccupancy

        WHERE actionRow.buildingActionTypeID_FK = 2
          AND actionRow.buildingActionActive = 1
          AND actionRow.buildingActionDate IS NOT NULL

          AND CAST(actionRow.buildingActionDate AS date)
              <= @HistoricalEndDate
    ),
    OccupancyPeriods AS
    (
        SELECT
              o.*

            , CASE
                  WHEN o.ExitDate IS NOT NULL
                   AND o.ExitDate <= @HistoricalEndDate
                   AND
                       (
                           o.NextOccupancyDate IS NULL
                           OR o.ExitDate < o.NextOccupancyDate
                       )
                      THEN o.ExitDate

                  WHEN o.NextOccupancyDate IS NOT NULL
                   AND DATEADD
                       (
                           day,
                           -1,
                           o.NextOccupancyDate
                       ) < @HistoricalEndDate
                      THEN DATEADD
                           (
                               day,
                               -1,
                               o.NextOccupancyDate
                           )

                  ELSE @HistoricalEndDate
              END AS EndDate

            -- Approved 2026-11-08: uniform rent floor for all occupancy cycles.
            , @RentChargeStartDate AS RentChargeStartForCycle

        FROM OccupancyBase o
    ),
    Months AS
    (
        SELECT
              p.SourceActionID
            , p.EntityKey
            , p.GeneralNo
            , p.ResidentInfoID
            , p.ResidentDetailsID
            , p.FullName
            , p.BuildingDetailsID
            , p.BuildingDetailsNo
            , p.OccupancyDate
            , p.ExitDate
            , p.NextOccupancyDate
            , p.SourceEntryData
            , p.EndDate
            , p.RentChargeStartForCycle

            , CASE
                  WHEN p.OccupancyDate <
                       p.RentChargeStartForCycle
                      THEN p.RentChargeStartForCycle

                  ELSE DATEFROMPARTS
                       (
                           YEAR(p.OccupancyDate),
                           MONTH(p.OccupancyDate),
                           1
                       )
              END AS MonthStart

        FROM OccupancyPeriods p

        WHERE p.OccupancyDate <= p.EndDate
          AND p.EndDate >= p.RentChargeStartForCycle

        UNION ALL

        SELECT
              m.SourceActionID
            , m.EntityKey
            , m.GeneralNo
            , m.ResidentInfoID
            , m.ResidentDetailsID
            , m.FullName
            , m.BuildingDetailsID
            , m.BuildingDetailsNo
            , m.OccupancyDate
            , m.ExitDate
            , m.NextOccupancyDate
            , m.SourceEntryData
            , m.EndDate
            , m.RentChargeStartForCycle

            , DATEADD(month, 1, m.MonthStart)

        FROM Months m

        WHERE DATEADD(month, 1, m.MonthStart)
              <= m.EndDate
    ),
    BillPeriods AS
    (
        SELECT
              m.*

            , CASE
                  WHEN m.OccupancyDate > m.MonthStart
                      THEN m.OccupancyDate
                  ELSE m.MonthStart
              END AS BillFrom

            , CASE
                  WHEN m.EndDate < EOMONTH(m.MonthStart)
                      THEN m.EndDate
                  ELSE EOMONTH(m.MonthStart)
              END AS BillTo

        FROM Months m
    ),
    ChargePeriods AS
    (
        SELECT
              p.*

            , charge.ChargeTypeID

            , CASE
                  WHEN charge.ChargeTypeID = 1
                   AND p.BillFrom < p.RentChargeStartForCycle
                      THEN p.RentChargeStartForCycle

                  WHEN charge.ChargeTypeID = 3
                   AND p.BillFrom < @WaterChargeStartDate
                      THEN @WaterChargeStartDate

                  ELSE p.BillFrom
              END AS ChargeBillFrom

            , p.BillTo AS ChargeBillTo

        FROM BillPeriods p

        CROSS JOIN
        (
            VALUES (1), (3)
        ) charge(ChargeTypeID)

        WHERE
              (
                  charge.ChargeTypeID = 1
                  AND p.BillTo >= p.RentChargeStartForCycle
              )

           OR (
                  charge.ChargeTypeID = 3
                  AND p.BillTo >= @WaterChargeStartDate
              )
    ),
    Calculated AS
    (
        SELECT
              p.*

            , (
                  (YEAR(p.ChargeBillTo) -
                   YEAR(p.ChargeBillFrom)) * 360

                + (MONTH(p.ChargeBillTo) -
                   MONTH(p.ChargeBillFrom)) * 30

                + (
                      CASE
                          WHEN p.ChargeBillTo =
                               EOMONTH(p.ChargeBillTo)
                           AND DAY(p.ChargeBillTo) < 30
                              THEN 30

                          WHEN DAY(p.ChargeBillTo) > 30
                              THEN 30

                          ELSE DAY(p.ChargeBillTo)
                      END

                      -

                      CASE
                          WHEN p.ChargeBillFrom =
                               EOMONTH(p.ChargeBillFrom)
                           AND DAY(p.ChargeBillFrom) < 30
                              THEN 30

                          WHEN DAY(p.ChargeBillFrom) > 30
                              THEN 30

                          ELSE DAY(p.ChargeBillFrom)
                      END
                  )

                + 1

              ) AS Days30

        FROM ChargePeriods p

        WHERE p.ChargeBillFrom <= p.ChargeBillTo
    )
    INSERT INTO #FV_ExpectedHistoricalResidentBills
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , ChargeTypeID
        , BillTypeID
        , BuildingDetailsID
        , BuildingDetailsNo
        , PeriodMonth
        , PeriodYear
        , FromDate
        , ToDate
        , Amount
        , SourceEntryData
        , ExpectedRentDays30
        , CoveredRentDays30
        , RentCalculationReason
    )
    SELECT
          c.EntityKey
        , c.GeneralNo
        , c.ResidentInfoID
        , c.ResidentDetailsID
        , c.FullName

        , c.ChargeTypeID

        , CASE
              WHEN c.ExitDate IS NOT NULL
               AND c.ChargeBillTo = c.ExitDate
                  THEN 3
              ELSE 2
          END

        , c.BuildingDetailsID
        , c.BuildingDetailsNo

        , MONTH(c.MonthStart)
        , YEAR(c.MonthStart)

        , CASE WHEN c.ChargeTypeID = 1
                   AND tariffStats.TotalTariffRows > 0
               THEN tariffWindow.EffectiveFrom
               ELSE c.ChargeBillFrom END
        , CASE WHEN c.ChargeTypeID = 1
                   AND tariffStats.TotalTariffRows > 0
               THEN tariffWindow.EffectiveTo
               ELSE c.ChargeBillTo END

        , CASE c.ChargeTypeID

              WHEN 1
                  THEN ISNULL
                       (
                           rent.RentForMonth,
                           0
                       )

              WHEN 3
                  THEN CAST
                       (
                           (@WaterMonthlyAmount / 30.0)
                           * c.Days30
                           AS decimal(18,2)
                       )
          END

        , c.SourceEntryData
        , CASE WHEN c.ChargeTypeID = 1 THEN c.Days30 END
        , CASE WHEN c.ChargeTypeID = 1 THEN rent.Days30InMonth END
        , CASE
            WHEN c.ChargeTypeID <> 1 THEN NULL
            WHEN tariffStats.TotalTariffRows = 0 THEN N'إيجار صفر: لا توجد أي تعرفة إيجار مسجلة للمبنى'
            WHEN ISNULL(rent.RentForMonth, 0) = 0 THEN N'إيجار صفر وفق تعرفة مسجلة بقيمة صفر'
            WHEN ISNULL(rent.Days30InMonth, 0) < c.Days30
                THEN N'احتساب إيجار جزئي من الشهر وفق تواريخ سريان التعرفة'
            ELSE NULL
        END

    FROM Calculated c

    OUTER APPLY Housing.fn_CalcBuildingRent_ForOneMonth
    (
          CONVERT(INT, c.BuildingDetailsID)
        , c.OccupancyDate
        , YEAR(c.MonthStart)
        , MONTH(c.MonthStart)
        , c.EndDate
    ) rent
    -- A building with no tariff ever gets 0-SAR monthly invoices.
    -- For a building with tariff history, issue invoices ONLY in effective tariff months.
    OUTER APPLY
    (
        SELECT COUNT_BIG(*) AS TotalTariffRows
        FROM Housing.BuildingRent tr
        WHERE tr.buildingDetailsID_FK = c.BuildingDetailsID
    ) tariffStats
    -- Aggregate ONLY tariff-table expressions; apply outer invoice bounds
    -- separately to avoid SQL Server Msg 8124 (outer reference in MIN/MAX).
    OUTER APPLY
    (
        SELECT
            MIN(CAST(tr.buildingRentStartDate AS date)) AS FirstEffectiveStart,
            MAX(COALESCE(CAST(tr.buildingRentEndDate AS date),
                         CONVERT(date, '99991231', 112))) AS LastEffectiveEnd
        FROM Housing.BuildingRent tr
        WHERE tr.buildingDetailsID_FK = c.BuildingDetailsID
          AND tr.buildingRentStartDate IS NOT NULL
          AND CAST(tr.buildingRentStartDate AS date) <= c.ChargeBillTo
          AND (tr.buildingRentEndDate IS NULL
               OR CAST(tr.buildingRentEndDate AS date) >= c.ChargeBillFrom)
    ) tariffBounds
    OUTER APPLY
    (
        SELECT
            CASE WHEN tariffBounds.FirstEffectiveStart > c.ChargeBillFrom
                 THEN tariffBounds.FirstEffectiveStart
                 ELSE c.ChargeBillFrom END AS EffectiveFrom,
            CASE WHEN tariffBounds.LastEffectiveEnd < c.ChargeBillTo
                 THEN tariffBounds.LastEffectiveEnd
                 ELSE c.ChargeBillTo END AS EffectiveTo
    ) tariffWindow
    -- WATER stays exactly as before; rent has two distinct behaviors:
    --   no tariff records: monthly 0-SAR invoice + explanation;
    --   tariff history: only months with effective tariff days are invoiced.
    WHERE c.ChargeTypeID <> 1
       OR tariffStats.TotalTariffRows = 0
       OR ISNULL(rent.Days30InMonth, 0) > 0

    OPTION (MAXRECURSION 0);

    /* Overlapping tariff-days must not exceed 30/360 eligible month-days. */
    INSERT INTO #ValidationIssues
    (
        EntityKey, GeneralNo, ResidentInfoID, ResidentDetailsID, FullName,
        SectionName, IssueCode, SourceObject, TargetObject, ReferenceID,
        FieldName, ExpectedValue, ActualValue, Severity, Notes
    )
    SELECT
        e.EntityKey,e.GeneralNo,e.ResidentInfoID,e.ResidentDetailsID,e.FullName,
        N'RENT',N'HISTORICAL_RENT_DAY_OVERCOUNT',
        N'KFMC.Housing.BuildingRent',N'DATACORE.Housing.Bills',
        CONCAT(e.BuildingDetailsID,N':',CONVERT(nvarchar(10),MIN(e.FromDate),120)),
        N'Days30InMonth',CONVERT(nvarchar(100),MAX(e.ExpectedRentDays30)),
        CONVERT(nvarchar(100),MAX(e.CoveredRentDays30)),'ERROR',
        N'Rate changes produced more charge-days than the eligible occupancy period; correct 30/360 boundaries.'
    FROM #FV_ExpectedHistoricalResidentBills e
    WHERE e.ChargeTypeID=1
      AND ISNULL(e.CoveredRentDays30,0)>e.ExpectedRentDays30
    GROUP BY e.EntityKey,e.GeneralNo,e.ResidentInfoID,
             e.ResidentDetailsID,e.FullName,e.BuildingDetailsID;

    /* Zero rent is VALID for buildings without a historical tariff.
       For buildings with tariff records, only periods of effective tariff
       coverage are expected. Their month-specific values are independently
       reconstructed with the same rate-history calculator. */

    ------------------------------------------------------------
    -- Rank EXPECTED rows by exact migration key.
    --
    -- This preserves multiplicity if source history produces
    -- more than one staging row using the same business key.
    ------------------------------------------------------------

    SELECT
          e.*

        , ROW_NUMBER() OVER
          (
              PARTITION BY
                    e.ChargeTypeID
                  , e.BillTypeID
                  , e.ResidentInfoID
                  , e.BuildingDetailsID
                  , e.PeriodYear
                  , e.PeriodMonth
                  , e.FromDate
                  , e.ToDate

              ORDER BY
                    e.Amount
                  , e.StagingID
          ) AS ClaimOccurrence

    INTO #FV_ExpectedHistoricalResidentBillsRanked

    FROM #FV_ExpectedHistoricalResidentBills e;


    ------------------------------------------------------------
    -- Actual historical Rent/Water rows for eligible residents
    ------------------------------------------------------------

    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.SourceResidentInfoID AS ResidentInfoID
        , e.SourceResidentDetailsID AS ResidentDetailsID
        , e.FullName

        , b.BillsID

        , b.BillChargeTypeID_FK AS ChargeTypeID
        , b.BillTypeID_FK AS BillTypeID

        , b.buildingDetailsID AS BuildingDetailsID
        , b.buildingDetailsNo AS BuildingDetailsNo

        , b.PeriodMonth
        , b.PeriodYear

        , CAST(b.BillsFromDate AS date) AS FromDate
        , CAST(b.BillsToDate AS date) AS ToDate

        , b.PRICE
        , b.PRICETAX
        , b.TotalPrice
        , b.RentCalculationReason

        , b.CurrentPeriodTax
        , b.meterServiceTypeID
        , b.buildingRentTypeID_FK

        , b.BillActive
        , b.idaraID_FK

        , b.entryData
        , b.hostName

        , ROW_NUMBER() OVER
          (
              PARTITION BY
                    b.BillChargeTypeID_FK
                  , b.BillTypeID_FK
                  , b.residentInfoID_FK
                  , b.buildingDetailsID
                  , b.PeriodYear
                  , b.PeriodMonth
                  , CAST(b.BillsFromDate AS date)
                  , CAST(b.BillsToDate AS date)

              ORDER BY
                    b.TotalPrice
                  , b.BillsID
          ) AS ClaimOccurrence

    INTO #FV_ActualHistoricalResidentBills

    FROM Housing.Bills b

    JOIN #ExpectedResidents e
        ON e.SourceResidentInfoID =
           b.residentInfoID_FK

    WHERE b.idaraID_FK = @IdaraId
      AND b.BillActive = 1

      AND b.BillChargeTypeID_FK IN (1,3)

      AND CAST(b.BillsToDate AS date)
          <= @HistoricalEndDate

      AND
      (
           (
               b.BillChargeTypeID_FK = 1
               -- Keep pre-2017 actual rows visible to FULL OUTER JOIN,
               -- so any such active bill becomes an unexpected claim (FAIL).
           )

        OR (
               b.BillChargeTypeID_FK = 3
               AND CAST(b.BillsToDate AS date)
                   >= @WaterChargeStartDate
           )
      );


    ------------------------------------------------------------
    -- Full expected vs actual historical claims comparison
    ------------------------------------------------------------

    SELECT
          COALESCE(e.EntityKey, a.EntityKey)
            AS EntityKey

        , COALESCE(e.GeneralNo, a.GeneralNo)
            AS GeneralNo

        , COALESCE(e.ResidentInfoID, a.ResidentInfoID)
            AS ResidentInfoID

        , COALESCE(e.ResidentDetailsID, a.ResidentDetailsID)
            AS ResidentDetailsID

        , COALESCE(e.FullName, a.FullName)
            AS FullName

        , COALESCE(e.ChargeTypeID, a.ChargeTypeID)
            AS ChargeTypeID

        , e.StagingID
        , a.BillsID

        , e.BillTypeID AS ExpectedBillTypeID
        , a.BillTypeID AS ActualBillTypeID

        , e.BuildingDetailsID AS ExpectedBuildingID
        , a.BuildingDetailsID AS ActualBuildingID

        , e.BuildingDetailsNo AS ExpectedBuildingNo
        , a.BuildingDetailsNo AS ActualBuildingNo

        , e.PeriodMonth AS ExpectedPeriodMonth
        , a.PeriodMonth AS ActualPeriodMonth

        , e.PeriodYear AS ExpectedPeriodYear
        , a.PeriodYear AS ActualPeriodYear

        , e.FromDate AS ExpectedFromDate
        , a.FromDate AS ActualFromDate

        , e.ToDate AS ExpectedToDate
        , a.ToDate AS ActualToDate

        , e.Amount AS ExpectedAmount
        , a.TotalPrice AS ActualAmount
        , e.RentCalculationReason AS ExpectedRentCalculationReason
        , a.RentCalculationReason AS ActualRentCalculationReason

        , e.SourceEntryData

        , e.ClaimOccurrence AS ExpectedOccurrence
        , a.ClaimOccurrence AS ActualOccurrence

        , a.PRICE AS ActualPrice
        , a.PRICETAX AS ActualPriceTax
        , a.CurrentPeriodTax AS ActualCurrentPeriodTax
        , a.meterServiceTypeID AS ActualMeterServiceTypeID
        , a.buildingRentTypeID_FK AS ActualBuildingRentTypeID
        , a.BillActive AS ActualBillActive
        , a.idaraID_FK AS ActualIdaraID
        , a.entryData AS ActualEntryData
        , a.hostName AS ActualHostName

    INTO #FV_HistoricalClaimComparison

    FROM #FV_ExpectedHistoricalResidentBillsRanked e

    FULL OUTER JOIN #FV_ActualHistoricalResidentBills a

        ON a.ChargeTypeID =
           e.ChargeTypeID

       AND a.BillTypeID =
           e.BillTypeID

       AND a.ResidentInfoID =
           e.ResidentInfoID

       AND a.BuildingDetailsID =
           e.BuildingDetailsID

       AND a.PeriodYear =
           e.PeriodYear

       AND a.PeriodMonth =
           e.PeriodMonth

       AND a.FromDate =
           e.FromDate

       AND a.ToDate =
           e.ToDate

       AND a.ClaimOccurrence =
           e.ClaimOccurrence;


    /* Preserve and verify the accounting explanation on each matched rent bill.
       Existing operational invoices are not in scope; only expected historical
       migration rows matching both sides are checked. */
    INSERT INTO #ValidationIssues
    (
        EntityKey, GeneralNo, ResidentInfoID, ResidentDetailsID, FullName,
        SectionName, IssueCode, SourceObject, TargetObject, ReferenceID,
        FieldName, ExpectedValue, ActualValue, Severity, Notes
    )
    SELECT
        c.EntityKey, c.GeneralNo, c.ResidentInfoID, c.ResidentDetailsID,
        c.FullName, N'RENT', N'HISTORICAL_RENT_REASON_MISMATCH',
        N'Expected historical rent calculation', N'DATACORE.Housing.Bills',
        CONVERT(nvarchar(50),c.BillsID), N'RentCalculationReason',
        c.ExpectedRentCalculationReason, c.ActualRentCalculationReason,
        'ERROR', N'Zero or partially billed rent must retain the expected tariff reason.'
    FROM #FV_HistoricalClaimComparison c
    WHERE c.ChargeTypeID=1
      AND c.StagingID IS NOT NULL
      AND c.BillsID IS NOT NULL
      AND EXISTS
      (
          SELECT c.ExpectedRentCalculationReason
          EXCEPT
          SELECT c.ActualRentCalculationReason
      );

    ------------------------------------------------------------
    -- Missing Rent / Water
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          c.EntityKey
        , c.GeneralNo
        , c.ResidentInfoID
        , c.ResidentDetailsID
        , c.FullName

        , CASE
              WHEN c.ChargeTypeID = 1
                  THEN N'RENT_CLAIMS'
              ELSE N'WATER_CLAIMS'
          END

        , CASE
              WHEN c.ChargeTypeID = 1
                  THEN N'MISSING_RENT_BILL'
              ELSE N'MISSING_WATER_BILL'
          END

        , N'Expected DATACORE historical generation'
        , N'DATACORE.Housing.Bills'

        , CONCAT
          (
              N'Building=',
              c.ExpectedBuildingID,
              N';',
              c.ExpectedPeriodYear,
              N'/',
              c.ExpectedPeriodMonth,
              N';Occurrence=',
              c.ExpectedOccurrence
          )

        , N'BillRow'

        , CONCAT
          (
              N'Amount=',
              c.ExpectedAmount,
              N';From=',
              CONVERT
              (
                  NVARCHAR(30),
                  c.ExpectedFromDate,
                  126
              ),
              N';To=',
              CONVERT
              (
                  NVARCHAR(30),
                  c.ExpectedToDate,
                  126
              )
          )

        , NULL
        , 'ERROR'

        , N'مطالبة تاريخية متوقعة غير موجودة في DATACORE.'

    FROM #FV_HistoricalClaimComparison c

    WHERE c.ExpectedOccurrence IS NOT NULL
      AND c.ActualOccurrence IS NULL;


    ------------------------------------------------------------
    -- Unexpected historical Rent / Water
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          c.EntityKey
        , c.GeneralNo
        , c.ResidentInfoID
        , c.ResidentDetailsID
        , c.FullName

        , CASE
              WHEN c.ChargeTypeID = 1
                  THEN N'RENT_CLAIMS'
              ELSE N'WATER_CLAIMS'
          END

        , CASE
              WHEN c.ChargeTypeID = 1
                  THEN N'UNEXPECTED_RENT_BILL'
              ELSE N'UNEXPECTED_WATER_BILL'
          END

        , N'Expected DATACORE historical generation'
        , N'DATACORE.Housing.Bills'

        , CONVERT(NVARCHAR(100), c.BillsID)

        , N'BillRow'

        , NULL

        , CONCAT
          (
              N'Amount=',
              c.ActualAmount,
              N';From=',
              CONVERT
              (
                  NVARCHAR(30),
                  c.ActualFromDate,
                  126
              ),
              N';To=',
              CONVERT
              (
                  NVARCHAR(30),
                  c.ActualToDate,
                  126
              )
          )

        , 'ERROR'

        , N'يوجد Bill تاريخي للمستفيد لا يقابله Expected Claim من منطق الترحيل.'

    FROM #FV_HistoricalClaimComparison c

    WHERE c.ExpectedOccurrence IS NULL
      AND c.ActualOccurrence IS NOT NULL;


    ------------------------------------------------------------
    -- Rent / Water field comparison
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          c.EntityKey
        , c.GeneralNo
        , c.ResidentInfoID
        , c.ResidentDetailsID
        , c.FullName

        , CASE
              WHEN c.ChargeTypeID = 1
                  THEN N'RENT_CLAIMS'
              ELSE N'WATER_CLAIMS'
          END

        , CASE
              WHEN c.ChargeTypeID = 1
                  THEN N'RENT_BILL_VALUE_MISMATCH'
              ELSE N'WATER_BILL_VALUE_MISMATCH'
          END

        , N'Expected DATACORE historical generation'
        , N'DATACORE.Housing.Bills'

        , CONVERT(NVARCHAR(100), c.BillsID)

        , v.FieldName
        , v.ExpectedValue
        , v.ActualValue

        , 'ERROR'

        , N'المطالبة موجودة ولكن إحدى قيمها لا تطابق نتيجة التوليد التاريخي المتوقعة.'

    FROM #FV_HistoricalClaimComparison c

    CROSS APPLY
    (
        SELECT charge.MeterServiceTypeID_FK
        FROM Housing.BillChargeType charge
        WHERE charge.BillChargeTypeID =
              c.ChargeTypeID
    ) charge

    CROSS APPLY
    (
        VALUES

        (N'TotalPrice',
         CONVERT(NVARCHAR(MAX), c.ExpectedAmount),
         CONVERT(NVARCHAR(MAX), c.ActualAmount)),

        (N'PRICE',
         CONVERT
         (
             NVARCHAR(MAX),
             CASE
                 WHEN c.ChargeTypeID = 3
                     THEN CAST
                          (
                              ROUND
                              (
                                  c.ExpectedAmount
                                  /
                                  CAST
                                  (
                                      1.15
                                      AS decimal(18,4)
                                  ),
                                  2
                              )
                              AS decimal(18,2)
                          )
                 ELSE c.ExpectedAmount
             END
         ),
         CONVERT(NVARCHAR(MAX), c.ActualPrice)),

        (N'PRICETAX',
         CONVERT
         (
             NVARCHAR(MAX),
             CASE
                 WHEN c.ChargeTypeID = 3
                     THEN CAST
                          (
                              c.ExpectedAmount
                              -
                              ROUND
                              (
                                  c.ExpectedAmount
                                  /
                                  CAST
                                  (
                                      1.15
                                      AS decimal(18,4)
                                  ),
                                  2
                              )
                              AS decimal(18,2)
                          )
                 ELSE CAST(0 AS decimal(18,2))
             END
         ),
         CONVERT(NVARCHAR(MAX), c.ActualPriceTax)),

        (N'CurrentPeriodTax',
         CONVERT
         (
             NVARCHAR(MAX),
             CASE
                 WHEN c.ChargeTypeID = 3
                     THEN CAST(15 AS decimal(18,2))
                 ELSE CAST(0 AS decimal(18,2))
             END
         ),
         CONVERT(NVARCHAR(MAX), c.ActualCurrentPeriodTax)),

        (N'meterServiceTypeID',
         CONVERT
         (
             NVARCHAR(MAX),
             charge.MeterServiceTypeID_FK
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             c.ActualMeterServiceTypeID
         )),

        (N'buildingRentTypeID_FK',
         CASE
             WHEN c.ChargeTypeID = 1
                 THEN N'1'
             ELSE NULL
         END,
         CONVERT
         (
             NVARCHAR(MAX),
             c.ActualBuildingRentTypeID
         )),

        (N'BillActive',
         N'1',
         CONVERT
         (
             NVARCHAR(MAX),
             c.ActualBillActive
         )),

        (N'idaraID_FK',
         CONVERT(NVARCHAR(MAX), @IdaraId),
         CONVERT
         (
             NVARCHAR(MAX),
             c.ActualIdaraID
         )),

        (N'entryData',
         CONVERT
         (
             NVARCHAR(MAX),
             MoveData.fn_MapEntryData
             (
                 c.SourceEntryData
             )
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             c.ActualEntryData
         )),

        (N'hostName',
         CONVERT
         (
             NVARCHAR(MAX),
             CASE
                 WHEN MoveData.fn_MapEntryData
                      (
                          c.SourceEntryData
                      ) IS NULL
                     THEN N'Data Migration'

                 ELSE CONCAT
                      (
                          N'Data Migration-',
                          NULLIF
                          (
                              LTRIM
                              (
                                  RTRIM
                                  (
                                      c.SourceEntryData
                                  )
                              ),
                              N''
                          )
                      )
             END
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             c.ActualHostName
         ))

    ) v(FieldName, ExpectedValue, ActualValue)

    WHERE c.ExpectedOccurrence IS NOT NULL
      AND c.ActualOccurrence IS NOT NULL

      AND
      (
             (
                 v.ExpectedValue COLLATE DATABASE_DEFAULT
                 <>
                 v.ActualValue COLLATE DATABASE_DEFAULT
             )

          OR (
                 v.ExpectedValue IS NULL
                 AND v.ActualValue IS NOT NULL
             )

          OR (
                 v.ExpectedValue IS NOT NULL
                 AND v.ActualValue IS NULL
             )
      );


    ------------------------------------------------------------
    -- 14D. PENALTY CLAIMS
    ------------------------------------------------------------

    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.SourceResidentInfoID AS ResidentInfoID
        , e.SourceResidentDetailsID AS ResidentDetailsID
        , e.FullName

        , c.occupantCustodyActionID AS SourcePenaltyID

        , CONVERT
          (
              UNIQUEIDENTIFIER,
              HASHBYTES
              (
                  'MD5',
                  CONCAT
                  (
                      N'PENALTY-BILL|',
                      c.occupantCustodyActionID
                  )
              )
          ) AS ExpectedBillsUID

        , a.buildingDetailsNo AS ExpectedBuildingNo
        , CONVERT
          (
              INT,
              a.buildingDetailsID_FK
          ) AS ExpectedBuildingID

        , a.residentInfoID_FK AS ExpectedResidentInfoID
        , a.generalNo_FK AS ExpectedGeneralNo

        , c.occupantCustodyActionPenalty
            AS ExpectedAmount

        , c.entryDate AS ExpectedEntryDate

        , c.occupantCustodyActionNote
            AS ExpectedPenaltyReason

        , c.occupantCustodyActionActive
            AS ExpectedBillActive

        , c.canceldBy
            AS ExpectedCanceledBy

        , MoveData.fn_MapEntryData(c.entryData)
            AS ExpectedEntryData

        , MoveData.fn_MapHostName
          (
              c.hostName,
              c.entryData
          ) AS ExpectedHostName

    INTO #FV_ExpectedPenaltyBills

    FROM KFMC.Housing.OccupantCustodyAction c

    JOIN Housing.BuildingAction a
        ON a.buildingActionID =
           TRY_CONVERT
           (
               BIGINT,
               c.buildingActionID_FK
           )

    JOIN #ExpectedResidents e
        ON e.SourceResidentInfoID =
           a.residentInfoID_FK;


    ------------------------------------------------------------
    -- Missing or duplicate penalty Bill
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , N'PENALTY_CLAIMS'

        , CASE
              WHEN x.MatchCount = 0
                  THEN N'MISSING_PENALTY_BILL'
              ELSE N'DUPLICATE_PENALTY_BILL'
          END

        , N'KFMC.Housing.OccupantCustodyAction'
        , N'DATACORE.Housing.Bills'

        , CONVERT
          (
              NVARCHAR(100),
              e.SourcePenaltyID
          )

        , N'BillsUID'

        , CONVERT
          (
              NVARCHAR(100),
              e.ExpectedBillsUID
          )

        , CONVERT
          (
              NVARCHAR(100),
              x.MatchCount
          )

        , 'ERROR'

        , N'كل غرامة KFMC يجب أن تنتج Bill واحدة فقط.'

    FROM #FV_ExpectedPenaltyBills e

    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.Bills b
        WHERE b.BillsUID =
              e.ExpectedBillsUID
    ) x

    WHERE x.MatchCount <> 1;


    ------------------------------------------------------------
    -- Penalty field comparison
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , N'PENALTY_CLAIMS'
        , N'PENALTY_BILL_VALUE_MISMATCH'

        , N'KFMC.Housing.OccupantCustodyAction'
        , N'DATACORE.Housing.Bills'

        , CONVERT
          (
              NVARCHAR(100),
              e.SourcePenaltyID
          )

        , v.FieldName
        , v.ExpectedValue
        , v.ActualValue

        , 'ERROR'

        , N'فاتورة الغرامة موجودة ولكن إحدى قيمها تختلف عن المصدر.'

    FROM #FV_ExpectedPenaltyBills e

    JOIN Housing.Bills b
        ON b.BillsUID =
           e.ExpectedBillsUID

    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.Bills x
        WHERE x.BillsUID =
              e.ExpectedBillsUID
    ) billCount

    CROSS APPLY
    (
        VALUES

        (N'BillChargeTypeID_FK',
         N'5',
         CONVERT(NVARCHAR(MAX),b.BillChargeTypeID_FK)),

        (N'BillTypeID_FK',
         N'3',
         CONVERT(NVARCHAR(MAX),b.BillTypeID_FK)),

        (N'PeriodMonth',
         CONVERT
         (
             NVARCHAR(MAX),
             MONTH(e.ExpectedEntryDate)
         ),
         CONVERT(NVARCHAR(MAX),b.PeriodMonth)),

        (N'PeriodYear',
         CONVERT
         (
             NVARCHAR(MAX),
             YEAR(e.ExpectedEntryDate)
         ),
         CONVERT(NVARCHAR(MAX),b.PeriodYear)),

        (N'buildingDetailsNo',
         CONVERT
         (
             NVARCHAR(MAX),
             e.ExpectedBuildingNo
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             b.buildingDetailsNo
         )),

        (N'buildingDetailsID',
         CONVERT
         (
             NVARCHAR(MAX),
             e.ExpectedBuildingID
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             b.buildingDetailsID
         )),

        (N'residentInfoID_FK',
         CONVERT
         (
             NVARCHAR(MAX),
             e.ExpectedResidentInfoID
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             b.residentInfoID_FK
         )),

        (N'generalNo_FK',
         CONVERT
         (
             NVARCHAR(MAX),
             e.ExpectedGeneralNo
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             b.generalNo_FK
         )),

        (N'PRICE',
         CONVERT
         (
             NVARCHAR(MAX),
             e.ExpectedAmount
         ),
         CONVERT(NVARCHAR(MAX),b.PRICE)),

        (N'PRICETAX',
         N'0.00',
         CONVERT(NVARCHAR(MAX),b.PRICETAX)),

        (N'TotalPrice',
         CONVERT
         (
             NVARCHAR(MAX),
             e.ExpectedAmount
         ),
         CONVERT(NVARCHAR(MAX),b.TotalPrice)),

        (N'BillsFromDate',
         CONVERT
         (
             NVARCHAR(MAX),
             e.ExpectedEntryDate,
             126
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             b.BillsFromDate,
             126
         )),

        (N'BillsToDate',
         CONVERT
         (
             NVARCHAR(MAX),
             e.ExpectedEntryDate,
             126
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             b.BillsToDate,
             126
         )),

        (N'PenaltyReason',
         CONVERT
         (
             NVARCHAR(MAX),
             e.ExpectedPenaltyReason
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             b.PenaltyReason
         )),

        (N'BillActive',
         CONVERT
         (
             NVARCHAR(MAX),
             e.ExpectedBillActive
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             b.BillActive
         )),

        (N'CanceledBy',
         CONVERT
         (
             NVARCHAR(MAX),
             e.ExpectedCanceledBy
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             b.CanceledBy
         )),

        (N'idaraID_FK',
         CONVERT(NVARCHAR(MAX),@IdaraId),
         CONVERT
         (
             NVARCHAR(MAX),
             b.idaraID_FK
         )),

        (N'entryDate',
         CONVERT
         (
             NVARCHAR(MAX),
             e.ExpectedEntryDate,
             126
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             b.entryDate,
             126
         )),

        (N'entryData',
         CONVERT
         (
             NVARCHAR(MAX),
             e.ExpectedEntryData
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             b.entryData
         )),

        (N'hostName',
         CONVERT
         (
             NVARCHAR(MAX),
             e.ExpectedHostName
         ),
         CONVERT
         (
             NVARCHAR(MAX),
             b.hostName
         ))

    ) v(FieldName, ExpectedValue, ActualValue)

    WHERE billCount.MatchCount = 1

      AND
      (
             (
                 v.ExpectedValue COLLATE DATABASE_DEFAULT
                 <>
                 v.ActualValue COLLATE DATABASE_DEFAULT
             )

          OR (
                 v.ExpectedValue IS NULL
                 AND v.ActualValue IS NOT NULL
             )

          OR (
                 v.ExpectedValue IS NOT NULL
                 AND v.ActualValue IS NULL
             )
      );



    ------------------------------------------------------------
    -- 15. PAYMENTS
    --
    -- 15A Historical Rent Payments
    -- 15B Electricity Opening Payments
    -- 15C Penalty Payments
    -- 15D Payment Types
    --
    -- Link-status / building allocation rules are validated
    -- in the next phase. This section validates payment migration
    -- identity, amount, source list, activity, charge type and
    -- payment type without treating later classification changes
    -- as migration mismatches.
    ------------------------------------------------------------


    ------------------------------------------------------------
    -- 15A. Historical Rent Payments
    ------------------------------------------------------------

    SELECT
          COALESCE
          (
              e.EntityKey,
              CASE
                  WHEN TRY_CONVERT(BIGINT, p.userID_FK) IS NOT NULL
                      THEN CONCAT
                           (
                               N'G:',
                               TRY_CONVERT(BIGINT, p.userID_FK)
                           )
                  ELSE CONCAT
                       (
                           N'RENT_PAYMENT:',
                           TRY_CONVERT(BIGINT, p.paymentID)
                       )
              END
          ) AS EntityKey

        , TRY_CONVERT(BIGINT, p.userID_FK)
            AS GeneralNo

        , eligible.ResidentInfoID
            AS ResidentInfoID

        , e.SourceResidentDetailsID
            AS ResidentDetailsID

        , e.FullName

        , TRY_CONVERT(BIGINT, p.paymentID)
            AS ExpectedPaymentID

        , p.PaymentUID
            AS ExpectedPaymentUID

        , p.buildingPaymentTypeID_FK
            AS ExpectedPaymentTypeID

        , TRY_CONVERT(BIGINT, p.userID_FK)
            AS ExpectedGeneralNo

        , p.amount
            AS ExpectedAmount

        , p.deductListID_FK
            AS ExpectedDeductListID

        , CONVERT(bit,CASE WHEN eligible.ResidentInfoID IS NOT NULL
                               AND targetResident.residentInfoID IS NOT NULL
                               AND ISNULL(p.buildingPayementActive,0)=1
                               AND ISNULL(d.deductActive,0)=1
                          THEN 1 ELSE 0 END) AS ExpectedActive

        , CONVERT(int, 1)
            AS ExpectedChargeTypeID

        , CONVERT(int, @IdaraId)
            AS ExpectedIdaraID

    INTO #FV_ExpectedRentPayments

    FROM KFMC.Housing.BuildingPayment p

    JOIN KFMC.Housing.DeductList d
        ON d.deductListID = p.deductListID_FK

    LEFT JOIN #ExpectedResidents e
        ON e.GeneralNo = TRY_CONVERT(BIGINT, p.userID_FK)
    LEFT JOIN #EligibleMigrationResidents eligible
        ON eligible.GeneralNo = TRY_CONVERT(BIGINT, p.userID_FK)
    LEFT JOIN Housing.ResidentInfo targetResident
        ON targetResident.residentInfoID = eligible.ResidentInfoID
       AND targetResident.residentInfoActive=1

    WHERE
      (
          @GeneralNo IS NULL
          OR TRY_CONVERT(BIGINT, p.userID_FK) = @GeneralNo
      );


    ------------------------------------------------------------
    -- Rent payment must exist exactly once by preserved paymentID
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , N'PAYMENTS'

        , CASE
              WHEN x.MatchCount = 0
                  THEN N'MISSING_RENT_PAYMENT'
              ELSE N'DUPLICATE_RENT_PAYMENT'
          END

        , N'KFMC.Housing.BuildingPayment'
        , N'DATACORE.Housing.BuildingPayment'

        , CONVERT
          (
              NVARCHAR(100),
              e.ExpectedPaymentID
          )

        , N'paymentID'

        , N'1'

        , CONVERT
          (
              NVARCHAR(100),
              x.MatchCount
          )

        , 'ERROR'

        , N'كل سداد إيجار تاريخي نشط في KFMC يجب أن ينتج صف BuildingPayment واحداً محفوظ الهوية في DATACORE.'

    FROM #FV_ExpectedRentPayments e

    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.BuildingPayment t
        WHERE t.paymentID = e.ExpectedPaymentID
          AND t.BillChargeTypeID_FK = 1
    ) x

    WHERE x.MatchCount <> 1;


    ------------------------------------------------------------
    -- Rent payment field comparison
    -- Payment-link fields are intentionally excluded here.
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , CASE
              WHEN v.FieldName = N'buildingPaymentTypeID_FK'
                  THEN N'PAYMENT_TYPES'
              ELSE N'PAYMENTS'
          END

        , CASE
              WHEN v.FieldName = N'buildingPaymentTypeID_FK'
                  THEN N'RENT_PAYMENT_TYPE_MISMATCH'
              ELSE N'RENT_PAYMENT_VALUE_MISMATCH'
          END

        , N'KFMC.Housing.BuildingPayment / DeductList'
        , N'DATACORE.Housing.BuildingPayment'

        , CONVERT
          (
              NVARCHAR(100),
              e.ExpectedPaymentID
          )

        , v.FieldName
        , v.ExpectedValue
        , v.ActualValue

        , 'ERROR'

        , N'سداد الإيجار موجود ولكن إحدى القيم المحفوظة من المصدر لا تطابق القيمة المتوقعة.'

    FROM #FV_ExpectedRentPayments e

    JOIN Housing.BuildingPayment t
        ON t.paymentID = e.ExpectedPaymentID
       AND t.BillChargeTypeID_FK = 1

    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.BuildingPayment x
        WHERE x.paymentID = e.ExpectedPaymentID
          AND x.BillChargeTypeID_FK = 1
    ) paymentCount

    CROSS APPLY
    (
        VALUES
        (
            N'PaymentUID',
            CONVERT(NVARCHAR(MAX), e.ExpectedPaymentUID),
            CONVERT(NVARCHAR(MAX), t.PaymentUID)
        ),
        (
            N'buildingPaymentTypeID_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedPaymentTypeID),
            CONVERT(NVARCHAR(MAX), t.buildingPaymentTypeID_FK)
        ),
        (
            N'generalNo_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedGeneralNo),
            CONVERT(NVARCHAR(MAX), t.generalNo_FK)
        ),
        (
            N'amount',
            CONVERT(NVARCHAR(MAX), e.ExpectedAmount),
            CONVERT(NVARCHAR(MAX), t.amount)
        ),
        (
            N'deductListID_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedDeductListID),
            CONVERT(NVARCHAR(MAX), t.deductListID_FK)
        ),
        (
            N'buildingPayementActive',
            CONVERT(NVARCHAR(MAX), e.ExpectedActive),
            CONVERT(NVARCHAR(MAX), t.buildingPayementActive)
        ),
        (
            N'BillChargeTypeID_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedChargeTypeID),
            CONVERT(NVARCHAR(MAX), t.BillChargeTypeID_FK)
        ),
        (
            N'IdaraId_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedIdaraID),
            CONVERT(NVARCHAR(MAX), t.IdaraId_FK)
        )
    ) v
    (
          FieldName
        , ExpectedValue
        , ActualValue
    )

    WHERE paymentCount.MatchCount = 1

      AND
      (
             (
                 v.ExpectedValue COLLATE DATABASE_DEFAULT
                 <>
                 v.ActualValue COLLATE DATABASE_DEFAULT
             )

          OR (
                 v.ExpectedValue IS NULL
                 AND v.ActualValue IS NOT NULL
             )

          OR (
                 v.ExpectedValue IS NOT NULL
                 AND v.ActualValue IS NULL
             )
      );


    ------------------------------------------------------------
    -- Unexpected target Rent payment
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          COALESCE
          (
              e.EntityKey,
              CASE
                  WHEN t.generalNo_FK IS NOT NULL
                      THEN CONCAT(N'G:', t.generalNo_FK)
                  ELSE CONCAT(N'RENT_PAYMENT:', t.paymentID)
              END
          )

        , t.generalNo_FK
        , e.SourceResidentInfoID
        , e.SourceResidentDetailsID
        , e.FullName

        , N'PAYMENTS'
        , N'UNEXPECTED_TARGET_RENT_PAYMENT'

        , N'KFMC.Housing.BuildingPayment'
        , N'DATACORE.Housing.BuildingPayment'

        , CONVERT(NVARCHAR(100), t.paymentID)

        , N'paymentID'

        , NULL
        , CONVERT(NVARCHAR(100), t.paymentID)

        , 'ERROR'

        , N'يوجد سداد إيجار في DATACORE لا يقابله سداد نشط متوقع من KFMC ضمن نطاق التحقق.'

    FROM Housing.BuildingPayment t

    LEFT JOIN #ExpectedResidents e
        ON e.SourceResidentInfoID = t.residentInfoID_FK

    WHERE t.BillChargeTypeID_FK = 1
      AND t.IdaraId_FK = @IdaraId

      AND
      (
          @GeneralNo IS NULL
          OR t.generalNo_FK = @GeneralNo
          OR EXISTS
             (
                 SELECT 1
                 FROM #ExpectedResidents scopeResident
                 WHERE scopeResident.SourceResidentInfoID =
                       t.residentInfoID_FK
             )
      )

      AND NOT EXISTS
      (
          SELECT 1
          FROM #FV_ExpectedRentPayments expectedPayment
          WHERE expectedPayment.ExpectedPaymentID =
                t.paymentID
      );


    ------------------------------------------------------------
    -- 15B. Electricity Opening Payments
    ------------------------------------------------------------

    SELECT
          COALESCE
          (
              e.EntityKey,
              CASE
                  WHEN TRY_CONVERT(BIGINT, b.generalNo_FK) IS NOT NULL
                      THEN CONCAT
                           (
                               N'G:',
                               TRY_CONVERT(BIGINT, b.generalNo_FK)
                           )
                  ELSE CONCAT
                       (
                           N'ELECTRIC_PAYMENT:',
                           d.billsDeductListDetailsID
                       )
              END
          ) AS EntityKey

        , TRY_CONVERT(BIGINT, b.generalNo_FK)
            AS GeneralNo

        , e.SourceResidentInfoID
            AS ResidentInfoID

        , e.SourceResidentDetailsID
            AS ResidentDetailsID

        , e.FullName

        , d.billsDeductListDetailsID
            AS SourcePaymentDetailID

        , d.billsDeductListDetailsUID
            AS ExpectedPaymentUID

        , COALESCE(d.paymentType, 1)
            AS ExpectedPaymentTypeID

        , TRY_CONVERT(BIGINT, b.generalNo_FK)
            AS ExpectedGeneralNo

        , migratedResident.residentInfoID
            AS ExpectedResidentInfoID

        , CONVERT
          (
              NVARCHAR(400),
              b.buildingDetailsID
          ) AS ExpectedBuildingDetailsID

        , d.paidAmount
            AS ExpectedAmount

        , targetList.deductListID
            AS ExpectedDeductListID

        , CONVERT(bit,CASE WHEN migratedResident.residentInfoID IS NOT NULL
                                AND ISNULL(sourceList.deductActive,0)=1
                          THEN 1 ELSE 0 END) AS ExpectedActive

        , CONVERT(int, 2)
            AS ExpectedChargeTypeID

        , CONVERT(int, @IdaraId)
            AS ExpectedIdaraID

    INTO #FV_ExpectedElectricPayments

    FROM KFMC.Housing.BillsDeductListDetails d

    JOIN #FV_ElectricSourceRanked b
        ON b.BillsID = d.billsID_FK
       AND b.migrationRowNo = 1

    LEFT JOIN #ExpectedResidents e
        ON e.GeneralNo = TRY_CONVERT(BIGINT, b.generalNo_FK)

    LEFT JOIN Housing.ResidentInfo migratedResident
        ON migratedResident.residentInfoID = e.SourceResidentInfoID
       AND migratedResident.residentInfoActive = 1

    JOIN KFMC.Housing.BillDeductList sourceList
        ON sourceList.billDeductListID =
           d.billDeductListID_FK

    LEFT JOIN Housing.DeductList targetList
        ON targetList.deductUID =
           CONVERT
           (
               UNIQUEIDENTIFIER,
               HASHBYTES
               (
                   'MD5',
                   CONCAT
                   (
                       N'E|',
                       sourceList.billDeductListID,
                       N'|',
                       COALESCE
                       (
                           sourceList.issueYear,
                           YEAR(d.paidDate)
                       ),
                       N'|',
                       COALESCE
                       (
                           sourceList.issueMonth,
                           MONTH(d.paidDate)
                       )
                   )
               )
           )

    WHERE d.billPaid = 1
      AND d.paidAmount IS NOT NULL
      AND EXISTS
      (
          SELECT 1 FROM #FV_ExpectedElectricBills expectedBill
          WHERE expectedBill.SourceBillsID = TRY_CONVERT(BIGINT, b.BillsID)
      )

      AND
      (
          @GeneralNo IS NULL
          OR TRY_CONVERT(BIGINT, b.generalNo_FK) = @GeneralNo
      );


    ------------------------------------------------------------
    -- Missing electricity settlement list
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , N'PAYMENTS'
        , N'MISSING_ELECTRIC_SETTLEMENT_LIST'

        , N'KFMC.Housing.BillDeductList'
        , N'DATACORE.Housing.DeductList'

        , CONVERT
          (
              NVARCHAR(100),
              e.SourcePaymentDetailID
          )

        , N'deductListID_FK'

        , N'<EXPECTED_SETTLEMENT_LIST>'
        , NULL

        , 'ERROR'

        , N'تفصيل سداد كهرباء مدفوع لا يملك مسير تسوية افتتاحية مطابقاً في DATACORE.'

    FROM #FV_ExpectedElectricPayments e

    WHERE e.ExpectedDeductListID IS NULL;


    ------------------------------------------------------------
    -- Electricity payment must exist exactly once by PaymentUID
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , N'PAYMENTS'

        , CASE
              WHEN x.MatchCount = 0
                  THEN N'MISSING_ELECTRIC_PAYMENT'
              ELSE N'DUPLICATE_ELECTRIC_PAYMENT'
          END

        , N'KFMC.Housing.BillsDeductListDetails'
        , N'DATACORE.Housing.BuildingPayment'

        , CONVERT
          (
              NVARCHAR(100),
              e.SourcePaymentDetailID
          )

        , N'PaymentUID'

        , N'1'

        , CONVERT
          (
              NVARCHAR(100),
              x.MatchCount
          )

        , 'ERROR'

        , N'كل تفصيل كهرباء مدفوع ومختار للترحيل يجب أن ينتج BuildingPayment واحداً فقط.'

    FROM #FV_ExpectedElectricPayments e

    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.BuildingPayment t
        WHERE t.PaymentUID = e.ExpectedPaymentUID
          AND t.BillChargeTypeID_FK = 2
    ) x

    WHERE x.MatchCount <> 1;


    ------------------------------------------------------------
    -- Electricity payment field comparison
    -- Resident/building/status are checked in Payment Links.
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , CASE
              WHEN v.FieldName = N'buildingPaymentTypeID_FK'
                  THEN N'PAYMENT_TYPES'
              ELSE N'PAYMENTS'
          END

        , CASE
              WHEN v.FieldName = N'buildingPaymentTypeID_FK'
                  THEN N'ELECTRIC_PAYMENT_TYPE_MISMATCH'
              ELSE N'ELECTRIC_PAYMENT_VALUE_MISMATCH'
          END

        , N'KFMC.Housing.BillsDeductListDetails / BillDeductList'
        , N'DATACORE.Housing.BuildingPayment'

        , CONVERT
          (
              NVARCHAR(100),
              e.SourcePaymentDetailID
          )

        , v.FieldName
        , v.ExpectedValue
        , v.ActualValue

        , 'ERROR'

        , N'سداد الكهرباء موجود ولكن إحدى القيم المالية الأساسية لا تطابق المصدر.'

    FROM #FV_ExpectedElectricPayments e

    JOIN Housing.BuildingPayment t
        ON t.PaymentUID = e.ExpectedPaymentUID
       AND t.BillChargeTypeID_FK = 2

    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.BuildingPayment x
        WHERE x.PaymentUID = e.ExpectedPaymentUID
          AND x.BillChargeTypeID_FK = 2
    ) paymentCount

    CROSS APPLY
    (
        VALUES
        (
            N'buildingPaymentTypeID_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedPaymentTypeID),
            CONVERT(NVARCHAR(MAX), t.buildingPaymentTypeID_FK)
        ),
        (
            N'generalNo_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedGeneralNo),
            CONVERT(NVARCHAR(MAX), t.generalNo_FK)
        ),
        (
            N'amount',
            CONVERT(NVARCHAR(MAX), e.ExpectedAmount),
            CONVERT(NVARCHAR(MAX), t.amount)
        ),
        (
            N'deductListID_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedDeductListID),
            CONVERT(NVARCHAR(MAX), t.deductListID_FK)
        ),
        (
            N'buildingPayementActive',
            CONVERT(NVARCHAR(MAX), e.ExpectedActive),
            CONVERT(NVARCHAR(MAX), t.buildingPayementActive)
        ),
        (
            N'BillChargeTypeID_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedChargeTypeID),
            CONVERT(NVARCHAR(MAX), t.BillChargeTypeID_FK)
        ),
        (
            N'IdaraId_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedIdaraID),
            CONVERT(NVARCHAR(MAX), t.IdaraId_FK)
        )
    ) v
    (
          FieldName
        , ExpectedValue
        , ActualValue
    )

    WHERE paymentCount.MatchCount = 1

      AND
      (
             (
                 v.ExpectedValue COLLATE DATABASE_DEFAULT
                 <>
                 v.ActualValue COLLATE DATABASE_DEFAULT
             )

          OR (
                 v.ExpectedValue IS NULL
                 AND v.ActualValue IS NOT NULL
             )

          OR (
                 v.ExpectedValue IS NOT NULL
                 AND v.ActualValue IS NULL
             )
      );


    ------------------------------------------------------------
    -- Unexpected target Electricity payment
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          COALESCE
          (
              e.EntityKey,
              CASE
                  WHEN t.generalNo_FK IS NOT NULL
                      THEN CONCAT(N'G:', t.generalNo_FK)
                  ELSE CONCAT(N'ELECTRIC_PAYMENT:', t.paymentID)
              END
          )

        , t.generalNo_FK
        , e.SourceResidentInfoID
        , e.SourceResidentDetailsID
        , e.FullName

        , N'PAYMENTS'
        , N'UNEXPECTED_TARGET_ELECTRIC_PAYMENT'

        , N'KFMC.Housing.BillsDeductListDetails'
        , N'DATACORE.Housing.BuildingPayment'

        , CONVERT(NVARCHAR(100), t.PaymentUID)

        , N'PaymentUID'

        , NULL
        , CONVERT(NVARCHAR(100), t.PaymentUID)

        , 'ERROR'

        , N'يوجد سداد كهرباء في DATACORE لا يقابله تفصيل كهرباء مدفوع متوقع ضمن نطاق التحقق.'

    FROM Housing.BuildingPayment t

    LEFT JOIN #ExpectedResidents e
        ON e.SourceResidentInfoID = t.residentInfoID_FK

    WHERE t.BillChargeTypeID_FK = 2
      AND t.IdaraId_FK = @IdaraId

      AND
      (
          @GeneralNo IS NULL
          OR t.generalNo_FK = @GeneralNo
          OR EXISTS
             (
                 SELECT 1
                 FROM #ExpectedResidents scopeResident
                 WHERE scopeResident.SourceResidentInfoID =
                       t.residentInfoID_FK
             )
      )

      AND NOT EXISTS
      (
          SELECT 1
          FROM #FV_ExpectedElectricPayments expectedPayment
          WHERE expectedPayment.ExpectedPaymentUID =
                t.PaymentUID
      );


    ------------------------------------------------------------
    -- 15C. Penalty Payments
    ------------------------------------------------------------

    SELECT
          COALESCE
          (
              e.EntityKey,
              CASE
                  WHEN TRY_CONVERT(BIGINT, sourceAction.generalNo_FK)
                       IS NOT NULL
                      THEN CONCAT
                           (
                               N'G:',
                               TRY_CONVERT
                               (
                                   BIGINT,
                                   sourceAction.generalNo_FK
                               )
                           )
                  ELSE CONCAT
                       (
                           N'PENALTY_PAYMENT:',
                           c.occupantCustodyActionID
                       )
              END
          ) AS EntityKey

        , TRY_CONVERT
          (
              BIGINT,
              sourceAction.generalNo_FK
          ) AS GeneralNo

        , e.SourceResidentInfoID
            AS ResidentInfoID

        , e.SourceResidentDetailsID
            AS ResidentDetailsID

        , e.FullName

        , c.occupantCustodyActionID
            AS SourcePenaltyID

        , CONVERT
          (
              UNIQUEIDENTIFIER,
              HASHBYTES
              (
                  'MD5',
                  CONCAT
                  (
                      N'PENALTY-PAYMENT|',
                      c.occupantCustodyActionID
                  )
              )
          ) AS ExpectedPaymentUID

        , c.PaidPaymentType
            AS ExpectedPaymentTypeID

        , TRY_CONVERT(bigint,sourceAction.generalNo_FK)
            AS ExpectedGeneralNo

        , migratedPenaltyResident.residentInfoID
            AS ExpectedResidentInfoID

        , CONVERT
          (
              NVARCHAR(400),
              targetAction.buildingDetailsID_FK
          ) AS ExpectedBuildingDetailsID

        , c.occupantCustodyActionPenalty
            AS ExpectedAmount

        , targetList.deductListID
            AS ExpectedDeductListID

        , CONVERT(bit,CASE WHEN migratedPenaltyResident.residentInfoID IS NOT NULL
                                AND ISNULL(c.occupantCustodyActionActive,0)=1
                          THEN 1 ELSE 0 END) AS ExpectedActive

        , CONVERT(int, 5)
            AS ExpectedChargeTypeID

        , CONVERT(int, @IdaraId)
            AS ExpectedIdaraID

        , CONCAT(N'سداد غرامة تاريخية؛ رقم إجراء العهدة ',c.occupantCustodyActionID,
                 CASE WHEN NULLIF(c.PaidNumber,N'') IS NULL
                      THEN N'' ELSE CONCAT(N'; رقم السداد ',c.PaidNumber) END)
            AS ExpectedPaymentLinkNote

    INTO #FV_ExpectedPenaltyPayments

    FROM KFMC.Housing.OccupantCustodyAction c

    LEFT JOIN KFMC.Housing.BuildingAction sourceAction
        ON sourceAction.buildingActionID =
           TRY_CONVERT
           (
               BIGINT,
               c.buildingActionID_FK
           )

    LEFT JOIN Housing.BuildingAction targetAction
        ON targetAction.buildingActionID =
           TRY_CONVERT
           (
               BIGINT,
               c.buildingActionID_FK
           )

    LEFT JOIN #ExpectedResidents e
        ON e.GeneralNo = TRY_CONVERT(BIGINT, sourceAction.generalNo_FK)
    LEFT JOIN #EligibleMigrationResidents sourceEligible
        ON sourceEligible.GeneralNo=TRY_CONVERT(bigint,sourceAction.generalNo_FK)
    LEFT JOIN Housing.ResidentInfo migratedPenaltyResident
        ON migratedPenaltyResident.residentInfoID=sourceEligible.ResidentInfoID
       AND migratedPenaltyResident.residentInfoActive=1
       AND migratedPenaltyResident.residentInfoID=targetAction.residentInfoID_FK

    OUTER APPLY
    (
        SELECT TRY_CONVERT
               (
                   DATETIME2(3),
                   RIGHT(c.PaidBy, 23),
                   121
               ) AS PaidDate
    ) paid

    LEFT JOIN Housing.DeductList targetList
        ON targetList.deductUID =
           CONVERT
           (
               UNIQUEIDENTIFIER,
               HASHBYTES
               (
                   'MD5',
                   CONCAT
                   (
                       N'PENALTY-LIST|',
                       YEAR(paid.PaidDate),
                       N'|',
                       MONTH(paid.PaidDate),
                       N'|',
                       c.PaidPaymentType
                   )
               )
           )

    WHERE c.Paid = 1

      AND
      (
          @GeneralNo IS NULL
          OR TRY_CONVERT
             (
                 BIGINT,
                 sourceAction.generalNo_FK
             ) = @GeneralNo
      );


    ------------------------------------------------------------
    -- Missing penalty settlement list
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , N'PAYMENTS'
        , N'MISSING_PENALTY_SETTLEMENT_LIST'

        , N'KFMC.Housing.OccupantCustodyAction'
        , N'DATACORE.Housing.DeductList'

        , CONVERT
          (
              NVARCHAR(100),
              e.SourcePenaltyID
          )

        , N'deductListID_FK'

        , N'<EXPECTED_SETTLEMENT_LIST>'
        , NULL

        , 'ERROR'

        , N'سداد غرامة مدفوع لا يملك مسير تسوية افتتاحية مطابقاً في DATACORE.'

    FROM #FV_ExpectedPenaltyPayments e

    WHERE e.ExpectedDeductListID IS NULL;


    ------------------------------------------------------------
    -- Penalty payment must exist exactly once by deterministic UID
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , N'PAYMENTS'

        , CASE
              WHEN x.MatchCount = 0
                  THEN N'MISSING_PENALTY_PAYMENT'
              ELSE N'DUPLICATE_PENALTY_PAYMENT'
          END

        , N'KFMC.Housing.OccupantCustodyAction'
        , N'DATACORE.Housing.BuildingPayment'

        , CONVERT
          (
              NVARCHAR(100),
              e.SourcePenaltyID
          )

        , N'PaymentUID'

        , N'1'

        , CONVERT
          (
              NVARCHAR(100),
              x.MatchCount
          )

        , 'ERROR'

        , N'كل غرامة مدفوعة في KFMC يجب أن تنتج BuildingPayment واحداً فقط.'

    FROM #FV_ExpectedPenaltyPayments e

    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.BuildingPayment t
        WHERE t.PaymentUID = e.ExpectedPaymentUID
          AND t.BillChargeTypeID_FK = 5
    ) x

    WHERE x.MatchCount <> 1;


    ------------------------------------------------------------
    -- Penalty payment field comparison
    -- Link fields are validated in the next phase.
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName

        , CASE
              WHEN v.FieldName = N'buildingPaymentTypeID_FK'
                  THEN N'PAYMENT_TYPES'
              ELSE N'PAYMENTS'
          END

        , CASE
              WHEN v.FieldName = N'buildingPaymentTypeID_FK'
                  THEN N'PENALTY_PAYMENT_TYPE_MISMATCH'
              ELSE N'PENALTY_PAYMENT_VALUE_MISMATCH'
          END

        , N'KFMC.Housing.OccupantCustodyAction'
        , N'DATACORE.Housing.BuildingPayment'

        , CONVERT
          (
              NVARCHAR(100),
              e.SourcePenaltyID
          )

        , v.FieldName
        , v.ExpectedValue
        , v.ActualValue

        , 'ERROR'

        , N'سداد الغرامة موجود ولكن إحدى القيم المالية الأساسية لا تطابق المصدر.'

    FROM #FV_ExpectedPenaltyPayments e

    JOIN Housing.BuildingPayment t
        ON t.PaymentUID = e.ExpectedPaymentUID
       AND t.BillChargeTypeID_FK = 5

    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.BuildingPayment x
        WHERE x.PaymentUID = e.ExpectedPaymentUID
          AND x.BillChargeTypeID_FK = 5
    ) paymentCount

    CROSS APPLY
    (
        VALUES
        (
            N'buildingPaymentTypeID_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedPaymentTypeID),
            CONVERT(NVARCHAR(MAX), t.buildingPaymentTypeID_FK)
        ),
        (
            N'generalNo_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedGeneralNo),
            CONVERT(NVARCHAR(MAX), t.generalNo_FK)
        ),
        (
            N'amount',
            CONVERT(NVARCHAR(MAX), e.ExpectedAmount),
            CONVERT(NVARCHAR(MAX), t.amount)
        ),
        (
            N'deductListID_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedDeductListID),
            CONVERT(NVARCHAR(MAX), t.deductListID_FK)
        ),
        (
            N'buildingPayementActive',
            CONVERT(NVARCHAR(MAX), e.ExpectedActive),
            CONVERT(NVARCHAR(MAX), t.buildingPayementActive)
        ),
        (
            N'BillChargeTypeID_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedChargeTypeID),
            CONVERT(NVARCHAR(MAX), t.BillChargeTypeID_FK)
        ),
        (
            N'IdaraId_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedIdaraID),
            CONVERT(NVARCHAR(MAX), t.IdaraId_FK)
        ),
        (
            N'paymentLinkNote',
            CONVERT(NVARCHAR(MAX), e.ExpectedPaymentLinkNote),
            CONVERT(NVARCHAR(MAX), t.paymentLinkNote)
        )
    ) v
    (
          FieldName
        , ExpectedValue
        , ActualValue
    )

    WHERE paymentCount.MatchCount = 1

      AND
      (
             (
                 v.ExpectedValue COLLATE DATABASE_DEFAULT
                 <>
                 v.ActualValue COLLATE DATABASE_DEFAULT
             )

          OR (
                 v.ExpectedValue IS NULL
                 AND v.ActualValue IS NOT NULL
             )

          OR (
                 v.ExpectedValue IS NOT NULL
                 AND v.ActualValue IS NULL
             )
      );


    ------------------------------------------------------------
    -- Unexpected target Penalty payment
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          COALESCE
          (
              e.EntityKey,
              CASE
                  WHEN t.generalNo_FK IS NOT NULL
                      THEN CONCAT(N'G:', t.generalNo_FK)
                  ELSE CONCAT(N'PENALTY_PAYMENT:', t.paymentID)
              END
          )

        , t.generalNo_FK
        , e.SourceResidentInfoID
        , e.SourceResidentDetailsID
        , e.FullName

        , N'PAYMENTS'
        , N'UNEXPECTED_TARGET_PENALTY_PAYMENT'

        , N'KFMC.Housing.OccupantCustodyAction'
        , N'DATACORE.Housing.BuildingPayment'

        , CONVERT(NVARCHAR(100), t.PaymentUID)

        , N'PaymentUID'

        , NULL
        , CONVERT(NVARCHAR(100), t.PaymentUID)

        , 'ERROR'

        , N'يوجد سداد غرامة في DATACORE لا يقابله سداد غرامة متوقع ضمن نطاق التحقق.'

    FROM Housing.BuildingPayment t

    LEFT JOIN #ExpectedResidents e
        ON e.SourceResidentInfoID = t.residentInfoID_FK

    WHERE t.BillChargeTypeID_FK = 5
      AND t.IdaraId_FK = @IdaraId

      AND
      (
          @GeneralNo IS NULL
          OR t.generalNo_FK = @GeneralNo
          OR EXISTS
             (
                 SELECT 1
                 FROM #ExpectedResidents scopeResident
                 WHERE scopeResident.SourceResidentInfoID =
                       t.residentInfoID_FK
             )
      )

      AND NOT EXISTS
      (
          SELECT 1
          FROM #FV_ExpectedPenaltyPayments expectedPayment
          WHERE expectedPayment.ExpectedPaymentUID =
                t.PaymentUID
      );


    ------------------------------------------------------------
    -- 16. PAYMENT LINKS / PAYMENT LINK STATUS
    --
    -- 16A Historical Rent payment classification
    -- 16B Electricity payment resident/building/status
    -- 16C Penalty payment resident/building/status
    --
    -- Authoritative accounting/link policy:
    --   Status 1 = linked resident + building
    --   Status 2 = resident credit without building
    --   Status 3 = unresolved resident
    --   Status 4 = payment period entirely before first known occupancy
    --
    -- Hijri rent periods are converted with dbo._GregorianHijriDate.
    -- A Hijri-period payment is never automatically allocated to a
    -- building. If the period is not entirely before first occupancy,
    -- it remains Status 2 for a known resident.
    ------------------------------------------------------------


    ------------------------------------------------------------
    -- 16A. Historical Rent payment link classification
    ------------------------------------------------------------

    CREATE TABLE #FV_HijriPeriodMap
    (
          issueYear  INT NOT NULL
        , issueMonth INT NOT NULL
        , PeriodFrom DATE NOT NULL
        , PeriodTo   DATE NOT NULL
        , PRIMARY KEY (issueYear, issueMonth)
    );

    INSERT INTO #FV_HijriPeriodMap
    (
          issueYear
        , issueMonth
        , PeriodFrom
        , PeriodTo
    )
    SELECT
          g.yearH
        , g.monthH
        , MIN(CONVERT(date, g.gregorianDate))
        , MAX(CONVERT(date, g.gregorianDate))
    FROM dbo._GregorianHijriDate g
    WHERE g.yearH BETWEEN 1300 AND 1600
      AND g.monthH BETWEEN 1 AND 12
    GROUP BY
          g.yearH
        , g.monthH;


    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName
        , e.ExpectedPaymentID AS PaymentID
        , e.ExpectedActive
        , e.ResidentInfoID AS ExpectedResidentInfoID

        , CASE
              WHEN sourceList.issueYear BETWEEN 1300 AND 1600
               AND sourceList.issueMonth BETWEEN 1 AND 12
                  THEN hijri.PeriodFrom

              WHEN sourceList.issueYear BETWEEN 1900 AND 9999
               AND sourceList.issueMonth BETWEEN 1 AND 12
                  THEN TRY_CONVERT
                       (
                           date,
                           CONCAT
                           (
                               sourceList.issueYear,
                               N'-',
                               RIGHT
                               (
                                   N'0' + CONVERT
                                   (
                                       NVARCHAR(2),
                                       sourceList.issueMonth
                                   ),
                                   2
                               ),
                               N'-01'
                           )
                       )

              ELSE CONVERT(date, sourceList.paymentDate)
          END AS EffectivePaymentDate

        , CASE
              WHEN sourceList.issueYear BETWEEN 1300 AND 1600
               AND sourceList.issueMonth BETWEEN 1 AND 12
                  THEN hijri.PeriodTo

              WHEN sourceList.issueYear BETWEEN 1900 AND 9999
               AND sourceList.issueMonth BETWEEN 1 AND 12
                  THEN EOMONTH
                       (
                           TRY_CONVERT
                           (
                               date,
                               CONCAT
                               (
                                   sourceList.issueYear,
                                   N'-',
                                   RIGHT
                                   (
                                       N'0' + CONVERT
                                       (
                                           NVARCHAR(2),
                                           sourceList.issueMonth
                                       ),
                                       2
                                   ),
                                   N'-01'
                               )
                           )
                       )

              ELSE CONVERT(date, sourceList.paymentDate)
          END AS EffectivePaymentEndDate

        , CASE
              WHEN sourceList.issueYear BETWEEN 1300 AND 1600
               AND sourceList.issueMonth BETWEEN 1 AND 12
                  THEN CONVERT(bit, 1)
              ELSE CONVERT(bit, 0)
          END AS IsHijriPeriod

    INTO #FV_RentLinkPaymentBase

    FROM #FV_ExpectedRentPayments e

    JOIN KFMC.Housing.DeductList sourceList
        ON sourceList.deductListID = e.ExpectedDeductListID

    LEFT JOIN #FV_HijriPeriodMap hijri
        ON hijri.issueYear = sourceList.issueYear
       AND hijri.issueMonth = sourceList.issueMonth;


    CREATE INDEX IX_FV_RentLinkPaymentBase_ResidentDates
        ON #FV_RentLinkPaymentBase
           (
               ExpectedResidentInfoID,
               EffectivePaymentDate,
               EffectivePaymentEndDate
           )
        INCLUDE
           (
               PaymentID,
               ExpectedActive,
               IsHijriPeriod
           );


    CREATE TABLE #FV_LinkOccupancyRoots
    (
          RootActionID      BIGINT NOT NULL PRIMARY KEY
        , ResidentInfoID    BIGINT NOT NULL
        , BuildingDetailsID BIGINT NOT NULL
        , OccupancyDate     DATE NOT NULL
    );

    INSERT INTO #FV_LinkOccupancyRoots
    (
          RootActionID
        , ResidentInfoID
        , BuildingDetailsID
        , OccupancyDate
    )
    SELECT
          actionRow.buildingActionID
        , actionRow.residentInfoID_FK
        , TRY_CONVERT(BIGINT, actionRow.buildingDetailsID_FK)
        , CONVERT(date, actionRow.buildingActionDate)
    FROM Housing.BuildingAction actionRow
    WHERE actionRow.buildingActionTypeID_FK = 2
      AND actionRow.buildingActionActive = 1
      AND actionRow.residentInfoID_FK IS NOT NULL
      AND TRY_CONVERT(BIGINT, actionRow.buildingDetailsID_FK) IS NOT NULL
      AND actionRow.buildingActionDate IS NOT NULL
      AND EXISTS
      (
          SELECT 1
          FROM #FV_RentLinkPaymentBase paymentBase
          WHERE paymentBase.ExpectedResidentInfoID =
                actionRow.residentInfoID_FK
      );


    CREATE TABLE #FV_LinkActionTree
    (
          RootActionID         BIGINT NOT NULL
        , BuildingActionID     BIGINT NOT NULL
        , BuildingActionTypeID INT NULL
        , BuildingActionDate   DATETIME NULL
        , TreeLevel            INT NOT NULL
    );

    ;WITH ActionTree AS
    (
        SELECT
              rootRow.RootActionID
            , actionRow.buildingActionID
            , actionRow.buildingActionTypeID_FK
            , actionRow.buildingActionDate
            , 0 AS TreeLevel
        FROM #FV_LinkOccupancyRoots rootRow
        JOIN Housing.BuildingAction actionRow
            ON actionRow.buildingActionID = rootRow.RootActionID

        UNION ALL

        SELECT
              treeRow.RootActionID
            , childAction.buildingActionID
            , childAction.buildingActionTypeID_FK
            , childAction.buildingActionDate
            , treeRow.TreeLevel + 1
        FROM ActionTree treeRow
        JOIN Housing.BuildingAction childAction
            ON childAction.buildingActionParentID =
               treeRow.BuildingActionID
           AND childAction.buildingActionActive = 1
        WHERE treeRow.TreeLevel < 100
    )
    INSERT INTO #FV_LinkActionTree
    (
          RootActionID
        , BuildingActionID
        , BuildingActionTypeID
        , BuildingActionDate
        , TreeLevel
    )
    SELECT
          RootActionID
        , BuildingActionID
        , BuildingActionTypeID_FK
        , BuildingActionDate
        , TreeLevel
    FROM ActionTree
    OPTION (MAXRECURSION 0);


    CREATE INDEX IX_FV_LinkActionTree_RootType
        ON #FV_LinkActionTree
           (
               RootActionID,
               BuildingActionTypeID
           )
        INCLUDE (BuildingActionDate);


    CREATE TABLE #FV_LinkOccupancyPeriods
    (
          ResidentInfoID    BIGINT NOT NULL
        , BuildingDetailsID BIGINT NOT NULL
        , OccupancyDate     DATE NOT NULL
        , ExitDate          DATE NULL
        , RootActionID      BIGINT NOT NULL PRIMARY KEY
    );

    INSERT INTO #FV_LinkOccupancyPeriods
    (
          ResidentInfoID
        , BuildingDetailsID
        , OccupancyDate
        , ExitDate
        , RootActionID
    )
    SELECT
          rootRow.ResidentInfoID
        , rootRow.BuildingDetailsID
        , rootRow.OccupancyDate
        , MIN
          (
              CASE
                  WHEN treeRow.BuildingActionTypeID = 3
                      THEN CONVERT(date, treeRow.BuildingActionDate)
              END
          ) AS ExitDate
        , rootRow.RootActionID
    FROM #FV_LinkOccupancyRoots rootRow
    LEFT JOIN #FV_LinkActionTree treeRow
        ON treeRow.RootActionID = rootRow.RootActionID
    GROUP BY
          rootRow.ResidentInfoID
        , rootRow.BuildingDetailsID
        , rootRow.OccupancyDate
        , rootRow.RootActionID;


    CREATE INDEX IX_FV_LinkOccupancyPeriods_ResidentDates
        ON #FV_LinkOccupancyPeriods
           (
               ResidentInfoID,
               OccupancyDate,
               ExitDate
           )
        INCLUDE (BuildingDetailsID);


    CREATE TABLE #FV_LinkCandidateBuildings
    (
          PaymentID         BIGINT NOT NULL
        , BuildingDetailsID BIGINT NOT NULL
        , PRIMARY KEY (PaymentID, BuildingDetailsID)
    );

    INSERT INTO #FV_LinkCandidateBuildings
    (
          PaymentID
        , BuildingDetailsID
    )
    SELECT DISTINCT
          paymentBase.PaymentID
        , occupancy.BuildingDetailsID
    FROM #FV_RentLinkPaymentBase paymentBase
    JOIN #FV_LinkOccupancyPeriods occupancy
        ON occupancy.ResidentInfoID =
           paymentBase.ExpectedResidentInfoID
       AND paymentBase.ExpectedActive = 1
       AND paymentBase.IsHijriPeriod = 0
       AND paymentBase.EffectivePaymentEndDate >=
           occupancy.OccupancyDate
       AND paymentBase.EffectivePaymentDate <=
           ISNULL
           (
               occupancy.ExitDate,
               CONVERT(date, GETDATE())
           );


    CREATE TABLE #FV_LinkCandidateSummary
    (
          PaymentID                  BIGINT NOT NULL PRIMARY KEY
        , CandidateCount             INT NOT NULL
        , ProposedBuildingDetailsID  BIGINT NULL
    );

    INSERT INTO #FV_LinkCandidateSummary
    (
          PaymentID
        , CandidateCount
        , ProposedBuildingDetailsID
    )
    SELECT
          PaymentID
        , COUNT(*)
        , MIN(BuildingDetailsID)
    FROM #FV_LinkCandidateBuildings
    GROUP BY PaymentID;


    CREATE TABLE #FV_LinkFirstOccupancy
    (
          ResidentInfoID      BIGINT NOT NULL PRIMARY KEY
        , FirstOccupancyDate  DATE NOT NULL
    );

    INSERT INTO #FV_LinkFirstOccupancy
    (
          ResidentInfoID
        , FirstOccupancyDate
    )
    SELECT
          ResidentInfoID
        , MIN(OccupancyDate)
    FROM #FV_LinkOccupancyPeriods
    GROUP BY ResidentInfoID;


    SELECT
          paymentBase.EntityKey
        , paymentBase.GeneralNo
        , paymentBase.ResidentInfoID
        , paymentBase.ResidentDetailsID
        , paymentBase.FullName
        , paymentBase.PaymentID
        , paymentBase.ExpectedResidentInfoID
        , paymentBase.EffectivePaymentDate
        , paymentBase.EffectivePaymentEndDate
        , paymentBase.IsHijriPeriod
        , firstOccupancy.FirstOccupancyDate
        , ISNULL(candidateSummary.CandidateCount, 0)
            AS CandidateBuildingCount

        , CASE
              WHEN paymentBase.ExpectedActive = 0
                  THEN NULL

              WHEN paymentBase.IsHijriPeriod = 0
               AND candidateSummary.CandidateCount = 1
                  THEN candidateSummary.ProposedBuildingDetailsID

              ELSE NULL
          END AS ExpectedBuildingDetailsID

        , CASE
              WHEN paymentBase.ExpectedActive = 0
               AND paymentBase.ExpectedResidentInfoID IS NULL
                  THEN 3

              WHEN paymentBase.ExpectedActive = 0
                  THEN 2

              WHEN paymentBase.ExpectedResidentInfoID IS NULL
                  THEN 3

              WHEN paymentBase.IsHijriPeriod = 1
               AND paymentBase.EffectivePaymentEndDate IS NOT NULL
               AND firstOccupancy.FirstOccupancyDate IS NOT NULL
               AND paymentBase.EffectivePaymentEndDate <
                   firstOccupancy.FirstOccupancyDate
                  THEN 4

              WHEN paymentBase.IsHijriPeriod = 1
                  THEN 2

              WHEN paymentBase.EffectivePaymentEndDate IS NOT NULL
               AND firstOccupancy.FirstOccupancyDate IS NOT NULL
               AND paymentBase.EffectivePaymentEndDate <
                   firstOccupancy.FirstOccupancyDate
                  THEN 4

              WHEN candidateSummary.CandidateCount = 1
                  THEN 1

              ELSE 2
          END AS ExpectedStatusID

    INTO #FV_ExpectedRentPaymentLinks

    FROM #FV_RentLinkPaymentBase paymentBase

    LEFT JOIN #FV_LinkFirstOccupancy firstOccupancy
        ON firstOccupancy.ResidentInfoID =
           paymentBase.ExpectedResidentInfoID

    LEFT JOIN #FV_LinkCandidateSummary candidateSummary
        ON candidateSummary.PaymentID =
           paymentBase.PaymentID;


    ------------------------------------------------------------
    -- Rent resident / building link comparison
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName
        , N'PAYMENT_LINKS'
        , N'RENT_PAYMENT_LINK_MISMATCH'
        , N'KFMC.Housing.BuildingPayment / DeductList + DATACORE occupancy'
        , N'DATACORE.Housing.BuildingPayment'
        , CONVERT(NVARCHAR(100), e.PaymentID)
        , v.FieldName
        , v.ExpectedValue
        , v.ActualValue
        , 'ERROR'
        , N'ربط سداد الإيجار بالمستفيد أو المبنى لا يطابق سياسة التصنيف المعتمدة.'
    FROM #FV_ExpectedRentPaymentLinks e
    JOIN Housing.BuildingPayment t
        ON t.paymentID = e.PaymentID
       AND t.BillChargeTypeID_FK = 1
    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.BuildingPayment x
        WHERE x.paymentID = e.PaymentID
          AND x.BillChargeTypeID_FK = 1
    ) paymentCount
    CROSS APPLY
    (
        VALUES
        (
            N'residentInfoID_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedResidentInfoID),
            CONVERT(NVARCHAR(MAX), t.residentInfoID_FK)
        ),
        (
            N'buildingDetailsID_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedBuildingDetailsID),
            NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(MAX), t.buildingDetailsID_FK))), N'')
        )
    ) v(FieldName, ExpectedValue, ActualValue)
    WHERE paymentCount.MatchCount = 1
      AND
      (
             v.ExpectedValue COLLATE DATABASE_DEFAULT <>
             v.ActualValue COLLATE DATABASE_DEFAULT

          OR (v.ExpectedValue IS NULL AND v.ActualValue IS NOT NULL)
          OR (v.ExpectedValue IS NOT NULL AND v.ActualValue IS NULL)
      );


    ------------------------------------------------------------
    -- Rent payment link-status comparison
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName
        , N'PAYMENT_LINK_STATUS'
        , N'RENT_PAYMENT_LINK_STATUS_MISMATCH'
        , N'Approved temporal / Hijri payment classification policy'
        , N'DATACORE.Housing.BuildingPayment'
        , CONVERT(NVARCHAR(100), e.PaymentID)
        , N'buildingPaymentLinkStatusID_FK'
        , CONVERT(NVARCHAR(MAX), e.ExpectedStatusID)
        , CONVERT(NVARCHAR(MAX), t.buildingPaymentLinkStatusID_FK)
        , 'ERROR'
        , N'حالة ربط سداد الإيجار لا تطابق السياسة الزمنية المعتمدة.'
    FROM #FV_ExpectedRentPaymentLinks e
    JOIN Housing.BuildingPayment t
        ON t.paymentID = e.PaymentID
       AND t.BillChargeTypeID_FK = 1
    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.BuildingPayment x
        WHERE x.paymentID = e.PaymentID
          AND x.BillChargeTypeID_FK = 1
    ) paymentCount
    WHERE paymentCount.MatchCount = 1
      AND ISNULL(t.buildingPaymentLinkStatusID_FK, -1) <>
          e.ExpectedStatusID;


    ------------------------------------------------------------
    -- 16B. Electricity payment links/status
    --
    -- Electricity preserves the source bill building even when
    -- the resident is unresolved. Therefore Status 3 with a
    -- building is valid for this migrated payment class.
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName
        , N'PAYMENT_LINKS'
        , N'ELECTRIC_PAYMENT_LINK_MISMATCH'
        , N'KFMC.Housing.Bills / BillsDeductListDetails'
        , N'DATACORE.Housing.BuildingPayment'
        , CONVERT(NVARCHAR(100), e.SourcePaymentDetailID)
        , v.FieldName
        , v.ExpectedValue
        , v.ActualValue
        , 'ERROR'
        , N'ربط سداد الكهرباء بالمستفيد أو المبنى لا يطابق السداد التاريخي المصدر.'
    FROM #FV_ExpectedElectricPayments e
    JOIN Housing.BuildingPayment t
        ON t.PaymentUID = e.ExpectedPaymentUID
       AND t.BillChargeTypeID_FK = 2
    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.BuildingPayment x
        WHERE x.PaymentUID = e.ExpectedPaymentUID
          AND x.BillChargeTypeID_FK = 2
    ) paymentCount
    CROSS APPLY
    (
        VALUES
        (
            N'residentInfoID_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedResidentInfoID),
            CONVERT(NVARCHAR(MAX), t.residentInfoID_FK)
        ),
        (
            N'buildingDetailsID_FK',
            NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(MAX), e.ExpectedBuildingDetailsID))), N''),
            NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(MAX), t.buildingDetailsID_FK))), N'')
        )
    ) v(FieldName, ExpectedValue, ActualValue)
    WHERE paymentCount.MatchCount = 1
      AND
      (
             v.ExpectedValue COLLATE DATABASE_DEFAULT <>
             v.ActualValue COLLATE DATABASE_DEFAULT

          OR (v.ExpectedValue IS NULL AND v.ActualValue IS NOT NULL)
          OR (v.ExpectedValue IS NOT NULL AND v.ActualValue IS NULL)
      );


    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName
        , N'PAYMENT_LINK_STATUS'
        , N'ELECTRIC_PAYMENT_LINK_STATUS_MISMATCH'
        , N'KFMC.Housing.Bills / eligible resident mapping'
        , N'DATACORE.Housing.BuildingPayment'
        , CONVERT(NVARCHAR(100), e.SourcePaymentDetailID)
        , N'buildingPaymentLinkStatusID_FK'
        , CONVERT
          (
              NVARCHAR(MAX),
              CASE
                  WHEN e.ExpectedResidentInfoID IS NULL THEN 3
                  ELSE 1
              END
          )
        , CONVERT(NVARCHAR(MAX), t.buildingPaymentLinkStatusID_FK)
        , 'ERROR'
        , N'حالة ربط سداد الكهرباء يجب أن تكون 1 للمستفيد المؤهل و3 عند تعذر إسناد المستفيد.'
    FROM #FV_ExpectedElectricPayments e
    JOIN Housing.BuildingPayment t
        ON t.PaymentUID = e.ExpectedPaymentUID
       AND t.BillChargeTypeID_FK = 2
    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.BuildingPayment x
        WHERE x.PaymentUID = e.ExpectedPaymentUID
          AND x.BillChargeTypeID_FK = 2
    ) paymentCount
    WHERE paymentCount.MatchCount = 1
      AND ISNULL(t.buildingPaymentLinkStatusID_FK, -1) <>
          CASE
              WHEN e.ExpectedResidentInfoID IS NULL THEN 3
              ELSE 1
          END;


    ------------------------------------------------------------
    -- 16C. Penalty payment links/status
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName
        , N'PAYMENT_LINKS'
        , N'PENALTY_PAYMENT_LINK_MISMATCH'
        , N'KFMC.Housing.OccupantCustodyAction / migrated BuildingAction'
        , N'DATACORE.Housing.BuildingPayment'
        , CONVERT(NVARCHAR(100), e.SourcePenaltyID)
        , v.FieldName
        , v.ExpectedValue
        , v.ActualValue
        , 'ERROR'
        , N'ربط سداد الغرامة بالمستفيد أو المبنى لا يطابق الإجراء المصدر.'
    FROM #FV_ExpectedPenaltyPayments e
    JOIN Housing.BuildingPayment t
        ON t.PaymentUID = e.ExpectedPaymentUID
       AND t.BillChargeTypeID_FK = 5
    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.BuildingPayment x
        WHERE x.PaymentUID = e.ExpectedPaymentUID
          AND x.BillChargeTypeID_FK = 5
    ) paymentCount
    CROSS APPLY
    (
        VALUES
        (
            N'residentInfoID_FK',
            CONVERT(NVARCHAR(MAX), e.ExpectedResidentInfoID),
            CONVERT(NVARCHAR(MAX), t.residentInfoID_FK)
        ),
        (
            N'buildingDetailsID_FK',
            NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(MAX), e.ExpectedBuildingDetailsID))), N''),
            NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(MAX), t.buildingDetailsID_FK))), N'')
        )
    ) v(FieldName, ExpectedValue, ActualValue)
    WHERE paymentCount.MatchCount = 1
      AND
      (
             v.ExpectedValue COLLATE DATABASE_DEFAULT <>
             v.ActualValue COLLATE DATABASE_DEFAULT

          OR (v.ExpectedValue IS NULL AND v.ActualValue IS NOT NULL)
          OR (v.ExpectedValue IS NOT NULL AND v.ActualValue IS NULL)
      );


    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName
        , N'PAYMENT_LINK_STATUS'
        , N'PENALTY_PAYMENT_LINK_STATUS_MISMATCH'
        , N'KFMC.Housing.OccupantCustodyAction / migrated BuildingAction'
        , N'DATACORE.Housing.BuildingPayment'
        , CONVERT(NVARCHAR(100), e.SourcePenaltyID)
        , N'buildingPaymentLinkStatusID_FK'
        , N'1'
        , CONVERT(NVARCHAR(MAX), t.buildingPaymentLinkStatusID_FK)
        , 'ERROR'
        , N'سداد الغرامة المرتبط بإجراء ومستفيد ومبنى يجب أن يكون في حالة الربط 1.'
    FROM #FV_ExpectedPenaltyPayments e
    JOIN Housing.BuildingPayment t
        ON t.PaymentUID = e.ExpectedPaymentUID
       AND t.BillChargeTypeID_FK = 5
    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS MatchCount
        FROM Housing.BuildingPayment x
        WHERE x.PaymentUID = e.ExpectedPaymentUID
          AND x.BillChargeTypeID_FK = 5
    ) paymentCount
    WHERE paymentCount.MatchCount = 1
      AND ISNULL(t.buildingPaymentLinkStatusID_FK, -1) <> 1;


    ------------------------------------------------------------
    -- 17. FINANCIAL RECONCILIATION
    --
    -- Authoritative accounting scope:
    --   Claims:
    --     Housing.Bills
    --     BillActive = 1
    --     residentInfoID_FK IS NOT NULL
    --     TotalPrice > 0
    --     idaraID_FK = @IdaraId
    --
    --   Eligible payments:
    --     Housing.BuildingPayment + Housing.DeductList
    --     payment active = 1
    --     deduct active = 1
    --     Link Status IN (1,2)
    --     residentInfoID_FK IS NOT NULL
    --     IdaraId_FK = @IdaraId
    --
    -- Expected financial claims are derived from the already
    -- validated migration expectations. Expected eligible payments
    -- are derived from the already validated source-payment rows and
    -- the approved link-status rules, including the Hijri policy.
    ------------------------------------------------------------


    ------------------------------------------------------------
    -- 17.1 Expected financial claims
    ------------------------------------------------------------

    CREATE TABLE #FV_ExpectedFinancialClaims
    (
          EntityKey         NVARCHAR(100)  NOT NULL
        , GeneralNo         BIGINT         NULL
        , ResidentInfoID    BIGINT         NOT NULL
        , ResidentDetailsID BIGINT         NULL
        , FullName          NVARCHAR(1000) NULL
        , ChargeTypeID      INT            NOT NULL
        , Amount            DECIMAL(38,4)  NOT NULL
    );


    INSERT INTO #FV_ExpectedFinancialClaims
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , ChargeTypeID
        , Amount
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName
        , 2
        , CONVERT(DECIMAL(38,4), e.TotalPrice)
    FROM #FV_ExpectedElectricBills e
    WHERE e.BillActive = 1
      AND e.TotalPrice > 0
      AND e.ResidentInfoID IS NOT NULL;


    INSERT INTO #FV_ExpectedFinancialClaims
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , ChargeTypeID
        , Amount
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName
        , e.ChargeTypeID
        , CONVERT(DECIMAL(38,4), e.Amount)
    FROM #FV_ExpectedHistoricalResidentBills e
    WHERE e.Amount > 0;


    INSERT INTO #FV_ExpectedFinancialClaims
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , ChargeTypeID
        , Amount
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName
        , 5
        , CONVERT(DECIMAL(38,4), e.ExpectedAmount)
    FROM #FV_ExpectedPenaltyBills e
    WHERE e.ExpectedBillActive = 1
      AND e.ExpectedAmount > 0;


    SELECT
          ResidentInfoID
        , ChargeTypeID
        , COUNT_BIG(*) AS ClaimRows
        , SUM(Amount) AS ClaimAmount
    INTO #FV_ExpectedFinancialClaimAgg
    FROM #FV_ExpectedFinancialClaims
    GROUP BY
          ResidentInfoID
        , ChargeTypeID;


    ------------------------------------------------------------
    -- 17.2 Actual financial claims
    ------------------------------------------------------------

    SELECT
          e.SourceResidentInfoID AS ResidentInfoID
        , b.BillChargeTypeID_FK AS ChargeTypeID
        , COUNT_BIG(*) AS ClaimRows
        , SUM(CONVERT(DECIMAL(38,4), b.TotalPrice)) AS ClaimAmount
    INTO #FV_ActualFinancialClaimAgg
    FROM #ExpectedResidents e
    JOIN Housing.Bills b
        ON b.residentInfoID_FK = e.SourceResidentInfoID
    WHERE b.BillActive = 1
      AND b.residentInfoID_FK IS NOT NULL
      AND b.TotalPrice > 0
      AND b.idaraID_FK = @IdaraId
    GROUP BY
          e.SourceResidentInfoID
        , b.BillChargeTypeID_FK;


    ------------------------------------------------------------
    -- 17.3 Claims reconciliation per resident / charge type
    ------------------------------------------------------------

    ;WITH ClaimKeys AS
    (
        SELECT ResidentInfoID, ChargeTypeID
        FROM #FV_ExpectedFinancialClaimAgg

        UNION

        SELECT ResidentInfoID, ChargeTypeID
        FROM #FV_ActualFinancialClaimAgg
    )
    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.SourceResidentInfoID
        , e.SourceResidentDetailsID
        , e.FullName
        , N'FINANCIAL_RECONCILIATION'
        , N'FINANCIAL_CLAIM_RECONCILIATION_MISMATCH'
        , N'Expected migrated claims under final financial scope'
        , N'DATACORE.Housing.Bills'
        , CONCAT
          (
              N'Resident=', k.ResidentInfoID,
              N';ChargeType=', k.ChargeTypeID
          )
        , N'ClaimRows/ClaimAmount'
        , CONCAT
          (
              N'Rows=', ISNULL(x.ClaimRows, 0),
              N';Amount=', CONVERT(NVARCHAR(100), ISNULL(x.ClaimAmount, 0))
          )
        , CONCAT
          (
              N'Rows=', ISNULL(a.ClaimRows, 0),
              N';Amount=', CONVERT(NVARCHAR(100), ISNULL(a.ClaimAmount, 0))
          )
        , 'ERROR'
        , N'إجمالي المطالبات المالية للمستفيد/نوع الخدمة لا يطابق المطالبات المتوقعة بعد تطبيق نطاق الرصيد المالي النهائي.'
    FROM ClaimKeys k
    JOIN #ExpectedResidents e
        ON e.SourceResidentInfoID = k.ResidentInfoID
    LEFT JOIN #FV_ExpectedFinancialClaimAgg x
        ON x.ResidentInfoID = k.ResidentInfoID
       AND x.ChargeTypeID = k.ChargeTypeID
    LEFT JOIN #FV_ActualFinancialClaimAgg a
        ON a.ResidentInfoID = k.ResidentInfoID
       AND a.ChargeTypeID = k.ChargeTypeID
    WHERE ISNULL(x.ClaimRows, 0) <> ISNULL(a.ClaimRows, 0)
       OR ISNULL(x.ClaimAmount, 0) <> ISNULL(a.ClaimAmount, 0);


    ------------------------------------------------------------
    -- 17.4 Expected financially eligible payments
    ------------------------------------------------------------

    CREATE TABLE #FV_ExpectedFinancialPayments
    (
          EntityKey         NVARCHAR(100)  NOT NULL
        , GeneralNo         BIGINT         NULL
        , ResidentInfoID    BIGINT         NOT NULL
        , ResidentDetailsID BIGINT         NULL
        , FullName          NVARCHAR(1000) NULL
        , ChargeTypeID      INT            NOT NULL
        , Amount            DECIMAL(38,4)  NOT NULL
    );


    -- Rent: active migrated payment and final expected status 1 or 2.
    INSERT INTO #FV_ExpectedFinancialPayments
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , ChargeTypeID
        , Amount
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ResidentInfoID
        , e.ResidentDetailsID
        , e.FullName
        , 1
        , CONVERT(DECIMAL(38,4), p.ExpectedAmount)
    FROM #FV_ExpectedRentPaymentLinks e
    JOIN #FV_ExpectedRentPayments p
        ON p.ExpectedPaymentID = e.PaymentID
    WHERE p.ExpectedActive = 1
      AND e.ExpectedResidentInfoID IS NOT NULL
      AND e.ExpectedStatusID IN (1,2);


    -- Electricity: only a known migrated resident is financially eligible.
    -- The generated settlement list preserves the source BillDeductList
    -- activity, therefore inactive source lists do not enter the balance.
    INSERT INTO #FV_ExpectedFinancialPayments
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , ChargeTypeID
        , Amount
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ExpectedResidentInfoID
        , e.ResidentDetailsID
        , e.FullName
        , 2
        , CONVERT(DECIMAL(38,4), e.ExpectedAmount)
    FROM #FV_ExpectedElectricPayments e
    JOIN KFMC.Housing.BillsDeductListDetails sourceDetail
        ON sourceDetail.billsDeductListDetailsID =
           e.SourcePaymentDetailID
    JOIN KFMC.Housing.BillDeductList sourceList
        ON sourceList.billDeductListID =
           sourceDetail.billDeductListID_FK
    WHERE e.ExpectedActive = 1
      AND e.ExpectedResidentInfoID IS NOT NULL
      AND sourceList.deductActive = 1;


    -- Penalty opening payments are active, resident/building linked,
    -- and their generated settlement lists are active.
    INSERT INTO #FV_ExpectedFinancialPayments
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , ChargeTypeID
        , Amount
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.ExpectedResidentInfoID
        , e.ResidentDetailsID
        , e.FullName
        , 5
        , CONVERT(DECIMAL(38,4), e.ExpectedAmount)
    FROM #FV_ExpectedPenaltyPayments e
    WHERE e.ExpectedActive = 1
      AND e.ExpectedResidentInfoID IS NOT NULL;


    SELECT
          ResidentInfoID
        , ChargeTypeID
        , COUNT_BIG(*) AS PaymentRows
        , SUM(Amount) AS PaymentAmount
    INTO #FV_ExpectedFinancialPaymentAgg
    FROM #FV_ExpectedFinancialPayments
    GROUP BY
          ResidentInfoID
        , ChargeTypeID;


    ------------------------------------------------------------
    -- 17.5 Actual financially eligible payments
    ------------------------------------------------------------

    SELECT
          e.SourceResidentInfoID AS ResidentInfoID
        , p.BillChargeTypeID_FK AS ChargeTypeID
        , COUNT_BIG(*) AS PaymentRows
        , SUM(CONVERT(DECIMAL(38,4), p.amount)) AS PaymentAmount
    INTO #FV_ActualFinancialPaymentAgg
    FROM #ExpectedResidents e
    JOIN Housing.BuildingPayment p
        ON p.residentInfoID_FK = e.SourceResidentInfoID
    JOIN Housing.DeductList d
        ON d.deductListID = p.deductListID_FK
    WHERE d.deductActive = 1
      AND p.buildingPayementActive = 1
      AND p.buildingPaymentLinkStatusID_FK IN (1,2)
      AND p.residentInfoID_FK IS NOT NULL
      AND p.IdaraId_FK = @IdaraId
    GROUP BY
          e.SourceResidentInfoID
        , p.BillChargeTypeID_FK;


    ------------------------------------------------------------
    -- 17.6 Payment reconciliation per resident / charge type
    ------------------------------------------------------------

    ;WITH PaymentKeys AS
    (
        SELECT ResidentInfoID, ChargeTypeID
        FROM #FV_ExpectedFinancialPaymentAgg

        UNION

        SELECT ResidentInfoID, ChargeTypeID
        FROM #FV_ActualFinancialPaymentAgg
    )
    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.SourceResidentInfoID
        , e.SourceResidentDetailsID
        , e.FullName
        , N'FINANCIAL_RECONCILIATION'
        , N'FINANCIAL_PAYMENT_RECONCILIATION_MISMATCH'
        , N'Expected migrated payments + approved final link-status policy'
        , N'DATACORE.Housing.BuildingPayment / DeductList'
        , CONCAT
          (
              N'Resident=', k.ResidentInfoID,
              N';ChargeType=', k.ChargeTypeID
          )
        , N'PaymentRows/PaymentAmount'
        , CONCAT
          (
              N'Rows=', ISNULL(x.PaymentRows, 0),
              N';Amount=', CONVERT(NVARCHAR(100), ISNULL(x.PaymentAmount, 0))
          )
        , CONCAT
          (
              N'Rows=', ISNULL(a.PaymentRows, 0),
              N';Amount=', CONVERT(NVARCHAR(100), ISNULL(a.PaymentAmount, 0))
          )
        , 'ERROR'
        , N'إجمالي السدادات المؤهلة ماليًا للمستفيد/نوع الخدمة لا يطابق السدادات المتوقعة بعد تطبيق حالات الربط 1 و2.'
    FROM PaymentKeys k
    JOIN #ExpectedResidents e
        ON e.SourceResidentInfoID = k.ResidentInfoID
    LEFT JOIN #FV_ExpectedFinancialPaymentAgg x
        ON x.ResidentInfoID = k.ResidentInfoID
       AND x.ChargeTypeID = k.ChargeTypeID
    LEFT JOIN #FV_ActualFinancialPaymentAgg a
        ON a.ResidentInfoID = k.ResidentInfoID
       AND a.ChargeTypeID = k.ChargeTypeID
    WHERE ISNULL(x.PaymentRows, 0) <> ISNULL(a.PaymentRows, 0)
       OR ISNULL(x.PaymentAmount, 0) <> ISNULL(a.PaymentAmount, 0);


    ------------------------------------------------------------
    -- 17.7 Financial population containment
    --      Global only: a scoped resident test must not interpret
    --      other residents as outside the requested scope.
    ------------------------------------------------------------

    IF @GeneralNo IS NULL
    BEGIN
        INSERT INTO #ValidationIssues
        (
              EntityKey
            , GeneralNo
            , ResidentInfoID
            , ResidentDetailsID
            , FullName
            , SectionName
            , IssueCode
            , SourceObject
            , TargetObject
            , ReferenceID
            , FieldName
            , ExpectedValue
            , ActualValue
            , Severity
            , Notes
        )
        SELECT
              CONCAT(N'R:', b.residentInfoID_FK)
            , MAX(TRY_CONVERT(BIGINT, b.generalNo_FK))
            , b.residentInfoID_FK
            , NULL
            , NULL
            , N'FINANCIAL_RECONCILIATION'
            , N'FINANCIAL_CLAIM_OUTSIDE_MIGRATED_POPULATION'
            , N'Expected migrated resident population'
            , N'DATACORE.Housing.Bills'
            , CONVERT(NVARCHAR(100), b.residentInfoID_FK)
            , N'residentInfoID_FK'
            , N'MIGRATED_RESIDENT'
            , N'OUTSIDE_MIGRATED_POPULATION'
            , 'ERROR'
            , N'توجد مطالبة مالية نشطة موجبة مرتبطة بمستفيد خارج مجموعة المستفيدين المؤهلة للترحيل.'
        FROM Housing.Bills b
        WHERE b.BillActive = 1
          AND b.residentInfoID_FK IS NOT NULL
          AND b.TotalPrice > 0
          AND b.idaraID_FK = @IdaraId
          AND NOT EXISTS
              (
                  SELECT 1
                  FROM #ExpectedResidents e
                  WHERE e.SourceResidentInfoID =
                        b.residentInfoID_FK
              )
        GROUP BY b.residentInfoID_FK;


        INSERT INTO #ValidationIssues
        (
              EntityKey
            , GeneralNo
            , ResidentInfoID
            , ResidentDetailsID
            , FullName
            , SectionName
            , IssueCode
            , SourceObject
            , TargetObject
            , ReferenceID
            , FieldName
            , ExpectedValue
            , ActualValue
            , Severity
            , Notes
        )
        SELECT
              CONCAT(N'R:', p.residentInfoID_FK)
            , MAX(TRY_CONVERT(BIGINT, p.generalNo_FK))
            , p.residentInfoID_FK
            , NULL
            , NULL
            , N'FINANCIAL_RECONCILIATION'
            , N'ELIGIBLE_PAYMENT_OUTSIDE_MIGRATED_POPULATION'
            , N'Expected migrated resident population'
            , N'DATACORE.Housing.BuildingPayment / DeductList'
            , CONVERT(NVARCHAR(100), p.residentInfoID_FK)
            , N'residentInfoID_FK'
            , N'MIGRATED_RESIDENT'
            , N'OUTSIDE_MIGRATED_POPULATION'
            , 'ERROR'
            , N'يوجد سداد مؤهل ماليًا بالحالة 1 أو 2 مرتبط بمستفيد خارج مجموعة المستفيدين المؤهلة للترحيل.'
        FROM Housing.BuildingPayment p
        JOIN Housing.DeductList d
            ON d.deductListID = p.deductListID_FK
        WHERE d.deductActive = 1
          AND p.buildingPayementActive = 1
          AND p.buildingPaymentLinkStatusID_FK IN (1,2)
          AND p.residentInfoID_FK IS NOT NULL
          AND p.IdaraId_FK = @IdaraId
          AND NOT EXISTS
              (
                  SELECT 1
                  FROM #ExpectedResidents e
                  WHERE e.SourceResidentInfoID =
                        p.residentInfoID_FK
              )
        GROUP BY p.residentInfoID_FK;
    END;


    ------------------------------------------------------------
    -- 17.8 Link integrity of all financially eligible payments
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          COALESCE
          (
              e.EntityKey,
              CASE
                  WHEN p.generalNo_FK IS NOT NULL
                      THEN CONCAT(N'G:', p.generalNo_FK)
                  ELSE CONCAT(N'PAYMENT:', p.paymentID)
              END
          )
        , p.generalNo_FK
        , p.residentInfoID_FK
        , e.SourceResidentDetailsID
        , e.FullName
        , N'FINANCIAL_RECONCILIATION'
        , N'ELIGIBLE_PAYMENT_LINK_INTEGRITY_MISMATCH'
        , N'Approved financial eligibility policy'
        , N'DATACORE.Housing.BuildingPayment'
        , CONVERT(NVARCHAR(100), p.paymentID)
        , N'LinkStatus/Resident/Building'
        , CASE
              WHEN p.buildingPaymentLinkStatusID_FK = 1
                  THEN N'Status1: Resident + Building required'
              ELSE N'Status2: Resident required, Building must be NULL'
          END
        , CONCAT
          (
              N'Status=', COALESCE(CONVERT(NVARCHAR(20), p.buildingPaymentLinkStatusID_FK), N'<NULL>'),
              N';Resident=', COALESCE(CONVERT(NVARCHAR(100), p.residentInfoID_FK), N'<NULL>'),
              N';Building=', COALESCE(NULLIF(LTRIM(RTRIM(p.buildingDetailsID_FK)), N''), N'<NULL>')
          )
        , 'ERROR'
        , N'هيكل ربط سداد مؤهل ماليًا لا يطابق متطلبات حالتي الربط 1 و2.'
    FROM Housing.BuildingPayment p
    JOIN Housing.DeductList d
        ON d.deductListID = p.deductListID_FK
    LEFT JOIN #ExpectedResidents e
        ON e.SourceResidentInfoID = p.residentInfoID_FK
    WHERE d.deductActive = 1
      AND p.buildingPayementActive = 1
      AND p.IdaraId_FK = @IdaraId
      AND p.buildingPaymentLinkStatusID_FK IN (1,2)
      AND
      (
          @GeneralNo IS NULL
          OR p.generalNo_FK = @GeneralNo
          OR EXISTS
             (
                 SELECT 1
                 FROM #ExpectedResidents scopeResident
                 WHERE scopeResident.SourceResidentInfoID =
                       p.residentInfoID_FK
             )
      )
      AND
      (
             p.residentInfoID_FK IS NULL

          OR (
                 p.buildingPaymentLinkStatusID_FK = 1
                 AND NULLIF
                     (
                         LTRIM(RTRIM(p.buildingDetailsID_FK)),
                         N''
                     ) IS NULL
             )

          OR (
                 p.buildingPaymentLinkStatusID_FK = 2
                 AND NULLIF
                     (
                         LTRIM(RTRIM(p.buildingDetailsID_FK)),
                         N''
                     ) IS NOT NULL
             )
      );


    ------------------------------------------------------------
    -- 17.9 Final financial state per resident
    --
    -- FinalBalance = Claims - Eligible Payments
    --   > 0  = deficit / amount to collect
    --   = 0  = balanced (when movement exists)
    --   < 0  = surplus / refundable credit
    --
    -- A non-zero balance is NOT a validation failure.
    ------------------------------------------------------------

    ;WITH ClaimTotals AS
    (
        SELECT
              ResidentInfoID
            , SUM(ClaimRows) AS ClaimRows
            , SUM(ClaimAmount) AS ClaimAmount
        FROM #FV_ActualFinancialClaimAgg
        GROUP BY ResidentInfoID
    ),
    PaymentTotals AS
    (
        SELECT
              ResidentInfoID
            , SUM(PaymentRows) AS PaymentRows
            , SUM(PaymentAmount) AS PaymentAmount
        FROM #FV_ActualFinancialPaymentAgg
        GROUP BY ResidentInfoID
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.SourceResidentInfoID AS ResidentInfoID
        , e.SourceResidentDetailsID AS ResidentDetailsID
        , e.FullName

        , ISNULL(c.ClaimRows, 0) AS ClaimRows
        , CONVERT
          (
              DECIMAL(38,4),
              ISNULL(c.ClaimAmount, 0)
          ) AS ClaimAmount

        , ISNULL(p.PaymentRows, 0) AS PaymentRows
        , CONVERT
          (
              DECIMAL(38,4),
              ISNULL(p.PaymentAmount, 0)
          ) AS PaymentAmount

        , CONVERT
          (
              DECIMAL(38,4),
              ISNULL(c.ClaimAmount, 0)
              - ISNULL(p.PaymentAmount, 0)
          ) AS FinalBalance

    INTO #FV_FinancialResident

    FROM #ExpectedResidents e

    LEFT JOIN ClaimTotals c
        ON c.ResidentInfoID = e.SourceResidentInfoID

    LEFT JOIN PaymentTotals p
        ON p.ResidentInfoID = e.SourceResidentInfoID;


    ------------------------------------------------------------
    -- 18. CURRENT / LAST ACTION PARITY
    --
    -- Purpose:
    --   1. Prove the final preserved SOURCE-derived action for
    --      every Resident + Building pair is present in DATACORE
    --      with the expected transformed action type.
    --
    --   2. Prove the operational CURRENT action for each
    --      Resident + Building pair is either:
    --        a) that final preserved source action, or
    --        b) an expected MoveData-generated workflow successor.
    --
    --   3. Independently reconstruct the CURRENT action for every
    --      building using the approved independent operational-current rule
    --      and compare it with the live view.
    --
    -- Notes:
    --   * Raw KFMC last action may differ from the migratable last
    --     action only because of already-approved migration rules
    --     such as consecutive duplicate exclusion or old Type-27
    --     letter-allocation exclusion.
    --
    --   * A generated CURRENT action is valid only when its marker
    --     exists in #FV_ExpectedGeneratedActions.
    ------------------------------------------------------------


    ------------------------------------------------------------
    -- 18.1 Raw KFMC last action per Resident + Building
    ------------------------------------------------------------

    ;WITH RawRanked AS
    (
        SELECT
              s.buildingActionID
            , TRY_CONVERT(BIGINT, s.generalNo_FK) AS GeneralNo

            , UPPER
              (
                  REPLACE
                  (
                      LTRIM(RTRIM(ISNULL(s.buildingDetailsNo,N''))),
                      N' ',
                      N''
                  )
              ) AS BuildingNoKey

            , s.buildingDetailsNo
            , s.buildingActionTypeID_FK
            , s.buildingActionActive

            , ROW_NUMBER() OVER
              (
                  PARTITION BY
                        TRY_CONVERT(BIGINT, s.generalNo_FK)
                      , UPPER
                        (
                            REPLACE
                            (
                                LTRIM(RTRIM(ISNULL(s.buildingDetailsNo,N''))),
                                N' ',
                                N''
                            )
                        )
                  ORDER BY s.buildingActionID DESC
              ) AS rn

        FROM KFMC.Housing.BuildingAction s

        WHERE NULLIF(LTRIM(RTRIM(s.buildingDetailsNo)), N'')
              IS NOT NULL

          AND EXISTS
              (
                  SELECT 1
                  FROM #ExpectedResidents e
                  WHERE e.GeneralNo =
                        TRY_CONVERT(BIGINT, s.generalNo_FK)
              )
    )
    SELECT
          buildingActionID
        , GeneralNo
        , BuildingNoKey
        , buildingDetailsNo
        , buildingActionTypeID_FK
        , buildingActionActive
    INTO #FV_RawSourceLastPair
    FROM RawRanked
    WHERE rn = 1;


    ------------------------------------------------------------
    -- 18.2 Last migratable SOURCE action
    --      per Resident + Building
    ------------------------------------------------------------

    ;WITH RankedExpected AS
    (
        SELECT
              e.SourceActionID
            , e.EntityKey
            , e.GeneralNo
            , e.ResidentInfoID
            , e.ResidentDetailsID
            , e.FullName
            , e.ExpectedActionTypeID
            , e.ExpectedBuildingDetailsID
            , e.buildingDetailsNo AS SourceBuildingNo

            , UPPER
              (
                  REPLACE
                  (
                      LTRIM(RTRIM(ISNULL(e.buildingDetailsNo,N''))),
                      N' ',
                      N''
                  )
              ) AS BuildingNoKey

            , ROW_NUMBER() OVER
              (
                  PARTITION BY
                        e.GeneralNo
                      , UPPER
                        (
                            REPLACE
                            (
                                LTRIM(RTRIM(ISNULL(e.buildingDetailsNo,N''))),
                                N' ',
                                N''
                            )
                        )
                  ORDER BY e.SourceActionID DESC
              ) AS rn

        FROM #FV_ExpectedSourceActions e

        WHERE NULLIF(LTRIM(RTRIM(e.buildingDetailsNo)), N'')
              IS NOT NULL
    )
    SELECT
          SourceActionID
        , EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , ExpectedActionTypeID
        , ExpectedBuildingDetailsID
        , SourceBuildingNo
        , BuildingNoKey
    INTO #FV_SourceLastPair
    FROM RankedExpected
    WHERE rn = 1;


    ------------------------------------------------------------
    -- 18.3 Independently calculate CURRENT action
    --      per Resident + Building in DATACORE
    --
    -- Real:
    --   highest active source/non-generated action ID.
    --
    -- Generated:
    --   latest active MoveData action by entryDate DESC,
    --   then buildingActionID DESC.
    --
    -- Generated wins only when Generated.entryDate >
    -- Real.entryDate.
    ------------------------------------------------------------

    ;WITH Resolved AS
    (
        SELECT
              p.SourceActionID
            , p.EntityKey
            , p.GeneralNo
            , p.ResidentInfoID
            , p.ResidentDetailsID
            , p.FullName
            , p.ExpectedActionTypeID
            , p.ExpectedBuildingDetailsID
            , p.SourceBuildingNo
            , p.BuildingNoKey

            , realAction.buildingActionID
                AS RealActionID

            , realAction.buildingActionTypeID_FK
                AS RealActionTypeID

            , realAction.entryDate
                AS RealEntryDate

            , generatedAction.buildingActionID
                AS GeneratedActionID

            , generatedAction.buildingActionTypeID_FK
                AS GeneratedActionTypeID

            , generatedAction.entryDate
                AS GeneratedEntryDate

            , generatedAction.buildingActionExtraText4
                AS GeneratedMarker

            , generatedAction.buildingDetailsID_FK
                AS GeneratedBuildingDetailsID

            , CASE
                  WHEN generatedAction.buildingActionID IS NOT NULL
                   AND EXISTS
                       (
                           SELECT 1
                           FROM #FV_ExpectedGeneratedActions x
                           WHERE x.Marker =
                                 generatedAction.buildingActionExtraText4
                             AND x.GeneralNo = p.GeneralNo
                             AND
                             (
                                 x.ExpectedBuildingID IS NULL
                                 OR x.ExpectedBuildingID =
                                    TRY_CONVERT
                                    (
                                        BIGINT,
                                        generatedAction.buildingDetailsID_FK
                                    )
                             )
                       )
                      THEN 1
                  ELSE 0
              END AS GeneratedIsExpected

        FROM #FV_SourceLastPair p

        OUTER APPLY
        (
            SELECT TOP (1)
                  a.buildingActionID
                , a.buildingActionTypeID_FK
                , a.entryDate

            FROM Housing.BuildingAction a

            WHERE TRY_CONVERT(BIGINT, a.generalNo_FK) =
                  p.GeneralNo

              AND UPPER
                  (
                      REPLACE
                      (
                          LTRIM(RTRIM(ISNULL(a.buildingDetailsNo,N''))),
                          N' ',
                          N''
                      )
                  ) = p.BuildingNoKey

              AND a.buildingActionActive = 1

              /*
                  A preserved KFMC row is REAL even if its old
                  ExtraText4 happens to begin with "MoveData:".
              */
              AND
              (
                  EXISTS
                  (
                      SELECT 1
                      FROM KFMC.Housing.BuildingAction s
                      WHERE s.buildingActionID =
                            a.buildingActionID
                  )

                  OR a.buildingActionExtraText4 IS NULL
                  OR a.buildingActionExtraText4 NOT LIKE N'MoveData:%'
              )

            ORDER BY a.buildingActionID DESC
        ) realAction

        OUTER APPLY
        (
            SELECT TOP (1)
                  a.buildingActionID
                , a.buildingActionTypeID_FK
                , a.entryDate
                , a.buildingActionExtraText4
                , a.buildingDetailsID_FK

            FROM Housing.BuildingAction a

            WHERE TRY_CONVERT(BIGINT, a.generalNo_FK) =
                  p.GeneralNo

              AND UPPER
                  (
                      REPLACE
                      (
                          LTRIM(RTRIM(ISNULL(a.buildingDetailsNo,N''))),
                          N' ',
                          N''
                      )
                  ) = p.BuildingNoKey

              AND a.buildingActionActive = 1

              AND a.buildingActionExtraText4 LIKE N'MoveData:%'

              AND NOT EXISTS
                  (
                      SELECT 1
                      FROM KFMC.Housing.BuildingAction s
                      WHERE s.buildingActionID =
                            a.buildingActionID
                  )

            ORDER BY
                  a.entryDate DESC
                , a.buildingActionID DESC
        ) generatedAction
    )
    SELECT
          r.*

        , preserved.buildingActionID
            AS PreservedSourceActionID

        , preserved.buildingActionTypeID_FK
            AS PreservedSourceActionTypeID

        , CASE
              WHEN r.RealActionID IS NULL
                  THEN r.GeneratedActionID

              WHEN r.GeneratedActionID IS NULL
                  THEN r.RealActionID

              WHEN r.GeneratedEntryDate > r.RealEntryDate
                  THEN r.GeneratedActionID

              ELSE r.RealActionID
          END AS CurrentActionID

        , CASE
              WHEN r.RealActionID IS NULL
                  THEN r.GeneratedActionTypeID

              WHEN r.GeneratedActionID IS NULL
                  THEN r.RealActionTypeID

              WHEN r.GeneratedEntryDate > r.RealEntryDate
                  THEN r.GeneratedActionTypeID

              ELSE r.RealActionTypeID
          END AS CurrentActionTypeID

        , CASE
              WHEN r.RealActionID IS NULL
                  THEN N'GENERATED'

              WHEN r.GeneratedActionID IS NULL
                  THEN N'REAL'

              WHEN r.GeneratedEntryDate > r.RealEntryDate
                  THEN N'GENERATED'

              ELSE N'REAL'
          END AS CurrentProvenance

    INTO #FV_CurrentPair

    FROM Resolved r

    LEFT JOIN Housing.BuildingAction preserved
        ON preserved.buildingActionID =
           r.SourceActionID;


    ------------------------------------------------------------
    -- 18.4 Classify Resident + Building parity
    ------------------------------------------------------------

    SELECT
          p.*
        , raw.buildingActionID
            AS RawKFMC_LastActionID

        , raw.buildingActionTypeID_FK
            AS RawKFMC_LastActionTypeID

        , CASE
              WHEN p.PreservedSourceActionID IS NULL
                  THEN N'MISSING_PRESERVED_SOURCE_ACTION'

              WHEN p.PreservedSourceActionID <>
                   p.SourceActionID
                  THEN N'WRONG_LAST_PRESERVED_SOURCE_ACTION'

              WHEN ISNULL
                   (
                       p.PreservedSourceActionTypeID,
                       -1
                   )
                   <>
                   ISNULL
                   (
                       p.ExpectedActionTypeID,
                       -1
                   )
                  THEN N'WRONG_TRANSFORMED_ACTION_TYPE'

              WHEN p.CurrentActionID =
                   p.SourceActionID
                  THEN N'MATCH_SOURCE_CURRENT'

              WHEN p.CurrentProvenance = N'GENERATED'
               AND p.GeneratedIsExpected = 1
                  THEN N'EXPECTED_GENERATED_SUCCESSOR'

              ELSE N'CURRENT_ACTION_MISMATCH'
          END AS PairStatus

    INTO #FV_CurrentPairAudit

    FROM #FV_CurrentPair p

    LEFT JOIN #FV_RawSourceLastPair raw
        ON raw.GeneralNo = p.GeneralNo
       AND raw.BuildingNoKey = p.BuildingNoKey;


    ------------------------------------------------------------
    -- 18.5 Resident + Building current-state failures
    ------------------------------------------------------------

    INSERT INTO #ValidationIssues
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
        , SectionName
        , IssueCode
        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName
        , ExpectedValue
        , ActualValue
        , Severity
        , Notes
    )
    SELECT
          p.EntityKey
        , p.GeneralNo
        , p.ResidentInfoID
        , p.ResidentDetailsID
        , p.FullName

        , N'CURRENT_ACTION_PARITY'

        , CASE p.PairStatus
              WHEN N'MISSING_PRESERVED_SOURCE_ACTION'
                  THEN N'LAST_SOURCE_ACTION_MISSING'

              WHEN N'WRONG_LAST_PRESERVED_SOURCE_ACTION'
                  THEN N'LAST_SOURCE_ACTION_ID_MISMATCH'

              WHEN N'WRONG_TRANSFORMED_ACTION_TYPE'
                  THEN N'LAST_SOURCE_ACTION_TYPE_MISMATCH'

              ELSE N'CURRENT_RESIDENT_BUILDING_ACTION_MISMATCH'
          END AS IssueCode

        , N'KFMC.Housing.BuildingAction + approved MoveData transformations'
        , N'DATACORE.Housing.BuildingAction'

        , CONCAT
          (
              N'GeneralNo=',
              CONVERT(NVARCHAR(50), p.GeneralNo),
              N'; Building=',
              ISNULL(p.SourceBuildingNo,N'<NULL>')
          )

        , N'Current / Last Action'

        , CONCAT
          (
              N'LastSourceID=',
              CONVERT(NVARCHAR(50), p.SourceActionID),
              N'; ExpectedType=',
              CONVERT(NVARCHAR(50), p.ExpectedActionTypeID),
              N'; Current=Source or expected MoveData successor'
          )

        , CONCAT
          (
              N'PreservedID=',
              ISNULL
              (
                  CONVERT
                  (
                      NVARCHAR(50),
                      p.PreservedSourceActionID
                  ),
                  N'<NULL>'
              ),
              N'; PreservedType=',
              ISNULL
              (
                  CONVERT
                  (
                      NVARCHAR(50),
                      p.PreservedSourceActionTypeID
                  ),
                  N'<NULL>'
              ),
              N'; CurrentID=',
              ISNULL
              (
                  CONVERT
                  (
                      NVARCHAR(50),
                      p.CurrentActionID
                  ),
                  N'<NULL>'
              ),
              N'; CurrentType=',
              ISNULL
              (
                  CONVERT
                  (
                      NVARCHAR(50),
                      p.CurrentActionTypeID
                  ),
                  N'<NULL>'
              ),
              N'; Provenance=',
              ISNULL(p.CurrentProvenance,N'<NULL>'),
              N'; Marker=',
              ISNULL(p.GeneratedMarker,N'<NULL>')
          )

        , 'ERROR'

        , CASE p.PairStatus
              WHEN N'MISSING_PRESERVED_SOURCE_ACTION'
                  THEN N'The final migratable source action for this resident/building pair is missing from DATACORE.'

              WHEN N'WRONG_LAST_PRESERVED_SOURCE_ACTION'
                  THEN N'The final preserved source-derived action ID does not match the expected KFMC action.'

              WHEN N'WRONG_TRANSFORMED_ACTION_TYPE'
                  THEN N'The final preserved source-derived action exists but its transformed action type is incorrect.'

              ELSE N'The operational current action for this resident/building pair is neither the final expected source action nor an expected MoveData-generated successor.'
          END AS Notes

    FROM #FV_CurrentPairAudit p

    WHERE p.PairStatus IN
          (
              N'MISSING_PRESERVED_SOURCE_ACTION',
              N'WRONG_LAST_PRESERVED_SOURCE_ACTION',
              N'WRONG_TRANSFORMED_ACTION_TYPE',
              N'CURRENT_ACTION_MISMATCH'
          );


    ------------------------------------------------------------
    -- 18.6 Building scope for independent current-action check
    --
    -- Full run:
    --   all DATACORE buildings.
    --
    -- Scoped resident run:
    --   only buildings associated with that resident in source
    --   or generated migration history.
    ------------------------------------------------------------

    SELECT
          b.buildingDetailsID
        , b.buildingDetailsNo

    INTO #FV_CurrentBuildingScope

    FROM Housing.BuildingDetails b

    WHERE
          @GeneralNo IS NULL

       OR EXISTS
          (
              SELECT 1
              FROM #FV_ExpectedSourceActions s
              WHERE s.GeneralNo = @GeneralNo
                AND s.ExpectedBuildingDetailsID =
                    b.buildingDetailsID
          )

       OR EXISTS
          (
              SELECT 1
              FROM #FV_ExpectedGeneratedActions g
              WHERE g.GeneralNo = @GeneralNo
                AND g.ExpectedBuildingID =
                    b.buildingDetailsID
          )

       OR EXISTS
          (
              SELECT 1
              FROM Housing.BuildingAction a
              WHERE TRY_CONVERT(BIGINT, a.generalNo_FK) =
                    @GeneralNo
                AND TRY_CONVERT
                    (
                        BIGINT,
                        a.buildingDetailsID_FK
                    ) = b.buildingDetailsID
          );


  /*
Replacement for sections 18.7 through 18.10 ONLY of:
MoveData.usp_FinalValidateMigrationForEveryResident
Do not execute this fragment standalone. Replace the existing text between
'-- 18.7 Independently reconstruct' and '-- 18A. WAITING_CLASS_PARITY'.
Independent reconstruction of Housing.V_GetGeneralListForBuilding semantics.
No updates or deletes to source/target data.
*/

------------------------------------------------------------
-- 18.7 Independently reconstruct operational CURRENT action
-- and building visibility, without referencing either view.
------------------------------------------------------------
SELECT
      b.buildingDetailsID
    , b.buildingDetailsNo
    , CONVERT(BIT, CASE WHEN eligible.IsEligible = 1 THEN 1 ELSE 0 END) AS IsEligibleForCurrentView
    , currentAction.buildingActionID AS ExpectedCurrentActionID
    , realAction.buildingActionID AS ExpectedRealActionID
    , generatedAction.buildingActionID AS ExpectedGeneratedActionID
    , realAction.entryDate AS RealEntryDate
    , generatedAction.entryDate AS GeneratedEntryDate
INTO #FV_ExpectedCurrentBuilding
FROM #FV_CurrentBuildingScope b
OUTER APPLY
(
    SELECT TOP (1) 1 AS IsEligible
    FROM Housing.BuildingDetails bd
    INNER JOIN Housing.BuildingType bt
        ON bt.buildingTypeID = bd.buildingTypeID_FK
    INNER JOIN Housing.BuildingUtilityType bu
        ON bu.buildingUtilityTypeID = bd.buildingUtilityTypeID_FK
    INNER JOIN Housing.MilitaryLocation ml
        ON ml.militaryLocationID = bd.militaryLocationID_FK
    INNER JOIN Housing.MilitaryAreaCity mac
        ON mac.militaryAreaCityID = ml.militaryAreaCityID_FK
    INNER JOIN Housing.MilitaryArea ma
        ON ma.militaryAreaID = mac.militaryAreaID_FK
    INNER JOIN Housing.BuildingClass bc
        ON bc.buildingClassID = bd.buildingClassID_FK
    INNER JOIN dbo.Idara i
        ON i.IdaraId = bd.IdaraId_FK
    WHERE bd.buildingDetailsID = b.buildingDetailsID
      AND bd.buildingDetailsActive = 1
      AND bt.buildingTypeActive = 1
      AND bu.buildingUtilityTypeActive = 1
      AND ml.militaryLocationActive = 1
      AND bc.buildingClassActive = 1
      AND mac.militaryAreaCityActive = 1
      AND ma.militaryAreaIsActive = 1
      AND bd.buildingDetailsStartDate IS NOT NULL
      AND bu.buildingUtilityTypeStartDate IS NOT NULL
      AND (bd.buildingDetailsEndDate IS NULL OR bd.buildingDetailsEndDate > GETDATE())
      AND (bu.buildingUtilityTypeEndDate IS NULL OR bu.buildingUtilityTypeEndDate > GETDATE())
) eligible
OUTER APPLY
(
    SELECT TOP (1) a.buildingActionID, a.entryDate
    FROM Housing.BuildingAction a
    WHERE TRY_CONVERT(BIGINT, a.buildingDetailsID_FK) = b.buildingDetailsID
      AND a.buildingActionActive = 1
      AND (a.buildingActionExtraText4 IS NULL
           OR a.buildingActionExtraText4 NOT LIKE N'MoveData:%')
    ORDER BY a.buildingActionID DESC
) realAction
OUTER APPLY
(
    SELECT TOP (1) a.buildingActionID, a.entryDate
    FROM Housing.BuildingAction a
    WHERE TRY_CONVERT(BIGINT, a.buildingDetailsID_FK) = b.buildingDetailsID
      AND a.buildingActionActive = 1
      AND a.buildingActionExtraText4 LIKE N'MoveData:%'
    ORDER BY a.entryDate DESC, a.buildingActionID DESC
) generatedAction
OUTER APPLY
(
    SELECT TOP (1) ba.buildingActionID
    FROM Housing.BuildingAction ba
    INNER JOIN Housing.BuildingDetails bd
        ON bd.buildingDetailsID = b.buildingDetailsID
    WHERE ba.buildingDetailsID_FK = bd.buildingDetailsID
      AND ba.buildingActionActive = 1
      AND NOT
      (
          ba.buildingActionTypeID_FK IN (3, 58)
          AND EXISTS
          (
              SELECT 1
              FROM Housing.fn_BuildingAction_ChainToRoot(ba.buildingActionID) ancestor
              INNER JOIN Housing.BuildingAction stage57
                  ON stage57.buildingActionID = ancestor.buildingActionID
                 AND stage57.buildingActionTypeID_FK = 57
                 AND stage57.buildingActionActive = 1
                 AND stage57.buildingDetailsID_FK = bd.buildingDetailsID
                 AND stage57.IdaraId_FK = bd.IdaraId_FK
              INNER JOIN Housing.BuildingAction operatingRoot
                  ON operatingRoot.buildingDetailsID_FK = bd.buildingDetailsID
                 AND operatingRoot.IdaraId_FK = bd.IdaraId_FK
                 AND operatingRoot.buildingActionActive = 1
                 AND operatingRoot.buildingActionParentID IS NULL
                 AND operatingRoot.residentInfoID_FK IS NULL
                 AND operatingRoot.buildingActionTypeID_FK IN (4, 5, 62)
                 AND operatingRoot.buildingActionID > stage57.buildingActionID
                 AND operatingRoot.buildingActionID < ba.buildingActionID
          )
      )
    ORDER BY ba.buildingActionID DESC
) currentAction;

------------------------------------------------------------
-- 18.8 Materialize new live view; one row per building.
-- Important: the view may have a row whose LastActionID is NULL.
------------------------------------------------------------
SELECT
      v.buildingDetailsID
    , COUNT_BIG(*) AS ViewRowCount
    , MIN(v.LastActionID) AS MinViewActionID
    , MAX(v.LastActionID) AS MaxViewActionID
INTO #FV_ViewCurrentBuilding
FROM Housing.V_GetGeneralListForBuilding v
INNER JOIN #FV_CurrentBuildingScope b
    ON b.buildingDetailsID = v.buildingDetailsID
GROUP BY v.buildingDetailsID;

------------------------------------------------------------
-- 18.9 Compare both visibility and current-action selection.
------------------------------------------------------------
SELECT
      e.buildingDetailsID
    , e.buildingDetailsNo
    , e.IsEligibleForCurrentView
    , e.ExpectedCurrentActionID
    , e.ExpectedRealActionID
    , e.ExpectedGeneratedActionID
    , e.RealEntryDate
    , e.GeneratedEntryDate
    , ISNULL(v.ViewRowCount, 0) AS ViewRowCount
    , v.MinViewActionID
    , v.MaxViewActionID
    , CASE
          WHEN e.IsEligibleForCurrentView = 0
           AND ISNULL(v.ViewRowCount, 0) = 0
              THEN N'EXCLUDED_BY_VIEW_FILTER'
          WHEN e.IsEligibleForCurrentView = 1
           AND ISNULL(v.ViewRowCount, 0) = 1
           AND
           (
               v.MinViewActionID = e.ExpectedCurrentActionID
               OR (v.MinViewActionID IS NULL AND e.ExpectedCurrentActionID IS NULL)
           )
              THEN N'MATCH'
          ELSE N'MISMATCH'
      END AS CurrentBuildingStatus
INTO #FV_BuildingCurrentAudit
FROM #FV_ExpectedCurrentBuilding e
LEFT JOIN #FV_ViewCurrentBuilding v
    ON v.buildingDetailsID = e.buildingDetailsID;

------------------------------------------------------------
-- 18.10 Log only actual mismatches (including duplicate rows).
------------------------------------------------------------
INSERT INTO #ValidationIssues
(
      EntityKey
    , GeneralNo
    , ResidentInfoID
    , ResidentDetailsID
    , FullName
    , SectionName
    , IssueCode
    , SourceObject
    , TargetObject
    , ReferenceID
    , FieldName
    , ExpectedValue
    , ActualValue
    , Severity
    , Notes
)
SELECT
      NULL
    , NULL
    , NULL
    , NULL
    , NULL
    , N'CURRENT_ACTION_PARITY'
    , CASE
          WHEN a.ViewRowCount > 1 THEN N'BUILDING_CURRENT_VIEW_DUPLICATE'
          WHEN a.IsEligibleForCurrentView = 0 THEN N'BUILDING_UNEXPECTEDLY_IN_VIEW'
          WHEN a.ViewRowCount = 0 THEN N'BUILDING_ELIGIBLE_BUT_MISSING'
          ELSE N'BUILDING_CURRENT_VIEW_MISMATCH'
      END
    , N'Independent reconstruction from Housing base tables'
    , N'Housing.V_GetGeneralListForBuilding'
    , CONCAT
      (
          N'BuildingDetailsID=', CONVERT(NVARCHAR(50), a.buildingDetailsID),
          N'; BuildingNo=', ISNULL(a.buildingDetailsNo, N'<NULL>')
      )
    , N'LastActionID'
    , CASE
          WHEN a.IsEligibleForCurrentView = 0 THEN N'<EXCLUDED BY ELIGIBILITY>'
          ELSE ISNULL(CONVERT(NVARCHAR(50), a.ExpectedCurrentActionID), N'<NO ACTION>')
      END
    , CASE
          WHEN a.ViewRowCount = 0 THEN N'<NO VIEW ROW>'
          WHEN a.ViewRowCount = 1 THEN
              ISNULL(CONVERT(NVARCHAR(50), a.MinViewActionID), N'<NO ACTION>')
          ELSE CONCAT
          (
              N'ROWS=', CONVERT(NVARCHAR(50), a.ViewRowCount),
              N'; MIN=', ISNULL(CONVERT(NVARCHAR(50), a.MinViewActionID), N'<NULL>'),
              N'; MAX=', ISNULL(CONVERT(NVARCHAR(50), a.MaxViewActionID), N'<NULL>')
          )
      END
    , N'ERROR'
    , CASE
          WHEN a.ViewRowCount > 1 THEN
              N'V_GetGeneralListForBuilding returned multiple rows for one building.'
          WHEN a.IsEligibleForCurrentView = 0 THEN
              N'Building appears in the view although it fails the approved eligibility predicates.'
          WHEN a.ViewRowCount = 0 THEN
              N'Eligible building is missing from V_GetGeneralListForBuilding.'
          ELSE
              N'V_GetGeneralListForBuilding LastActionID differs from independently reconstructed operational action.'
      END
FROM #FV_BuildingCurrentAudit a
WHERE a.CurrentBuildingStatus = N'MISMATCH';

    ------------------------------------------------------------
    -- 18A. WAITING_CLASS_PARITY (global master + historical links)
    -- Legacy KFMC IDs 1-11 are preserved; ID 12 is the main
    -- leaders list; ID 99 is virtual letter housing, not master.
    -- No source/target data are changed by these checks.
    ------------------------------------------------------------

    -- Source-based parity for ALL legacy letter roots, including historical closed chains.
    -- IDs are used for matching, not as hard-coded exception lists.
    INSERT INTO #ValidationIssues
    (EntityKey,GeneralNo,SectionName,IssueCode,SourceObject,TargetObject,
     ReferenceID,FieldName,ExpectedValue,ActualValue,Severity,Notes)
    SELECT CASE WHEN TRY_CONVERT(bigint,k.generalNo_FK) IS NULL THEN NULL
                ELSE CONCAT(N'G:',TRY_CONVERT(bigint,k.generalNo_FK)) END,
           TRY_CONVERT(bigint,k.generalNo_FK),
           N'WAITING_CLASS_PARITY',N'LEGACY_LETTER_ROOT_TRANSFORM_MISMATCH',
           N'KFMC.Housing.BuildingAction',N'DATACORE.Housing.BuildingAction',
           CONVERT(nvarchar(100),k.buildingActionID),
           N'Type,Class,Parent',
           CONCAT(N'Type=1; Class=',CASE WHEN k.buildingActionTypeID_FK=7 THEN 17 ELSE 18 END,
                  N'; Parent=NULL'),
           CASE WHEN t.buildingActionID IS NULL THEN N'<MISSING>'
                ELSE CONCAT(N'Type=',COALESCE(CONVERT(nvarchar(30),t.buildingActionTypeID_FK),N'<NULL>'),
                            N'; Class=',COALESCE(CONVERT(nvarchar(30),t.buildingActionExtraType1),N'<NULL>'),
                            N'; Parent=',COALESCE(CONVERT(nvarchar(30),t.buildingActionParentID),N'<NULL>')) END,
           'ERROR',N'Root ID must be preserved, only its type/class transformed; children are checked separately.'
    FROM KFMC.Housing.BuildingAction k
    JOIN #ExpectedResidents eligibleRoot
      ON eligibleRoot.GeneralNo=TRY_CONVERT(bigint,k.generalNo_FK)
    LEFT JOIN Housing.BuildingAction t ON t.buildingActionID=k.buildingActionID
    WHERE k.buildingActionParentID IS NULL
      AND k.buildingActionTypeID_FK IN (7,25)
      AND (@GeneralNo IS NULL OR TRY_CONVERT(bigint,k.generalNo_FK)=@GeneralNo)
      AND (t.buildingActionID IS NULL OR t.buildingActionTypeID_FK<>1
           OR t.buildingActionTypeID_FK IS NULL
           OR t.buildingActionExtraType1<>CASE WHEN k.buildingActionTypeID_FK=7 THEN 17 ELSE 18 END
           OR t.buildingActionExtraType1 IS NULL OR t.buildingActionParentID IS NOT NULL);

    -- Newly approved legacy-letter side classes in Idara 1.
    -- Check independently of KFMC: these classes are DATACORE-only.
    INSERT INTO #ValidationIssues
    (SectionName,IssueCode,TargetObject,ReferenceID,FieldName,
     ExpectedValue,ActualValue,Severity,Notes)
    SELECT N'WAITING_CLASS_PARITY', N'MIGRATED_LETTER_CLASS_MISMATCH',
           N'DATACORE.Housing.WaitingClass', CONVERT(nvarchar(50),x.ClassID),
           N'NameA,Sequence,Root,Active,Idara',
           CONCAT(x.ClassName,N'; Sequence=',x.ClassSequence,
                  N'; Root=NULL; Active=1; Idara=1'),
           CASE WHEN t.waitingClassID IS NULL THEN N'<MISSING>'
                ELSE CONCAT(COALESCE(t.waitingClassName_A,N'<NULL>'),
                   N'; Sequence=',COALESCE(CONVERT(nvarchar(30),t.waitingClassSequence),N'<NULL>'),
                   N'; Root=',COALESCE(CONVERT(nvarchar(30),t.waitingClassRoot),N'<NULL>'),
                   N'; Active=',COALESCE(CONVERT(nvarchar(30),t.waitingClassActive),N'<NULL>'),
                   N'; Idara=',COALESCE(CONVERT(nvarchar(30),t.idara_FK),N'<NULL>')) END,
           'ERROR', N'Approved migration-only side class for converted legacy letter root.'
    FROM (VALUES (17,N'خطاب تسكين',3),(18,N'خطاب تسكين عزاب',4))
         x(ClassID,ClassName,ClassSequence)
    LEFT JOIN Housing.WaitingClass t ON t.waitingClassID=x.ClassID
    WHERE t.waitingClassID IS NULL
       OR t.waitingClassName_A COLLATE DATABASE_DEFAULT <> x.ClassName COLLATE DATABASE_DEFAULT
       OR t.waitingClassName_A IS NULL
       OR t.waitingClassSequence <> x.ClassSequence
       OR t.waitingClassSequence IS NULL
       OR t.waitingClassRoot IS NOT NULL
       OR t.waitingClassActive IS NULL OR t.waitingClassActive <> 1
       OR t.idara_FK IS NULL OR t.idara_FK <> 1;

    ;WITH ClassIds AS
    (
        SELECT ClassID
        FROM (VALUES (1),(2),(3),(4),(5),(6),
                     (7),(8),(9),(10),(11),(12)) c(ClassID)
    )
    SELECT
          c.ClassID
        , CASE WHEN c.ClassID = 12 OR s.waitingClassID IS NOT NULL
               THEN 1 ELSE 0 END AS SourcePresent
        , (CASE WHEN c.ClassID = 12 THEN N'القادة'
                ELSE s.waitingClassName_A END)
            COLLATE DATABASE_DEFAULT AS ExpectedNameA
        , (CASE WHEN c.ClassID = 12 THEN CAST(NULL AS nvarchar(100))
                ELSE s.waitingClassName_E END)
            COLLATE DATABASE_DEFAULT AS ExpectedNameE
        , CASE WHEN c.ClassID BETWEEN 1 AND 4 THEN c.ClassID + 1
               WHEN c.ClassID = 12 THEN 1
               ELSE s.waitingClassSequence END AS ExpectedSequence
        , CASE WHEN c.ClassID = 12 THEN CAST(NULL AS int)
               ELSE s.waitingClassRoot END AS ExpectedRoot
        , CAST(1 AS bit) AS ExpectedActive
        , CASE WHEN c.ClassID BETWEEN 5 AND 11 THEN @IdaraId
               ELSE CAST(NULL AS bigint) END AS ExpectedIdara
    INTO #FV_ExpectedWaitingClasses
    FROM ClassIds c
    LEFT JOIN KFMC.Housing.WaitingClass s
      ON s.waitingClassID = c.ClassID
     AND c.ClassID BETWEEN 1 AND 11;

    -- A source master row may not silently disappear from the baseline.
    INSERT INTO #ValidationIssues
    (SectionName,IssueCode,SourceObject,TargetObject,
     ReferenceID,FieldName,ExpectedValue,ActualValue,Severity,Notes)
    SELECT
          N'WAITING_CLASS_PARITY'
        , N'MISSING_SOURCE_WAITING_CLASS'
        , N'KFMC.Housing.WaitingClass'
        , N'DATACORE.Housing.WaitingClass'
        , CONVERT(nvarchar(100),e.ClassID)
        , N'waitingClassID'
        , CONVERT(nvarchar(100),e.ClassID)
        , N'<MISSING IN KFMC>'
        , 'ERROR'
        , N'KFMC IDs 1-11 must exist before checking frozen-source master parity.'
    FROM #FV_ExpectedWaitingClasses e
    WHERE e.SourcePresent = 0;

    -- Null-safe comparison covers ID, names, sequence, root,
    -- active state and main/side Idara classification.
    INSERT INTO #ValidationIssues
    (SectionName,IssueCode,SourceObject,TargetObject,
     ReferenceID,FieldName,ExpectedValue,ActualValue,Severity,Notes)
    SELECT
          N'WAITING_CLASS_PARITY'
        , CASE WHEN t.waitingClassID IS NULL
               THEN N'MISSING_TARGET_WAITING_CLASS'
               ELSE N'WAITING_CLASS_MASTER_MISMATCH' END
        , N'KFMC.Housing.WaitingClass / approved leaders ID 12'
        , N'DATACORE.Housing.WaitingClass'
        , CONVERT(nvarchar(100),e.ClassID)
        , N'NameA,NameE,Sequence,Root,Active,Idara'
        , CONCAT(N'NameA=',COALESCE(e.ExpectedNameA,N'<NULL>'),
                 N'; NameE=',COALESCE(e.ExpectedNameE,N'<NULL>'),
                 N'; Sequence=',COALESCE(CONVERT(nvarchar(30),e.ExpectedSequence),N'<NULL>'),
                 N'; Root=',COALESCE(CONVERT(nvarchar(30),e.ExpectedRoot),N'<NULL>'),
                 N'; Active=1; Idara=',COALESCE(CONVERT(nvarchar(30),e.ExpectedIdara),N'<NULL>'))
        , CASE WHEN t.waitingClassID IS NULL THEN N'<MISSING>'
               ELSE CONCAT(N'NameA=',COALESCE(t.waitingClassName_A,N'<NULL>'),
                     N'; NameE=',COALESCE(t.waitingClassName_E,N'<NULL>'),
                     N'; Sequence=',COALESCE(CONVERT(nvarchar(30),t.waitingClassSequence),N'<NULL>'),
                     N'; Root=',COALESCE(CONVERT(nvarchar(30),t.waitingClassRoot),N'<NULL>'),
                     N'; Active=',COALESCE(CONVERT(nvarchar(30),t.waitingClassActive),N'<NULL>'),
                     N'; Idara=',COALESCE(CONVERT(nvarchar(30),t.idara_FK),N'<NULL>')) END
        , 'ERROR'
        , N'Main classes 1-4 and 12 must be global; historical side classes 5-11 belong to the migration Idara.'
    FROM #FV_ExpectedWaitingClasses e
    LEFT JOIN Housing.WaitingClass t ON t.waitingClassID = e.ClassID
    WHERE e.SourcePresent = 1
      AND (t.waitingClassID IS NULL OR EXISTS
      (
          SELECT t.waitingClassName_A COLLATE DATABASE_DEFAULT,
                 t.waitingClassName_E COLLATE DATABASE_DEFAULT,
                 t.waitingClassSequence,t.waitingClassRoot,
                 t.waitingClassActive,t.idara_FK
          EXCEPT
          SELECT e.ExpectedNameA COLLATE DATABASE_DEFAULT,
                 e.ExpectedNameE COLLATE DATABASE_DEFAULT,
                 e.ExpectedSequence,e.ExpectedRoot,
                 e.ExpectedActive,e.ExpectedIdara
      ));

    -- Reject leftover test classes and an incorrect master ID 99.
    INSERT INTO #ValidationIssues
    (SectionName,IssueCode,TargetObject,ReferenceID,
     FieldName,ExpectedValue,ActualValue,Severity,Notes)
    SELECT
          N'WAITING_CLASS_PARITY'
        , CASE WHEN t.waitingClassID = 99
               THEN N'VIRTUAL_99_MUST_NOT_BE_MASTER'
               ELSE N'UNEXPECTED_WAITING_CLASS_MASTER' END
        , N'DATACORE.Housing.WaitingClass'
        , CONVERT(nvarchar(100),t.waitingClassID)
        , N'waitingClassID'
        , N'Approved historical classes 1-12 and converted side classes 17/18'
        , CONCAT(t.waitingClassID,N': ',COALESCE(t.waitingClassName_A,N'<NULL>'))
        , 'ERROR'
        , N'ID 99 is a historical virtual letter-housing marker; 13-15 are confirmed test data.'
    FROM Housing.WaitingClass t
    WHERE t.waitingClassID NOT BETWEEN 1 AND 12
      AND t.waitingClassID NOT IN (17,18)
      AND (t.waitingClassID=99
           OR t.waitingClassActive=1
           OR EXISTS (SELECT 1 FROM Housing.BuildingAction a
                      WHERE a.buildingActionExtraType1=t.waitingClassID)
           OR EXISTS (SELECT 1 FROM Housing.AssignPeriod p
                      WHERE p.WaitingClassID_FK=t.waitingClassID));

    -- ExtraType1 is generic. Check it only for waiting-list
    -- workflow action types; virtual 99 remains a valid reference.
    INSERT INTO #ValidationIssues
    (EntityKey,GeneralNo,SectionName,IssueCode,TargetObject,
     ReferenceID,FieldName,ExpectedValue,ActualValue,Severity,Notes)
    SELECT
          CASE WHEN TRY_CONVERT(bigint,a.generalNo_FK) IS NULL THEN NULL
               ELSE CONCAT(N'G:',TRY_CONVERT(bigint,a.generalNo_FK)) END
        , TRY_CONVERT(bigint,a.generalNo_FK)
        , N'WAITING_CLASS_PARITY'
        , N'ORPHAN_ACTION_WAITING_CLASS'
        , N'DATACORE.Housing.BuildingAction'
        , CONVERT(nvarchar(100),a.buildingActionID)
        , N'buildingActionExtraType1'
        , N'Valid WaitingClass ID or virtual 99'
        , CONVERT(nvarchar(100),a.buildingActionExtraType1)
        , 'ERROR'
        , N'Waiting-list workflow action references a missing/inactive master (other than virtual 99).'
    FROM Housing.BuildingAction a
    WHERE a.buildingActionTypeID_FK IN (1,20,21,22,27,28)
      AND a.buildingActionExtraType1 IS NOT NULL
      AND a.buildingActionExtraType1 <> 99
      AND (@GeneralNo IS NULL OR TRY_CONVERT(bigint,a.generalNo_FK) = @GeneralNo)
      AND NOT EXISTS
      (
          SELECT 1 FROM Housing.WaitingClass wc
          WHERE wc.waitingClassID = a.buildingActionExtraType1
            AND wc.waitingClassActive = 1
      );

    -- ID 99 is allowed only where it was preserved from an
    -- eligible KFMC source action in the letter-housing workflow.
    INSERT INTO #ValidationIssues
    (EntityKey,GeneralNo,SectionName,IssueCode,TargetObject,
     ReferenceID,FieldName,ExpectedValue,ActualValue,Severity,Notes)
    SELECT
          CASE WHEN TRY_CONVERT(bigint,a.generalNo_FK) IS NULL THEN NULL
               ELSE CONCAT(N'G:',TRY_CONVERT(bigint,a.generalNo_FK)) END
        , TRY_CONVERT(bigint,a.generalNo_FK)
        , N'WAITING_CLASS_PARITY'
        , N'UNEXPECTED_VIRTUAL_99_USAGE'
        , N'DATACORE.Housing.BuildingAction'
        , CONVERT(nvarchar(100),a.buildingActionID)
        , N'buildingActionExtraType1'
        , N'Preserved historical non-root 99 only; waiting root 1 with source 99 maps to class 5'
        , CONCAT(N'99; ActionType=',a.buildingActionTypeID_FK)
        , 'ERROR'
        , N'Virtual 99 may not be invented or assigned to an unrelated waiting-list action.'
    FROM Housing.BuildingAction a
    LEFT JOIN #FV_ExpectedSourceActions s
      ON s.SourceActionID = a.buildingActionID
    WHERE a.buildingActionTypeID_FK IN (1,20,21,22,27,28)
      AND a.buildingActionExtraType1 = 99
      AND (@GeneralNo IS NULL OR TRY_CONVERT(bigint,a.generalNo_FK) = @GeneralNo)
      AND (s.SourceActionID IS NULL
           OR s.ExpectedActionTypeID NOT IN (1,22,27)
           OR s.buildingActionExtraType1 IS NULL
           OR s.buildingActionExtraType1 <> 99
           OR (a.buildingActionParentID IS NULL
               AND a.buildingActionTypeID_FK = 1));

    -- Compare copied waiting-class values, including 99, using
    -- the already-filtered source actions (duplicates/letter 27 excluded).
    INSERT INTO #ValidationIssues
    (EntityKey,GeneralNo,ResidentInfoID,ResidentDetailsID,FullName,
     SectionName,IssueCode,SourceObject,TargetObject,
     ReferenceID,FieldName,ExpectedValue,ActualValue,Severity,Notes)
    SELECT
          s.EntityKey,s.GeneralNo,s.ResidentInfoID,s.ResidentDetailsID,s.FullName
        , N'WAITING_CLASS_PARITY'
        , N'HISTORICAL_WAITING_CLASS_VALUE_MISMATCH'
        , N'KFMC.Housing.BuildingAction'
        , N'DATACORE.Housing.BuildingAction'
        , CONVERT(nvarchar(100),s.SourceActionID)
        , N'buildingActionExtraType1'
        , COALESCE(CONVERT(nvarchar(100),s.buildingActionExtraType1),N'<NULL>')
        , CASE WHEN t.buildingActionID IS NULL THEN N'<MISSING ACTION>'
               ELSE COALESCE(CONVERT(nvarchar(100),t.buildingActionExtraType1),N'<NULL>') END
        , 'ERROR'
        , N'Compare with the expected migrated waiting class: legacy root 7=>17, 25=>18 and root 1 class 99=>5; preserve other eligible values.'
    FROM #FV_ExpectedSourceActions s
    LEFT JOIN Housing.BuildingAction t
      ON t.buildingActionID = s.SourceActionID
    WHERE s.ExpectedActionTypeID IN (1,20,21,22,27,28)
      AND (t.buildingActionID IS NULL OR EXISTS
      (
          SELECT s.buildingActionExtraType1
          EXCEPT
          SELECT t.buildingActionExtraType1
      ));

    -- AssignPeriod class references and four approved historical periods.
    INSERT INTO #ValidationIssues
    (SectionName,IssueCode,TargetObject,ReferenceID,
     FieldName,ExpectedValue,ActualValue,Severity,Notes)
    SELECT
          N'WAITING_CLASS_PARITY'
        , N'ORPHAN_ASSIGN_PERIOD_WAITING_CLASS'
        , N'DATACORE.Housing.AssignPeriod'
        , CONVERT(nvarchar(100),ap.AssignPeriodID)
        , N'WaitingClassID_FK'
        , N'Existing active WaitingClass'
        , COALESCE(CONVERT(nvarchar(100),ap.WaitingClassID_FK),N'<NULL>')
        , 'ERROR'
        , N'Every populated AssignPeriod waiting-class reference must resolve to a valid master.'
    FROM Housing.AssignPeriod ap
    WHERE ap.IdaraId_FK = @IdaraId
      AND ap.WaitingClassID_FK IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1 FROM Housing.WaitingClass wc
          WHERE wc.waitingClassID = ap.WaitingClassID_FK
            AND wc.waitingClassActive = 1
      );

    INSERT INTO #ValidationIssues
    (SectionName,IssueCode,TargetObject,ReferenceID,
     FieldName,ExpectedValue,ActualValue,Severity,Notes)
    SELECT
          N'WAITING_CLASS_PARITY'
        , N'INVALID_LEGACY_MAIN_ASSIGN_PERIOD_COUNT'
        , N'DATACORE.Housing.AssignPeriod'
        , CONVERT(nvarchar(100),c.ClassID)
        , N'Legacy AssignPeriod per main class'
        , N'1'
        , CONVERT(nvarchar(100),x.PeriodCount)
        , 'ERROR'
        , N'Exactly one historical period must exist for each main class 1-4 within this migration Idara.'
    FROM (VALUES (1),(2),(3),(4)) c(ClassID)
    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS PeriodCount
        FROM Housing.AssignPeriod ap
        WHERE ap.IdaraId_FK = @IdaraId
          AND ap.WaitingClassID_FK = c.ClassID
          AND ap.AssignPeriodDescrption =
              CONCAT(N'Legacy allocation migration - WaitingClass ',c.ClassID)
    ) x
    WHERE x.PeriodCount <> 1;

    INSERT INTO #ValidationIssues
    (SectionName,IssueCode,TargetObject,ReferenceID,
     FieldName,ExpectedValue,ActualValue,Severity,Notes)
    SELECT
          N'WAITING_CLASS_PARITY'
        , N'UNEXPECTED_LEGACY_ASSIGN_PERIOD'
        , N'DATACORE.Housing.AssignPeriod'
        , CONVERT(nvarchar(100),ap.AssignPeriodID)
        , N'WaitingClassID_FK / AssignPeriodDescrption'
        , N'Legacy period for matching class 1-4'
        , CONCAT(COALESCE(CONVERT(nvarchar(30),ap.WaitingClassID_FK),N'<NULL>'),
                 N' / ',COALESCE(ap.AssignPeriodDescrption,N'<NULL>'))
        , 'ERROR'
        , N'Only 1-4 may have legacy allocation migration periods; names must match their class IDs.'
    FROM Housing.AssignPeriod ap
    WHERE ap.IdaraId_FK = @IdaraId
      AND ap.AssignPeriodDescrption LIKE N'Legacy allocation migration - WaitingClass %'
      AND (ap.WaitingClassID_FK NOT IN (1,2,3,4)
           OR ap.WaitingClassID_FK IS NULL
           OR ap.AssignPeriodDescrption <>
              CONCAT(N'Legacy allocation migration - WaitingClass ',ap.WaitingClassID_FK));

    -- Indirect AssignNote -> AssignPeriod integrity for this Idara.
    INSERT INTO #ValidationIssues
    (SectionName,IssueCode,TargetObject,ReferenceID,
     FieldName,ExpectedValue,ActualValue,Severity,Notes)
    SELECT
          N'WAITING_CLASS_PARITY'
        , N'ORPHAN_ASSIGN_NOTE_PERIOD'
        , N'DATACORE.Housing.AssignNote'
        , CONVERT(nvarchar(100),an.AssignNoteID)
        , N'AssignPeriodID_FK'
        , N'Existing AssignPeriod'
        , COALESCE(CONVERT(nvarchar(100),an.AssignPeriodID_FK),N'<NULL>')
        , 'ERROR'
        , N'An assignment note references a period missing from the migrated allocation workflow.'
    FROM Housing.AssignNote an
    WHERE an.IdaraID_FK = @IdaraId
      AND an.AssignPeriodID_FK IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1 FROM Housing.AssignPeriod ap
          WHERE ap.AssignPeriodID = an.AssignPeriodID_FK
      );

    -- BuildingAssign links to action 27 beneath waiting root 1.
    INSERT INTO #ValidationIssues
    (EntityKey,GeneralNo,SectionName,IssueCode,TargetObject,
     ReferenceID,FieldName,ExpectedValue,ActualValue,Severity,Notes)
    SELECT
          CASE WHEN TRY_CONVERT(bigint,ba.GeneralNo) IS NULL THEN NULL
               ELSE CONCAT(N'G:',TRY_CONVERT(bigint,ba.GeneralNo)) END
        , TRY_CONVERT(bigint,ba.GeneralNo)
        , N'WAITING_CLASS_PARITY'
        , N'ORPHAN_ASSIGNMENT_WAITING_CLASS'
        , N'DATACORE.Housing.BuildingAssign / BuildingAction'
        , CONVERT(nvarchar(100),ba.BuildingAssignID)
        , N'Effective WaitingClassID'
        , N'Existing active WaitingClass or virtual 99'
        , CONVERT(nvarchar(100),COALESCE(a.buildingActionExtraType1,r.buildingActionExtraType1))
        , 'ERROR'
        , N'An assignment beneath waiting root type 1 resolves to a missing/inactive class.'
    FROM Housing.BuildingAssign ba
    JOIN Housing.BuildingAction a
      ON a.buildingActionID = ba.BuildingActionID_FK
     AND a.buildingActionTypeID_FK = 27
    JOIN Housing.BuildingAction r
      ON r.buildingActionID = a.buildingActionParentID
     AND r.buildingActionTypeID_FK = 1
    WHERE (@GeneralNo IS NULL OR TRY_CONVERT(bigint,ba.GeneralNo) = @GeneralNo)
      AND COALESCE(a.buildingActionExtraType1,r.buildingActionExtraType1) IS NOT NULL
      AND COALESCE(a.buildingActionExtraType1,r.buildingActionExtraType1) <> 99
      AND NOT EXISTS
      (
          SELECT 1 FROM Housing.WaitingClass wc
          WHERE wc.waitingClassID = COALESCE(a.buildingActionExtraType1,r.buildingActionExtraType1)
            AND wc.waitingClassActive = 1
      );

    ------------------------------------------------------------
    -- 19. Build resident/entity result list
    ------------------------------------------------------------

    IF @GeneralNo IS NULL
    BEGIN
    /* MOVE 20261109: full, dynamic source parity; run after migration and before source deletion.
       No fixed population, payment or meter-read totals. Does not create or update data. */
    SELECT TRY_CONVERT(bigint, p.paymentID) AS PaymentID,
           p.PaymentUID,
           TRY_CONVERT(bigint,p.userID_FK) AS GeneralNo,
           p.amount,
           p.deductListID_FK,
           eligible.ResidentInfoID,
           CONVERT(bit,CASE WHEN eligible.ResidentInfoID IS NOT NULL
                        AND targetResident.residentInfoID IS NOT NULL
                        AND ISNULL(p.buildingPayementActive,0)=1
                        AND ISNULL(sourceList.deductActive,0)=1
                       THEN 1 ELSE 0 END) AS ExpectedActive
    INTO #MV_RentSourceFull
    FROM KFMC.Housing.BuildingPayment p
    LEFT JOIN KFMC.Housing.DeductList sourceList
      ON sourceList.deductListID=p.deductListID_FK
    LEFT JOIN #EligibleMigrationResidents eligible
      ON eligible.GeneralNo=TRY_CONVERT(bigint,p.userID_FK)
    LEFT JOIN Housing.ResidentInfo targetResident
      ON targetResident.residentInfoID=eligible.ResidentInfoID
     AND targetResident.residentInfoActive=1;

    CREATE UNIQUE CLUSTERED INDEX IX_MV_RentSourceFull ON #MV_RentSourceFull(PaymentID);

    SELECT s.PaymentID
    INTO #MV_RentMismatch
    FROM #MV_RentSourceFull s
    LEFT JOIN Housing.BuildingPayment t
      ON t.paymentID=s.PaymentID
    WHERE t.paymentID IS NULL
       OR EXISTS
       (
           SELECT t.PaymentUID,t.generalNo_FK,t.amount,t.deductListID_FK,
                  t.residentInfoID_FK,t.buildingPayementActive,t.BillChargeTypeID_FK
           EXCEPT
           SELECT s.PaymentUID,s.GeneralNo,s.amount,s.deductListID_FK,
                  s.ResidentInfoID,s.ExpectedActive,CONVERT(int,1)
       )
       OR (s.ExpectedActive=0
           AND (NULLIF(LTRIM(RTRIM(t.disactiveReason)),N'') IS NULL
                OR NOT EXISTS
                (
                  SELECT 1 FROM dbo.AuditLog audit
                  WHERE audit.TableName=N'[Housing].[BuildingPayment]'
                    AND audit.ActionType=N'MIGRATION_PAYMENT_PROTECTED'
                    AND audit.RecordID=s.PaymentID
                )));

    SELECT sourceRead.meterReadID AS MeterReadID
    INTO #MV_MissingMeterReads
    FROM KFMC.Housing.MeterRead sourceRead
    LEFT JOIN Housing.MeterRead targetRead
      ON targetRead.meterReadID=TRY_CONVERT(bigint,sourceRead.meterReadID)
    WHERE targetRead.meterReadID IS NULL;

    ;WITH IndependentRanked AS
    (
       SELECT b.BillsID,b.BillsUID,b.TotalPrice,b.meterReadID,b.BillActive,
              CASE WHEN ISNULL(b.BillActive,1)=1
                         AND b.PeriodYear=2024 AND b.PeriodMonth=10
                   THEN ROW_NUMBER() OVER
                   (
                      PARTITION BY b.generalNo_FK,b.buildingDetailsNo,b.PeriodYear,
                                   b.PeriodMonth,CAST(ISNULL(b.TotalPrice,0) AS decimal(18,2)),
                                   b.meterID,b.meterNo,b.meterReadID
                      ORDER BY CASE WHEN EXISTS
                      (
                          SELECT 1 FROM KFMC.Housing.BillsDeductListDetails d
                          WHERE d.billsID_FK=b.BillsID AND d.billPaid=1
                            AND d.paidAmount IS NOT NULL
                      ) THEN 1 ELSE 0 END DESC,b.BillsID
                   )
                   ELSE 1 END AS RowNo
       FROM KFMC.Housing.Bills b
       WHERE b.generalNo_FK IS NULL
    )
    SELECT b.BillsID
    INTO #MV_IndependentBillMismatch
    FROM IndependentRanked b
    LEFT JOIN Housing.Bills t
      ON t.BillsID=TRY_CONVERT(bigint,b.BillsID)
     AND t.BillChargeTypeID_FK=2
    WHERE (b.RowNo=1 AND
          (t.BillsID IS NULL OR t.generalNo_FK IS NOT NULL
           OR t.residentInfoID_FK IS NOT NULL OR EXISTS
           (
               SELECT t.BillsUID,t.TotalPrice,t.meterReadID
               EXCEPT
               SELECT b.BillsUID,b.TotalPrice,b.meterReadID
           )))
       OR (b.RowNo>1 AND t.BillsID IS NOT NULL);

    SELECT c.occupantCustodyActionID AS CustodyID,
           CONVERT(uniqueidentifier,HASHBYTES('MD5',
             CONCAT(N'PENALTY-PAYMENT|',c.occupantCustodyActionID))) AS PaymentUID,
           c.occupantCustodyActionPenalty AS Amount,
           TRY_CONVERT(bigint,sa.generalNo_FK) AS GeneralNo,
           eligible.residentInfoID AS EligibleResidentID,
           CONVERT(bit,CASE WHEN eligible.residentInfoID IS NOT NULL
                                  AND ISNULL(c.occupantCustodyActionActive,0)=1
                            THEN 1 ELSE 0 END) AS ExpectedActive
    INTO #MV_PaidPenalties
    FROM KFMC.Housing.OccupantCustodyAction c
    LEFT JOIN KFMC.Housing.BuildingAction sa ON sa.buildingActionID=c.buildingActionID_FK
    LEFT JOIN Housing.BuildingAction ta ON ta.buildingActionID=TRY_CONVERT(bigint,c.buildingActionID_FK)
    OUTER APPLY
    (
      SELECT TOP (1) tr.residentInfoID
      FROM KFMC.Housing.ResidentInfo sr
      JOIN Housing.ResidentInfo tr
        ON tr.residentInfoID=TRY_CONVERT(bigint,sr.residentInfoID)
       AND tr.residentInfoActive=1
      WHERE sr.generalNo=sa.generalNo_FK
        AND sr.residentInfoActive=1
        AND tr.residentInfoID=ta.residentInfoID_FK
      ORDER BY tr.residentInfoID
    ) eligible
    WHERE c.Paid=1;

    SELECT p.CustodyID
    INTO #MV_PenaltyPaymentMismatch
    FROM #MV_PaidPenalties p
    LEFT JOIN Housing.BuildingPayment t ON t.PaymentUID=p.PaymentUID
    WHERE t.paymentID IS NULL
       OR EXISTS
       (
         SELECT t.amount,t.generalNo_FK,t.residentInfoID_FK,
                t.BillChargeTypeID_FK,t.buildingPayementActive
         EXCEPT
         SELECT p.Amount,p.GeneralNo,p.EligibleResidentID,
                CONVERT(int,5),p.ExpectedActive
       )
       OR (p.ExpectedActive=0
           AND (NULLIF(LTRIM(RTRIM(t.disactiveReason)),N'') IS NULL
                OR NOT EXISTS
                (
                  SELECT 1 FROM dbo.AuditLog audit
                  WHERE audit.TableName=N'[Housing].[BuildingPayment]'
                    AND audit.ActionType=N'MIGRATION_PAYMENT_PROTECTED'
                    AND audit.RecordID=t.paymentID
                )));

    /* Global totals are independently derived from source rows; never infer
       success from the count of target rows alone. */

    IF EXISTS (SELECT 1 FROM #MV_RentMismatch)
       INSERT INTO #ValidationIssues
       (EntityKey,SectionName,IssueCode,SourceObject,TargetObject,ReferenceID,
        FieldName,ExpectedValue,ActualValue,Severity,Notes)
       SELECT N'GLOBAL:ALL_HISTORICAL_RENT_PAYMENT_MISMATCH',N'PAYMENTS',N'ALL_HISTORICAL_RENT_PAYMENT_MISMATCH',
              N'Migration source',N'Housing target',
              (SELECT CONVERT(nvarchar(100),MIN(PaymentID)) FROM #MV_RentMismatch),
              N'FailedSourceRows',N'0',CONVERT(nvarchar(100),COUNT_BIG(*)),
              'ERROR',N'Dynamic per-row migration parity failed. See #MV_RentMismatch and the source data.'
       FROM #MV_RentMismatch;

    IF EXISTS (SELECT 1 FROM #MV_MissingMeterReads)
       INSERT INTO #ValidationIssues
       (EntityKey,SectionName,IssueCode,SourceObject,TargetObject,ReferenceID,
        FieldName,ExpectedValue,ActualValue,Severity,Notes)
       SELECT N'GLOBAL:MISSING_HISTORICAL_METER_READ',N'METER_READS',N'MISSING_HISTORICAL_METER_READ',
              N'Migration source',N'Housing target',
              (SELECT CONVERT(nvarchar(100),MIN(MeterReadID)) FROM #MV_MissingMeterReads),
              N'FailedSourceRows',N'0',CONVERT(nvarchar(100),COUNT_BIG(*)),
              'ERROR',N'Dynamic per-row migration parity failed. See #MV_MissingMeterReads and the source data.'
       FROM #MV_MissingMeterReads;

    IF EXISTS (SELECT 1 FROM #MV_IndependentBillMismatch)
       INSERT INTO #ValidationIssues
       (EntityKey,SectionName,IssueCode,SourceObject,TargetObject,ReferenceID,
        FieldName,ExpectedValue,ActualValue,Severity,Notes)
       SELECT N'GLOBAL:INDEPENDENT_ELECTRICITY_BILL_MISMATCH',N'ELECTRICITY_CLAIMS',N'INDEPENDENT_ELECTRICITY_BILL_MISMATCH',
              N'Migration source',N'Housing target',
              (SELECT CONVERT(nvarchar(100),MIN(BillsID)) FROM #MV_IndependentBillMismatch),
              N'FailedSourceRows',N'0',CONVERT(nvarchar(100),COUNT_BIG(*)),
              'ERROR',N'Dynamic per-row migration parity failed. See #MV_IndependentBillMismatch and the source data.'
       FROM #MV_IndependentBillMismatch;

    IF EXISTS (SELECT 1 FROM #MV_PenaltyPaymentMismatch)
       INSERT INTO #ValidationIssues
       (EntityKey,SectionName,IssueCode,SourceObject,TargetObject,ReferenceID,
        FieldName,ExpectedValue,ActualValue,Severity,Notes)
       SELECT N'GLOBAL:PAID_PENALTY_MISMATCH',N'PAYMENTS',N'PAID_PENALTY_MISMATCH',
              N'Migration source',N'Housing target',
              (SELECT CONVERT(nvarchar(100),MIN(CustodyID)) FROM #MV_PenaltyPaymentMismatch),
              N'FailedSourceRows',N'0',CONVERT(nvarchar(100),COUNT_BIG(*)),
              'ERROR',N'Dynamic per-row migration parity failed. See #MV_PenaltyPaymentMismatch and the source data.'
       FROM #MV_PenaltyPaymentMismatch;
    END;

    CREATE TABLE #ResidentResults
    (
          EntityKey         NVARCHAR(100) NOT NULL
        , GeneralNo         BIGINT NULL
        , ResidentInfoID    BIGINT NULL
        , ResidentDetailsID BIGINT NULL
        , FullName          NVARCHAR(1000) NULL
    );


    INSERT INTO #ResidentResults
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
    )
    SELECT
          e.EntityKey
        , e.GeneralNo
        , e.SourceResidentInfoID
        , e.SourceResidentDetailsID
        , e.FullName
    FROM #ExpectedResidents e;


    /*
        Add entities which failed before they could become
        an expected resident row, or unexpected target rows.
    */
    INSERT INTO #ResidentResults
    (
          EntityKey
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName
    )
    SELECT
          i.EntityKey
        , MAX(i.GeneralNo)
        , MAX(i.ResidentInfoID)
        , MAX(i.ResidentDetailsID)
        , MAX(i.FullName)
    FROM #ValidationIssues i
    WHERE i.EntityKey IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM #ResidentResults r
          WHERE r.EntityKey = i.EntityKey
      )
    GROUP BY i.EntityKey;



    /* PHASE 62: independent building operational completion.
       Historical source parity stays unchanged. This runs only on active
       buildings of the selected Idara, never on unrelated departments. */
    ;WITH RankedKnown AS
    (
        SELECT a.buildingDetailsID_FK AS BuildingID,
               a.IdaraId_FK AS IdaraID,
               a.buildingActionID AS ExitActionID,
               a.buildingActionTypeID_FK AS ExitType,
               a.residentInfoID_FK AS ResidentID,
               a.entryDate,
               a.ExitDate,
               a.buildingActionDate,
               ROW_NUMBER() OVER
               (PARTITION BY a.buildingDetailsID_FK,a.IdaraId_FK
                ORDER BY a.entryDate DESC,a.buildingActionID DESC) AS rn
        FROM Housing.BuildingAction a
        WHERE a.IdaraId_FK=@IdaraId
          AND a.buildingDetailsID_FK IS NOT NULL
          AND a.buildingActionActive=1
          AND a.buildingActionTypeID_FK IS NOT NULL
          AND a.buildingActionTypeID_FK<>62
    )
    SELECT r.BuildingID,r.IdaraID,r.ExitActionID,r.ExitType,r.ResidentID
    INTO #V62Expected
    FROM RankedKnown r
    JOIN Housing.BuildingDetails b ON b.buildingDetailsID=r.BuildingID
                                 AND b.IdaraId_FK=r.IdaraID
    WHERE r.rn=1
      AND r.ExitType IN (57,58,3)
      AND r.ResidentID IS NOT NULL
      AND b.buildingDetailsActive=1
      AND NOT EXISTS
      (
          SELECT 1 FROM Housing.BuildingAction o
          WHERE o.buildingDetailsID_FK=r.BuildingID
            AND o.IdaraId_FK=r.IdaraID
            AND o.buildingActionActive=1
            AND o.buildingActionParentID IS NULL
            AND o.residentInfoID_FK IS NULL
            AND o.buildingActionTypeID_FK IN (4,5)
            AND EXISTS
            (
                SELECT 1
                FROM Housing.fn_BuildingAction_ChainToRoot(r.ExitActionID) fh
                WHERE fh.buildingActionTypeID_FK=57
                  AND fh.buildingActionActive=1
                  AND o.entryDate>fh.entryDate
            )
      )
      AND NOT EXISTS
      (
          SELECT 1 FROM Housing.BuildingAction occupied
          WHERE occupied.buildingDetailsID_FK=r.BuildingID
            AND occupied.IdaraId_FK=r.IdaraID
            AND occupied.buildingActionActive=1
            AND occupied.buildingActionTypeID_FK=2
            AND occupied.residentInfoID_FK IS NOT NULL
            AND occupied.residentInfoID_FK<>r.ResidentID
            AND
            (
                occupied.entryDate>r.entryDate
                OR COALESCE(TRY_CONVERT(datetime2(3),occupied.OccupentDate),
                            TRY_CONVERT(datetime2(3),occupied.buildingActionDate))
                   >
                   (SELECT MAX(COALESCE(TRY_CONVERT(datetime2(3),ea.ExitDate),
                                         TRY_CONVERT(datetime2(3),ea.buildingActionDate)))
                    FROM Housing.BuildingAction ea
                    WHERE ea.buildingDetailsID_FK=r.BuildingID
                      AND ea.IdaraId_FK=r.IdaraID
                      AND ea.residentInfoID_FK=r.ResidentID
                      AND ea.buildingActionActive=1
                      AND ea.buildingActionTypeID_FK IN (54,57,58,3)
                      AND ea.buildingActionID<=r.ExitActionID)
            )
      );

    SELECT a.buildingActionID AS Action62ID,
           a.buildingDetailsID_FK AS BuildingID,
           a.IdaraId_FK AS IdaraID,
           a.buildingStatusID_FK AS StatusID,
           a.residentInfoID_FK AS ResidentID,
           a.generalNo_FK AS GeneralNo,
           a.buildingActionParentID AS ParentID,
           a.buildingActionActive AS IsActive,
           a.buildingActionExtraText4 AS Marker,
           a.buildingActionNote AS NoteText
    INTO #V62Actual
    FROM Housing.BuildingAction a
    WHERE a.IdaraId_FK=@IdaraId
      AND a.buildingActionTypeID_FK=62
      AND a.buildingActionExtraText4=N'MoveData:FinalizeVacant62';


    IF @GeneralNo IS NULL
    BEGIN
        INSERT INTO #ValidationIssues
        (EntityKey,SectionName,IssueCode,SourceObject,TargetObject,
         ReferenceID,FieldName,ExpectedValue,ActualValue,Severity,Notes)
        SELECT CONCAT(N'B:',e.BuildingID),N'BUILDING_OPERATIONAL_62',
               N'MISSING_GENERATED_62',N'MoveData.usp_FinalizeVacantBuildingActions',
               N'Housing.BuildingAction',CONVERT(nvarchar(100),e.ExitActionID),
               N'buildingActionTypeID_FK',N'62',N'<MISSING>','ERROR',
               N'Eligible active building has no active generated 62 after the migration step.'
        FROM #V62Expected e
        WHERE NOT EXISTS
        (SELECT 1 FROM #V62Actual a
         WHERE a.BuildingID=e.BuildingID AND a.IdaraID=e.IdaraID AND a.IsActive=1);

        INSERT INTO #ValidationIssues
        (EntityKey,SectionName,IssueCode,TargetObject,ReferenceID,
         FieldName,ExpectedValue,ActualValue,Severity,Notes)
        SELECT CONCAT(N'B:',a.BuildingID),N'BUILDING_OPERATIONAL_62',
               N'INVALID_GENERATED_62_STRUCTURE',N'Housing.BuildingAction',
               CONVERT(nvarchar(100),a.Action62ID),N'OperationalRoot',
               N'Active=1;Status=2;Resident=NULL;GeneralNo=NULL;Parent=NULL',
               CONCAT(N'Active=',COALESCE(CONVERT(nvarchar(10),a.IsActive),N'NULL'),
                      N';Status=',COALESCE(CONVERT(nvarchar(10),a.StatusID),N'NULL')),
               'ERROR',N'Generated 62 does not satisfy the independent vacant building-root contract.'
        FROM #V62Actual a
        WHERE a.IsActive<>1 OR a.IsActive IS NULL
           OR a.StatusID<>2 OR a.StatusID IS NULL
           OR a.ResidentID IS NOT NULL OR a.GeneralNo IS NOT NULL
           OR a.ParentID IS NOT NULL OR a.BuildingID IS NULL;

        INSERT INTO #ValidationIssues
        (EntityKey,SectionName,IssueCode,TargetObject,ReferenceID,
         FieldName,ExpectedValue,ActualValue,Severity,Notes)
        SELECT CONCAT(N'B:',x.BuildingID),N'BUILDING_OPERATIONAL_62',
               N'DUPLICATE_GENERATED_62',N'Housing.BuildingAction',
               CONVERT(nvarchar(100),MIN(x.Action62ID)),N'Active62Count',
               N'1',CONVERT(nvarchar(100),COUNT_BIG(*)),'ERROR',
               N'Multiple active generated 62 actions for one building.'
        FROM #V62Actual x
        WHERE x.IsActive=1
        GROUP BY x.BuildingID,x.IdaraID
        HAVING COUNT_BIG(*)>1;

        INSERT INTO #ValidationIssues
        (EntityKey,SectionName,IssueCode,TargetObject,ReferenceID,
         FieldName,ExpectedValue,ActualValue,Severity,Notes)
        SELECT CONCAT(N'B:',a.BuildingID),N'BUILDING_OPERATIONAL_62',
               N'UNEXPECTED_GENERATED_62',N'Housing.BuildingAction',
               CONVERT(nvarchar(100),a.Action62ID),N'Eligibility',
               N'Eligible vacant after financial exit',N'Not eligible',
               'ERROR',N'Unexpected generated 62; review historical occupancy and operational cycles.'
        FROM #V62Actual a
        WHERE a.IsActive=1
          AND NOT EXISTS (SELECT 1 FROM #V62Expected e
                          WHERE e.BuildingID=a.BuildingID AND e.IdaraID=a.IdaraID)
          AND NOT EXISTS
          (SELECT 1 FROM Housing.BuildingAction newer
           WHERE newer.buildingDetailsID_FK=a.BuildingID
             AND newer.IdaraId_FK=a.IdaraID
             AND newer.buildingActionActive=1
             AND newer.buildingActionTypeID_FK IN (2,4,5,24,39)
             AND newer.entryDate>
                 (SELECT entryDate FROM Housing.BuildingAction original
                  WHERE original.buildingActionID=a.Action62ID));
    END;

    ------------------------------------------------------------
    -- RESULT SET 1
    -- GLOBAL SUMMARY
    ------------------------------------------------------------

    SELECT
          N'PHASE_8_FINAL_MIGRATION_CURRENT_ACTION_PARITY'
            AS ValidationPhase

        , @IdaraId AS EffectiveIdaraId
        , @GeneralNo AS RequestedGeneralNo

        ,CASE
    WHEN @GeneralNo IS NULL
        THEN N'ALL_ELIGIBLE_RESIDENTS'

    WHEN EXISTS
    (
        SELECT 1
        FROM #EligibleMigrationResidents e
        WHERE e.GeneralNo = @GeneralNo
    )
    AND NOT EXISTS
    (
        SELECT 1
        FROM #SelectedResidentDetails d
        WHERE TRY_CONVERT(BIGINT, d.generalNo_FK) = @GeneralNo
    )
        THEN N'ELIGIBLE_WITHOUT_RESIDENTDETAILS'

    WHEN EXISTS
    (
        SELECT 1
        FROM #ExpectedResidents e
        WHERE e.GeneralNo = @GeneralNo
    )
        THEN N'ELIGIBLE'

    WHEN EXISTS
    (
        SELECT 1
        FROM #EligibleMigrationResidents e
        WHERE e.GeneralNo = @GeneralNo
    )
        THEN N'SOURCE_MAPPING_ERROR'

    WHEN EXISTS
    (
        SELECT 1
        FROM KFMC.Housing.ResidentInfo r
        WHERE TRY_CONVERT(BIGINT, r.generalNo) = @GeneralNo
    )
        THEN N'EXCLUDED_BY_MIGRATION_POLICY'

    ELSE N'NOT_FOUND_IN_KFMC'
END AS ScopeStatus

        , (
            SELECT COUNT_BIG(*)
            FROM KFMC.Housing.ResidentInfo r
            WHERE
                @GeneralNo IS NULL
                OR TRY_CONVERT(BIGINT, r.generalNo) = @GeneralNo
          ) AS SourceResidentInfoRows

        , (
            SELECT COUNT_BIG(*)
            FROM KFMC.Housing.ResidentInfo r
            WHERE
                (
                    @GeneralNo IS NULL
                    OR TRY_CONVERT(BIGINT, r.generalNo) = @GeneralNo
                )
                AND NOT EXISTS
                (
                    SELECT 1
                    FROM KFMC.Housing.ResidentDetails d
                    WHERE TRY_CONVERT(BIGINT, d.generalNo_FK)
                        = TRY_CONVERT(BIGINT, r.generalNo)
                )
          ) AS SourceResidentInfoExcludedNoDetails

        , (
            SELECT COUNT_BIG(*)
            FROM #SelectedResidentDetails d
            WHERE
                @GeneralNo IS NULL
                OR TRY_CONVERT(BIGINT, d.generalNo_FK) = @GeneralNo
          ) AS SelectedResidentDetailsRows

        , (
    SELECT COUNT_BIG(*)
    FROM #EligibleMigrationResidents e
    WHERE @GeneralNo IS NULL
       OR e.GeneralNo = @GeneralNo
) AS EligibleResidentsExpected

        , (
            SELECT COUNT_BIG(DISTINCT i.EntityKey)
            FROM #ValidationIssues i
            WHERE i.Severity = 'ERROR'
              AND i.EntityKey IS NOT NULL
          ) AS FailedEntities

        , (
            SELECT COUNT_BIG(*)
            FROM #ValidationIssues i
            WHERE i.Severity = 'ERROR'
          ) AS FailureRows

                  , (
            SELECT COUNT_BIG(*)
            FROM #ExpectedContacts
          ) AS ExpectedResidentContactRows

        , (
            SELECT COUNT_BIG(*)
            FROM #ActualContacts
          ) AS ActualResidentContactRows

        , (
            SELECT COUNT_BIG(*)
            FROM #ValidationIssues i
            WHERE i.SectionName = N'RESIDENT_CONTACTS'
              AND i.Severity = 'ERROR'
          ) AS ResidentContactFailureRows


                  , (
            SELECT COUNT_BIG(*)
            FROM #FV_ExpectedSourceActions
          ) AS ExpectedSourceActionRows

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_DuplicateActionMap
          ) AS ExpectedDuplicateActionsExcluded

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_ExpectedGeneratedActions
          ) AS ExpectedGeneratedActionRows

        , (
            SELECT COUNT_BIG(*)
            FROM #ValidationIssues
            WHERE SectionName = N'ACTIONS'
              AND Severity = 'ERROR'
          ) AS ActionFailureRows

        , (
            SELECT COUNT_BIG(DISTINCT EntityKey)
            FROM #ValidationIssues
            WHERE SectionName = N'ACTIONS'
              AND Severity = 'ERROR'
          ) AS ResidentsWithActionFailures

                  , (
            SELECT COUNT_BIG(*)
            FROM #FV_ExpectedElectricBills
          ) AS ExpectedElectricityClaims

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_ExpectedHistoricalResidentBills
            WHERE ChargeTypeID = 1
          ) AS ExpectedRentClaims

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_ExpectedHistoricalResidentBills
            WHERE ChargeTypeID = 3
          ) AS ExpectedResidentWaterClaims

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_ExpectedPenaltyBills
          ) AS ExpectedPenaltyClaims

        , (
            SELECT COUNT_BIG(*)
            FROM #ValidationIssues
            WHERE SectionName IN
                  (
                      N'ELECTRICITY_CLAIMS',
                      N'RENT_CLAIMS',
                      N'WATER_CLAIMS',
                      N'PENALTY_CLAIMS'
                  )
              AND Severity = 'ERROR'
          ) AS ClaimFailureRows

        , (
            SELECT COUNT_BIG(DISTINCT EntityKey)
            FROM #ValidationIssues
            WHERE SectionName IN
                  (
                      N'ELECTRICITY_CLAIMS',
                      N'RENT_CLAIMS',
                      N'WATER_CLAIMS',
                      N'PENALTY_CLAIMS'
                  )
              AND Severity = 'ERROR'
          ) AS ResidentsWithClaimFailures

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_ExpectedRentPayments
          ) AS ExpectedRentPaymentRows

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_ExpectedElectricPayments
          ) AS ExpectedElectricityPaymentRows

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_ExpectedPenaltyPayments
          ) AS ExpectedPenaltyPaymentRows

        , (
            SELECT COUNT_BIG(*)
            FROM #ValidationIssues
            WHERE SectionName = N'PAYMENTS'
              AND Severity = 'ERROR'
          ) AS PaymentFailureRows

        , (
            SELECT COUNT_BIG(*)
            FROM #ValidationIssues
            WHERE SectionName = N'PAYMENT_TYPES'
              AND Severity = 'ERROR'
          ) AS PaymentTypeFailureRows

        , (
            SELECT COUNT_BIG(DISTINCT EntityKey)
            FROM #ValidationIssues
            WHERE SectionName IN
                  (
                      N'PAYMENTS',
                      N'PAYMENT_TYPES'
                  )
              AND Severity = 'ERROR'
          ) AS ResidentsWithPaymentFailures


        , (
            SELECT COUNT_BIG(*)
            FROM #ValidationIssues
            WHERE SectionName = N'PAYMENT_LINKS'
              AND Severity = 'ERROR'
          ) AS PaymentLinkFailureRows

        , (
            SELECT COUNT_BIG(*)
            FROM #ValidationIssues
            WHERE SectionName = N'PAYMENT_LINK_STATUS'
              AND Severity = 'ERROR'
          ) AS PaymentLinkStatusFailureRows

        , (
            SELECT COUNT_BIG(DISTINCT EntityKey)
            FROM #ValidationIssues
            WHERE SectionName IN
                  (
                      N'PAYMENT_LINKS',
                      N'PAYMENT_LINK_STATUS'
                  )
              AND Severity = 'ERROR'
          ) AS ResidentsWithPaymentLinkFailures

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_ExpectedFinancialClaims
          ) AS ExpectedFinancialClaimRows

        , (
            SELECT ISNULL(SUM(Amount), 0)
            FROM #FV_ExpectedFinancialClaims
          ) AS ExpectedFinancialClaims

        , (
            SELECT ISNULL(SUM(ClaimRows), 0)
            FROM #FV_ActualFinancialClaimAgg
          ) AS ActualFinancialClaimRows

        , (
            SELECT ISNULL(SUM(ClaimAmount), 0)
            FROM #FV_ActualFinancialClaimAgg
          ) AS ActualFinancialClaims

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_ExpectedFinancialPayments
          ) AS ExpectedEligiblePaymentRows

        , (
            SELECT ISNULL(SUM(Amount), 0)
            FROM #FV_ExpectedFinancialPayments
          ) AS ExpectedEligiblePayments

        , (
            SELECT ISNULL(SUM(PaymentRows), 0)
            FROM #FV_ActualFinancialPaymentAgg
          ) AS ActualEligiblePaymentRows

        , (
            SELECT ISNULL(SUM(PaymentAmount), 0)
            FROM #FV_ActualFinancialPaymentAgg
          ) AS ActualEligiblePayments

        , (
            SELECT ISNULL(SUM(FinalBalance), 0)
            FROM #FV_FinancialResident
          ) AS NetOutstandingBalance

        , (
            SELECT COUNT_BIG(*)
            FROM #ValidationIssues
            WHERE SectionName = N'FINANCIAL_RECONCILIATION'
              AND Severity = 'ERROR'
          ) AS FinancialReconciliationFailureRows

        , (
            SELECT COUNT_BIG(DISTINCT EntityKey)
            FROM #ValidationIssues
            WHERE SectionName = N'FINANCIAL_RECONCILIATION'
              AND Severity = 'ERROR'
          ) AS ResidentsWithFinancialReconciliationFailures

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_FinancialResident
            WHERE ClaimRows > 0 OR PaymentRows > 0
          ) AS ResidentsWithFinancialMovement

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_FinancialResident
            WHERE ClaimRows > 0 AND PaymentRows = 0
          ) AS ClaimsOnlyResidents

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_FinancialResident
            WHERE ClaimRows = 0 AND PaymentRows > 0
          ) AS PaymentsOnlyResidents

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_FinancialResident
            WHERE ClaimRows > 0 AND PaymentRows > 0
          ) AS ClaimsAndPaymentsResidents

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_FinancialResident
            WHERE (ClaimRows > 0 OR PaymentRows > 0)
              AND FinalBalance = 0
          ) AS BalancedResidents

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_FinancialResident
            WHERE FinalBalance > 0
          ) AS DeficitResidents

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_FinancialResident
            WHERE FinalBalance < 0
          ) AS SurplusResidents

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_CurrentPairAudit
          ) AS ResidentBuildingPairs

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_CurrentPairAudit
            WHERE ISNULL(RawKFMC_LastActionID,-1)
                  <> ISNULL(SourceActionID,-1)
          ) AS RawLastChangedByApprovedMigrationRules

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_CurrentPairAudit
            WHERE PairStatus = N'MATCH_SOURCE_CURRENT'
          ) AS ExactCurrentSourceMatches

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_CurrentPairAudit
            WHERE PairStatus = N'EXPECTED_GENERATED_SUCCESSOR'
          ) AS ExpectedGeneratedCurrentPairs

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_CurrentPairAudit
            WHERE PairStatus IN
                  (
                      N'MISSING_PRESERVED_SOURCE_ACTION',
                      N'WRONG_LAST_PRESERVED_SOURCE_ACTION',
                      N'WRONG_TRANSFORMED_ACTION_TYPE',
                      N'CURRENT_ACTION_MISMATCH'
                  )
          ) AS ResidentBuildingCurrentMismatches

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_BuildingCurrentAudit
          ) AS BuildingsChecked

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_BuildingCurrentAudit
            WHERE CurrentBuildingStatus = N'MATCH'
          ) AS MatchingCurrentActions

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_BuildingCurrentAudit
            WHERE CurrentBuildingStatus = N'EXCLUDED_BY_VIEW_FILTER'
          ) AS BuildingsWithNoAction

        , (
            SELECT COUNT_BIG(*)
            FROM #FV_BuildingCurrentAudit
            WHERE CurrentBuildingStatus = N'MISMATCH'
          ) AS CurrentBuildingActionMismatches

        , (
            SELECT COUNT_BIG(*)
            FROM #ValidationIssues
            WHERE SectionName = N'CURRENT_ACTION_PARITY'
              AND Severity = 'ERROR'
          ) AS CurrentActionParityFailureRows

        , (
            SELECT COUNT_BIG(DISTINCT EntityKey)
            FROM #ValidationIssues
            WHERE SectionName = N'CURRENT_ACTION_PARITY'
              AND Severity = 'ERROR'
              AND EntityKey IS NOT NULL
          ) AS ResidentsWithCurrentActionParityFailures


        , CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues
                       WHERE Severity = 'ERROR'
                   )
                  THEN 'FAIL'

              WHEN @GeneralNo IS NULL
                  THEN 'PASS'

              ELSE 'PASS_SCOPE_ONLY'
          END AS OverallResult

        , CASE
              WHEN @GeneralNo IS NULL
               AND NOT EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues
                       WHERE Severity = 'ERROR'
                   )
                  THEN CAST(1 AS BIT)
              ELSE CAST(0 AS BIT)
          END AS IsFinalCutoverGateReady

        , CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues
                       WHERE Severity = 'ERROR'
                   )
                  THEN N'Validation failures must be resolved before the final cutover gate can open.'

              WHEN @GeneralNo IS NOT NULL
                  THEN N'Full-population execution (@GeneralNo = NULL) is required for the final cutover gate.'

              ELSE NULL
          END AS RemainingValidationScope


    ------------------------------------------------------------
    -- RESULT SET 2
    -- RESIDENT / ENTITY STATUS
    ------------------------------------------------------------

    SELECT
          r.GeneralNo
        , r.ResidentInfoID
        , r.ResidentDetailsID
        , r.FullName

        , CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues i
                       WHERE i.EntityKey = r.EntityKey
                         AND i.SectionName = N'POPULATION'
                         AND i.Severity = 'ERROR'
                   )
                  THEN 'FAIL'
              ELSE 'PASS'
          END AS PopulationStatus

        , CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues i
                       WHERE i.EntityKey = r.EntityKey
                         AND i.SectionName = N'RESIDENT_DATA'
                         AND i.Severity = 'ERROR'
                   )
                  THEN 'FAIL'
              ELSE 'PASS'
          END AS ResidentDataStatus

                  , CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues i
                       WHERE i.EntityKey = r.EntityKey
                         AND i.SectionName = N'RESIDENT_CONTACTS'
                         AND i.Severity = 'ERROR'
                   )
                  THEN 'FAIL'
              ELSE 'PASS'
          END AS ContactsStatus

                  , CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues i
                       WHERE i.EntityKey = r.EntityKey
                         AND i.SectionName = N'ACTIONS'
                         AND i.Severity = 'ERROR'
                   )
                  THEN 'FAIL'
              ELSE 'PASS'
          END AS ActionsStatus

                  , CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues i
                       WHERE i.EntityKey = r.EntityKey
                         AND i.SectionName = N'ELECTRICITY_CLAIMS'
                         AND i.Severity = 'ERROR'
                   )
                  THEN 'FAIL'
              ELSE 'PASS'
          END AS ElectricityClaimsStatus

        , CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues i
                       WHERE i.EntityKey = r.EntityKey
                         AND i.SectionName = N'RENT_CLAIMS'
                         AND i.Severity = 'ERROR'
                   )
                  THEN 'FAIL'
              ELSE 'PASS'
          END AS RentClaimsStatus

        , CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues i
                       WHERE i.EntityKey = r.EntityKey
                         AND i.SectionName = N'WATER_CLAIMS'
                         AND i.Severity = 'ERROR'
                   )
                  THEN 'FAIL'
              ELSE 'PASS'
          END AS WaterClaimsStatus

        , CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues i
                       WHERE i.EntityKey = r.EntityKey
                         AND i.SectionName = N'PENALTY_CLAIMS'
                         AND i.Severity = 'ERROR'
                   )
                  THEN 'FAIL'
              ELSE 'PASS'
          END AS PenaltyClaimsStatus

        , CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues i
                       WHERE i.EntityKey = r.EntityKey
                         AND i.SectionName IN
                             (
                                 N'ELECTRICITY_CLAIMS',
                                 N'RENT_CLAIMS',
                                 N'WATER_CLAIMS',
                                 N'PENALTY_CLAIMS'
                             )
                         AND i.Severity = 'ERROR'
                   )
                  THEN 'FAIL'
              ELSE 'PASS'
          END AS ClaimsStatus

        , CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues i
                       WHERE i.EntityKey = r.EntityKey
                         AND i.SectionName IN
                             (
                                 N'PAYMENTS',
                                 N'PAYMENT_TYPES'
                             )
                         AND i.Severity = 'ERROR'
                   )
                  THEN 'FAIL'
              ELSE 'PASS'
          END AS PaymentsStatus

        , CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues i
                       WHERE i.EntityKey = r.EntityKey
                         AND i.SectionName IN
                             (
                                 N'PAYMENT_LINKS',
                                 N'PAYMENT_LINK_STATUS'
                             )
                         AND i.Severity = 'ERROR'
                   )
                  THEN 'FAIL'
              ELSE 'PASS'
          END AS PaymentLinksStatus

        , CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues i
                       WHERE i.EntityKey = r.EntityKey
                         AND i.SectionName = N'FINANCIAL_RECONCILIATION'
                         AND i.Severity = 'ERROR'
                   )
                  THEN 'FAIL'
              ELSE 'PASS'
          END AS FinancialReconciliationStatus

        , CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues i
                       WHERE i.EntityKey = r.EntityKey
                         AND i.SectionName = N'CURRENT_ACTION_PARITY'
                         AND i.Severity = 'ERROR'
                   )
                  THEN 'FAIL'
              ELSE 'PASS'
          END AS CurrentActionParityStatus

        , f.ClaimRows
        , f.ClaimAmount
        , f.PaymentRows AS EligiblePaymentRows
        , f.PaymentAmount AS EligiblePaymentAmount
        , f.FinalBalance

        , CASE
              WHEN f.EntityKey IS NULL
                  THEN N'NOT_AVAILABLE'
              WHEN f.ClaimRows = 0 AND f.PaymentRows = 0
                  THEN N'NO_FINANCIAL_MOVEMENT'
              WHEN f.FinalBalance > 0
                  THEN N'DEFICIT'
              WHEN f.FinalBalance < 0
                  THEN N'SURPLUS'
              ELSE N'BALANCED'
          END AS FinancialState

        , (
            SELECT COUNT_BIG(*)
            FROM #ValidationIssues i
            WHERE i.EntityKey = r.EntityKey
              AND i.Severity = 'ERROR'
          ) AS FailureCount

        , CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues i
                       WHERE i.EntityKey = r.EntityKey
                         AND i.Severity = 'ERROR'
                   )
                  THEN 'FAIL'
              ELSE 'PASS'
          END AS FinalResidentStatus

    FROM #ResidentResults r

    LEFT JOIN #FV_FinancialResident f
        ON f.EntityKey = r.EntityKey

    WHERE
        @OnlyFailures = 0

        OR EXISTS
           (
               SELECT 1
               FROM #ValidationIssues i
               WHERE i.EntityKey = r.EntityKey
                 AND i.Severity = 'ERROR'
           )

    ORDER BY
          CASE
              WHEN EXISTS
                   (
                       SELECT 1
                       FROM #ValidationIssues i
                       WHERE i.EntityKey = r.EntityKey
                         AND i.Severity = 'ERROR'
                   )
                  THEN 0
              ELSE 1
          END
        , r.GeneralNo
        , r.ResidentInfoID;


    ------------------------------------------------------------
    -- RESULT SET 3
    -- EXACT FAILURE DETAILS
    ------------------------------------------------------------

    SELECT
          FailureID
        , GeneralNo
        , ResidentInfoID
        , ResidentDetailsID
        , FullName

        , SectionName
        , IssueCode

        , SourceObject
        , TargetObject
        , ReferenceID
        , FieldName

        , ExpectedValue
        , ActualValue

        , Severity
        , Notes

    FROM #ValidationIssues

    WHERE
        @OnlyFailures = 0
        OR Severity = 'ERROR'

    ORDER BY
          GeneralNo
        , ResidentInfoID
        , SectionName
        , FailureID;


    ------------------------------------------------------------
    -- RESULT SET 4
    -- FAILURE SUMMARY BY SECTION
    ------------------------------------------------------------

    ;WITH RequiredSections AS
(
    SELECT N'POPULATION' AS SectionName

    UNION ALL
    SELECT N'RESIDENT_DATA'

    UNION ALL
    SELECT N'RESIDENT_CONTACTS'

    UNION ALL
    SELECT N'ACTIONS'

    UNION ALL
    SELECT N'ELECTRICITY_CLAIMS'

    UNION ALL
    SELECT N'RENT_CLAIMS'

    UNION ALL
    SELECT N'WATER_CLAIMS'

    UNION ALL
    SELECT N'PENALTY_CLAIMS'

    UNION ALL
    SELECT N'PAYMENTS'

    UNION ALL
    SELECT N'PAYMENT_TYPES'

    UNION ALL
    SELECT N'PAYMENT_LINKS'

    UNION ALL
    SELECT N'PAYMENT_LINK_STATUS'

    UNION ALL
    SELECT N'FINANCIAL_RECONCILIATION'

    UNION ALL
    SELECT N'BUILDING_OPERATIONAL_62'

    UNION ALL
    SELECT N'CURRENT_ACTION_PARITY'

    UNION ALL
    SELECT N'WAITING_CLASS_PARITY'
),
    SectionFailures AS
    (
        SELECT
              i.SectionName
            , COUNT_BIG(*) AS FailureRows
            , COUNT_BIG(DISTINCT i.EntityKey)
                AS FailedResidents
        FROM #ValidationIssues i
        WHERE i.Severity = 'ERROR'
        GROUP BY i.SectionName
    )
    SELECT
          summary.SectionName
        , summary.FailedResidents
        , summary.FailureRows
        , summary.SectionResult
    FROM
    (
        SELECT
              s.SectionName

            , ISNULL(f.FailedResidents, 0)
                AS FailedResidents

            , ISNULL(f.FailureRows, 0)
                AS FailureRows

            , CASE
                  WHEN ISNULL(f.FailureRows, 0) = 0
                      THEN 'PASS'
                  ELSE 'FAIL'
              END AS SectionResult

        FROM RequiredSections s

        LEFT JOIN SectionFailures f
            ON f.SectionName = s.SectionName

        UNION ALL

        SELECT
              N'FINAL_RESIDENT'

            , (
                SELECT COUNT_BIG(*)
                FROM #ResidentResults r
                WHERE EXISTS
                      (
                          SELECT 1
                          FROM #ValidationIssues i
                          WHERE i.EntityKey = r.EntityKey
                            AND i.Severity = 'ERROR'
                      )
              ) AS FailedResidents

            , (
                SELECT COUNT_BIG(*)
                FROM #ResidentResults r
                WHERE EXISTS
                      (
                          SELECT 1
                          FROM #ValidationIssues i
                          WHERE i.EntityKey = r.EntityKey
                            AND i.Severity = 'ERROR'
                      )
              ) AS FailureRows

            , CASE
                  WHEN EXISTS
                       (
                           SELECT 1
                           FROM #ResidentResults rr
                           WHERE EXISTS
                                 (
                                     SELECT 1
                                     FROM #ValidationIssues i
                                     WHERE i.EntityKey = rr.EntityKey
                                       AND i.Severity = 'ERROR'
                                 )
                       )
                      THEN 'FAIL'
                  ELSE 'PASS'
              END AS SectionResult
    ) summary
    ORDER BY summary.SectionName;


    ------------------------------------------------------------
    -- Fail hard when requested
    --
    -- Results above are intentionally returned BEFORE THROW
    -- so the exact causes remain visible in SSMS.
    ------------------------------------------------------------

    IF @FailOnMismatch = 1
       AND EXISTS
       (
           SELECT 1
           FROM #ValidationIssues
           WHERE Severity = 'ERROR'
       )
    BEGIN
        THROW 59990,
              N'Final resident migration validation failed. Review the returned failure details before cutover.',
              1;
    END;

END;

GO

