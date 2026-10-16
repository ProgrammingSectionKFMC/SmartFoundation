CREATE PROCEDURE [MoveData].[usp_MigrateBuildingActions]
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
        THROW 54000, N'The supplied IdaraId does not exist in DATACORE.dbo.Idara.', 1;
    IF EXISTS
    (
        SELECT requiredType.[buildingActionTypeID]
        FROM (VALUES (3), (39), (57), (58), (59)) requiredType([buildingActionTypeID])
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM [Housing].[BuildingActionType] targetType
            WHERE targetType.[buildingActionTypeID] = requiredType.[buildingActionTypeID]
        )
    )
        THROW 54003, N'Required mapped action types 3, 39, 57, 58, and 59 must exist in DATACORE.Housing.BuildingActionType.', 1;
    IF EXISTS
    (
        SELECT 1
        FROM [KFMC].[Housing].[BuildingAction] sourceAction
        WHERE sourceAction.[buildingActionTypeID_FK] = 3
          AND sourceAction.[buildingActionExtraInt1] IS NOT NULL
          AND sourceAction.[buildingActionExtraInt1] NOT IN (1, 2, 3, 4, 5)
    )
        THROW 54004, N'KFMC contains an unsupported evacuation stage in buildingActionExtraInt1.', 1;
   IF EXISTS
(
    SELECT 1
    FROM [KFMC].[Housing].[ResidentInfo] sourceResident

    LEFT JOIN [Housing].[ResidentInfo] targetResident
        ON targetResident.[residentInfoID] =
           CONVERT(bigint, sourceResident.[residentInfoID])

    WHERE targetResident.[residentInfoID] IS NULL

      AND EXISTS
      (
          SELECT 1
          FROM [KFMC].[Housing].[ResidentDetails] sourceDetails
          WHERE sourceDetails.[generalNo_FK] =
                sourceResident.[generalNo]
      )
)
    THROW 54001,
        N'Run MoveData.usp_MigrateResidents before migrating building actions.',
        1;
    IF EXISTS
    (
        SELECT 1 FROM [KFMC].[Housing].[BuildingDetails] sourceBuilding
        LEFT JOIN [Housing].[BuildingDetails] targetBuilding
          ON targetBuilding.[buildingDetailsID] = CONVERT(bigint, sourceBuilding.[buildingDetailsID])
        WHERE targetBuilding.[buildingDetailsID] IS NULL
    )
        THROW 54002, N'Run MoveData.usp_MigrateBuildings before migrating building actions.', 1;

    DECLARE @ActionsInserted bigint = 0, @AssignmentsInserted bigint = 0;
    DECLARE @DuplicateActionsExcluded bigint = 0;
    DECLARE @ActionIdentity bit = 0, @AssignIdentity bit = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        /*
          A repeated button click may create an identical action immediately after
          the previous action for the same resident/building. Actions belonging to
          other residents/buildings do not break that sequence.

          Keep the first action, skip every following identical action, and map any
          parent references from the skipped action to the first retained action.
          No rows are changed or deleted in KFMC.
        */
        ;WITH OrderedSourceActions AS
        (
            SELECT
                sourceAction.*,
                LAG(sourceAction.[buildingActionID]) OVER
                (
                    PARTITION BY
                        sourceAction.[generalNo_FK],
                        ISNULL(LTRIM(RTRIM(sourceAction.[buildingDetailsNo])), N'')
                    ORDER BY sourceAction.[buildingActionID]
                ) AS [previousEntityActionID]
            FROM [KFMC].[Housing].[BuildingAction] sourceAction
            WHERE sourceAction.[generalNo_FK] IS NULL
               OR
               (
                   sourceAction.[generalNo_FK] NOT IN (0,1)
                   AND EXISTS
                   (
                       SELECT 1
                       FROM [KFMC].[Housing].[ResidentInfo] validResident
                       WHERE validResident.[generalNo]=sourceAction.[generalNo_FK]
                   )
               )
        )
        SELECT
            currentAction.[buildingActionID] AS [duplicateActionID],
            previousAction.[buildingActionID] AS [previousActionID]
        INTO #DuplicateActionEdges
        FROM OrderedSourceActions currentAction
        JOIN [KFMC].[Housing].[BuildingAction] previousAction
          ON previousAction.[buildingActionID] = currentAction.[previousEntityActionID]
        WHERE NOT EXISTS
        (
            SELECT
                currentAction.[buildingActionTypeID_FK],
                currentAction.[buildingStatusID_FK],
                currentAction.[generalNo_FK],
                currentAction.[buildingPaymentTypeID_FK],
                currentAction.[buildingDetailsNo],
                currentAction.[buildingActionFromDate],
                currentAction.[buildingActionToDate],
                currentAction.[buildingActionDate],
                currentAction.[buildingActionDate2],
                currentAction.[buildingActionDecisionNo],
                currentAction.[buildingActionDecisionDate],
                currentAction.[fromDSD_FK],
                currentAction.[toDSD_FK],
                currentAction.[buildingActionFromSourceID_FK],
                currentAction.[buildingActionToSourceID_FK],
                currentAction.[buildingActionNote],
                currentAction.[buildingActionExtraText1],
                currentAction.[buildingActionExtraText2],
                currentAction.[buildingActionExtraText3],
                currentAction.[buildingActionExtraText4],
                currentAction.[buildingActionExtraDate1],
                currentAction.[buildingActionExtraDate2],
                currentAction.[buildingActionExtraDate3],
                currentAction.[buildingActionExtraFloat1],
                currentAction.[buildingActionExtraFloat2],
                currentAction.[buildingActionExtraInt1],
                currentAction.[buildingActionExtraInt2],
                currentAction.[buildingActionExtraInt3],
                currentAction.[buildingActionExtraInt4],
                currentAction.[buildingActionExtraType1],
                currentAction.[buildingActionExtraType2],
                currentAction.[buildingActionExtraType3],
                currentAction.[buildingActionActive],
                currentAction.[buildingActionParentID]
            EXCEPT
            SELECT
                previousAction.[buildingActionTypeID_FK],
                previousAction.[buildingStatusID_FK],
                previousAction.[generalNo_FK],
                previousAction.[buildingPaymentTypeID_FK],
                previousAction.[buildingDetailsNo],
                previousAction.[buildingActionFromDate],
                previousAction.[buildingActionToDate],
                previousAction.[buildingActionDate],
                previousAction.[buildingActionDate2],
                previousAction.[buildingActionDecisionNo],
                previousAction.[buildingActionDecisionDate],
                previousAction.[fromDSD_FK],
                previousAction.[toDSD_FK],
                previousAction.[buildingActionFromSourceID_FK],
                previousAction.[buildingActionToSourceID_FK],
                previousAction.[buildingActionNote],
                previousAction.[buildingActionExtraText1],
                previousAction.[buildingActionExtraText2],
                previousAction.[buildingActionExtraText3],
                previousAction.[buildingActionExtraText4],
                previousAction.[buildingActionExtraDate1],
                previousAction.[buildingActionExtraDate2],
                previousAction.[buildingActionExtraDate3],
                previousAction.[buildingActionExtraFloat1],
                previousAction.[buildingActionExtraFloat2],
                previousAction.[buildingActionExtraInt1],
                previousAction.[buildingActionExtraInt2],
                previousAction.[buildingActionExtraInt3],
                previousAction.[buildingActionExtraInt4],
                previousAction.[buildingActionExtraType1],
                previousAction.[buildingActionExtraType2],
                previousAction.[buildingActionExtraType3],
                previousAction.[buildingActionActive],
                previousAction.[buildingActionParentID]
        );

        /* Resolve chains such as A,A,A so every skipped row points to A. */
        ;WITH DuplicatePaths AS
        (
            SELECT
                edge.[duplicateActionID],
                edge.[previousActionID] AS [retainedActionID],
                1 AS [pathLevel]
            FROM #DuplicateActionEdges edge

            UNION ALL

            SELECT
                path.[duplicateActionID],
                previousEdge.[previousActionID],
                path.[pathLevel] + 1
            FROM DuplicatePaths path
            JOIN #DuplicateActionEdges previousEdge
              ON previousEdge.[duplicateActionID] = path.[retainedActionID]
            WHERE path.[pathLevel] < 100
        ),
        RankedDuplicatePaths AS
        (
            SELECT
                path.[duplicateActionID],
                path.[retainedActionID],
                ROW_NUMBER() OVER
                (
                    PARTITION BY path.[duplicateActionID]
                    ORDER BY path.[pathLevel] DESC
                ) AS [rowNumber]
            FROM DuplicatePaths path
        )
        SELECT
            [duplicateActionID],
            [retainedActionID]
        INTO #DuplicateActionMap
        FROM RankedDuplicatePaths
        WHERE [rowNumber] = 1
        OPTION (MAXRECURSION 100);

        SET @DuplicateActionsExcluded = @@ROWCOUNT;

        CREATE UNIQUE CLUSTERED INDEX [IX_DuplicateActionMap_DuplicateActionID]
            ON #DuplicateActionMap ([duplicateActionID]);

        SET IDENTITY_INSERT [Housing].[BuildingAction] ON;
        SET @ActionIdentity = 1;

        ;WITH ActionAncestors AS
        (
            /* Start from every evacuation and walk upward through its parent chain. */
            SELECT exitAction.[buildingActionID] exitActionID,
                   parentAction.[buildingActionID] ancestorActionID,
                   parentAction.[buildingActionParentID] nextParentID,
                   parentAction.[buildingActionTypeID_FK] ancestorTypeID,
                   parentAction.[buildingActionDate] ancestorActionDate,
                   1 ancestorLevel
            FROM [KFMC].[Housing].[BuildingAction] exitAction
            LEFT JOIN [KFMC].[Housing].[BuildingAction] parentAction
              ON parentAction.[buildingActionID] = exitAction.[buildingActionParentID]
            WHERE exitAction.[buildingActionTypeID_FK] = 3

            UNION ALL

            SELECT ancestorRow.[exitActionID],
                   parentAction.[buildingActionID],
                   parentAction.[buildingActionParentID],
                   parentAction.[buildingActionTypeID_FK],
                   parentAction.[buildingActionDate],
                   ancestorRow.[ancestorLevel] + 1
            FROM ActionAncestors ancestorRow
            JOIN [KFMC].[Housing].[BuildingAction] parentAction
              ON parentAction.[buildingActionID] = ancestorRow.[nextParentID]
            WHERE ancestorRow.[ancestorLevel] < 100
        ),
        ExitOccupancyRanked AS
        (
            SELECT [exitActionID], [ancestorActionDate] occupentDate,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY [exitActionID]
                       ORDER BY [ancestorLevel]
                   ) rowNumber
            FROM ActionAncestors
            WHERE [ancestorTypeID] = 2
        ),
        ExitOccupancy AS
        (
            SELECT [exitActionID], [occupentDate]
            FROM ExitOccupancyRanked
            WHERE [rowNumber] = 1
        )
        INSERT INTO [Housing].[BuildingAction]
        (
            [buildingActionID], [buildingActionUDID], [buildingActionTypeID_FK],
            [buildingStatusID_FK], [residentInfoID_FK], [generalNo_FK],
            [buildingPaymentTypeID_FK], [buildingDetailsID_FK], [buildingDetailsNo],
            [buildingActionFromDate], [buildingActionToDate], [buildingActionDate],
            [buildingActionDate2], [buildingActionDecisionNo], [buildingActionDecisionDate],
            [fromDSD_FK], [toDSD_FK], [buildingActionFromSourceID_FK],
            [buildingActionToSourceID_FK], [buildingActionNote],
            [buildingActionExtraText1], [buildingActionExtraText2],
            [buildingActionExtraText3], [buildingActionExtraText4],
            [buildingActionExtraText5],
            [buildingActionExtraDate1], [buildingActionExtraDate2], [buildingActionExtraDate3],
            [buildingActionExtraFloat1], [buildingActionExtraFloat2],
            [buildingActionExtraInt1], [buildingActionExtraInt2],
            [buildingActionExtraInt3], [buildingActionExtraInt4],
            [buildingActionExtraType1], [buildingActionExtraType2], [buildingActionExtraType3],
            [buildingActionActive], [buildingActionParentID], [CustdyRecord],
            [AssignPeriodID_FK], [InAssignPeriod], [ExtendReasonTypeID_FK],
            [OccupentDate], [ExitDate], [IdaraId_FK], [entryDate], [entryData], [hostName]
        )
        SELECT
            sourceAction.[buildingActionID], sourceAction.[buildingActionUDID],
            CASE
                WHEN sourceAction.[buildingActionTypeID_FK] = 3
                     AND sourceAction.[buildingActionExtraInt1] IS NULL THEN 3
                WHEN sourceAction.[buildingActionTypeID_FK] = 3
                     AND sourceAction.[buildingActionExtraInt1] = 1 THEN 59
                WHEN sourceAction.[buildingActionTypeID_FK] = 3
                     AND sourceAction.[buildingActionExtraInt1] IN (2, 3) THEN 57
                WHEN sourceAction.[buildingActionTypeID_FK] = 3
                     AND sourceAction.[buildingActionExtraInt1] = 4 THEN 58
                WHEN sourceAction.[buildingActionTypeID_FK] = 3
                     AND sourceAction.[buildingActionExtraInt1] = 5 THEN 3
                WHEN sourceAction.[buildingActionTypeID_FK] = 18
                     AND sourceAction.[generalNo_FK] IS NOT NULL
                     AND NOT EXISTS
                     (
                         SELECT 1
                         FROM [KFMC].[Housing].[BuildingAction] laterAction
                         WHERE laterAction.[generalNo_FK] = sourceAction.[generalNo_FK]
                           AND laterAction.[buildingActionID] > sourceAction.[buildingActionID]
                     ) THEN 39
                ELSE sourceAction.[buildingActionTypeID_FK]
            END,
            sourceAction.[buildingStatusID_FK],
            CONVERT(bigint, sourceResident.[residentInfoID]),
            CONVERT(bigint, sourceAction.[generalNo_FK]),
            sourceAction.[buildingPaymentTypeID_FK],
            CONVERT(bigint, sourceBuilding.[buildingDetailsID]), sourceAction.[buildingDetailsNo],
            sourceAction.[buildingActionFromDate], sourceAction.[buildingActionToDate],
            sourceAction.[buildingActionDate], sourceAction.[buildingActionDate2],
            sourceAction.[buildingActionDecisionNo], sourceAction.[buildingActionDecisionDate],
            sourceAction.[fromDSD_FK], sourceAction.[toDSD_FK],
            sourceAction.[buildingActionFromSourceID_FK], sourceAction.[buildingActionToSourceID_FK],
            sourceAction.[buildingActionNote], sourceAction.[buildingActionExtraText1],
            sourceAction.[buildingActionExtraText2], sourceAction.[buildingActionExtraText3],
            sourceAction.[buildingActionExtraText4],
            N'LEGACY',
            sourceAction.[buildingActionExtraDate1],
            sourceAction.[buildingActionExtraDate2], sourceAction.[buildingActionExtraDate3],
            sourceAction.[buildingActionExtraFloat1], sourceAction.[buildingActionExtraFloat2],
            sourceAction.[buildingActionExtraInt1], sourceAction.[buildingActionExtraInt2],
            sourceAction.[buildingActionExtraInt3], sourceAction.[buildingActionExtraInt4],
            sourceAction.[buildingActionExtraType1], sourceAction.[buildingActionExtraType2],
            sourceAction.[buildingActionExtraType3], sourceAction.[buildingActionActive],
            COALESCE
            (
                parentDuplicate.[retainedActionID],
                CASE WHEN letterAllocationParent.[buildingActionID] IS NOT NULL
                     THEN letterAllocationParent.[buildingActionParentID] END,
                sourceAction.[buildingActionParentID]
            ),
NULL, -- CustdyRecord
NULL, -- AssignPeriodID_FK
NULL, -- InAssignPeriod
CASE
    WHEN sourceAction.[buildingActionTypeID_FK] = 24
         AND sourceAction.[buildingActionExtraType1] = 2 THEN 1
    WHEN sourceAction.[buildingActionTypeID_FK] = 24
         AND sourceAction.[buildingActionExtraType1] = 3 THEN 3
    WHEN sourceAction.[buildingActionTypeID_FK] = 24
         AND sourceAction.[buildingActionExtraType1] = 4 THEN 2
END, -- ExtendReasonTypeID_FK
CASE
    WHEN sourceAction.[buildingActionTypeID_FK] = 2
        THEN sourceAction.[buildingActionDate]
    WHEN sourceAction.[buildingActionTypeID_FK] = 3
        THEN exitOccupancy.[occupentDate]
END, -- OccupentDate
CASE
    WHEN sourceAction.[buildingActionTypeID_FK] = 3
        THEN sourceAction.[buildingActionDate]
END, -- ExitDate
@IdaraId,
sourceAction.[entryDate],
            [MoveData].[fn_MapEntryData](sourceAction.[entryData]),
            [MoveData].[fn_MapHostName](sourceAction.[hostName], sourceAction.[entryData])
        FROM [KFMC].[Housing].[BuildingAction] sourceAction
        LEFT JOIN [KFMC].[Housing].[ResidentInfo] sourceResident
          ON sourceResident.[generalNo] = sourceAction.[generalNo_FK]
        LEFT JOIN [KFMC].[Housing].[BuildingDetails] sourceBuilding
          ON LTRIM(RTRIM(sourceBuilding.[buildingDetailsNo])) = LTRIM(RTRIM(sourceAction.[buildingDetailsNo]))
        LEFT JOIN ExitOccupancy exitOccupancy
          ON exitOccupancy.[exitActionID] = sourceAction.[buildingActionID]
        LEFT JOIN #DuplicateActionMap parentDuplicate
          ON parentDuplicate.[duplicateActionID] = sourceAction.[buildingActionParentID]
        LEFT JOIN [KFMC].[Housing].[BuildingAction] letterAllocationParent
          ON letterAllocationParent.[buildingActionID] = sourceAction.[buildingActionParentID]
         AND letterAllocationParent.[buildingActionTypeID_FK] = 27
         AND EXISTS
         (
             SELECT 1
             FROM [KFMC].[Housing].[BuildingAction] letterRoot
             WHERE letterRoot.[buildingActionID] = letterAllocationParent.[buildingActionParentID]
               AND letterRoot.[buildingActionTypeID_FK] = 7
         )
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [Housing].[BuildingAction] targetAction
            WHERE targetAction.[buildingActionID] = sourceAction.[buildingActionID]
        )
          AND NOT EXISTS
        (
            SELECT 1
            FROM #DuplicateActionMap duplicateAction
            WHERE duplicateAction.[duplicateActionID] = sourceAction.[buildingActionID]
        )
          /* Keep NULL general numbers because they are valid building-only actions.
             Exclude cancellation placeholders 0/1 and non-NULL numbers that do
             not belong to a real KFMC resident. */
          AND
          (
              sourceAction.[generalNo_FK] IS NULL
              OR
              (
                  sourceAction.[generalNo_FK] NOT IN (0,1)
                  AND sourceResident.[residentInfoID] IS NOT NULL
              )
          )
          /* Letter housing uses OtherWaitingListSP in DATACORE: 7 -> 45/2, not 7 -> 27. */
          AND NOT
          (
              sourceAction.[buildingActionTypeID_FK] = 27
              AND EXISTS
              (
                  SELECT 1
                  FROM [KFMC].[Housing].[BuildingAction] letterRoot
                  WHERE letterRoot.[buildingActionID] = sourceAction.[buildingActionParentID]
                    AND letterRoot.[buildingActionTypeID_FK] = 7
              )
          )
        OPTION (MAXRECURSION 100);

        SET @ActionsInserted = @@ROWCOUNT;
        SET IDENTITY_INSERT [Housing].[BuildingAction] OFF;
        SET @ActionIdentity = 0;

        SET IDENTITY_INSERT [Housing].[BuildingAssign] ON;
        SET @AssignIdentity = 1;

        ;WITH OrderedAssignments AS
        (
            SELECT
                s.*,
                LAG(s.[BuildingAssignID]) OVER
                (
                    PARTITION BY s.[GeneralNo],s.[BuildingActionID_FK]
                    ORDER BY s.[BuildingAssignID]
                ) [PreviousAssignID]
            FROM [KFMC].[Housing].[BuildingAssign] s
        ),
        ValidAssignments AS
        (
            SELECT currentRow.*
            FROM OrderedAssignments currentRow
            JOIN [KFMC].[Housing].[BuildingAction] ownerAction
              ON ownerAction.[buildingActionID] = currentRow.[BuildingActionID_FK]
             AND CONVERT(nvarchar(100),ownerAction.[generalNo_FK])
                 = CONVERT(nvarchar(100),currentRow.[GeneralNo])
             AND ownerAction.[generalNo_FK] NOT IN (0,1)
             AND EXISTS
             (
                 SELECT 1
                 FROM [KFMC].[Housing].[ResidentInfo] validResident
                 WHERE validResident.[generalNo]=ownerAction.[generalNo_FK]
             )
            LEFT JOIN [KFMC].[Housing].[BuildingAssign] previousRow
              ON previousRow.[BuildingAssignID] = currentRow.[PreviousAssignID]
            WHERE previousRow.[BuildingAssignID] IS NULL
               OR EXISTS
               (
                   SELECT currentRow.[BuildingAssignTypeID_FK],currentRow.[ParentBuildingAssignID],
                          currentRow.[BuildingNo],currentRow.[BuildingAssignStatusID_FK],currentRow.[MeterReadValue]
                   EXCEPT
                   SELECT previousRow.[BuildingAssignTypeID_FK],previousRow.[ParentBuildingAssignID],
                          previousRow.[BuildingNo],previousRow.[BuildingAssignStatusID_FK],previousRow.[MeterReadValue]
               )
        )
        INSERT INTO [Housing].[BuildingAssign]
        (
            [BuildingAssignID], [GeneralNo], [BuildingActionID_FK], [BuildingAssignTypeID_FK],
            [ParentBuildingAssignID], [BuildingNo], [BuildingAssignDate], [BuildingAssignNo],
            [BuildingAssignStatusID_FK], [buildingPaymentTypeID_FK],
            [buildingActionDecisionNo], [buildingActionDecisionDate],
            [buildingActionOccupentDate], [MeterReadValue], [buildingActionLetterNo],
            [buildingActionLetterDate], [Note], [entryDate], [entryData], [hostName]
        )
        SELECT
            s.[BuildingAssignID], s.[GeneralNo],
            COALESCE
            (
                assignedActionDuplicate.[retainedActionID],
                CASE WHEN letterAllocation.[buildingActionID] IS NOT NULL
                     THEN letterAllocation.[buildingActionParentID] END,
                s.[BuildingActionID_FK]
            ),
            s.[BuildingAssignTypeID_FK], s.[ParentBuildingAssignID], s.[BuildingNo],
            s.[BuildingAssignDate], s.[BuildingAssignNo], s.[BuildingAssignStatusID_FK],
            s.[buildingPaymentTypeID_FK], s.[buildingActionDecisionNo],
            s.[buildingActionDecisionDate], s.[buildingActionOccupentDate], s.[MeterReadValue],
            s.[buildingActionLetterNo], s.[buildingActionLetterDate], s.[Note],
            s.[entryDate],
            [MoveData].[fn_MapEntryData](s.[entryData]),
            [MoveData].[fn_MapHostName](s.[hostName], s.[entryData])
        FROM ValidAssignments s
        LEFT JOIN #DuplicateActionMap assignedActionDuplicate
          ON assignedActionDuplicate.[duplicateActionID] = s.[BuildingActionID_FK]
        LEFT JOIN [KFMC].[Housing].[BuildingAction] letterAllocation
          ON letterAllocation.[buildingActionID] = s.[BuildingActionID_FK]
         AND letterAllocation.[buildingActionTypeID_FK] = 27
         AND EXISTS
         (
             SELECT 1
             FROM [KFMC].[Housing].[BuildingAction] letterRoot
             WHERE letterRoot.[buildingActionID] = letterAllocation.[buildingActionParentID]
               AND letterRoot.[buildingActionTypeID_FK] = 7
         )
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [Housing].[BuildingAssign] t
            WHERE t.[BuildingAssignID] = s.[BuildingAssignID]
        );

        SET @AssignmentsInserted = @@ROWCOUNT;
        SET IDENTITY_INSERT [Housing].[BuildingAssign] OFF;
        SET @AssignIdentity = 0;

        SELECT @RollbackAfterTest [RollbackAfterTest],
               @ActionsInserted [BuildingActionsInserted],
               @DuplicateActionsExcluded [DuplicateActionsExcluded],
               @AssignmentsInserted [BuildingAssignmentsInserted],
               (SELECT COUNT_BIG(*) FROM [Housing].[BuildingAction]
                WHERE [residentInfoID_FK] IS NULL AND [generalNo_FK] IS NOT NULL) [ActionsWithUnmatchedResident],
               (SELECT COUNT_BIG(*) FROM [Housing].[BuildingAction]
                WHERE [buildingDetailsID_FK] IS NULL
                  AND NULLIF(LTRIM(RTRIM([buildingDetailsNo])), N'') IS NOT NULL
                  AND ([buildingActionTypeID_FK] IS NULL
                       OR [buildingActionTypeID_FK] NOT IN (4,5,8,9,10,11,12,13,14,15,16,17,29,30,31))) [ActionsWithUnmatchedBuilding],
               (SELECT COUNT_BIG(*) FROM [Housing].[BuildingAction]
                WHERE [buildingActionTypeID_FK] = 2
                  AND [buildingActionActive] = 1
                  AND [OccupentDate] IS NULL) [HousingActionsWithoutOccupentDate],
               (SELECT COUNT_BIG(*) FROM [Housing].[BuildingAction]
                WHERE [buildingActionTypeID_FK] = 3
                  AND [buildingActionActive] = 1
                  AND ([OccupentDate] IS NULL OR [ExitDate] IS NULL)) [ExitActionsWithMissingDates];

        IF @RollbackAfterTest = 1 ROLLBACK TRANSACTION; ELSE COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @AssignIdentity = 1 SET IDENTITY_INSERT [Housing].[BuildingAssign] OFF;
        IF @ActionIdentity = 1 SET IDENTITY_INSERT [Housing].[BuildingAction] OFF;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;