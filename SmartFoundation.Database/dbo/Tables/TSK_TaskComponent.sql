CREATE TABLE [dbo].[TSK_TaskComponent] (
    [taskComponentID]         INT            IDENTITY (1, 1) NOT NULL,
    [title]                   NVARCHAR (100) NULL,
    [fieldName]               NVARCHAR (100) NULL,
    [parentID_FK]             INT            NULL,
    [serial]                  INT            NULL,
    [isActive]                BIT            NULL,
    [isPrivate]               BIT            NULL,
    [isSubComponentUpdatable] BIT            NULL,
    [isComponentUpdatable]    BIT            NULL,
    [isSingleTask]            BIT            NULL,
    [isOpenPermission]        BIT            NULL,
    CONSTRAINT [PK_TSK_TaskComponent] PRIMARY KEY CLUSTERED ([taskComponentID] ASC),
    CONSTRAINT [FK_TSK_TaskComponent_TSK_TaskComponent] FOREIGN KEY ([parentID_FK]) REFERENCES [dbo].[TSK_TaskComponent] ([taskComponentID])
);

