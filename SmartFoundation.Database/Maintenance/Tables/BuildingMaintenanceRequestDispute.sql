CREATE TABLE [Maintenance].[BuildingMaintenanceRequestDispute] (
    [DisputeID]         BIGINT         IDENTITY (1, 1) NOT NULL,
    [RequestID]         BIGINT         NOT NULL,
    [RaisedByDSDID]     BIGINT         NULL,
    [AgainstDSDID]      BIGINT         NULL,
    [RaisedByUserID]    BIGINT         NULL,
    [Reason]            NVARCHAR (MAX) NOT NULL,
    [ArbitrationDSDID]  BIGINT         NULL,
    [DecisionByUserID]  BIGINT         NULL,
    [DecisionNote]      NVARCHAR (MAX) NULL,
    [IsBindingDecision] BIT            CONSTRAINT [DF_BuildingMaintenanceRequestDispute_IsBindingDecision] DEFAULT ((1)) NOT NULL,
    [DecisionDate]      DATETIME       NULL,
    [DisputeStatusID]   INT            NULL,
    [entryUser]         BIGINT         NULL,
    [entryDate]         DATETIME       CONSTRAINT [DF_BuildingMaintenanceRequestDispute_entryDate] DEFAULT (getdate()) NOT NULL,
    [updateUser]        BIGINT         NULL,
    [updateDate]        DATETIME       NULL,
    [IsActive]          BIT            CONSTRAINT [DF_BuildingMaintenanceRequestDispute_IsActive] DEFAULT ((1)) NOT NULL,
    [IdaraId_FK]        BIGINT         NULL,
    [entryData]         NVARCHAR (20)  NULL,
    [hostName]          NVARCHAR (200) NULL,
    CONSTRAINT [PK_BuildingMaintenanceRequestDispute] PRIMARY KEY CLUSTERED ([DisputeID] ASC),
    CONSTRAINT [FK_BuildingMaintenanceRequestDispute_DeptSecDiv_Against] FOREIGN KEY ([AgainstDSDID]) REFERENCES [dbo].[DeptSecDiv] ([DSDID]),
    CONSTRAINT [FK_BuildingMaintenanceRequestDispute_DeptSecDiv_Arbitration] FOREIGN KEY ([ArbitrationDSDID]) REFERENCES [dbo].[DeptSecDiv] ([DSDID]),
    CONSTRAINT [FK_BuildingMaintenanceRequestDispute_DeptSecDiv_RaisedBy] FOREIGN KEY ([RaisedByDSDID]) REFERENCES [dbo].[DeptSecDiv] ([DSDID]),
    CONSTRAINT [FK_BuildingMaintenanceRequestDispute_Request] FOREIGN KEY ([RequestID]) REFERENCES [Maintenance].[BuildingMaintenanceRequest] ([RequestID]),
    CONSTRAINT [FK_BuildingMaintenanceRequestDispute_Status] FOREIGN KEY ([DisputeStatusID]) REFERENCES [Maintenance].[MaintenanceRequestStatus] ([StatusID])
);


GO

