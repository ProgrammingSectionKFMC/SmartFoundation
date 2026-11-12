CREATE TABLE [Tickets].[TicketAttachment] (
    [ticketAttachmentID]     BIGINT          IDENTITY (1, 1) NOT NULL,
    [ticketID_FK]            BIGINT          NOT NULL,
    [idaraID_FK]             INT             NOT NULL,
    [fileName]               NVARCHAR (500)  NOT NULL,
    [storedFileName]         NVARCHAR (500)  NOT NULL,
    [filePath]               NVARCHAR (1000) NOT NULL,
    [fileSizeBytes]          BIGINT          NULL,
    [contentType]            NVARCHAR (200)  NULL,
    [uploadedByUserID]       INT             NULL,
    [attachmentType]         NVARCHAR (50)   NULL,
    [ticketAttachmentActive] BIT             NULL,
    [entryDate]              DATETIME        CONSTRAINT [DF_Tickets_TicketAttachment_entryDate] DEFAULT (getdate()) NULL,
    [entryData]              NVARCHAR (20)   NULL,
    [hostName]               NVARCHAR (200)  NULL,
    CONSTRAINT [PK_Tickets_TicketAttachment] PRIMARY KEY CLUSTERED ([ticketAttachmentID] ASC)
);


GO

