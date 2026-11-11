CREATE TABLE [Tickets].[TicketHistory](
	[ticketHistoryID] [bigint] IDENTITY(1,1) NOT NULL,
	[ticketID_FK] [bigint] NOT NULL,
	[idaraID_FK] [int] NOT NULL,
	[actionTypeCode] [nvarchar](100) NOT NULL,
	[oldStatusID_FK] [int] NULL,
	[newStatusID_FK] [int] NULL,
	[oldDSDID_FK] [int] NULL,
	[newDSDID_FK] [int] NULL,
	[oldAssignedUserID] [int] NULL,
	[newAssignedUserID] [int] NULL,
	[performerUserID] [int] NULL,
	[notes] [nvarchar](2000) NULL,
	[actionDate] [datetime] NOT NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[notes_A] [nvarchar](2000) NULL,
 CONSTRAINT [PK_Tickets_TicketHistory] PRIMARY KEY CLUSTERED 
(
	[ticketHistoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[TicketHistory] ADD  CONSTRAINT [DF_Tickets_TicketHistory_actionDate]  DEFAULT (getdate()) FOR [actionDate]
GO

ALTER TABLE [Tickets].[TicketHistory] ADD  CONSTRAINT [DF_Tickets_TicketHistory_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
