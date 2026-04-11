
/* =========================================================
   Description:
   إضافة/تعديل أمر صيانة في جدول VIC.VehicleMaintenance (Header)،
   مع التحقق من رقم الهيكل وصحة تواريخ البداية/النهاية وتعبئة حقول التدقيق.
   وفي حالة وجود قالب لنوع الصيانة يتم إنشاء بنود الصيانة تلقائيًا عند الإضافة.
   Type: WRITE (UPSERT)
========================================================= */

CREATE PROCEDURE [VIC].[MaintenanceOrder_Upsert_SP]
(
      @maintOrdID      INT = NULL
    , @maintOrdTypeID  INT = NULL
    , @chassisNumber   NVARCHAR(100)
    , @startDate       DATETIME = NULL
    , @endDate         DATETIME = NULL
    , @desc            NVARCHAR(800) = NULL
    , @active          BIT = 1
    , @idaraID_FK      NVARCHAR(10) = NULL
    , @entryData       NVARCHAR(40)
    , @hostName        NVARCHAR(400)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @CH NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
    DECLARE @StartDT DATETIME = ISNULL(@startDate, GETDATE());

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE
          @ActionType NVARCHAR(20) = NULL
        , @Note_Audit NVARCHAR(MAX) = NULL
        , @NewID INT = NULL;

    BEGIN TRY

        IF @tc = 0
            BEGIN TRAN;

        IF @CH IS NULL
            THROW 50001, N'chassisNumber مطلوب', 1;

        IF @maintOrdTypeID IS NULL OR @maintOrdTypeID <= 0
            THROW 50001, N'maintOrdTypeID مطلوب', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.TypesRoot t
            WHERE t.typesID = @maintOrdTypeID
              AND t.typesRoot_ParentID = 264
              AND ISNULL(t.typesActive, 0) = 1
        )
            THROW 50001, N'نوع أمر الصيانة غير صحيح', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.Vehicles v
            WHERE v.chassisNumber = @CH
              AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
        )
            THROW 50001, N'رقم الهيكل غير موجود أو لا يطابق الإدارة', 1;

        IF @endDate IS NOT NULL AND @endDate < @StartDT
            THROW 50001, N'لا يمكن أن يكون تاريخ النهاية أقل من تاريخ البداية', 1;

        IF @maintOrdID IS NULL
        BEGIN
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
                  @maintOrdTypeID
                , @CH
                , @StartDT
                , @endDate
                , @desc
                , @active
                , @IdaraID_BIG
                , GETDATE()
                , @entryData
                , @hostName
            );

            SET @maintOrdID = CONVERT(INT, SCOPE_IDENTITY());

            IF @maintOrdID IS NULL OR @maintOrdID <= 0
                THROW 50002, N'فشل إضافة أمر الصيانة', 1;

            -- NEW: تعبئة بنود الصيانة تلقائيًا من القالب عند الإضافة فقط
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
                  @maintOrdID
                , mt.typesID_FK
                , NULL
                , NULL
                , NULL
                , NULL
                , NULL
                , NULL
                , @StartDT
                , NULL
                , GETDATE()
                , @entryData
                , @hostName
            FROM VIC.MaintenanceTemplate mt
            WHERE mt.MaintOrdTypeID_FK = @maintOrdTypeID
              AND mt.templateActive = 1
            ORDER BY
                  mt.TemplateOrder
                , mt.TemplateID;

            SET @ActionType = N'INSERT';
        END
        ELSE
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM VIC.VehicleMaintenance AS m
                WHERE m.MaintOrdID = @maintOrdID
                  AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)
            )
                THROW 50001, N'maintOrdID غير موجود للتعديل أو لا يطابق الإدارة', 1;

            UPDATE VIC.VehicleMaintenance
            SET
                  MaintOrdTypeID_FK  = @maintOrdTypeID
                , chassisNumber_FK   = @CH
                , MaintOrdStartDate  = @StartDT
                , MaintOrdEndDate    = @endDate
                , MaintOrdDesc       = @desc
                , MaintOrdActive     = @active
                , IdaraID_FK         = COALESCE(@IdaraID_BIG, IdaraID_FK)
                , entryDate          = GETDATE()
                , entryData          = @entryData
                , hostName           = @hostName
            WHERE MaintOrdID = @maintOrdID;

            IF @@ROWCOUNT <= 0
                THROW 50002, N'لم يتم تعديل أي سجل', 1;

            SET @ActionType = N'UPDATE';
        END

        SET @NewID = @maintOrdID;
        SET @Note_Audit = N'{'
            + N'"maintOrdID": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @maintOrdID), '') + N'"'
            + N',"maintOrdTypeID": "'   + ISNULL(CONVERT(NVARCHAR(MAX), @maintOrdTypeID), '') + N'"'
            + N',"chassisNumber": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @CH), '') + N'"'
            + N',"startDate": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @StartDT, 121), '') + N'"'
            + N',"endDate": "'          + ISNULL(CONVERT(NVARCHAR(MAX), @endDate, 121), '') + N'"'
            + N',"desc": "'             + ISNULL(CONVERT(NVARCHAR(MAX), @desc), '') + N'"'
            + N',"active": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @active), '') + N'"'
            + N',"idaraID_FK": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
            + N',"entryData": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
            + N',"hostName": "'         + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
            , @ActionType
            , ISNULL(@NewID, 0)
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0
            COMMIT;

        SELECT 1 AS IsSuccessful, N'تم حفظ أمر الصيانة بنجاح' AS Message_;

    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END