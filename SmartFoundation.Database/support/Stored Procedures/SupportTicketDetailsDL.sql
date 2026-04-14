CREATE   PROCEDURE [support].[SupportTicketDetailsDL]
      @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      BIGINT
    , @hostname       NVARCHAR(400)
    , @ticketID       BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;


    SELECT t.ticketID, t.ticketNo, t.ticketTitle, t.ticketDescription, t.errorDetails,
           t.ticketTypeID_FK, tt.ticketTypeName_A, t.priorityID_FK, tp.priorityName_A,
           t.statusID_FK, ts.statusName_A, t.affectedPageName, t.affectedPageUrl, t.affectedActionName,
           t.createdByUserID_FK, uc.nationalID AS createdByNationalID,
           t.assignedToTeamMemberID_FK, tm.userID_FK AS assignedToUserID, ua.nationalID AS assignedToNationalID,
           t.entryDate, t.assignedDate, t.closedDate
    FROM [support].[Ticket] t
    INNER JOIN [support].[TicketType] tt ON tt.ticketTypeID = t.ticketTypeID_FK
    INNER JOIN [support].[TicketPriority] tp ON tp.priorityID = t.priorityID_FK
    INNER JOIN [support].[TicketStatus] ts ON ts.statusID = t.statusID_FK
    LEFT JOIN [support].[TeamMember] tm ON tm.teamMemberID = t.assignedToTeamMemberID_FK
    LEFT JOIN [dbo].[Users] uc ON uc.usersID = t.createdByUserID_FK
    LEFT JOIN [dbo].[Users] ua ON ua.usersID = tm.userID_FK
    WHERE t.ticketID = @ticketID;

    SELECT r.ticketReplyID, r.ticketID_FK, r.replyText, r.replyByUserID_FK,
           u.nationalID AS replyByNationalID, r.isInternal, r.entryDate
    FROM [support].[TicketReply] r
    LEFT JOIN [dbo].[Users] u ON u.usersID = r.replyByUserID_FK
    WHERE r.ticketID_FK = @ticketID
      AND r.ticketReplyActive = 1
      AND (r.isInternal = 0 OR EXISTS
            (SELECT 1 FROM [support].[TeamMember] tm WHERE tm.userID_FK = @entrydata AND tm.teamMemberActive = 1))
    ORDER BY r.ticketReplyID ASC;

    SELECT a.ticketAttachmentID, a.ticketID_FK, a.fileName, a.contentType,
           a.fileSizeBytes, a.storagePath, a.uploadedByUserID_FK,
           u.nationalID AS uploadedByNationalID, a.entryDate
    FROM [support].[TicketAttachment] a
    LEFT JOIN [dbo].[Users] u ON u.usersID = a.uploadedByUserID_FK
    WHERE a.ticketID_FK = @ticketID AND a.ticketAttachmentActive = 1
    ORDER BY a.ticketAttachmentID DESC;

    SELECT h.ticketAssignmentHistoryID, h.ticketID_FK, h.fromTeamMemberID_FK,
           f.userID_FK AS fromUserID, uf.nationalID AS fromNationalID,
           h.toTeamMemberID_FK, tmm.userID_FK AS toUserID, ut.nationalID AS toNationalID,
           h.actionByUserID_FK, ua.nationalID AS actionByNationalID,
           h.assignmentNote, h.entryDate
    FROM [support].[TicketAssignmentHistory] h
    LEFT JOIN [support].[TeamMember] f ON f.teamMemberID = h.fromTeamMemberID_FK
    LEFT JOIN [support].[TeamMember] tmm ON tmm.teamMemberID = h.toTeamMemberID_FK
    LEFT JOIN [dbo].[Users] uf ON uf.usersID = f.userID_FK
    LEFT JOIN [dbo].[Users] ut ON ut.usersID = tmm.userID_FK
    LEFT JOIN [dbo].[Users] ua ON ua.usersID = h.actionByUserID_FK
    WHERE h.ticketID_FK = @ticketID
    ORDER BY h.ticketAssignmentHistoryID DESC;

    SELECT tk.ticketTaskID, tk.ticketID_FK, tk.taskNo, tk.taskTitle, tk.taskDescription,
           tk.statusID_FK, s.statusName_A, tk.priorityID_FK, p.priorityName_A,
           tk.assignedToTeamMemberID_FK, tm.userID_FK AS assignedToUserID, u.nationalID AS assignedToNationalID,
           tk.assignedDate, tk.dueDate, tk.completedDate, tk.taskOrder, tk.isRequired
    FROM [support].[TicketTask] tk
    INNER JOIN [support].[TicketStatus] s ON s.statusID = tk.statusID_FK
    INNER JOIN [support].[TicketPriority] p ON p.priorityID = tk.priorityID_FK
    LEFT JOIN [support].[TeamMember] tm ON tm.teamMemberID = tk.assignedToTeamMemberID_FK
    LEFT JOIN [dbo].[Users] u ON u.usersID = tm.userID_FK
    WHERE tk.ticketID_FK = @ticketID AND tk.taskActive = 1
    ORDER BY ISNULL(tk.taskOrder, 999999), tk.ticketTaskID;

    SELECT statusID, statusName_A FROM [support].[TicketStatus] WHERE statusActive = 1 ORDER BY statusID;
    SELECT priorityID, priorityName_A FROM [support].[TicketPriority] WHERE priorityActive = 1 ORDER BY priorityID;

        select t.teamMemberID,u.FullName 
    from support.TeamMember  t
    inner join dbo.V_GetFullSystemUsersDetails u on u.usersID = t.userID_FK
    where teamMemberActive = 1 
    and canReceiveTickets = 1
END