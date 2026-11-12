CREATE TABLE [Housing].[DeductListReportImport] (
    [DeductListReportImportID] BIGINT          IDENTITY (1, 1) NOT NULL,
    [DeductListReportID_FK]    BIGINT          NOT NULL,
    [DeductListID_FK]          INT             NOT NULL,
    [ImportedAmount]           DECIMAL (18, 2) CONSTRAINT [DF_DeductListReportImport_Amount] DEFAULT ((0)) NOT NULL,
    [ImportedRows]             INT             CONSTRAINT [DF_DeductListReportImport_Rows] DEFAULT ((0)) NOT NULL,
    [entryDate]                DATETIME        CONSTRAINT [DF_DeductListReportImport_EntryDate] DEFAULT (getdate()) NOT NULL,
    [entryData]                NVARCHAR (20)   NULL,
    [hostName]                 NVARCHAR (200)  NULL,
    CONSTRAINT [PK_DeductListReportImport] PRIMARY KEY CLUSTERED ([DeductListReportImportID] ASC),
    CONSTRAINT [FK_DeductListReportImport_DeductList] FOREIGN KEY ([DeductListID_FK]) REFERENCES [Housing].[DeductList] ([deductListID]),
    CONSTRAINT [FK_DeductListReportImport_Report] FOREIGN KEY ([DeductListReportID_FK]) REFERENCES [Housing].[DeductListReport] ([DeductListReportID])
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_DeductListReportImport_DeductList]
    ON [Housing].[DeductListReportImport]([DeductListID_FK] ASC);


GO

