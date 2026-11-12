CREATE TABLE [Maintenance].[MaintenanceSLA] (
    [SLAID]                 BIGINT         IDENTITY (1, 1) NOT NULL,
    [IdaraId_FK]            BIGINT         NOT NULL,
    [MaintenanceCategoryID] BIGINT         NULL,
    [PriorityID]            INT            NULL,
    [InspectionHours]       INT            NULL,
    [ExecutionHours]        INT            NULL,
    [ApprovalHours]         INT            NULL,
    [TransferResponseHours] INT            NULL,
    [entryUser]             BIGINT         NULL,
    [entryDate]             DATETIME       CONSTRAINT [DF_MaintenanceSLA_entryDate] DEFAULT (getdate()) NOT NULL,
    [updateUser]            BIGINT         NULL,
    [updateDate]            DATETIME       NULL,
    [IsActive]              BIT            CONSTRAINT [DF_MaintenanceSLA_IsActive] DEFAULT ((1)) NOT NULL,
    [entryData]             NVARCHAR (20)  NULL,
    [hostName]              NVARCHAR (200) NULL,
    CONSTRAINT [PK_MaintenanceSLA] PRIMARY KEY CLUSTERED ([SLAID] ASC),
    CONSTRAINT [FK_MaintenanceSLA_MaintenanceCategory] FOREIGN KEY ([IdaraId_FK], [MaintenanceCategoryID]) REFERENCES [Maintenance].[MaintenanceCategory] ([IdaraId_FK], [MaintenanceCategoryID]),
    CONSTRAINT [FK_MaintenanceSLA_Priority] FOREIGN KEY ([PriorityID]) REFERENCES [Maintenance].[MaintenancePriority] ([PriorityID])
);


GO

