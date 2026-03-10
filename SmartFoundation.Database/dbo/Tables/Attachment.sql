CREATE TABLE [dbo].[Attachment] (
    [attachmentID]          BIGINT           IDENTITY (1, 1) NOT NULL,
    [attachmentUID]         UNIQUEIDENTIFIER CONSTRAINT [DF_Attachment_attachmentUID] DEFAULT (newid()) NULL,
    [transactionID_FK]      BIGINT           NULL,
    [DocumentID_FK]         BIGINT           NULL,
    [attachmentServerID_FK] INT              NULL,
    [attachmentPath]        NVARCHAR (500)   NULL,
    [attachmentName]        NVARCHAR (1000)  NULL,
    [attachmentExtintion]   NVARCHAR (50)    NULL,
    [attachmentSize]        NVARCHAR (2000)  NULL,
    [attachmentActive]      BIT              NULL,
    [attachmentCanceledBy]  NVARCHAR (500)   NULL,
    [entryDate]             DATETIME         CONSTRAINT [DF_Attachment_entryDate] DEFAULT (getdate()) NULL,
    [entryData]             NVARCHAR (20)    NULL,
    [hostName]              NVARCHAR (200)   CONSTRAINT [DF_Attachment_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_Attachment] PRIMARY KEY CLUSTERED ([attachmentID] ASC)
);

