CREATE TABLE [Tickets].[ClarificationReason](
	[clarificationReasonID] [int] IDENTITY(1,1) NOT NULL,
	[clarificationReasonCode] [nvarchar](50) NOT NULL,
	[clarificationReasonName_A] [nvarchar](200) NULL,
	[clarificationReasonName_E] [nvarchar](200) NULL,
	[clarificationReasonDesc] [nvarchar](1000) NULL,
	[clarificationReasonActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[clarificationReasonDesc_A] [nvarchar](1000) NULL,
 CONSTRAINT [PK_Tickets_ClarificationReason] PRIMARY KEY CLUSTERED 
(
	[clarificationReasonID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[ClarificationReason] ADD  CONSTRAINT [DF_Tickets_ClarificationReason_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
