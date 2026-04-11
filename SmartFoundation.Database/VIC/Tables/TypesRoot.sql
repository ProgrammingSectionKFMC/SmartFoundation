CREATE TABLE [VIC].[TypesRoot] (
    [typesID]            INT            IDENTITY (1, 1) NOT NULL,
    [typesName_A]        NVARCHAR (100) NULL,
    [typesName_E]        NVARCHAR (100) NULL,
    [typesDesc]          NVARCHAR (300) NULL,
    [typesActive]        BIT            NULL,
    [typesStartDate]     DATETIME       NULL,
    [typesEndDate]       DATETIME       NULL,
    [typesRoot_ParentID] INT            NULL,
    [entryDate]          DATETIME       CONSTRAINT [DF_TypesRoot_entryDate] DEFAULT (getdate()) NULL,
    [entryData]          NVARCHAR (50)  NULL,
    [hostName]           NVARCHAR (200) NULL,
    CONSTRAINT [PK_TypesRoot] PRIMARY KEY CLUSTERED ([typesID] ASC)
);

