CREATE TABLE [VIC].[_DebugDetailJson] (
    [CapturedAt] DATETIME2 (7)  DEFAULT (sysutcdatetime()) NOT NULL,
    [ActionType] NVARCHAR (100) NULL,
    [MaintOrdID] INT            NULL,
    [RawJson]    NVARCHAR (MAX) NULL
);


GO

