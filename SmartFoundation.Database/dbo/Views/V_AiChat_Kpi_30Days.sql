CREATE   VIEW dbo.V_AiChat_Kpi_30Days
AS
SELECT
    COUNT(*) AS TotalChats,
    COUNT(DISTINCT UserId) AS UniqueUsers,
    SUM(CASE WHEN UserFeedback =  1 THEN 1 ELSE 0 END) AS ThumbsUp,
    SUM(CASE WHEN UserFeedback = -1 THEN 1 ELSE 0 END) AS ThumbsDown,
    AVG(CAST(ResponseTimeMs AS FLOAT)) AS AvgResponseTimeMs,
    AVG(CASE WHEN ISNULL(CitationsCount,0) > 0 THEN 1.0 ELSE 0.0 END) * 100 AS CitationCoveragePct
FROM dbo.AiChatHistory
WHERE CreatedAt >= DATEADD(DAY, -30, SYSDATETIME());
