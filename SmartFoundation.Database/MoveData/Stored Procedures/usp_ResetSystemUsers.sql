CREATE   PROCEDURE [MoveData].[usp_ResetSystemUsers]
    @ConfirmReset bit = 0,
    @RollbackAfterTest bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF DB_NAME() <> N'DATACORE'
        THROW 59100, N'This procedure can run only in the DATACORE database.', 1;

    IF @ConfirmReset <> 1
        THROW 59101, N'User reset was not confirmed. Pass @ConfirmReset = 1.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE usersID > 12)
    BEGIN
        BEGIN TRANSACTION;
        DBCC CHECKIDENT (N'dbo.Users', RESEED, 12) WITH NO_INFOMSGS;

        SELECT
            @RollbackAfterTest AS RollbackAfterTest,
            CONVERT(bigint, 0) AS UsersDeleted,
            CONVERT(bigint, 12) AS UsersIdentityReseed,
            N'No users above usersID 12 were found.' AS Message_;

        IF @RollbackAfterTest = 1 ROLLBACK TRANSACTION; ELSE COMMIT TRANSACTION;
        RETURN;
    END;

    /*
      Support tickets are operational records, not user permissions.  Do not
      silently erase them as part of an account reset.  They must be handled
      explicitly before deleting the referenced users/team members.
    */
    IF EXISTS (SELECT 1 FROM support.Ticket WHERE createdByUserID_FK > 12 OR assignedByUserID_FK > 12)
       OR EXISTS (SELECT 1 FROM support.TicketAssignmentHistory WHERE actionByUserID_FK > 12)
       OR EXISTS (SELECT 1 FROM support.TicketAttachment WHERE uploadedByUserID_FK > 12)
       OR EXISTS (SELECT 1 FROM support.TicketReply WHERE replyByUserID_FK > 12)
       OR EXISTS (SELECT 1 FROM support.TicketTask WHERE assignedByUserID_FK > 12)
       OR EXISTS
       (
           SELECT 1
           FROM support.TeamMember teamMember
           WHERE teamMember.userID_FK > 12
             AND
             (
                 EXISTS (SELECT 1 FROM support.Ticket ticketRow WHERE ticketRow.assignedToTeamMemberID_FK = teamMember.teamMemberID)
                 OR EXISTS (SELECT 1 FROM support.TicketAssignmentHistory historyRow WHERE historyRow.fromTeamMemberID_FK = teamMember.teamMemberID OR historyRow.toTeamMemberID_FK = teamMember.teamMemberID)
                 OR EXISTS (SELECT 1 FROM support.TicketTask taskRow WHERE taskRow.assignedToTeamMemberID_FK = teamMember.teamMemberID)
             )
       )
        THROW 59102, N'Cannot reset users: support transactions reference one or more users above usersID 12. Reassign or remove those transactions explicitly first.', 1;

    DECLARE
        @UsersBefore bigint = (SELECT COUNT_BIG(*) FROM dbo.Users WHERE usersID > 12),
        @MenuPermissionsDeleted bigint = 0,
        @PermissionsDeleted bigint = 0,
        @ProgramDistributorsDeleted bigint = 0,
        @UserDistributorsDeleted bigint = 0,
        @UsersDeleted bigint = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* User preferences, notifications, photos, and direct account data. */
        DELETE FROM dbo.ChartListUsers WHERE UsersID_FK > 12;
        DELETE FROM dbo.MvcThameUser WHERE UsersID_FK > 12;
        DELETE FROM dbo.UserNotifications WHERE UserId_FK > 12;
        DELETE FROM dbo.UserPhoto WHERE userID_FK > 12;
        DELETE FROM dbo.UsersPhoto WHERE usersID_FK > 12;
        DELETE FROM dbo.contactInfo WHERE userID_FK > 12;

        /* User-specific permissions and administrative assignments. */
        DELETE FROM dbo.MenuDistributor WHERE userID_FK > 12;
        SET @MenuPermissionsDeleted = @@ROWCOUNT;

        DELETE FROM dbo.Permission WHERE UsersID_FK > 12;
        SET @PermissionsDeleted = @@ROWCOUNT;

        DELETE FROM dbo.ProgramDistributor WHERE userID_FK > 12;
        SET @ProgramDistributorsDeleted = @@ROWCOUNT;

        DELETE FROM dbo.UserDistributor WHERE userID_FK > 12;
        SET @UserDistributorsDeleted = @@ROWCOUNT;

        /* Remove support-team roles/membership after transactional references were checked. */
        DELETE teamMemberRole
        FROM support.TeamMemberRole teamMemberRole
        JOIN support.TeamMember teamMember
          ON teamMember.teamMemberID = teamMemberRole.teamMemberID_FK
        WHERE teamMember.userID_FK > 12;

        DELETE FROM support.TeamMember WHERE userID_FK > 12;

        /* Preserve operational rows but remove reusable user IDs from nullable, non-FK columns. */
        
        UPDATE dbo.Document SET userID_FK = NULL WHERE userID_FK > 12;
        
        UPDATE VIC.vehicleWithUsers SET userID_FK = NULL WHERE userID_FK > 12;

        /* Required children of dbo.Users. */
        DELETE FROM dbo.UsersPassword WHERE usersID_FK > 12;
        DELETE FROM dbo.UsersDetails WHERE usersID_FK > 12;

        DELETE FROM dbo.Users WHERE usersID > 12;
        SET @UsersDeleted = @@ROWCOUNT;

        IF EXISTS (SELECT 1 FROM dbo.Users WHERE usersID > 12)
            THROW 59103, N'User reset verification failed: users above usersID 12 remain.', 1;

        /* With rows 1..12 retained, RESEED 12 makes the next Users identity 13. */
        DBCC CHECKIDENT (N'dbo.Users', RESEED, 12) WITH NO_INFOMSGS;

        SELECT
            @RollbackAfterTest AS RollbackAfterTest,
            @UsersBefore AS UsersBeforeReset,
            @UsersDeleted AS UsersDeleted,
            @MenuPermissionsDeleted AS MenuPermissionsDeleted,
            @PermissionsDeleted AS PermissionsDeleted,
            @ProgramDistributorsDeleted AS ProgramDistributorsDeleted,
            @UserDistributorsDeleted AS UserDistributorsDeleted,
            (SELECT COUNT_BIG(*) FROM dbo.Users) AS UsersRemaining,
            CONVERT(bigint, 13) AS NextUsersIdentity;

        IF @RollbackAfterTest = 1
            ROLLBACK TRANSACTION;
        ELSE
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
