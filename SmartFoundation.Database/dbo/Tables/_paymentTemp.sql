CREATE TABLE [dbo].[_paymentTemp] (
    [paymentTempID] INT             IDENTITY (1, 1) NOT NULL,
    [generalNo]     NVARCHAR (20)   NULL,
    [unitCode]      NVARCHAR (20)   NULL,
    [amount]        DECIMAL (18, 2) NULL,
    [month]         INT             NULL,
    [year]          INT             NULL,
    [entryDate]     DATETIME        CONSTRAINT [DF__paymentTemp_entryDate] DEFAULT (getdate()) NULL,
    [entryData]     NVARCHAR (20)   NULL,
    [hostName]      NVARCHAR (200)  NULL,
    CONSTRAINT [PK__paymentTemp] PRIMARY KEY CLUSTERED ([paymentTempID] ASC)
);

