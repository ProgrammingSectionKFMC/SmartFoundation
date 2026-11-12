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
    [odometer]          INT            NULL,
    [jobOrderNumber]    AS             (((case [MaintOrdTypeID_FK] when (265) then N'P' when (266) then N'G' else N'X' end+right(CONVERT([nvarchar](4),datepart(year,[entryDate])),(2)))+right(N'0'+CONVERT([nvarchar](2),datepart(month,[entryDate])),(2)))+right(N'00000000'+CONVERT([nvarchar](8),[MaintOrdID]),(8))) PERSISTED,
    [closeNote]         NVARCHAR (MAX) NULL,
    [workshopIDs]       NVARCHAR (200) NULL,
    [Cancelled]         BIT            DEFAULT ((0)) NOT NULL,
    [CancelReason]      NVARCHAR (100) NULL,
    [CancelDate]        DATETIME       NULL,
    CONSTRAINT [PK_VehicleMaintenance] PRIMARY KEY CLUSTERED ([MaintOrdID] ASC),
    CONSTRAINT [CK_VehicleMaintenance_DateRange] CHECK ([MaintOrdStartDate] IS NULL OR [MaintOrdEndDate] IS NULL OR [MaintOrdStartDate]<=[MaintOrdEndDate]),
    CONSTRAINT [FK_VehicleMaintenance_Idara] FOREIGN KEY ([IdaraID_FK]) REFERENCES [dbo].[Idara] ([idaraID]),
    CONSTRAINT [FK_VehicleMaintenance_Vehicles] FOREIGN KEY ([chassisNumber_FK]) REFERENCES [VIC].[Vehicles] ([chassisNumber])
);


GO

