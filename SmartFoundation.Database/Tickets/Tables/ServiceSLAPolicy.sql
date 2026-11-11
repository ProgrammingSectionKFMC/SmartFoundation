CREATE TABLE [Tickets].[ServiceSLAPolicy](
	[serviceSLAPolicyID] [bigint] IDENTITY(1,1) NOT NULL,
	[idaraID_FK] [int] NOT NULL,
	[serviceID_FK] [bigint] NOT NULL,
	[priorityID_FK] [int] NOT NULL,
	[firstResponseTargetMinutes] [int] NULL,
	[assignmentTargetMinutes] [int] NULL,
	[operationalCompletionTargetMinutes] [int] NULL,
	[finalClosureTargetMinutes] [int] NULL,
	[effectiveFrom] [datetime] NULL,
	[effectiveTo] [datetime] NULL,
	[slaPolicyActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
 CONSTRAINT [PK_Tickets_ServiceSLAPolicy] PRIMARY KEY CLUSTERED 
(
	[serviceSLAPolicyID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[ServiceSLAPolicy] ADD  CONSTRAINT [DF_Tickets_ServiceSLAPolicy_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
