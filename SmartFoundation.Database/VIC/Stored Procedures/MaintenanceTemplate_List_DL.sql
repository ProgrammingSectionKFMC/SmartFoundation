
/* =========================================================
   Description:
   قائمة بنود قالب الصيانة حسب نوع أمر الصيانة.
   Type: READ (LIST)
========================================================= */

CREATE   PROCEDURE [VIC].[MaintenanceTemplate_List_DL]
(
      @MaintOrdTypeID_FK INT = NULL
    , @active            BIT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
          mt.TemplateID
        , mt.MaintOrdTypeID_FK
        , mot.typesName_A AS MaintOrdTypeName_A
        , mt.typesID_FK
        , t.typesName_A   AS TemplateItemName_A
        , mt.TemplateOrder
        , mt.templateActive
        , mt.entryDate
        , mt.entryData
        , mt.hostName
    FROM VIC.MaintenanceTemplate mt
    LEFT JOIN VIC.TypesRoot mot
        ON mot.typesID = mt.MaintOrdTypeID_FK
    LEFT JOIN VIC.TypesRoot t
        ON t.typesID = mt.typesID_FK
    WHERE (@MaintOrdTypeID_FK IS NULL OR mt.MaintOrdTypeID_FK = @MaintOrdTypeID_FK)
      AND (@active IS NULL OR mt.templateActive = @active)
    ORDER BY
          mt.MaintOrdTypeID_FK
        , mt.TemplateOrder
        , mt.TemplateID;
END