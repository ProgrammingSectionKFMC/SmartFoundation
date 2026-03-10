CREATE TABLE [Housing].[CustodyStatus] (
    [custodyStatusID]          INT             IDENTITY (1, 1) NOT NULL,
    [custodyStatusName_A]      NVARCHAR (100)  NULL,
    [custodyStatusName_E]      NCHAR (10)      NULL,
    [custodyStatusDescription] NVARCHAR (1000) NULL,
    [custodyStatusActive]      BIT             NULL,
    [entryDate]                DATETIME        CONSTRAINT [DF_CustodyStatus_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                NVARCHAR (20)   NULL,
    [hostName]                 NVARCHAR (200)  NULL,
    CONSTRAINT [PK_CustodyStatus] PRIMARY KEY CLUSTERED ([custodyStatusID] ASC)
);

