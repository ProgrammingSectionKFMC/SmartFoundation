
/* =========================================================
   Description:
   إضافة/تعديل بند صيانة في جدول VIC.MaintenanceDetails،
   مع التحقق من وجود أمر الصيانة المرتبط ومطابقة الإدارة
   ومن أن أمر الصيانة غير مقفل (MaintOrdActive = 1).
   Type: WRITE (UPSERT)
========================================================= */

CREATE PROCEDURE [VIC].[MaintenanceDetails_Upsert_SP]
(
      @maintDetailesID   INT = NULL
    , @maintOrdID        INT
    , @typesID_FK        INT = NULL
    , @SupportID_FK      INT = NULL
    , @CheckStatus_FK    INT = NULL
    , @ActionState       NVARCHAR(400) = NULL
    , @CorrectiveAction  NVARCHAR(1000) = NULL
    , @FSN               NVARCHAR(400) = NULL
    , @MaintLevel        NVARCHAR(400) = NULL
    , @CurrentDate       DATETIME = NULL
    , @Notes             NVARCHAR(1000) = NULL
    , @idaraID_FK        NVARCHAR(10) = NULL
    , @entryData         NVARCHAR(40) = NULL
    , @hostName          NVARCHAR(400) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE @CurrentDT DATETIME = ISNULL(@CurrentDate, GETDATE());

    DECLARE
          @ActionType NVARCHAR(20) = NULL
        , @Note_Audit NVARCHAR(MAX) = NULL
        , @NewID INT = NULL;

    BEGIN TRY

        IF @tc = 0
            BEGIN TRAN;

        IF @maintOrdID IS NULL OR @maintOrdID <= 0
            THROW 50001, N'maintOrdID مطلوب', 1;

        -- تحقق وجود أمر الصيانة + مطابقة الإدارة (إن تم تمريرها)
        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.VehicleMaintenance AS m
            WHERE m.MaintOrdID = @maintOrdID
              AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)
        )
            THROW 50001, N'أمر الصيانة غير موجود أو لا يطابق الإدارة', 1;

        -- NEW: منع الإضافة/التعديل إذا كان أمر الصيانة مقفل
        IF EXISTS
        (
            SELECT 1
            FROM VIC.VehicleMaintenance AS m
            WHERE m.MaintOrdID = @maintOrdID
              AND m.MaintOrdActive = 0
        )
            THROW 50001, N'الأمر مقفل لا يمكن إضافة أو تعديل البنود', 1;

        IF @maintDetailesID IS NULL
        BEGIN
            INSERT INTO VIC.MaintenanceDetails
            (
                  MaintOrdID_FK
                , typesID_FK
                , SupportID_FK
                , CheckStatus_FK
                , ActionState
                , CorrectiveAction
                , FSN
                , MaintLevel
                , CurrentDate
                , Notes
                , entryDate
                , entryData
                , hostName
            )
            VALUES
            (
                  @maintOrdID
                , @typesID_FK
                , @SupportID_FK
                , @CheckStatus_FK
                , @ActionState
                , @CorrectiveAction
                , @FSN
                , @MaintLevel
                , @CurrentDT
                , @Notes
                , GETDATE()
                , @entryData
                , @hostName
            );

            SET @maintDetailesID = CONVERT(INT, SCOPE_IDENTITY());

            IF @maintDetailesID IS NULL OR @maintDetailesID <= 0
                THROW 50002, N'فشل إضافة بند الصيانة', 1;

            SET @ActionType = N'INSERT';
        END
        ELSE
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM VIC.MaintenanceDetails AS d
                INNER JOIN VIC.VehicleMaintenance AS m
                    ON m.MaintOrdID = d.MaintOrdID_FK
                WHERE d.MaintDetailesID = @maintDetailesID
                  AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)
            )
                THROW 50001, N'maintDetailesID غير موجود للتعديل أو لا يطابق الإدارة', 1;

            UPDATE VIC.MaintenanceDetails
            SET
                  MaintOrdID_FK      = @maintOrdID
                , typesID_FK         = @typesID_FK
                , SupportID_FK       = @SupportID_FK
                , CheckStatus_FK     = @CheckStatus_FK
                , ActionState        = @ActionState
                , CorrectiveAction   = @CorrectiveAction
                , FSN                = @FSN
                , MaintLevel         = @MaintLevel
                , CurrentDate        = @CurrentDT
                , Notes              = @Notes
                , entryDate          = GETDATE()
                , entryData          = @entryData
                , hostName           = @hostName
            WHERE MaintDetailesID = @maintDetailesID;

            IF @@ROWCOUNT <= 0
                THROW 50002, N'لم يتم تعديل أي سجل', 1;

            SET @ActionType = N'UPDATE';
        END

        SET @NewID = @maintDetailesID;
        SET @Note_Audit = N'{'
            + N'"maintDetailesID": "'  + ISNULL(CONVERT(NVARCHAR(MAX), @maintDetailesID), '') + N'"'
            + N',"maintOrdID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @maintOrdID), '') + N'"'
            + N',"typesID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @typesID_FK), '') + N'"'
            + N',"SupportID_FK": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @SupportID_FK), '') + N'"'
            + N',"CheckStatus_FK": "'  + ISNULL(CONVERT(NVARCHAR(MAX), @CheckStatus_FK), '') + N'"'
            + N',"ActionState": "'     + ISNULL(CONVERT(NVARCHAR(MAX), @ActionState), '') + N'"'
            + N',"CorrectiveAction": "'+ ISNULL(CONVERT(NVARCHAR(MAX), @CorrectiveAction), '') + N'"'
            + N',"FSN": "'             + ISNULL(CONVERT(NVARCHAR(MAX), @FSN), '') + N'"'
            + N',"MaintLevel": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @MaintLevel), '') + N'"'
            + N',"CurrentDate": "'     + ISNULL(CONVERT(NVARCHAR(MAX), @CurrentDT, 121), '') + N'"'
            + N',"Notes": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
            + N',"idaraID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
            + N',"entryData": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
            + N',"hostName": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
              N'[VIC].[MaintenanceDetails]'
            , @ActionType
            , ISNULL(@NewID, 0)
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0
            COMMIT;

        SELECT 1 AS IsSuccessful, N'تم حفظ بند الصيانة بنجاح' AS Message_;

    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END