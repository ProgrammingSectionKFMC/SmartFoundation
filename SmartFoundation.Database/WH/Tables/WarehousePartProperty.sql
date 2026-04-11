CREATE TABLE [WH].[WarehousePartProperty] (
    [warehousePartPropertyID]        INT            IDENTITY (1, 1) NOT NULL,
    [warehousePartID_FK]             BIGINT         NULL,
    [warehousePartPropertyTypeID_FK] INT            NULL,
    [warehousePartPropertyValue]     NVARCHAR (50)  NULL,
    [warehousePartPropertyActive]    BIT            NULL,
    [hostName]                       NVARCHAR (200) NULL,
    [entryDate]                      DATETIME       CONSTRAINT [DF_WarehousePartProperty_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                      NVARCHAR (20)  NULL,
    CONSTRAINT [PK_WarehousePartProperty] PRIMARY KEY CLUSTERED ([warehousePartPropertyID] ASC),
    CONSTRAINT [FK_WarehousePartProperty_WarehousePart1] FOREIGN KEY ([warehousePartID_FK]) REFERENCES [WH].[WarehousePart] ([warehousePartID]),
    CONSTRAINT [FK_WarehousePartProperty_WarehousePartPropertyType] FOREIGN KEY ([warehousePartPropertyTypeID_FK]) REFERENCES [WH].[WarehousePartPropertyType] ([warehousePartPropertyTypeID])
);

