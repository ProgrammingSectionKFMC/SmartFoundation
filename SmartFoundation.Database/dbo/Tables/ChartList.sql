CREATE TABLE [dbo].[ChartList] (
    [ChartListID]        INT            IDENTITY (1, 1) NOT NULL,
    [ChartListName_A]    NVARCHAR (500) NULL,
    [ChartListName_E]    NVARCHAR (500) NULL,
    [ChartListStartDate] DATETIME       NULL,
    [ChartListEndDate]   DATETIME       NULL,
    [ChartListActive]    BIT            NULL,
    CONSTRAINT [PK_ChartList] PRIMARY KEY CLUSTERED ([ChartListID] ASC)
);

