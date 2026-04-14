CREATE PROCEDURE [support].[SupportTicketDetailsSP]
(
      @Action                NVARCHAR(200)
    , @ticketID              BIGINT         = NULL
    , @replyText             NVARCHAR(MAX)  = NULL
    , @isInternal            BIT            = 0
    , @statusID              TINYINT        = NULL
    , @assignToTeamMemberID  BIGINT         = NULL
    , @assignmentNote        NVARCHAR(1000) = NULL
    , @taskTitle             NVARCHAR(300)  = NULL
    , @taskDescription       NVARCHAR(MAX)  = NULL
    , @taskPriorityID        TINYINT        = NULL
    , @taskAssignToMemberID  BIGINT         = NULL
    , @taskDueDate           DATETIME       = NULL
    , @taskID                BIGINT         = NULL
    , @taskStatusID          TINYINT        = NULL
    , @entryData             NVARCHAR(20)   = NULL
    , @hostName              NVARCHAR(200)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE
          @entryUserID BIGINT = TRY_CONVERT(BIGINT, @entryData)
        , @isSupportUser BIT = 0
        , @currentAssigned BIGINT = NULL
        , @seq BIGINT = NULL
        , @newTaskNo NVARCHAR(40) = NULL
        , @newReplyID BIGINT = NULL
        , @newAssignmentID BIGINT = NULL
        , @newTaskID BIGINT = NULL
        , @note NVARCHAR(MAX) = NULL;

    BEGIN TRY
        IF @tc = 0
            BEGIN TRAN;

        IF NULLIF(LTRIM(RTRIM(@Action)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'العملية مطلوبة', 1;
        END

        IF @ticketID IS NULL
        BEGIN
            ;THROW 50001, N'رقم التذكرة مطلوب', 1;
        END

        IF @entryUserID IS NULL
        BEGIN
            ;THROW 50001, N'المستخدم غير صالح', 1;
        END

        IF NOT EXISTS (SELECT 1 FROM [support].[Ticket] WHERE ticketID = @ticketID AND ticketActive = 1)
        BEGIN
            ;THROW 50001, N'التذكرة غير موجودة', 1;
        END

        SELECT @isSupportUser = CASE WHEN EXISTS
        (
            SELECT 1 FROM [support].[TeamMember] WHERE userID_FK = @entryUserID AND teamMemberActive = 1
        ) THEN 1 ELSE 0 END;

        IF @Action = N'STD_ADD_REPLY'
        BEGIN
            IF NULLIF(LTRIM(RTRIM(@replyText)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نص الرد مطلوب', 1;
            END

            INSERT INTO [support].[TicketReply]
            (
                ticketID_FK, replyText, replyByUserID_FK, isInternal, entryData, hostName
            )
            VALUES
            (
                @ticketID, @replyText, @entryUserID,
                CASE WHEN @isSupportUser = 1 THEN ISNULL(@isInternal, 0) ELSE 0 END,
                @entryData, @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في إضافة الرد', 1;
            END

            SET @newReplyID = SCOPE_IDENTITY();
            SET @note = N'{"ticketID":"' + ISNULL(CONVERT(NVARCHAR(20), @ticketID), N'')
                      + N'","replyID":"' + ISNULL(CONVERT(NVARCHAR(20), @newReplyID), N'') + N'"}';

            INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[support].[TicketReply]', N'STD_INSERT', ISNULL(@newReplyID, 0), @entryData, @note);

            SELECT 1 AS IsSuccessful, N'تم إضافة الرد بنجاح' AS Message_;
            RETURN;
        END
        ELSE IF @Action = N'STD_CHANGE_STATUS'
        BEGIN
            IF @statusID IS NULL
            BEGIN
                ;THROW 50001, N'الحالة مطلوبة', 1;
            END

            IF @isSupportUser = 0
            BEGIN
                ;THROW 50001, N'عفوا لاتملك صلاحية تغيير الحالة', 1;
            END

            IF NOT EXISTS (SELECT 1 FROM [support].[TicketStatus] WHERE statusID = @statusID AND statusActive = 1)
            BEGIN
                ;THROW 50001, N'الحالة غير صالحة', 1;
            END

            UPDATE [support].[Ticket]
            SET statusID_FK = @statusID,
                closedDate = CASE WHEN @statusID = 4 THEN GETDATE() ELSE closedDate END,
                entryData = ISNULL(ISNULL(entryData, N'') + N',' + @entryData, entryData),
                hostName = ISNULL(ISNULL(hostName, N'') + N',' + @hostName, hostName)
            WHERE ticketID = @ticketID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1;
            END

            SET @note = N'{"ticketID":"' + ISNULL(CONVERT(NVARCHAR(20), @ticketID), N'')
                      + N'","statusID":"' + ISNULL(CONVERT(NVARCHAR(20), @statusID), N'') + N'"}';

            INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[support].[Ticket]', N'STD_UPDATE_STATUS', @ticketID, @entryData, @note);

            SELECT 1 AS IsSuccessful, N'تم تحديث حالة التذكرة بنجاح' AS Message_;
            RETURN;
        END
        ELSE IF @Action = N'STD_ASSIGN'
        BEGIN
            IF @assignToTeamMemberID IS NULL
            BEGIN
                ;THROW 50001, N'الموظف المراد الإسناد له مطلوب', 1;
            END

            IF @isSupportUser = 0
            BEGIN
                ;THROW 50001, N'عفوا لاتملك صلاحية الإسناد', 1;
            END

            IF NOT EXISTS (SELECT 1 FROM [support].[TeamMember] WHERE teamMemberID = @assignToTeamMemberID AND teamMemberActive = 1)
            BEGIN
                ;THROW 50001, N'الموظف غير موجود أو غير نشط', 1;
            END

            SELECT @currentAssigned = assignedToTeamMemberID_FK
            FROM [support].[Ticket]
            WHERE ticketID = @ticketID;

            UPDATE [support].[Ticket]
            SET assignedToTeamMemberID_FK = @assignToTeamMemberID,
                assignedByUserID_FK = @entryUserID,
                assignedDate = GETDATE(),
                statusID_FK = CASE WHEN statusID_FK = 1 THEN 2 ELSE statusID_FK END,
                entryData = ISNULL(ISNULL(entryData, N'') + N',' + @entryData, entryData),
                hostName = ISNULL(ISNULL(hostName, N'') + N',' + @hostName, hostName)
            WHERE ticketID = @ticketID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1;
            END

            INSERT INTO [support].[TicketAssignmentHistory]
            (
                ticketID_FK, fromTeamMemberID_FK, toTeamMemberID_FK,
                actionByUserID_FK, assignmentNote, entryData, hostName
            )
            VALUES
            (
                @ticketID, @currentAssigned, @assignToTeamMemberID,
                @entryUserID, @assignmentNote, @entryData, @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسجيل التحويل', 1;
            END

            SET @newAssignmentID = SCOPE_IDENTITY();
            SET @note = N'{"ticketID":"' + ISNULL(CONVERT(NVARCHAR(20), @ticketID), N'')
                      + N'","from":"' + ISNULL(CONVERT(NVARCHAR(20), @currentAssigned), N'')
                      + N'","to":"' + ISNULL(CONVERT(NVARCHAR(20), @assignToTeamMemberID), N'') + N'"}';

            INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[support].[TicketAssignmentHistory]', N'STD_INSERT', ISNULL(@newAssignmentID, 0), @entryData, @note);

            SELECT 1 AS IsSuccessful, N'تم تحويل التذكرة بنجاح' AS Message_;
            RETURN;
        END
        ELSE IF @Action = N'STD_ADD_TASK'
        BEGIN
            IF @taskAssignToMemberID IS NULL
            BEGIN
                ;THROW 50001, N'الموظف للمهمة مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@taskTitle)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'عنوان المهمة مطلوب', 1;
            END

            IF @isSupportUser = 0
            BEGIN
                ;THROW 50001, N'عفوا لاتملك صلاحية إضافة مهام', 1;
            END

            IF NOT EXISTS (SELECT 1 FROM [support].[TeamMember] WHERE teamMemberID = @taskAssignToMemberID AND teamMemberActive = 1)
            BEGIN
                ;THROW 50001, N'الموظف غير موجود أو غير نشط', 1;
            END

            IF @taskPriorityID IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM [support].[TicketPriority] WHERE priorityID = @taskPriorityID AND priorityActive = 1)
            BEGIN
                ;THROW 50001, N'أولوية المهمة غير صالحة', 1;
            END

            SET @seq = NEXT VALUE FOR [support].[SeqTicketNo];
            SET @newTaskNo = CONVERT(NVARCHAR(8), GETDATE(), 112)
                           + RIGHT(REPLICATE(N'0', 20) + CONVERT(NVARCHAR(20), @seq), 20);

            INSERT INTO [support].[TicketTask]
            (
                ticketID_FK, taskNo, taskTitle, taskDescription, statusID_FK, priorityID_FK,
                assignedToTeamMemberID_FK, assignedByUserID_FK, dueDate, entryData, hostName
            )
            VALUES
            (
                @ticketID, @newTaskNo, @taskTitle, @taskDescription, 1, ISNULL(@taskPriorityID, 2),
                @taskAssignToMemberID, @entryUserID, @taskDueDate, @entryData, @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في إنشاء المهمة', 1;
            END

            SET @newTaskID = SCOPE_IDENTITY();
            IF @newTaskID IS NULL OR @newTaskID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في إنشاء المهمة - Identity', 1;
            END

            UPDATE [support].[Ticket]
            SET statusID_FK = CASE WHEN statusID_FK IN (1, 5) THEN 2 ELSE statusID_FK END,
                entryData = ISNULL(ISNULL(entryData, N'') + N',' + @entryData, entryData),
                hostName = ISNULL(ISNULL(hostName, N'') + N',' + @hostName, hostName)
            WHERE ticketID = @ticketID;

            SET @note = N'{"ticketID":"' + ISNULL(CONVERT(NVARCHAR(20), @ticketID), N'')
                      + N'","taskID":"' + ISNULL(CONVERT(NVARCHAR(20), @newTaskID), N'')
                      + N'","taskNo":"' + ISNULL(@newTaskNo, N'') + N'"}';

            INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[support].[TicketTask]', N'STD_INSERT', @newTaskID, @entryData, @note);

            SELECT 1 AS IsSuccessful, N'تم إنشاء المهمة بنجاح' AS Message_;
            RETURN;
        END
        ELSE IF @Action = N'STD_UPDATE_TASK_STATUS'
        BEGIN
            IF @taskID IS NULL OR @taskStatusID IS NULL
            BEGIN
                ;THROW 50001, N'بيانات المهمة غير مكتملة', 1;
            END

            IF NOT EXISTS (SELECT 1 FROM [support].[TicketStatus] WHERE statusID = @taskStatusID AND statusActive = 1)
            BEGIN
                ;THROW 50001, N'حالة المهمة غير صالحة', 1;
            END

            UPDATE [support].[TicketTask]
            SET statusID_FK = @taskStatusID,
                completedDate = CASE WHEN @taskStatusID IN (3, 4) THEN GETDATE() ELSE completedDate END,
                entryData = ISNULL(ISNULL(entryData, N'') + N',' + @entryData, entryData),
                hostName = ISNULL(ISNULL(hostName, N'') + N',' + @hostName, hostName)
            WHERE ticketTaskID = @taskID
              AND ticketID_FK = @ticketID
              AND taskActive = 1;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1;
            END

            SET @note = N'{"ticketID":"' + ISNULL(CONVERT(NVARCHAR(20), @ticketID), N'')
                      + N'","taskID":"' + ISNULL(CONVERT(NVARCHAR(20), @taskID), N'')
                      + N'","statusID":"' + ISNULL(CONVERT(NVARCHAR(20), @taskStatusID), N'') + N'"}';

            INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[support].[TicketTask]', N'STD_UPDATE_STATUS', @taskID, @entryData, @note);

            SELECT 1 AS IsSuccessful, N'تم تحديث حالة المهمة' AS Message_;
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