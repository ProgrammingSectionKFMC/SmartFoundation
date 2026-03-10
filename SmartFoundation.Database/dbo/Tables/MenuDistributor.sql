CREATE TABLE [dbo].[MenuDistributor] (
    [menuDistributorID]     INT    IDENTITY (1, 1) NOT NULL,
    [menuID_FK]             BIGINT NULL,
    [distributorID_FK]      BIGINT NULL,
    [roleID_FK]             BIGINT NULL,
    [userID_FK]             BIGINT NULL,
    [isDenied]              BIT    NULL,
    [menuDistributorActive] BIT    NULL,
    CONSTRAINT [PK_MenuDistributor] PRIMARY KEY CLUSTERED ([menuDistributorID] ASC),
    CONSTRAINT [FK_MenuDistributor_Distributor1] FOREIGN KEY ([distributorID_FK]) REFERENCES [dbo].[Distributor] ([distributorID]),
    CONSTRAINT [FK_MenuDistributor_Menu1] FOREIGN KEY ([menuID_FK]) REFERENCES [dbo].[Menu] ([menuID]),
    CONSTRAINT [FK_MenuDistributor_Role] FOREIGN KEY ([roleID_FK]) REFERENCES [dbo].[Role] ([roleID]),
    CONSTRAINT [FK_MenuDistributor_Users] FOREIGN KEY ([userID_FK]) REFERENCES [dbo].[Users] ([usersID])
);

