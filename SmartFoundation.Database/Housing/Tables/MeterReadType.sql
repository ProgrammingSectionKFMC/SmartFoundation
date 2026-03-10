CREATE TABLE [Housing].[MeterReadType] (
    [meterReadTypeID]     INT            IDENTITY (1, 1) NOT NULL,
    [meterReadTypeName_A] NVARCHAR (500) NULL,
    [meterReadTypeName_E] NVARCHAR (500) NULL,
    [meterReadTypeActive] BIT            NULL,
    CONSTRAINT [PK_MeterReadType] PRIMARY KEY CLUSTERED ([meterReadTypeID] ASC)
);

