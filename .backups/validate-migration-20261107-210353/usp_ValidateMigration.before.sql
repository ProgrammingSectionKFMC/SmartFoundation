CREATE PROCEDURE [MoveData].[usp_ValidateMigration]
    @IdaraId bigint = 1,
    @CutoverDate date = NULL,
    @WaterMonthlyAmount decimal(18,2) = 8.25
AS
BEGIN
    SET NOCOUNT ON;
    /* Normalize migration administration: preserve a valid supplied value, otherwise use Idara 1. */
    IF NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID = 1)
        THROW 57990, N'Default migration Idara 1 does not exist.', 1;
    IF @IdaraId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID = @IdaraId)
        SET @IdaraId = 1;
    SET XACT_ABORT ON;

    DECLARE @Checks TABLE
    (
        CheckOrder int IDENTITY(1,1) PRIMARY KEY,
        Category nvarchar(100) NOT NULL,
        CheckName nvarchar(300) NOT NULL,
        ExpectedValue decimal(38,2) NULL,
        ActualValue decimal(38,2) NULL,
        Difference decimal(38,2) NULL,
        Result varchar(30) NOT NULL,
        Notes nvarchar(1000) NULL
    );
    DECLARE @RentChargeStartDate date = CONVERT(date, '20171001', 112);
    DECLARE @WaterChargeStartDate date = CONVERT(date, '20240101', 112);

    /* REVIEW PATCH 20261107: canonical eligibility = usp_MigrateResidents.
       No actions: excluded. One action 6 only: excluded.
       Any non-6 or more than one action: eligible, even without details.
       No UID is part of identity gates. */
    SELECT TRY_CONVERT(bigint,r.residentInfoID) AS ResidentInfoID,
           TRY_CONVERT(bigint,r.generalNo) AS GeneralNo
    INTO #ValidationEligibleResidents
    FROM KFMC.Housing.ResidentInfo r
    WHERE TRY_CONVERT(bigint,r.generalNo) IS NOT NULL
      AND TRY_CONVERT(bigint,r.generalNo) NOT IN (0,1,18)
      AND EXISTS
      (
        SELECT 1 FROM KFMC.Housing.BuildingAction a
        WHERE a.generalNo_FK=TRY_CONVERT(bigint,r.generalNo)
        GROUP BY a.generalNo_FK
        HAVING COUNT_BIG(*)>1
            OR MAX(CASE WHEN a.buildingActionTypeID_FK<>6 THEN 1 ELSE 0 END)=1
      );
    IF EXISTS(SELECT 1 FROM #ValidationEligibleResidents
              GROUP BY GeneralNo HAVING COUNT_BIG(*)>1)
        THROW 58210,N'Duplicate eligible source generalNo: validation cannot establish unique resident identity.',1;


    /* Distinguish historical monthly charges from operational invoices issued
       after cutover. NULL retains the existing interface and resolves from a
       successful non-rollback historical rent/water migration run. */
    DECLARE @ValidationCutoverDate date = COALESCE
    (
        @CutoverDate,
        (
            SELECT TOP (1) logRow.CutoverDate
            FROM MoveData.MigrationExecutionLog logRow
            WHERE logRow.IdaraId = @IdaraId
              AND logRow.RollbackAfterTest = 0
              AND logRow.ExecutionStatus = 'Succeeded'
              AND logRow.ProcedureName = N'MoveData.usp_MigrateHistoricalRentAndWaterBills'
              AND logRow.CutoverDate IS NOT NULL
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM MoveData.MigrationExecutionLog failedRow
                  WHERE failedRow.MigrationRunID = logRow.MigrationRunID
                    AND failedRow.ExecutionStatus <> 'Succeeded'
              )
            ORDER BY logRow.CompletedAt DESC
        )
    );

    IF @ValidationCutoverDate IS NULL
        THROW 57991, N'CutoverDate مطلوب لتحديد نطاق فواتير الترحيل، ولم يُعثر على تشغيل ترحيل ناجح مسجل.', 1;

    DECLARE @HistoricalBillMonthEnd date =
        EOMONTH(DATEADD(month, -1, @ValidationCutoverDate));

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

    /* Validate effective TARGET current requests, not active KFMC root count.
       ROOT active flag alone is insufficient: migrated housing and eviction
       history can retain a root with active=1. Include active type 18. */
    ;WITH ActiveRoots AS
    (
        SELECT r.buildingActionID RootID,
               r.generalNo_FK GeneralNo,
               r.buildingActionExtraType1 WaitingClassID,
               COALESCE(r.IdaraId_FK,@IdaraId) ScopeIdaraID
        FROM Housing.BuildingAction r
        WHERE r.buildingActionParentID IS NULL
          AND r.buildingActionTypeID_FK=1
          AND r.buildingActionActive=1
          AND r.generalNo_FK NOT IN(0,1)
          AND r.generalNo_FK IS NOT NULL
          AND r.buildingActionExtraType1 IS NOT NULL
    ), ActionTree AS
    (
        SELECT r.RootID,r.GeneralNo,r.WaitingClassID,r.ScopeIdaraID,
               a.buildingActionID ActionID,
               a.buildingActionTypeID_FK ActionTypeID,
               CONVERT(int,0) Depth
        FROM ActiveRoots r
        JOIN Housing.BuildingAction a ON a.buildingActionID=r.RootID
        UNION ALL
        SELECT t.RootID,t.GeneralNo,t.WaitingClassID,t.ScopeIdaraID,
               a.buildingActionID,a.buildingActionTypeID_FK,t.Depth+1
        FROM ActionTree t
        JOIN Housing.BuildingAction a ON a.buildingActionParentID=t.ActionID
            AND a.buildingActionActive=1
        WHERE t.Depth<100
    ), Ranked AS
    (
        SELECT *,ROW_NUMBER() OVER
            (PARTITION BY RootID ORDER BY Depth DESC,ActionID DESC) rn
        FROM ActionTree
    ), Grouped AS
    (
        SELECT GeneralNo,WaitingClassID,ScopeIdaraID,
               SUM(CASE WHEN ActionTypeID IN(1,18,26,27) THEN 1 ELSE 0 END) PendingCount,
               SUM(CASE WHEN ActionTypeID IN(2,24) THEN 1 ELSE 0 END) OccupiedCount,
               STRING_AGG(CASE WHEN ActionTypeID IN(1,18,26,27)
                        THEN CONVERT(nvarchar(max),RootID) END,N', ') AS ActionIDs
        FROM Ranked WHERE rn=1
        GROUP BY GeneralNo,WaitingClassID,ScopeIdaraID
    )
    SELECT GeneralNo,WaitingClassID,
           PendingCount AS ActiveRequests,ActionIDs
    INTO #ValidationWaitingRootDuplicates
    FROM Grouped
    WHERE (PendingCount>1 OR (PendingCount>0 AND OccupiedCount>0))
      AND ScopeIdaraID=@IdaraId
    OPTION (MAXRECURSION 100);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingList', N'Duplicate effective waiting roots in DATACORE',
           0, COUNT_BIG(*), COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Target effective pending roots (1/18/26/27), checking same class and Idara; real occupancy 2/24 conflicts also fail.'
    FROM #ValidationWaitingRootDuplicates;

    /* Mirror usp_MigrateBuildingActions: exclude an inactive root and all
       descendants only if none of those descendants is active. */
    ;WITH InactiveWaitingTree AS
    (
        SELECT
            a.buildingActionID AS RootActionID,
            a.generalNo_FK AS GeneralNo,
            a.buildingActionExtraType1 AS WaitingClassID,
            a.buildingActionID AS ActionID,
            a.buildingActionActive AS IsActive,
            0 AS Depth
        FROM KFMC.Housing.BuildingAction a
        WHERE a.buildingActionTypeID_FK IN (1,7,25)
          AND ISNULL(a.buildingActionActive,0)=0
          AND a.generalNo_FK IS NOT NULL
          AND a.generalNo_FK NOT IN (0,1,18)

        UNION ALL

        SELECT
            t.RootActionID, t.GeneralNo, t.WaitingClassID,
            c.buildingActionID, c.buildingActionActive, t.Depth+1
        FROM InactiveWaitingTree t
        JOIN KFMC.Housing.BuildingAction c
          ON c.buildingActionParentID=t.ActionID
        WHERE t.Depth<100
    )
    SELECT RootActionID,GeneralNo,WaitingClassID,ActionID,IsActive,Depth
    INTO #ValidationInactiveWaitingTree
    FROM InactiveWaitingTree
    OPTION (MAXRECURSION 101);

    SELECT DISTINCT
    t.RootActionID AS ActionID
INTO #ValidationExcludedWaitingActions
FROM #ValidationInactiveWaitingTree t
JOIN KFMC.Housing.BuildingAction root
    ON root.buildingActionID = t.RootActionID
WHERE t.Depth = 0
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
  );

    CREATE UNIQUE CLUSTERED INDEX IX_ValidationExcludedWaitingActions
        ON #ValidationExcludedWaitingActions(ActionID);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingList', N'Active descendants of inactive waiting roots in KFMC',
           0, COUNT_BIG(*), COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'An inactive waiting root with any active descendant blocks the full migration. Actual counts distinct violating roots.'
    FROM
    (
        SELECT DISTINCT RootActionID
        FROM #ValidationInactiveWaitingTree
        WHERE Depth>0 AND IsActive=1
    ) badRoot;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingList', N'Inactive waiting-root chains exceed 100 levels',
           0, COUNT_BIG(*), COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Chains deeper than 100 levels (or cyclic chains) cannot be safely classified for exclusion.'
    FROM
    (
        SELECT DISTINCT t.RootActionID
        FROM #ValidationInactiveWaitingTree t
        WHERE t.Depth=100
          AND EXISTS
          (
              SELECT 1
              FROM KFMC.Housing.BuildingAction nextAction
              WHERE nextAction.buildingActionParentID=t.ActionID
          )
    ) overflowRoot;

    /* Build the same valid/de-duplicated assignment set used by migration. */
    ;WITH OrderedAssignments AS
    (
        SELECT sourceAssign.*,
               LAG(sourceAssign.BuildingAssignID) OVER
               (
                   PARTITION BY sourceAssign.GeneralNo,sourceAssign.BuildingActionID_FK
                   ORDER BY sourceAssign.BuildingAssignID
               ) PreviousAssignID
        FROM KFMC.Housing.BuildingAssign sourceAssign
    )
    SELECT currentAssign.*
    INTO #ValidationValidAssign
    FROM OrderedAssignments currentAssign
    JOIN KFMC.Housing.BuildingAction ownerAction
      ON ownerAction.buildingActionID=currentAssign.BuildingActionID_FK
     AND CONVERT(nvarchar(100),ownerAction.generalNo_FK)
         =CONVERT(nvarchar(100),currentAssign.GeneralNo)
     AND ownerAction.generalNo_FK NOT IN (0,1,18)
     AND EXISTS
     (
         SELECT 1 FROM KFMC.Housing.ResidentInfo validResident
         WHERE validResident.generalNo=ownerAction.generalNo_FK
     )
     AND NOT EXISTS
     (
          SELECT 1
          FROM #ValidationExcludedWaitingActions excluded
          WHERE excluded.ActionID=ownerAction.buildingActionID
     )
    LEFT JOIN KFMC.Housing.BuildingAssign previousAssign
      ON previousAssign.BuildingAssignID=currentAssign.PreviousAssignID
    WHERE previousAssign.BuildingAssignID IS NULL
       OR EXISTS
       (
           SELECT currentAssign.BuildingAssignTypeID_FK,currentAssign.ParentBuildingAssignID,
                  currentAssign.BuildingNo,currentAssign.BuildingAssignStatusID_FK,currentAssign.MeterReadValue
           EXCEPT
           SELECT previousAssign.BuildingAssignTypeID_FK,previousAssign.ParentBuildingAssignID,
                  previousAssign.BuildingNo,previousAssign.BuildingAssignStatusID_FK,previousAssign.MeterReadValue
       );

    CREATE UNIQUE CLUSTERED INDEX IX_ValidationValidAssign_ID
        ON #ValidationValidAssign(BuildingAssignID);

    /* WaitingClass migration parity for Idara 1.
       IDs 1-11 retain their frozen KFMC identities and names.
       IDs 1-4 and 12 are main lists; 5-11 are side lists for @IdaraId.
       ID 99 is a virtual legacy letter-housing marker, not a master row. */
    ;WITH ExpectedWaitingClasses AS
    (
        SELECT
            s.waitingClassID AS ClassID,
            s.waitingClassName_A COLLATE DATABASE_DEFAULT AS NameA,
            s.waitingClassName_E COLLATE DATABASE_DEFAULT AS NameE,
            CASE WHEN s.waitingClassID BETWEEN 1 AND 4
                 THEN s.waitingClassID + 1
                 ELSE s.waitingClassSequence END AS ClassSequence,
            s.waitingClassRoot AS ClassRoot,
            CAST(CASE WHEN s.waitingClassID BETWEEN 1 AND 4
                      THEN NULL ELSE @IdaraId END AS bigint) AS ClassIdara
        FROM KFMC.Housing.WaitingClass s
        WHERE s.waitingClassID BETWEEN 1 AND 11

        UNION ALL

        SELECT 12, N'القادة', CAST(NULL AS nvarchar(100)),
               1, CAST(NULL AS int), CAST(NULL AS bigint)
    ),
    MatchedWaitingClasses AS
    (
        SELECT
            e.ClassID,
            CASE WHEN t.waitingClassID IS NOT NULL
                  AND NOT EXISTS
                  (
                      SELECT t.waitingClassName_A,
                             t.waitingClassName_E,
                             t.waitingClassSequence,
                             t.waitingClassRoot,
                             t.waitingClassActive,
                             t.idara_FK
                      EXCEPT
                      SELECT e.NameA,
                             e.NameE,
                             e.ClassSequence,
                             e.ClassRoot,
                             CAST(1 AS bit),
                             e.ClassIdara
                  )
                 THEN 1 ELSE 0 END AS IsMatched
        FROM ExpectedWaitingClasses e
        LEFT JOIN Housing.WaitingClass t
          ON t.waitingClassID = e.ClassID
    )
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingClass',N'WaitingClass master parity',
           12,COALESCE(SUM(IsMatched),0),COALESCE(SUM(IsMatched),0)-12,
           CASE WHEN COUNT_BIG(*)=12 AND COALESCE(SUM(IsMatched),0)=12
                THEN 'PASS' ELSE 'FAIL' END,
           N'KFMC IDs 1-11: preserved names, root and historical sequence; main IDs 1-4 use sequence 2-5; side IDs 5-11 use Idara 1; ID 12 is main class القادة.'
    FROM MatchedWaitingClasses;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingClass',N'Legacy letter roots 7/25 converted by source ID',
           COUNT_BIG(*),SUM(CASE WHEN t.buildingActionID IS NOT NULL
                                    AND t.buildingActionTypeID_FK=1
                                    AND t.buildingActionExtraType1=CASE WHEN k.buildingActionTypeID_FK=7 THEN 17 ELSE 18 END
                                    AND t.buildingActionParentID IS NULL
                                THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END),
           SUM(CASE WHEN t.buildingActionID IS NOT NULL
                                    AND t.buildingActionTypeID_FK=1
                                    AND t.buildingActionExtraType1=CASE WHEN k.buildingActionTypeID_FK=7 THEN 17 ELSE 18 END
                                    AND t.buildingActionParentID IS NULL
                                THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END)-COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=SUM(CASE WHEN t.buildingActionID IS NOT NULL
                                    AND t.buildingActionTypeID_FK=1
                                    AND t.buildingActionExtraType1=CASE WHEN k.buildingActionTypeID_FK=7 THEN 17 ELSE 18 END
                                    AND t.buildingActionParentID IS NULL
                                THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END)
                THEN 'PASS' ELSE 'FAIL' END,
           N'Compare all KFMC legacy roots by preserved action ID: type 7->1/class17 and 25->1/class18; no fixed ActionID lists.'
    FROM KFMC.Housing.BuildingAction k
    LEFT JOIN Housing.BuildingAction t ON t.buildingActionID=k.buildingActionID
    WHERE k.buildingActionParentID IS NULL AND k.buildingActionTypeID_FK IN (7,25);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingClass', N'Converted legacy letter side classes 17/18',
           2, COUNT_BIG(*), COUNT_BIG(*)-2,
           CASE WHEN COUNT_BIG(*)=2 THEN 'PASS' ELSE 'FAIL' END,
           N'Idara 1 side classes: 17 خطاب تسكين sequence 3; 18 خطاب تسكين عزاب sequence 4, both active with NULL root.'
    FROM Housing.WaitingClass t
    JOIN (VALUES (17,N'خطاب تسكين',3),(18,N'خطاب تسكين عزاب',4))
         x(ClassID,ClassName,ClassSequence)
      ON t.waitingClassID=x.ClassID
    WHERE t.waitingClassName_A COLLATE DATABASE_DEFAULT=x.ClassName COLLATE DATABASE_DEFAULT
      AND t.waitingClassSequence=x.ClassSequence
      AND t.waitingClassRoot IS NULL
      AND t.waitingClassActive=1
      AND t.idara_FK=1;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingClass',N'Unconverted legacy 7/25 roots in DATACORE',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Legacy root types 7 and 25 must be converted to type 1; do not alter dependent actions.'
    FROM Housing.BuildingAction a
    WHERE a.buildingActionParentID IS NULL
      AND a.buildingActionTypeID_FK IN (7,25);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingClass',N'Test and virtual IDs incorrectly in WaitingClass master',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'IDs 13-15 are confirmed test data; ID 99 is a virtual legacy letter-housing category, not a WaitingClass master row.'
    FROM Housing.WaitingClass
    WHERE waitingClassID IN (13,14,15,99);

    /* Only action types known to use ExtraType1 as a waiting-list class are checked.
       Other action types can use the same generic column for unrelated meanings. */
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingClass',N'Orphan waiting-class references in BuildingAction',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Action types 1,21,22,27,28: every non-NULL class must have a master row, except virtual legacy ID 99.'
    FROM Housing.BuildingAction a
    WHERE a.buildingActionTypeID_FK IN (1,21,22,27,28)
      AND a.buildingActionExtraType1 IS NOT NULL
      AND a.buildingActionExtraType1 <> 99
      AND NOT EXISTS
      (
          SELECT 1 FROM Housing.WaitingClass wc
          WHERE wc.waitingClassID=a.buildingActionExtraType1
      );

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingClass',N'Waiting-class values changed in copied historical actions',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Compare expected transformed class: root type 7=>17, 25=>18; root type 1 class 99=>5; other copied waiting/allocation values unchanged.'
    FROM KFMC.Housing.BuildingAction sourceAction
    JOIN Housing.BuildingAction targetAction
      ON targetAction.buildingActionID=CONVERT(bigint,sourceAction.buildingActionID)
    WHERE sourceAction.buildingActionTypeID_FK IN (1,7,25,21,22,27,28)
       AND EXISTS
      (
           SELECT targetAction.buildingActionExtraType1
           EXCEPT
           SELECT CASE
                    WHEN sourceAction.buildingActionParentID IS NULL
                     AND sourceAction.buildingActionTypeID_FK=7 THEN 17
                    WHEN sourceAction.buildingActionParentID IS NULL
                     AND sourceAction.buildingActionTypeID_FK=25 THEN 18
                    WHEN sourceAction.buildingActionParentID IS NULL
                     AND sourceAction.buildingActionTypeID_FK=1
                     AND sourceAction.buildingActionExtraType1=99 THEN 5
                    ELSE sourceAction.buildingActionExtraType1
                  END
      );

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingClass',N'Orphan waiting-class references in AssignPeriod',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Every populated AssignPeriod.WaitingClassID_FK must match an existing master row.'
    FROM Housing.AssignPeriod ap
    WHERE ap.WaitingClassID_FK IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1 FROM Housing.WaitingClass wc
          WHERE wc.waitingClassID=ap.WaitingClassID_FK
      );

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingClass',N'Missing or duplicated legacy periods for main waiting classes',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Exactly one historical period per class 1,2,3,4 in the migration Idara; no legacy period is required for side classes.'
    FROM (VALUES (1),(2),(3),(4)) expected(ClassID)
    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS PeriodCount
        FROM Housing.AssignPeriod ap
        WHERE ap.IdaraId_FK=@IdaraId
          AND ap.WaitingClassID_FK=expected.ClassID
          AND ap.AssignPeriodDescrption=CONCAT(N'Legacy allocation migration - WaitingClass ',expected.ClassID)
    ) actual
    WHERE actual.PeriodCount<>1;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingClass',N'Orphan waiting classes in BuildingAssign allocation chains',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'When a BuildingAssign row links to action 27 under waiting root 1, its effective class must exist, except virtual ID 99.'
    FROM Housing.BuildingAssign ba
    JOIN Housing.BuildingAction action27
      ON action27.buildingActionID=ba.BuildingActionID_FK
     AND action27.buildingActionTypeID_FK=27
    JOIN Housing.BuildingAction waitingRoot
      ON waitingRoot.buildingActionID=action27.buildingActionParentID
     AND waitingRoot.buildingActionTypeID_FK=1
    WHERE COALESCE(action27.buildingActionExtraType1,waitingRoot.buildingActionExtraType1) IS NOT NULL
      AND COALESCE(action27.buildingActionExtraType1,waitingRoot.buildingActionExtraType1)<>99
      AND NOT EXISTS
      (
          SELECT 1 FROM Housing.WaitingClass wc
          WHERE wc.waitingClassID=COALESCE(action27.buildingActionExtraType1,waitingRoot.buildingActionExtraType1)
      );

    /* Directly copied master and transactional data. Actual means source rows found in target. */
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Completeness',N'Military units',s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,N'Matched by ID and code.'
    FROM (SELECT COUNT_BIG(*) c FROM KFMC.dbo.MilitaryUnit) s
    CROSS JOIN
    (SELECT COUNT_BIG(*) c FROM KFMC.dbo.MilitaryUnit x JOIN dbo.MilitaryUnit y
       ON y.militaryUnitID=x.militaryUnitID
      AND ISNULL(LTRIM(RTRIM(y.militaryUnitCode)),N'')=ISNULL(LTRIM(RTRIM(x.militaryUnitCode)),N'')) t;

    
/* ResidentInfo expected by action-based eligibility (including eligible without details). */
INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
SELECT N'Completeness',N'ResidentInfo',s.c,t.c,t.c-s.c,
       CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,
       N'Eligible by BuildingAction; no actions and lone type 6 are excluded.'
FROM (SELECT COUNT_BIG(*) c FROM #ValidationEligibleResidents) s
CROSS JOIN
(
 SELECT COUNT_BIG(*) c FROM #ValidationEligibleResidents e
 JOIN Housing.ResidentInfo t ON t.residentInfoID=e.ResidentInfoID
) t;

/* One selected details row per ELIGIBLE source resident having details.
   Same order as current usp_MigrateResidents. */
;WITH SelectedDetails AS
(
 SELECT d.residentDetailsID,
        ROW_NUMBER() OVER
        (PARTITION BY d.generalNo_FK ORDER BY
          CASE WHEN d.residentDetailsActive=1 THEN 0 ELSE 1 END,
          d.entryDate DESC,d.residentDetailsID DESC) AS rn
 FROM KFMC.Housing.ResidentDetails d
 JOIN #ValidationEligibleResidents e
   ON e.GeneralNo=TRY_CONVERT(bigint,d.generalNo_FK)
)
INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
SELECT N'Completeness',N'ResidentDetails',s.c,t.c,t.c-s.c,
       CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,
       N'One selected details record per eligible resident with source details; absence of details is allowed.'
FROM (SELECT COUNT_BIG(*) c FROM SelectedDetails WHERE rn=1) s
CROSS JOIN
(
 SELECT COUNT_BIG(*) c FROM SelectedDetails x
 JOIN Housing.ResidentDetails y ON y.residentDetailsID=TRY_CONVERT(bigint,x.residentDetailsID)
 WHERE x.rn=1
) t;

/* Excluded by action-based rule: do not migrate ResidentInfo. */
INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
SELECT N'Integrity',N'Excluded residents migrated',0,COUNT_BIG(*),COUNT_BIG(*),
       CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
       N'Only residents excluded by canonical BuildingAction eligibility may not appear in DATACORE.'
FROM KFMC.Housing.ResidentInfo r
JOIN Housing.ResidentInfo t ON t.residentInfoID=TRY_CONVERT(bigint,r.residentInfoID)
WHERE NOT EXISTS
(SELECT 1 FROM #ValidationEligibleResidents e
 WHERE e.ResidentInfoID=TRY_CONVERT(bigint,r.residentInfoID));

    /* Legacy Excel runs are identified only by the required name prefix. */
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Legacy Excel',N'Legacy Excel deduction-list import logs',sourceCount.c,targetCount.c,
           targetCount.c-sourceCount.c,
           CASE WHEN sourceCount.c=targetCount.c THEN 'PASS' ELSE 'FAIL' END,
           N'Active KFMC deduction lists whose trimmed name starts with مسير استقطاع and have both a migrated list and an UploadExcelImportLog row.'
    FROM
    (
        SELECT COUNT_BIG(*) c
        FROM KFMC.Housing.DeductList sourceDeduct
        WHERE sourceDeduct.deductActive=1
          AND LTRIM(RTRIM(sourceDeduct.deductName)) LIKE N'مسير استقطاع%'
    ) sourceCount
    CROSS JOIN
    (
        SELECT COUNT_BIG(*) c
        FROM KFMC.Housing.DeductList sourceDeduct
        JOIN Housing.DeductList targetDeduct
          ON targetDeduct.deductListID=sourceDeduct.deductListID
        JOIN Housing.UploadExcelImportLog importLog
          ON importLog.DeductListID_FK=targetDeduct.deductListID
        WHERE sourceDeduct.deductActive=1
          AND LTRIM(RTRIM(sourceDeduct.deductName)) LIKE N'مسير استقطاع%'
    ) targetCount;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Legacy Excel',N'Duplicate import logs for one deduction list',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Actual is the number of duplicated non-null DeductListID_FK groups.'
    FROM
    (
        SELECT DeductListID_FK
        FROM Housing.UploadExcelImportLog
        WHERE DeductListID_FK IS NOT NULL
        GROUP BY DeductListID_FK
        HAVING COUNT_BIG(*)>1
    ) duplicateLog;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Legacy Excel',N'Import logs with missing deduction list',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Normally enforced by FK; retained to detect disabled or untrusted constraints.'
    FROM Housing.UploadExcelImportLog importLog
    LEFT JOIN Housing.DeductList targetDeduct
      ON targetDeduct.deductListID=importLog.DeductListID_FK
    WHERE importLog.DeductListID_FK IS NOT NULL
      AND targetDeduct.deductListID IS NULL;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Legacy Excel',N'Legacy Excel logs with incorrect InsertedRows',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'InsertedRows must equal every BuildingPayment row linked to the migrated deduction list.'
    FROM KFMC.Housing.DeductList sourceDeduct
    JOIN Housing.DeductList targetDeduct
      ON targetDeduct.deductListID=sourceDeduct.deductListID
    JOIN Housing.UploadExcelImportLog importLog
      ON importLog.DeductListID_FK=targetDeduct.deductListID
    CROSS APPLY
    (
        SELECT COUNT_BIG(*) paymentCount
        FROM Housing.BuildingPayment targetPayment
        WHERE targetPayment.deductListID_FK=targetDeduct.deductListID
    ) linkedPayment
    WHERE sourceDeduct.deductActive=1
      AND LTRIM(RTRIM(sourceDeduct.deductName)) LIKE N'مسير استقطاع%'
      AND (importLog.InsertedRows IS NULL
           OR CONVERT(bigint,importLog.InsertedRows)<>linkedPayment.paymentCount);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Legacy Excel',N'Legacy Excel logs with incorrect synthetic hash',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Hash must be SHA2-256 of LEGACY-KFMC-EXCEL:<deductListID>.'
    FROM KFMC.Housing.DeductList sourceDeduct
    JOIN Housing.UploadExcelImportLog importLog
      ON importLog.DeductListID_FK=sourceDeduct.deductListID
    WHERE sourceDeduct.deductActive=1
      AND LTRIM(RTRIM(sourceDeduct.deductName)) LIKE N'مسير استقطاع%'
      AND importLog.FileHash<>
          LOWER
          (
            CONVERT
            (
              varchar(64),
              HASHBYTES('SHA2_256',CONCAT(N'LEGACY-KFMC-EXCEL:',sourceDeduct.deductListID)),
              2
            )
          );

    
/* Contacts are required only for action-eligible source residents. */
INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
SELECT N'Completeness',N'Resident contacts',s.c,t.c,t.c-s.c,
       CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,
       N'Contacts for action-eligible source residents (not details-based eligibility).'
FROM
(
 SELECT COUNT_BIG(*) c FROM KFMC.dbo.contactInfo sourceContact
 JOIN #ValidationEligibleResidents e
   ON e.GeneralNo=TRY_CONVERT(bigint,sourceContact.userID_FK)
) s
CROSS JOIN
(
 SELECT COUNT_BIG(*) c FROM Housing.ResidentContactInfo targetContact
 JOIN #ValidationEligibleResidents e
   ON e.ResidentInfoID=targetContact.residentInfoID_FK
) t;

INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
SELECT N'Integrity',N'Contacts linked to excluded residents',0,COUNT_BIG(*),COUNT_BIG(*),
       CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
       N'Target contacts of source residents not eligible by action-based rule.'
FROM Housing.ResidentContactInfo targetContact
JOIN KFMC.Housing.ResidentInfo r
  ON TRY_CONVERT(bigint,r.residentInfoID)=targetContact.residentInfoID_FK
WHERE NOT EXISTS
(SELECT 1 FROM #ValidationEligibleResidents e
 WHERE e.ResidentInfoID=TRY_CONVERT(bigint,r.residentInfoID));

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Completeness',N'Buildings',s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,N'Matched by buildingDetailsID.'
    FROM (SELECT COUNT_BIG(*) c FROM KFMC.Housing.BuildingDetails) s
    CROSS JOIN (SELECT COUNT_BIG(*) c FROM KFMC.Housing.BuildingDetails x JOIN Housing.BuildingDetails y
                 ON y.buildingDetailsID=CONVERT(bigint,x.buildingDetailsID)) t;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Completeness',N'Meters',s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,N'Matched by meterID.'
    FROM (SELECT COUNT_BIG(*) c FROM KFMC.Housing.Meter) s
    CROSS JOIN (SELECT COUNT_BIG(*) c FROM KFMC.Housing.Meter x JOIN Housing.Meter y
                 ON y.meterID=CONVERT(bigint,x.meterID)) t;

    
/*
    MeterRead:
    Exclude readings belonging to KFMC residents
    who have no ResidentDetails.

    Preserve all other source readings by meterReadID.
*/

INSERT @Checks
(
    Category,
    CheckName,
    ExpectedValue,
    ActualValue,
    Difference,
    Result,
    Notes
)
SELECT
    N'Completeness',
    N'Meter reads',
    s.c,
    t.c,
    t.c - s.c,
    CASE
        WHEN s.c = t.c THEN 'PASS'
        ELSE 'FAIL'
    END,
    N'قراءات المستفيدين الذين لا يملكون ResidentDetails مستبعدة من الترحيل.'

FROM
(
    SELECT COUNT_BIG(*) AS c

    FROM KFMC.Housing.MeterRead sourceRead

    WHERE NOT EXISTS
    (
        SELECT 1
        FROM KFMC.Housing.ResidentInfo excludedResident

        WHERE excludedResident.generalNo =
              sourceRead.generalNo_FK

          AND NOT EXISTS
          (
              SELECT 1
              FROM KFMC.Housing.ResidentDetails details

              WHERE details.generalNo_FK =
                    excludedResident.generalNo
          )
    )
) s

CROSS JOIN
(
    SELECT COUNT_BIG(*) AS c

    FROM KFMC.Housing.MeterRead sourceRead

    INNER JOIN Housing.MeterRead targetRead
        ON targetRead.meterReadID =
           CONVERT(bigint, sourceRead.meterReadID)

    WHERE NOT EXISTS
    (
        SELECT 1
        FROM KFMC.Housing.ResidentInfo excludedResident

        WHERE excludedResident.generalNo =
              sourceRead.generalNo_FK

          AND NOT EXISTS
          (
              SELECT 1
              FROM KFMC.Housing.ResidentDetails details

              WHERE details.generalNo_FK =
                    excludedResident.generalNo
          )
    )
) t;



/*
    Verify excluded MeterRead rows are absent
    from DATACORE after clean migration.
*/

INSERT @Checks
(
    Category,
    CheckName,
    ExpectedValue,
    ActualValue,
    Difference,
    Result,
    Notes
)
SELECT
    N'Integrity',
    N'Excluded source meter reads migrated',
    0,
    COUNT_BIG(*),
    COUNT_BIG(*),

    CASE
        WHEN COUNT_BIG(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END,

    N'يجب عدم نقل قراءات المستفيدين المستبعدين، مع الاحتفاظ بفواتيرها الأصلية.'

FROM KFMC.Housing.MeterRead sourceRead

INNER JOIN Housing.MeterRead targetRead
    ON targetRead.meterReadID =
       CONVERT(bigint, sourceRead.meterReadID)

WHERE EXISTS
(
    SELECT 1
    FROM KFMC.Housing.ResidentInfo excludedResident

    WHERE excludedResident.generalNo =
          sourceRead.generalNo_FK

      AND NOT EXISTS
      (
          SELECT 1
          FROM KFMC.Housing.ResidentDetails details

          WHERE details.generalNo_FK =
                excludedResident.generalNo
      )
);


    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Historical corrections',N'Meter reads linked to corrected residents',s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,
           N'Applies documented mappings 202964->60013013, 404529/1265->10038776, and 306499/B06-5-2->10036016.'
    FROM
    (
        SELECT COUNT_BIG(*) c FROM KFMC.Housing.MeterRead sourceRead
        WHERE sourceRead.generalNo_FK=202964
           OR (sourceRead.generalNo_FK=404529 AND LTRIM(RTRIM(sourceRead.buildingDetailsNo))=N'1265')
           OR (sourceRead.generalNo_FK=306499 AND LTRIM(RTRIM(sourceRead.buildingDetailsNo))=N'B06-5-2')
    ) s
    CROSS JOIN
    (
        SELECT COUNT_BIG(*) c
        FROM KFMC.Housing.MeterRead sourceRead
        JOIN Housing.MeterRead targetRead ON targetRead.meterReadID=sourceRead.meterReadID
        WHERE (sourceRead.generalNo_FK=202964 AND targetRead.generalNo_FK=60013013 AND targetRead.residentInfoID_FK IS NOT NULL)
           OR (sourceRead.generalNo_FK=404529 AND LTRIM(RTRIM(sourceRead.buildingDetailsNo))=N'1265'
               AND targetRead.generalNo_FK=10038776 AND targetRead.residentInfoID_FK IS NOT NULL)
           OR (sourceRead.generalNo_FK=306499 AND LTRIM(RTRIM(sourceRead.buildingDetailsNo))=N'B06-5-2'
               AND targetRead.generalNo_FK=10036016 AND targetRead.residentInfoID_FK IS NOT NULL)
    ) t;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Historical corrections',N'Meter reads linked to corrected building C07-2-1',s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,
           N'Corrects historical building number C7-2-1 to C07-2-1.'
    FROM (SELECT COUNT_BIG(*) c FROM KFMC.Housing.MeterRead WHERE LTRIM(RTRIM(buildingDetailsNo))=N'C7-2-1') s
    CROSS JOIN
    (
        SELECT COUNT_BIG(*) c
        FROM KFMC.Housing.MeterRead sourceRead
        JOIN Housing.MeterRead targetRead ON targetRead.meterReadID=sourceRead.meterReadID
        WHERE LTRIM(RTRIM(sourceRead.buildingDetailsNo))=N'C7-2-1'
          AND LTRIM(RTRIM(targetRead.buildingDetailsNo))=N'C07-2-1'
          AND targetRead.buildingDetailsID IS NOT NULL
    ) t;

    /* Exclusion integrity: these actions and assignments are deliberately
       absent after a CLEAN migration. Old DATACORE copies will FAIL this check. */
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingList',N'Excluded inactive waiting actions migrated',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'No inactive waiting root or descendant excluded by the new migration rule may remain in DATACORE after clean migration.'
    FROM #ValidationExcludedWaitingActions excluded
    JOIN Housing.BuildingAction targetAction
      ON targetAction.buildingActionID=excluded.ActionID;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingList',N'Non-excluded actions referring to excluded roots or descendants',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Retained actions may not reference excluded waiting actions via buildingActionParentID.'
    FROM Housing.BuildingAction targetAction
    JOIN #ValidationExcludedWaitingActions excluded
      ON excluded.ActionID=targetAction.buildingActionParentID
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM #ValidationExcludedWaitingActions selfExcluded
        WHERE selfExcluded.ActionID=targetAction.buildingActionID
    );

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingList',N'Assignments linked to excluded waiting actions',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'No target BuildingAssign row may reference an excluded waiting action.'
    FROM Housing.BuildingAssign targetAssign
    JOIN #ValidationExcludedWaitingActions excluded
      ON excluded.ActionID=targetAssign.BuildingActionID_FK;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'WaitingList',N'Excluded source assignments migrated',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Assignments whose KFMC owning action belongs to an excluded inactive waiting chain must not be imported.'
    FROM KFMC.Housing.BuildingAssign sourceAssign
    JOIN #ValidationExcludedWaitingActions excluded
      ON excluded.ActionID=sourceAssign.BuildingActionID_FK
    JOIN Housing.BuildingAssign targetAssign
      ON targetAssign.BuildingAssignID=sourceAssign.BuildingAssignID;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Completeness',N'Building actions',s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,
           N'Matched by buildingActionID after excluding consecutive identical source actions.'
    FROM
    (
        SELECT COUNT_BIG(*) c
        FROM KFMC.Housing.BuildingAction sourceAction
        WHERE NOT EXISTS
        (
            SELECT 1 FROM #ValidationDuplicateActionMap duplicateAction
            WHERE duplicateAction.duplicateActionID=sourceAction.buildingActionID
        )
          AND NOT EXISTS
        (
            SELECT 1 FROM #ValidationExcludedWaitingActions excluded
            WHERE excluded.ActionID=sourceAction.buildingActionID
        )
          AND
          (
              sourceAction.generalNo_FK IS NULL
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
          AND NOT EXISTS
(
    SELECT 1
    FROM KFMC.Housing.BuildingAction letterRoot
    WHERE letterRoot.buildingActionID = sourceAction.buildingActionParentID
      AND letterRoot.buildingActionTypeID_FK = 7
      AND sourceAction.buildingActionTypeID_FK = 27
)
    ) s
    CROSS JOIN
    (
        SELECT COUNT_BIG(*) c
        FROM KFMC.Housing.BuildingAction x
        JOIN Housing.BuildingAction y ON y.buildingActionID=CONVERT(bigint,x.buildingActionID)
        WHERE NOT EXISTS
        (
            SELECT 1 FROM #ValidationExcludedWaitingActions excluded
            WHERE excluded.ActionID=x.buildingActionID
        )
          AND
        (
            x.generalNo_FK IS NULL
            OR
            (
                x.generalNo_FK NOT IN (0,1,18)
                AND EXISTS
                (
                    SELECT 1 FROM KFMC.Housing.ResidentInfo validResident
                    WHERE validResident.generalNo=x.generalNo_FK
                )
            )
        )
        AND NOT
        (
            x.buildingActionTypeID_FK=27
            AND EXISTS
            (
                SELECT 1 FROM KFMC.Housing.BuildingAction letterRoot
                WHERE letterRoot.buildingActionID=x.buildingActionParentID
                  AND letterRoot.buildingActionTypeID_FK=7
            )
        )
    ) t;

    /* Origin classification validations. Values other than the two reserved
       labels (including NULL) are allowed for future operational uses. */
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Action provenance',N'Source-matched actions missing LEGACY classification',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'An action with the same source ID and UDID must be classified LEGACY.'
    FROM Housing.BuildingAction a
    JOIN KFMC.Housing.BuildingAction k
      ON k.buildingActionID=a.buildingActionID
     AND k.buildingActionUDID=a.buildingActionUDID
    WHERE a.buildingActionExtraText5 IS NULL
       OR a.buildingActionExtraText5<>N'LEGACY';

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Action provenance',N'LEGACY classification without source identity',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'LEGACY requires matching source buildingActionID and buildingActionUDID.'
    FROM Housing.BuildingAction a
    WHERE a.buildingActionExtraText5=N'LEGACY'
      AND NOT EXISTS
      (
          SELECT 1 FROM KFMC.Housing.BuildingAction k
          WHERE k.buildingActionID=a.buildingActionID
            AND k.buildingActionUDID=a.buildingActionUDID
      );

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Action provenance',N'MIGRATION_GENERATED without marker or with source identity',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Generated actions need MoveData: marker and may not replace source actions.'
    FROM Housing.BuildingAction a
    WHERE a.buildingActionExtraText5=N'MIGRATION_GENERATED'
      AND
      (
          a.buildingActionExtraText4 IS NULL
          OR a.buildingActionExtraText4 NOT LIKE N'MoveData:%'
          OR EXISTS
          (
              SELECT 1 FROM KFMC.Housing.BuildingAction k
              WHERE k.buildingActionID=a.buildingActionID
          )
      );

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Action provenance',N'MoveData-generated marker missing classification',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'MoveData: marker without a source action requires MIGRATION_GENERATED.'
    FROM Housing.BuildingAction a
    WHERE a.buildingActionExtraText4 LIKE N'MoveData:%'
      AND NOT EXISTS
      (
          SELECT 1 FROM KFMC.Housing.BuildingAction k
          WHERE k.buildingActionID=a.buildingActionID
      )
      AND
      (
          a.buildingActionExtraText5 IS NULL
          OR a.buildingActionExtraText5<>N'MIGRATION_GENERATED'
      );

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Action provenance',N'Source ID collision with different action UDID',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'A matching legacy ID with different or missing UDID must be investigated.'
    FROM Housing.BuildingAction a
    JOIN KFMC.Housing.BuildingAction k
      ON k.buildingActionID=a.buildingActionID
    WHERE a.buildingActionUDID IS NULL
       OR k.buildingActionUDID IS NULL
       OR a.buildingActionUDID<>k.buildingActionUDID;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Completeness',N'Building assignments',s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,N'Matched by BuildingAssignID.'
    FROM (SELECT COUNT_BIG(*) c FROM #ValidationValidAssign) s
    CROSS JOIN (SELECT COUNT_BIG(*) c FROM #ValidationValidAssign x JOIN Housing.BuildingAssign y
                 ON y.BuildingAssignID=x.BuildingAssignID) t;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Allocation migration',N'Historical assignment periods',4,COUNT_BIG(*),COUNT_BIG(*)-4,
           CASE WHEN COUNT_BIG(*)=4 THEN 'PASS' ELSE 'FAIL' END,
           N'Exactly one legacy period is created for each normal waiting class 1,2,3,4.'
    FROM Housing.AssignPeriod
    WHERE IdaraId_FK=@IdaraId
      AND AssignPeriodDescrption LIKE N'Legacy allocation migration - WaitingClass %';

    /* Approved policy: preserve action 18 as 18; MAIN resumes allocation,
       SIDE resumes waiting. The View/stage verifier is separate. */
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Allocation migration', N'Old action 18 retains historical action type',
           s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,
           N'Copied source action 18 must remain 18; no migration mapping to 39.'
    FROM
    (
        SELECT COUNT_BIG(*) c
        FROM KFMC.Housing.BuildingAction k
        WHERE k.buildingActionTypeID_FK=18
          AND (k.generalNo_FK IS NULL OR EXISTS
              (SELECT 1 FROM #ValidationEligibleResidents e WHERE e.GeneralNo=k.generalNo_FK))
          AND NOT EXISTS
              (SELECT 1 FROM #ValidationDuplicateActionMap d WHERE d.duplicateActionID=k.buildingActionID)
    ) s
    CROSS JOIN
    (
        SELECT COUNT_BIG(*) c
        FROM KFMC.Housing.BuildingAction k
        JOIN Housing.BuildingAction t ON t.buildingActionID=k.buildingActionID
        WHERE k.buildingActionTypeID_FK=18
          AND t.buildingActionTypeID_FK=18
          AND (k.generalNo_FK IS NULL OR EXISTS
              (SELECT 1 FROM #ValidationEligibleResidents e WHERE e.GeneralNo=k.generalNo_FK))
          AND NOT EXISTS
              (SELECT 1 FROM #ValidationDuplicateActionMap d WHERE d.duplicateActionID=k.buildingActionID)
    ) t;

    /* Historical 27 may be retained when it has BuildingAssign links.
       Do not require blanket exclusion of 27 under legacy type-7 roots. */
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Allocation migration',N'Linked legacy side allocation 27 missing',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Source type-27 with BuildingAssign history must not be dropped without an approved remap.'
    FROM KFMC.Housing.BuildingAction k
    JOIN KFMC.Housing.BuildingAction root
      ON root.buildingActionID=k.buildingActionParentID
     AND root.buildingActionParentID IS NULL
     AND root.buildingActionTypeID_FK IN (7,25)
    WHERE k.buildingActionTypeID_FK=27
      AND EXISTS (SELECT 1 FROM KFMC.Housing.BuildingAssign ba
                  WHERE ba.BuildingActionID_FK=k.buildingActionID)
      AND NOT EXISTS (SELECT 1 FROM Housing.BuildingAction t
                      WHERE t.buildingActionID=k.buildingActionID);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Allocation migration',N'Two No_house allocations become action 42',s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,
           N'No fake building or intermediate fake allocation action is created.'
    FROM
    (
        SELECT COUNT_BIG(*) c
        FROM
        (
            SELECT action27.buildingActionID
            FROM KFMC.Housing.BuildingAction action27
            JOIN KFMC.Housing.BuildingAction waitingRoot
              ON waitingRoot.buildingActionID=action27.buildingActionParentID
             AND waitingRoot.buildingActionTypeID_FK=1
            JOIN #ValidationValidAssign virtualOffer
              ON virtualOffer.BuildingActionID_FK=action27.buildingActionID
             AND virtualOffer.BuildingAssignTypeID_FK=1
             AND UPPER(LTRIM(RTRIM(ISNULL(virtualOffer.BuildingNo,N''))))=N'NO_HOUSE'
            WHERE action27.buildingActionTypeID_FK=27
            GROUP BY action27.buildingActionID
            HAVING COUNT_BIG(*)>=2
        ) expectedCancellation
    ) s
    CROSS JOIN
    (
        SELECT COUNT_BIG(*) c
        FROM Housing.BuildingAction
        WHERE buildingActionTypeID_FK=42
          AND buildingActionExtraText4 LIKE N'MoveData:NoHouse2:%'
    ) t;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Allocation migration',N'No operational No_house building',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'No generated action or building may use No_house as a real building number.'
    FROM Housing.BuildingAction
    WHERE buildingActionExtraText4 LIKE N'MoveData:%'
      AND UPPER(LTRIM(RTRIM(ISNULL(buildingDetailsNo,N''))))=N'NO_HOUSE';

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Allocation migration',N'Accepted normal allocations linked to housing through 47',s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,
           N'Every accepted normal allocation that reached housing ends 45->46->47->2.'
    FROM
    (
        SELECT COUNT_BIG(*) c
        FROM #ValidationValidAssign offer
        JOIN KFMC.Housing.BuildingAction action27
          ON action27.buildingActionID=offer.BuildingActionID_FK
         AND action27.buildingActionTypeID_FK=27
        JOIN KFMC.Housing.BuildingAction waitingRoot
          ON waitingRoot.buildingActionID=action27.buildingActionParentID
         AND waitingRoot.buildingActionTypeID_FK=1
        WHERE offer.BuildingAssignTypeID_FK=1
          AND UPPER(LTRIM(RTRIM(ISNULL(offer.BuildingNo,N''))))<>N'NO_HOUSE'
          AND offer.MeterReadValue IS NOT NULL
          AND NOT EXISTS
          (
              SELECT 1 FROM #ValidationValidAssign rejectRow
              WHERE rejectRow.BuildingAssignTypeID_FK=2
                AND rejectRow.ParentBuildingAssignID=offer.BuildingAssignID
          )
          AND EXISTS
          (
              SELECT 1 FROM KFMC.Housing.BuildingAction housingAction
              WHERE housingAction.generalNo_FK=action27.generalNo_FK
                AND housingAction.buildingActionTypeID_FK=2
                AND housingAction.buildingActionID>action27.buildingActionID
                AND UPPER(REPLACE(LTRIM(RTRIM(ISNULL(housingAction.buildingDetailsNo,N''))),N' ',N''))
                    =UPPER(REPLACE(LTRIM(RTRIM(ISNULL(offer.BuildingNo,N''))),N' ',N''))
          )
    ) s
    CROSS JOIN
    (
        SELECT COUNT_BIG(*) c
        FROM Housing.BuildingAction housingAction
        JOIN Housing.BuildingAction action47
          ON action47.buildingActionID=housingAction.buildingActionParentID
         AND action47.buildingActionTypeID_FK=47
         AND action47.buildingActionExtraText4 LIKE N'MoveData:Accept:%:47'
        WHERE housingAction.buildingActionTypeID_FK=2
    ) t;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Allocation migration',N'Letter housing linked directly 7 to 2',s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,
           N'REVIEW REQUIRED: verify historical direct-relinking against the CURRENT usp_MigrateBuildingActions contract; root now type 1/class 17.'
    FROM
    (
        SELECT COUNT_BIG(*) c
        FROM KFMC.Housing.BuildingAction sourceHousing
        JOIN KFMC.Housing.BuildingAction oldAction27
          ON oldAction27.buildingActionID=sourceHousing.buildingActionParentID
         AND oldAction27.buildingActionTypeID_FK=27
        JOIN KFMC.Housing.BuildingAction letterRoot
          ON letterRoot.buildingActionID=oldAction27.buildingActionParentID
         AND letterRoot.buildingActionTypeID_FK=7
        WHERE sourceHousing.buildingActionTypeID_FK=2
    ) s
    CROSS JOIN
    (
        SELECT COUNT_BIG(*) c
        FROM KFMC.Housing.BuildingAction sourceHousing
        JOIN KFMC.Housing.BuildingAction oldAction27
          ON oldAction27.buildingActionID=sourceHousing.buildingActionParentID
         AND oldAction27.buildingActionTypeID_FK=27
        JOIN KFMC.Housing.BuildingAction letterRoot
          ON letterRoot.buildingActionID=oldAction27.buildingActionParentID
         AND letterRoot.buildingActionTypeID_FK=7
        JOIN Housing.BuildingAction targetHousing
          ON targetHousing.buildingActionID=CONVERT(bigint,sourceHousing.buildingActionID)
         AND targetHousing.buildingActionParentID=CONVERT(bigint,letterRoot.buildingActionID)
        WHERE sourceHousing.buildingActionTypeID_FK=2
    ) t;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Completeness',N'Extend insurance',s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,
           N'Only residents whose last active action is type 24 with buildingActionExtraType1 = 2 are migrated.'
    FROM
    (
        SELECT COUNT_BIG(*) c
        FROM
        (
            SELECT sourceAction.*,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY sourceAction.generalNo_FK
                       ORDER BY ISNULL(sourceAction.buildingActionDate, sourceAction.entryDate) DESC,
                                sourceAction.buildingActionID DESC
                   ) rowNumber
            FROM KFMC.Housing.BuildingAction sourceAction
            WHERE sourceAction.generalNo_FK IS NOT NULL
              AND ISNULL(sourceAction.buildingActionActive,1)=1
        ) lastAction
        WHERE lastAction.rowNumber=1
          AND lastAction.buildingActionTypeID_FK=24
          AND lastAction.buildingActionExtraType1=2
    ) s
    CROSS JOIN
    (
        SELECT COUNT_BIG(*) c
        FROM Housing.ExtendInsurance
        WHERE IdaraId_FK=@IdaraId
    ) t;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Completeness',N'Electricity bills',s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,
           N'Matched by BillsID. Duplicate active 2024/10 bills for the same resident, building, month, year, and amount are intentionally excluded, including NULL generalNo_FK groups.'
    FROM
    (
        SELECT COUNT_BIG(*) c
        FROM
        (
            SELECT
                x.BillsID,
                CASE
                  WHEN ISNULL(x.BillActive,1)=1
                   AND x.PeriodYear=2024
                   AND x.PeriodMonth=10
                  THEN ROW_NUMBER() OVER
                  (
                    
PARTITION BY
    x.generalNo_FK,
    x.buildingDetailsNo,
    x.PeriodYear,
    x.PeriodMonth,
    CAST(ISNULL(x.TotalPrice,0) AS decimal(18,2)),
    x.meterID,
    x.meterNo,
    x.meterReadID

                    ORDER BY
                      CASE WHEN EXISTS
                      (
                        SELECT 1
                        FROM KFMC.Housing.BillsDeductListDetails d
                        WHERE d.billsID_FK=x.BillsID
                          AND d.billPaid=1
                          AND d.paidAmount IS NOT NULL
                      ) THEN 1 ELSE 0 END DESC,
                      x.BillsID
                  )
                  ELSE 1
                END AS migrationRowNo
            FROM KFMC.Housing.Bills x
        ) expectedBills
        WHERE expectedBills.migrationRowNo=1
    ) s
    CROSS JOIN
    (
        SELECT COUNT_BIG(*) c
        FROM
        (
            SELECT
                x.BillsID,
                CASE
                  WHEN ISNULL(x.BillActive,1)=1
                   AND x.PeriodYear=2024
                   AND x.PeriodMonth=10
                  THEN ROW_NUMBER() OVER
                  (
                    
PARTITION BY
    x.generalNo_FK,
    x.buildingDetailsNo,
    x.PeriodYear,
    x.PeriodMonth,
    CAST(ISNULL(x.TotalPrice,0) AS decimal(18,2)),
    x.meterID,
    x.meterNo,
    x.meterReadID

                    ORDER BY
                      CASE WHEN EXISTS
                      (
                        SELECT 1
                        FROM KFMC.Housing.BillsDeductListDetails d
                        WHERE d.billsID_FK=x.BillsID
                          AND d.billPaid=1
                          AND d.paidAmount IS NOT NULL
                      ) THEN 1 ELSE 0 END DESC,
                      x.BillsID
                  )
                  ELSE 1
                END AS migrationRowNo
            FROM KFMC.Housing.Bills x
        ) x
        JOIN Housing.Bills y ON y.BillsID=CONVERT(bigint,x.BillsID) AND y.BillChargeTypeID_FK=2
        WHERE x.migrationRowNo=1
    ) t;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Completeness',N'Excluded duplicate electricity bills present',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Active duplicate electricity bills for 2024/10 must not exist in DATACORE after migration, including NULL generalNo_FK groups.'
    FROM
    (
        SELECT
            x.BillsID,
            CASE
              WHEN ISNULL(x.BillActive,1)=1
               AND x.PeriodYear=2024
               AND x.PeriodMonth=10
              THEN ROW_NUMBER() OVER
              (
                
PARTITION BY
    x.generalNo_FK,
    x.buildingDetailsNo,
    x.PeriodYear,
    x.PeriodMonth,
    CAST(ISNULL(x.TotalPrice,0) AS decimal(18,2)),
    x.meterID,
    x.meterNo,
    x.meterReadID


                ORDER BY
                  CASE WHEN EXISTS
                  (
                    SELECT 1
                    FROM KFMC.Housing.BillsDeductListDetails d
                    WHERE d.billsID_FK=x.BillsID
                      AND d.billPaid=1
                      AND d.paidAmount IS NOT NULL
                  ) THEN 1 ELSE 0 END DESC,
                  x.BillsID
              )
              ELSE 1
            END AS migrationRowNo
        FROM KFMC.Housing.Bills x
    ) excludedBills
    JOIN Housing.Bills y ON y.BillsID=CONVERT(bigint,excludedBills.BillsID)
    WHERE excludedBills.migrationRowNo>1
      AND y.BillChargeTypeID_FK=2;




      
/*
    Validate electricity bills linked to excluded MeterRead rows.

    The bills must be preserved with:
    - Original BillsID and BillsUID.
    - Original generalNo_FK and TotalPrice.
    - NULL meterReadID.
    - NULL residentInfoID_FK.

    Excluded readings are identified dynamically
    from KFMC residents without ResidentDetails.
*/

;WITH AffectedBills AS
(
    SELECT
        sourceBill.BillsID,
        sourceBill.TotalPrice,

        CASE
            WHEN targetBill.BillsID IS NOT NULL
                THEN 1
            ELSE 0
        END AS IsCorrectlyMigrated

    FROM KFMC.Housing.Bills sourceBill

    LEFT JOIN Housing.Bills targetBill
        ON targetBill.BillsID =
           CONVERT(bigint, sourceBill.BillsID)

       AND targetBill.BillsUID =
           sourceBill.BillsUID

       AND targetBill.BillChargeTypeID_FK = 2

       AND targetBill.meterReadID IS NULL

       AND targetBill.residentInfoID_FK IS NULL

       AND NOT EXISTS
       (
           SELECT
               targetBill.generalNo_FK,
               targetBill.TotalPrice

           EXCEPT

           SELECT
               CONVERT(bigint, sourceBill.generalNo_FK),
               sourceBill.TotalPrice
       )

    WHERE EXISTS
    (
        SELECT 1
        FROM KFMC.Housing.MeterRead sourceRead

        INNER JOIN KFMC.Housing.ResidentInfo excludedResident
            ON excludedResident.generalNo =
               sourceRead.generalNo_FK

        WHERE sourceRead.meterReadID =
              sourceBill.meterReadID

          AND NOT EXISTS
          (
              SELECT 1
              FROM KFMC.Housing.ResidentDetails details
              WHERE details.generalNo_FK =
                    excludedResident.generalNo
          )
    )
),
Totals AS
(
    SELECT
        COUNT_BIG(*) AS ExpectedBills,

        COALESCE(
            SUM(CONVERT(bigint, IsCorrectlyMigrated)),
            0
        ) AS MatchedBills,

        COALESCE(
            SUM(CONVERT(decimal(38,2), TotalPrice)),
            0
        ) AS ExpectedAmount,

        COALESCE(
            SUM
            (
                CASE
                    WHEN IsCorrectlyMigrated = 1
                        THEN CONVERT(decimal(38,2), TotalPrice)
                    ELSE CONVERT(decimal(38,2), 0)
                END
            ),
            0
        ) AS MatchedAmount

    FROM AffectedBills
)

INSERT @Checks
(
    Category,
    CheckName,
    ExpectedValue,
    ActualValue,
    Difference,
    Result,
    Notes
)
SELECT
    N'Integrity',
    v.CheckName,
    v.ExpectedValue,
    v.ActualValue,
    v.ActualValue - v.ExpectedValue,

    CASE
        WHEN v.ExpectedValue = v.ActualValue
            THEN 'PASS'
        ELSE 'FAIL'
    END,

    v.Notes

FROM Totals t

CROSS APPLY
(
    VALUES
    (
        N'Electricity bills with excluded readings - count',

        CONVERT(decimal(38,2), t.ExpectedBills),
        CONVERT(decimal(38,2), t.MatchedBills),

        N'Bills must retain their original identity, amount and general number, with NULL meterReadID and residentInfoID_FK.'
    ),

    (
        N'Electricity bills with excluded readings - amount',

        CONVERT(decimal(38,2), t.ExpectedAmount),
        CONVERT(decimal(38,2), t.MatchedAmount),

        N'Total amounts of correctly migrated bills linked to excluded source readings.'
    )
) v
(
    CheckName,
    ExpectedValue,
    ActualValue,
    Notes
);


    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Completeness',N'Active rent payments',s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,N'Cancelled source lists and payments are excluded.'
    FROM
    (
        SELECT COUNT_BIG(*) c FROM KFMC.Housing.BuildingPayment p
        JOIN KFMC.Housing.DeductList d ON d.deductListID=p.deductListID_FK
        WHERE p.buildingPayementActive=1 AND d.deductActive=1
    ) s
    CROSS JOIN
    (
        SELECT COUNT_BIG(*) c
        FROM Housing.BuildingPayment targetPayment
        INNER JOIN KFMC.Housing.BuildingPayment sourcePayment
            ON sourcePayment.paymentID = targetPayment.paymentID
        INNER JOIN KFMC.Housing.DeductList sourceDeduct
            ON sourceDeduct.deductListID = sourcePayment.deductListID_FK
        WHERE targetPayment.BillChargeTypeID_FK = 1
          AND targetPayment.buildingPayementActive = 1
          AND targetPayment.IdaraId_FK = @IdaraId
          AND sourcePayment.buildingPayementActive = 1
          AND sourceDeduct.deductActive = 1
    ) t;



     
/*
    Validate historical rent payments by original ID.

    Source payments with buildingPayementActive = 1:
    - Active source list   => active target payment.
    - Inactive source list => inactive target payment.

    Preserve original payment identity, general number,
    amount, deduction list and payment UID.
*/

;WITH SourcePayments AS
(
    SELECT
        p.paymentID,
        p.PaymentUID,
        p.userID_FK,
        p.amount,
        p.deductListID_FK,
        p.buildingPayementActive,
        d.deductActive,

        CASE
            WHEN t.paymentID IS NOT NULL
             AND td.deductListID IS NOT NULL

             AND td.deductActive = d.deductActive

             AND t.BillChargeTypeID_FK = 1
             AND t.IdaraId_FK = @IdaraId

             AND NOT EXISTS
             (
                 SELECT
                     t.PaymentUID,
                     t.generalNo_FK,
                     t.amount,
                     t.deductListID_FK,
                     t.buildingPayementActive

                 EXCEPT

                 SELECT
                     p.PaymentUID,
                     CONVERT(bigint, p.userID_FK),
                     p.amount,
                     p.deductListID_FK,

                     CASE
                         WHEN d.deductActive = 0
                             THEN CONVERT(bit, 0)
                         ELSE p.buildingPayementActive
                     END
             )
            THEN CONVERT(bigint, 1)
            ELSE CONVERT(bigint, 0)
        END AS IsCorrectlyMigrated

    FROM KFMC.Housing.BuildingPayment p

    INNER JOIN KFMC.Housing.DeductList d
        ON d.deductListID = p.deductListID_FK

    LEFT JOIN Housing.BuildingPayment t
        ON t.paymentID = CONVERT(bigint, p.paymentID)

    LEFT JOIN Housing.DeductList td
        ON td.deductListID = p.deductListID_FK

    WHERE p.buildingPayementActive = 1
      AND d.deductActive IN (0, 1)
),
Totals AS
(
    SELECT
        deductActive,

        COUNT_BIG(*) AS ExpectedCount,

        SUM(IsCorrectlyMigrated) AS MatchedCount,

        COALESCE
        (
            SUM(CONVERT(decimal(38,2), amount)),
            0
        ) AS ExpectedAmount,

        COALESCE
        (
            SUM
            (
                CASE
                    WHEN IsCorrectlyMigrated = 1
                        THEN CONVERT(decimal(38,2), amount)
                    ELSE CONVERT(decimal(38,2), 0)
                END
            ),
            0
        ) AS MatchedAmount

    FROM SourcePayments

    GROUP BY deductActive
)

INSERT @Checks
(
    Category,
    CheckName,
    ExpectedValue,
    ActualValue,
    Difference,
    Result,
    Notes
)
SELECT
    N'Financial reconciliation',
    v.CheckName,
    v.ExpectedValue,
    v.ActualValue,
    v.ActualValue - v.ExpectedValue,

    CASE
        WHEN v.ExpectedValue = v.ActualValue
            THEN 'PASS'
        ELSE 'FAIL'
    END,

    N'مطابقة السدادات بالمعرف الأصلي والرقم العام والمبلغ وحالة النشاط والمسير.'

FROM Totals t

CROSS APPLY
(
    VALUES
    (
        CASE
            WHEN t.deductActive = 1
                THEN N'Active historical rent payments - count'
            ELSE N'Inactive historical rent payments - count'
        END,
        CONVERT(decimal(38,2), t.ExpectedCount),
        CONVERT(decimal(38,2), t.MatchedCount)
    ),

    (
        CASE
            WHEN t.deductActive = 1
                THEN N'Active historical rent payments - amount'
            ELSE N'Inactive historical rent payments - amount'
        END,
        t.ExpectedAmount,
        t.MatchedAmount
    )
) v
(
    CheckName,
    ExpectedValue,
    ActualValue
);



    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Completeness',N'Penalty bills',s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,N'Every old custody penalty becomes a bill.'
    FROM (SELECT COUNT_BIG(*) c FROM KFMC.Housing.OccupantCustodyAction) s
    CROSS JOIN
    (
        SELECT COUNT_BIG(*) c
        FROM Housing.Bills targetBill
        INNER JOIN KFMC.Housing.OccupantCustodyAction sourcePenalty
            ON targetBill.BillsUID = CONVERT
            (
                uniqueidentifier,
                HASHBYTES('MD5', CONCAT(N'PENALTY-BILL|', sourcePenalty.occupantCustodyActionID))
            )
        WHERE targetBill.BillChargeTypeID_FK = 5
          AND targetBill.idaraID_FK = @IdaraId
    ) t;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Completeness',N'Paid penalties',s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,N'Every old paid penalty becomes a payment.'
    FROM (SELECT COUNT_BIG(*) c FROM KFMC.Housing.OccupantCustodyAction WHERE Paid=1) s
    CROSS JOIN (SELECT COUNT_BIG(*) c FROM Housing.BuildingPayment
                 WHERE BillChargeTypeID_FK=5 AND buildingPayementActive=1 AND IdaraId_FK=@IdaraId) t;

    /* Generated monthly bill invariants. */
    /* Pre-2017 rent is valid ONLY for an occupancy cycle still active at
       the actual historical migration cutover.  This check does NOT require
       pre-2017 bills from people who had already vacated or were replaced. */
    ;WITH ContinuedOccupanciesAtCutover AS
    (
        SELECT
            sr.residentInfoID AS ResidentID,
            a.generalNo_FK AS GeneralNo,
            LTRIM(RTRIM(a.buildingDetailsNo)) AS BuildingNo,
            CAST(a.buildingActionDate AS date) AS OccupancyDate
        FROM KFMC.Housing.BuildingAction a
        JOIN KFMC.Housing.ResidentInfo sr
          ON sr.generalNo = a.generalNo_FK
        WHERE a.buildingActionTypeID_FK = 2
          AND a.buildingActionActive = 1
          AND a.buildingActionDate IS NOT NULL
          AND a.buildingActionDate < @RentChargeStartDate
          AND NOT EXISTS
          (
              SELECT 1 FROM KFMC.Housing.BuildingAction ex
              WHERE ex.buildingActionTypeID_FK = 3
                AND ex.buildingActionActive = 1
                AND ex.generalNo_FK = a.generalNo_FK
                AND LTRIM(RTRIM(ex.buildingDetailsNo)) = LTRIM(RTRIM(a.buildingDetailsNo))
                AND ex.buildingActionDate >= a.buildingActionDate
                AND ex.buildingActionDate < DATEADD(day,1,@ValidationCutoverDate)
                AND (ex.buildingActionParentID = a.buildingActionID
                     OR ex.buildingActionParentID IS NULL)
          )
          AND NOT EXISTS
          (
              SELECT 1 FROM KFMC.Housing.BuildingAction nx
              WHERE nx.buildingActionTypeID_FK = 2
                AND nx.buildingActionActive = 1
                AND LTRIM(RTRIM(nx.buildingDetailsNo)) = LTRIM(RTRIM(a.buildingDetailsNo))
                AND nx.buildingActionDate > a.buildingActionDate
                AND nx.buildingActionDate < DATEADD(day,1,@ValidationCutoverDate)
          )
    )
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Generated bills',N'Pre-2017 rent only for continued occupancy at cutover',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Pre-2017 active rent bills must belong to a housing cycle still occupied at migration cutover; vacated/replaced cycles retain the 2017 floor.'
    FROM Housing.Bills b
    WHERE b.BillChargeTypeID_FK = 1
      AND b.idaraID_FK = @IdaraId
      AND b.BillActive = 1
      AND b.BillsFromDate < @RentChargeStartDate
      AND NOT EXISTS
      (
          SELECT 1 FROM ContinuedOccupanciesAtCutover c
          WHERE c.ResidentID = b.residentInfoID_FK
            AND c.GeneralNo = b.generalNo_FK
            AND c.BuildingNo COLLATE DATABASE_DEFAULT
                = LTRIM(RTRIM(b.buildingDetailsNo)) COLLATE DATABASE_DEFAULT
            AND b.BillsFromDate >= c.OccupancyDate
            AND b.BillsToDate <= @HistoricalBillMonthEnd
      );

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Generated bills',N'No water bills before enforcement date',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Water charges start on 2024-01-01; older occupancy months must not receive water bills.'
    FROM Housing.Bills
    WHERE BillChargeTypeID_FK=3
      AND idaraID_FK=@IdaraId
      AND BillActive=1
      AND BillsFromDate < @WaterChargeStartDate;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Generated bills',N'Rent or water bills extending beyond evacuation date',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Every active KFMC type-3 action ends rent and water charging on its buildingActionDate, regardless of ExtraInt1 workflow stage.'
    FROM Housing.Bills targetBill
    CROSS APPLY
    (
        SELECT TOP (1)
               occupancy.buildingActionID,
               occupancy.buildingActionDate OccupancyDate
        FROM KFMC.Housing.BuildingAction occupancy
        WHERE occupancy.buildingActionTypeID_FK=2
          AND occupancy.generalNo_FK=targetBill.generalNo_FK
          AND LTRIM(RTRIM(occupancy.buildingDetailsNo))=LTRIM(RTRIM(targetBill.buildingDetailsNo))
          AND occupancy.buildingActionDate<=targetBill.BillsFromDate
        ORDER BY occupancy.buildingActionDate DESC,occupancy.buildingActionID DESC
    ) relevantOccupancy
    CROSS APPLY
    (
        SELECT TOP (1) evacuation.buildingActionDate EvacuationDate
        FROM KFMC.Housing.BuildingAction evacuation
        WHERE evacuation.buildingActionTypeID_FK=3
          AND evacuation.buildingActionActive=1
          AND evacuation.generalNo_FK=targetBill.generalNo_FK
          AND LTRIM(RTRIM(evacuation.buildingDetailsNo))=LTRIM(RTRIM(targetBill.buildingDetailsNo))
          AND evacuation.buildingActionDate>=relevantOccupancy.OccupancyDate
          AND evacuation.buildingActionParentID=relevantOccupancy.buildingActionID
        ORDER BY evacuation.buildingActionDate,evacuation.buildingActionID
    ) relevantEvacuation
    WHERE targetBill.BillChargeTypeID_FK IN(1,3)
      AND targetBill.BillActive=1
      AND targetBill.BillsToDate>relevantEvacuation.EvacuationDate;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Business rules',N'Monthly rent procedure ignores ExitDate',
           0,
           CASE
               WHEN OBJECT_DEFINITION(OBJECT_ID(N'Housing.BuildingRentForOneMonth',N'P')) LIKE N'%CAST(o.ExitDate AS date)%'
                AND OBJECT_DEFINITION(OBJECT_ID(N'Housing.BuildingRentForOneMonth',N'P')) LIKE N'%o.ExitDate IS NULL%'
               THEN 0 ELSE 1
           END,
           CASE
               WHEN OBJECT_DEFINITION(OBJECT_ID(N'Housing.BuildingRentForOneMonth',N'P')) LIKE N'%CAST(o.ExitDate AS date)%'
                AND OBJECT_DEFINITION(OBJECT_ID(N'Housing.BuildingRentForOneMonth',N'P')) LIKE N'%o.ExitDate IS NULL%'
               THEN 0 ELSE 1
           END,
           CASE
               WHEN OBJECT_DEFINITION(OBJECT_ID(N'Housing.BuildingRentForOneMonth',N'P')) LIKE N'%CAST(o.ExitDate AS date)%'
                AND OBJECT_DEFINITION(OBJECT_ID(N'Housing.BuildingRentForOneMonth',N'P')) LIKE N'%o.ExitDate IS NULL%'
               THEN 'PASS' ELSE 'FAIL'
           END,
           N'BuildingRentForOneMonth must pass ExitDate to the rent function and exclude months wholly after evacuation.';

    /* Row-value reconciliation for directly copied entities. */
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Value reconciliation',N'ResidentInfo value differences',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Compares NationalID and active status for matching IDs.'
    FROM KFMC.Housing.ResidentInfo s JOIN Housing.ResidentInfo t
      ON t.residentInfoID=CONVERT(bigint,s.residentInfoID)
    WHERE ISNULL(t.NationalID,N'')<>ISNULL(s.NationalID,N'')
       OR ISNULL(t.residentInfoActive,0)<>ISNULL(s.residentInfoActive,0);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Value reconciliation',N'Building value differences',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,N'Compares normalized building number.'
    FROM KFMC.Housing.BuildingDetails s JOIN Housing.BuildingDetails t
      ON t.buildingDetailsID=CONVERT(bigint,s.buildingDetailsID)
    WHERE ISNULL(LTRIM(RTRIM(t.buildingDetailsNo)),N'')<>
          ISNULL(LTRIM(RTRIM(s.buildingDetailsNo)),N'');

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Value reconciliation',N'Meter value differences',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,N'Compares normalized meter number.'
    FROM KFMC.Housing.Meter s JOIN Housing.Meter t ON t.meterID=CONVERT(bigint,s.meterID)
    WHERE ISNULL(LTRIM(RTRIM(t.meterNo)),N'')<>ISNULL(LTRIM(RTRIM(s.meterNo)),N'');

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Value reconciliation',N'BuildingAction value differences',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Compares mapped type, parent, active flag, and action date. Old evacuation type 3 maps by ExtraInt1.'
    FROM KFMC.Housing.BuildingAction s JOIN Housing.BuildingAction t
      ON t.buildingActionID=CONVERT(bigint,s.buildingActionID)
    LEFT JOIN #ValidationDuplicateActionMap parentDuplicate
      ON parentDuplicate.duplicateActionID=s.buildingActionParentID
    LEFT JOIN KFMC.Housing.BuildingAction letterAllocationParent
      ON letterAllocationParent.buildingActionID=s.buildingActionParentID
     AND letterAllocationParent.buildingActionTypeID_FK=27
     AND EXISTS
     (
         SELECT 1 FROM KFMC.Housing.BuildingAction letterRoot
         WHERE letterRoot.buildingActionID=letterAllocationParent.buildingActionParentID
           AND letterRoot.buildingActionTypeID_FK=7
     )
    WHERE
      (
       s.generalNo_FK IS NULL
       OR
       (
        s.generalNo_FK NOT IN (0,1,18)
        AND EXISTS
        (
         SELECT 1 FROM KFMC.Housing.ResidentInfo validResident
         WHERE validResident.generalNo=s.generalNo_FK
        )
       )
      )
      AND
      (
       ISNULL(t.buildingActionTypeID_FK,-1)<>
          ISNULL(CASE
              WHEN s.buildingActionTypeID_FK=3
                   AND s.buildingActionExtraInt1 IS NULL THEN 3
              WHEN s.buildingActionTypeID_FK=3
                   AND s.buildingActionExtraInt1=1 THEN 59
              WHEN s.buildingActionTypeID_FK=3
                   AND s.buildingActionExtraInt1 IN (2,3) THEN 57
              WHEN s.buildingActionTypeID_FK=3
                   AND s.buildingActionExtraInt1=4 THEN 57
              WHEN s.buildingActionTypeID_FK=3
                   AND s.buildingActionExtraInt1=5 THEN 3
              ELSE s.buildingActionTypeID_FK
          END,-1)
       OR ISNULL(t.buildingActionParentID,-1)<>
          ISNULL(COALESCE
          (
              parentDuplicate.retainedActionID,
              CASE WHEN letterAllocationParent.buildingActionID IS NOT NULL
                   THEN letterAllocationParent.buildingActionParentID END,
              s.buildingActionParentID
          ),-1)
       OR ISNULL(t.buildingActionActive,0)<>ISNULL(s.buildingActionActive,0)
       OR ISNULL(t.buildingActionDate,CONVERT(datetime,'19000101',112))<>
          ISNULL(s.buildingActionDate,CONVERT(datetime,'19000101',112))
      )
      AND NOT
      (
          s.buildingActionTypeID_FK=27
          AND EXISTS
          (
              SELECT 1 FROM KFMC.Housing.BuildingAction letterRoot
              WHERE letterRoot.buildingActionID=s.buildingActionParentID
              AND letterRoot.buildingActionTypeID_FK=7
          )
      )
      AND NOT
      (
          s.buildingActionTypeID_FK=2
          AND EXISTS
          (
              SELECT 1
              FROM Housing.BuildingAction generatedParent
              WHERE generatedParent.buildingActionID=t.buildingActionParentID
                AND generatedParent.buildingActionTypeID_FK=47
                AND generatedParent.buildingActionExtraText4 LIKE N'MoveData:Accept:%:47'
          )
      );

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Integrity',N'Excluded invalid-general-number actions present',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Actions with general number 0/1 or a non-NULL number absent from KFMC ResidentInfo must not be migrated. NULL building-only actions remain valid.'
    FROM Housing.BuildingAction targetAction
    JOIN KFMC.Housing.BuildingAction sourceAction
      ON sourceAction.buildingActionID=targetAction.buildingActionID
    WHERE sourceAction.generalNo_FK IN (0,1)
       OR
       (
           sourceAction.generalNo_FK IS NOT NULL
           AND NOT EXISTS
           (
               SELECT 1 FROM KFMC.Housing.ResidentInfo validResident
               WHERE validResident.generalNo=sourceAction.generalNo_FK
           )
       );

    /* Action 27 is an allocation stage, never a workflow root. General numbers
       0 and 1 are retained cancellation/audit rows and are intentionally ignored. */
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Business rules',N'Meaningful action 27 without parent action 1 or 7',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
N'Action 27 requires an existing waiting root of type 1 or 7. Historical inactive roots are valid; operational eligibility is validated separately.'    FROM Housing.BuildingAction action27
    WHERE action27.buildingActionTypeID_FK=27
      AND action27.buildingActionActive=1
      AND ISNULL(action27.generalNo_FK,0) NOT IN (0,1,18)
      AND NOT EXISTS
(
    SELECT 1
    FROM Housing.BuildingAction rootAction
    WHERE rootAction.buildingActionID = action27.buildingActionParentID
      AND rootAction.buildingActionTypeID_FK IN (1,7)
      AND rootAction.buildingActionParentID IS NULL
)

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Business rules',N'Duplicate waiting-list traversal for same final action',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'V_WaitingList must not traverse the same resident, building, and final action from more than one root.'
    FROM
    (
        SELECT waiting.residentInfoID,waiting.buildingDetailsID,waiting.LastActionID
        FROM Housing.V_WaitingList waiting
        WHERE waiting.IdaraId=@IdaraId
          AND waiting.LastActionID IS NOT NULL
        GROUP BY waiting.residentInfoID,waiting.buildingDetailsID,waiting.LastActionID
        HAVING COUNT_BIG(*)>1
    ) duplicateTraversal;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Allocation migration',N'Pending legacy allocations hidden from AssignStatusDL',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Migration-generated pending actions 38/40 belong to closed historical periods and must have InAssignPeriod = 0.'
    FROM Housing.BuildingAction pendingAllocation
    WHERE pendingAllocation.buildingActionTypeID_FK IN (38,40)
      AND pendingAllocation.buildingActionExtraText4 LIKE N'MoveData:Assign:%'
      AND ISNULL(pendingAllocation.InAssignPeriod,-1)<>0;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Evacuation actions',N'Evacuation actions completeness',s.c,t.c,t.c-s.c,
           CASE WHEN s.c=t.c THEN 'PASS' ELSE 'FAIL' END,
           N'All old type-3 actions must be migrated, except consecutive identical actions excluded by the migration rule.'
    FROM
    (
        SELECT COUNT_BIG(*) c
        FROM KFMC.Housing.BuildingAction sourceAction
        WHERE sourceAction.buildingActionTypeID_FK=3
          AND NOT EXISTS
          (
              SELECT 1 FROM #ValidationDuplicateActionMap duplicateAction
              WHERE duplicateAction.duplicateActionID=sourceAction.buildingActionID
          )
    ) s
    CROSS JOIN
    (
        SELECT COUNT_BIG(*) c
        FROM KFMC.Housing.BuildingAction sourceAction
        JOIN Housing.BuildingAction targetAction
          ON targetAction.buildingActionID=CONVERT(bigint,sourceAction.buildingActionID)
        WHERE sourceAction.buildingActionTypeID_FK=3
    ) t;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Evacuation actions',N'Evacuation action type mapping differences',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Old ExtraInt1: NULL/5->3, 1->59, 2/3->57, 4->57.'
    FROM KFMC.Housing.BuildingAction sourceAction
    JOIN Housing.BuildingAction targetAction
      ON targetAction.buildingActionID=CONVERT(bigint,sourceAction.buildingActionID)
    WHERE sourceAction.buildingActionTypeID_FK=3
      AND targetAction.buildingActionTypeID_FK<>
          CASE
              WHEN sourceAction.buildingActionExtraInt1 IS NULL
                   OR sourceAction.buildingActionExtraInt1=5 THEN 3
              WHEN sourceAction.buildingActionExtraInt1=1 THEN 59
              WHEN sourceAction.buildingActionExtraInt1 IN(2,3) THEN 57
              WHEN sourceAction.buildingActionExtraInt1=4 THEN 57
              ELSE -1
          END;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Evacuation actions',N'Unsupported old evacuation stages',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Only NULL and values 1,2,3,4,5 are supported in old buildingActionExtraInt1.'
    FROM KFMC.Housing.BuildingAction
    WHERE buildingActionTypeID_FK=3
      AND buildingActionExtraInt1 IS NOT NULL
      AND buildingActionExtraInt1 NOT IN(1,2,3,4,5);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Evacuation actions',N'Evacuation effective-date mapping differences',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Every old type-3 action retains its recorded buildingActionDate as effective ExitDate, regardless of workflow stage.'
    FROM KFMC.Housing.BuildingAction sourceAction
    JOIN Housing.BuildingAction targetAction
      ON targetAction.buildingActionID=CONVERT(bigint,sourceAction.buildingActionID)
    WHERE sourceAction.buildingActionTypeID_FK=3
      AND ISNULL(targetAction.ExitDate,CONVERT(datetime,'19000101',112))<>
          ISNULL(sourceAction.buildingActionDate,CONVERT(datetime,'19000101',112));

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Evacuation actions',N'Evacuation workflow actions missing effective dates',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Workflow status and effective evacuation date are independent; migrated stages 57/58/59 must retain OccupentDate and ExitDate.'
    FROM KFMC.Housing.BuildingAction sourceAction
    JOIN Housing.BuildingAction targetAction
      ON targetAction.buildingActionID=CONVERT(bigint,sourceAction.buildingActionID)
    WHERE sourceAction.buildingActionTypeID_FK=3
      AND sourceAction.buildingActionExtraInt1 IN(1,2,3,4)
      AND (targetAction.ExitDate IS NULL OR targetAction.OccupentDate IS NULL);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Value reconciliation',N'BuildingAction extend reason differences',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'For action type 24: old extra type 2->1, 3->3, 4->2.'
    FROM KFMC.Housing.BuildingAction s
    JOIN Housing.BuildingAction t ON t.buildingActionID=CONVERT(bigint,s.buildingActionID)
    WHERE s.buildingActionTypeID_FK=24
      AND ISNULL(t.ExtendReasonTypeID_FK,-1) <>
          ISNULL(CASE
              WHEN s.buildingActionExtraType1=2 THEN 1
              WHEN s.buildingActionExtraType1=3 THEN 3
              WHEN s.buildingActionExtraType1=4 THEN 2
          END,-1);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Value reconciliation',N'Extend insurance value differences',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Compares amount, remaining, type, approval flag, number, and date.'
    FROM
    (
        SELECT retainedAction.*
        FROM
        (
            SELECT actionRow.*,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY actionRow.generalNo_FK
                       ORDER BY ISNULL(actionRow.buildingActionDate, actionRow.entryDate) DESC,
                                actionRow.buildingActionID DESC
                   ) rowNumber
            FROM Housing.BuildingAction actionRow
            WHERE actionRow.generalNo_FK IS NOT NULL
              AND ISNULL(actionRow.buildingActionActive,1)=1
        ) retainedAction
        WHERE retainedAction.rowNumber=1
          AND retainedAction.buildingActionTypeID_FK=24
          AND retainedAction.buildingActionExtraType1=2
    ) s
    JOIN Housing.ExtendInsurance t ON t.buildingActionID_FK=s.buildingActionID
    WHERE CAST(ISNULL(t.InsuranceAmount,0) AS decimal(18,2))<>
          CAST(ISNULL(s.buildingActionExtraFloat1,0) AS decimal(18,2))
       OR ISNULL(t.Remaining,0)<>0
       OR CAST(ISNULL(t.InsuranceAmountWithRemaining,0) AS decimal(18,2))<>
          CAST(ISNULL(s.buildingActionExtraFloat1,0) AS decimal(18,2))
       OR ISNULL(t.ExtendInsuranceNo,N'')<>ISNULL(s.buildingActionDecisionNo,N'')
       OR ISNULL(t.ExtendInsuranceDate,CONVERT(datetime,'19000101',112))<>ISNULL(s.entryDate,CONVERT(datetime,'19000101',112))
       OR ISNULL(t.ExtendInsuranceType,-1)<>1
       OR ISNULL(t.ExtendInsuranceActive,0)<>1
       OR ISNULL(t.ExtendInsuranceApproved,1)<>0;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Value reconciliation',N'Missing or changed resident contacts',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Compares type, details, dates, and active status for resident contacts.'
    FROM KFMC.dbo.contactInfo sc
    JOIN KFMC.Housing.ResidentInfo sr ON sr.generalNo=sc.userID_FK
    JOIN Housing.ResidentInfo tr ON tr.residentInfoID=CONVERT(bigint,sr.residentInfoID)
    WHERE NOT EXISTS
    (
        SELECT 1 FROM Housing.ResidentContactInfo tc
        WHERE tc.residentInfoID_FK=tr.residentInfoID
          AND ISNULL(tc.residentcontanctTypeID_FK,-1)=ISNULL(sc.contanctTypeID_FK,-1)
          AND ISNULL(tc.residentcontactDetails,N'')=ISNULL(sc.contactDetails,N'')
          AND ISNULL(tc.residentcontactInfoStartDate,CONVERT(datetime,'19000101',112))=
              ISNULL(sc.contactInfoStartDate,CONVERT(datetime,'19000101',112))
          AND ISNULL(tc.residentcontactInfoEndDate,CONVERT(datetime,'19000101',112))=
              ISNULL(sc.contactInfoEndDate,CONVERT(datetime,'19000101',112))
          AND ISNULL(tc.residentcontactInfoActive,0)=ISNULL(sc.contactInfoActive,0)
    );

    /* Generated-bill uniqueness and pairing for occupied periods. */
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Generated bills',N'Duplicate occupied rent/water monthly bill groups',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'One bill per charge type, resident, building, year, and month for occupied periods.'
    FROM
    (
        SELECT BillChargeTypeID_FK,residentInfoID_FK,buildingDetailsID,PeriodYear,PeriodMonth
        FROM Housing.Bills
        WHERE BillChargeTypeID_FK IN(1,3) AND idaraID_FK=@IdaraId AND BillActive=1
          AND residentInfoID_FK IS NOT NULL
        GROUP BY BillChargeTypeID_FK,residentInfoID_FK,buildingDetailsID,PeriodYear,PeriodMonth
        HAVING COUNT_BIG(*)>1
    ) duplicateGroup;

    ;WITH OccupiedMonthlyPairs AS
    (
        SELECT residentInfoID_FK,buildingDetailsID,PeriodYear,PeriodMonth,
               SUM(CASE WHEN BillChargeTypeID_FK=1 THEN 1 ELSE 0 END) RentCount,
               SUM(CASE WHEN BillChargeTypeID_FK=3 THEN 1 ELSE 0 END) WaterCount
        FROM Housing.Bills
        WHERE BillChargeTypeID_FK IN(1,3) AND idaraID_FK=@IdaraId AND BillActive=1
          AND residentInfoID_FK IS NOT NULL
        GROUP BY residentInfoID_FK,buildingDetailsID,PeriodYear,PeriodMonth
    )
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Generated bills',N'Unpaired occupied monthly rent/water bills',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'From 2024-01 onward, every occupied migrated month must contain one rent and one water bill.'
    FROM OccupiedMonthlyPairs
    WHERE DATEFROMPARTS(PeriodYear,PeriodMonth,1)>=@WaterChargeStartDate
      AND (RentCount<>1 OR WaterCount<>1);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Vacant service bills',N'Rent bills generated for vacant periods',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Vacant periods may receive fixed-service bills but must never receive rent bills.'
    FROM Housing.Bills
    WHERE BillChargeTypeID_FK=1 AND idaraID_FK=@IdaraId AND BillActive=1
      AND residentInfoID_FK IS NULL AND generalNo_FK IS NULL;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Vacant service bills',N'Duplicate exact vacant-water periods',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Only one active water bill may represent the same building and exact vacant date range.'
    FROM
    (
        SELECT buildingDetailsID,BillsFromDate,BillsToDate
        FROM Housing.Bills
        WHERE BillChargeTypeID_FK=3 AND idaraID_FK=@IdaraId AND BillActive=1
          AND residentInfoID_FK IS NULL AND generalNo_FK IS NULL
        GROUP BY buildingDetailsID,BillsFromDate,BillsToDate
        HAVING COUNT_BIG(*)>1
    ) duplicateVacancy;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Vacant service bills',N'Overlapping distinct vacant-water periods',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Distinct vacant-water periods for one building must not overlap; separate non-overlapping gaps in one month are valid.'
    FROM Housing.Bills firstBill
    JOIN Housing.Bills secondBill
      ON secondBill.BillsID>firstBill.BillsID
     AND secondBill.buildingDetailsID=firstBill.buildingDetailsID
     AND secondBill.BillChargeTypeID_FK=3
     AND secondBill.idaraID_FK=@IdaraId
     AND secondBill.BillActive=1
     AND secondBill.residentInfoID_FK IS NULL
     AND secondBill.generalNo_FK IS NULL
     AND secondBill.BillsFromDate<=firstBill.BillsToDate
     AND secondBill.BillsToDate>=firstBill.BillsFromDate
     AND NOT (secondBill.BillsFromDate=firstBill.BillsFromDate AND secondBill.BillsToDate=firstBill.BillsToDate)
    WHERE firstBill.BillChargeTypeID_FK=3 AND firstBill.idaraID_FK=@IdaraId
      AND firstBill.BillActive=1 AND firstBill.residentInfoID_FK IS NULL
      AND firstBill.generalNo_FK IS NULL;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Vacant service bills',N'Vacant water bills carrying a general number',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'A water bill without a resident must not retain a general number from a previous or later occupant.'
    FROM Housing.Bills
    WHERE BillChargeTypeID_FK=3 AND idaraID_FK=@IdaraId AND BillActive=1
      AND residentInfoID_FK IS NULL AND generalNo_FK IS NOT NULL;
    ;WITH WaterCalculation AS
    (
        SELECT b.BillsID,b.PRICE,b.PRICETAX,b.TotalPrice,
               ((YEAR(b.BillsToDate)-YEAR(b.BillsFromDate))*360
                +(MONTH(b.BillsToDate)-MONTH(b.BillsFromDate))*30
                +(CASE WHEN b.BillsToDate=EOMONTH(b.BillsToDate) AND DAY(b.BillsToDate)<30 THEN 30
                       WHEN DAY(b.BillsToDate)>30 THEN 30 ELSE DAY(b.BillsToDate) END)
                -(CASE WHEN b.BillsFromDate=EOMONTH(b.BillsFromDate) AND DAY(b.BillsFromDate)<30 THEN 30
                       WHEN DAY(b.BillsFromDate)>30 THEN 30 ELSE DAY(b.BillsFromDate) END)+1) Days30
        FROM Housing.Bills b
        WHERE b.BillChargeTypeID_FK=3 AND b.idaraID_FK=@IdaraId AND b.BillActive=1
          AND b.BillsFromDate IS NOT NULL
          AND b.BillsToDate <= @HistoricalBillMonthEnd
    )
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Generated bills',N'Incorrect water-bill calculations',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Expected amount is WaterMonthlyAmount divided by 30 and multiplied by Days30.'
    FROM WaterCalculation
    WHERE TotalPrice<>CAST((@WaterMonthlyAmount/30.0)*Days30 AS decimal(18,2));

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Generated bills',N'Incorrect water VAT separation',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Water TotalPrice is VAT-inclusive; PRICE is net of 15% VAT and PRICETAX is the separated VAT amount.'
    FROM Housing.Bills waterBill
    WHERE waterBill.BillChargeTypeID_FK=3
      AND waterBill.idaraID_FK=@IdaraId
      AND waterBill.BillActive=1
      AND
      (
          CAST(ISNULL(waterBill.PRICE,0)+ISNULL(waterBill.PRICETAX,0) AS decimal(18,2))
              <>CAST(ISNULL(waterBill.TotalPrice,0) AS decimal(18,2))
          OR CAST(ISNULL(waterBill.PRICE,0) AS decimal(18,2))
              <>CAST(ROUND(ISNULL(waterBill.TotalPrice,0)/CAST(1.15 AS decimal(18,4)),2) AS decimal(18,2))
          OR CAST(ISNULL(waterBill.PRICETAX,0) AS decimal(18,2))
              <>CAST
                (
                    ISNULL(waterBill.TotalPrice,0)
                    -ROUND(ISNULL(waterBill.TotalPrice,0)/CAST(1.15 AS decimal(18,4)),2)
                    AS decimal(18,2)
                )
      );

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Generated bills',N'No migrated rent/water bills in cutover month',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'The historical monthly migration must not generate rent/water bills in the cutover month. Operational invoices are excluded.'
    FROM Housing.Bills
    /* Only bills stamped by the historical monthly migration are in scope;
       operational rent/water bills issued during the cutover month are valid. */
    WHERE BillChargeTypeID_FK IN (1,3)
      AND idaraID_FK=@IdaraId
      AND PeriodYear=YEAR(@ValidationCutoverDate)
      AND PeriodMonth=MONTH(@ValidationCutoverDate)
      AND BillActive=1
      AND (hostName = N'Data Migration' OR hostName LIKE N'Data Migration-%');

    /* New-system billing-period and fixed-service contract. */
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Billing periods',N'Water bills without current billing period',0,COUNT_BIG(*),COUNT_BIG(*),CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,N'Every migrated water bill must link to its generated monthly water period.'
    FROM Housing.Bills
    WHERE BillChargeTypeID_FK=3 AND idaraID_FK=@IdaraId AND BillActive=1
      AND BillsFromDate IS NOT NULL AND BillsToDate <= @HistoricalBillMonthEnd
      AND CurrentPeriodID IS NULL;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Billing periods',N'Water bills linked to incorrect billing period',0,COUNT_BIG(*),COUNT_BIG(*),CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,N'The current period must belong to the same administration, water service, and cover the bill dates.'
    FROM Housing.Bills b
    LEFT JOIN Housing.BillPeriod bp ON bp.billPeriodID=b.CurrentPeriodID
    LEFT JOIN Housing.BillPeriodType bpt ON bpt.billPeriodTypeID=bp.billPeriodTypeID_FK
    WHERE b.BillChargeTypeID_FK=3 AND b.idaraID_FK=@IdaraId AND b.BillActive=1
      AND b.BillsFromDate IS NOT NULL AND b.BillsToDate <= @HistoricalBillMonthEnd
      AND (bp.billPeriodID IS NULL OR bp.IdaraId_FK<>@IdaraId OR bpt.meterServiceTypeID_FK<>2 OR CAST(bp.billPeriodStartDate AS date)>CAST(b.BillsFromDate AS date) OR CAST(bp.billPeriodEndDate AS date)<CAST(b.BillsToDate AS date));

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Billing periods',N'Water bills missing an available previous period',0,COUNT_BIG(*),COUNT_BIG(*),CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,N'PreviousPeriodID is required when an earlier water period exists.'
    FROM Housing.Bills b
    JOIN Housing.BillPeriod currentPeriod ON currentPeriod.billPeriodID=b.CurrentPeriodID
    WHERE b.BillChargeTypeID_FK=3 AND b.idaraID_FK=@IdaraId AND b.BillActive=1 AND b.PerviosPeriodID IS NULL
      AND EXISTS(SELECT 1 FROM Housing.BillPeriod previousPeriod JOIN Housing.BillPeriodType previousType ON previousType.billPeriodTypeID=previousPeriod.billPeriodTypeID_FK WHERE previousPeriod.IdaraId_FK=@IdaraId AND previousType.meterServiceTypeID_FK=2 AND previousPeriod.billPeriodStartDate<currentPeriod.billPeriodStartDate);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Bills',N'Water bills missing available building utility type',0,COUNT_BIG(*),COUNT_BIG(*),CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,N'Water bills must copy buildingUtilityTypeID_FK from BuildingDetails when it is available.'
    FROM Housing.Bills b JOIN Housing.BuildingDetails building ON building.buildingDetailsID=b.buildingDetailsID
    WHERE b.BillChargeTypeID_FK=3 AND b.idaraID_FK=@IdaraId AND b.BillActive=1 AND building.buildingUtilityTypeID_FK IS NOT NULL AND b.buildingUtilityTypeID IS NULL;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Fixed services',N'Missing or mismatched active water fixed amount',0,COUNT_BIG(*),COUNT_BIG(*),CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,N'Water fixed amount is stored net of 15 percent VAT and must reconcile to WaterMonthlyAmount.'
    FROM (SELECT 1 RequiredRow) required
    WHERE NOT EXISTS(SELECT 1 FROM Housing.MeterServiceTypeFixedAmount amount WHERE amount.MeterServiceTypeID_FK=2 AND amount.idaraID_FK=@IdaraId AND amount.MeterServiceTypeFixedAmountActive=1 AND amount.FixedAmount=CAST(ROUND(@WaterMonthlyAmount/CAST(1.15 AS decimal(18,4)),2) AS decimal(18,2)));

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Billing periods',N'Electric bills missing an available previous period',0,COUNT_BIG(*),COUNT_BIG(*),CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,N'An electricity bill requires PreviousPeriodID when the same meter has an earlier migrated bill.'
    FROM Housing.Bills b
    JOIN Housing.BillPeriod currentPeriod ON currentPeriod.billPeriodID=b.CurrentPeriodID
    WHERE b.BillChargeTypeID_FK=2 AND b.idaraID_FK=@IdaraId AND b.BillActive=1 AND b.meterID IS NOT NULL AND b.PerviosPeriodID IS NULL
      AND EXISTS(SELECT 1 FROM Housing.Bills previousBill JOIN Housing.BillPeriod previousPeriod ON previousPeriod.billPeriodID=previousBill.CurrentPeriodID WHERE previousBill.BillChargeTypeID_FK=2 AND previousBill.idaraID_FK=@IdaraId AND previousBill.BillActive=1 AND previousBill.meterID=b.meterID AND previousBill.BillsID<>b.BillsID AND previousPeriod.billPeriodStartDate<currentPeriod.billPeriodStartDate);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Billing periods',N'Electric bills linked to invalid previous period',0,COUNT_BIG(*),COUNT_BIG(*),CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,N'Previous electricity period must belong to the same administration and service and precede the current period.'
    FROM Housing.Bills b
    JOIN Housing.BillPeriod currentPeriod ON currentPeriod.billPeriodID=b.CurrentPeriodID
    LEFT JOIN Housing.BillPeriod previousPeriod ON previousPeriod.billPeriodID=b.PerviosPeriodID
    LEFT JOIN Housing.BillPeriodType previousType ON previousType.billPeriodTypeID=previousPeriod.billPeriodTypeID_FK
    WHERE b.BillChargeTypeID_FK=2 AND b.idaraID_FK=@IdaraId AND b.BillActive=1 AND b.PerviosPeriodID IS NOT NULL
      /* Electricity migration preserves the source BillsID. Do not treat
         newly issued occupancy/exit meter-read bills as migrated bills. */
      AND EXISTS
      (
          SELECT 1
          FROM KFMC.Housing.Bills sourceBill
          WHERE CONVERT(bigint, sourceBill.BillsID) = b.BillsID
      )
      AND (previousPeriod.billPeriodID IS NULL OR previousPeriod.IdaraId_FK<>@IdaraId OR previousType.meterServiceTypeID_FK<>1 OR previousPeriod.billPeriodStartDate>=currentPeriod.billPeriodStartDate);
    /* Broken relationships and business invariants. Expected value is zero. */
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Integrity',N'ResidentDetails without ResidentInfo',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,NULL
    FROM Housing.ResidentDetails d LEFT JOIN Housing.ResidentInfo r
      ON r.residentInfoID=d.residentInfoID_FK WHERE r.residentInfoID IS NULL;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Integrity',N'ResidentDetails without MilitaryUnit',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,NULL
    FROM Housing.ResidentDetails d LEFT JOIN dbo.MilitaryUnit u
      ON u.militaryUnitID=d.militaryUnitID_FK
    WHERE d.militaryUnitID_FK IS NOT NULL AND u.militaryUnitID IS NULL;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Integrity',N'Resident contacts without resident',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,NULL
    FROM Housing.ResidentContactInfo c LEFT JOIN Housing.ResidentInfo r
      ON r.residentInfoID=c.residentInfoID_FK WHERE r.residentInfoID IS NULL;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Integrity',N'Extend insurance without action or resident',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,NULL
    FROM Housing.ExtendInsurance insurance
    LEFT JOIN Housing.BuildingAction actionRow
      ON actionRow.buildingActionID=insurance.buildingActionID_FK
    LEFT JOIN Housing.ResidentInfo resident
      ON resident.residentInfoID=insurance.residentInfoID_FK
    WHERE insurance.IdaraId_FK=@IdaraId
      AND (actionRow.buildingActionID IS NULL OR resident.residentInfoID IS NULL);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Business rules',N'Active housing actions missing OccupentDate',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,NULL
    FROM Housing.BuildingAction
    WHERE buildingActionTypeID_FK=2 AND buildingActionActive=1 AND OccupentDate IS NULL;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Business rules',N'Active exit actions missing dates',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,NULL
    FROM Housing.BuildingAction
    WHERE buildingActionTypeID_FK=3 AND buildingActionActive=1
      AND (OccupentDate IS NULL OR ExitDate IS NULL);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Business rules',N'Exit date earlier than occupancy date',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,NULL
    FROM Housing.BuildingAction WHERE buildingActionTypeID_FK=3 AND OccupentDate>ExitDate;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Bills',N'Bills without BillNumber',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,NULL
    FROM Housing.Bills WHERE NULLIF(LTRIM(RTRIM(BillNumber)),N'') IS NULL;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Bills',N'Duplicate BillNumber values',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,N'Actual is the number of duplicated bill-number groups.'
    FROM (SELECT BillNumber FROM Housing.Bills GROUP BY BillNumber HAVING COUNT_BIG(*)>1) d;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Payments',N'Active payments without link status',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,NULL
    FROM Housing.BuildingPayment
    WHERE buildingPayementActive=1 AND buildingPaymentLinkStatusID_FK IS NULL;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Payments',N'Status-1 payments missing resident or building',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,NULL
    FROM Housing.BuildingPayment
    WHERE buildingPayementActive=1 AND buildingPaymentLinkStatusID_FK=1
      AND (residentInfoID_FK IS NULL OR NULLIF(LTRIM(RTRIM(buildingDetailsID_FK)),N'') IS NULL);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Entry metadata',N'Migration-generated text in entryData',0,SUM(x.BadCount),SUM(x.BadCount),
           CASE WHEN SUM(x.BadCount)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Values originating in KFMC are preserved exactly; migration literals are forbidden.'
    FROM
    (
        SELECT COUNT_BIG(*) BadCount FROM Housing.Bills WHERE entryData LIKE N'MIGRATION%'
        UNION ALL SELECT COUNT_BIG(*) FROM Housing.BuildingPayment WHERE entryData LIKE N'MIGRATION%'
        UNION ALL SELECT COUNT_BIG(*) FROM Housing.DeductList WHERE entryData LIKE N'MIGRATION%'
    ) x;

    /* Known historical gaps are warnings, not migration failures. */
    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Historical warnings',N'Meter reads without resident',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'WARN' END,N'Preserved historical data.'
    FROM Housing.MeterRead WHERE residentInfoID_FK IS NULL AND generalNo_FK IS NOT NULL;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Historical warnings',N'Meter reads without building',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'WARN' END,N'Preserved historical data.'
    FROM Housing.MeterRead
    WHERE buildingDetailsID IS NULL AND NULLIF(LTRIM(RTRIM(buildingDetailsNo)),N'') IS NOT NULL;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'Historical warnings',N'Unexpected building actions with unmatched building',0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'WARN' END,
           N'Known building-workflow types 4,5,8-17,29-31 are accepted and excluded.'
    FROM Housing.BuildingAction
    WHERE buildingDetailsID_FK IS NULL
      AND generalNo_FK IS NULL
      AND NULLIF(LTRIM(RTRIM(buildingDetailsNo)),N'') IS NOT NULL
      AND (buildingActionTypeID_FK IS NULL
           OR buildingActionTypeID_FK NOT IN (4,5,8,9,10,11,12,13,14,15,16,17,29,30,31));


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


    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'BuildingOperational62',N'Missing generated 62 for eligible active building',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Expected from the post-migration building exit state (not from raw KFMC action counts).'
    FROM #V62Expected e
    WHERE NOT EXISTS
    (SELECT 1 FROM #V62Actual a
     WHERE a.BuildingID=e.BuildingID AND a.IdaraID=e.IdaraID AND a.IsActive=1);

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'BuildingOperational62',N'Duplicate generated 62 per building',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'One active generated 62 at most per building and Idara.'
    FROM (SELECT BuildingID,IdaraID
          FROM #V62Actual WHERE IsActive=1
          GROUP BY BuildingID,IdaraID HAVING COUNT_BIG(*)>1) dup;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'BuildingOperational62',N'Invalid generated 62 independent-root structure',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'62 must be active, vacant (status 2), without resident, general number or parent.'
    FROM #V62Actual a
    WHERE a.IsActive<>1 OR a.IsActive IS NULL
       OR a.StatusID<>2 OR a.StatusID IS NULL
       OR a.ResidentID IS NOT NULL OR a.GeneralNo IS NOT NULL
       OR a.ParentID IS NOT NULL OR a.BuildingID IS NULL;

    INSERT @Checks(Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes)
    SELECT N'BuildingOperational62',N'Generated 62 on building not eligible for post-migration vacancy',
           0,COUNT_BIG(*),COUNT_BIG(*),
           CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           N'Generated 62 has no corresponding eligible final exit state; review any later occupancy or operational cycle.'
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

    /* Overall result first. */
    SELECT
        CASE WHEN EXISTS(SELECT 1 FROM @Checks WHERE Result='FAIL') THEN 'FAIL'
             WHEN EXISTS(SELECT 1 FROM @Checks WHERE Result='WARN') THEN 'PASS_WITH_WARNINGS'
             ELSE 'PASS' END OverallResult,
        SUM(CASE WHEN Result='PASS' THEN 1 ELSE 0 END) PassedChecks,
        SUM(CASE WHEN Result='WARN' THEN 1 ELSE 0 END) WarningChecks,
        SUM(CASE WHEN Result='FAIL' THEN 1 ELSE 0 END) FailedChecks,
        GETDATE() ValidationDate
    FROM @Checks;

    SELECT Category,CheckName,ExpectedValue,ActualValue,Difference,Result,Notes
    FROM @Checks
    ORDER BY CASE Result WHEN 'FAIL' THEN 1 WHEN 'WARN' THEN 2 ELSE 3 END,CheckOrder;

    /* Financial reconciliation used by the new calculation. */
    SELECT chargeType.BillChargeTypeID,chargeType.BillChargeTypeName_A,
           ISNULL(b.TotalBills,0) TotalBills,ISNULL(p.TotalPayments,0) LinkedPayments,
           ISNULL(b.TotalBills,0)-ISNULL(p.TotalPayments,0) Remaining
    FROM Housing.BillChargeType chargeType
    LEFT JOIN
    (
        SELECT BillChargeTypeID_FK,SUM(TotalPrice) TotalBills
        FROM Housing.Bills WHERE BillActive=1 AND idaraID_FK=@IdaraId
        GROUP BY BillChargeTypeID_FK
    ) b ON b.BillChargeTypeID_FK=chargeType.BillChargeTypeID
    LEFT JOIN
    (
        SELECT bp.BillChargeTypeID_FK,SUM(bp.amount) TotalPayments
        FROM Housing.BuildingPayment bp JOIN Housing.DeductList dl
          ON dl.deductListID=bp.deductListID_FK
        WHERE bp.buildingPayementActive=1 AND dl.deductActive=1
          AND bp.buildingPaymentLinkStatusID_FK=1 AND bp.IdaraId_FK=@IdaraId
        GROUP BY bp.BillChargeTypeID_FK
    ) p ON p.BillChargeTypeID_FK=chargeType.BillChargeTypeID
    WHERE chargeType.BillChargeTypeID IN(1,2,3,5)
    ORDER BY chargeType.BillChargeTypeID;

    /* Preserved but not necessarily counted payment balances. */
    SELECT bp.BillChargeTypeID_FK,ct.BillChargeTypeName_A,
           bp.buildingPaymentLinkStatusID_FK,ls.buildingPaymentLinkStatusName_A,
           COUNT_BIG(*) PaymentCount,SUM(bp.amount) PaymentTotal
    FROM Housing.BuildingPayment bp
    LEFT JOIN Housing.BillChargeType ct ON ct.BillChargeTypeID=bp.BillChargeTypeID_FK
    LEFT JOIN Housing.BuildingPaymentLinkStatus ls
      ON ls.buildingPaymentLinkStatusID=bp.buildingPaymentLinkStatusID_FK
    WHERE bp.buildingPayementActive=1 AND bp.IdaraId_FK=@IdaraId
    GROUP BY bp.BillChargeTypeID_FK,ct.BillChargeTypeName_A,
             bp.buildingPaymentLinkStatusID_FK,ls.buildingPaymentLinkStatusName_A
    ORDER BY bp.BillChargeTypeID_FK,bp.buildingPaymentLinkStatusID_FK;

    /* Detailed reconciliation of every old evacuation workflow stage. */
    ;WITH EvacuationStages AS
    (
        SELECT *
        FROM (VALUES
            (0,CONVERT(int,NULL),N'إخلاء نهائي قديم قبل استحداث الفلاج',3),
            (1,1,N'إرسال طلب قراءة العدادات',59),
            (2,2,N'مرسل للتدقيق المالي - مرحلة 2',57),
            (3,3,N'مرسل للتدقيق المالي - مرحلة 3',57),
            (4,4,N'انتهى التدقيق المالي',58),
            (5,5,N'اكتمل الإخلاء نهائيا',3)
        ) stage(StageOrder,OldExtraInt1,StageName,ExpectedTargetActionTypeID)
    )
    SELECT
        stage.OldExtraInt1,
        stage.StageName,
        stage.ExpectedTargetActionTypeID,
        COUNT_BIG(sourceAction.buildingActionID) SourceActionCount,
        SUM(CASE WHEN targetAction.buildingActionID IS NOT NULL THEN 1 ELSE 0 END) TargetActionCount,
        SUM(CASE WHEN sourceAction.buildingActionID IS NOT NULL
                      AND targetAction.buildingActionID IS NULL THEN 1 ELSE 0 END) MissingActionCount,
        SUM(CASE WHEN targetAction.buildingActionID IS NOT NULL
                      AND targetAction.buildingActionTypeID_FK<>
                          stage.ExpectedTargetActionTypeID THEN 1 ELSE 0 END) WrongTargetTypeCount
    FROM EvacuationStages stage
    LEFT JOIN KFMC.Housing.BuildingAction sourceAction
      ON sourceAction.buildingActionTypeID_FK=3
     AND (sourceAction.buildingActionExtraInt1=stage.OldExtraInt1
          OR (sourceAction.buildingActionExtraInt1 IS NULL AND stage.OldExtraInt1 IS NULL))
     AND NOT EXISTS
     (
         SELECT 1 FROM #ValidationDuplicateActionMap duplicateAction
         WHERE duplicateAction.duplicateActionID=sourceAction.buildingActionID
     )
    LEFT JOIN Housing.BuildingAction targetAction
      ON targetAction.buildingActionID=CONVERT(bigint,sourceAction.buildingActionID)
    GROUP BY stage.StageOrder,stage.OldExtraInt1,stage.StageName,
             stage.ExpectedTargetActionTypeID
    ORDER BY stage.StageOrder;

    /* entryData values that could not be resolved to dbo.Users.usersID. */
    CREATE TABLE #UnmatchedEntryDataStats
    (
        TableName nvarchar(300) NOT NULL,
        entryData nvarchar(4000) NOT NULL,
        RowCount_ bigint NOT NULL
    );

    DECLARE @EntryDataTables TABLE
    (
        SchemaName sysname NOT NULL,
        TableName sysname NOT NULL
    );

    INSERT @EntryDataTables(SchemaName,TableName)
    VALUES
        (N'dbo',N'Users'),
        (N'dbo',N'UsersDetails'),
        (N'dbo',N'UsersPassword'),
        (N'dbo',N'MilitaryUnit'),
        (N'Housing',N'ResidentInfo'),
        (N'Housing',N'ResidentDetails'),
        (N'Housing',N'ResidentContactInfo'),
        (N'Housing',N'MilitaryLocation'),
        (N'Housing',N'BuildingDetails'),
        (N'Housing',N'BuildingRent'),
        (N'Housing',N'MeterType'),
        (N'Housing',N'MeterServicePrice'),
        (N'Housing',N'BillPeriod'),
        (N'Housing',N'Meter'),
        (N'Housing',N'MeterForBuilding'),
        (N'Housing',N'MeterRead'),
        (N'Housing',N'BuildingAction'),
        (N'Housing',N'BuildingAssign'),
        (N'Housing',N'ExtendInsurance'),
        (N'Housing',N'Bills'),
        (N'Housing',N'DeductList'),
        (N'Housing',N'BuildingPayment'),
        (N'Housing',N'BillDeductList'),
        (N'Housing',N'BillDeductAction'),
        (N'Housing',N'BillsDeductListDetails');

    DECLARE @EntryDataSchema sysname,
            @EntryDataTable sysname,
            @EntryDataObject nvarchar(517),
            @EntryDataFullName nvarchar(300),
            @EntryDataSql nvarchar(max);

    DECLARE EntryDataCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT SchemaName, TableName
        FROM @EntryDataTables
        ORDER BY SchemaName, TableName;

    OPEN EntryDataCursor;
    FETCH NEXT FROM EntryDataCursor INTO @EntryDataSchema, @EntryDataTable;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EntryDataObject = QUOTENAME(@EntryDataSchema) + N'.' + QUOTENAME(@EntryDataTable);
        SET @EntryDataFullName = @EntryDataSchema + N'.' + @EntryDataTable;

        IF OBJECT_ID(@EntryDataObject) IS NOT NULL
           AND COL_LENGTH(@EntryDataObject, 'entryData') IS NOT NULL
        BEGIN
            SET @EntryDataSql = N'
                INSERT INTO #UnmatchedEntryDataStats(TableName, entryData, RowCount_)
                SELECT
                    @FullName,
                    CONVERT(nvarchar(4000), sourceRow.entryData),
                    COUNT_BIG(*)
                FROM ' + @EntryDataObject + N' sourceRow
                WHERE NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(4000), sourceRow.entryData))), N'''') IS NOT NULL
                  AND NOT EXISTS
                  (
                      SELECT 1
                      FROM dbo.Users userRow
                      WHERE userRow.usersID =
                            TRY_CONVERT(bigint, CONVERT(nvarchar(4000), sourceRow.entryData))
                  )
                GROUP BY CONVERT(nvarchar(4000), sourceRow.entryData);';

            EXEC sys.sp_executesql
                @EntryDataSql,
                N'@FullName nvarchar(300)',
                @FullName = @EntryDataFullName;
        END

        FETCH NEXT FROM EntryDataCursor INTO @EntryDataSchema, @EntryDataTable;
    END

    CLOSE EntryDataCursor;
    DEALLOCATE EntryDataCursor;

    SELECT TableName, entryData, RowCount_
    FROM #UnmatchedEntryDataStats
    ORDER BY TableName, RowCount_ DESC, entryData;

    /* Diagnostic sets appended last: existing result-set order is preserved. */
    SELECT GeneralNo,WaitingClassID,ActiveRequests,ActionIDs
    FROM #ValidationWaitingRootDuplicates
    ORDER BY GeneralNo,WaitingClassID;

    SELECT DISTINCT
        GeneralNo,WaitingClassID,RootActionID,
        ActionID AS ActiveDescendantID,Depth
    FROM #ValidationInactiveWaitingTree
    WHERE Depth>0 AND IsActive=1
    ORDER BY GeneralNo,WaitingClassID,RootActionID,Depth,ActiveDescendantID;

    SELECT DISTINCT
        t.GeneralNo,t.WaitingClassID,t.RootActionID,
        t.ActionID AS Depth100ActionID
    FROM #ValidationInactiveWaitingTree t
    WHERE t.Depth=100
      AND EXISTS
      (
          SELECT 1
          FROM KFMC.Housing.BuildingAction nextAction
          WHERE nextAction.buildingActionParentID=t.ActionID
      )
    ORDER BY t.GeneralNo,t.WaitingClassID,t.RootActionID,Depth100ActionID;
END;
