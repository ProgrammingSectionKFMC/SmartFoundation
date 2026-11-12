CREATE TABLE [Maintenance].[BuildingMaintenanceRequestAssignment] (
    [AssignmentID]       BIGINT         IDENTITY (1, 1) NOT NULL,
    [RequestID]          BIGINT         NOT NULL,
    [AssignedToUserID]   BIGINT         NOT NULL,
    [AssignedByUserID]   BIGINT         NULL,
    [AssignedDSDID]      BIGINT         NULL,
    [AssignedDate]       DATETIME       CONSTRAINT [DF_BuildingMaintenanceRequestAssignment_AssignedDate] DEFAULT (getdate()) NOT NULL,
    [InspectionDate]     DATETIME       NULL,
    [CompletionDate]     DATETIME       NULL,
    [AssignmentStatusID] INT            NULL,
    [ReportText]         NVARCHAR (MAX) NULL,
    [NeedsApproval]      BIT            CONSTRAINT [DF_BuildingMaintenanceRequestAssignment_NeedsApproval] DEFAULT ((0)) NOT NULL,
    [NeedsSubRequest]    BIT            CONSTRAINT [DF_BuildingMaintenanceRequestAssignment_NeedsSubRequest] DEFAULT ((0)) NOT NULL,
    [entryUser]          BIGINT         NULL,
    [entryDate]          DATETIME       CONSTRAINT [DF_BuildingMaintenanceRequestAssignment_entryDate] DEFAULT (getdate()) NOT NULL,
    [updateUser]         BIGINT         NULL,
    [updateDate]         DATETIME       NULL,
    [IsActive]           BIT            CONSTRAINT [DF_BuildingMaintenanceRequestAssignment_IsActive] DEFAULT ((1)) NOT NULL,
    [IdaraId_FK]         BIGINT         NULL,
    [entryData]          NVARCHAR (20)  NULL,
    [hostName]           NVARCHAR (200) NULL,
    CONSTRAINT [PK_BuildingMaintenanceRequestAssignment] PRIMARY KEY CLUSTERED ([AssignmentID] ASC),
    CONSTRAINT [FK_BuildingMaintenanceRequestAssignment_DeptSecDiv_Assigned] FOREIGN KEY ([AssignedDSDID]) REFERENCES [dbo].[DeptSecDiv] ([DSDID]),
    CONSTRAINT [FK_BuildingMaintenanceRequestAssignment_Request] FOREIGN KEY ([RequestID]) REFERENCES [Maintenance].[BuildingMaintenanceRequest] ([RequestID])
);


GO

