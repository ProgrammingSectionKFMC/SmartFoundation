CREATE TABLE [Maintenance].[MaintenanceActionType] (
    [ActionTypeID]     INT            NOT NULL,
    [ActionTypeName_A] NVARCHAR (150) NOT NULL,
    [ActionTypeCode]   NVARCHAR (80)  NOT NULL,
    [DisplayOrder]     INT            NOT NULL,
    [IsActive]         BIT            CONSTRAINT [DF_MaintenanceActionType_IsActive] DEFAULT ((1)) NOT NULL,
    [IdaraId_FK]       BIGINT         NULL,
    [entryDate]        DATETIME       CONSTRAINT [DF_MaintenanceActionType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]        NVARCHAR (20)  NULL,
    [hostName]         NVARCHAR (200) NULL,
    CONSTRAINT [PK_MaintenanceActionType] PRIMARY KEY CLUSTERED ([ActionTypeID] ASC),
    CONSTRAINT [UQ_MaintenanceActionType_ActionTypeCode] UNIQUE NONCLUSTERED ([ActionTypeCode] ASC)
);


GO

