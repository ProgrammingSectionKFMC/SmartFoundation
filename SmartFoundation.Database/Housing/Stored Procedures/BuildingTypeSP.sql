
CREATE PROCEDURE [Housing].[BuildingTypeSP]
(
      @Action                  NVARCHAR(200)
    , @buildingTypeID          BIGINT          = NULL
    , @buildingTypeCode        NVARCHAR(10)    = NULL
    , @buildingTypeName_A      NVARCHAR(100)   = NULL
    , @buildingTypeName_E      NVARCHAR(100)   = NULL
    , @buildingTypeDescription NVARCHAR(1000)  = NULL
    , @idaraID_FK              NVARCHAR(10)    = NULL
    , @entryData               NVARCHAR(20)    = NULL
    , @hostName                NVARCHAR(200)   = NULL
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
            IF NULLIF(LTRIM(RTRIM(@buildingTypeName_A)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'اسم نوع المبنى (عربي) مطلوب', 1;
            END

            IF EXISTS
            (
                SELECT 1
                FROM  Housing.BuildingType bt
                WHERE bt.buildingTypeName_A = @buildingTypeName_A
                  AND bt.buildingTypeActive = 1
                  AND (bt.IdaraId_FK = @IdaraID_INT OR @IdaraID_INT IS NULL)
            )
            BEGIN
                ;THROW 50001, N'البيانات مدخلة مسبقا', 1;
            END

            INSERT INTO  Housing.BuildingType
            (
                  buildingTypeCode
                , buildingTypeName_A
                , buildingTypeName_E
                , buildingTypeDescription
                , buildingTypeActive
                , IdaraId_FK
                , entryData
                , hostName
            )
            VALUES
            (
                  @buildingTypeCode
                , @buildingTypeName_A
                , @buildingTypeName_E
                , @buildingTypeDescription
                , 1
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
                + N'"buildingTypeID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingTypeCode": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @buildingTypeCode), '') + N'"'
                + N',"buildingTypeName_A": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingTypeName_A), '') + N'"'
                + N',"buildingTypeName_E": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingTypeName_E), '') + N'"'
                + N',"buildingTypeDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingTypeDescription), '') + N'"'
                + N',"buildingTypeActive": "1"'
                + N',"IdaraId_FK": "'              + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingType]'
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
            IF @buildingTypeID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.BuildingType
                WHERE buildingTypeID = @buildingTypeID
                  AND buildingTypeActive = 1
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            UPDATE  Housing.BuildingType
            SET
                  buildingTypeCode        = ISNULL(@buildingTypeCode, buildingTypeCode)
                , buildingTypeName_A      = ISNULL(@buildingTypeName_A, buildingTypeName_A)
                , buildingTypeName_E      = ISNULL(@buildingTypeName_E, buildingTypeName_E)
                , buildingTypeDescription = ISNULL(@buildingTypeDescription, buildingTypeDescription)
                , IdaraId_FK              = ISNULL(@IdaraID_INT, IdaraId_FK)
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE buildingTypeID = @buildingTypeID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1; -- برمجي/غير متوقع
            END

            SET @Note = N'{'
                + N'"buildingTypeID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @buildingTypeID), '') + N'"'
                + N',"buildingTypeCode": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @buildingTypeCode), '') + N'"'
                + N',"buildingTypeName_A": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingTypeName_A), '') + N'"'
                + N',"buildingTypeName_E": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingTypeName_E), '') + N'"'
                + N',"buildingTypeDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingTypeDescription), '') + N'"'
                + N',"IdaraId_FK": "'              + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingType]'
                , N'UPDATE'
                , @buildingTypeID
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
            IF @buildingTypeID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للحذف', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.BuildingType
                WHERE buildingTypeID = @buildingTypeID
                  AND buildingTypeActive = 1
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            UPDATE  Housing.BuildingType
            SET
                  buildingTypeActive = 0
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE buildingTypeID = @buildingTypeID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم حذف أي سجل', 1; -- برمجي/غير متوقع
            END

            SET @Note = N'{'
                + N'"buildingTypeID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingTypeID), '') + N'"'
                + N',"entryData": "'     + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingType]'
                , N'DELETE'
                , @buildingTypeID
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
