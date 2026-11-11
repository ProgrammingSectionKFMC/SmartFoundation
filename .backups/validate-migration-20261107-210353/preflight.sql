SET NOCOUNT ON; DECLARE @IdaraId bigint=1;
DECLARE @Checks TABLE(Category nvarchar(100),CheckName nvarchar(300),ExpectedValue decimal(38,2),ActualValue decimal(38,2),Difference decimal(38,2),Result varchar(30),Notes nvarchar(1000));
    /* Build the same consecutive-duplicate action map used by the migration. */
    ;WITH OrderedSourceActions AS
    (
        SELECT
            sourceAction.*,
            LAG(sourceAction.buildingActionID) OVER
            (
                PARTITION BY
                    sourceAction.generalNo_FK,
                    ISNULL(LTRIM(RTRIM(sourceAction.buildingDetailsNo)),N'')
                ORDER BY sourceAction.buildingActionID
            ) previousEntityActionID
        FROM KFMC.Housing.BuildingAction sourceAction
        WHERE sourceAction.generalNo_FK IS NULL
           OR
           (
               sourceAction.generalNo_FK NOT IN (0,1,18)
               AND EXISTS
               (
                   SELECT 1 FROM KFMC.Housing.ResidentInfo validResident
                   WHERE validResident.generalNo=sourceAction.generalNo_FK
               )
           )
    )
    SELECT
        currentAction.buildingActionID duplicateActionID,
        previousAction.buildingActionID previousActionID
    INTO #ValidationDuplicateActionEdges
    FROM OrderedSourceActions currentAction
    JOIN KFMC.Housing.BuildingAction previousAction
  ON previousAction.buildingActionID=currentAction.previousEntityActionID
WHERE NOT EXISTS
(
    SELECT 1
    WHERE currentAction.buildingActionParentID IS NULL
      AND currentAction.buildingActionTypeID_FK IN (1,7,25)
)
AND NOT EXISTS
(
        SELECT
            currentAction.buildingActionTypeID_FK,currentAction.buildingStatusID_FK,
            currentAction.generalNo_FK,currentAction.buildingPaymentTypeID_FK,
            currentAction.buildingDetailsNo,currentAction.buildingActionFromDate,
            currentAction.buildingActionToDate,currentAction.buildingActionDate,
            currentAction.buildingActionDate2,currentAction.buildingActionDecisionNo,
            currentAction.buildingActionDecisionDate,currentAction.fromDSD_FK,
            currentAction.toDSD_FK,currentAction.buildingActionFromSourceID_FK,
            currentAction.buildingActionToSourceID_FK,currentAction.buildingActionNote,
            currentAction.buildingActionExtraText1,currentAction.buildingActionExtraText2,
            currentAction.buildingActionExtraText3,currentAction.buildingActionExtraText4,
            currentAction.buildingActionExtraDate1,currentAction.buildingActionExtraDate2,
            currentAction.buildingActionExtraDate3,currentAction.buildingActionExtraFloat1,
            currentAction.buildingActionExtraFloat2,currentAction.buildingActionExtraInt1,
            currentAction.buildingActionExtraInt2,currentAction.buildingActionExtraInt3,
            currentAction.buildingActionExtraInt4,currentAction.buildingActionExtraType1,
            currentAction.buildingActionExtraType2,currentAction.buildingActionExtraType3,
            currentAction.buildingActionActive,currentAction.buildingActionParentID
        EXCEPT
        SELECT
            previousAction.buildingActionTypeID_FK,previousAction.buildingStatusID_FK,
            previousAction.generalNo_FK,previousAction.buildingPaymentTypeID_FK,
            previousAction.buildingDetailsNo,previousAction.buildingActionFromDate,
            previousAction.buildingActionToDate,previousAction.buildingActionDate,
            previousAction.buildingActionDate2,previousAction.buildingActionDecisionNo,
            previousAction.buildingActionDecisionDate,previousAction.fromDSD_FK,
            previousAction.toDSD_FK,previousAction.buildingActionFromSourceID_FK,
            previousAction.buildingActionToSourceID_FK,previousAction.buildingActionNote,
            previousAction.buildingActionExtraText1,previousAction.buildingActionExtraText2,
            previousAction.buildingActionExtraText3,previousAction.buildingActionExtraText4,
            previousAction.buildingActionExtraDate1,previousAction.buildingActionExtraDate2,
            previousAction.buildingActionExtraDate3,previousAction.buildingActionExtraFloat1,
            previousAction.buildingActionExtraFloat2,previousAction.buildingActionExtraInt1,
            previousAction.buildingActionExtraInt2,previousAction.buildingActionExtraInt3,
            previousAction.buildingActionExtraInt4,previousAction.buildingActionExtraType1,
            previousAction.buildingActionExtraType2,previousAction.buildingActionExtraType3,
            previousAction.buildingActionActive,previousAction.buildingActionParentID
    );

    ;WITH DuplicatePaths AS
    (
        SELECT duplicateActionID,previousActionID retainedActionID,1 pathLevel
        FROM #ValidationDuplicateActionEdges

        UNION ALL

        SELECT path.duplicateActionID,edge.previousActionID,path.pathLevel+1
        FROM DuplicatePaths path
        JOIN #ValidationDuplicateActionEdges edge
          ON edge.duplicateActionID=path.retainedActionID
        WHERE path.pathLevel<100
    ),
    RankedPaths AS
    (
        SELECT duplicateActionID,retainedActionID,
               ROW_NUMBER() OVER
               (PARTITION BY duplicateActionID ORDER BY pathLevel DESC) rowNumber
        FROM DuplicatePaths
    )
    SELECT duplicateActionID,retainedActionID
    INTO #ValidationDuplicateActionMap
    FROM RankedPaths
    WHERE rowNumber=1
    OPTION (MAXRECURSION 100);

    CREATE UNIQUE CLUSTERED INDEX IX_ValidationDuplicateActionMap
        ON #ValidationDuplicateActionMap(duplicateActionID);

        /* Trial 2 — dynamic policy: exclude terminal 26 only when it follows 27
           and has neither descendants nor BuildingAssign links.  The data
           source (KFMC) remains unchanged. */
        SELECT source26.[buildingActionID] AS [Action26ID]
        INTO #ExcludedLeaf26
        FROM [KFMC].[Housing].[BuildingAction] source26
        JOIN [KFMC].[Housing].[BuildingAction] parent27
          ON parent27.[buildingActionID] = source26.[buildingActionParentID]
         AND parent27.[buildingActionTypeID_FK] = 27
        WHERE source26.[buildingActionTypeID_FK] = 26
          AND source26.[buildingActionActive] = 1
          AND NOT EXISTS
          (
              SELECT 1
              FROM [KFMC].[Housing].[BuildingAction] child
              WHERE child.[buildingActionParentID] = source26.[buildingActionID]
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM [KFMC].[Housing].[BuildingAssign] link
              WHERE link.[BuildingActionID_FK] = source26.[buildingActionID]
          );

        CREATE UNIQUE CLUSTERED INDEX [IX_ExcludedLeaf26]
            ON #ExcludedLeaf26 ([Action26ID]);

        /* Exclude terminal 21 only when it is a leaf and belongs directly
           to a legacy waiting root. No source changes, and no orphan children. */
        SELECT moved.[buildingActionID] AS [Action21ID]
        INTO #ExcludedLeaf21
        FROM [KFMC].[Housing].[BuildingAction] moved
        JOIN [KFMC].[Housing].[BuildingAction] parentRoot
          ON parentRoot.[buildingActionID] = moved.[buildingActionParentID]
         AND parentRoot.[buildingActionParentID] IS NULL
         AND parentRoot.[buildingActionTypeID_FK] IN (1,7,25)
        WHERE moved.[buildingActionTypeID_FK] = 21
          AND moved.[buildingActionActive] = 1
          AND NOT EXISTS
          (
              SELECT 1 FROM [KFMC].[Housing].[BuildingAction] child
              WHERE child.[buildingActionParentID] = moved.[buildingActionID]
          )
          AND NOT EXISTS
          (
              SELECT 1 FROM [KFMC].[Housing].[BuildingAssign] assigned
              WHERE assigned.[BuildingActionID_FK] = moved.[buildingActionID]
          );

        CREATE UNIQUE CLUSTERED INDEX [IX_ExcludedLeaf21]
            ON #ExcludedLeaf21 ([Action21ID]);

        /* Determine the active terminal action of every independent waiting
           chain. Compare EFFECTIVE destination class, not the legacy class.
           Never treat an old occupied/exited chain as a current wait merely
           because the root row still has buildingActionActive=1. */
        ;WITH WaitingRoots AS
        (
            SELECT
                root.[buildingActionID] AS [RootID],
                root.[generalNo_FK] AS [GeneralNo],
                CASE
                    WHEN root.[buildingActionTypeID_FK] = 7 THEN 17
                    WHEN root.[buildingActionTypeID_FK] = 25 THEN 18
                    WHEN root.[buildingActionTypeID_FK] = 1
                     AND root.[buildingActionExtraType1] = 99 THEN 5
                    ELSE root.[buildingActionExtraType1]
                END AS [EffectiveClassID]
            FROM [KFMC].[Housing].[BuildingAction] root
            WHERE root.[buildingActionParentID] IS NULL
              AND root.[buildingActionTypeID_FK] IN (1,7,25)
              AND root.[buildingActionActive] = 1
              AND root.[generalNo_FK] IS NOT NULL
              AND root.[generalNo_FK] NOT IN (0,1,18)
        ),
        WaitingTree AS
        (
            SELECT
                r.[RootID], r.[GeneralNo], r.[EffectiveClassID],
                root.[buildingActionID] AS [ActionID],
                root.[buildingActionTypeID_FK] AS [ActionTypeID],
                CONVERT(int, 0) AS [Depth]
            FROM WaitingRoots r
            JOIN [KFMC].[Housing].[BuildingAction] root
              ON root.[buildingActionID] = r.[RootID]
            UNION ALL
            SELECT
                t.[RootID], t.[GeneralNo], t.[EffectiveClassID],
                child.[buildingActionID], child.[buildingActionTypeID_FK],
                t.[Depth] + 1
            FROM WaitingTree t
            JOIN [KFMC].[Housing].[BuildingAction] child
              ON child.[buildingActionParentID] = t.[ActionID]
             AND child.[buildingActionActive] = 1
            WHERE t.[Depth] < 100
        ),
        RankedTerminals AS
        (
            SELECT t.*,
                ROW_NUMBER() OVER
                (
                    PARTITION BY t.[RootID]
                    ORDER BY t.[Depth] DESC, t.[ActionID] DESC
                ) AS [rn]
            FROM WaitingTree t
        )
        SELECT [RootID], [GeneralNo], [EffectiveClassID],
               [ActionID] AS [TerminalActionID],
               [ActionTypeID] AS [TerminalActionTypeID]
        INTO #WaitingRootTerminals
        FROM RankedTerminals
        WHERE [rn] = 1
        OPTION (MAXRECURSION 100);

        CREATE UNIQUE CLUSTERED INDEX [IX_WaitingRootTerminals]
            ON #WaitingRootTerminals ([RootID]);
        CREATE INDEX [IX_WaitingRootTerminals_Key]
            ON #WaitingRootTerminals ([GeneralNo], [EffectiveClassID]);

        /* Trial 2: canonical duplicate policy by GeneralNo + EFFECTIVE class + Idara.
           Source KFMC is read only. Never cancel a different waiting class.
           Conservative rules: occupied supersedes parallel pending; one allocated
           27 WITH BuildingAssign supersedes other pending; 27 supersedes leaf26;
           pure 1/1 duplicates keep the earliest decision date, then entry date.
           Anything unresolved is retained and blocks this migration rather than
           being silently dropped. */
        SELECT t.[RootID],t.[GeneralNo],t.[EffectiveClassID],
               @IdaraId AS [ScopeIdaraID] /* TRIAL2_SOURCE_IDARA_SCOPE_FIX */,
               t.[TerminalActionTypeID],
               r.[buildingActionDecisionDate] AS [WaitingDecisionDate],
               r.[entryDate] AS [RootEntryDate],
               CASE
                 WHEN t.[TerminalActionTypeID]=2 THEN N'OCCUPIED'
                 WHEN t.[TerminalActionTypeID] IN (1,18,27)
                   OR (t.[TerminalActionTypeID]=26 AND EXISTS
                       (SELECT 1 FROM #ExcludedLeaf26 e
                        WHERE e.[Action26ID]=t.[TerminalActionID]))
                   THEN N'PENDING'
                 ELSE N'OTHER'
               END AS [EffectiveState],
               CASE WHEN EXISTS
               (
                   SELECT 1 FROM [KFMC].[Housing].[BuildingAction] a27
                   JOIN [KFMC].[Housing].[BuildingAssign] ba
                     ON ba.[BuildingActionID_FK]=a27.[buildingActionID]
                   WHERE a27.[buildingActionParentID]=t.[RootID]
                     AND a27.[buildingActionTypeID_FK]=27
               ) THEN 1 ELSE 0 END AS [Has27Assignments]
        INTO #RootCandidates
        FROM #WaitingRootTerminals t
        JOIN [KFMC].[Housing].[BuildingAction] r ON r.[buildingActionID]=t.[RootID];
        CREATE UNIQUE CLUSTERED INDEX IX_RootCandidates_Root ON #RootCandidates(RootID);
        CREATE INDEX IX_RootCandidates_Key ON #RootCandidates
            (GeneralNo,EffectiveClassID,ScopeIdaraID);

        SELECT GeneralNo,EffectiveClassID,ScopeIdaraID,
               SUM(CASE WHEN EffectiveState=N'PENDING' THEN 1 ELSE 0 END) AS PendingCount,
               SUM(CASE WHEN EffectiveState=N'OCCUPIED' THEN 1 ELSE 0 END) AS OccupiedCount,
               SUM(CASE WHEN EffectiveState=N'PENDING' AND Has27Assignments=1
                        THEN 1 ELSE 0 END) AS AssignedPendingCount,
               SUM(CASE WHEN EffectiveState=N'PENDING'
                          AND TerminalActionTypeID=27 THEN 1 ELSE 0 END) AS Pending27Count,
               SUM(CASE WHEN EffectiveState=N'PENDING'
                          AND TerminalActionTypeID=26 THEN 1 ELSE 0 END) AS Pending26Count,
               SUM(CASE WHEN EffectiveState=N'PENDING'
                          AND TerminalActionTypeID=1 THEN 1 ELSE 0 END) AS Pending1Count
        INTO #RootDuplicateGroups
        FROM #RootCandidates
        WHERE EffectiveClassID IS NOT NULL
        GROUP BY GeneralNo,EffectiveClassID,ScopeIdaraID;
        CREATE UNIQUE CLUSTERED INDEX IX_RootDuplicateGroups
          ON #RootDuplicateGroups(GeneralNo,EffectiveClassID,ScopeIdaraID);

        ;WITH Ranked AS
        (
          SELECT c.*,
            ROW_NUMBER() OVER
            (
              PARTITION BY c.GeneralNo,c.EffectiveClassID,c.ScopeIdaraID
              ORDER BY
                CASE
                  WHEN c.TerminalActionTypeID=27 AND c.Has27Assignments=1 THEN 0 /* TRIAL2_54012_27_OVER_26 */
                  WHEN c.TerminalActionTypeID=27 THEN 1
                  WHEN c.TerminalActionTypeID=26 THEN 2
                  WHEN c.TerminalActionTypeID=1 THEN 3 ELSE 4
                END,
                COALESCE(c.WaitingDecisionDate,c.RootEntryDate),
                c.RootEntryDate,c.RootID
            ) AS PriorityRank
          FROM #RootCandidates c
          WHERE c.EffectiveState=N'PENDING'
            AND c.EffectiveClassID IS NOT NULL
        )
        SELECT r.RootID,
          CASE WHEN g.OccupiedCount>0 THEN N'DUPLICATE_PENDING_WITH_OCCUPANCY'
               ELSE N'DUPLICATE_PENDING_SAME_CLASS' END AS Reason
        INTO #AutoResolvedDuplicateRoots
        FROM Ranked r
        JOIN #RootDuplicateGroups g
          ON g.GeneralNo=r.GeneralNo
         AND g.EffectiveClassID=r.EffectiveClassID
         AND g.ScopeIdaraID=r.ScopeIdaraID
        WHERE
          (g.OccupiedCount>0)
          OR
          (
            g.OccupiedCount=0 AND g.PendingCount>1 AND r.PriorityRank>1
            AND
            (
              g.AssignedPendingCount=1
              OR (g.AssignedPendingCount=0 AND g.Pending1Count=g.PendingCount)
              OR (g.Pending27Count=1
                  AND g.Pending26Count=g.PendingCount-1)
            )
          );
        CREATE UNIQUE CLUSTERED INDEX IX_AutoResolvedDuplicateRoots
          ON #AutoResolvedDuplicateRoots(RootID);

        INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
        SELECT N'Building actions',N'Unresolved source pending-root duplicate groups',0,COUNT_BIG(*),COUNT_BIG(*),
               CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
               N'Same conservative root-resolution policy as the live migration; ambiguous history is retained and fails validation.'
        FROM #RootDuplicateGroups g
        WHERE g.PendingCount>1 AND g.OccupiedCount=0
          AND (SELECT COUNT_BIG(*) FROM #RootCandidates c
               WHERE c.GeneralNo=g.GeneralNo AND c.EffectiveClassID=g.EffectiveClassID
                 AND c.ScopeIdaraID=g.ScopeIdaraID AND c.EffectiveState=N'PENDING'
                 AND NOT EXISTS(SELECT 1 FROM #AutoResolvedDuplicateRoots x WHERE x.RootID=c.RootID))>1;

        /* REVIEW DRAFT 2026-11-07: stage 4 evacuations mapped to 57; 18 is pending (MAIN=allocation, SIDE=waiting),
           not terminal; source 21 exclusion and root deactivation remain unchanged.
           Stage designation must also be verified in relevant views/validators.
           Root cancellation is conditional and GENERAL, not an ID allowlist.
           19=retirement, 20=transfer, 23=entered in error.
           21 is cancelled as a current waiting root in all cases; an existing valid
           same-class root (if present) must be preserved.
           Pending 26/27 with an occupied same-class chain must not resurrect. */
        SELECT
            terminal.[RootID],
            CASE
                WHEN terminal.[TerminalActionTypeID] IN (19,20,22,23,28)
                    THEN N'TERMINATED_OR_ENTERED_IN_ERROR'
                WHEN terminal.[TerminalActionTypeID]=21
                    THEN N'TRANSFERRED_21_CANCELLED'
                ELSE duplicateRoot.[Reason]
            END AS [Reason]
        INTO #RootsToDeactivate
        FROM #WaitingRootTerminals terminal
        LEFT JOIN #AutoResolvedDuplicateRoots duplicateRoot
          ON duplicateRoot.[RootID]=terminal.[RootID]
        WHERE terminal.[TerminalActionTypeID] IN (19,20,21,22,23,28)
           OR duplicateRoot.[RootID] IS NOT NULL;

        CREATE UNIQUE CLUSTERED INDEX [IX_RootsToDeactivate]
            ON #RootsToDeactivate ([RootID]);

        /* If a redundant pending 27 has no retained children or assignments,
           it can be excluded. If it has BuildingAssign history, preserve it
           under its deactivated root (but never treat it as current). */
        SELECT allocation.[buildingActionID] AS [Action27ID]
        INTO #ExcludedDuplicate27
        FROM [KFMC].[Housing].[BuildingAction] allocation
        JOIN #RootsToDeactivate cancelledRoot
          ON cancelledRoot.[RootID] = allocation.[buildingActionParentID]
         AND cancelledRoot.[Reason] IN (N'DUPLICATE_PENDING_WITH_OCCUPANCY',N'DUPLICATE_PENDING_SAME_CLASS')
        WHERE allocation.[buildingActionTypeID_FK] = 27
          AND NOT EXISTS
          (
              SELECT 1 FROM [KFMC].[Housing].[BuildingAssign] linked
              WHERE linked.[BuildingActionID_FK] = allocation.[buildingActionID]
          )
          AND NOT EXISTS
          (
              SELECT 1 FROM [KFMC].[Housing].[BuildingAction] child
              WHERE child.[buildingActionParentID] = allocation.[buildingActionID]
                AND NOT EXISTS
                (
                    SELECT 1 FROM #ExcludedLeaf26 excluded26
                    WHERE excluded26.[Action26ID] = child.[buildingActionID]
                )
          );

        CREATE UNIQUE CLUSTERED INDEX [IX_ExcludedDuplicate27]
            ON #ExcludedDuplicate27 ([Action27ID]);


    /* One canonical source-ID eligibility set, copied from live migration predicates.
       NOT EXISTS predicates are NULL-safe; a NULL action type is not an exclusion. */
    SELECT sourceAction.buildingActionID
    INTO #ValidationEligibleBuildingActions
    FROM KFMC.Housing.BuildingAction sourceAction
    LEFT JOIN KFMC.Housing.ResidentInfo sourceResident
      ON sourceResident.generalNo=sourceAction.generalNo_FK
    WHERE 1=1
      AND NOT EXISTS
        (
            SELECT 1
            FROM #ExcludedLeaf26 excluded26
            WHERE excluded26.[Action26ID] = sourceAction.[buildingActionID]
        )
          AND NOT EXISTS
        (
            SELECT 1 FROM #ExcludedLeaf21 excluded21
            WHERE excluded21.[Action21ID] = sourceAction.[buildingActionID]
        )
          AND NOT EXISTS
        (
            SELECT 1 FROM #ExcludedDuplicate27 excluded27
            WHERE excluded27.[Action27ID] = sourceAction.[buildingActionID]
        )
          AND NOT EXISTS
        (
            SELECT 1
            FROM #ValidationDuplicateActionMap duplicateAction
            WHERE duplicateAction.[duplicateActionID] = sourceAction.[buildingActionID]
        )
        /* Exclude isolated inactive legacy waiting roots only.
   Preserve roots with any historical child or assignment. */
AND NOT EXISTS
(
    SELECT 1
    FROM KFMC.Housing.BuildingAction root
    WHERE root.buildingActionID = sourceAction.buildingActionID
      AND root.buildingActionParentID IS NULL
      AND root.buildingActionTypeID_FK IN (1,7,25)
      AND ISNULL(root.buildingActionActive,0) = 0
      AND NOT EXISTS
      (
          SELECT 1
          FROM KFMC.Housing.BuildingAction child
          WHERE child.buildingActionParentID = root.buildingActionID
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM KFMC.Housing.BuildingAssign ba
          WHERE ba.BuildingActionID_FK = root.buildingActionID
      )
)
          /* Keep NULL general numbers because they are valid building-only actions.
             Exclude cancellation placeholders 0/1 and non-NULL numbers that do
             not belong to a real KFMC resident. */
          AND
          (
              sourceAction.[generalNo_FK] IS NULL
              OR
              (
                  sourceAction.[generalNo_FK] NOT IN (0,1,18)
                  AND sourceResident.[residentInfoID] IS NOT NULL
                  AND EXISTS
                  (
                      SELECT 1 FROM [Housing].[ResidentInfo] eligibleTarget
                      WHERE eligibleTarget.[residentInfoID] =
                            TRY_CONVERT(bigint,sourceResident.[residentInfoID])
                  )
              )
          )
          /* Remove an unfinished direct SIDE allocation 27 only if it has no
             retained children after the qualified leaf-26 exclusion. Preserve
             any allocation with BuildingAssign links, or any other descendant. */
          /* Exclude unfinished direct SIDE allocation 27 only.
   Preserve linked assignments and retained descendants.
   NULL action types must remain eligible. */
AND NOT EXISTS
(
    SELECT 1
    FROM [KFMC].[Housing].[BuildingAction] root
    LEFT JOIN [Housing].[WaitingClass] waitingClass
      ON waitingClass.[waitingClassID] = root.[buildingActionExtraType1]
    WHERE sourceAction.[buildingActionTypeID_FK] = 27
      AND root.[buildingActionID] = sourceAction.[buildingActionParentID]
      AND root.[buildingActionParentID] IS NULL
      AND
      (
          root.[buildingActionTypeID_FK] IN (7,25)
          OR
          (
              root.[buildingActionTypeID_FK] = 1
              AND
              (
                  root.[buildingActionExtraType1] = 99
                  OR waitingClass.[idara_FK] = 1
              )
          )
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM [KFMC].[Housing].[BuildingAction] child
          WHERE child.[buildingActionParentID] = sourceAction.[buildingActionID]
            AND NOT EXISTS
            (
                SELECT 1
                FROM #ExcludedLeaf26 excluded26
                WHERE excluded26.[Action26ID] = child.[buildingActionID]
            )
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM [KFMC].[Housing].[BuildingAssign] link
          WHERE link.[BuildingActionID_FK] = sourceAction.[buildingActionID]
      )
)
        ;
    CREATE UNIQUE CLUSTERED INDEX IX_ValidationEligibleBuildingActions
      ON #ValidationEligibleBuildingActions(buildingActionID);
    /* Compare membership by source ID, not cardinality alone. Synthetic and
       later operational target-only actions are outside the source identity domain. */
    SELECT sourceAction.buildingActionID,
           CASE WHEN eligible.buildingActionID IS NOT NULL THEN 1 ELSE 0 END AS IsExpected,
           CASE WHEN targetAction.buildingActionID IS NOT NULL THEN 1 ELSE 0 END AS IsActual
    INTO #ValidationBuildingActionMembership
    FROM KFMC.Housing.BuildingAction sourceAction
    LEFT JOIN #ValidationEligibleBuildingActions eligible
      ON eligible.buildingActionID=sourceAction.buildingActionID
    LEFT JOIN Housing.BuildingAction targetAction
      ON targetAction.buildingActionID=CONVERT(bigint,sourceAction.buildingActionID);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Completeness',N'Building actions',
           COALESCE(SUM(CONVERT(bigint,IsExpected)),0),COALESCE(SUM(CONVERT(bigint,IsActual)),0),
           COALESCE(SUM(CONVERT(bigint,IsActual)-IsExpected),0),
           CASE WHEN COUNT_BIG(CASE WHEN IsExpected<>IsActual THEN 1 END)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Exact source-ID membership using one migration eligibility set; equal totals alone cannot pass.'
    FROM #ValidationBuildingActionMembership;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Completeness',N'Building actions Missing',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Eligible source IDs missing in DATACORE.'
    FROM #ValidationBuildingActionMembership WHERE IsExpected=1 AND IsActual=0;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Completeness',N'Building actions Unexpected',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Excluded source IDs still present in DATACORE; generated target-only IDs are not imported source actions.'
    FROM #ValidationBuildingActionMembership WHERE IsExpected=0 AND IsActual=1;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Building actions',N'Waiting roots excluded by consecutive deduplication',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Root identities 1/7/25 must never be merged by consecutive deduplication.'
    FROM KFMC.Housing.BuildingAction a
    JOIN #ValidationDuplicateActionMap d ON d.duplicateActionID=a.buildingActionID
    WHERE a.buildingActionParentID IS NULL AND a.buildingActionTypeID_FK IN(1,7,25);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Building actions',N'Protected linked history excluded by leaf policies',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Leaf exclusions must not remove assignment history or retained children.'
    FROM KFMC.Housing.BuildingAction a
    WHERE (EXISTS(SELECT 1 FROM #ExcludedLeaf21 e WHERE e.Action21ID=a.buildingActionID)
        OR EXISTS(SELECT 1 FROM #ExcludedLeaf26 e WHERE e.Action26ID=a.buildingActionID)
        OR EXISTS(SELECT 1 FROM #ExcludedDuplicate27 e WHERE e.Action27ID=a.buildingActionID))
      AND (EXISTS(SELECT 1 FROM KFMC.Housing.BuildingAssign ba WHERE ba.BuildingActionID_FK=a.buildingActionID)
        OR EXISTS(SELECT 1 FROM KFMC.Housing.BuildingAction child
                  WHERE child.buildingActionParentID=a.buildingActionID
                    AND NOT EXISTS(SELECT 1 FROM #ExcludedLeaf26 e WHERE e.Action26ID=child.buildingActionID)));


SELECT Category,CheckName,ExpectedValue,ActualValue,Difference,Result FROM @Checks;
SELECT buildingActionID,IsExpected,IsActual FROM #ValidationBuildingActionMembership WHERE buildingActionID=22817;
