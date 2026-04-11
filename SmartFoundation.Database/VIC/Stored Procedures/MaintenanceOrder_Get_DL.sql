
/* =========================================================
   Description:
   إرجاع بيانات رأس أمر الصيانة (Header) من جدول VIC.VehicleMaintenance حسب maintOrdID،
   ويشمل نوع الأمر، رقم الهيكل، تواريخ البداية/النهاية، الوصف، حالة التفعيل وحقول التدقيق.
   Type: READ (GET)
========================================================= */

CREATE   PROCEDURE [VIC].[MaintenanceOrder_Get_DL]
(
      @maintOrdID INT
    , @idaraID_FK NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @maintOrdID IS NULL OR @maintOrdID <= 0
        THROW 50001, N'maintOrdID مطلوب', 1;

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- تحقق وجود أمر الصيانة + فلترة الإدارة إن تم تمريرها
    IF NOT EXISTS
    (
        SELECT 1
        FROM VIC.VehicleMaintenance AS m
        WHERE m.MaintOrdID = @maintOrdID
          AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)
    )
        THROW 50001, N'أمر الصيانة غير موجود أو لا يطابق الإدارة', 1;

    SELECT
          m.MaintOrdID
        , m.MaintOrdTypeID_FK
        , m.chassisNumber_FK
        , m.MaintOrdStartDate
        , m.MaintOrdEndDate
        , m.MaintOrdDesc
        , m.MaintOrdActive
        , m.entryDate
        , m.entryData
        , m.hostName
    FROM VIC.VehicleMaintenance AS m
    WHERE m.MaintOrdID = @maintOrdID
      AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG);
END