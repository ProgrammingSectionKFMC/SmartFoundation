CREATE TABLE [Housing].[MeterForBuilding] (
    [meterForBuildingID]          INT             IDENTITY (1, 1) NOT NULL,
    [meterID_FK]                  BIGINT          NULL,
    [buildingDetailsID_FK]        BIGINT          NULL,
    [meterForBuildingStartDate]   DATETIME        NULL,
    [meterForBuildingEndDate]     DATETIME        NULL,
    [meterForBuildingActive]      BIT             NULL,
    [meterForBuildingDescription] NVARCHAR (1000) NULL,
    [CanceledBy]                  NVARCHAR (200)  NULL,
    [CanceledDate]                DATETIME        NULL,
    [CanceledNote]                NVARCHAR (4000) NULL,
    [IdaraID_FK]                  INT             NULL,
    [entryDate]                   DATETIME        CONSTRAINT [DF_MeterForBuilding_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                   NVARCHAR (20)   NULL,
    [hostName]                    NVARCHAR (200)  NULL,
    CONSTRAINT [PK_MeterForBuilding] PRIMARY KEY CLUSTERED ([meterForBuildingID] ASC),
    CONSTRAINT [FK_MeterForBuilding_BuildingDetails] FOREIGN KEY ([buildingDetailsID_FK]) REFERENCES [Housing].[BuildingDetails] ([buildingDetailsID]),
    CONSTRAINT [FK_MeterForBuilding_Meter] FOREIGN KEY ([meterID_FK]) REFERENCES [Housing].[Meter] ([meterID])
);


GO
CREATE NONCLUSTERED INDEX [IX_MeterForBuilding_Active_Building]
    ON [Housing].[MeterForBuilding]([buildingDetailsID_FK] ASC, [meterForBuildingActive] ASC)
    INCLUDE([meterID_FK]);


GO
CREATE NONCLUSTERED INDEX [IX_MeterForBuilding_Meter_Active_Dates]
    ON [Housing].[MeterForBuilding]([meterID_FK] ASC, [meterForBuildingActive] ASC, [meterForBuildingStartDate] ASC, [meterForBuildingEndDate] ASC)
    INCLUDE([buildingDetailsID_FK]);


GO
CREATE NONCLUSTERED INDEX [IX_MeterForBuilding_Building_Active_Dates]
    ON [Housing].[MeterForBuilding]([buildingDetailsID_FK] ASC, [meterForBuildingActive] ASC, [meterForBuildingStartDate] ASC, [meterForBuildingEndDate] ASC)
    INCLUDE([meterID_FK]);

