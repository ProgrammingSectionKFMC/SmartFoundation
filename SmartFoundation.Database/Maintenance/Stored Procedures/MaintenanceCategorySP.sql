
CREATE   PROCEDURE [Maintenance].[MaintenanceCategorySP]
(
      @Action                           NVARCHAR(200)
    , @MaintenanceCategoryID            NVARCHAR(100)   = NULL
    , @ParentID                         NVARCHAR(100)   = NULL
    , @CategoryName_A                   NVARCHAR(250)   = NULL
    , @CategoryName_E                   NVARCHAR(250)   = NULL
    , @Description_A                    NVARCHAR(1000)  = NULL
    , @DisplayOrder                     NVARCHAR(100)   = NULL
    , @ResponsibleDSDID                 NVARCHAR(100)   = NULL
    , @Notes                            NVARCHAR(1000)  = NULL
    , @idaraID_FK                       NVARCHAR(10)    = NULL
    , @entryData                        NVARCHAR(20)    = NULL
    , @hostName                         NVARCHAR(200)   = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE
          @NewID BIGINT = NULL
        , @Note  NVARCHAR(MAX) = NULL;

    -- تحويلات رقمية آمنة
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), ''));
    DECLARE @MaintenanceCategoryID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@MaintenanceCategoryID)), ''));
    DECLARE @ParentID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@ParentID)), ''));
    DECLARE @DisplayOrder_INT INT = ISNULL(TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@DisplayOrder)), '')), 0);
    DECLARE @ResponsibleDSDID_BIGINT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@ResponsibleDSDID)), ''));

    BEGIN TRY
        -- Transaction-safe
        IF @tc = 0
            BEGIN TRAN;

        ----------------------------------------------------------------
        --                    MaintenanceCategory
        ----------------------------------------------------------------

        ----------------------------------------------------------------
        -- Business validations => THROW 50001
        ----------------------------------------------------------------
        IF NULLIF(LTRIM(RTRIM(@Action)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'العملية مطلوبة', 1;
        END

        IF @IdaraID_INT IS NULL
        BEGIN
            ;THROW 50001, N'الإدارة مطلوبة', 1;
        END

        ----------------------------------------------------------------
        -- INSERT
        ----------------------------------------------------------------
        IF @Action = N'INSERTMAINTENANCECATEGORY'
        BEGIN
            IF NULLIF(LTRIM(RTRIM(@CategoryName_A)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'اسم نوع الصيانة (عربي) مطلوب', 1;
            END

            IF @ParentID_BIGINT IS NOT NULL
            AND NOT EXISTS
            (
                SELECT 1
                FROM  Maintenance.MaintenanceCategory
                WHERE MaintenanceCategoryID = @ParentID_BIGINT
                  AND IdaraId_FK = @IdaraID_INT
                  AND IsActive = 1
            )
            BEGIN
                ;THROW 50001, N'التصنيف الأب غير موجود', 1;
            END

            IF @ParentID_BIGINT IS NOT NULL
            AND EXISTS
            (
                SELECT 1
                FROM  Maintenance.MaintenanceCategoryRouting
                WHERE MaintenanceCategoryID = @ParentID_BIGINT
                  AND IdaraId_FK = @IdaraID_INT
                  AND IsActive = 1
                  AND IsDefault = 1
                  AND ISNULL(ResponsibleDSDID, 0) <> 0
            )
            BEGIN
                ;THROW 50001, N'لا يمكن إضافة نوع فرعي لتصنيف مرتبط بجهة مسؤولة، ألغِ الربط أولاً', 1;
            END

            INSERT INTO  Maintenance.MaintenanceCategory
            (
                  IdaraId_FK
                , ParentID
                , CategoryName_A
                , CategoryName_E
                , Description_A
                , DisplayOrder
                , entryUser
                , entryData
                , hostName
            )
            VALUES
            (
                  @IdaraID_INT
                , @ParentID_BIGINT
                , @CategoryName_A
                , @CategoryName_E
                , @Description_A
                , @DisplayOrder_INT
                , TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@entryData)), ''))
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات', 1; -- برمجي/غير متوقع
            END

            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات - Identity', 1; -- برمجي/غير متوقع
            END

            SET @Note = N'{'
                + N'"MaintenanceCategoryID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"ParentID": "'             + ISNULL(CONVERT(NVARCHAR(MAX), @ParentID_BIGINT), '') + N'"'
                + N',"CategoryName_A": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @CategoryName_A), '') + N'"'
                + N',"CategoryName_E": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @CategoryName_E), '') + N'"'
                + N',"Description_A": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @Description_A), '') + N'"'
                + N',"DisplayOrder": "'         + ISNULL(CONVERT(NVARCHAR(MAX), @DisplayOrder_INT), '') + N'"'
                + N',"IdaraId_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'             + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Maintenance].[MaintenanceCategory]'
                , N'INSERT'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            IF @tc = 0
                COMMIT;

            SELECT 1 AS IsSuccessful, N'تم اضافة البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- UPDATE
        ----------------------------------------------------------------
        ELSE IF @Action = N'UPDATEMAINTENANCECATEGORY'
        BEGIN
            IF @MaintenanceCategoryID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@CategoryName_A)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'اسم نوع الصيانة (عربي) مطلوب', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Maintenance.MaintenanceCategory
                WHERE MaintenanceCategoryID = @MaintenanceCategoryID_BIGINT
                  AND IdaraId_FK = @IdaraID_INT
                  AND IsActive = 1
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            IF @ParentID_BIGINT = @MaintenanceCategoryID_BIGINT
            BEGIN
                ;THROW 50001, N'لا يمكن جعل التصنيف أباً لنفسه', 1;
            END

            IF @ParentID_BIGINT IS NOT NULL
            AND NOT EXISTS
            (
                SELECT 1
                FROM  Maintenance.MaintenanceCategory
                WHERE MaintenanceCategoryID = @ParentID_BIGINT
                  AND IdaraId_FK = @IdaraID_INT
                  AND IsActive = 1
            )
            BEGIN
                ;THROW 50001, N'التصنيف الأب غير موجود', 1;
            END

            IF @ParentID_BIGINT IS NOT NULL
            BEGIN
                DECLARE @ChildCount INT = 0;

                ;WITH CategoryChildren AS
                (
                    SELECT MaintenanceCategoryID
                    FROM  Maintenance.MaintenanceCategory
                    WHERE ParentID = @MaintenanceCategoryID_BIGINT
                      AND IdaraId_FK = @IdaraID_INT
                      AND IsActive = 1

                    UNION ALL

                    SELECT child.MaintenanceCategoryID
                    FROM  Maintenance.MaintenanceCategory child
                    INNER JOIN CategoryChildren parent
                        ON parent.MaintenanceCategoryID = child.ParentID
                    WHERE child.IdaraId_FK = @IdaraID_INT
                      AND child.IsActive = 1
                )
                SELECT @ChildCount = COUNT(1)
                FROM CategoryChildren
                WHERE MaintenanceCategoryID = @ParentID_BIGINT;

                IF @ChildCount > 0
                BEGIN
                    ;THROW 50001, N'لا يمكن نقل التصنيف تحت أحد أبنائه', 1;
                END
            END

            UPDATE  Maintenance.MaintenanceCategory
            SET
                  ParentID       = @ParentID_BIGINT
                , CategoryName_A = @CategoryName_A
                , CategoryName_E = @CategoryName_E
                , Description_A  = @Description_A
                , DisplayOrder   = @DisplayOrder_INT
                , updateUser     = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@entryData)), ''))
                , updateDate     = GETDATE()
                , entryData      = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName       = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE MaintenanceCategoryID = @MaintenanceCategoryID_BIGINT
              AND IdaraId_FK = @IdaraID_INT;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1; -- برمجي/غير متوقع
            END

            SET @Note = N'{'
                + N'"MaintenanceCategoryID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MaintenanceCategoryID_BIGINT), '') + N'"'
                + N',"ParentID": "'             + ISNULL(CONVERT(NVARCHAR(MAX), @ParentID_BIGINT), '') + N'"'
                + N',"CategoryName_A": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @CategoryName_A), '') + N'"'
                + N',"CategoryName_E": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @CategoryName_E), '') + N'"'
                + N',"Description_A": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @Description_A), '') + N'"'
                + N',"DisplayOrder": "'         + ISNULL(CONVERT(NVARCHAR(MAX), @DisplayOrder_INT), '') + N'"'
                + N',"IdaraId_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'             + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Maintenance].[MaintenanceCategory]'
                , N'UPDATE'
                , @MaintenanceCategoryID_BIGINT
                , @entryData
                , @Note
            );

            IF @tc = 0
                COMMIT;

            SELECT 1 AS IsSuccessful, N'تم تحديث البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- DELETE (Soft Delete)
        ----------------------------------------------------------------
        ELSE IF @Action = N'DELETEMAINTENANCECATEGORY'
        BEGIN
            IF @MaintenanceCategoryID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للحذف', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Maintenance.MaintenanceCategory
                WHERE MaintenanceCategoryID = @MaintenanceCategoryID_BIGINT
                  AND IdaraId_FK = @IdaraID_INT
                  AND IsActive = 1
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            IF EXISTS
            (
                SELECT 1
                FROM  Maintenance.MaintenanceCategory
                WHERE ParentID = @MaintenanceCategoryID_BIGINT
                  AND IdaraId_FK = @IdaraID_INT
                  AND IsActive = 1
            )
            BEGIN
                ;THROW 50001, N'لا يمكن حذف السجل لوجود تصنيفات فرعية نشطة', 1;
            END

            IF EXISTS
            (
                SELECT 1
                FROM  Maintenance.BuildingMaintenanceRequest
                WHERE MaintenanceCategoryID = @MaintenanceCategoryID_BIGINT
                  AND IdaraId_FK = @IdaraID_INT
                  AND IsActive = 1
            )
            BEGIN
                ;THROW 50001, N'لا يمكن حذف السجل لأنه مستخدم في طلبات صيانة نشطة', 1;
            END

            UPDATE  Maintenance.MaintenanceCategory
            SET
                  IsActive  = 0
                , updateUser = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@entryData)), ''))
                , updateDate = GETDATE()
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE MaintenanceCategoryID = @MaintenanceCategoryID_BIGINT
              AND IdaraId_FK = @IdaraID_INT;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم حذف أي سجل', 1; -- برمجي/غير متوقع
            END

            UPDATE  Maintenance.MaintenanceCategoryRouting
            SET
                  IsActive  = 0
                , IsDefault = 0
                , updateUser = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@entryData)), ''))
                , updateDate = GETDATE()
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE MaintenanceCategoryID = @MaintenanceCategoryID_BIGINT
              AND IdaraId_FK = @IdaraID_INT
              AND IsActive = 1;

            SET @Note = N'{'
                + N'"MaintenanceCategoryID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MaintenanceCategoryID_BIGINT), '') + N'"'
                + N',"entryData": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'             + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Maintenance].[MaintenanceCategory]'
                , N'DELETE'
                , @MaintenanceCategoryID_BIGINT
                , @entryData
                , @Note
            );

            IF @tc = 0
                COMMIT;

            SELECT 1 AS IsSuccessful, N'تم حذف البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- ROUTE
        ----------------------------------------------------------------
        ELSE IF @Action = N'ROUTEMAINTENANCECATEGORY'
        BEGIN
            IF @MaintenanceCategoryID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF @ResponsibleDSDID_BIGINT IS NULL
            BEGIN
                ;THROW 50001, N'الجهة المسؤولة مطلوبة', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Maintenance.MaintenanceCategory
                WHERE MaintenanceCategoryID = @MaintenanceCategoryID_BIGINT
                  AND IdaraId_FK = @IdaraID_INT
                  AND IsActive = 1
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            IF @ResponsibleDSDID_BIGINT = 0
            BEGIN
                UPDATE  Maintenance.MaintenanceCategoryRouting
                SET
                      IsActive  = 0
                    , IsDefault = 0
                    , updateUser = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@entryData)), ''))
                    , updateDate = GETDATE()
                    , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                    , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
                WHERE MaintenanceCategoryID = @MaintenanceCategoryID_BIGINT
                  AND IdaraId_FK = @IdaraID_INT
                  AND IsDefault = 1
                  AND IsActive = 1;

                IF @@ROWCOUNT = 0
                BEGIN
                    ;THROW 50001, N'لا يوجد ربط جهة مسؤولة لإلغائه', 1;
                END

                SET @Note = N'{'
                    + N'"MaintenanceCategoryID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MaintenanceCategoryID_BIGINT), '') + N'"'
                    + N',"Action": "UNROUTE"'
                    + N',"IdaraId_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                    + N',"entryData": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                    + N',"hostName": "'             + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                    + N'}';

                INSERT INTO  dbo.AuditLog
                (
                      TableName
                    , ActionType
                    , RecordID
                    , PerformedBy
                    , Notes
                )
                VALUES
                (
                      N'[Maintenance].[MaintenanceCategoryRouting]'
                    , N'UNROUTE'
                    , ISNULL(@MaintenanceCategoryID_BIGINT, 0)
                    , @entryData
                    , @Note
                );

                IF @tc = 0
                    COMMIT;

                SELECT 1 AS IsSuccessful, N'تم إلغاء ربط الجهة المسؤولة بنجاح' AS Message_;
                RETURN;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  dbo.DeptSecDiv
                WHERE DSDID = @ResponsibleDSDID_BIGINT
                  AND idaraID_FK = @IdaraID_INT
            )
            BEGIN
                ;THROW 50001, N'الجهة المسؤولة غير موجودة', 1;
            END

                        IF EXISTS
            (
                SELECT 1
                FROM  Maintenance.MaintenanceCategory
                WHERE ParentID = @MaintenanceCategoryID_BIGINT
                  AND IdaraId_FK = @IdaraID_INT
                  AND IsActive = 1
            )
            BEGIN
                ;THROW 50001, N'لا يمكن ربط الجهة المسؤولة بتصنيف يحتوي على أبناء، اختر آخر مستوى', 1;
            END

            UPDATE  Maintenance.MaintenanceCategoryRouting
            SET
                  IsActive  = 0
                , IsDefault = 0
                , updateUser = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@entryData)), ''))
                , updateDate = GETDATE()
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE MaintenanceCategoryID = @MaintenanceCategoryID_BIGINT
              AND IdaraId_FK = @IdaraID_INT
              AND IsDefault = 1
              AND IsActive = 1;

            INSERT INTO  Maintenance.MaintenanceCategoryRouting
            (
                  IdaraId_FK
                , MaintenanceCategoryID
                , ResponsibleDSDID
                , IsDefault
                , Notes
                , entryUser
                , entryData
                , hostName
            )
            VALUES
            (
                  @IdaraID_INT
                , @MaintenanceCategoryID_BIGINT
                , @ResponsibleDSDID_BIGINT
                , 1
                , ISNULL(@Notes, @Description_A)
                , TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@entryData)), ''))
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات', 1; -- برمجي/غير متوقع
            END

            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات - Identity', 1; -- برمجي/غير متوقع
            END

            SET @Note = N'{'
                + N'"MaintenanceCategoryRoutingID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"MaintenanceCategoryID": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @MaintenanceCategoryID_BIGINT), '') + N'"'
                + N',"ResponsibleDSDID": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @ResponsibleDSDID_BIGINT), '') + N'"'
                + N',"IdaraId_FK": "'                  + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                   + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                    + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Maintenance].[MaintenanceCategoryRouting]'
                , N'INSERT'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            IF @tc = 0
                COMMIT;

            SELECT 1 AS IsSuccessful, N'تم اضافة البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- Unknown Action
        ----------------------------------------------------------------
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

