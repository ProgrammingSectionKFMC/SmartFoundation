
/* =========================================================
   Description:
   تسجيل سداد مخالفة محددة عبر تحديث PaymentDate وبيانات المُسدد.
   - يمنع تسجيل السداد إذا كانت المخالفة مسددة مسبقاً
   Type: WRITE (WORKFLOW)
   Output: IsSuccessful / Message_
========================================================= */
CREATE PROCEDURE [VIC].[Violation_SetPayment_SP]
(
      @violationID   INT
    , @PaymentDate   DATETIME = NULL
    , @entryPayment  NVARCHAR(100)
    , @hostname      NVARCHAR(400)
    , @idaraID_FK    NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;
    DECLARE @PayDT DATETIME = ISNULL(@PaymentDate, GETDATE());

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- AuditLog
    DECLARE @Note_Audit NVARCHAR(MAX) = NULL;

    BEGIN TRY
        IF @violationID IS NULL OR @violationID <= 0
            THROW 50001, N'violationID مطلوب', 1;

        IF @IdaraID_BIG IS NULL
            THROW 50001, N'idaraID_FK مطلوب', 1;

        IF NULLIF(LTRIM(RTRIM(@entryPayment)), N'') IS NULL
            THROW 50001, N'entryPayment مطلوب', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.Violations AS vln
            WHERE vln.violationID = @violationID
              AND vln.IdaraID_FK = @IdaraID_BIG
        )
            THROW 50001, N'المخالفة غير موجودة أو لا تطابق الإدارة', 1;

        IF EXISTS
        (
            SELECT 1
            FROM VIC.Violations AS vln
            WHERE vln.violationID = @violationID
              AND vln.IdaraID_FK = @IdaraID_BIG
              AND vln.PaymentDate IS NOT NULL
        )
            THROW 50001, N'المخالفة مسددة مسبقاً', 1;

        IF @tc = 0 BEGIN TRAN;

        UPDATE VIC.Violations
        SET
              PaymentDate  = @PayDT
            , entryPayment = @entryPayment
            , hostName     = @hostname
        WHERE violationID = @violationID
          AND IdaraID_FK = @IdaraID_BIG;

        IF @@ROWCOUNT <= 0
            THROW 50002, N'لم يتم تحديث السداد', 1;

        -- AuditLog (PAYMENT)
        SET @Note_Audit = N'{'
            + N'"violationID":"'   + ISNULL(CONVERT(NVARCHAR(MAX), @violationID), '') + N'"'
            + N',"PaymentDate":"'  + ISNULL(CONVERT(NVARCHAR(30), @PayDT, 121), '') + N'"'
            + N',"entryPayment":"' + ISNULL(CONVERT(NVARCHAR(MAX), @entryPayment), '') + N'"'
            + N',"hostName":"'     + ISNULL(CONVERT(NVARCHAR(MAX), @hostname), '') + N'"'
            + N',"IdaraID_FK":"'   + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_BIG), '') + N'"'
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
            , N'PAYMENT'
            , ISNULL(@violationID, 0)
            , @entryPayment
            , @Note_Audit
        );

        IF @tc = 0 COMMIT;

        SELECT 1 AS IsSuccessful, N'تم تسجيل سداد المخالفة' AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END