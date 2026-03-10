CREATE TABLE [dbo].[AiChatLog] (
    [AiChatLogId]       BIGINT          IDENTITY (1, 1) NOT NULL,
    [AtUtc]             DATETIME2 (0)   CONSTRAINT [DF_AiChatLog_AtUtc] DEFAULT (sysutcdatetime()) NOT NULL,
    [UsersId]           NVARCHAR (50)   NULL,
    [ConvoKey]          NVARCHAR (100)  NULL,
    [PageUrl]           NVARCHAR (500)  NULL,
    [PageTitle]         NVARCHAR (300)  NULL,
    [Culture]           NVARCHAR (10)   NULL,
    [Message]           NVARCHAR (MAX)  NOT NULL,
    [Intent]            NVARCHAR (20)   NULL,
    [EntityKey]         NVARCHAR (50)   NULL,
    [Mode]              NVARCHAR (20)   NULL,
    [SearchQuery]       NVARCHAR (500)  NULL,
    [TopSources]        NVARCHAR (2000) NULL,
    [Answer]            NVARCHAR (MAX)  NULL,
    [AnswerLen]         INT             NULL,
    [WasDisambiguation] BIT             CONSTRAINT [DF_AiChatLog_WasDisamb] DEFAULT ((0)) NOT NULL,
    [LatencyMs]         INT             NULL,
    [Error]             NVARCHAR (1000) NULL,
    PRIMARY KEY CLUSTERED ([AiChatLogId] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_AiChatLog_AtUtc]
    ON [dbo].[AiChatLog]([AtUtc] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_AiChatLog_UsersId]
    ON [dbo].[AiChatLog]([UsersId] ASC);

