CREATE TABLE [Tickets].[HistoryActionType](
	[historyActionTypeID] [int] IDENTITY(1,1) NOT NULL,
	[actionTypeCode] [nvarchar](50) NOT NULL,
	[actionTypeName_A] [nvarchar](200) NOT NULL,
	[actionTypeName_E] [nvarchar](200) NULL,
	[historyActionTypeActive] [bit] NOT NULL,
	[entryDate] [datetime] NOT NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
 CONSTRAINT [PK_Tickets_HistoryActionType] PRIMARY KEY CLUSTERED 
(
	[historyActionTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF),
 CONSTRAINT [UQ_Tickets_HistoryActionType_Code] UNIQUE NONCLUSTERED 
(
	[actionTypeCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[HistoryActionType] ADD  CONSTRAINT [DF_Tickets_HistoryActionType_Active]  DEFAULT ((1)) FOR [historyActionTypeActive]
GO

ALTER TABLE [Tickets].[HistoryActionType] ADD  CONSTRAINT [DF_Tickets_HistoryActionType_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
