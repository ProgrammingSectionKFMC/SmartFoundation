
/* =========================================================
   Description:
   إضافة/تعديل سجل تأمين لمركبة في VIC.VehicleInsurance.
   - يتحقق من وجود المركبة
   - يتحقق من منطق تواريخ التأمين (End >= Start)
   - يحدّث حقول التدقيق entryDate/entryData/hostName
   Type: WRITE (UPSERT)
========================================================= */
CREATE PROCEDURE [VIC].[VehicleInsurance_Upsert_SP]
(
      @VehicleInsuranceID INT = NULL
    , @chassisNumber      NVARCHAR(100)
    , @OperationTypeID    INT = NULL
    , @InsuranceTypeID    INT = NULL
    , @Source             NVARCHAR(300) = NULL
    , @StartInsurance     DATETIME = NULL
    , @EndInsurance       DATETIME = NULL
    , @Amount             FLOAT = NULL
    , @Note               NVARCHAR(800) = NULL
    , @active             BIT = 1
    , @idaraID_FK         NVARCHAR(10) = NULL
    , @entryData          NVARCHAR(40)
    , @hostName           NVARCHAR(400)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @FinalID INT = NULL;

    DECLARE @CH NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
    DECLARE @StartDT DATETIME = ISNULL(@StartInsurance, GETDATE());

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- AuditLog
    DECLARE @Note_Audit NVARCHAR(MAX) = NULL;

    BEGIN TRY
        IF @CH IS NULL
            THROW 50001, N'chassisNumber مطلوب', 1;

        IF @IdaraID_BIG IS NULL
            THROW 50001, N'idaraID_FK مطلوب', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.Vehicles AS v
            WHERE v.chassisNumber = @CH
              AND v.IdaraID_FK = @IdaraID_BIG
        )
            THROW 50001, N'رقم الشاصي غير موجود أو لا يطابق الإدارة', 1;

        IF @EndInsurance IS NOT NULL AND @EndInsurance < @StartDT
            THROW 50001, N'لا يمكن أن يكون تاريخ نهاية التأمين أقل من تاريخ البداية', 1;

        IF @tc = 0 BEGIN TRAN;

        IF @VehicleInsuranceID IS NULL
        BEGIN
            INSERT INTO VIC.VehicleInsurance
            (
                  InsuranceOpertionType_FK
                , InsuranceTypeID_FK
                , chassisNumber_FK
                , Source
                , StartInsurance
                , EndInsurance
                , Amount
                , Note
                , active
                , IdaraID_FK
                , entryDate
                , entryData
                , hostName
            )
            VALUES
            (
                  @OperationTypeID
                , @InsuranceTypeID
                , @CH
                , @Source
                , @StartDT
                , @EndInsurance
                , @Amount
                , @Note
                , @active
                , @IdaraID_BIG
                , GETDATE()
                , @entryData
                , @hostName
            );

            SET @FinalID = CONVERT(INT, SCOPE_IDENTITY());

            IF @FinalID IS NULL OR @FinalID <= 0
                THROW 50002, N'فشل إضافة التأمين', 1;

            SET @Note_Audit = N'{'
                + N'"VehicleInsuranceID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @FinalID), '') + N'"'
                + N',"chassisNumber":"'     + ISNULL(CONVERT(NVARCHAR(MAX), @CH), '') + N'"'
                + N',"OperationTypeID":"'   + ISNULL(CONVERT(NVARCHAR(MAX), @OperationTypeID), '') + N'"'
                + N',"InsuranceTypeID":"'   + ISNULL(CONVERT(NVARCHAR(MAX), @InsuranceTypeID), '') + N'"'
                + N',"StartInsurance":"'    + ISNULL(CONVERT(NVARCHAR(30), @StartDT, 121), '') + N'"'
                + N',"EndInsurance":"'      + ISNULL(CONVERT(NVARCHAR(30), @EndInsurance, 121), '') + N'"'
                + N',"active":"'            + ISNULL(CONVERT(NVARCHAR(MAX), @active), '') + N'"'
                + N',"IdaraID_FK":"'         + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_BIG), '') + N'"'
                + N',"entryData":"'          + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName":"'           + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO DATACORE.dbo.AuditLog
            (
                  TableName, ActionType, RecordID, PerformedBy, Notes
            )
            VALUES
            (
                  N'[VIC].[VehicleInsurance]'
                , N'INSERT'
                , ISNULL(@FinalID, 0)
                , @entryData
                , @Note_Audit
            );
        END
        ELSE
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM VIC.VehicleInsurance AS i
                WHERE i.VehicleInsuranceID = @VehicleInsuranceID
                  AND i.IdaraID_FK = @IdaraID_BIG
            )
                THROW 50001, N'VehicleInsuranceID غير موجود للتعديل أو لا يطابق الإدارة', 1;

            UPDATE VIC.VehicleInsurance
            SET
                  InsuranceOpertionType_FK = @OperationTypeID
                , InsuranceTypeID_FK       = @InsuranceTypeID
                , chassisNumber_FK         = @CH
                , Source                   = @Source
                , StartInsurance           = @StartDT
                , EndInsurance             = @EndInsurance
                , Amount                   = @Amount
                , Note                     = @Note
                , active                   = @active
                , IdaraID_FK               = @IdaraID_BIG
                , entryDate                = GETDATE()
                , entryData                = @entryData
                , hostName                 = @hostName
            WHERE VehicleInsuranceID = @VehicleInsuranceID
              AND IdaraID_FK = @IdaraID_BIG;

            IF @@ROWCOUNT <= 0
                THROW 50002, N'لم يتم تعديل أي سجل', 1;

            SET @FinalID = @VehicleInsuranceID;

            SET @Note_Audit = N'{'
                + N'"VehicleInsuranceID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @FinalID), '') + N'"'
                + N',"chassisNumber":"'     + ISNULL(CONVERT(NVARCHAR(MAX), @CH), '') + N'"'
                + N',"OperationTypeID":"'   + ISNULL(CONVERT(NVARCHAR(MAX), @OperationTypeID), '') + N'"'
                + N',"InsuranceTypeID":"'   + ISNULL(CONVERT(NVARCHAR(MAX), @InsuranceTypeID), '') + N'"'
                + N',"StartInsurance":"'    + ISNULL(CONVERT(NVARCHAR(30), @StartDT, 121), '') + N'"'
                + N',"EndInsurance":"'      + ISNULL(CONVERT(NVARCHAR(30), @EndInsurance, 121), '') + N'"'
                + N',"active":"'            + ISNULL(CONVERT(NVARCHAR(MAX), @active), '') + N'"'
                + N',"IdaraID_FK":"'         + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_BIG), '') + N'"'
                + N',"entryData":"'          + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName":"'           + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO DATACORE.dbo.AuditLog
            (
                  TableName, ActionType, RecordID, PerformedBy, Notes
            )
            VALUES
            (
                  N'[VIC].[VehicleInsurance]'
                , N'UPDATE'
                , ISNULL(@FinalID, 0)
                , @entryData
                , @Note_Audit
            );
        END

        IF @tc = 0 COMMIT;

        SELECT
              1 AS IsSuccessful
            , N'تم حفظ التأمين بنجاح' AS Message_
            , @FinalID AS VehicleInsuranceID;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END