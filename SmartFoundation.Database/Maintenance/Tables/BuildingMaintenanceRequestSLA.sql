CREATE TABLE [Maintenance].[BuildingMaintenanceRequestSLA] (
    [RequestSLAID]      BIGINT         IDENTITY (1, 1) NOT NULL,
    [RequestID]         BIGINT         NOT NULL,
    [InspectionDueDate] DATETIME       NULL,
    [ExecutionDueDate]  DATETIME       NULL,
    [ApprovalDueDate]   DATETIME       NULL,
    [IsInspectionLate]  BIT            CONSTRAINT [DF_BuildingMaintenanceRequestSLA_IsInspectionLate] DEFAULT ((0)) NOT NULL,
    [IsExecutionLate]   BIT            CONSTRAINT [DF_BuildingMaintenanceRequestSLA_IsExecutionLate] DEFAULT ((0)) NOT NULL,
    [IsApprovalLate]    BIT            CONSTRAINT [DF_BuildingMaintenanceRequestSLA_IsApprovalLate] DEFAULT ((0)) NOT NULL,
    [entryUser]         BIGINT         NULL,
    [entryDate]         DATETIME       CONSTRAINT [DF_BuildingMaintenanceRequestSLA_entryDate] DEFAULT (getdate()) NOT NULL,
    [updateUser]        BIGINT         NULL,
    [updateDate]        DATETIME       NULL,
    [IsActive]          BIT            CONSTRAINT [DF_BuildingMaintenanceRequestSLA_IsActive] DEFAULT ((1)) NOT NULL,
    [IdaraId_FK]        BIGINT         NULL,
    [entryData]         NVARCHAR (20)  NULL,
    [hostName]          NVARCHAR (200) NULL,
    CONSTRAINT [PK_BuildingMaintenanceRequestSLA] PRIMARY KEY CLUSTERED ([RequestSLAID] ASC),
    CONSTRAINT [FK_BuildingMaintenanceRequestSLA_Request] FOREIGN KEY ([RequestID]) REFERENCES [Maintenance].[BuildingMaintenanceRequest] ([RequestID])
);


GO

