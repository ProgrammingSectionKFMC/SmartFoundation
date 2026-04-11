CREATE TABLE [WH].[ItemPropertyType] (
    [itemPropertyTypeID]     INT            IDENTITY (1, 1) NOT NULL,
    [itemPropertyTypeName_A] NVARCHAR (100) NULL,
    [itemPropertyTypeName_E] NVARCHAR (100) NULL,
    [itemPropertyTypeActive] BIT            NULL,
    [hostName]               NVARCHAR (200) NULL,
    [entryDate]              DATETIME       CONSTRAINT [DF_ItemPropertyType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]              NVARCHAR (20)  NULL,
    CONSTRAINT [PK_ItemPropertyType] PRIMARY KEY CLUSTERED ([itemPropertyTypeID] ASC)
);

