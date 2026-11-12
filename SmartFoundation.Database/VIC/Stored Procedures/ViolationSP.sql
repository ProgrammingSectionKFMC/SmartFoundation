CREATE   PROCEDURE [VIC].[ViolationSP]
(
      @ActionType           NVARCHAR(100)
    , @violationID          INT = NULL
    , @violationTypeID      INT = NULL
    , @vehicleID            INT = NULL
    , @chassisNumber        NVARCHAR(200) = NULL
    , @violationDate        DATETIME = NULL
    , @violationPrice       DECIMAL(18,2) = NULL
    , @violationLocation    NVARCHAR(300) = NULL
    , @PaymentDate          DATETIME = NULL
    , @entryPayment         NVARCHAR(100) = NULL
    , @idaraID_FK           NVARCHAR(10) = NULL
    , @entryData            NVARCHAR(40) = NULL
    , @hostName             NVARCHAR(400) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;
    DECLARE @IdaraID_BIG BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE @CH NVARCHAR(200);
    DECLARE @VID INT;

    IF @vehicleID IS NOT NULL
    BEGIN
        SELECT @CH = v.chassisNumber, @VID = v.vehicleID
        FROM VIC.Vehicles v WHERE v.vehicleID = @vehicleID;
    END
    ELSE IF @chassisNumber IS NOT NULL
    BEGIN
        SET @CH = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
        SELECT @VID = v.vehicleID FROM VIC.Vehicles v WHERE v.chassisNumber = @CH;
    END

    ----------------------------------------------------------------
    -- UPSERT
    ----------------------------------------------------------------
    IF @ActionType = N'UPSERT'
    BEGIN
        BEGIN TRY

            IF @IdaraID_BIG IS NULL
                THROW 50001, N'الإدارة مطلوبة', 1;

            IF @violationTypeID IS NULL
                THROW 50001, N'نوع المخالفة مطلوب', 1;

            IF @CH IS NULL
                THROW 50001, N'رقم الهيكل مطلوب', 1;

            IF @violationDate IS NULL
                THROW 50001, N'تاريخ المخالفة مطلوب', 1;

            IF NOT EXISTS (
                SELECT 1 FROM VIC.Vehicles
                WHERE chassisNumber = @CH
                  AND IdaraID_FK = @IdaraID_BIG
            )
                THROW 50001, N'المركبة غير موجودة أو لا تطابق الإدارة', 1;

            IF NOT EXISTS (
                SELECT 1 FROM VIC.TypesRoot
                WHERE typesID = @violationTypeID
                  AND ISNULL(typesActive,1)=1
            )
                THROW 50001, N'نوع المخالفة غير صحيح', 1;

            IF @violationPrice IS NOT NULL
   AND @violationPrice < 0
    THROW 50001, N'قيمة المخالفة غير صحيحة', 1;

            IF @tc = 0 BEGIN TRAN;

            IF @violationID IS NULL
            BEGIN
                INSERT INTO VIC.Violations
                (
                    violationTypeRoot_FK,
                    chassisNumber_FK,
                    violationDate,
                    violationPrice,
                    violationLocation,
                    entrydate,
                    entrydata,
                    hostname,
                    IdaraID_FK
                )
                VALUES
                (
                    @violationTypeID,
                    @CH,
                    @violationDate,
                    @violationPrice,
                    NULLIF(LTRIM(RTRIM(@violationLocation)), N''),
                    GETDATE(),
                    @entryData,
                    @hostName,
                    @IdaraID_BIG
                );

                SET @violationID = SCOPE_IDENTITY();
            END
            ELSE
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM VIC.Violations
                    WHERE violationID = @violationID
                      AND IdaraID_FK = @IdaraID_BIG
                )
                    THROW 50001, N'المخالفة غير موجودة', 1;

                    IF EXISTS (
    SELECT 1
    FROM VIC.Violations
    WHERE violationID = @violationID
      AND IdaraID_FK = @IdaraID_BIG
      AND PaymentDate IS NOT NULL
)
    THROW 50001, N'لا يمكن تعديل مخالفة مدفوعة', 1;


                UPDATE VIC.Violations
                SET violationTypeRoot_FK = @violationTypeID,
                    chassisNumber_FK    = @CH,
                    violationDate       = @violationDate,
                    violationPrice      = @violationPrice,
                    violationLocation   = NULLIF(LTRIM(RTRIM(@violationLocation)), N''),
                    entrydata           = @entryData,
                    hostname            = @hostName
                WHERE violationID = @violationID
                  AND IdaraID_FK = @IdaraID_BIG;
            END

            IF @tc = 0 COMMIT;

            SELECT 1 AS IsSuccessful,
                   N'تم حفظ المخالفة' AS Message_;
                   
        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ----------------------------------------------------------------
    -- SET_PAYMENT
    ----------------------------------------------------------------
    IF @ActionType = N'SET_PAYMENT'
    BEGIN
        BEGIN TRY

            IF @IdaraID_BIG IS NULL
                THROW 50001, N'الإدارة مطلوبة', 1;

            IF @violationID IS NULL
                THROW 50001, N'رقم المخالفة مطلوب', 1;

            IF EXISTS (
                SELECT 1 FROM VIC.Violations
                WHERE violationID = @violationID
                  AND PaymentDate IS NOT NULL
            )
                THROW 50001, N'المخالفة مدفوعة مسبقاً', 1;

            IF @tc = 0 BEGIN TRAN;

            UPDATE VIC.Violations
            SET PaymentDate = ISNULL(@PaymentDate, GETDATE()),
                entryPayment = @entryPayment,
                entrydata = @entryData,
                hostname = @hostName
            WHERE violationID = @violationID
              AND IdaraID_FK = @IdaraID_BIG;

            IF @@ROWCOUNT = 0
                THROW 50002, N'فشل في تسجيل السداد', 1;

            IF @tc = 0 COMMIT;

            SELECT 1 AS IsSuccessful,
                   N'تم تسجيل السداد' AS Message_;

        END TRY
        BEGIN CATCH
            IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
            THROW;
        END CATCH
        RETURN;
    END

    ;THROW 50001, N'نوع العملية غير معروف في إجراء معالجة المخالفات', 1;
END

GO

