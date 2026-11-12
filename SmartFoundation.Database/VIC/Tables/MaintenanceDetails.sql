CREATE TABLE [VIC].[MaintenanceDetails] (
    [MaintDetailesID]   INT            IDENTITY (1, 1) NOT NULL,
    [MaintOrdID_FK]     INT            NULL,
    [typesID_FK]        INT            NULL,
    [SupportID_FK]      NVARCHAR (100) NULL,
    [CheckStatus_FK]    NVARCHAR (100) NULL,
    [ActionState]       NVARCHAR (400) NULL,
    [CorrectiveAction]  NVARCHAR (400) NULL,
    [FSN]               NVARCHAR (200) NULL,
    [MaintLevel]        NVARCHAR (200) NULL,
    [CurrentDate]       DATETIME       NULL,
    [Notes]             NVARCHAR (400) NULL,
    [entryDate]         DATETIME       NULL,
    [entryData]         NVARCHAR (40)  NULL,
    [hostName]          NVARCHAR (400) NULL,
    [MaintDetailActive] BIT            CONSTRAINT [DF_MaintenanceDetails_New_MaintDetailActive] DEFAULT ((1)) NOT NULL,
    CONSTRAINT [PK_MaintenanceDetails_New] PRIMARY KEY CLUSTERED ([MaintDetailesID] ASC),
    CONSTRAINT [FK_MaintenanceDetails_New_VehicleMaintenance] FOREIGN KEY ([MaintOrdID_FK]) REFERENCES [VIC].[VehicleMaintenance] ([MaintOrdID])
);


GO

CREATE NONCLUSTERED INDEX [IX_MaintenanceDetails_New_MaintOrdID]
    ON [VIC].[MaintenanceDetails]([MaintOrdID_FK] ASC);


GO

