
/* =========================================================
   Description:
   بحث سريع عن المركبات:
   - إذا تم تمرير plateLetters + plateNumbers: يرجع مطابقات اللوحة مباشرة (مسار سريع).
   - غير ذلك: يستخدم q للبحث العام (شاصي/رقم عسكري/حروف لوحة/أرقام لوحة) مع تفضيل المطابقة الدقيقة.
   ويُرجع كذلك بيانات العهدة الحالية + الطلب النشط (من V_ActiveTransferRequests).
   Type: READ (SEARCH/LIST)
========================================================= */

CREATE   PROCEDURE [VIC].[Vehicle_Search_DL]
(
      @q            NVARCHAR(200) = NULL
     , @plateLetters NVARCHAR(100) = NULL
    , @plateNumbers INT = NULL
    , @Top          INT = 50
    , @idaraID_FK    NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @QTrim       NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@q)), N'');
    DECLARE @LettersTrim NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@plateLetters)), N'');
    DECLARE @TopN INT = CASE WHEN @Top IS NULL OR @Top <= 0 OR @Top > 200 THEN 50 ELSE @Top END;

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- لأن جدول العهدة فيه Snapshot كـ INT
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, @IdaraID_BIG);

    /* مسار اللوحة (سريع) */
    IF @LettersTrim IS NOT NULL AND @plateNumbers IS NOT NULL
    BEGIN
        SELECT TOP (@TopN)
            v.*,

            cu.userID_FK         AS CurrentUserID,
            cu.startDate         AS CustodyStartDate,

            tr.RequestID         AS ActiveRequestID,
            tr.RequestTypeID_FK  AS ActiveRequestTypeID,
            tr.fromUserID_FK     AS ActiveFromUserID,
            tr.toUserID_FK       AS ActiveToUserID,
            tr.LastStatus        AS ActiveRequestLastStatus,
            tr.LastActionDate    AS ActiveRequestLastActionDate
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
            SELECT TOP (1) ar.*
            FROM VIC.V_ActiveTransferRequests ar
            INNER JOIN VIC.VehicleTransferRequest vr
                ON vr.RequestID = ar.RequestID
            WHERE ar.chassisNumber_FK = v.chassisNumber
              AND (@IdaraID_BIG IS NULL OR vr.IdaraID_FK = @IdaraID_BIG)
        ) tr
        WHERE v.plateLetters = @LettersTrim
          AND v.plateNumbers = @plateNumbers
          AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
        ORDER BY v.chassisNumber;

        RETURN;
    END

    /* مسار البحث العام */
    IF @QTrim IS NULL
        THROW 50001, N'أدخل قيمة للبحث', 1;

    ;WITH Candidates AS
    (
        /* Exact أولاً */
        SELECT TOP (@TopN) v.chassisNumber
        FROM VIC.Vehicles v
        WHERE (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
          AND (v.chassisNumber = @QTrim OR v.armyNumber = @QTrim)

        UNION ALL

        /* Like/Partial */
        SELECT TOP (@TopN) v2.chassisNumber
        FROM VIC.Vehicles v2
        WHERE (@IdaraID_BIG IS NULL OR v2.IdaraID_FK = @IdaraID_BIG)
          AND (
                (v2.chassisNumber LIKE N'%' + @QTrim + N'%')
             OR (v2.armyNumber    LIKE N'%' + @QTrim + N'%')
             OR (v2.plateLetters  LIKE N'%' + @QTrim + N'%')
             OR (TRY_CONVERT(INT, @QTrim) IS NOT NULL AND v2.plateNumbers = TRY_CONVERT(INT, @QTrim))
          )
    )
    SELECT TOP (@TopN)
        v.*,

        cu.userID_FK         AS CurrentUserID,
        cu.startDate         AS CustodyStartDate,

        tr.RequestID         AS ActiveRequestID,
        tr.RequestTypeID_FK  AS ActiveRequestTypeID,
        tr.fromUserID_FK     AS ActiveFromUserID,
        tr.toUserID_FK       AS ActiveToUserID,
        tr.LastStatus        AS ActiveRequestLastStatus,
        tr.LastActionDate    AS ActiveRequestLastActionDate
    FROM (SELECT DISTINCT chassisNumber FROM Candidates) c
    INNER JOIN VIC.Vehicles v
        ON v.chassisNumber = c.chassisNumber
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
        SELECT TOP (1) ar.*
        FROM VIC.V_ActiveTransferRequests ar
        INNER JOIN VIC.VehicleTransferRequest vr
            ON vr.RequestID = ar.RequestID
        WHERE ar.chassisNumber_FK = v.chassisNumber
          AND (@IdaraID_BIG IS NULL OR vr.IdaraID_FK = @IdaraID_BIG)
    ) tr
    ORDER BY
        CASE WHEN v.chassisNumber = @QTrim THEN 0 ELSE 1 END,
        v.chassisNumber;
END