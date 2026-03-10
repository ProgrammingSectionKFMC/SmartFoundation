CREATE TABLE [dbo].[ProgramDistributor] (
    [programDistributorID] INT    IDENTITY (1, 1) NOT NULL,
    [programID_FK]         INT    NULL,
    [distributorID_FK]     BIGINT NULL,
    [roleID_FK]            BIGINT NULL,
    [userID_FK]            INT    NULL,
    [isDenied]             BIT    NULL,
    CONSTRAINT [PK_ProgramDistributor] PRIMARY KEY CLUSTERED ([programDistributorID] ASC),
    CONSTRAINT [FK_ProgramDistributor_Distributor] FOREIGN KEY ([distributorID_FK]) REFERENCES [dbo].[Distributor] ([distributorID]),
    CONSTRAINT [FK_ProgramDistributor_Program] FOREIGN KEY ([programID_FK]) REFERENCES [dbo].[Program] ([programID]),
    CONSTRAINT [FK_ProgramDistributor_Role] FOREIGN KEY ([roleID_FK]) REFERENCES [dbo].[Role] ([roleID])
);

