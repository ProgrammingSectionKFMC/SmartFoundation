CREATE TABLE [dbo].[TSK_TaskLabelType] (
    [taskLabelTypeID]   INT           IDENTITY (1, 1) NOT NULL,
    [taskLabelTypeName] NVARCHAR (50) NULL,
    CONSTRAINT [PK_TSK_TaskLabelType] PRIMARY KEY CLUSTERED ([taskLabelTypeID] ASC)
);

