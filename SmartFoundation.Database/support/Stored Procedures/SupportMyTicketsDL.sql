CREATE PROCEDURE [support].[SupportMyTicketsDL]
      @pageName_ NVARCHAR(400)
    , @idaraID   INT
    , @entrydata BIGINT
    , @hostname  NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT t.ticketID, t.ticketNo, t.ticketTitle, t.ticketDescription,
           tt.ticketTypeName_A, tp.priorityName_A, ts.statusName_A,
           t.affectedPageName, t.affectedPageUrl, t.affectedActionName,
           t.entryDate, t.assignedDate, t.closedDate
    FROM [support].[Ticket] t
    INNER JOIN [support].[TicketType] tt ON tt.ticketTypeID = t.ticketTypeID_FK
    INNER JOIN [support].[TicketPriority] tp ON tp.priorityID = t.priorityID_FK
    INNER JOIN [support].[TicketStatus] ts ON ts.statusID = t.statusID_FK
    WHERE t.ticketActive = 1 AND t.createdByUserID_FK = @entrydata
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
    WHERE v.userID = @entrydata
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
    WHERE v.userID = @entrydata
      AND NULLIF(LTRIM(RTRIM(ISNULL(v.menuName_A, N''))), N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(ISNULL(v.permissionTypeName_A, N''))), N'') IS NOT NULL
      AND NOT (
            v.permissionTypeName_E = N'ACCESS'
         OR v.permissionTypeName_E = N'SELECT'
         OR v.permissionTypeName_E LIKE N'%_ACCESS'
         OR v.permissionTypeName_E LIKE N'%_SELECT'
      )
    ORDER BY v.menuName_A, v.permissionTypeName_A;

    SELECT statusID, statusName_A
    FROM [support].[TicketStatus]
    WHERE statusActive = 1
    ORDER BY statusID;
END