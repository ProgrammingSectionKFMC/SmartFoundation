CREATE TABLE [dbo].[TSK_TaskLabel] (
    [taskLabelID]        INT           IDENTITY (1, 1) NOT NULL,
    [taskLabelName]      NVARCHAR (50) NULL,
    [taskLabelTypeID_FK] INT           NULL,
    [labelColor]         NVARCHAR (50) NULL,
    [fontColor]          NVARCHAR (50) NULL,
    [borderColor]        NVARCHAR (50) NULL,
    [class]              NVARCHAR (50) NULL,
    [isUnderprocess]     BIT           NULL,
    [isFinished]         BIT           NULL,
    [isCanceled]         BIT           NULL,
    [isNew]              BIT           NULL,
    [isSuccessful]       BIT           NULL,
    [isDelay]            BIT           NULL,
    CONSTRAINT [PK_TSK_TaskLabel] PRIMARY KEY CLUSTERED ([taskLabelID] ASC),
    CONSTRAINT [FK_TSK_TaskLabel_TSK_TaskLabelType] FOREIGN KEY ([taskLabelTypeID_FK]) REFERENCES [dbo].[TSK_TaskLabelType] ([taskLabelTypeID])
);

