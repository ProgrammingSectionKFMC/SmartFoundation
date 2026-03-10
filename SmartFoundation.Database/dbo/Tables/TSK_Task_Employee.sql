CREATE TABLE [dbo].[TSK_Task_Employee] (
    [TEID]          INT          IDENTITY (1, 1) NOT NULL,
    [taskID_FK]     INT          NULL,
    [userID_FK]     DECIMAL (10) NULL,
    [taskStepID_FK] INT          NULL,
    CONSTRAINT [PK_TSK_Task_Employee] PRIMARY KEY CLUSTERED ([TEID] ASC),
    CONSTRAINT [FK_TSK_Task_Employee_TSK_Task] FOREIGN KEY ([taskID_FK]) REFERENCES [dbo].[TSK_Task] ([taskID]),
    CONSTRAINT [FK_TSK_Task_Employee_TSK_TaskStep] FOREIGN KEY ([taskStepID_FK]) REFERENCES [dbo].[TSK_TaskStep] ([taskStepID])
);

