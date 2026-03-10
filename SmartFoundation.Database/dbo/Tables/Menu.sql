CREATE TABLE [dbo].[Menu] (
    [menuID]          BIGINT          IDENTITY (1, 1) NOT NULL,
    [menuName_A]      NVARCHAR (100)  NULL,
    [menuName_E]      NVARCHAR (100)  NULL,
    [menuDescription] NVARCHAR (4000) NULL,
    [parentMenuID_FK] INT             NULL,
    [menuLink]        NVARCHAR (1000) NULL,
    [programID_FK]    INT             NULL,
    [menuSerial]      INT             NULL,
    [menuActive]      BIT             NULL,
    [isDashboard]     BIT             NULL,
    [PageLvl]         INT             CONSTRAINT [DF_Menu_isPrivate] DEFAULT ((3)) NOT NULL,
    CONSTRAINT [PK_Menu] PRIMARY KEY CLUSTERED ([menuID] ASC),
    CONSTRAINT [FK_Menu_Program] FOREIGN KEY ([programID_FK]) REFERENCES [dbo].[Program] ([programID])
);

