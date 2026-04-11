
/* =========================================================
   Description:
   إرجاع قائمة أنواع الجذور (TypesRoot) مع فلترة اختيارية حسب:
   - ParentID (جذر/فرعي)
   - ActiveOnly (النشط فقط)
   - Search (بحث بالاسم عربي/إنجليزي)
   Type: READ (LOOKUP_LIST / LIST)
========================================================= */

CREATE     PROCEDURE [VIC].[TypesRoot_List_DL]
(
      @parentID   INT = NULL
    , @activeOnly BIT = 0
    , @search     NVARCHAR(200) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @S NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@search)), N'');

    SELECT
          t.typesID
        , t.typesName_A
        , t.typesName_E
        , t.typesDesc
        , t.typesActive
        , t.typesStartDate
        , t.typesEndDate
        , t.typesRoot_ParentID
    FROM VIC.TypesRoot AS t
    WHERE 1 = 1
      AND (
            (@parentID IS NULL AND t.typesRoot_ParentID IS NULL)
            OR
            (@parentID IS NOT NULL AND t.typesRoot_ParentID = @parentID)
          )
      AND (@activeOnly = 0 OR t.typesActive = 1)
      AND (
            @S IS NULL
            OR t.typesName_A LIKE N'%' + @S + N'%'
            OR t.typesName_E LIKE N'%' + @S + N'%'
          )
    ORDER BY t.typesName_A;
END