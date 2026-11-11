CREATE TABLE [Tickets].[TicketClass](
	[ticketClassID] [int] IDENTITY(1,1) NOT NULL,
	[ticketClassCode] [nvarchar](50) NOT NULL,
	[ticketClassName_A] [nvarchar](200) NULL,
	[ticketClassName_E] [nvarchar](200) NULL,
	[ticketClassDesc] [nvarchar](1000) NULL,
	[ticketClassActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[ticketClassDesc_A] [nvarchar](1000) NULL,
 CONSTRAINT [PK_Tickets_TicketClass] PRIMARY KEY CLUSTERED 
(
	[ticketClassID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[TicketClass] ADD  CONSTRAINT [DF_Tickets_TicketClass_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
