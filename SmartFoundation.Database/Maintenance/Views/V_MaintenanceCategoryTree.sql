
CREATE   VIEW [Maintenance].[V_MaintenanceCategoryTree]
AS
WITH CategoryTree AS
(
    SELECT
        [IdaraId_FK] AS [IdaraId],
        [MaintenanceCategoryID],
        [ParentID],
        [CategoryName_A],
        [CategoryName_E],
        CAST(0 AS INT) AS [LevelNo],
        CAST([CategoryName_A] AS NVARCHAR(MAX)) AS [FullPath_A],
        [DisplayOrder],
        [IsActive]
    FROM [Maintenance].[MaintenanceCategory]
    WHERE [ParentID] IS NULL

    UNION ALL

    SELECT
        child.[IdaraId_FK] AS [IdaraId],
        child.[MaintenanceCategoryID],
        child.[ParentID],
        child.[CategoryName_A],
        child.[CategoryName_E],
        parent.[LevelNo] + 1 AS [LevelNo],
        CAST(parent.[FullPath_A] + N' / ' + child.[CategoryName_A] AS NVARCHAR(MAX)) AS [FullPath_A],
        child.[DisplayOrder],
        child.[IsActive]
    FROM [Maintenance].[MaintenanceCategory] AS child
    INNER JOIN CategoryTree AS parent
        ON parent.[IdaraId] = child.[IdaraId_FK]
        AND parent.[MaintenanceCategoryID] = child.[ParentID]
)
SELECT
    [IdaraId],
    [MaintenanceCategoryID],
    [ParentID],
    [CategoryName_A],
    [CategoryName_E],
    [LevelNo],
    [FullPath_A],
    [DisplayOrder],
    [IsActive],
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM [Maintenance].[MaintenanceCategory] AS child
            WHERE child.[IdaraId_FK] = CategoryTree.[IdaraId]
              AND child.[ParentID] = CategoryTree.[MaintenanceCategoryID]
              AND child.[IsActive] = 1
        )
        THEN 1
        ELSE 0
    END AS [HasChildren]
FROM CategoryTree;

GO

