
CREATE PROCEDURE [Housing].[BuildingClassSP] 
(
      @Action                   NVARCHAR(200)
    , @buildingClassID          BIGINT          = NULL
    , @buildingClassName_A      NVARCHAR(100)   = NULL
    , @buildingClassName_E      NVARCHAR(100)   = NULL
    , @buildingClassDescription NVARCHAR(1000)  = NULL
    , @idaraID_FK               NVARCHAR(10)    = NULL
    , @entryData                NVARCHAR(20)    = NULL
    , @hostName                 NVARCHAR(200)   = NULL
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
        ----------------------------------------------------------------
        -- INSERT
        ----------------------------------------------------------------
        IF @Action = N'INSERT'
        BEGIN
            IF NULLIF(LTRIM(RTRIM(@buildingClassName_A)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'اسم فئة المبنى (عربي) مطلوب', 1;
            END

            IF EXISTS
            (
                SELECT 1
                FROM  Housing.BuildingClass c
                WHERE c.buildingClassName_A = @buildingClassName_A
                  AND c.buildingClassActive = 1
                  AND (c.IdaraId_FK = @IdaraID_INT OR @IdaraID_INT IS NULL)
            )
            BEGIN
                ;THROW 50001, N'البيانات مدخلة مسبقا', 1;
            END
            INSERT INTO  Housing.BuildingClass
            (
                  buildingClassName_A
                , buildingClassName_E
                , buildingClassDescription
                , buildingClassActive
                , IdaraId_FK
                , entryData
                , hostName
            )
            VALUES
            (
                  @buildingClassName_A
                , @buildingClassName_E
                , @buildingClassDescription
                , 1
                , @IdaraID_INT
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingClassID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingClassName_A": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingClassName_A), '') + N'"'
                + N',"buildingClassName_E": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingClassName_E), '') + N'"'
                + N',"buildingClassDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingClassDescription), '') + N'"'
                + N',"buildingClassActive": "1"'
                + N',"IdaraId_FK": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                 + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingClass]'
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
            IF @buildingClassID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.BuildingClass
                WHERE BuildingClassID = @buildingClassID
                  AND buildingClassActive = 1
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END
            UPDATE  Housing.BuildingClass
            SET
                  BuildingClassName_A      = ISNULL(@buildingClassName_A, BuildingClassName_A)
                , BuildingClassName_E      = ISNULL(@buildingClassName_E, BuildingClassName_E)
                , BuildingClassDescription = ISNULL(@buildingClassDescription, BuildingClassDescription)
                , IdaraId_FK               = ISNULL(@IdaraID_INT, IdaraId_FK)
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE BuildingClassID = @buildingClassID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1; -- برمجي/غير متوقع
            END

            SET @Note = N'{'
                + N'"buildingClassID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @buildingClassID), '') + N'"'
                + N',"buildingClassName_A": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingClassName_A), '') + N'"'
                + N',"buildingClassName_E": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingClassName_E), '') + N'"'
                + N',"buildingClassDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingClassDescription), '') + N'"'
                + N',"IdaraId_FK": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                 + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingClass]'
                , N'UPDATE'
                , @buildingClassID
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
            IF @buildingClassID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للحذف', 1;
            END
            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.BuildingClass
                WHERE BuildingClassID = @buildingClassID
                  AND buildingClassActive = 1
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            UPDATE  Housing.BuildingClass
            SET
                  buildingClassActive = 0
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE BuildingClassID = @buildingClassID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم حذف أي سجل', 1; -- برمجي/غير متوقع
            END
            SET @Note = N'{'
                + N'"buildingClassID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingClassID), '') + N'"'
                + N',"entryData": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingClass]'
                , N'DELETE'
                , @buildingClassID
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
