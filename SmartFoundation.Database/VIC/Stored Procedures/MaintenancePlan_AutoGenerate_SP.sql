
/* =========================================================
   Description:
   إنشاء أوامر الصيانة الدورية تلقائيًا للمركبات المستحقة حسب جدول
   VIC.VehicleMaintenancePlan، مع منع التكرار إذا كان هناك أمر دوري مفتوح.
   Type: WRITE (AUTO GENERATE)
========================================================= */

CREATE PROCEDURE [VIC].[MaintenancePlan_AutoGenerate_SP]
(
      @idaraID_FK NVARCHAR(10) = NULL
    , @entryData  NVARCHAR(40) = NULL
    , @hostName   NVARCHAR(400) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE @Now DATETIME = GETDATE();
    DECLARE @InsertedCount INT = 0;

    BEGIN TRY
        IF @tc = 0
            BEGIN TRAN;

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
        SELECT
              265
            , p.chassisNumber_FK
            , @Now
            , NULL
            , N'صيانة دورية تلقائية'
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
          );

        SET @InsertedCount = @@ROWCOUNT;

        IF @tc = 0
            COMMIT;

        SELECT
              CAST(1 AS BIT) AS IsSuccessful
            , N'تم تنفيذ التوليد الآلي لأوامر الصيانة الدورية بنجاح' AS Message_
            , @InsertedCount AS InsertedCount;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END