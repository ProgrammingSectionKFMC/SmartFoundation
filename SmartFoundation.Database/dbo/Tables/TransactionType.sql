CREATE TABLE [dbo].[TransactionType] (
    [transactionTypeID]     INT            IDENTITY (1, 1) NOT NULL,
    [transactionTypeName_A] NVARCHAR (100) NULL,
    [transactionTypeName_E] NVARCHAR (100) NULL,
    [transactionTypeActive] BIT            NULL,
    [entryDate]             DATETIME       CONSTRAINT [DF_TransactionType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]             NVARCHAR (20)  NULL,
    [hostName]              NVARCHAR (200) NULL,
    CONSTRAINT [PK_TransactionType] PRIMARY KEY CLUSTERED ([transactionTypeID] ASC)
);

