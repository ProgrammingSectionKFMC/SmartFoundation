CREATE TABLE [dbo].[TableChanges] (
    [DatabaseName]  NVARCHAR (250)  NULL,
    [TableName]     NVARCHAR (250)  NULL,
    [EventType]     NVARCHAR (250)  NULL,
    [LoginName]     NVARCHAR (250)  NULL,
    [SQLCommand]    NVARCHAR (2500) NULL,
    [AuditDateTime] DATETIME        NULL
);

