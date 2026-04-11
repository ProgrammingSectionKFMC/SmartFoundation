CREATE TABLE [WH].[ItemLocation] (
    [itemLocationID]     BIGINT         IDENTITY (1, 1) NOT NULL,
    [itemID_FK]          BIGINT         NULL,
    [warehousePartID_FK] BIGINT         NULL,
    [itemLocationActive] BIT            NULL,
    [hostName]           NVARCHAR (200) NULL,
    [entryDate]          DATETIME       CONSTRAINT [DF_ItemLocation_entryDate] DEFAULT (getdate()) NULL,
    [entryData]          NVARCHAR (20)  NULL,
    CONSTRAINT [PK_ItemLocation] PRIMARY KEY CLUSTERED ([itemLocationID] ASC),
    CONSTRAINT [FK_ItemLocation_Item] FOREIGN KEY ([itemID_FK]) REFERENCES [WH].[Item] ([itemID]),
    CONSTRAINT [FK_ItemLocation_WarehousePart1] FOREIGN KEY ([warehousePartID_FK]) REFERENCES [WH].[WarehousePart] ([warehousePartID])
);

