CREATE TABLE [dbo].[TSK_Task_TaskLabel] (
    [TTLID]          INT            IDENTITY (1, 1) NOT NULL,
    [taskID_FK]      INT            NULL,
    [taskLabelID_FK] INT            NULL,
    [insertDateTime] DATETIME       NULL,
    [byUserID_FK]    DECIMAL (10)   NULL,
    [note]           NVARCHAR (MAX) NULL,
    CONSTRAINT [PK_TSK_Task_TaskLabel] PRIMARY KEY CLUSTERED ([TTLID] ASC),
    CONSTRAINT [FK_TSK_Task_TaskLabel_TSK_TaskLabel] FOREIGN KEY ([taskLabelID_FK]) REFERENCES [dbo].[TSK_TaskLabel] ([taskLabelID])
);

