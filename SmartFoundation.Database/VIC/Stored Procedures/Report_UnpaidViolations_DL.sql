
/* =========================================================
   Description:
   تقرير المخالفات غير المسددة من جدول VIC.Violations مع فلاتر اختيارية
   حسب رقم الهيكل ونطاق التاريخ، وإظهار نوع المخالفة من VIC.TypesRoot.
   Type: READ (REPORT)
========================================================= */

CREATE   PROCEDURE [VIC].[Report_UnpaidViolations_DL]
(
      @chassisNumber NVARCHAR(100) = NULL
    , @fromDate      DATE = NULL
    , @toDate        DATE = NULL
    , @idaraID_FK    NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CH NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    /* ملاحظة: هذه النسخة تتطلب أن يكون اسم عمود رقم الهيكل ثابتًا في VIC.Violations (chassisNumber_FK). */
    SELECT
          v.violationID
        , v.chassisNumber_FK AS chassisNumber
        , v.violationDate
        , v.violationPrice
        , v.violationLocation
        , v.violationTypeRoot_FK
        , t.typesName_A
    FROM VIC.Violations v
    INNER JOIN VIC.TypesRoot t
        ON t.typesID = v.violationTypeRoot_FK
    WHERE v.PaymentDate IS NULL
      AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
      AND (@CH IS NULL OR v.chassisNumber_FK = @CH)
      AND (@fromDate IS NULL OR v.violationDate >= @fromDate)
      AND (@toDate   IS NULL OR v.violationDate <= @toDate)
    ORDER BY v.violationDate DESC;
END