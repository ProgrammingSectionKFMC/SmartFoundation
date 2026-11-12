CREATE   PROCEDURE VIC.CustodySP
(
      @ActionType           NVARCHAR(100)
    , @vehicleID            INT            = NULL
    , @chassisNumber        NVARCHAR(200)  = NULL
    , @vehicleUserID_FK     INT            = NULL
    , @startDate            DATETIME       = NULL
    , @note                 NVARCHAR(2000) = NULL
    , @idaraID_FK           NVARCHAR(10)   = NULL
    , @entryData            NVARCHAR(40)   = NULL
    , @hostName             NVARCHAR(400)  = NULL
    , @handOverTypeID       INT            = NULL
    , @handoverDate         DATETIME       = NULL
    , @handoverNote         NVARCHAR(1000) = NULL
    , @handoverTypeNameA    NVARCHAR(100)  = NULL
    , @handoverTypeNameE    NVARCHAR(100)  = NULL
    , @active               BIT            = 1
    , @vehicleWithUsersID   INT            = NULL
    , @endDate              DATETIME       = NULL
    , @handOverTypeID_Param INT            = NULL
    , @createGeneralNo      BIGINT         = NULL
    , @createNationalID     NVARCHAR(20)   = NULL
    , @createMobileNo       NVARCHAR(20)   = NULL
    , @createRankID_FK      INT            = NULL
    , @createNationalityID_FK INT          = NULL
    , @createGenderID_FK    INT            = NULL
    , @createFirstName_A    NVARCHAR(50)   = NULL
    , @createSecondName_A   NVARCHAR(50)   = NULL
    , @createThirdName_A    NVARCHAR(50)   = NULL
    , @createLastName_A     NVARCHAR(50)   = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @tc INT = @@TRANCOUNT;
    DECLARE @CH NVARCHAR(200);
    DECLARE @VID INT;

    IF @vehicleID IS NOT NULL
    BEGIN
        SELECT @CH = v.chassisNumber, @VID = v.vehicleID FROM VIC.Vehicles v WHERE v.vehicleID = @vehicleID;
        IF @CH IS NULL BEGIN THROW 50001, N'المركبة غير موجودة بالمعرف المحدد', 1; RETURN; END
    END
    ELSE IF @chassisNumber IS NOT NULL
    BEGIN
        SET @CH = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
        SELECT @VID = v.vehicleID FROM VIC.Vehicles v WHERE v.chassisNumber = @CH;
    END

    DECLARE @SD DATETIME = ISNULL(@startDate, GETDATE());
    DECLARE @ED DATETIME = ISNULL(@endDate, GETDATE());
    DECLARE @IdaraID_BIG BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));
    DECLARE @Note_Audit NVARCHAR(MAX);
    DECLARE @NewID INT;
    DECLARE @HT_Receive INT = 1;
    DECLARE @HT_Return  INT = 2;

    IF NOT EXISTS (SELECT 1 FROM VIC.HandoverType WHERE handOverTypeID = @HT_Receive AND ISNULL(active, 1) = 1)
    BEGIN THROW 50002, N'نوع محضر الاستلام غير مهيأ (المعرف 1)', 1; RETURN; END
    IF NOT EXISTS (SELECT 1 FROM VIC.HandoverType WHERE handOverTypeID = @HT_Return AND ISNULL(active, 1) = 1)
    BEGIN THROW 50002, N'نوع محضر الإرجاع غير مهيأ (المعرف 2)', 1; RETURN; END

    IF @ActionType IN ('CREATE', 'INSERTCUSTODY')
    BEGIN
        BEGIN TRY
            IF @CH IS NULL BEGIN THROW 50001, N'رقم الهيكل أو معرف المركبة مطلوب', 1; RETURN; END
            IF @VID IS NULL BEGIN THROW 50001, N'المركبة غير موجودة', 1; RETURN; END
            IF @IdaraID_BIG IS NULL BEGIN THROW 50001, N'معرف الإدارة مطلوب', 1; RETURN; END

            IF NOT EXISTS (SELECT 1 FROM VIC.Vehicles v WHERE v.chassisNumber = @CH AND v.IdaraID_FK = @IdaraID_BIG)
            BEGIN THROW 50001, N'المركبة غير موجودة أو لا تتبع الإدارة الحالية', 1; RETURN; END

            IF EXISTS (SELECT 1 FROM VIC.Vehicles v WHERE v.chassisNumber = @CH AND v.IdaraID_FK = @IdaraID_BIG AND v.vehicleStatusID_FK IN (261, 262))
            BEGIN THROW 50001, N'لا يمكن إنشاء عهدة لأن المركبة خارج الخدمة أو متلفة', 1; RETURN; END

            IF EXISTS (SELECT 1 FROM VIC.vehicleWithUsers w INNER JOIN VIC.Vehicles v ON v.chassisNumber = w.chassisNumber_FK WHERE w.chassisNumber_FK = @CH AND w.endDate IS NULL AND v.IdaraID_FK = @IdaraID_BIG)
            BEGIN THROW 50001, N'للمركبة عهدة نشطة مسبقًا في الإدارة الحالية', 1; RETURN; END

            DECLARE @ResolvedVehicleUserID INT = @vehicleUserID_FK;

            IF (@ResolvedVehicleUserID IS NULL OR @ResolvedVehicleUserID <= 0) AND @createGeneralNo IS NOT NULL
            BEGIN
                SELECT @ResolvedVehicleUserID = u.vehicleUserID
                FROM VIC.VehicleUser u WHERE u.generalNo = @createGeneralNo AND u.IdaraID_FK = @IdaraID_BIG AND u.userActive = 1;

                IF @ResolvedVehicleUserID IS NULL
                BEGIN
                    IF EXISTS (SELECT 1 FROM VIC.VehicleUser u WHERE u.generalNo = @createGeneralNo)
                    BEGIN THROW 50001, N'يوجد مستخدم بهذا الرقم العام في إدارة أخرى', 1; RETURN; END

                    INSERT INTO VIC.VehicleUser (generalNo, nationalID, mobileNo, IdaraID_FK, userActive, entryDate, entryData, hostName)
                    VALUES (@createGeneralNo, @createNationalID, @createMobileNo, @IdaraID_BIG, 1, GETDATE(), @entryData, @hostName);

                    SET @ResolvedVehicleUserID = CONVERT(INT, SCOPE_IDENTITY());
                    IF @ResolvedVehicleUserID IS NULL OR @ResolvedVehicleUserID <= 0 BEGIN THROW 50002, N'فشل إنشاء مستخدم المركبة', 1; RETURN; END

                    IF @createFirstName_A IS NOT NULL OR @createLastName_A IS NOT NULL
                        INSERT INTO VIC.VehicleUserDetails (
                            vehicleUserID_FK, generalNo_Snapshot, rankID_FK, nationalityID_FK, genderID_FK,
                            firstName_A, secondName_A, thirdName_A, lastName_A,
                            detailsStartDate, detailsActive, IdaraID_FK, entryDate, entryData, hostName)
                        VALUES (
                            @ResolvedVehicleUserID, @createGeneralNo, @createRankID_FK, @createNationalityID_FK, @createGenderID_FK,
                            @createFirstName_A, @createSecondName_A, @createThirdName_A, @createLastName_A,
                            GETDATE(), 1, @IdaraID_BIG, GETDATE(), @entryData, @hostName);
                END
            END

            IF @ResolvedVehicleUserID IS NULL OR @ResolvedVehicleUserID <= 0
            BEGIN THROW 50001, N'تعذر تحديد مستخدم المركبة', 1; RETURN; END

            DECLARE @GeneralNo_Snap NVARCHAR(50);
            DECLARE @UserFullName_Snap NVARCHAR(200);
            DECLARE @RankName_Snap NVARCHAR(200);

            SELECT @GeneralNo_Snap = CAST(u.generalNo AS NVARCHAR(50))
                 , @UserFullName_Snap = CONCAT_WS(N' ', ud.firstName_A, ud.secondName_A, ud.thirdName_A, ud.lastName_A)
                 , @RankName_Snap = r.rankName_A
            FROM VIC.VehicleUser u
            LEFT JOIN VIC.VehicleUserDetails ud ON ud.vehicleUserID_FK = u.vehicleUserID AND ud.detailsActive = 1
            LEFT JOIN VIC.VehicleRank r ON r.rankID = ud.rankID_FK
            WHERE u.vehicleUserID = @ResolvedVehicleUserID;

            IF @tc = 0 BEGIN TRAN;

            INSERT INTO VIC.vehicleWithUsers (vehicleUserID_FK, vehicleID_FK, startDate, endDate, note, entryDate, entryData, hostName, chassisNumber_FK, GeneralNo_Snapshot, UserFullName_Snapshot, RankName_Snapshot, OrgSnapshotDate)
            VALUES (@ResolvedVehicleUserID, @VID, @SD, NULL, @note, GETDATE(), @entryData, @hostName, @CH, @GeneralNo_Snap, @UserFullName_Snap, @RankName_Snap, GETDATE());

            SET @NewID = CONVERT(INT, SCOPE_IDENTITY());
            IF @NewID IS NULL OR @NewID <= 0 BEGIN THROW 50002, N'فشل إنشاء سجل العهدة', 1; RETURN; END

            INSERT INTO VIC.VehicleHandover (handOverTypeID_FK, handoverDate, note, entryDate, entryData, hostName, chassisNumber_FK, vehicleID_FK, vehicleUserID_FK, IdaraID_FK)
            VALUES (@HT_Receive, ISNULL(@handoverDate, @SD), ISNULL(@handoverNote, @note), GETDATE(), @entryData, @hostName, @CH, @VID, @ResolvedVehicleUserID, @IdaraID_BIG);

            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[vehicleWithUsers]', N'INSERT', @NewID, @entryData, N'{"vehicleWithUsersID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), N'') + N'","chassisNumber":"' + ISNULL(@CH, N'') + N'","vehicleUserID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @ResolvedVehicleUserID), N'') + N'"}');

            IF @tc = 0 COMMIT;
            SELECT CAST(1 AS BIT) AS IsSuccessful, N'تم إنشاء العهدة بنجاح' AS Message_, @NewID AS vehicleWithUsersID;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    IF @ActionType IN ('CLOSE', 'CLOSECUSTODY')
    BEGIN
        BEGIN TRY
            IF @vehicleWithUsersID IS NULL OR @vehicleWithUsersID <= 0 BEGIN THROW 50001, N'معرف عهدة المركبة مطلوب', 1; RETURN; END
            IF @IdaraID_BIG IS NULL BEGIN THROW 50001, N'معرف الإدارة مطلوب', 1; RETURN; END
            IF NOT EXISTS (SELECT 1 FROM VIC.vehicleWithUsers w WHERE w.vehicleWithUsersID = @vehicleWithUsersID AND w.endDate IS NULL)
            BEGIN THROW 50001, N'سجل العهدة غير موجود أو مغلق مسبقًا', 1; RETURN; END

            DECLARE @CurrentStartDate DATETIME;
            DECLARE @CurrentChassisNumber NVARCHAR(200);
            DECLARE @CloseVehicleID INT;
            DECLARE @CloseVehicleUserID INT;

            SELECT @CurrentStartDate = w.startDate, @CurrentChassisNumber = w.chassisNumber_FK, @CloseVehicleID = v.vehicleID, @CloseVehicleUserID = w.vehicleUserID_FK
            FROM VIC.vehicleWithUsers w INNER JOIN VIC.Vehicles v ON v.chassisNumber = w.chassisNumber_FK WHERE w.vehicleWithUsersID = @vehicleWithUsersID;

            IF @CurrentStartDate IS NOT NULL AND @ED < @CurrentStartDate BEGIN THROW 50001, N'يجب أن يكون تاريخ النهاية مساويًا لتاريخ البداية أو بعده', 1; RETURN; END
            IF EXISTS (SELECT 1 FROM VIC.Vehicles v WHERE v.chassisNumber = @CurrentChassisNumber AND v.vehicleStatusID_FK IN (261, 262))
            BEGIN THROW 50001, N'لا يمكن إغلاق العهدة لأن المركبة خارج الخدمة أو متلفة', 1; RETURN; END

            IF @tc = 0 BEGIN TRAN;

            UPDATE VIC.vehicleWithUsers SET endDate = @ED, note = CASE WHEN @note IS NULL THEN note ELSE @note END, entryDate = GETDATE(), entryData = @entryData, hostName = @hostName
            WHERE vehicleWithUsersID = @vehicleWithUsersID AND endDate IS NULL;
            IF @@ROWCOUNT <= 0 BEGIN THROW 50002, N'فشل إغلاق العهدة', 1; RETURN; END

            INSERT INTO VIC.VehicleHandover (handOverTypeID_FK, handoverDate, note, entryDate, entryData, hostName, chassisNumber_FK, vehicleID_FK, vehicleUserID_FK, IdaraID_FK)
            VALUES (@HT_Return, @ED, ISNULL(@handoverNote, @note), GETDATE(), @entryData, @hostName, @CurrentChassisNumber, @CloseVehicleID, @CloseVehicleUserID, @IdaraID_BIG);

            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[vehicleWithUsers]', N'UPDATE', @vehicleWithUsersID, @entryData, N'{"vehicleWithUsersID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleWithUsersID), N'') + N'","endDate":"' + ISNULL(CONVERT(NVARCHAR(MAX), @ED, 121), N'') + N'"}');

            IF @tc = 0 COMMIT;
            SELECT CAST(1 AS BIT) AS IsSuccessful, N'تم إغلاق العهدة بنجاح' AS Message_;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    IF @ActionType = 'UPSERT_HANDOVER_TYPE'
    BEGIN
        BEGIN TRY
            DECLARE @NameA NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@handoverTypeNameA)), N'');
            DECLARE @NameE NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@handoverTypeNameE)), N'');
            DECLARE @AuditAction NVARCHAR(20);

            IF @NameA IS NULL BEGIN THROW 50001, N'الاسم العربي لنوع المحضر مطلوب', 1; RETURN; END
            IF EXISTS (SELECT 1 FROM VIC.HandoverType ht WHERE ht.handOverTypeName_A = @NameA AND (@handOverTypeID_Param IS NULL OR ht.handOverTypeID <> @handOverTypeID_Param))
            BEGIN THROW 50001, N'يوجد نوع محضر بهذا الاسم العربي مسبقًا', 1; RETURN; END

            IF @tc = 0 BEGIN TRAN;

            IF @handOverTypeID_Param IS NULL
            BEGIN
                INSERT INTO VIC.HandoverType (handOverTypeName_A, handOverTypeName_E, active) VALUES (@NameA, @NameE, @active);
                SET @NewID = CONVERT(INT, SCOPE_IDENTITY());
                IF @NewID IS NULL OR @NewID <= 0 BEGIN THROW 50002, N'فشل إنشاء نوع المحضر', 1; RETURN; END
                SET @AuditAction = N'INSERT';
            END
            ELSE
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM VIC.HandoverType WHERE handOverTypeID = @handOverTypeID_Param) BEGIN THROW 50001, N'نوع المحضر غير موجود', 1; RETURN; END
                UPDATE VIC.HandoverType SET handOverTypeName_A = @NameA, handOverTypeName_E = @NameE, active = @active WHERE handOverTypeID = @handOverTypeID_Param;
                IF @@ROWCOUNT <= 0 BEGIN THROW 50002, N'فشل تحديث نوع المحضر', 1; RETURN; END
                SET @NewID = @handOverTypeID_Param;
                SET @AuditAction = N'UPDATE';
            END

            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[HandoverType]', @AuditAction, @NewID, @entryData, N'{"handOverTypeID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), N'') + N'","handOverTypeName_A":"' + ISNULL(@NameA, N'') + N'"}');

            IF @tc = 0 COMMIT;
            SELECT CAST(1 AS BIT) AS IsSuccessful, CASE WHEN @handOverTypeID_Param IS NULL THEN N'تم إنشاء نوع محضر التسليم والاستلام' ELSE N'تم تحديث نوع محضر التسليم والاستلام' END AS Message_;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    BEGIN THROW 50001, N'نوع العملية غير معروف في إجراء معالجة العهد', 1; RETURN; END
END

GO

