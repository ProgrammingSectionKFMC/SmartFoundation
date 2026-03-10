
CREATE PROCEDURE [Housing].[BuildingDetailsSP] 
(
      @Action                     NVARCHAR(200)
    , @buildingDetailsID           BIGINT          = NULL
    , @buildingDetailsNo           NVARCHAR(1000)  = NULL
    , @buildingDetailsRooms        NVARCHAR(1000)  = NULL
    , @buildingLevelsCount         NVARCHAR(1000)  = NULL
    , @buildingDetailsArea         NVARCHAR(1000)  = NULL
    , @buildingDetailsCoordinates  NVARCHAR(1000)  = NULL
    , @buildingTypeID_FK           NVARCHAR(1000)  = NULL
    , @buildingUtilityTypeID_FK    NVARCHAR(1000)  = NULL
    , @militaryLocationID_FK       NVARCHAR(1000)  = NULL
    , @buildingClassID_FK          NVARCHAR(1000)  = NULL
    , @buildingDetailsTel_1        NVARCHAR(1000)  = NULL
    , @buildingDetailsTel_2        NVARCHAR(1000)  = NULL
    , @buildingDetailsRemark       NVARCHAR(1000)  = NULL
    , @buildingDetailsStartDate    NVARCHAR(1000)  = NULL
    , @buildingDetailsEndDate      NVARCHAR(1000)  = NULL
    , @buildingDetailsActive       NVARCHAR(1000)  = NULL
    , @buildingRentTypeID_FK       NVARCHAR(1000)  = NULL
    , @buildingRentAmount          NVARCHAR(1000)  = NULL
    , @idaraID_FK                  NVARCHAR(10)    = NULL
    , @entryData                   NVARCHAR(20)    = NULL
    , @hostName                    NVARCHAR(200)   = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE
          @NewID           BIGINT = NULL
        , @Note            NVARCHAR(MAX) = NULL
        , @Identity_Insert BIGINT = NULL;

    -- تحويل التواريخ
    DECLARE @StartDT DATETIME = TRY_CONVERT(DATETIME, NULLIF(LTRIM(RTRIM(@buildingDetailsStartDate)),''), 120);
    DECLARE @EndDT   DATETIME = TRY_CONVERT(DATETIME, NULLIF(LTRIM(RTRIM(@buildingDetailsEndDate)),''), 120);

    -- تحويلات رقمية آمنة
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), ''));

    DECLARE @BuildingTypeID_INT        INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@buildingTypeID_FK)), ''));
    DECLARE @BuildingUtilityTypeID_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@buildingUtilityTypeID_FK)), ''));
    DECLARE @MilitaryLocationID_INT    INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@militaryLocationID_FK)), ''));
    DECLARE @BuildingClassID_INT       INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@buildingClassID_FK)), ''));

    DECLARE @RentTypeID_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@buildingRentTypeID_FK)), ''));
    DECLARE @RentAmount_DEC DECIMAL(18,2) = TRY_CONVERT(DECIMAL(18,2), NULLIF(LTRIM(RTRIM(@buildingRentAmount)), ''));

    -- هل نوع الخدمة يتطلب إيجار؟
    DECLARE @IsRent BIT = 0;
    SELECT @IsRent =
        CASE WHEN ISNULL(u.buildingUtilityIsRent,0) = 1 THEN 1 ELSE 0 END
    FROM  Housing.BuildingUtilityType u
    WHERE u.buildingUtilityTypeID = @BuildingUtilityTypeID_INT;

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

        
          


        IF(@Action IN('UPDATE'))
        BEGIN

        IF NULLIF(LTRIM(RTRIM(@buildingDetailsID)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'معرف المبنى مطلوب', 1;
        END

        IF NULLIF(LTRIM(RTRIM(@buildingDetailsNo)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'رقم المبنى مطلوب', 1;
        END

        IF @IdaraID_INT IS NULL
        BEGIN
            ;THROW 50001, N'رقم الإدارة غير صحيح', 1;
        END

        IF @StartDT >= @EndDT
        BEGIN
            ;THROW 50001, N'تاريخ النهاية يجب ان يكون اكبر من تاريخ البداية', 1;
        END

        IF @BuildingUtilityTypeID_INT IS NULL
        BEGIN
            ;THROW 50001, N'نوع المرفق (الخدمة) غير صحيح', 1;
        END

        IF @IsRent = 1
        BEGIN
            IF @RentTypeID_INT IS NULL
            BEGIN
                ;THROW 50001, N'نوع الإيجار غير صحيح', 1;
            END

            IF @RentAmount_DEC IS NULL
            BEGIN
                ;THROW 50001, N'قيمة الإيجار غير صحيحة (لازم رقم)', 1;
            END
        END
        END

        IF(@Action IN('INSERT'))
        BEGIN


        IF NULLIF(LTRIM(RTRIM(@buildingDetailsNo)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'رقم المبنى مطلوب', 1;
        END

        IF @IdaraID_INT IS NULL
        BEGIN
            ;THROW 50001, N'رقم الإدارة غير صحيح', 1;
        END

        IF @StartDT >= @EndDT
        BEGIN
            ;THROW 50001, N'تاريخ النهاية يجب ان يكون اكبر من تاريخ البداية', 1;
        END

        IF @BuildingUtilityTypeID_INT IS NULL
        BEGIN
            ;THROW 50001, N'نوع المرفق (الخدمة) غير صحيح', 1;
        END

        IF @IsRent = 1
        BEGIN
            IF @RentTypeID_INT IS NULL
            BEGIN
                ;THROW 50001, N'نوع الإيجار غير صحيح', 1;
            END

            IF @RentAmount_DEC IS NULL
            BEGIN
                ;THROW 50001, N'قيمة الإيجار غير صحيحة (لازم رقم)', 1;
            END
        END
        END

        IF(@Action IN('DELETE'))
            BEGIN
            
            IF NULLIF(LTRIM(RTRIM(@buildingDetailsID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'معرف المبنى مطلوب', 1;
            END
            
            
            END

        ----------------------------------------------------------------
        -- INSERT
        ----------------------------------------------------------------
        IF @Action = N'INSERT'
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM  Housing.BuildingDetails c
                WHERE c.buildingDetailsNo = @buildingDetailsNo
                  AND c.IdaraId_FK = @IdaraID_INT
                  AND c.buildingDetailsActive = 1
            )
            BEGIN
                ;THROW 50001, N'البيانات مدخلة مسبقا', 1;
            END

            INSERT INTO  Housing.BuildingDetails
            (
                  buildingDetailsNo
                , buildingDetailsRooms
                , buildingLevelsCount
                , buildingDetailsArea
                , buildingDetailsCoordinates
                , buildingTypeID_FK
                , buildingUtilityTypeID_FK
                , militaryLocationID_FK
                , buildingClassID_FK
                , buildingDetailsTel_1
                , buildingDetailsTel_2
                , buildingDetailsRemark
                , buildingDetailsStartDate
                , buildingDetailsEndDate
                , buildingDetailsActive
                , IdaraId_FK
                , entryData
                , hostName
            )
            VALUES
            (
                  @buildingDetailsNo
                , @buildingDetailsRooms
                , @buildingLevelsCount
                , @buildingDetailsArea
                , @buildingDetailsCoordinates
                , @BuildingTypeID_INT
                , @BuildingUtilityTypeID_INT
                , @MilitaryLocationID_INT
                , @BuildingClassID_INT
                , @buildingDetailsTel_1
                , @buildingDetailsTel_2
                , @buildingDetailsRemark
                , @StartDT
                , @EndDT
                , 1
                , @IdaraID_INT
                , @entryData
                , @hostName
            );

            SET @Identity_Insert = SCOPE_IDENTITY();
            IF @Identity_Insert IS NULL OR @Identity_Insert <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات - BuildingDetails', 1; -- برمجي
            END

            IF @IsRent = 1
            BEGIN
                INSERT INTO  Housing.BuildingRent
                (
                      buildingRentTypeID_FK
                    , buildingDetailsID_FK
                    , buildingRentAmount
                    , buildingRentStartDate
                    , buildingRentEndDate
                    , buildingRentActive
                    , entryData
                    , hostName
                )
                VALUES
                (
                      @RentTypeID_INT
                    , @Identity_Insert
                    , @RentAmount_DEC
                    , ISNULL(@StartDT, GETDATE())
                    , @EndDT
                    , 1
                    , @entryData
                    , @hostName
                );

                IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في اضافة البيانات - BuildingRent', 1; -- برمجي
                END
            END

            SET @NewID = @Identity_Insert;

            SET @Note = N'{'
                + N'"buildingDetailsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingDetailsNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingDetails],[Housing].[BuildingRent]'
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
            IF @buildingDetailsID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.BuildingDetails bd
                WHERE bd.buildingDetailsID = @buildingDetailsID
                  AND bd.buildingDetailsActive = 1
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            -- Duplicate check (مع تجاهل نفس السجل)
            IF EXISTS
            (
                SELECT 1
                FROM  Housing.BuildingDetails c
                WHERE c.buildingDetailsNo = @buildingDetailsNo
                  AND c.IdaraId_FK = @IdaraID_INT
                  AND c.buildingDetailsActive = 1
                  AND c.buildingDetailsID <> @buildingDetailsID
            )
            BEGIN
                ;THROW 50001, N'البيانات مدخلة مسبقا', 1;
            END

           
            UPDATE  Housing.BuildingDetails
            SET
                  buildingDetailsNo          = ISNULL(@buildingDetailsNo, buildingDetailsNo)
                , buildingDetailsRooms       = ISNULL(@buildingDetailsRooms, buildingDetailsRooms)
                , buildingLevelsCount        = ISNULL(@buildingLevelsCount, buildingLevelsCount)
                , buildingDetailsArea        = ISNULL(@buildingDetailsArea, buildingDetailsArea)
                , buildingDetailsCoordinates = ISNULL(@buildingDetailsCoordinates, buildingDetailsCoordinates)
                , buildingTypeID_FK          = ISNULL(@BuildingTypeID_INT, buildingTypeID_FK)
                --, buildingUtilityTypeID_FK   = ISNULL(@BuildingUtilityTypeID_INT, buildingUtilityTypeID_FK)
                , militaryLocationID_FK      = ISNULL(@MilitaryLocationID_INT, militaryLocationID_FK)
                , buildingClassID_FK         = ISNULL(@BuildingClassID_INT, buildingClassID_FK)
                , buildingDetailsTel_1       = ISNULL(@buildingDetailsTel_1, buildingDetailsTel_1)
                , buildingDetailsTel_2       = ISNULL(@buildingDetailsTel_2, buildingDetailsTel_2)
                , buildingDetailsRemark      = ISNULL(@buildingDetailsRemark, buildingDetailsRemark)
                , buildingDetailsStartDate   = ISNULL(@StartDT, buildingDetailsStartDate)
                , buildingDetailsEndDate     = ISNULL(@EndDT, buildingDetailsEndDate)
                , IdaraId_FK                 = ISNULL(@IdaraID_INT, IdaraId_FK)
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE buildingDetailsID = @buildingDetailsID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1; -- برمجي/غير متوقع
            END

            ----------------------------------------------------------------
            -- BuildingRent: لو IsRent=1 => Upsert (يفضل آخر سجل Active)
            --             لو IsRent=0 => اقفال أي إيجار Active لنفس المبنى
            ----------------------------------------------------------------
            IF @IsRent = 1
            BEGIN
                IF EXISTS
                (
                    SELECT 1
                    FROM  Housing.BuildingRent br
                    WHERE br.buildingDetailsID_FK = @buildingDetailsID
                      AND br.buildingRentActive = 1
                )
                BEGIN
                    UPDATE  Housing.BuildingRent
                SET
                      buildingRentActive = 0
                    , buildingRentEndDate = ISNULL(buildingRentEndDate, GETDATE())
                    , entryData = ISNULL(@entryData, entryData)
                    , hostName  = ISNULL(@hostName, hostName)
                WHERE buildingDetailsID_FK = @buildingDetailsID
                  AND buildingRentActive = 1;

                    IF @@ROWCOUNT = 0
                    BEGIN
                        ;THROW 50002, N'حصل خطأ في تحديث البيانات - BuildingRent', 1; -- برمجي/غير متوقع
                    END

                    
                    INSERT INTO  Housing.BuildingRent
                    (
                          buildingRentTypeID_FK
                        , buildingDetailsID_FK
                        , buildingRentAmount
                        , buildingRentStartDate
                        , buildingRentEndDate
                        , buildingRentActive
                        , entryData
                        , hostName
                    )
                    VALUES
                    (
                          @RentTypeID_INT
                        , @buildingDetailsID
                        , @RentAmount_DEC
                        , ISNULL(@StartDT, GETDATE())
                        , @EndDT
                        , 1
                        , @entryData
                        , @hostName
                    );

                    IF @@ROWCOUNT <= 0
                    BEGIN
                        ;THROW 50003, N'حصل خطأ في اضافة البيانات - BuildingRent', 1; -- برمجي
                    END
                END
                ELSE
                BEGIN
                    INSERT INTO  Housing.BuildingRent
                    (
                          buildingRentTypeID_FK
                        , buildingDetailsID_FK
                        , buildingRentAmount
                        , buildingRentStartDate
                        , buildingRentEndDate
                        , buildingRentActive
                        , entryData
                        , hostName
                    )
                    VALUES
                    (
                          @RentTypeID_INT
                        , @buildingDetailsID
                        , @RentAmount_DEC
                        , ISNULL(@StartDT, GETDATE())
                        , @EndDT
                        , 1
                        , @entryData
                        , @hostName
                    );

                    IF @@ROWCOUNT <= 0
                    BEGIN
                        ;THROW 50003, N'حصل خطأ في اضافة البيانات - BuildingRent', 1; -- برمجي
                    END
                END
            END
            ELSE
            BEGIN
                UPDATE  Housing.BuildingRent
                SET
                      buildingRentActive = 0
                    , buildingRentEndDate = ISNULL(buildingRentEndDate, GETDATE())
                    , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                    , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
                WHERE buildingDetailsID_FK = @buildingDetailsID
                  AND buildingRentActive = 1;
            END

            SET @Note = N'{'
                + N'"buildingDetailsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"buildingDetailsNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingDetails],[Housing].[BuildingRent]'
                , N'UPDATE'
                , @buildingDetailsID
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
            IF @buildingDetailsID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للحذف', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.BuildingDetails bd
                WHERE bd.buildingDetailsID = @buildingDetailsID
                  AND bd.buildingDetailsActive = 1
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            UPDATE  Housing.BuildingDetails
            SET
                  buildingDetailsActive = 0
                , buildingDetailsEndDate = GETDATE()
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE buildingDetailsID = @buildingDetailsID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم حذف أي سجل', 1; -- برمجي/غير متوقع
            END

            -- اقفال الإيجار (إن وجد)
            UPDATE  Housing.BuildingRent
            SET
                  buildingRentActive = 0
                , buildingRentEndDate = GETDATE()
                , entryData = ISNULL(@entryData, entryData)
                , hostName  = ISNULL(@hostName, hostName)
            WHERE buildingDetailsID_FK = @buildingDetailsID
              AND buildingRentActive = 1;

            SET @Note = N'{'
                + N'"buildingDetailsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingDetails],[Housing].[BuildingRent]'
                , N'DELETE'
                , @buildingDetailsID
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
