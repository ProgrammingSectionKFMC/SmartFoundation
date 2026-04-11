
/* =========================================================
   Description:
   جلب سجل مخالفة واحد حسب violationID
   مع إرجاع بيانات المركبة الأساسية ونوع المخالفة.
   - تمت إضافة vehicleID داخليًا
   Type: READ (GET)
========================================================= */
CREATE PROCEDURE [VIC].[Violation_Get_DL]
(
      @violationID  INT
    , @idaraID_FK   NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    IF @violationID IS NULL OR @violationID <= 0
        THROW 50001, N'violationID مطلوب', 1;

    SELECT
          vln.violationID
        , vh.vehicleID
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
        , vln.IdaraID_FK

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
    WHERE vln.violationID = @violationID
      AND (@IdaraID_BIG IS NULL OR vln.IdaraID_FK = @IdaraID_BIG);
END