
/* =========================================================
   Description:
   إرجاع تفاصيل محضر تسليم/استلام واحد حسب VehicleHandoverID،
   مع بيانات نوع المحضر (HandoverType) وبيانات طلب النقل المرتبط (VehicleTransferRequest).
   + التحقق من الإدارة (IdaraID_FK) بمعيار BIGINT.
   Type: READ (GET)
========================================================= */

CREATE   PROCEDURE [VIC].[Handover_Get_DL]
(
      @vehicleHandoverID INT
    , @idaraID_FK        NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    BEGIN TRY

        IF @tc = 0 BEGIN TRAN;

        /* ===== Business Validation ===== */

        IF @vehicleHandoverID IS NULL OR @vehicleHandoverID <= 0
            THROW 50001, N'vehicleHandoverID مطلوب', 1;

        IF NOT EXISTS (
            SELECT 1
            FROM VIC.VehicleHandover h
            WHERE h.VehicleHandoverID = @vehicleHandoverID
        )
            THROW 50001, N'المحضر غير موجود', 1;

        IF @IdaraID_BIG IS NOT NULL
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM VIC.VehicleHandover h
                WHERE h.VehicleHandoverID = @vehicleHandoverID
                  AND h.IdaraID_FK = @IdaraID_BIG
            )
                THROW 50001, N'المحضر لا يتبع نفس الإدارة', 1;
        END

        /* ===== Query ===== */

        SELECT
              h.VehicleHandoverID
            , h.RequestID_FK
            , h.handOverTypeID_FK
            , h.handoverDate
            , h.note
            , h.entryDate
            , h.entryData
            , h.hostName
            , h.IdaraID_FK

            , t.handOverTypeName_A
            , t.handOverTypeName_E
            , t.active AS handOverTypeActive

            , r.RequestID
            , r.chassisNumber_FK
            , r.fromUserID_FK
            , r.toUserID_FK
            , r.deptID_FK
            , r.active AS RequestActive
            , r.entryDate AS RequestEntryDate
        FROM VIC.VehicleHandover AS h
        INNER JOIN VIC.HandoverType AS t
            ON t.handOverTypeID = h.handOverTypeID_FK
        INNER JOIN VIC.VehicleTransferRequest AS r
            ON r.RequestID = h.RequestID_FK
        WHERE h.VehicleHandoverID = @vehicleHandoverID;

        IF @tc = 0 COMMIT;

    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END