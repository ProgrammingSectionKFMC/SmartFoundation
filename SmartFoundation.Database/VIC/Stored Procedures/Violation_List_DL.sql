
/* =========================================================
   Description:
   قائمة المخالفات مع فلاتر اختيارية (شاصي/نوع/مدفوعة/نطاق تاريخ)
   وإرجاع اسم النوع من TypesRoot + بيانات المركبة مع Paging.
   - تمت إضافة vehicleID داخليًا
   - تمت إضافة حالة السداد المحسوبة
   Type: READ (LIST)
========================================================= */
CREATE PROCEDURE [VIC].[Violation_List_DL]
(
      @chassisNumber   NVARCHAR(100) = NULL
    , @violationTypeID INT = NULL
    , @Paid            BIT = NULL      -- 1=مدفوعة, 0=غير مدفوعة
    , @FromDate        DATE = NULL
    , @ToDate          DATE = NULL
    , @Page            INT = 1
    , @PageSize        INT = 50
    , @idaraID_FK      NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @P  INT = CASE WHEN @Page IS NULL OR @Page < 1 THEN 1 ELSE @Page END;
    DECLARE @PS INT = CASE WHEN @PageSize IS NULL OR @PageSize < 1 OR @PageSize > 200 THEN 50 ELSE @PageSize END;
    DECLARE @Skip INT = (@P - 1) * @PS;

    DECLARE @CH NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    SELECT
          vln.violationID
        , vh.vehicleID                              -- داخلي فقط
        , vln.violationTypeRoot_FK
        , vln.chassisNumber_FK
        , vln.violationDate
        , vln.violationPrice
        , vln.violationLocation
        , vln.PaymentDate
        , vln.entryPayment
        , vln.entryDate
        , vln.entryData
        , vln.hostName

        , CASE WHEN vln.PaymentDate IS NULL THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END AS IsPaid
        , CASE WHEN vln.PaymentDate IS NULL THEN N'غير مسددة' ELSE N'مسددة' END AS PaymentStatusName_A

        , tr.typesName_A AS ViolationTypeName_A
        , tr.typesName_E AS ViolationTypeName_E

        , vh.plateLetters
        , vh.plateNumbers
        , vh.yearModel
        , vh.armyNumber
    FROM VIC.Violations AS vln
    INNER JOIN VIC.TypesRoot AS tr
        ON tr.typesID = vln.violationTypeRoot_FK
    LEFT JOIN VIC.Vehicles AS vh
        ON vh.chassisNumber = vln.chassisNumber_FK
    WHERE 1 = 1
      AND (@IdaraID_BIG IS NULL OR vln.IdaraID_FK = @IdaraID_BIG)
      AND (@CH IS NULL OR vln.chassisNumber_FK = @CH)
      AND (@violationTypeID IS NULL OR vln.violationTypeRoot_FK = @violationTypeID)
      AND (
            @Paid IS NULL
            OR (@Paid = 1 AND vln.PaymentDate IS NOT NULL)
            OR (@Paid = 0 AND vln.PaymentDate IS NULL)
          )
      AND (@FromDate IS NULL OR vln.violationDate >= @FromDate)
      AND (@ToDate   IS NULL OR vln.violationDate < DATEADD(DAY, 1, @ToDate))
    ORDER BY
        vln.violationDate DESC,
        vln.violationID DESC
    OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;
END