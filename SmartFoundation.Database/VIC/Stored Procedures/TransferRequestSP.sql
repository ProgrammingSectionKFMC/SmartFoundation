

/* ORIGINAL PROCEDURE VIC.TransferRequestSP */
CREATE PROCEDURE [VIC].[TransferRequestSP]
    @ActionType NVARCHAR(100)
    , @requestID INT = NULL
    , @requestTypeID INT = NULL
    , @vehicleID INT = NULL
    , @chassisNumber NVARCHAR(200) = NULL
    , @fromUserID BIGINT = NULL
    , @toUserID BIGINT = NULL
    , @deptID INT = NULL
    , @createByUser NVARCHAR(200) = NULL
    , @note NVARCHAR(400) = NULL
    , @actionBy BIGINT = NULL
    , @idaraID_FK NVARCHAR(10) = NULL
    , @entryData NVARCHAR(40) = NULL
    , @hostName NVARCHAR(400) = NULL
    , @requestTypeNameA NVARCHAR(50) = NULL
    , @requestTypeNameE NVARCHAR(50) = NULL
    , @typeActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;
    DECLARE @IdaraID_BIG BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));
    DECLARE @Now DATETIME = GETDATE();
    DECLARE @NewRequestID INT = NULL;
    DECLARE @NewVehicleWithUsersID BIGINT = NULL;
    DECLARE @Note_Audit NVARCHAR(MAX) = N'';
    DECLARE @LastStatus NVARCHAR(100) = N'';
    DECLARE @ReqCH NVARCHAR(200) = N'';
    DECLARE @AuditAction NVARCHAR(20) = N'';

    DECLARE @CH NVARCHAR(200);
    DECLARE @VID INT;

    IF @vehicleID IS NOT NULL
    BEGIN
        SELECT @CH = v.chassisNumber, @VID = v.vehicleID
        FROM VIC.Vehicles v WHERE v.vehicleID = @vehicleID;
        IF @CH IS NULL BEGIN THROW 50001, N'المركبة غير موجودة برقم المركبة الداخلي', 1; RETURN; END
    END
    ELSE IF @chassisNumber IS NOT NULL
    BEGIN
        SET @CH = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
        IF @CH IS NOT NULL
            SELECT @VID = v.vehicleID FROM VIC.Vehicles v WHERE v.chassisNumber = @CH;
    END

    ----------------------------------------------------------------
    -- CREATE
    ----------------------------------------------------------------
    IF @ActionType = N'CREATE'
    BEGIN
        BEGIN TRY
            IF @CH IS NULL
            BEGIN THROW 50001, N'رقم الشاصي أو رقم المركبة مطلوب', 1; RETURN; END

            IF @fromUserID IS NULL
            BEGIN THROW 50001, N'مستخدم العهدة الحالي مطلوب', 1; RETURN; END

            IF @toUserID IS NULL
            BEGIN THROW 50001, N'المستخدم المنقول إليه مطلوب', 1; RETURN; END

            IF @deptID IS NULL
            BEGIN THROW 50001, N'القسم مطلوب', 1; RETURN; END

            IF @IdaraID_BIG IS NULL
            BEGIN THROW 50001, N'الإدارة مطلوبة', 1; RETURN; END

            IF @requestTypeID IS NULL OR @requestTypeID <= 0
            BEGIN THROW 50001, N'نوع الطلب مطلوب', 1; RETURN; END

            IF NOT EXISTS (SELECT 1 FROM VIC.VehicleTransferRequestType WHERE VehicleTransferRequestTypeID = @requestTypeID AND ISNULL(Active,1)=1)
            BEGIN THROW 50001, N'نوع الطلب غير موجود أو غير نشط', 1; RETURN; END

            IF NOT EXISTS (
                SELECT 1
                FROM VIC.Vehicles v
                WHERE v.chassisNumber = @CH
                  AND v.IdaraID_FK = @IdaraID_BIG
            )
            BEGIN THROW 50001, N'المركبة غير موجودة في هذه الإدارة', 1; RETURN; END

            DECLARE
                  @CurrentCustodyUserID BIGINT = NULL
                , @CurrentCustodyDeptID INT = NULL;

            SELECT TOP (1)
                  @CurrentCustodyUserID = w.userID_FK
                , @CurrentCustodyDeptID = w.DeptID_Snapshot
            FROM VIC.vehicleWithUsers w
            INNER JOIN VIC.Vehicles v
                ON v.chassisNumber = w.chassisNumber_FK
            WHERE w.chassisNumber_FK = @CH
              AND w.endDate IS NULL
              AND v.IdaraID_FK = @IdaraID_BIG
            ORDER BY w.startDate DESC, w.vehicleWithUsersID DESC;

            IF @CurrentCustodyUserID IS NULL
            BEGIN THROW 50001, N'لا توجد عهدة فعالة لهذه المركبة', 1; RETURN; END

            IF @CurrentCustodyUserID <> @fromUserID
            BEGIN THROW 50001, N'المستخدم الحالي لا يطابق صاحب العهدة الحالي', 1; RETURN; END

            IF @fromUserID <> @actionBy
            BEGIN THROW 50001, N'فقط صاحب العهدة يمكنه إنشاء طلب النقل', 1; RETURN; END

            IF EXISTS (
                SELECT 1 FROM VIC.Vehicles v
                WHERE v.chassisNumber = @CH
                  AND v.vehicleStatusID_FK IN (261, 262)
            )
            BEGIN THROW 50001, N'لا يمكن إنشاء طلب نقل لمركبة خارج الخدمة أو مشطوبة', 1; RETURN; END

            IF @CurrentCustodyDeptID IS NULL
            BEGIN THROW 50001, N'تعذر تحديد قسم العهدة', 1; RETURN; END

            IF @deptID <> @CurrentCustodyDeptID
            BEGIN THROW 50001, N'القسم لا يطابق قسم العهدة الحالي', 1; RETURN; END

            DECLARE
                  @FromDeptID INT = NULL
                , @FromIdaraID INT = NULL
                , @ToDeptID INT = NULL
                , @ToIdaraID INT = NULL;

            SELECT TOP (1)
                  @FromDeptID = TRY_CONVERT(INT, fs.DepartmentID)
                , @FromIdaraID = TRY_CONVERT(INT, fs.IdaraID)
            FROM DATACORE.dbo.Users u
            INNER JOIN DATACORE.dbo.UsersDetails ud
                ON ud.usersID_FK = u.usersID AND ISNULL(ud.userActive, 0) = 1
            LEFT JOIN DATACORE.dbo.V_getFullStructureForDSD fs
                ON fs.DSDID = (
                    SELECT TOP 1 ds.DSDID_FK
                    FROM DATACORE.dbo.UserDistributor d2
                    INNER JOIN DATACORE.dbo.Distributor ds
                        ON ds.distributorID = d2.distributorID_FK
                        AND ds.distributorActive = 1
                        AND ds.distributorType_FK = 1
                        AND ds.DSDID_FK IS NOT NULL
                    WHERE d2.userID_FK = u.usersID
                      AND d2.UDActive = 1
                      AND d2.UDStartDate IS NOT NULL
                      AND d2.UDEndDate IS NULL
                    ORDER BY d2.UDStartDate DESC
                )
            WHERE u.usersID = @fromUserID;

            IF @FromDeptID IS NULL OR @FromIdaraID IS NULL
            BEGIN THROW 50001, N'تعذر تحديد قسم أو إدارة المستخدم الحالي', 1; RETURN; END

            SELECT TOP (1)
                  @ToDeptID = TRY_CONVERT(INT, fs.DepartmentID)
                , @ToIdaraID = TRY_CONVERT(INT, fs.IdaraID)
            FROM DATACORE.dbo.Users u
            INNER JOIN DATACORE.dbo.UsersDetails ud
                ON ud.usersID_FK = u.usersID AND ISNULL(ud.userActive, 0) = 1
            LEFT JOIN DATACORE.dbo.V_getFullStructureForDSD fs
                ON fs.DSDID = (
                    SELECT TOP 1 ds.DSDID_FK
                    FROM DATACORE.dbo.UserDistributor d2
                    INNER JOIN DATACORE.dbo.Distributor ds
                        ON ds.distributorID = d2.distributorID_FK
                        AND ds.distributorActive = 1
                        AND ds.distributorType_FK = 1
                        AND ds.DSDID_FK IS NOT NULL
                    WHERE d2.userID_FK = u.usersID
                      AND d2.UDActive = 1
                      AND d2.UDStartDate IS NOT NULL
                      AND d2.UDEndDate IS NULL
                    ORDER BY d2.UDStartDate DESC
                )
            WHERE u.usersID = @toUserID;

            IF @ToDeptID IS NULL OR @ToIdaraID IS NULL
            BEGIN THROW 50001, N'تعذر تحديد قسم أو إدارة المستخدم المنقول إليه', 1; RETURN; END

            IF @FromIdaraID <> TRY_CONVERT(INT, @IdaraID_BIG)
               OR @ToIdaraID <> TRY_CONVERT(INT, @IdaraID_BIG)
            BEGIN THROW 50001, N'يجب أن يكون المستخدمان في نفس الإدارة', 1; RETURN; END

            IF @FromDeptID <> @deptID OR @ToDeptID <> @deptID
            BEGIN THROW 50001, N'يجب أن يكون المستخدمان في نفس القسم', 1; RETURN; END

            IF EXISTS (
                SELECT 1
                FROM VIC.vehicleWithUsers w
                INNER JOIN VIC.Vehicles v
                    ON v.chassisNumber = w.chassisNumber_FK
                WHERE w.userID_FK = @toUserID
                  AND w.endDate IS NULL
                  AND v.IdaraID_FK = @IdaraID_BIG
            )
            BEGIN THROW 50001, N'المستخدم المنقول إليه لديه عهدة مركبة فعالة بالفعل', 1; RETURN; END

            IF EXISTS (
                SELECT 1
                FROM VIC.VehicleTransferRequest r
                WHERE r.chassisNumber_FK = @CH
                  AND r.IdaraID_FK = @IdaraID_BIG
                  AND ISNULL(r.active, 0) = 1
            )
            BEGIN THROW 50001, N'يوجد طلب نقل فعال لهذه المركبة بالفعل', 1; RETURN; END

            IF @tc = 0 BEGIN TRAN;

            INSERT INTO VIC.VehicleTransferRequest
            (
                  RequestTypeID_FK
                , chassisNumber_FK
                , vehicleID_FK
                , fromUserID_FK
                , toUserID_FK
                , deptID_FK
                , CreateByUser
                , aproveNote
                , active
                , IdaraID_FK
                , entryDate
                , entryData
                , hostName
            )
            VALUES
            (
                  @requestTypeID
                , @CH
                , @VID
                , @fromUserID
                , @toUserID
                , @deptID
                , @createByUser
                , @note
                , 1
                , @IdaraID_BIG
                , @Now
                , @entryData
                , @hostName
            );

            SET @NewRequestID = CONVERT(INT, SCOPE_IDENTITY());

            IF @NewRequestID IS NULL OR @NewRequestID <= 0
            BEGIN THROW 50002, N'فشل إنشاء طلب النقل', 1; RETURN; END

            INSERT INTO VIC.VehicleTransferRequestHistory
            (
                  RequestID_FK
                , Status
                , ActionBy
                , ActionDate
                , Notes
                , hostName
                , entryDate
                , entryData
            )
            VALUES
            (
                  @NewRequestID
                , N'Created'
                , @actionBy
                , @Now
                , @note
                , @hostName
                , @Now
                , @entryData
            );

            SET @Note_Audit = N'{"chassisNumber":"' + ISNULL(@CH, N'')
                + N'","IdaraID":"' + ISNULL(@idaraID_FK, N'')
                + N'","Action":"CREATE","entryData":"' + ISNULL(@entryData, N'') + N'"}';

            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[VehicleTransferRequest]', N'CREATE', @NewRequestID, @entryData, @Note_Audit);

            IF @tc = 0 COMMIT;

            SELECT 1 AS IsSuccessful, N'تم إنشاء طلب النقل بنجاح' AS Message_, @NewRequestID AS RequestID;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- APPROVE
    ----------------------------------------------------------------
    IF @ActionType = N'APPROVE'
    BEGIN
        BEGIN TRY
            IF @requestID IS NULL OR @requestID <= 0
            BEGIN THROW 50001, N'requestID مطلوب', 1; RETURN; END

            IF @actionBy IS NULL OR @actionBy <= 0
            BEGIN THROW 50001, N'actionBy مطلوب', 1; RETURN; END

            IF @IdaraID_BIG IS NULL
            BEGIN THROW 50001, N'idaraID_FK مطلوب', 1; RETURN; END

            SELECT @ReqCH = r.chassisNumber_FK
            FROM VIC.VehicleTransferRequest r
            WHERE r.RequestID = @requestID
              AND r.IdaraID_FK = @IdaraID_BIG;

            IF @ReqCH IS NULL
            BEGIN THROW 50001, N'الطلب غير موجود أو لا يطابق الإدارة', 1; RETURN; END

            SELECT TOP (1) @LastStatus = h.Status
            FROM VIC.VehicleTransferRequestHistory h
            WHERE h.RequestID_FK = @requestID
            ORDER BY h.ActionDate DESC, h.HistoryID DESC;

            IF ISNULL(@LastStatus, N'') <> N'Created'
            BEGIN THROW 50001, N'يجب أن تكون حالة الطلب Created حتى يمكن اعتماده', 1; RETURN; END

            IF NOT EXISTS (
                SELECT 1
                FROM VIC.VehicleTransferRequest r
                WHERE r.RequestID = @requestID
                  AND r.IdaraID_FK = @IdaraID_BIG
                  AND ISNULL(r.active, 0) = 1
            )
            BEGIN THROW 50001, N'الطلب غير نشط', 1; RETURN; END

            IF EXISTS (
                SELECT 1
                FROM VIC.VehicleTransferRequest r2
                WHERE r2.chassisNumber_FK = @ReqCH
                  AND r2.RequestID <> @requestID
                  AND ISNULL(r2.active, 0) = 1
            )
            BEGIN THROW 50001, N'يوجد طلب نقل آخر نشط لهذه المركبة', 1; RETURN; END

            IF @actionBy IS NOT NULL
            BEGIN
                DECLARE @ApproverDeptID INT = NULL;

                SELECT TOP (1) @ApproverDeptID = TRY_CONVERT(INT, fs.DepartmentID)
                FROM DATACORE.dbo.Users u
                INNER JOIN DATACORE.dbo.UsersDetails ud
                    ON ud.usersID_FK = u.usersID AND ISNULL(ud.userActive, 0) = 1
                LEFT JOIN DATACORE.dbo.V_getFullStructureForDSD fs
                    ON fs.DSDID = (
                        SELECT TOP 1 ds.DSDID_FK
                        FROM DATACORE.dbo.UserDistributor d2
                        INNER JOIN DATACORE.dbo.Distributor ds
                            ON ds.distributorID = d2.distributorID_FK
                            AND ds.distributorActive = 1
                            AND ds.distributorType_FK = 1
                            AND ds.DSDID_FK IS NOT NULL
                        WHERE d2.userID_FK = u.usersID
                          AND d2.UDActive = 1
                          AND d2.UDStartDate IS NOT NULL
                          AND d2.UDEndDate IS NULL
                        ORDER BY d2.UDStartDate DESC
                    )
                WHERE u.usersID = @actionBy;

                IF @ApproverDeptID IS NOT NULL
                BEGIN
                    DECLARE @ApproveReqDeptID INT = NULL;
                    SELECT @ApproveReqDeptID = r.deptID_FK
                    FROM VIC.VehicleTransferRequest r
                    WHERE r.RequestID = @requestID;

                    IF @ApproveReqDeptID IS NOT NULL AND @ApproveReqDeptID <> @ApproverDeptID
                    BEGIN THROW 50001, N'لا يمكنك اعتماد طلب خارج قسمك', 1; RETURN; END
                END
            END

            IF @tc = 0 BEGIN TRAN;

            UPDATE VIC.VehicleTransferRequest
            SET
                  active      = 1
                , aproveNote  = CASE WHEN @note IS NULL THEN aproveNote ELSE LEFT(@note, 400) END
                , entryDate   = @Now
                , entryData   = CONVERT(NVARCHAR(40), @actionBy)
                , hostName    = @hostName
            WHERE RequestID = @requestID
              AND IdaraID_FK = @IdaraID_BIG;

            IF @@ROWCOUNT <= 0
            BEGIN THROW 50002, N'لم يتم تحديث أي سجل', 1; RETURN; END

            INSERT INTO VIC.VehicleTransferRequestHistory
            (
                  RequestID_FK
                , Status
                , ActionBy
                , ActionDate
                , Notes
                , hostName
                , entryDate
                , entryData
            )
            VALUES
            (
                  @requestID
                , N'Approved'
                , @actionBy
                , @Now
                , @note
                , @hostName
                , @Now
                , CONVERT(NVARCHAR(40), @actionBy)
            );

            SET @Note_Audit = N'{"RequestID":"' + CONVERT(NVARCHAR(20), @requestID)
                + N'","Action":"APPROVE","entryData":"' + ISNULL(@entryData, N'') + N'"}';

            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[VehicleTransferRequest]', N'APPROVE', @requestID, @entryData, @Note_Audit);

            IF @tc = 0 COMMIT;

            SELECT 1 AS IsSuccessful, N'تم اعتماد الطلب' AS Message_;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- REJECT
    ----------------------------------------------------------------
    IF @ActionType = N'REJECT'
    BEGIN
        BEGIN TRY
            IF @requestID IS NULL OR @requestID <= 0
            BEGIN THROW 50001, N'requestID مطلوب', 1; RETURN; END

            IF @actionBy IS NULL OR @actionBy <= 0
            BEGIN THROW 50001, N'actionBy مطلوب', 1; RETURN; END

            IF @IdaraID_BIG IS NULL
            BEGIN THROW 50001, N'idaraID_FK مطلوب', 1; RETURN; END

            IF NOT EXISTS (
                SELECT 1
                FROM VIC.VehicleTransferRequest r
                WHERE r.RequestID = @requestID
                  AND r.IdaraID_FK = @IdaraID_BIG
            )
            BEGIN THROW 50001, N'الطلب غير موجود أو لا يطابق الإدارة', 1; RETURN; END

            SELECT TOP (1) @LastStatus = h.Status
            FROM VIC.VehicleTransferRequestHistory h
            WHERE h.RequestID_FK = @requestID
            ORDER BY h.ActionDate DESC, h.HistoryID DESC;

            IF ISNULL(@LastStatus, N'') NOT IN (N'Created', N'Approved')
            BEGIN THROW 50001, N'يجب أن تكون حالة الطلب Created أو Approved حتى يمكن رفضه', 1; RETURN; END

            IF @actionBy IS NOT NULL
            BEGIN
                DECLARE @RejecterDeptID INT = NULL;

                SELECT TOP (1) @RejecterDeptID = TRY_CONVERT(INT, fs.DepartmentID)
                FROM DATACORE.dbo.Users u
                INNER JOIN DATACORE.dbo.UsersDetails ud
                    ON ud.usersID_FK = u.usersID AND ISNULL(ud.userActive, 0) = 1
                LEFT JOIN DATACORE.dbo.V_getFullStructureForDSD fs
                    ON fs.DSDID = (
                        SELECT TOP 1 ds.DSDID_FK
                        FROM DATACORE.dbo.UserDistributor d2
                        INNER JOIN DATACORE.dbo.Distributor ds
                            ON ds.distributorID = d2.distributorID_FK
                            AND ds.distributorActive = 1
                            AND ds.distributorType_FK = 1
                            AND ds.DSDID_FK IS NOT NULL
                        WHERE d2.userID_FK = u.usersID
                          AND d2.UDActive = 1
                          AND d2.UDStartDate IS NOT NULL
                          AND d2.UDEndDate IS NULL
                        ORDER BY d2.UDStartDate DESC
                    )
                WHERE u.usersID = @actionBy;

                IF @RejecterDeptID IS NOT NULL
                BEGIN
                    DECLARE @RejectReqDeptID INT = NULL;
                    SELECT @RejectReqDeptID = r.deptID_FK
                    FROM VIC.VehicleTransferRequest r
                    WHERE r.RequestID = @requestID;

                    IF @RejectReqDeptID IS NOT NULL AND @RejectReqDeptID <> @RejecterDeptID
                    BEGIN THROW 50001, N'لا يمكنك رفض طلب خارج قسمك', 1; RETURN; END
                END
            END

            IF @tc = 0 BEGIN TRAN;

            UPDATE VIC.VehicleTransferRequest
            SET
                  active      = 0
                , aproveNote  = CASE WHEN @note IS NULL THEN aproveNote ELSE LEFT(@note, 400) END
                , entryDate   = @Now
                , entryData   = CONVERT(NVARCHAR(40), @actionBy)
                , hostName    = @hostName
            WHERE RequestID = @requestID
              AND IdaraID_FK = @IdaraID_BIG;

            IF @@ROWCOUNT <= 0
            BEGIN THROW 50002, N'لم يتم تحديث أي سجل', 1; RETURN; END

            INSERT INTO VIC.VehicleTransferRequestHistory
            (
                  RequestID_FK
                , Status
                , ActionBy
                , ActionDate
                , Notes
                , hostName
                , entryDate
                , entryData
            )
            VALUES
            (
                  @requestID
                , N'Rejected'
                , @actionBy
                , @Now
                , @note
                , @hostName
                , @Now
                , CONVERT(NVARCHAR(40), @actionBy)
            );

            SET @Note_Audit = N'{"RequestID":"' + CONVERT(NVARCHAR(20), @requestID)
                + N'","Action":"REJECT","entryData":"' + ISNULL(@entryData, N'') + N'"}';

            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[VehicleTransferRequest]', N'REJECT', @requestID, @entryData, @Note_Audit);

            IF @tc = 0 COMMIT;

            SELECT 1 AS IsSuccessful, N'تم رفض الطلب' AS Message_;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- CANCEL
    ----------------------------------------------------------------
    IF @ActionType = N'CANCEL'
    BEGIN
        BEGIN TRY
            IF @requestID IS NULL OR @requestID <= 0
            BEGIN THROW 50001, N'requestID مطلوب', 1; RETURN; END

            IF @actionBy IS NULL OR @actionBy <= 0
            BEGIN THROW 50001, N'actionBy مطلوب', 1; RETURN; END

            IF @IdaraID_BIG IS NULL
            BEGIN THROW 50001, N'idaraID_FK مطلوب', 1; RETURN; END

            IF NOT EXISTS (
                SELECT 1
                FROM VIC.VehicleTransferRequest r
                WHERE r.RequestID = @requestID
                  AND r.IdaraID_FK = @IdaraID_BIG
            )
            BEGIN THROW 50001, N'الطلب غير موجود أو لا يطابق الإدارة', 1; RETURN; END

            SELECT TOP (1) @LastStatus = h.Status
            FROM VIC.VehicleTransferRequestHistory h
            WHERE h.RequestID_FK = @requestID
            ORDER BY h.ActionDate DESC, h.HistoryID DESC;

            IF ISNULL(@LastStatus, N'') NOT IN (N'Created', N'Approved')
            BEGIN THROW 50001, N'يجب أن تكون حالة الطلب Created أو Approved حتى يمكن إلغاؤه', 1; RETURN; END

            DECLARE @ExFromUserID BIGINT = NULL;

            SELECT @ExFromUserID = r.fromUserID_FK
            FROM VIC.VehicleTransferRequest r
            WHERE r.RequestID = @requestID;

            IF @ExFromUserID IS NOT NULL AND @ExFromUserID <> @actionBy
            BEGIN THROW 50001, N'فقط صاحب الطلب يمكنه إلغاءه', 1; RETURN; END

            IF @tc = 0 BEGIN TRAN;

            UPDATE VIC.VehicleTransferRequest
            SET
                  active      = 0
                , aproveNote  = CASE WHEN @note IS NULL THEN aproveNote ELSE LEFT(@note, 400) END
                , entryDate   = @Now
                , entryData   = CONVERT(NVARCHAR(40), @actionBy)
                , hostName    = @hostName
            WHERE RequestID = @requestID
              AND IdaraID_FK = @IdaraID_BIG;

            IF @@ROWCOUNT <= 0
            BEGIN THROW 50002, N'لم يتم تحديث أي سجل', 1; RETURN; END

            INSERT INTO VIC.VehicleTransferRequestHistory
            (
                  RequestID_FK
                , Status
                , ActionBy
                , ActionDate
                , Notes
                , hostName
                , entryDate
                , entryData
            )
            VALUES
            (
                  @requestID
                , N'Cancelled'
                , @actionBy
                , @Now
                , @note
                , @hostName
                , @Now
                , CONVERT(NVARCHAR(40), @actionBy)
            );

            SET @Note_Audit = N'{"RequestID":"' + CONVERT(NVARCHAR(20), @requestID)
                + N'","Action":"CANCEL","entryData":"' + ISNULL(@entryData, N'') + N'"}';

            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[VehicleTransferRequest]', N'CANCEL', @requestID, @entryData, @Note_Audit);

            IF @tc = 0 COMMIT;

            SELECT 1 AS IsSuccessful, N'تم إلغاء الطلب' AS Message_;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- EXECUTE
    ----------------------------------------------------------------
    IF @ActionType = N'EXECUTE'
    BEGIN
        BEGIN TRY
            IF @requestID IS NULL OR @requestID <= 0
            BEGIN THROW 50001, N'requestID مطلوب', 1; RETURN; END

            IF NULLIF(LTRIM(RTRIM(@entryData)), N'') IS NULL
            BEGIN THROW 50001, N'entryData مطلوب', 1; RETURN; END

            IF @IdaraID_BIG IS NULL
            BEGIN THROW 50001, N'idaraID_FK مطلوب', 1; RETURN; END

            DECLARE
                  @ExFromUserID2 BIGINT = NULL
                , @ExToUserID BIGINT = NULL
                , @ExDeptID INT = NULL
                , @ExReqActive BIT = 0
                , @CurrentVehicleWithUsersID INT = NULL
                , @CurrentCustodyUserID2 BIGINT = NULL
                , @CurrentCustodyDeptID2 INT = NULL;

            IF @tc = 0 BEGIN TRAN;

            SELECT
                  @ReqCH       = r.chassisNumber_FK
                , @ExFromUserID2 = r.fromUserID_FK
                , @ExToUserID  = r.toUserID_FK
                , @ExDeptID    = r.deptID_FK
                , @ExReqActive = r.active
            FROM VIC.VehicleTransferRequest r
            WHERE r.RequestID = @requestID
              AND r.IdaraID_FK = @IdaraID_BIG;

            IF @ReqCH IS NULL
            BEGIN THROW 50001, N'الطلب غير موجود أو لا يطابق الإدارة', 1; RETURN; END

            IF ISNULL(@ExReqActive, 0) <> 1
            BEGIN THROW 50001, N'الطلب غير نشط', 1; RETURN; END

            SELECT TOP (1) @LastStatus = h.Status
            FROM VIC.VehicleTransferRequestHistory h
            WHERE h.RequestID_FK = @requestID
            ORDER BY h.ActionDate DESC, h.HistoryID DESC;

            IF ISNULL(@LastStatus, N'') <> N'Approved'
            BEGIN THROW 50001, N'لا يمكن تنفيذ الطلب إلا بعد الموافقة', 1; RETURN; END

            SELECT TOP (1)
                  @CurrentVehicleWithUsersID = w.vehicleWithUsersID
                , @CurrentCustodyUserID2 = w.userID_FK
                , @CurrentCustodyDeptID2 = w.DeptID_Snapshot
            FROM VIC.vehicleWithUsers w
            INNER JOIN VIC.Vehicles v
                ON v.chassisNumber = w.chassisNumber_FK
            WHERE w.chassisNumber_FK = @ReqCH
              AND w.endDate IS NULL
              AND v.IdaraID_FK = @IdaraID_BIG
              AND ISNULL(w.IdaraID_Snapshot, -1) = TRY_CONVERT(INT, @IdaraID_BIG)
            ORDER BY w.startDate DESC, w.vehicleWithUsersID DESC;

            IF @CurrentVehicleWithUsersID IS NULL
            BEGIN THROW 50001, N'لا توجد عهدة نشطة حالية على المركبة', 1; RETURN; END

            IF @CurrentCustodyUserID2 <> @ExFromUserID2
            BEGIN THROW 50001, N'صاحب العهدة الحالية لا يطابق المستخدم المنقول منه في الطلب', 1; RETURN; END

            IF @CurrentCustodyDeptID2 <> @ExDeptID
            BEGIN THROW 50001, N'قسم العهدة الحالية لا يطابق قسم الطلب', 1; RETURN; END

            IF EXISTS (
                SELECT 1
                FROM VIC.vehicleWithUsers w
                WHERE w.userID_FK = @ExToUserID
                  AND w.endDate IS NULL
                  AND ISNULL(w.IdaraID_Snapshot, -1) = TRY_CONVERT(INT, @IdaraID_BIG)
            )
            BEGIN THROW 50001, N'المنقول إليه لديه عهدة نشطة بالفعل', 1; RETURN; END

            UPDATE VIC.vehicleWithUsers
            SET
                  endDate = @Now
                , note = CASE
                            WHEN NULLIF(LTRIM(RTRIM(@note)), N'') IS NULL
                                THEN ISNULL(note, N'') + N' | إغلاق تلقائي بسبب تنفيذ طلب نقل رقم ' + CONVERT(NVARCHAR(20), @requestID)
                            ELSE LEFT(@note, 2000)
                         END
                , entryDate = @Now
                , entryData = @entryData
                , hostName = @hostName
            WHERE vehicleWithUsersID = @CurrentVehicleWithUsersID
              AND endDate IS NULL;

            IF @@ROWCOUNT <= 0
            BEGIN THROW 50002, N'فشل إغلاق العهدة الحالية', 1; RETURN; END

            INSERT INTO VIC.vehicleWithUsers
            (
                  userID_FK
                , RequestID_FK
                , startDate
                , endDate
                , note
                , entryDate
                , entryData
                , hostName
                , chassisNumber_FK
                , OrgSnapshotDate
                , IdaraID_Snapshot
                , DeptID_Snapshot
            )
            SELECT
                  @ExToUserID
                , @requestID
                , @Now
                , NULL
                , CASE
                      WHEN NULLIF(LTRIM(RTRIM(@note)), N'') IS NULL
                          THEN N'تم الإنشاء تلقائياً من تنفيذ طلب نقل رقم ' + CONVERT(NVARCHAR(20), @requestID)
                      ELSE LEFT(@note, 2000)
                  END
                , @Now
                , @entryData
                , @hostName
                , @ReqCH
                , @Now
                , TRY_CONVERT(INT, fs.IdaraID)
                , TRY_CONVERT(INT, fs.DepartmentID)
            FROM DATACORE.dbo.Users u
            INNER JOIN DATACORE.dbo.UsersDetails ud
                ON ud.usersID_FK = u.usersID AND ISNULL(ud.userActive, 0) = 1
            LEFT JOIN DATACORE.dbo.V_getFullStructureForDSD fs
                ON fs.DSDID = (
                    SELECT TOP 1 ds.DSDID_FK
                    FROM DATACORE.dbo.UserDistributor d2
                    INNER JOIN DATACORE.dbo.Distributor ds
                        ON ds.distributorID = d2.distributorID_FK
                        AND ds.distributorActive = 1
                        AND ds.distributorType_FK = 1
                        AND ds.DSDID_FK IS NOT NULL
                    WHERE d2.userID_FK = u.usersID
                      AND d2.UDActive = 1
                      AND d2.UDStartDate IS NOT NULL
                      AND d2.UDEndDate IS NULL
                    ORDER BY d2.UDStartDate DESC
                )
            WHERE u.usersID = @ExToUserID;

            SET @NewVehicleWithUsersID = CONVERT(BIGINT, SCOPE_IDENTITY());

            IF @NewVehicleWithUsersID IS NULL OR @NewVehicleWithUsersID <= 0
            BEGIN THROW 50002, N'فشل إنشاء العهدة الجديدة', 1; RETURN; END

            UPDATE VIC.VehicleTransferRequest
            SET
                  active = 0
                , aproveNote = CASE
                                  WHEN NULLIF(LTRIM(RTRIM(@note)), N'') IS NULL
                                      THEN ISNULL(aproveNote, N'') + N' | تم التنفيذ'
                                  ELSE LEFT(@note, 400)
                               END
                , entryDate = @Now
                , entryData = @entryData
                , hostName = @hostName
            WHERE RequestID = @requestID
              AND IdaraID_FK = @IdaraID_BIG
              AND ISNULL(active, 0) = 1;

            IF @@ROWCOUNT <= 0
            BEGIN THROW 50002, N'فشل إغلاق طلب النقل', 1; RETURN; END

            INSERT INTO VIC.VehicleTransferRequestHistory
            (
                  RequestID_FK
                , Status
                , ActionBy
                , ActionDate
                , Notes
                , hostName
                , entryDate
                , entryData
            )
            VALUES
            (
                  @requestID
                , N'Closed'
                , TRY_CONVERT(BIGINT, @entryData)
                , @Now
                , CASE
                      WHEN NULLIF(LTRIM(RTRIM(@note)), N'') IS NULL
                          THEN N'تم تنفيذ الطلب وإنشاء عهدة جديدة'
                      ELSE @note
                  END
                , @hostName
                , @Now
                , @entryData
            );

            SET @Note_Audit = N'{"RequestID":"' + CONVERT(NVARCHAR(20), @requestID)
                + N'","chassisNumber":"' + ISNULL(@ReqCH, N'')
                + N'","Action":"EXECUTE","NewVehicleWithUsersID":"' + CONVERT(NVARCHAR(20), @NewVehicleWithUsersID)
                + N'","entryData":"' + ISNULL(@entryData, N'') + N'"}';

            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[VehicleTransferRequest]', N'EXECUTE', @requestID, @entryData, @Note_Audit);

            IF @tc = 0 COMMIT;

            SELECT
                  CAST(1 AS INT) AS IsSuccessful
                , N'تم تنفيذ طلب النقل بنجاح' AS Message_
                , @NewVehicleWithUsersID AS vehicleWithUsersID;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- CLOSE
    ----------------------------------------------------------------
    IF @ActionType = N'CLOSE'
    BEGIN
        BEGIN TRY
            IF @requestID IS NULL OR @requestID <= 0
            BEGIN THROW 50001, N'requestID مطلوب', 1; RETURN; END

            IF @actionBy IS NULL OR @actionBy <= 0
            BEGIN THROW 50001, N'actionBy مطلوب', 1; RETURN; END

            IF @IdaraID_BIG IS NULL
            BEGIN THROW 50001, N'idaraID_FK مطلوب', 1; RETURN; END

            IF NOT EXISTS (
                SELECT 1
                FROM VIC.VehicleTransferRequest
                WHERE RequestID = @requestID
                  AND ISNULL(active,0) = 1
                  AND IdaraID_FK = @IdaraID_BIG
            )
            BEGIN THROW 50001, N'الطلب غير موجود أو غير نشط', 1; RETURN; END

            IF @tc = 0 BEGIN TRAN;

            UPDATE VIC.VehicleTransferRequest
            SET
                  active      = 0
                , aproveNote  = CASE WHEN @note IS NULL THEN aproveNote ELSE LEFT(@note,200) END
                , entryDate   = @Now
                , entryData   = CONVERT(NVARCHAR(40), @actionBy)
                , hostName    = LEFT(@hostName,200)
            WHERE RequestID = @requestID
              AND IdaraID_FK = @IdaraID_BIG;

            IF @@ROWCOUNT <= 0
            BEGIN THROW 50002, N'لم يتم تحديث أي سجل', 1; RETURN; END

            IF NOT EXISTS (
                SELECT 1
                FROM VIC.VehicleTransferRequestHistory h
                WHERE h.RequestID_FK = @requestID
                  AND h.HistoryID = (
                        SELECT MAX(HistoryID)
                        FROM VIC.VehicleTransferRequestHistory
                        WHERE RequestID_FK = @requestID
                  )
                  AND h.Status = N'Closed'
            )
            BEGIN
                INSERT INTO VIC.VehicleTransferRequestHistory
                (
                      RequestID_FK
                    , Status
                    , ActionBy
                    , ActionDate
                    , Notes
                    , hostName
                    , entryDate
                    , entryData
                )
                VALUES
                (
                      @requestID
                    , N'Closed'
                    , @actionBy
                    , @Now
                    , LEFT(@note,1000)
                    , LEFT(@hostName,200)
                    , @Now
                    , CONVERT(NVARCHAR(40), @actionBy)
                );
            END

            SET @Note_Audit = N'{"RequestID":"' + CONVERT(NVARCHAR(20), @requestID)
                + N'","Action":"CLOSE","entryData":"' + ISNULL(@entryData, N'') + N'"}';

            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[VehicleTransferRequest]', N'CLOSE', @requestID, @entryData, @Note_Audit);

            IF @tc = 0 COMMIT;

            SELECT 1 AS IsSuccessful, N'تم إغلاق الطلب' AS Message_;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- UPSERT_REQUEST_TYPE
    ----------------------------------------------------------------
    IF @ActionType = N'UPSERT_REQUEST_TYPE'
    BEGIN
        BEGIN TRY
            DECLARE @NameA_Trim NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@requestTypeNameA)), N'');
            DECLARE @NameE_Trim NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@requestTypeNameE)), N'');
            DECLARE @IsInsert BIT = CASE WHEN @requestTypeID IS NULL THEN 1 ELSE 0 END;

            IF @NameA_Trim IS NULL
            BEGIN THROW 50001, N'اسم النوع العربي مطلوب', 1; RETURN; END

            IF EXISTS (
                SELECT 1
                FROM VIC.VehicleTransferRequestType AS t
                WHERE t.VehicleTransferRequestTypeNameA = @NameA_Trim
                  AND (@requestTypeID IS NULL OR t.VehicleTransferRequestTypeID <> @requestTypeID)
            )
            BEGIN THROW 50001, N'اسم النوع العربي موجود مسبقاً', 1; RETURN; END

            IF @tc = 0 BEGIN TRAN;

            IF @IsInsert = 1
            BEGIN
                INSERT INTO VIC.VehicleTransferRequestType
                (
                      VehicleTransferRequestTypeNameA
                    , VehicleTransferRequestTypeNameE
                    , Active
                )
                VALUES
                (
                      @NameA_Trim
                    , @NameE_Trim
                    , @typeActive
                );

                SET @requestTypeID = CONVERT(INT, SCOPE_IDENTITY());

                IF @requestTypeID IS NULL OR @requestTypeID <= 0
                BEGIN THROW 50002, N'فشل إضافة نوع طلب النقل', 1; RETURN; END
            END
            ELSE
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM VIC.VehicleTransferRequestType WHERE VehicleTransferRequestTypeID = @requestTypeID)
                BEGIN THROW 50001, N'السجل غير موجود للتعديل', 1; RETURN; END

                UPDATE VIC.VehicleTransferRequestType
                SET
                      VehicleTransferRequestTypeNameA = @NameA_Trim
                    , VehicleTransferRequestTypeNameE = @NameE_Trim
                    , Active = @typeActive
                WHERE VehicleTransferRequestTypeID = @requestTypeID;

                IF @@ROWCOUNT <= 0
                BEGIN THROW 50002, N'لم يتم تعديل أي سجل', 1; RETURN; END
            END

            IF @tc = 0 COMMIT;

            SELECT
                  1 AS IsSuccessful
                , CASE WHEN @IsInsert = 1 THEN N'تمت الإضافة بنجاح' ELSE N'تم التعديل بنجاح' END AS Message_;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- Unknown ActionType
    ----------------------------------------------------------------
    ;THROW 50001, N'نوع العملية غير معروف في الإجراء TransferRequestSP', 1;
    RETURN;
END