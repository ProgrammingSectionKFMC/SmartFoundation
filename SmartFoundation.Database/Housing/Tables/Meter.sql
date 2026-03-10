CREATE TABLE [Housing].[Meter] (
    [meterID]          BIGINT          IDENTITY (1, 1) NOT NULL,
    [meterTypeID_FK]   INT             NULL,
    [meterNo]          NVARCHAR (50)   NOT NULL,
    [meterName_A]      NVARCHAR (100)  NULL,
    [meterName_E]      NVARCHAR (100)  NULL,
    [meterDescription] NVARCHAR (1000) NULL,
    [meterStartDate]   DATETIME        NULL,
    [meterEndDate]     DATETIME        NULL,
    [meterActive]      BIT             NULL,
    [CanceledBy]       NVARCHAR (200)  NULL,
    [CanceledDate]     DATETIME        NULL,
    [CanceledNote]     NVARCHAR (4000) NULL,
    [IdaraId_FK]       BIGINT          NULL,
    [entryDate]        DATETIME        CONSTRAINT [DF_Meter_entryDate] DEFAULT (getdate()) NULL,
    [entryData]        NVARCHAR (20)   NULL,
    [hostName]         NVARCHAR (200)  NULL,
    CONSTRAINT [PK_Meter] PRIMARY KEY CLUSTERED ([meterID] ASC),
    CONSTRAINT [FK_Meter_Idara] FOREIGN KEY ([IdaraId_FK]) REFERENCES [dbo].[Idara] ([idaraID]),
    CONSTRAINT [FK_Meter_MeterType] FOREIGN KEY ([meterTypeID_FK]) REFERENCES [Housing].[MeterType] ([meterTypeID])
);


GO
CREATE NONCLUSTERED INDEX [IX_Meter_Active_Idara_DateRange_All]
    ON [Housing].[Meter]([meterActive] ASC, [IdaraId_FK] ASC, [meterStartDate] ASC, [meterEndDate] ASC)
    INCLUDE([meterTypeID_FK], [meterNo]);

