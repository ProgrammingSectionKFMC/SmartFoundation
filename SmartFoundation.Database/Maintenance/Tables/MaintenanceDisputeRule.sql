CREATE TABLE [Maintenance].[MaintenanceDisputeRule] (
    [DisputeRuleID]    BIGINT          IDENTITY (1, 1) NOT NULL,
    [IdaraId_FK]       BIGINT          NOT NULL,
    [FromDSDID]        BIGINT          NULL,
    [ToDSDID]          BIGINT          NULL,
    [ArbitrationDSDID] BIGINT          NOT NULL,
    [RuleDescription]  NVARCHAR (1000) NULL,
    [entryUser]        BIGINT          NULL,
    [entryDate]        DATETIME        CONSTRAINT [DF_MaintenanceDisputeRule_entryDate] DEFAULT (getdate()) NOT NULL,
    [updateUser]       BIGINT          NULL,
    [updateDate]       DATETIME        NULL,
    [IsActive]         BIT             CONSTRAINT [DF_MaintenanceDisputeRule_IsActive] DEFAULT ((1)) NOT NULL,
    [entryData]        NVARCHAR (20)   NULL,
    [hostName]         NVARCHAR (200)  NULL,
    CONSTRAINT [PK_MaintenanceDisputeRule] PRIMARY KEY CLUSTERED ([DisputeRuleID] ASC),
    CONSTRAINT [FK_MaintenanceDisputeRule_DeptSecDiv_Arbitration] FOREIGN KEY ([ArbitrationDSDID]) REFERENCES [dbo].[DeptSecDiv] ([DSDID]),
    CONSTRAINT [FK_MaintenanceDisputeRule_DeptSecDiv_From] FOREIGN KEY ([FromDSDID]) REFERENCES [dbo].[DeptSecDiv] ([DSDID]),
    CONSTRAINT [FK_MaintenanceDisputeRule_DeptSecDiv_To] FOREIGN KEY ([ToDSDID]) REFERENCES [dbo].[DeptSecDiv] ([DSDID])
);


GO

