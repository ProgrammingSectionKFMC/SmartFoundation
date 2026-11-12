CREATE TABLE [Maintenance].[MaintenanceRequestStatus] (
    [StatusID]     INT            NOT NULL,
    [StatusName_A] NVARCHAR (100) NOT NULL,
    [StatusCode]   NVARCHAR (50)  NOT NULL,
    [DisplayOrder] INT            NOT NULL,
    [IsClosed]     BIT            CONSTRAINT [DF_MaintenanceRequestStatus_IsClosed] DEFAULT ((0)) NOT NULL,
    [IsActive]     BIT            CONSTRAINT [DF_MaintenanceRequestStatus_IsActive] DEFAULT ((1)) NOT NULL,
    [IdaraId_FK]   BIGINT         NULL,
    [entryDate]    DATETIME       CONSTRAINT [DF_MaintenanceRequestStatus_entryDate] DEFAULT (getdate()) NULL,
    [entryData]    NVARCHAR (20)  NULL,
    [hostName]     NVARCHAR (200) NULL,
    CONSTRAINT [PK_MaintenanceRequestStatus] PRIMARY KEY CLUSTERED ([StatusID] ASC),
    CONSTRAINT [UQ_MaintenanceRequestStatus_StatusCode] UNIQUE NONCLUSTERED ([StatusCode] ASC)
);


GO

