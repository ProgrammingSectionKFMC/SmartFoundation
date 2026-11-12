
CREATE   PROCEDURE [Maintenance].[MaintenanceApprovalSP]
      @Action NVARCHAR(200)
    , @RequestID NVARCHAR(100) = NULL
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
        , @RequestID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@RequestID)), N''))
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

        IF @RequestID_BIGINT IS NULL
        BEGIN
            ;THROW 50001, N'طلب الصيانة مطلوب', 1;
        END

        IF @Action NOT IN (N'APPROVEMAINTENANCEAPPROVAL', N'REJECTMAINTENANCEAPPROVAL')
        BEGIN
            ;THROW 50001, N'نوع العملية غير معروف', 1;
        END

        IF @Action = N'REJECTMAINTENANCEAPPROVAL' AND NULLIF(LTRIM(RTRIM(ISNULL(@Notes, N''))), N'') IS NULL
        BEGIN
            ;THROW 50001, N'ملاحظة الرفض مطلوبة', 1;
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

        IF ISNULL(@CurrentStatusCode, N'') <> N'WAITING_APPROVAL'
        BEGIN
            ;THROW 50001, N'لا يمكن تنفيذ الموافقة إلا على طلب بانتظار الموافقة', 1;
        END

        SELECT @NewStatusID = [StatusID]
        FROM [Maintenance].[MaintenanceRequestStatus]
        WHERE [StatusCode] = CASE WHEN @Action = N'APPROVEMAINTENANCEAPPROVAL' THEN N'IN_PROGRESS' ELSE N'REJECTED' END
          AND [IsActive] = 1;

        IF @NewStatusID IS NULL
        BEGIN
            ;THROW 50002, N'حالة الطلب المستهدفة غير معرفة', 1;
        END

        SELECT @ActionTypeID = [ActionTypeID]
        FROM [Maintenance].[MaintenanceActionType]
        WHERE [ActionTypeCode] = CASE WHEN @Action = N'APPROVEMAINTENANCEAPPROVAL' THEN N'APPROVE' ELSE N'REJECT' END
          AND [IsActive] = 1;

        IF @ActionTypeID IS NULL
        BEGIN
            ;THROW 50002, N'نوع إجراء الموافقة غير معرف', 1;
        END

        UPDATE [Maintenance].[BuildingMaintenanceRequest]
        SET
              [StatusID] = @NewStatusID
            , [updateUser] = @EntryUser_BIGINT
            , [updateDate] = GETDATE()
            , [entryData] = ISNULL(ISNULL([entryData], N'') + N',' + @entryData, [entryData])
            , [hostName] = ISNULL(ISNULL([hostName], N'') + N',' + @hostName, [hostName])
        WHERE [RequestID] = @RequestID_BIGINT
          AND [IdaraId_FK] = @IdaraID_BIGINT
          AND [IsActive] = 1;

        IF @@ROWCOUNT = 0
        BEGIN
            ;THROW 50002, N'حصل خطأ أثناء تحديث حالة طلب الصيانة', 1;
        END

        UPDATE [Maintenance].[BuildingMaintenanceRequestApproval]
        SET
              [ApprovalStatusID] = @NewStatusID
            , [ApprovalUserID] = @EntryUser_BIGINT
            , [DecisionNote] = @Notes
            , [DecisionDate] = GETDATE()
            , [updateUser] = @EntryUser_BIGINT
            , [updateDate] = GETDATE()
            , [entryData] = ISNULL(ISNULL([entryData], N'') + N',' + @entryData, [entryData])
            , [hostName] = ISNULL(ISNULL([hostName], N'') + N',' + @hostName, [hostName])
        WHERE [RequestID] = @RequestID_BIGINT
          AND ([IdaraId_FK] = @IdaraID_BIGINT OR [IdaraId_FK] IS NULL)
          AND [IsActive] = 1;

        INSERT INTO [Maintenance].[BuildingMaintenanceRequestAction]
        (
              [RequestID]
            , [ActionTypeID]
            , [FromDSDID]
            , [ToDSDID]
            , [FromUserID]
            , [OldStatusID]
            , [NewStatusID]
            , [ActionNote]
            , [ActionDate]
            , [entryUser]
            , [IdaraId_FK]
            , [entryData]
            , [hostName]
        )
        VALUES
        (
              @RequestID_BIGINT
            , @ActionTypeID
            , @CurrentDSDID
            , @CurrentDSDID
            , @EntryUser_BIGINT
            , @CurrentStatusID
            , @NewStatusID
            , @Notes
            , GETDATE()
            , @EntryUser_BIGINT
            , @IdaraID_BIGINT
            , @entryData
            , @hostName
        );

        IF @@ROWCOUNT = 0
        BEGIN
            ;THROW 50002, N'حصل خطأ أثناء تسجيل حركة الموافقة', 1;
        END

        SET @NewID = @RequestID_BIGINT;
        SET @Note = N'{"RequestID":"' + CONVERT(NVARCHAR(30), @RequestID_BIGINT) + N'","Action":"' + @Action + N'"}';

        INSERT INTO [dbo].[AuditLog]
        (
              [TableName]
            , [ActionType]
            , [RecordID]
            , [PerformedBy]
            , [Notes]
        )
        VALUES
        (
              N'[Maintenance].[BuildingMaintenanceRequest]'
            , @Action
            , @NewID
            , @entryData
            , @Note
        );

        SET @Message = CASE
            WHEN @Action = N'APPROVEMAINTENANCEAPPROVAL' THEN N'تمت الموافقة على طلب الصيانة بنجاح'
            ELSE N'تم رفض طلب الصيانة بنجاح'
        END;

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

