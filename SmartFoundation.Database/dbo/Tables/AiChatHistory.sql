CREATE TABLE [dbo].[AiChatHistory] (
    [ChatId]          BIGINT          IDENTITY (1, 1) NOT NULL,
    [UserId]          INT             NULL,
    [UserQuestion]    NVARCHAR (MAX)  NOT NULL,
    [AiAnswer]        NVARCHAR (MAX)  NOT NULL,
    [PageKey]         NVARCHAR (100)  NULL,
    [PageTitle]       NVARCHAR (500)  NULL,
    [PageUrl]         NVARCHAR (1000) NULL,
    [EntityKey]       NVARCHAR (100)  NULL,
    [Intent]          NVARCHAR (50)   NULL,
    [UserFeedback]    SMALLINT        NULL,
    [FeedbackComment] NVARCHAR (1000) NULL,
    [FeedbackDate]    DATETIME2 (7)   NULL,
    [ResponseTimeMs]  INT             NULL,
    [CitationsCount]  INT             NULL,
    [WasSuccessful]   BIT             DEFAULT ((1)) NULL,
    [CreatedAt]       DATETIME2 (7)   DEFAULT (getdate()) NULL,
    [IpAddress]       NVARCHAR (50)   NULL,
    [IdaraID]         NVARCHAR (50)   NULL,
    PRIMARY KEY CLUSTERED ([ChatId] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_Feedback]
    ON [dbo].[AiChatHistory]([UserFeedback] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_CreatedAt]
    ON [dbo].[AiChatHistory]([CreatedAt] DESC);


GO
CREATE NONCLUSTERED INDEX [IX_Intent]
    ON [dbo].[AiChatHistory]([Intent] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_EntityKey]
    ON [dbo].[AiChatHistory]([EntityKey] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_UserId]
    ON [dbo].[AiChatHistory]([UserId] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_AiChatHistory_CreatedAt]
    ON [dbo].[AiChatHistory]([CreatedAt] ASC)
    INCLUDE([EntityKey], [Intent], [PageKey], [UserFeedback], [CitationsCount], [ResponseTimeMs]);

