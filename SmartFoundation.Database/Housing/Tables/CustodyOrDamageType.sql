CREATE TABLE [Housing].[CustodyOrDamageType] (
    [custodyOrDamageTypeID]          INT             IDENTITY (1, 1) NOT NULL,
    [custodyOrDamageName_A]          NVARCHAR (100)  NULL,
    [custodyOrDamageTypeName_E]      NVARCHAR (100)  NULL,
    [custodyOrDamageTypeActive]      BIT             NULL,
    [custodyOrDamageTypeDescription] NVARCHAR (1000) NULL,
    [entryDate]                      DATETIME        CONSTRAINT [DF_CustodyOrDamageType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                      NVARCHAR (20)   NULL,
    [hostName]                       NVARCHAR (200)  NULL,
    CONSTRAINT [PK_CustodyOrDamageType] PRIMARY KEY CLUSTERED ([custodyOrDamageTypeID] ASC)
);

