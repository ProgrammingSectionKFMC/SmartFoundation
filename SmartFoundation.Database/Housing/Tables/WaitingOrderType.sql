CREATE TABLE [Housing].[WaitingOrderType] (
    [waitingOrderTypeID]          INT             IDENTITY (1, 1) NOT NULL,
    [waitingOrderTypeName_A]      NVARCHAR (100)  NULL,
    [waitingOrderTypeName_E]      NVARCHAR (100)  NULL,
    [waitingOrderTypeActive]      BIT             NULL,
    [waitingOrderTypeDescription] NVARCHAR (1000) NULL,
    [entryDate]                   DATETIME        CONSTRAINT [DF_WaitingOrderType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                   NVARCHAR (20)   NULL,
    [hostName]                    NVARCHAR (200)  NULL
);

