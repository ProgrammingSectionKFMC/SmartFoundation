CREATE TABLE [Tickets].[PauseReason](
	[pauseReasonID] [int] IDENTITY(1,1) NOT NULL,
	[pauseReasonCode] [nvarchar](50) NOT NULL,
	[pauseReasonName_A] [nvarchar](200) NULL,
	[pauseReasonName_E] [nvarchar](200) NULL,
	[pauseReasonDesc] [nvarchar](1000) NULL,
	[pauseReasonActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[pauseReasonDesc_A] [nvarchar](1000) NULL,
 CONSTRAINT [PK_Tickets_PauseReason] PRIMARY KEY CLUSTERED 
(
	[pauseReasonID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[PauseReason] ADD  CONSTRAINT [DF_Tickets_PauseReason_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
