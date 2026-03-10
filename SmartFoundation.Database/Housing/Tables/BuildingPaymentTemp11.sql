CREATE TABLE [Housing].[BuildingPaymentTemp11] (
    [paymentID]                INT              IDENTITY (1, 1) NOT NULL,
    [PaymentUID]               UNIQUEIDENTIFIER NOT NULL,
    [buildingPaymentTypeID_FK] INT              NULL,
    [userID_FK]                INT              NULL,
    [IDNumber]                 NVARCHAR (10)    NULL,
    [rankNameA]                NVARCHAR (50)    NULL,
    [unitID]                   NVARCHAR (50)    NULL,
    [userName]                 NVARCHAR (500)   NULL,
    [buildingName]             NVARCHAR (200)   NULL,
    [amount]                   DECIMAL (10, 2)  NULL,
    [deductListID_FK]          INT              NULL,
    [buildingPayementActive]   BIT              NULL
);

