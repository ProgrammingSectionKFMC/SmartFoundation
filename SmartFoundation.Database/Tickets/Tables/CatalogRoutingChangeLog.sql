CREATE TABLE [Tickets].[CatalogRoutingChangeLog](
	[catalogRoutingChangeLogID] [bigint] IDENTITY(1,1) NOT NULL,
	[serviceID_FK] [bigint] NOT NULL,
	[idaraID_FK] [int] NOT NULL,
	[oldRoutingRuleID_FK] [bigint] NULL,
	[newRoutingRuleID_FK] [bigint] NULL,
	[changeReason] [nvarchar](2000) NULL,
	[sourceArbitrationCaseID_FK] [bigint] NULL,
	[approvedByUserID] [int] NULL,
	[effectiveFrom] [datetime] NOT NULL,
	[loggedDate] [datetime] NOT NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[changeReason_A] [nvarchar](2000) NULL,
 CONSTRAINT [PK_Tickets_CatalogRoutingChangeLog] PRIMARY KEY CLUSTERED 
(
	[catalogRoutingChangeLogID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[CatalogRoutingChangeLog] ADD  CONSTRAINT [DF_Tickets_CatalogRoutingChangeLog_loggedDate]  DEFAULT (getdate()) FOR [loggedDate]
GO

ALTER TABLE [Tickets].[CatalogRoutingChangeLog] ADD  CONSTRAINT [DF_Tickets_CatalogRoutingChangeLog_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
