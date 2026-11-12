CREATE   PROCEDURE [VIC].[VehicleSP]
(
      @ActionType             NVARCHAR(100)

    , @vehicleID              BIGINT = NULL
    , @chassisNumber          NVARCHAR(200) = NULL

    , @ownerID_FK             NVARCHAR(200) = NULL
    , @ManufacturerNameID_FK  NVARCHAR(200) = NULL
    , @vehicleModelID_FK      NVARCHAR(200) = NULL
    , @vehicleClassID_FK      NVARCHAR(200) = NULL
    , @TypeOfUseID_FK         NVARCHAR(200) = NULL
    , @vehicleColorID_FK      NVARCHAR(200) = NULL
    , @countryMadeID_FK       NVARCHAR(200) = NULL
    , @regstritionTypeID_FK   NVARCHAR(200) = NULL
    , @regionID_FK            NVARCHAR(200) = NULL
    , @fuelTypeID_FK          NVARCHAR(200) = NULL
    , @vehicleTypeID_FK       NVARCHAR(200) = NULL
    , @yearModel              NVARCHAR(200) = NULL
    , @capacity               NVARCHAR(200) = NULL
    , @serialNumber           NVARCHAR(200) = NULL
    , @plateLetters           NVARCHAR(200) = NULL
    , @plateNumbers           NVARCHAR(200) = NULL
    , @armyNumber             NVARCHAR(200) = NULL
    , @vehicleNote            NVARCHAR(MAX) = NULL

    , @idaraID_FK             NVARCHAR(10) = NULL
    , @entryData              NVARCHAR(40) = NULL
    , @hostName               NVARCHAR(400) = NULL

    , @vehicleDocumentID      INT = NULL
    , @vehicleDocumentTypeID  INT = NULL
    , @vehicleDocumentNo      NVARCHAR(200) = NULL
    , @vehicleDocStartDate    DATETIME = NULL
    , @vehicleDocEndDate      DATETIME = NULL

    , @documentTypeID         INT = NULL
    , @documentTypeNameA      NVARCHAR(100) = NULL
    , @documentTypeNameE      NVARCHAR(100) = NULL
    , @documentTypeActive     BIT = 1

    , @VehicleInsuranceID     INT = NULL
    , @InsuranceOpertionType  INT = NULL
    , @InsuranceTypeID        INT = NULL
    , @Source                 NVARCHAR(300) = NULL
    , @StartInsurance         DATETIME = NULL
    , @EndInsurance           DATETIME = NULL
    , @Amount                 DECIMAL(18,2) = NULL
    , @InsuranceNote          NVARCHAR(800) = NULL
    , @InsuranceActive        BIT = NULL
    , @InsuranceActiveFlag    BIT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;
    DECLARE @CH NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
    DECLARE @IdaraID_BIG BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));
    DECLARE @Note_Audit NVARCHAR(MAX);
    DECLARE @NewID INT;

    ----------------------------------------------------------------
    -- UPSERT
    ----------------------------------------------------------------
    IF @ActionType = 'UPSERT'
    BEGIN
        BEGIN TRY
            IF @CH IS NULL
            BEGIN
                THROW 50001, N'رقم الهيكل مطلوب', 1;
                RETURN;
            END

            IF @IdaraID_BIG IS NULL
            BEGIN
                THROW 50001, N'معرف الإدارة مطلوب', 1;
                RETURN;
            END

            IF EXISTS (SELECT 1 FROM VIC.Vehicles WHERE chassisNumber = @CH AND IdaraID_FK <> @IdaraID_BIG)
            BEGIN
                THROW 50001, N'المركبة مسجلة في إدارة أخرى', 1;
                RETURN;
            END

            IF @tc = 0 BEGIN TRAN;

            IF EXISTS (SELECT 1 FROM VIC.Vehicles WHERE chassisNumber = @CH AND IdaraID_FK = @IdaraID_BIG)
            BEGIN
                UPDATE VIC.Vehicles
                SET ownerID_FK = @ownerID_FK, ManufacturerNameID_FK = @ManufacturerNameID_FK,
                    vehicleModelID_FK = @vehicleModelID_FK, vehicleClassID_FK = @vehicleClassID_FK,
                    TypeOfUseID_FK = @TypeOfUseID_FK, vehicleColorID_FK = @vehicleColorID_FK,
                    countryMadeID_FK = @countryMadeID_FK, regstritionTypeID_FK = @regstritionTypeID_FK,
                    regionID_FK = @regionID_FK, fuelTypeID_FK = @fuelTypeID_FK,
                    vehicleTypeID_FK = @vehicleTypeID_FK, yearModel = @yearModel,
                    capacity = @capacity, serialNumber = @serialNumber,
                    plateLetters = @plateLetters, plateNumbers = @plateNumbers,
                    armyNumber = @armyNumber, vehicleNote = @vehicleNote,
                    entryDate = GETDATE(), entryData = @entryData, hostName = @hostName
                WHERE chassisNumber = @CH AND IdaraID_FK = @IdaraID_BIG;

                SET @Note_Audit = N'{"chassisNumber":"' + @CH + N'","IdaraID":"' + ISNULL(@idaraID_FK, N'') + N'","Action":"UPDATE","entryData":"' + ISNULL(@entryData, N'') + N'"}';
            END
            ELSE
            BEGIN
                INSERT INTO VIC.Vehicles
                (ownerID_FK, ManufacturerNameID_FK, vehicleModelID_FK, vehicleClassID_FK, TypeOfUseID_FK,
                 vehicleColorID_FK, countryMadeID_FK, regstritionTypeID_FK, regionID_FK, fuelTypeID_FK,
                 vehicleTypeID_FK, yearModel, capacity, chassisNumber, serialNumber, plateLetters,
                 plateNumbers, armyNumber, vehicleNote, entryDate, entryData, hostName, IdaraID_FK,
                 vehicleStatusID_FK)
                VALUES
                (@ownerID_FK, @ManufacturerNameID_FK, @vehicleModelID_FK, @vehicleClassID_FK, @TypeOfUseID_FK,
                 @vehicleColorID_FK, @countryMadeID_FK, @regstritionTypeID_FK, @regionID_FK, @fuelTypeID_FK,
                 @vehicleTypeID_FK, @yearModel, @capacity, @CH, @serialNumber, @plateLetters,
                 @plateNumbers, @armyNumber, @vehicleNote, GETDATE(), @entryData, @hostName, @IdaraID_BIG,
                 260);

                SET @Note_Audit = N'{"chassisNumber":"' + @CH + N'","IdaraID":"' + ISNULL(@idaraID_FK, N'') + N'","Action":"INSERT","entryData":"' + ISNULL(@entryData, N'') + N'"}';
            END

            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[Vehicles]', N'UPSERT', 0, @entryData, @Note_Audit);

            IF @tc = 0 COMMIT;

            SELECT CAST(1 AS BIT) AS IsSuccessful, N'تم حفظ المركبة بنجاح' AS Message_, @CH AS chassisNumber, v.vehicleID
            FROM VIC.Vehicles v WHERE v.chassisNumber = @CH AND v.IdaraID_FK = @IdaraID_BIG;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- UPSERT_DOCUMENT
    ----------------------------------------------------------------
    IF @ActionType = 'UPSERT_DOCUMENT'
    BEGIN
        BEGIN TRY
            IF @CH IS NULL
            BEGIN
                THROW 50001, N'رقم الهيكل مطلوب', 1;
                RETURN;
            END

            IF @IdaraID_BIG IS NULL
            BEGIN
                THROW 50001, N'معرف الإدارة مطلوب', 1;
                RETURN;
            END

            IF @vehicleDocumentTypeID IS NULL OR @vehicleDocumentTypeID <= 0
            BEGIN
                THROW 50001, N'نوع الوثيقة مطلوب', 1;
                RETURN;
            END

            IF NOT EXISTS (SELECT 1 FROM VIC.Vehicles WHERE chassisNumber = @CH AND IdaraID_FK = @IdaraID_BIG)
            BEGIN
                THROW 50001, N'المركبة غير موجودة في الإدارة الحالية', 1;
                RETURN;
            END

            IF @vehicleDocEndDate IS NOT NULL AND @vehicleDocStartDate IS NOT NULL AND @vehicleDocEndDate < @vehicleDocStartDate
            BEGIN
                THROW 50001, N'يجب أن يكون تاريخ النهاية مساويًا لتاريخ البداية أو بعده', 1;
                RETURN;
            END

            IF @tc = 0 BEGIN TRAN;

            IF ISNULL(@vehicleDocumentID, 0) = 0
            BEGIN
                INSERT INTO VIC.vehicleDocument
                (chassisNumber_FK, vehicleDocumentTypeID_FK, vehicleDocumentNo,
                 vehicleDocumentStartDate, vehicleDocumentEndDate, IdaraID_FK, entryDate, entryData, hostName)
                VALUES (@CH, @vehicleDocumentTypeID, NULLIF(LTRIM(RTRIM(@vehicleDocumentNo)), N''),
                        @vehicleDocStartDate, @vehicleDocEndDate, @IdaraID_BIG, GETDATE(), @entryData, @hostName);

                SET @NewID = CONVERT(INT, SCOPE_IDENTITY());
                SET @Note_Audit = N'{"vehicleDocumentID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), N'') + N'","chassisNumber":"' + @CH + N'","Action":"INSERT"}';
            END
            ELSE
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM VIC.vehicleDocument WHERE vehicleDocumentID = @vehicleDocumentID)
                BEGIN
                    THROW 50001, N'الوثيقة غير موجودة', 1;
                    RETURN;
                END

                UPDATE VIC.vehicleDocument
                SET chassisNumber_FK = @CH, vehicleDocumentTypeID_FK = @vehicleDocumentTypeID,
                    vehicleDocumentNo = NULLIF(LTRIM(RTRIM(@vehicleDocumentNo)), N''),
                    vehicleDocumentStartDate = @vehicleDocStartDate, vehicleDocumentEndDate = @vehicleDocEndDate,
                    entryDate = GETDATE(), entryData = @entryData, hostName = @hostName
                WHERE vehicleDocumentID = @vehicleDocumentID;

                SET @Note_Audit = N'{"vehicleDocumentID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleDocumentID), N'') + N'","chassisNumber":"' + @CH + N'","Action":"UPDATE"}';
            END

            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[vehicleDocument]', N'UPSERT_DOCUMENT', ISNULL(@vehicleDocumentID, 0), @entryData, @Note_Audit);

            IF @tc = 0 COMMIT;
            SELECT CAST(1 AS BIT) AS IsSuccessful, N'تم حفظ الوثيقة بنجاح' AS Message_;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- UPSERT_DOCUMENT_TYPE
    ----------------------------------------------------------------
    IF @ActionType = 'UPSERT_DOCUMENT_TYPE'
    BEGIN
        BEGIN TRY
            DECLARE @DTN NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@documentTypeNameA)), N'');

            IF @DTN IS NULL
            BEGIN
                THROW 50001, N'الاسم العربي مطلوب', 1;
                RETURN;
            END

            IF @tc = 0 BEGIN TRAN;

            IF ISNULL(@documentTypeID, 0) = 0
            BEGIN
                IF EXISTS (SELECT 1 FROM VIC.VehiclesDocumentType WHERE vehicleDocumentTypeName_A = @DTN)
                BEGIN
                    THROW 50001, N'اسم نوع الوثيقة موجود مسبقًا', 1;
                    RETURN;
                END

                INSERT INTO VIC.VehiclesDocumentType (vehicleDocumentTypeName_A, vehicleDocumentTypeName_E, vehicleDocumentTypeActive, entryDate)
                VALUES (@DTN, NULLIF(LTRIM(RTRIM(@documentTypeNameE)), N''), @documentTypeActive, GETDATE());

                SET @NewID = CONVERT(INT, SCOPE_IDENTITY());
            END
            ELSE
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM VIC.VehiclesDocumentType WHERE vehicleDocumentTypeID = @documentTypeID)
                BEGIN
                    THROW 50001, N'نوع الوثيقة غير موجود', 1;
                    RETURN;
                END

                UPDATE VIC.VehiclesDocumentType
                SET vehicleDocumentTypeName_A = @DTN, vehicleDocumentTypeName_E = NULLIF(LTRIM(RTRIM(@documentTypeNameE)), N''),
                    vehicleDocumentTypeActive = @documentTypeActive
                WHERE vehicleDocumentTypeID = @documentTypeID;
            END

            SET @Note_Audit = N'{"documentTypeID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @documentTypeID), N'') + N'","nameA":"' + ISNULL(@DTN, N'') + N'"}';

            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[VehiclesDocumentType]', N'UPSERT_DOCUMENT_TYPE', ISNULL(@documentTypeID, 0), @entryData, @Note_Audit);

            IF @tc = 0 COMMIT;
            SELECT CAST(1 AS BIT) AS IsSuccessful, N'تم حفظ نوع الوثيقة بنجاح' AS Message_;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- UPSERT_INSURANCE
    ----------------------------------------------------------------
    IF @ActionType = 'UPSERT_INSURANCE'
    BEGIN
        BEGIN TRY
            IF @CH IS NULL
            BEGIN
                THROW 50001, N'رقم الهيكل مطلوب', 1;
                RETURN;
            END

            IF @IdaraID_BIG IS NULL
            BEGIN
                THROW 50001, N'معرف الإدارة مطلوب', 1;
                RETURN;
            END

            IF NOT EXISTS (SELECT 1 FROM VIC.Vehicles WHERE chassisNumber = @CH AND IdaraID_FK = @IdaraID_BIG)
            BEGIN
                THROW 50001, N'المركبة غير موجودة في الإدارة الحالية', 1;
                RETURN;
            END

            IF @EndInsurance IS NOT NULL AND @StartInsurance IS NOT NULL AND @EndInsurance < @StartInsurance
            BEGIN
                THROW 50001, N'يجب أن يكون تاريخ النهاية مساويًا لتاريخ البداية أو بعده', 1;
                RETURN;
            END

            IF @tc = 0 BEGIN TRAN;

            IF ISNULL(@VehicleInsuranceID, 0) = 0
            BEGIN
                IF EXISTS (
                    SELECT 1 FROM VIC.VehicleInsurance
                    WHERE chassisNumber_FK = @CH
                      AND IdaraID_FK = @IdaraID_BIG
                      AND @StartInsurance <= ISNULL(EndInsurance, '9999-12-31')
                      AND ISNULL(@EndInsurance, '9999-12-31') >= StartInsurance
                )
                BEGIN
                    THROW 50001, N'يوجد تأمين آخر لنفس المركبة يتداخل مع هذا التاريخ. يرجى مراجعة التواريخ', 1;
                    RETURN;
                END

                INSERT INTO VIC.VehicleInsurance
                (chassisNumber_FK, InsuranceOpertionType_FK, InsuranceTypeID_FK, Source, StartInsurance, EndInsurance,
                 Amount, Note, active, IdaraID_FK, entryDate, entryData, hostName)
                VALUES (@CH, @InsuranceOpertionType, @InsuranceTypeID, NULLIF(LTRIM(RTRIM(@Source)), N''),
                        @StartInsurance, @EndInsurance, @Amount, NULLIF(LTRIM(RTRIM(@InsuranceNote)), N''),
                        ISNULL(@InsuranceActive, 1), @IdaraID_BIG, GETDATE(), @entryData, @hostName);

                SET @NewID = CONVERT(INT, SCOPE_IDENTITY());
            END
            ELSE
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM VIC.VehicleInsurance WHERE VehicleInsuranceID = @VehicleInsuranceID AND IdaraID_FK = @IdaraID_BIG)
                BEGIN
                    THROW 50001, N'سجل التأمين غير موجود في الإدارة الحالية', 1;
                    RETURN;
                END

                IF EXISTS (
                    SELECT 1 FROM VIC.VehicleInsurance
                    WHERE chassisNumber_FK = @CH
                      AND IdaraID_FK = @IdaraID_BIG
                      AND VehicleInsuranceID <> @VehicleInsuranceID
                      AND @StartInsurance <= ISNULL(EndInsurance, '9999-12-31')
                      AND ISNULL(@EndInsurance, '9999-12-31') >= StartInsurance
                )
                BEGIN
                    THROW 50001, N'يوجد تأمين آخر لنفس المركبة يتداخل مع هذا التاريخ. يرجى مراجعة التواريخ', 1;
                    RETURN;
                END

                UPDATE VIC.VehicleInsurance
                SET InsuranceOpertionType_FK = @InsuranceOpertionType, InsuranceTypeID_FK = @InsuranceTypeID,
                    Source = NULLIF(LTRIM(RTRIM(@Source)), N''), StartInsurance = @StartInsurance,
                    EndInsurance = @EndInsurance, Amount = @Amount, Note = NULLIF(LTRIM(RTRIM(@InsuranceNote)), N''),
                    entryDate = GETDATE(), entryData = @entryData, hostName = @hostName
                WHERE VehicleInsuranceID = @VehicleInsuranceID AND IdaraID_FK = @IdaraID_BIG;
            END

            SET @Note_Audit = N'{"VehicleInsuranceID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @VehicleInsuranceID), N'') + N'","chassisNumber":"' + @CH + N'"}';

            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[VehicleInsurance]', N'UPSERT_INSURANCE', ISNULL(@VehicleInsuranceID, 0), @entryData, @Note_Audit);

            IF @tc = 0 COMMIT;
            SELECT CAST(1 AS BIT) AS IsSuccessful, N'تم حفظ التأمين بنجاح' AS Message_;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- SET_INSURANCE_ACTIVE
    ----------------------------------------------------------------
    IF @ActionType = 'SET_INSURANCE_ACTIVE'
    BEGIN
        BEGIN TRY
            IF @VehicleInsuranceID IS NULL OR @VehicleInsuranceID <= 0
            BEGIN
                THROW 50001, N'معرف سجل التأمين مطلوب', 1;
                RETURN;
            END

            IF @IdaraID_BIG IS NULL
            BEGIN
                THROW 50001, N'معرف الإدارة مطلوب', 1;
                RETURN;
            END

            IF NOT EXISTS (SELECT 1 FROM VIC.VehicleInsurance WHERE VehicleInsuranceID = @VehicleInsuranceID AND IdaraID_FK = @IdaraID_BIG)
            BEGIN
                THROW 50001, N'سجل التأمين غير موجود في الإدارة الحالية', 1;
                RETURN;
            END

            DECLARE @CurrentActive BIT;
            DECLARE @NewActive BIT;
            DECLARE @TargetChassis NVARCHAR(200);

            SELECT @CurrentActive = ISNULL(active, 0), @TargetChassis = chassisNumber_FK
            FROM VIC.VehicleInsurance WHERE VehicleInsuranceID = @VehicleInsuranceID;

            SET @NewActive = CASE WHEN @CurrentActive = 1 THEN 0 ELSE 1 END;

            IF @tc = 0 BEGIN TRAN;

            IF @NewActive = 1
            BEGIN
                UPDATE VIC.VehicleInsurance
                SET active = 0, entryDate = GETDATE(), entryData = @entryData, hostName = @hostName
                WHERE chassisNumber_FK = @TargetChassis
                  AND IdaraID_FK = @IdaraID_BIG
                  AND VehicleInsuranceID <> @VehicleInsuranceID
                  AND ISNULL(active, 0) = 1;
            END

            UPDATE VIC.VehicleInsurance
            SET active = @NewActive, entryDate = GETDATE(), entryData = @entryData, hostName = @hostName
            WHERE VehicleInsuranceID = @VehicleInsuranceID AND IdaraID_FK = @IdaraID_BIG;

            IF @@ROWCOUNT <= 0
            BEGIN
                THROW 50002, N'فشل تحديث التأمين', 1;
                RETURN;
            END

            SET @Note_Audit = N'{"VehicleInsuranceID":"' + CONVERT(NVARCHAR(MAX), @VehicleInsuranceID) + N'","active":"' + CONVERT(NVARCHAR(10), @NewActive) + N'"}';

            INSERT INTO DATACORE.dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES (N'[VIC].[VehicleInsurance]', N'SET_INSURANCE_ACTIVE', @VehicleInsuranceID, @entryData, @Note_Audit);

            IF @tc = 0 COMMIT;
            SELECT CAST(1 AS BIT) AS IsSuccessful, N'تم تحديث حالة التأمين بنجاح' AS Message_;
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- Unknown ActionType
    ----------------------------------------------------------------
    BEGIN
        THROW 50001, N'نوع العملية غير معروف في إجراء معالجة المركبات', 1;
        RETURN;
    END
END

GO

