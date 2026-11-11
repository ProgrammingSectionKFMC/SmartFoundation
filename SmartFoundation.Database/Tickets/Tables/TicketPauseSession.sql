CREATE TABLE [Tickets].[TicketPauseSession](
	[ticketPauseSessionID] [bigint] IDENTITY(1,1) NOT NULL,
	[ticketID_FK] [bigint] NOT NULL,
	[idaraID_FK] [int] NOT NULL,
	[pauseReasonID_FK] [int] NULL,
	[relatedChildTicketID_FK] [bigint] NULL,
	[relatedArbitrationCaseID_FK] [bigint] NULL,
	[relatedClarificationRequestID_FK] [bigint] NULL,
	[pauseStart] [datetime] NOT NULL,
	[pauseEnd] [datetime] NULL,
	[slaPauseFlag] [bit] NULL,
	[pauseNotes] [nvarchar](2000) NULL,
	[ticketPauseSessionActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[pauseNotes_A] [nvarchar](2000) NULL,
 CONSTRAINT [PK_Tickets_TicketPauseSession] PRIMARY KEY CLUSTERED 
(
	[ticketPauseSessionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[TicketPauseSession] ADD  CONSTRAINT [DF_Tickets_TicketPauseSession_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
