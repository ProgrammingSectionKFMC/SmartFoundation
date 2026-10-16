CREATE PROCEDURE [dbo].[_BackupDatabase]
(
      @1Home2Work   INT
    , @databaseName SYSNAME = N'DATACORE'
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
          @basePath NVARCHAR(256)
        , @folder   NVARCHAR(4000)
        , @fileName NVARCHAR(4000)
        , @fileDate NVARCHAR(8);

    SET @fileDate = CONVERT(NVARCHAR(8), GETDATE(), 112);

    IF @1Home2Work = 1
        SET @basePath = N'D:\DATACORE BackUp';
    ELSE IF @1Home2Work = 2
        SET @basePath = N'B:\test';
    ELSE
    BEGIN
        ;THROW 50001, N'قيمة @1Home2Work غير صحيحة. استخدم 1 أو 2.', 1;
    END

    IF RIGHT(@basePath, 1) <> N'\'
        SET @basePath += N'\';

    SET @folder = @basePath + @fileDate + N'\';

    BEGIN TRY
        EXEC master.dbo.xp_create_subdir @folder;

        IF NULLIF(LTRIM(RTRIM(@databaseName)), N'') IS NULL
            SET @databaseName = N'DATACORE';

        SET @fileName =
            @folder
            + @databaseName + N'_'
            + CONVERT(NVARCHAR(8), GETDATE(), 112) + N'_'
            + REPLACE(CONVERT(NVARCHAR(8), GETDATE(), 108), N':', N'')
            + N'.bak';

        DECLARE @sql NVARCHAR(MAX) =
    N'BACKUP DATABASE ' + QUOTENAME(@databaseName) +
    N' TO DISK = N''' + REPLACE(@fileName, N'''', N'''''') + N'''
       WITH INIT, CHECKSUM, COPY_ONLY, STATS = 5;';

EXEC sys.sp_executesql @sql;

DECLARE @verifySql NVARCHAR(MAX) =
    N'RESTORE VERIFYONLY
      FROM DISK = N''' + REPLACE(@fileName, N'''', N'''''') + N'''
      WITH CHECKSUM;';

EXEC sys.sp_executesql @verifySql;

SELECT
    1 AS IsSuccessful,
    @databaseName AS DatabaseName,
    @fileName AS BackupFile,
    N'تم أخذ النسخة الاحتياطية والتحقق منها بنجاح.' AS Message_;
    END TRY
   BEGIN CATCH
    THROW;
END CATCH
END