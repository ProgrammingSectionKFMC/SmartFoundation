CREATE   PROCEDURE [support].[SupportTeamManagementDL]
      @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      BIGINT
    , @hostname       NVARCHAR(400)
    , @onlyActive     BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT tm.teamMemberID, tm.userID_FK, u.nationalID, u.usersActive,
           tm.canReceiveTickets, tm.canAssignTickets, tm.teamMemberActive, tm.entryDate
    FROM [support].[TeamMember] tm
    INNER JOIN [dbo].[Users] u ON u.usersID = tm.userID_FK
   -- WHERE (@onlyActive = 0 OR tm.teamMemberActive = 1)
    ORDER BY tm.teamMemberID DESC;

    SELECT tmr.teamMemberRoleID, tmr.teamMemberID_FK, tmr.roleID_FK,
           r.roleName_A, r.roleName_E, tmr.teamMemberRoleActive, tmr.entryDate
    FROM [support].[TeamMemberRole] tmr
    INNER JOIN [dbo].[Role] r ON r.roleID = tmr.roleID_FK
    ORDER BY tmr.teamMemberRoleID DESC;

    SELECT u.usersID, u.nationalID
    FROM [dbo].[Users] u
    WHERE ISNULL(u.usersActive, 0) = 1
    ORDER BY u.nationalID;

    SELECT r.roleID, r.roleName_A, r.roleName_E
    FROM [dbo].[Role] r
    WHERE ISNULL(r.PublicView, 1) = 1
    ORDER BY r.roleID;
END