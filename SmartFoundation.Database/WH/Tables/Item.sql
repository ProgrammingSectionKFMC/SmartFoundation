CREATE TABLE [WH].[Item] (
    [itemID]               BIGINT           IDENTITY (1, 1) NOT NULL,
    [itemUID]              UNIQUEIDENTIFIER NULL,
    [categoryLevelID_FK]   BIGINT           NULL,
    [itemName_A]           NVARCHAR (100)   NULL,
    [itemName_E]           NVARCHAR (100)   NULL,
    [itemStockNoOldSystem] NVARCHAR (100)   NULL,
    [itemStockNo]          NVARCHAR (100)   NULL,
    [itemStockNoSaudi]     NVARCHAR (100)   NULL,
    [itemActive]           BIT              NULL,
    [itemDescription_A]    NVARCHAR (4000)  NULL,
    [itemDescription_E]    NVARCHAR (4000)  NULL,
    [oldItemID]            BIGINT           NULL,
    [hostName]             NVARCHAR (200)   NULL,
    [entryDate]            DATETIME         CONSTRAINT [DF_Item_entryDate] DEFAULT (getdate()) NULL,
    [entryData]            NVARCHAR (20)    NULL,
    CONSTRAINT [PK_Item] PRIMARY KEY CLUSTERED ([itemID] ASC),
    CONSTRAINT [FK_Item_CategoryLevel] FOREIGN KEY ([categoryLevelID_FK]) REFERENCES [WH].[CategoryLevel] ([categoryLevelID])
);

