
/* =========================================================
   Description:
   إرجاع قائمة أنواع وثائق المركبات من جدول VIC.VehiclesDocumentType
   لاستخدامها في الشاشات (Lookup/Dropdown)، مع خيار إرجاع النشطة فقط.
   Type: READ (LOOKUP_LIST)
========================================================= */

CREATE     PROCEDURE [VIC].[VehicleDocumentType_List_DL]
(
      @ActiveOnly BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
          t.vehicleDocumentTypeID
        , t.vehicleDocumentTypeName_A
        , t.vehicleDocumentTypeName_E
        , t.vehicleDocumentTypeActive
    FROM VIC.VehiclesDocumentType AS t
    WHERE (@ActiveOnly = 0 OR t.vehicleDocumentTypeActive = 1)
    ORDER BY t.vehicleDocumentTypeName_A ASC;
END