CREATE TABLE [dbo].[AiChatFeedback] (
    [AiChatFeedbackId] BIGINT         IDENTITY (1, 1) NOT NULL,
    [AiChatLogId]      BIGINT         NOT NULL,
    [AtUtc]            DATETIME2 (0)  CONSTRAINT [DF_AiChatFeedback_AtUtc] DEFAULT (sysutcdatetime()) NOT NULL,
    [UsersId]          NVARCHAR (50)  NULL,
    [IsHelpful]        BIT            NOT NULL,
    [Reason]           NVARCHAR (100) NULL,
    [Comment]          NVARCHAR (500) NULL,
    PRIMARY KEY CLUSTERED ([AiChatFeedbackId] ASC),
    CONSTRAINT [FK_AiChatFeedback_History] FOREIGN KEY ([AiChatLogId]) REFERENCES [dbo].[AiChatHistory] ([ChatId])
);


GO
CREATE NONCLUSTERED INDEX [IX_AiChatFeedback_LogId]
    ON [dbo].[AiChatFeedback]([AiChatLogId] ASC);

