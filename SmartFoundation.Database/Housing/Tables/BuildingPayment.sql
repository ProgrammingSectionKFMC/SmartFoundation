CREATE TABLE [Housing].[BuildingPayment] (
    [paymentID]                BIGINT           IDENTITY (1, 1) NOT NULL,
    [PaymentUID]               UNIQUEIDENTIFIER CONSTRAINT [DF_BuildingPayment_PaymentUID] DEFAULT (newid()) NOT NULL,
    [buildingPaymentTypeID_FK] INT              NULL,
    [generalNo_FK]             BIGINT           NULL,
    [IDNumber]                 NVARCHAR (10)    NULL,
    [residentInfoID_FK]        BIGINT           NULL,
    [rankNameA]                NVARCHAR (50)    NULL,
    [unitID]                   NVARCHAR (50)    NULL,
    [userName]                 NVARCHAR (500)   NULL,
    [buildingDetailsID_FK]     NVARCHAR (200)   NULL,
    [amount]                   DECIMAL (10, 2)  NULL,
    [deductListID_FK]          INT              NULL,
    [buildingPayementActive]   BIT              NULL,
    [BillChargeTypeID_FK]      BIGINT           NULL,
    [IdaraId_FK]               INT              NULL,
    [entryDate]                DATETIME         CONSTRAINT [DF_BuildingPayment_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                NVARCHAR (2000)  NULL,
    [hostName]                 NVARCHAR (2000)  NULL,
    CONSTRAINT [PK_BuildingPayment] PRIMARY KEY CLUSTERED ([paymentID] ASC)
);




GO
CREATE NONCLUSTERED INDEX [IX_BuildingPayment_user]
    ON [Housing].[BuildingPayment]([generalNo_FK] ASC)
    INCLUDE([amount]);

