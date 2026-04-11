
/* =========================================================
   Description:
   إرجاع قائمة أنواع محاضر التسليم/الاستلام من جدول VIC.HandoverType
   مع إمكانية إرجاع الأنواع النشطة فقط عند تمرير @activeOnly = 1.
   Type: READ (LOOKUP_LIST)
========================================================= */

CREATE   PROCEDURE [VIC].[HandoverType_List_DL]
(
    @activeOnly BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
          ht.handOverTypeID
        , ht.handOverTypeName_A
        , ht.handOverTypeName_E
        , ht.active
    FROM VIC.HandoverType AS ht
    WHERE (@activeOnly = 0 OR ht.active = 1)
    ORDER BY ht.handOverTypeName_A;
END