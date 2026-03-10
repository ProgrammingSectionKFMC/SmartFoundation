CREATE TABLE [dbo].[MvcThameUser] (
    [MvcThameUserID]     INT    IDENTITY (1, 1) NOT NULL,
    [UsersID_FK]         BIGINT NULL,
    [MvcThameID_FK]      INT    NULL,
    [MvcThameUserActive] BIT    NULL,
    CONSTRAINT [PK_MvcThameUser] PRIMARY KEY CLUSTERED ([MvcThameUserID] ASC)
);

