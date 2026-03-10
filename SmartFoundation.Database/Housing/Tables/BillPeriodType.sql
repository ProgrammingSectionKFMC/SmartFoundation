CREATE TABLE [Housing].[BillPeriodType] (
    [billPeriodTypeID]          INT             IDENTITY (1, 1) NOT NULL,
    [meterServiceTypeID_FK]     INT             NULL,
    [billPeriodTypeName_A]      NVARCHAR (100)  NULL,
    [billPeriodTypeName_E]      NVARCHAR (100)  NULL,
    [billPeriodTypeDescription] NVARCHAR (1000) NULL,
    [billPeriodTypeActive]      BIT             NULL,
    [entryDate]                 DATETIME        CONSTRAINT [DF_BillPeriodType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                 NVARCHAR (20)   NULL,
    [hostName]                  NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BillPeriodType] PRIMARY KEY CLUSTERED ([billPeriodTypeID] ASC),
    CONSTRAINT [FK_BillPeriodType_MeterServiceType] FOREIGN KEY ([meterServiceTypeID_FK]) REFERENCES [Housing].[MeterServiceType] ([meterServiceTypeID])
);


GO
CREATE NONCLUSTERED INDEX [IX_BillPeriodType_Service_Active]
    ON [Housing].[BillPeriodType]([meterServiceTypeID_FK] ASC, [billPeriodTypeActive] ASC, [billPeriodTypeID] ASC);

