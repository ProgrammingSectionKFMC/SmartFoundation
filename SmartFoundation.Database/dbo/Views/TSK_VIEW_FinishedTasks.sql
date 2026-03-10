CREATE   VIEW dbo.TSK_VIEW_FinishedTasks
AS
WITH Hier AS
(
    -- ربط كل مهمة بأطفالها المباشرين (نشطة فقط)
    SELECT 
        p.taskID       AS rootTaskID,
        c.taskID       AS childTaskID
    FROM dbo.TSK_Task AS p
    INNER JOIN dbo.TSK_Task AS c
        ON c.parentID_FK = p.taskID
    WHERE p.isActive = 1
      AND c.isActive = 1

    UNION ALL

    -- توسيع للسلسلة: أحفاد وأحفاد الأحفاد... (نشطة فقط)
    SELECT
        h.rootTaskID,
        gc.taskID      AS childTaskID
    FROM Hier AS h
    INNER JOIN dbo.TSK_Task AS gc
        ON gc.parentID_FK = h.childTaskID
    WHERE gc.isActive = 1
),
Agg AS
(
    -- تجميع لكل rootTask: كم طفل/حفيد غير منتهٍ
    SELECT
        h.rootTaskID                     AS taskID,
        COUNT(*)                         AS totalDescendants,
        SUM(CASE WHEN t.taskStepID_FK IS NULL THEN 1 ELSE 0 END) AS unfinishedDescendants
    FROM Hier AS h
    INNER JOIN dbo.TSK_Task AS t
        ON t.taskID = h.childTaskID
    GROUP BY h.rootTaskID
)
SELECT 
    t.taskID,
    -- لو لا يوجد أحفاد/أطفال أو لا يوجد غير منتهين ⇒ 1
    CASE WHEN ISNULL(a.unfinishedDescendants, 0) = 0 THEN 1 ELSE 0 END AS itsChildrenFinished,
    ISNULL(a.totalDescendants, 0)         AS totalChildren,          -- اختياري: إجمالي الأطفال/الأحفاد
    ISNULL(a.unfinishedDescendants, 0)    AS unfinishedChildren      -- اختياري: غير المنتهين
FROM dbo.TSK_Task AS t
LEFT JOIN Agg AS a
    ON a.taskID = t.taskID;
