CREATE TABLE [dbo].[TSK_TaskSubComponent] (
    [taskSubComponentID] INT            IDENTITY (1, 1) NOT NULL,
    [title]              NVARCHAR (100) NULL,
    CONSTRAINT [PK_TSK_TaskSubComponent] PRIMARY KEY CLUSTERED ([taskSubComponentID] ASC)
);

