CREATE TABLE [dbo].[Distributor] (
    [distributorID]          BIGINT         IDENTITY (1, 1) NOT NULL,
    [distributorName_A]      NVARCHAR (100) NULL,
    [distributorName_E]      NVARCHAR (100) NULL,
    [distributorDescription] NVARCHAR (400) NULL,
    [distributorCode]        NVARCHAR (20)  NULL,
    [distributorActive]      BIT            NULL,
    [distributorType_FK]     INT            NULL,
    [DSDID_FK]               BIGINT         NULL,
    [roleID_FK]              BIGINT         NULL,
    [groupID_FK]             INT            NULL,
    [jobNo]                  INT            NULL,
    [entryDate]              DATETIME       CONSTRAINT [DF_Distributor_entryDate] DEFAULT (getdate()) NULL,
    [entryData]              NVARCHAR (20)  NULL,
    [hostName]               NVARCHAR (200) CONSTRAINT [DF_Distributor_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_Distributor] PRIMARY KEY CLUSTERED ([distributorID] ASC),
    CONSTRAINT [FK_Distributor_DeptSecDiv] FOREIGN KEY ([DSDID_FK]) REFERENCES [dbo].[DeptSecDiv] ([DSDID]),
    CONSTRAINT [FK_Distributor_DistributorType] FOREIGN KEY ([distributorType_FK]) REFERENCES [dbo].[DistributorType] ([distributorTypeID]),
    CONSTRAINT [FK_Distributor_Role] FOREIGN KEY ([roleID_FK]) REFERENCES [dbo].[Role] ([roleID])
);

