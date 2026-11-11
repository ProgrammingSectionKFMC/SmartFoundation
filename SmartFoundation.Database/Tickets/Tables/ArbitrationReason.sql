CREATE TABLE [Tickets].[ArbitrationReason](
	[arbitrationReasonID] [int] IDENTITY(1,1) NOT NULL,
	[arbitrationReasonCode] [nvarchar](50) NOT NULL,
	[arbitrationReasonName_A] [nvarchar](200) NULL,
	[arbitrationReasonName_E] [nvarchar](200) NULL,
	[arbitrationReasonDesc] [nvarchar](1000) NULL,
	[arbitrationReasonActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[arbitrationReasonDesc_A] [nvarchar](1000) NULL,
 CONSTRAINT [PK_Tickets_ArbitrationReason] PRIMARY KEY CLUSTERED 
(
	[arbitrationReasonID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[ArbitrationReason] ADD  CONSTRAINT [DF_Tickets_ArbitrationReason_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
