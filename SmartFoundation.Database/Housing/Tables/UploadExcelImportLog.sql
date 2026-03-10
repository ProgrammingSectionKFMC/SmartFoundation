CREATE TABLE [Housing].[UploadExcelImportLog] (
    [ImportLogID]      INT             IDENTITY (1, 1) NOT NULL,
    [FileHash]         CHAR (64)       NOT NULL,
    [OriginalFileName] NVARCHAR (260)  NULL,
    [UploadedAt]       DATETIME2 (0)   CONSTRAINT [DF_UploadExcelImportLog_UploadedAt] DEFAULT (sysdatetime()) NOT NULL,
    [Column1Name]      NVARCHAR (200)  NULL,
    [Column2Name]      NVARCHAR (200)  NULL,
    [Column3Name]      NVARCHAR (200)  NULL,
    [TotalExcelRows]   INT             NULL,
    [SentRows]         INT             NULL,
    [InsertedRows]     INT             NULL,
    [SkippedEmpty]     INT             NULL,
    [Notes]            NVARCHAR (1000) NULL,
    PRIMARY KEY CLUSTERED ([ImportLogID] ASC)
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_UploadExcelImportLog_FileHash]
    ON [Housing].[UploadExcelImportLog]([FileHash] ASC);

