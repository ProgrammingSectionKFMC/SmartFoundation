CREATE   PROCEDURE [VIC].[MaintenanceSP]
(
      @ActionType         NVARCHAR(100)
    , @maintOrdID         INT            = NULL
    , @maintOrdTypeID_FK  INT            = NULL
    , @vehicleID          INT            = NULL
    , @chassisNumber      NVARCHAR(200)  = NULL
    , @maintOrdStartDate  DATETIME       = NULL
    , @maintOrdEndDate    DATETIME       = NULL
    , @maintOrdDesc       NVARCHAR(400)  = NULL
    , @maintOrdActive     BIT            = 1
    , @idaraID_FK         BIGINT          = NULL
    , @entryData          NVARCHAR(40)   = NULL
    , @hostName           NVARCHAR(400)  = NULL

    , @maintDetailesID    INT            = NULL
    , @typesID_FK         INT            = NULL
    , @SupportID_FK       NVARCHAR(50)   = NULL
    , @CheckStatus_FK     NVARCHAR(50)   = NULL
    , @ActionState        NVARCHAR(200)  = NULL
    , @CorrectiveAction   NVARCHAR(1000) = NULL
    , @FSN                NVARCHAR(100)  = NULL
    , @MaintLevel         NVARCHAR(100)  = NULL
    , @CurrentDate        DATETIME       = NULL
    , @Notes              NVARCHAR(200)  = NULL

    , @odometer           INT            = NULL
    , @detailJson         NVARCHAR(MAX)  = NULL
    , @faultJson          NVARCHAR(MAX)  = NULL
    , @actionJson         NVARCHAR(MAX)  = NULL
    , @groupID            INT            = NULL
    , @workshopIDs        NVARCHAR(200)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;
    DECLARE @Note_Audit NVARCHAR(MAX);

    ----------------------------------------------------------------
    -- UPSERT_ORDER
    ----------------------------------------------------------------
    IF @ActionType = 'UPSERT_ORDER'
    BEGIN
        BEGIN TRY
            IF @maintOrdTypeID_FK IS NULL
            BEGIN
                THROW 50001, N'نوع أمر الصيانة مطلوب', 1;
                RETURN;
            END

            IF @idaraID_FK IS NULL
            BEGIN
                THROW 50001, N'معرف الإدارة مطلوب', 1;
                RETURN;
            END

            DECLARE @TargetChassis NVARCHAR(200);
            IF @vehicleID IS NOT NULL AND @vehicleID > 0
            BEGIN
                SELECT @TargetChassis = v.chassisNumber
                FROM VIC.Vehicles v WHERE v.vehicleID = @vehicleID;
            END
            ELSE IF @chassisNumber IS NOT NULL AND LEN(LTRIM(RTRIM(@chassisNumber))) > 0
            BEGIN
                SET @TargetChassis = LTRIM(RTRIM(@chassisNumber));
            END

            IF @TargetChassis IS NULL
            BEGIN
                THROW 50001, N'معرف المركبة مطلوب', 1;
                RETURN;
            END

            IF NOT EXISTS (SELECT 1 FROM VIC.Vehicles v WHERE v.chassisNumber = @TargetChassis)
            BEGIN
                THROW 50001, N'المركبة غير موجودة', 1;
                RETURN;
            END

            IF @maintOrdID IS NULL OR @maintOrdID <= 0
            BEGIN
                IF @tc = 0 BEGIN TRAN;

                IF @maintOrdTypeID_FK = 265 AND EXISTS (SELECT 1 FROM VIC.VehicleMaintenance WHERE chassisNumber_FK = @TargetChassis AND MaintOrdTypeID_FK = 265 AND MaintOrdActive = 1)
BEGIN
    THROW 50001, N'يوجد أمر صيانة دورية مفتوح مسبقًا لهذه المركبة', 1;
    RETURN;
END

                IF @maintOrdTypeID_FK = 265 AND @groupID IS NOT NULL AND @groupID > 0
                   AND EXISTS (SELECT 1 FROM VIC.VehicleMaintenanceGroup vmg WHERE vmg.chassisNumber_FK = @TargetChassis AND vmg.Active = 1)
                BEGIN
                    DECLARE @AsgnGroupCode NVARCHAR(50);
                    SELECT @AsgnGroupCode = ISNULL(mg.GroupCode, N'?') FROM VIC.VehicleMaintenanceGroup vmg LEFT JOIN VIC.MaintenanceGroup mg ON mg.GroupID = vmg.GroupID_FK WHERE vmg.chassisNumber_FK = @TargetChassis AND vmg.Active = 1;
                    DECLARE @AsgnMsg NVARCHAR(300) = N'المركبة مسندة بالفعل إلى المجموعة (' + @AsgnGroupCode + N'). استخدم إجراء نقل مجموعة المركبة لتغييرها.';
                    THROW 50001, @AsgnMsg, 1;
                    RETURN;
                END

                INSERT INTO VIC.VehicleMaintenance
                (
                      MaintOrdTypeID_FK
                    , chassisNumber_FK
                    , MaintOrdStartDate
                    , MaintOrdEndDate
                    , MaintOrdDesc
                    , MaintOrdActive
                    , IdaraID_FK
                    , entryDate
                    , entryData
                    , hostName
                )
                VALUES
                (
                      @maintOrdTypeID_FK
                    , @TargetChassis
                    , ISNULL(@maintOrdStartDate, GETDATE())
                    , @maintOrdEndDate
                    , @maintOrdDesc
                    , 1
                    , @idaraID_FK
                    , GETDATE()
                    , @entryData
                    , @hostName
                );

                DECLARE @NewMaintOrdID INT = SCOPE_IDENTITY();

                IF @maintOrdTypeID_FK = 265 AND @groupID IS NOT NULL AND @groupID > 0
                BEGIN
                    -- first-time assignment (pre-check above guaranteed no active assignment)
                    INSERT INTO VIC.VehicleMaintenanceGroup (chassisNumber_FK, GroupID_FK, IdaraID_FK, Active, AssignedDate, AssignedBy)
                    VALUES (@TargetChassis, @groupID, CAST(@idaraID_FK AS NVARCHAR(20)), 1, GETDATE(), @entryData);

                    -- create/refresh plan: nextDueDate = first group period month >= current month
                    DECLARE @Add_CurMonth INT = MONTH(GETDATE());
                    DECLARE @Add_DueMonth INT;
                    SELECT @Add_DueMonth = MIN(gp.MonthNumber) FROM VIC.MaintenanceGroupPeriod gp WHERE gp.GroupID_FK = @groupID AND gp.MonthNumber >= @Add_CurMonth;
                    IF @Add_DueMonth IS NULL
                        SELECT @Add_DueMonth = MIN(gp.MonthNumber) FROM VIC.MaintenanceGroupPeriod gp WHERE gp.GroupID_FK = @groupID;
                    DECLARE @Add_DueYear INT = YEAR(GETDATE()) + CASE WHEN @Add_DueMonth < @Add_CurMonth THEN 1 ELSE 0 END;
                    DECLARE @Add_NextDue DATE = DATEFROMPARTS(@Add_DueYear, @Add_DueMonth, 1);

                    IF NOT EXISTS (SELECT 1 FROM VIC.VehicleMaintenancePlan p WHERE p.chassisNumber_FK = @TargetChassis AND p.planActive = 1)
                        INSERT INTO VIC.VehicleMaintenancePlan (chassisNumber_FK, periodMonths, nextDueDate, planActive, IdaraID_FK, entryDate, entryData, hostName)
                        VALUES (@TargetChassis, 3, @Add_NextDue, 1, @idaraID_FK, GETDATE(), @entryData, @hostName);
                    ELSE
                        UPDATE VIC.VehicleMaintenancePlan
                        SET nextDueDate = @Add_NextDue, entryDate = GETDATE(), entryData = @entryData, hostName = @hostName
                        WHERE chassisNumber_FK = @TargetChassis AND planActive = 1;
                END

                -- General (266): insert fault rows - NO FaultID (identity column)
                IF @maintOrdTypeID_FK = 266 AND @faultJson IS NOT NULL AND LEN(LTRIM(RTRIM(@faultJson))) > 2
                BEGIN
                    INSERT INTO VIC.GeneralMaintenanceFault
                    (
                          MaintOrdID_FK
                        , [LineNo]
                        , FaultDescription
                        , [Active]
                        , entryDate
                        , entryData
                        , hostName
                    )
                    SELECT
                          @NewMaintOrdID
                        , fj.[LineNo]
                        , fj.FaultDescription
                        , 1
                        , GETDATE()
                        , @entryData
                        , @hostName
                    FROM OPENJSON(@faultJson)
                    WITH (
                          [LineNo]           INT N'$.lineNo'
                        , FaultDescription  NVARCHAR(500) N'$.faultDescription'
                    ) fj
                    WHERE fj.FaultDescription IS NOT NULL
                      AND LEN(LTRIM(RTRIM(fj.FaultDescription))) > 0;
                END

                SET @Note_Audit = N'{'
                    + N'"maintOrdID":"'   + ISNULL(CONVERT(NVARCHAR(MAX), @NewMaintOrdID), N'') + N'"'
                    + N',"maintOrdTypeID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @maintOrdTypeID_FK), N'') + N'"'
                    + N',"chassisNumber":"'     + ISNULL(@TargetChassis, N'') + N'"'
                    + N',"idaraID_FK":"'  + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), N'') + N'"'
                    + N',"entryData":"'   + ISNULL(@entryData, N'') + N'"'
                    + N'}';

                INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
                VALUES (N'[VIC].[VehicleMaintenance]', N'UPSERT_ORDER_INSERT', @NewMaintOrdID, @entryData, @Note_Audit);

                IF @tc = 0 COMMIT;

                SELECT 1 AS IsSuccessful, N'تم إنشاء أمر الصيانة بنجاح' AS Message_;
            END
            ELSE
            BEGIN
                IF @tc = 0 BEGIN TRAN;

                
                DECLARE @SubmittedFaults TABLE
                (
                      FaultID          INT            NULL
                    , [LineNo]         INT            NOT NULL
                    , FaultDescription NVARCHAR(MAX)  NULL
                );

                IF @maintOrdTypeID_FK = 266 AND @faultJson IS NOT NULL
                BEGIN
                    IF ISJSON(@faultJson) <> 1 OR LEFT(LTRIM(@faultJson), 1) <> N'['
                        THROW 50001, N'بيانات الأعطال المرسلة غير صالحة', 1;

                    INSERT INTO @SubmittedFaults (FaultID, [LineNo], FaultDescription)
                    SELECT
                          TRY_CONVERT(INT, NULLIF(JSON_VALUE(j.[value], N'$.faultId'), N''))
                        , TRY_CONVERT(INT, j.[key]) + 1
                        , LTRIM(RTRIM(JSON_VALUE(j.[value], N'$.faultDescription')))
                    FROM OPENJSON(@faultJson) j;

                    IF (SELECT COUNT(*) FROM @SubmittedFaults) NOT BETWEEN 1 AND 16
                        THROW 50001, N'يجب أن يتراوح عدد أعطال الصيانة العامة بين عطل واحد و16 عطلًا', 1;

                    IF EXISTS
                    (
                        SELECT 1
                        FROM @SubmittedFaults
                        WHERE FaultDescription IS NULL
                           OR LEN(FaultDescription) = 0
                           OR LEN(FaultDescription) > 500
                    )
                        THROW 50001, N'وصف كل عطل مطلوب ويجب ألا يتجاوز 500 حرف', 1;

                    IF EXISTS
                    (
                        SELECT FaultID
                        FROM @SubmittedFaults
                        WHERE FaultID IS NOT NULL
                        GROUP BY FaultID
                        HAVING COUNT(*) > 1
                    )
                        THROW 50001, N'لا يُسمح بتكرار معرفات الأعطال', 1;

                    IF EXISTS
                    (
                        SELECT 1
                        FROM @SubmittedFaults sf
                        WHERE sf.FaultID IS NOT NULL
                          AND NOT EXISTS
                          (
                              SELECT 1
                              FROM VIC.GeneralMaintenanceFault gf
                              WHERE gf.FaultID = sf.FaultID
                                AND gf.MaintOrdID_FK = @maintOrdID
                                AND ISNULL(gf.[Active], 1) = 1
                          )
                    )
                        THROW 50001, N'يوجد عطل واحد أو أكثر لا يتبع أمر الصيانة المحدد', 1;
                END

                UPDATE VIC.VehicleMaintenance
                SET
                      chassisNumber_FK = @TargetChassis
                    , MaintOrdStartDate = ISNULL(@maintOrdStartDate, MaintOrdStartDate)
                    , MaintOrdEndDate   = @maintOrdEndDate
                    , MaintOrdDesc      = ISNULL(@maintOrdDesc, MaintOrdDesc)
                    , entryDate         = GETDATE()
                    , entryData         = @entryData
                    , hostName          = @hostName
                WHERE MaintOrdID = @maintOrdID
                  AND IdaraID_FK = @idaraID_FK;

                IF @@ROWCOUNT <= 0
                BEGIN
                    THROW 50002, N'فشل تحديث أمر الصيانة', 1;
                    RETURN;
                END

                
                IF @maintOrdTypeID_FK = 266 AND @faultJson IS NOT NULL
                BEGIN
                    UPDATE gf
                    SET
                          gf.[LineNo] = sf.[LineNo]
                        , gf.FaultDescription = CONVERT(NVARCHAR(500), sf.FaultDescription)
                        , gf.entryData = @entryData
                        , gf.hostName = @hostName
                    FROM VIC.GeneralMaintenanceFault gf
                    INNER JOIN @SubmittedFaults sf ON sf.FaultID = gf.FaultID
                    WHERE gf.MaintOrdID_FK = @maintOrdID
                      AND ISNULL(gf.[Active], 1) = 1;

                    UPDATE gf
                    SET
                          gf.[Active] = 0
                        , gf.entryData = @entryData
                        , gf.hostName = @hostName
                    FROM VIC.GeneralMaintenanceFault gf
                    WHERE gf.MaintOrdID_FK = @maintOrdID
                      AND ISNULL(gf.[Active], 1) = 1
                      AND NOT EXISTS
                      (
                          SELECT 1
                          FROM @SubmittedFaults sf
                          WHERE sf.FaultID = gf.FaultID
                      );

                    INSERT INTO VIC.GeneralMaintenanceFault
                    (
                          MaintOrdID_FK
                        , [LineNo]
                        , FaultDescription
                        , [Active]
                        , entryDate
                        , entryData
                        , hostName
                    )
                    SELECT
                          @maintOrdID
                        , sf.[LineNo]
                        , CONVERT(NVARCHAR(500), sf.FaultDescription)
                        , 1
                        , GETDATE()
                        , @entryData
                        , @hostName
                    FROM @SubmittedFaults sf
                    WHERE sf.FaultID IS NULL;
                END

                SET @Note_Audit = N'{'
                    + N'"maintOrdID":"'   + ISNULL(CONVERT(NVARCHAR(MAX), @maintOrdID), N'') + N'"'
                    + N',"chassisNumber":"' + ISNULL(@TargetChassis, N'') + N'"'
                    + N',"idaraID_FK":"'  + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), N'') + N'"'
                    + N'}';

                INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
                VALUES (N'[VIC].[VehicleMaintenance]', N'UPSERT_ORDER_UPDATE', @maintOrdID, @entryData, @Note_Audit);

                IF @tc = 0 COMMIT;

                SELECT 1 AS IsSuccessful, N'تم تحديث أمر الصيانة بنجاح' AS Message_;
            END
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- CLOSE_ORDER
    ----------------------------------------------------------------
    IF @ActionType = 'CLOSE_ORDER'
    BEGIN
        BEGIN TRY
            INSERT INTO VIC._DebugDetailJson(ActionType, MaintOrdID, RawJson) VALUES (@ActionType, @maintOrdID, @detailJson);
            IF @maintOrdID IS NULL OR @maintOrdID <= 0
            BEGIN
                THROW 50001, N'معرف أمر الصيانة مطلوب', 1;
                RETURN;
            END

            IF @idaraID_FK IS NULL
            BEGIN
                THROW 50001, N'معرف الإدارة مطلوب', 1;
                RETURN;
            END

            DECLARE @EndDT DATETIME = ISNULL(@maintOrdEndDate, GETDATE());
            DECLARE @OrderTypeID INT;
            DECLARE @OrderChassis NVARCHAR(200);

            IF NOT EXISTS
            (
                SELECT 1
                FROM VIC.VehicleMaintenance m
                WHERE m.MaintOrdID = @maintOrdID
                  AND m.IdaraID_FK = @idaraID_FK
                  AND ISNULL(m.MaintOrdActive, 1) = 1
            )
            BEGIN
                THROW 50001, N'لم يتم العثور على أمر صيانة نشط أو أنه لا يتبع الإدارة الحالية', 1;
                RETURN;
            END

            IF EXISTS
            (
                SELECT 1 FROM VIC.Vehicles v
                INNER JOIN VIC.VehicleMaintenance m ON m.chassisNumber_FK = v.chassisNumber
                WHERE m.MaintOrdID = @maintOrdID AND v.vehicleStatusID_FK = 262
            )
            BEGIN
                THROW 50001, N'لا يمكن إغلاق أمر الصيانة لأن المركبة متلفة', 1;
                RETURN;
            END

            IF @tc = 0 BEGIN TRAN;

            SELECT
                  @OrderTypeID  = m.MaintOrdTypeID_FK
                , @OrderChassis = m.chassisNumber_FK
            FROM VIC.VehicleMaintenance m
            WHERE m.MaintOrdID = @maintOrdID;

            IF @EndDT = CAST(@EndDT AS DATE)
                SET @EndDT = DATEADD(SECOND, -1, DATEADD(DAY, 1, @EndDT));

            -- Periodic (265): process checklist detailJson
            IF @OrderTypeID = 265 AND @detailJson IS NOT NULL AND LEN(LTRIM(RTRIM(@detailJson))) > 2
            BEGIN
                DECLARE @DetailTable TABLE
                (
                      RowID INT IDENTITY(1,1)
                    , MaintDetailesID INT
                    , TypesID INT
                    , CheckStatus NVARCHAR(50)
                    , Notes NVARCHAR(200)
                );

                INSERT INTO @DetailTable (MaintDetailesID, TypesID, CheckStatus, Notes)
                SELECT dj.MaintDetailesID, dj.TypesID, dj.CheckStatus, dj.Notes
                FROM OPENJSON(@detailJson)
                WITH (
                      MaintDetailesID INT N'$.MaintDetailesID'
                    , TypesID INT N'$.typesID_FK'
                    , CheckStatus NVARCHAR(50) N'$.CheckStatus_FK'
                    , Notes NVARCHAR(200) N'$.Notes'
                ) dj;

                UPDATE d
                SET
                      d.CheckStatus_FK = dt.CheckStatus
                    , d.Notes         = ISNULL(dt.Notes, d.Notes)
                    , d.entryDate      = GETDATE()
                    , d.entryData      = @entryData
                    , d.hostName       = @hostName
                FROM VIC.MaintenanceDetails d
                INNER JOIN @DetailTable dt
                    ON dt.MaintDetailesID = d.MaintDetailesID
                    AND dt.MaintDetailesID > 0
                WHERE d.MaintOrdID_FK = @maintOrdID
                  AND ISNULL(d.MaintDetailActive, 1) = 1;

                INSERT INTO VIC.MaintenanceDetails
(
      MaintOrdID_FK
    , typesID_FK
    , CheckStatus_FK
    , Notes
    , entryDate
    , entryData
    , hostName
    , MaintDetailActive
)
SELECT
      @maintOrdID
    , dt.TypesID
    , dt.CheckStatus
    , dt.Notes
    , GETDATE()
    , @entryData
    , @hostName
    , 1
FROM @DetailTable dt
WHERE (dt.MaintDetailesID = 0 OR dt.MaintDetailesID IS NULL)
  AND dt.TypesID IS NOT NULL;
            END

            -- General (266): update corrective actions on GeneralMaintenanceFault
            IF @OrderTypeID = 266 AND @actionJson IS NOT NULL AND LEN(LTRIM(RTRIM(@actionJson))) > 2
            BEGIN
                UPDATE f
                SET
                      f.CorrectiveAction = aj.correctiveAction
                    , f.entryDate        = GETDATE()
                    , f.entryData        = @entryData
                    , f.hostName         = @hostName
                FROM VIC.GeneralMaintenanceFault f
                INNER JOIN (
                    SELECT faultID, correctiveAction
                    FROM OPENJSON(@actionJson)
                    WITH (
                          faultID INT N'$.faultID'
                        , correctiveAction NVARCHAR(500) N'$.correctiveAction'
                    )
                ) aj ON aj.faultID = f.FaultID
                WHERE f.MaintOrdID_FK = @maintOrdID
                  AND ISNULL(f.[Active], 1) = 1;
            END

            -- Periodic (265): validate all checklist items complete
            IF @OrderTypeID = 265
            BEGIN
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM VIC.MaintenanceDetails d
                    WHERE d.MaintOrdID_FK = @maintOrdID
                      AND ISNULL(d.MaintDetailActive, 1) = 1
                )
                BEGIN
                    THROW 50001, N'لا يمكن إغلاق أمر الصيانة الدورية دون وجود بنود صيانة نشطة', 1;
                    RETURN;
                END

                IF EXISTS
                (
                    SELECT 1
                    FROM VIC.MaintenanceDetails d
                    WHERE d.MaintOrdID_FK = @maintOrdID
                      AND ISNULL(d.MaintDetailActive, 1) = 1
                      AND (d.CheckStatus_FK IS NULL OR d.CheckStatus_FK <> N'268')
                )
                BEGIN
                    THROW 50001, N'يجب إكمال جميع بنود الفحص النشطة قبل إغلاق أمر الصيانة', 1;
                    RETURN;
                END
            END

            -- Close the order
            -- Fix: adjust MaintOrdStartDate when closing before original start date
            DECLARE @FinalEndDT DATETIME = ISNULL(@EndDT, GETDATE());

            UPDATE VIC.VehicleMaintenance
            SET
                  MaintOrdActive    = 0
                , MaintOrdStartDate = CASE WHEN MaintOrdStartDate > @FinalEndDT THEN @FinalEndDT ELSE MaintOrdStartDate END
                , MaintOrdEndDate   = @FinalEndDT
                , odometer          = @odometer
                , closeNote         = @maintOrdDesc
                , workshopIDs       = CASE WHEN @OrderTypeID = 266 THEN @workshopIDs ELSE workshopIDs END
                , entryDate         = GETDATE()
                , entryData         = @entryData
                , hostName          = @hostName
            WHERE MaintOrdID = @maintOrdID;

            IF @@ROWCOUNT <= 0
            BEGIN
                THROW 50002, N'فشل إغلاق أمر الصيانة', 1;
                RETURN;
            END

            -- Periodic (265): update/insert maintenance plan for next due date
            IF @OrderTypeID = 265
            BEGIN
                DECLARE @CloseMonth INT = MONTH(ISNULL(@EndDT, GETDATE()));
                DECLARE @CloseYear  INT = YEAR(ISNULL(@EndDT, GETDATE()));
                DECLARE @NextMonth  INT = NULL;
                DECLARE @NextYear   INT = NULL;

                SELECT TOP 1 @NextMonth = gp.MonthNumber
                FROM VIC.VehicleMaintenanceGroup vmg
                JOIN VIC.MaintenanceGroupPeriod gp ON vmg.GroupID_FK = gp.GroupID_FK
                WHERE vmg.chassisNumber_FK = @OrderChassis
                  AND vmg.Active = 1
                  AND gp.MonthNumber > @CloseMonth
                ORDER BY gp.MonthNumber;

                IF @NextMonth IS NOT NULL
                BEGIN
                    SET @NextYear = @CloseYear;
                END
                ELSE
                BEGIN
                    SELECT TOP 1 @NextMonth = gp.MonthNumber
                    FROM VIC.VehicleMaintenanceGroup vmg
                    JOIN VIC.MaintenanceGroupPeriod gp ON vmg.GroupID_FK = gp.GroupID_FK
                    WHERE vmg.chassisNumber_FK = @OrderChassis
                      AND vmg.Active = 1
                    ORDER BY gp.MonthNumber;

                    IF @NextMonth IS NOT NULL
                        SET @NextYear = @CloseYear + 1;
                END

                IF @NextMonth IS NOT NULL AND @NextYear IS NOT NULL
                BEGIN
                    DECLARE @NextDueDate DATE = DATEFROMPARTS(@NextYear, @NextMonth, 1);

                    IF EXISTS (
                        SELECT 1 FROM VIC.VehicleMaintenancePlan p
                        WHERE p.chassisNumber_FK = @OrderChassis AND p.planActive = 1
                    )
                    BEGIN
                        UPDATE VIC.VehicleMaintenancePlan
                        SET nextDueDate = @NextDueDate
                            , entryDate = GETDATE()
                            , entryData = @entryData
                            , hostName  = @hostName
                        WHERE chassisNumber_FK = @OrderChassis
                          AND planActive = 1;
                    END
                    ELSE
                    BEGIN
                        INSERT INTO VIC.VehicleMaintenancePlan
                        (chassisNumber_FK, nextDueDate, planActive, entryDate, entryData, hostName, IdaraID_FK)
                        VALUES (@OrderChassis, @NextDueDate, 1, GETDATE(), @entryData, @hostName, @idaraID_FK);
                    END
                END
            END

            -- Audit log
            SET @Note_Audit = N'{'
                + N'"maintOrdID":"'   + ISNULL(CONVERT(NVARCHAR(MAX), @maintOrdID), N'') + N'"'
                + N',"endDate":"'     + ISNULL(CONVERT(NVARCHAR(MAX), @EndDT, 121), N'') + N'"'
                + N',"odometer":"'    + ISNULL(CONVERT(NVARCHAR(MAX), @odometer), N'') + N'"'
                + N',"idaraID_FK":"'  + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), N'') + N'"'
                + N',"entryData":"'   + ISNULL(@entryData, N'') + N'"'
                + N'}';

            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[VehicleMaintenance]', N'CLOSE_ORDER', @maintOrdID, @entryData, @Note_Audit);

            IF @tc = 0 COMMIT;

            SELECT 1 AS IsSuccessful, N'تم إغلاق أمر الصيانة بنجاح' AS Message_;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- Unknown ActionType
    ----------------------------------------------------------------
    BEGIN
        THROW 50001, N'نوع العملية غير معروف في إجراء معالجة الصيانة', 1;
        RETURN;
    END
END

GO

