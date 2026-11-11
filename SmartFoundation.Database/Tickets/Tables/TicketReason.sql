CREATE TABLE [Tickets].[TicketReason](
	[ticketReasonID] [bigint] IDENTITY(1,1) NOT NULL,
	[ticketReasonCode] [nvarchar](50) NOT NULL,
	[ticketReasonName_A] [nvarchar](500) NOT NULL,
	[ticketReasonName_E] [nvarchar](500) NULL,
	[ticketReasonDesc] [nvarchar](2000) NULL,
	[serviceID_FK] [bigint] NULL,
	[ticketClassID_FK] [int] NULL,
	[priorityID_FK] [int] NULL,
	[displayOrder] [int] NULL,
	[ticketReasonActive] [bit] NULL,
	[idaraID_FK] [int] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
 CONSTRAINT [PK_TicketReason] PRIMARY KEY CLUSTERED 
(
	[ticketReasonID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

CREATE NONCLUSTERED INDEX [IX_TicketReason_Active_Order] ON [Tickets].[TicketReason]
(
	[ticketReasonActive] ASC,
	[displayOrder] ASC,
	[ticketReasonID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
GO

CREATE NONCLUSTERED INDEX [IX_TicketReason_Class] ON [Tickets].[TicketReason]
(
	[ticketClassID_FK] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
GO

CREATE NONCLUSTERED INDEX [IX_TicketReason_Priority] ON [Tickets].[TicketReason]
(
	[priorityID_FK] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
GO

CREATE NONCLUSTERED INDEX [IX_TicketReason_Service] ON [Tickets].[TicketReason]
(
	[serviceID_FK] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
GO

ALTER TABLE [Tickets].[TicketReason] ADD  CONSTRAINT [DF_TicketReason_displayOrder]  DEFAULT ((0)) FOR [displayOrder]
GO

ALTER TABLE [Tickets].[TicketReason] ADD  CONSTRAINT [DF_TicketReason_ticketReasonActive]  DEFAULT ((1)) FOR [ticketReasonActive]
GO

ALTER TABLE [Tickets].[TicketReason] ADD  CONSTRAINT [DF_TicketReason_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO

ALTER TABLE [Tickets].[TicketReason]  WITH CHECK ADD  CONSTRAINT [FK_TicketReason_Priority] FOREIGN KEY([priorityID_FK])
REFERENCES [Tickets].[Priority] ([priorityID])
GO

ALTER TABLE [Tickets].[TicketReason] CHECK CONSTRAINT [FK_TicketReason_Priority]
GO

ALTER TABLE [Tickets].[TicketReason]  WITH CHECK ADD  CONSTRAINT [FK_TicketReason_Service] FOREIGN KEY([serviceID_FK])
REFERENCES [Tickets].[Service] ([serviceID])
GO

ALTER TABLE [Tickets].[TicketReason] CHECK CONSTRAINT [FK_TicketReason_Service]
GO

ALTER TABLE [Tickets].[TicketReason]  WITH CHECK ADD  CONSTRAINT [FK_TicketReason_TicketClass] FOREIGN KEY([ticketClassID_FK])
REFERENCES [Tickets].[TicketClass] ([ticketClassID])
GO

ALTER TABLE [Tickets].[TicketReason] CHECK CONSTRAINT [FK_TicketReason_TicketClass]
GO
