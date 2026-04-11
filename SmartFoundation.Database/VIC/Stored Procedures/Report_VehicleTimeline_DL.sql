
/* =========================================================
   Description:
   تقرير “الخط الزمني” لمركبة واحدة حسب chassisNumber، ويجمع الأحداث من عدة مصادر:
   العهد (بدء/انتهاء) + طلبات النقل + المحاضر + الصيانة (بدء/انتهاء) + الوثائق (بدء/انتهاء) + التأمين (بدء/انتهاء)
   مع فلاتر اختيارية لنطاق التاريخ.
   Type: READ (REPORT)
========================================================= */

CREATE   PROCEDURE [VIC].[Report_VehicleTimeline_DL]
(
      @chassisNumber NVARCHAR(100)
    , @fromDate      DATETIME = NULL
    , @toDate        DATETIME = NULL
    , @idaraID_FK    NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CH NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
    IF @CH IS NULL
        THROW 50001, N'chassisNumber مطلوب', 1;

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- لأن جدول العهدة فيه Snapshot كـ INT
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, @IdaraID_BIG);

    -- تحقق وجود المركبة + مطابقة الإدارة إن تم تمريرها (READ لا يرجع “فاضي” بصمت)
    IF NOT EXISTS
    (
        SELECT 1
        FROM VIC.Vehicles v
        WHERE v.chassisNumber = @CH
          AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
    )
        THROW 50001, N'المركبة غير موجودة أو لا تطابق الإدارة', 1;

    ;WITH Timeline AS
    (
        -- Custody Start
        SELECT
              N'Custody'              AS EventType
            , w.startDate             AS EventDate
            , w.vehicleWithUsersID    AS RefID
            , N'بدء عهدة'             AS Title
            , ISNULL(w.note, N'')     AS Details
        FROM VIC.vehicleWithUsers w
        WHERE w.chassisNumber_FK = @CH
          AND w.startDate IS NOT NULL
          AND (@IdaraID_INT IS NULL OR w.IdaraID_Snapshot = @IdaraID_INT)

        UNION ALL

        -- Custody End
        SELECT
              N'Custody'
            , w.endDate
            , w.vehicleWithUsersID
            , N'انتهاء عهدة'
            , ISNULL(w.note, N'')
        FROM VIC.vehicleWithUsers w
        WHERE w.chassisNumber_FK = @CH
          AND w.endDate IS NOT NULL
          AND (@IdaraID_INT IS NULL OR w.IdaraID_Snapshot = @IdaraID_INT)

        UNION ALL

        -- Transfer Request
        SELECT
              N'Transfer'
            , r.entryDate
            , r.RequestID
            , N'طلب نقل مركبة'
            , N''
        FROM VIC.VehicleTransferRequest r
        WHERE r.chassisNumber_FK = @CH
          AND (@IdaraID_BIG IS NULL OR r.IdaraID_FK = @IdaraID_BIG)

        UNION ALL

        -- Handover
        SELECT
              N'Handover'
            , h.handoverDate
            , h.VehicleHandoverID
            , N'محضر تسليم/استلام'
            , ISNULL(h.note, N'')
        FROM VIC.VehicleHandover h
        INNER JOIN VIC.VehicleTransferRequest r
            ON r.RequestID = h.RequestID_FK
        WHERE r.chassisNumber_FK = @CH
          AND (@IdaraID_BIG IS NULL OR r.IdaraID_FK = @IdaraID_BIG)

        UNION ALL

        -- Maintenance Start
        SELECT
              N'Maintenance'
            , m.MaintOrdStartDate
            , m.MaintOrdID
            , N'بدء صيانة'
            , ISNULL(m.MaintOrdDesc, N'')
        FROM VIC.VehicleMaintenance m
        WHERE m.chassisNumber_FK = @CH
          AND m.MaintOrdStartDate IS NOT NULL
          AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)

        UNION ALL

        -- Maintenance End
        SELECT
              N'Maintenance'
            , m.MaintOrdEndDate
            , m.MaintOrdID
            , N'انتهاء صيانة'
            , ISNULL(m.MaintOrdDesc, N'')
        FROM VIC.VehicleMaintenance m
        WHERE m.chassisNumber_FK = @CH
          AND m.MaintOrdEndDate IS NOT NULL
          AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)

        UNION ALL

        -- Document Start
        SELECT
              N'Document'
            , d.vehicleDocumentStartDate
            , d.vehicleDocumentID
            , N'بدء وثيقة'
            , ISNULL(d.vehicleDocumentNo, N'')
        FROM VIC.vehicleDocument d
        WHERE d.chassisNumber_FK = @CH
          AND d.vehicleDocumentStartDate IS NOT NULL
          AND (@IdaraID_BIG IS NULL OR d.IdaraID_FK = @IdaraID_BIG)

        UNION ALL

        -- Document End
        SELECT
              N'Document'
            , d.vehicleDocumentEndDate
            , d.vehicleDocumentID
            , N'انتهاء وثيقة'
            , ISNULL(d.vehicleDocumentNo, N'')
        FROM VIC.vehicleDocument d
        WHERE d.chassisNumber_FK = @CH
          AND d.vehicleDocumentEndDate IS NOT NULL
          AND (@IdaraID_BIG IS NULL OR d.IdaraID_FK = @IdaraID_BIG)

        UNION ALL

        -- Insurance Start
        SELECT
              N'Insurance'
            , i.StartInsurance
            , i.VehicleInsuranceID
            , N'بدء تأمين'
            , ISNULL(i.Source, N'')
        FROM VIC.VehicleInsurance i
        WHERE i.chassisNumber_FK = @CH
          AND i.StartInsurance IS NOT NULL
          AND (@IdaraID_BIG IS NULL OR i.IdaraID_FK = @IdaraID_BIG)

        UNION ALL

        -- Insurance End
        SELECT
              N'Insurance'
            , i.EndInsurance
            , i.VehicleInsuranceID
            , N'انتهاء تأمين'
            , ISNULL(i.Source, N'')
        FROM VIC.VehicleInsurance i
        WHERE i.chassisNumber_FK = @CH
          AND i.EndInsurance IS NOT NULL
          AND (@IdaraID_BIG IS NULL OR i.IdaraID_FK = @IdaraID_BIG)
    )
    SELECT
          EventType
        , EventDate
        , RefID
        , Title
        , Details
    FROM Timeline
    WHERE (@fromDate IS NULL OR EventDate >= @fromDate)
      AND (@toDate   IS NULL OR EventDate <= @toDate)
    ORDER BY EventDate ASC;
END