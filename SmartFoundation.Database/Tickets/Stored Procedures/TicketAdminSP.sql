
-- Lookup maintenance for the TicketAdmin page (classes, priorities, statuses,
-- pause reasons, arbitration reasons, quality review results).
-- Called by dbo.Masters_CRUD for @pageName_ = 'TicketAdmin'.
-- Codes are generated automatically on insert (CLS-006, PSR-009 ...) and never edited from the form;
-- codes the ticket workflow relies on are protected from deletion.
CREATE PROCEDURE [Tickets].[TicketAdminSP]
(
      @Action        NVARCHAR(200)
    , @recordID      INT            = NULL
    , @code          NVARCHAR(100)  = NULL
    , @name_A        NVARCHAR(200)  = NULL
    , @name_E        NVARCHAR(200)  = NULL
    , @desc          NVARCHAR(1000) = NULL
    , @level         NVARCHAR(20)   = NULL
    , @idaraID_FK    INT            = NULL
    , @entryData     NVARCHAR(20)   = NULL
    , @hostName      NVARCHAR(200)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    BEGIN TRY
        IF @tc = 0 BEGIN TRAN;

        DECLARE @Op NVARCHAR(10) = LEFT(@Action, CHARINDEX(N'_', @Action + N'_') - 1);
        DECLARE @Entity NVARCHAR(100) = SUBSTRING(@Action, LEN(@Op) + 2, 200);

        -- Fixed whitelist: table and column names never come from user input.
        DECLARE @Table SYSNAME, @Prefix SYSNAME, @EntityName NVARCHAR(100), @CodePrefix NVARCHAR(10);
        SELECT @Table = t.tbl, @Prefix = t.prefix, @EntityName = t.label, @CodePrefix = t.codePrefix
        FROM (VALUES
              (N'TICKETCLASS',         N'TicketClass',         N'ticketClass',         N'فئة التذكرة',          N'CLS')
            , (N'PRIORITY',            N'Priority',            N'priority',            N'الأولوية',             N'PRI')
            , (N'TICKETSTATUS',        N'TicketStatus',        N'ticketStatus',        N'حالة التذكرة',         N'STS')
            , (N'PAUSEREASON',         N'PauseReason',         N'pauseReason',         N'سبب الإيقاف',          N'PSR')
            , (N'ARBITRATIONREASON',   N'ArbitrationReason',   N'arbitrationReason',   N'سبب التحكيم',          N'ARB')
            , (N'QUALITYREVIEWRESULT', N'QualityReviewResult', N'qualityReviewResult', N'نتيجة مراجعة الجودة', N'QRR')
        ) t (entity, tbl, prefix, label, codePrefix)
        WHERE t.entity = @Entity;

        IF @Table IS NULL OR @Op NOT IN (N'INSERT', N'UPDATE', N'DELETE')
        BEGIN ;THROW 50001, N'نوع الإجراء غير معروف في TicketAdminSP', 1; END

        SET @code   = NULLIF(UPPER(LTRIM(RTRIM(@code))), N'');
        SET @name_A = NULLIF(LTRIM(RTRIM(@name_A)), N'');
        SET @name_E = NULLIF(LTRIM(RTRIM(@name_E)), N'');
        SET @desc   = NULLIF(LTRIM(RTRIM(@desc)), N'');

        DECLARE @levelInt INT = TRY_CAST(NULLIF(LTRIM(RTRIM(@level)), N'') AS INT);
        IF @Entity = N'PRIORITY' AND @Op <> N'DELETE' AND NULLIF(LTRIM(RTRIM(@level)), N'') IS NOT NULL AND @levelInt IS NULL
        BEGIN ;THROW 50001, N'مستوى الأولوية يجب أن يكون رقماً', 1; END

        DECLARE @fq NVARCHAR(300) = N'[Tickets].' + QUOTENAME(@Table);
        DECLARE @idCol SYSNAME = QUOTENAME(@Prefix + N'ID');
        DECLARE @codeCol SYSNAME = QUOTENAME(@Prefix + N'Code');
        DECLARE @activeCol SYSNAME = QUOTENAME(@Prefix + N'Active');
        DECLARE @sql NVARCHAR(MAX);
        DECLARE @exists BIT = 0, @inUse BIT = 0, @oldCode NVARCHAR(100);

        IF @Op IN (N'UPDATE', N'DELETE')
        BEGIN
            IF @recordID IS NULL
            BEGIN ;THROW 50001, N'الرقم المرجعي للسجل مطلوب', 1; END

            SET @sql = N'SELECT @exists = 1, @oldCode = ' + @codeCol + N' FROM ' + @fq
                     + N' WHERE ' + @idCol + N' = @id AND ISNULL(' + @activeCol + N', 1) = 1;';
            EXEC sp_executesql @sql, N'@id INT, @exists BIT OUTPUT, @oldCode NVARCHAR(100) OUTPUT',
                 @id = @recordID, @exists = @exists OUTPUT, @oldCode = @oldCode OUTPUT;

            IF @exists = 0
            BEGIN ;THROW 50001, N'لم يتم العثور على سجل نشط', 1; END
        END

        -- Workflow logic in Tickets.TicketSP / TicketDL relies on these codes.
        DECLARE @systemCode BIT =
            CASE WHEN @Entity = N'TICKETSTATUS' AND @oldCode IN (N'NEW', N'ROUTED', N'ASSIGNED', N'IN_PROGRESS', N'CLARIFICATION', N'ARBITRATION', N'PAUSED', N'RESOLVED', N'CLOSED', N'REJECTED', N'REOPENED') THEN 1
                 WHEN @Entity = N'PRIORITY' AND @oldCode IN (N'CRITICAL', N'HIGH', N'MEDIUM', N'LOW') THEN 1
                 WHEN @Entity = N'PAUSEREASON' AND @oldCode IN (N'CHILD_DEPENDENCY', N'ARBITRATION', N'CLARIFICATION') THEN 1
                 WHEN @Entity = N'QUALITYREVIEWRESULT' AND @oldCode IN (N'APPROVED', N'RETURN_CORRECTION', N'REJECTED', N'ESCALATED') THEN 1
                 ELSE 0 END;

        IF @Op IN (N'INSERT', N'UPDATE')
        BEGIN
            IF @name_A IS NULL
            BEGIN ;THROW 50001, N'الاسم العربي مطلوب', 1; END

            -- The code is never changed from the form.
            IF @Op = N'UPDATE'
                SET @code = @oldCode;

            -- A code passed explicitly on insert must be unique; otherwise one is generated below.
            IF @Op = N'INSERT' AND @code IS NOT NULL
            BEGIN
                SET @exists = 0;
                SET @sql = N'SELECT @exists = 1 FROM ' + @fq + N' WHERE ' + @codeCol + N' = @code;';
                EXEC sp_executesql @sql, N'@code NVARCHAR(100), @exists BIT OUTPUT',
                     @code = @code, @exists = @exists OUTPUT;

                IF @exists = 1
                BEGIN ;THROW 50001, N'الكود مستخدم مسبقاً', 1; END
            END
        END

        IF @Op = N'DELETE'
        BEGIN
            IF @systemCode = 1
            BEGIN ;THROW 50001, N'لا يمكن حذف هذا السجل لأن سير عمل التذاكر يعتمد عليه', 1; END

            SET @inUse = CASE @Entity
                WHEN N'TICKETCLASS' THEN CASE WHEN EXISTS (SELECT 1 FROM [Tickets].[Ticket] WHERE [ticketClassID_FK] = @recordID AND [ticketActive] = 1)
                                                OR EXISTS (SELECT 1 FROM [Tickets].[Service] WHERE [ticketClassID_FK] = @recordID AND [serviceActive] = 1) THEN 1 ELSE 0 END
                WHEN N'PRIORITY' THEN CASE WHEN EXISTS (SELECT 1 FROM [Tickets].[Ticket] WHERE [effectivePriorityID_FK] = @recordID AND [ticketActive] = 1)
                                             OR EXISTS (SELECT 1 FROM [Tickets].[Service] WHERE [defaultPriorityID_FK] = @recordID AND [serviceActive] = 1) THEN 1 ELSE 0 END
                WHEN N'PAUSEREASON' THEN CASE WHEN EXISTS (SELECT 1 FROM [Tickets].[TicketPauseSession] WHERE [pauseReasonID_FK] = @recordID AND [pauseEnd] IS NULL AND [ticketPauseSessionActive] = 1) THEN 1 ELSE 0 END
                WHEN N'ARBITRATIONREASON' THEN CASE WHEN EXISTS (SELECT 1 FROM [Tickets].[ArbitrationCase] WHERE [arbitrationReasonID_FK] = @recordID AND [arbitrationStatus] = N'OPEN' AND [arbitrationCaseActive] = 1) THEN 1 ELSE 0 END
                ELSE 0 END;

            IF @inUse = 1
            BEGIN ;THROW 50001, N'لا يمكن حذف السجل لأنه مستخدم حالياً', 1; END

            SET @sql = N'UPDATE ' + @fq + N' SET ' + @activeCol + N' = 0, [entryData] = @entryData, [hostName] = @hostName'
                     + N' WHERE ' + @idCol + N' = @id;';
            EXEC sp_executesql @sql, N'@id INT, @entryData NVARCHAR(20), @hostName NVARCHAR(200)',
                 @id = @recordID, @entryData = @entryData, @hostName = @hostName;
        END
        ELSE IF @Op = N'INSERT'
        BEGIN
            DECLARE @autoCode BIT = CASE WHEN @code IS NULL THEN 1 ELSE 0 END;
            DECLARE @insertCode NVARCHAR(100) = ISNULL(@code, @CodePrefix + N'-NEW');

            SET @sql = N'INSERT INTO ' + @fq + N' (' + @codeCol + N', ' + QUOTENAME(@Prefix + N'Name_A') + N', ' + QUOTENAME(@Prefix + N'Name_E')
                     + N', ' + QUOTENAME(@Prefix + N'Desc') + N', ' + QUOTENAME(@Prefix + N'Desc_A')
                     + CASE WHEN @Entity = N'PRIORITY' THEN N', [priorityLevel]' ELSE N'' END
                     + N', ' + @activeCol + N', [entryDate], [entryData], [hostName])'
                     + N' VALUES (@code, @name_A, @name_E, @desc, @desc'
                     + CASE WHEN @Entity = N'PRIORITY' THEN N', @level' ELSE N'' END
                     + N', 1, GETDATE(), @entryData, @hostName);'
                     + N' SET @newID = SCOPE_IDENTITY();';
            EXEC sp_executesql @sql,
                 N'@code NVARCHAR(100), @name_A NVARCHAR(200), @name_E NVARCHAR(200), @desc NVARCHAR(1000), @level INT, @entryData NVARCHAR(20), @hostName NVARCHAR(200), @newID INT OUTPUT',
                 @code = @insertCode, @name_A = @name_A, @name_E = @name_E, @desc = @desc, @level = @levelInt,
                 @entryData = @entryData, @hostName = @hostName, @newID = @recordID OUTPUT;

            -- Readable automatic code from the new id: CLS-006, PSR-012 ...
            IF @autoCode = 1
            BEGIN
                SET @code = @CodePrefix + N'-' + RIGHT(N'000' + CAST(@recordID AS NVARCHAR(20)),
                            CASE WHEN @recordID > 999 THEN LEN(CAST(@recordID AS NVARCHAR(20))) ELSE 3 END);
                SET @sql = N'UPDATE ' + @fq + N' SET ' + @codeCol + N' = @code WHERE ' + @idCol + N' = @id;';
                EXEC sp_executesql @sql, N'@code NVARCHAR(100), @id INT', @code = @code, @id = @recordID;
            END
        END
        ELSE
        BEGIN
            SET @sql = N'UPDATE ' + @fq + N' SET ' + QUOTENAME(@Prefix + N'Name_A') + N' = @name_A, '
                     + QUOTENAME(@Prefix + N'Name_E') + N' = @name_E, ' + QUOTENAME(@Prefix + N'Desc') + N' = @desc, '
                     + QUOTENAME(@Prefix + N'Desc_A') + N' = @desc'
                     + CASE WHEN @Entity = N'PRIORITY' THEN N', [priorityLevel] = @level' ELSE N'' END
                     + N', [entryData] = @entryData, [hostName] = @hostName WHERE ' + @idCol + N' = @id;';
            EXEC sp_executesql @sql,
                 N'@name_A NVARCHAR(200), @name_E NVARCHAR(200), @desc NVARCHAR(1000), @level INT, @entryData NVARCHAR(20), @hostName NVARCHAR(200), @id INT',
                 @name_A = @name_A, @name_E = @name_E, @desc = @desc, @level = @levelInt,
                 @entryData = @entryData, @hostName = @hostName, @id = @recordID;
        END

        DECLARE @Note NVARCHAR(MAX) = N'{"' + @Prefix + N'ID":"' + CAST(@recordID AS NVARCHAR(20)) + N'","code":"' + ISNULL(@code, ISNULL(@oldCode, N'')) + N'"}';
        INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
        VALUES (@fq, @Action, @recordID, @entryData, @Note);

        SELECT 1 AS IsSuccessful,
               CASE @Op WHEN N'INSERT' THEN N'تمت إضافة ' WHEN N'UPDATE' THEN N'تم تعديل ' ELSE N'تم حذف ' END
               + @EntityName + N' بنجاح' AS Message_;

        IF @tc = 0 COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        ;THROW;
    END CATCH
END
