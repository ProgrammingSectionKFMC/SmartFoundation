
/* =========================================================
   (E) TransferRequest_Reject_SP  (تعطيل + History Rejected)
========================================================= */
CREATE PROCEDURE [VIC].[TransferRequest_Reject_SP]
(
      @requestID  INT
    , @actionBy   INT
    , @note       NVARCHAR(1000)
    , @hostName   NVARCHAR(400)
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

    BEGIN TRY
        IF @tc = 0 BEGIN TRAN;

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.VehicleTransferRequest r
            WHERE r.RequestID = @requestID
              AND (@IdaraID_BIG IS NULL OR r.IdaraID_FK = @IdaraID_BIG)
        )
            THROW 50001, N'الطلب غير موجود أو لا يطابق الإدارة', 1;

        UPDATE VIC.VehicleTransferRequest
        SET
              active      = 0
            , aproveNote  = CASE WHEN @note IS NULL THEN aproveNote ELSE LEFT(@note, 400) END
            , entryDate   = GETDATE()
            , entryData   = CONVERT(NVARCHAR(40), @actionBy)
            , hostName    = @hostName
        WHERE RequestID = @requestID
          AND (@IdaraID_BIG IS NULL OR IdaraID_FK = @IdaraID_BIG); -- CHANGED (Idara filter)

        IF @@ROWCOUNT <= 0
            THROW 50002, N'لم يتم تحديث أي سجل', 1;

        INSERT INTO VIC.VehicleTransferRequestHistory
        (
              RequestID_FK
            , Status
            , ActionBy
            , ActionDate
            , Notes
            , hostName
            , entryDate      -- ADDED (Unify History)
            , entryData      -- ADDED (Unify History)
        )
        VALUES
        (
              @requestID
            , N'Rejected'
            , @actionBy
            , GETDATE()
            , @note
            , @hostName
            , GETDATE()                         -- ADDED
            , CONVERT(NVARCHAR(40), @actionBy)  -- ADDED
        );

        IF @tc = 0 COMMIT;

        SELECT 1 AS IsSuccessful, N'تم رفض الطلب' AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END