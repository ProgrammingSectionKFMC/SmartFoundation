CREATE   PROCEDURE [support].[SupportInboxDL]
      @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      BIGINT
    , @hostname       NVARCHAR(400)
    , @statusID       TINYINT = NULL
    , @priorityID     TINYINT = NULL
    , @ticketTypeID   TINYINT = NULL
    , @assignedToID   BIGINT  = NULL
    , @dateFrom       DATE    = NULL
    , @dateTo         DATE    = NULL
    , @searchText     NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM [support].[TeamMember] tm
        WHERE tm.userID_FK = @entrydata
          AND tm.teamMemberActive = 1
    )
    BEGIN
        THROW 50001, N'عفوا لاتملك صلاحية عرض صندوق الدعم', 1;
    END

    SELECT t.ticketID, t.ticketNo, t.ticketTitle, t.ticketDescription,
           tt.ticketTypeName_A, tp.priorityName_A, ts.statusName_A,
           t.createdByUserID_FK, uc.nationalID AS createdByNationalID,
           t.assignedToTeamMemberID_FK, tm.userID_FK AS assignedToUserID, ua.nationalID AS assignedToNationalID,
           t.affectedPageName, t.affectedActionName, t.entryDate, t.assignedDate, t.closedDate
    FROM [support].[Ticket] t
    INNER JOIN [support].[TicketType] tt ON tt.ticketTypeID = t.ticketTypeID_FK
    INNER JOIN [support].[TicketPriority] tp ON tp.priorityID = t.priorityID_FK
    INNER JOIN [support].[TicketStatus] ts ON ts.statusID = t.statusID_FK
    LEFT JOIN [support].[TeamMember] tm ON tm.teamMemberID = t.assignedToTeamMemberID_FK
    LEFT JOIN [dbo].[Users] uc ON uc.usersID = t.createdByUserID_FK
    LEFT JOIN [dbo].[Users] ua ON ua.usersID = tm.userID_FK
    WHERE t.ticketActive = 1
      AND (@statusID IS NULL OR t.statusID_FK = @statusID)
      AND (@priorityID IS NULL OR t.priorityID_FK = @priorityID)
      AND (@ticketTypeID IS NULL OR t.ticketTypeID_FK = @ticketTypeID)
      AND (@assignedToID IS NULL OR t.assignedToTeamMemberID_FK = @assignedToID)
      AND (@dateFrom IS NULL OR CAST(t.entryDate AS DATE) >= @dateFrom)
      AND (@dateTo IS NULL OR CAST(t.entryDate AS DATE) <= @dateTo)
      AND (
            NULLIF(LTRIM(RTRIM(ISNULL(@searchText, N''))), N'') IS NULL
            OR t.ticketNo LIKE N'%' + @searchText + N'%'
            OR t.ticketTitle LIKE N'%' + @searchText + N'%'
            OR t.ticketDescription LIKE N'%' + @searchText + N'%'
          )
    ORDER BY t.ticketID DESC;

    SELECT statusID, statusName_A FROM [support].[TicketStatus] WHERE statusActive = 1 ORDER BY statusID;
    SELECT priorityID, priorityName_A FROM [support].[TicketPriority] WHERE priorityActive = 1 ORDER BY priorityID;
    SELECT ticketTypeID, ticketTypeName_A FROM [support].[TicketType] WHERE ticketTypeActive = 1 ORDER BY ticketTypeID;

    SELECT tm.teamMemberID, tm.userID_FK, u.nationalID AS userName
    FROM [support].[TeamMember] tm
    INNER JOIN [dbo].[Users] u ON u.usersID = tm.userID_FK
    WHERE tm.teamMemberActive = 1 AND tm.canReceiveTickets = 1
    ORDER BY u.nationalID;
END