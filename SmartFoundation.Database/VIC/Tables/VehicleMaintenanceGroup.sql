CREATE TABLE [VIC].[VehicleMaintenanceGroup] (
    [RecID]            INT            IDENTITY (1, 1) NOT NULL,
    [chassisNumber_FK] NVARCHAR (200) NOT NULL,
    [GroupID_FK]       INT            NOT NULL,
    [IdaraID_FK]       NVARCHAR (10)  NOT NULL,
    [Active]           BIT            DEFAULT ((1)) NOT NULL,
    [AssignedDate]     DATETIME       DEFAULT (getdate()) NOT NULL,
    [AssignedBy]       NVARCHAR (40)  DEFAULT (suser_sname()) NOT NULL,
    PRIMARY KEY CLUSTERED ([RecID] ASC),
    FOREIGN KEY ([GroupID_FK]) REFERENCES [VIC].[MaintenanceGroup] ([GroupID]),
    FOREIGN KEY ([GroupID_FK]) REFERENCES [VIC].[MaintenanceGroup] ([GroupID]),
    CONSTRAINT [UQ_VehicleGroup] UNIQUE NONCLUSTERED ([chassisNumber_FK] ASC)
);




GO

