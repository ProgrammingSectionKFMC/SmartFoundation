CREATE TABLE [dbo].[NationalIDType] (
    [nationalIDTypeID]        INT            IDENTITY (1, 1) NOT NULL,
    [nationalIDTypeName_A]    NVARCHAR (200) NULL,
    [nationalIDTypeName_E]    NVARCHAR (200) NULL,
    [nationalIDTypeStartDate] DATETIME       NULL,
    [nationalIDTypeEndDate]   DATETIME       NULL,
    [nationalIDTypeActive]    BIT            NULL,
    [entryDate]               DATETIME       CONSTRAINT [DF_NationalIDType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]               NVARCHAR (20)  NULL,
    [hostName]                NVARCHAR (200) CONSTRAINT [DF_NationalIDType_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_NationalIDType] PRIMARY KEY CLUSTERED ([nationalIDTypeID] ASC)
);

