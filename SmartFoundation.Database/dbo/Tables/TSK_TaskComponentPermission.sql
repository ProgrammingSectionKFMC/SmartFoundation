CREATE TABLE [dbo].[TSK_TaskComponentPermission] (
    [taskComponentPermissionID] INT          IDENTITY (1, 1) NOT NULL,
    [taskComponentID_FK]        INT          NULL,
    [userID_FK]                 DECIMAL (10) NULL,
    CONSTRAINT [PK_TSK_TaskComponentPermission] PRIMARY KEY CLUSTERED ([taskComponentPermissionID] ASC),
    CONSTRAINT [FK_TSK_TaskComponentPermission_TSK_TaskComponent] FOREIGN KEY ([taskComponentID_FK]) REFERENCES [dbo].[TSK_TaskComponent] ([taskComponentID])
);

