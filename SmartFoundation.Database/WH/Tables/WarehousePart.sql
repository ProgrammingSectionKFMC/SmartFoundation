CREATE TABLE [WH].[WarehousePart] (
    [warehousePartID]             BIGINT         IDENTITY (1, 1) NOT NULL,
    [warehousePartTypeID_FK]      INT            NULL,
    [warehousePartName]           NVARCHAR (100) NULL,
    [warehousePartName_A]         NVARCHAR (500) NULL,
    [warehousePartParentID_FK]    INT            NULL,
    [warehousePartActive]         BIT            NULL,
    [warehousePartOldName]        NVARCHAR (100) NULL,
    [warehousePartOldParentID_FK] INT            NULL,
    [warehousePartIsChecked]      BIT            NULL,
    [IdaraID_FK]                  BIGINT         NULL,
    [hostName]                    NVARCHAR (200) NULL,
    [entryDate]                   DATETIME       CONSTRAINT [DF_WarehousePart_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                   NVARCHAR (20)  NULL,
    CONSTRAINT [PK_WarehousePart_1] PRIMARY KEY CLUSTERED ([warehousePartID] ASC),
    CONSTRAINT [FK_WarehousePart_WarehousePartType1] FOREIGN KEY ([warehousePartTypeID_FK]) REFERENCES [WH].[WarehousePartType] ([warehousePartTypeID])
);

