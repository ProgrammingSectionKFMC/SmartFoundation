CREATE TABLE [dbo].[TSK_TaskProject] (
    [taskProjectID]    INT            IDENTITY (1, 1) NOT NULL,
    [taskProjectName]  NVARCHAR (100) NULL,
    [taskProjectTitle] NVARCHAR (50)  NULL,
    [serial]           NVARCHAR (50)  NULL,
    CONSTRAINT [PK_TSK_TaskProject] PRIMARY KEY CLUSTERED ([taskProjectID] ASC)
);

