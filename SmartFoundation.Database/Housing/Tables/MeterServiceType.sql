CREATE TABLE [Housing].[MeterServiceType] (
    [meterServiceTypeID]          INT             IDENTITY (1, 1) NOT NULL,
    [meterServiceTypeName_A]      NVARCHAR (100)  NULL,
    [meterServiceTypeName_E]      NVARCHAR (100)  NULL,
    [meterServiceTypeDescription] NVARCHAR (1000) NULL,
    [meterServiceTypeStartDate]   DATETIME        NULL,
    [meterServiceTypeEndDate]     DATETIME        NULL,
    [meterServiceTypeActive]      BIT             NULL,
    [BillChargeTypeID_FK]         INT             NULL,
    [entryDate]                   DATETIME        CONSTRAINT [DF_MeterServiceType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                   NVARCHAR (20)   NULL,
    [hostName]                    NVARCHAR (200)  NULL,
    CONSTRAINT [PK_MeterServiceType] PRIMARY KEY CLUSTERED ([meterServiceTypeID] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_MeterServiceType_Active_Dates]
    ON [Housing].[MeterServiceType]([meterServiceTypeID] ASC, [meterServiceTypeActive] ASC, [meterServiceTypeStartDate] ASC, [meterServiceTypeEndDate] ASC);

