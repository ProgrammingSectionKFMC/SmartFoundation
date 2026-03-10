CREATE TABLE [dbo].[UserDistributor] (
    [UDID]             INT             IDENTITY (1, 1) NOT NULL,
    [userID_FK]        BIGINT          NULL,
    [distributorID_FK] BIGINT          NULL,
    [UDStartDate]      DATE            NULL,
    [UDEndDate]        DATE            NULL,
    [UDActive]         BIT             NULL,
    [CanceldBy]        NVARCHAR (4000) NULL,
    [Note]             NVARCHAR (1000) NULL,
    [entryDate]        DATETIME        CONSTRAINT [DF_UserDistributor_entryDate_1] DEFAULT (getdate()) NULL,
    [entryData]        NVARCHAR (20)   NULL,
    [hostName]         NVARCHAR (200)  CONSTRAINT [DF_UserDistributor_hostName_1] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_UserDistributor] PRIMARY KEY CLUSTERED ([UDID] ASC),
    CONSTRAINT [FK_UserDistributor_Distributor2] FOREIGN KEY ([distributorID_FK]) REFERENCES [dbo].[Distributor] ([distributorID]),
    CONSTRAINT [FK_UserDistributor_Users1] FOREIGN KEY ([userID_FK]) REFERENCES [dbo].[Users] ([usersID])
);

