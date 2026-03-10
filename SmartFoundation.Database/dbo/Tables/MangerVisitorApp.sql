CREATE TABLE [dbo].[MangerVisitorApp] (
    [id]          INT            IDENTITY (1, 1) NOT NULL,
    [visitorname] NVARCHAR (300) NULL,
    [visitreason] NVARCHAR (MAX) NULL,
    [status]      INT            NULL,
    [response]    NVARCHAR (300) NULL,
    [finish]      INT            NULL,
    [TimeSpan]    DATETIME       CONSTRAINT [DF_MangerVisitorApp_TimeSpan] DEFAULT (getdate()) NULL
);

