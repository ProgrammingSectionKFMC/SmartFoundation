
/* =========================================================
   Description:
   قائمة موسّعة للمركبات (Vehicle List Extended) مع:
   - تحقق صلاحيات اختياري (UsersID/MenuLink/SkipPermission)
   - بحث عام q (شاصي/لوحة/رقم عسكري)
   - فلاتر: ownerID_FK / plateLetters / plateNumbers / HasCustody / HasActiveRequest
   - إثراء البيانات: العهدة الحالية + الطلب النشط (من V_ActiveTransferRequests)
   - Paging: OFFSET/FETCH
   Type: READ (LIST)
========================================================= */

CREATE   PROCEDURE [VIC].[Vehicle_List_EXT_DL]
(
      @UsersID          INT = NULL
    , @MenuLink         NVARCHAR(1000) = NULL
    , @SkipPermission   BIT = 1

    , @q                NVARCHAR(200) = NULL
    , @ownerID_FK       NVARCHAR(100) = NULL
    , @plateLetters     NVARCHAR(100) = NULL
    , @plateNumbers     INT = NULL
    , @HasCustody       BIT = NULL
    , @HasActiveRequest BIT = NULL

    , @PageNumber       INT = 1
    , @PageSize         INT = 50

    , @idaraID_FK       NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MenuLink_Trim NVARCHAR(1000) = NULLIF(LTRIM(RTRIM(@MenuLink)), N'');

    IF ISNULL(@SkipPermission, 1) = 0 AND @MenuLink_Trim IS NOT NULL
    BEGIN
        IF dbo.fn_UserHasMenuPermission(@UsersID, @MenuLink_Trim) = 0
            THROW 50001, N'عفواً لا تملك صلاحية', 1;
    END

    DECLARE @QTrim        NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@q)), N'');
    DECLARE @Owner_Trim   NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@ownerID_FK)), N'');
    DECLARE @Letters_Trim NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@plateLetters)), N'');

    DECLARE @PN INT = CASE WHEN @PageNumber IS NULL OR @PageNumber < 1 THEN 1 ELSE @PageNumber END;
    DECLARE @PS INT = CASE WHEN @PageSize   IS NULL OR @PageSize   < 1 OR @PageSize   > 200 THEN 50 ELSE @PageSize END;
    DECLARE @Skip INT = (@PN - 1) * @PS;

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- لأن جدول العهدة فيه Snapshot كـ INT
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, @IdaraID_BIG);

    ;WITH Base AS
    (
        SELECT
              v.vehicleID
            , v.chassisNumber
            , v.ownerID_FK
            , v.plateLetters
            , v.plateNumbers
            , v.armyNumber
            , v.yearModel
            , v.vehicleNote
            , v.entryDate
        FROM VIC.Vehicles v
        WHERE 1 = 1
          AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
          AND (@Owner_Trim   IS NULL OR v.ownerID_FK   = @Owner_Trim)
          AND (@Letters_Trim IS NULL OR v.plateLetters = @Letters_Trim)
          AND (@plateNumbers IS NULL OR v.plateNumbers = @plateNumbers)
          AND (
                @QTrim IS NULL
                OR v.chassisNumber LIKE N'%' + @QTrim + N'%'
                OR v.armyNumber    LIKE N'%' + @QTrim + N'%'
                OR v.plateLetters  LIKE N'%' + @QTrim + N'%'
                OR (TRY_CONVERT(INT, @QTrim) IS NOT NULL AND v.plateNumbers = TRY_CONVERT(INT, @QTrim))
              )
    ),
    Enriched AS
    (
        SELECT
              b.*
            , cu.userID_FK        AS CurrentUserID
            , cu.startDate        AS CustodyStartDate
            , ar.RequestID        AS ActiveRequestID
            , ar.LastStatus       AS ActiveRequestLastStatus
            , ar.LastActionDate   AS ActiveRequestLastActionDate
        FROM Base b
        OUTER APPLY
        (
            SELECT TOP (1) w.userID_FK, w.startDate
            FROM VIC.vehicleWithUsers w
            WHERE w.chassisNumber_FK = b.chassisNumber
              AND w.endDate IS NULL
              AND (@IdaraID_INT IS NULL OR w.IdaraID_Snapshot = @IdaraID_INT)
            ORDER BY w.startDate DESC, w.vehicleWithUsersID DESC
        ) cu
        OUTER APPLY
        (
            SELECT TOP (1)
                  r.RequestID
                , r.LastStatus
                , r.LastActionDate
            FROM VIC.V_ActiveTransferRequests r
            INNER JOIN VIC.VehicleTransferRequest vr
                ON vr.RequestID = r.RequestID
            WHERE r.chassisNumber_FK = b.chassisNumber
              AND (@IdaraID_BIG IS NULL OR vr.IdaraID_FK = @IdaraID_BIG)
        ) ar
    )
    SELECT e.*
    FROM Enriched e
    WHERE (
            @HasCustody IS NULL
         OR (@HasCustody = 1 AND e.CurrentUserID IS NOT NULL)
         OR (@HasCustody = 0 AND e.CurrentUserID IS NULL)
    )
      AND (
            @HasActiveRequest IS NULL
         OR (@HasActiveRequest = 1 AND e.ActiveRequestID IS NOT NULL)
         OR (@HasActiveRequest = 0 AND e.ActiveRequestID IS NULL)
    )
    ORDER BY e.entryDate DESC, e.chassisNumber
    OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;
END