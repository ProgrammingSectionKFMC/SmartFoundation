CREATE TABLE [dbo].[UserNotifications] (
    [UserNotificationId] BIGINT         IDENTITY (1, 1) NOT NULL,
    [NotificationId_FK]  BIGINT         NOT NULL,
    [UserId_FK]          BIGINT         NOT NULL,
    [IsRead]             BIT            CONSTRAINT [DF__UserNotif__IsRea__6251440D] DEFAULT ((0)) NOT NULL,
    [ReadUtc]            DATETIME       NULL,
    [IsClicked]          BIT            NULL,
    [ClickUtc]           DATETIME       NULL,
    [DeliveredUtc]       DATETIME       CONSTRAINT [DF__UserNotif__Deliv__63456846] DEFAULT (sysutcdatetime()) NOT NULL,
    [entryDate]          DATETIME       CONSTRAINT [DF__UserNotif__entry__64398C7F] DEFAULT (getdate()) NOT NULL,
    [entryData]          NVARCHAR (20)  NULL,
    [hostName]           NVARCHAR (200) NULL,
    CONSTRAINT [PK__UserNoti__EB298629689886F9] PRIMARY KEY CLUSTERED ([UserNotificationId] ASC),
    CONSTRAINT [FK_UserNotifications_Notifications] FOREIGN KEY ([NotificationId_FK]) REFERENCES [dbo].[Notifications] ([NotificationId]),
    CONSTRAINT [FK_UserNotifications_Users] FOREIGN KEY ([UserId_FK]) REFERENCES [dbo].[Users] ([usersID]),
    CONSTRAINT [UQ_UserNotifications] UNIQUE NONCLUSTERED ([NotificationId_FK] ASC, [UserId_FK] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_UserNotifications_User_IsRead]
    ON [dbo].[UserNotifications]([UserId_FK] ASC, [IsRead] ASC, [DeliveredUtc] DESC);

