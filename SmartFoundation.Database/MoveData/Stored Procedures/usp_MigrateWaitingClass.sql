
CREATE   PROCEDURE MoveData.usp_MigrateWaitingClass
    @IdaraId bigint = 1,
    @RollbackAfterTest bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @IdaraId IS NULL OR @IdaraId <> 1
        THROW 51001, N'الترحيل الحالي مخصص للإدارة 1 فقط', 1;

    -- Validate frozen source classes 1-11.
    IF EXISTS
    (
        SELECT 1
        FROM
        (
            VALUES (1),(2),(3),(4),(5),(6),
                   (7),(8),(9),(10),(11)
        ) v(ID)
        LEFT JOIN KFMC.Housing.WaitingClass s
            ON s.waitingClassID = v.ID
        WHERE s.waitingClassID IS NULL
    )
        THROW 51002, N'توجد قوائم تاريخية مفقودة في KFMC', 1;

    DECLARE @IdentityOn bit = 0;
    DECLARE @Inserted int = 0;
    DECLARE @Deleted int = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Protect references before cleaning test data.
        IF EXISTS
        (
            SELECT 1
            FROM Housing.BuildingAction
            WHERE buildingActionExtraType1 IN (12,13,14,15)
        )
        OR EXISTS
        (
            SELECT 1
            FROM Housing.AssignPeriod
            WHERE WaitingClassID_FK IN (12,13,14,15)
        )
            THROW 51003, N'توجد مراجع على القوائم التجريبية؛ تم إيقاف العملية', 1;

        -- Preserve original historical IDs.
        SET IDENTITY_INSERT Housing.WaitingClass ON;
        SET @IdentityOn = 1;

        INSERT INTO Housing.WaitingClass
        (
            waitingClassID,
            waitingClassName_A,
            waitingClassName_E,
            waitingClassSequence,
            waitingClassRoot,
            waitingClassActive,
            idara_FK
        )
        SELECT
            s.waitingClassID,
            s.waitingClassName_A,
            s.waitingClassName_E,
            CASE
                WHEN s.waitingClassID BETWEEN 1 AND 4
                    THEN s.waitingClassID + 1
                ELSE s.waitingClassSequence
            END,
            s.waitingClassRoot,
            1,
            CASE
                WHEN s.waitingClassID <= 4 THEN NULL
                ELSE @IdaraId
            END
        FROM KFMC.Housing.WaitingClass s
        WHERE s.waitingClassID BETWEEN 1 AND 11
          AND NOT EXISTS
          (
              SELECT 1
              FROM Housing.WaitingClass t
              WHERE t.waitingClassID = s.waitingClassID
          );

        SET @Inserted = @@ROWCOUNT;

        IF NOT EXISTS
        (
            SELECT 1 FROM Housing.WaitingClass
            WHERE waitingClassID = 12
        )
        BEGIN
            INSERT INTO Housing.WaitingClass
            (
                waitingClassID,
                waitingClassName_A,
                waitingClassSequence,
                waitingClassActive,
                idara_FK
            )
            VALUES (12, N'القادة', 1, 1, NULL);

            SET @Inserted = @Inserted + 1;
        END;

        SET IDENTITY_INSERT Housing.WaitingClass OFF;
        SET @IdentityOn = 0;

        -- Synchronize historical classes without rebuilding table.
        UPDATE t
        SET
            t.waitingClassName_A = s.waitingClassName_A,
            t.waitingClassName_E = s.waitingClassName_E,
            t.waitingClassSequence =
                CASE WHEN s.waitingClassID <= 4
                     THEN s.waitingClassID + 1
                     ELSE s.waitingClassSequence END,
            t.waitingClassRoot = s.waitingClassRoot,
            t.waitingClassActive = 1,
            t.idara_FK =
                CASE WHEN s.waitingClassID <= 4
                     THEN NULL ELSE @IdaraId END
        FROM Housing.WaitingClass t
        JOIN KFMC.Housing.WaitingClass s
            ON s.waitingClassID = t.waitingClassID
        WHERE s.waitingClassID BETWEEN 1 AND 11;

        -- Final leaders class.
        UPDATE Housing.WaitingClass
        SET
            waitingClassName_A = N'القادة',
            waitingClassName_E = NULL,
            waitingClassSequence = 1,
            waitingClassRoot = NULL,
            waitingClassDescription = NULL,
            waitingClassActive = 1,
            idara_FK = NULL
        WHERE waitingClassID = 12;

        -- Remove confirmed test-only classes.
        DELETE FROM Housing.WaitingClass
        WHERE waitingClassID IN (13,14,15);

        SET @Deleted = @@ROWCOUNT;

        IF
        (
            SELECT COUNT(*)
            FROM Housing.WaitingClass
            WHERE waitingClassID BETWEEN 1 AND 12
        ) <> 12
            THROW 51004, N'فشل التحقق من اكتمال القوائم', 1;

        IF @RollbackAfterTest = 1
            ROLLBACK TRANSACTION;
        ELSE
            COMMIT TRANSACTION;

        SELECT
            CAST(1 AS bit) AS IsSuccessful,
            @Inserted AS InsertedClasses,
            @Deleted AS DeletedTestClasses,
            @RollbackAfterTest AS WasRolledBack;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF @IdentityOn = 1
        BEGIN
            BEGIN TRY
                SET IDENTITY_INSERT Housing.WaitingClass OFF;
            END TRY
            BEGIN CATCH
            END CATCH;
        END;

        THROW;
    END CATCH;
END;