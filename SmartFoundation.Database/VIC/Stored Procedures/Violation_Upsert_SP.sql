
/* =========================================================
   Description:
   إضافة أو تعديل سجل مخالفة في VIC.Violations
   - لا يتم تعديل بيانات السداد هنا
   - التحقق من وجود المركبة ومطابقة الإدارة
   - التحقق من وجود نوع المخالفة وصحته
   Type: WRITE (UPSERT)
   Output: IsSuccessful / Message_
========================================================= */
CREATE PROCEDURE [VIC].[Violation_Upsert_SP]
(
      @violationID        INT = NULL
    , @violationTypeID    INT
    , @chassisNumber      NVARCHAR(100)
    , @violationDate      DATETIME
    , @violationPrice     DECIMAL(18,2) = NULL
    , @violationLocation  NVARCHAR(500) = NULL
    , @idaraID_FK         NVARCHAR(10) = NULL
    , @entryData          NVARCHAR(40)
    , @hostName           NVARCHAR(400)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @CH NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
    DECLARE @LOC NVARCHAR(500) = NULLIF(LTRIM(RTRIM(@violationLocation)), N'');

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE @vehicleID INT = NULL;
    DECLARE @Note_Audit NVARCHAR(MAX) = NULL;

    BEGIN TRY
        IF @violationTypeID IS NULL OR @violationTypeID <= 0
            THROW 50001, N'نوع المخالفة مطلوب', 1;

        IF @CH IS NULL
            THROW 50001, N'رقم الشاصي مطلوب', 1;

        IF @violationDate IS NULL
            THROW 50001, N'تاريخ المخالفة مطلوب', 1;

        IF @IdaraID_BIG IS NULL
            THROW 50001, N'idaraID_FK مطلوب', 1;

        IF NULLIF(LTRIM(RTRIM(@entryData)), N'') IS NULL
            THROW 50001, N'entryData مطلوب', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.Vehicles AS v
            WHERE v.chassisNumber = @CH
              AND v.IdaraID_FK = @IdaraID_BIG
        )
            THROW 50001, N'المركبة غير موجودة أو لا تطابق الإدارة', 1;

        SELECT @vehicleID = v.vehicleID
        FROM VIC.Vehicles AS v
        WHERE v.chassisNumber = @CH
          AND v.IdaraID_FK = @IdaraID_BIG;

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.TypesRoot AS t
            WHERE t.typesID = @violationTypeID
              AND ISNULL(t.typesActive, 0) = 1
        )
            THROW 50001, N'نوع المخالفة غير موجود أو غير نشط', 1;

        IF @violationPrice IS NOT NULL AND @violationPrice < 0
            THROW 50001, N'قيمة المخالفة لا يمكن أن تكون سالبة', 1;

        IF @tc = 0 BEGIN TRAN;

        IF ISNULL(@violationID, 0) = 0
        BEGIN
            INSERT INTO VIC.Violations
            (
                  violationTypeRoot_FK
                , chassisNumber_FK
                , violationDate
                , violationPrice
                , violationLocation
                , entryDate
                , entryData
                , hostName
                , IdaraID_FK
            )
            VALUES
            (
                  @violationTypeID
                , @CH
                , @violationDate
                , @violationPrice
                , @LOC
                , GETDATE()
                , @entryData
                , @hostName
                , @IdaraID_BIG
            );

            SET @violationID = SCOPE_IDENTITY();

            SET @Note_Audit = N'{'
                + N'"violationID":"'       + ISNULL(CONVERT(NVARCHAR(MAX), @violationID), '') + N'"'
                + N',"vehicleID":"'        + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleID), '') + N'"'
                + N',"chassisNumber":"'    + ISNULL(CONVERT(NVARCHAR(MAX), @CH), '') + N'"'
                + N',"violationTypeID":"'  + ISNULL(CONVERT(NVARCHAR(MAX), @violationTypeID), '') + N'"'
                + N',"violationDate":"'    + ISNULL(CONVERT(NVARCHAR(30), @violationDate, 121), '') + N'"'
                + N',"violationPrice":"'   + ISNULL(CONVERT(NVARCHAR(MAX), @violationPrice), '') + N'"'
                + N',"violationLocation":"'+ ISNULL(CONVERT(NVARCHAR(MAX), @LOC), '') + N'"'
                + N',"IdaraID_FK":"'       + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_BIG), '') + N'"'
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
                  N'[VIC].[Violations]'
                , N'INSERT'
                , @violationID
                , @entryData
                , @Note_Audit
            );

            IF @tc = 0 COMMIT;

            SELECT 1 AS IsSuccessful, N'تمت إضافة المخالفة بنجاح' AS Message_;
            RETURN;
        END

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.Violations AS vln
            WHERE vln.violationID = @violationID
              AND vln.IdaraID_FK = @IdaraID_BIG
        )
            THROW 50001, N'المخالفة غير موجودة أو لا تطابق الإدارة', 1;

        UPDATE VIC.Violations
        SET
              violationTypeRoot_FK = @violationTypeID
            , chassisNumber_FK     = @CH
            , violationDate        = @violationDate
            , violationPrice       = @violationPrice
            , violationLocation    = @LOC
            , entryDate            = GETDATE()
            , entryData            = @entryData
            , hostName             = @hostName
        WHERE violationID = @violationID
          AND IdaraID_FK = @IdaraID_BIG;

        IF @@ROWCOUNT <= 0
            THROW 50002, N'لم يتم تحديث المخالفة', 1;

        SET @Note_Audit = N'{'
            + N'"violationID":"'       + ISNULL(CONVERT(NVARCHAR(MAX), @violationID), '') + N'"'
            + N',"vehicleID":"'        + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleID), '') + N'"'
            + N',"chassisNumber":"'    + ISNULL(CONVERT(NVARCHAR(MAX), @CH), '') + N'"'
            + N',"violationTypeID":"'  + ISNULL(CONVERT(NVARCHAR(MAX), @violationTypeID), '') + N'"'
            + N',"violationDate":"'    + ISNULL(CONVERT(NVARCHAR(30), @violationDate, 121), '') + N'"'
            + N',"violationPrice":"'   + ISNULL(CONVERT(NVARCHAR(MAX), @violationPrice), '') + N'"'
            + N',"violationLocation":"'+ ISNULL(CONVERT(NVARCHAR(MAX), @LOC), '') + N'"'
            + N',"IdaraID_FK":"'       + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_BIG), '') + N'"'
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
              N'[VIC].[Violations]'
            , N'UPDATE'
            , @violationID
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0 COMMIT;

        SELECT 1 AS IsSuccessful, N'تم تحديث المخالفة بنجاح' AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END