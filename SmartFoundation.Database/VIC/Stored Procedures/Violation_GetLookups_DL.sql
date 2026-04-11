
/* =========================================================
   Description:
   إرجاع قائمة أنواع المخالفات من VIC.TypesRoot
   تحت Root ثابت = 257
   مع خيار إرجاع النشطة فقط.
   Type: READ (LOOKUP_LIST)
========================================================= */
CREATE PROCEDURE [VIC].[Violation_GetLookups_DL]
(
      @ActiveOnly BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
          t.typesID
        , t.typesName_A
        , t.typesName_E
        , t.typesActive
    FROM VIC.TypesRoot AS t
    WHERE t.typesRoot_ParentID = 257
      AND (@ActiveOnly = 0 OR t.typesActive = 1)
    ORDER BY t.typesName_A;
END