CREATE TABLE [VIC].[MaintenanceDetails] (
    [MaintDetailesID]  INT            NOT NULL,
    [MaintOrdID_FK]    INT            NULL,
    [typesID_FK]       INT            NULL,
    [SupportID_FK]     NVARCHAR (50)  NULL,
    [CheckStatus_FK]   NVARCHAR (50)  NULL,
    [ActionState]      NVARCHAR (200) NULL,
    [CorrectiveAction] NVARCHAR (200) NULL,
    [FSN]              NVARCHAR (100) NULL,
    [MaintLevel]       NVARCHAR (100) NULL,
    [CurrentDate]      DATETIME       NULL,
    [Notes]            NVARCHAR (200) NULL,
    [entryDate]        DATETIME       NULL,
    [entryData]        NVARCHAR (20)  NULL,
    [hostName]         NVARCHAR (200) NULL,
    CONSTRAINT [FK_MaintenanceDetails_VehicleMaintenance] FOREIGN KEY ([MaintOrdID_FK]) REFERENCES [VIC].[VehicleMaintenance] ([MaintOrdID])
);

