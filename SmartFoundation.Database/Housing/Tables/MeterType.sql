CREATE TABLE [Housing].[MeterType] (
    [meterTypeID]               INT             IDENTITY (1, 1) NOT NULL,
    [meterServiceTypeID_FK]     INT             NULL,
    [meterTypeName_A]           NVARCHAR (100)  NULL,
    [meterTypeName_E]           NVARCHAR (100)  NULL,
    [meterTypeDescription]      NVARCHAR (1000) NULL,
    [meterTypeConversionFactor] NVARCHAR (200)  NULL,
    [meterMaxRead]              BIGINT          NULL,
    [meterTypeStartDate]        DATETIME        NULL,
    [meterTypeEndDate]          DATETIME        NULL,
    [meterTypeActive]           BIT             NULL,
    [CanceledBy]                NVARCHAR (200)  NULL,
    [CanceledDate]              DATETIME        NULL,
    [CanceledNote]              NVARCHAR (4000) NULL,
    [IdaraId_FK]                BIGINT          NULL,
    [entryDate]                 DATETIME        CONSTRAINT [DF_MeterType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                 NVARCHAR (20)   NULL,
    [hostName]                  NVARCHAR (200)  NULL,
    CONSTRAINT [PK_MeterType] PRIMARY KEY CLUSTERED ([meterTypeID] ASC),
    CONSTRAINT [FK_MeterType_Idara] FOREIGN KEY ([IdaraId_FK]) REFERENCES [dbo].[Idara] ([idaraID]),
    CONSTRAINT [FK_MeterType_MeterServiceType] FOREIGN KEY ([meterServiceTypeID_FK]) REFERENCES [Housing].[MeterServiceType] ([meterServiceTypeID])
);

