CREATE TABLE [Maintenance].[MaintenancePriority] (
    [PriorityID]     INT            NOT NULL,
    [PriorityName_A] NVARCHAR (100) NOT NULL,
    [PriorityCode]   NVARCHAR (50)  NOT NULL,
    [DisplayOrder]   INT            NOT NULL,
    [IsActive]       BIT            CONSTRAINT [DF_MaintenancePriority_IsActive] DEFAULT ((1)) NOT NULL,
    [IdaraId_FK]     BIGINT         NULL,
    [entryDate]      DATETIME       CONSTRAINT [DF_MaintenancePriority_entryDate] DEFAULT (getdate()) NULL,
    [entryData]      NVARCHAR (20)  NULL,
    [hostName]       NVARCHAR (200) NULL,
    CONSTRAINT [PK_MaintenancePriority] PRIMARY KEY CLUSTERED ([PriorityID] ASC),
    CONSTRAINT [UQ_MaintenancePriority_PriorityCode] UNIQUE NONCLUSTERED ([PriorityCode] ASC)
);


GO

