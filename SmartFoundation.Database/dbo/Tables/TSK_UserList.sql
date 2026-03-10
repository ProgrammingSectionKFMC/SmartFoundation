CREATE TABLE [dbo].[TSK_UserList] (
    [userListID]         INT             IDENTITY (1, 1) NOT NULL,
    [userID_FK]          DECIMAL (10)    NULL,
    [dependentUserID_FK] DECIMAL (10)    NULL,
    [customizedName]     NVARCHAR (1000) NULL,
    [isActive]           BIT             NULL,
    CONSTRAINT [PK_TSK_UserList] PRIMARY KEY CLUSTERED ([userListID] ASC)
);

