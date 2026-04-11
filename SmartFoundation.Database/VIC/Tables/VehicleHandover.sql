CREATE TABLE [VIC].[VehicleHandover] (
    [VehicleHandoverID] INT            IDENTITY (1, 1) NOT NULL,
    [RequestID_FK]      INT            NULL,
    [handOverTypeID_FK] INT            NULL,
    [handoverDate]      DATETIME       NULL,
    [note]              NVARCHAR (500) NULL,
    [entryDate]         DATETIME       CONSTRAINT [DF_VehicleHandover_entryDate] DEFAULT (getdate()) NULL,
    [entryData]         NVARCHAR (20)  NULL,
    [hostName]          NVARCHAR (200) NULL,
    [chassisNumber_FK]  NVARCHAR (100) NULL,
    [IdaraID_FK]        BIGINT         NULL,
    CONSTRAINT [PK_VehicleHandover] PRIMARY KEY CLUSTERED ([VehicleHandoverID] ASC),
    CONSTRAINT [FK_VehicleHandover_HandoverType] FOREIGN KEY ([handOverTypeID_FK]) REFERENCES [VIC].[HandoverType] ([handOverTypeID]),
    CONSTRAINT [FK_VehicleHandover_Idara] FOREIGN KEY ([IdaraID_FK]) REFERENCES [dbo].[Idara] ([idaraID]),
    CONSTRAINT [FK_VehicleHandover_TransferRequest] FOREIGN KEY ([RequestID_FK]) REFERENCES [VIC].[VehicleTransferRequest] ([RequestID]),
    CONSTRAINT [FK_VehicleHandover_Vehicles] FOREIGN KEY ([chassisNumber_FK]) REFERENCES [VIC].[Vehicles] ([chassisNumber])
);

