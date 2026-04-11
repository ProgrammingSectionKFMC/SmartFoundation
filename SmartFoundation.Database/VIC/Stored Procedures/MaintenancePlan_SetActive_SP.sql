
/* =========================================================
   Description:
   تفعيل أو تعطيل خطة الصيانة الدورية في جدول VIC.VehicleMaintenancePlan.
   Type: WRITE (SETACTIVE)
========================================================= */

CREATE   PROCEDURE [VIC].[MaintenancePlan_SetActive_SP]
(
      @planID       INT
    , @active       BIT
    , @idaraID_FK   NVARCHAR(10) = NULL
    , @entryData    NVARCHAR(40)
    , @hostName     NVARCHAR(400)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE
          @ChassisNumber NVARCHAR(100)
        , @Note_Audit NVARCHAR(MAX) = NULL;

    BEGIN TRY

        IF @tc = 0
            BEGIN TRAN;

        IF @planID IS NULL OR @planID <= 0
            THROW 50001, N'planID غير صحيح', 1;

        -- تحقق وجود الخطة + مطابقة الإدارة
        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.VehicleMaintenancePlan p
            WHERE p.PlanID = @planID
              AND (@IdaraID_BIG IS NULL OR p.IdaraID_FK = @IdaraID_BIG)
        )
            THROW 50001, N'الخطة غير موجودة أو لا تطابق الإدارة', 1;

        -- جلب بيانات قبل التحديث (للاستخدام لاحقًا)
        SELECT
              @ChassisNumber = p.chassisNumber_FK
        FROM VIC.VehicleMaintenancePlan p
        WHERE p.PlanID = @planID;

        -- التحديث
        UPDATE VIC.VehicleMaintenancePlan
        SET
              planActive = @active
            , entryDate  = GETDATE()
            , entryData  = @entryData
            , hostName   = @hostName
        WHERE PlanID = @planID;

        IF @@ROWCOUNT <= 0
            THROW 50002, N'لم يتم تحديث أي سجل', 1;

        -- ADDED (AuditLog)
        SET @Note_Audit = N'{'
            + N'"planID": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @planID), '') + N'"'
            + N',"chassisNumber": "'+ ISNULL(CONVERT(NVARCHAR(MAX), @ChassisNumber), '') + N'"'
            + N',"active": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @active), '') + N'"'
            + N',"idaraID_FK": "'   + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
            + N',"entryData": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
            + N',"hostName": "'     + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
            , N'SETACTIVE'
            , @planID
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0
            COMMIT;

        SELECT 1 AS IsSuccessful,
               CASE WHEN @active = 1 
                    THEN N'تم تفعيل الخطة بنجاح'
                    ELSE N'تم تعطيل الخطة بنجاح'
               END AS Message_;

    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END