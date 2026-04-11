
/* =========================================================
   (D) TransferRequest_Close_SP
   - يغلق الطلب (active=0)
   - History Closed مع منع تكرار Closed كآخر حالة
========================================================= */
CREATE   PROCEDURE [VIC].[TransferRequest_Close_SP]
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

    DECLARE @Now DATETIME = GETDATE();
    DECLARE @EntryData NVARCHAR(20) = LEFT(CONVERT(NVARCHAR(40), @actionBy), 20);

    BEGIN TRY
        IF @tc = 0 BEGIN TRAN;

        IF NOT EXISTS (
            SELECT 1
            FROM VIC.VehicleTransferRequest
            WHERE RequestID = @requestID
              AND ISNULL(active,0) = 1
              AND (@IdaraID_BIG IS NULL OR IdaraID_FK = @IdaraID_BIG)
        )
            THROW 50001, N'الطلب غير موجود أو غير نشط', 1;

        UPDATE VIC.VehicleTransferRequest
        SET
              active      = 0
            , aproveNote  = CASE WHEN @note IS NULL THEN aproveNote ELSE LEFT(@note,200) END
            , entryDate   = @Now
            , entryData   = @EntryData
            , hostName    = LEFT(@hostName,200)
        WHERE RequestID = @requestID
          AND (@IdaraID_BIG IS NULL OR IdaraID_FK = @IdaraID_BIG);

        IF @@ROWCOUNT <= 0
            THROW 50002, N'لم يتم تحديث أي سجل', 1; -- ADDED (50002)

        IF NOT EXISTS (
            SELECT 1
            FROM VIC.VehicleTransferRequestHistory h
            WHERE h.RequestID_FK = @requestID
              AND h.HistoryID = (
                    SELECT MAX(HistoryID)
                    FROM VIC.VehicleTransferRequestHistory
                    WHERE RequestID_FK = @requestID
              )
              AND h.Status = N'Closed'
        )
        BEGIN
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
                , N'Closed'
                , @actionBy
                , @Now
                , LEFT(@note,1000)
                , LEFT(@hostName,200)
                , @Now
                , @EntryData
            );
        END

        IF @tc = 0 COMMIT;

        SELECT 1 AS IsSuccessful, N'تم إغلاق الطلب' AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END