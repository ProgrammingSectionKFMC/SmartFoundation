
/* =========================================================
   Description:
   إرجاع قائمة أنواع طلبات نقل المركبات من جدول VIC.VehicleTransferRequestType
   مع خيار حصر النتائج على الأنواع النشطة فقط.
   Type: READ (LOOKUP_LIST)
========================================================= */

CREATE     PROCEDURE [VIC].[TransferRequestType_List_DL]
(
    @activeOnly BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
          t.VehicleTransferRequestTypeID
        , t.VehicleTransferRequestTypeNameA
        , t.VehicleTransferRequestTypeNameE
        , t.Active
    FROM VIC.VehicleTransferRequestType AS t
    WHERE (@activeOnly = 0 OR t.Active = 1)
    ORDER BY t.VehicleTransferRequestTypeNameA;
END