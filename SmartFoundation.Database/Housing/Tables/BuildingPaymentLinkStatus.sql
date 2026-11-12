CREATE TABLE [Housing].[BuildingPaymentLinkStatus] (
    [buildingPaymentLinkStatusID]          INT             NOT NULL,
    [buildingPaymentLinkStatusName_A]      NVARCHAR (200)  NOT NULL,
    [buildingPaymentLinkStatusName_E]      NVARCHAR (200)  NULL,
    [buildingPaymentLinkStatusDescription] NVARCHAR (1000) NULL,
    [buildingPaymentLinkStatusActive]      BIT             CONSTRAINT [DF_BuildingPaymentLinkStatus_Active] DEFAULT ((1)) NOT NULL,
    [entryDate]                            DATETIME        CONSTRAINT [DF_BuildingPaymentLinkStatus_EntryDate] DEFAULT (getdate()) NOT NULL,
    [entryData]                            NVARCHAR (20)   NULL,
    [hostName]                             NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BuildingPaymentLinkStatus] PRIMARY KEY CLUSTERED ([buildingPaymentLinkStatusID] ASC)
);


GO

