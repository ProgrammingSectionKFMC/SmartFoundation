
CREATE   PROCEDURE [Maintenance].[MaintenanceDisputeSP]
      @Action NVARCHAR(200)
    , @RequestID NVARCHAR(100) = NULL
    , @DisputeID NVARCHAR(100) = NULL
    , @AgainstDSDID NVARCHAR(100) = NULL
    , @DecisionDSDID NVARCHAR(100) = NULL
    , @Reason NVARCHAR(MAX) = NULL
    , @DecisionNote NVARCHAR(MAX) = NULL
    , @idaraID_FK NVARCHAR(10) = NULL
    , @entryData NVARCHAR(20) = NULL
    , @hostName NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
          @tc INT = @@TRANCOUNT
        , @RequestID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@RequestID)), N''))
        , @DisputeID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@DisputeID)), N''))
        , @AgainstDSDID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@AgainstDSDID)), N''))
        , @DecisionDSDID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@DecisionDSDID)), N''))
        , @IdaraID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''))
        , @EntryUser_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@entryData)), N''))
        , @CurrentStatusID INT = NULL
        , @CurrentStatusCode NVARCHAR(100) = NULL
        , @NewStatusID INT = NULL
        , @ActionTypeID INT = NULL
        , @CurrentDSDID BIGINT = NULL
        , @NewID BIGINT = NULL
        , @Note NVARCHAR(MAX) = NULL
        , @Message NVARCHAR(400) = NULL;

    SET @Action = UPPER(LTRIM(RTRIM(ISNULL(@Action, N''))));

    BEGIN TRY
        IF @tc = 0
            BEGIN TRAN;

        IF @IdaraID_BIGINT IS NULL
        BEGIN
            ;THROW 50001, N'الإدارة مطلوبة', 1;
        END

        IF @Action = N'RAISEMAINTENANCEDISPUTE'
        BEGIN
            IF @RequestID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'طلب الصيانة مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(ISNULL(@Reason, N''))), N'') IS NULL
            BEGIN
                ;THROW 50001, N'سبب النزاع مطلوب', 1;
            END

            SELECT
                  @CurrentStatusID = request.[StatusID]
                , @CurrentStatusCode = status.[StatusCode]
                , @CurrentDSDID = request.[CurrentDSDID]
            FROM [Maintenance].[BuildingMaintenanceRequest] AS request WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN [Maintenance].[MaintenanceRequestStatus] AS status
                ON status.[StatusID] = request.[StatusID]
            WHERE request.[RequestID] = @RequestID_BIGINT
              AND request.[IdaraId_FK] = @IdaraID_BIGINT
              AND request.[IsActive] = 1;

            IF @CurrentStatusID IS NULL
            BEGIN
                ;THROW 50001, N'طلب الصيانة غير موجود أو غير نشط', 1;
            END

            IF ISNULL(@CurrentStatusCode, N'') IN (N'CLOSED', N'CANCELLED')
            BEGIN
                ;THROW 50001, N'لا يمكن تسجيل نزاع على طلب مغلق أو ملغي', 1;
            END

            IF EXISTS
            (
                SELECT 1
                FROM [Maintenance].[BuildingMaintenanceRequestDispute]
                WHERE [RequestID] = @RequestID_BIGINT
                  AND [IsActive] = 1
                  AND [DecisionDate] IS NULL
            )
            BEGIN
                ;THROW 50001, N'يوجد نزاع نشط مفتوح لنفس الطلب', 1;
            END

            SELECT @NewStatusID = [StatusID]
            FROM [Maintenance].[MaintenanceRequestStatus]
            WHERE [StatusCode] = N'DISPUTE'
              AND [IsActive] = 1;

            SELECT @ActionTypeID = [ActionTypeID]
            FROM [Maintenance].[MaintenanceActionType]
            WHERE [ActionTypeCode] = N'RAISE_DISPUTE'
              AND [IsActive] = 1;

            IF @NewStatusID IS NULL OR @ActionTypeID IS NULL
            BEGIN
                ;THROW 50002, N'تعريفات النزاع غير مكتملة', 1;
            END

            INSERT INTO [Maintenance].[BuildingMaintenanceRequestDispute]
            (
                  [RequestID]
                , [RaisedByDSDID]
                , [AgainstDSDID]
                , [RaisedByUserID]
                , [Reason]
                , [DisputeStatusID]
                , [entryUser]
                , [IdaraId_FK]
                , [entryData]
                , [hostName]
            )
            VALUES
            (
                  @RequestID_BIGINT
                , @CurrentDSDID
                , @AgainstDSDID_BIGINT
                , @EntryUser_BIGINT
                , @Reason
                , @NewStatusID
                , @EntryUser_BIGINT
                , @IdaraID_BIGINT
                , @entryData
                , @hostName
            );

            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ أثناء تسجيل النزاع - Identity', 1;
            END

            UPDATE [Maintenance].[BuildingMaintenanceRequest]
            SET
                  [HasDispute] = 1
                , [DisputeStatusID] = @NewStatusID
                , [StatusID] = @NewStatusID
                , [updateUser] = @EntryUser_BIGINT
                , [updateDate] = GETDATE()
                , [entryData] = ISNULL(ISNULL([entryData], N'') + N',' + @entryData, [entryData])
                , [hostName] = ISNULL(ISNULL([hostName], N'') + N',' + @hostName, [hostName])
            WHERE [RequestID] = @RequestID_BIGINT
              AND [IdaraId_FK] = @IdaraID_BIGINT
              AND [IsActive] = 1;

            INSERT INTO [Maintenance].[BuildingMaintenanceRequestAction]
            ([RequestID], [ActionTypeID], [FromDSDID], [ToDSDID], [FromUserID], [OldStatusID], [NewStatusID], [ActionNote], [ActionDate], [entryUser], [IdaraId_FK], [entryData], [hostName])
            VALUES
            (@RequestID_BIGINT, @ActionTypeID, @CurrentDSDID, @AgainstDSDID_BIGINT, @EntryUser_BIGINT, @CurrentStatusID, @NewStatusID, @Reason, GETDATE(), @EntryUser_BIGINT, @IdaraID_BIGINT, @entryData, @hostName);

            SET @Message = N'تم تسجيل نزاع الاختصاص بنجاح';
            SET @Note = N'{"RequestID":"' + CONVERT(NVARCHAR(30), @RequestID_BIGINT) + N'","DisputeID":"' + CONVERT(NVARCHAR(30), @NewID) + N'"}';
        END
        ELSE IF @Action = N'DECIDEMAINTENANCEDISPUTE'
        BEGIN
            IF @DisputeID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'النزاع مطلوب', 1;
            END

            IF @DecisionDSDID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'جهة القرار مطلوبة', 1;
            END

            IF NULLIF(LTRIM(RTRIM(ISNULL(@DecisionNote, N''))), N'') IS NULL
            BEGIN
                ;THROW 50001, N'قرار التحكيم مطلوب', 1;
            END

            SELECT
                  @RequestID_BIGINT = dispute.[RequestID]
                , @CurrentStatusID = request.[StatusID]
                , @CurrentDSDID = request.[CurrentDSDID]
            FROM [Maintenance].[BuildingMaintenanceRequestDispute] AS dispute WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN [Maintenance].[BuildingMaintenanceRequest] AS request
                ON request.[RequestID] = dispute.[RequestID]
            WHERE dispute.[DisputeID] = @DisputeID_BIGINT
              AND (dispute.[IdaraId_FK] = @IdaraID_BIGINT OR dispute.[IdaraId_FK] IS NULL)
              AND dispute.[IsActive] = 1
              AND dispute.[DecisionDate] IS NULL;

            IF @RequestID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'النزاع غير موجود أو غير نشط', 1;
            END

            SELECT @NewStatusID = [StatusID]
            FROM [Maintenance].[MaintenanceRequestStatus]
            WHERE [StatusCode] = N'UNDER_INSPECTION'
              AND [IsActive] = 1;

            SELECT @ActionTypeID = [ActionTypeID]
            FROM [Maintenance].[MaintenanceActionType]
            WHERE [ActionTypeCode] = N'ARBITRATION_DECISION'
              AND [IsActive] = 1;

            IF @NewStatusID IS NULL OR @ActionTypeID IS NULL
            BEGIN
                ;THROW 50002, N'تعريفات قرار التحكيم غير مكتملة', 1;
            END

            UPDATE [Maintenance].[BuildingMaintenanceRequestDispute]
            SET
                  [ArbitrationDSDID] = @DecisionDSDID_BIGINT
                , [DecisionByUserID] = @EntryUser_BIGINT
                , [DecisionNote] = @DecisionNote
                , [IsBindingDecision] = 1
                , [DecisionDate] = GETDATE()
                , [DisputeStatusID] = @NewStatusID
                , [updateUser] = @EntryUser_BIGINT
                , [updateDate] = GETDATE()
                , [entryData] = ISNULL(ISNULL([entryData], N'') + N',' + @entryData, [entryData])
                , [hostName] = ISNULL(ISNULL([hostName], N'') + N',' + @hostName, [hostName])
            WHERE [DisputeID] = @DisputeID_BIGINT;

            UPDATE [Maintenance].[BuildingMaintenanceRequest]
            SET
                  [CurrentDSDID] = @DecisionDSDID_BIGINT
                , [HasDispute] = 0
                , [StatusID] = @NewStatusID
                , [IsLockedByDecision] = 1
                , [EscalationLevel] = ISNULL([EscalationLevel], 0) + 1
                , [updateUser] = @EntryUser_BIGINT
                , [updateDate] = GETDATE()
                , [entryData] = ISNULL(ISNULL([entryData], N'') + N',' + @entryData, [entryData])
                , [hostName] = ISNULL(ISNULL([hostName], N'') + N',' + @hostName, [hostName])
            WHERE [RequestID] = @RequestID_BIGINT
              AND [IdaraId_FK] = @IdaraID_BIGINT
              AND [IsActive] = 1;

            INSERT INTO [Maintenance].[BuildingMaintenanceRequestAction]
            ([RequestID], [ActionTypeID], [FromDSDID], [ToDSDID], [FromUserID], [OldStatusID], [NewStatusID], [ActionNote], [ActionDate], [entryUser], [IdaraId_FK], [entryData], [hostName])
            VALUES
            (@RequestID_BIGINT, @ActionTypeID, @CurrentDSDID, @DecisionDSDID_BIGINT, @EntryUser_BIGINT, @CurrentStatusID, @NewStatusID, @DecisionNote, GETDATE(), @EntryUser_BIGINT, @IdaraID_BIGINT, @entryData, @hostName);

            SET @NewID = @DisputeID_BIGINT;
            SET @Message = N'تم تسجيل قرار التحكيم بنجاح';
            SET @Note = N'{"DisputeID":"' + CONVERT(NVARCHAR(30), @DisputeID_BIGINT) + N'","RequestID":"' + CONVERT(NVARCHAR(30), @RequestID_BIGINT) + N'"}';
        END
        ELSE IF @Action = N'CLOSEMAINTENANCEDISPUTE'
        BEGIN
            IF @DisputeID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'النزاع مطلوب', 1;
            END

            UPDATE [Maintenance].[BuildingMaintenanceRequestDispute]
            SET
                  [IsActive] = 0
                , [DecisionDate] = ISNULL([DecisionDate], GETDATE())
                , [updateUser] = @EntryUser_BIGINT
                , [updateDate] = GETDATE()
                , [entryData] = ISNULL(ISNULL([entryData], N'') + N',' + @entryData, [entryData])
                , [hostName] = ISNULL(ISNULL([hostName], N'') + N',' + @hostName, [hostName])
            WHERE [DisputeID] = @DisputeID_BIGINT
              AND ([IdaraId_FK] = @IdaraID_BIGINT OR [IdaraId_FK] IS NULL)
              AND [IsActive] = 1;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50001, N'النزاع غير موجود أو مغلق مسبقاً', 1;
            END

            SET @NewID = @DisputeID_BIGINT;
            SET @Message = N'تم إغلاق النزاع بنجاح';
            SET @Note = N'{"DisputeID":"' + CONVERT(NVARCHAR(30), @DisputeID_BIGINT) + N'"}';
        END
        ELSE
        BEGIN
            ;THROW 50001, N'نوع العملية غير معروف', 1;
        END

        INSERT INTO [dbo].[AuditLog] ([TableName], [ActionType], [RecordID], [PerformedBy], [Notes])
        VALUES (N'[Maintenance].[BuildingMaintenanceRequestDispute]', @Action, ISNULL(@NewID, 0), @entryData, @Note);

        IF @tc = 0
            COMMIT;

        SELECT 1 AS [IsSuccessful], @Message AS [Message_];
        RETURN;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;

        ;THROW;
    END CATCH
END;

GO

