CREATE TABLE [Maintenance].[MaintenanceActionReason] (
    [ReasonID]     INT            IDENTITY (1, 1) NOT NULL,
    [ReasonName_A] NVARCHAR (200) NOT NULL,
    [ReasonCode]   NVARCHAR (80)  NULL,
    [IsActive]     BIT            CONSTRAINT [DF_MaintenanceActionReason_IsActive] DEFAULT ((1)) NOT NULL,
    [IdaraId_FK]   BIGINT         NULL,
    [entryDate]    DATETIME       CONSTRAINT [DF_MaintenanceActionReason_entryDate] DEFAULT (getdate()) NULL,
    [entryData]    NVARCHAR (20)  NULL,
    [hostName]     NVARCHAR (200) NULL,
    CONSTRAINT [PK_MaintenanceActionReason] PRIMARY KEY CLUSTERED ([ReasonID] ASC),
    CONSTRAINT [UQ_MaintenanceActionReason_ReasonName_A] UNIQUE NONCLUSTERED ([ReasonName_A] ASC)
);


GO

