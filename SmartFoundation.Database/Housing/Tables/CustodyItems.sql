CREATE TABLE [Housing].[CustodyItems] (
    [custodyItemID]          INT              IDENTITY (1, 1) NOT NULL,
    [custodyItemUID]         UNIQUEIDENTIFIER NULL,
    [custodyItemName_A]      NVARCHAR (100)   NULL,
    [custodyItemName_E]      NVARCHAR (100)   NULL,
    [custodyItemDescription] NVARCHAR (1000)  NULL,
    [custodyItemActive]      BIT              NULL,
    [entryDate]              DATETIME         CONSTRAINT [DF_CustodyItems_entryDate] DEFAULT (getdate()) NULL,
    [entryData]              NVARCHAR (20)    NULL,
    [hostName]               NVARCHAR (200)   NULL,
    CONSTRAINT [PK_CustodyItems] PRIMARY KEY CLUSTERED ([custodyItemID] ASC)
);

