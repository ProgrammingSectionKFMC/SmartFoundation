CREATE TABLE [Housing].[billPaymentType] (
    [billPaymentTypeID]            INT             IDENTITY (1, 1) NOT NULL,
    [billPaymentDestainationID_FK] INT             NULL,
    [billPaymentTypeName_A]        NVARCHAR (100)  NULL,
    [billPaymentTypeName_E]        NVARCHAR (100)  NULL,
    [billPaymentTypeDescription]   NVARCHAR (1000) NULL,
    [deductTypeID_FK]              INT             NULL,
    [billPaymentTypeActive]        BIT             NULL,
    [entryDate]                    DATETIME        CONSTRAINT [DF_billPaymentType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                    NVARCHAR (20)   NULL,
    [hostName]                     NVARCHAR (200)  NULL,
    CONSTRAINT [PK_billPaymentType] PRIMARY KEY CLUSTERED ([billPaymentTypeID] ASC)
);

