CREATE   PROCEDURE [VIC].[ScrapSP]
    @ActionType     NVARCHAR(50)   = NULL
  , @ScrapID        BIGINT         = NULL
  , @vehicleID      INT            = NULL
  , @chassisNumber  NVARCHAR(200)  = NULL
  , @idaraID_FK     NVARCHAR(10)   = NULL
  , @ScrapDate      DATETIME       = NULL
  , @ScrapTypeID_FK INT            = NULL
  , @RefNo          NVARCHAR(100)  = NULL
  , @Reason         NVARCHAR(400)  = NULL
  , @Note           NVARCHAR(1000) = NULL
  , @entryData      NVARCHAR(40)   = NULL
  , @hostName       NVARCHAR(400)  = NULL
  , @actionByUserID BIGINT         = NULL
  , @actionNote     NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;
    DECLARE @IdaraID_BIG BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));
    DECLARE @SCRAP_STATUS INT;

    SELECT @SCRAP_STATUS = typesID
    FROM VIC.TypesRoot
    WHERE typesID = 262;

    DECLARE @CH NVARCHAR(200);
    DECLARE @VID INT;

    IF @vehicleID IS NOT NULL
    BEGIN
        SELECT @CH = v.chassisNumber, @VID = v.vehicleID
        FROM VIC.Vehicles v
        WHERE v.vehicleID = @vehicleID;
    END
    ELSE IF @chassisNumber IS NOT NULL
    BEGIN
        SET @CH = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
        SELECT @VID = v.vehicleID
        FROM VIC.Vehicles v
        WHERE v.chassisNumber = @CH;
    END

    ----------------------------------------------------------------
    -- UPSERT
    ----------------------------------------------------------------
    IF @ActionType = N'UPSERT'
    BEGIN
        BEGIN TRY

            IF @IdaraID_BIG IS NULL
                THROW 50001, N'الإدارة مطلوبة', 1;

            IF @VID IS NULL
                THROW 50001, N'رقم المركبة مطلوب', 1;

            IF @ScrapTypeID_FK IS NULL OR @ScrapTypeID_FK <= 0
                THROW 50001, N'نوع التشليح مطلوب', 1;

            IF NOT EXISTS (
                SELECT 1 FROM VIC.TypesRoot t
                WHERE t.typesID = @ScrapTypeID_FK
                  AND ISNULL(t.typesActive,0) = 1
            )
                THROW 50001, N'نوع التشليح غير صحيح', 1;

            IF NOT EXISTS (
                SELECT 1 FROM VIC.Vehicles v
                WHERE v.vehicleID = @VID
                  AND v.IdaraID_FK = @IdaraID_BIG
            )
                THROW 50001, N'المركبة غير موجودة أو لا تطابق الإدارة', 1;

            IF EXISTS (
                SELECT 1 FROM VIC.Vehicles
                WHERE vehicleID = @VID
                  AND vehicleStatusID_FK = @SCRAP_STATUS
            )
                THROW 50001, N'المركبة مشطوبة مسبقاً', 1;

            IF @tc = 0 BEGIN TRAN;

            IF @ScrapID IS NULL
            BEGIN
                INSERT INTO VIC.VehicleScrap
                (
                    chassisNumber_FK, IdaraID_FK, ScrapDate,
                    ScrapTypeID_FK, RefNo, Reason, Note,
                    Status, entryDate, entryData, hostName
                )
                VALUES
                (
                    @CH, @IdaraID_BIG, ISNULL(@ScrapDate, GETDATE()),
                    @ScrapTypeID_FK, @RefNo, @Reason, @Note,
                    N'Draft', GETDATE(), @entryData, @hostName
                );

                SET @ScrapID = SCOPE_IDENTITY();
            END
            ELSE
            BEGIN
                SELECT @CH       = chassisNumber_FK,
                       @ScrapDate = ScrapDate,
                       @RefNo     = RefNo,
                       @Reason    = Reason,
                       @Note      = Note
                FROM VIC.VehicleScrap WITH (UPDLOCK, HOLDLOCK)
                WHERE ScrapID = @ScrapID
                  AND IdaraID_FK = @IdaraID_BIG
                  AND Status = N'Draft';

                IF @@ROWCOUNT = 0
                    THROW 50001, N'لا يمكن تعديل الطلب', 1;

                UPDATE VIC.VehicleScrap
                SET ScrapDate      = ISNULL(@ScrapDate, ScrapDate),
                    ScrapTypeID_FK = @ScrapTypeID_FK,
                    RefNo          = @RefNo,
                    Reason         = @Reason,
                    Note           = @Note,
                    entryDate      = GETDATE(),
                    entryData      = @entryData,
                    hostName       = @hostName
                WHERE ScrapID = @ScrapID;
            END

            IF @tc = 0 COMMIT;

            SELECT 1 AS IsSuccessful,
                   N'تم حفظ طلب التشليح' AS Message_;

        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- APPROVE
    ----------------------------------------------------------------
    IF @ActionType = N'APPROVE'
    BEGIN
        BEGIN TRY

            IF @ScrapID IS NULL
                THROW 50001, N'رقم الطلب مطلوب', 1;

            IF @IdaraID_BIG IS NULL
                THROW 50001, N'الإدارة مطلوبة', 1;

            -- Lock سجل الطلب + قراءة البيانات + التحقق من الحالة في استعلام واحد
            SELECT @CH        = chassisNumber_FK,
                   @ScrapDate = ScrapDate,
                   @RefNo     = RefNo,
                   @Reason    = Reason,
                   @Note      = Note
            FROM VIC.VehicleScrap WITH (UPDLOCK, HOLDLOCK)
            WHERE ScrapID = @ScrapID
              AND IdaraID_FK = @IdaraID_BIG
              AND Status = N'Draft';

            IF @@ROWCOUNT = 0 OR @CH IS NULL
                THROW 50001, N'الطلب غير صالح أو تمت معالجته', 1;

            -- Lock المركبة + قراءة vehicleID
            SELECT @VID = vehicleID
            FROM VIC.Vehicles WITH (UPDLOCK)
            WHERE chassisNumber = @CH;

            IF @VID IS NULL
                THROW 50001, N'المركبة غير موجودة', 1;

            -- إعادة التحقق من حالة المركبة (حماية من التزامن)
            IF EXISTS (
                SELECT 1 FROM VIC.Vehicles
                WHERE vehicleID = @VID
                  AND vehicleStatusID_FK = @SCRAP_STATUS
            )
                THROW 50001, N'المركبة مشطوبة مسبقاً', 1;

            IF @tc = 0 BEGIN TRAN;

            -- اغلاق العهد
            UPDATE VIC.vehicleWithUsers
            SET endDate = GETDATE()
            WHERE chassisNumber_FK = @CH
              AND endDate IS NULL;

            -- اغلاق الصيانة
            UPDATE VIC.VehicleMaintenance
            SET MaintOrdActive = 0,
                MaintOrdEndDate = GETDATE()
            WHERE chassisNumber_FK = @CH
              AND ISNULL(MaintOrdActive, 1) = 1;

            -- تحديث المركبة (الأساس vehicleID) — ببيانات الطلب الأصلية
            UPDATE VIC.Vehicles
            SET isActive = 0,
                vehicleStatusID_FK = @SCRAP_STATUS,
                scrapDate = ISNULL(@ScrapDate, GETDATE()),
                scrapRefNo = @RefNo,
                scrapReason = @Reason,
                scrapNote = @Note
            WHERE vehicleID = @VID;

            -- تحديث الطلب — ملاحظة الاعتماد في Notes
            UPDATE VIC.VehicleScrap
            SET Status = N'Approved',
                ApprovedByUserID = @actionByUserID,
                ApprovedDate = GETDATE(),
                Notes = ISNULL(@actionNote, Notes)
            WHERE ScrapID = @ScrapID;

            IF @tc = 0 COMMIT;

            SELECT 1 AS IsSuccessful,
                   N'تم اعتماد التشليح' AS Message_;

        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- CANCEL
    ----------------------------------------------------------------
    IF @ActionType = N'CANCEL'
    BEGIN
        BEGIN TRY

            IF @ScrapID IS NULL
                THROW 50001, N'رقم الطلب مطلوب', 1;

            IF @IdaraID_BIG IS NULL
                THROW 50001, N'الإدارة مطلوبة', 1;

            -- Lock سجل الطلب + التحقق من الحالة
            IF NOT EXISTS (
                SELECT 1 FROM VIC.VehicleScrap WITH (UPDLOCK, HOLDLOCK)
                WHERE ScrapID = @ScrapID
                  AND IdaraID_FK = @IdaraID_BIG
                  AND Status = N'Draft'
            )
                THROW 50001, N'لا يمكن إلغاء الطلب', 1;

            IF @tc = 0 BEGIN TRAN;

            UPDATE VIC.VehicleScrap
            SET Status = N'Cancelled',
                Notes = ISNULL(@actionNote, Notes)
            WHERE ScrapID = @ScrapID;

            IF @tc = 0 COMMIT;

            SELECT 1 AS IsSuccessful,
                   N'تم إلغاء الطلب' AS Message_;

        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- Unknown
    ----------------------------------------------------------------
    ;THROW 50001, N'نوع العملية غير معروف في إجراء معالجة الإتلاف', 1;

END

GO

