CREATE TABLE [dbo].[TSK_TaskDuration] (
    [taskDurationID] INT           IDENTITY (1, 1) NOT NULL,
    [durationName]   NVARCHAR (50) NULL,
    [durationDays]   INT           NULL,
    [startDate]      DATE          NULL,
    CONSTRAINT [PK_TSK_TaskDuration] PRIMARY KEY CLUSTERED ([taskDurationID] ASC)
);

