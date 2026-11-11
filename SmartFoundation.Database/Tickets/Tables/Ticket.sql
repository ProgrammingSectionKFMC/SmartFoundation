CREATE TABLE [Tickets].[Ticket](
	[ticketID] [bigint] IDENTITY(1,1) NOT NULL,
	[ticketNo] [nvarchar](50) NOT NULL,
	[idaraID_FK] [int] NOT NULL,
	[parentTicketID_FK] [bigint] NULL,
	[rootTicketID_FK] [bigint] NULL,
	[serviceID_FK] [bigint] NULL,
	[ticketClassID_FK] [int] NOT NULL,
	[requesterTypeID_FK] [int] NOT NULL,
	[requesterUserID_FK] [int] NULL,
	[requesterResidentID_FK] [bigint] NULL,
	[title] [nvarchar](500) NOT NULL,
	[description_] [nvarchar](4000) NULL,
	[suggestedPriorityID_FK] [int] NULL,
	[effectivePriorityID_FK] [int] NULL,
	[ticketStatusID_FK] [int] NOT NULL,
	[currentDSDID_FK] [int] NULL,
	[currentQueueDistributorID_FK] [int] NULL,
	[assignedUserID_FK] [int] NULL,
	[locationBuildingNo] [nvarchar](100) NULL,
	[locationUnitNo] [nvarchar](50) NULL,
	[locationArea] [nvarchar](200) NULL,
	[operationalResolutionDate] [datetime] NULL,
	[finalClosureDate] [datetime] NULL,
	[requiresQualityReview] [bit] NULL,
	[isOtherService] [bit] NULL,
	[isParentBlocked] [bit] NULL,
	[ticketActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[title_A] [nvarchar](500) NULL,
	[description_A] [nvarchar](4000) NULL,
	[locationArea_A] [nvarchar](200) NULL,
	[reporterName] [nvarchar](200) NULL,
	[reporterPhone] [nvarchar](30) NULL,
	[ticketReasonID_FK] [int] NULL,
 CONSTRAINT [PK_Tickets_Ticket] PRIMARY KEY CLUSTERED 
(
	[ticketID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[Ticket] ADD  CONSTRAINT [DF_Tickets_Ticket_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
