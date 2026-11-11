CREATE TABLE [Tickets].[RequesterType](
	[requesterTypeID] [int] IDENTITY(1,1) NOT NULL,
	[requesterTypeCode] [nvarchar](50) NOT NULL,
	[requesterTypeName_A] [nvarchar](200) NULL,
	[requesterTypeName_E] [nvarchar](200) NULL,
	[requesterTypeDesc] [nvarchar](1000) NULL,
	[requesterTypeActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[requesterTypeDesc_A] [nvarchar](1000) NULL,
 CONSTRAINT [PK_Tickets_RequesterType] PRIMARY KEY CLUSTERED 
(
	[requesterTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[RequesterType] ADD  CONSTRAINT [DF_Tickets_RequesterType_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
