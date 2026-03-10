
CREATE PROCEDURE [dbo].[PermissionSP]
(
      @Action                             NVARCHAR(200)
    , @PermissionID                       BIGINT          = NULL
    , @DistributorPermissionTypeID_FK     BIGINT          = NULL
    , @UsersID                            NVARCHAR(100)   = NULL
    , @RoleID                             NVARCHAR(100)   = NULL
    , @distributorID                      NVARCHAR(100)   = NULL
    , @IdaraID                            NVARCHAR(100)   = NULL
    , @DeptID                             NVARCHAR(100)   = NULL
    , @SectionID                          NVARCHAR(100)   = NULL
    , @DivisonID                          NVARCHAR(100)   = NULL
    , @searchID                           BIGINT          = NULL
    , @permissionStartDate                NVARCHAR(1000)  = NULL
    , @permissionEndDate                  NVARCHAR(1000)  = NULL
    , @permissionNote                     NVARCHAR(2000)  = NULL
    , @permissionActive                   BIT             = NULL
    , @InIdaraID                          NVARCHAR(100)   = NULL
    , @entryData                          NVARCHAR(20)    = NULL
    , @hostName                           NVARCHAR(200)   = NULL
    , @distributorIDFroGiveAllPermissions BIGINT          = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE
          @NewID BIGINT = NULL
        , @Note  NVARCHAR(MAX) = NULL
        , @Rows  INT = 0
        , @DSDID BIGINT = NULL;

    -- تواريخ (تحويل آمن)
    DECLARE @StartDT DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@permissionStartDate)), ''), 120);
    DECLARE @EndDT   DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@permissionEndDate)), ''), 120);

    BEGIN TRY
        -- Transaction-safe
        IF @tc = 0
            BEGIN TRAN;

        ----------------------------------------------------------------
        -- Business validations => THROW 50001 (داخل BEGIN/END + ; قبل THROW)
        ----------------------------------------------------------------
        IF NULLIF(LTRIM(RTRIM(@Action)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'العملية مطلوبة', 1;
        END

        IF (@StartDT IS NOT NULL AND @EndDT IS NOT NULL AND @EndDT <= @StartDT)
        BEGIN
            ;THROW 50001, N'لايمكن ان يكون تاريخ النهاية اصغر من او مساوي لتاريخ البداية', 1;
        END

        IF (@StartDT IS NOT NULL AND @StartDT < CAST(GETDATE() AS DATE))
        BEGIN
            ;THROW 50001, N'لايمكن ان يكون تاريخ البداية اصغر من تاريخ اليوم', 1;
        END

        IF (@EndDT IS NOT NULL AND @EndDT <= CAST(GETDATE() AS DATE))
        BEGIN
            ;THROW 50001, N'لايمكن ان يكون تاريخ النهاية اصغر من او مساوي لتاريخ اليوم', 1;
        END

        ----------------------------------------------------------------
        -- تحديث صلاحيات منتهية (كما عندك)
        ----------------------------------------------------------------
        UPDATE  dbo.Permission
        SET permissionActive = 0
        WHERE permissionEndDate IS NOT NULL
          AND CAST(permissionEndDate AS DATE) < CAST(GETDATE() AS DATE);

        UPDATE  dbo.Permission
        SET permissionEndDate = CAST(GETDATE() AS DATE)
        WHERE permissionActive = 0
          AND permissionEndDate IS NULL;

        UPDATE  dbo.UserDistributor
        SET UDActive = 0
        WHERE UDEndDate IS NOT NULL
          AND CAST(UDEndDate AS DATE) < CAST(GETDATE() AS DATE);

        UPDATE  dbo.UserDistributor
        SET UDEndDate = CAST(GETDATE() AS DATE)
        WHERE UDActive = 0
          AND UDEndDate IS NULL;

        ----------------------------------------------------------------
        -- DSDID (فقط إذا searchID = 5)
        ----------------------------------------------------------------
        IF ISNULL(@searchID, 0) = 5
        BEGIN
            IF (@IdaraID IS NOT NULL AND @DeptID IS NULL AND @SectionID IS NULL AND @DivisonID IS NULL)
            BEGIN
                SELECT @DSDID = dsd.DSDID
                FROM  dbo.DeptSecDiv dsd
                WHERE dsd.idaraID_FK = @IdaraID
                  AND dsd.deptID_FK IS NULL AND dsd.secID_FK IS NULL AND dsd.divID_FK IS NULL;
            END
            ELSE IF (@IdaraID IS NOT NULL AND @DeptID IS NOT NULL AND @SectionID IS NULL AND @DivisonID IS NULL)
            BEGIN
                SELECT @DSDID = dsd.DSDID
                FROM  dbo.DeptSecDiv dsd
                WHERE dsd.idaraID_FK = @IdaraID
                  AND dsd.deptID_FK = @DeptID
                  AND dsd.secID_FK IS NULL AND dsd.divID_FK IS NULL;
            END
            ELSE IF (@IdaraID IS NOT NULL AND @DeptID IS NOT NULL AND @SectionID IS NOT NULL AND @DivisonID IS NULL)
            BEGIN
                SELECT @DSDID = dsd.DSDID
                FROM  dbo.DeptSecDiv dsd
                WHERE dsd.idaraID_FK = @IdaraID
                  AND dsd.deptID_FK = @DeptID
                  AND dsd.secID_FK = @SectionID
                  AND dsd.divID_FK IS NULL;
            END
            ELSE IF (@IdaraID IS NOT NULL AND @DeptID IS NOT NULL AND @SectionID IS NOT NULL AND @DivisonID IS NOT NULL)
            BEGIN
                SELECT @DSDID = dsd.DSDID
                FROM  dbo.DeptSecDiv dsd
                WHERE dsd.idaraID_FK = @IdaraID
                  AND dsd.deptID_FK = @DeptID
                  AND dsd.secID_FK = @SectionID
                  AND dsd.divID_FK = @DivisonID;
            END
            ELSE
            BEGIN
                ;THROW 50001, N'حصل خطأ غير متوقع في تحديد DSDID', 1;
            END

            IF @DSDID IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ ما - DSDID غير موجود', 1;
            END
        END

        ----------------------------------------------------------------
        -- INSERT
        ----------------------------------------------------------------
        IF @Action = N'INSERT'
        BEGIN
            IF (ISNULL(@searchID,0) = 1 AND (NULLIF(LTRIM(RTRIM(@UsersID)), N'') IS NULL))
            BEGIN
                ;THROW 50001, N'الرجاء اختيار المستخدم اولا', 1;
            END

            IF (ISNULL(@searchID,0) = 2 AND (NULLIF(LTRIM(RTRIM(@distributorID)), N'') IS NULL))
            BEGIN
                ;THROW 50001, N'الرجاء اختيار الموزع اولا', 1;
            END

            IF (ISNULL(@searchID,0) = 3 AND (NULLIF(LTRIM(RTRIM(@RoleID)), N'') IS NULL))
            BEGIN
                ;THROW 50001, N'الرجاء اختيار الدور اولا', 1;
            END

            IF (ISNULL(@searchID,0) = 4 AND (NULLIF(LTRIM(RTRIM(@IdaraID)), N'') IS NULL))
            BEGIN
                ;THROW 50001, N'الرجاء اختيار الادارة اولا', 1;
            END

            IF (ISNULL(@searchID,0) = 5
                AND (NULLIF(LTRIM(RTRIM(@DeptID)), N'') IS NULL)
                AND (NULLIF(LTRIM(RTRIM(@SectionID)), N'') IS NULL)
                AND (NULLIF(LTRIM(RTRIM(@DivisonID)), N'') IS NULL))
            BEGIN
                ;THROW 50001, N'الرجاء اختيار القسم اولا', 1;
            END

            IF NULLIF(@DistributorPermissionTypeID_FK, 0) IS NULL
            BEGIN
                ;THROW 50001, N'نوع الصلاحية مطلوب', 1;
            END

            DECLARE @Flag INT = 0;

            IF ISNULL(@searchID,0) = 1
            BEGIN
                SELECT @Flag = COUNT(*)
                FROM  dbo.Permission p
                JOIN  dbo.DistributorPermissionType dt
                  ON p.DistributorPermissionTypeID_FK = dt.distributorPermissionTypeID
                WHERE p.DistributorPermissionTypeID_FK = @DistributorPermissionTypeID_FK
                  AND p.permissionActive = 1
                  AND dt.distributorPermissionTypeActive = 1
                  AND (p.permissionEndDate IS NULL OR CONVERT(date, p.permissionEndDate) > CONVERT(date, GETDATE()))
                  AND p.UsersID_FK = @UsersID;
            END
            ELSE IF ISNULL(@searchID,0) = 2
            BEGIN
                SELECT @Flag = COUNT(*)
                FROM  dbo.Permission p
                JOIN  dbo.DistributorPermissionType dt
                  ON p.DistributorPermissionTypeID_FK = dt.distributorPermissionTypeID
                WHERE p.DistributorPermissionTypeID_FK = @DistributorPermissionTypeID_FK
                  AND p.permissionActive = 1
                  AND dt.distributorPermissionTypeActive = 1
                  AND (p.permissionEndDate IS NULL OR CONVERT(date, p.permissionEndDate) > CONVERT(date, GETDATE()))
                  AND p.distributorID_FK = @distributorID;
            END
            ELSE IF ISNULL(@searchID,0) = 3
            BEGIN
                SELECT @Flag = COUNT(*)
                FROM  dbo.Permission p
                JOIN  dbo.DistributorPermissionType dt
                  ON p.DistributorPermissionTypeID_FK = dt.distributorPermissionTypeID
                WHERE p.DistributorPermissionTypeID_FK = @DistributorPermissionTypeID_FK
                  AND p.permissionActive = 1
                  AND dt.distributorPermissionTypeActive = 1
                  AND (p.permissionEndDate IS NULL OR CONVERT(date, p.permissionEndDate) > CONVERT(date, GETDATE()))
                  AND p.RoleID_FK = @RoleID;
            END
            ELSE IF ISNULL(@searchID,0) = 4
            BEGIN
                SELECT @Flag = COUNT(*)
                FROM  dbo.Permission p
                JOIN  dbo.DistributorPermissionType dt
                  ON p.DistributorPermissionTypeID_FK = dt.distributorPermissionTypeID
                WHERE p.DistributorPermissionTypeID_FK = @DistributorPermissionTypeID_FK
                  AND p.permissionActive = 1
                  AND dt.distributorPermissionTypeActive = 1
                  AND (p.permissionEndDate IS NULL OR CONVERT(date, p.permissionEndDate) > CONVERT(date, GETDATE()))
                  AND p.IdaraID_FK = @IdaraID;
            END
            ELSE IF ISNULL(@searchID,0) = 5
            BEGIN
                SELECT @Flag = COUNT(*)
                FROM  dbo.Permission p
                JOIN  dbo.DistributorPermissionType dt
                  ON p.DistributorPermissionTypeID_FK = dt.distributorPermissionTypeID
                WHERE p.DistributorPermissionTypeID_FK = @DistributorPermissionTypeID_FK
                  AND p.permissionActive = 1
                  AND dt.distributorPermissionTypeActive = 1
                  AND (p.permissionEndDate IS NULL OR CONVERT(date, p.permissionEndDate) > CONVERT(date, GETDATE()))
                  AND p.DSDID_FK = @DSDID;
            END
            ELSE
            BEGIN
                ;THROW 50001, N'يوجد خطأ ما - searchID غير صحيح', 1;
            END

            IF @Flag > 0
            BEGIN
                ;THROW 50001, N'البيانات مدخلة مسبقا', 1;
            END

            INSERT INTO  dbo.Permission
            (
                  DistributorPermissionTypeID_FK
                , UsersID_FK
                , distributorID_FK
                , RoleID_FK
                , IdaraID_FK
                , DSDID_FK
                , permissionStartDate
                , permissionEndDate
                , permissionActive
                , permissionNote
                , InIdaraID
                , entryData
                , hostName
            )
            VALUES
            (
                  @DistributorPermissionTypeID_FK
                , CASE WHEN @searchID = 1 THEN @UsersID ELSE NULL END
                , CASE WHEN @searchID = 2 THEN @distributorID ELSE NULL END
                , CASE WHEN @searchID = 3 THEN @RoleID ELSE NULL END
                , CASE WHEN @searchID = 4 THEN @IdaraID ELSE NULL END
                , CASE WHEN @searchID = 5 THEN @DSDID ELSE NULL END
                , ISNULL(CONVERT(DATETIME, @StartDT), GETDATE())
                , CONVERT(DATETIME, @EndDT)
                , 1
                , @permissionNote
                , @InIdaraID
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة الصلاحية (Permission)', 1;
            END

            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة الصلاحية - Identity', 1;
            END

            SET @Note = N'{'
                + N'"PermissionID": "'                   + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"searchID": "'                      + ISNULL(CONVERT(NVARCHAR(MAX), @searchID), '') + N'"'
                + N',"UsersID_FK": "'                    + ISNULL(CONVERT(NVARCHAR(MAX), @UsersID), '') + N'"'
                + N',"distributorID_FK": "'              + ISNULL(CONVERT(NVARCHAR(MAX), @distributorID), '') + N'"'
                + N',"RoleID_FK": "'                     + ISNULL(CONVERT(NVARCHAR(MAX), @RoleID), '') + N'"'
                + N',"IdaraID_FK": "'                    + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID), '') + N'"'
                + N',"DSDID_FK": "'                      + ISNULL(CONVERT(NVARCHAR(MAX), @DSDID), '') + N'"'
                + N',"permissionStartDate": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @permissionStartDate), '') + N'"'
                + N',"permissionEndDate": "'             + ISNULL(CONVERT(NVARCHAR(MAX), @permissionEndDate), '') + N'"'
                + N',"permissionNote": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @permissionNote), '') + N'"'
                + N',"DistributorPermissionTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @DistributorPermissionTypeID_FK), '') + N'"'
                + N',"entryData": "'                     + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                      + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[dbo].[Permission]', N'INSERT', ISNULL(@NewID, 0), @entryData, @Note);

            SELECT 1 AS IsSuccessful, N'تم اضافة البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- INSERTFULLACCESS
        ----------------------------------------------------------------
        ELSE IF @Action = N'INSERTFULLACCESS'
        BEGIN
            IF (ISNULL(@searchID,0) = 1 AND (NULLIF(LTRIM(RTRIM(@UsersID)), N'') IS NULL))
            BEGIN
                ;THROW 50001, N'الرجاء اختيار المستخدم اولا', 1;
            END

            IF (ISNULL(@searchID,0) = 2 AND (NULLIF(LTRIM(RTRIM(@distributorID)), N'') IS NULL))
            BEGIN
                ;THROW 50001, N'الرجاء اختيار الموزع اولا', 1;
            END

            IF (ISNULL(@searchID,0) = 3 AND (NULLIF(LTRIM(RTRIM(@RoleID)), N'') IS NULL))
            BEGIN
                ;THROW 50001, N'الرجاء اختيار الدور اولا', 1;
            END

            IF (ISNULL(@searchID,0) = 4 AND (NULLIF(LTRIM(RTRIM(@IdaraID)), N'') IS NULL))
            BEGIN
                ;THROW 50001, N'الرجاء اختيار الادارة اولا', 1;
            END

            IF (ISNULL(@searchID,0) = 5
                AND (NULLIF(LTRIM(RTRIM(@DeptID)), N'') IS NULL)
                AND (NULLIF(LTRIM(RTRIM(@SectionID)), N'') IS NULL)
                AND (NULLIF(LTRIM(RTRIM(@DivisonID)), N'') IS NULL))
            BEGIN
                ;THROW 50001, N'الرجاء اختيار القسم اولا', 1;
            END

            IF NULLIF(@distributorIDFroGiveAllPermissions, 0) IS NULL
            BEGIN
                ;THROW 50001, N'موزع منح الصلاحيات مطلوب', 1;
            END

            -- الإدخال حسب نوع الهدف
            IF ISNULL(@searchID,0) = 1
            BEGIN
                INSERT INTO  dbo.Permission
                (
                      DistributorPermissionTypeID_FK, UsersID_FK
                    , permissionStartDate, permissionEndDate, permissionNote
                    , permissionActive,InIdaraID, entryData, hostName
                )
                SELECT
                      dt.distributorPermissionTypeID, @UsersID
                    , ISNULL(CONVERT(DATETIME, @StartDT), GETDATE())
                    , CONVERT(DATETIME, @EndDT)
                    , @permissionNote
                    , 1,@InIdaraID, @entryData, @hostName
                FROM  dbo.DistributorPermissionType dt
                INNER JOIN  dbo.PermissionType p
                    ON dt.permissionTypeID_FK = p.permissionTypeID
                WHERE dt.distributorID_FK = @distributorIDFroGiveAllPermissions
                  AND dt.distributorPermissionTypeActive = 1
                  AND p.permissionTypeActive = 1
                  AND CAST(dt.distributorPermissionTypeStartDate AS DATE) <= CAST(GETDATE() AS DATE)
                  AND (CAST(dt.distributorPermissionTypeEndDate AS DATE) > CAST(GETDATE() AS DATE)
                       OR dt.distributorPermissionTypeEndDate IS NULL)
                  AND dt.distributorPermissionTypeID NOT IN
                  (
                        SELECT r.DistributorPermissionTypeID_FK
                        FROM  dbo.Permission r
                        WHERE r.permissionActive = 1
                          AND CAST(r.permissionStartDate AS DATE) <= CAST(GETDATE() AS DATE)
                          AND (CAST(r.permissionEndDate AS DATE) > CAST(GETDATE() AS DATE)
                               OR r.permissionEndDate IS NULL)
                          AND r.UsersID_FK = @UsersID
                  );

                SET @Rows = @@ROWCOUNT;
                IF @Rows <= 0
                BEGIN
                    ;THROW 50001, N'حصل خطأ في اضافة البيانات او الموظف يملك جميع الصلاحيات', 1;
                END
            END
            ELSE IF ISNULL(@searchID,0) = 2
            BEGIN
                INSERT INTO  dbo.Permission
                (
                      DistributorPermissionTypeID_FK, distributorID_FK
                    , permissionStartDate, permissionEndDate, permissionNote
                    , permissionActive,InIdaraID, entryData, hostName
                )
                SELECT
                      dt.distributorPermissionTypeID, @distributorID
                    , ISNULL(CONVERT(DATETIME, @StartDT), GETDATE())
                    , CONVERT(DATETIME, @EndDT)
                    , @permissionNote
                    , 1,@InIdaraID, @entryData, @hostName
                FROM  dbo.DistributorPermissionType dt
                INNER JOIN  dbo.PermissionType p
                    ON dt.permissionTypeID_FK = p.permissionTypeID
                WHERE dt.distributorID_FK = @distributorIDFroGiveAllPermissions
                  AND dt.distributorPermissionTypeActive = 1
                  AND p.permissionTypeActive = 1
                  AND CAST(dt.distributorPermissionTypeStartDate AS DATE) <= CAST(GETDATE() AS DATE)
                  AND (CAST(dt.distributorPermissionTypeEndDate AS DATE) > CAST(GETDATE() AS DATE)
                       OR dt.distributorPermissionTypeEndDate IS NULL)
                  AND dt.distributorPermissionTypeID NOT IN
                  (
                        SELECT r.DistributorPermissionTypeID_FK
                        FROM  dbo.Permission r
                        WHERE r.permissionActive = 1
                          AND CAST(r.permissionStartDate AS DATE) <= CAST(GETDATE() AS DATE)
                          AND (CAST(r.permissionEndDate AS DATE) > CAST(GETDATE() AS DATE)
                               OR r.permissionEndDate IS NULL)
                          AND r.distributorID_FK = @distributorID
                  );

                SET @Rows = @@ROWCOUNT;
                IF @Rows <= 0
                BEGIN
                    ;THROW 50001, N'حصل خطأ في اضافة البيانات او الموزع يملك جميع الصلاحيات', 1;
                END
            END
            ELSE IF ISNULL(@searchID,0) = 3
            BEGIN
                INSERT INTO  dbo.Permission
                (
                      DistributorPermissionTypeID_FK, RoleID_FK
                    , permissionStartDate, permissionEndDate, permissionNote
                    , permissionActive,InIdaraID, entryData, hostName
                )
                SELECT
                      dt.distributorPermissionTypeID, @RoleID
                    , ISNULL(CONVERT(DATETIME, @StartDT), GETDATE())
                    , CONVERT(DATETIME, @EndDT)
                    , @permissionNote
                    , 1,@InIdaraID, @entryData, @hostName
                FROM  dbo.DistributorPermissionType dt
                INNER JOIN  dbo.PermissionType p
                    ON dt.permissionTypeID_FK = p.permissionTypeID
                WHERE dt.distributorID_FK = @distributorIDFroGiveAllPermissions
                  AND dt.distributorPermissionTypeActive = 1
                  AND p.permissionTypeActive = 1
                  AND CAST(dt.distributorPermissionTypeStartDate AS DATE) <= CAST(GETDATE() AS DATE)
                  AND (CAST(dt.distributorPermissionTypeEndDate AS DATE) > CAST(GETDATE() AS DATE)
                       OR dt.distributorPermissionTypeEndDate IS NULL)
                  AND dt.distributorPermissionTypeID NOT IN
                  (
                        SELECT r.DistributorPermissionTypeID_FK
                        FROM  dbo.Permission r
                        WHERE r.permissionActive = 1
                          AND CAST(r.permissionStartDate AS DATE) <= CAST(GETDATE() AS DATE)
                          AND (CAST(r.permissionEndDate AS DATE) > CAST(GETDATE() AS DATE)
                               OR r.permissionEndDate IS NULL)
                          AND r.RoleID_FK = @RoleID
                  );

                SET @Rows = @@ROWCOUNT;
                IF @Rows <= 0
                BEGIN
                    ;THROW 50001, N'حصل خطأ في اضافة البيانات او الدور يملك جميع الصلاحيات', 1;
                END
            END
            ELSE IF ISNULL(@searchID,0) = 4
            BEGIN
                INSERT INTO  dbo.Permission
                (
                      DistributorPermissionTypeID_FK, IdaraID_FK
                    , permissionStartDate, permissionEndDate, permissionNote
                    , permissionActive,InIdaraID, entryData, hostName
                )
                SELECT
                      dt.distributorPermissionTypeID, @IdaraID
                    , ISNULL(CONVERT(DATETIME, @StartDT), GETDATE())
                    , CONVERT(DATETIME, @EndDT)
                    , @permissionNote
                    , 1,@InIdaraID, @entryData, @hostName
                FROM  dbo.DistributorPermissionType dt
                INNER JOIN  dbo.PermissionType p
                    ON dt.permissionTypeID_FK = p.permissionTypeID
                WHERE dt.distributorID_FK = @distributorIDFroGiveAllPermissions
                  AND dt.distributorPermissionTypeActive = 1
                  AND p.permissionTypeActive = 1
                  AND CAST(dt.distributorPermissionTypeStartDate AS DATE) <= CAST(GETDATE() AS DATE)
                  AND (CAST(dt.distributorPermissionTypeEndDate AS DATE) > CAST(GETDATE() AS DATE)
                       OR dt.distributorPermissionTypeEndDate IS NULL)
                  AND dt.distributorPermissionTypeID NOT IN
                  (
                        SELECT r.DistributorPermissionTypeID_FK
                        FROM  dbo.Permission r
                        WHERE r.permissionActive = 1
                          AND CAST(r.permissionStartDate AS DATE) <= CAST(GETDATE() AS DATE)
                          AND (CAST(r.permissionEndDate AS DATE) > CAST(GETDATE() AS DATE)
                               OR r.permissionEndDate IS NULL)
                          AND r.IdaraID_FK = @IdaraID
                  );

                SET @Rows = @@ROWCOUNT;
                IF @Rows <= 0
                BEGIN
                    ;THROW 50001, N'حصل خطأ في اضافة البيانات او الادارة تملك جميع الصلاحيات', 1;
                END
            END
            ELSE IF ISNULL(@searchID,0) = 5
            BEGIN
                INSERT INTO  dbo.Permission
                (
                      DistributorPermissionTypeID_FK, DSDID_FK
                    , permissionStartDate, permissionEndDate, permissionNote
                    , permissionActive,InIdaraID, entryData, hostName
                )
                SELECT
                      dt.distributorPermissionTypeID, @DSDID
                    , ISNULL(CONVERT(DATETIME, @StartDT), GETDATE())
                    , CONVERT(DATETIME, @EndDT)
                    , @permissionNote
                    , 1,@InIdaraID, @entryData, @hostName
                FROM  dbo.DistributorPermissionType dt
                INNER JOIN  dbo.PermissionType p
                    ON dt.permissionTypeID_FK = p.permissionTypeID
                WHERE dt.distributorID_FK = @distributorIDFroGiveAllPermissions
                  AND dt.distributorPermissionTypeActive = 1
                  AND p.permissionTypeActive = 1
                  AND CAST(dt.distributorPermissionTypeStartDate AS DATE) <= CAST(GETDATE() AS DATE)
                  AND (CAST(dt.distributorPermissionTypeEndDate AS DATE) > CAST(GETDATE() AS DATE)
                       OR dt.distributorPermissionTypeEndDate IS NULL)
                  AND dt.distributorPermissionTypeID NOT IN
                  (
                        SELECT r.DistributorPermissionTypeID_FK
                        FROM  dbo.Permission r
                        WHERE r.permissionActive = 1
                          AND CAST(r.permissionStartDate AS DATE) <= CAST(GETDATE() AS DATE)
                          AND (CAST(r.permissionEndDate AS DATE) > CAST(GETDATE() AS DATE)
                               OR r.permissionEndDate IS NULL)
                          AND r.DSDID_FK = @DSDID
                  );

                SET @Rows = @@ROWCOUNT;
                IF @Rows <= 0
                BEGIN
                    ;THROW 50001, N'حصل خطأ في اضافة البيانات او القسم/الفرع/الشعبة يملك جميع الصلاحيات', 1;
                END
            END
            ELSE
            BEGIN
                ;THROW 50001, N'يوجد خطأ ما - searchID غير صحيح', 1;
            END

            SET @Note = N'{'
                + N'"Action": "INSERTFULLACCESS"'
                + N',"searchID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @searchID), '') + N'"'
                + N',"RowsInserted": "' + CONVERT(NVARCHAR(50), @Rows) + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[dbo].[Permission]', N'INSERTFULLACCESS', 0, @entryData, @Note);

            SELECT 1 AS IsSuccessful, N'تم اضافة البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- UPDATE (يقفل القديم + يضيف جديد)
        ----------------------------------------------------------------
        ELSE IF @Action = N'UPDATE'
        BEGIN
            IF @PermissionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتعديل', 1;
            END

            IF NOT EXISTS (SELECT 1 FROM  dbo.Permission WHERE permissionID = @PermissionID)
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            UPDATE  dbo.Permission
            SET permissionEndDate = CAST(GETDATE() AS DATE),
                permissionActive  = 0
            WHERE permissionID = @PermissionID;

            IF @@ROWCOUNT <= 0
            BEGIN
                ;THROW 50002, N'لم يتم تعديل السجل القديم', 1;
            END

            INSERT INTO  dbo.Permission
            (
                  DistributorPermissionTypeID_FK
                , UsersID_FK
                , RoleID_FK
                , distributorID_FK
                , IdaraID_FK
                , DSDID_FK
                , permissionStartDate
                , permissionEndDate
                , permissionNote
                , permissionActive
                , InIdaraID
                , entryData
                , hostName
            )
            SELECT
                  p.DistributorPermissionTypeID_FK
                , p.UsersID_FK
                , p.RoleID_FK
                , p.distributorID_FK
                , p.IdaraID_FK
                , p.DSDID_FK
                , ISNULL(CONVERT(DATETIME, @StartDT), GETDATE())
                , CONVERT(DATETIME, @EndDT)
                , @permissionNote
                , 1
                , @InIdaraID
                , @entryData
                , @hostName
            FROM  dbo.Permission p
            WHERE p.permissionID = @PermissionID;

            SET @Rows = @@ROWCOUNT;
            IF @Rows <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة السجل الجديد بعد التعديل', 1;
            END

            SET @Note = N'{'
                + N'"PermissionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @PermissionID), '') + N'"'
                + N',"permissionStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @permissionStartDate), '') + N'"'
                + N',"permissionEndDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @permissionEndDate), '') + N'"'
                + N',"permissionNote": "' + ISNULL(CONVERT(NVARCHAR(MAX), @permissionNote), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[dbo].[Permission]', N'UPDATE', @PermissionID, @entryData, @Note);

            SELECT 1 AS IsSuccessful, N'تم تعديل البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- DELETE (يقفل صلاحية)
        ----------------------------------------------------------------
        ELSE IF @Action = N'DELETE'
        BEGIN
            IF @PermissionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للحذف', 1;
            END

            IF NOT EXISTS (SELECT 1 FROM  dbo.Permission WHERE permissionID = @PermissionID)
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            UPDATE  dbo.Permission
            SET permissionEndDate = CAST(GETDATE() AS DATE),
                permissionActive  = 0
            WHERE permissionID = @PermissionID;

            IF @@ROWCOUNT <= 0
            BEGIN
                ;THROW 50002, N'لم يتم حذف أي سجل', 1;
            END

            SET @Note = N'{'
                + N'"PermissionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @PermissionID), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[dbo].[Permission]', N'DELETE', @PermissionID, @entryData, @Note);

            SELECT 1 AS IsSuccessful, N'تم حذف البيانات بنجاح' AS Message_;
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
