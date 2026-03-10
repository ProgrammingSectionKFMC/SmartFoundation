CREATE TABLE [dbo].[KFMCReports] (
    [KFMCReportsID]        INT              IDENTITY (1, 1) NOT NULL,
    [KFMCReportNo]         AS               (concat(CONVERT([nvarchar](4),datepart(year,[entryDate])),right('0'+CONVERT([nvarchar](2),datepart(month,[entryDate])),(2)),right('0'+CONVERT([nvarchar](2),datepart(day,[entryDate])),(2)),right('000000000'+CONVERT([nvarchar](50),[KFMCReportsID]),(9)))) PERSISTED NOT NULL,
    [KFMCReportsUID]       UNIQUEIDENTIFIER CONSTRAINT [DF_Table_1_HousingReportsUID] DEFAULT (newid()) NOT NULL,
    [ReportDetails]        NVARCHAR (MAX)   NULL,
    [KFMCReportsTypeID_FK] INT              NULL,
    [ReportActive]         BIT              NULL,
    [entryDate]            DATETIME         CONSTRAINT [DF_KFMCReports_entryDate] DEFAULT (getdate()) NULL,
    [entryData]            NVARCHAR (20)    NULL,
    [hostName]             NVARCHAR (200)   NULL,
    CONSTRAINT [PK_KFMCReports] PRIMARY KEY CLUSTERED ([KFMCReportsID] ASC)
);

