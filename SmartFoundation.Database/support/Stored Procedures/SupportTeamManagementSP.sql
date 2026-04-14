CREATE PROCEDURE [support].[SupportTeamManagementSP]
(
      @Action             NVARCHAR(200)
    , @teamMemberID       BIGINT        = NULL
    , @userID             BIGINT        = NULL
    , @canReceiveTickets  BIT           = NULL
    , @canAssignTickets   BIT           = NULL
    , @memberActive       BIT           = NULL
    , @teamMemberRoleID   BIGINT        = NULL
    , @roleID             BIGINT        = NULL
    , @entryData          NVARCHAR(20)  = NULL
    , @hostName           NVARCHAR(200) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE
          @entryUserID BIGINT = TRY_CONVERT(BIGINT, @entryData)
        , @newMemberID BIGINT = NULL
        , @newMemberRoleID BIGINT = NULL
        , @note NVARCHAR(MAX) = NULL;

    BEGIN TRY
        IF @tc = 0
            BEGIN TRAN;

        IF NULLIF(LTRIM(RTRIM(@Action)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'العملية مطلوبة', 1;
        END

        IF @entryUserID IS NULL
        BEGIN
            ;THROW 50001, N'المستخدم غير صالح', 1;
        END

        IF @Action = N'STM_ADD_MEMBER'
        BEGIN
            IF @userID IS NULL
            BEGIN
                ;THROW 50001, N'المستخدم مطلوب', 1;
            END

            IF NOT EXISTS (SELECT 1 FROM dbo.[Users] WHERE usersID = @userID)
            BEGIN
                ;THROW 50001, N'المستخدم غير موجود', 1;
            END

            IF EXISTS (SELECT 1 FROM [support].[TeamMember] WHERE userID_FK = @userID)
            BEGIN
                ;THROW 50001, N'المستخدم مضاف مسبقاً في فريق الدعم', 1;
            END

            INSERT INTO [support].[TeamMember]
            (
                userID_FK, canReceiveTickets, canAssignTickets,
                teamMemberActive, entryData, hostName
            )
            VALUES
            (
                @userID, ISNULL(@canReceiveTickets, 1), ISNULL(@canAssignTickets, 0),
                1, @entryData, @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في إضافة عضو الدعم', 1;
            END

            SET @newMemberID = SCOPE_IDENTITY();
            IF @newMemberID IS NULL OR @newMemberID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في إضافة عضو الدعم - Identity', 1;
            END

            SET @note = N'{"teamMemberID":"' + ISNULL(CONVERT(NVARCHAR(20), @newMemberID), N'')
                      + N'","userID":"' + ISNULL(CONVERT(NVARCHAR(20), @userID), N'') + N'"}';

            INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[support].[TeamMember]', N'STM_INSERT', @newMemberID, @entryData, @note);

            SELECT 1 AS IsSuccessful, N'تمت إضافة عضو الدعم بنجاح' AS Message_;
            RETURN;
        END
        ELSE IF @Action = N'STM_UPDATE_MEMBER'
        BEGIN
            IF @teamMemberID IS NULL
            BEGIN
                ;THROW 50001, N'عضو الدعم مطلوب', 1;
            END

            IF NOT EXISTS (SELECT 1 FROM [support].[TeamMember] WHERE teamMemberID = @teamMemberID)
            BEGIN
                ;THROW 50001, N'عضو الدعم غير موجود', 1;
            END

            UPDATE [support].[TeamMember]
            SET canReceiveTickets = ISNULL(@canReceiveTickets, canReceiveTickets),
                canAssignTickets = ISNULL(@canAssignTickets, canAssignTickets),
                teamMemberActive = ISNULL(@memberActive, teamMemberActive),
                entryData = ISNULL(ISNULL(entryData, N'') + N',' + @entryData, entryData),
                hostName = ISNULL(ISNULL(hostName, N'') + N',' + @hostName, hostName)
            WHERE teamMemberID = @teamMemberID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1;
            END

            SET @note = N'{"teamMemberID":"' + ISNULL(CONVERT(NVARCHAR(20), @teamMemberID), N'') + N'"}';

            INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[support].[TeamMember]', N'STM_UPDATE', @teamMemberID, @entryData, @note);

            SELECT 1 AS IsSuccessful, N'تم تحديث عضو الدعم بنجاح' AS Message_;
            RETURN;
        END
        ELSE IF @Action = N'STM_DEACTIVATE_MEMBER'
        BEGIN
            IF @teamMemberID IS NULL
            BEGIN
                ;THROW 50001, N'عضو الدعم مطلوب', 1;
            END

            IF NOT EXISTS (SELECT 1 FROM [support].[TeamMember] WHERE teamMemberID = @teamMemberID)
            BEGIN
                ;THROW 50001, N'عضو الدعم غير موجود', 1;
            END

            UPDATE [support].[TeamMember]
            SET teamMemberActive = 0,
                entryData = ISNULL(ISNULL(entryData, N'') + N',' + @entryData, entryData),
                hostName = ISNULL(ISNULL(hostName, N'') + N',' + @hostName, hostName)
            WHERE teamMemberID = @teamMemberID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1;
            END

            UPDATE [support].[TeamMemberRole]
            SET teamMemberRoleActive = 0,
                entryData = ISNULL(ISNULL(entryData, N'') + N',' + @entryData, entryData),
                hostName = ISNULL(ISNULL(hostName, N'') + N',' + @hostName, hostName)
            WHERE teamMemberID_FK = @teamMemberID
              AND teamMemberRoleActive = 1;

            SET @note = N'{"teamMemberID":"' + ISNULL(CONVERT(NVARCHAR(20), @teamMemberID), N'') + N'"}';

            INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[support].[TeamMember]', N'STM_DELETE', @teamMemberID, @entryData, @note);

            SELECT 1 AS IsSuccessful, N'تم تعطيل عضو الدعم بنجاح' AS Message_;
            RETURN;
        END
        ELSE IF @Action = N'STM_ADD_MEMBER_ROLE'
        BEGIN
            IF @teamMemberID IS NULL OR @roleID IS NULL
            BEGIN
                ;THROW 50001, N'بيانات الدور غير مكتملة', 1;
            END

            IF NOT EXISTS (SELECT 1 FROM [support].[TeamMember] WHERE teamMemberID = @teamMemberID AND teamMemberActive = 1)
            BEGIN
                ;THROW 50001, N'عضو الدعم غير موجود أو غير نشط', 1;
            END

            IF NOT EXISTS (SELECT 1 FROM dbo.[Role] WHERE roleID = @roleID)
            BEGIN
                ;THROW 50001, N'الدور غير موجود', 1;
            END

            IF EXISTS
            (
                SELECT 1
                FROM [support].[TeamMemberRole]
                WHERE teamMemberID_FK = @teamMemberID
                  AND roleID_FK = @roleID
                  AND teamMemberRoleActive = 1
            )
            BEGIN
                ;THROW 50001, N'الدور مضاف مسبقاً لهذا العضو', 1;
            END

            INSERT INTO [support].[TeamMemberRole]
            (
                teamMemberID_FK, roleID_FK, teamMemberRoleActive, entryData, hostName
            )
            VALUES
            (
                @teamMemberID, @roleID, 1, @entryData, @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في إضافة الدور', 1;
            END

            SET @newMemberRoleID = SCOPE_IDENTITY();
            IF @newMemberRoleID IS NULL OR @newMemberRoleID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في إضافة الدور - Identity', 1;
            END

            SET @note = N'{"teamMemberRoleID":"' + ISNULL(CONVERT(NVARCHAR(20), @newMemberRoleID), N'')
                      + N'","teamMemberID":"' + ISNULL(CONVERT(NVARCHAR(20), @teamMemberID), N'')
                      + N'","roleID":"' + ISNULL(CONVERT(NVARCHAR(20), @roleID), N'') + N'"}';

            INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[support].[TeamMemberRole]', N'STM_INSERT', @newMemberRoleID, @entryData, @note);

            SELECT 1 AS IsSuccessful, N'تمت إضافة الدور بنجاح' AS Message_;
            RETURN;
        END
        ELSE IF @Action = N'STM_REMOVE_MEMBER_ROLE'
        BEGIN
            IF @teamMemberRoleID IS NULL
            BEGIN
                ;THROW 50001, N'ربط الدور مطلوب', 1;
            END

            IF NOT EXISTS (SELECT 1 FROM [support].[TeamMemberRole] WHERE teamMemberRoleID = @teamMemberRoleID)
            BEGIN
                ;THROW 50001, N'ربط الدور غير موجود', 1;
            END

            UPDATE [support].[TeamMemberRole]
            SET teamMemberRoleActive = 0,
                entryData = ISNULL(ISNULL(entryData, N'') + N',' + @entryData, entryData),
                hostName = ISNULL(ISNULL(hostName, N'') + N',' + @hostName, hostName)
            WHERE teamMemberRoleID = @teamMemberRoleID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1;
            END

            SET @note = N'{"teamMemberRoleID":"' + ISNULL(CONVERT(NVARCHAR(20), @teamMemberRoleID), N'') + N'"}';

            INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[support].[TeamMemberRole]', N'STM_DELETE', @teamMemberRoleID, @entryData, @note);

            SELECT 1 AS IsSuccessful, N'تم إزالة الدور بنجاح' AS Message_;
            RETURN;
        END
        ELSE
        BEGIN
            ;THROW 50001, N'العملية غير مسجلة', 1;
        END
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;

        ;THROW;
    END CATCH
END