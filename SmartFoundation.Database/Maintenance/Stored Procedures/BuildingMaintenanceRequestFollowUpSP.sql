CREATE PROCEDURE [Maintenance].[BuildingMaintenanceRequestFollowUpSP]
      @Action NVARCHAR(200)
    , @RequestID NVARCHAR(100) = NULL
    , @AssignedToUserID NVARCHAR(100) = NULL
    , @AssignmentID NVARCHAR(100) = NULL
    , @ReportText NVARCHAR(MAX) = NULL
    , @ReasonID NVARCHAR(100) = NULL
    , @NeedsApproval NVARCHAR(20) = NULL
    , @NeedsSubRequest NVARCHAR(20) = NULL
    , @Notes NVARCHAR(MAX) = NULL
    , @idaraID_FK NVARCHAR(10) = NULL
    , @entryData NVARCHAR(20) = NULL
    , @hostName NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    ----------------------------------------------------------------
    --                    BuildingMaintenanceRequestFollowUp
    ----------------------------------------------------------------

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE
          @NewID BIGINT = NULL
        , @Note NVARCHAR(MAX) = NULL
        , @IdaraID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''))
        , @RequestID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@RequestID)), N''))
        , @AssignedToUserID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@AssignedToUserID)), N''))
        , @AssignmentID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@AssignmentID)), N''))
        , @ReasonID_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@ReasonID)), N''))
        , @NeedsApproval_BIT BIT = CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(@NeedsApproval, N'')))) IN (N'1', N'TRUE', N'YES', N'ON') THEN 1 ELSE 0 END
        , @NeedsSubRequest_BIT BIT = CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(@NeedsSubRequest, N'')))) IN (N'1', N'TRUE', N'YES', N'ON') THEN 1 ELSE 0 END
        , @EntryUser_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@entryData)), N''))
        , @CurrentStatusID INT = NULL
        , @CurrentStatusCode NVARCHAR(100) = NULL
        , @NewStatusID INT = NULL
        , @ActionTypeID INT = NULL
        , @RequestApprovalActionTypeID INT = NULL
        , @CurrentDSDID BIGINT = NULL
        , @LastActionTypeCode NVARCHAR(100) = NULL
        , @LastInspectionActionID BIGINT = NULL
        , @LastInspectionActionDate DATETIME = NULL
        , @SuccessMessage NVARCHAR(4000) = N'تم تنفيذ الإجراء بنجاح'
        , @ReasonCode NVARCHAR(100) = NULL;

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
            ;THROW 50001, N'رقم الطلب مطلوب', 1;
        END

        SELECT
              @CurrentStatusID = request.StatusID
            , @CurrentStatusCode = status.StatusCode
            , @CurrentDSDID = request.CurrentDSDID
        FROM Maintenance.BuildingMaintenanceRequest AS request
        INNER JOIN Maintenance.MaintenanceRequestStatus AS status
            ON status.StatusID = request.StatusID
        WHERE request.RequestID = @RequestID_BIGINT
          AND request.IdaraId_FK = @IdaraID_BIGINT
          AND request.IsActive = 1;

        IF @CurrentStatusID IS NULL
        BEGIN
            ;THROW 50001, N'طلب الصيانة غير موجود', 1;
        END

        IF ISNULL(@CurrentStatusCode, N'') IN (N'CLOSED', N'CANCELLED')
        BEGIN
            ;THROW 50001, N'لا يمكن تنفيذ إجراء على طلب مغلق أو ملغي', 1;
        END

        SELECT TOP 1
              @LastActionTypeCode = actionType.ActionTypeCode
        FROM Maintenance.BuildingMaintenanceRequestAction AS action
        INNER JOIN Maintenance.MaintenanceActionType AS actionType
            ON actionType.ActionTypeID = action.ActionTypeID
        WHERE action.RequestID = @RequestID_BIGINT
          AND action.IdaraId_FK = @IdaraID_BIGINT
          AND action.IsActive = 1
        ORDER BY action.ActionDate DESC, action.ActionID DESC;

        SELECT TOP 1
              @LastInspectionActionID = action.ActionID
            , @LastInspectionActionDate = action.ActionDate
        FROM Maintenance.BuildingMaintenanceRequestAction AS action
        INNER JOIN Maintenance.MaintenanceActionType AS actionType
            ON actionType.ActionTypeID = action.ActionTypeID
        WHERE action.RequestID = @RequestID_BIGINT
          AND action.IdaraId_FK = @IdaraID_BIGINT
          AND action.IsActive = 1
          AND actionType.ActionTypeCode = N'INSPECTION_REPORT'
        ORDER BY action.ActionDate DESC, action.ActionID DESC;

        SELECT TOP 1 @ActionTypeID = ActionTypeID
        FROM Maintenance.MaintenanceActionType
        WHERE ActionTypeCode =
            CASE @Action
                WHEN N'ASSIGNMAINTENANCETECHNICIAN' THEN N'ASSIGN_TECHNICIAN'
                WHEN N'ADDINSPECTIONREPORT' THEN N'INSPECTION_REPORT'
                WHEN N'STARTMAINTENANCEWORK' THEN N'START_WORK'
                WHEN N'COMPLETEMAINTENANCEWORK' THEN N'COMPLETE_WORK'
                WHEN N'CLOSEMAINTENANCEREQUEST' THEN N'CLOSE'
                ELSE N''
            END
          AND IsActive = 1
          AND (IdaraId_FK IS NULL OR IdaraId_FK = @IdaraID_BIGINT)
        ORDER BY CASE WHEN IdaraId_FK = @IdaraID_BIGINT THEN 0 ELSE 1 END, ActionTypeID;

        IF @ActionTypeID IS NULL
        BEGIN
            ;THROW 50001, N'نوع الإجراء غير معرف', 1;
        END

        IF @Action = N'ASSIGNMAINTENANCETECHNICIAN'
        BEGIN
            IF ISNULL(@CurrentStatusCode, N'') = N'COMPLETED'
            BEGIN
                ;THROW 50001, N'لا يمكن تنفيذ إجراء على طلب مغلق أو ملغي', 1;
            END

            IF @AssignedToUserID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'الفني مطلوب', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.V_GetFullSystemUsersDetails
                WHERE usersID = @AssignedToUserID_BIGINT
                  AND userActive = 1
                  AND (IdaraID IS NULL OR IdaraID = @IdaraID_BIGINT)
            )
            BEGIN
                ;THROW 50001, N'الفني غير موجود أو غير فعال', 1;
            END

            IF EXISTS
            (
                SELECT 1
                FROM Maintenance.BuildingMaintenanceRequestAssignment
                WHERE RequestID = @RequestID_BIGINT
                  AND AssignedToUserID = @AssignedToUserID_BIGINT
                  AND IdaraId_FK = @IdaraID_BIGINT
                  AND IsActive = 1
            )
            BEGIN
                ;THROW 50001, N'تم إسناد هذا الفني مسبقاً لنفس الطلب', 1;
            END

            IF ISNULL(@CurrentStatusCode, N'') = N'NEW'
            BEGIN
                SELECT TOP 1 @NewStatusID = StatusID
                FROM Maintenance.MaintenanceRequestStatus
                WHERE StatusCode = N'UNDER_INSPECTION'
                  AND IsActive = 1
                  AND (IdaraId_FK IS NULL OR IdaraId_FK = @IdaraID_BIGINT)
                ORDER BY CASE WHEN IdaraId_FK = @IdaraID_BIGINT THEN 0 ELSE 1 END, StatusID;

                IF @NewStatusID IS NULL
                BEGIN
                    ;THROW 50002, N'حالة UNDER_INSPECTION غير معرفة', 1;
                END
            END
            ELSE
            BEGIN
                SET @NewStatusID = @CurrentStatusID;
            END

            INSERT INTO Maintenance.BuildingMaintenanceRequestAssignment
            (
                  RequestID
                , AssignedToUserID
                , AssignedByUserID
                , AssignedDSDID
                , AssignedDate
                , NeedsApproval
                , NeedsSubRequest
                , entryUser
                , IdaraId_FK
                , entryData
                , hostName
            )
            VALUES
            (
                  @RequestID_BIGINT
                , @AssignedToUserID_BIGINT
                , @EntryUser_BIGINT
                , @CurrentDSDID
                , GETDATE()
                , 0
                , 0
                , @EntryUser_BIGINT
                , @IdaraID_BIGINT
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ أثناء إسناد الفني', 1;
            END

            SET @NewID = SCOPE_IDENTITY();

            IF ISNULL(@CurrentStatusCode, N'') = N'NEW'
            BEGIN
                UPDATE Maintenance.BuildingMaintenanceRequest
                SET
                      StatusID = @NewStatusID
                    , updateUser = @EntryUser_BIGINT
                    , updateDate = GETDATE()
                    , entryData = ISNULL(ISNULL(entryData, N'') + N',' + @entryData, entryData)
                    , hostName = ISNULL(ISNULL(@hostName, N'') + N',' + @hostName, hostName)
                WHERE RequestID = @RequestID_BIGINT
                  AND IdaraId_FK = @IdaraID_BIGINT
                  AND IsActive = 1;

                IF @@ROWCOUNT = 0
                BEGIN
                    ;THROW 50002, N'حصل خطأ أثناء تحديث حالة الطلب', 1;
                END
            END

            INSERT INTO Maintenance.BuildingMaintenanceRequestAction
            (
                  RequestID
                , ActionTypeID
                , FromDSDID
                , ToDSDID
                , FromUserID
                , ToUserID
                , OldStatusID
                , NewStatusID
                , ActionNote
                , ActionDate
                , entryUser
                , IdaraId_FK
                , entryData
                , hostName
            )
            VALUES
            (
                  @RequestID_BIGINT
                , @ActionTypeID
                , @CurrentDSDID
                , @CurrentDSDID
                , @EntryUser_BIGINT
                , @AssignedToUserID_BIGINT
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
                ;THROW 50002, N'حصل خطأ أثناء تسجيل حركة الإسناد', 1;
            END

            SET @Note = N'{"RequestID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @RequestID_BIGINT), N'') + N'","AssignmentID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), N'') + N'"}';
            SET @SuccessMessage = N'تم إسناد الفني للطلب بنجاح';
        END

        ELSE IF @Action = N'ADDINSPECTIONREPORT'
        BEGIN
            IF ISNULL(@CurrentStatusCode, N'') <> N'UNDER_INSPECTION'
            BEGIN
                ;THROW 50001, N'لا يمكن تسجيل تقرير المعاينة قبل إسناد فني للطلب', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM Maintenance.BuildingMaintenanceRequestAssignment
                WHERE RequestID = @RequestID_BIGINT
                  AND IdaraId_FK = @IdaraID_BIGINT
                  AND IsActive = 1
            )
            BEGIN
                ;THROW 50001, N'لا يمكن تسجيل تقرير المعاينة قبل إسناد فني للطلب', 1;
            END

            IF @ReasonID_INT IS NULL
            BEGIN
                ;THROW 50001, N'سبب تقرير المعاينة مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@ReportText)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'تقرير المعاينة مطلوب', 1;
            END

            SELECT TOP 1 @ReasonCode = ReasonCode
            FROM Maintenance.MaintenanceActionReason
            WHERE ReasonID = @ReasonID_INT
              AND IsActive = 1
              AND (IdaraId_FK IS NULL OR IdaraId_FK = @IdaraID_BIGINT)
            ORDER BY CASE WHEN IdaraId_FK = @IdaraID_BIGINT THEN 0 ELSE 1 END, ReasonID;

            IF @ReasonCode IS NULL
            BEGIN
                ;THROW 50001, N'سبب تقرير المعاينة غير موجود أو غير فعال', 1;
            END
            SET @NeedsApproval_BIT = CASE WHEN @ReasonCode = N'NEEDS_APPROVAL' THEN 1 ELSE 0 END;
            SET @NeedsSubRequest_BIT = CASE WHEN @ReasonCode = N'NEEDS_SUB_REQUEST' THEN 1 ELSE 0 END;
            SET @NewStatusID = @CurrentStatusID;

            IF @NeedsApproval_BIT = 1
            BEGIN
                SELECT @NewStatusID = StatusID
                FROM Maintenance.MaintenanceRequestStatus
                WHERE StatusCode = N'WAITING_APPROVAL'
                  AND IsActive = 1;

                IF @NewStatusID IS NULL
                BEGIN
                    ;THROW 50002, N'حالة WAITING_APPROVAL غير معرفة في جدول الحالات', 1;
                END

                SELECT @RequestApprovalActionTypeID = ActionTypeID
                FROM Maintenance.MaintenanceActionType
                WHERE ActionTypeCode = N'REQUEST_APPROVAL'
                  AND IsActive = 1;

                IF @RequestApprovalActionTypeID IS NULL
                BEGIN
                    ;THROW 50002, N'نوع الإجراء REQUEST_APPROVAL غير معرف في جدول أنواع الإجراءات', 1;
                END
            END
            ELSE IF @NeedsSubRequest_BIT = 1
            BEGIN
                SELECT @NewStatusID = StatusID
                FROM Maintenance.MaintenanceRequestStatus
                WHERE StatusCode = N'WAITING_SUB_REQUEST'
                  AND IsActive = 1;

                IF @NewStatusID IS NULL
                BEGIN
                    ;THROW 50002, N'حالة WAITING_SUB_REQUEST غير معرفة في جدول الحالات', 1;
                END
            END

            UPDATE Maintenance.BuildingMaintenanceRequestAssignment
            SET
                  InspectionDate = GETDATE()
                , ReportText = @ReportText
                , NeedsApproval = @NeedsApproval_BIT
                , NeedsSubRequest = @NeedsSubRequest_BIT
                , updateUser = @EntryUser_BIGINT
                , updateDate = GETDATE()
                , entryData = ISNULL(ISNULL(entryData, N'') + N',' + @entryData, entryData)
                , hostName = ISNULL(ISNULL(@hostName, N'') + N',' + @hostName, hostName)
            WHERE RequestID = @RequestID_BIGINT
              AND IdaraId_FK = @IdaraID_BIGINT
              AND IsActive = 1;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ أثناء تحديث تقرير المعاينة', 1;
            END

            UPDATE Maintenance.BuildingMaintenanceRequest
            SET
                  StatusID = @NewStatusID
                , updateUser = @EntryUser_BIGINT
                , updateDate = GETDATE()
                , entryData = ISNULL(ISNULL(entryData, N'') + N',' + @entryData, entryData)
                , hostName = ISNULL(ISNULL(@hostName, N'') + N',' + @hostName, hostName)
            WHERE RequestID = @RequestID_BIGINT
              AND IdaraId_FK = @IdaraID_BIGINT
              AND IsActive = 1;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ أثناء تحديث حالة الطلب', 1;
            END

            INSERT INTO Maintenance.BuildingMaintenanceRequestAction
            (
                  RequestID
                , ActionTypeID
                , ReasonID
                , FromDSDID
                , ToDSDID
                , FromUserID
                , OldStatusID
                , NewStatusID
                , ActionNote
                , ActionDate
                , entryUser
                , IdaraId_FK
                , entryData
                , hostName
            )
            VALUES
            (
                  @RequestID_BIGINT
                , @ActionTypeID
                , @ReasonID_INT
                , @CurrentDSDID
                , @CurrentDSDID
                , @EntryUser_BIGINT
                , @CurrentStatusID
                , @NewStatusID
                , @ReportText
                , GETDATE()
                , @EntryUser_BIGINT
                , @IdaraID_BIGINT
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ أثناء تسجيل حركة المعاينة', 1;
            END

            IF @NeedsApproval_BIT = 1
            BEGIN
                INSERT INTO Maintenance.BuildingMaintenanceRequestAction
                (
                      RequestID
                    , ActionTypeID
                    , ReasonID
                    , FromDSDID
                    , ToDSDID
                    , FromUserID
                    , OldStatusID
                    , NewStatusID
                    , ActionNote
                    , ActionDate
                    , entryUser
                    , IdaraId_FK
                    , entryData
                    , hostName
                )
                VALUES
                (
                      @RequestID_BIGINT
                    , @RequestApprovalActionTypeID
                    , @ReasonID_INT
                    , @CurrentDSDID
                    , @CurrentDSDID
                    , @EntryUser_BIGINT
                    , @CurrentStatusID
                    , @NewStatusID
                    , @ReportText
                    , GETDATE()
                    , @EntryUser_BIGINT
                    , @IdaraID_BIGINT
                    , @entryData
                    , @hostName
                );

                IF NOT EXISTS
                (
                    SELECT 1
                    FROM Maintenance.BuildingMaintenanceRequestApproval
                    WHERE RequestID = @RequestID_BIGINT
                      AND IsActive = 1
                )
                BEGIN
                    INSERT INTO Maintenance.BuildingMaintenanceRequestApproval
                    (
                          RequestID
                        , RequestedByUserID
                        , RequestedDate
                        , ApprovalLevel
                        , ApprovalDSDID
                        , Reason
                        , entryUser
                        , IdaraId_FK
                        , entryData
                        , hostName
                    )
                    VALUES
                    (
                          @RequestID_BIGINT
                        , @EntryUser_BIGINT
                        , GETDATE()
                        , 1
                        , @CurrentDSDID
                        , @ReportText
                        , @EntryUser_BIGINT
                        , @IdaraID_BIGINT
                        , @entryData
                        , @hostName
                    );
                END
            END
            SET @NewID = @RequestID_BIGINT;
            SET @Note = N'{"RequestID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @RequestID_BIGINT), N'')
                + N'","ReasonID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @ReasonID_INT), N'')
                + N'","ReasonCode":"' + ISNULL(CONVERT(NVARCHAR(MAX), @ReasonCode), N'') + N'"}';
        END

        ELSE IF @Action IN (N'STARTMAINTENANCEWORK', N'COMPLETEMAINTENANCEWORK', N'CLOSEMAINTENANCEREQUEST')
        BEGIN
            IF @Action = N'STARTMAINTENANCEWORK'
            BEGIN
                IF ISNULL(@LastActionTypeCode, N'') <> N'INSPECTION_REPORT'
                BEGIN
                    ;THROW 50001, N'لا يمكن بدء التنفيذ قبل تسجيل تقرير المعاينة', 1;
                END

                IF ISNULL(@CurrentStatusCode, N'') IN (N'CLOSED', N'CANCELLED', N'COMPLETED')
                BEGIN
                    ;THROW 50001, N'لا يمكن بدء التنفيذ قبل تسجيل تقرير المعاينة', 1;
                END
            END

            IF @Action = N'COMPLETEMAINTENANCEWORK'
            BEGIN
                IF ISNULL(@CurrentStatusCode, N'') <> N'IN_PROGRESS'
                BEGIN
                    ;THROW 50001, N'لا يمكن إنهاء التنفيذ قبل بدء العمل', 1;
                END

                IF NOT EXISTS
                (
                    SELECT 1
                    FROM Maintenance.BuildingMaintenanceRequestAction AS action
                    INNER JOIN Maintenance.MaintenanceActionType AS actionType
                        ON actionType.ActionTypeID = action.ActionTypeID
                    WHERE action.RequestID = @RequestID_BIGINT
                      AND action.IdaraId_FK = @IdaraID_BIGINT
                      AND action.IsActive = 1
                      AND actionType.ActionTypeCode = N'START_WORK'
                )
                BEGIN
                    ;THROW 50001, N'لا يمكن إنهاء التنفيذ قبل بدء العمل', 1;
                END
            END

            IF @Action = N'CLOSEMAINTENANCEREQUEST'
            BEGIN
                IF @LastInspectionActionID IS NULL
                BEGIN
                    ;THROW 50001, N'لا يمكن إغلاق الطلب قبل تسجيل تقرير المعاينة', 1;
                END

                IF ISNULL(@CurrentStatusCode, N'') = N'COMPLETED'
                   AND NOT EXISTS
                   (
                       SELECT 1
                       FROM Maintenance.BuildingMaintenanceRequestAction AS action
                       INNER JOIN Maintenance.MaintenanceActionType AS actionType
                           ON actionType.ActionTypeID = action.ActionTypeID
                       WHERE action.RequestID = @RequestID_BIGINT
                         AND action.IdaraId_FK = @IdaraID_BIGINT
                         AND action.IsActive = 1
                         AND actionType.ActionTypeCode = N'COMPLETE_WORK'
                   )
                BEGIN
                    ;THROW 50001, N'لا يمكن إغلاق الطلب قبل تسجيل تقرير المعاينة', 1;
                END

                IF ISNULL(@CurrentStatusCode, N'') <> N'COMPLETED'
                   AND
                   (
                       ISNULL(@LastActionTypeCode, N'') <> N'INSPECTION_REPORT'
                       OR EXISTS
                       (
                           SELECT 1
                           FROM Maintenance.BuildingMaintenanceRequestAction AS action
                           INNER JOIN Maintenance.MaintenanceActionType AS actionType
                               ON actionType.ActionTypeID = action.ActionTypeID
                           WHERE action.RequestID = @RequestID_BIGINT
                             AND action.IdaraId_FK = @IdaraID_BIGINT
                             AND action.IsActive = 1
                             AND action.ActionDate >= @LastInspectionActionDate
                             AND action.ActionID > @LastInspectionActionID
                             AND actionType.ActionTypeCode IN (N'START_WORK', N'COMPLETE_WORK')
                       )
                   )
                BEGIN
                    ;THROW 50001, N'لا يمكن إغلاق الطلب قبل تسجيل تقرير المعاينة', 1;
                END
            END

            IF @Action = N'STARTMAINTENANCEWORK' AND ISNULL(@CurrentStatusCode, N'') IN (N'COMPLETED')
            BEGIN
                ;THROW 50001, N'لا يمكن بدء تنفيذ طلب مكتمل', 1;
            END

            IF @Action = N'CLOSEMAINTENANCEREQUEST'
               AND ISNULL(@CurrentStatusCode, N'') <> N'COMPLETED'
               AND ISNULL(@LastActionTypeCode, N'') <> N'INSPECTION_REPORT'
            BEGIN
                ;THROW 50001, N'لا يمكن إغلاق الطلب إلا بعد اكتماله', 1;
            END

            SELECT TOP 1 @NewStatusID = StatusID
            FROM Maintenance.MaintenanceRequestStatus
            WHERE StatusCode =
                CASE @Action
                    WHEN N'STARTMAINTENANCEWORK' THEN N'IN_PROGRESS'
                    WHEN N'COMPLETEMAINTENANCEWORK' THEN N'COMPLETED'
                    WHEN N'CLOSEMAINTENANCEREQUEST' THEN N'CLOSED'
                END
              AND IsActive = 1
              AND (IdaraId_FK IS NULL OR IdaraId_FK = @IdaraID_BIGINT)
            ORDER BY CASE WHEN IdaraId_FK = @IdaraID_BIGINT THEN 0 ELSE 1 END, StatusID;

            IF @NewStatusID IS NULL
            BEGIN
                ;THROW 50002, N'حالة الطلب المطلوبة غير معرفة', 1;
            END

            UPDATE Maintenance.BuildingMaintenanceRequest
            SET
                  StatusID = @NewStatusID
                , ClosedDate = CASE WHEN @Action = N'CLOSEMAINTENANCEREQUEST' THEN GETDATE() ELSE ClosedDate END
                , updateUser = @EntryUser_BIGINT
                , updateDate = GETDATE()
                , entryData = ISNULL(ISNULL(entryData, N'') + N',' + @entryData, entryData)
                , hostName = ISNULL(ISNULL(@hostName, N'') + N',' + @hostName, hostName)
            WHERE RequestID = @RequestID_BIGINT
              AND IdaraId_FK = @IdaraID_BIGINT
              AND IsActive = 1;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ أثناء تحديث حالة الطلب', 1;
            END

            IF @Action = N'COMPLETEMAINTENANCEWORK'
            BEGIN
                UPDATE Maintenance.BuildingMaintenanceRequestAssignment
                SET
                      CompletionDate = ISNULL(CompletionDate, GETDATE())
                    , updateUser = @EntryUser_BIGINT
                    , updateDate = GETDATE()
                    , entryData = ISNULL(ISNULL(entryData, N'') + N',' + @entryData, entryData)
                    , hostName = ISNULL(ISNULL(@hostName, N'') + N',' + @hostName, hostName)
                WHERE RequestID = @RequestID_BIGINT
                  AND IdaraId_FK = @IdaraID_BIGINT
                  AND IsActive = 1;
            END

            INSERT INTO Maintenance.BuildingMaintenanceRequestAction
            (
                  RequestID
                , ActionTypeID
                , FromDSDID
                , ToDSDID
                , FromUserID
                , OldStatusID
                , NewStatusID
                , ActionNote
                , ActionDate
                , entryUser
                , IdaraId_FK
                , entryData
                , hostName
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
                ;THROW 50002, N'حصل خطأ أثناء تسجيل حركة الطلب', 1;
            END

            SET @NewID = @RequestID_BIGINT;
            SET @Note = N'{"RequestID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @RequestID_BIGINT), N'') + N'","Action":"' + ISNULL(CONVERT(NVARCHAR(MAX), @Action), N'') + N'"}';
        END

        ELSE
        BEGIN
            ;THROW 50001, N'العملية غير مسجلة', 1;
        END

        INSERT INTO dbo.AuditLog
        (
              TableName
            , ActionType
            , RecordID
            , PerformedBy
            , Notes
        )
        VALUES
        (
              N'[Maintenance].[BuildingMaintenanceRequestFollowUp]'
            , @Action
            , ISNULL(@NewID, @RequestID_BIGINT)
            , @entryData
            , @Note
        );

        IF @tc = 0
            COMMIT;

        SELECT 1 AS IsSuccessful, @SuccessMessage AS Message_;
        RETURN;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;

        ;THROW;
    END CATCH
END

GO

