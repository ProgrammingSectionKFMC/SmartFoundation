CREATE TABLE [Tickets].[TicketStatus](
	[ticketStatusID] [int] IDENTITY(1,1) NOT NULL,
	[ticketStatusCode] [nvarchar](50) NOT NULL,
	[ticketStatusName_A] [nvarchar](200) NULL,
	[ticketStatusName_E] [nvarchar](200) NULL,
	[ticketStatusDesc] [nvarchar](1000) NULL,
	[ticketStatusActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[ticketStatusDesc_A] [nvarchar](1000) NULL,
	[ticketStatusColor] [nvarchar](20) NULL,
 CONSTRAINT [PK_Tickets_TicketStatus] PRIMARY KEY CLUSTERED 
(
	[ticketStatusID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[TicketStatus] ADD  CONSTRAINT [DF_Tickets_TicketStatus_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
