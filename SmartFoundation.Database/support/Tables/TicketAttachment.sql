CREATE TABLE [support].[TicketAttachment] (
    [ticketAttachmentID]     BIGINT          IDENTITY (1, 1) NOT NULL,
    [ticketID_FK]            BIGINT          NOT NULL,
    [fileName]               NVARCHAR (260)  NOT NULL,
    [contentType]            NVARCHAR (100)  NULL,
    [fileSizeBytes]          BIGINT          NULL,
    [storagePath]            NVARCHAR (500)  NULL,
    [fileContent]            VARBINARY (MAX) NULL,
    [uploadedByUserID_FK]    BIGINT          NOT NULL,
    [ticketAttachmentActive] BIT             CONSTRAINT [DF_support_TicketAttachment_Active] DEFAULT ((1)) NOT NULL,
    [entryDate]              DATETIME        CONSTRAINT [DF_support_TicketAttachment_entryDate] DEFAULT (getdate()) NULL,
    [entryData]              NVARCHAR (20)   NULL,
    [hostName]               NVARCHAR (200)  CONSTRAINT [DF_support_TicketAttachment_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_support_TicketAttachment] PRIMARY KEY CLUSTERED ([ticketAttachmentID] ASC),
    CONSTRAINT [CK_support_TicketAttachment_Content] CHECK (nullif(ltrim(rtrim(isnull([storagePath],N''))),N'') IS NOT NULL OR [fileContent] IS NOT NULL),
    CONSTRAINT [FK_support_TicketAttachment_Ticket] FOREIGN KEY ([ticketID_FK]) REFERENCES [support].[Ticket] ([ticketID]),
    CONSTRAINT [FK_support_TicketAttachment_User] FOREIGN KEY ([uploadedByUserID_FK]) REFERENCES [dbo].[Users] ([usersID])
);

