CREATE TABLE [WH].[ItemProperty] (
    [itemPropertyID]        BIGINT         IDENTITY (1, 1) NOT NULL,
    [itemID_FK]             BIGINT         NULL,
    [itemPropertyTypeID_FK] INT            NULL,
    [itemPropertyValue]     NVARCHAR (50)  NULL,
    [itemPropertyActive]    BIT            NULL,
    [hostName]              NVARCHAR (200) NULL,
    [entryDate]             DATETIME       CONSTRAINT [DF_ItemProperty_entryDate] DEFAULT (getdate()) NULL,
    [entryData]             NVARCHAR (20)  NULL,
    CONSTRAINT [PK_ItemProperty] PRIMARY KEY CLUSTERED ([itemPropertyID] ASC),
    CONSTRAINT [FK_ItemProperty_Item] FOREIGN KEY ([itemID_FK]) REFERENCES [WH].[Item] ([itemID]),
    CONSTRAINT [FK_ItemProperty_ItemPropertyType] FOREIGN KEY ([itemPropertyTypeID_FK]) REFERENCES [WH].[ItemPropertyType] ([itemPropertyTypeID])
);

