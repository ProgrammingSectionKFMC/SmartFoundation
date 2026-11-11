CREATE TABLE [Tickets].[QualityReview](
	[qualityReviewID] [bigint] IDENTITY(1,1) NOT NULL,
	[ticketID_FK] [bigint] NOT NULL,
	[idaraID_FK] [int] NOT NULL,
	[reviewerUserID] [int] NOT NULL,
	[reviewScope] [nvarchar](200) NULL,
	[qualityReviewResultID_FK] [int] NULL,
	[reviewNotes] [nvarchar](2000) NULL,
	[reviewDate] [datetime] NOT NULL,
	[returnToUserID] [int] NULL,
	[finalized] [bit] NULL,
	[qualityReviewActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[reviewNotes_A] [nvarchar](2000) NULL,
 CONSTRAINT [PK_Tickets_QualityReview] PRIMARY KEY CLUSTERED 
(
	[qualityReviewID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[QualityReview] ADD  CONSTRAINT [DF_Tickets_QualityReview_reviewDate]  DEFAULT (getdate()) FOR [reviewDate]
GO

ALTER TABLE [Tickets].[QualityReview] ADD  CONSTRAINT [DF_Tickets_QualityReview_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
