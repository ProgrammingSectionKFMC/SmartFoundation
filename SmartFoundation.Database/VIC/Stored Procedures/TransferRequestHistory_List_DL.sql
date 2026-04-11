

/* =========================================================
   VIC.TransferRequestHistory_List_DL (Optionally show entryDate/entryData)
========================================================= */
CREATE PROCEDURE [VIC].[TransferRequestHistory_List_DL]
(
      @requestID  INT
    , @idaraID_FK NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @requestID IS NULL OR @requestID <= 0
        THROW 50001, N'requestID مطلوب', 1;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    IF NOT EXISTS
    (
        SELECT 1
        FROM VIC.VehicleTransferRequest r
        WHERE r.RequestID = @requestID
          AND (@IdaraID_BIG IS NULL OR r.IdaraID_FK = @IdaraID_BIG)
    )
        THROW 50001, N'الطلب غير موجود أو لا يطابق الإدارة', 1;

    SELECT
          h.HistoryID
        , h.RequestID_FK
        , h.Status
        , h.ActionBy
        , h.ActionDate
        , h.Notes
        , h.hostName
        , h.entryDate
        , h.entryData
    FROM VIC.VehicleTransferRequestHistory AS h
    WHERE h.RequestID_FK = @requestID
    ORDER BY h.ActionDate ASC, h.HistoryID ASC;
END