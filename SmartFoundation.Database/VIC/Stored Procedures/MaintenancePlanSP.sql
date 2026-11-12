CREATE   PROCEDURE [VIC].[MaintenancePlanSP]
(
      @ActionType        NVARCHAR(100)
    , @planID            INT           = NULL
    , @vehicleID         INT           = NULL
    , @chassisNumber     NVARCHAR(200) = NULL
    , @periodMonths      INT           = NULL
    , @nextDueDate       DATETIME      = NULL
    , @planActive        BIT           = 1
    , @idaraID_FK        NVARCHAR(10)  = NULL
    , @entryData         NVARCHAR(40)  = NULL
    , @hostName          NVARCHAR(400) = NULL

    , @templateID        INT           = NULL
    , @maintOrdTypeID_FK INT           = NULL
    , @typesID_FK        INT           = NULL
    , @templateOrder     INT           = 1
    , @active            BIT = 1
    , @groupID            INT           = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @CH NVARCHAR(200);
    DECLARE @VID INT;
    IF @vehicleID IS NOT NULL
    BEGIN
        SELECT @CH = v.chassisNumber, @VID = v.vehicleID FROM VIC.Vehicles v WHERE v.vehicleID = @vehicleID;
    END
    ELSE IF @chassisNumber IS NOT NULL
    BEGIN
        SET @CH = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
        SELECT @VID = v.vehicleID FROM VIC.Vehicles v WHERE v.chassisNumber = @CH;
    END

    DECLARE @IdaraID_BIG BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));
    DECLARE @Note_Audit NVARCHAR(MAX);
    DECLARE @NewID INT;

    ----------------------------------------------------------------
    -- UPSERT_PLAN
    ----------------------------------------------------------------
    IF @ActionType = 'UPSERT_PLAN'
    BEGIN
        BEGIN TRY
            IF @CH IS NULL
            BEGIN
                THROW 50001, N'رقم الهيكل مطلوب', 1;
                RETURN;
            END

            IF @periodMonths IS NULL OR @periodMonths <= 0
            BEGIN
                THROW 50001, N'عدد أشهر الدورة مطلوب ويجب أن يكون أكبر من صفر', 1;
                RETURN;
            END

            IF @nextDueDate IS NULL
            BEGIN
                THROW 50001, N'تاريخ الاستحقاق القادم مطلوب', 1;
                RETURN;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM VIC.Vehicles v
                WHERE v.chassisNumber = @CH
                  AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
            )
            BEGIN
                THROW 50001, N'المركبة غير موجودة أو لا تتبع الإدارة الحالية', 1;
                RETURN;
            END

            IF @tc = 0 BEGIN TRAN;

            IF @planID IS NULL
            BEGIN
                IF EXISTS
                (
                    SELECT 1
                    FROM VIC.VehicleMaintenancePlan p
                    WHERE p.chassisNumber_FK = @CH
                      AND p.planActive = 1
                )
                BEGIN
                    THROW 50001, N'توجد خطة صيانة نشطة مسبقًا لهذه المركبة', 1;
                    RETURN;
                END

                INSERT INTO VIC.VehicleMaintenancePlan
                (
                      chassisNumber_FK
                    , periodMonths
                    , nextDueDate
                    , planActive
                    , IdaraID_FK
                    , entryDate
                    , entryData
                    , hostName
                )
                VALUES
                (
                      @CH
                    , @periodMonths
                    , @nextDueDate
                    , @planActive
                    , @IdaraID_BIG
                    , GETDATE()
                    , @entryData
                    , @hostName
                );

                SET @planID = CONVERT(INT, SCOPE_IDENTITY());

                IF @planID IS NULL OR @planID <= 0
                BEGIN
                    THROW 50002, N'فشل إنشاء خطة الصيانة', 1;
                    RETURN;
                END
            END
            ELSE
            BEGIN
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM VIC.VehicleMaintenancePlan p
                    WHERE p.PlanID = @planID
                      AND (@IdaraID_BIG IS NULL OR p.IdaraID_FK = @IdaraID_BIG)
                )
                BEGIN
                    THROW 50001, N'خطة الصيانة غير موجودة أو لا تتبع الإدارة الحالية', 1;
                    RETURN;
                END

                UPDATE VIC.VehicleMaintenancePlan
                SET
                      chassisNumber_FK = @CH
                    , periodMonths     = @periodMonths
                    , nextDueDate      = @nextDueDate
                    , planActive       = @planActive
                    , IdaraID_FK       = COALESCE(@IdaraID_BIG, IdaraID_FK)
                    , entryDate        = GETDATE()
                    , entryData        = @entryData
                    , hostName         = @hostName
                WHERE PlanID = @planID;

                IF @@ROWCOUNT <= 0
                BEGIN
                    THROW 50002, N'فشل تحديث خطة الصيانة', 1;
                    RETURN;
                END
            END

            SET @NewID = @planID;
            SET @Note_Audit = N'{'
                + N'"planID":"'         + ISNULL(CONVERT(NVARCHAR(MAX), @planID), N'') + N'"'
                + N',"chassisNumber":"' + ISNULL(CONVERT(NVARCHAR(MAX), @CH), N'') + N'"'
                + N',"periodMonths":"'  + ISNULL(CONVERT(NVARCHAR(MAX), @periodMonths), N'') + N'"'
                + N',"nextDueDate":"'   + ISNULL(CONVERT(NVARCHAR(MAX), @nextDueDate, 121), N'') + N'"'
                + N',"planActive":"'    + ISNULL(CONVERT(NVARCHAR(MAX), @planActive), N'') + N'"'
                + N',"idaraID_FK":"'    + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), N'') + N'"'
                + N',"entryData":"'     + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), N'') + N'"'
                + N'}';

            INSERT INTO DATACORE.dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[VIC].[VehicleMaintenancePlan]'
                , N'UPSERT_PLAN'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note_Audit
            );

            IF @tc = 0 COMMIT;

            SELECT
                  1            AS IsSuccessful
                , N'تم حفظ خطة الصيانة بنجاح' AS Message_
                , @planID      AS PlanID
                , @VID         AS vehicleID
                , @CH          AS chassisNumber;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- SET_ACTIVE
    ----------------------------------------------------------------
    IF @ActionType = 'SET_ACTIVE'
    BEGIN
        DECLARE @PlanChassis NVARCHAR(200);

        BEGIN TRY
            IF @planID IS NULL OR @planID <= 0
            BEGIN
                THROW 50001, N'معرف خطة الصيانة مطلوب', 1;
                RETURN;
            END

            IF @IdaraID_BIG IS NULL
            BEGIN
                THROW 50001, N'معرف الإدارة مطلوب', 1;
                RETURN;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM VIC.VehicleMaintenancePlan p
                WHERE p.PlanID = @planID
                  AND p.IdaraID_FK = @IdaraID_BIG
            )
            BEGIN
                THROW 50001, N'خطة الصيانة غير موجودة أو لا تتبع الإدارة الحالية', 1;
                RETURN;
            END

            SELECT @PlanChassis = p.chassisNumber_FK
            FROM VIC.VehicleMaintenancePlan p
            WHERE p.PlanID = @planID;

            IF @planActive = 0
            BEGIN
                IF EXISTS
                (
                    SELECT 1 FROM VIC.Vehicles v
                    WHERE v.chassisNumber = @PlanChassis AND v.vehicleStatusID_FK = 262
                )
                BEGIN
                    THROW 50001, N'لا يمكن تعطيل الخطة لأن المركبة متلفة', 1;
                    RETURN;
                END
            END

            IF @tc = 0 BEGIN TRAN;

            UPDATE VIC.VehicleMaintenancePlan
            SET
                  planActive = @planActive
                , entryDate  = GETDATE()
                , entryData  = @entryData
                , hostName   = @hostName
            WHERE PlanID = @planID;

            IF @@ROWCOUNT <= 0
            BEGIN
                THROW 50002, N'فشل تحديث حالة خطة الصيانة', 1;
                RETURN;
            END

            SELECT @VID = v.vehicleID FROM VIC.Vehicles v WHERE v.chassisNumber = @PlanChassis;

            SET @Note_Audit = N'{'
                + N'"planID":"'      + ISNULL(CONVERT(NVARCHAR(MAX), @planID), N'') + N'"'
                + N',"planActive":"' + ISNULL(CONVERT(NVARCHAR(MAX), @planActive), N'') + N'"'
                + N',"idaraID_FK":"'+ ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), N'') + N'"'
                + N',"entryData":"'  + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), N'') + N'"'
                + N'}';

            INSERT INTO DATACORE.dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[VIC].[VehicleMaintenancePlan]'
                , N'SET_ACTIVE'
                , @planID
                , @entryData
                , @Note_Audit
            );

            IF @tc = 0 COMMIT;

            SELECT
                  1 AS IsSuccessful
                , CASE
                    WHEN @planActive = 1 THEN N'تم تفعيل الخطة'
                    ELSE N'تم إلغاء تفعيل الخطة'
                  END AS Message_
                , @VID          AS vehicleID
                , @PlanChassis  AS chassisNumber;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- AUTO_GENERATE
    ----------------------------------------------------------------
    IF @ActionType = 'AUTO_GENERATE'
    BEGIN
        DECLARE @Now DATETIME = GETDATE();
        DECLARE @InsertedCount INT = 0;

        BEGIN TRY
            IF @tc = 0 BEGIN TRAN;

            DECLARE @NewOrders TABLE (MaintOrdID INT, chassisNumber_FK NVARCHAR(200));

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
            OUTPUT
                  INSERTED.MaintOrdID
                , INSERTED.chassisNumber_FK
            INTO @NewOrders (MaintOrdID, chassisNumber_FK)
            SELECT
                  265
                , p.chassisNumber_FK
                , @Now
                , NULL
                , N'أمر صيانة دورية منشأ تلقائيًا'
                , 1
                , p.IdaraID_FK
                , GETDATE()
                , @entryData
                , @hostName
            FROM VIC.VehicleMaintenancePlan p
            WHERE p.planActive = 1
              AND p.nextDueDate <= @Now
              AND (@IdaraID_BIG IS NULL OR p.IdaraID_FK = @IdaraID_BIG)
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM VIC.VehicleMaintenance m
                  WHERE m.chassisNumber_FK = p.chassisNumber_FK
                    AND m.MaintOrdTypeID_FK = 265
                    AND m.MaintOrdActive = 1
              )
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM VIC.Vehicles vv
                  WHERE vv.chassisNumber = p.chassisNumber_FK
                    AND vv.vehicleStatusID_FK = 262
              );

            SET @InsertedCount = @@ROWCOUNT;

            INSERT INTO VIC.MaintenanceDetails
            (
                  MaintOrdID_FK
                , typesID_FK
                , SupportID_FK
                , CheckStatus_FK
                , ActionState
                , CorrectiveAction
                , FSN
                , MaintLevel
                , CurrentDate
                , Notes
                , entryDate
                , entryData
                , hostName
            )
            SELECT
                  no.MaintOrdID
                , mt.typesID_FK
                , NULL
                , NULL
                , NULL
                , NULL
                , NULL
                , NULL
                , @Now
                , NULL
                , GETDATE()
                , @entryData
                , @hostName
            FROM @NewOrders no
            INNER JOIN VIC.MaintenanceTemplate mt
                ON mt.MaintOrdTypeID_FK = 265
                AND mt.templateActive = 1;

            SET @Note_Audit = N'{'
                + N'"InsertedCount":"' + ISNULL(CONVERT(NVARCHAR(MAX), @InsertedCount), N'') + N'"'
                + N',"idaraID_FK":"'   + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), N'') + N'"'
                + N',"entryData":"'    + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), N'') + N'"'
                + N'}';

            INSERT INTO DATACORE.dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[VIC].[VehicleMaintenance]'
                , N'AUTO_GENERATE'
                , @InsertedCount
                , @entryData
                , @Note_Audit
            );

            IF @tc = 0 COMMIT;

            SELECT
                  CAST(1 AS BIT) AS IsSuccessful
                , N'أوامر صيانة دورية مولّدة آليًا' AS Message_
                , @InsertedCount AS InsertedCount;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- UPSERT_TEMPLATE
    ----------------------------------------------------------------
    IF @ActionType = 'UPSERT_TEMPLATE'
    BEGIN
        BEGIN TRY
            IF @maintOrdTypeID_FK IS NULL OR @maintOrdTypeID_FK <= 0
            BEGIN
                THROW 50001, N'نوع أمر الصيانة مطلوب', 1;
                RETURN;
            END

            IF @typesID_FK IS NULL OR @typesID_FK <= 0
            BEGIN
                THROW 50001, N'معرف نوع البند مطلوب', 1;
                RETURN;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM VIC.TypesRoot t
                WHERE t.typesID = @maintOrdTypeID_FK
                  AND t.typesRoot_ParentID = 264
                  AND ISNULL(t.typesActive, 0) = 1
            )
            BEGIN
                THROW 50001, N'نوع أمر الصيانة غير صحيح', 1;
                RETURN;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM VIC.TypesRoot t
                WHERE t.typesID = @typesID_FK
                  AND ISNULL(t.typesActive, 0) = 1
            )
            BEGIN
                THROW 50001, N'نوع بند القالب غير صحيح', 1;
                RETURN;
            END

            IF @tc = 0 BEGIN TRAN;

            IF @templateID IS NULL
            BEGIN
                IF EXISTS
                (
                    SELECT 1
                    FROM VIC.MaintenanceTemplate mt
                    WHERE mt.MaintOrdTypeID_FK = @maintOrdTypeID_FK
                      AND mt.typesID_FK = @typesID_FK
                      AND mt.templateActive = 1
                )
                BEGIN
                    THROW 50001, N'يوجد قالب نشط مسبقًا لهذه التوليفة من الأنواع', 1;
                    RETURN;
                END

                INSERT INTO VIC.MaintenanceTemplate
                (
                      MaintOrdTypeID_FK
                    , typesID_FK
                    , TemplateOrder
                    , templateActive
                    , entryDate
                    , entryData
                    , hostName
                )
                VALUES
                (
                      @maintOrdTypeID_FK
                    , @typesID_FK
                    , @templateOrder
                    , @active
                    , GETDATE()
                    , @entryData
                    , @hostName
                );

                SET @templateID = CONVERT(INT, SCOPE_IDENTITY());

                IF @templateID IS NULL OR @templateID <= 0
                BEGIN
                    THROW 50002, N'فشل إنشاء القالب', 1;
                    RETURN;
                END
            END
            ELSE
            BEGIN
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM VIC.MaintenanceTemplate mt
                    WHERE mt.TemplateID = @templateID
                )
                BEGIN
                    THROW 50001, N'القالب غير موجود', 1;
                    RETURN;
                END

                UPDATE VIC.MaintenanceTemplate
                SET
                      MaintOrdTypeID_FK = @maintOrdTypeID_FK
                    , typesID_FK        = @typesID_FK
                    , TemplateOrder     = @templateOrder
                    , templateActive    = @active
                    , entryDate         = GETDATE()
                    , entryData         = @entryData
                    , hostName          = @hostName
                WHERE TemplateID = @templateID;

                IF @@ROWCOUNT <= 0
                BEGIN
                    THROW 50002, N'فشل تحديث القالب', 1;
                    RETURN;
                END
            END

            SET @NewID = @templateID;
            SET @Note_Audit = N'{'
                + N'"templateID":"'        + ISNULL(CONVERT(NVARCHAR(MAX), @templateID), N'') + N'"'
                + N',"maintOrdTypeID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @maintOrdTypeID_FK), N'') + N'"'
                + N',"typesID_FK":"'        + ISNULL(CONVERT(NVARCHAR(MAX), @typesID_FK), N'') + N'"'
                + N',"templateOrder":"'     + ISNULL(CONVERT(NVARCHAR(MAX), @templateOrder), N'') + N'"'
                + N',"active":"'            + ISNULL(CONVERT(NVARCHAR(MAX), @active), N'') + N'"'
                + N',"entryData":"'         + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), N'') + N'"'
                + N'}';

            INSERT INTO DATACORE.dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[VIC].[MaintenanceTemplate]'
                , N'UPSERT_TEMPLATE'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note_Audit
            );

            IF @tc = 0 COMMIT;

            SELECT
                  1               AS IsSuccessful
                , N'تم حفظ القالب بنجاح' AS Message_
                , @templateID     AS TemplateID;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- DELETE_TEMPLATE
    ----------------------------------------------------------------
    IF @ActionType = 'DELETE_TEMPLATE'
    BEGIN
        BEGIN TRY
            IF @templateID IS NULL OR @templateID <= 0
            BEGIN
                THROW 50001, N'معرف القالب مطلوب', 1;
                RETURN;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM VIC.MaintenanceTemplate mt
                WHERE mt.TemplateID = @templateID
            )
            BEGIN
                THROW 50001, N'القالب غير موجود', 1;
                RETURN;
            END

            IF @tc = 0 BEGIN TRAN;

            UPDATE VIC.MaintenanceTemplate
            SET
                  templateActive = 0
                , entryDate      = GETDATE()
                , entryData      = @entryData
                , hostName       = @hostName
            WHERE TemplateID = @templateID;

            IF @@ROWCOUNT <= 0
            BEGIN
                THROW 50002, N'فشل حذف القالب', 1;
                RETURN;
            END

            SET @Note_Audit = N'{'
                + N'"templateID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @templateID), N'') + N'"'
                + N',"entryData":"' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), N'') + N'"'
                + N'}';

            INSERT INTO DATACORE.dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[VIC].[MaintenanceTemplate]'
                , N'DELETE_TEMPLATE'
                , @templateID
                , @entryData
                , @Note_Audit
            );

            IF @tc = 0 COMMIT;

            SELECT 1 AS IsSuccessful, N'تم حذف القالب بنجاح' AS Message_;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- MOVE_GROUP
    ----------------------------------------------------------------
    IF @ActionType = 'MOVE_GROUP'
    BEGIN
        BEGIN TRY
            IF @CH IS NULL
            BEGIN
                THROW 50001, N'رقم الهيكل مطلوب', 1;
                RETURN;
            END

            IF @groupID IS NULL OR @groupID <= 0
               OR NOT EXISTS (SELECT 1 FROM VIC.MaintenanceGroup mg WHERE mg.GroupID = @groupID AND ISNULL(mg.GroupActive,1) = 1)
            BEGIN
                THROW 50001, N'يجب تحديد مجموعة مستهدفة صحيحة', 1;
                RETURN;
            END

            IF NOT EXISTS (SELECT 1 FROM VIC.VehicleMaintenanceGroup vmg WHERE vmg.chassisNumber_FK = @CH AND vmg.Active = 1)
            BEGIN
                THROW 50001, N'المركبة غير مرتبطة بمجموعة نشطة', 1;
                RETURN;
            END

            IF EXISTS (SELECT 1 FROM VIC.VehicleMaintenance m WHERE m.chassisNumber_FK = @CH AND m.MaintOrdTypeID_FK = 265 AND m.MaintOrdActive = 1)
            BEGIN
                THROW 50001, N'لا يمكن نقل المركبة لوجود أمر صيانة دورية مفتوح؛ يجب إغلاقه أولًا', 1;
                RETURN;
            END

            IF @tc = 0 BEGIN TRAN;

            UPDATE vmg
            SET vmg.GroupID_FK = @groupID
              , vmg.Active = 1
              , vmg.AssignedDate = GETDATE()
              , vmg.AssignedBy = @entryData
              , vmg.IdaraID_FK = CAST(@IdaraID_BIG AS NVARCHAR(20))
            FROM VIC.VehicleMaintenanceGroup vmg
            WHERE vmg.chassisNumber_FK = @CH;

            DECLARE @MG_CurMonth INT = MONTH(GETDATE());
            DECLARE @MG_DueMonth INT;
            SELECT @MG_DueMonth = MIN(gp.MonthNumber) FROM VIC.MaintenanceGroupPeriod gp WHERE gp.GroupID_FK = @groupID AND gp.MonthNumber >= @MG_CurMonth;
            IF @MG_DueMonth IS NULL
                SELECT @MG_DueMonth = MIN(gp.MonthNumber) FROM VIC.MaintenanceGroupPeriod gp WHERE gp.GroupID_FK = @groupID;
            DECLARE @MG_DueYear INT = YEAR(GETDATE()) + CASE WHEN @MG_DueMonth < @MG_CurMonth THEN 1 ELSE 0 END;
            DECLARE @MG_NextDue DATE = DATEFROMPARTS(@MG_DueYear, @MG_DueMonth, 1);

            IF EXISTS (SELECT 1 FROM VIC.VehicleMaintenancePlan p WHERE p.chassisNumber_FK = @CH AND p.planActive = 1)
                UPDATE VIC.VehicleMaintenancePlan
                SET nextDueDate = @MG_NextDue
                  , entryDate = GETDATE()
                  , entryData = @entryData
                  , hostName = @hostName
                WHERE chassisNumber_FK = @CH AND planActive = 1;

            SELECT 1 AS IsSuccessful, N'تم نقل المجموعة بنجاح' AS Message_, @CH AS chassisNumber, @groupID AS newGroupID;
            IF @tc = 0 COMMIT;
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
        THROW 50001, N'نوع العملية غير معروف في إجراء معالجة خطط الصيانة', 1;
        RETURN;
    END
END

GO

