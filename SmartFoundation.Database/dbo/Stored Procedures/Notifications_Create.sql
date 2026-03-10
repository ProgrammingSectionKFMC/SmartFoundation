CREATE PROCEDURE [dbo].[Notifications_Create]
(
    @Title         NVARCHAR(200),
    @Body          NVARCHAR(MAX),
    @Url           NVARCHAR(500) = NULL,
    @StartDate     NVARCHAR(500) = NULL,
    @EndDate       NVARCHAR(500) = NULL,
    @UserID        BIGINT = NULL,
    @DistributorID BIGINT = NULL,
    @RoleID        BIGINT = NULL,
    @DsdID         BIGINT = NULL,
    @IdaraID       NVARCHAR(500) = NULL,
    @MenuID        NVARCHAR(500) = NULL,
    @entryData     NVARCHAR(20),
    @hostName      NVARCHAR(200)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NotificationId BIGINT;

    -- ملاحظة: StartDate/EndDate عندك NVARCHAR .. الأفضل تحويلها
    DECLARE @StartDT DATETIME = TRY_CONVERT(DATETIME, NULLIF(@StartDate,''), 120);
    DECLARE @EndDT   DATETIME = TRY_CONVERT(DATETIME, NULLIF(@EndDate,''), 120);

    INSERT INTO dbo.Notifications (Title, Body, Url_, StartDate, EndDate, entryData, hostName)
    VALUES (@Title, @Body, @Url, ISNULL(@StartDT, GETDATE()), @EndDT, @entryData, @hostName);

    SET @NotificationId = SCOPE_IDENTITY();

    IF @NotificationId IS NULL OR @NotificationId = 0
    BEGIN
        -- رجع فشل منطقي بدون ما تخرب الترانزكشن العليا
        --SELECT 0 AS IsSuccessful, N'فشل إنشاء الإشعار' AS Message_;
        RETURN;
    END

    -- حالة 1: مستخدم محدد
    IF (@UserID IS NOT NULL AND @DistributorID IS NULL AND @RoleID IS NULL AND @DsdID IS NULL AND @IdaraID IS NULL AND @MenuID IS NULL)
    BEGIN
        INSERT INTO dbo.UserNotifications
        (NotificationId_FK, UserId_FK, IsRead, IsClicked, DeliveredUtc, entryData, hostName)
        SELECT @NotificationId, u.usersID, 0, 0, GETDATE(), @entryData, @hostName
        FROM dbo.[Users] u
        WHERE u.usersID = @UserID AND u.usersActive = 1;
    END
    -- حالة 2: موزع
    ELSE IF (@UserID IS NULL AND @DistributorID IS NOT NULL AND @RoleID IS NULL AND @DsdID IS NULL AND @IdaraID IS NULL AND @MenuID IS NULL)
    BEGIN
        INSERT INTO dbo.UserNotifications
        (NotificationId_FK, UserId_FK, IsRead, IsClicked, DeliveredUtc, entryData, hostName)
        SELECT @NotificationId, u.usersID, 0, 0, GETDATE(), @entryData, @hostName
        FROM dbo.[Users] u
        INNER JOIN dbo.UserDistributor ud ON ud.userID_FK = u.usersID
        INNER JOIN dbo.Distributor d ON ud.distributorID_FK = d.distributorID
        WHERE d.distributorID = @DistributorID
          AND u.usersActive = 1
          AND d.distributorActive = 1
          AND ud.UDActive = 1
          AND CAST(ud.UDStartDate AS date) <= CAST(GETDATE() AS date)
          AND (ud.UDEndDate IS NULL OR CAST(ud.UDEndDate AS date) > CAST(GETDATE() AS date));
    END
    -- حالة 3: Role
    ELSE IF (@UserID IS NULL AND @DistributorID IS NULL AND @RoleID IS NOT NULL AND @DsdID IS NULL AND @IdaraID IS NULL  AND @MenuID IS NULL)
    BEGIN
        INSERT INTO dbo.UserNotifications
        (NotificationId_FK, UserId_FK, IsRead, IsClicked, DeliveredUtc, entryData, hostName)
        SELECT @NotificationId, u.usersID, 0, 0, GETDATE(), @entryData, @hostName
        FROM dbo.[Users] u
        INNER JOIN dbo.UserDistributor ud ON ud.userID_FK = u.usersID
        INNER JOIN dbo.Distributor d ON ud.distributorID_FK = d.distributorID
        WHERE d.roleID_FK = @RoleID
          AND u.usersActive = 1
          AND d.distributorActive = 1
          AND ud.UDActive = 1
          AND CAST(ud.UDStartDate AS date) <= CAST(GETDATE() AS date)
          AND (ud.UDEndDate IS NULL OR CAST(ud.UDEndDate AS date) > CAST(GETDATE() AS date));
    END
    -- حالة 4: DSD
    ELSE IF (@UserID IS NULL AND @DistributorID IS NULL AND @RoleID IS NULL AND @DsdID IS NOT NULL AND @IdaraID IS NULL  AND @MenuID IS NULL)
    BEGIN
        INSERT INTO dbo.UserNotifications
        (NotificationId_FK, UserId_FK, IsRead, IsClicked, DeliveredUtc, entryData, hostName)
        SELECT @NotificationId, dsd.usersID, 0, 0, GETDATE(), @entryData, @hostName
        FROM [DATACORE].[dbo].V_GetListUsersInDSD dsd
        inner join [DATACORE].[dbo].V_GetFullStructureForDSD f on dsd.DSDID = f.DSDID
        WHERE dsd.DSDID = @DsdID;
    END
    -- حالة 5: ادارة محددة
    ELSE IF (@UserID IS NULL AND @DistributorID IS NULL AND @RoleID IS NULL AND @DsdID IS NULL AND @IdaraID IS NOT NULL  AND @MenuID IS NULL)
    BEGIN
        INSERT INTO dbo.UserNotifications
        (NotificationId_FK, UserId_FK, IsRead, IsClicked, DeliveredUtc, entryData, hostName)
        SELECT @NotificationId, d.usersID, 0, 0, GETDATE(), @entryData, @hostName
        FROM dbo.V_GetListUsersInDSD d 
        inner join dbo.V_GetFullStructureForDSD f on d.DSDID = f.DSDID
        where f.IdaraID = @IdaraID

    END


      -- حالة 6: من يملك صلاحية على صفحة محددة في ادارة محددة
    ELSE IF (@UserID IS NULL AND @DistributorID IS NULL AND @RoleID IS NULL AND @DsdID IS NULL AND @IdaraID IS Not NULL AND @MenuID IS NOT NULL)
    BEGIN
        INSERT INTO dbo.UserNotifications
        (NotificationId_FK, UserId_FK, IsRead, IsClicked, DeliveredUtc, entryData, hostName)
        SELECT distinct @NotificationId, all_.usersID, 0, 0, GETDATE(), @entryData, @hostName
        --select distinct all_.usersID 
        from (

        select s.UsersID_FK as usersID,s.menuID ,f.IdaraID
        from dbo.V_GetFullPermissionDetails  s
            inner join dbo.V_GetListUsersInDSD dsd on s.UsersID_FK = dsd.usersID
            inner join dbo.V_GetFullStructureForDSD f on dsd.DSDID = f.DSDID
        where  s.UsersID_FK is not null 
        
        union all
        
        select ud.userID_FK as usersID ,s.menuID ,f.IdaraID
        from dbo.V_GetFullPermissionDetails  s
        left join dbo.Distributor d on S.RoleID_FK = d.roleID_FK
        left join dbo.UserDistributor ud on d.distributorID = ud.distributorID_FK and ud.UDActive = 1
        inner join dbo.V_GetListUsersInDSD dsd on s.UsersID_FK = dsd.usersID
        inner join dbo.V_GetFullStructureForDSD f on dsd.DSDID = f.DSDID
        where ud.userID_FK IS NOT NULL 
        
        union all
        
        select ud.userID_FK as usersID ,s.menuID ,f.IdaraID from dbo.V_GetFullPermissionDetails  s
        left join UserDistributor ud on s.distributorID_FK = ud.distributorID_FK and ud.UDActive = 1
        inner join dbo.V_GetListUsersInDSD dsd on s.UsersID_FK = dsd.usersID
        inner join dbo.V_GetFullStructureForDSD f on dsd.DSDID = f.DSDID
        where  ud.distributorID_FK is not null
        
        union all
        
        select d.usersID as usersID,s.menuID,f.IdaraID from dbo.V_GetFullPermissionDetails  s
        left join dbo.V_GetListUsersInDSD d on s.DSDID_FK = d.DSDID
        inner join dbo.V_GetListUsersInDSD dsd on s.UsersID_FK = dsd.usersID
        inner join dbo.V_GetFullStructureForDSD f on dsd.DSDID = f.DSDID
        where   d.DSDID is not null
        
        union all
        
        select d.usersID  as usersID ,s.menuID,f.IdaraID from dbo.V_GetFullPermissionDetails  s
        left join dbo.V_GetListUsersInDSD d on s.DSDID_FK = d.DSDID
        left join dbo.V_GetFullStructureForDSD f on d.DSDID = f.DSDID
        where  f.IdaraID is not null
        
        ) all_ where all_.menuID = @MenuID and all_.IdaraID = @IdaraID
    END

     -- حالة 7: الجميع
    ELSE IF (@UserID IS NULL AND @DistributorID IS NULL AND @RoleID IS NULL AND @DsdID IS NULL AND @IdaraID IS NULL AND @MenuID IS NULL)
    BEGIN
        INSERT INTO dbo.UserNotifications
        (NotificationId_FK, UserId_FK, IsRead, IsClicked, DeliveredUtc, entryData, hostName)
        SELECT @NotificationId, u.usersID, 0, 0, GETDATE(), @entryData, @hostName
        FROM dbo.[Users] u
        WHERE u.usersActive = 1;
    END
    ELSE
    BEGIN
        --SELECT 0 AS IsSuccessful, N'باراميترات الإرسال غير صحيحة' AS Message_;
        RETURN;
    END

   --SELECT 1 AS IsSuccessful, N'تم إنشاء الإشعار بنجاح' AS Message_;
END
