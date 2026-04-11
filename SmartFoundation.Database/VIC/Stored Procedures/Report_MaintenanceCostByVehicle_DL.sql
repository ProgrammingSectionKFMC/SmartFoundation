
/* =========================================================
   Description:
   تقرير عدد أوامر الصيانة لكل مركبة خلال نطاق تاريخ اختياري،
   مع عرض عدد الأوامر وإرجاع إجمالي تكلفة افتراضي (0) لعدم توفر حقل تكلفة في الهيكل الحالي.
   Type: READ (REPORT)
========================================================= */

CREATE   PROCEDURE [VIC].[Report_MaintenanceCostByVehicle_DL]
(
      @fromDate   DATETIME = NULL
    , @toDate     DATETIME = NULL
    , @idaraID_FK NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    SELECT
          m.chassisNumber_FK AS chassisNumber
        , v.plateLetters
        , v.plateNumbers
        , COUNT(DISTINCT m.MaintOrdID) AS OrdersCount
        , CAST(0 AS DECIMAL(18,2)) AS TotalCost
        , N'التكلفة غير متاحة في هيكل الصيانة الحالي' AS Note
    FROM VIC.VehicleMaintenance m
    INNER JOIN VIC.Vehicles v
        ON v.chassisNumber = m.chassisNumber_FK
    WHERE (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)
      AND (@fromDate IS NULL OR m.MaintOrdStartDate >= @fromDate)
      AND (@toDate   IS NULL OR m.MaintOrdStartDate <= @toDate)
    GROUP BY
          m.chassisNumber_FK
        , v.plateLetters
        , v.plateNumbers;
END