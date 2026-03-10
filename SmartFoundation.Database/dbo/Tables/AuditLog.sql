CREATE TABLE [dbo].[AuditLog] (
    [AuditID]     INT            IDENTITY (1, 1) NOT NULL,
    [TableName]   NVARCHAR (200) NOT NULL,
    [ActionType]  NVARCHAR (200) NOT NULL,
    [RecordID]    BIGINT         NULL,
    [PerformedBy] NVARCHAR (100) NULL,
    [Notes]       NVARCHAR (MAX) NULL,
    [PerformedAt] DATETIME       CONSTRAINT [DF__AuditLog__Perfor__36A7CBF9] DEFAULT (getdate()) NULL,
    CONSTRAINT [PK__AuditLog__A17F23B8B83CB07B] PRIMARY KEY CLUSTERED ([AuditID] ASC)
);

