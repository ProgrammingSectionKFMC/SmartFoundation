CREATE PROCEDURE [dbo].[sp_AiChat_SaveFeedback]
(
    @ChatId          BIGINT,
    @UserFeedback    INT,                 -- 1 أو -1
    @FeedbackComment NVARCHAR(2000) = NULL,
    @UsersId         NVARCHAR(50) = NULL   -- اختياري
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- تحقق أن الشات موجود في AiChatHistory (الجدول الصحيح)
    IF NOT EXISTS (SELECT 1 FROM dbo.AiChatHistory WHERE ChatId = @ChatId)
    BEGIN
        SELECT CAST(0 AS bit) AS IsSuccessful, N'ChatId غير موجود في AiChatHistory' AS Message_;
        RETURN;
    END

    DECLARE @IsHelpful BIT = CASE WHEN @UserFeedback = 1 THEN 1 ELSE 0 END;

    BEGIN TRY
        BEGIN TRAN;

        -- ✅ حدّث سجل المحادثة نفسه (عشان يظهر التقييم في نفس الجدول)
        UPDATE dbo.AiChatHistory
        SET
            UserFeedback    = @UserFeedback,
            FeedbackComment = @FeedbackComment,
            FeedbackDate    = SYSUTCDATETIME()
        WHERE ChatId = @ChatId;

        -- ✅ (اختياري) خزّن سجل تفصيلي في جدول AiChatFeedback
        INSERT INTO dbo.AiChatFeedback
        (
            AiChatLogId,     -- عندك مربوط FK على AiChatHistory(ChatId) (رغم الاسم)
            AtUtc,
            UsersId,
            IsHelpful,
            Comment
        )
        VALUES
        (
            @ChatId,
            SYSUTCDATETIME(),
            @UsersId,
            @IsHelpful,
            LEFT(@FeedbackComment, 500)
        );

        COMMIT;

        SELECT CAST(1 AS bit) AS IsSuccessful, N'تم حفظ التقييم' AS Message_, @ChatId AS ChatId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        ;THROW;
    END CATCH
END
