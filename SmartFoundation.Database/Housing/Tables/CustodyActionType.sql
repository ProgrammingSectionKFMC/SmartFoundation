CREATE TABLE [Housing].[CustodyActionType] (
    [custodyActionTypeID]          INT             IDENTITY (1, 1) NOT NULL,
    [custodyActionTypeName_A]      NVARCHAR (100)  NULL,
    [custodyActionTypeName_E]      NVARCHAR (100)  NULL,
    [custodyActionTypeDescription] NVARCHAR (1000) NULL,
    [custodyActionTypeActive]      BIT             NULL,
    [entryDate]                    DATETIME        CONSTRAINT [DF_CustodyActionType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                    NVARCHAR (20)   NULL,
    [hostName]                     NVARCHAR (200)  NULL,
    CONSTRAINT [PK_CustodyActionType] PRIMARY KEY CLUSTERED ([custodyActionTypeID] ASC)
);

