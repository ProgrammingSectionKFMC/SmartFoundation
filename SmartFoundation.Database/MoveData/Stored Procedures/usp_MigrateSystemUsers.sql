CREATE PROCEDURE [MoveData].[usp_MigrateSystemUsers]
    @IdaraId int = 1,
    @DepartmentId int = NULL,
    @DefaultPassword nvarchar(200),
    @RollbackAfterTest bit = 1,
    @RequireUsersSPFields bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    /* Normalize migration administration: preserve a valid supplied value, otherwise use Idara 1. */
    IF NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID = 1)
        THROW 57990, N'Default migration Idara 1 does not exist.', 1;
    IF @IdaraId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID = @IdaraId)
        SET @IdaraId = 1;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID = @IdaraId)
        THROW 51700, N'The supplied IdaraId does not exist.', 1;

    IF NULLIF(@DefaultPassword, N'') IS NULL
        THROW 51701, N'DefaultPassword is required.', 1;

    IF LEN(@DefaultPassword) < 8
       OR @DefaultPassword COLLATE Latin1_General_100_BIN2 NOT LIKE '%[A-Z]%'
       OR @DefaultPassword COLLATE Latin1_General_100_BIN2 NOT LIKE '%[a-z]%'
        THROW 51702, N'DefaultPassword must contain at least 8 characters, one uppercase English letter, and one lowercase English letter.', 1;

    IF @DepartmentId IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.V_GetFullStructureForDSD structureRow
           WHERE structureRow.DepartmentID = @DepartmentId
             AND structureRow.IdaraID = @IdaraId
       )
        THROW 51710, N'The supplied DepartmentId does not exist, is inactive, or does not belong to the supplied IdaraId.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.MaritalStatus WHERE maritalStatusID = 1)
        THROW 51711, N'Default MaritalStatus ID 1 does not exist in DATACORE.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Education WHERE educationID = 1)
        THROW 51712, N'Default Education ID 1 does not exist in DATACORE.', 1;

    IF OBJECT_ID('tempdb..#TargetPrograms') IS NOT NULL DROP TABLE #TargetPrograms;
    IF OBJECT_ID('tempdb..#DistinctMenus') IS NOT NULL DROP TABLE #DistinctMenus;
    IF OBJECT_ID('tempdb..#MenuDistributors') IS NOT NULL DROP TABLE #MenuDistributors;
    IF OBJECT_ID('tempdb..#PermissionUsers') IS NOT NULL DROP TABLE #PermissionUsers;
    IF OBJECT_ID('tempdb..#CandidateUsers') IS NOT NULL DROP TABLE #CandidateUsers;
    IF OBJECT_ID('tempdb..#SkippedExistingUsers') IS NOT NULL DROP TABLE #SkippedExistingUsers;
    IF OBJECT_ID('tempdb..#UserMap') IS NOT NULL DROP TABLE #UserMap;
    IF OBJECT_ID('tempdb..#CandidateDistributors') IS NOT NULL DROP TABLE #CandidateDistributors;
    IF OBJECT_ID('tempdb..#CandidateUserDistributors') IS NOT NULL DROP TABLE #CandidateUserDistributors;
    IF OBJECT_ID('tempdb..#DistributorMap') IS NOT NULL DROP TABLE #DistributorMap;

    SELECT programID
    INTO #TargetPrograms
    FROM KFMC.dbo.Program
    WHERE programID IN (7, 9, 13);

    ;WITH ProgramMenus AS
    (
        SELECT
            menuID,
            parentMenuID_FK,
            programID_FK,
            CAST(0 AS int) AS MenuLevel
        FROM KFMC.dbo.Menu
        WHERE programID_FK IN (SELECT programID FROM #TargetPrograms)

        UNION ALL

        SELECT
            child.menuID,
            child.parentMenuID_FK,
            child.programID_FK,
            parent.MenuLevel + 1
        FROM KFMC.dbo.Menu child
        JOIN ProgramMenus parent
          ON child.parentMenuID_FK = parent.menuID
    )
    SELECT DISTINCT
        menuID,
        parentMenuID_FK,
        programID_FK,
        MenuLevel
    INTO #DistinctMenus
    FROM ProgramMenus
    OPTION (MAXRECURSION 0);

    SELECT
        md.menuDistributorID,
        md.menuID_FK,
        md.distributorID_FK,
        md.roleID_FK,
        md.userID_FK,
        md.isDenied,
        md.menuDistributorActive
    INTO #MenuDistributors
    FROM KFMC.dbo.MenuDistributor md
    JOIN #DistinctMenus m
      ON m.menuID = md.menuID_FK;

    CREATE TABLE #PermissionUsers
    (
        GeneralNo int NOT NULL PRIMARY KEY
    );

    INSERT INTO #PermissionUsers (GeneralNo)
    SELECT DISTINCT md.userID_FK
    FROM #MenuDistributors md
    WHERE md.userID_FK IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM #PermissionUsers pu WHERE pu.GeneralNo = md.userID_FK);

    INSERT INTO #PermissionUsers (GeneralNo)
    SELECT DISTINCT ud.userID_FK
    FROM KFMC.dbo.UserDistributor ud
    JOIN #MenuDistributors md
      ON md.distributorID_FK = ud.distributorID_FK
    WHERE ud.userID_FK IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM #PermissionUsers pu WHERE pu.GeneralNo = ud.userID_FK);

    SELECT DISTINCT
        oldUser.ID_ AS OldUserRowID,
        oldUser.userID AS GeneralNo,
        oldUser.userTypeID_FK,
        oldUser.fristName_A,
        oldUser.secondName_A,
        oldUser.thirdName_A,
        oldUser.forthName_A,
        oldUser.lastName_A,
        oldUser.fristName_E,
        oldUser.secondName_E,
        oldUser.thirdName_E,
        oldUser.forthName_E,
        oldUser.lastName_E,
        oldUser.IDNumber,
        oldUser.IDIssueDate,
        oldUser.IDExpiryDate,
        oldUser.IDIssuePlaceCityID_FK,
        oldUser.dateOfBirth,
        oldUser.birthPlaceCityID_FK,
        oldUser.genderID_FK,
        oldUser.nationalityID_FK,
        oldUser.religionID_FK,
        oldUser.bloodID_FK,
        oldUser.maritalStatusID_FK,
        oldUser.educationID_FK,
        oldUser.userNote,
        oldUser.entryDate,
        oldUser.entryData,
        oldUser.hostName
    INTO #CandidateUsers
    FROM #PermissionUsers pu
    JOIN KFMC.dbo.[User] oldUser
      ON oldUser.userID = pu.GeneralNo;

    /* Optional department scope.  Every DSD row below a department carries
       the same DepartmentID in V_GetFullStructureForDSD, so this includes the
       department itself, all sections, and all divisions beneath it. */
    IF @DepartmentId IS NOT NULL
    BEGIN
        DELETE candidateUser
        FROM #CandidateUsers candidateUser
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM KFMC.dbo.UserDistributor sourceUD
            JOIN KFMC.dbo.Distributor sourceDistributor
              ON sourceDistributor.distributorID = sourceUD.distributorID_FK
            JOIN dbo.V_GetFullStructureForDSD structureRow
              ON structureRow.DSDID = CONVERT(bigint, sourceDistributor.DSDID_FK)
            WHERE sourceUD.userID_FK = candidateUser.GeneralNo
              AND sourceDistributor.distributorType_FK = 1
              AND ISNULL(sourceDistributor.distributorActive, 0) = 1
              AND ISNULL(sourceUD.UDActive, 0) = 1
              AND sourceUD.UDStartDate IS NOT NULL
              AND CONVERT(date, sourceUD.UDStartDate) <= CONVERT(date, GETDATE())
              AND sourceUD.UDEndDate IS NULL
              AND structureRow.IdaraID = @IdaraId
              AND structureRow.DepartmentID = @DepartmentId
        );
    END;

    /* Never touch a user that is already known to DATACORE.  A match by
       either national ID or GeneralNo is enough, even when the old target
       account is inactive. */
    SELECT
        candidateUser.GeneralNo,
        candidateUser.IDNumber,
        CASE
            WHEN EXISTS
                 (
                     SELECT 1
                     FROM dbo.Users targetUser
                     WHERE targetUser.nationalID = candidateUser.IDNumber
                 ) THEN N'NationalID'
            ELSE N'GeneralNo'
        END AS ExistingMatch
    INTO #SkippedExistingUsers
    FROM #CandidateUsers candidateUser
    WHERE EXISTS
          (
              SELECT 1
              FROM dbo.Users targetUser
              WHERE targetUser.nationalID = candidateUser.IDNumber
          )
       OR EXISTS
          (
              SELECT 1
              FROM dbo.UsersDetails targetDetails
              WHERE TRY_CONVERT(bigint, targetDetails.GeneralNo) = CONVERT(bigint, candidateUser.GeneralNo)
          );

    DELETE candidateUser
    FROM #CandidateUsers candidateUser
    WHERE EXISTS
          (
              SELECT 1
              FROM #SkippedExistingUsers skippedUser
              WHERE skippedUser.GeneralNo = candidateUser.GeneralNo
          );

    IF EXISTS (SELECT 1 FROM #CandidateUsers WHERE NULLIF(LTRIM(RTRIM(IDNumber)), N'') IS NULL)
        THROW 51702, N'Cannot migrate users: one or more source users has an empty IDNumber.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM #CandidateUsers
        GROUP BY IDNumber
        HAVING COUNT_BIG(*) > 1
    )
        THROW 51703, N'Cannot migrate users: duplicate IDNumber values found among candidate users.', 1;

    /*
       Keep the migration consistent with dbo.UsersSP/INSERTUSERS.  That
       procedure treats the Arabic four-part name, identity dates and the
       following lookup values as mandatory.  Fail before opening the
       transaction instead of leaving a partially usable user account.
    */
    IF EXISTS
    (
        SELECT 1
        FROM #CandidateUsers sourceUser
        WHERE NULLIF(LTRIM(RTRIM(sourceUser.fristName_A)), N'') IS NULL
           OR NULLIF(LTRIM(RTRIM(sourceUser.secondName_A)), N'') IS NULL
           OR NULLIF(LTRIM(RTRIM(sourceUser.thirdName_A)), N'') IS NULL
           OR NULLIF(LTRIM(RTRIM(sourceUser.lastName_A)), N'') IS NULL
           OR sourceUser.IDIssueDate IS NULL
           OR sourceUser.dateOfBirth IS NULL
           OR sourceUser.userTypeID_FK IS NULL
           OR sourceUser.genderID_FK IS NULL
           OR sourceUser.nationalityID_FK IS NULL
           OR sourceUser.religionID_FK IS NULL
           OR sourceUser.maritalStatusID_FK IS NULL
           OR sourceUser.educationID_FK IS NULL
    )
    BEGIN
        SELECT
            sourceUser.GeneralNo,
            sourceUser.IDNumber,
            CASE WHEN NULLIF(LTRIM(RTRIM(sourceUser.fristName_A)), N'') IS NULL
                   OR NULLIF(LTRIM(RTRIM(sourceUser.secondName_A)), N'') IS NULL
                   OR NULLIF(LTRIM(RTRIM(sourceUser.thirdName_A)), N'') IS NULL
                   OR NULLIF(LTRIM(RTRIM(sourceUser.lastName_A)), N'') IS NULL THEN 1 ELSE 0 END AS MissingArabicFourPartName,
            CASE WHEN sourceUser.IDIssueDate IS NULL THEN 1 ELSE 0 END AS MissingNationalIDIssueDate,
            CASE WHEN sourceUser.dateOfBirth IS NULL THEN 1 ELSE 0 END AS MissingDateOfBirth,
            CASE WHEN sourceUser.userTypeID_FK IS NULL THEN 1 ELSE 0 END AS MissingUserType,
            CASE WHEN sourceUser.genderID_FK IS NULL THEN 1 ELSE 0 END AS MissingGender,
            CASE WHEN sourceUser.nationalityID_FK IS NULL THEN 1 ELSE 0 END AS MissingNationality,
            CASE WHEN sourceUser.religionID_FK IS NULL THEN 1 ELSE 0 END AS MissingReligion,
            CASE WHEN sourceUser.maritalStatusID_FK IS NULL THEN 1 ELSE 0 END AS MissingMaritalStatus,
            CASE WHEN sourceUser.educationID_FK IS NULL THEN 1 ELSE 0 END AS MissingEducation
        FROM #CandidateUsers sourceUser
        WHERE NULLIF(LTRIM(RTRIM(sourceUser.fristName_A)), N'') IS NULL
           OR NULLIF(LTRIM(RTRIM(sourceUser.secondName_A)), N'') IS NULL
           OR NULLIF(LTRIM(RTRIM(sourceUser.thirdName_A)), N'') IS NULL
           OR NULLIF(LTRIM(RTRIM(sourceUser.lastName_A)), N'') IS NULL
           OR sourceUser.IDIssueDate IS NULL
           OR sourceUser.dateOfBirth IS NULL
           OR sourceUser.userTypeID_FK IS NULL
           OR sourceUser.genderID_FK IS NULL
           OR sourceUser.nationalityID_FK IS NULL
           OR sourceUser.religionID_FK IS NULL
           OR sourceUser.maritalStatusID_FK IS NULL
           OR sourceUser.educationID_FK IS NULL
        ORDER BY sourceUser.GeneralNo;

    END;

    /* Strict mode validates the effective values after applying migration
       defaults (dates/status/education and the repeated second name). */
    IF @RequireUsersSPFields = 1
       AND EXISTS
       (
           SELECT 1
           FROM #CandidateUsers sourceUser
           WHERE NULLIF(LTRIM(RTRIM(sourceUser.fristName_A)), N'') IS NULL
              OR NULLIF(LTRIM(RTRIM(sourceUser.secondName_A)), N'') IS NULL
              OR NULLIF
                 (
                     LTRIM(RTRIM(COALESCE(NULLIF(LTRIM(RTRIM(sourceUser.thirdName_A)), N''), sourceUser.secondName_A))),
                     N''
                 ) IS NULL
              OR NULLIF(LTRIM(RTRIM(sourceUser.lastName_A)), N'') IS NULL
              OR sourceUser.userTypeID_FK IS NULL
              OR sourceUser.genderID_FK IS NULL
              OR sourceUser.nationalityID_FK IS NULL
              OR sourceUser.religionID_FK IS NULL
       )
        THROW 51705, N'Cannot migrate users: effective data still does not satisfy dbo.UsersSP INSERTUSERS required fields. See the preceding result set.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM #CandidateUsers sourceUser
        LEFT JOIN dbo.UserType targetUserType ON targetUserType.userTypeID = sourceUser.userTypeID_FK
        LEFT JOIN dbo.Gender targetGender ON targetGender.genderID = sourceUser.genderID_FK
        LEFT JOIN dbo.Nationality targetNationality ON targetNationality.nationalityID = sourceUser.nationalityID_FK
        LEFT JOIN dbo.Religion targetReligion ON targetReligion.religionID = sourceUser.religionID_FK
        LEFT JOIN dbo.MaritalStatus targetMaritalStatus ON targetMaritalStatus.maritalStatusID = sourceUser.maritalStatusID_FK
        LEFT JOIN dbo.Education targetEducation ON targetEducation.educationID = sourceUser.educationID_FK
        WHERE (sourceUser.userTypeID_FK IS NOT NULL AND targetUserType.userTypeID IS NULL)
           OR (sourceUser.genderID_FK IS NOT NULL AND targetGender.genderID IS NULL)
           OR (sourceUser.nationalityID_FK IS NOT NULL AND targetNationality.nationalityID IS NULL)
           OR (sourceUser.religionID_FK IS NOT NULL AND targetReligion.religionID IS NULL)
           OR (sourceUser.maritalStatusID_FK IS NOT NULL AND targetMaritalStatus.maritalStatusID IS NULL)
           OR (sourceUser.educationID_FK IS NOT NULL AND targetEducation.educationID IS NULL)
    )
        THROW 51706, N'Cannot migrate users: one or more source lookup values do not exist in DATACORE.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM #CandidateUsers sourceUser
        WHERE sourceUser.nationalityID_FK = 1
          AND (TRY_CONVERT(bigint, sourceUser.IDNumber) IS NULL
               OR LEN(sourceUser.IDNumber) <> 10
               OR LEFT(sourceUser.IDNumber, 1) <> N'1')
    )
        THROW 51707, N'Cannot migrate users: a Saudi national ID does not satisfy dbo.UsersSP validation.', 1;

    CREATE TABLE #UserMap
    (
        GeneralNo bigint NOT NULL PRIMARY KEY,
        usersID bigint NOT NULL,
        WasExisting bit NOT NULL
    );

    DECLARE @UsersInserted bigint = 0,
            @UsersDetailsInserted bigint = 0,
            @PasswordsInserted bigint = 0,
            @DistributorsInserted bigint = 0,
            @UserDistributorsInserted bigint = 0;
    CREATE TABLE #DistributorMap
    (
        OldDistributorID bigint NOT NULL PRIMARY KEY,
        TargetDistributorID bigint NOT NULL
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Users
        (
            nationalID,
            nationalIDTypeID_FK,
            usersStartDate,
            usersEndDate,
            usersActive,
            IsAdmin,
            entryDate,
            entryData,
            hostName
        )
        SELECT
            sourceUser.IDNumber,
            1,
            COALESCE(sourceUser.entryDate, GETDATE()),
            NULL,
            1,
            0,
            sourceUser.entryDate,
            N'4',
            CASE
                WHEN entryDataMap.MappedEntryData IS NOT NULL
                THEN CONCAT(ISNULL(sourceUser.hostName, N''), N'-', NULLIF(LTRIM(RTRIM(sourceUser.entryData)), N''))
                ELSE sourceUser.hostName
            END
        FROM #CandidateUsers sourceUser
        OUTER APPLY
        (
            SELECT TOP (1)
                CONVERT(nvarchar(40), details.usersID_FK) AS MappedEntryData
            FROM dbo.UsersDetails details
            JOIN dbo.Users usersRow
              ON usersRow.usersID = details.usersID_FK
            WHERE details.GeneralNo =
                  TRY_CONVERT(bigint, NULLIF(LTRIM(RTRIM(sourceUser.entryData)), N''))
            ORDER BY
                CASE
                    WHEN ISNULL(usersRow.usersActive,0)=1
                     AND ISNULL(details.userActive,0)=1 THEN 0
                    ELSE 1
                END,
                details.usersID_FK
        ) entryDataMap
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.UsersDetails existingDetails
            JOIN dbo.Users existingDetailsUser
              ON existingDetailsUser.usersID = existingDetails.usersID_FK
            WHERE TRY_CONVERT(bigint, existingDetails.GeneralNo) = CONVERT(bigint, sourceUser.GeneralNo)
              AND ISNULL(existingDetails.userActive, 0) = 1
              AND ISNULL(existingDetailsUser.usersActive, 0) = 1
        )
        AND NOT EXISTS
        (
            SELECT 1
            FROM dbo.Users existingUser
            WHERE existingUser.nationalID = sourceUser.IDNumber
              AND ISNULL(existingUser.usersActive, 0) = 1
        );

        SET @UsersInserted = @@ROWCOUNT;

        INSERT INTO #UserMap (GeneralNo, usersID, WasExisting)
        SELECT
            sourceUser.GeneralNo,
            COALESCE(existingDetails.usersID_FK, existingUser.usersID),
            CASE WHEN existingDetails.usersID_FK IS NULL THEN 0 ELSE 1 END
        FROM #CandidateUsers sourceUser
        OUTER APPLY
        (
            SELECT TOP (1) details.usersID_FK
            FROM dbo.UsersDetails details
            JOIN dbo.Users usersRow
              ON usersRow.usersID = details.usersID_FK
            WHERE TRY_CONVERT(bigint, details.GeneralNo) = CONVERT(bigint, sourceUser.GeneralNo)
              AND ISNULL(details.userActive, 0) = 1
              AND ISNULL(usersRow.usersActive, 0) = 1
            ORDER BY details.usersDetailsID DESC
        ) existingDetails
        OUTER APPLY
        (
            SELECT TOP (1) usersRow.usersID
            FROM dbo.Users usersRow
            WHERE usersRow.nationalID = sourceUser.IDNumber
              AND ISNULL(usersRow.usersActive, 0) = 1
            ORDER BY usersRow.usersID DESC
        ) existingUser
        WHERE COALESCE(existingDetails.usersID_FK, existingUser.usersID) IS NOT NULL;

        INSERT INTO dbo.UsersDetails
        (
            usersID_FK,
            GeneralNo,
            userTypeID_FK,
            firstName_A,
            secondName_A,
            thirdName_A,
            forthName_A,
            lastName_A,
            firstName_E,
            secondName_E,
            thirdName_E,
            forthName_E,
            lastName_E,
            nationalIDIssueDate,
            nationalIDExpiryDate,
            nationalIDIssuePlaceCityID_FK,
            dateOfBirth,
            birthPlaceCityID_FK,
            genderID_FK,
            nationalityID_FK,
            religionID_FK,
            bloodID_FK,
            maritalStatusID_FK,
            educationID_FK,
            userActive,
            userNote,
            usersAuthTypeID_FK,
            IdaraID,
            entryDate,
            entryData,
            hostName
        )
        SELECT
            userMap.usersID,
            CONVERT(bigint, sourceUser.GeneralNo),
            sourceUser.userTypeID_FK,
            sourceUser.fristName_A,
            sourceUser.secondName_A,
            COALESCE(NULLIF(LTRIM(RTRIM(sourceUser.thirdName_A)), N''), sourceUser.secondName_A),
            NULL,
            sourceUser.lastName_A,
            sourceUser.fristName_E,
            sourceUser.secondName_E,
            sourceUser.thirdName_E,
            NULL,
            sourceUser.lastName_E,
            COALESCE(sourceUser.IDIssueDate, CONVERT(date, '20200101', 112)),
            sourceUser.IDExpiryDate,
            sourceUser.IDIssuePlaceCityID_FK,
            COALESCE(sourceUser.dateOfBirth, CONVERT(date, '19800101', 112)),
            sourceUser.birthPlaceCityID_FK,
            sourceUser.genderID_FK,
            sourceUser.nationalityID_FK,
            sourceUser.religionID_FK,
            sourceUser.bloodID_FK,
            COALESCE(sourceUser.maritalStatusID_FK, 1),
            COALESCE(sourceUser.educationID_FK, 1),
            1,
            sourceUser.userNote,
            3,
            @IdaraId,
            sourceUser.entryDate,
            N'4',
            CASE
                WHEN entryDataMap.MappedEntryData IS NOT NULL
                THEN CONCAT(ISNULL(sourceUser.hostName, N''), N'-', NULLIF(LTRIM(RTRIM(sourceUser.entryData)), N''))
                ELSE sourceUser.hostName
            END
        FROM #CandidateUsers sourceUser
        JOIN #UserMap userMap
          ON userMap.GeneralNo = CONVERT(bigint, sourceUser.GeneralNo)
        OUTER APPLY
        (
            SELECT TOP (1)
                CONVERT(nvarchar(40), details.usersID_FK) AS MappedEntryData
            FROM dbo.UsersDetails details
            JOIN dbo.Users usersRow
              ON usersRow.usersID = details.usersID_FK
            WHERE details.GeneralNo =
                  TRY_CONVERT(bigint, NULLIF(LTRIM(RTRIM(sourceUser.entryData)), N''))
            ORDER BY
                CASE
                    WHEN ISNULL(usersRow.usersActive,0)=1
                     AND ISNULL(details.userActive,0)=1 THEN 0
                    ELSE 1
                END,
                details.usersID_FK
        ) entryDataMap
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.UsersDetails existingDetails
            WHERE TRY_CONVERT(bigint, existingDetails.GeneralNo) = CONVERT(bigint, sourceUser.GeneralNo)
              AND ISNULL(existingDetails.userActive, 0) = 1
        );

        SET @UsersDetailsInserted = @@ROWCOUNT;

        INSERT INTO dbo.UsersPassword
        (
            usersID_FK,
            PasswordHash,
            PasswordSalt,
            HashAlgorithm,
            userPasswordStartDate,
            userPasswordEndDate,
            userPasswordActive,
            ChangedPassword,
            entryDate,
            entryData,
            hostName
        )
        SELECT
            userMap.usersID,
            HASHBYTES('SHA2_256', generatedSalt.PasswordSalt + CAST(@DefaultPassword AS varbinary(200))),
            generatedSalt.PasswordSalt,
            N'SHA2_256',
            GETDATE(),
            DATEADD(HOUR, 24, GETDATE()),
            1,
            0,
            GETDATE(),
            N'4',
            CASE
                WHEN entryDataMap.MappedEntryData IS NOT NULL
                THEN CONCAT(ISNULL(sourceUser.hostName, N''), N'-', NULLIF(LTRIM(RTRIM(sourceUser.entryData)), N''))
                ELSE sourceUser.hostName
            END
        FROM #CandidateUsers sourceUser
        JOIN #UserMap userMap
          ON userMap.GeneralNo = CONVERT(bigint, sourceUser.GeneralNo)
        OUTER APPLY
        (
            SELECT TOP (1)
                CONVERT(nvarchar(40), details.usersID_FK) AS MappedEntryData
            FROM dbo.UsersDetails details
            JOIN dbo.Users usersRow
              ON usersRow.usersID = details.usersID_FK
            WHERE details.GeneralNo =
                  TRY_CONVERT(bigint, NULLIF(LTRIM(RTRIM(sourceUser.entryData)), N''))
            ORDER BY
                CASE
                    WHEN ISNULL(usersRow.usersActive,0)=1
                     AND ISNULL(details.userActive,0)=1 THEN 0
                    ELSE 1
                END,
                details.usersID_FK
        ) entryDataMap
        CROSS APPLY (SELECT CRYPT_GEN_RANDOM(32) AS PasswordSalt) generatedSalt
        WHERE userMap.WasExisting = 0
          AND EXISTS
        (
            SELECT 1
            FROM dbo.UsersDetails details
            WHERE details.usersID_FK = userMap.usersID
              AND TRY_CONVERT(bigint, details.GeneralNo) = CONVERT(bigint, sourceUser.GeneralNo)
        );

        SET @PasswordsInserted = @@ROWCOUNT;

        SELECT DISTINCT
            sourceDistributor.distributorID,
            sourceDistributor.distributorName_A,
            sourceDistributor.distributorName_E,
            sourceDistributor.distributorDescription,
            sourceDistributor.distributorCode,
            sourceDistributor.distributorActive,
            sourceDistributor.distributorType_FK,
            sourceDistributor.DSDID_FK,
            sourceDistributor.roleID_FK,
            sourceDistributor.groupID_FK,
            sourceDistributor.jobNo,
            sourceDistributor.entryDate,
            N'4' AS entryData,
            CASE
                WHEN entryDataMap.MappedEntryData IS NOT NULL
                THEN CONCAT(ISNULL(sourceDistributor.hostName, N''), N'-', NULLIF(LTRIM(RTRIM(sourceDistributor.entryData)), N''))
                ELSE sourceDistributor.hostName
            END AS hostName
        INTO #CandidateDistributors
        FROM KFMC.dbo.UserDistributor sourceUserDistributor
        JOIN #CandidateUsers sourceUser
          ON sourceUser.GeneralNo = sourceUserDistributor.userID_FK
        JOIN KFMC.dbo.Distributor sourceDistributor
          ON sourceDistributor.distributorID = sourceUserDistributor.distributorID_FK
        JOIN KFMC.dbo.DistributorType sourceDistributorType
          ON sourceDistributorType.distributorTypeID = sourceDistributor.distributorType_FK
        OUTER APPLY
        (
            SELECT TOP (1)
                CONVERT(nvarchar(40), details.usersID_FK) AS MappedEntryData
            FROM dbo.UsersDetails details
            JOIN dbo.Users usersRow
              ON usersRow.usersID = details.usersID_FK
            WHERE details.GeneralNo =
                  TRY_CONVERT(bigint, NULLIF(LTRIM(RTRIM(sourceDistributor.entryData)), N''))
            ORDER BY
                CASE
                    WHEN ISNULL(usersRow.usersActive,0)=1
                     AND ISNULL(details.userActive,0)=1 THEN 0
                    ELSE 1
                END,
                details.usersID_FK
        ) entryDataMap
        WHERE sourceDistributorType.distributorTypeID = 1
          AND sourceDistributor.distributorActive = 1
          AND ISNULL(sourceUserDistributor.UDActive, 0) = 1
          AND sourceUserDistributor.UDStartDate IS NOT NULL
          AND CONVERT(date, sourceUserDistributor.UDStartDate) <= CONVERT(date, GETDATE())
          AND sourceUserDistributor.UDEndDate IS NULL
          AND
          (
              @DepartmentId IS NULL
              OR EXISTS
              (
                  SELECT 1
                  FROM dbo.V_GetFullStructureForDSD scopedStructure
                  WHERE scopedStructure.DSDID = CONVERT(bigint, sourceDistributor.DSDID_FK)
                    AND scopedStructure.IdaraID = @IdaraId
                    AND scopedStructure.DepartmentID = @DepartmentId
              )
          );

        IF EXISTS
        (
            SELECT 1
            FROM #CandidateDistributors sourceDistributor
            LEFT JOIN dbo.DeptSecDiv targetDSD
              ON targetDSD.DSDID = CONVERT(bigint, sourceDistributor.DSDID_FK)
            WHERE sourceDistributor.DSDID_FK IS NOT NULL
              AND targetDSD.DSDID IS NULL
        )
            THROW 51704, N'Cannot migrate user distributors: one or more type-1 distributors references a missing DSDID.', 1;

        /* GetSessionInfoForMVC resolves the administrative structure through
           V_GetListUsersInDSD, not through UsersDetails.IdaraID.  Ensure each
           candidate has at least one assignment that can satisfy that view. */
        IF EXISTS
        (
            SELECT 1
            FROM #CandidateUsers sourceUser
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM KFMC.dbo.UserDistributor sourceUD
                JOIN KFMC.dbo.Distributor sourceDistributor
                  ON sourceDistributor.distributorID = sourceUD.distributorID_FK
                JOIN dbo.V_GetFullStructureForDSD targetStructure
                  ON targetStructure.DSDID = CONVERT(bigint, sourceDistributor.DSDID_FK)
                WHERE sourceUD.userID_FK = sourceUser.GeneralNo
                  AND ISNULL(sourceUD.UDActive, 0) = 1
                  AND sourceUD.UDStartDate IS NOT NULL
                  AND CONVERT(date, sourceUD.UDStartDate) <= CONVERT(date, GETDATE())
                  AND sourceUD.UDEndDate IS NULL
                  AND ISNULL(sourceDistributor.distributorActive, 0) = 1
                  AND sourceDistributor.distributorType_FK = 1
                  AND sourceDistributor.DSDID_FK IS NOT NULL
                  AND sourceDistributor.roleID_FK IS NULL
                  AND targetStructure.IdaraID IS NOT NULL
                  AND targetStructure.DepartmentName IS NOT NULL
                  AND (@DepartmentId IS NULL OR targetStructure.DepartmentID = @DepartmentId)
            )
        )
            THROW 51708, N'Cannot migrate users: at least one user has no active department assignment accepted by GetSessionInfoForMVC.', 1;

        /* Map every source section/division distributor to the existing
           distributor of its parent department in DATACORE.  No source
           section/division distributor is copied to the target. */
        INSERT INTO #DistributorMap(OldDistributorID, TargetDistributorID)
        SELECT
            CONVERT(bigint, sourceDistributor.distributorID),
            departmentDistributor.distributorID
        FROM #CandidateDistributors sourceDistributor
        JOIN dbo.V_GetFullStructureForDSD sourceStructure
          ON sourceStructure.DSDID = CONVERT(bigint, sourceDistributor.DSDID_FK)
        CROSS APPLY
        (
            SELECT TOP (1) targetDistributor.distributorID
            FROM dbo.V_GetFullStructureForDSD departmentStructure
            JOIN dbo.Distributor targetDistributor
              ON targetDistributor.DSDID_FK = departmentStructure.DSDID
             AND targetDistributor.distributorType_FK = 1
             AND ISNULL(targetDistributor.distributorActive, 0) = 1
             AND targetDistributor.roleID_FK IS NULL
            WHERE departmentStructure.IdaraID = sourceStructure.IdaraID
              AND departmentStructure.DepartmentID = sourceStructure.DepartmentID
              AND departmentStructure.DSDLevel = 3
            ORDER BY targetDistributor.distributorID
        ) departmentDistributor;

        SET @DistributorsInserted = 0;

        IF (SELECT COUNT_BIG(*) FROM #DistributorMap) <
           (SELECT COUNT_BIG(*) FROM #CandidateDistributors)
            THROW 51709, N'Cannot migrate users: a source assignment has no active parent-department distributor in DATACORE.', 1;

        SELECT DISTINCT
            sourceUserDistributor.UDID,
            userMap.usersID,
            distributorMap.TargetDistributorID,
            sourceUserDistributor.UDStartDate,
            sourceUserDistributor.UDEndDate,
            sourceUserDistributor.UDActive,
            sourceUserDistributor.CanceldBy,
            sourceUserDistributor.Note,
            sourceUserDistributor.entryDate,
            N'4' AS entryData,
            CASE
                WHEN entryDataMap.MappedEntryData IS NOT NULL
                THEN CONCAT(ISNULL(sourceUserDistributor.hostName, N''), N'-', NULLIF(LTRIM(RTRIM(sourceUserDistributor.entryData)), N''))
                ELSE sourceUserDistributor.hostName
            END AS hostName
        INTO #CandidateUserDistributors
        FROM KFMC.dbo.UserDistributor sourceUserDistributor
        JOIN #CandidateUsers sourceUser
          ON sourceUser.GeneralNo = sourceUserDistributor.userID_FK
        JOIN #UserMap userMap
          ON userMap.GeneralNo = CONVERT(bigint, sourceUser.GeneralNo)
        JOIN #CandidateDistributors sourceDistributor
          ON sourceDistributor.distributorID = sourceUserDistributor.distributorID_FK
        JOIN #DistributorMap distributorMap
          ON distributorMap.OldDistributorID = CONVERT(bigint, sourceDistributor.distributorID)
        OUTER APPLY
        (
            SELECT TOP (1)
                CONVERT(nvarchar(40), details.usersID_FK) AS MappedEntryData
            FROM dbo.UsersDetails details
            JOIN dbo.Users usersRow
              ON usersRow.usersID = details.usersID_FK
            WHERE details.GeneralNo =
                  TRY_CONVERT(bigint, NULLIF(LTRIM(RTRIM(sourceUserDistributor.entryData)), N''))
            ORDER BY
                CASE
                    WHEN ISNULL(usersRow.usersActive,0)=1
                     AND ISNULL(details.userActive,0)=1 THEN 0
                    ELSE 1
                END,
                details.usersID_FK
        ) entryDataMap
        WHERE ISNULL(sourceUserDistributor.UDActive, 0) = 1
          AND sourceUserDistributor.UDStartDate IS NOT NULL
          AND CONVERT(date, sourceUserDistributor.UDStartDate) <= CONVERT(date, GETDATE())
          AND sourceUserDistributor.UDEndDate IS NULL;

        INSERT INTO dbo.UserDistributor
        (
            userID_FK,
            distributorID_FK,
            UDStartDate,
            UDEndDate,
            UDActive,
            CanceldBy,
            Note,
            entryDate,
            entryData,
            hostName
        )
        SELECT
            sourceUserDistributor.usersID,
            sourceUserDistributor.TargetDistributorID,
            sourceUserDistributor.UDStartDate,
            sourceUserDistributor.UDEndDate,
            sourceUserDistributor.UDActive,
            sourceUserDistributor.CanceldBy,
            sourceUserDistributor.Note,
            sourceUserDistributor.entryDate,
            sourceUserDistributor.entryData,
            sourceUserDistributor.hostName
        FROM #CandidateUserDistributors sourceUserDistributor
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.UserDistributor targetUserDistributor
            WHERE targetUserDistributor.userID_FK = sourceUserDistributor.usersID
              AND targetUserDistributor.distributorID_FK = sourceUserDistributor.TargetDistributorID
              AND ISNULL(targetUserDistributor.UDStartDate, CONVERT(date,'19000101',112)) =
                  ISNULL(sourceUserDistributor.UDStartDate, CONVERT(date,'19000101',112))
        );

        SET @UserDistributorsInserted = @@ROWCOUNT;

        SELECT
            @RollbackAfterTest AS RollbackAfterTest,
            @IdaraId AS IdaraId,
            @DepartmentId AS DepartmentId,
            @RequireUsersSPFields AS RequireUsersSPFields,
            (SELECT COUNT_BIG(*) FROM #SkippedExistingUsers) AS ExistingUsersSkipped,
            (SELECT COUNT_BIG(*) FROM #CandidateUsers) AS CandidateUsers,
            @UsersInserted AS UsersInserted,
            @UsersDetailsInserted AS UsersDetailsInserted,
            @PasswordsInserted AS PasswordsInserted,
            (SELECT COUNT_BIG(*) FROM #CandidateDistributors) AS CandidateDistributorsType1,
            @DistributorsInserted AS DistributorsInserted,
            (SELECT COUNT_BIG(*) FROM #CandidateUserDistributors) AS CandidateUserDistributorsType1,
            @UserDistributorsInserted AS UserDistributorsInserted,
            (SELECT COUNT_BIG(*) FROM #UserMap WHERE WasExisting = 1) AS ExistingUsersDetails,
            (SELECT COUNT_BIG(*) FROM #CandidateUsers sourceUser
             WHERE EXISTS
             (
                 SELECT 1
                 FROM dbo.UsersDetails details
                 WHERE TRY_CONVERT(bigint, details.GeneralNo) = CONVERT(bigint, sourceUser.GeneralNo)
             )) AS AvailableUsersDetails;

        IF @RollbackAfterTest = 1 ROLLBACK TRANSACTION; ELSE COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
