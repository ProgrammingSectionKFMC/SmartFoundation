
CREATE PROCEDURE dbo.sp_AiChat_GetQuestionsNeedingImprovement
    @TopN INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP (@TopN)
        QuestionId,
        Question,
        EntityKey,
        Intent,
        AskCount,
        SuccessRate,
        LastAsked,
        SuggestedAnswer,
        CASE 
            WHEN SuccessRate IS NULL THEN N'لا يوجد تقييم'
            WHEN SuccessRate < 30 THEN N'سيء جداً'
            WHEN SuccessRate < 50 THEN N'ضعيف'
            WHEN SuccessRate < 70 THEN N'متوسط'
            ELSE N'جيد'
        END AS StatusAr
    FROM dbo.AiFrequentQuestions
    WHERE NeedsImprovement = 1
       OR SuccessRate < 50
       OR (AskCount > 5 AND SuggestedAnswer IS NULL)
    ORDER BY 
        AskCount DESC, 
        ISNULL(SuccessRate, 0) ASC;
END;
