CREATE TABLE [dbo].[AiFrequentQuestions] (
    [QuestionId]         INT            IDENTITY (1, 1) NOT NULL,
    [Question]           NVARCHAR (500) NOT NULL,
    [NormalizedQuestion] NVARCHAR (500) NOT NULL,
    [EntityKey]          NVARCHAR (100) NULL,
    [Intent]             NVARCHAR (50)  NULL,
    [AskCount]           INT            DEFAULT ((1)) NULL,
    [SuccessRate]        DECIMAL (5, 2) NULL,
    [LastAsked]          DATETIME2 (7)  DEFAULT (getdate()) NULL,
    [SuggestedAnswer]    NVARCHAR (MAX) NULL,
    [NeedsImprovement]   BIT            DEFAULT ((0)) NULL,
    PRIMARY KEY CLUSTERED ([QuestionId] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_AskCount]
    ON [dbo].[AiFrequentQuestions]([AskCount] DESC);


GO
CREATE NONCLUSTERED INDEX [IX_EntityKey]
    ON [dbo].[AiFrequentQuestions]([EntityKey] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_NormalizedQuestion]
    ON [dbo].[AiFrequentQuestions]([NormalizedQuestion] ASC);

