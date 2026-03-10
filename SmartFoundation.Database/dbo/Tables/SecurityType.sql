CREATE TABLE [dbo].[SecurityType] (
    [securityTypeID]     INT            IDENTITY (1, 1) NOT NULL,
    [securityTypeName_A] NVARCHAR (100) NULL,
    [securityTypeName_E] NVARCHAR (100) NULL,
    [securityTypeActive] BIT            NULL,
    [entryDate]          DATETIME       CONSTRAINT [DF_SecurityType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]          NVARCHAR (20)  NULL,
    [hostName]           NVARCHAR (200) NULL,
    CONSTRAINT [PK_SecurityType] PRIMARY KEY CLUSTERED ([securityTypeID] ASC)
);

