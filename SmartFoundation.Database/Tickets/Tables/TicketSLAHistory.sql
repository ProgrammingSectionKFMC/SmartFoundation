CREATE TABLE [Tickets].[TicketSLAHistory](
	[ticketSLAHistoryID] [bigint] IDENTITY(1,1) NOT NULL,
	[ticketSLAID_FK] [bigint] NOT NULL,
	[idaraID_FK] [int] NOT NULL,
	[slaEventType] [nvarchar](50) NOT NULL,
	[eventDate] [datetime] NOT NULL,
	[notes] [nvarchar](2000) NULL,
	[performerUserID] [int] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[notes_A] [nvarchar](2000) NULL,
 CONSTRAINT [PK_Tickets_TicketSLAHistory] PRIMARY KEY CLUSTERED 
(
	[ticketSLAHistoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[TicketSLAHistory] ADD  CONSTRAINT [DF_Tickets_TicketSLAHistory_eventDate]  DEFAULT (getdate()) FOR [eventDate]
GO

ALTER TABLE [Tickets].[TicketSLAHistory] ADD  CONSTRAINT [DF_Tickets_TicketSLAHistory_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
