CREATE TABLE [Housing].[ExitMeterPeriodicSubstitution] (
    [SubstitutionID]           BIGINT          IDENTITY (1, 1) NOT NULL,
    [ExitRequestActionID_FK]   BIGINT          NOT NULL,
    [MeterID]                  BIGINT          NOT NULL,
    [BillPeriodID]             INT             NOT NULL,
    [OriginalBillsID]          BIGINT          NOT NULL,
    [OriginalMeterReadID]      INT             NOT NULL,
    [OriginalBillCanceledBy]   NVARCHAR (1000) NULL,
    [OriginalBillCanceledDate] DATETIME        NULL,
    [OriginalReadCanceledBy]   NVARCHAR (1000) NULL,
    [ResidentInfoID]           BIGINT          NOT NULL,
    [GeneralNo]                BIGINT          NOT NULL,
    [BuildingDetailsID]        BIGINT          NOT NULL,
    [IdaraID]                  INT             NOT NULL,
    [SubstitutionStatus]       TINYINT         CONSTRAINT [DF_ExitMeterSubstitution_Status] DEFAULT ((1)) NOT NULL,
    [SubstitutedAt]            DATETIME2 (3)   CONSTRAINT [DF_ExitMeterSubstitution_At] DEFAULT (sysdatetime()) NOT NULL,
    [SubstitutedBy]            NVARCHAR (20)   NOT NULL,
    [RestoredAt]               DATETIME2 (3)   NULL,
    [RestoredBy]               NVARCHAR (20)   NULL,
    CONSTRAINT [PK_ExitMeterPeriodicSubstitution] PRIMARY KEY CLUSTERED ([SubstitutionID] ASC),
    CONSTRAINT [CK_ExitMeterSubstitution_Status] CHECK ([SubstitutionStatus]=(2) OR [SubstitutionStatus]=(1)),
    CONSTRAINT [FK_ExitMeterSubstitution_Bill] FOREIGN KEY ([OriginalBillsID]) REFERENCES [Housing].[Bills] ([BillsID]),
    CONSTRAINT [FK_ExitMeterSubstitution_Exit] FOREIGN KEY ([ExitRequestActionID_FK]) REFERENCES [Housing].[BuildingAction] ([buildingActionID]),
    CONSTRAINT [FK_ExitMeterSubstitution_Read] FOREIGN KEY ([OriginalMeterReadID]) REFERENCES [Housing].[MeterRead] ([meterReadID])
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_ExitMeterSubstitution_Active_OriginalRead]
    ON [Housing].[ExitMeterPeriodicSubstitution]([OriginalMeterReadID] ASC) WHERE ([SubstitutionStatus]=(1));


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_ExitMeterSubstitution_Active_OriginalBill]
    ON [Housing].[ExitMeterPeriodicSubstitution]([OriginalBillsID] ASC) WHERE ([SubstitutionStatus]=(1));


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_ExitMeterSubstitution_Exit_Meter_Period]
    ON [Housing].[ExitMeterPeriodicSubstitution]([ExitRequestActionID_FK] ASC, [MeterID] ASC, [BillPeriodID] ASC);

