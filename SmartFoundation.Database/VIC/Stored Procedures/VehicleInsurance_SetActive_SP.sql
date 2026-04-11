
/* =========================================================
   Description:
   تغيير حالة تأمين محدد (active) في VIC.VehicleInsurance.
   - عند تفعيل سجل (@active=1): يتم إلغاء تفعيل باقي تأمينات نفس المركبة.
   - يحدث حقول التدقيق entryDate/entryData/hostName.
   Type: WRITE (SETACTIVE)
========================================================= */
CREATE PROCEDURE [VIC].[VehicleInsurance_SetActive_SP]
(
      @VehicleInsuranceID INT
    , @active             BIT
    , @idaraID_FK         NVARCHAR(10) = NULL
    , @entryData          NVARCHAR(40)
    , @hostName           NVARCHAR(400)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @CH NVARCHAR(100);

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- AuditLog
    DECLARE @Note_Audit NVARCHAR(MAX) = NULL;

    BEGIN TRY
        IF @VehicleInsuranceID IS NULL OR @VehicleInsuranceID <= 0
            THROW 50001, N'VehicleInsuranceID مطلوب', 1;

        IF @active IS NULL
            THROW 50001, N'active مطلوب', 1;

        IF @IdaraID_BIG IS NULL
            THROW 50001, N'idaraID_FK مطلوب', 1;

        SELECT @CH = i.chassisNumber_FK
        FROM VIC.VehicleInsurance AS i
        WHERE i.VehicleInsuranceID = @VehicleInsuranceID
          AND i.IdaraID_FK = @IdaraID_BIG;

        IF @CH IS NULL
            THROW 50001, N'سجل التأمين غير موجود أو لا يطابق الإدارة', 1;

        IF @tc = 0 BEGIN TRAN;

        IF @active = 1
        BEGIN
            UPDATE VIC.VehicleInsurance
            SET
                  active    = 0
                , entryDate = GETDATE()
                , entryData = @entryData
                , hostName  = @hostName
            WHERE chassisNumber_FK = @CH
              AND IdaraID_FK = @IdaraID_BIG
              AND VehicleInsuranceID <> @VehicleInsuranceID
              AND ISNULL(active, 0) = 1;
        END

        UPDATE VIC.VehicleInsurance
        SET
              active    = @active
            , entryDate = GETDATE()
            , entryData = @entryData
            , hostName  = @hostName
        WHERE VehicleInsuranceID = @VehicleInsuranceID
          AND IdaraID_FK = @IdaraID_BIG;

        IF @@ROWCOUNT <= 0
            THROW 50002, N'لم يتم تحديث السجل', 1;

        -- AuditLog (SETACTIVE)
        SET @Note_Audit = N'{'
            + N'"VehicleInsuranceID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @VehicleInsuranceID), '') + N'"'
            + N',"chassisNumber":"'     + ISNULL(CONVERT(NVARCHAR(MAX), @CH), '') + N'"'
            + N',"active":"'            + ISNULL(CONVERT(NVARCHAR(MAX), @active), '') + N'"'
            + N',"IdaraID_FK":"'         + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_BIG), '') + N'"'
            + N',"entryData":"'          + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
            + N',"hostName":"'           + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
            + N'}';

        INSERT INTO DATACORE.dbo.AuditLog
        (
              TableName, ActionType, RecordID, PerformedBy, Notes
        )
        VALUES
        (
              N'[VIC].[VehicleInsurance]'
            , N'SETACTIVE'
            , ISNULL(@VehicleInsuranceID, 0)
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0 COMMIT;

        SELECT 1 AS IsSuccessful, N'تم تحديث حالة التأمين' AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END