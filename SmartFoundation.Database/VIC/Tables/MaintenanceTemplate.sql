CREATE TABLE [VIC].[MaintenanceTemplate] (
    [TemplateID]        INT            IDENTITY (1, 1) NOT NULL,
    [MaintOrdTypeID_FK] INT            NOT NULL,
    [typesID_FK]        INT            NOT NULL,
    [TemplateOrder]     INT            CONSTRAINT [DF_MaintenanceTemplate_TemplateOrder] DEFAULT ((1)) NOT NULL,
    [templateActive]    BIT            CONSTRAINT [DF_MaintenanceTemplate_templateActive] DEFAULT ((1)) NOT NULL,
    [entryDate]         DATETIME       CONSTRAINT [DF_MaintenanceTemplate_entryDate] DEFAULT (getdate()) NOT NULL,
    [entryData]         NVARCHAR (40)  NULL,
    [hostName]          NVARCHAR (400) NULL,
    CONSTRAINT [PK_MaintenanceTemplate] PRIMARY KEY CLUSTERED ([TemplateID] ASC)
);

