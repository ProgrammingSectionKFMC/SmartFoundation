CREATE TABLE [dbo].[TSK_TaskProjectPermission] (
    [taskProjectPermissionID] INT          IDENTITY (1, 1) NOT NULL,
    [taskProjectID_FK]        INT          NULL,
    [userID_FK]               DECIMAL (10) NULL,
    CONSTRAINT [PK_TSK_TaskProjectPermission] PRIMARY KEY CLUSTERED ([taskProjectPermissionID] ASC),
    CONSTRAINT [FK_TSK_TaskProjectPermission_TSK_TaskProject] FOREIGN KEY ([taskProjectID_FK]) REFERENCES [dbo].[TSK_TaskProject] ([taskProjectID])
);

