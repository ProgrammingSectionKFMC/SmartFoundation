CREATE TABLE [Tickets].[TicketSLA](
	[ticketSLAID] [bigint] IDENTITY(1,1) NOT NULL,
	[ticketID_FK] [bigint] NOT NULL,
	[idaraID_FK] [int] NOT NULL,
	[slaTypeCode] [nvarchar](50) NOT NULL,
	[targetMinutes] [int] NULL,
	[elapsedMinutes] [int] NULL,
	[remainingMinutes] [int] NULL,
	[isBreached] [bit] NULL,
	[slaStartDate] [datetime] NULL,
	[slaStopDate] [datetime] NULL,
	[slaCompletionDate] [datetime] NULL,
	[lastCalculatedDate] [datetime] NULL,
	[ticketSLAActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
 CONSTRAINT [PK_Tickets_TicketSLA] PRIMARY KEY CLUSTERED 
(
	[ticketSLAID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[TicketSLA] ADD  CONSTRAINT [DF_Tickets_TicketSLA_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
