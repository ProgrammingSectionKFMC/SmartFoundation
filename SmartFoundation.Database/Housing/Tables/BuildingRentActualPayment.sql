CREATE TABLE [Housing].[BuildingRentActualPayment] (
    [rentActualPaymentID]  INT              IDENTITY (1, 1) NOT NULL,
    [rentActualPaymentUID] UNIQUEIDENTIFIER CONSTRAINT [DF_BuildingRentActualPayment_rentActualPaymentUID] DEFAULT (newid()) NULL,
    [generalNo_FK]         INT              NULL,
    [actualmonth]          INT              NULL,
    [actualyear]           INT              NULL,
    [rentActualPayment]    DECIMAL (18, 6)  NULL,
    [buildingNo]           NVARCHAR (50)    NULL,
    [paymentID_FK]         INT              NULL,
    [description]          NVARCHAR (1000)  NULL,
    [entryDate]            DATETIME         CONSTRAINT [DF_BuildingRentActualPayment_entryDate] DEFAULT (getdate()) NULL,
    [entryData]            NVARCHAR (20)    NULL,
    [hostName]             NVARCHAR (200)   CONSTRAINT [DF_BuildingRentActualPayment_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_BuildingRentActualPayment] PRIMARY KEY CLUSTERED ([rentActualPaymentID] ASC)
);

