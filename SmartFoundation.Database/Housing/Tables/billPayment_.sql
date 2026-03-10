CREATE TABLE [Housing].[billPayment_] (
    [billpaymentID]        INT              IDENTITY (1, 1) NOT NULL,
    [billPaymentUID]       UNIQUEIDENTIFIER CONSTRAINT [DF_billPayment__billPaymentUID] DEFAULT (newid()) NOT NULL,
    [billPaymentTypeID_FK] INT              NULL,
    [userID_FK]            INT              NULL,
    [IDNumber]             NVARCHAR (10)    NULL,
    [rankNameA]            NVARCHAR (50)    NULL,
    [unitID]               NVARCHAR (50)    NULL,
    [userName]             NVARCHAR (500)   NULL,
    [buildingName]         NVARCHAR (200)   NULL,
    [amount]               DECIMAL (10, 2)  NULL,
    [billDeductListID_FK]  INT              NULL,
    [billPaymentActive]    BIT              NULL,
    [billPeriodID_FK]      INT              NULL
);

