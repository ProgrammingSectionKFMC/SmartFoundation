
/* =========================================================
   Description:
   إغلاق أمر الصيانة عبر تحديث VIC.VehicleMaintenance بحيث يصبح MaintOrdActive = 0
   وتحديد تاريخ الإغلاق MaintOrdEndDate (افتراضيًا الآن) مع تحديث حقول التدقيق.
   وفي حالة الصيانة الدورية يتم تحديث موعد الاستحقاق القادم في VIC.VehicleMaintenancePlan.
   ولا يسمح بالإغلاق إلا بعد وجود بنود صيانة واكتمال جميع البنود (CheckStatus_FK = 268).
   Type: WRITE (CLOSE)
========================================================= */

CREATE PROCEDURE [VIC].[MaintenanceOrder_Close_SP]
(
      @maintOrdID INT
    , @endDate    DATETIME = NULL
    , @idaraID_FK NVARCHAR(10) = NULL
    , @entryData  NVARCHAR(40) = NULL
    , @hostName   NVARCHAR(400) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;
    DECLARE @EndDT DATETIME = ISNULL(@endDate, GETDATE());

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE @MaintOrdTypeID INT = NULL;
    DECLARE @ChassisNumber NVARCHAR(100) = NULL;

    -- ADDED (Audit)
    DECLARE @Note_Audit NVARCHAR(MAX) = NULL;

    BEGIN TRY

        IF @tc = 0
            BEGIN TRAN;

        IF @maintOrdID IS NULL OR @maintOrdID <= 0
            THROW 50001, N'maintOrdID مطلوب', 1;

        -- تحقق وجود أمر الصيانة + مطابقة الإدارة (إن تم تمريرها)
        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.VehicleMaintenance AS m
            WHERE m.MaintOrdID = @maintOrdID
              AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)
        )
            THROW 50001, N'أمر الصيانة غير موجود أو لا يطابق الإدارة', 1;

        -- NEW: منع إعادة الإغلاق إذا كان الأمر مقفلًا أصلًا
        IF EXISTS
        (
            SELECT 1
            FROM VIC.VehicleMaintenance AS m
            WHERE m.MaintOrdID = @maintOrdID
              AND m.MaintOrdActive = 0
        )
            THROW 50001, N'أمر الصيانة مقفل مسبقًا', 1;

        -- NEW: يجب أن يكون للأمر بنود صيانة
        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.MaintenanceDetails AS d
            INNER JOIN VIC.VehicleMaintenance AS m
                ON m.MaintOrdID = d.MaintOrdID_FK
            WHERE d.MaintOrdID_FK = @maintOrdID
              AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)
        )
            THROW 50001, N'لا يمكن إغلاق أمر الصيانة قبل إضافة بنود الصيانة', 1;

        -- NEW: جميع البنود يجب أن تكون مكتملة (CheckStatus_FK = 268)
        IF EXISTS
        (
            SELECT 1
            FROM VIC.MaintenanceDetails AS d
            INNER JOIN VIC.VehicleMaintenance AS m
                ON m.MaintOrdID = d.MaintOrdID_FK
            WHERE d.MaintOrdID_FK = @maintOrdID
              AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)
              AND (d.CheckStatus_FK IS NULL OR d.CheckStatus_FK <> 268)
        )
            THROW 50001, N'لا يمكن إغلاق أمر الصيانة قبل إكمال جميع البنود', 1;

        SELECT
              @MaintOrdTypeID = m.MaintOrdTypeID_FK
            , @ChassisNumber  = m.chassisNumber_FK
        FROM VIC.VehicleMaintenance AS m
        WHERE m.MaintOrdID = @maintOrdID;

        UPDATE VIC.VehicleMaintenance
        SET
              MaintOrdActive   = 0
            , MaintOrdEndDate  = @EndDT
            , entryDate        = GETDATE()
            , entryData        = COALESCE(@entryData, entryData)
            , hostName         = COALESCE(@hostName, hostName)
        WHERE MaintOrdID = @maintOrdID;

        IF @@ROWCOUNT <= 0
            THROW 50002, N'لم يتم تحديث السجل', 1;

        -- تحديث موعد الصيانة القادمة إذا كان الأمر دوري
        IF @MaintOrdTypeID = 265
        BEGIN
            UPDATE p
            SET
                  nextDueDate = DATEADD(MONTH, p.periodMonths, @EndDT)
                , entryDate   = GETDATE()
                , entryData   = COALESCE(@entryData, p.entryData)
                , hostName    = COALESCE(@hostName, p.hostName)
            FROM VIC.VehicleMaintenancePlan p
            WHERE p.chassisNumber_FK = @ChassisNumber
              AND p.planActive = 1
              AND (@IdaraID_BIG IS NULL OR p.IdaraID_FK = @IdaraID_BIG);
        END

        -- ADDED (AuditLog)
        SET @Note_Audit = N'{'
            + N'"maintOrdID": "'   + ISNULL(CONVERT(NVARCHAR(MAX), @maintOrdID), '') + N'"'
            + N',"endDate": "'     + ISNULL(CONVERT(NVARCHAR(MAX), @EndDT, 121), '') + N'"'
            + N',"idaraID_FK": "'  + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
            + N',"entryData": "'   + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
            + N',"hostName": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
            , N'UPDATE'
            , @maintOrdID
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0
            COMMIT;

        SELECT 1 AS IsSuccessful, N'تم إغلاق أمر الصيانة' AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END