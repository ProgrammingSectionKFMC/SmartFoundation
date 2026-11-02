CREATE TABLE [Housing].[MonthlyBillingQueue] (
    [QueueID]       BIGINT          IDENTITY (1, 1) NOT NULL,
    [IdaraID]       BIGINT          NOT NULL,
    [PeriodYear]    INT             NOT NULL,
    [PeriodMonth]   INT             NOT NULL,
    [Status]        NVARCHAR (16)   CONSTRAINT [DF_MBQ_Status] DEFAULT (N'PENDING') NOT NULL,
    [RequestedBy]   NVARCHAR (20)   NULL,
    [RequestedHost] NVARCHAR (200)  NULL,
    [CreatedAt]     DATETIME2 (3)   CONSTRAINT [DF_MBQ_Created] DEFAULT (sysutcdatetime()) NOT NULL,
    [StartedAt]     DATETIME2 (3)   NULL,
    [HeartbeatAt]   DATETIME2 (3)   NULL,
    [FinishedAt]    DATETIME2 (3)   NULL,
    [AttemptCount]  INT             CONSTRAINT [DF_MBQ_Attempts] DEFAULT ((0)) NOT NULL,
    [LastError]     NVARCHAR (2000) NULL,
    CONSTRAINT [PK_MonthlyBillingQueue] PRIMARY KEY CLUSTERED ([QueueID] ASC),
    CONSTRAINT [CK_MBQ_Period] CHECK ([PeriodYear]>=(2000) AND [PeriodYear]<=(2100) AND ([PeriodMonth]>=(1) AND [PeriodMonth]<=(12))),
    CONSTRAINT [CK_MBQ_Status] CHECK ([Status]=N'FAILED' OR [Status]=N'COMPLETED' OR [Status]=N'RUNNING' OR [Status]=N'PENDING'),
    CONSTRAINT [UQ_MBQ_Key] UNIQUE NONCLUSTERED ([IdaraID] ASC, [PeriodYear] ASC, [PeriodMonth] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_MBQ_Claim]
    ON [Housing].[MonthlyBillingQueue]([Status] ASC, [HeartbeatAt] ASC, [QueueID] ASC);

