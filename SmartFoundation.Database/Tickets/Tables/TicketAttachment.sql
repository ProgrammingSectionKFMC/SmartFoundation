CREATE TABLE [Tickets].[TicketAttachment](
	[ticketAttachmentID] [bigint] IDENTITY(1,1) NOT NULL,
	[ticketID_FK] [bigint] NOT NULL,
	[idaraID_FK] [int] NOT NULL,
	[fileName] [nvarchar](500) NOT NULL,
	[storedFileName] [nvarchar](500) NOT NULL,
	[filePath] [nvarchar](1000) NOT NULL,
	[fileSizeBytes] [bigint] NULL,
	[contentType] [nvarchar](200) NULL,
	[uploadedByUserID] [int] NULL,
	[attachmentType] [nvarchar](50) NULL,
	[ticketAttachmentActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
 CONSTRAINT [PK_Tickets_TicketAttachment] PRIMARY KEY CLUSTERED 
(
	[ticketAttachmentID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[TicketAttachment] ADD  CONSTRAINT [DF_Tickets_TicketAttachment_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
