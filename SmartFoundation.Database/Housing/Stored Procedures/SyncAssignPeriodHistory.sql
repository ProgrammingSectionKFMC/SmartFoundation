CREATE   PROCEDURE Housing.SyncAssignPeriodHistory
    @AssignPeriodID BIGINT,
    @ApplyChanges BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;
    DECLARE @IdaraID INT;
    DECLARE @Origin NVARCHAR(30);
    DECLARE @LockResult INT;
    DECLARE @PeriodsChecked INT = 0;

    BEGIN TRY
        IF @AssignPeriodID IS NULL OR @AssignPeriodID <= 0
            THROW 51201, N'رقم محضر التخصيص غير صالح.', 1;
        IF OBJECT_ID(N'Housing.AssignPeriodMember',N'U') IS NULL
           OR OBJECT_ID(N'Housing.AssignPeriodAllocation',N'U') IS NULL
            THROW 51202, N'جداول السجل التاريخي غير موجودة.', 1;

        IF @ApplyChanges = 1
        BEGIN
            IF @tc = 0 BEGIN TRANSACTION;
            EXEC @LockResult = sys.sp_getapplock
                @Resource = N'Housing.AssignPeriodHistory',
                @LockMode = N'Exclusive',
                @LockOwner = N'Transaction',
                @LockTimeout = 10000;
            IF @LockResult < 0
                THROW 51203, N'تعذر الحصول على قفل مزامنة سجل المحاضر.', 1;

            SELECT @IdaraID = p.IdaraId_FK,
                   @Origin = CASE WHEN p.AssignPeriodDescrption LIKE N'Legacy allocation migration - WaitingClass %'
                           THEN N'LEGACY_RECONSTRUCTED' ELSE N'OPERATIONAL' END
            FROM Housing.AssignPeriod p WITH (UPDLOCK, HOLDLOCK)
            WHERE p.AssignPeriodID = @AssignPeriodID;
        END
        ELSE
        BEGIN
            SELECT @IdaraID = p.IdaraId_FK,
                   @Origin = CASE WHEN p.AssignPeriodDescrption LIKE N'Legacy allocation migration - WaitingClass %'
                           THEN N'LEGACY_RECONSTRUCTED' ELSE N'OPERATIONAL' END
            FROM Housing.AssignPeriod p
            WHERE p.AssignPeriodID = @AssignPeriodID;
        END;

        IF @IdaraID IS NULL
            THROW 51204, N'المحضر غير موجود أو لا يتبع لإدارة محددة.', 1;
        IF @ApplyChanges = 1 AND @Origin = N'LEGACY_RECONSTRUCTED'
            THROW 51205, N'لا يُعاد بناء المحاضر التاريخية المرحلة بهذا الإجراء التشغيلي.', 1;

        SELECT a.buildingActionID, a.buildingActionParentID,
               a.buildingActionTypeID_FK, a.AssignPeriodID_FK,
               a.InAssignPeriod, a.residentInfoID_FK, a.IdaraId_FK,
               a.buildingDetailsID_FK, a.buildingDetailsNo,
               a.buildingActionActive, a.entryDate
        INTO #H3Actions
        FROM Housing.BuildingAction a
        WHERE a.AssignPeriodID_FK = @AssignPeriodID;
        CREATE UNIQUE CLUSTERED INDEX IX_H3A_ID ON #H3Actions(buildingActionID);
        CREATE INDEX IX_H3A_Parent ON #H3Actions(buildingActionParentID);

        /* Resolve actual waiting-request root, not the resident's latest action. */
        ;WITH Ancestors AS
        (
            SELECT a.buildingActionID AS PeriodActionID,
                   a.buildingActionID AS AncestorID,
                   a.buildingActionParentID AS ParentID,
                   a.buildingActionTypeID_FK AS ActionType,
                   0 AS Depth,
                   CONVERT(VARCHAR(MAX), '/' + CONVERT(VARCHAR(30), a.buildingActionID) + '/') AS Visited
            FROM #H3Actions a
            UNION ALL
            SELECT c.PeriodActionID, p.buildingActionID, p.buildingActionParentID,
                   p.buildingActionTypeID_FK, c.Depth + 1,
                   CONVERT(VARCHAR(MAX), c.Visited + CONVERT(VARCHAR(30), p.buildingActionID) + '/')
            FROM Ancestors c
            JOIN Housing.BuildingAction p ON p.buildingActionID = c.ParentID
            WHERE c.Depth < 256
              AND CHARINDEX('/' + CONVERT(VARCHAR(30), p.buildingActionID) + '/',c.Visited) = 0
        ), Roots AS
        (
            SELECT PeriodActionID, AncestorID AS WaitingRootID,
                   COUNT(*) OVER (PARTITION BY PeriodActionID) AS RootMatches,
                   ROW_NUMBER() OVER (PARTITION BY PeriodActionID ORDER BY Depth DESC) AS rn
            FROM Ancestors WHERE ActionType IN (1,7,25)
        )
        SELECT PeriodActionID, WaitingRootID, RootMatches
        INTO #H3Root
        FROM Roots WHERE rn = 1
        OPTION (MAXRECURSION 0);
        CREATE UNIQUE CLUSTERED INDEX IX_H3R_ID ON #H3Root(PeriodActionID);

        IF EXISTS (SELECT 1 FROM #H3Actions a LEFT JOIN #H3Root r
                   ON r.PeriodActionID=a.buildingActionID WHERE r.PeriodActionID IS NULL)
           OR EXISTS (SELECT 1 FROM #H3Root WHERE RootMatches<>1)
           OR EXISTS (SELECT 1 FROM #H3Actions a WHERE a.IdaraId_FK IS NOT NULL AND a.IdaraId_FK<>@IdaraID)
           OR EXISTS
           (
                SELECT 1 FROM #H3Actions a
                JOIN #H3Root ar ON ar.PeriodActionID=a.buildingActionID
                JOIN Housing.BuildingAction root ON root.buildingActionID=ar.WaitingRootID
                WHERE root.residentInfoID_FK IS NULL
                   OR (a.residentInfoID_FK IS NOT NULL AND a.residentInfoID_FK<>root.residentInfoID_FK)
           )
            THROW 51206, N'تعارض في جذر سجل الانتظار أو الإدارة أو هوية المستفيد.', 1;

        ;WITH Ranked AS
        (
            SELECT ar.WaitingRootID, root.residentInfoID_FK AS ResidentID,
                   a.buildingActionID AS FirstActionID,
                   ROW_NUMBER() OVER
                   (PARTITION BY ar.WaitingRootID ORDER BY a.entryDate, a.buildingActionID) AS rn
            FROM #H3Actions a
            JOIN #H3Root ar ON ar.PeriodActionID=a.buildingActionID
            JOIN Housing.BuildingAction root ON root.buildingActionID=ar.WaitingRootID
        )
        SELECT WaitingRootID, ResidentID, FirstActionID
        INTO #H3Member
        FROM Ranked WHERE rn=1;
        CREATE UNIQUE CLUSTERED INDEX IX_H3M_Root ON #H3Member(WaitingRootID);

        /* CLOSEASSIGNPERIOD clones 38/40 as sibling (same parent) with InAssignPeriod=1. */
        SELECT a.buildingActionID AS OriginalID, b.buildingActionID AS CopyID
        INTO #H3Pairs
        FROM #H3Actions a
        JOIN #H3Actions b ON b.buildingActionID>a.buildingActionID
            AND b.buildingActionParentID=a.buildingActionParentID
            AND b.buildingActionTypeID_FK=a.buildingActionTypeID_FK
            AND b.residentInfoID_FK=a.residentInfoID_FK
            AND b.IdaraId_FK=a.IdaraId_FK
            AND (b.buildingDetailsID_FK=a.buildingDetailsID_FK OR
                 (b.buildingDetailsID_FK IS NULL AND a.buildingDetailsID_FK IS NULL
                  AND ISNULL(b.buildingDetailsNo,N'')=ISNULL(a.buildingDetailsNo,N'')))
        WHERE a.buildingActionTypeID_FK IN (38,40)
          AND (a.InAssignPeriod IS NULL OR a.InAssignPeriod<>1)
          AND b.InAssignPeriod=1;

        IF EXISTS (SELECT OriginalID FROM #H3Pairs GROUP BY OriginalID HAVING COUNT(*)>1)
          OR EXISTS (SELECT CopyID FROM #H3Pairs GROUP BY CopyID HAVING COUNT(*)>1)
            THROW 51207, N'وجدت نسخ تثبيت تخصيص غير فريدة؛ يلزم مراجعة السلسلة.', 1;

        SELECT a.buildingActionID AS AllocationID, p.CopyID AS ConfirmationID,
               a.buildingActionTypeID_FK AS AllocationType,
               a.residentInfoID_FK AS ResidentID,
               a.buildingActionActive,
               r.WaitingRootID
        INTO #H3Alloc
        FROM #H3Actions a
        JOIN #H3Root r ON r.PeriodActionID=a.buildingActionID
        LEFT JOIN #H3Pairs p ON p.OriginalID=a.buildingActionID
        WHERE a.buildingActionTypeID_FK IN (38,40)
          AND (a.InAssignPeriod IS NULL OR a.InAssignPeriod<>1)
        UNION ALL
        SELECT a.buildingActionID, CAST(NULL AS BIGINT), a.buildingActionTypeID_FK,
               a.residentInfoID_FK, a.buildingActionActive, r.WaitingRootID
        FROM #H3Actions a
        JOIN #H3Root r ON r.PeriodActionID=a.buildingActionID
        WHERE a.buildingActionTypeID_FK IN (38,40)
          AND a.InAssignPeriod=1
          AND NOT EXISTS (SELECT 1 FROM #H3Pairs p WHERE p.CopyID=a.buildingActionID);
        CREATE UNIQUE CLUSTERED INDEX IX_H3Alloc_ID ON #H3Alloc(AllocationID);

        /* 43 only resolves an offer when followed by replacement 38/40.
           44 only resolves an excluded offer when followed by 27/39.
           In incomplete transitions, fail closed and leave pending. */
        SELECT ca.AllocationID, o.buildingActionID AS OutcomeID,
               o.buildingActionTypeID_FK AS OutcomeType
        INTO #H3OutcomeCandidates
        FROM #H3Alloc ca
        JOIN Housing.BuildingAction o
          ON o.buildingActionParentID IN (ca.AllocationID, ca.ConfirmationID)
         AND o.AssignPeriodID_FK=@AssignPeriodID
         AND o.residentInfoID_FK=ca.ResidentID
         AND o.buildingActionActive=1
         AND
         (
             (ca.AllocationType=38 AND o.buildingActionTypeID_FK IN (39,41,45))
             OR (ca.AllocationType=40 AND o.buildingActionTypeID_FK IN (41,42,45))
             OR (o.buildingActionTypeID_FK=43
                 AND EXISTS (SELECT 1 FROM Housing.BuildingAction nextAction
                             WHERE nextAction.buildingActionParentID=o.buildingActionID
                               AND nextAction.buildingActionTypeID_FK=ca.AllocationType
                               AND nextAction.AssignPeriodID_FK=@AssignPeriodID
                               AND nextAction.residentInfoID_FK=ca.ResidentID
                               AND nextAction.buildingActionActive=1))
             OR (o.buildingActionTypeID_FK=44
                 AND EXISTS (SELECT 1 FROM Housing.BuildingAction nextAction
                             WHERE nextAction.buildingActionParentID=o.buildingActionID
                               AND nextAction.buildingActionTypeID_FK IN (27,39)
                               AND nextAction.residentInfoID_FK=ca.ResidentID
                               AND nextAction.buildingActionActive=1))
         );

        IF EXISTS (SELECT AllocationID FROM #H3OutcomeCandidates
                   GROUP BY AllocationID HAVING COUNT(*)>1)
            THROW 51208, N'توجد نتائج معالجة متضاربة لتخصيص واحد.', 1;

        SELECT a.AllocationID, a.ConfirmationID, a.AllocationType,
               a.ResidentID, a.WaitingRootID, o.OutcomeID,
               CASE WHEN o.OutcomeID IS NULL THEN N'PENDING' ELSE N'PROCESSED' END AS Status
        INTO #H3Draft
        FROM #H3Alloc a
        LEFT JOIN #H3OutcomeCandidates o ON o.AllocationID=a.AllocationID;

        IF EXISTS (SELECT 1 FROM #H3Alloc WHERE buildingActionActive=0)
           OR EXISTS (SELECT 1 FROM #H3Draft d JOIN #H3Member m ON m.WaitingRootID=d.WaitingRootID
                      WHERE d.ResidentID<>m.ResidentID)
            THROW 51209, N'يوجد إجراء تخصيص غير نشط أو اختلاف في المستفيد.', 1;

        /* Fail rather than silently rewrite previously established history. */
        IF EXISTS
        (
            SELECT 1 FROM Housing.AssignPeriodMember existing
            JOIN #H3Member d ON d.WaitingRootID=existing.WaitingRootActionID_FK
            WHERE existing.AssignPeriodID_FK=@AssignPeriodID
              AND (existing.ResidentInfoID_FK<>d.ResidentID OR existing.DataOrigin<>@Origin)
        )
            THROW 51210, N'عضوية تاريخية قائمة تختلف عن مصدر المحضر.', 1;
        IF EXISTS
        (
            SELECT 1 FROM Housing.AssignPeriodAllocation existing
            JOIN #H3Draft d ON d.AllocationID=existing.AllocationActionID_FK
            JOIN Housing.AssignPeriodMember m ON m.AssignPeriodMemberID=existing.AssignPeriodMemberID_FK
            WHERE m.AssignPeriodID_FK<>@AssignPeriodID
               OR m.WaitingRootActionID_FK<>d.WaitingRootID
               OR existing.AllocationTypeID<>d.AllocationType
               OR (existing.ConfirmationActionID_FK IS NOT NULL
                   AND ISNULL(d.ConfirmationID,-1)<>existing.ConfirmationActionID_FK)
               OR (existing.OutcomeActionID_FK IS NOT NULL
                   AND ISNULL(d.OutcomeID,-1)<>existing.OutcomeActionID_FK)
        )
            THROW 51211, N'رابط تخصيص محفوظ يتعارض مع حالة المصدر.', 1;

        IF @ApplyChanges=0
        BEGIN
            SELECT @AssignPeriodID AS AssignPeriodID, @Origin AS DataOrigin,
                (SELECT COUNT(*) FROM #H3Member) AS SourceMembers,
                (SELECT COUNT(*) FROM #H3Draft) AS SourceAllocations,
                (SELECT COUNT(*) FROM #H3Draft WHERE Status=N'PROCESSED') AS SourceProcessed,
                (SELECT COUNT(*) FROM #H3Draft WHERE Status=N'PENDING') AS SourcePending,
                (SELECT COUNT(*) FROM Housing.AssignPeriodMember WHERE AssignPeriodID_FK=@AssignPeriodID) AS SavedMembers,
                (SELECT COUNT(*) FROM Housing.AssignPeriodAllocation a
                  JOIN Housing.AssignPeriodMember m ON m.AssignPeriodMemberID=a.AssignPeriodMemberID_FK
                 WHERE m.AssignPeriodID_FK=@AssignPeriodID) AS SavedAllocations,
                N'PREVIEW_ONLY' AS ExecutionMode;
            RETURN;
        END;

        INSERT Housing.AssignPeriodMember
            (AssignPeriodID_FK,WaitingRootActionID_FK,ResidentInfoID_FK,FirstPeriodActionID_FK,DataOrigin)
        SELECT @AssignPeriodID,d.WaitingRootID,d.ResidentID,d.FirstActionID,@Origin
        FROM #H3Member d
        WHERE NOT EXISTS
        (SELECT 1 FROM Housing.AssignPeriodMember m
          WHERE m.AssignPeriodID_FK=@AssignPeriodID AND m.WaitingRootActionID_FK=d.WaitingRootID);

        INSERT Housing.AssignPeriodAllocation
            (AssignPeriodMemberID_FK,AllocationActionID_FK,ConfirmationActionID_FK,
             OutcomeActionID_FK,AllocationTypeID)
        SELECT m.AssignPeriodMemberID,d.AllocationID,d.ConfirmationID,d.OutcomeID,d.AllocationType
        FROM #H3Draft d
        JOIN Housing.AssignPeriodMember m ON m.AssignPeriodID_FK=@AssignPeriodID
                                         AND m.WaitingRootActionID_FK=d.WaitingRootID
        WHERE NOT EXISTS
        (SELECT 1 FROM Housing.AssignPeriodAllocation a WHERE a.AllocationActionID_FK=d.AllocationID);

        UPDATE a
        SET ConfirmationActionID_FK=COALESCE(a.ConfirmationActionID_FK,d.ConfirmationID),
            OutcomeActionID_FK=COALESCE(a.OutcomeActionID_FK,d.OutcomeID)
        FROM Housing.AssignPeriodAllocation a
        JOIN #H3Draft d ON d.AllocationID=a.AllocationActionID_FK
        JOIN Housing.AssignPeriodMember m ON m.AssignPeriodMemberID=a.AssignPeriodMemberID_FK
        WHERE m.AssignPeriodID_FK=@AssignPeriodID
          AND ((a.ConfirmationActionID_FK IS NULL AND d.ConfirmationID IS NOT NULL)
            OR (a.OutcomeActionID_FK IS NULL AND d.OutcomeID IS NOT NULL));

        /* Fail closed if saved rows differ from source after writes. */
        IF (SELECT COUNT(*) FROM Housing.AssignPeriodMember WHERE AssignPeriodID_FK=@AssignPeriodID)
             <> (SELECT COUNT(*) FROM #H3Member)
           OR (SELECT COUNT(*) FROM Housing.AssignPeriodAllocation a
                 JOIN Housing.AssignPeriodMember m ON m.AssignPeriodMemberID=a.AssignPeriodMemberID_FK
                 WHERE m.AssignPeriodID_FK=@AssignPeriodID)
             <> (SELECT COUNT(*) FROM #H3Draft)
            THROW 51212, N'فشل تطابق السجل التاريخي بعد المزامنة.', 1;

        IF @tc=0 COMMIT TRANSACTION;
        /* No result set in APPLY mode: safe inside Masters_CRUD -> INSERT EXEC page SP. */
    END TRY
    BEGIN CATCH
        IF @tc=0 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;