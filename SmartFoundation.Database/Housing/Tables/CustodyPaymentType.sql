CREATE TABLE [Housing].[CustodyPaymentType] (
    [custodyPaymentTypeID]            INT             IDENTITY (1, 1) NOT NULL,
    [custodyPaymentDestainationID_FK] INT             NULL,
    [custodyPaymentTypeName_A]        NVARCHAR (100)  NULL,
    [custodyPaymentTypeName_E]        NVARCHAR (100)  NULL,
    [custodyPaymentTypeDescription]   NVARCHAR (1000) NULL,
    [custodyPaymentTypeActive]        BIT             NULL,
    [entryDate]                       DATETIME        NULL,
    [entryData]                       NVARCHAR (20)   NULL,
    [hostName]                        NVARCHAR (200)  NULL
);

