CREATE PROCEDURE [support].[SupportInboxSP]
(
      @Action                NVARCHAR(200)
    , @ticketID              BIGINT         = NULL
    , @statusID              TINYINT        = NULL
    , @assignToTeamMemberID  BIGINT         = NULL
    , @assignmentNote        NVARCHAR(1000) = NULL
    , @ticketIDsCsv          NVARCHAR(MAX)  = NULL
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
        , @fromMemberID BIGINT = NULL
        , @rowsAffected INT = 0
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

        IF NOT EXISTS
        (
            SELECT 1 FROM [support].[TeamMember]
            WHERE userID_FK = @entryUserID AND teamMemberActive = 1
        )
        BEGIN
            ;THROW 50001, N'عفوا لاتملك صلاحية عمليات صندوق الدعم', 1;
        END

        IF @Action = N'SIN_ASSIGN'
        BEGIN
            IF @ticketID IS NULL OR @assignToTeamMemberID IS NULL
            BEGIN
                ;THROW 50001, N'بيانات التحويل غير مكتملة', 1;
            END

            IF NOT EXISTS (SELECT 1 FROM [support].[Ticket] WHERE ticketID = @ticketID AND ticketActive = 1)
            BEGIN
                ;THROW 50001, N'التذكرة غير موجودة', 1;
            END

            IF NOT EXISTS (SELECT 1 FROM [support].[TeamMember] WHERE teamMemberID = @assignToTeamMemberID AND teamMemberActive = 1)
            BEGIN
                ;THROW 50001, N'الموظف غير موجود أو غير نشط', 1;
            END

            SELECT @fromMemberID = assignedToTeamMemberID_FK
            FROM [support].[Ticket]
            WHERE ticketID = @ticketID;

            UPDATE [support].[Ticket]
            SET assignedToTeamMemberID_FK = @assignToTeamMemberID,
                assignedByUserID_FK = @entryUserID,
                assignedDate = GETDATE(),
                statusID_FK = CASE WHEN statusID_FK = 1 THEN 2 ELSE statusID_FK END,
                entryData = ISNULL(ISNULL(entryData,N'') + N',' + @entryData, entryData),
                hostName = ISNULL(ISNULL(hostName,N'') + N',' + @hostName, hostName)
            WHERE ticketID = @ticketID AND ticketActive = 1;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1;
            END

            INSERT INTO [support].[TicketAssignmentHistory]
            (ticketID_FK, fromTeamMemberID_FK, toTeamMemberID_FK, actionByUserID_FK, assignmentNote, entryData, hostName)
            VALUES (@ticketID, @fromMemberID, @assignToTeamMemberID, @entryUserID, @assignmentNote, @entryData, @hostName);

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسجيل التحويل', 1;
            END

            SET @note = N'{"ticketID":"' + ISNULL(CONVERT(NVARCHAR(20), @ticketID), N'')
                      + N'","from":"' + ISNULL(CONVERT(NVARCHAR(20), @fromMemberID), N'')
                      + N'","to":"' + ISNULL(CONVERT(NVARCHAR(20), @assignToTeamMemberID), N'') + N'"}';

            INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[support].[Ticket]', N'SIN_ASSIGN', @ticketID, @entryData, @note);

            SELECT 1 AS IsSuccessful, N'تم تحويل التذكرة بنجاح' AS Message_;
            RETURN;
        END
        ELSE IF @Action = N'SIN_CHANGE_STATUS'
        BEGIN
            IF @ticketID IS NULL OR @statusID IS NULL
            BEGIN
                ;THROW 50001, N'بيانات الحالة غير مكتملة', 1;
            END

            IF NOT EXISTS (SELECT 1 FROM [support].[TicketStatus] WHERE statusID = @statusID AND statusActive = 1)
            BEGIN
                ;THROW 50001, N'الحالة غير صالحة', 1;
            END

            UPDATE [support].[Ticket]
            SET statusID_FK = @statusID,
                closedDate = CASE WHEN @statusID = 4 THEN GETDATE() ELSE closedDate END,
                entryData = ISNULL(ISNULL(entryData,N'') + N',' + @entryData, entryData),
                hostName = ISNULL(ISNULL(hostName,N'') + N',' + @hostName, hostName)
            WHERE ticketID = @ticketID AND ticketActive = 1;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1;
            END

            SET @note = N'{"ticketID":"' + ISNULL(CONVERT(NVARCHAR(20), @ticketID), N'')
                      + N'","statusID":"' + ISNULL(CONVERT(NVARCHAR(20), @statusID), N'') + N'"}';

            INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[support].[Ticket]', N'SIN_UPDATE_STATUS', @ticketID, @entryData, @note);

            SELECT 1 AS IsSuccessful, N'تم تحديث الحالة بنجاح' AS Message_;
            RETURN;
        END
        ELSE IF @Action = N'SIN_BULK_ASSIGN'
        BEGIN
            IF NULLIF(LTRIM(RTRIM(ISNULL(@ticketIDsCsv, N''))), N'') IS NULL OR @assignToTeamMemberID IS NULL
            BEGIN
                ;THROW 50001, N'بيانات التحويل الجماعي غير مكتملة', 1;
            END

            IF NOT EXISTS (SELECT 1 FROM [support].[TeamMember] WHERE teamMemberID = @assignToTeamMemberID AND teamMemberActive = 1)
            BEGIN
                ;THROW 50001, N'الموظف غير موجود أو غير نشط', 1;
            END

            ;WITH ids AS
            (
                SELECT DISTINCT TRY_CONVERT(BIGINT, LTRIM(RTRIM(value))) AS ticketID
                FROM STRING_SPLIT(@ticketIDsCsv, ',')
                WHERE NULLIF(LTRIM(RTRIM(value)), N'') IS NOT NULL
            )
            UPDATE t
            SET assignedToTeamMemberID_FK = @assignToTeamMemberID,
                assignedByUserID_FK = @entryUserID,
                assignedDate = GETDATE(),
                statusID_FK = CASE WHEN statusID_FK = 1 THEN 2 ELSE statusID_FK END,
                entryData = ISNULL(ISNULL(entryData,N'') + N',' + @entryData, entryData),
                hostName = ISNULL(ISNULL(hostName,N'') + N',' + @hostName, hostName)
            FROM [support].[Ticket] t
            INNER JOIN ids i ON i.ticketID = t.ticketID
            WHERE t.ticketActive = 1;

            SET @rowsAffected = @@ROWCOUNT;
            IF @rowsAffected <= 0
            BEGIN
                ;THROW 50001, N'لا توجد تذاكر صالحة للتحويل الجماعي', 1;
            END

            SET @note = N'{"assignTo":"' + ISNULL(CONVERT(NVARCHAR(20), @assignToTeamMemberID), N'')
                      + N'","count":"' + ISNULL(CONVERT(NVARCHAR(20), @rowsAffected), N'') + N'"}';

            INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[support].[Ticket]', N'SIN_BULK_ASSIGN', 0, @entryData, @note);

            SELECT 1 AS IsSuccessful, N'تم التحويل الجماعي بنجاح' AS Message_;
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