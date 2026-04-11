
CREATE PROCEDURE [dbo].[Notifications_Create]
(
    @Title              NVARCHAR(200),
    @Body               NVARCHAR(MAX),
    @Url                NVARCHAR(500) = NULL,
    @StartDate          NVARCHAR(500) = NULL,
    @EndDate            NVARCHAR(500) = NULL,
    @UserID             BIGINT = NULL,
    @DistributorID      BIGINT = NULL,
    @RoleID             BIGINT = NULL,
    @DsdID              BIGINT = NULL,
    @IdaraID            NVARCHAR(500) = NULL,
    @MenuID             NVARCHAR(500) = NULL,
    @PermissionTypeID   BIGINT = NULL,
    @PermissionTypeIDs  NVARCHAR(MAX) = NULL,
    @entryData          NVARCHAR(20),
    @hostName           NVARCHAR(200)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NotificationId BIGINT;
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);

    DECLARE @StartDT DATETIME = TRY_CONVERT(DATETIME, NULLIF(@StartDate, ''), 120);
    DECLARE @EndDT   DATETIME = TRY_CONVERT(DATETIME, NULLIF(@EndDate, ''), 120);

    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(@IdaraID, ''));
    DECLARE @MenuID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(@MenuID, ''));

    DECLARE @TargetUsers TABLE
    (
        UserID BIGINT PRIMARY KEY
    );

    INSERT INTO dbo.Notifications
    (
        Title,
        Body,
        Url_,
        StartDate,
        EndDate,
        IsActive,
        IdaraID_FK,
        entryData,
        hostName
    )
    VALUES
    (
        @Title,
        @Body,
        @Url,
        ISNULL(@StartDT, GETDATE()),
        @EndDT,
        1,
        @IdaraID_INT,
        @entryData,
        @hostName
    );

    SET @NotificationId = SCOPE_IDENTITY();

    IF @NotificationId IS NULL OR @NotificationId = 0
        RETURN;

    /*========================================================
      1) مستخدم محدد
    ========================================================*/
    IF (
           @UserID IS NOT NULL
       AND @DistributorID IS NULL
       AND @RoleID IS NULL
       AND @DsdID IS NULL
       AND @IdaraID IS NULL
       AND @MenuID IS NULL
       AND @PermissionTypeID IS NULL
       AND @PermissionTypeIDs IS NULL
    )
    BEGIN
        INSERT INTO @TargetUsers (UserID)
        SELECT u.usersID
        FROM dbo.Users u
        WHERE u.usersID = @UserID
          AND u.usersActive = 1
          AND CAST(ISNULL(u.usersStartDate, GETDATE()) AS DATE) <= @Today
          AND (u.usersEndDate IS NULL OR CAST(u.usersEndDate AS DATE) >= @Today);
    END

    /*========================================================
      2) موزع فقط
    ========================================================*/
    ELSE IF (
           @UserID IS NULL
       AND @DistributorID IS NOT NULL
       AND @RoleID IS NULL
       AND @DsdID IS NULL
       AND @IdaraID IS NULL
       AND @MenuID IS NULL
       AND @PermissionTypeID IS NULL
       AND @PermissionTypeIDs IS NULL
    )
    BEGIN
        INSERT INTO @TargetUsers (UserID)
    SELECT DISTINCT u.usersID
    FROM dbo.Permission p
    INNER JOIN dbo.DistributorPermissionType dpt
        ON dpt.distributorPermissionTypeID = p.DistributorPermissionTypeID_FK
    INNER JOIN dbo.Users u
        ON u.usersID = p.UsersID_FK
    WHERE p.permissionActive = 1
      AND p.UsersID_FK IS NOT NULL
      AND dpt.DistributorID_FK = @DistributorID
      AND dpt.distributorPermissionTypeActive = 1
      AND u.usersActive = 1
      AND CAST(ISNULL(u.usersStartDate, GETDATE()) AS DATE) <= @Today
      AND (u.usersEndDate IS NULL OR CAST(u.usersEndDate AS DATE) >= @Today)
      AND CAST(ISNULL(p.permissionStartDate, GETDATE()) AS DATE) <= @Today
      AND (p.permissionEndDate IS NULL OR CAST(p.permissionEndDate AS DATE) >= @Today)
      AND CAST(ISNULL(dpt.distributorPermissionTypeStartDate, GETDATE()) AS DATE) <= @Today
      AND (dpt.distributorPermissionTypeEndDate IS NULL OR CAST(dpt.distributorPermissionTypeEndDate AS DATE) >= @Today);
    END

    /*========================================================
      3) Role فقط
    ========================================================*/
    ELSE IF (
           @UserID IS NULL
       AND @DistributorID IS NULL
       AND @RoleID IS NOT NULL
       AND @DsdID IS NULL
       AND @IdaraID IS NULL
       AND @MenuID IS NULL
       AND @PermissionTypeID IS NULL
       AND @PermissionTypeIDs IS NULL
    )
    BEGIN
        INSERT INTO @TargetUsers (UserID)
        SELECT DISTINCT u.usersID
        FROM dbo.Users u
        INNER JOIN dbo.UserDistributor ud
            ON ud.userID_FK = u.usersID
        INNER JOIN dbo.Distributor d
            ON d.distributorID = ud.distributorID_FK
        WHERE d.roleID_FK = @RoleID
          AND u.usersActive = 1
          AND d.distributorActive = 1
          AND ud.UDActive = 1
          AND CAST(ISNULL(u.usersStartDate, GETDATE()) AS DATE) <= @Today
          AND (u.usersEndDate IS NULL OR CAST(u.usersEndDate AS DATE) >= @Today)
          AND CAST(ud.UDStartDate AS DATE) <= @Today
          AND (ud.UDEndDate IS NULL OR CAST(ud.UDEndDate AS DATE) >= @Today);
    END

    /*========================================================
      4) Role + Idara
    ========================================================*/
    ELSE IF (
           @UserID IS NULL
       AND @DistributorID IS NULL
       AND @RoleID IS NOT NULL
       AND @DsdID IS NULL
       AND @IdaraID IS NOT NULL
       AND @MenuID IS NULL
       AND @PermissionTypeID IS NULL
       AND @PermissionTypeIDs IS NULL
    )
    BEGIN
        INSERT INTO @TargetUsers (UserID)
        SELECT DISTINCT u.usersID
        FROM dbo.Users u
        INNER JOIN dbo.UsersDetails udt
            ON udt.usersID_FK = u.usersID
        INNER JOIN dbo.UserDistributor ud
            ON ud.userID_FK = u.usersID
        INNER JOIN dbo.Distributor d
            ON d.distributorID = ud.distributorID_FK
        WHERE d.roleID_FK = @RoleID
          AND udt.IdaraID = @IdaraID_INT
          AND u.usersActive = 1
          AND udt.userActive = 1
          AND d.distributorActive = 1
          AND ud.UDActive = 1
          AND CAST(ISNULL(u.usersStartDate, GETDATE()) AS DATE) <= @Today
          AND (u.usersEndDate IS NULL OR CAST(u.usersEndDate AS DATE) >= @Today)
          AND CAST(ud.UDStartDate AS DATE) <= @Today
          AND (ud.UDEndDate IS NULL OR CAST(ud.UDEndDate AS DATE) >= @Today);
    END

    /*========================================================
      5) DSD فقط
    ========================================================*/
    ELSE IF (
           @UserID IS NULL
       AND @DistributorID IS NULL
       AND @RoleID IS NULL
       AND @DsdID IS NOT NULL
       AND @IdaraID IS NULL
       AND @MenuID IS NULL
       AND @PermissionTypeID IS NULL
       AND @PermissionTypeIDs IS NULL
    )
    BEGIN
        INSERT INTO @TargetUsers (UserID)
        SELECT DISTINCT u.usersID
        FROM dbo.Users u
        INNER JOIN dbo.V_GetListUsersInDSD v
            ON v.usersID = u.usersID
        WHERE v.DSDID = @DsdID
          AND u.usersActive = 1
          AND CAST(ISNULL(u.usersStartDate, GETDATE()) AS DATE) <= @Today
          AND (u.usersEndDate IS NULL OR CAST(u.usersEndDate AS DATE) >= @Today);
    END

    /*========================================================
      6) DSD + Idara
    ========================================================*/
    ELSE IF (
           @UserID IS NULL
       AND @DistributorID IS NULL
       AND @RoleID IS NULL
       AND @DsdID IS NOT NULL
       AND @IdaraID IS NOT NULL
       AND @MenuID IS NULL
       AND @PermissionTypeID IS NULL
       AND @PermissionTypeIDs IS NULL
    )
    BEGIN
        INSERT INTO @TargetUsers (UserID)
        SELECT DISTINCT u.usersID
        FROM dbo.Users u
        INNER JOIN dbo.UsersDetails udt
            ON udt.usersID_FK = u.usersID
        INNER JOIN dbo.V_GetListUsersInDSD v
            ON v.usersID = u.usersID
        INNER JOIN dbo.V_GetFullStructureForDSD fs
            ON fs.DSDID = v.DSDID
        WHERE v.DSDID = @DsdID
          AND fs.IdaraID = @IdaraID_INT
          AND udt.IdaraID = @IdaraID_INT
          AND u.usersActive = 1
          AND udt.userActive = 1
          AND CAST(ISNULL(u.usersStartDate, GETDATE()) AS DATE) <= @Today
          AND (u.usersEndDate IS NULL OR CAST(u.usersEndDate AS DATE) >= @Today);
    END

    /*========================================================
      7) Idara فقط
    ========================================================*/
    ELSE IF (
           @UserID IS NULL
       AND @DistributorID IS NULL
       AND @RoleID IS NULL
       AND @DsdID IS NULL
       AND @IdaraID IS NOT NULL
       AND @MenuID IS NULL
       AND @PermissionTypeID IS NULL
       AND @PermissionTypeIDs IS NULL
    )
    BEGIN
        INSERT INTO @TargetUsers (UserID)
        SELECT DISTINCT u.usersID
        FROM dbo.Users u
        INNER JOIN dbo.UsersDetails udt
            ON udt.usersID_FK = u.usersID
        WHERE udt.IdaraID = @IdaraID_INT
          AND u.usersActive = 1
          AND udt.userActive = 1
          AND CAST(ISNULL(u.usersStartDate, GETDATE()) AS DATE) <= @Today
          AND (u.usersEndDate IS NULL OR CAST(u.usersEndDate AS DATE) >= @Today);
    END

/*========================================================
  8) Menu + Idara
  من يملك صلاحية مباشرة لمستخدم
  مرتبطة بموزع ومرتبطة بالصفحة المحددة
  داخل إدارة معيّنة فقط
========================================================*/
ELSE IF (
       @UserID IS NULL
   AND @DistributorID IS NULL
   AND @RoleID IS NULL
   AND @DsdID IS NULL
   AND @IdaraID IS NOT NULL
   AND @MenuID IS NOT NULL
   AND @PermissionTypeID IS NULL
   AND @PermissionTypeIDs IS NULL
)
BEGIN
    INSERT INTO @TargetUsers (UserID)
    SELECT DISTINCT u.usersID
    FROM dbo.V_GetFullPermissionDetails s
    INNER JOIN dbo.Users u
        ON u.usersID = s.UsersID_FK
    INNER JOIN dbo.UsersDetails udt
        ON udt.usersID_FK = u.usersID
    WHERE s.UsersID_FK IS NOT NULL
      AND s.distributorID IS NOT NULL
      AND s.menuID = @MenuID_BIGINT
      AND udt.IdaraID = @IdaraID_INT
      AND s.permissionActive = 1
      AND s.distributorPermissionTypeActive = 1
      AND s.distributorActive = 1
      AND s.permissionTypeActive = 1
      AND s.userActive = 1
      AND u.usersActive = 1
      AND udt.userActive = 1
      AND CAST(ISNULL(u.usersStartDate, GETDATE()) AS DATE) <= @Today
      AND (u.usersEndDate IS NULL OR CAST(u.usersEndDate AS DATE) >= @Today)
      AND CAST(ISNULL(s.permissionStartDate, GETDATE()) AS DATE) <= @Today
      AND (s.permissionEndDate IS NULL OR CAST(s.permissionEndDate AS DATE) >= @Today);
END

  /*========================================================
  9) PermissionType + Idara
  صلاحية معيّنة مباشرة على مستخدم داخل إدارة معيّنة فقط
========================================================*/
ELSE IF (
       @UserID IS NULL
   AND @DistributorID IS NULL
   AND @RoleID IS NULL
   AND @DsdID IS NULL
   AND @IdaraID IS NOT NULL
   AND @MenuID IS NULL
   AND @PermissionTypeID IS NOT NULL
   AND @PermissionTypeIDs IS NULL
)
BEGIN
    INSERT INTO @TargetUsers (UserID)
    SELECT DISTINCT u.usersID
    FROM dbo.Permission p
    INNER JOIN dbo.DistributorPermissionType dpt
        ON dpt.distributorPermissionTypeID = p.DistributorPermissionTypeID_FK
    INNER JOIN dbo.Users u
        ON u.usersID = p.UsersID_FK
    INNER JOIN dbo.UsersDetails udt
        ON udt.usersID_FK = u.usersID
    WHERE p.permissionActive = 1
      AND p.UsersID_FK IS NOT NULL
      AND dpt.permissionTypeID_FK = @PermissionTypeID
      AND dpt.distributorPermissionTypeActive = 1
      AND udt.IdaraID = @IdaraID_INT
      AND u.usersActive = 1
      AND udt.userActive = 1
      AND CAST(ISNULL(u.usersStartDate, GETDATE()) AS DATE) <= @Today
      AND (u.usersEndDate IS NULL OR CAST(u.usersEndDate AS DATE) >= @Today)
      AND CAST(ISNULL(p.permissionStartDate, GETDATE()) AS DATE) <= @Today
      AND (p.permissionEndDate IS NULL OR CAST(p.permissionEndDate AS DATE) >= @Today)
      AND CAST(ISNULL(dpt.distributorPermissionTypeStartDate, GETDATE()) AS DATE) <= @Today
      AND (dpt.distributorPermissionTypeEndDate IS NULL OR CAST(dpt.distributorPermissionTypeEndDate AS DATE) >= @Today);
END

   /*========================================================
  10) Distributor + Idara
  من يملك صلاحيات مرتبطة بموزع معيّن داخل إدارة معيّنة فقط
========================================================*/
ELSE IF (
       @UserID IS NULL
   AND @DistributorID IS NOT NULL
   AND @RoleID IS NULL
   AND @DsdID IS NULL
   AND @IdaraID IS NOT NULL
   AND @MenuID IS NULL
   AND @PermissionTypeID IS NULL
   AND @PermissionTypeIDs IS NULL
)
BEGIN
    INSERT INTO @TargetUsers (UserID)
    SELECT DISTINCT u.usersID
    FROM dbo.Permission p
    INNER JOIN dbo.DistributorPermissionType dpt
        ON dpt.distributorPermissionTypeID = p.DistributorPermissionTypeID_FK
    INNER JOIN dbo.Users u
        ON u.usersID = p.UsersID_FK
    INNER JOIN dbo.UsersDetails udt
        ON udt.usersID_FK = u.usersID
    WHERE p.permissionActive = 1
      AND p.UsersID_FK IS NOT NULL
      AND dpt.DistributorID_FK = @DistributorID
      AND dpt.distributorPermissionTypeActive = 1
      AND udt.IdaraID = @IdaraID_INT
      AND u.usersActive = 1
      AND udt.userActive = 1
      AND CAST(ISNULL(u.usersStartDate, GETDATE()) AS DATE) <= @Today
      AND (u.usersEndDate IS NULL OR CAST(u.usersEndDate AS DATE) >= @Today)
      AND CAST(ISNULL(p.permissionStartDate, GETDATE()) AS DATE) <= @Today
      AND (p.permissionEndDate IS NULL OR CAST(p.permissionEndDate AS DATE) >= @Today)
      AND CAST(ISNULL(dpt.distributorPermissionTypeStartDate, GETDATE()) AS DATE) <= @Today
      AND (dpt.distributorPermissionTypeEndDate IS NULL OR CAST(dpt.distributorPermissionTypeEndDate AS DATE) >= @Today);
END
    /*========================================================
      11) الجميع
    ========================================================*/
    ELSE IF (
           @UserID IS NULL
       AND @DistributorID IS NULL
       AND @RoleID IS NULL
       AND @DsdID IS NULL
       AND @IdaraID IS NULL
       AND @MenuID IS NULL
       AND @PermissionTypeID IS NULL
       AND @PermissionTypeIDs IS NULL
    )
    BEGIN
        INSERT INTO @TargetUsers (UserID)
        SELECT u.usersID
        FROM dbo.Users u
        WHERE u.usersActive = 1
          AND CAST(ISNULL(u.usersStartDate, GETDATE()) AS DATE) <= @Today
          AND (u.usersEndDate IS NULL OR CAST(u.usersEndDate AS DATE) >= @Today);
    END

    /*========================================================
  PermissionTypes (OR) + Idara
  من يملك أي صلاحية من الصلاحيات المحددة
  مباشرة على المستخدم داخل إدارة معيّنة فقط
========================================================*/
ELSE IF (
       @UserID IS NULL
   AND @DistributorID IS NULL
   AND @RoleID IS NULL
   AND @DsdID IS NULL
   AND @IdaraID IS NOT NULL
   AND @MenuID IS NULL
   AND @PermissionTypeID IS NULL
   AND @PermissionTypeIDs IS NOT NULL
)
BEGIN
    DECLARE @Perms TABLE
    (
        PermissionTypeID BIGINT PRIMARY KEY
    );

    INSERT INTO @Perms (PermissionTypeID)
    SELECT DISTINCT TRY_CONVERT(BIGINT, LTRIM(RTRIM(value)))
    FROM STRING_SPLIT(@PermissionTypeIDs, ',')
    WHERE TRY_CONVERT(BIGINT, LTRIM(RTRIM(value))) IS NOT NULL;

    INSERT INTO @TargetUsers (UserID)
    SELECT DISTINCT u.usersID
    FROM dbo.Users u
    INNER JOIN dbo.UsersDetails udt
        ON udt.usersID_FK = u.usersID
    INNER JOIN dbo.Permission p
        ON p.UsersID_FK = u.usersID
    INNER JOIN dbo.DistributorPermissionType dpt
        ON dpt.distributorPermissionTypeID = p.DistributorPermissionTypeID_FK
    WHERE udt.IdaraID = @IdaraID_INT
      AND u.usersActive = 1
      AND udt.userActive = 1
      AND p.permissionActive = 1
      AND p.UsersID_FK IS NOT NULL
      AND dpt.distributorPermissionTypeActive = 1
      AND dpt.permissionTypeID_FK IN (SELECT PermissionTypeID FROM @Perms)
      AND CAST(ISNULL(u.usersStartDate, GETDATE()) AS DATE) <= @Today
      AND (u.usersEndDate IS NULL OR CAST(u.usersEndDate AS DATE) >= @Today)
      AND CAST(ISNULL(p.permissionStartDate, GETDATE()) AS DATE) <= @Today
      AND (p.permissionEndDate IS NULL OR CAST(p.permissionEndDate AS DATE) >= @Today)
      AND CAST(ISNULL(dpt.distributorPermissionTypeStartDate, GETDATE()) AS DATE) <= @Today
      AND (dpt.distributorPermissionTypeEndDate IS NULL OR CAST(dpt.distributorPermissionTypeEndDate AS DATE) >= @Today);
END

    ELSE
    BEGIN
        RETURN;
    END;

    INSERT INTO dbo.UserNotifications
    (
        NotificationId_FK,
        UserId_FK,
        IsRead,
        IsClicked,
        DeliveredUtc,
        entryData,
        hostName
    )
    SELECT
        @NotificationId,
        tu.UserID,
        0,
        0,
        GETDATE(),
        @entryData,
        @hostName
    FROM @TargetUsers tu
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.UserNotifications un
        WHERE un.NotificationId_FK = @NotificationId
          AND un.UserId_FK = tu.UserID
    );

END