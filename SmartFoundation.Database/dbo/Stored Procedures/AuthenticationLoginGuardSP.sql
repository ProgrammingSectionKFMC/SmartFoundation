CREATE PROCEDURE [dbo].[AuthenticationLoginGuardSP]
    @LoginIdentifier NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @LoginIdentifier = NULLIF(LTRIM(RTRIM(@LoginIdentifier)), N'');

    IF @LoginIdentifier IS NULL
    BEGIN
        SELECT
              CAST(0 AS BIT) AS [IsAllowed]
            , CAST(1 AS BIT) AS [IsAvailable]
            , CAST(NULL AS BIGINT) AS [UsersID]
            , N'MISSING_IDENTIFIER' AS [BlockReasonCode]
            , N'الرجاء إدخال بيانات تسجيل الدخول.' AS [Message_]
            , CAST(NULL AS DATETIME2(3)) AS [LockedUntil]
            , CAST(0 AS INT) AS [RetryAfterSeconds];
        RETURN;
    END;

    DECLARE @Now DATETIME2(3) = SYSDATETIME();
    DECLARE @UsersID BIGINT;
    DECLARE @UsersActive BIT;
    DECLARE @LatestCanceledBy NVARCHAR(500);

    SELECT TOP (1)
          @UsersID = u.usersID
        , @UsersActive = CONVERT(BIT, CASE WHEN EXISTS
          (
              SELECT 1
              FROM dbo.UsersDetails userDetails
              WHERE userDetails.usersID_FK = u.usersID
                AND userDetails.userActive = 1
          ) THEN 1 ELSE 0 END)
    FROM dbo.Users u
    WHERE u.nationalID = @LoginIdentifier
    ORDER BY u.usersID DESC;

    SELECT TOP (1) @LatestCanceledBy = userDetails.canceldBy
    FROM dbo.UsersDetails userDetails
    WHERE userDetails.usersID_FK = @UsersID
    ORDER BY userDetails.usersDetailsID DESC;

    IF @UsersID IS NOT NULL
       AND ISNULL(@UsersActive, 0) = 0
       AND NULLIF(LTRIM(RTRIM(@LatestCanceledBy)), N'') IS NOT NULL
    BEGIN
        SELECT
              CAST(0 AS BIT) AS [IsAllowed]
            , CAST(1 AS BIT) AS [IsAvailable]
            , @UsersID AS [UsersID]
            , N'ACCOUNT_DEACTIVATED_BY_ADMIN' AS [BlockReasonCode]
            , N'حسابك معطل، يرجى التواصل مع مدير النظام.' AS [Message_]
            , CAST(NULL AS DATETIME2(3)) AS [LockedUntil]
            , CAST(0 AS INT) AS [RetryAfterSeconds];
        RETURN;
    END;

    IF @UsersID IS NOT NULL
       AND ISNULL(@UsersActive, 0) = 0
       AND EXISTS
       (
           SELECT 1
           FROM dbo.AuthenticationAuditLog auditLog
           WHERE auditLog.UsersID_FK = @UsersID
             AND auditLog.FailureReasonCode = N'ACCOUNT_DEACTIVATED_BY_FAILED_LOGIN'
             AND NOT EXISTS
             (
                 SELECT 1
                 FROM dbo.AuthenticationAuditLog reactivation
                 WHERE reactivation.UsersID_FK = @UsersID
                   AND reactivation.EventType = N'ACCOUNT_REACTIVATED'
                   AND reactivation.OccurredAt > auditLog.OccurredAt
             )
       )
    BEGIN
        SELECT
              CAST(0 AS BIT) AS [IsAllowed]
            , CAST(1 AS BIT) AS [IsAvailable]
            , @UsersID AS [UsersID]
            , N'ACCOUNT_DEACTIVATED' AS [BlockReasonCode]
            , N'تم إلغاء تنشيط الحساب بسبب تكرار محاولات الدخول الفاشلة. يرجى التواصل مع مسؤول النظام.' AS [Message_]
            , CAST(NULL AS DATETIME2(3)) AS [LockedUntil]
            , CAST(0 AS INT) AS [RetryAfterSeconds];
        RETURN;
    END;

    DECLARE @LastSuccessAt DATETIME2(3);
    DECLARE @ConsecutiveFailureCount INT;
    DECLARE @LastQualifyingFailureAt DATETIME2(3);

    SELECT @LastSuccessAt = MAX(auditLog.OccurredAt)
    FROM dbo.AuthenticationAuditLog auditLog
    WHERE auditLog.LoginIdentifier = @LoginIdentifier
      AND auditLog.EventType IN (N'LOGIN_SUCCESS', N'ACCOUNT_REACTIVATED');

    SELECT
          @ConsecutiveFailureCount = COUNT(*)
        , @LastQualifyingFailureAt = MAX(auditLog.OccurredAt)
    FROM dbo.AuthenticationAuditLog auditLog
    WHERE auditLog.LoginIdentifier = @LoginIdentifier
      AND auditLog.EventType = N'LOGIN_FAILED'
      AND auditLog.FailureReasonCode IN
      (
          N'INVALID_CREDENTIALS',
          N'AUTHENTICATION_REJECTED'
      )
      AND (@LastSuccessAt IS NULL OR auditLog.OccurredAt > @LastSuccessAt);

    SET @ConsecutiveFailureCount = ISNULL(@ConsecutiveFailureCount, 0);

    DECLARE @LockedUntil DATETIME2(3) =
        CASE
            WHEN @ConsecutiveFailureCount > 0
             AND @ConsecutiveFailureCount % 5 = 0
             AND @LastQualifyingFailureAt IS NOT NULL
            THEN DATEADD(MINUTE, 5, @LastQualifyingFailureAt)
            ELSE NULL
        END;

    IF @LockedUntil IS NOT NULL AND @LockedUntil > @Now
    BEGIN
        SELECT
              CAST(0 AS BIT) AS [IsAllowed]
            , CAST(1 AS BIT) AS [IsAvailable]
            , @UsersID AS [UsersID]
            , N'TEMPORARY_LOCKOUT' AS [BlockReasonCode]
            , N'تم إيقاف محاولات الدخول مؤقتًا لمدة خمس دقائق بسبب تكرار المحاولات الفاشلة.' AS [Message_]
            , @LockedUntil AS [LockedUntil]
            , CONVERT(INT, CEILING(DATEDIFF_BIG(MILLISECOND, @Now, @LockedUntil) / 1000.0)) AS [RetryAfterSeconds];
        RETURN;
    END;

    SELECT
          CAST(1 AS BIT) AS [IsAllowed]
        , CAST(1 AS BIT) AS [IsAvailable]
        , @UsersID AS [UsersID]
        , CAST(NULL AS NVARCHAR(50)) AS [BlockReasonCode]
        , CAST(NULL AS NVARCHAR(500)) AS [Message_]
        , CAST(NULL AS DATETIME2(3)) AS [LockedUntil]
        , CAST(0 AS INT) AS [RetryAfterSeconds];
END;

