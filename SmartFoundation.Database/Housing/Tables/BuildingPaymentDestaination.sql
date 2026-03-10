CREATE TABLE [Housing].[BuildingPaymentDestaination] (
    [buildingPaymentDestainationID]          INT             IDENTITY (1, 1) NOT NULL,
    [buildingPaymentDestainationName_A]      NVARCHAR (100)  NULL,
    [buildingPaymentDestainationName_E]      NVARCHAR (100)  NULL,
    [buildingPaymentDestainationDescription] NVARCHAR (1000) NULL,
    [buildingPaymentDestainationActive]      BIT             NULL,
    [entryDate]                              DATETIME        CONSTRAINT [DF_BuildingPaymentDestaination_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                              NVARCHAR (20)   NULL,
    [hostName]                               NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BuildingPaymentDestaination] PRIMARY KEY CLUSTERED ([buildingPaymentDestainationID] ASC)
);

