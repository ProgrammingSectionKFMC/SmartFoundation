CREATE TABLE [Maintenance].[BuildingMaintenanceRequestAction] (
    [ActionID]     BIGINT         IDENTITY (1, 1) NOT NULL,
    [RequestID]    BIGINT         NOT NULL,
    [ActionTypeID] INT            NOT NULL,
    [ReasonID]     INT            NULL,
    [FromDSDID]    BIGINT         NULL,
    [ToDSDID]      BIGINT         NULL,
    [FromUserID]   BIGINT         NULL,
    [ToUserID]     BIGINT         NULL,
    [OldStatusID]  INT            NULL,
    [NewStatusID]  INT            NULL,
    [ActionNote]   NVARCHAR (MAX) NULL,
    [ActionDate]   DATETIME       CONSTRAINT [DF_BuildingMaintenanceRequestAction_ActionDate] DEFAULT (getdate()) NOT NULL,
    [entryUser]    BIGINT         NULL,
    [entryDate]    DATETIME       CONSTRAINT [DF_BuildingMaintenanceRequestAction_entryDate] DEFAULT (getdate()) NOT NULL,
    [updateUser]   BIGINT         NULL,
    [updateDate]   DATETIME       NULL,
    [IsActive]     BIT            CONSTRAINT [DF_BuildingMaintenanceRequestAction_IsActive] DEFAULT ((1)) NOT NULL,
    [IdaraId_FK]   BIGINT         NULL,
    [entryData]    NVARCHAR (20)  NULL,
    [hostName]     NVARCHAR (200) NULL,
    CONSTRAINT [PK_BuildingMaintenanceRequestAction] PRIMARY KEY CLUSTERED ([ActionID] ASC),
    CONSTRAINT [FK_BuildingMaintenanceRequestAction_ActionType] FOREIGN KEY ([ActionTypeID]) REFERENCES [Maintenance].[MaintenanceActionType] ([ActionTypeID]),
    CONSTRAINT [FK_BuildingMaintenanceRequestAction_DeptSecDiv_From] FOREIGN KEY ([FromDSDID]) REFERENCES [dbo].[DeptSecDiv] ([DSDID]),
    CONSTRAINT [FK_BuildingMaintenanceRequestAction_DeptSecDiv_To] FOREIGN KEY ([ToDSDID]) REFERENCES [dbo].[DeptSecDiv] ([DSDID]),
    CONSTRAINT [FK_BuildingMaintenanceRequestAction_NewStatus] FOREIGN KEY ([NewStatusID]) REFERENCES [Maintenance].[MaintenanceRequestStatus] ([StatusID]),
    CONSTRAINT [FK_BuildingMaintenanceRequestAction_OldStatus] FOREIGN KEY ([OldStatusID]) REFERENCES [Maintenance].[MaintenanceRequestStatus] ([StatusID]),
    CONSTRAINT [FK_BuildingMaintenanceRequestAction_Reason] FOREIGN KEY ([ReasonID]) REFERENCES [Maintenance].[MaintenanceActionReason] ([ReasonID]),
    CONSTRAINT [FK_BuildingMaintenanceRequestAction_Request] FOREIGN KEY ([RequestID]) REFERENCES [Maintenance].[BuildingMaintenanceRequest] ([RequestID])
);


GO

