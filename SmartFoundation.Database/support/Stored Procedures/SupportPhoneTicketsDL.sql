
CREATE   PROCEDURE [support].[SupportPhoneTicketsDL]
      @pageName_         NVARCHAR(400)
    , @idaraID           INT
    , @entrydata         BIGINT
    , @hostname          NVARCHAR(400)
    , @permissionUserID  NVARCHAR(50) = NULL
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

    -- الصفحات المسموح بها للمستخدم المختار
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

    -- الإجراءات المسموح بها لكل صفحة للمستخدم المختار
    SELECT DISTINCT
           v.menuID,
           v.menuName_A,
           v.menuName_E,
           v.permissionTypeName_A,
           v.permissionTypeName_E,
           v.permissionID
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