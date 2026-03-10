CREATE TABLE [dbo].[DistributorType] (
    [distributorTypeID]          INT            IDENTITY (1, 1) NOT NULL,
    [distributorTypeName_A]      NVARCHAR (100) NULL,
    [distributorTypeName_E]      NVARCHAR (100) NULL,
    [distributorTypeDescription] NVARCHAR (200) NULL,
    [distributorTypeActive]      BIT            NULL,
    [entryDate]                  DATETIME       CONSTRAINT [DF_DistributorType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                  NVARCHAR (20)  NULL,
    [hostName]                   NVARCHAR (200) CONSTRAINT [DF_DistributorType_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_DistributorType] PRIMARY KEY CLUSTERED ([distributorTypeID] ASC)
);

