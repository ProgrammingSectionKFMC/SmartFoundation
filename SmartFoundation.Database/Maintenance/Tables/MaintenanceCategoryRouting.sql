CREATE TABLE [Maintenance].[MaintenanceCategoryRouting] (
    [MaintenanceCategoryRoutingID] BIGINT          IDENTITY (1, 1) NOT NULL,
    [IdaraId_FK]                   BIGINT          NOT NULL,
    [MaintenanceCategoryID]        BIGINT          NOT NULL,
    [ResponsibleDSDID]             BIGINT          NOT NULL,
    [IsDefault]                    BIT             CONSTRAINT [DF_MaintenanceCategoryRouting_IsDefault] DEFAULT ((1)) NOT NULL,
    [Notes]                        NVARCHAR (1000) NULL,
    [entryUser]                    BIGINT          NULL,
    [entryDate]                    DATETIME        CONSTRAINT [DF_MaintenanceCategoryRouting_entryDate] DEFAULT (getdate()) NOT NULL,
    [updateUser]                   BIGINT          NULL,
    [updateDate]                   DATETIME        NULL,
    [IsActive]                     BIT             CONSTRAINT [DF_MaintenanceCategoryRouting_IsActive] DEFAULT ((1)) NOT NULL,
    [entryData]                    NVARCHAR (20)   NULL,
    [hostName]                     NVARCHAR (200)  NULL,
    CONSTRAINT [PK_MaintenanceCategoryRouting] PRIMARY KEY CLUSTERED ([MaintenanceCategoryRoutingID] ASC),
    CONSTRAINT [FK_MaintenanceCategoryRouting_DeptSecDiv_Responsible] FOREIGN KEY ([ResponsibleDSDID]) REFERENCES [dbo].[DeptSecDiv] ([DSDID]),
    CONSTRAINT [FK_MaintenanceCategoryRouting_MaintenanceCategory] FOREIGN KEY ([IdaraId_FK], [MaintenanceCategoryID]) REFERENCES [Maintenance].[MaintenanceCategory] ([IdaraId_FK], [MaintenanceCategoryID])
);


GO

