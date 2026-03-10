CREATE TABLE [dbo].[TSK_TaskStep] (
    [taskStepID]         INT             IDENTITY (1, 1) NOT NULL,
    [taskComponentID_FK] INT             NULL,
    [stepName]           NVARCHAR (50)   NULL,
    [stepTitle]          NVARCHAR (50)   NULL,
    [parentID_FK]        INT             NULL,
    [isForSupervisor]    BIT             NULL,
    [isMultiRecord]      BIT             NULL,
    [weightPercent]      INT             NULL,
    [hideStepName]       BIT             NULL,
    [isFiltered]         BIT             NULL,
    [serial]             INT             NULL,
    [stepLongName]       NVARCHAR (1000) NULL,
    [isDeletable]        BIT             NULL,
    [isOrganizer]        BIT             NULL,
    CONSTRAINT [PK_TSK_TaskStep] PRIMARY KEY CLUSTERED ([taskStepID] ASC),
    CONSTRAINT [FK_TSK_TaskStep_TSK_TaskComponent] FOREIGN KEY ([taskComponentID_FK]) REFERENCES [dbo].[TSK_TaskComponent] ([taskComponentID]),
    CONSTRAINT [FK_TSK_TaskStep_TSK_TaskStep] FOREIGN KEY ([parentID_FK]) REFERENCES [dbo].[TSK_TaskStep] ([taskStepID])
);

