
CREATE   PROCEDURE [Maintenance].[MaintenanceCategoryDL]
      @pageName_ NVARCHAR(400)
    , @idaraID BIGINT
    , @entryData NVARCHAR(20)
    , @hostName NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    --                    MaintenanceCategory

    SELECT
          t.[IdaraId]
        , t.[MaintenanceCategoryID]
        , t.[ParentID]
        , t.[CategoryName_A]
        , t.[CategoryName_E]
        , t.[FullPath_A]
        , CASE
              WHEN t.[LevelNo] = 0 THEN N'مستوى رئيسي'
              ELSE N'مستوى فرعي ' + CAST(t.[LevelNo] AS NVARCHAR)
          END AS [LevelNo]
        , t.[LevelNo] AS [levelInt]
        , t.[DisplayOrder]
        , t.[IsActive]
        , t.[HasChildren]
        , ISNULL(routing.[ResponsibleDSDID], 0) AS [ResponsibleDSDID]
        , ISNULL
          (
              COALESCE
              (
                  NULLIF
                  (
                      LTRIM(RTRIM
                      (
                          CONCAT
                          (
                              ISNULL(dept.[deptName_A], N''),
                              CASE WHEN sec.[secName_A] IS NOT NULL THEN N' / ' + sec.[secName_A] ELSE N'' END,
                              CASE WHEN div.[divName_A] IS NOT NULL THEN N' / ' + div.[divName_A] ELSE N'' END
                          )
                      )),
                      N''
                  ),
                  N'جهة رقم ' + CONVERT(NVARCHAR(30), dsd.[DSDID])
              ),
              N'لايوجد جهة مسؤولة'
          ) AS [DSDName_A]
    FROM [Maintenance].[V_MaintenanceCategoryTree] AS t
    LEFT JOIN [Maintenance].[MaintenanceCategoryRouting] AS routing
        ON routing.[MaintenanceCategoryID] = t.[MaintenanceCategoryID]
        AND routing.[IdaraId_FK] = t.[IdaraId]
        AND routing.[IsActive] = 1
        AND routing.[IsDefault] = 1
    LEFT JOIN [dbo].[DeptSecDiv] AS dsd
        ON dsd.[DSDID] = routing.[ResponsibleDSDID]
    LEFT JOIN [dbo].[Department] AS dept
        ON dept.[deptID] = dsd.[deptID_FK]
    LEFT JOIN [dbo].[Section] AS sec
        ON sec.[secID] = dsd.[secID_FK]
    LEFT JOIN [dbo].[Divison] AS div
        ON div.[divID] = dsd.[divID_FK]
    WHERE t.[IdaraId] = @idaraID
      AND t.[IsActive] = 1
    ORDER BY t.[FullPath_A],t.[DisplayOrder], t.[MaintenanceCategoryID];

    SELECT
          [MaintenanceCategoryID]
        , [FullPath_A]
    FROM [Maintenance].[V_MaintenanceCategoryTree]
    WHERE [IdaraId] = @idaraID
      AND [IsActive] = 1
    ORDER BY [FullPath_A],[MaintenanceCategoryID];

    SELECT
          dsd.[DSDID]
        , COALESCE
          (
              NULLIF
              (
                  LTRIM(RTRIM
                  (
                      CONCAT
                      (
                          ISNULL(dept.[deptName_A], N''),
                          CASE WHEN sec.[secName_A] IS NOT NULL THEN N' / ' + sec.[secName_A] ELSE N'' END,
                          CASE WHEN div.[divName_A] IS NOT NULL THEN N' / ' + div.[divName_A] ELSE N'' END
                      )
                  )),
                  N''
              ),
              N'جهة رقم ' + CONVERT(NVARCHAR(30), dsd.[DSDID])
          ) AS [DSDName_A]
        , dept.[deptName_A]
        , sec.[secName_A]
        , div.[divName_A]
    FROM [dbo].[DeptSecDiv] AS dsd
    LEFT JOIN [dbo].[Department] AS dept
        ON dept.[deptID] = dsd.[deptID_FK]
    LEFT JOIN [dbo].[Section] AS sec
        ON sec.[secID] = dsd.[secID_FK]
    LEFT JOIN [dbo].[Divison] AS div
        ON div.[divID] = dsd.[divID_FK]
    WHERE dsd.[idaraID_FK] = @idaraID
    ORDER BY [DSDName_A], dsd.[DSDID];

    SELECT
          routing.[MaintenanceCategoryRoutingID]
        , routing.[IdaraId_FK]
        , routing.[MaintenanceCategoryID]
        , category.[CategoryName_A] AS [MaintenanceCategoryName_A]
        , category.[FullPath_A] AS [MaintenanceCategoryFullPath_A]
        , routing.[ResponsibleDSDID]
        , COALESCE
          (
              NULLIF
              (
                  LTRIM(RTRIM
                  (
                      CONCAT
                      (
                          ISNULL(dept.[deptName_A], N''),
                          CASE WHEN sec.[secName_A] IS NOT NULL THEN N' / ' + sec.[secName_A] ELSE N'' END,
                          CASE WHEN div.[divName_A] IS NOT NULL THEN N' / ' + div.[divName_A] ELSE N'' END
                      )
                  )),
                  N''
              ),
              N'جهة رقم ' + CONVERT(NVARCHAR(30), routing.[ResponsibleDSDID])
          ) AS [ResponsibleDSDName_A]
        , routing.[IsDefault]
        , routing.[Notes]
        , routing.[IsActive]
    FROM [Maintenance].[MaintenanceCategoryRouting] AS routing
    LEFT JOIN [Maintenance].[V_MaintenanceCategoryTree] AS category
        ON category.[IdaraId] = routing.[IdaraId_FK]
        AND category.[MaintenanceCategoryID] = routing.[MaintenanceCategoryID]
    LEFT JOIN [dbo].[DeptSecDiv] AS dsd
        ON dsd.[DSDID] = routing.[ResponsibleDSDID]
    LEFT JOIN [dbo].[Department] AS dept
        ON dept.[deptID] = dsd.[deptID_FK]
    LEFT JOIN [dbo].[Section] AS sec
        ON sec.[secID] = dsd.[secID_FK]
    LEFT JOIN [dbo].[Divison] AS div
        ON div.[divID] = dsd.[divID_FK]
    WHERE routing.[IdaraId_FK] = @idaraID
    ORDER BY category.[FullPath_A], routing.[MaintenanceCategoryRoutingID];
END

GO

