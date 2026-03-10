CREATE TABLE [dbo].[ErrorLog] (
    [ErrorLogID]      INT             IDENTITY (1, 1) NOT NULL,
    [ERROR_MESSAGE_]  NVARCHAR (4000) NULL,
    [ERROR_SEVERITY_] NVARCHAR (4000) NULL,
    [ERROR_STATE_]    NVARCHAR (4000) NULL,
    [SP_NAME]         NVARCHAR (4000) NULL,
    [entryDate]       DATETIME        CONSTRAINT [DF_ErrorLog_entryDate] DEFAULT (getdate()) NULL,
    [entryData]       NVARCHAR (20)   NULL,
    [hostName]        NVARCHAR (200)  NULL,
    CONSTRAINT [PK_ErrorLog] PRIMARY KEY CLUSTERED ([ErrorLogID] ASC)
);

