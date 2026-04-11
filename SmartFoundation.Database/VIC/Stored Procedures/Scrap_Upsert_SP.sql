
/* =========================================================
   Description:
   إنشاء/تعديل محضر إتلاف (مسودة) في VIC.VehicleScrap.
   - لا يغير حالة المركبة
   - لا يغلق عهدة/طلبات/صيانة
   - الحالة: Draft
   Type: WRITE (UPSERT)
   Output: صف واحد IsSuccessful / Message_
========================================================= */
CREATE   PROCEDURE [VIC].[Scrap_Upsert_SP]
(
      @ScrapID        BIGINT        = NULL
    , @chassisNumber  NVARCHAR(100)
    , @idaraID_FK     NVARCHAR(10)   = NULL

    , @ScrapDate      DATETIME      = NULL
    , @ScrapTypeID_FK INT           = NULL
    , @RefNo          NVARCHAR(200)  = NULL
    , @Reason         NVARCHAR(800)  = NULL
    , @Note           NVARCHAR(2000) = NULL
    , @Notes          NVARCHAR(2000) = NULL

    , @entryData      NVARCHAR(80)   = NULL
    , @hostName       NVARCHAR(800)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @CH NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
    IF @CH IS NULL
        THROW 50001, N'chassisNumber مطلوب', 1;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- ADDED (Audit)
    DECLARE
          @ActionType NVARCHAR(20) = NULL
        , @Note_Audit NVARCHAR(MAX) = NULL;

    BEGIN TRY
        /* تحقق وجود المركبة + مطابقة الإدارة */
        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.Vehicles v
            WHERE v.chassisNumber = @CH
              AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
        )
            THROW 50001, N'المركبة غير موجودة أو لا تتبع هذه الإدارة', 1;

        /* منع المسودة إذا المركبة Scrapped */
        IF EXISTS
        (
            SELECT 1
            FROM VIC.Vehicles v
            WHERE v.chassisNumber = @CH
              AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
              AND v.vehicleStatusID_FK = 262
        )
            THROW 50001, N'المركبة متلفة نهائيًا (Scrapped) ولا يمكن إنشاء/تعديل مسودة إتلاف لها', 1;

        IF @tc = 0 BEGIN TRAN;

        IF @ScrapID IS NULL
        BEGIN
            INSERT INTO VIC.VehicleScrap
            (
                  chassisNumber_FK
                , IdaraID_FK
                , ScrapDate
                , ScrapTypeID_FK
                , RefNo
                , Reason
                , Note
                , Status
                , entryDate
                , entryData
                , hostName
                , Notes
            )
            VALUES
            (
                  @CH
                , @IdaraID_BIG
                , @ScrapDate
                , @ScrapTypeID_FK
                , @RefNo
                , @Reason
                , @Note
                , N'Draft'
                , GETDATE()
                , @entryData
                , @hostName
                , @Notes
            );

            SET @ScrapID = CONVERT(BIGINT, SCOPE_IDENTITY());
            IF @ScrapID IS NULL OR @ScrapID <= 0
                THROW 50002, N'فشل إنشاء مسودة الإتلاف', 1; -- CHANGED (50002)

            SET @ActionType = N'INSERT'; -- ADDED
        END
        ELSE
        BEGIN
            /* لا نعدّل إلا مسودة */
            IF NOT EXISTS
            (
                SELECT 1
                FROM VIC.VehicleScrap s
                WHERE s.ScrapID = @ScrapID
                  AND s.Status = N'Draft'
            )
                THROW 50001, N'لا يمكن تعديل هذا السجل (ليس Draft أو غير موجود)', 1;

            /* مطابقة الإدارة من السجل نفسه (إذا تمررت) */
            IF @IdaraID_BIG IS NOT NULL
            BEGIN
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM VIC.VehicleScrap s
                    WHERE s.ScrapID = @ScrapID
                      AND s.IdaraID_FK = @IdaraID_BIG
                )
                    THROW 50001, N'السجل لا يتبع هذه الإدارة', 1;
            END

            UPDATE VIC.VehicleScrap
            SET
                  chassisNumber_FK = @CH
                , IdaraID_FK       = COALESCE(@IdaraID_BIG, IdaraID_FK)
                , ScrapDate        = @ScrapDate
                , ScrapTypeID_FK   = @ScrapTypeID_FK
                , RefNo            = @RefNo
                , Reason           = @Reason
                , Note             = @Note
                , entryDate        = GETDATE()
                , entryData        = @entryData
                , hostName         = @hostName
                , Notes            = @Notes
            WHERE ScrapID = @ScrapID;

            IF @@ROWCOUNT <= 0
                THROW 50002, N'لم يتم تعديل أي سجل', 1; -- CHANGED (50002)

            SET @ActionType = N'UPDATE'; -- ADDED
        END

        -- ADDED (AuditLog)
        SET @Note_Audit = N'{'
            + N'"ScrapID": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @ScrapID), '') + N'"'
            + N',"chassisNumber": "'+ ISNULL(CONVERT(NVARCHAR(MAX), @CH), '') + N'"'
            + N',"idaraID_FK": "'   + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
            + N',"ScrapDate": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @ScrapDate, 121), '') + N'"'
            + N',"ScrapTypeID_FK": "'+ ISNULL(CONVERT(NVARCHAR(MAX), @ScrapTypeID_FK), '') + N'"'
            + N',"RefNo": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @RefNo), '') + N'"'
            + N',"Reason": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @Reason), '') + N'"'
            + N',"Note": "'         + ISNULL(CONVERT(NVARCHAR(MAX), @Note), '') + N'"'
            + N',"Notes": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
            + N',"Status": "Draft"'
            + N',"entryData": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
            + N',"hostName": "'     + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
              N'[VIC].[VehicleScrap]'
            , @ActionType
            , ISNULL(@ScrapID, 0)
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0 COMMIT;

        SELECT
              1 AS IsSuccessful
            , N'تم حفظ مسودة الإتلاف بنجاح' AS Message_
            , @ScrapID AS ScrapID;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END