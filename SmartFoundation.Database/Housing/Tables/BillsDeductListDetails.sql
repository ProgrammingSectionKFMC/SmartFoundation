CREATE TABLE [Housing].[BillsDeductListDetails] (
    [billsDeductListDetailsID]        INT              IDENTITY (1, 1) NOT NULL,
    [billsDeductListDetailsUID]       UNIQUEIDENTIFIER CONSTRAINT [DF_BillsDeductListDetails_billsDeductListDetailsUID] DEFAULT (newid()) NOT NULL,
    [billDeductListDestainationID_FK] INT              NULL,
    [billDeductListID_FK]             INT              NULL,
    [billsID_FK]                      BIGINT           NULL,
    [billAmount]                      DECIMAL (18, 2)  NULL,
    [billActive]                      BIT              NULL,
    [billPaid]                        BIT              NULL,
    [paymentType]                     INT              NULL,
    [paidNumber]                      NVARCHAR (200)   NULL,
    [paidDate]                        DATETIME         NULL,
    [paidAmount]                      DECIMAL (18, 2)  NULL,
    [Note]                            NVARCHAR (1000)  NULL,
    [entryDate]                       DATETIME         CONSTRAINT [DF_BillsDeductListDetails_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                       NVARCHAR (20)    NULL,
    [hostName]                        NVARCHAR (200)   NULL,
    CONSTRAINT [PK_billsDeductListDetails] PRIMARY KEY CLUSTERED ([billsDeductListDetailsID] ASC),
    CONSTRAINT [FK_BillsDeductListDetails_BillDeductList] FOREIGN KEY ([billDeductListID_FK]) REFERENCES [Housing].[BillDeductList] ([billDeductListID]),
    CONSTRAINT [FK_BillsDeductListDetails_billDeductListDestaination] FOREIGN KEY ([billDeductListDestainationID_FK]) REFERENCES [Housing].[billDeductListDestaination] ([billDeductListDestainationID]),
    CONSTRAINT [FK_BillsDeductListDetails_Bills] FOREIGN KEY ([billsID_FK]) REFERENCES [Housing].[Bills] ([BillsID])
);


GO
CREATE NONCLUSTERED INDEX [IX_BillsDeduct_active_paid]
    ON [Housing].[BillsDeductListDetails]([billsID_FK] ASC, [billActive] ASC, [billPaid] ASC)
    INCLUDE([paidAmount], [paidDate]);

