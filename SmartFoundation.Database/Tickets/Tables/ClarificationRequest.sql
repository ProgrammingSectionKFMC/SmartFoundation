CREATE TABLE [Tickets].[ClarificationRequest](
	[clarificationRequestID] [bigint] IDENTITY(1,1) NOT NULL,
	[ticketID_FK] [bigint] NOT NULL,
	[idaraID_FK] [int] NOT NULL,
	[requestedByUserID] [int] NULL,
	[requestedFromUserID] [int] NULL,
	[requestedFromDSDID_FK] [int] NULL,
	[clarificationReasonID_FK] [int] NULL,
	[requestNotes] [nvarchar](2000) NULL,
	[responseNotes] [nvarchar](2000) NULL,
	[requestDate] [datetime] NOT NULL,
	[responseDate] [datetime] NULL,
	[clarificationStatus] [nvarchar](50) NOT NULL,
	[clarificationActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[requestNotes_A] [nvarchar](2000) NULL,
	[responseNotes_A] [nvarchar](2000) NULL,
 CONSTRAINT [PK_Tickets_ClarificationRequest] PRIMARY KEY CLUSTERED 
(
	[clarificationRequestID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[ClarificationRequest] ADD  CONSTRAINT [DF_Tickets_ClarificationRequest_requestDate]  DEFAULT (getdate()) FOR [requestDate]
GO

ALTER TABLE [Tickets].[ClarificationRequest] ADD  CONSTRAINT [DF_Tickets_ClarificationRequest_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
