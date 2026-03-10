CREATE TABLE [Housing].[BillOldelectricbillPayment] (
    [OldelectricbillPaymentID]   INT             IDENTITY (1, 1) NOT NULL,
    [bno]                        NVARCHAR (200)  COLLATE Arabic_CI_AS NOT NULL,
    [meterno]                    NVARCHAR (20)   COLLATE Arabic_CI_AS NULL,
    [totamt]                     FLOAT (53)      NULL,
    [UserID]                     INT             NOT NULL,
    [OldelectricbillPaymentNote] NVARCHAR (1000) NULL,
    [entryDate]                  DATETIME        CONSTRAINT [DF_OldelectricbillPayment_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                  NVARCHAR (20)   NULL,
    [hostName]                   NVARCHAR (200)  NULL,
    CONSTRAINT [PK_OldelectricbillPayment] PRIMARY KEY CLUSTERED ([OldelectricbillPaymentID] ASC)
);

