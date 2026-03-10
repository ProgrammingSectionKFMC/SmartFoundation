
-- 3) عدّل SP تحديث الأسئلة الشائعة (نفس المشكلة)
CREATE   PROCEDURE dbo.sp_AiChat_UpdateFrequentQuestions
    @ChatId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Question NVARCHAR(500);
    DECLARE @NormalizedQ NVARCHAR(500);
    DECLARE @EntityKey NVARCHAR(100);
    DECLARE @Intent NVARCHAR(50);
    DECLARE @Feedback SMALLINT;

    SELECT 
        @Question = SUBSTRING(UserQuestion, 1, 500),
        @EntityKey = EntityKey,
        @Intent = Intent,
        @Feedback = UserFeedback
    FROM dbo.AiChatHistory
    WHERE ChatId = @ChatId;

    IF @Question IS NULL RETURN;

    SET @NormalizedQ = LOWER(LTRIM(RTRIM(@Question)));
    SET @NormalizedQ = REPLACE(@NormalizedQ, N'؟', N'');
    SET @NormalizedQ = REPLACE(@NormalizedQ, N'?', N'');

    IF EXISTS (SELECT 1 FROM dbo.AiFrequentQuestions WHERE NormalizedQuestion = @NormalizedQ)
    BEGIN
        UPDATE dbo.AiFrequentQuestions
        SET AskCount = AskCount + 1,
            LastAsked = GETDATE(),
            SuccessRate = (
                SELECT AVG(CAST(UserFeedback AS FLOAT)) * 100
                FROM dbo.AiChatHistory
                WHERE LOWER(REPLACE(REPLACE(SUBSTRING(UserQuestion, 1, 500), N'؟', N''), N'?', N'')) = @NormalizedQ
                  AND UserFeedback IS NOT NULL
            ),
            NeedsImprovement = CASE WHEN @Feedback = -1 THEN 1 ELSE NeedsImprovement END
        WHERE NormalizedQuestion = @NormalizedQ;
    END
    ELSE
    BEGIN
        INSERT dbo.AiFrequentQuestions (Question, NormalizedQuestion, EntityKey, Intent, AskCount, LastAsked)
        VALUES (@Question, @NormalizedQ, @EntityKey, @Intent, 1, GETDATE());
    END
END;
