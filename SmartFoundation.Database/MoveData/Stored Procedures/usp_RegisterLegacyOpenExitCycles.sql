CREATE PROCEDURE [MoveData].[usp_RegisterLegacyOpenExitCycles]
    @IdaraId BIGINT,
    @RollbackAfterTest BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF DB_NAME() <> N'DATACORE'
        THROW 56100, N'This migration procedure must run against DATACORE.', 1;

    IF @RollbackAfterTest IS NULL
        THROW 56106, N'RollbackAfterTest must be 0 or 1.', 1;

    IF @IdaraId IS NULL OR NOT EXISTS
    (
        SELECT 1 FROM dbo.Idara WHERE idaraID = @IdaraId
    )
        THROW 56101, N'The migration IdaraId does not exist.', 1;

    IF OBJECT_ID(N'Housing.ExitFinancialProcessingCycle', N'U') IS NULL
        THROW 56102, N'ExitFinancialProcessingCycle is required before registration.', 1;

    DECLARE @OwnTransaction BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @LockResource NVARCHAR(255);
    DECLARE @LockResult INT;
    DECLARE @Candidates BIGINT = 0;
    DECLARE @AlreadyFinalized BIGINT = 0;
    DECLARE @AlreadyRegistered BIGINT = 0;
    DECLARE @Registered BIGINT = 0;

    -- Do not roll back a caller-owned migration transaction here.
    -- usp_MigrateAll calls this helper with @RollbackAfterTest = 0.
    IF @OwnTransaction = 0 AND @RollbackAfterTest = 1
        THROW 56103, N'Inside an existing transaction use @RollbackAfterTest = 0; the caller controls rollback.', 1;

    BEGIN TRY
        IF @OwnTransaction = 1
            BEGIN TRANSACTION;

        SET @LockResource = CONCAT(N'MOVEDATA_LEGACY_OPEN_EXIT:', CONVERT(NVARCHAR(30), @IdaraId));
        EXEC @LockResult = sys.sp_getapplock
              @Resource = @LockResource
            , @LockMode = N'Exclusive'
            , @LockOwner = N'Transaction'
            , @LockTimeout = 15000;

        IF @LockResult < 0
            THROW 56104, N'Could not acquire the legacy exit registration lock.', 1;

        /*
          Only genuine KFMC exit actions still in progress:
          extraInt1 1 -> 59; 2/3 -> 57; 4 -> 58.
          Completed extraInt1=5 and NULL -> 3 are NOT enrolled.
          No synthetic 54 action is created.
        */
        SELECT
              a.buildingActionID AS ExitRequestActionID
            , a.residentInfoID_FK
            , a.buildingDetailsID_FK
            , a.OccupentDate
            , a.ExitDate
            , CASE WHEN EXISTS
              (
                  SELECT 1
                  FROM Housing.BuildingAction finalAction
                  WHERE finalAction.IdaraId_FK = a.IdaraId_FK
                    AND finalAction.residentInfoID_FK = a.residentInfoID_FK
                    AND finalAction.buildingDetailsID_FK = a.buildingDetailsID_FK
                    AND finalAction.buildingActionTypeID_FK = 3
                    AND finalAction.buildingActionActive = 1
                    AND finalAction.buildingActionExtraText5 = N'LEGACY'
                    AND finalAction.OccupentDate IS NOT NULL
                    AND a.OccupentDate IS NOT NULL
                    AND CONVERT(DATE, finalAction.OccupentDate) = CONVERT(DATE, a.OccupentDate)
                    AND finalAction.buildingActionDate >= a.buildingActionDate
              )
              OR EXISTS
              (
                  /* Also detect completed exits the original migration skipped. */
                  SELECT 1
                  FROM KFMC.Housing.BuildingAction sourceFinal
                  WHERE sourceFinal.buildingActionTypeID_FK = 3
                    AND sourceFinal.buildingActionExtraInt1 = 5
                    AND sourceFinal.buildingActionActive = 1
                    AND sourceFinal.generalNo_FK = sourceAction.generalNo_FK
                    AND LTRIM(RTRIM(sourceFinal.buildingDetailsNo)) =
                        LTRIM(RTRIM(sourceAction.buildingDetailsNo))
                    AND sourceFinal.buildingActionDate >= sourceAction.buildingActionDate
                    AND NOT EXISTS
                    (
                        SELECT 1
                        FROM KFMC.Housing.BuildingAction reoccupancy
                        WHERE reoccupancy.buildingActionTypeID_FK = 2
                          AND reoccupancy.buildingActionActive = 1
                          AND reoccupancy.generalNo_FK = sourceAction.generalNo_FK
                          AND LTRIM(RTRIM(reoccupancy.buildingDetailsNo)) =
                              LTRIM(RTRIM(sourceAction.buildingDetailsNo))
                          AND reoccupancy.buildingActionDate > a.OccupentDate
                          AND reoccupancy.buildingActionDate <= sourceFinal.buildingActionDate
                    )
              ) THEN 1 ELSE 0 END AS HasFinalizedSameOccupancy
        INTO #LegacyExitCandidates
        FROM Housing.BuildingAction a
        INNER JOIN KFMC.Housing.BuildingAction sourceAction
            ON sourceAction.buildingActionID = a.buildingActionID
        WHERE a.IdaraId_FK = @IdaraId
          AND a.buildingActionExtraText5 = N'LEGACY'
          AND a.buildingActionActive = 1
          AND sourceAction.buildingActionTypeID_FK = 3
          AND sourceAction.buildingActionActive = 1
          AND sourceAction.buildingActionExtraInt1 IN (1, 2, 3, 4)
          AND
          (
                (sourceAction.buildingActionExtraInt1 = 1 AND a.buildingActionTypeID_FK = 59)
             OR (sourceAction.buildingActionExtraInt1 IN (2, 3) AND a.buildingActionTypeID_FK = 57)
             OR (sourceAction.buildingActionExtraInt1 = 4 AND a.buildingActionTypeID_FK = 58)
          );

        IF EXISTS
        (
            SELECT 1
            FROM #LegacyExitCandidates
            WHERE HasFinalizedSameOccupancy = 0
              AND (residentInfoID_FK IS NULL OR buildingDetailsID_FK IS NULL
                   OR OccupentDate IS NULL OR ExitDate IS NULL)
        )
            THROW 56105, N'An unfinished historical exit has missing resident, building, occupancy or exit dates; registration aborted.', 1;

        SELECT
              @Candidates = COUNT_BIG(*)
            , @AlreadyFinalized = COALESCE(SUM(CONVERT(BIGINT, HasFinalizedSameOccupancy)), 0)
        FROM #LegacyExitCandidates;

        SELECT @AlreadyRegistered = COUNT_BIG(*)
        FROM #LegacyExitCandidates candidate
        INNER JOIN Housing.ExitFinancialProcessingCycle cycleRow WITH (UPDLOCK, HOLDLOCK)
            ON cycleRow.ExitRequestActionID_FK = candidate.ExitRequestActionID
        WHERE candidate.HasFinalizedSameOccupancy = 0;

        INSERT INTO Housing.ExitFinancialProcessingCycle
        (
              ExitRequestActionID_FK
            , ProcessingVersion
            , CreatedAt
            , entryData
            , hostName
        )
        SELECT
              candidate.ExitRequestActionID
            , CONVERT(TINYINT, 1)
            , SYSDATETIME()
            , N'MOVEDATA'
            , N'usp_RegisterLegacyOpenExitCycles'
        FROM #LegacyExitCandidates candidate
        WHERE candidate.HasFinalizedSameOccupancy = 0
          AND NOT EXISTS
          (
              SELECT 1
              FROM Housing.ExitFinancialProcessingCycle existing WITH (UPDLOCK, HOLDLOCK)
              WHERE existing.ExitRequestActionID_FK = candidate.ExitRequestActionID
          );

        SET @Registered = @@ROWCOUNT;

        IF @OwnTransaction = 1
        BEGIN
            IF @RollbackAfterTest = 1
                ROLLBACK TRANSACTION;
            ELSE
                COMMIT TRANSACTION;
        END;

        SELECT
              @Candidates AS HistoricalUnfinishedCandidateRows
            , @AlreadyFinalized AS SupersededByFinalExit
            , @AlreadyRegistered AS AlreadyRegisteredCycles
            , @Registered AS InsertedCycles
            , @RollbackAfterTest AS RollbackAfterTest;
    END TRY
    BEGIN CATCH
        IF @OwnTransaction = 1 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;