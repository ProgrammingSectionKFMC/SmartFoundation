CREATE TABLE [Tickets].[Priority](
	[priorityID] [int] IDENTITY(1,1) NOT NULL,
	[priorityCode] [nvarchar](50) NOT NULL,
	[priorityName_A] [nvarchar](200) NULL,
	[priorityName_E] [nvarchar](200) NULL,
	[priorityDesc] [nvarchar](1000) NULL,
	[priorityLevel] [int] NULL,
	[priorityActive] [bit] NULL,
	[entryDate] [datetime] NULL,
	[entryData] [nvarchar](20) NULL,
	[hostName] [nvarchar](200) NULL,
	[priorityDesc_A] [nvarchar](1000) NULL,
	[priorityColor] [nvarchar](20) NULL,
 CONSTRAINT [PK_Tickets_Priority] PRIMARY KEY CLUSTERED 
(
	[priorityID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
)
GO

ALTER TABLE [Tickets].[Priority] ADD  CONSTRAINT [DF_Tickets_Priority_entryDate]  DEFAULT (getdate()) FOR [entryDate]
GO
