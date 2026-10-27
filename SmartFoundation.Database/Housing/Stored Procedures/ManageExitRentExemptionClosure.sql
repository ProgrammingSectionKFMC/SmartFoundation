
-- Internal helper: APPLY / RESTORE. Default: no resultset for central CRUD callers.
CREATE   PROCEDURE Housing.ManageExitRentExemptionClosure
      @Action NVARCHAR(10)
    , @ExitRequestActionID BIGINT
    , @ResidentInfoID BIGINT
    , @BuildingDetailsID BIGINT
    , @IdaraID BIGINT
    , @ExitDate DATE = NULL
    , @EntryData NVARCHAR(20) = NULL
    , @HostName NVARCHAR(200) = NULL
    , @ReturnResult BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @InitialTranCount INT = @@TRANCOUNT;
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(255);
    DECLARE @OriginalCycleExitDate DATE;
    DECLARE @OccupentDate DATE;

    BEGIN TRY
        IF @InitialTranCount = 0 BEGIN TRANSACTION;

        SET @Action = UPPER(LTRIM(RTRIM(@Action)));
        IF @Action NOT IN (N'APPLY', N'RESTORE') OR @Action IS NULL
            THROW 50001, N'عملية إغلاق الإعفاء غير صحيحة', 1;
        IF @ExitRequestActionID IS NULL OR @ResidentInfoID IS NULL
           OR @BuildingDetailsID IS NULL OR @IdaraID IS NULL
            THROW 50001, N'بيانات دورة الإخلاء والمستفيد والمبنى والإدارة مطلوبة', 1;
        IF @Action = N'APPLY' AND @ExitDate IS NULL
            THROW 50001, N'تاريخ الإخلاء مطلوب', 1;

        SET @LockResource = CONCAT(
              N'EXIT_EXEMPTION:', @IdaraID, N':', @ResidentInfoID, N':', @BuildingDetailsID
        );

        EXEC @LockResult = sys.sp_getapplock
              @Resource = @LockResource
            , @LockMode = N'Exclusive'
            , @LockOwner = N'Transaction'
            , @LockTimeout = 15000;
        IF @LockResult < 0
            THROW 50001, N'تعذر حجز معالجة الإعفاء للمستفيد', 1;

        SELECT
              @OriginalCycleExitDate = CONVERT(DATE, a.ExitDate)
            , @OccupentDate = CONVERT(DATE, a.OccupentDate)
        FROM Housing.ExitFinancialProcessingCycle cyc WITH (UPDLOCK, HOLDLOCK)
        JOIN Housing.BuildingAction a WITH (UPDLOCK, HOLDLOCK)
          ON a.buildingActionID = cyc.ExitRequestActionID_FK
        WHERE cyc.ExitRequestActionID_FK = @ExitRequestActionID
          AND cyc.ProcessingVersion = 1
          AND a.buildingActionTypeID_FK = 54
          AND a.buildingActionActive = 1
          AND a.residentInfoID_FK = @ResidentInfoID
          AND a.buildingDetailsID_FK = @BuildingDetailsID
          AND a.IdaraId_FK = @IdaraID;

        IF @OriginalCycleExitDate IS NULL OR @OccupentDate IS NULL
            THROW 50001, N'دورة الإخلاء الجديدة غير مسجلة أو غير متطابقة', 1;

        IF @Action = N'APPLY' AND
           (
               @ExitDate < @OccupentDate
               OR @ExitDate <> @OriginalCycleExitDate
           )
            THROW 50001, N'تاريخ الإخلاء غير مؤهل أو تغيّر شهر دورة الإخلاء', 1;

        -- Protect against changing somebody else's closure or an exemption edited externally.
        IF EXISTS
        (
            SELECT 1
            FROM Housing.ExitRentExemptionClosure c WITH (UPDLOCK, HOLDLOCK)
            LEFT JOIN Housing.ResidentRentExemption e WITH (UPDLOCK, HOLDLOCK)
              ON e.residentRentExemptionID = c.ResidentRentExemptionID_FK
            WHERE c.ExitRequestActionID_FK = @ExitRequestActionID
              AND c.RestoredAt IS NULL
              AND
              (
                  e.residentRentExemptionID IS NULL
                  OR e.residentInfoID_FK <> @ResidentInfoID
                  OR e.buildingDetailsID_FK <> @BuildingDetailsID
                  OR e.idaraID_FK <> @IdaraID
                  OR ISNULL(e.residentRentExemptionActive, 0) <> 1
                  OR e.residentRentExemptionEndDate IS NULL
                  OR e.residentRentExemptionEndDate <> c.AppliedExitEndDate
              )
        )
            THROW 50001, N'تغيّر الإعفاء بعد إغلاقه؛ يلزم تدقيق قبل الاستعادة أو التعديل', 1;

        IF @Action = N'APPLY' AND EXISTS
        (
            SELECT 1
            FROM Housing.ExitRentExemptionClosure c WITH (UPDLOCK, HOLDLOCK)
            JOIN Housing.ResidentRentExemption e
              ON e.residentRentExemptionID = c.ResidentRentExemptionID_FK
            WHERE c.RestoredAt IS NULL
              AND c.ExitRequestActionID_FK <> @ExitRequestActionID
              AND e.residentInfoID_FK = @ResidentInfoID
              AND e.buildingDetailsID_FK = @BuildingDetailsID
              AND e.idaraID_FK = @IdaraID
        )
            THROW 50001, N'يوجد إغلاق إعفاء غير مستعاد يتبع دورة إخلاء أخرى', 1;

        -- RESTORE canceled cycle OR exemption no longer eligible for truncation after a date edit.
        DECLARE @Restore TABLE
        (
            ClosureID BIGINT PRIMARY KEY,
            ExemptionID BIGINT NOT NULL,
            OriginalEndDate DATETIME NULL
        );

        INSERT INTO @Restore (ClosureID, ExemptionID, OriginalEndDate)
        SELECT c.ExitRentExemptionClosureID,
               c.ResidentRentExemptionID_FK,
               c.OriginalEndDate
        FROM Housing.ExitRentExemptionClosure c WITH (UPDLOCK, HOLDLOCK)
        JOIN Housing.ResidentRentExemption e WITH (UPDLOCK, HOLDLOCK)
          ON e.residentRentExemptionID = c.ResidentRentExemptionID_FK
        WHERE c.ExitRequestActionID_FK = @ExitRequestActionID
          AND c.RestoredAt IS NULL
          AND
          (
              @Action = N'RESTORE'
              OR CONVERT(DATE, e.residentRentExemptionStartDate) > @ExitDate
              OR (c.OriginalEndDate IS NOT NULL AND CONVERT(DATE, c.OriginalEndDate) <= @ExitDate)
          );

        UPDATE e SET e.residentRentExemptionEndDate = r.OriginalEndDate
        FROM Housing.ResidentRentExemption e
        JOIN @Restore r ON r.ExemptionID = e.residentRentExemptionID;

        UPDATE c
           SET c.RestoredAt = SYSDATETIME(),
               c.RestoredBy = @EntryData,
               c.RestoreHostName = @HostName
        FROM Housing.ExitRentExemptionClosure c
        JOIN @Restore r ON r.ClosureID = c.ExitRentExemptionClosureID;

        IF @Action = N'APPLY'
        BEGIN
            -- Existing active closure: change only the imposed end date; original remains immutable.
            UPDATE e
               SET e.residentRentExemptionEndDate = CONVERT(DATETIME, @ExitDate)
            FROM Housing.ResidentRentExemption e
            JOIN Housing.ExitRentExemptionClosure c
              ON c.ResidentRentExemptionID_FK = e.residentRentExemptionID
            WHERE c.ExitRequestActionID_FK = @ExitRequestActionID
              AND c.RestoredAt IS NULL
              AND CONVERT(DATE, e.residentRentExemptionStartDate) <= @ExitDate;

            UPDATE c
               SET c.AppliedExitEndDate = CONVERT(DATETIME, @ExitDate)
            FROM Housing.ExitRentExemptionClosure c
            WHERE c.ExitRequestActionID_FK = @ExitRequestActionID
              AND c.RestoredAt IS NULL;

            -- New closure: store the original end-date BEFORE truncating the exemption.
            DECLARE @Added TABLE (ExemptionID BIGINT PRIMARY KEY);
            INSERT INTO Housing.ExitRentExemptionClosure
            (
                  ExitRequestActionID_FK, ResidentRentExemptionID_FK,
                  OriginalEndDate, AppliedExitEndDate, ClosureReason,
                  ClosedBy, CloseHostName
            )
            OUTPUT inserted.ResidentRentExemptionID_FK INTO @Added (ExemptionID)
            SELECT @ExitRequestActionID, e.residentRentExemptionID,
                   e.residentRentExemptionEndDate, CONVERT(DATETIME, @ExitDate),
                   N'EXIT_REQUEST', @EntryData, @HostName
            FROM Housing.ResidentRentExemption e WITH (UPDLOCK, HOLDLOCK)
            WHERE e.residentInfoID_FK = @ResidentInfoID
              AND e.buildingDetailsID_FK = @BuildingDetailsID
              AND e.idaraID_FK = @IdaraID
              AND e.residentRentExemptionActive = 1
              AND e.residentRentExemptionStartDate IS NOT NULL
              AND CONVERT(DATE, e.residentRentExemptionStartDate) <= @ExitDate
              AND (e.residentRentExemptionEndDate IS NULL
                   OR CONVERT(DATE, e.residentRentExemptionEndDate) > @ExitDate)
              AND NOT EXISTS
              (
                  SELECT 1 FROM Housing.ExitRentExemptionClosure c WITH (UPDLOCK, HOLDLOCK)
                  WHERE c.ResidentRentExemptionID_FK = e.residentRentExemptionID
                    AND c.RestoredAt IS NULL
              );

            UPDATE e
               SET e.residentRentExemptionEndDate = CONVERT(DATETIME, @ExitDate)
            FROM Housing.ResidentRentExemption e
            JOIN @Added a ON a.ExemptionID = e.residentRentExemptionID;
        END;

        IF @ReturnResult = 1
        BEGIN
            SELECT 1 AS IsSuccessful, @Action AS ActionName,
                   (SELECT COUNT_BIG(*) FROM Housing.ExitRentExemptionClosure
                    WHERE ExitRequestActionID_FK = @ExitRequestActionID AND RestoredAt IS NULL)
                    AS ActiveClosures;
        END;

        IF @InitialTranCount = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @InitialTranCount = 0 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        -- If caller owns the transaction, caller must rollback on error.
        THROW;
    END CATCH;
END;