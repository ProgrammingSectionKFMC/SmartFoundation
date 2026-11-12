CREATE TABLE [Maintenance].[MaintenanceCategory] (
    [MaintenanceCategoryID] BIGINT          IDENTITY (1, 1) NOT NULL,
    [IdaraId_FK]            BIGINT          NOT NULL,
    [ParentID]              BIGINT          NULL,
    [CategoryName_A]        NVARCHAR (250)  NOT NULL,
    [CategoryName_E]        NVARCHAR (250)  NULL,
    [Description_A]         NVARCHAR (1000) NULL,
    [DisplayOrder]          INT             CONSTRAINT [DF_MaintenanceCategory_DisplayOrder] DEFAULT ((0)) NOT NULL,
    [entryUser]             BIGINT          NULL,
    [entryDate]             DATETIME        CONSTRAINT [DF_MaintenanceCategory_entryDate] DEFAULT (getdate()) NOT NULL,
    [updateUser]            BIGINT          NULL,
    [updateDate]            DATETIME        NULL,
    [IsActive]              BIT             CONSTRAINT [DF_MaintenanceCategory_IsActive] DEFAULT ((1)) NOT NULL,
    [entryData]             NVARCHAR (20)   NULL,
    [hostName]              NVARCHAR (200)  NULL,
    CONSTRAINT [PK_MaintenanceCategory] PRIMARY KEY CLUSTERED ([MaintenanceCategoryID] ASC),
    CONSTRAINT [FK_MaintenanceCategory_Parent] FOREIGN KEY ([IdaraId_FK], [ParentID]) REFERENCES [Maintenance].[MaintenanceCategory] ([IdaraId_FK], [MaintenanceCategoryID]),
    CONSTRAINT [UQ_MaintenanceCategory_Idara_Category] UNIQUE NONCLUSTERED ([IdaraId_FK] ASC, [MaintenanceCategoryID] ASC)
);


GO

