CREATE TABLE [Housing].[WaitingClass] (
    [waitingClassID]       INT            IDENTITY (1, 1) NOT NULL,
    [waitingClassName_A]   NVARCHAR (100) NULL,
    [waitingClassName_E]   NVARCHAR (100) NULL,
    [waitingClassSequence] INT            NULL,
    [waitingClassRoot]     INT            NULL,
    [idara_FK]             BIGINT         NULL,
    CONSTRAINT [PK_WaitingClass] PRIMARY KEY CLUSTERED ([waitingClassID] ASC)
);

