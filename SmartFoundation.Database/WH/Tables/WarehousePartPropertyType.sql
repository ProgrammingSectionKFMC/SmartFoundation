CREATE TABLE [WH].[WarehousePartPropertyType] (
    [warehousePartPropertyTypeID]     INT            IDENTITY (1, 1) NOT NULL,
    [warehousePartPropertyTypeName_A] NVARCHAR (100) NULL,
    [warehousePartPropertyTypeName_E] NVARCHAR (100) NULL,
    [warehousePartPropertyTypeActive] BIT            NULL,
    [entryDate]                       DATETIME       CONSTRAINT [DF_WarehousePartPropertyType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                       NVARCHAR (20)  NULL,
    [hostName]                        NVARCHAR (200) NULL,
    CONSTRAINT [PK_WarehousePartPropertyType] PRIMARY KEY CLUSTERED ([warehousePartPropertyTypeID] ASC)
);

