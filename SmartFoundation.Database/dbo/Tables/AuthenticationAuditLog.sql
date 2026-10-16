CREATE TABLE [dbo].[AuthenticationAuditLog] (
    [AuthenticationAuditLogID] BIGINT          IDENTITY (1, 1) NOT NULL,
    [EventType]                NVARCHAR (50)   NOT NULL,
    [UsersID_FK]               BIGINT          NULL,
    [LoginIdentifier]          NVARCHAR (20)   NULL,
    [IsSuccessful]             BIT             NOT NULL,
    [FailureReasonCode]        NVARCHAR (50)   NULL,
    [FailureMessage]           NVARCHAR (500)  NULL,
    [IPAddress]                NVARCHAR (45)   NULL,
    [HostName]                 NVARCHAR (255)  NULL,
    [UserAgent]                NVARCHAR (1000) NULL,
    [SessionID]                NVARCHAR (200)  NULL,
    [TraceID]                  NVARCHAR (100)  NULL,
    [RequestPath]              NVARCHAR (500)  NULL,
    [OccurredAt]               DATETIME2 (3)   CONSTRAINT [DF_AuthenticationAuditLog_OccurredAt] DEFAULT (sysdatetime()) NOT NULL,
    CONSTRAINT [PK_AuthenticationAuditLog] PRIMARY KEY CLUSTERED ([AuthenticationAuditLogID] ASC),
    CONSTRAINT [CK_AuthenticationAuditLog_EventType] CHECK ([EventType]=N'ACCOUNT_REACTIVATED' OR [EventType]=N'PASSWORD_CHANGE_FAILED' OR [EventType]=N'PASSWORD_CHANGED' OR [EventType]=N'SESSION_EXPIRED' OR [EventType]=N'LOGOUT' OR [EventType]=N'LOGIN_FAILED' OR [EventType]=N'LOGIN_SUCCESS')
);



GO
CREATE NONCLUSTERED INDEX [IX_AuthenticationAuditLog_LoginIdentifier_OccurredAt]
    ON [dbo].[AuthenticationAuditLog]([LoginIdentifier] ASC, [OccurredAt] DESC);

GO
CREATE NONCLUSTERED INDEX [IX_AuthenticationAuditLog_UsersID_EventType_OccurredAt]
    ON [dbo].[AuthenticationAuditLog]([UsersID_FK] ASC, [EventType] ASC, [OccurredAt] DESC);

GO
CREATE NONCLUSTERED INDEX [IX_AuthenticationAuditLog_Success_OccurredAt]
    ON [dbo].[AuthenticationAuditLog]([IsSuccessful] ASC, [OccurredAt] DESC);

GO
CREATE NONCLUSTERED INDEX [IX_AuthenticationAuditLog_LoginPolicy]
    ON [dbo].[AuthenticationAuditLog]
    (
        [LoginIdentifier] ASC,
        [EventType] ASC,
        [FailureReasonCode] ASC,
        [OccurredAt] DESC
    )
    INCLUDE ([UsersID_FK]);

