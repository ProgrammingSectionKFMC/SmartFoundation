
CREATE PROCEDURE [Housing].[BuildingUtilityTypeSP] 
(
      @Action                         NVARCHAR(200)
    , @buildingUtilityTypeID          BIGINT          = NULL
    , @buildingUtilityTypeName_A      NVARCHAR(100)   = NULL
    , @buildingUtilityTypeName_E      NVARCHAR(100)   = NULL
    , @buildingUtilityTypeDescription NVARCHAR(1000)  = NULL
    , @buildingUtilityTypeActive      NVARCHAR(1)     = NULL
    , @buildingUtilityTypeStartDate   NVARCHAR(1000)  = NULL
    , @buildingUtilityTypeEndDate     NVARCHAR(1000)  = NULL
    , @buildingUtilityIsRent          NVARCHAR(1)     = NULL
    , @idaraID_FK                     NVARCHAR(10)    = NULL
    , @entryData                      NVARCHAR(20)    = NULL
    , @hostName                       NVARCHAR(200)   = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE 
          @NewID BIGINT = NULL
        , @Note  NVARCHAR(MAX) = NULL;

    -- تحويل التواريخ
    DECLARE @StartDT DATETIME = TRY_CONVERT(DATETIME, NULLIF(LTRIM(RTRIM(@buildingUtilityTypeStartDate)), ''), 120);
    DECLARE @EndDT   DATETIME = TRY_CONVERT(DATETIME, NULLIF(LTRIM(RTRIM(@buildingUtilityTypeEndDate)), ''), 120);

    -- تحويلات رقمية آمنة
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), ''));

    -- تحويلات BIT/INT آمنة
    DECLARE @IsRent_BIT BIT = TRY_CONVERT(BIT, NULLIF(LTRIM(RTRIM(@buildingUtilityIsRent)), ''));
    IF @IsRent_BIT IS NULL
        SET @IsRent_BIT = 0;

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

        ----------------------------------------------------------------
        -- INSERT
        ----------------------------------------------------------------
        IF @Action = N'INSERT'
        BEGIN
            IF NULLIF(LTRIM(RTRIM(@buildingUtilityTypeName_A)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'اسم نوع المرفق (عربي) مطلوب', 1;
            END

            IF (@StartDT IS NOT NULL AND @EndDT IS NOT NULL AND @EndDT <= @StartDT)
            BEGIN
                ;THROW 50001, N'لايمكن ان يكون تاريخ النهاية اصغر من او مساوي لتاريخ البداية', 1;
            END

            IF EXISTS
            (
                SELECT 1
                FROM  Housing.BuildingUtilityType but
                WHERE but.buildingUtilityTypeName_A = @buildingUtilityTypeName_A
                  AND but.buildingUtilityTypeActive = 1
                  AND (but.IdaraId_FK = @IdaraID_INT OR @IdaraID_INT IS NULL)
            )
            BEGIN
                ;THROW 50001, N'البيانات مدخلة مسبقا', 1;
            END

            INSERT INTO  Housing.BuildingUtilityType
            (
                  buildingUtilityTypeName_A
                , buildingUtilityTypeName_E
                , buildingUtilityTypeDescription
                , buildingUtilityTypeActive
                , buildingUtilityTypeStartDate
                , buildingUtilityTypeEndDate
                , buildingUtilityIsRent
                , IdaraId_FK
                , entryData
                , hostName
            )
            VALUES
            (
                  @buildingUtilityTypeName_A
                , @buildingUtilityTypeName_E
                , @buildingUtilityTypeDescription
                , 1
                , ISNULL(@StartDT, GETDATE())
                , @EndDT
                , @IsRent_BIT
                , @IdaraID_INT
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
                + N'"buildingUtilityTypeID": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingUtilityTypeName_A": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @buildingUtilityTypeName_A), '') + N'"'
                + N',"buildingUtilityTypeName_E": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @buildingUtilityTypeName_E), '') + N'"'
                + N',"buildingUtilityTypeDescription": "'  + ISNULL(CONVERT(NVARCHAR(MAX), @buildingUtilityTypeDescription), '') + N'"'
                + N',"buildingUtilityTypeActive": "1"'
                + N',"buildingUtilityTypeStartDate": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @StartDT, 120), '') + N'"'
                + N',"buildingUtilityTypeEndDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @EndDT, 120), '') + N'"'
                + N',"buildingUtilityIsRent": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @IsRent_BIT), '') + N'"'
                + N',"IdaraId_FK": "'                      + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                       + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                        + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingUtilityType]'
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
        ELSE IF @Action = N'UPDATE'
        BEGIN
            IF @buildingUtilityTypeID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.BuildingUtilityType
                WHERE buildingUtilityTypeID = @buildingUtilityTypeID
                  AND buildingUtilityTypeActive = 1
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            IF (@StartDT IS NOT NULL AND @EndDT IS NOT NULL AND @EndDT <= @StartDT)
            BEGIN
                ;THROW 50001, N'لايمكن ان يكون تاريخ النهاية اصغر من او مساوي لتاريخ البداية', 1;
            END

            UPDATE  Housing.BuildingUtilityType
            SET
                  buildingUtilityTypeName_A      = ISNULL(@buildingUtilityTypeName_A, buildingUtilityTypeName_A)
                , buildingUtilityTypeName_E      = ISNULL(@buildingUtilityTypeName_E, buildingUtilityTypeName_E)
                , buildingUtilityTypeDescription = ISNULL(@buildingUtilityTypeDescription, buildingUtilityTypeDescription)
                , buildingUtilityTypeStartDate   = ISNULL(@StartDT, buildingUtilityTypeStartDate)
                , buildingUtilityTypeEndDate     = ISNULL(@EndDT, buildingUtilityTypeEndDate)
                , buildingUtilityIsRent          = ISNULL(@IsRent_BIT, buildingUtilityIsRent)
                , IdaraId_FK                     = ISNULL(@IdaraID_INT, IdaraId_FK)
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE buildingUtilityTypeID = @buildingUtilityTypeID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1; -- برمجي/غير متوقع
            END

            SET @Note = N'{'
                + N'"buildingUtilityTypeID": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @buildingUtilityTypeID), '') + N'"'
                + N',"buildingUtilityTypeName_A": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @buildingUtilityTypeName_A), '') + N'"'
                + N',"buildingUtilityTypeName_E": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @buildingUtilityTypeName_E), '') + N'"'
                + N',"buildingUtilityTypeDescription": "'  + ISNULL(CONVERT(NVARCHAR(MAX), @buildingUtilityTypeDescription), '') + N'"'
                + N',"buildingUtilityTypeStartDate": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @StartDT, 120), '') + N'"'
                + N',"buildingUtilityTypeEndDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @EndDT, 120), '') + N'"'
                + N',"buildingUtilityIsRent": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @IsRent_BIT), '') + N'"'
                + N',"IdaraId_FK": "'                      + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                       + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                        + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingUtilityType]'
                , N'UPDATE'
                , @buildingUtilityTypeID
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم تحديث البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- DELETE (Soft Delete)
        ----------------------------------------------------------------
        ELSE IF @Action = N'DELETE'
        BEGIN
            IF @buildingUtilityTypeID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للحذف', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.BuildingUtilityType
                WHERE buildingUtilityTypeID = @buildingUtilityTypeID
                  AND buildingUtilityTypeActive = 1
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            UPDATE  Housing.BuildingUtilityType
            SET
                  buildingUtilityTypeActive = 0
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE buildingUtilityTypeID = @buildingUtilityTypeID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم حذف أي سجل', 1; -- برمجي/غير متوقع
            END

            SET @Note = N'{'
                + N'"buildingUtilityTypeID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingUtilityTypeID), '') + N'"'
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
                  N'[Housing].[BuildingUtilityType]'
                , N'DELETE'
                , @buildingUtilityTypeID
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
