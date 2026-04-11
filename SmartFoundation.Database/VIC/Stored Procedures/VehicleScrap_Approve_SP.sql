
/* =========================================================
   Description:
   اعتماد محضر/طلب إتلاف مركبة (VIC.VehicleScrap) مع تطبيق قواعد المنع:
   - إغلاق أي عهدة نشطة تلقائياً
   - إغلاق/تعطيل أي طلب نقل نشط للمركبة + إضافة History
   - إغلاق أي أمر صيانة نشط تلقائياً
   - تحديث VIC.Vehicles: isActive=0 + vehicleStatusID_FK=Scrapped + تعبئة scrap*
   - تحديث VehicleScrap إلى Approved
   Type: WRITE (WORKFLOW/APPROVE)
========================================================= */

CREATE PROCEDURE [VIC].[VehicleScrap_Approve_SP]
(
      @ScrapID          BIGINT
    , @ApprovedByUserID BIGINT
    , @ApprovedDate     DATETIME = NULL
    , @entryData        NVARCHAR(80)  = NULL
    , @hostName         NVARCHAR(800) = NULL
    , @idaraID_FK        NVARCHAR(10)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE @Now DATETIME = GETDATE();
    DECLARE @ApprDT DATETIME = ISNULL(@ApprovedDate, @Now);

    DECLARE @CH NVARCHAR(200);
    DECLARE @ScrapStatus NVARCHAR(40);
    DECLARE @ScrapDate DATETIME;
    DECLARE @RefNo NVARCHAR(200);
    DECLARE @Reason NVARCHAR(800);
    DECLARE @Note NVARCHAR(2000);
    DECLARE @ScrapIdara BIGINT;

    DECLARE @VehicleIdara BIGINT;
    DECLARE @VehicleStatus INT;

    -- AuditLog
    DECLARE @Note_Audit NVARCHAR(MAX) = NULL;

    BEGIN TRY
        IF @ScrapID IS NULL OR @ScrapID <= 0
            THROW 50001, N'ScrapID غير صحيح', 1;

        IF @ApprovedByUserID IS NULL OR @ApprovedByUserID <= 0
            THROW 50001, N'ApprovedByUserID مطلوب', 1;

        SELECT
              @CH          = s.chassisNumber_FK
            , @ScrapStatus = s.Status
            , @ScrapDate   = s.ScrapDate
            , @RefNo       = s.RefNo
            , @Reason      = s.Reason
            , @Note        = ISNULL(NULLIF(LTRIM(RTRIM(s.Note)), N''), s.Notes)  -- عندك Note + Notes
            , @ScrapIdara  = s.IdaraID_FK
        FROM VIC.VehicleScrap s
        WHERE s.ScrapID = @ScrapID;

        IF @CH IS NULL
            THROW 50001, N'محضر الإتلاف غير موجود', 1;

        IF @ScrapStatus IN (N'Approved', N'Cancelled')
            THROW 50001, N'لا يمكن اعتماد محضر بحالة Approved/Cancelled', 1;

        SELECT
              @VehicleIdara  = v.IdaraID_FK
            , @VehicleStatus = v.vehicleStatusID_FK
        FROM VIC.Vehicles v
        WHERE v.chassisNumber = @CH;

        IF @VehicleIdara IS NULL
            THROW 50001, N'المركبة غير موجودة', 1;

        IF @IdaraID_BIG IS NOT NULL AND @VehicleIdara <> @IdaraID_BIG
            THROW 50001, N'الإدارة غير مطابقة للمركبة', 1;

        IF @ScrapIdara IS NOT NULL AND @IdaraID_BIG IS NOT NULL AND @ScrapIdara <> @IdaraID_BIG
            THROW 50001, N'الإدارة غير مطابقة لمحضر الإتلاف', 1;

        IF @VehicleStatus = 262
            THROW 50001, N'المركبة مُتلفة مسبقاً', 1;

        IF @tc = 0 BEGIN TRAN;

        /* 1) إغلاق أي عهدة نشطة */
        UPDATE VIC.vehicleWithUsers
        SET endDate = @Now
        WHERE chassisNumber_FK = @CH
          AND endDate IS NULL;

        /* 2) إغلاق/تعطيل أي طلب نقل نشط + History */
        DECLARE @Req TABLE (RequestID INT);

        UPDATE r
        SET
              r.active    = 0
            , r.entryDate = @Now
            , r.entryData = COALESCE(@entryData, r.entryData)
            , r.hostName  = COALESCE(@hostName, r.hostName)
        OUTPUT INSERTED.RequestID INTO @Req(RequestID)
        FROM VIC.VehicleTransferRequest r
        WHERE r.chassisNumber_FK = @CH
          AND ISNULL(r.active, 0) = 1
          AND (@IdaraID_BIG IS NULL OR r.IdaraID_FK = @IdaraID_BIG);

        INSERT INTO VIC.VehicleTransferRequestHistory
        (
              RequestID_FK
            , Status
            , ActionBy
            , ActionDate
            , Notes
            , hostName
            , entryDate
            , entryData
        )
        SELECT
              q.RequestID
            , N'Closed'
            , TRY_CONVERT(INT, @ApprovedByUserID)
            , @Now
            , N'Auto closed by scrap approve'
            , @hostName
            , @Now
            , @entryData
        FROM @Req q;

        /* 3) إغلاق أوامر الصيانة النشطة */
        UPDATE m
        SET
              m.MaintOrdActive  = 0
            , m.MaintOrdEndDate = COALESCE(m.MaintOrdEndDate, @Now)
            , m.entryDate       = @Now
            , m.entryData       = COALESCE(@entryData, m.entryData)
            , m.hostName        = COALESCE(@hostName, m.hostName)
        FROM VIC.VehicleMaintenance m
        WHERE m.chassisNumber_FK = @CH
          AND ISNULL(m.MaintOrdActive, 0) = 1
          AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG);

        /* 4) تحديث المركبة إلى Scrapped */
        UPDATE VIC.Vehicles
        SET
              isActive           = 0
            , vehicleStatusID_FK = 262
            , scrapDate          = COALESCE(@ScrapDate, @Now)
            , scrapRefNo         = @RefNo
            , scrapReason        = @Reason
            , scrapNote          = @Note
            , entryDate          = @Now
            , entryData          = COALESCE(@entryData, entryData)
            , hostName           = COALESCE(@hostName, hostName)
        WHERE chassisNumber = @CH
          AND (@IdaraID_BIG IS NULL OR IdaraID_FK = @IdaraID_BIG);

        IF @@ROWCOUNT <= 0
            THROW 50002, N'فشل تحديث حالة المركبة', 1;

        /* 5) تحديث محضر الإتلاف إلى Approved */
        UPDATE VIC.VehicleScrap
        SET
              Status           = N'Approved'
            , ApprovedByUserID = @ApprovedByUserID
            , ApprovedDate     = @ApprDT
            , entryDate        = @Now
            , entryData        = COALESCE(@entryData, entryData)
            , hostName         = COALESCE(@hostName, hostName)
            , IdaraID_FK        = COALESCE(IdaraID_FK, @VehicleIdara) -- تثبيت إن كانت NULL
        WHERE ScrapID = @ScrapID;

        IF @@ROWCOUNT <= 0
            THROW 50002, N'فشل اعتماد محضر الإتلاف', 1;

        -- AuditLog (SCRAP_APPROVE)
        SET @Note_Audit = N'{'
            + N'"ScrapID":"'           + ISNULL(CONVERT(NVARCHAR(MAX), @ScrapID), '') + N'"'
            + N',"chassisNumber":"'    + ISNULL(CONVERT(NVARCHAR(MAX), @CH), '') + N'"'
            + N',"ApprovedByUserID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @ApprovedByUserID), '') + N'"'
            + N',"ApprovedDate":"'     + ISNULL(CONVERT(NVARCHAR(30), @ApprDT, 121), '') + N'"'
            + N',"IdaraID_FK":"'        + ISNULL(CONVERT(NVARCHAR(MAX), COALESCE(@IdaraID_BIG, @VehicleIdara)), '') + N'"'
            + N',"hostName":"'         + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
            + N',"entryData":"'        + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
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
            , N'SCRAP_APPROVE'
            , ISNULL(CONVERT(BIGINT, @ScrapID), 0)
            , COALESCE(@entryData, CONVERT(NVARCHAR(80), @ApprovedByUserID))
            , @Note_Audit
        );

        IF @tc = 0 COMMIT;

        SELECT 1 AS IsSuccessful, N'تم اعتماد الإتلاف وتطبيق الإغلاقات تلقائياً' AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END;