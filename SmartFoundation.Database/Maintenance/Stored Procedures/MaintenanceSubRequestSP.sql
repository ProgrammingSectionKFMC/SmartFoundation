
CREATE   PROCEDURE [Maintenance].[MaintenanceSubRequestSP]
      @Action NVARCHAR(200)
    , @ParentRequestID NVARCHAR(100) = NULL
    , @RequestID NVARCHAR(100) = NULL
    , @MaintenanceCategoryID NVARCHAR(100) = NULL
    , @ToDSDID NVARCHAR(100) = NULL
    , @Description_A NVARCHAR(MAX) = NULL
    , @PriorityID NVARCHAR(100) = NULL
    , @Notes NVARCHAR(MAX) = NULL
    , @idaraID_FK NVARCHAR(10) = NULL
    , @entryData NVARCHAR(20) = NULL
    , @hostName NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
          @tc INT = @@TRANCOUNT
        , @ParentRequestID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@ParentRequestID)), N''))
        , @RequestID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@RequestID)), N''))
        , @MaintenanceCategoryID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@MaintenanceCategoryID)), N''))
        , @ToDSDID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@ToDSDID)), N''))
        , @PriorityID_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@PriorityID)), N''))
        , @IdaraID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''))
        , @EntryUser_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@entryData)), N''))
        , @ParentStatusID INT = NULL
        , @ParentStatusCode NVARCHAR(100) = NULL
        , @ParentRootRequestID BIGINT = NULL
        , @ParentRequestLevel INT = NULL
        , @ParentBuildingID BIGINT = NULL
        , @ParentUnitID BIGINT = NULL
        , @ParentResidentID BIGINT = NULL
        , @ParentPriorityID INT = NULL
        , @ParentCurrentDSDID BIGINT = NULL
        , @NewStatusID INT = NULL
        , @WaitingSubRequestStatusID INT = NULL
        , @InProgressStatusID INT = NULL
        , @CancelledStatusID INT = NULL
        , @CompletedStatusID INT = NULL
        , @ActionTypeID INT = NULL
        , @ParentActionTypeID INT = NULL
        , @NewID BIGINT = NULL
        , @RequestNo NVARCHAR(50) = NULL
        , @NextNo INT = NULL
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

        IF @Action = N'CREATEMAINTENANCESUBREQUEST'
        BEGIN
            IF @ParentRequestID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'الطلب الرئيسي مطلوب', 1;
            END

            IF @MaintenanceCategoryID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'نوع الصيانة مطلوب', 1;
            END

            SELECT
                  @ParentStatusID = parent.[StatusID]
                , @ParentStatusCode = status.[StatusCode]
                , @ParentRootRequestID = parent.[RootRequestID]
                , @ParentRequestLevel = parent.[RequestLevel]
                , @ParentBuildingID = parent.[BuildingID]
                , @ParentUnitID = parent.[UnitID]
                , @ParentResidentID = parent.[ResidentID]
                , @ParentPriorityID = parent.[PriorityID]
                , @ParentCurrentDSDID = parent.[CurrentDSDID]
            FROM [Maintenance].[BuildingMaintenanceRequest] AS parent WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN [Maintenance].[MaintenanceRequestStatus] AS status
                ON status.[StatusID] = parent.[StatusID]
            WHERE parent.[RequestID] = @ParentRequestID_BIGINT
              AND parent.[IdaraId_FK] = @IdaraID_BIGINT
              AND parent.[IsActive] = 1;

            IF @ParentStatusID IS NULL
            BEGIN
                ;THROW 50001, N'الطلب الرئيسي غير موجود أو غير نشط', 1;
            END

            IF ISNULL(@ParentStatusCode, N'') IN (N'CLOSED', N'CANCELLED')
            BEGIN
                ;THROW 50001, N'لا يمكن إنشاء طلب فرعي لطلب مغلق أو ملغي', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM [Maintenance].[MaintenanceCategory]
                WHERE [MaintenanceCategoryID] = @MaintenanceCategoryID_BIGINT
                  AND [IdaraId_FK] = @IdaraID_BIGINT
                  AND [IsActive] = 1
            )
            BEGIN
                ;THROW 50001, N'نوع الصيانة غير موجود أو غير فعال', 1;
            END

            IF @ToDSDID_BIGINT IS NULL
            BEGIN
                SELECT TOP 1 @ToDSDID_BIGINT = [ResponsibleDSDID]
                FROM [Maintenance].[MaintenanceCategoryRouting]
                WHERE [MaintenanceCategoryID] = @MaintenanceCategoryID_BIGINT
                  AND [IdaraId_FK] = @IdaraID_BIGINT
                  AND [IsActive] = 1
                  AND [IsDefault] = 1
                ORDER BY [MaintenanceCategoryRoutingID] DESC;
            END

            IF @ToDSDID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'لا يمكن إنشاء طلب فرعي بدون جهة مسؤولة', 1;
            END

            SELECT @NewStatusID = [StatusID]
            FROM [Maintenance].[MaintenanceRequestStatus]
            WHERE [StatusCode] = N'NEW'
              AND [IsActive] = 1;

            SELECT @WaitingSubRequestStatusID = [StatusID]
            FROM [Maintenance].[MaintenanceRequestStatus]
            WHERE [StatusCode] = N'WAITING_SUB_REQUEST'
              AND [IsActive] = 1;

            SELECT @ActionTypeID = [ActionTypeID]
            FROM [Maintenance].[MaintenanceActionType]
            WHERE [ActionTypeCode] = N'CREATE'
              AND [IsActive] = 1;

            SELECT @ParentActionTypeID = [ActionTypeID]
            FROM [Maintenance].[MaintenanceActionType]
            WHERE [ActionTypeCode] = N'CREATE_SUB_REQUEST'
              AND [IsActive] = 1;

            IF @NewStatusID IS NULL OR @WaitingSubRequestStatusID IS NULL OR @ActionTypeID IS NULL OR @ParentActionTypeID IS NULL
            BEGIN
                ;THROW 50002, N'تعريفات الحالات أو الإجراءات الخاصة بالطلب الفرعي غير مكتملة', 1;
            END

            SELECT @NextNo = ISNULL(MAX(TRY_CONVERT(INT, RIGHT([RequestNo], 6))), 0) + 1
            FROM [Maintenance].[BuildingMaintenanceRequest] WITH (UPDLOCK, HOLDLOCK)
            WHERE [IdaraId_FK] = @IdaraID_BIGINT
              AND [RequestNo] LIKE N'MR-' + CONVERT(NVARCHAR(4), YEAR(GETDATE())) + N'-%';

            SET @RequestNo = N'MR-' + CONVERT(NVARCHAR(4), YEAR(GETDATE())) + N'-' + RIGHT(N'000000' + CONVERT(NVARCHAR(20), @NextNo), 6);

            INSERT INTO [Maintenance].[BuildingMaintenanceRequest]
            (
                  [IdaraId_FK]
                , [RequestNo]
                , [ParentRequestID]
                , [RootRequestID]
                , [RequestLevel]
                , [IsSubRequest]
                , [IsBlockingParent]
                , [BuildingID]
                , [UnitID]
                , [ResidentID]
                , [MaintenanceCategoryID]
                , [CurrentDSDID]
                , [OriginalDSDID]
                , [StatusID]
                , [PriorityID]
                , [Description_A]
                , [HasDispute]
                , [EscalationLevel]
                , [IsLockedByDecision]
                , [RequestDate]
                , [entryUser]
                , [entryData]
                , [hostName]
            )
            VALUES
            (
                  @IdaraID_BIGINT
                , @RequestNo
                , @ParentRequestID_BIGINT
                , ISNULL(@ParentRootRequestID, @ParentRequestID_BIGINT)
                , ISNULL(@ParentRequestLevel, 0) + 1
                , 1
                , 1
                , @ParentBuildingID
                , @ParentUnitID
                , @ParentResidentID
                , @MaintenanceCategoryID_BIGINT
                , @ToDSDID_BIGINT
                , @ToDSDID_BIGINT
                , @NewStatusID
                , ISNULL(@PriorityID_INT, @ParentPriorityID)
                , ISNULL(NULLIF(LTRIM(RTRIM(@Description_A)), N''), N'طلب فرعي')
                , 0
                , 0
                , 0
                , GETDATE()
                , @EntryUser_BIGINT
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ أثناء إنشاء الطلب الفرعي', 1;
            END

            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ أثناء إنشاء الطلب الفرعي - Identity', 1;
            END

            UPDATE [Maintenance].[BuildingMaintenanceRequest]
            SET
                  [StatusID] = @WaitingSubRequestStatusID
                , [updateUser] = @EntryUser_BIGINT
                , [updateDate] = GETDATE()
                , [entryData] = ISNULL(ISNULL([entryData], N'') + N',' + @entryData, [entryData])
                , [hostName] = ISNULL(ISNULL([hostName], N'') + N',' + @hostName, [hostName])
            WHERE [RequestID] = @ParentRequestID_BIGINT
              AND [IdaraId_FK] = @IdaraID_BIGINT
              AND [IsActive] = 1;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ أثناء تحديث حالة الطلب الرئيسي', 1;
            END

            INSERT INTO [Maintenance].[BuildingMaintenanceRequestAction]
            ([RequestID], [ActionTypeID], [FromDSDID], [ToDSDID], [FromUserID], [OldStatusID], [NewStatusID], [ActionNote], [ActionDate], [entryUser], [IdaraId_FK], [entryData], [hostName])
            VALUES
            (@ParentRequestID_BIGINT, @ParentActionTypeID, @ParentCurrentDSDID, @ParentCurrentDSDID, @EntryUser_BIGINT, @ParentStatusID, @WaitingSubRequestStatusID, @Description_A, GETDATE(), @EntryUser_BIGINT, @IdaraID_BIGINT, @entryData, @hostName),
            (@NewID, @ActionTypeID, @ToDSDID_BIGINT, @ToDSDID_BIGINT, @EntryUser_BIGINT, NULL, @NewStatusID, @Description_A, GETDATE(), @EntryUser_BIGINT, @IdaraID_BIGINT, @entryData, @hostName);

            SET @Message = N'تم إنشاء الطلب الفرعي بنجاح';
            SET @Note = N'{"ParentRequestID":"' + CONVERT(NVARCHAR(30), @ParentRequestID_BIGINT) + N'","SubRequestID":"' + CONVERT(NVARCHAR(30), @NewID) + N'"}';
        END
        ELSE IF @Action IN (N'COMPLETEMAINTENANCESUBREQUEST', N'RETURNTOPARENTREQUEST', N'CANCELMAINTENANCESUBREQUEST')
        BEGIN
            IF @RequestID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'الطلب الفرعي مطلوب', 1;
            END

            SELECT
                  @ParentRequestID_BIGINT = request.[ParentRequestID]
                , @ParentStatusID = request.[StatusID]
                , @ParentStatusCode = status.[StatusCode]
                , @ParentCurrentDSDID = request.[CurrentDSDID]
            FROM [Maintenance].[BuildingMaintenanceRequest] AS request WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN [Maintenance].[MaintenanceRequestStatus] AS status
                ON status.[StatusID] = request.[StatusID]
            WHERE request.[RequestID] = @RequestID_BIGINT
              AND request.[IdaraId_FK] = @IdaraID_BIGINT
              AND request.[IsSubRequest] = 1
              AND request.[IsActive] = 1;

            IF @ParentRequestID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'الطلب الفرعي غير موجود أو غير نشط', 1;
            END

            IF ISNULL(@ParentStatusCode, N'') IN (N'CLOSED', N'CANCELLED')
            BEGIN
                ;THROW 50001, N'لا يمكن تنفيذ الإجراء على طلب فرعي مغلق أو ملغي', 1;
            END

            SELECT @CompletedStatusID = [StatusID]
            FROM [Maintenance].[MaintenanceRequestStatus]
            WHERE [StatusCode] = N'COMPLETED'
              AND [IsActive] = 1;

            SELECT @CancelledStatusID = [StatusID]
            FROM [Maintenance].[MaintenanceRequestStatus]
            WHERE [StatusCode] = N'CANCELLED'
              AND [IsActive] = 1;

            SELECT @InProgressStatusID = [StatusID]
            FROM [Maintenance].[MaintenanceRequestStatus]
            WHERE [StatusCode] = N'IN_PROGRESS'
              AND [IsActive] = 1;

            SELECT @ActionTypeID = [ActionTypeID]
            FROM [Maintenance].[MaintenanceActionType]
            WHERE [ActionTypeCode] = CASE WHEN @Action = N'CANCELMAINTENANCESUBREQUEST' THEN N'CANCEL' ELSE N'COMPLETE_WORK' END
              AND [IsActive] = 1;

            SELECT @ParentActionTypeID = [ActionTypeID]
            FROM [Maintenance].[MaintenanceActionType]
            WHERE [ActionTypeCode] = N'RETURN_TO_PARENT'
              AND [IsActive] = 1;

            IF @CompletedStatusID IS NULL OR @CancelledStatusID IS NULL OR @InProgressStatusID IS NULL OR @ActionTypeID IS NULL
            BEGIN
                ;THROW 50002, N'تعريفات الحالات أو الإجراءات الخاصة بالطلب الفرعي غير مكتملة', 1;
            END

            SET @NewStatusID = CASE WHEN @Action = N'CANCELMAINTENANCESUBREQUEST' THEN @CancelledStatusID ELSE @CompletedStatusID END;

            UPDATE [Maintenance].[BuildingMaintenanceRequest]
            SET
                  [StatusID] = @NewStatusID
                , [ClosedDate] = CASE WHEN @Action = N'CANCELMAINTENANCESUBREQUEST' THEN [ClosedDate] ELSE ISNULL([ClosedDate], GETDATE()) END
                , [updateUser] = @EntryUser_BIGINT
                , [updateDate] = GETDATE()
                , [entryData] = ISNULL(ISNULL([entryData], N'') + N',' + @entryData, [entryData])
                , [hostName] = ISNULL(ISNULL([hostName], N'') + N',' + @hostName, [hostName])
            WHERE [RequestID] = @RequestID_BIGINT
              AND [IdaraId_FK] = @IdaraID_BIGINT
              AND [IsActive] = 1;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ أثناء تحديث الطلب الفرعي', 1;
            END

            INSERT INTO [Maintenance].[BuildingMaintenanceRequestAction]
            ([RequestID], [ActionTypeID], [FromDSDID], [ToDSDID], [FromUserID], [OldStatusID], [NewStatusID], [ActionNote], [ActionDate], [entryUser], [IdaraId_FK], [entryData], [hostName])
            VALUES
            (@RequestID_BIGINT, @ActionTypeID, @ParentCurrentDSDID, @ParentCurrentDSDID, @EntryUser_BIGINT, @ParentStatusID, @NewStatusID, @Notes, GETDATE(), @EntryUser_BIGINT, @IdaraID_BIGINT, @entryData, @hostName);

            IF @Action <> N'CANCELMAINTENANCESUBREQUEST'
               AND NOT EXISTS
               (
                   SELECT 1
                   FROM [Maintenance].[BuildingMaintenanceRequest] AS child
                   INNER JOIN [Maintenance].[MaintenanceRequestStatus] AS childStatus
                       ON childStatus.[StatusID] = child.[StatusID]
                   WHERE child.[ParentRequestID] = @ParentRequestID_BIGINT
                     AND child.[IdaraId_FK] = @IdaraID_BIGINT
                     AND child.[IsSubRequest] = 1
                     AND child.[IsBlockingParent] = 1
                     AND child.[IsActive] = 1
                     AND ISNULL(childStatus.[StatusCode], N'') NOT IN (N'COMPLETED', N'CLOSED', N'CANCELLED')
               )
            BEGIN
                UPDATE [Maintenance].[BuildingMaintenanceRequest]
                SET
                      [StatusID] = @InProgressStatusID
                    , [updateUser] = @EntryUser_BIGINT
                    , [updateDate] = GETDATE()
                    , [entryData] = ISNULL(ISNULL([entryData], N'') + N',' + @entryData, [entryData])
                    , [hostName] = ISNULL(ISNULL([hostName], N'') + N',' + @hostName, [hostName])
                WHERE [RequestID] = @ParentRequestID_BIGINT
                  AND [IdaraId_FK] = @IdaraID_BIGINT
                  AND [IsActive] = 1;

                INSERT INTO [Maintenance].[BuildingMaintenanceRequestAction]
                ([RequestID], [ActionTypeID], [FromUserID], [OldStatusID], [NewStatusID], [ActionNote], [ActionDate], [entryUser], [IdaraId_FK], [entryData], [hostName])
                VALUES
                (@ParentRequestID_BIGINT, @ParentActionTypeID, @EntryUser_BIGINT, NULL, @InProgressStatusID, @Notes, GETDATE(), @EntryUser_BIGINT, @IdaraID_BIGINT, @entryData, @hostName);
            END

            SET @NewID = @RequestID_BIGINT;
            SET @Message = CASE WHEN @Action = N'CANCELMAINTENANCESUBREQUEST' THEN N'تم إلغاء الطلب الفرعي بنجاح' ELSE N'تم إنهاء الطلب الفرعي بنجاح' END;
            SET @Note = N'{"SubRequestID":"' + CONVERT(NVARCHAR(30), @RequestID_BIGINT) + N'","Action":"' + @Action + N'"}';
        END
        ELSE
        BEGIN
            ;THROW 50001, N'نوع العملية غير معروف', 1;
        END

        INSERT INTO [dbo].[AuditLog] ([TableName], [ActionType], [RecordID], [PerformedBy], [Notes])
        VALUES (N'[Maintenance].[BuildingMaintenanceRequest]', @Action, ISNULL(@NewID, 0), @entryData, @Note);

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

