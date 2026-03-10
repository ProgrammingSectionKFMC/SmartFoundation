
CREATE PROCEDURE [Housing].[MilitaryLocationSP]
(
      @Action                           NVARCHAR(200)
    , @militaryLocationID               BIGINT          = NULL
    , @militaryLocationCode             NVARCHAR(10)    = NULL
    , @militaryAreaCityID_FK            INT             = NULL
    , @militaryLocationName_A           NVARCHAR(1000)  = NULL
    , @militaryLocationName_E           NVARCHAR(1000)  = NULL
    , @militaryLocationCoordinates      NVARCHAR(1000)  = NULL
    , @militaryLocationDescription      NVARCHAR(1000)  = NULL
    , @militaryLocationActive           INT             = NULL
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
            IF NULLIF(LTRIM(RTRIM(@militaryLocationName_A)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'اسم الموقع العسكري (عربي) مطلوب', 1;
            END

            IF EXISTS
            (
                SELECT 1
                FROM  Housing.MilitaryLocation ml
                WHERE ml.militaryLocationName_A = @militaryLocationName_A
                  AND ml.militaryLocationActive = 1
                  AND (ml.IdaraId_FK = @IdaraID_INT OR @IdaraID_INT IS NULL)
            )
            BEGIN
                ;THROW 50001, N'البيانات مدخلة مسبقا', 1;
            END

            INSERT INTO  Housing.MilitaryLocation
            (
                  militaryLocationCode
                , militaryAreaCityID_FK
                , militaryLocationName_A
                , militaryLocationName_E
                , militaryLocationCoordinates
                , militaryLocationDescription
                , militaryLocationActive
                , IdaraId_FK
                , entryData
                , hostName
            )
            VALUES
            (
                  @militaryLocationCode
                , @militaryAreaCityID_FK
                , @militaryLocationName_A
                , @militaryLocationName_E
                , @militaryLocationCoordinates
                , @militaryLocationDescription
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
                + N'"militaryLocationID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"militaryLocationCode": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @militaryLocationCode), '') + N'"'
                + N',"militaryAreaCityID_FK": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @militaryAreaCityID_FK), '') + N'"'
                + N',"militaryLocationName_A": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @militaryLocationName_A), '') + N'"'
                + N',"militaryLocationName_E": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @militaryLocationName_E), '') + N'"'
                + N',"militaryLocationCoordinates": "' + ISNULL(CONVERT(NVARCHAR(MAX), @militaryLocationCoordinates), '') + N'"'
                + N',"militaryLocationDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @militaryLocationDescription), '') + N'"'
                + N',"militaryLocationActive": "1"'
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
                  N'[Housing].[MilitaryLocation]'
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
            IF @militaryLocationID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.MilitaryLocation
                WHERE militaryLocationID = @militaryLocationID
                  AND militaryLocationActive = 1
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            UPDATE  Housing.MilitaryLocation
            SET
                  militaryLocationCode        = ISNULL(@militaryLocationCode, militaryLocationCode)
                , militaryAreaCityID_FK       = ISNULL(@militaryAreaCityID_FK, militaryAreaCityID_FK)
                , militaryLocationName_A      = ISNULL(@militaryLocationName_A, militaryLocationName_A)
                , militaryLocationName_E      = ISNULL(@militaryLocationName_E, militaryLocationName_E)
                , militaryLocationCoordinates = ISNULL(@militaryLocationCoordinates, militaryLocationCoordinates)
                , militaryLocationDescription = ISNULL(@militaryLocationDescription, militaryLocationDescription)
                , IdaraId_FK                  = ISNULL(@IdaraID_INT, IdaraId_FK)
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE militaryLocationID = @militaryLocationID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1; -- برمجي/غير متوقع
            END

            SET @Note = N'{'
                + N'"militaryLocationID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @militaryLocationID), '') + N'"'
                + N',"militaryLocationCode": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @militaryLocationCode), '') + N'"'
                + N',"militaryAreaCityID_FK": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @militaryAreaCityID_FK), '') + N'"'
                + N',"militaryLocationName_A": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @militaryLocationName_A), '') + N'"'
                + N',"militaryLocationName_E": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @militaryLocationName_E), '') + N'"'
                + N',"militaryLocationCoordinates": "' + ISNULL(CONVERT(NVARCHAR(MAX), @militaryLocationCoordinates), '') + N'"'
                + N',"militaryLocationDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @militaryLocationDescription), '') + N'"'
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
                  N'[Housing].[MilitaryLocation]'
                , N'UPDATE'
                , @militaryLocationID
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
            IF @militaryLocationID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للحذف', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.MilitaryLocation
                WHERE militaryLocationID = @militaryLocationID
                  AND militaryLocationActive = 1
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            UPDATE  Housing.MilitaryLocation
            SET
                  militaryLocationActive = 0
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE militaryLocationID = @militaryLocationID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم حذف أي سجل', 1; -- برمجي/غير متوقع
            END

            SET @Note = N'{'
                + N'"militaryLocationID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @militaryLocationID), '') + N'"'
                + N',"entryData": "'         + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'          + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[MilitaryLocation]'
                , N'DELETE'
                , @militaryLocationID
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
