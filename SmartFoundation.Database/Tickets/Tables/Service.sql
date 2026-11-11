CREATE TABLE [Tickets].[Service](
	[serviceID] [bigint] IDENTITY(1,1) NOT NULL,
	[serviceCode] [nvarchar](100) NOT NULL,
	[serviceName_A] [nvarchar](500) NULL,
	[serviceName_E] [nvarchar](500) NULL,
	[serviceDesc] [nvarchar](2000) NULL,
	[idaraID_FK] [int] NOT NULL,
	[ticketClassID_FK] [int] NULL,
	[defaultPriorityID_FK] [int] NULL,
	[requiresLocation] [bit] NULL,
	[allowsChildTickets] [bit] NULL,
	[requiresQualityReview] [bit] NULL,
	[serviceActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[serviceDesc_A] [nvarchar](2000) NULL,
 CONSTRAINT [PK_Tickets_Service] PRIMARY KEY CLUSTERED 
(
	[serviceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[Service] ADD  CONSTRAINT [DF_Tickets_Service_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
