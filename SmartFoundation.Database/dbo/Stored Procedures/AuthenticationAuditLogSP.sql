CREATE PROCEDURE [dbo].[AuthenticationAuditLogSP]
      @EventType          NVARCHAR(50)
    , @UsersID_FK         BIGINT = NULL
    , @LoginIdentifier    NVARCHAR(20) = NULL
    , @IsSuccessful       BIT
    , @FailureReasonCode  NVARCHAR(50) = NULL
    , @FailureMessage     NVARCHAR(500) = NULL
    , @IPAddress          NVARCHAR(45) = NULL
    , @HostName           NVARCHAR(255) = NULL
    , @UserAgent          NVARCHAR(1000) = NULL
    , @SessionID          NVARCHAR(200) = NULL
    , @TraceID            NVARCHAR(100) = NULL
    , @RequestPath        NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StartedTransaction BIT = 0;

    IF @@TRANCOUNT = 0
    BEGIN
        BEGIN TRANSACTION;
        SET @StartedTransaction = 1;
    END;

    BEGIN TRY

    SET @EventType = UPPER(LTRIM(RTRIM(@EventType)));

    IF @EventType NOT IN
    (
        N'LOGIN_SUCCESS',
        N'LOGIN_FAILED',
        N'LOGOUT',
        N'SESSION_EXPIRED',
        N'PASSWORD_CHANGED',
        N'PASSWORD_CHANGE_FAILED',
        N'ACCOUNT_REACTIVATED'
    )
    BEGIN
        ;THROW 50001, N'نوع حدث المصادقة غير معتمد.', 1;
    END;

    INSERT INTO [dbo].[AuthenticationAuditLog]
    (
          [EventType]
        , [UsersID_FK]
        , [LoginIdentifier]
        , [IsSuccessful]
        , [FailureReasonCode]
        , [FailureMessage]
        , [IPAddress]
        , [HostName]
        , [UserAgent]
        , [SessionID]
        , [TraceID]
        , [RequestPath]
    )
    VALUES
    (
          @EventType
        , @UsersID_FK
        , NULLIF(LTRIM(RTRIM(@LoginIdentifier)), N'')
        , @IsSuccessful
        , NULLIF(UPPER(LTRIM(RTRIM(@FailureReasonCode))), N'')
        , NULLIF(LTRIM(RTRIM(@FailureMessage)), N'')
        , NULLIF(LTRIM(RTRIM(@IPAddress)), N'')
        , NULLIF(LTRIM(RTRIM(@HostName)), N'')
        , NULLIF(LTRIM(RTRIM(@UserAgent)), N'')
        , NULLIF(LTRIM(RTRIM(@SessionID)), N'')
        , NULLIF(LTRIM(RTRIM(@TraceID)), N'')
        , NULLIF(LTRIM(RTRIM(@RequestPath)), N'')
    );

    DECLARE @AuthenticationAuditLogID BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());
    DECLARE @AccountDeactivated BIT = 0;

    IF @EventType = N'LOGIN_FAILED'
       AND @FailureReasonCode IN (N'INVALID_CREDENTIALS', N'AUTHENTICATION_REJECTED')
       AND @LoginIdentifier IS NOT NULL
    BEGIN
        DECLARE @TargetUsersID BIGINT;

        SELECT TOP (1) @TargetUsersID = u.usersID
        FROM dbo.Users u WITH (UPDLOCK, HOLDLOCK)
        WHERE u.nationalID = @LoginIdentifier
          AND u.usersActive = 1
          AND EXISTS
          (
              SELECT 1
              FROM dbo.UsersDetails userDetails
              WHERE userDetails.usersID_FK = u.usersID
                AND userDetails.userActive = 1
          )
        ORDER BY u.usersID DESC;

        IF @TargetUsersID IS NOT NULL
        BEGIN
            DECLARE @LastSuccessAt DATETIME2(3);

            SELECT @LastSuccessAt = MAX(auditLog.OccurredAt)
            FROM dbo.AuthenticationAuditLog auditLog
            WHERE auditLog.LoginIdentifier = @LoginIdentifier
              AND auditLog.EventType IN (N'LOGIN_SUCCESS', N'ACCOUNT_REACTIVATED');

            IF
            (
                SELECT COUNT(*)
                FROM
                (
                    SELECT TOP (10) auditLog.OccurredAt
                    FROM dbo.AuthenticationAuditLog auditLog WITH (UPDLOCK, HOLDLOCK)
                    WHERE auditLog.LoginIdentifier = @LoginIdentifier
                      AND auditLog.EventType = N'LOGIN_FAILED'
                      AND auditLog.FailureReasonCode IN
                      (
                          N'INVALID_CREDENTIALS',
                          N'AUTHENTICATION_REJECTED'
                      )
                      AND (@LastSuccessAt IS NULL OR auditLog.OccurredAt > @LastSuccessAt)
                    ORDER BY auditLog.OccurredAt DESC, auditLog.AuthenticationAuditLogID DESC
                ) recentFailures
                WHERE recentFailures.OccurredAt >= DATEADD(HOUR, -1, SYSDATETIME())
            ) >= 10
            BEGIN
                UPDATE userDetails
                SET
                      userActive = 0
                    , UDendDate = GETDATE()
                    , canceldWhy = N'تم التعطيل تلقائيًا بعد عشر محاولات دخول فاشلة متتالية خلال ساعة واحدة'
                    , canceldBy = NULL
                FROM dbo.UsersDetails userDetails
                WHERE userDetails.usersID_FK = @TargetUsersID
                  AND userDetails.userActive = 1;

                IF @@ROWCOUNT > 0
                BEGIN
                    SET @AccountDeactivated = 1;

                    UPDATE dbo.AuthenticationAuditLog
                    SET
                          UsersID_FK = ISNULL(UsersID_FK, @TargetUsersID)
                        , FailureReasonCode = N'ACCOUNT_DEACTIVATED_BY_FAILED_LOGIN'
                        , FailureMessage = N'تم إلغاء تنشيط الحساب بعد عشر محاولات دخول فاشلة متتالية خلال ساعة واحدة.'
                    WHERE AuthenticationAuditLogID = @AuthenticationAuditLogID;
                END;
            END;
        END;
    END;

    IF @StartedTransaction = 1
        COMMIT TRANSACTION;

    SELECT
          CAST(1 AS BIT) AS [IsSuccessful]
        , @AuthenticationAuditLogID AS [AuthenticationAuditLogID]
        , @AccountDeactivated AS [AccountDeactivated];
    END TRY
    BEGIN CATCH
        IF @StartedTransaction = 1 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;

