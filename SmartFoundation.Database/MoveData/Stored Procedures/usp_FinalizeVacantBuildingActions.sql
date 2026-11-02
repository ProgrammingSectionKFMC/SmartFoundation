
CREATE   PROCEDURE [MoveData].[usp_FinalizeVacantBuildingActions]
    @IdaraId BIGINT,
    @RollbackAfterTest BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @InitialTranCount INT = @@TRANCOUNT;
    DECLARE @LockResult INT;
    DECLARE @InsertedCount BIGINT = 0;

    IF @IdaraId IS NULL
       OR NOT EXISTS
       (
           SELECT 1
           FROM dbo.Idara
           WHERE IdaraId = @IdaraId
       )
        THROW 50001, N'الإدارة المحددة غير موجودة.', 1;

    IF @InitialTranCount > 0 AND @RollbackAfterTest = 1
        THROW 50001,
            N'لا يمكن اختبار التراجع داخل معاملة خارجية؛ استخدم RollbackAfterTest=0 ضمن MigrateAll.',
            1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.BuildingActionType
        WHERE buildingActionTypeID = 62
          AND buildingActionTypeActive = 1
          AND IsResident = 0
          AND buildingStatusID_FK = 2
    )
        THROW 50001,
            N'تعريف الإجراء التشغيلي 62 غير متاح أو غير مطابق.',
            1;

    BEGIN TRY

        IF @InitialTranCount = 0
            BEGIN TRANSACTION;

        EXEC @LockResult = sys.sp_getapplock
            @Resource = N'MoveData.FinalizeVacantBuildingActions',
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 10000;

        IF @LockResult < 0
            THROW 50001,
                N'توجد معالجة أخرى لحالات المنازل؛ تعذر المتابعة.',
                1;

        ;WITH RankedActions AS
        (
            SELECT
                a.buildingActionID,
                a.buildingDetailsID_FK,
                a.IdaraId_FK,
                a.residentInfoID_FK,
                a.buildingActionTypeID_FK,
                a.ExitDate,
                a.buildingActionDate,
                a.entryDate,
                ROW_NUMBER() OVER
                (
                    PARTITION BY
                        a.buildingDetailsID_FK,
                        a.IdaraId_FK
                    ORDER BY
                        a.entryDate DESC,
                        a.buildingActionID DESC
                ) AS rn
            FROM Housing.BuildingAction a
            WHERE a.IdaraId_FK = @IdaraId
              AND a.buildingDetailsID_FK IS NOT NULL
              AND a.buildingActionActive = 1

              -- Unknown historical actions are retained,
              -- but do not determine the operational state.
              AND a.buildingActionTypeID_FK IS NOT NULL
        )
        SELECT
            r.buildingDetailsID_FK AS BuildingID,
            r.IdaraId_FK AS IdaraID,
            r.buildingActionID AS SourceExitActionID,
            r.buildingActionTypeID_FK AS SourceExitType,
            r.residentInfoID_FK AS SourceResidentID
        INTO #Candidates62
        FROM RankedActions r
        JOIN Housing.BuildingDetails b
          ON b.buildingDetailsID = r.buildingDetailsID_FK
         AND b.IdaraId_FK = r.IdaraId_FK
        WHERE r.rn = 1
          AND r.buildingActionTypeID_FK IN (57, 58, 3)
          AND r.residentInfoID_FK IS NOT NULL
          AND b.buildingDetailsActive = 1

-- Do not create 62 if a valid independent operational
-- cycle has already started after financial stage 57.
AND NOT EXISTS
(
    SELECT 1
    FROM Housing.BuildingAction operatingRoot
         WITH (UPDLOCK, HOLDLOCK)
    WHERE operatingRoot.buildingDetailsID_FK =
          r.buildingDetailsID_FK
      AND operatingRoot.IdaraId_FK = r.IdaraId_FK
      AND operatingRoot.buildingActionActive = 1
      AND operatingRoot.buildingActionParentID IS NULL
      AND operatingRoot.residentInfoID_FK IS NULL
      AND operatingRoot.buildingActionTypeID_FK IN (4, 5, 62)
      AND EXISTS
      (
          SELECT 1
          FROM Housing.fn_BuildingAction_ChainToRoot
               (r.buildingActionID) financialHistory
          WHERE financialHistory.buildingActionTypeID_FK = 57
            AND financialHistory.buildingActionActive = 1
            AND operatingRoot.entryDate >
                financialHistory.entryDate
      )
)

-- Additional actual-occupancy guard.
AND NOT EXISTS
(
              SELECT 1
              FROM Housing.BuildingAction occupied
              WHERE occupied.buildingDetailsID_FK =
                    r.buildingDetailsID_FK
                AND occupied.IdaraId_FK = r.IdaraId_FK
                AND occupied.buildingActionActive = 1
                AND occupied.buildingActionTypeID_FK = 2
                AND occupied.residentInfoID_FK IS NOT NULL
                AND occupied.residentInfoID_FK <>
                    r.residentInfoID_FK
                AND
(
    -- ترتيب تسجيل الحركات
    occupied.entryDate > r.entryDate

    OR

    -- مقارنة التسكين بتاريخ الإخلاء الفعلي
    (
        COALESCE
        (
            TRY_CONVERT(DATETIME2(3), occupied.OccupentDate),
            TRY_CONVERT(DATETIME2(3), occupied.buildingActionDate)
        )
        >
        (
            SELECT MAX
            (
                COALESCE
                (
                    TRY_CONVERT(DATETIME2(3), exitAction.ExitDate),
                    TRY_CONVERT(DATETIME2(3), exitAction.buildingActionDate)
                )
            )
            FROM Housing.BuildingAction exitAction
            WHERE exitAction.buildingDetailsID_FK =
                  r.buildingDetailsID_FK
              AND exitAction.IdaraId_FK = r.IdaraId_FK
              AND exitAction.residentInfoID_FK =
                  r.residentInfoID_FK
              AND exitAction.buildingActionActive = 1
              AND exitAction.buildingActionTypeID_FK
                  IN (54, 57, 58, 3)
              AND exitAction.buildingActionID <=
                  r.buildingActionID
        )
    )
)
          );

        DECLARE @Created TABLE
        (
            Action62ID BIGINT NOT NULL PRIMARY KEY,
            BuildingID BIGINT NOT NULL
        );

        INSERT INTO Housing.BuildingAction
        (
            buildingActionTypeID_FK,
            buildingStatusID_FK,
            residentInfoID_FK,
            generalNo_FK,
            buildingDetailsID_FK,
            buildingDetailsNo,
            buildingActionDate,
            buildingActionNote,
            buildingActionExtraText4,
            buildingActionExtraText5,
            buildingActionActive,
            buildingActionParentID,
            IdaraId_FK,
            entryDate,
            entryData,
            hostName
        )
        OUTPUT
            inserted.buildingActionID,
            inserted.buildingDetailsID_FK
        INTO @Created(Action62ID, BuildingID)
        SELECT
            62,
            2,
            NULL,
            NULL,
            c.BuildingID,
            b.buildingDetailsNo,
            GETDATE(),
            CONCAT
            (
                N'إتاحة تشغيلية بعد إخلاء تاريخي. ',
                N'الإجراء المرجعي: ',
                c.SourceExitActionID
            ),
            N'MoveData:FinalizeVacant62',
            N'MIGRATION_GENERATED',
            1,
            NULL,
            c.IdaraID,
            GETDATE(),
            N'MoveData',
            HOST_NAME()
        FROM #Candidates62 c
        JOIN Housing.BuildingDetails b
          ON b.buildingDetailsID = c.BuildingID
         AND b.IdaraId_FK = c.IdaraID;

        SET @InsertedCount = @@ROWCOUNT;

        INSERT INTO dbo.AuditLog
        (
            TableName,
            ActionType,
            RecordID,
            PerformedBy,
            Notes
        )
        SELECT
            N'[Housing].[BuildingAction]',
            N'MIGRATEHOUSEOPERATIONAL62',
            created.Action62ID,
            N'MoveData',
            CONCAT
            (
                N'{"action62ID":',
                created.Action62ID,
                N',"buildingDetailsID":',
                c.BuildingID,
                N',"sourceExitActionID":',
                c.SourceExitActionID,
                N',"sourceExitType":',
                c.SourceExitType,
                N',"sourceResidentID":',
                c.SourceResidentID,
                N'}'
            )
        FROM @Created created
        JOIN #Candidates62 c
          ON c.BuildingID = created.BuildingID;

        SELECT
            @RollbackAfterTest AS RollbackAfterTest,
            @InsertedCount AS Actions62Created,
            COUNT_BIG(*) AS CandidatesVerified
        FROM #Candidates62;

        SELECT
            created.Action62ID,
            c.BuildingID,
            b.buildingDetailsNo,
            c.SourceExitActionID,
            c.SourceExitType,
            c.SourceResidentID
        FROM @Created created
        JOIN #Candidates62 c
          ON c.BuildingID = created.BuildingID
        JOIN Housing.BuildingDetails b
          ON b.buildingDetailsID = c.BuildingID
        ORDER BY c.BuildingID;

        IF @InitialTranCount = 0
        BEGIN
            IF @RollbackAfterTest = 1
                ROLLBACK TRANSACTION;
            ELSE
                COMMIT TRANSACTION;
        END;

    END TRY
    BEGIN CATCH

        IF @InitialTranCount = 0
           AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;