CREATE TABLE [Housing].[UploadExcel] (
    [UploadExcelID] BIGINT          IDENTITY (1, 1) NOT NULL,
    [UploadExcel1]  NVARCHAR (4000) NULL,
    [Column1Name]   NVARCHAR (4000) NULL,
    [UploadExcel2]  NVARCHAR (4000) NULL,
    [Column2Name]   NVARCHAR (4000) NULL,
    [UploadExcel3]  NVARCHAR (4000) NULL,
    [Column3Name]   NVARCHAR (4000) NULL,
    [UploadExcel4]  NVARCHAR (4000) NULL,
    [Column4Name]   NVARCHAR (4000) NULL,
    [InsertedAt]    DATETIME2 (0)   CONSTRAINT [DF_UploadExcel_InsertedAt] DEFAULT (sysutcdatetime()) NOT NULL,
    CONSTRAINT [PK__UploadEx__5A61C607F4B04DDB] PRIMARY KEY CLUSTERED ([UploadExcelID] ASC)
);

