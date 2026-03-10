
CREATE PROCEDURE dbo.sp_AiChat_GetStatistics
    @FromDate DATETIME2 = NULL,
    @ToDate DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -30, GETDATE());
    IF @ToDate IS NULL SET @ToDate = GETDATE();
    
    -- إجمالي المحادثات
    SELECT 
        COUNT(*) AS TotalChats,
        COUNT(DISTINCT UserId) AS UniqueUsers,
        COUNT(CASE WHEN UserFeedback = 1 THEN 1 END) AS ThumbsUp,
        COUNT(CASE WHEN UserFeedback = -1 THEN 1 END) AS ThumbsDown,
        AVG(ResponseTimeMs) AS AvgResponseTimeMs,
        MAX(ResponseTimeMs) AS MaxResponseTimeMs
    FROM dbo.AiChatHistory
    WHERE CreatedAt BETWEEN @FromDate AND @ToDate;
    
    -- أكثر الـ Entities استخداماً
    SELECT TOP 10
        EntityKey,
        COUNT(*) AS ChatCount,
        AVG(CAST(UserFeedback AS FLOAT)) * 100 AS AvgFeedback
    FROM dbo.AiChatHistory
    WHERE CreatedAt BETWEEN @FromDate AND @ToDate
      AND EntityKey IS NOT NULL
    GROUP BY EntityKey
    ORDER BY ChatCount DESC;
    
    -- أكثر الـ Intents استخداماً
    SELECT TOP 10
        Intent,
        COUNT(*) AS ChatCount,
        AVG(CAST(UserFeedback AS FLOAT)) * 100 AS AvgFeedback
    FROM dbo.AiChatHistory
    WHERE CreatedAt BETWEEN @FromDate AND @ToDate
      AND Intent IS NOT NULL
    GROUP BY Intent
    ORDER BY ChatCount DESC;
END;
