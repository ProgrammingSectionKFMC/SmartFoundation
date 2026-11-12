CREATE TABLE [Housing].[WaitingClass] (
    [waitingClassID]          INT             IDENTITY (1, 1) NOT NULL,
    [waitingClassName_A]      NVARCHAR (100)  NULL,
    [waitingClassName_E]      NVARCHAR (100)  NULL,
    [waitingClassSequence]    INT             NULL,
    [waitingClassRoot]        INT             NULL,
    [waitingClassDescription] NVARCHAR (1000) NULL,
    [waitingClassActive]      BIT             NULL,
    [idara_FK]                BIGINT          NULL,
    [UpdatedBy]               NVARCHAR (MAX)  NULL,
    [UpdatedWhy]              NVARCHAR (MAX)  NULL,
    [CancelBy]                NVARCHAR (MAX)  NULL,
    [CancelWhy]               NVARCHAR (MAX)  NULL,
    [entryDate]               DATETIME        CONSTRAINT [DF_WaitingClass_entryDate] DEFAULT (getdate()) NULL,
    [entryData]               NVARCHAR (20)   NULL,
    [hostName]                NVARCHAR (200)  NULL,
    CONSTRAINT [PK_WaitingClass] PRIMARY KEY CLUSTERED ([waitingClassID] ASC)
);


GO

