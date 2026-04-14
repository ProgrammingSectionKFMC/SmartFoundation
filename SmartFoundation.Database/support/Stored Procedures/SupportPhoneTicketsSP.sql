
CREATE   PROCEDURE [support].[SupportPhoneTicketsSP]
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