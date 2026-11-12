CREATE   PROCEDURE VIC.VehicleUserSP
(
      @ActionType          NVARCHAR(100)
    , @vehicleUserID       INT            = NULL
    , @generalNo           BIGINT         = NULL
    , @nationalID          NVARCHAR(20)   = NULL
    , @mobileNo            NVARCHAR(20)   = NULL
    , @IdaraID_FK          NVARCHAR(10)   = NULL
    , @userActive          BIT            = 1
    , @entryData           NVARCHAR(40)   = NULL
    , @hostName            NVARCHAR(400)  = NULL
    , @rankID_FK           INT            = NULL
    , @nationalityID_FK    INT            = NULL
    , @genderID_FK         INT            = NULL
    , @firstName_A         NVARCHAR(50)   = NULL
    , @secondName_A        NVARCHAR(50)   = NULL
    , @thirdName_A         NVARCHAR(50)   = NULL
    , @lastName_A          NVARCHAR(50)   = NULL
    , @firstName_E         NVARCHAR(50)   = NULL
    , @secondName_E        NVARCHAR(50)   = NULL
    , @thirdName_E         NVARCHAR(50)   = NULL
    , @lastName_E          NVARCHAR(50)   = NULL
    , @note                NVARCHAR(1000) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @tc INT = @@TRANCOUNT;
    DECLARE @IdaraID_BIG BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@IdaraID_FK)), N''));
    DECLARE @Note_Audit NVARCHAR(MAX);
    DECLARE @NewID INT;

    IF @ActionType = 'UPSERT'
    BEGIN
        DECLARE @AuditAction NVARCHAR(20);
        BEGIN TRY
            IF @IdaraID_BIG IS NULL BEGIN THROW 50001, N'معرف الإدارة مطلوب', 1; RETURN; END
            IF @tc = 0 BEGIN TRAN;

            IF @vehicleUserID IS NULL
            BEGIN
                IF @generalNo IS NOT NULL AND EXISTS (SELECT 1 FROM VIC.VehicleUser u WHERE u.generalNo = @generalNo)
                BEGIN THROW 50001, N'يوجد مستخدم آخر مسجل بهذا الرقم العام', 1; RETURN; END

                INSERT INTO VIC.VehicleUser (generalNo, nationalID, mobileNo, IdaraID_FK, userActive, entryDate, entryData, hostName)
                VALUES (@generalNo, @nationalID, @mobileNo, @IdaraID_BIG, @userActive, GETDATE(), @entryData, @hostName);

                SET @vehicleUserID = CONVERT(INT, SCOPE_IDENTITY());
                IF @vehicleUserID IS NULL OR @vehicleUserID <= 0 BEGIN THROW 50002, N'فشل إنشاء المستخدم', 1; RETURN; END
                SET @AuditAction = N'INSERT';
            END
            ELSE
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM VIC.VehicleUser u WHERE u.vehicleUserID = @vehicleUserID)
                BEGIN THROW 50001, N'المستخدم غير موجود', 1; RETURN; END
                IF @generalNo IS NOT NULL AND EXISTS (SELECT 1 FROM VIC.VehicleUser u WHERE u.generalNo = @generalNo AND u.vehicleUserID <> @vehicleUserID)
                BEGIN THROW 50001, N'يوجد مستخدم آخر مسجل بهذا الرقم العام', 1; RETURN; END

                UPDATE VIC.VehicleUser
                SET generalNo = @generalNo, nationalID = @nationalID, mobileNo = @mobileNo
                  , IdaraID_FK = @IdaraID_BIG, entryDate = GETDATE(), entryData = @entryData, hostName = @hostName
                WHERE vehicleUserID = @vehicleUserID;
                IF @@ROWCOUNT <= 0 BEGIN THROW 50002, N'فشل تحديث المستخدم', 1; RETURN; END
                SET @AuditAction = N'UPDATE';
            END

            UPDATE VIC.VehicleUserDetails SET detailsActive = 0, detailsEndDate = GETDATE()
            WHERE vehicleUserID_FK = @vehicleUserID AND detailsActive = 1;

            IF @firstName_A IS NOT NULL OR @secondName_A IS NOT NULL OR @thirdName_A IS NOT NULL OR @lastName_A IS NOT NULL
            BEGIN
                INSERT INTO VIC.VehicleUserDetails (
                    vehicleUserID_FK, generalNo_Snapshot, rankID_FK, nationalityID_FK, genderID_FK,
                    firstName_A, secondName_A, thirdName_A, lastName_A,
                    firstName_E, secondName_E, thirdName_E, lastName_E,
                    note, detailsStartDate, detailsActive, IdaraID_FK, entryDate, entryData, hostName)
                VALUES (
                    @vehicleUserID, @generalNo, @rankID_FK, @nationalityID_FK, @genderID_FK,
                    @firstName_A, @secondName_A, @thirdName_A, @lastName_A,
                    @firstName_E, @secondName_E, @thirdName_E, @lastName_E,
                    @note, GETDATE(), 1, @IdaraID_BIG, GETDATE(), @entryData, @hostName);
            END

            SET @NewID = @vehicleUserID;
            SET @Note_Audit = N'{"vehicleUserID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleUserID), N'') + N'","generalNo":"' + ISNULL(CONVERT(NVARCHAR(MAX), @generalNo), N'') + N'"}';
            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[VehicleUser]', @AuditAction, ISNULL(@NewID, 0), @entryData, @Note_Audit);
            IF @tc = 0 COMMIT;
            SELECT CAST(1 AS BIT) AS IsSuccessful, N'تم حفظ المستخدم بنجاح' AS Message_, @vehicleUserID AS VehicleUserID;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    IF @ActionType = 'SET_ACTIVE'
    BEGIN
        BEGIN TRY
            IF @vehicleUserID IS NULL OR @vehicleUserID <= 0 BEGIN THROW 50001, N'معرف مستخدم المركبة مطلوب', 1; RETURN; END
            IF NOT EXISTS (SELECT 1 FROM VIC.VehicleUser u WHERE u.vehicleUserID = @vehicleUserID) BEGIN THROW 50001, N'المستخدم غير موجود', 1; RETURN; END
            IF @tc = 0 BEGIN TRAN;
            UPDATE VIC.VehicleUser SET userActive = @userActive, entryDate = GETDATE(), entryData = @entryData, hostName = @hostName WHERE vehicleUserID = @vehicleUserID;
            IF @@ROWCOUNT <= 0 BEGIN THROW 50002, N'فشل تحديث حالة المستخدم', 1; RETURN; END
            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[VehicleUser]', N'SET_ACTIVE', @vehicleUserID, @entryData, N'{"vehicleUserID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleUserID), N'') + N'","userActive":"' + ISNULL(CONVERT(NVARCHAR(10), @userActive), N'') + N'"}');
            IF @tc = 0 COMMIT;
            SELECT CAST(1 AS BIT) AS IsSuccessful, CASE WHEN @userActive = 1 THEN N'تم تفعيل المستخدم' ELSE N'تم إلغاء تفعيل المستخدم' END AS Message_;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    BEGIN THROW 50001, N'نوع العملية غير معروف في إجراء معالجة مستخدمي المركبات', 1; RETURN; END
END

GO

