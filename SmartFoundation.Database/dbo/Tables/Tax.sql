CREATE TABLE [dbo].[Tax] (
    [taxID]          INT             IDENTITY (1, 1) NOT NULL,
    [taxName_A]      NVARCHAR (100)  NULL,
    [taxName_E]      NVARCHAR (100)  NULL,
    [taxDescription] NVARCHAR (1000) NULL,
    [taxIsRate]      BIT             NULL,
    [taxRate]        DECIMAL (10, 2) NULL,
    [taxStartDate]   DATETIME        NULL,
    [taxEndDate]     DATETIME        NULL,
    [taxActive]      BIT             NULL,
    [entryDate]      DATETIME        CONSTRAINT [DF_Tax_entryDate] DEFAULT (getdate()) NULL,
    [entryData]      NVARCHAR (20)   NULL,
    [hostName]       NVARCHAR (200)  NULL,
    CONSTRAINT [PK_Tax] PRIMARY KEY CLUSTERED ([taxID] ASC)
);

