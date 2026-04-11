SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRAN;

    DECLARE @entryData NVARCHAR(20) = N'4';
    DECLARE @hostName NVARCHAR(400) = ISNULL(HOST_NAME(), N'CODEx');
    DECLARE @today DATETIME = GETDATE();

    DECLARE @menuID BIGINT;
    DECLARE @distributorID BIGINT;

    -- 1) Menu
    SELECT @menuID = m.menuID
    FROM dbo.Menu m
    WHERE m.menuName_E = N'SupportPhoneTickets';

    IF @menuID IS NULL
    BEGIN
        DECLARE @nextMenuSerial INT = ISNULL((SELECT MAX(menuSerial) FROM dbo.Menu WHERE programID_FK = 19), 0) + 1;

        INSERT INTO dbo.Menu
        (
            menuName_A,
            menuName_E,
            menuDescription,
            parentMenuID_FK,
            menuLink,
            programID_FK,
            menuSerial,
            menuActive,
            isDashboard,
            PageLvl
        )
        VALUES
        (
            N'التذاكر الهاتفية',
            N'SupportPhoneTickets',
            N'MVC',
            NULL,
            N'SupportPhoneTickets',
            19,
            @nextMenuSerial,
            1,
            NULL,
            3
        );

        SET @menuID = SCOPE_IDENTITY();
    END

    -- 2) Distributor
    SELECT @distributorID = d.distributorID
    FROM dbo.Distributor d
    WHERE d.distributorName_E = N'SupportPhoneTickets';

    IF @distributorID IS NULL
    BEGIN
        INSERT INTO dbo.Distributor
        (
            distributorName_A,
            distributorName_E,
            distributorDescription,
            distributorCode,
            distributorActive,
            distributorType_FK,
            DSDID_FK,
            roleID_FK,
            groupID_FK,
            jobNo,
            entryDate,
            entryData,
            hostName
        )
        VALUES
        (
            N'التذاكر الهاتفية',
            N'SupportPhoneTickets',
            N'MVC',
            NULL,
            1,
            4,
            NULL,
            NULL,
            NULL,
            NULL,
            @today,
            @entryData,
            @hostName
        );

        SET @distributorID = SCOPE_IDENTITY();
    END

    -- 3) MenuDistributor
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.MenuDistributor md
        WHERE md.menuID_FK = @menuID
          AND md.distributorID_FK = @distributorID
    )
    BEGIN
        INSERT INTO dbo.MenuDistributor
        (
            menuID_FK,
            distributorID_FK,
            roleID_FK,
            userID_FK,
            isDenied,
            menuDistributorActive
        )
        VALUES
        (
            @menuID,
            @distributorID,
            NULL,
            NULL,
            NULL,
            1
        );
    END

    -- 4) PermissionType
    IF NOT EXISTS (SELECT 1 FROM dbo.PermissionType WHERE permissionTypeName_E = N'SPT_ACCESS')
        INSERT INTO dbo.PermissionType(permissionTypeName_A, permissionTypeName_E, permissionTypeActive, RoleID_FK)
        VALUES (N'وصول التذاكر الهاتفية', N'SPT_ACCESS', 1, NULL);

    IF NOT EXISTS (SELECT 1 FROM dbo.PermissionType WHERE permissionTypeName_E = N'SPT_SELECT')
        INSERT INTO dbo.PermissionType(permissionTypeName_A, permissionTypeName_E, permissionTypeActive, RoleID_FK)
        VALUES (N'عرض التذاكر الهاتفية', N'SPT_SELECT', 1, NULL);

    IF NOT EXISTS (SELECT 1 FROM dbo.PermissionType WHERE permissionTypeName_E = N'SPT_CREATE_TICKET')
        INSERT INTO dbo.PermissionType(permissionTypeName_A, permissionTypeName_E, permissionTypeActive, RoleID_FK)
        VALUES (N'إنشاء تذكرة هاتفية', N'SPT_CREATE_TICKET', 1, NULL);

    DECLARE @ptAccess BIGINT = (SELECT TOP 1 permissionTypeID FROM dbo.PermissionType WHERE permissionTypeName_E = N'SPT_ACCESS' ORDER BY permissionTypeID DESC);
    DECLARE @ptSelect BIGINT = (SELECT TOP 1 permissionTypeID FROM dbo.PermissionType WHERE permissionTypeName_E = N'SPT_SELECT' ORDER BY permissionTypeID DESC);
    DECLARE @ptCreate BIGINT = (SELECT TOP 1 permissionTypeID FROM dbo.PermissionType WHERE permissionTypeName_E = N'SPT_CREATE_TICKET' ORDER BY permissionTypeID DESC);

    -- 5) DistributorPermissionType
    IF NOT EXISTS (SELECT 1 FROM dbo.DistributorPermissionType WHERE DistributorID_FK = @distributorID AND permissionTypeID_FK = @ptAccess)
    BEGIN
        INSERT INTO dbo.DistributorPermissionType
        (
            permissionTypeID_FK,
            DistributorID_FK,
            distributorPermissionTypeStartDate,
            distributorPermissionTypeEndDate,
            distributorPermissionTypeActive,
            permissionAuthLvl,
            entryDate,
            entryData,
            hostName
        )
        VALUES
        (
            @ptAccess,
            @distributorID,
            CAST(@today AS DATE),
            NULL,
            1,
            3,
            @today,
            @entryData,
            @hostName
        );
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.DistributorPermissionType WHERE DistributorID_FK = @distributorID AND permissionTypeID_FK = @ptSelect)
    BEGIN
        INSERT INTO dbo.DistributorPermissionType
        (
            permissionTypeID_FK,
            DistributorID_FK,
            distributorPermissionTypeStartDate,
            distributorPermissionTypeEndDate,
            distributorPermissionTypeActive,
            permissionAuthLvl,
            entryDate,
            entryData,
            hostName
        )
        VALUES
        (
            @ptSelect,
            @distributorID,
            CAST(@today AS DATE),
            NULL,
            1,
            3,
            @today,
            @entryData,
            @hostName
        );
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.DistributorPermissionType WHERE DistributorID_FK = @distributorID AND permissionTypeID_FK = @ptCreate)
    BEGIN
        INSERT INTO dbo.DistributorPermissionType
        (
            permissionTypeID_FK,
            DistributorID_FK,
            distributorPermissionTypeStartDate,
            distributorPermissionTypeEndDate,
            distributorPermissionTypeActive,
            permissionAuthLvl,
            entryDate,
            entryData,
            hostName
        )
        VALUES
        (
            @ptCreate,
            @distributorID,
            CAST(@today AS DATE),
            NULL,
            1,
            3,
            @today,
            @entryData,
            @hostName
        );
    END

    DECLARE @newDptAccess BIGINT = (
        SELECT TOP 1 distributorPermissionTypeID
        FROM dbo.DistributorPermissionType
        WHERE DistributorID_FK = @distributorID AND permissionTypeID_FK = @ptAccess
        ORDER BY distributorPermissionTypeID DESC
    );
    DECLARE @newDptSelect BIGINT = (
        SELECT TOP 1 distributorPermissionTypeID
        FROM dbo.DistributorPermissionType
        WHERE DistributorID_FK = @distributorID AND permissionTypeID_FK = @ptSelect
        ORDER BY distributorPermissionTypeID DESC
    );
    DECLARE @newDptCreate BIGINT = (
        SELECT TOP 1 distributorPermissionTypeID
        FROM dbo.DistributorPermissionType
        WHERE DistributorID_FK = @distributorID AND permissionTypeID_FK = @ptCreate
        ORDER BY distributorPermissionTypeID DESC
    );

    -- 6) Clone Permission assignments from SupportMyTickets (SMT_*)
    DECLARE @srcDistributorID BIGINT = (
        SELECT TOP 1 d.distributorID
        FROM dbo.Distributor d
        WHERE d.distributorName_E = N'SupportMyTickets'
        ORDER BY d.distributorID DESC
    );

    DECLARE @srcDptAccess BIGINT = (
        SELECT TOP 1 dpt.distributorPermissionTypeID
        FROM dbo.DistributorPermissionType dpt
        JOIN dbo.PermissionType pt ON pt.permissionTypeID = dpt.permissionTypeID_FK
        WHERE dpt.DistributorID_FK = @srcDistributorID
          AND pt.permissionTypeName_E = N'SMT_ACCESS'
        ORDER BY dpt.distributorPermissionTypeID DESC
    );

    DECLARE @srcDptSelect BIGINT = (
        SELECT TOP 1 dpt.distributorPermissionTypeID
        FROM dbo.DistributorPermissionType dpt
        JOIN dbo.PermissionType pt ON pt.permissionTypeID = dpt.permissionTypeID_FK
        WHERE dpt.DistributorID_FK = @srcDistributorID
          AND pt.permissionTypeName_E = N'SMT_SELECT'
        ORDER BY dpt.distributorPermissionTypeID DESC
    );

    DECLARE @srcDptCreate BIGINT = (
        SELECT TOP 1 dpt.distributorPermissionTypeID
        FROM dbo.DistributorPermissionType dpt
        JOIN dbo.PermissionType pt ON pt.permissionTypeID = dpt.permissionTypeID_FK
        WHERE dpt.DistributorID_FK = @srcDistributorID
          AND pt.permissionTypeName_E = N'SMT_CREATE_TICKET'
        ORDER BY dpt.distributorPermissionTypeID DESC
    );

    IF @srcDptAccess IS NOT NULL
    BEGIN
        INSERT INTO dbo.Permission
        (
            DistributorPermissionTypeID_FK,
            UsersID_FK,
            RoleID_FK,
            distributorID_FK,
            IdaraID_FK,
            DSDID_FK,
            permissionStartDate,
            permissionEndDate,
            permissionActive,
            permissionNote,
            InIdaraID,
            entryDate,
            entryData,
            hostName
        )
        SELECT
            @newDptAccess,
            p.UsersID_FK,
            p.RoleID_FK,
            p.distributorID_FK,
            p.IdaraID_FK,
            p.DSDID_FK,
            p.permissionStartDate,
            p.permissionEndDate,
            p.permissionActive,
            p.permissionNote,
            p.InIdaraID,
            @today,
            @entryData,
            @hostName
        FROM dbo.Permission p
        WHERE p.DistributorPermissionTypeID_FK = @srcDptAccess
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.Permission x
              WHERE x.DistributorPermissionTypeID_FK = @newDptAccess
                AND ISNULL(x.UsersID_FK, -1) = ISNULL(p.UsersID_FK, -1)
                AND ISNULL(x.RoleID_FK, -1) = ISNULL(p.RoleID_FK, -1)
                AND ISNULL(x.distributorID_FK, -1) = ISNULL(p.distributorID_FK, -1)
                AND ISNULL(x.IdaraID_FK, -1) = ISNULL(p.IdaraID_FK, -1)
                AND ISNULL(x.DSDID_FK, -1) = ISNULL(p.DSDID_FK, -1)
                AND ISNULL(x.InIdaraID, -1) = ISNULL(p.InIdaraID, -1)
          );
    END

    IF @srcDptSelect IS NOT NULL
    BEGIN
        INSERT INTO dbo.Permission
        (
            DistributorPermissionTypeID_FK,
            UsersID_FK,
            RoleID_FK,
            distributorID_FK,
            IdaraID_FK,
            DSDID_FK,
            permissionStartDate,
            permissionEndDate,
            permissionActive,
            permissionNote,
            InIdaraID,
            entryDate,
            entryData,
            hostName
        )
        SELECT
            @newDptSelect,
            p.UsersID_FK,
            p.RoleID_FK,
            p.distributorID_FK,
            p.IdaraID_FK,
            p.DSDID_FK,
            p.permissionStartDate,
            p.permissionEndDate,
            p.permissionActive,
            p.permissionNote,
            p.InIdaraID,
            @today,
            @entryData,
            @hostName
        FROM dbo.Permission p
        WHERE p.DistributorPermissionTypeID_FK = @srcDptSelect
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.Permission x
              WHERE x.DistributorPermissionTypeID_FK = @newDptSelect
                AND ISNULL(x.UsersID_FK, -1) = ISNULL(p.UsersID_FK, -1)
                AND ISNULL(x.RoleID_FK, -1) = ISNULL(p.RoleID_FK, -1)
                AND ISNULL(x.distributorID_FK, -1) = ISNULL(p.distributorID_FK, -1)
                AND ISNULL(x.IdaraID_FK, -1) = ISNULL(p.IdaraID_FK, -1)
                AND ISNULL(x.DSDID_FK, -1) = ISNULL(p.DSDID_FK, -1)
                AND ISNULL(x.InIdaraID, -1) = ISNULL(p.InIdaraID, -1)
          );
    END

    IF @srcDptCreate IS NOT NULL
    BEGIN
        INSERT INTO dbo.Permission
        (
            DistributorPermissionTypeID_FK,
            UsersID_FK,
            RoleID_FK,
            distributorID_FK,
            IdaraID_FK,
            DSDID_FK,
            permissionStartDate,
            permissionEndDate,
            permissionActive,
            permissionNote,
            InIdaraID,
            entryDate,
            entryData,
            hostName
        )
        SELECT
            @newDptCreate,
            p.UsersID_FK,
            p.RoleID_FK,
            p.distributorID_FK,
            p.IdaraID_FK,
            p.DSDID_FK,
            p.permissionStartDate,
            p.permissionEndDate,
            p.permissionActive,
            p.permissionNote,
            p.InIdaraID,
            @today,
            @entryData,
            @hostName
        FROM dbo.Permission p
        WHERE p.DistributorPermissionTypeID_FK = @srcDptCreate
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.Permission x
              WHERE x.DistributorPermissionTypeID_FK = @newDptCreate
                AND ISNULL(x.UsersID_FK, -1) = ISNULL(p.UsersID_FK, -1)
                AND ISNULL(x.RoleID_FK, -1) = ISNULL(p.RoleID_FK, -1)
                AND ISNULL(x.distributorID_FK, -1) = ISNULL(p.distributorID_FK, -1)
                AND ISNULL(x.IdaraID_FK, -1) = ISNULL(p.IdaraID_FK, -1)
                AND ISNULL(x.DSDID_FK, -1) = ISNULL(p.DSDID_FK, -1)
                AND ISNULL(x.InIdaraID, -1) = ISNULL(p.InIdaraID, -1)
          );
    END

    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

CREATE OR ALTER PROCEDURE [support].[SupportPhoneTicketsDL]
      @pageName_ NVARCHAR(400)
    , @idaraID   INT
    , @entrydata BIGINT
    , @hostname  NVARCHAR(400)
    , @permissionUserID NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @permUser BIGINT = ISNULL(TRY_CONVERT(BIGINT, @permissionUserID), @entrydata);

    SELECT
          t.ticketID
        , t.ticketNo
        , t.ticketTitle
        , t.ticketDescription
        , tt.ticketTypeName_A
        , tp.priorityName_A
        , ts.statusName_A
        , t.affectedPageName
        , t.affectedPageUrl
        , t.affectedActionName
        , u.nationalID AS callerNationalID
        , u.FullName   AS callerFullName
        , t.entryDate
        , t.assignedDate
        , t.closedDate
    FROM [support].[Ticket] t
    INNER JOIN [support].[TicketType] tt ON tt.ticketTypeID = t.ticketTypeID_FK
    INNER JOIN [support].[TicketPriority] tp ON tp.priorityID = t.priorityID_FK
    INNER JOIN [support].[TicketStatus] ts ON ts.statusID = t.statusID_FK
    LEFT JOIN dbo.V_GetFullSystemUsersDetails u ON u.usersID = t.createdByUserID_FK
    WHERE t.ticketActive = 1
      AND TRY_CONVERT(BIGINT, t.entryData) = @entrydata
    ORDER BY t.ticketID DESC;

    SELECT ticketTypeID, ticketTypeName_A
    FROM [support].[TicketType]
    WHERE ticketTypeActive = 1
    ORDER BY ticketTypeID;

    SELECT priorityID, priorityName_A
    FROM [support].[TicketPriority]
    WHERE priorityActive = 1
    ORDER BY priorityID;

    -- الصفحات المسموح بها للمستخدم
    SELECT DISTINCT
           v.menuID,
           m.menuName_A,
           m.menuName_E,
           m.menuLink
    FROM dbo.V_GetListUserPermission v
    INNER JOIN dbo.Menu m ON m.menuID = v.menuID
    WHERE v.userID = @permUser
      AND ISNULL(m.menuActive, 1) = 1
      AND NULLIF(LTRIM(RTRIM(ISNULL(m.menuName_A, N''))), N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(ISNULL(m.menuLink, N''))), N'') IS NOT NULL
      AND (
            v.permissionTypeName_E = N'SELECT'
         OR v.permissionTypeName_E = N'ACCESS'
         OR v.permissionTypeName_E LIKE N'%_SELECT'
         OR v.permissionTypeName_E LIKE N'%_ACCESS'
      )
    ORDER BY m.menuName_A;

    -- الإجراءات المسموح بها لكل صفحة للمستخدم الحالي
    SELECT DISTINCT
           v.menuID,
           v.menuName_A,
           v.menuName_E,
           v.permissionTypeName_A,
           v.permissionTypeName_E
    FROM dbo.V_GetListUserPermission v
    WHERE v.userID = @permUser
      AND NULLIF(LTRIM(RTRIM(ISNULL(v.menuName_A, N''))), N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(ISNULL(v.permissionTypeName_A, N''))), N'') IS NOT NULL
      AND NOT (
            v.permissionTypeName_E = N'ACCESS'
         OR v.permissionTypeName_E = N'SELECT'
         OR v.permissionTypeName_E LIKE N'%_ACCESS'
         OR v.permissionTypeName_E LIKE N'%_SELECT'
      )
    ORDER BY v.menuName_A, v.permissionTypeName_A;

    -- مستخدمو النظام النشطون (المتصل)
    SELECT
          CAST(u.usersID AS BIGINT) AS usersID
        , CAST(ISNULL(u.nationalID, N'') + N' - ' + ISNULL(u.FullName, N'') +
               CASE WHEN NULLIF(LTRIM(RTRIM(ISNULL(u.idaraLongName_A, N''))), N'') IS NULL
                    THEN N''
                    ELSE N' - ' + u.idaraLongName_A
               END AS NVARCHAR(500)) AS callerDisplayName
    FROM dbo.V_GetFullSystemUsersDetails u
    WHERE u.userActive = 1
      AND u.usersID IS NOT NULL
    ORDER BY u.FullName;

    SELECT statusID, statusName_A
    FROM [support].[TicketStatus]
    WHERE statusActive = 1
    ORDER BY statusID;
END
GO

CREATE OR ALTER PROCEDURE [support].[SupportPhoneTicketsSP]
(
      @Action             NVARCHAR(200)
    , @ticketTypeID       TINYINT       = NULL
    , @priorityID         TINYINT       = NULL
    , @ticketTitle        NVARCHAR(300) = NULL
    , @ticketDescription  NVARCHAR(MAX) = NULL
    , @affectedPageName   NVARCHAR(200) = NULL
    , @affectedPageUrl    NVARCHAR(500) = NULL
    , @affectedActionName NVARCHAR(200) = NULL
    , @errorDetails       NVARCHAR(MAX) = NULL
    , @callerUserID       BIGINT        = NULL
    , @entryData          NVARCHAR(20)  = NULL
    , @hostName           NVARCHAR(200) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE
          @newID BIGINT = NULL
        , @seq BIGINT = NULL
        , @ticketNo NVARCHAR(30) = NULL
        , @entryUserID BIGINT = TRY_CONVERT(BIGINT, @entryData)
        , @note NVARCHAR(MAX) = NULL
        , @affectedPageNameClean NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@affectedPageName)), N'')
        , @affectedPageUrlClean NVARCHAR(500) = NULLIF(LTRIM(RTRIM(@affectedPageUrl)), N'')
        , @affectedActionNameClean NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@affectedActionName)), N'');

    BEGIN TRY
        IF @tc = 0
            BEGIN TRAN;

        IF NULLIF(LTRIM(RTRIM(@Action)), N'') IS NULL
            THROW 50001, N'العملية مطلوبة', 1;

        IF @Action <> N'SPT_CREATE_TICKET'
            THROW 50001, N'العملية غير مسجلة', 1;

        IF @entryUserID IS NULL
            THROW 50001, N'الموظف الحالي غير صالح', 1;

        IF @callerUserID IS NULL
            THROW 50001, N'المتصل مطلوب', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.V_GetFullSystemUsersDetails u
            WHERE u.usersID = @callerUserID
              AND u.userActive = 1
        )
            THROW 50001, N'المتصل غير صالح أو غير نشط', 1;

        IF @ticketTypeID IS NULL
            THROW 50001, N'نوع التذكرة مطلوب', 1;

        IF NOT EXISTS (SELECT 1 FROM [support].[TicketType] WHERE ticketTypeID = @ticketTypeID AND ticketTypeActive = 1)
            THROW 50001, N'نوع التذكرة غير صالح', 1;

        IF @priorityID IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM [support].[TicketPriority] WHERE priorityID = @priorityID AND priorityActive = 1)
            THROW 50001, N'أولوية التذكرة غير صالحة', 1;

        IF NULLIF(LTRIM(RTRIM(@ticketTitle)), N'') IS NULL
            THROW 50001, N'عنوان التذكرة مطلوب', 1;

        IF NULLIF(LTRIM(RTRIM(@ticketDescription)), N'') IS NULL
            THROW 50001, N'وصف التذكرة مطلوب', 1;

        IF @ticketTypeID IN (1, 2)
        BEGIN
            SET @affectedPageNameClean = NULL;
            SET @affectedPageUrlClean = NULL;
            SET @affectedActionNameClean = NULL;
        END
        ELSE IF @ticketTypeID = 3
        BEGIN
            IF @affectedPageNameClean IS NULL AND @affectedPageUrlClean IS NULL
                THROW 50001, N'لنوع خطأ صفحة محددة يجب تحديد اسم الصفحة أو رابطها', 1;

            SET @affectedActionNameClean = NULL;
        END
        ELSE IF @ticketTypeID = 4
        BEGIN
            IF @affectedPageNameClean IS NULL AND @affectedPageUrlClean IS NULL
                THROW 50001, N'لنوع خطأ إجراء داخل صفحة يجب تحديد اسم الصفحة أو رابطها', 1;

            IF @affectedActionNameClean IS NULL
                THROW 50001, N'لنوع خطأ إجراء داخل صفحة يجب تحديد اسم الإجراء', 1;
        END

        SET @seq = NEXT VALUE FOR [support].[SeqTicketNo];
        SET @ticketNo = CONVERT(NVARCHAR(8), GETDATE(), 112)
                      + RIGHT(REPLICATE(N'0', 20) + CONVERT(NVARCHAR(20), @seq), 20);

        INSERT INTO [support].[Ticket]
        (
            ticketNo, ticketTypeID_FK, priorityID_FK, statusID_FK,
            ticketTitle, ticketDescription,
            affectedPageName, affectedPageUrl, affectedActionName, errorDetails,
            createdByUserID_FK, entryData, hostName
        )
        VALUES
        (
            @ticketNo, @ticketTypeID, ISNULL(@priorityID, 2), 1,
            @ticketTitle, @ticketDescription,
            @affectedPageNameClean,
            @affectedPageUrlClean,
            @affectedActionNameClean,
            NULLIF(LTRIM(RTRIM(@errorDetails)), N''),
            @callerUserID, @entryData, @hostName
        );

        IF @@ROWCOUNT = 0
            THROW 50002, N'حصل خطأ في إنشاء التذكرة', 1;

        SET @newID = SCOPE_IDENTITY();
        IF @newID IS NULL OR @newID <= 0
            THROW 50002, N'حصل خطأ في إنشاء التذكرة - Identity', 1;

        SET @note = N'{' +
              N'"ticketID":"' + ISNULL(CONVERT(NVARCHAR(20), @newID), N'') + N'"'
            + N',"ticketNo":"' + ISNULL(@ticketNo, N'') + N'"'
            + N',"ticketTypeID":"' + ISNULL(CONVERT(NVARCHAR(20), @ticketTypeID), N'') + N'"'
            + N',"priorityID":"' + ISNULL(CONVERT(NVARCHAR(20), @priorityID), N'') + N'"'
            + N',"callerUserID":"' + ISNULL(CONVERT(NVARCHAR(20), @callerUserID), N'') + N'"'
            + N',"entryData":"' + ISNULL(@entryData, N'') + N'"'
            + N'}';

        INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
        VALUES (N'[support].[Ticket]', N'SPT_CREATE_TICKET', @newID, @entryData, @note);

        SELECT 1 AS IsSuccessful, N'تم إنشاء التذكرة الهاتفية بنجاح' AS Message_;
        RETURN;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END
GO

-- Patch Masters_DataLoad: add SupportPhoneTickets route
BEGIN
    DECLARE @DefDL NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.Masters_DataLoad'));
    IF @DefDL IS NOT NULL
       AND @DefDL NOT LIKE N'%ELSE IF @pageName_ = ''SupportPhoneTickets''%'
    BEGIN
        SET @DefDL = REPLACE(@DefDL,
            N'CREATE PROCEDURE [dbo].[Masters_DataLoad]',
            N'ALTER PROCEDURE [dbo].[Masters_DataLoad]');

        DECLARE @NeedleDL NVARCHAR(200) = N'ELSE IF @pageName_ = ''SupportTicketDetails''';
        DECLARE @InsertDL NVARCHAR(MAX) = N'ELSE IF @pageName_ = ''SupportPhoneTickets''
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E IN (N''SPT_ACCESS'', N''SPT_SELECT'')
            )
            BEGIN
                SELECT 0 AS IsSuccessful, N''عفوا لاتملك صلاحية عرض هذه الصفحة'' AS Message_;
            END
            ELSE
            BEGIN
                EXEC [support].[SupportPhoneTicketsDL]
                      @pageName_ = @pageName_
                    , @idaraID   = @idaraID
                    , @entryData = @entrydata
                    , @hostName  = @hostName
                    , @permissionUserID = @parameter_01;
            END
        END

' + @NeedleDL;

        SET @DefDL = REPLACE(@DefDL, @NeedleDL, @InsertDL);

        EXEC sys.sp_executesql @DefDL;
    END
END
GO

-- Patch Masters_CRUD: add SupportPhoneTickets route
BEGIN
    DECLARE @DefCRUD NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.Masters_CRUD'));
    IF @DefCRUD IS NOT NULL
       AND @DefCRUD NOT LIKE N'%ELSE IF @pageName_ = ''SupportPhoneTickets''%'
    BEGIN
        SET @DefCRUD = REPLACE(@DefCRUD,
            N'CREATE PROCEDURE [dbo].[Masters_CRUD]',
            N'ALTER PROCEDURE [dbo].[Masters_CRUD]');

        DECLARE @NeedleCRUD NVARCHAR(200) = N'ELSE IF @pageName_ = ''SupportTicketDetails''';
        DECLARE @InsertCRUD NVARCHAR(MAX) = N'ELSE IF @pageName_ = ''SupportPhoneTickets''
        BEGIN
            IF (
                SELECT COUNT(*) FROM dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata AND v.menuName_E = @pageName_ AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0; SET @msg = N''عفوا لاتملك صلاحية لهذه العملية''; GOTO Finish;
            END

            DELETE FROM @Result;

            IF @ActionType = ''SPT_CREATE_TICKET''
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [support].[SupportPhoneTicketsSP]
                      @Action             = @ActionType
                    , @ticketTypeID       = @parameter_01
                    , @priorityID         = @parameter_02
                    , @ticketTitle        = @parameter_03
                    , @ticketDescription  = @parameter_04
                    , @affectedPageName   = @parameter_05
                    , @affectedPageUrl    = @parameter_06
                    , @affectedActionName = @parameter_07
                    , @errorDetails       = @parameter_08
                    , @callerUserID       = @parameter_09
                    , @entryData          = @entrydata
                    , @hostName           = @hostName;
            END
            ELSE
            BEGIN
                SET @ok = 0; SET @msg = N''نوع العملية المطلوبة غير معروف. ActionType''; GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END

        ----------------------------------------------------------------
        -- SupportTicketDetails
        ----------------------------------------------------------------
        ' + @NeedleCRUD;

        SET @DefCRUD = REPLACE(@DefCRUD, @NeedleCRUD, @InsertCRUD);

        EXEC sys.sp_executesql @DefCRUD;
    END
END
GO

-- Summary output
SELECT m.menuID, m.menuName_A, m.menuName_E, m.menuLink
FROM dbo.Menu m
WHERE m.menuName_E = N'SupportPhoneTickets';

SELECT d.distributorID, d.distributorName_A, d.distributorName_E
FROM dbo.Distributor d
WHERE d.distributorName_E = N'SupportPhoneTickets';

SELECT pt.permissionTypeID, pt.permissionTypeName_A, pt.permissionTypeName_E
FROM dbo.PermissionType pt
WHERE pt.permissionTypeName_E IN (N'SPT_ACCESS', N'SPT_SELECT', N'SPT_CREATE_TICKET')
ORDER BY pt.permissionTypeID;

SELECT dpt.distributorPermissionTypeID, dpt.DistributorID_FK, pt.permissionTypeName_E
FROM dbo.DistributorPermissionType dpt
JOIN dbo.PermissionType pt ON pt.permissionTypeID = dpt.permissionTypeID_FK
WHERE dpt.DistributorID_FK = (SELECT TOP 1 distributorID FROM dbo.Distributor WHERE distributorName_E = N'SupportPhoneTickets' ORDER BY distributorID DESC)
ORDER BY dpt.distributorPermissionTypeID;

SELECT COUNT(1) AS PermissionRowsForSupportPhoneTickets
FROM dbo.Permission p
JOIN dbo.DistributorPermissionType dpt ON dpt.distributorPermissionTypeID = p.DistributorPermissionTypeID_FK
WHERE dpt.DistributorID_FK = (SELECT TOP 1 distributorID FROM dbo.Distributor WHERE distributorName_E = N'SupportPhoneTickets' ORDER BY distributorID DESC);
