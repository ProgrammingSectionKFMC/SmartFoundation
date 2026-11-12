CREATE TABLE [MoveData].[MigrationExecutionLog] (
    [ExecutionLogID]       BIGINT           IDENTITY (1, 1) NOT NULL,
    [MigrationRunID]       UNIQUEIDENTIFIER NOT NULL,
    [StepNumber]           INT              NOT NULL,
    [ProcedureName]        [sysname]        NOT NULL,
    [StartedAt]            DATETIME2 (3)    NOT NULL,
    [CompletedAt]          DATETIME2 (3)    NOT NULL,
    [DurationMilliseconds] BIGINT           NOT NULL,
    [ExecutionStatus]      VARCHAR (20)     NOT NULL,
    [ErrorNumber]          INT              NULL,
    [ErrorMessage]         NVARCHAR (4000)  NULL,
    [IdaraId]              BIGINT           NULL,
    [CutoverDate]          DATE             NULL,
    [RollbackAfterTest]    BIT              NOT NULL,
    [LoggedAt]             DATETIME2 (3)    CONSTRAINT [DF_MigrationExecutionLog_LoggedAt] DEFAULT (sysdatetime()) NOT NULL,
    CONSTRAINT [PK_MigrationExecutionLog] PRIMARY KEY CLUSTERED ([ExecutionLogID] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_MigrationExecutionLog_RunStep]
    ON [MoveData].[MigrationExecutionLog]([MigrationRunID] ASC, [StepNumber] ASC);


GO

