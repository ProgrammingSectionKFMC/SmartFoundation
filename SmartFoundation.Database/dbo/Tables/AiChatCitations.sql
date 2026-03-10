CREATE TABLE [dbo].[AiChatCitations] (
    [CitationId]     BIGINT         IDENTITY (1, 1) NOT NULL,
    [ChatId]         BIGINT         NOT NULL,
    [Source]         NVARCHAR (500) NOT NULL,
    [TextSnippet]    NVARCHAR (MAX) NULL,
    [RelevanceScore] FLOAT (53)     NULL,
    [UsedInAnswer]   BIT            DEFAULT ((1)) NULL,
    PRIMARY KEY CLUSTERED ([CitationId] ASC),
    FOREIGN KEY ([ChatId]) REFERENCES [dbo].[AiChatHistory] ([ChatId]) ON DELETE CASCADE
);


GO
CREATE NONCLUSTERED INDEX [IX_Source]
    ON [dbo].[AiChatCitations]([Source] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_ChatId]
    ON [dbo].[AiChatCitations]([ChatId] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_AiChatCitations_ChatId]
    ON [dbo].[AiChatCitations]([ChatId] ASC);

