CREATE   PROCEDURE dbo.sp_AiChat_Dashboard
(
    @FromDate DATETIME2 = NULL,
    @ToDate   DATETIME2 = NULL,
    @TopN     INT = 50
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -30, SYSDATETIME());
    IF @ToDate   IS NULL SET @ToDate   = SYSDATETIME();

    ----------------------------------------------------------------------
    -- SET 1: Heatmap (Entity+Intent+Page) مع الجودة والتغطية
    ----------------------------------------------------------------------
    SELECT TOP (@TopN)
        ISNULL(EntityKey, N'(NULL)') AS EntityKey,
        ISNULL(Intent,   N'(NULL)') AS Intent,
        ISNULL(PageKey,  N'(NULL)') AS PageKey,
        COUNT(*) AS Chats,
        SUM(CASE WHEN UserFeedback = -1 THEN 1 ELSE 0 END) AS ThumbsDown,
        SUM(CASE WHEN UserFeedback =  1 THEN 1 ELSE 0 END) AS ThumbsUp,
        AVG(CAST(ResponseTimeMs AS FLOAT)) AS AvgMs,
        AVG(CASE WHEN ISNULL(CitationsCount,0) > 0 THEN 1.0 ELSE 0.0 END) * 100 AS CitationCoveragePct
    FROM dbo.AiChatHistory
    WHERE CreatedAt BETWEEN @FromDate AND @ToDate
    GROUP BY EntityKey, Intent, PageKey
    ORDER BY Chats DESC;

    ----------------------------------------------------------------------
    -- SET 2: الأسئلة السيئة + مصادرها
    ----------------------------------------------------------------------
   SELECT TOP (@TopN)
    h.ChatId,
    h.CreatedAt,
    h.UserId,
    LEFT(h.UserQuestion, 250) AS Q,
    h.EntityKey,
    h.Intent,
    h.PageKey,
    h.UserFeedback,
    h.ResponseTimeMs,
    h.CitationsCount,
    src.Sources
FROM dbo.AiChatHistory h
OUTER APPLY
(
    SELECT STRING_AGG(s.Source, ' | ') AS Sources
    FROM (SELECT DISTINCT Source
          FROM dbo.AiChatCitations
          WHERE ChatId = h.ChatId) s
) src
WHERE h.CreatedAt BETWEEN @FromDate AND @ToDate
  AND h.UserFeedback = -1
ORDER BY h.CreatedAt DESC;

    ----------------------------------------------------------------------
    -- SET 3: Backlog للتطوير من AiFrequentQuestions
    ----------------------------------------------------------------------
    SELECT TOP (@TopN)
        QuestionId,
        Question,
        EntityKey,
        Intent,
        AskCount,
        SuccessRate,
        LastAsked,
        NeedsImprovement,
        SuggestedAnswer
    FROM dbo.AiFrequentQuestions
    WHERE (AskCount >= 3 AND (SuggestedAnswer IS NULL OR LTRIM(RTRIM(SuggestedAnswer)) = N''))
       OR (SuccessRate IS NOT NULL AND SuccessRate < 60)
       OR NeedsImprovement = 1
    ORDER BY AskCount DESC, ISNULL(SuccessRate, 0) ASC, LastAsked DESC;

    ----------------------------------------------------------------------
    -- SET 4: أسئلة بدون Citations
    ----------------------------------------------------------------------
    SELECT TOP (@TopN)
        h.ChatId,
        h.CreatedAt,
        h.EntityKey,
        h.Intent,
        h.PageKey,
        LEFT(h.UserQuestion, 300) AS Q
    FROM dbo.AiChatHistory h
    WHERE h.CreatedAt BETWEEN @FromDate AND @ToDate
      AND ISNULL(h.CitationsCount, 0) = 0
    ORDER BY h.CreatedAt DESC;

    ----------------------------------------------------------------------
    -- SET 5: أكثر ملفات MD استخداماً + علاقتها بالتقييم
    ----------------------------------------------------------------------
    SELECT TOP (@TopN)
        c.Source,
        COUNT(*) AS Citations,
        COUNT(DISTINCT c.ChatId) AS ChatsUsingSource,
        AVG(CAST(h.UserFeedback AS FLOAT)) AS AvgFeedback,
        SUM(CASE WHEN h.UserFeedback = -1 THEN 1 ELSE 0 END) AS DownCount,
        SUM(CASE WHEN h.UserFeedback =  1 THEN 1 ELSE 0 END) AS UpCount
    FROM dbo.AiChatCitations c
    JOIN dbo.AiChatHistory h ON h.ChatId = c.ChatId
    WHERE h.CreatedAt BETWEEN @FromDate AND @ToDate
    GROUP BY c.Source
    ORDER BY ChatsUsingSource DESC, Citations DESC;

    ----------------------------------------------------------------------
    -- SET 6: تكرار نفس المصدر داخل نفس Chat (يبي Dedup)
    ----------------------------------------------------------------------
    SELECT TOP (@TopN)
        c.ChatId,
        MAX(h.CreatedAt) AS CreatedAt,
        c.Source,
        COUNT(*) AS RepeatCount
    FROM dbo.AiChatCitations c
    JOIN dbo.AiChatHistory h ON h.ChatId = c.ChatId
    WHERE h.CreatedAt BETWEEN @FromDate AND @ToDate
    GROUP BY c.ChatId, c.Source
    HAVING COUNT(*) > 1
    ORDER BY RepeatCount DESC, CreatedAt DESC;

    ----------------------------------------------------------------------
    -- SET 7: أبطأ محادثات
    ----------------------------------------------------------------------
    SELECT TOP (@TopN)
        h.ChatId,
        h.CreatedAt,
        h.EntityKey,
        h.Intent,
        h.PageKey,
        h.ResponseTimeMs,
        LEFT(h.UserQuestion, 250) AS Q
    FROM dbo.AiChatHistory h
    WHERE h.CreatedAt BETWEEN @FromDate AND @ToDate
      AND h.ResponseTimeMs IS NOT NULL
    ORDER BY h.ResponseTimeMs DESC;
END
