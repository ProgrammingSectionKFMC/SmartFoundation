CREATE TABLE [Housing].[MeterRead] (
    [meterReadID]         INT             IDENTITY (1, 1) NOT NULL,
    [meterReadTypeID_FK]  INT             NULL,
    [meterID_FK]          BIGINT          NULL,
    [billPeriodID_FK]     INT             NULL,
    [residentInfoID_FK]   BIGINT          NULL,
    [generalNo_FK]        BIGINT          NULL,
    [buildingDetailsID]   BIGINT          NULL,
    [buildingDetailsNo]   NVARCHAR (50)   NULL,
    [dateOfRead]          DATETIME        NULL,
    [meterReadValue]      BIGINT          NULL,
    [buildingActionID_FK] BIGINT          NULL,
    [meterReadActive]     BIT             NULL,
    [CanceledBy]          NVARCHAR (1000) NULL,
    [IdaraID_FK]          INT             NULL,
    [entryDate]           DATETIME        CONSTRAINT [DF_MeterRead_entryDate] DEFAULT (getdate()) NULL,
    [entryData]           NVARCHAR (20)   NULL,
    [hostName]            NVARCHAR (200)  NULL,
    CONSTRAINT [PK_MeterRead] PRIMARY KEY CLUSTERED ([meterReadID] ASC),
    CONSTRAINT [FK_MeterRead_BillPeriod] FOREIGN KEY ([billPeriodID_FK]) REFERENCES [Housing].[BillPeriod] ([billPeriodID]),
    CONSTRAINT [FK_MeterRead_Meter] FOREIGN KEY ([meterID_FK]) REFERENCES [Housing].[Meter] ([meterID]),
    CONSTRAINT [FK_MeterRead_MeterReadType] FOREIGN KEY ([meterReadTypeID_FK]) REFERENCES [Housing].[MeterReadType] ([meterReadTypeID])
);


GO
CREATE NONCLUSTERED INDEX [IX_MeterRead_Period_Meter_Last_Active]
    ON [Housing].[MeterRead]([billPeriodID_FK] ASC, [meterID_FK] ASC, [dateOfRead] DESC, [meterReadID] DESC)
    INCLUDE([meterReadValue], [meterReadTypeID_FK], [generalNo_FK]) WHERE ([meterReadActive]=(1));


GO
CREATE NONCLUSTERED INDEX [IX_MeterRead_PeriodActive_Meter_Date]
    ON [Housing].[MeterRead]([billPeriodID_FK] ASC, [meterReadActive] ASC, [meterID_FK] ASC, [dateOfRead] DESC, [meterReadID] DESC)
    INCLUDE([meterReadValue], [meterReadTypeID_FK], [generalNo_FK]);


GO
CREATE NONCLUSTERED INDEX [IX_MeterRead_Meter_Last2_Active]
    ON [Housing].[MeterRead]([meterID_FK] ASC, [dateOfRead] DESC, [meterReadID] DESC)
    INCLUDE([billPeriodID_FK], [meterReadValue], [meterReadTypeID_FK], [generalNo_FK], [buildingDetailsID], [buildingDetailsNo]) WHERE ([meterReadActive]=(1));


GO
CREATE NONCLUSTERED INDEX [IX_MeterRead_Meter_Active_Date]
    ON [Housing].[MeterRead]([meterID_FK] ASC, [meterReadActive] ASC, [dateOfRead] DESC, [meterReadID] DESC)
    INCLUDE([billPeriodID_FK], [meterReadValue], [meterReadTypeID_FK], [generalNo_FK], [buildingDetailsID], [buildingDetailsNo]);

