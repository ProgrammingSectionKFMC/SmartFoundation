CREATE TABLE [Maintenance].[BuildingMaintenanceRequestApproval] (
    [ApprovalID]        BIGINT          IDENTITY (1, 1) NOT NULL,
    [RequestID]         BIGINT          NOT NULL,
    [RequestedByUserID] BIGINT          NULL,
    [RequestedDate]     DATETIME        CONSTRAINT [DF_BuildingMaintenanceRequestApproval_RequestedDate] DEFAULT (getdate()) NOT NULL,
    [ApprovalLevel]     INT             NULL,
    [ApprovalDSDID]     BIGINT          NULL,
    [ApprovalUserID]    BIGINT          NULL,
    [ApprovalStatusID]  INT             NULL,
    [Reason]            NVARCHAR (MAX)  NULL,
    [EstimatedCost]     DECIMAL (18, 2) NULL,
    [DecisionNote]      NVARCHAR (MAX)  NULL,
    [DecisionDate]      DATETIME        NULL,
    [entryUser]         BIGINT          NULL,
    [entryDate]         DATETIME        CONSTRAINT [DF_BuildingMaintenanceRequestApproval_entryDate] DEFAULT (getdate()) NOT NULL,
    [updateUser]        BIGINT          NULL,
    [updateDate]        DATETIME        NULL,
    [IsActive]          BIT             CONSTRAINT [DF_BuildingMaintenanceRequestApproval_IsActive] DEFAULT ((1)) NOT NULL,
    [IdaraId_FK]        BIGINT          NULL,
    [entryData]         NVARCHAR (20)   NULL,
    [hostName]          NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BuildingMaintenanceRequestApproval] PRIMARY KEY CLUSTERED ([ApprovalID] ASC),
    CONSTRAINT [FK_BuildingMaintenanceRequestApproval_DeptSecDiv] FOREIGN KEY ([ApprovalDSDID]) REFERENCES [dbo].[DeptSecDiv] ([DSDID]),
    CONSTRAINT [FK_BuildingMaintenanceRequestApproval_Request] FOREIGN KEY ([RequestID]) REFERENCES [Maintenance].[BuildingMaintenanceRequest] ([RequestID]),
    CONSTRAINT [FK_BuildingMaintenanceRequestApproval_Status] FOREIGN KEY ([ApprovalStatusID]) REFERENCES [Maintenance].[MaintenanceRequestStatus] ([StatusID])
);


GO

