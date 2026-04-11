
/* =========================================================
   Description:
   إرجاع تفاصيل طلب نقل مركبة واحد من جدول VIC.VehicleTransferRequest حسب requestID،
   ويشمل نوع الطلب، رقم الهيكل، الأطراف، الجهة، الملاحظات، حالة التفعيل وحقول التدقيق.
   Type: READ (GET)
========================================================= */

CREATE   PROCEDURE [VIC].[TransferRequest_Get_DL]
(
      @requestID  INT
    , @idaraID_FK NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @requestID IS NULL OR @requestID <= 0
        THROW 50001, N'requestID مطلوب', 1;

    -- معيار الإدارة (BIGINT)
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
          r.RequestID
        , r.RequestTypeID_FK
        , r.chassisNumber_FK
        , r.fromUserID_FK
        , r.toUserID_FK
        , r.deptID_FK
        , r.CreateByUser
        , r.aproveNote
        , r.active
        , r.entryDate
        , r.entryData
        , r.hostName
    FROM VIC.VehicleTransferRequest AS r
    WHERE r.RequestID = @requestID
      AND (@IdaraID_BIG IS NULL OR r.IdaraID_FK = @IdaraID_BIG);
END