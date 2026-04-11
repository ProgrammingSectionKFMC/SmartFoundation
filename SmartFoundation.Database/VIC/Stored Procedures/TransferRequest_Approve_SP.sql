
/* =========================================================
   (C) TransferRequest_Approve_SP
   - يمنع التفعيل إذا يوجد طلب نشط آخر لنفس المركبة داخل نفس الإدارة
========================================================= */
CREATE   PROCEDURE [VIC].[TransferRequest_Approve_SP]
(
      @requestID  INT
    , @actionBy   INT
    , @note       NVARCHAR(1000) = NULL
    , @hostName   NVARCHAR(400) = NULL
    , @idaraID_FK NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @requestID IS NULL OR @requestID <= 0
        THROW 50001, N'requestID مطلوب', 1;

    IF @actionBy IS NULL OR @actionBy <= 0
        THROW 50001, N'actionBy مطلوب', 1;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    IF @IdaraID_BIG IS NULL
        THROW 50001, N'idaraID_FK مطلوب', 1;

    DECLARE @CH NVARCHAR(100);

    BEGIN TRY
        IF @tc = 0 BEGIN TRAN;

        SELECT @CH = r.chassisNumber_FK
        FROM VIC.VehicleTransferRequest r
        WHERE r.RequestID = @requestID
          AND r.IdaraID_FK = @IdaraID_BIG;

        IF @CH IS NULL
            THROW 50001, N'الطلب غير موجود أو لا يطابق الإدارة', 1;

        IF EXISTS
        (
            SELECT 1
            FROM VIC.VehicleTransferRequest r
            WHERE r.chassisNumber_FK = @CH
              AND r.IdaraID_FK = @IdaraID_BIG
              AND ISNULL(r.active, 0) = 1
              AND r.RequestID <> @requestID
        )
            THROW 50001, N'يوجد طلب نقل نشط لهذه المركبة، أغلقه أولاً', 1;

        UPDATE VIC.VehicleTransferRequest
        SET
              active      = 1
            , aproveNote  = CASE WHEN @note IS NULL THEN aproveNote ELSE LEFT(@note, 400) END
            , entryDate   = GETDATE()
            , entryData   = CONVERT(NVARCHAR(40), @actionBy)
            , hostName    = @hostName
        WHERE RequestID = @requestID
          AND IdaraID_FK = @IdaraID_BIG;

        IF @@ROWCOUNT <= 0
            THROW 50002, N'لم يتم تحديث أي سجل', 1; -- CHANGED (50002)

        INSERT INTO VIC.VehicleTransferRequestHistory
        (
              RequestID_FK
            , Status
            , ActionBy
            , ActionDate
            , Notes
            , hostName
            , entryDate
            , entryData
        )
        VALUES
        (
              @requestID
            , N'Approved'
            , @actionBy
            , GETDATE()
            , @note
            , @hostName
            , GETDATE()
            , CONVERT(NVARCHAR(40), @actionBy)
        );

        IF @tc = 0 COMMIT;

        SELECT 1 AS IsSuccessful, N'تم اعتماد الطلب' AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END