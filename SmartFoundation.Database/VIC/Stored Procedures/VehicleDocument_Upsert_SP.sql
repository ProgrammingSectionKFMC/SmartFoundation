
/* =========================================================
   Description:
   إدخال/تعديل وثيقة مركبة في VIC.vehicleDocument.
   - يتحقق من وجود chassisNumber في VIC.Vehicles
   - يدعم Insert عند عدم تمرير vehicleDocumentID
   - ويدعم Update عند تمريره
   Type: WRITE (UPSERT)
========================================================= */

CREATE PROCEDURE [VIC].[VehicleDocument_Upsert_SP]
(
      @vehicleDocumentID     INT = NULL
    , @chassisNumber         NVARCHAR(100)
    , @vehicleDocumentTypeID INT
    , @vehicleDocumentNo     NVARCHAR(100) = NULL
    , @StartDate             DATETIME = NULL
    , @EndDate               DATETIME = NULL
    , @idaraID_FK            NVARCHAR(10) = NULL
    , @entryData             NVARCHAR(40)
    , @hostName              NVARCHAR(400)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @FinalID INT = NULL;

    DECLARE @CH    NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
    DECLARE @DocNo NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@vehicleDocumentNo)), N'');

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- AuditLog
    DECLARE @Note_Audit NVARCHAR(MAX) = NULL;

    BEGIN TRY
        IF @CH IS NULL
            THROW 50001, N'chassisNumber مطلوب', 1;

        IF @vehicleDocumentTypeID IS NULL OR @vehicleDocumentTypeID <= 0
            THROW 50001, N'vehicleDocumentTypeID مطلوب', 1;

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

        IF @EndDate IS NOT NULL AND @StartDate IS NOT NULL AND @EndDate < @StartDate
            THROW 50001, N'تاريخ النهاية لا يمكن أن يكون أقل من تاريخ البداية', 1;

        IF @tc = 0 BEGIN TRAN;

        IF @vehicleDocumentID IS NULL
        BEGIN
            INSERT INTO VIC.vehicleDocument
            (
                  vehicleDocumentTypeID_FK
                , chassisNumber_FK
                , vehicleDocumentNo
                , vehicleDocumentStartDate
                , vehicleDocumentEndDate
                , IdaraID_FK
                , entryDate
                , entryData
                , hostName
            )
            VALUES
            (
                  @vehicleDocumentTypeID
                , @CH
                , @DocNo
                , ISNULL(@StartDate, GETDATE())
                , @EndDate
                , @IdaraID_BIG
                , GETDATE()
                , @entryData
                , @hostName
            );

            SET @FinalID = CONVERT(INT, SCOPE_IDENTITY());

            IF @FinalID IS NULL OR @FinalID <= 0
                THROW 50002, N'فشل إضافة الوثيقة', 1; -- CHANGED (50002)

            -- AuditLog (INSERT)
            SET @Note_Audit = N'{'
                + N'"vehicleDocumentID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @FinalID), '') + N'"'
                + N',"chassisNumber":"' + ISNULL(@CH, '') + N'"'
                + N',"vehicleDocumentTypeID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleDocumentTypeID), '') + N'"'
                + N',"vehicleDocumentNo":"' + ISNULL(@DocNo, '') + N'"'
                + N',"StartDate":"' + ISNULL(CONVERT(NVARCHAR(30), ISNULL(@StartDate, GETDATE()), 121), '') + N'"'
                + N',"EndDate":"' + ISNULL(CONVERT(NVARCHAR(30), @EndDate, 121), '') + N'"'
                + N',"IdaraID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_BIG), '') + N'"'
                + N',"entryData":"' + ISNULL(@entryData, '') + N'"'
                + N',"hostName":"' + ISNULL(@hostName, '') + N'"'
                + N'}';

            INSERT INTO DATACORE.dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[VIC].[vehicleDocument]'
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
                FROM VIC.vehicleDocument AS d
                WHERE d.vehicleDocumentID = @vehicleDocumentID
                  AND (@IdaraID_BIG IS NULL OR d.IdaraID_FK = @IdaraID_BIG)
            )
                THROW 50001, N'vehicleDocumentID غير موجود للتعديل', 1;

            UPDATE VIC.vehicleDocument
            SET
                  vehicleDocumentTypeID_FK   = @vehicleDocumentTypeID
                , chassisNumber_FK           = @CH
                , vehicleDocumentNo          = @DocNo
                , vehicleDocumentStartDate   = ISNULL(@StartDate, vehicleDocumentStartDate)
                , vehicleDocumentEndDate     = @EndDate
                , IdaraID_FK                 = @IdaraID_BIG
                , entryDate                  = GETDATE()
                , entryData                  = @entryData
                , hostName                   = @hostName
            WHERE vehicleDocumentID = @vehicleDocumentID
              AND IdaraID_FK = @IdaraID_BIG;

            IF @@ROWCOUNT <= 0
                THROW 50002, N'لم يتم تعديل أي سجل', 1; -- CHANGED (50002)

            SET @FinalID = @vehicleDocumentID;

            -- AuditLog (UPDATE)
            SET @Note_Audit = N'{'
                + N'"vehicleDocumentID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @FinalID), '') + N'"'
                + N',"chassisNumber":"' + ISNULL(@CH, '') + N'"'
                + N',"vehicleDocumentTypeID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleDocumentTypeID), '') + N'"'
                + N',"vehicleDocumentNo":"' + ISNULL(@DocNo, '') + N'"'
                + N',"StartDate":"' + ISNULL(CONVERT(NVARCHAR(30), @StartDate, 121), '') + N'"'
                + N',"EndDate":"' + ISNULL(CONVERT(NVARCHAR(30), @EndDate, 121), '') + N'"'
                + N',"IdaraID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_BIG), '') + N'"'
                + N',"entryData":"' + ISNULL(@entryData, '') + N'"'
                + N',"hostName":"' + ISNULL(@hostName, '') + N'"'
                + N'}';

            INSERT INTO DATACORE.dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[VIC].[vehicleDocument]'
                , N'UPDATE'
                , ISNULL(@FinalID, 0)
                , @entryData
                , @Note_Audit
            );
        END

        IF @tc = 0 COMMIT;

        SELECT
              1 AS IsSuccessful
            , N'تم حفظ الوثيقة بنجاح' AS Message_
            , @FinalID AS vehicleDocumentID;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END