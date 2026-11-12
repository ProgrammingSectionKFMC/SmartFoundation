CREATE PROCEDURE [MoveData].[usp_MigrateBuildingActions]     @IdaraId bigint,     @RollbackAfterTest bit = 1 AS BEGIN     SET NOCOUNT ON;     /* Normalize migration administration: preserve a valid supplied value, otherwise use Idara 1. */     IF NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID = 1)
     THROW 57990, N'Default migration Idara 1 does not exist.', 1;     IF @IdaraId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID = @IdaraId)
     SET @IdaraId = 1;     SET XACT_ABORT ON;      IF NOT EXISTS (SELECT 1 FROM [dbo].[Idara] WHERE [idaraID] = @IdaraId)
     THROW 54000, N'The supplied IdaraId does not exist in DATACORE.dbo.Idara.', 1;     /* Class remapping 7=>17, 25=>18, 1/99=>5 is approved for Idara 1 only. */     IF @IdaraId <> 1
     THROW 54005, N'Waiting-class legacy remapping is configured only for Idara 1.', 1;      /* ACTIVE_RESIDENT_SCOPE_20261109
        A resident can participate in this migration only when their source
        ResidentInfo is active AND the same ResidentInfoID was actually migrated.
        Do not impose activity filters on historical actions themselves.
        Building-only actions with generalNo_FK IS NULL remain independent. */
     SELECT

     TRY_CONVERT(BIGINT, sourceResident.generalNo) AS GeneralNo,

     TRY_CONVERT(BIGINT, sourceResident.residentInfoID) AS ResidentInfoID
     INTO #ActiveMigratedResidents
     FROM KFMC.Housing.ResidentInfo AS sourceResident
     INNER JOIN Housing.ResidentInfo AS targetResident

     ON targetResident.residentInfoID = TRY_CONVERT(BIGINT, sourceResident.residentInfoID)
     WHERE sourceResident.residentInfoActive = 1
       AND targetResident.residentInfoActive = 1
       AND TRY_CONVERT(BIGINT, sourceResident.generalNo) IS NOT NULL
       AND TRY_CONVERT(BIGINT, sourceResident.generalNo) NOT IN (0,1,18);

     CREATE UNIQUE CLUSTERED INDEX IX_ActiveMigratedResidents_GeneralNo
       ON #ActiveMigratedResidents (GeneralNo);
     CREATE UNIQUE INDEX IX_ActiveMigratedResidents_ResidentInfoID
       ON #ActiveMigratedResidents (ResidentInfoID);

     IF EXISTS     (
     SELECT 1
     FROM (VALUES
         (5, N'بند التشغيل والصيانة'),
         (17, N'خطاب تسكين'),
         (18, N'خطاب تسكين عزاب')
     ) expected([ClassID], [ClassName])
     LEFT JOIN [Housing].[WaitingClass] wc
       ON wc.[waitingClassID] = expected.[ClassID]
      AND wc.[idara_FK] = 1
      AND wc.[waitingClassActive] = 1
      AND wc.[waitingClassName_A] = expected.[ClassName]
     WHERE wc.[waitingClassID] IS NULL     )
     THROW 54006, N'Required Idara 1 waiting classes (5,17,18) are not correctly configured.', 1;      IF EXISTS     (
     SELECT requiredType.[buildingActionTypeID]
     FROM (VALUES (3), (39), (57), (58), (59)) requiredType([buildingActionTypeID])
     WHERE NOT EXISTS
     (
         SELECT 1
         FROM [Housing].[BuildingActionType] targetType
         WHERE targetType.[buildingActionTypeID] = requiredType.[buildingActionTypeID]
     )     )
     THROW 54003, N'Required mapped action types 3, 39, 57, 58, and 59 must exist in DATACORE.Housing.BuildingActionType.', 1;     IF EXISTS     (
     SELECT 1
     FROM [KFMC].[Housing].[BuildingAction] sourceAction
     WHERE sourceAction.[buildingActionTypeID_FK] = 3

       AND EXISTS

       (

           SELECT 1 FROM #ActiveMigratedResidents eligible

           WHERE eligible.GeneralNo = TRY_CONVERT(BIGINT, sourceAction.generalNo_FK)

       )

       AND sourceAction.[buildingActionExtraInt1] IS NOT NULL
       AND sourceAction.[buildingActionExtraInt1] NOT IN (1, 2, 3, 4, 5)     )
     THROW 54004, N'KFMC contains an unsupported evacuation stage in buildingActionExtraInt1.', 1;
     /* TRIAL2_GENERIC_ACTION_ELIGIBILITY_20261105        Exactly the same generalNo action-count rule as usp_MigrateResidents. */     IF EXISTS     (
     SELECT 1
     FROM [KFMC].[Housing].[ResidentInfo] s
     WHERE s.residentInfoActive = 1

       AND TRY_CONVERT(bigint,s.generalNo) IS NOT NULL
       AND TRY_CONVERT(bigint,s.generalNo) NOT IN (0,1,18)
       AND EXISTS
       (
           SELECT 1 FROM [KFMC].[Housing].[BuildingAction] a
           WHERE a.generalNo_FK=TRY_CONVERT(bigint,s.generalNo)
           GROUP BY a.generalNo_FK
           HAVING COUNT_BIG(*) > 1
              OR MAX(CASE WHEN a.buildingActionTypeID_FK <> 6 THEN 1 ELSE 0 END)=1
       )
       AND NOT EXISTS
       (
           SELECT 1 FROM #ActiveMigratedResidents t

           WHERE t.ResidentInfoID = TRY_CONVERT(bigint,s.residentInfoID)

             AND t.GeneralNo = TRY_CONVERT(bigint,s.generalNo)

       )     )
     THROW 54001, N'An eligible KFMC resident is missing in DATACORE; migrate residents first.', 1;      /* Do not omit BuildingAssign history silently for the excluded lone-6 case. */     IF EXISTS     (
     SELECT 1
     FROM [KFMC].[Housing].[BuildingAction] a
     JOIN [KFMC].[Housing].[BuildingAssign] ba
       ON ba.BuildingActionID_FK=a.buildingActionID
     WHERE a.buildingActionTypeID_FK=6

       AND EXISTS

       (

           SELECT 1 FROM KFMC.Housing.ResidentInfo activeResident

           WHERE TRY_CONVERT(BIGINT, activeResident.generalNo) = TRY_CONVERT(BIGINT, a.generalNo_FK)

             AND activeResident.residentInfoActive = 1

       )

       AND a.generalNo_FK IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1 FROM [KFMC].[Housing].[BuildingAction] otherAction
           WHERE otherAction.generalNo_FK=a.generalNo_FK
             AND otherAction.buildingActionID<>a.buildingActionID
       )     )
     THROW 58212, N'An excluded lone-type-6 action has BuildingAssign references; investigate before migration.', 1;      IF EXISTS     (
     SELECT 1 FROM [KFMC].[Housing].[BuildingDetails] sourceBuilding
     LEFT JOIN [Housing].[BuildingDetails] targetBuilding
       ON targetBuilding.[buildingDetailsID] = CONVERT(bigint, sourceBuilding.[buildingDetailsID])
     WHERE targetBuilding.[buildingDetailsID] IS NULL     )
     THROW 54002, N'Run MoveData.usp_MigrateBuildings before migrating building actions.', 1;      /* A final, direct side-list allocation (27) is droppable only if it has        neither a child action nor any BuildingAssign reference. Guard against        data loss before starting the migration transaction. */     IF EXISTS     (
     SELECT 1
     FROM [KFMC].[Housing].[BuildingAction] allocation
     JOIN [KFMC].[Housing].[BuildingAction] root
       ON root.[buildingActionID] = allocation.[buildingActionParentID]
      AND root.[buildingActionParentID] IS NULL
     LEFT JOIN [Housing].[WaitingClass] waitingClass
       ON waitingClass.[waitingClassID] = root.[buildingActionExtraType1]
     WHERE allocation.[buildingActionTypeID_FK] = 27

       AND EXISTS (SELECT 1 FROM #ActiveMigratedResidents eligible

                WHERE eligible.GeneralNo = TRY_CONVERT(BIGINT, root.generalNo_FK))

       AND
       (
           root.[buildingActionTypeID_FK] IN (7,25)
           OR
           (
               root.[buildingActionTypeID_FK] = 1
               AND (root.[buildingActionExtraType1] = 99
                OR waitingClass.[idara_FK] = 1)
           )
       )
       AND NOT EXISTS
       (
           SELECT 1
           FROM [KFMC].[Housing].[BuildingAction] child
           WHERE child.[buildingActionParentID] = allocation.[buildingActionID]
             AND NOT
             (
                child.[buildingActionTypeID_FK] = 26
                AND NOT EXISTS
                (
                SELECT 1
                FROM [KFMC].[Housing].[BuildingAction] descendant
                WHERE descendant.[buildingActionParentID] = child.[buildingActionID]
                )
                AND NOT EXISTS
                (
                SELECT 1
                FROM [KFMC].[Housing].[BuildingAssign] childLink
                WHERE childLink.[BuildingActionID_FK] = child.[buildingActionID]
                )
             )
       )
       AND EXISTS
       (
           SELECT 1
           FROM [KFMC].[Housing].[BuildingAssign] assignment
           WHERE assignment.[BuildingActionID_FK] = allocation.[buildingActionID]
       )     )
     THROW 54007, N'A final side-list allocation 27 has BuildingAssign references; review before migration.', 1;      /* Any 27 with only inactive children may still be the effective current        action in the active view. Stop until those paths are reviewed. */     IF EXISTS     (
     SELECT 1
     FROM [KFMC].[Housing].[BuildingAction] allocation
     JOIN [KFMC].[Housing].[BuildingAction] root
       ON root.[buildingActionID] = allocation.[buildingActionParentID]
      AND root.[buildingActionParentID] IS NULL
     LEFT JOIN [Housing].[WaitingClass] waitingClass
       ON waitingClass.[waitingClassID] = root.[buildingActionExtraType1]
     WHERE allocation.[buildingActionTypeID_FK] = 27

       AND EXISTS (SELECT 1 FROM #ActiveMigratedResidents eligible

                WHERE eligible.GeneralNo = TRY_CONVERT(BIGINT, root.generalNo_FK))

       AND allocation.[buildingActionActive] = 1
       AND
       (
           root.[buildingActionTypeID_FK] IN (7,25)
           OR
           (
               root.[buildingActionTypeID_FK] = 1
               AND (root.[buildingActionExtraType1] = 99
                OR waitingClass.[idara_FK] = 1)
           )
       )
       AND EXISTS
       (
           SELECT 1
           FROM [KFMC].[Housing].[BuildingAction] child
           WHERE child.[buildingActionParentID] = allocation.[buildingActionID]
       )
       AND NOT EXISTS
       (
           SELECT 1
           FROM [KFMC].[Housing].[BuildingAction] activeChild
           WHERE activeChild.[buildingActionParentID] = allocation.[buildingActionID]
             AND activeChild.[buildingActionActive] = 1
       )     )
     THROW 54008, N'A side-list allocation 27 has only inactive children; inspect its effective current state.', 1;      DECLARE @ActionsInserted bigint = 0, @AssignmentsInserted bigint = 0;     DECLARE @DuplicateActionsExcluded bigint = 0;     DECLARE @ActionIdentity bit = 0, @AssignIdentity bit = 0;      BEGIN TRY
     BEGIN TRANSACTION;
      /* Trial 2 — dynamic policy: exclude terminal 26 only when it follows 27            and has neither descendants nor BuildingAssign links.  The data            source (KFMC) remains unchanged. */
     SELECT source26.[buildingActionID] AS [Action26ID]
     INTO #ExcludedLeaf26
     FROM [KFMC].[Housing].[BuildingAction] source26
     JOIN [KFMC].[Housing].[BuildingAction] parent27
       ON parent27.[buildingActionID] = source26.[buildingActionParentID]
      AND parent27.[buildingActionTypeID_FK] = 27
     WHERE source26.[buildingActionTypeID_FK] = 26

       AND EXISTS (SELECT 1 FROM #ActiveMigratedResidents eligible

                WHERE eligible.GeneralNo = TRY_CONVERT(BIGINT, source26.generalNo_FK))

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
      /* Exclude terminal 21 only when it is a leaf and belongs directly            to a legacy waiting root. No source changes, and no orphan children. */
     SELECT moved.[buildingActionID] AS [Action21ID]
     INTO #ExcludedLeaf21
     FROM [KFMC].[Housing].[BuildingAction] moved
     JOIN [KFMC].[Housing].[BuildingAction] parentRoot
       ON parentRoot.[buildingActionID] = moved.[buildingActionParentID]
      AND parentRoot.[buildingActionParentID] IS NULL
      AND parentRoot.[buildingActionTypeID_FK] IN (1,7,25)
     WHERE moved.[buildingActionTypeID_FK] = 21

       AND EXISTS (SELECT 1 FROM #ActiveMigratedResidents eligible

                WHERE eligible.GeneralNo = TRY_CONVERT(BIGINT, moved.generalNo_FK))

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
      /* Determine the active terminal action of every independent waiting            chain. Compare EFFECTIVE destination class, not the legacy class.            Never treat an old occupied/exited chain as a current wait merely            because the root row still has buildingActionActive=1. */
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

           AND EXISTS (SELECT 1 FROM #ActiveMigratedResidents eligible

                WHERE eligible.GeneralNo = TRY_CONVERT(BIGINT,root.generalNo_FK))

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
      /* Trial 2: canonical duplicate policy by GeneralNo + EFFECTIVE class + Idara.            Source KFMC is read only. Never cancel a different waiting class.            Conservative rules: occupied supersedes parallel pending; one allocated            27 WITH BuildingAssign supersedes other pending; 27 supersedes leaf26;            pure 1/1 duplicates keep the earliest decision date, then entry date.            Anything unresolved is retained and blocks this migration rather than            being silently dropped. */
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
      /* Any real unresolved duplicate remains protected. Fail before inserting.            Unknown/nonpending terminals are NOT removed based on suspicion. */
     IF EXISTS
     (
       SELECT 1
       FROM #RootDuplicateGroups g
       WHERE g.PendingCount>1 AND g.OccupiedCount=0
         AND
         (
           SELECT COUNT_BIG(*)
           FROM #RootCandidates c
           WHERE c.GeneralNo=g.GeneralNo
             AND c.EffectiveClassID=g.EffectiveClassID
             AND c.ScopeIdaraID=g.ScopeIdaraID
             AND c.EffectiveState=N'PENDING'
             AND NOT EXISTS
             (SELECT 1 FROM #AutoResolvedDuplicateRoots x WHERE x.RootID=c.RootID)
         )>1
     )
         THROW 54012, N'Unresolved same-class pending roots: migration stopped without deleting ambiguous requests.', 1;
      /* REVIEW DRAFT 2026-11-07: stage 4 evacuations mapped to 57; 18 is pending (MAIN=allocation, SIDE=waiting),            not terminal; source 21 exclusion and root deactivation remain unchanged.            Stage designation must also be verified in relevant views/validators.            Root cancellation is conditional and GENERAL, not an ID allowlist.            19=retirement, 20=transfer, 23=entered in error.            21 is cancelled as a current waiting root in all cases; an existing valid            same-class root (if present) must be preserved.            Pending 26/27 with an occupied same-class chain must not resurrect. */
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
      /* If a redundant pending 27 has no retained children or assignments,            it can be excluded. If it has BuildingAssign history, preserve it            under its deactivated root (but never treat it as current). */
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
      /*           A repeated button click may create an identical action immediately after           the previous action for the same resident/building. Actions belonging to           other residents/buildings do not break that sequence.            Keep the first action, skip every following identical action, and map any           parent references from the skipped action to the first retained action.           No rows are changed or deleted in KFMC.         */
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
                sourceAction.[generalNo_FK] NOT IN (0,1,18)
                AND EXISTS
                (
                SELECT 1
                FROM #ActiveMigratedResidents validResident

                WHERE validResident.GeneralNo=TRY_CONVERT(BIGINT,sourceAction.[generalNo_FK])
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
     /* A root is the identity of a distinct waiting chain, not a duplicate            button click. Never merge a root (1/7/25) into an adjacent root:            children can be lost or attached to a different historical chain. */
     WHERE NOT
     (
         currentAction.[buildingActionParentID] IS NULL
         AND currentAction.[buildingActionTypeID_FK] IN (1, 7, 25)
     )
       AND NOT EXISTS
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
             /* Only start/root actions change; no descendant action type changes. */
             WHEN sourceAction.[buildingActionParentID] IS NULL
              AND sourceAction.[buildingActionTypeID_FK] IN (7,25) THEN 1
             WHEN sourceAction.[buildingActionTypeID_FK] = 3
                AND sourceAction.[buildingActionExtraInt1] IS NULL THEN 3
             WHEN sourceAction.[buildingActionTypeID_FK] = 3
                AND sourceAction.[buildingActionExtraInt1] = 1 THEN 59
             WHEN sourceAction.[buildingActionTypeID_FK] = 3
                AND sourceAction.[buildingActionExtraInt1] IN (2, 3) THEN 57
             WHEN sourceAction.[buildingActionTypeID_FK] = 3
                AND sourceAction.[buildingActionExtraInt1] = 4 THEN 57
             WHEN sourceAction.[buildingActionTypeID_FK] = 3
                AND sourceAction.[buildingActionExtraInt1] = 5 THEN 3
             /* Legacy action 18 cancels this waiting request: do not remap it to 39. */
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
         CASE
             WHEN sourceAction.[buildingActionParentID] IS NULL
              AND sourceAction.[buildingActionTypeID_FK] = 7 THEN 17
             WHEN sourceAction.[buildingActionParentID] IS NULL
              AND sourceAction.[buildingActionTypeID_FK] = 25 THEN 18
             WHEN sourceAction.[buildingActionParentID] IS NULL
              AND sourceAction.[buildingActionTypeID_FK] = 1
              AND sourceAction.[buildingActionExtraType1] = 99 THEN 5
             ELSE sourceAction.[buildingActionExtraType1]
         END, sourceAction.[buildingActionExtraType2],
         sourceAction.[buildingActionExtraType3],
         CASE
             WHEN cancelledRoot.[RootID] IS NOT NULL THEN CONVERT(bit, 0)
             ELSE sourceAction.[buildingActionActive]
         END,
         COALESCE
         (
             parentDuplicate.[retainedActionID],
             sourceAction.[buildingActionParentID]
         ), NULL, -- CustdyRecord
NULL, -- AssignPeriodID_FK
NULL, -- InAssignPeriod
CASE     WHEN sourceAction.[buildingActionTypeID_FK] = 24
      AND sourceAction.[buildingActionExtraType1] = 2 THEN 1     WHEN sourceAction.[buildingActionTypeID_FK] = 24
      AND sourceAction.[buildingActionExtraType1] = 3 THEN 3     WHEN sourceAction.[buildingActionTypeID_FK] = 24
      AND sourceAction.[buildingActionExtraType1] = 4 THEN 2 END, -- ExtendReasonTypeID_FK
CASE     WHEN sourceAction.[buildingActionTypeID_FK] = 2
     THEN sourceAction.[buildingActionDate]     WHEN sourceAction.[buildingActionTypeID_FK] = 3
     THEN exitOccupancy.[occupentDate] END, -- OccupentDate
CASE     WHEN sourceAction.[buildingActionTypeID_FK] = 3
     THEN sourceAction.[buildingActionDate] END, -- ExitDate
@IdaraId, sourceAction.[entryDate],
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
     LEFT JOIN #RootsToDeactivate cancelledRoot
       ON cancelledRoot.[RootID] = sourceAction.[buildingActionID]
     WHERE NOT EXISTS
     (
         SELECT 1 FROM [Housing].[BuildingAction] targetAction
         WHERE targetAction.[buildingActionID] = sourceAction.[buildingActionID]
     )
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
         FROM #DuplicateActionMap duplicateAction
         WHERE duplicateAction.[duplicateActionID] = sourceAction.[buildingActionID]
     )
     /* Exclude isolated inactive legacy waiting roots only.     Preserve roots with any historical child or assignment. */  AND NOT EXISTS  (      SELECT 1      FROM KFMC.Housing.BuildingAction root      WHERE root.buildingActionID = sourceAction.buildingActionID
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
    )  )
       /* Keep NULL general numbers because they are valid building-only actions.              Exclude cancellation placeholders 0/1 and non-NULL numbers that do              not belong to a real KFMC resident. */
       AND
       (
           sourceAction.[generalNo_FK] IS NULL
           OR
           (
               sourceAction.[generalNo_FK] NOT IN (0,1,18)
               AND sourceResident.[residentInfoID] IS NOT NULL

               AND sourceResident.residentInfoActive = 1

               AND EXISTS

               (

                SELECT 1 FROM #ActiveMigratedResidents eligibleTarget

                WHERE eligibleTarget.ResidentInfoID = TRY_CONVERT(bigint,sourceResident.[residentInfoID])

                AND eligibleTarget.GeneralNo = TRY_CONVERT(bigint,sourceAction.[generalNo_FK])

               )
           )
       )
       /* Remove an unfinished direct SIDE allocation 27 only if it has no              retained children after the qualified leaf-26 exclusion. Preserve              any allocation with BuildingAssign links, or any other descendant. */
       /* Exclude unfinished direct SIDE allocation 27 only.     Preserve linked assignments and retained descendants.     NULL action types must remain eligible. */  AND NOT EXISTS  (      SELECT 1      FROM [KFMC].[Housing].[BuildingAction] root      LEFT JOIN [Housing].[WaitingClass] waitingClass
    ON waitingClass.[waitingClassID] = root.[buildingActionExtraType1]      WHERE sourceAction.[buildingActionTypeID_FK] = 27
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
    )  )
     OPTION (MAXRECURSION 100);
      SET @ActionsInserted = @@ROWCOUNT;

     /* Enforce no orphan migrated parents and no inactive source resident. */

     IF EXISTS

     (

         SELECT 1

         FROM Housing.BuildingAction child

         WHERE child.buildingActionExtraText5 = N'LEGACY'

           AND child.buildingActionParentID IS NOT NULL

           AND NOT EXISTS

           (SELECT 1 FROM Housing.BuildingAction parent

            WHERE parent.buildingActionID = child.buildingActionParentID)

     )

         THROW 58214, N'Migrated BuildingAction has a missing parent action; the transaction was stopped.', 1;

     IF EXISTS

     (

         SELECT 1

         FROM Housing.BuildingAction migratedAction

         JOIN KFMC.Housing.ResidentInfo sourceResident

           ON TRY_CONVERT(BIGINT, sourceResident.residentInfoID) = migratedAction.residentInfoID_FK

         WHERE migratedAction.buildingActionExtraText5 = N'LEGACY'

           AND ISNULL(sourceResident.residentInfoActive, 0) <> 1

     )

         THROW 58215, N'Inactive-source resident action was migrated; the transaction was stopped.', 1;


     SET IDENTITY_INSERT [Housing].[BuildingAction] OFF;
     SET @ActionIdentity = 0;
      /* M58217: remap deduplicated assignment parent IDs to the preserved
        first assignment of the same consecutive-equivalent run.
        Exact duplicate decision matches ValidAssignments below. */
     ;WITH AssignmentOrdered AS
     (
         SELECT
             s.BuildingAssignID,
             s.GeneralNo,
             s.BuildingActionID_FK,
             s.BuildingAssignTypeID_FK,
             s.ParentBuildingAssignID,
             s.BuildingNo,
             s.BuildingAssignStatusID_FK,
             s.MeterReadValue,
             LAG(s.BuildingAssignID) OVER
             (
                 PARTITION BY s.GeneralNo, s.BuildingActionID_FK
                 ORDER BY s.BuildingAssignID
             ) AS PreviousAssignID
         FROM KFMC.Housing.BuildingAssign AS s
     ),
     AssignmentBreaks AS
     (
         SELECT
             currentRow.BuildingAssignID,
             currentRow.GeneralNo,
             currentRow.BuildingActionID_FK,
             CASE
                 WHEN previousRow.BuildingAssignID IS NOT NULL
                  AND NOT EXISTS
                  (
                      SELECT currentRow.BuildingAssignTypeID_FK,
                             currentRow.ParentBuildingAssignID,
                             currentRow.BuildingNo,
                             currentRow.BuildingAssignStatusID_FK,
                             currentRow.MeterReadValue
                      EXCEPT
                      SELECT previousRow.BuildingAssignTypeID_FK,
                             previousRow.ParentBuildingAssignID,
                             previousRow.BuildingNo,
                             previousRow.BuildingAssignStatusID_FK,
                             previousRow.MeterReadValue
                  )
                 THEN CONVERT(bigint, 0)
                 ELSE CONVERT(bigint, 1)
             END AS IsRunStart
         FROM AssignmentOrdered AS currentRow
         LEFT JOIN KFMC.Housing.BuildingAssign AS previousRow
           ON previousRow.BuildingAssignID = currentRow.PreviousAssignID
     ),
     AssignmentRuns AS
     (
         SELECT
             b.*,
             SUM(b.IsRunStart) OVER
             (
                 PARTITION BY b.GeneralNo, b.BuildingActionID_FK
                 ORDER BY b.BuildingAssignID
                 ROWS UNBOUNDED PRECEDING
             ) AS RunNumber
         FROM AssignmentBreaks AS b
     ),
     AssignmentRetained AS
     (
         SELECT
             r.*,
             MIN(r.BuildingAssignID) OVER
             (
                 PARTITION BY r.GeneralNo, r.BuildingActionID_FK, r.RunNumber
             ) AS RetainedAssignID
         FROM AssignmentRuns AS r
     )
     SELECT
         BuildingAssignID AS DuplicateAssignID,
         RetainedAssignID
     INTO #AssignmentDedupParentMap
     FROM AssignmentRetained
     WHERE IsRunStart = 0;

     CREATE UNIQUE CLUSTERED INDEX IX_AssignmentDedupParentMap
         ON #AssignmentDedupParentMap (DuplicateAssignID);

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
          AND ownerAction.[generalNo_FK] NOT IN (0,1,18)
          AND EXISTS
          (
              SELECT 1

              FROM #ActiveMigratedResidents validResident

              WHERE validResident.GeneralNo = TRY_CONVERT(BIGINT,ownerAction.[generalNo_FK])

          )

          AND EXISTS

          (

              SELECT 1 FROM Housing.BuildingAction retainedAction

              WHERE retainedAction.buildingActionID = COALESCE

              (

                (SELECT duplicateMap.retainedActionID

                FROM #DuplicateActionMap duplicateMap

                WHERE duplicateMap.duplicateActionID = ownerAction.buildingActionID),

                ownerAction.buildingActionID

              )

              AND retainedAction.residentInfoID_FK =

                (SELECT eligible.ResidentInfoID FROM #ActiveMigratedResidents eligible

                WHERE eligible.GeneralNo = TRY_CONVERT(BIGINT,ownerAction.generalNo_FK))

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
             s.[BuildingActionID_FK]
         ),
         s.[BuildingAssignTypeID_FK], COALESCE(parentAssignmentMap.RetainedAssignID, s.[ParentBuildingAssignID]), s.[BuildingNo],
         s.[BuildingAssignDate], s.[BuildingAssignNo], s.[BuildingAssignStatusID_FK],
         s.[buildingPaymentTypeID_FK], s.[buildingActionDecisionNo],
         s.[buildingActionDecisionDate], s.[buildingActionOccupentDate], s.[MeterReadValue],
         s.[buildingActionLetterNo], s.[buildingActionLetterDate], s.[Note],
         s.[entryDate],
         [MoveData].[fn_MapEntryData](s.[entryData]),
         [MoveData].[fn_MapHostName](s.[hostName], s.[entryData])
     FROM ValidAssignments s
     LEFT JOIN #AssignmentDedupParentMap AS parentAssignmentMap
       ON parentAssignmentMap.DuplicateAssignID = s.ParentBuildingAssignID
     LEFT JOIN #DuplicateActionMap assignedActionDuplicate
       ON assignedActionDuplicate.[duplicateActionID] = s.[BuildingActionID_FK]
     WHERE NOT EXISTS
     (
         SELECT 1 FROM [Housing].[BuildingAssign] t
         WHERE t.[BuildingAssignID] = s.[BuildingAssignID]
     );
      SET @AssignmentsInserted = @@ROWCOUNT;

     IF EXISTS

     (

         SELECT 1 FROM Housing.BuildingAssign assignment

         LEFT JOIN Housing.BuildingAction migratedAction

           ON migratedAction.buildingActionID = assignment.BuildingActionID_FK

         WHERE migratedAction.buildingActionID IS NULL

     )

         THROW 58216, N'BuildingAssign has missing target BuildingAction; the transaction was stopped.', 1;

     IF EXISTS

     (

         SELECT 1 FROM Housing.BuildingAssign assignment

         WHERE assignment.ParentBuildingAssignID IS NOT NULL

           AND NOT EXISTS

           (

               SELECT 1 FROM Housing.BuildingAssign parentAssignment

               WHERE parentAssignment.BuildingAssignID = assignment.ParentBuildingAssignID

           )

     )

         THROW 58217, N'BuildingAssign parent reference points to an excluded or missing assignment; the transaction was stopped.', 1;


     SET IDENTITY_INSERT [Housing].[BuildingAssign] OFF;
     SET @AssignIdentity = 0;
      /* Trial 2 dynamic counters (the 26 population may change in KFMC). */
     SELECT
         N'QA_TRIAL2_SOURCE_RULES' AS [ResultType],
         (SELECT COUNT_BIG(*) FROM #ExcludedLeaf26) AS [SourceLeaf26EligibleForExclusion],
         (SELECT COUNT_BIG(*) FROM #ExcludedLeaf21) AS [SourceLeaf21EligibleForExclusion],
         (SELECT COUNT_BIG(*) FROM #ExcludedDuplicate27) AS [RedundantLeaf27Excluded],
         (SELECT COUNT_BIG(*) FROM #RootsToDeactivate) AS [WaitingRootsDeactivated],
         (SELECT COUNT_BIG(*) FROM #RootsToDeactivate
          WHERE [Reason] = N'TERMINATED_OR_ENTERED_IN_ERROR') AS [RootsTerminated18_19_20_22_23_28],
         (SELECT COUNT_BIG(*) FROM #RootsToDeactivate
          WHERE [Reason] = N'TRANSFERRED_21_CANCELLED') AS [Cancelled21Roots],
         (SELECT COUNT_BIG(*) FROM #RootsToDeactivate
          WHERE [Reason] = N'DUPLICATE_PENDING_WITH_OCCUPANCY') AS [DuplicatePendingAllocationRoots],
         (SELECT COUNT_BIG(*) FROM #RootsToDeactivate
          WHERE [Reason] = N'DUPLICATE_PENDING_SAME_CLASS') AS [SameClassDuplicateRootsCancelled],
         (SELECT COUNT_BIG(*) FROM #RootDuplicateGroups
          WHERE [PendingCount]>1) AS [SourcePendingDuplicateGroups],
         (SELECT COUNT_BIG(*) FROM #RootsToDeactivate cancelled
          JOIN [Housing].[BuildingAction] actual
            ON actual.[buildingActionID] = cancelled.[RootID]
          WHERE actual.[buildingActionActive] <> 0)
             AS [CancelledRootsStillActive_MustBeZero],
         (SELECT COUNT_BIG(*)
          FROM [KFMC].[Housing].[BuildingAction] a
          JOIN [KFMC].[Housing].[BuildingAction] parent27
            ON parent27.[buildingActionID] = a.[buildingActionParentID]
           AND parent27.[buildingActionTypeID_FK] = 27
          WHERE a.[buildingActionTypeID_FK] = 26

            AND EXISTS (SELECT 1 FROM #ActiveMigratedResidents eligible

                WHERE eligible.GeneralNo = TRY_CONVERT(BIGINT,a.generalNo_FK))

            AND NOT EXISTS
            (SELECT 1 FROM #ExcludedLeaf26 x WHERE x.[Action26ID] = a.[buildingActionID]))
             AS [Source26RetainedForReview],
         (SELECT COUNT_BIG(*)
          FROM #DuplicateActionMap d
          JOIN [KFMC].[Housing].[BuildingAction] r
            ON r.[buildingActionID] = d.[duplicateActionID]
          WHERE r.[buildingActionParentID] IS NULL
            AND r.[buildingActionTypeID_FK] IN (1,7,25))
             AS [RootExcludedByDedup_MustBeZero],
         (SELECT COUNT_BIG(*) FROM [Housing].[BuildingAction] a
          JOIN #ExcludedLeaf26 x ON x.[Action26ID] = a.[buildingActionID])
             AS [Excluded26StillInTarget_MustBeZero];
      /* Preview/parity results are emitted before ROLLBACK in test mode. */
     SELECT
         N'QA_MIGRATION_PREVIEW' AS [ResultType],
         (SELECT COUNT_BIG(*)
          FROM [KFMC].[Housing].[BuildingAction] sourceRoot
          JOIN [Housing].[BuildingAction] targetRoot
            ON targetRoot.[buildingActionID] = sourceRoot.[buildingActionID]
          WHERE sourceRoot.[buildingActionParentID] IS NULL
            AND sourceRoot.[buildingActionTypeID_FK] = 7
            AND targetRoot.[buildingActionTypeID_FK] = 1
            AND targetRoot.[buildingActionExtraType1] = 17) [Mapped7To1Class17],
         (SELECT COUNT_BIG(*)
          FROM [KFMC].[Housing].[BuildingAction] sourceRoot
          JOIN [Housing].[BuildingAction] targetRoot
            ON targetRoot.[buildingActionID] = sourceRoot.[buildingActionID]
          WHERE sourceRoot.[buildingActionParentID] IS NULL
            AND sourceRoot.[buildingActionTypeID_FK] = 25
            AND targetRoot.[buildingActionTypeID_FK] = 1
            AND targetRoot.[buildingActionExtraType1] = 18) [Mapped25To1Class18],
         (SELECT COUNT_BIG(*)
          FROM [KFMC].[Housing].[BuildingAction] sourceRoot
          JOIN [Housing].[BuildingAction] targetRoot
            ON targetRoot.[buildingActionID] = sourceRoot.[buildingActionID]
          WHERE sourceRoot.[buildingActionParentID] IS NULL
            AND sourceRoot.[buildingActionTypeID_FK] = 1
            AND sourceRoot.[buildingActionExtraType1] = 99
            AND targetRoot.[buildingActionTypeID_FK] = 1
            AND targetRoot.[buildingActionExtraType1] = 5) [Mapped99To5],
         (SELECT COUNT_BIG(*)
          FROM [Housing].[BuildingAction] targetAction
          JOIN [KFMC].[Housing].[BuildingAction] sourceAction
            ON sourceAction.[buildingActionID] = targetAction.[buildingActionID]
          WHERE sourceAction.[buildingActionTypeID_FK] = 27
            AND NOT EXISTS
            (
                SELECT 1 FROM [KFMC].[Housing].[BuildingAction] c
                WHERE c.[buildingActionParentID] = sourceAction.[buildingActionID]
                AND NOT EXISTS
                (
                SELECT 1 FROM #ExcludedLeaf26 excluded26
                WHERE excluded26.[Action26ID] = c.[buildingActionID]
                )
            )
            AND NOT EXISTS
            (
                SELECT 1 FROM [KFMC].[Housing].[BuildingAssign] assignment
                WHERE assignment.[BuildingActionID_FK] = sourceAction.[buildingActionID]
            )
            AND EXISTS
            (
                SELECT 1 FROM [KFMC].[Housing].[BuildingAction] r
                LEFT JOIN [Housing].[WaitingClass] wc
                ON wc.[waitingClassID] = r.[buildingActionExtraType1]
                WHERE r.[buildingActionID] = sourceAction.[buildingActionParentID]
                AND r.[buildingActionParentID] IS NULL
                AND (r.[buildingActionTypeID_FK] IN (7,25)
                OR (r.[buildingActionTypeID_FK] = 1
                AND (r.[buildingActionExtraType1] = 99 OR wc.[idara_FK] = 1)))
            )) [LeafSide27StillPresent],
         (SELECT COUNT_BIG(*)
          FROM [Housing].[BuildingAction] child
          LEFT JOIN [Housing].[BuildingAction] parent
            ON parent.[buildingActionID] = child.[buildingActionParentID]
          WHERE child.[buildingActionExtraText5] = N'LEGACY'
            AND child.[buildingActionParentID] IS NOT NULL
            AND parent.[buildingActionID] IS NULL) [LegacyOrphanParentCount];
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
      IF @RollbackAfterTest = 1 ROLLBACK TRANSACTION; ELSE COMMIT TRANSACTION;     END TRY     BEGIN CATCH
     IF @AssignIdentity = 1 SET IDENTITY_INSERT [Housing].[BuildingAssign] OFF;
     IF @ActionIdentity = 1 SET IDENTITY_INSERT [Housing].[BuildingAction] OFF;
     IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
     THROW;     END CATCH; END;

GO

