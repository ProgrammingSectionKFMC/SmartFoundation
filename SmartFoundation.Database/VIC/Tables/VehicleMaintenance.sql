CREATE TABLE [VIC].[VehicleMaintenance] (
    [MaintOrdID]        INT            IDENTITY (1, 1) NOT NULL,
    [MaintOrdTypeID_FK] INT            NULL,
    [chassisNumber_FK]  NVARCHAR (100) NULL,
    [MaintOrdStartDate] DATETIME       NULL,
    [MaintOrdEndDate]   DATETIME       NULL,
    [MaintOrdDesc]      NVARCHAR (400) NULL,
    [MaintOrdActive]    BIT            NULL,
    [entryDate]         DATETIME       CONSTRAINT [DF_VehicleMaintenance_entryDate] DEFAULT (getdate()) NULL,
    [entryData]         NVARCHAR (20)  NULL,
    [hostName]          NVARCHAR (200) NULL,
    [IdaraID_FK]        BIGINT         NULL,
    CONSTRAINT [PK_VehicleMaintenance] PRIMARY KEY CLUSTERED ([MaintOrdID] ASC),
    CONSTRAINT [CK_VehicleMaintenance_DateRange] CHECK ([MaintOrdStartDate] IS NULL OR [MaintOrdEndDate] IS NULL OR [MaintOrdStartDate]<=[MaintOrdEndDate]),
    CONSTRAINT [FK_VehicleMaintenance_Idara] FOREIGN KEY ([IdaraID_FK]) REFERENCES [dbo].[Idara] ([idaraID]),
    CONSTRAINT [FK_VehicleMaintenance_Vehicles] FOREIGN KEY ([chassisNumber_FK]) REFERENCES [VIC].[Vehicles] ([chassisNumber])
);

