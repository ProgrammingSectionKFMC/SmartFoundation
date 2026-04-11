CREATE TABLE [WH].[WarehousePartType] (
    [warehousePartTypeID]          INT             IDENTITY (1, 1) NOT NULL,
    [warehousePartTypeName_A]      NVARCHAR (100)  NULL,
    [warehousePartTypeName_E]      NVARCHAR (100)  NULL,
    [warehousePartTypeDescription] NVARCHAR (1000) NULL,
    [warehousePartTypeActive]      BIT             NULL,
    [hostName]                     NVARCHAR (200)  NULL,
    [entryDate]                    DATETIME        CONSTRAINT [DF_WarehousePartType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                    NVARCHAR (20)   NULL,
    CONSTRAINT [PK_WarehousePartType] PRIMARY KEY CLUSTERED ([warehousePartTypeID] ASC)
);

