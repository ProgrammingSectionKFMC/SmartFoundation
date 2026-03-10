
CREATE   PROCEDURE [Housing].[UploadExcel_ImportSelected3Cols]
(
    @Column1Name NVARCHAR(255) = NULL,
    @Column2Name NVARCHAR(255) = NULL,
    @Column3Name NVARCHAR(255) = NULL,
    @Column4Name NVARCHAR(255) = NULL,
    @FileHash    CHAR(64),
    @OriginalFileName NVARCHAR(260) = NULL,
    @Rows [Housing].[UploadExcelRowType] READONLY
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StartedTran bit = 0;

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@FileHash)), N'') IS NULL
            THROW 50001, N'بصمة الملف غير موجودة.', 1;

        IF NOT EXISTS (SELECT 1 FROM @Rows)
            THROW 50001, N'لا توجد صفوف للإدخال.', 1;

        IF @@TRANCOUNT = 0
        BEGIN
            SET @StartedTran = 1;
            BEGIN TRAN;
        END

        -- ✅ منع استيراد نفس الملف أكثر من مرة فقط
        IF EXISTS (SELECT 1 FROM [Housing].[UploadExcelImportLog] WHERE FileHash = @FileHash)
        BEGIN
            IF @StartedTran = 1 COMMIT;
            SELECT CAST(0 AS bit) AS IsSuccessful,
                   N'تم استيراد نفس الملف سابقاً، ولن يتم تكرار الإدخال.' AS Message_,
                   0 AS InsertedRows;
            RETURN;
        END

        ;WITH Clean AS
        (
            SELECT
                UploadExcel1 = NULLIF(LTRIM(RTRIM(UploadExcel1)), N''),
                UploadExcel2 = NULLIF(LTRIM(RTRIM(UploadExcel2)), N''),
                UploadExcel3 = NULLIF(LTRIM(RTRIM(UploadExcel3)), N''),
                UploadExcel4 = NULLIF(LTRIM(RTRIM(UploadExcel4)), N'')
            FROM @Rows
            WHERE NOT (
                NULLIF(LTRIM(RTRIM(ISNULL(UploadExcel1,N''))), N'') IS NULL AND
                NULLIF(LTRIM(RTRIM(ISNULL(UploadExcel2,N''))), N'') IS NULL AND
                NULLIF(LTRIM(RTRIM(ISNULL(UploadExcel3,N''))), N'') IS NULL AND
                NULLIF(LTRIM(RTRIM(ISNULL(UploadExcel4,N''))), N'') IS NULL
            )
        )
        -- ✅ إدخال مباشر بدون منع تكرار داخل الجدول/الدفعة
        INSERT INTO [Housing].[UploadExcel] ([UploadExcel1],[UploadExcel2],[UploadExcel3],[UploadExcel4],[Column1Name],[Column2Name],[Column3Name],[Column4Name])
        SELECT UploadExcel1, UploadExcel2, UploadExcel3, UploadExcel4,@Column1Name,@Column2Name,@Column3Name ,@Column4Name
        FROM Clean;

        DECLARE @Inserted int = @@ROWCOUNT;

        INSERT INTO [Housing].[UploadExcelImportLog] (FileHash, OriginalFileName, InsertedRows)
        VALUES (@FileHash, @OriginalFileName, @Inserted);

        IF @StartedTran = 1 COMMIT;

        SELECT CAST(1 AS bit) AS IsSuccessful,
               CONCAT(N'تم إدخال ', @Inserted, N' صف بنجاح.') AS Message_,
               @Inserted AS InsertedRows;
    END TRY
    BEGIN CATCH
        IF @StartedTran = 1 AND @@TRANCOUNT > 0 ROLLBACK;
        ;THROW;
    END CATCH
END
