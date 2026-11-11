CREATE TABLE [Tickets].[TicketDescriptionTemplate](
	[templateID] [bigint] IDENTITY(1,1) NOT NULL,
	[templateCode] [nvarchar](50) NOT NULL,
	[templateName_A] [nvarchar](500) NOT NULL,
	[templateName_E] [nvarchar](500) NULL,
	[templateContent_A] [nvarchar](4000) NOT NULL,
	[templateContent_E] [nvarchar](4000) NULL,
	[templateDesc] [nvarchar](2000) NULL,
	[serviceID_FK] [bigint] NULL,
	[ticketClassID_FK] [int] NULL,
	[displayOrder] [int] NULL,
	[templateActive] [bit] NULL,
	[idaraID_FK] [int] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
 CONSTRAINT [PK_TicketDescriptionTemplate] PRIMARY KEY CLUSTERED 
(
	[templateID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

CREATE NONCLUSTERED INDEX [IX_TicketDescriptionTemplate_Active_Order] ON [Tickets].[TicketDescriptionTemplate]
(
	[templateActive] ASC,
	[displayOrder] ASC,
	[templateID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
GO

CREATE NONCLUSTERED INDEX [IX_TicketDescriptionTemplate_Class] ON [Tickets].[TicketDescriptionTemplate]
(
	[ticketClassID_FK] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
GO

CREATE NONCLUSTERED INDEX [IX_TicketDescriptionTemplate_Service] ON [Tickets].[TicketDescriptionTemplate]
(
	[serviceID_FK] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
GO

ALTER TABLE [Tickets].[TicketDescriptionTemplate] ADD  CONSTRAINT [DF_TicketDescriptionTemplate_displayOrder]  DEFAULT ((0)) FOR [displayOrder]
GO

ALTER TABLE [Tickets].[TicketDescriptionTemplate] ADD  CONSTRAINT [DF_TicketDescriptionTemplate_templateActive]  DEFAULT ((1)) FOR [templateActive]
GO

ALTER TABLE [Tickets].[TicketDescriptionTemplate] ADD  CONSTRAINT [DF_TicketDescriptionTemplate_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO

ALTER TABLE [Tickets].[TicketDescriptionTemplate]  WITH CHECK ADD  CONSTRAINT [FK_TicketDescriptionTemplate_Service] FOREIGN KEY([serviceID_FK])
REFERENCES [Tickets].[Service] ([serviceID])
GO

ALTER TABLE [Tickets].[TicketDescriptionTemplate] CHECK CONSTRAINT [FK_TicketDescriptionTemplate_Service]
GO

ALTER TABLE [Tickets].[TicketDescriptionTemplate]  WITH CHECK ADD  CONSTRAINT [FK_TicketDescriptionTemplate_TicketClass] FOREIGN KEY([ticketClassID_FK])
REFERENCES [Tickets].[TicketClass] ([ticketClassID])
GO

ALTER TABLE [Tickets].[TicketDescriptionTemplate] CHECK CONSTRAINT [FK_TicketDescriptionTemplate_TicketClass]
GO
