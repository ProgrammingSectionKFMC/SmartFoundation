
/* =========================================================
   Description:
   تنفيذ إجراء على محضر الإتلاف:
   - APPROVE: اعتماد الإتلاف + تطبيق آثار الإتلاف على المركبة (Scrapped) وإغلاق العهدة/الطلبات/الصيانة النشطة.
   - CANCEL : إلغاء المسودة فقط (Status=Cancelled) دون تعديل المركبة.
   Type: WRITE (WORKFLOW)
   Output: صف واحد IsSuccessful / Message_
========================================================= */
CREATE   PROCEDURE [VIC].[Scrap_Action_SP]
(
      @Action         NVARCHAR(20)   -- APPROVE | CANCEL
    , @ScrapID        BIGINT
    , @idaraID_FK     NVARCHAR(10) = NULL

    , @actionByUserID BIGINT = NULL
    , @actionNote     NVARCHAR(1000) = NULL

    , @entryData      NVARCHAR(80)  = NULL
    , @hostName       NVARCHAR(800) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @Act NVARCHAR(20) = UPPER(NULLIF(LTRIM(RTRIM(@Action)), N''));
    IF @Act IS NULL OR @Act NOT IN (N'APPROVE', N'CANCEL')
        THROW 50001, N'Action غير صحيح (APPROVE/CANCEL)', 1;

    IF @ScrapID IS NULL OR @ScrapID <= 0
        THROW 50001, N'ScrapID غير صحيح', 1;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE
          @CH NVARCHAR(200)
        , @ScrapStatus NVARCHAR(40)
        , @ScrapRefNo NVARCHAR(200)
        , @ScrapReason NVARCHAR(800)
        , @ScrapNote NVARCHAR(2000)
        , @ScrapDate DATETIME
        , @ScrapIdara BIGINT;

    -- ADDED (Audit)
    DECLARE @Note_Audit NVARCHAR(MAX) = NULL;

    BEGIN TRY
        /* جلب السجل + مطابقة الإدارة (إذا تم تمريرها) */
        SELECT
              @CH          = s.chassisNumber_FK
            , @ScrapStatus = s.Status
            , @ScrapDate   = s.ScrapDate
            , @ScrapRefNo  = s.RefNo
            , @ScrapReason = s.Reason
            , @ScrapNote   = s.Note
            , @ScrapIdara  = s.IdaraID_FK
        FROM VIC.VehicleScrap s
        WHERE s.ScrapID = @ScrapID;

        IF @CH IS NULL
            THROW 50001, N'سجل الإتلاف غير موجود', 1;

        IF @IdaraID_BIG IS NOT NULL
        BEGIN
            IF ISNULL(@ScrapIdara, -1) <> @IdaraID_BIG
                THROW 50001, N'سجل الإتلاف لا يتبع هذه الإدارة', 1;
        END

        /* لازم يكون Draft للتصرف */
        IF @ScrapStatus <> N'Draft'
            THROW 50001, N'لا يمكن تنفيذ العملية لأن السجل ليس Draft', 1;

        /* المركبة + مطابقة الإدارة على Vehicles */
        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.Vehicles v
            WHERE v.chassisNumber = @CH
              AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
        )
            THROW 50001, N'المركبة غير موجودة أو لا تتبع هذه الإدارة', 1;

        IF @tc = 0 BEGIN TRAN;

        /* =========================
           CANCEL
        ========================= */
        IF @Act = N'CANCEL'
        BEGIN
            UPDATE VIC.VehicleScrap
            SET
                  Status    = N'Cancelled'
                , entryDate = GETDATE()
                , entryData = @entryData
                , hostName  = @hostName
                , Notes     = COALESCE(@actionNote, Notes)
            WHERE ScrapID = @ScrapID;

            IF @@ROWCOUNT <= 0
                THROW 50002, N'لم يتم تحديث السجل', 1; -- CHANGED (50002)

            -- ADDED (AuditLog)
            SET @Note_Audit = N'{'
                + N'"Action": "'         + ISNULL(CONVERT(NVARCHAR(MAX), @Act), '') + N'"'
                + N',"ScrapID": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @ScrapID), '') + N'"'
                + N',"chassisNumber": "' + ISNULL(CONVERT(NVARCHAR(MAX), @CH), '') + N'"'
                + N',"fromStatus": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @ScrapStatus), '') + N'"'
                + N',"toStatus": "Cancelled"'
                + N',"idaraID_FK": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"actionByUserID": "'+ ISNULL(CONVERT(NVARCHAR(MAX), @actionByUserID), '') + N'"'
                + N',"actionNote": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @actionNote), '') + N'"'
                + N',"entryData": "'     + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                , @Act
                , ISNULL(@ScrapID, 0)
                , @entryData
                , @Note_Audit
            );

            IF @tc = 0 COMMIT;

            SELECT 1 AS IsSuccessful, N'تم إلغاء مسودة الإتلاف' AS Message_;
            RETURN;
        END

        /* =========================
           APPROVE
        ========================= */

        /* منع اعتماد إذا المركبة أصلاً Scrapped */
        IF EXISTS
        (
            SELECT 1
            FROM VIC.Vehicles v
            WHERE v.chassisNumber = @CH
              AND v.vehicleStatusID_FK = 262
        )
            THROW 50001, N'المركبة متلفة نهائيًا بالفعل', 1;

        /* 1) إغلاق أي عهدة نشطة */
        UPDATE VIC.vehicleWithUsers
        SET endDate = GETDATE()
        WHERE chassisNumber_FK = @CH
          AND endDate IS NULL;

        /* 2) إغلاق/تعطيل طلبات نقل نشطة */
        ;WITH ActiveReq AS
        (
            SELECT r.RequestID
            FROM VIC.VehicleTransferRequest r
            WHERE r.chassisNumber_FK = @CH
              AND ISNULL(r.active, 0) = 1
        )
        UPDATE r
        SET
              active     = 0
            , aproveNote = LEFT(COALESCE(@actionNote, r.aproveNote, N'Closed due to scrap'), 400)
            , entryDate  = GETDATE()
            , entryData  = COALESCE(@entryData, r.entryData)
            , hostName   = COALESCE(@hostName, r.hostName)
        FROM VIC.VehicleTransferRequest r
        INNER JOIN ActiveReq a ON a.RequestID = r.RequestID;

        /* 2-B) تسجيل حدث تاريخ لطلبات النقل التي أغلقت بسبب الإتلاف (مرة واحدة لكل طلب) */
        INSERT INTO VIC.VehicleTransferRequestHistory
        (
              RequestID_FK, Status, ActionBy, ActionDate, Notes, hostName
        )
        SELECT
              r.RequestID
            , N'ClosedDueToScrap'
            , TRY_CONVERT(BIGINT, @actionByUserID)
            , GETDATE()
            , @actionNote
            , @hostName
        FROM VIC.VehicleTransferRequest r
        WHERE r.chassisNumber_FK = @CH
          AND ISNULL(r.active, 0) = 0
          AND NOT EXISTS
          (
              SELECT 1
              FROM VIC.VehicleTransferRequestHistory h
              WHERE h.RequestID_FK = r.RequestID
                AND h.Status = N'ClosedDueToScrap'
          );

        /* 3) إغلاق أوامر صيانة نشطة تلقائيًا */
        UPDATE VIC.VehicleMaintenance
        SET
              MaintOrdActive  = 0
            , MaintOrdEndDate = COALESCE(MaintOrdEndDate, GETDATE())
            , entryDate       = GETDATE()
            , entryData       = COALESCE(@entryData, entryData)
            , hostName        = COALESCE(@hostName, hostName)
        WHERE chassisNumber_FK = @CH
          AND ISNULL(MaintOrdActive, 0) = 1;

        /* 4) اعتماد السجل */
        UPDATE VIC.VehicleScrap
        SET
              Status           = N'Approved'
            , ApprovedByUserID = @actionByUserID
            , ApprovedDate     = GETDATE()
            , entryDate        = GETDATE()
            , entryData        = @entryData
            , hostName         = @hostName
            , Notes            = COALESCE(@actionNote, Notes)
        WHERE ScrapID = @ScrapID;

        IF @@ROWCOUNT <= 0
            THROW 50002, N'لم يتم اعتماد السجل', 1; -- CHANGED (50002)

        /* 5) تحديث المركبة Scrapped */
        UPDATE VIC.Vehicles
        SET
              isActive            = 0
            , vehicleStatusID_FK  = 262
            , scrapDate           = COALESCE(@ScrapDate, GETDATE())
            , scrapRefNo          = @ScrapRefNo
            , scrapReason         = @ScrapReason
            , scrapNote           = @ScrapNote
        WHERE chassisNumber = @CH
          AND (@IdaraID_BIG IS NULL OR IdaraID_FK = @IdaraID_BIG);

        IF @@ROWCOUNT <= 0
            THROW 50002, N'فشل تحديث حالة المركبة إلى Scrapped', 1; -- CHANGED (50002)

        -- ADDED (AuditLog)
        SET @Note_Audit = N'{'
            + N'"Action": "'         + ISNULL(CONVERT(NVARCHAR(MAX), @Act), '') + N'"'
            + N',"ScrapID": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @ScrapID), '') + N'"'
            + N',"chassisNumber": "' + ISNULL(CONVERT(NVARCHAR(MAX), @CH), '') + N'"'
            + N',"fromStatus": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @ScrapStatus), '') + N'"'
            + N',"toStatus": "Approved"'
            + N',"ScrapDate": "'     + ISNULL(CONVERT(NVARCHAR(MAX), @ScrapDate, 121), '') + N'"'
            + N',"RefNo": "'         + ISNULL(CONVERT(NVARCHAR(MAX), @ScrapRefNo), '') + N'"'
            + N',"Reason": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @ScrapReason), '') + N'"'
            + N',"Note": "'          + ISNULL(CONVERT(NVARCHAR(MAX), @ScrapNote), '') + N'"'
            + N',"idaraID_FK": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
            + N',"actionByUserID": "'+ ISNULL(CONVERT(NVARCHAR(MAX), @actionByUserID), '') + N'"'
            + N',"actionNote": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @actionNote), '') + N'"'
            + N',"entryData": "'     + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
            + N',"hostName": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
            , @Act
            , ISNULL(@ScrapID, 0)
            , @entryData
            , @Note_Audit
        );

        IF @tc = 0 COMMIT;

        SELECT 1 AS IsSuccessful, N'تم اعتماد الإتلاف وتحديث حالة المركبة' AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END