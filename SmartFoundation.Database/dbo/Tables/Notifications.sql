CREATE TABLE [dbo].[Notifications] (
    [NotificationId] BIGINT         IDENTITY (1, 1) NOT NULL,
    [Title]          NVARCHAR (200) NOT NULL,
    [Body]           NVARCHAR (MAX) NOT NULL,
    [Url_]           NVARCHAR (500) NULL,
    [StartDate]      DATETIME       NULL,
    [EndDate]        DATETIME       NULL,
    [IsActive]       BIT            CONSTRAINT [DF__Notificat__IsAct__57D3B59A] DEFAULT ((1)) NOT NULL,
    [IdaraID_FK]     INT            NULL,
    [entryDate]      DATETIME       CONSTRAINT [DF__Notificat__entry__58C7D9D3] DEFAULT (getdate()) NOT NULL,
    [entryData]      NVARCHAR (20)  NULL,
    [hostName]       NVARCHAR (200) NULL,
    CONSTRAINT [PK__Notifica__20CF2E1236E51D88] PRIMARY KEY CLUSTERED ([NotificationId] ASC)
);

