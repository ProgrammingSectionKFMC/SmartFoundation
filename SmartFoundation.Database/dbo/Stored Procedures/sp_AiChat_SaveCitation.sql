CREATE   PROCEDURE [dbo].[sp_AiChat_SaveCitation]
(
    @ChatId        bigint,
    @Source        nvarchar(500),
    @TextSnippet   nvarchar(max) = NULL,
    @RelevanceScore float = NULL,
    @UsedInAnswer  bit = 1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @ChatId IS NULL OR @ChatId <= 0
            THROW 50001, N'ChatId غير صحيح', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.AiChatHistory WHERE ChatId = @ChatId)
            THROW 50001, N'ChatId غير موجود في AiChatHistory', 1;

        IF NULLIF(LTRIM(RTRIM(@Source)), N'') IS NULL
            THROW 50001, N'Source مطلوب', 1;

        INSERT INTO dbo.AiChatCitations (ChatId, Source, TextSnippet, RelevanceScore, UsedInAnswer)
        VALUES (@ChatId, @Source, @TextSnippet, @RelevanceScore, @UsedInAnswer);

        SELECT
            CAST(1 AS bit) AS Success,
            N'تم حفظ الاقتباس' AS Message,
            SCOPE_IDENTITY() AS CitationId,
            @ChatId AS ChatId,
            @Source AS Source;
    END TRY
    BEGIN CATCH
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message;
    END CATCH
END
