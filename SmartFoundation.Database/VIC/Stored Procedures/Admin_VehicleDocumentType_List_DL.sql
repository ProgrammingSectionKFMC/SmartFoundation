
/* =========================================================
   Description:
   إرجاع قائمة أنواع مستندات المركبات من جدول VIC.VehiclesDocumentType
   مع إمكانية تصفية الأنواع النشطة فقط عند تمرير @ActiveOnly = 1.
   Type: READ (LOOKUP_LIST)
========================================================= */

CREATE   PROCEDURE [VIC].[Admin_VehicleDocumentType_List_DL]
(
    @ActiveOnly BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SELECT
          dt.vehicleDocumentTypeID
        , dt.vehicleDocumentTypeName_A
        , dt.vehicleDocumentTypeName_E
        , dt.vehicleDocumentTypeActive
    FROM VIC.VehiclesDocumentType AS dt
    WHERE (@ActiveOnly = 0 OR dt.vehicleDocumentTypeActive = 1)
    ORDER BY dt.vehicleDocumentTypeName_A;
END