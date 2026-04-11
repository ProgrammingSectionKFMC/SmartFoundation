
/* =========================================================
   Description:
   ملف مركبة (Vehicle Profile) يعيد عدة Result Sets:
   1) Summary: بيانات المركبة + العهدة الحالية + الطلب النشط + عدّادات (وثائق/تأمين/صيانة/مخالفات)
   2) Documents: أحدث/الأقرب انتهاءً من وثائق المركبة
   3) Insurance: تأمين المركبة (النشط أولاً ثم الأقرب انتهاءً)
   4) Maintenance: أوامر الصيانة (النشط أولاً + عدد البنود لكل أمر)
   5) Violations: مخالفات المركبة (الأحدث)
   مع تحقق صلاحيات اختياري عبر fn_UserHasMenuPermission عند SkipPermission=0.
   Type: READ (GET)
========================================================= */

CREATE   PROCEDURE [VIC].[Vehicle_Profile_Get_DL]
(
      @UsersID         INT = NULL
    , @MenuLink        NVARCHAR(1000) = NULL
    , @SkipPermission  BIT = 1

    , @chassisNumber   NVARCHAR(100)

    , @TopDocuments    INT = 20
    , @TopInsurance    INT = 20
    , @TopMaintenance  INT = 20
    , @TopViolations   INT = 50

    , @idaraID_FK       NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MenuLink_Trim NVARCHAR(1000) = NULLIF(LTRIM(RTRIM(@MenuLink)), N'');
    DECLARE @CH_Trim       NVARCHAR(100)  = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- لأن جدول العهدة فيه Snapshot كـ INT
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, @IdaraID_BIG);

    IF ISNULL(@SkipPermission, 1) = 0 AND @MenuLink_Trim IS NOT NULL
    BEGIN
        IF dbo.fn_UserHasMenuPermission(@UsersID, @MenuLink_Trim) = 0
            THROW 50001, N'عفواً لا تملك صلاحية', 1;
    END

    IF @CH_Trim IS NULL
        THROW 50001, N'chassisNumber مطلوب', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM VIC.Vehicles v
        WHERE v.chassisNumber = @CH_Trim
          AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
    )
        THROW 50001, N'المركبة غير موجودة أو لا تطابق الإدارة', 1;

    DECLARE @TD INT = CASE WHEN @TopDocuments   IS NULL OR @TopDocuments   < 1 OR @TopDocuments   > 200 THEN 20 ELSE @TopDocuments   END;
    DECLARE @TI INT = CASE WHEN @TopInsurance   IS NULL OR @TopInsurance   < 1 OR @TopInsurance   > 200 THEN 20 ELSE @TopInsurance   END;
    DECLARE @TM INT = CASE WHEN @TopMaintenance IS NULL OR @TopMaintenance < 1 OR @TopMaintenance > 200 THEN 20 ELSE @TopMaintenance END;
    DECLARE @TV INT = CASE WHEN @TopViolations  IS NULL OR @TopViolations  < 1 OR @TopViolations  > 500 THEN 50 ELSE @TopViolations  END;

    /* 1) Summary */
    SELECT
        v.*,

        cu.userID_FK AS CurrentUserID,
        cu.startDate AS CustodyStartDate,

        ar.RequestID        AS ActiveRequestID,
        ar.RequestTypeID_FK AS ActiveRequestTypeID,
        ar.fromUserID_FK    AS ActiveFromUserID,
        ar.toUserID_FK      AS ActiveToUserID,
        ar.LastStatus       AS ActiveRequestLastStatus,
        ar.LastActionDate   AS ActiveRequestLastActionDate,

        (SELECT COUNT(*) FROM VIC.vehicleDocument d
          WHERE d.chassisNumber_FK = v.chassisNumber
            AND (@IdaraID_BIG IS NULL OR d.IdaraID_FK = @IdaraID_BIG)
        ) AS DocumentsCount,

        (SELECT COUNT(*) FROM VIC.VehicleInsurance i
          WHERE i.chassisNumber_FK = v.chassisNumber
            AND (@IdaraID_BIG IS NULL OR i.IdaraID_FK = @IdaraID_BIG)
        ) AS InsuranceCount,

        (SELECT COUNT(*) FROM VIC.VehicleMaintenance m
          WHERE m.chassisNumber_FK = v.chassisNumber
            AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)
        ) AS MaintenanceCount,

        (SELECT COUNT(*) FROM VIC.Violations vi
          WHERE vi.chassisNumber_FK = v.chassisNumber
            AND (@IdaraID_BIG IS NULL OR vi.IdaraID_FK = @IdaraID_BIG)
        ) AS ViolationsCount
    FROM VIC.Vehicles v
    OUTER APPLY
    (
        SELECT TOP (1) w.userID_FK, w.startDate
        FROM VIC.vehicleWithUsers w
        WHERE w.chassisNumber_FK = v.chassisNumber
          AND w.endDate IS NULL
          AND (@IdaraID_INT IS NULL OR w.IdaraID_Snapshot = @IdaraID_INT)
        ORDER BY w.startDate DESC, w.vehicleWithUsersID DESC
    ) cu
    OUTER APPLY
    (
        SELECT TOP (1) r.*
        FROM VIC.V_ActiveTransferRequests r
        INNER JOIN VIC.VehicleTransferRequest vr
            ON vr.RequestID = r.RequestID
        WHERE r.chassisNumber_FK = v.chassisNumber
          AND (@IdaraID_BIG IS NULL OR vr.IdaraID_FK = @IdaraID_BIG)
    ) ar
    WHERE v.chassisNumber = @CH_Trim
      AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG);

    /* 2) Documents */
    SELECT TOP (@TD) d.*
    FROM VIC.vehicleDocument d
    WHERE d.chassisNumber_FK = @CH_Trim
      AND (@IdaraID_BIG IS NULL OR d.IdaraID_FK = @IdaraID_BIG)
    ORDER BY
        CASE WHEN d.vehicleDocumentEndDate IS NULL THEN 1 ELSE 0 END,
        d.vehicleDocumentEndDate ASC,
        d.entryDate DESC,
        d.vehicleDocumentID DESC;

    /* 3) Insurance */
    SELECT TOP (@TI) i.*
    FROM VIC.VehicleInsurance i
    WHERE i.chassisNumber_FK = @CH_Trim
      AND (@IdaraID_BIG IS NULL OR i.IdaraID_FK = @IdaraID_BIG)
    ORDER BY
        CASE WHEN ISNULL(i.active, 0) = 1 THEN 0 ELSE 1 END,
        CASE WHEN i.EndInsurance IS NULL THEN 1 ELSE 0 END,
        i.EndInsurance ASC,
        i.entryDate DESC,
        i.VehicleInsuranceID DESC;

    /* 4) Maintenance Orders */
    SELECT TOP (@TM)
        m.*,
        (SELECT COUNT(*)
         FROM VIC.MaintenanceDetails md
         WHERE md.MaintOrdID_FK = m.MaintOrdID
        ) AS DetailsCount
    FROM VIC.VehicleMaintenance m
    WHERE m.chassisNumber_FK = @CH_Trim
      AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)
    ORDER BY
        CASE WHEN ISNULL(m.MaintOrdActive, 0) = 1 THEN 0 ELSE 1 END,
        CASE WHEN m.MaintOrdStartDate IS NULL THEN 1 ELSE 0 END,
        m.MaintOrdStartDate DESC,
        m.entryDate DESC,
        m.MaintOrdID DESC;

    /* 5) Violations */
    SELECT TOP (@TV) v.*
    FROM VIC.Violations v
    WHERE v.chassisNumber_FK = @CH_Trim
      AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
    ORDER BY
        CASE WHEN v.violationDate IS NULL THEN 1 ELSE 0 END,
        v.violationDate DESC,
        v.entrydate DESC,
        v.violationID DESC;
END