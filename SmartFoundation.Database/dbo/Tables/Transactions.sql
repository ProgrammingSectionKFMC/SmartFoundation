CREATE TABLE [dbo].[Transactions] (
    [transactionID]        BIGINT           IDENTITY (1, 1) NOT NULL,
    [transactionUID]       UNIQUEIDENTIFIER CONSTRAINT [DF_Transactions_transactionUID] DEFAULT (newid()) NULL,
    [createrByUserID_FK]   INT              NULL,
    [transactionTypeID_FK] INT              NULL,
    [securityTypeID_FK]    INT              NULL,
    [priorityTypeID_FK]    INT              NULL,
    [fromDSDID_FK]         INT              NULL,
    [toDSDID_FK]           INT              NULL,
    [by_SP]                NVARCHAR (500)   NULL,
    [toTable]              NVARCHAR (500)   NULL,
    [transactionDecs]      NVARCHAR (1000)  NULL,
    [transactionActive]    BIT              NULL,
    [entryDate]            DATETIME         CONSTRAINT [DF_Transaction_entryDate] DEFAULT (getdate()) NULL,
    [entryData]            NVARCHAR (20)    NULL,
    [hostName]             NVARCHAR (200)   NULL,
    CONSTRAINT [PK_Transaction] PRIMARY KEY CLUSTERED ([transactionID] ASC),
    CONSTRAINT [FK_Transaction_PriorityType] FOREIGN KEY ([priorityTypeID_FK]) REFERENCES [dbo].[PriorityType] ([priorityTypeID]),
    CONSTRAINT [FK_Transaction_SecurityType] FOREIGN KEY ([securityTypeID_FK]) REFERENCES [dbo].[SecurityType] ([securityTypeID]),
    CONSTRAINT [FK_Transaction_TransactionType] FOREIGN KEY ([transactionTypeID_FK]) REFERENCES [dbo].[TransactionType] ([transactionTypeID])
);

