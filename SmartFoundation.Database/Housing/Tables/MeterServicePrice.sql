CREATE TABLE [Housing].[MeterServicePrice] (
    [meterServicePriceID]        INT             IDENTITY (1, 1) NOT NULL,
    [meterTypeID_FK]             INT             NULL,
    [meterServicePriceStartDate] DATE            NULL,
    [meterServicePriceEndDate]   DATE            NULL,
    [meterServicePrice]          DECIMAL (18, 2) NULL,
    [meterServicePriceActive]    BIT             NULL,
    [entryDate]                  DATETIME        CONSTRAINT [DF_MeterServicePrice_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                  NVARCHAR (20)   NULL,
    [hostName]                   NVARCHAR (200)  NULL,
    CONSTRAINT [PK_MeterServicePrice] PRIMARY KEY CLUSTERED ([meterServicePriceID] ASC),
    CONSTRAINT [FK_MeterServicePrice_MeterType] FOREIGN KEY ([meterTypeID_FK]) REFERENCES [Housing].[MeterType] ([meterTypeID])
);

