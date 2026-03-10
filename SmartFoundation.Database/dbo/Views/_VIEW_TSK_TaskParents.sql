CREATE   VIEW dbo._VIEW_TSK_TaskParents
AS
WITH hierarchy AS
(
    -- مستوى 1: المهام الجذرية (بدون أب)
    SELECT
        t.taskID,
        t.parentID_FK,
        CAST(NULL AS INT) AS parentTaskID,
        CAST(NULL AS INT) AS parentParentTaskID,
        1 AS taskLevel
    FROM dbo.TSK_Task AS t
    WHERE t.parentID_FK IS NULL

    UNION ALL

    -- المستويات التالية: نمرّر الأب والجد
    SELECT
        c.taskID,
        c.parentID_FK,
        h.taskID AS parentTaskID,
        h.parentTaskID AS parentParentTaskID,
        h.taskLevel + 1 AS taskLevel
    FROM dbo.TSK_Task AS c
    INNER JOIN hierarchy AS h
        ON c.parentID_FK = h.taskID
)
SELECT
    taskID,
    parentTaskID,
    parentParentTaskID,
    CASE WHEN taskLevel > 3 THEN 3 ELSE taskLevel END AS taskLevel
FROM hierarchy;
