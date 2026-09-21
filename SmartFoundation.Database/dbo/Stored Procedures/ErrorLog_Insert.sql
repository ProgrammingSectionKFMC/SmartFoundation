CREATE PROCEDURE [dbo].[ErrorLog_Insert]
      @ErrorMessage   NVARCHAR(4000)
    , @ErrorSeverity  NVARCHAR(4000) = NULL
    , @ErrorState     NVARCHAR(4000) = NULL
    , @SourceName     NVARCHAR(4000) = NULL
    , @EntryData      NVARCHAR(20) = NULL
    , @HostName       NVARCHAR(200) = NULL
    , @StackTrace     NVARCHAR(MAX) = NULL
    , @InnerException NVARCHAR(MAX) = NULL
    , @RequestPath    NVARCHAR(1000) = NULL
    , @HttpMethod     NVARCHAR(20) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.ErrorLog
    (
          ERROR_MESSAGE_, ERROR_SEVERITY_, ERROR_STATE_, SP_NAME
        , entryDate, entryData, hostName
        , StackTrace, InnerException, RequestPath, HttpMethod
    )
    OUTPUT INSERTED.ErrorLogID
    VALUES
    (
          @ErrorMessage, @ErrorSeverity, @ErrorState, @SourceName
        , GETDATE(), @EntryData, @HostName
        , @StackTrace, @InnerException, @RequestPath, @HttpMethod
    );
END;
