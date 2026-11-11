CREATE TABLE [Tickets].[ServiceCatalogSuggestion](
	[serviceCatalogSuggestionID] [bigint] IDENTITY(1,1) NOT NULL,
	[sourceTicketID_FK] [bigint] NULL,
	[idaraID_FK] [int] NOT NULL,
	[proposedServiceName_A] [nvarchar](500) NULL,
	[proposedServiceName_E] [nvarchar](500) NULL,
	[proposedServiceDesc] [nvarchar](2000) NULL,
	[proposedTargetDSDID_FK] [int] NULL,
	[proposedPriorityID_FK] [int] NULL,
	[approvalStatus] [nvarchar](50) NULL,
	[approvedByUserID] [int] NULL,
	[approvalDate] [datetime] NULL,
	[approvalNotes] [nvarchar](2000) NULL,
	[createdServiceID_FK] [bigint] NULL,
	[suggestionActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[proposedServiceDesc_A] [nvarchar](2000) NULL,
	[approvalNotes_A] [nvarchar](2000) NULL,
 CONSTRAINT [PK_Tickets_ServiceCatalogSuggestion] PRIMARY KEY CLUSTERED 
(
	[serviceCatalogSuggestionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[ServiceCatalogSuggestion] ADD  CONSTRAINT [DF_Tickets_ServiceCatalogSuggestion_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
