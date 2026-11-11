CREATE TABLE [Tickets].[QualityReviewResult](
	[qualityReviewResultID] [int] IDENTITY(1,1) NOT NULL,
	[qualityReviewResultCode] [nvarchar](50) NOT NULL,
	[qualityReviewResultName_A] [nvarchar](200) NULL,
	[qualityReviewResultName_E] [nvarchar](200) NULL,
	[qualityReviewResultDesc] [nvarchar](1000) NULL,
	[qualityReviewResultActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[qualityReviewResultDesc_A] [nvarchar](1000) NULL,
 CONSTRAINT [PK_Tickets_QualityReviewResult] PRIMARY KEY CLUSTERED 
(
	[qualityReviewResultID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[QualityReviewResult] ADD  CONSTRAINT [DF_Tickets_QualityReviewResult_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
