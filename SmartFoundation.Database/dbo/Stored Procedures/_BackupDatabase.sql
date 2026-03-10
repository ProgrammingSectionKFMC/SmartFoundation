CREATE PROCEDURE [dbo].[_BackupDatabase]
(
      @databaseName  NVARCHAR(50)  = N'DATACORE'
    , @pathOfBackup  NVARCHAR(256) = N'D:\DATACORE BackUp'
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
          @name      NVARCHAR(50)
        , @basePath  NVARCHAR(256)
        , @folder    NVARCHAR(4000)
        , @fileName  NVARCHAR(4000)
        , @fileDate  NVARCHAR(8);

    -- تاريخ اليوم YYYYMMDD
    SET @fileDate = CONVERT(NVARCHAR(8), GETDATE(), 112);

    -- المسار الأساسي
    SET @basePath = NULLIF(LTRIM(RTRIM(@pathOfBackup)), N'');
    IF @basePath IS NULL
        SET @basePath = N'D:\DATACORE BackUp';

    -- تأكد ينتهي بـ "\"
    IF RIGHT(@basePath, 1) <> N'\'
        SET @basePath += N'\';

    -- مجلد اليوم
    SET @folder = @basePath + @fileDate + N'\';

    BEGIN TRY
        -- أنشئ مجلد اليوم (إذا موجود ما يضر)
        EXEC master.dbo.xp_create_subdir @folder;

        -- لو أرسلت NULL خله DATACORE
        IF NULLIF(LTRIM(RTRIM(@databaseName)), N'') IS NULL
            SET @databaseName = N'DATACORE';

        -- اسم ملف الباكب داخل مجلد اليوم (مثال: DATACORE_20260224_181530.bak)
        SET @fileName =
            @folder
            + @databaseName + N'_'
            + CONVERT(NVARCHAR(8), GETDATE(), 112) + N'_'
            + REPLACE(CONVERT(NVARCHAR(8), GETDATE(), 108), N':', N'')
            + N'.bak';

        -- نفّذ الباكب
        DECLARE @sql NVARCHAR(MAX) =
            N'BACKUP DATABASE ' + QUOTENAME(@databaseName) +
            N' TO DISK = N''' + REPLACE(@fileName, N'''', N'''''') + N'''
              WITH INIT, CHECKSUM, STATS = 5;';

        EXEC sys.sp_executesql @sql;

        SELECT 1 AS IsSuccessful,
               N'تم أخذ النسخة الاحتياطية بنجاح: ' + @fileName AS Message_;
    END TRY
    BEGIN CATCH
        DECLARE @err NVARCHAR(4000) = ERROR_MESSAGE();
        ;THROW 50002, @err, 1;
    END CATCH
END
