
/* =========================================================
   Description:
   إضافة/تعديل نوع طلب نقل مركبة في جدول VIC.VehicleTransferRequestType
   مع منع تكرار الاسم العربي وتحديث حالة التفعيل.
   Type: WRITE (UPSERT)
========================================================= */

CREATE   PROCEDURE [VIC].[TransferRequestType_Upsert_SP]
(
      @vehicleTransferRequestTypeID INT = NULL
    , @nameA                        NVARCHAR(100)
    , @nameE                        NVARCHAR(100) = NULL
    , @active                       BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @NameA_Trim NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@nameA)), N'');
    DECLARE @NameE_Trim NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@nameE)), N'');

    DECLARE @IsInsert BIT = CASE WHEN @vehicleTransferRequestTypeID IS NULL THEN 1 ELSE 0 END;

    BEGIN TRY

        IF @tc = 0
            BEGIN TRAN;

        IF @NameA_Trim IS NULL
            THROW 50001, N'اسم النوع العربي مطلوب', 1;

        IF EXISTS
        (
            SELECT 1
            FROM VIC.VehicleTransferRequestType AS t
            WHERE t.VehicleTransferRequestTypeNameA = @NameA_Trim
              AND (@vehicleTransferRequestTypeID IS NULL OR t.VehicleTransferRequestTypeID <> @vehicleTransferRequestTypeID)
        )
            THROW 50001, N'اسم النوع العربي موجود مسبقاً', 1;

        IF @IsInsert = 1
        BEGIN
            INSERT INTO VIC.VehicleTransferRequestType
            (
                  VehicleTransferRequestTypeNameA
                , VehicleTransferRequestTypeNameE
                , Active
            )
            VALUES
            (
                  @NameA_Trim
                , @NameE_Trim
                , @active
            );

            SET @vehicleTransferRequestTypeID = CONVERT(INT, SCOPE_IDENTITY());

            IF @vehicleTransferRequestTypeID IS NULL OR @vehicleTransferRequestTypeID <= 0
                THROW 50002, N'فشل إضافة نوع طلب النقل', 1;  -- CHANGED (50002)
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM VIC.VehicleTransferRequestType WHERE VehicleTransferRequestTypeID = @vehicleTransferRequestTypeID)
                THROW 50001, N'السجل غير موجود للتعديل', 1;

            UPDATE VIC.VehicleTransferRequestType
            SET
                  VehicleTransferRequestTypeNameA = @NameA_Trim
                , VehicleTransferRequestTypeNameE = @NameE_Trim
                , Active                          = @active
            WHERE VehicleTransferRequestTypeID = @vehicleTransferRequestTypeID;

            IF @@ROWCOUNT <= 0
                THROW 50002, N'لم يتم تعديل أي سجل', 1; -- CHANGED (50002)
        END

        IF @tc = 0
            COMMIT;

        SELECT
              1 AS IsSuccessful
            , CASE WHEN @IsInsert = 1 THEN N'تمت الإضافة بنجاح' ELSE N'تم التعديل بنجاح' END AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END