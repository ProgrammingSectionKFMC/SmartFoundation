
/* =========================================================
   Description:
   إرجاع قائمة أوامر الصيانة من جدول VIC.VehicleMaintenance مع Paging،
   مع فلاتر اختيارية حسب رقم الهيكل، نوع الأمر، حالة التفعيل، ونطاق تاريخ البداية.
   Type: READ (LIST)
========================================================= */

CREATE   PROCEDURE [VIC].[MaintenanceOrder_List_DL]
(
      @chassisNumber   NVARCHAR(100) = NULL
    , @maintOrdTypeID  INT = NULL
    , @active          BIT = NULL
    , @fromDate        DATETIME = NULL
    , @toDate          DATETIME = NULL
    , @pageNumber      INT = 1
    , @pageSize        INT = 50
    , @idaraID_FK      NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @P  INT = CASE WHEN @pageNumber IS NULL OR @pageNumber < 1 THEN 1 ELSE @pageNumber END;
    DECLARE @PS INT = CASE WHEN @pageSize IS NULL OR @pageSize < 1 OR @pageSize > 200 THEN 50 ELSE @pageSize END;
    DECLARE @Skip INT = (@P - 1) * @PS;

    DECLARE @CH NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

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
    WHERE 1 = 1
      AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)
      AND (@CH IS NULL OR m.chassisNumber_FK = @CH)
      AND (@maintOrdTypeID IS NULL OR m.MaintOrdTypeID_FK = @maintOrdTypeID)
      AND (@active IS NULL OR m.MaintOrdActive = @active)
      AND (@fromDate IS NULL OR m.MaintOrdStartDate >= @fromDate)
      AND (@toDate   IS NULL OR m.MaintOrdStartDate < DATEADD(DAY, 1, @toDate))
    ORDER BY
        m.MaintOrdStartDate DESC,
        m.MaintOrdID DESC
    OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;
END