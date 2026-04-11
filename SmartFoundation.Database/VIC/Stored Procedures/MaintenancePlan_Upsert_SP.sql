
/* =========================================================
   Description:
   إضافة/تعديل خطة صيانة دورية لمركبة في جدول VIC.VehicleMaintenancePlan.
   Type: WRITE (UPSERT)
========================================================= */

CREATE   PROCEDURE [VIC].[MaintenancePlan_Upsert_SP]
(
      @planID          INT = NULL
    , @chassisNumber   NVARCHAR(100)
    , @periodMonths    INT
    , @nextDueDate     DATETIME
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

        IF @periodMonths IS NULL OR @periodMonths <= 0
            THROW 50001, N'periodMonths مطلوب ويجب أن يكون أكبر من صفر', 1;

        IF @nextDueDate IS NULL
            THROW 50001, N'nextDueDate مطلوب', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.Vehicles v
            WHERE v.chassisNumber = @CH
              AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
        )
            THROW 50001, N'رقم الهيكل غير موجود أو لا يطابق الإدارة', 1;

        IF @planID IS NULL
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM VIC.VehicleMaintenancePlan p
                WHERE p.chassisNumber_FK = @CH
                  AND p.planActive = 1
            )
                THROW 50001, N'توجد خطة صيانة دورية فعالة لهذه المركبة', 1;

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
                , @active
                , @IdaraID_BIG
                , GETDATE()
                , @entryData
                , @hostName
            );

            SET @planID = CONVERT(INT, SCOPE_IDENTITY());

            IF @planID IS NULL OR @planID <= 0
                THROW 50002, N'فشل إضافة خطة الصيانة الدورية', 1;

            SET @ActionType = N'INSERT';
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
                THROW 50001, N'planID غير موجود للتعديل أو لا يطابق الإدارة', 1;

            UPDATE VIC.VehicleMaintenancePlan
            SET
                  chassisNumber_FK = @CH
                , periodMonths     = @periodMonths
                , nextDueDate      = @nextDueDate
                , planActive       = @active
                , IdaraID_FK       = COALESCE(@IdaraID_BIG, IdaraID_FK)
                , entryDate        = GETDATE()
                , entryData        = @entryData
                , hostName         = @hostName
            WHERE PlanID = @planID;

            IF @@ROWCOUNT <= 0
                THROW 50002, N'لم يتم تعديل أي سجل', 1;

            SET @ActionType = N'UPDATE';
        END

        SET @NewID = @planID;
        SET @Note_Audit = N'{'
            + N'"planID": "'         + ISNULL(CONVERT(NVARCHAR(MAX), @planID), '') + N'"'
            + N',"chassisNumber": "' + ISNULL(CONVERT(NVARCHAR(MAX), @CH), '') + N'"'
            + N',"periodMonths": "'  + ISNULL(CONVERT(NVARCHAR(MAX), @periodMonths), '') + N'"'
            + N',"nextDueDate": "'   + ISNULL(CONVERT(NVARCHAR(MAX), @nextDueDate, 121), '') + N'"'
            + N',"active": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @active), '') + N'"'
            + N',"idaraID_FK": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
            + N',"entryData": "'     + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
            + N',"hostName": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
            , @ActionType
            , ISNULL(@NewID, 0)
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0
            COMMIT;

        SELECT 1 AS IsSuccessful, N'تم حفظ خطة الصيانة الدورية بنجاح' AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END