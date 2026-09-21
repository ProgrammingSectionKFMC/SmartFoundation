CREATE PROCEDURE [Housing].[BuildingSpacesSP]
(
      @Action                     NVARCHAR(200)
    , @BuildingSpaceID            BIGINT          = NULL
    , @BuildingDetailsID_FK       BIGINT          = NULL
    , @BuildingSpaceTypeID_FK     INT             = NULL
    , @BuildingSpaceName          NVARCHAR(200)   = NULL
    , @BuildingSpaceLength        DECIMAL(10, 2)  = NULL
    , @BuildingSpaceWidth         DECIMAL(10, 2)  = NULL
    , @BuildingSpaceArea          DECIMAL(10, 2)  = NULL
    , @BuildingSpaceStartDate     DATE            = NULL
    , @BuildingSpaceEndDate       DATE            = NULL
    , @BuildingSpaceRemark        NVARCHAR(1000)  = NULL
    , @idaraID_FK                 NVARCHAR(10)    = NULL
    , @entryData                  NVARCHAR(20)    = NULL
    , @hostName                   NVARCHAR(200)   = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE
          @NewID                BIGINT        = NULL
        , @BuildingSpaceSequence INT          = NULL
        , @BuildingStartDate     DATE          = NULL
        , @CalculatedArea        DECIMAL(10,2) = NULL
        , @Note                 NVARCHAR(MAX) = NULL;

    -- تحويلات رقمية آمنة
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(@idaraID_FK, ''));

    BEGIN TRY
        -- Transaction-safe
        IF @tc = 0
            BEGIN TRAN;

        ----------------------------------------------------------------
        -- Business validations => THROW 50001
        ----------------------------------------------------------------
        IF NULLIF(LTRIM(RTRIM(@Action)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'العملية مطلوبة', 1;
        END

        IF @BuildingSpaceLength IS NOT NULL AND @BuildingSpaceLength <= 0
        BEGIN
            ;THROW 50001, N'طول الفراغ يجب أن يكون أكبر من صفر', 1;
        END

        IF @BuildingSpaceWidth IS NOT NULL AND @BuildingSpaceWidth <= 0
        BEGIN
            ;THROW 50001, N'عرض الفراغ يجب أن يكون أكبر من صفر', 1;
        END

        IF @BuildingSpaceArea IS NOT NULL AND @BuildingSpaceArea <= 0
        BEGIN
            ;THROW 50001, N'مساحة الفراغ يجب أن تكون أكبر من صفر', 1;
        END

        IF (@BuildingSpaceLength IS NULL AND @BuildingSpaceWidth IS NOT NULL)
           OR (@BuildingSpaceLength IS NOT NULL AND @BuildingSpaceWidth IS NULL)
        BEGIN
            ;THROW 50001, N'يجب إدخال طول وعرض الفراغ معاً', 1;
        END

        IF @BuildingSpaceLength IS NOT NULL AND @BuildingSpaceWidth IS NOT NULL
        BEGIN
            SET @CalculatedArea = TRY_CONVERT(DECIMAL(10,2), ROUND(@BuildingSpaceLength * @BuildingSpaceWidth, 2));

            IF @CalculatedArea IS NULL
            BEGIN
                ;THROW 50001, N'المساحة الناتجة من الطول والعرض تتجاوز الحد المسموح', 1;
            END

            IF @BuildingSpaceArea IS NULL
            BEGIN
                SET @BuildingSpaceArea = @CalculatedArea;
            END
            ELSE IF @BuildingSpaceArea <> @CalculatedArea
            BEGIN
                ;THROW 50001, N'مساحة الفراغ لا تطابق حاصل ضرب الطول في العرض', 1;
            END
        END

        IF @BuildingSpaceStartDate IS NOT NULL
           AND @BuildingSpaceEndDate IS NOT NULL
           AND @BuildingSpaceEndDate < @BuildingSpaceStartDate
        BEGIN
            ;THROW 50001, N'تاريخ نهاية الفراغ يجب ألا يسبق تاريخ البداية', 1;
        END

        ----------------------------------------------------------------
        -- INSERT
        ----------------------------------------------------------------
        IF @Action = N'INSERTBUILDINGSPACES'
        BEGIN
            IF @BuildingDetailsID_FK IS NULL
            BEGIN
                ;THROW 50001, N'المبنى مطلوب', 1;
            END

            IF @BuildingSpaceTypeID_FK IS NULL
            BEGIN
                ;THROW 50001, N'نوع الفراغ مطلوب', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM Housing.BuildingDetails bd
                WHERE bd.buildingDetailsID = @BuildingDetailsID_FK
                  AND bd.buildingDetailsActive = 1
                  AND bd.IdaraId_FK = @IdaraID_INT
            )
            BEGIN
                ;THROW 50001, N'المبنى غير موجود أو لا يتبع الإدارة الحالية', 1;
            END

            SELECT @BuildingStartDate = CAST(bd.buildingDetailsStartDate AS DATE)
            FROM Housing.BuildingDetails bd
            WHERE bd.buildingDetailsID = @BuildingDetailsID_FK;

            SET @BuildingSpaceStartDate = ISNULL(@BuildingSpaceStartDate, @BuildingStartDate);

            IF @BuildingSpaceStartDate IS NOT NULL
               AND @BuildingSpaceEndDate IS NOT NULL
               AND @BuildingSpaceEndDate < @BuildingSpaceStartDate
            BEGIN
                ;THROW 50001, N'تاريخ نهاية الفراغ يجب ألا يسبق تاريخ البداية', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM Housing.BuildingSpaceType bst
                WHERE bst.BuildingSpaceTypeID = @BuildingSpaceTypeID_FK
                  AND bst.BuildingSpaceTypeActive = 1
            )
            BEGIN
                ;THROW 50001, N'نوع الفراغ غير موجود أو غير نشط', 1;
            END

            SELECT @BuildingSpaceSequence = ISNULL(MAX(bs.BuildingSpaceSequence), 0) + 1
            FROM Housing.BuildingSpace bs WITH (UPDLOCK, HOLDLOCK)
            WHERE bs.BuildingDetailsID_FK = @BuildingDetailsID_FK
              AND bs.BuildingSpaceTypeID_FK = @BuildingSpaceTypeID_FK
              AND bs.BuildingSpaceActive = 1;

            INSERT INTO Housing.BuildingSpace
            (
                  BuildingDetailsID_FK
                , BuildingSpaceTypeID_FK
                , BuildingSpaceSequence
                , BuildingSpaceName
                , BuildingSpaceLength
                , BuildingSpaceWidth
                , BuildingSpaceArea
                , BuildingSpaceStartDate
                , BuildingSpaceEndDate
                , BuildingSpaceActive
                , BuildingSpaceRemark
                , entryData
                , hostName
            )
            VALUES
            (
                  @BuildingDetailsID_FK
                , @BuildingSpaceTypeID_FK
                , @BuildingSpaceSequence
                , @BuildingSpaceName
                , @BuildingSpaceLength
                , @BuildingSpaceWidth
                , @BuildingSpaceArea
                , @BuildingSpaceStartDate
                , @BuildingSpaceEndDate
                , 1
                , @BuildingSpaceRemark
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

            SET @Note = N'{'
                + N'"BuildingSpaceID": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"BuildingDetailsID_FK": "'  + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingDetailsID_FK), '') + N'"'
                + N',"BuildingSpaceTypeID_FK": "'+ ISNULL(CONVERT(NVARCHAR(MAX), @BuildingSpaceTypeID_FK), '') + N'"'
                + N',"BuildingSpaceSequence": "' + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingSpaceSequence), '') + N'"'
                + N',"BuildingSpaceName": "'     + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingSpaceName), '') + N'"'
                + N',"BuildingSpaceLength": "'   + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingSpaceLength), '') + N'"'
                + N',"BuildingSpaceWidth": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingSpaceWidth), '') + N'"'
                + N',"BuildingSpaceArea": "'     + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingSpaceArea), '') + N'"'
                + N',"entryData": "'             + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'              + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingSpace]'
                , N'INSERT'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم اضافة البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- UPDATE
        ----------------------------------------------------------------
        ELSE IF @Action = N'UPDATEBUILDINGSPACES'
        BEGIN
            IF @BuildingSpaceID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM Housing.BuildingSpace bs
                INNER JOIN Housing.BuildingDetails bd
                    ON bd.buildingDetailsID = bs.BuildingDetailsID_FK
                WHERE bs.BuildingSpaceID = @BuildingSpaceID
                  AND bs.BuildingSpaceActive = 1
                  AND bd.IdaraId_FK = @IdaraID_INT
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            UPDATE Housing.BuildingSpace
            SET
                  BuildingSpaceName      = @BuildingSpaceName
                , BuildingSpaceLength    = @BuildingSpaceLength
                , BuildingSpaceWidth     = @BuildingSpaceWidth
                , BuildingSpaceArea      = @BuildingSpaceArea
                , BuildingSpaceStartDate = @BuildingSpaceStartDate
                , BuildingSpaceEndDate   = @BuildingSpaceEndDate
                , BuildingSpaceRemark    = @BuildingSpaceRemark
                , entryData = ISNULL(ISNULL(entryData, '') + N',' + @entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName, '') + N',' + @hostName, hostName)
            WHERE BuildingSpaceID = @BuildingSpaceID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1;
            END

            SET @Note = N'{'
                + N'"BuildingSpaceID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingSpaceID), '') + N'"'
                + N',"BuildingSpaceName": "'   + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingSpaceName), '') + N'"'
                + N',"BuildingSpaceLength": "' + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingSpaceLength), '') + N'"'
                + N',"BuildingSpaceWidth": "'  + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingSpaceWidth), '') + N'"'
                + N',"BuildingSpaceArea": "'   + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingSpaceArea), '') + N'"'
                + N',"entryData": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingSpace]'
                , N'UPDATE'
                , @BuildingSpaceID
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم تحديث البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- DELETE (Soft Delete)
        ----------------------------------------------------------------
        ELSE IF @Action = N'DELETEBUILDINGSPACES'
        BEGIN
            IF @BuildingSpaceID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للحذف', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM Housing.BuildingSpace bs
                INNER JOIN Housing.BuildingDetails bd
                    ON bd.buildingDetailsID = bs.BuildingDetailsID_FK
                WHERE bs.BuildingSpaceID = @BuildingSpaceID
                  AND bs.BuildingSpaceActive = 1
                  AND bd.IdaraId_FK = @IdaraID_INT
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            UPDATE Housing.BuildingSpace
            SET
                  BuildingSpaceActive = 0
                , CanceledBy   = @entryData
                , CanceledDate = GETDATE()
                , entryData = ISNULL(ISNULL(entryData, '') + N',' + @entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName, '') + N',' + @hostName, hostName)
            WHERE BuildingSpaceID = @BuildingSpaceID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم حذف أي سجل', 1;
            END

            SET @Note = N'{'
                + N'"BuildingSpaceID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingSpaceID), '') + N'"'
                + N',"entryData": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingSpace]'
                , N'DELETE'
                , @BuildingSpaceID
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم حذف البيانات بنجاح' AS Message_;
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
