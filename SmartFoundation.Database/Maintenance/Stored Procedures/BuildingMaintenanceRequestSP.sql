
CREATE   PROCEDURE [Maintenance].[BuildingMaintenanceRequestSP]
      @Action NVARCHAR(200)
    , @RequestID NVARCHAR(100) = NULL
    , @BuildingID NVARCHAR(100) = NULL
    , @ResidentID NVARCHAR(100) = NULL
    , @MaintenanceCategoryID NVARCHAR(100) = NULL
    , @PriorityID NVARCHAR(100) = NULL
    , @Description_A NVARCHAR(MAX) = NULL
    , @Notes NVARCHAR(MAX) = NULL
    , @idaraID_FK NVARCHAR(10) = NULL
    , @entryData NVARCHAR(20) = NULL
    , @hostName NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    ----------------------------------------------------------------
    --                    BuildingMaintenanceRequest
    ----------------------------------------------------------------

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE
          @NewID BIGINT = NULL
        , @Note NVARCHAR(MAX) = NULL
        , @IdaraID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''))
        , @RequestID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@RequestID)), N''))
        , @BuildingID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@BuildingID)), N''))
        , @ResidentID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@ResidentID)), N''))
        , @MaintenanceCategoryID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@MaintenanceCategoryID)), N''))
        , @PriorityID_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@PriorityID)), N''))
        , @EntryUser_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@entryData)), N''))
        , @StatusID_NEW INT = NULL
        , @StatusID_CANCELLED INT = NULL
        , @ActionTypeID_CREATE INT = NULL
        , @ActionTypeID_CANCEL INT = NULL
        , @ResponsibleDSDID BIGINT = NULL
        , @OldStatusID INT = NULL
        , @OldStatusCode NVARCHAR(100) = NULL
        , @RequestNo NVARCHAR(50) = NULL
        , @NextNo INT = NULL;

    SET @Action = UPPER(LTRIM(RTRIM(ISNULL(@Action, N''))));

    BEGIN TRY
        IF @tc = 0
            BEGIN TRAN;

        IF @IdaraID_BIGINT IS NULL
        BEGIN
            ;THROW 50001, N'الإدارة مطلوبة', 1;
        END

        IF @Action IN (N'INSERTBUILDINGMAINTENANCEREQUEST', N'UPDATEBUILDINGMAINTENANCEREQUEST')
        BEGIN
            IF @BuildingID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'المبنى مطلوب', 1;
            END

            IF @ResidentID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'المستفيد مطلوب', 1;
            END

            IF @MaintenanceCategoryID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'نوع الصيانة مطلوب', 1;
            END

            IF @PriorityID_INT IS NULL
            BEGIN
                ;THROW 50001, N'الأولوية مطلوبة', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@Description_A)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'وصف المشكلة مطلوب', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.V_GetFullResidentDetails
                WHERE residentInfoID = @ResidentID_BIGINT
                  AND IdaraID = @IdaraID_BIGINT
            )
            BEGIN
                ;THROW 50001, N'المستفيد غير موجود ضمن الإدارة الحالية', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.V_Occupant
                WHERE buildingDetailsID = @BuildingID_BIGINT
                  AND residentInfoID = @ResidentID_BIGINT
                  AND IdaraId = @IdaraID_BIGINT
                  AND ExitDate IS NULL
            )
            BEGIN
                ;THROW 50001, N'المبنى غير مرتبط بالمستفيد الحالي', 1;
            END

            SELECT TOP 1
                   @ResponsibleDSDID = routing.ResponsibleDSDID
            FROM Maintenance.MaintenanceCategoryRouting AS routing
            INNER JOIN Maintenance.MaintenanceCategory AS category
                ON category.MaintenanceCategoryID = routing.MaintenanceCategoryID
               AND category.IdaraId_FK = routing.IdaraId_FK
               AND category.IsActive = 1
            WHERE routing.MaintenanceCategoryID = @MaintenanceCategoryID_BIGINT
              AND routing.IdaraId_FK = @IdaraID_BIGINT
              AND routing.IsActive = 1
              AND routing.IsDefault = 1
              AND routing.ResponsibleDSDID IS NOT NULL
            ORDER BY routing.MaintenanceCategoryRoutingID DESC;

            IF @ResponsibleDSDID IS NULL
            BEGIN
                ;THROW 50001, N'نوع الصيانة غير مربوط بجهة مسؤولة', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Maintenance.MaintenancePriority
                WHERE PriorityID = @PriorityID_INT
                  AND IsActive = 1
                  AND (IdaraId_FK IS NULL OR IdaraId_FK = @IdaraID_BIGINT)
            )
            BEGIN
                ;THROW 50001, N'الأولوية غير موجودة أو غير فعالة', 1;
            END
        END

        IF @Action = N'INSERTBUILDINGMAINTENANCEREQUEST'
        BEGIN
            SELECT TOP 1 @StatusID_NEW = StatusID
            FROM Maintenance.MaintenanceRequestStatus
            WHERE StatusCode = N'NEW'
              AND IsActive = 1
              AND (IdaraId_FK IS NULL OR IdaraId_FK = @IdaraID_BIGINT)
            ORDER BY CASE WHEN IdaraId_FK = @IdaraID_BIGINT THEN 0 ELSE 1 END, StatusID;

            IF @StatusID_NEW IS NULL
            BEGIN
                ;THROW 50002, N'حالة الطلب NEW غير معرفة', 1;
            END

            SELECT TOP 1 @ActionTypeID_CREATE = ActionTypeID
            FROM Maintenance.MaintenanceActionType
            WHERE ActionTypeCode = N'CREATE'
              AND IsActive = 1
              AND (IdaraId_FK IS NULL OR IdaraId_FK = @IdaraID_BIGINT)
            ORDER BY CASE WHEN IdaraId_FK = @IdaraID_BIGINT THEN 0 ELSE 1 END, ActionTypeID;

            IF @ActionTypeID_CREATE IS NULL
            BEGIN
                ;THROW 50002, N'نوع الحركة CREATE غير معرف', 1;
            END

            SELECT @NextNo = ISNULL(MAX(TRY_CONVERT(INT, RIGHT(RequestNo, 6))), 0) + 1
            FROM Maintenance.BuildingMaintenanceRequest WITH (UPDLOCK, HOLDLOCK)
            WHERE IdaraId_FK = @IdaraID_BIGINT
              AND RequestNo LIKE N'MR-' + CONVERT(NVARCHAR(4), YEAR(GETDATE())) + N'-%';

            SET @RequestNo = N'MR-' + CONVERT(NVARCHAR(4), YEAR(GETDATE())) + N'-' + RIGHT(N'000000' + CONVERT(NVARCHAR(20), @NextNo), 6);

            INSERT INTO Maintenance.BuildingMaintenanceRequest
            (
                  IdaraId_FK
                , RequestNo
                , TransactionID_FK
                , ParentRequestID
                , RootRequestID
                , RequestLevel
                , IsSubRequest
                , IsBlockingParent
                , BuildingID
                , ResidentID
                , MaintenanceCategoryID
                , OriginalDSDID
                , CurrentDSDID
                , StatusID
                , PriorityID
                , Description_A
                , RequestDate
                , IsActive
                , entryUser
                , entryData
                , hostName
            )
            VALUES
            (
                  @IdaraID_BIGINT
                , @RequestNo
                , NULL
                , NULL
                , NULL
                , 0
                , 0
                , 1
                , @BuildingID_BIGINT
                , @ResidentID_BIGINT
                , @MaintenanceCategoryID_BIGINT
                , @ResponsibleDSDID
                , @ResponsibleDSDID
                , @StatusID_NEW
                , @PriorityID_INT
                , @Description_A
                , GETDATE()
                , 1
                , @EntryUser_BIGINT
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات', 1;
            END

            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات - Identity', 1;
            END

            UPDATE Maintenance.BuildingMaintenanceRequest
            SET RootRequestID = @NewID
            WHERE RequestID = @NewID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ أثناء تحديث أصل الطلب', 1;
            END

            INSERT INTO Maintenance.BuildingMaintenanceRequestAction
            (
                  RequestID
                , ActionTypeID
                , OldStatusID
                , NewStatusID
                , ToDSDID
                , FromUserID
                , ActionNote
                , ActionDate
                , entryUser
                , IdaraId_FK
                , entryData
                , hostName
            )
            VALUES
            (
                  @NewID
                , @ActionTypeID_CREATE
                , NULL
                , @StatusID_NEW
                , @ResponsibleDSDID
                , @EntryUser_BIGINT
                , N'تم إنشاء طلب الصيانة'
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

            SET @Note = N'{'
                + N'"RequestID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"RequestNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @RequestNo), '') + N'"'
                + N',"BuildingID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingID_BIGINT), '') + N'"'
                + N',"ResidentID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ResidentID_BIGINT), '') + N'"'
                + N',"MaintenanceCategoryID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MaintenanceCategoryID_BIGINT), '') + N'"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

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
                  N'[Maintenance].[BuildingMaintenanceRequest]'
                , @Action
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            IF @tc = 0
                COMMIT;

            SELECT 1 AS IsSuccessful, N'تم إضافة طلب الصيانة بنجاح' AS Message_;
            RETURN;
        END

        ELSE IF @Action = N'UPDATEBUILDINGMAINTENANCEREQUEST'
        BEGIN
            IF @RequestID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'رقم الطلب مطلوب للتحديث', 1;
            END

            SELECT
                  @OldStatusID = request.StatusID
                , @OldStatusCode = status.StatusCode
            FROM Maintenance.BuildingMaintenanceRequest AS request
            INNER JOIN Maintenance.MaintenanceRequestStatus AS status
                ON status.StatusID = request.StatusID
            WHERE request.RequestID = @RequestID_BIGINT
              AND request.IdaraId_FK = @IdaraID_BIGINT
              AND request.IsActive = 1;

            IF @OldStatusID IS NULL
            BEGIN
                ;THROW 50001, N'طلب الصيانة غير موجود', 1;
            END

            IF ISNULL(@OldStatusCode, N'') <> N'NEW'
            BEGIN
                ;THROW 50001, N'لا يمكن تعديل الطلب إلا إذا كانت حالته جديد', 1;
            END

            UPDATE Maintenance.BuildingMaintenanceRequest
            SET
                  BuildingID = @BuildingID_BIGINT
                , ResidentID = @ResidentID_BIGINT
                , MaintenanceCategoryID = @MaintenanceCategoryID_BIGINT
                , OriginalDSDID = @ResponsibleDSDID
                , CurrentDSDID = @ResponsibleDSDID
                , PriorityID = @PriorityID_INT
                , Description_A = @Description_A
                , updateUser = @EntryUser_BIGINT
                , updateDate = GETDATE()
                , entryData = ISNULL(ISNULL(entryData, N'') + N',' + @entryData, entryData)
                , hostName = ISNULL(ISNULL(@hostName, N'') + N',' + @hostName, hostName)
            WHERE RequestID = @RequestID_BIGINT
              AND IdaraId_FK = @IdaraID_BIGINT
              AND IsActive = 1;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ أثناء تحديث الطلب', 1;
            END

            SET @Note = N'{'
                + N'"RequestID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @RequestID_BIGINT), '') + N'"'
                + N',"BuildingID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingID_BIGINT), '') + N'"'
                + N',"ResidentID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ResidentID_BIGINT), '') + N'"'
                + N',"MaintenanceCategoryID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MaintenanceCategoryID_BIGINT), '') + N'"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

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
                  N'[Maintenance].[BuildingMaintenanceRequest]'
                , @Action
                , ISNULL(@RequestID_BIGINT, 0)
                , @entryData
                , @Note
            );

            IF @tc = 0
                COMMIT;

            SELECT 1 AS IsSuccessful, N'تم تعديل طلب الصيانة بنجاح' AS Message_;
            RETURN;
        END

        ELSE IF @Action = N'CANCELBUILDINGMAINTENANCEREQUEST'
        BEGIN
            IF @RequestID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'رقم الطلب مطلوب للإلغاء', 1;
            END

            SELECT
                  @OldStatusID = request.StatusID
                , @OldStatusCode = status.StatusCode
                , @ResponsibleDSDID = request.CurrentDSDID
            FROM Maintenance.BuildingMaintenanceRequest AS request
            INNER JOIN Maintenance.MaintenanceRequestStatus AS status
                ON status.StatusID = request.StatusID
            WHERE request.RequestID = @RequestID_BIGINT
              AND request.IdaraId_FK = @IdaraID_BIGINT
              AND request.IsActive = 1;

            IF @OldStatusID IS NULL
            BEGIN
                ;THROW 50001, N'طلب الصيانة غير موجود', 1;
            END

            IF ISNULL(@OldStatusCode, N'') IN (N'CLOSED', N'COMPLETED', N'CANCELLED')
            BEGIN
                ;THROW 50001, N'لا يمكن إلغاء طلب مغلق أو مكتمل أو ملغي', 1;
            END

            SELECT TOP 1 @StatusID_CANCELLED = StatusID
            FROM Maintenance.MaintenanceRequestStatus
            WHERE StatusCode = N'CANCELLED'
              AND IsActive = 1
              AND (IdaraId_FK IS NULL OR IdaraId_FK = @IdaraID_BIGINT)
            ORDER BY CASE WHEN IdaraId_FK = @IdaraID_BIGINT THEN 0 ELSE 1 END, StatusID;

            IF @StatusID_CANCELLED IS NULL
            BEGIN
                ;THROW 50002, N'حالة الطلب CANCELLED غير معرفة', 1;
            END

            SELECT TOP 1 @ActionTypeID_CANCEL = ActionTypeID
            FROM Maintenance.MaintenanceActionType
            WHERE ActionTypeCode = N'CANCEL'
              AND IsActive = 1
              AND (IdaraId_FK IS NULL OR IdaraId_FK = @IdaraID_BIGINT)
            ORDER BY CASE WHEN IdaraId_FK = @IdaraID_BIGINT THEN 0 ELSE 1 END, ActionTypeID;

            IF @ActionTypeID_CANCEL IS NULL
            BEGIN
                ;THROW 50002, N'نوع الحركة CANCEL غير معرف', 1;
            END

            UPDATE Maintenance.BuildingMaintenanceRequest
            SET
                  StatusID = @StatusID_CANCELLED
                , ClosedDate = GETDATE()
                , updateUser = @EntryUser_BIGINT
                , updateDate = GETDATE()
                , entryData = ISNULL(ISNULL(entryData, N'') + N',' + @entryData, entryData)
                , hostName = ISNULL(ISNULL(@hostName, N'') + N',' + @hostName, hostName)
            WHERE RequestID = @RequestID_BIGINT
              AND IdaraId_FK = @IdaraID_BIGINT
              AND IsActive = 1;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ أثناء إلغاء الطلب', 1;
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
                , @ActionTypeID_CANCEL
                , @ResponsibleDSDID
                , @ResponsibleDSDID
                , @EntryUser_BIGINT
                , @OldStatusID
                , @StatusID_CANCELLED
                , @Notes
                , GETDATE()
                , @EntryUser_BIGINT
                , @IdaraID_BIGINT
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ أثناء تسجيل حركة الإلغاء', 1;
            END

            SET @Note = N'{'
                + N'"RequestID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @RequestID_BIGINT), '') + N'"'
                + N',"OldStatusID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @OldStatusID), '') + N'"'
                + N',"NewStatusID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @StatusID_CANCELLED), '') + N'"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

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
                  N'[Maintenance].[BuildingMaintenanceRequest]'
                , @Action
                , ISNULL(@RequestID_BIGINT, 0)
                , @entryData
                , @Note
            );

            IF @tc = 0
                COMMIT;

            SELECT 1 AS IsSuccessful, N'تم إلغاء طلب الصيانة بنجاح' AS Message_;
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

GO

