CREATE TABLE [Tickets].[ArbitrationCase](
	[arbitrationCaseID] [bigint] IDENTITY(1,1) NOT NULL,
	[ticketID_FK] [bigint] NOT NULL,
	[idaraID_FK] [int] NOT NULL,
	[raisedByUserID] [int] NOT NULL,
	[raisedFromDSDID_FK] [int] NOT NULL,
	[arbitrationReasonID_FK] [int] NULL,
	[arbitratorDistributorID] [int] NULL,
	[arbitrationStatus] [nvarchar](50) NOT NULL,
	[decisionType] [nvarchar](50) NULL,
	[decisionTargetDSDID_FK] [int] NULL,
	[decisionNotes] [nvarchar](2000) NULL,
	[decisionDate] [datetime] NULL,
	[arbitrationCaseActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[decisionNotes_A] [nvarchar](2000) NULL,
 CONSTRAINT [PK_Tickets_ArbitrationCase] PRIMARY KEY CLUSTERED 
(
	[arbitrationCaseID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[ArbitrationCase] ADD  CONSTRAINT [DF_Tickets_ArbitrationCase_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
