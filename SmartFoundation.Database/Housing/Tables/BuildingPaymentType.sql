CREATE TABLE [Housing].[BuildingPaymentType] (
    [buildingPaymentTypeID]            INT             IDENTITY (1, 1) NOT NULL,
    [buildingPaymentDestainationID_FK] INT             NULL,
    [buildingPaymentTypeName_A]        NVARCHAR (100)  NULL,
    [buildingPaymentTypeName_E]        NVARCHAR (100)  NULL,
    [buildingPaymentTypeDescription]   NVARCHAR (1000) NULL,
    [deductTypeID_FK]                  INT             NULL,
    [buildingPaymentTypeActive]        BIT             NULL,
    [entryDate]                        DATETIME        CONSTRAINT [DF_BuildingPaymentType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                        NVARCHAR (20)   NULL,
    [hostName]                         NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BuildingPaymentType] PRIMARY KEY CLUSTERED ([buildingPaymentTypeID] ASC),
    CONSTRAINT [FK_BuildingPaymentType_BuildingPaymentDestaination] FOREIGN KEY ([buildingPaymentDestainationID_FK]) REFERENCES [Housing].[BuildingPaymentDestaination] ([buildingPaymentDestainationID])
);

