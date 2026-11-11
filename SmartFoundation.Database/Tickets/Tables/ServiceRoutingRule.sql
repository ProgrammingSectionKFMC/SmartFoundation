CREATE TABLE [Tickets].[ServiceRoutingRule](
	[serviceRoutingRuleID] [bigint] IDENTITY(1,1) NOT NULL,
	[serviceID_FK] [bigint] NOT NULL,
	[idaraID_FK] [int] NOT NULL,
	[targetDSDID_FK] [int] NOT NULL,
	[queueDistributorID_FK] [int] NULL,
	[effectiveFrom] [datetime] NOT NULL,
	[effectiveTo] [datetime] NULL,
	[approvedByUserID] [int] NULL,
	[changeReason] [nvarchar](1000) NULL,
	[serviceRoutingRuleActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[changeReason_A] [nvarchar](1000) NULL,
 CONSTRAINT [PK_Tickets_ServiceRoutingRule] PRIMARY KEY CLUSTERED 
(
	[serviceRoutingRuleID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[ServiceRoutingRule] ADD  CONSTRAINT [DF_Tickets_ServiceRoutingRule_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
